"""Teaching synthetic-data backtest. Run beside synthetic-prices.csv. No dependencies."""
import csv
from pathlib import Path

def backtest(prices, fast=10, slow=40, cost_bps=5):
    assert 2 <= fast < slow <= len(prices)
    assert 0 <= cost_bps <= 100
    signals = [0 if i < slow - 1 else int(
        sum(prices[i-fast+1:i+1])/fast > sum(prices[i-slow+1:i+1])/slow
    ) for i in range(len(prices))]
    equity, holding, turnover = 1.0, 0, 0
    curve = [equity]
    for i in range(1, len(prices)):
        equity *= 1 + holding * (prices[i]/prices[i-1] - 1)
        target = 0 if i == len(prices)-1 else signals[i-1]
        change = abs(target-holding)
        equity *= 1 - change * cost_bps/10000
        turnover += change
        holding = target
        curve.append(equity)
    peak, drawdown = 1.0, 0.0
    for value in curve:
        peak = max(peak, value)
        drawdown = min(drawdown, value/peak-1)
    return dict(total=equity-1, annual=equity**(252/(len(prices)-1))-1,
                drawdown=drawdown, turnover=turnover, curve=curve)

if __name__ == '__main__':
    with Path(__file__).with_name('synthetic-prices.csv').open() as f:
        prices = [float(row['close']) for row in csv.DictReader(f)]
    result = backtest(prices)
    for key in ['total', 'annual', 'drawdown', 'turnover']:
        print(key, result[key])
    print('Synthetic data only; signal at t close, execution at t+1 close.')
