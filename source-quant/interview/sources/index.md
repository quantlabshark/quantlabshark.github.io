---
title: 资料来源与覆盖清单
layout: page
description: 教材章节、原始文件与网站阅读单元的对应关系。
---

# 资料来源与覆盖清单

## 整理范围

Xinfeng Zhou 教材按原书 7 章整理为 33 个阅读单元，对应所提供 PDF 的全部 96 页。QuantMaterial 的 93 个文件和压缩包内 4 个独有文件已逐项登记，正文整理为 67 个阅读单元。重复文件合并到同一篇题解。

[经典教材目录](/interview/zhou/) · [笔面试资料目录](/interview/practice/) · [下载完整覆盖记录](/assets/source-coverage.json)

## 教材章节

| 章节 | 阅读单元 | PDF 页码 |
|---|---|---|
| 1 | [1 一般原则](/read/?slug=zhou-full-1) | 1–2 |
| 2.1 | [2.1 问题简化](/read/?slug=zhou-full-2-1) | 2–3 |
| 2.2 | [2.2 逻辑推理](/read/?slug=zhou-full-2-2) | 3–6 |
| 2.3 | [2.3 转换问题表示](/read/?slug=zhou-full-2-3) | 6–8 |
| 2.4 | [2.4 对称性](/read/?slug=zhou-full-2-4) | 8–9 |
| 2.5 | [2.5 数列求和](/read/?slug=zhou-full-2-5) | 9–11 |
| 2.6 | [2.6 抽屉原理](/read/?slug=zhou-full-2-6) | 11–12 |
| 2.7 | [2.7 模运算](/read/?slug=zhou-full-2-7) | 12–14 |
| 2.8 | [2.8 数学归纳法](/read/?slug=zhou-full-2-8) | 14–16 |
| 2.9 | [2.9 反证法](/read/?slug=zhou-full-2-9) | 16–17 |
| 3.1 | [3.1 极限与导数](/read/?slug=zhou-full-3-1) | 17–19 |
| 3.2 | [3.2 积分](/read/?slug=zhou-full-3-2) | 19–21 |
| 3.3 | [3.3 偏导数与重积分](/read/?slug=zhou-full-3-3) | 21–21 |
| 3.4 | [3.4 微积分方法](/read/?slug=zhou-full-3-4) | 21–24 |
| 3.5 | [3.5 常微分方程](/read/?slug=zhou-full-3-5) | 24–26 |
| 3.6 | [3.6 线性代数](/read/?slug=zhou-full-3-6) | 26–30 |
| 4.1 | [4.1 概率定义与集合运算](/read/?slug=zhou-full-4-1) | 30–33 |
| 4.2 | [4.2 组合分析](/read/?slug=zhou-full-4-2) | 33–37 |
| 4.3 | [4.3 条件概率与贝叶斯公式](/read/?slug=zhou-full-4-3) | 37–44 |
| 4.4 | [4.4 离散分布与连续分布](/read/?slug=zhou-full-4-4) | 44–47 |
| 4.5 | [4.5 期望、方差与协方差](/read/?slug=zhou-full-4-5) | 47–50 |
| 4.6 | [4.6 顺序统计量](/read/?slug=zhou-full-4-6) | 50–52 |
| 5.1 | [马尔可夫链](/read/?slug=zhou-05-01) | 53–58 |
| 5.2 | [鞅与随机游走](/read/?slug=zhou-05-02) | 58–61 |
| 5.3 | [动态规划](/read/?slug=zhou-05-03) | 61–65 |
| 5.4 | [布朗运动与随机微积分](/read/?slug=zhou-05-04) | 65–69 |
| 6.1 | [期权定价](/read/?slug=zhou-06-01) | 69–75 |
| 6.2 | [期权风险敏感度](/read/?slug=zhou-06-02) | 75–80 |
| 6.3 | [期权组合与奇异期权](/read/?slug=zhou-06-03) | 80–82 |
| 6.4 | [组合、风险与固定收益](/read/?slug=zhou-06-04) | 82–85 |
| 7.1 | [算法与复杂度](/read/?slug=zhou-07-01) | 86–92 |
| 7.2 | [二进制与概率编码](/read/?slug=zhou-07-02) | 92–92 |
| 7.3 | [蒙特卡洛与有限差分](/read/?slug=zhou-07-03) | 93–96 |

