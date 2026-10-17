"""Fetch a local teaching sample with an environment token. Never publishes data."""
import argparse, csv, json, os, urllib.request
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def token():
    value = os.environ.get('TUSHARE_TOKEN')
    if not value and (ROOT / '.env').exists():
        for line in (ROOT / '.env').read_text().splitlines():
            if line.startswith('TUSHARE_TOKEN='):
                value = line.split('=', 1)[1].strip()
    if not value:
        raise SystemExit('Set TUSHARE_TOKEN in the environment or ignored local .env.')
    return value

def fetch(api, params, fields):
    body = json.dumps(dict(api_name=api, token=token(), params=params, fields=fields)).encode()
    req = urllib.request.Request('https://api.tushare.pro', body, {'Content-Type':'application/json'})
    with urllib.request.urlopen(req, timeout=30) as response:
        data = json.load(response)
    if data.get('code') != 0:
        raise SystemExit('Tushare error ' + str(data.get('code')) + ': ' + str(data.get('msg')))
    return data['data']

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--code', default='000001.SZ')
    p.add_argument('--start', default='20260101')
    p.add_argument('--end', default='20261016')
    args = p.parse_args()
    data = fetch('daily',dict(ts_code=args.code,start_date=args.start,end_date=args.end), 'ts_code,trade_date,open,high,low,close,pre_close,pct_chg,vol,amount')
    rows = sorted(data['items'],key=lambda x:x[1])
    out = ROOT/'.quantlab-work'/'market-data';out.mkdir(parents=True,exist_ok=True)
    dest = out/(args.code+'.csv')
    with dest.open('w',newline='',encoding='utf-8') as f:
        w=csv.writer(f);w.writerow(data['fields']);w.writerows(rows)
    print(json.dumps(dict(api='daily',rows=len(rows),first=rows[0][1] if rows else None,last=rows[-1][1] if rows else None,path=str(dest),adjustment='unadjusted'),ensure_ascii=False))
