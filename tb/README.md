# RTL 回归

从仓库根目录运行：

```powershell
& C:/Xilinx/Vivado/2020.2/bin/vivado.bat -mode batch -source tb/run.tcl
```

可用 `-tclargs compute dma` 只运行指定用例。每个测试独立创建 `build/test_*`，检查日志 PASS 标记并拒绝 Fatal/Error；最终结果以实际运行日志为准。

| test | 验证重点 |
|---|---|
| compute | 卷积/ReLU/池化，bias、融合、shift、饱和、INT32 回绕、padding/stride/多通道，256维度边界与非法描述符 |
| dma | raw/packed 双向、tail strobe、4KiB边界、通道背压、范围与 RRESP/BRESP/RLAST 恢复 |
| v2 | AXI Lite、排队、RAM互斥，DDR load→ReLU→DDR store，高位非法字段 |
| preprocess | 小尺寸逐像素面积平均、反相、双 bank 与异常帧 |
| preprocess_hd | 完整1280×720输入，每个像素都参与预处理 |
| feature_writer | 特征打包、双 DDR 槽和响应后发布 |
| video_ddr | 两个完整720p帧，经预处理后写入 DDR，逐字节及发布顺序验证 |

这些仿真不能代替综合后的时序、实际 DDR/cache 或摄像头/HDMI 板上检查。
