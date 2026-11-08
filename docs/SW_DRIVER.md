# 软件驱动、部署与调试

本文与 `NPU_ARCHITECTURE.md` 的硬件契约配套。运行目标为 Zynq-7000 Cortex-A9 裸机，依赖 Xilinx standalone BSP 的 `xil_io.h`、`xil_cache.h`、`xtime_l.h`、`xil_mmu.h`。不能直接当作 Linux 用户态驱动使用。

## 1. 分层与初始化顺序

| 文件 | 职责 |
|---|---|
| npu.h | MMIO、scratch 加载、单任务提交与等待 |
| npu_graph.h / npu_graph.c | DMA 描述符构造、异步/同步有序图调度 |
| npu_reference.c | 与 RTL 语义相同的独立整数参考 |
| npu_selftest.c | 小张量卷积、ReLU、池化硬件自检 |
| npu_live.c | 权重装载、完整测试集、逐帧采集/推理/比较/发布 |
| npu_overlay.c | 实际预测数字的 RGB888 显示叠加 |
| camera_rate.c | 用 ARM global timer 测量采集帧间隔 |
| digits_model_test.c | CPU MMIO 装载方式的完整模型回归 |
| app/ | 摄像头、VDMA、HDMI 初始化和裸机入口 |

上电流程：初始化 PS DDR/时钟 → 下载匹配 bitstream → PS post_config → 下载同一 XSA 构建的 ELF → 配置摄像头 → 启动 VDMA/HDMI → NPU 自检 → 实测帧率 → 模型回归 → 实时运行。不能把旧 XSA 的 BSP 与新硬件混用。

```c
npu_device dev = { .base = 0x43c20000u };
if (npu_read(&dev, 0) != 0x4e505532u) {
    /* 硬件版本不符：停止启动该应用。 */
}
```

## 2. 基本 API

`npu_read/write(dev, offset)` 访问 MMIO；offset 是字节偏移。外设区必须为 Device/不可缓存且有序。`npu_device` 只存基址，不提供锁。多线程、多核或 IRQ 与前台同时访问时，上层必须实现独占。

`npu_idle(dev)` 要求 busy=0 且 queue_count=0。`npu_load(dev, scratch_word, int32_data, count)` 只在 idle 时加载，返回 0 成功、-1 参数/设备状态不允许。偏移和数量以 scratch 的 32 位字计，不能传 DDR 指针代替字索引。

`npu_submit(dev, desc)` 将 16 个 word 写入 staging，然后提交，返回 0 或 -1 队列满。提交后的原始结构可以复用，因为硬件已复制；提交过程中任何其他调用者都不能改 staging。该 API 不检查算子合法性，硬件最终校验。当前裸机 MMIO 封装不会将 AXI SLVERR 转成 C 返回值，错误的 MMIO 访问可能产生处理器 data abort。

`npu_wait(dev, expected_completed, poll_limit)` 返回 0、-2 最近任务错误或 -1 轮询次数耗尽。limit 是 MMIO 次数而非微秒。它只适用于软件独占且能明确预期完成计数的简单序列；完整多节点图使用 graph API，以累计错误计数防止中间错误被覆盖。

## 3. DMA 构造与缓存协议

```c
npu_desc load = npu_dma_job(ddr_address, scratch_word, elements,
                            0,  /* store=0: DDR -> scratch */
                            1,  /* packed signed INT8 */
                            100 /* completion tag */);
```

store=1 为 scratch→DDR；packed=0 为原始 32 位元素。构造器只填字段，不替调用者验证内存规划。DDR 地址必须 4 字节对齐，必须在硬件允许范围内，scratch 跨度必须完整有效。INT8 packed 尾部读会触及对齐的完整字；准备至少 `round_up(elements,4)` 字节有效内存。回写尾部依靠 strobe 保留邻字节。

HP1 不与 Cortex-A9 数据 cache 自动一致。输入/权重：CPU 写完后 flush；输出：使用独占完整 cache line，发 DMA 前清理并失效，DMA 成功完成后再次失效，再读取。禁止 DMA 运行时 CPU 修改同一 cache line，即使修改的是逻辑上相邻的其他变量。

