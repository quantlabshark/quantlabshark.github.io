"""Fetch your own daily data over HTTPS. Requires environment variable TUSHARE_TOKEN."""
import csv
import json
import os
import urllib.request
from pathlib import Path

token = os.environ.get('TUSHARE_TOKEN')
if not token:
    raise SystemExit('Set TUSHARE_TOKEN in your local environment before running.')
request_body = dict(api_name='daily', token=token,
                    params=dict(ts_code='000001.SZ', start_date='20260101', end_date='20261016'),
                    fields='ts_code,trade_date,open,high,low,close,pre_close,pct_chg,vol,amount')
request = urllib.request.Request('https://api.tushare.pro', json.dumps(request_body).encode(),
                                 {'Content-Type': 'application/json'})
with urllib.request.urlopen(request, timeout=30) as response:
    result = json.load(response)
if result.get('code') != 0:
    raise SystemExit('API error %s: %s' % (result.get('code'), result.get('msg')))
data = result['data']
rows = sorted(data['items'], key=lambda row: row[1])
with Path('daily-unadjusted.csv').open('w', newline='', encoding='utf-8') as handle:
    writer = csv.writer(handle)
    writer.writerow(data['fields'])
    writer.writerows(rows)
print('Saved', len(rows), 'unadjusted daily rows to daily-unadjusted.csv')
