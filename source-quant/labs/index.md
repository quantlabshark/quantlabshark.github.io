---
title: 交互实验
layout: quant-static
section: labs
description: 改变一个条件，观察结果。这里的价格是教学合成数据。
---
<nav class="fl-tags"><a href="#backtest">均线回测</a><a href="#drawdown">收益与回撤</a><a href="#split">时间序列验证</a></nav>
<section class="quant-lab" id="backtest">
<h2>01 · 均线、成交延迟与交易成本</h2>
<p>短均线高于长均线时持有，否则空仓。t 日收盘生成信号，t+1 日收盘调仓，从 t+1 到 t+2 的收益才归新持仓。仅做多，不使用杠杆。</p>
<form id="backtest-form" class="quant-controls"><label>短均线窗口<input name="fast" type="number" value="10" min="2" max="100" required></label><label>长均线窗口<input name="slow" type="number" value="40" min="3" max="200" required></label><label>单边成本（基点）<input name="cost" type="number" value="5" min="0" max="100" step="1" required></label><button class="button" type="submit">运行实验</button></form>
<p id="backtest-error" class="quant-error" role="alert"></p><svg id="backtest-chart" class="quant-chart" viewBox="0 0 800 280" role="img" aria-label="策略与未扣费持有基准的净值曲线"></svg><p class="quant-note">绿线：扣费策略；蓝线：未扣费持有基准。基准没有交易费用，两者费用口径不同。</p><div id="backtest-metrics" class="quant-metrics" aria-live="polite"></div>
<p class="quant-note">固定种子 42，504 个工作日价格点；工作日不等于交易所日历。成本按单边成交额比例扣除；期末强制平仓并计费。年化按 252 个收益区间估算，现金收益率为零。这个单一样本仅用于演示，不用于挑选最优策略。</p><a class="text-link" href="/downloads/synthetic-prices.csv" download>下载合成价格 CSV ↓</a> · <a class="text-link" href="/downloads/backtest.py" download>下载同口径 Python 示例 ↓</a>
</section>
<section class="quant-lab" id="drawdown"><h2>02 · 复利收益与最大回撤</h2><p>按顺序输入每期收益率（百分数），用逗号分隔。回撤始终与当时已达到的净值高点比较，包含初始净值 1。</p><form id="drawdown-form"><div class="quant-controls"><label style="width:100%">每期收益率<textarea name="returns" required>10, -10, 5, -20, 15, 8</textarea></label></div><button class="button" type="submit">计算收益与回撤</button></form><p id="drawdown-error" class="quant-error" role="alert"></p><div id="drawdown-metrics" class="quant-metrics" aria-live="polite"></div></section>
<section class="quant-lab" id="split"><h2>03 · 留出时间，而不是打乱时间</h2><p>按先后顺序划分训练集和测试集，并在中间留出间隔。若预测目标使用未来 H 期数据，训练标签覆盖区间也必须与测试区间隔离；仅按行分割还不够。</p><form id="split-form" class="quant-controls"><label>训练样本数<input name="train" type="number" value="300" min="20" max="460" required></label><label>间隔样本数<input name="gap" type="number" value="5" min="0" max="100" required></label><button class="button" type="submit">查看划分</button></form><p id="split-error" class="quant-error" role="alert"></p><div id="split-result" aria-live="polite"></div><p class="quant-note">示意图总计 504 个样本。标准化、缺失值填充和特征选择都应只在训练数据上拟合。测试结果用于评价已冻结的方案。</p></section>
<script src="/assets/quant-labs.js" defer></script>
