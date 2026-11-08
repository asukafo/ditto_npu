# 训练与量化

运行 `python train_quantize.py`。依赖 Python3、NumPy、scikit-learn；数据使用 sklearn 内置 UCI optical digits，无需联网下载。训练随机种子 20261108，先固定隔离测试集，再从余下数据分出验证集。测试集只用于最终评分。

脚本包含 NumPy 前向、反向传播、优化、固定 shift 的整数参考和 C 头文件导出。模型输入为 8×8 单通道，训练归一化到 0..1，硬件整数输入到 0..112；标签为 0..9。当前不是 MNIST，也没有“无数字”类别。

| 文件 | 内容 |
|---|---|
| train_quantize.py | 训练、评估、导出入口 |
| digits_float.npz | 浮点模型参数 |
| digits_int8.npz | 整数权重、INT32 bias 和 shift |
| digits_test_vectors.npz | 隔离测试输入、标签、期望 logits |
| digits_model.h | 裸机使用的常量和测试向量，数组按64字节对齐 |
| training_report.json | 数据集、划分、种子、评分和数据 SHA256 |
| training_history.json | 每轮训练/验证记录 |

已训练模型的浮点测试准确率 96.67%，整数模型 349/360=96.94%。不要将它表述为摄像头实景准确率。真实纸面输入应为白底黑字、单个居中数字；面积平均不会自动检测、裁剪或居中数字。新模型部署后必须重新比较 RTL/CPU 的完整 logits，并执行独立测试与实时验证。

数据来源说明：[scikit-learn load_digits](https://scikit-learn.org/stable/modules/generated/sklearn.datasets.load_digits.html)，其中附有原始 UCI optical handwritten digits 数据集说明和引用。