```c
static int8_t input[64] __attribute__((aligned(64)));
static int8_t output[64] __attribute__((aligned(64)));
Xil_DCacheFlushRange((INTPTR)input, sizeof input);
Xil_DCacheFlushRange((INTPTR)output, sizeof output);
Xil_DCacheInvalidateRange((INTPTR)output, sizeof output);
/* 提交图，并等全部 DDR 回写完成。 */
Xil_DCacheInvalidateRange((INTPTR)output, sizeof output);
```

实际 BSP 的 cache line 为 32 字节，应用使用 64 字节对齐和独占空间，使相邻状态不会被失效操作丢弃。输出只有 10 字节，仍分配完整 64 字节。不允许把栈上紧邻其他状态的小数组直接当成无隔离的 DMA 输出。

硬件 mailbox 不由 CPU 写入；消费者只失效并读取。对 `0x04000000+bank*64` 做 cache maintenance 后核对相同 bank 的 MMIO 特征，随后直接把该 DDR 地址交给输入 DMA。

## 4. 图调度 API

`npu_graph_run(dev, jobs, count, timeout_us)` 是同步入口，内部使用下述异步状态机。支持 1..65535 个顺序节点，超过硬件队列深度时持续补充；它是有序描述符列表，尚无通用带分支的 DAG 解释器。

`npu_graph_begin(context, dev, jobs, count, timeout_us)` 要求设备 idle；记录起始完成数、错误数和 ARM timer，尽量填满可用队列。返回值 1 表示运行中，0 表示已完成，负值表示失败。begin 可能直接返回最终状态，调用者必须检查。

`npu_graph_poll(context)` 继续派发、读取完成计数、检查累积错误和超时。返回值相同。context 和 jobs 在运行期间必须保持有效，jobs 不得修改；每台设备只允许一个活动 context。完成后再次 poll 返回 -1。

```c
npu_graph_context ctx;
int status = npu_graph_begin(&ctx, &dev, jobs, 5, 100000);
if (status >= 0) {
    /* 进行有界的独立 CPU 工作，例如计算软件参考。
       不得触碰 scratch、DMA 缓冲或该设备的 MMIO staging。 */
}
while (status == 1) status = npu_graph_poll(&ctx);
if (status == 0) {
    /* invalidate 输出 cache，再消费结果。 */
}
```

| 返回值 | 含义 | 处理 |
|---|---|---|
| 1 | 异步 pending | 继续 poll |
| 0 | 整图成功 | 输出 cache invalidate 后读取 |
| -1 | 参数/设备非 idle/context 非活动 | 修正调用顺序 |
| -2 | 硬件错误 | 已接受任务 drain 后返回，丢弃整图输出 |
| -3 | wall-clock 超时 | 不代表取消，保留 DMA 缓冲所有权 |
| -4 | 完成计数超过本 context 已提交数 | 存在其他调用者/复位等状态异常 |

检测到错误后停止继续提交，但等待已接受任务完成并且设备 idle；这样错误路径不会把仍在使用的缓冲交还调用方。等待若超时则返回 -3，此时不得复用缓冲。无限不响应的 AXI 事务只能通过外部恢复/系统复位处理。关闭 CONTROL.bit0 不会取消当前任务，且会令待执行队列停止 drain。

计数差使用 uint32 模运算，适用于一次图内增量小于 2^32 的情况。调度器检查总 ERROR_COUNT，避免只看 LAST_ERROR 时漏掉中间失败。硬件完成记录只留最近 tag/cycles，要求逐节点定位错误时须逐项执行或增加追踪机制。

## 5. 完整 CNN 的调用

初始化用四个 DMA 任务装入 72 个 conv 权重、8 个 INT32 bias、1280 个分类权重及10 个 INT32 bias。权重布局为 output-channel/kernel-y/kernel-x/input-channel。训练导出的头文件包含模型常量和 360 个隔离测试向量。

每次输入有五项任务：

1. packed DDR 输入 → scratch[0..63]。
2. 8×8×1 卷积，输出 8×8×8 到 scratch[2048]，shift8、融合 ReLU。
3. 2×2 stride2 最大池化，输出 4×4×8 到 scratch[2560]。
4. 4×4 卷积输出 1×1×10 到 scratch[2816]，shift9。
5. packed scratch logits → DDR 输出缓冲。