## 数据与代码

| 配套包 | 内容 |
|---|---|
| [伯兄特征分析包，约 66.3 MB](/assets/downloads/quant-material/features-analysis.zip) | 原始数值表、时间划分与模型脚本、实测结果 |
| [顽岩数据分析包，约 8.8 MB](/assets/downloads/quant-material/wanyan-analysis.zip) | 去姓名交易表、行情与热度数据、计算结果、复现脚本 |
| [Assignment 支持文件](/assets/downloads/quant-material/assignment-support.zip) | 合约清单及原 MATLAB 读取函数；原始 Tick 行情未包含在资料中 |

## 原文件对应表

表内路径相对于 QuantMaterial；`!` 表示压缩包内文件。

| 原文件 | 处理方式 | 对应内容 |
|---|---|---|
| `xhs量化面经整理汇总/Assignment/Assignment/ContractList.csv` | 配套附件 | [五日 Tick 数据编程任务](/read/?slug=material-015) |
| `xhs量化面经整理汇总/Assignment/Assignment/Functions/FilterStructure.m` | 配套附件 | [五日 Tick 数据编程任务](/read/?slug=material-015) |
| `xhs量化面经整理汇总/Assignment/Assignment/Functions/LoadMarketData.m` | 配套附件 | [五日 Tick 数据编程任务](/read/?slug=material-015) |
| `xhs量化面经整理汇总/Assignment/Assignment/Functions/ReadCSV.m` | 配套附件 | [五日 Tick 数据编程任务](/read/?slug=material-015) |
| `xhs量化面经整理汇总/Assignment/Assignment/Question.docx` | 已整理 | [五日 Tick 数据编程任务](/read/?slug=material-015) |
| `xhs量化面经整理汇总/【quant-校招】笔试题202209/features.csv` | 配套附件 | [电梯等待与时序信号筛选](/read/?slug=material-051) |
| `xhs量化面经整理汇总/【quant-校招】笔试题202209/伯兄quant校招生机试题.txt` | 已整理 | [电梯等待与时序信号筛选](/read/?slug=material-051) |
| `xhs量化面经整理汇总/【quant-校招】笔试题202209 2/features.csv` | 重复合并 | [电梯等待与时序信号筛选](/read/?slug=material-051) |
| `xhs量化面经整理汇总/【quant-校招】笔试题202209 2/伯兄quant校招生机试题.txt` | 重复合并 | [电梯等待与时序信号筛选](/read/?slug=material-051) |
| `xhs量化面经整理汇总/上海念空私募基金管理合伙企业（有限合伙）线上笔试题目.pdf` | 已整理 | [滚动因子处理与随机收益](/read/?slug=material-047) |
| `xhs量化面经整理汇总/世纪前沿.docx` | 已整理 | [递推、区间匹配与质数操作](/read/?slug=material-036) |
| `xhs量化面经整理汇总/中量投.docx` | 已整理 | [概率、回归与序列问题](/read/?slug=material-021) |
| `xhs量化面经整理汇总/丰盛.docx` | 已整理 | [回归与随机等待](/read/?slug=material-023) |
| `xhs量化面经整理汇总/九坤.docx` | 已整理 | [概率递推、组合优化与研究设计](/read/?slug=material-037) |
| `xhs量化面经整理汇总/九坤2.docx` | 已整理 | [九坤笔试回忆：排列、等待时间与状态压缩](/read/?slug=material-jiukun-2) |
| `xhs量化面经整理汇总/乾象.docx` | 已整理 | [杠杆与随机排列](/read/?slug=material-011) |
| `xhs量化面经整理汇总/仲阳天王星.docx` | 已整理 | [系统基础与推理](/read/?slug=material-010) |
| `xhs量化面经整理汇总/伯兄投资.zip` | 重复合并 | [电梯等待与时序信号筛选](/read/?slug=material-051) |
| `xhs量化面经整理汇总/佳期.docx` | 已整理 | [贝叶斯、相关结构与计算性能](/read/?slug=material-024) |
| `xhs量化面经整理汇总/佳期.pdf` | 已整理 | [随机图、计算机基础与并行配送](/read/?slug=material-045) |
| `xhs量化面经整理汇总/信弘天禾.docx` | 已整理 | [损失函数与时序模型](/read/?slug=material-001) |
| `xhs量化面经整理汇总/凯读.docx` | 已整理 | [固定内存的时间加权移动平均](/read/?slug=material-049) |
| `xhs量化面经整理汇总/凯读2.pdf` | 已整理 | [行业暴露估计与潜变量识别](/read/?slug=material-050) |
| `xhs量化面经整理汇总/华均广汇.docx` | 已整理 | [华均广汇：图计数、最大子数组与数据合并](/read/?slug=material-huajun) |
| `xhs量化面经整理汇总/卓胜.docx` | 已整理 | [数值推理与收益概率](/read/?slug=material-020) |
| `xhs量化面经整理汇总/卓识投资.docx` | 已整理 | [卓识投资：前沿筛选、随机序列与组合计数](/read/?slug=material-zhuoshi) |
| `xhs量化面经整理汇总/卡方.pdf` | 已整理 | [相关结构、停止策略与算法](/read/?slug=material-033) |
| `xhs量化面经整理汇总/启林.docx` | 已整理 | [混频预测与模型基础](/read/?slug=material-025) |
| `xhs量化面经整理汇总/喜岳投资.docx` | 已整理 | [数组操作、统计选择题与编程](/read/?slug=material-048) |
| `xhs量化面经整理汇总/因诺.docx` | 已整理 | [市场结构与收益来源](/read/?slug=material-003) |
| `xhs量化面经整理汇总/大雁.pdf` | 已整理 | [条件概率与博弈决策](/read/?slug=material-030) |
| `xhs量化面经整理汇总/天演.docx` | 已整理 | [三份持仓记录核对](/read/?slug=material-012) |
| `xhs量化面经整理汇总/孝庸基金.docx` | 已整理 | [集合撮合、素数子串与坦克模拟](/read/?slug=material-054) |
| `xhs量化面经整理汇总/安贤.docx` | 已整理 | [正态分布、线性模型与数据结构](/read/?slug=material-043) |
| `xhs量化面经整理汇总/宽德.docx` | 已整理 | [抽样概率与比较算法](/read/?slug=material-019) |
| `xhs量化面经整理汇总/希格斯/微信图片_20210904223904.jpg` | 已整理 | [希格斯第一轮：分析、概率与矩阵](/read/?slug=material-higgs-first) |
| `xhs量化面经整理汇总/希格斯/微信图片_20210904223912.jpg` | 已整理 | [希格斯第二轮：构造、递推与不变量](/read/?slug=material-higgs-second) |
| `xhs量化面经整理汇总/希格斯.zip` | 重复合并 | [希格斯第一轮：分析、概率与矩阵](/read/?slug=material-higgs-first)、[希格斯第二轮：构造、递推与不变量](/read/?slug=material-higgs-second) |
| `xhs量化面经整理汇总/平方和.pdf` | 已整理 | [几何拼接与基础概率](/read/?slug=material-031) |
| `xhs量化面经整理汇总/幻方.docx` | 已整理 | [回归与随机游走](/read/?slug=material-027) |
| `xhs量化面经整理汇总/微观博易.jpg` | 已整理 | [微观博易：贪心算法、矩阵赋值与条件分布](/read/?slug=material-weiguan) |
| `xhs量化面经整理汇总/思晔.docx` | 已整理 | [市价委托与限价委托](/read/?slug=material-004) |
| `xhs量化面经整理汇总/投研面试题_v3.pdf` | 已整理 | [随机停止与研究讨论](/read/?slug=material-032) |
| `xhs量化面经整理汇总/明泓投资.docx` | 已整理 | [几何回归与程序基础](/read/?slug=material-009) |
| `xhs量化面经整理汇总/概率.docx` | 已整理 | [Tick 数据清洗与订单流分析](/read/?slug=material-013) |
| `xhs量化面经整理汇总/概率2.pdf` | 重复合并 | [Tick 数据清洗与订单流分析](/read/?slug=material-013) |
| `xhs量化面经整理汇总/正定.docx` | 已整理 | [停止时间与几何覆盖](/read/?slug=material-028) |
| `xhs量化面经整理汇总/洛书.docx` | 已整理 | [期权定价模型与假设](/read/?slug=material-007) |
| `xhs量化面经整理汇总/涵德.docx` | 重复合并 | [涵德：程序分析、组合风险与动态决策](/read/?slug=material-hande) |
| `xhs量化面经整理汇总/涵德.pdf` | 已整理 | [涵德：程序分析、组合风险与动态决策](/read/?slug=material-hande) |
| `xhs量化面经整理汇总/灵均.docx` | 已整理 | [贝叶斯与最优决策](/read/?slug=material-029) |
| `xhs量化面经整理汇总/灵均.zip` | 重复合并 | [灵均图像试题：概率、最优停止与动态规划](/read/?slug=material-lingjun-scans) |
| `xhs量化面经整理汇总/灵均笔试试题/iShot_2023-01-09_11.33.58.png` | 已整理 | [灵均图像试题：概率、最优停止与动态规划](/read/?slug=material-lingjun-scans) |
| `xhs量化面经整理汇总/灵均笔试试题/iShot_2023-01-09_11.34.14.png` | 已整理 | [灵均图像试题：概率、最优停止与动态规划](/read/?slug=material-lingjun-scans) |
| `xhs量化面经整理汇总/灵均笔试试题/iShot_2023-01-09_11.34.26.png` | 已整理 | [灵均图像试题：概率、最优停止与动态规划](/read/?slug=material-lingjun-scans) |
| `xhs量化面经整理汇总/灵均笔试试题/iShot_2023-01-09_11.34.31.png` | 已整理 | [灵均图像试题：概率、最优停止与动态规划](/read/?slug=material-lingjun-scans) |
| `xhs量化面经整理汇总/灵均笔试试题/iShot_2023-01-09_11.34.35.png` | 已整理 | [灵均图像试题：概率、最优停止与动态规划](/read/?slug=material-lingjun-scans) |
| `xhs量化面经整理汇总/灵均笔试试题/iShot_2023-01-09_11.34.42.png` | 已整理 | [灵均图像试题：概率、最优停止与动态规划](/read/?slug=material-lingjun-scans) |
| `xhs量化面经整理汇总/灵均笔试试题/iShot_2023-01-09_11.34.47.png` | 已整理 | [灵均图像试题：概率、最优停止与动态规划](/read/?slug=material-lingjun-scans) |
| `xhs量化面经整理汇总/灵均笔试试题/iShot_2023-01-09_11.34.56.png` | 已整理 | [灵均图像试题：概率、最优停止与动态规划](/read/?slug=material-lingjun-scans) |
| `xhs量化面经整理汇总/灵均笔试试题/iShot_2023-01-09_11.35.03.png` | 已整理 | [灵均图像试题：概率、最优停止与动态规划](/read/?slug=material-lingjun-scans) |
| `xhs量化面经整理汇总/灵均笔试试题/iShot_2023-01-09_11.35.17.png` | 已整理 | [灵均图像试题：概率、最优停止与动态规划](/read/?slug=material-lingjun-scans) |
| `xhs量化面经整理汇总/燧石.docx` | 已整理 | [量化研报复现流程](/read/?slug=material-006) |
| `xhs量化面经整理汇总/玄信.docx` | 已整理 | [矩阵约束与基础算法](/read/?slug=material-022) |
| `xhs量化面经整理汇总/白鹭.pdf` | 已整理 | [骰子、几何阻挡与概率算法](/read/?slug=material-046) |
| `xhs量化面经整理汇总/盛冠达.docx` | 已整理 | [字符统计与单次交易](/read/?slug=material-016) |
| `xhs量化面经整理汇总/稳博.docx` | 已整理 | [代数小数与序列模型](/read/?slug=material-017) |
| `xhs量化面经整理汇总/聚宽.docx` | 已整理 | [动态规划与量化研究判断](/read/?slug=material-041) |
| `xhs量化面经整理汇总/聚宽.pdf` | 重复合并 | [动态规划与量化研究判断](/read/?slug=material-041) |
| `xhs量化面经整理汇总/至诚卓远.pdf` | 已整理 | [最优停止、套利约束与吸收过程](/read/?slug=material-034) |
| `xhs量化面经整理汇总/致诚卓远.docx` | 重复合并 | [最优停止、套利约束与吸收过程](/read/?slug=material-034) |
| `xhs量化面经整理汇总/艾方.pdf` | 已整理 | [艾方：订单簿特征与波动率预测](/read/?slug=material-eff) |
| `xhs量化面经整理汇总/茂源.docx` | 已整理 | [期货配对交易与高频研究](/read/?slug=material-014) |
| `xhs量化面经整理汇总/蒙玺.docx` | 已整理 | [CTA 与多因子模型](/read/?slug=material-005) |
| `xhs量化面经整理汇总/蝶威.docx` | 已整理 | [模型选择与预测周期](/read/?slug=material-002) |
| `xhs量化面经整理汇总/衍复.docx` | 已整理 | [谱界、回归与组合计数](/read/?slug=material-026) |
| `xhs量化面经整理汇总/诚奇.docx` | 重复合并 | [几何概率、随机过程与顺序算法](/read/?slug=material-042) |
| `xhs量化面经整理汇总/赫富.docx` | 已整理 | [随机过程、交易算法与最优停止](/read/?slug=material-039) |
| `xhs量化面经整理汇总/超量子.docx` | 已整理 | [统计、因子与交易算法](/read/?slug=material-018) |
| `xhs量化面经整理汇总/通登 2.docx` | 已整理 | [几何体积、重掷策略与路径](/read/?slug=material-052) |
| `xhs量化面经整理汇总/通登.docx` | 已整理 | [概率、博弈与回归](/read/?slug=material-035) |
| `xhs量化面经整理汇总/锐天.docx` | 已整理 | [概率与线性代数选择题](/read/?slug=material-040) |
| `xhs量化面经整理汇总/集微.jpg` | 已整理 | [集微：递推策略、正则化与渐近估计](/read/?slug=material-jiwei) |
| `xhs量化面经整理汇总/靖奇.zip` | 重复合并 | [五日 Tick 数据编程任务](/read/?slug=material-015) |
| `xhs量化面经整理汇总/靖奇投资.docx` | 已整理 | [代数估计与最短路径](/read/?slug=material-038) |
| `xhs量化面经整理汇总/顽岩.zip` | 配套附件 | [交易数据分析与行情指标实作](/read/?slug=material-055) |
| `xhs量化面经整理汇总.zip` | 重复合并 | [滚动因子处理与随机收益](/read/?slug=material-047)、[递推、区间匹配与质数操作](/read/?slug=material-036)、[概率、回归与序列问题](/read/?slug=material-021)、[回归与随机等待](/read/?slug=material-023)、[概率递推、组合优化与研究设计](/read/?slug=material-037)、[九坤笔试回忆：排列、等待时间与状态压缩](/read/?slug=material-jiukun-2)、[杠杆与随机排列](/read/?slug=material-011)、[系统基础与推理](/read/?slug=material-010)、[电梯等待与时序信号筛选](/read/?slug=material-051)、[贝叶斯、相关结构与计算性能](/read/?slug=material-024)、[随机图、计算机基础与并行配送](/read/?slug=material-045)、[损失函数与时序模型](/read/?slug=material-001)、[固定内存的时间加权移动平均](/read/?slug=material-049)、[行业暴露估计与潜变量识别](/read/?slug=material-050)、[华均广汇：图计数、最大子数组与数据合并](/read/?slug=material-huajun)、[数值推理与收益概率](/read/?slug=material-020)、[卓识投资：前沿筛选、随机序列与组合计数](/read/?slug=material-zhuoshi)、[相关结构、停止策略与算法](/read/?slug=material-033)、[混频预测与模型基础](/read/?slug=material-025)、[数组操作、统计选择题与编程](/read/?slug=material-048)、[市场结构与收益来源](/read/?slug=material-003)、[条件概率与博弈决策](/read/?slug=material-030)、[三份持仓记录核对](/read/?slug=material-012)、[集合撮合、素数子串与坦克模拟](/read/?slug=material-054)、[正态分布、线性模型与数据结构](/read/?slug=material-043)、[抽样概率与比较算法](/read/?slug=material-019)、[希格斯第一轮：分析、概率与矩阵](/read/?slug=material-higgs-first)、[希格斯第二轮：构造、递推与不变量](/read/?slug=material-higgs-second)、[几何拼接与基础概率](/read/?slug=material-031)、[回归与随机游走](/read/?slug=material-027)、[微观博易：贪心算法、矩阵赋值与条件分布](/read/?slug=material-weiguan)、[市价委托与限价委托](/read/?slug=material-004)、[随机停止与研究讨论](/read/?slug=material-032)、[几何回归与程序基础](/read/?slug=material-009)、[Tick 数据清洗与订单流分析](/read/?slug=material-013)、[停止时间与几何覆盖](/read/?slug=material-028)、[期权定价模型与假设](/read/?slug=material-007)、[涵德：程序分析、组合风险与动态决策](/read/?slug=material-hande)、[贝叶斯与最优决策](/read/?slug=material-029)、[灵均图像试题：概率、最优停止与动态规划](/read/?slug=material-lingjun-scans)、[量化研报复现流程](/read/?slug=material-006)、[矩阵约束与基础算法](/read/?slug=material-022)、[骰子、几何阻挡与概率算法](/read/?slug=material-046)、[字符统计与单次交易](/read/?slug=material-016)、[代数小数与序列模型](/read/?slug=material-017)、[动态规划与量化研究判断](/read/?slug=material-041)、[最优停止、套利约束与吸收过程](/read/?slug=material-034)、[艾方：订单簿特征与波动率预测](/read/?slug=material-eff)、[期货配对交易与高频研究](/read/?slug=material-014)、[CTA 与多因子模型](/read/?slug=material-005)、[模型选择与预测周期](/read/?slug=material-002)、[谱界、回归与组合计数](/read/?slug=material-026)、[几何概率、随机过程与顺序算法](/read/?slug=material-042)、[随机过程、交易算法与最优停止](/read/?slug=material-039)、[统计、因子与交易算法](/read/?slug=material-018)、[几何体积、重掷策略与路径](/read/?slug=material-052)、[概率、博弈与回归](/read/?slug=material-035)、[概率与线性代数选择题](/read/?slug=material-040)、[集微：递推策略、正则化与渐近估计](/read/?slug=material-jiwei)、[五日 Tick 数据编程任务](/read/?slug=material-015)、[代数估计与最短路径](/read/?slug=material-038)、[交易数据分析与行情指标实作](/read/?slug=material-055) |
| `笔试面试回忆/念空面试回忆.docx` | 已整理 | [量化研究流程与项目讨论](/read/?slug=material-008) |
| `笔试面试回忆/托特投资笔试回忆.docx` | 已整理 | [Python、概率与算法题目回忆](/read/?slug=material-044) |
| `笔试面试回忆/诚奇笔试.docx` | 已整理 | [几何概率、随机过程与顺序算法](/read/?slug=material-042) |
| `笔试面试回忆/通登笔试.docx` | 已整理 | [语言推理、运动与几何](/read/?slug=material-053) |
| `笔试面试回忆(1).zip` | 重复合并 | [量化研究流程与项目讨论](/read/?slug=material-008)、[Python、概率与算法题目回忆](/read/?slug=material-044)、[几何概率、随机过程与顺序算法](/read/?slug=material-042)、[语言推理、运动与几何](/read/?slug=material-053) |
| `资本面学习资料.pdf` | 已整理 | [资本市场术语与研究指标](/read/?slug=material-capital-concepts)、[资本市场阅读与音视频资料索引](/read/?slug=material-capital-reading) |
| `xhs量化面经整理汇总/顽岩.zip!/量化研究实习岗笔试题（2.5h）.docx` | 已整理 | [交易数据分析与行情指标实作](/read/?slug=material-055) |
| `xhs量化面经整理汇总/顽岩.zip!/热门股票.csv` | 配套附件 | [交易数据分析与行情指标实作](/read/?slug=material-055) |
| `xhs量化面经整理汇总/顽岩.zip!/stock_price.csv` | 配套附件 | [交易数据分析与行情指标实作](/read/?slug=material-055) |
| `xhs量化面经整理汇总/顽岩.zip!/transaction.xlsx` | 配套附件 | [交易数据分析与行情指标实作](/read/?slug=material-055) |

