# ditto_npu

基于 XC7Z020 的可配置 INT8 NPU，连接 OV5640 1280×720 摄像头和 HDMI。支持卷积、融合 ReLU、独立 ReLU、最大池化、DDR DMA、描述符队列和完整数字分类模型调度。

**当前代码持续同步中，功能验收尚未全部完成。** 最终实时与实景识别结果见[验证报告](docs/VALIDATION.md)；早期 25 MHz 候选的严格延迟未达标，不能把它作为完成版本。

| 目录 | 内容 |
|---|---|
| rtl/ | 自研 NPU、DMA、视频特征处理 RTL |
| tb/ | 算子、AXI、DMA、全帧预处理和集成 testbench |
| sw_driver/ | 裸机驱动、图调度、参考模型、实时程序与视频应用 |
| sw_train/ | NumPy 训练/量化、已训练参数和测试向量 |
| fpg/ | FPGA 工程重建脚本、约束、视频 IP、部署产物和证据 |
| docs/ | 详细架构、驱动接口与验证记录 |

详见 [架构文档](docs/NPU_ARCHITECTURE.md)、[驱动文档](docs/SW_DRIVER.md) 和 [训练说明](sw_train/README.md)。完整工程需要 Vivado/Vitis 2020.2、相应器件支持和可用的 JTAG 驱动。