最高 logit 的类别即预测值，平分时取较小索引。top_score、margin 是有符号量化 logit 及其差，**不是概率或百分比置信度**。当前状态结构为了统一 32 位导出而保存了 uint32 top_score，解释时须还原为 int32。

实时路径先读取稳定的特征、准备参考 RAM，再 begin 硬件图；ARM 在 NPU 运行时计算独立整数参考，随后 poll 完整图并逐项比较 10 个 logits。只有真实硬件输出用于显示。不能用软件预测代替硬件输出通过验证。

## 6. 帧序号和显示叠加

读 PRE.published_sequence，与上次序号差必须为 1；确定 bank `(seq-1)&1`。检查 last_pixels=921600，读取 frontend_cycles，失效并读取该 DDR bank，逐字节核对 MMIO 特征，再复查序号未改变。推理完成、参考一致且画面字形写完后写 ACK。

源输入在叠加前采集。绘制目标为前一个已完成的 RGB888 视频帧，字形从 (16,16) 开始，尺寸 40×56。选择帧时读取 VDMA park pointer；当前实现不锁住显示扫描，因此表达的是“最新预测叠加”，没有保证像素级同步到被分类的同一帧。

`npu_overlay_initialize` 将视频帧覆盖的 1 MiB section 配置为 NORM_NONCACHE，必须只在当前专用视频内存区调用，不能对混放缓存应用数据的区域调用。字形写入使用 32 位对齐 store，避免 RGB888 的逐字节开销。

## 7. 实时验收与证据

camera_rate 使用 ARM timer 对 128 个连续采集间隔计时；摄像头实际约 28.587 fps。程序要求至少 256 个连续实时帧，无跳号、特征竞争、参考不符、预处理/DDR/NPU 错误或 deadline miss。

`max_inference_us` 当前字段名沿用早期版本，实际包括特征读取、参考/硬件推理、结果比较和 overlay 写入，不能宣传为纯核执行时间。`max_end_to_end_us = ceil(frontend_cycles/100) + processing_us`，从 SOF 算到 overlay 写入完成，严格门限 34980 us；未包含屏幕扫描等待。ARM 发现发布至开始计时之间的少量轮询开销也应纳入评估边界。

`live_evidence.state`：0 未启动，1 测试中，2 满足持续帧数且所有门限通过，3 失败。为便于实际观察，单独的 deadline miss 会保持运行并更新显示，但 state3 和 miss 计数不会清掉；这不构成验收通过。真实 graph/参考/帧序号错误会保留证据并停止该测试循环，视频继续。

证据结构包含数据集测试数/正确数/logit 不符数、graph 错误、实时帧数/跳帧数、特征竞争、参考不符、deadline misses、最大耗时、最后序号/类别/分数、错误计数、10 类直方图、10 个 signed logits 及64 字节输入。XSCT 读结构前后核对帧计数，避免把非原子更新当成单个样本。数据集评分和真实摄像头识别需分别记录。

## 8. 故障定位

| 现象 | 优先检查 |
|---|---|
| ID 不对 | bitstream、XSA、MMIO 基址与 BSP 是否匹配 |
| 队列不动 | CONTROL.bit0、时钟复位、AXI 连接、当前任务错误 |
| CPU RAM 访问 abort | 是否仍 busy/queued、是否对齐 |
| DMA 配置错误 | DDR 对齐/范围、元素数、scratch 字单位、保留字段 |
| logits 偶发不符 | cache line 共享、flush/invalidate、bank 重用、权重布局 |
| 特征序号停止 | SOF/EOL/TREADY 三方实际连线、frame_errors、writer BRESP |
| overrun/跳号 | 推理/CPU 时间过长、消费者未 ACK、调试暂停 |
| HDMI 正常但预测不准 | 比较 8×8 输入、黑白极性、数字位置尺寸与训练域 |
| 所有输入都有某个预测 | 本模型始终 argmax，尚无“无数字”类别或拒识阈值 |
| state3 且只有 deadline 增长 | 真实延迟未达门限，不能作为完成证据 |

需要复位时先保留失败记录，禁止将超时后的 DMA 缓冲立即交给其他使用者。恢复后重新加载权重；scratch 复位不自动产生有效模型。