## 原资料中的缺项与歧义

部分面试回忆只记录了题名或结论，部分数据题缺少所引用的数据。这些位置保留原条件，并说明可计算的结果、所需补充信息或尚缺的证明。

| 原资料 | 缺项或歧义 | 整理方式 |
|---|---|---|
| [燧石.docx](/read/?slug=material-006) | 仅有研报系列名，缺具体报告、模型公式及数据版本 | 提供逐阶段复现流程，无唯一实验数值 |
| [概率.docx/概率2.pdf](/read/?slug=material-013) | 三日0.csv、1.csv、2.csv及字段说明图未包含于目录 | 完整十项方法与可识别性分析，未填造行情统计 |
| [茂源.docx](/read/?slug=material-014) | 各历史原油/PTA/十品种Tick数据、汇率与主力表不在目录；3.5%%费率含义不清 | 保留原时间、数值、成本与任务；明确参数口径和所需输入 |
| [Assignment/Question.docx](/read/?slug=material-015) | 五天Tick行情本体；目录只有ContractList与读取函数 | 算法、账本格式及附件链接，真实排名与PNL待数据 |
| [通登.docx](/read/?slug=material-035) | 顺序选数中丙的最优反应并列规则 | 给最坏反应下75/76，并解释74在不同反应下结果 |
| [世纪前沿.docx](/read/?slug=material-036) | 质数操作目标误写为“全部已有” | 明确按全部相同解释并求解 |
| [九坤.docx](/read/?slug=material-037) | 篮球比赛回合数与平局规则；专家预测共同任务及收费条件 | 给参数化概率及条件比较，不定唯一赢家 |
| [托特投资笔试回忆.docx](/read/?slug=material-044) | 第6/7概率题全题缺失；翻牌打破成环、白魔法师仅题名；股票/约瑟夫II/滑雪版本条件缺失 | 缺题保留缺项；可识别常见版本明确标注条件并给算法 |
| [佳期.pdf](/read/?slug=material-045) | 圆环游走起点未写明 | 按零点起步得1/100，并说明起点为50时为零 |
| [白鹭.pdf](/read/?slug=material-046) | 三只乌龟不能捕获的完整下界证明；连续子数组与一般子序列用词冲突 | 证明四只足够且保留未证下界；按原前缀和意图解释连续子数组 |
| [上海念空线上笔试.pdf](/read/?slug=material-047) | factorA.csv/factorB.csv未包含于目录；贝叶斯题未指定先验 | 给可运行数据处理与合成检验；先验用Beta(a,b)及均匀特例 |
| [喜岳投资.docx](/read/?slug=material-048) | SQL表结构及筛选条件；打印K的尺寸和样例 | SQL说明缺项；K给明确参数化布局 |
| [凯读2.pdf](/read/?slug=material-050) | 未知行业收益时未提供保证识别的锚点或约束 | 可运行反例证明原条件不能保证唯一反推，并列出可补条件 |
| [伯兄quant校招生机试题.txt](/read/?slug=material-051) | 电梯起始/回程/停站细则，features无时间戳或信号定义，N未指定 | 明确电梯模型并独立枚举验证；按连续行序作时间切分且报告候选网格结果 |
| [通登 2.docx](/read/?slug=material-052) | 几何图形分支、键盘跨越中间点规则不完整 | 保留可见边长2/3/1，按凸四边形及任意端点连线假设求解 |
| [通登笔试.docx](/read/?slug=material-053) | 最后一题递归程序页未附；0至6的均匀分布未写明连续/离散 | 程序输出不能恢复；均匀题两种解释均完整计算 |
| [顽岩ZIP题面](/read/?slug=material-055) | Hot Rate、corr1/corr2及账户存续时间未定义 | 给明确定义并实跑全部附件，日期2018-02-29保留缺失 |
| [涵德.docx/涵德.pdf](/read/?slug=material-hande) | 25马取前5的全局最少场次证明未由当前资料提供 | 父任务给9场构造上界，不称已证最少 |
