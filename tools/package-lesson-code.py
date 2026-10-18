"""Package and execute the Python examples in an ignored editorial JSON payload."""
from pathlib import Path
import argparse,ast,hashlib,importlib.metadata,json,os,re,subprocess,sys,zipfile

ROOT=Path(__file__).resolve().parents[1]
THIRD_PARTY={'numpy':'numpy','pandas':'pandas','scipy':'scipy','sklearn':'scikit-learn','matplotlib':'matplotlib'}
GROUPS={
    'quant-course-':('courses','quant-curriculum-examples.zip','系统学习'),
    'factor-book-':('factor-investing','factor-investing-examples.zip','因子投资'),
    'harris-book-':('trading-and-exchanges','trading-and-exchanges-examples.zip','市场微观结构'),
}

def write_zip(target,files):
    target.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for name,data in sorted(files.items()):
            info=zipfile.ZipInfo(name,(2026,10,17,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
            z.writestr(info,data.encode('utf8') if isinstance(data,str) else data)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('payload');ap.add_argument('--output',required=True);args=ap.parse_args()
    rows=json.loads(Path(args.payload).read_text('utf8'));work=ROOT/'.quantlab-work/release/code';work.mkdir(parents=True,exist_ok=True)
    results=[];aggregate={k:{'files':{},'items':[]} for k in GROUPS}
    for row in rows:
        blocks=re.findall(r'```(?:python|py)\s*\n(.*?)```',row['body'],re.S)
        if not blocks:continue
        prefix=next((k for k in GROUPS if row['slug'].startswith(k)),None)
        if prefix is None:continue
        folder,aggregate_name,series=GROUPS[prefix];slug=row['slug'];title=row['title'];dest=work/slug;dest.mkdir(exist_ok=True)
        code='# -*- coding: utf-8 -*-\n'+f'# {title}\n# 教学数据在代码中给定；按正文顺序运行全部例子。\n\n'+'\n\n'.join(f'# 示例 {i}\n{b.rstrip()}' for i,b in enumerate(blocks,1))+'\n'
        modules=set()
        for n in ast.walk(ast.parse(code)):
            if isinstance(n,ast.Import):modules.update(a.name.split('.')[0] for a in n.names)
            if isinstance(n,ast.ImportFrom) and n.module:modules.add(n.module.split('.')[0])
        unknown=modules-set(sys.stdlib_module_names)-set(THIRD_PARTY)
        if unknown:raise RuntimeError(f'{slug}: unrecognized dependencies {unknown}')
        dependencies={THIRD_PARTY[m]:importlib.metadata.version(THIRD_PARTY[m]) for m in sorted(modules&set(THIRD_PARTY))}
        script=dest/'example.py';script.write_text(code,'utf8')
        env={**os.environ,'MPLBACKEND':'Agg','PYTHONHASHSEED':'0','PYTHONIOENCODING':'utf-8'}
        run=subprocess.run([sys.executable,'-X','utf8',str(script)],cwd=dest,env=env,text=True,encoding='utf8',capture_output=True,timeout=60)
        if run.returncode:raise RuntimeError(f'{slug}: exit {run.returncode}\n{run.stderr}')
        generated={p.relative_to(dest).as_posix():p.read_bytes() for p in dest.rglob('*') if p.is_file() and p.name not in ('example.py','README.md','requirements.txt','expected-output.txt') and '__pycache__' not in p.parts}
        requirement='\n'.join(f'{name}=={version}' for name,version in dependencies.items())+'\n' if dependencies else '# 本节仅使用 Python 标准库，无需安装第三方包。\n'
        output=run.stdout.replace('\r\n','\n')
        instructions=f'''# {title}

解压后，在此文件夹打开终端，运行：

```text
python -m pip install -r requirements.txt
python example.py
```

`example.py` 按正文顺序包含本节的 {len(blocks)} 段 Python 示例。代码中的价格、收益和参数均为课内教学数据，无需行情账号。

`expected-output.txt` 保存实际运行得到的终端输出，可逐项与运行结果比较。涉及随机模拟的例子在代码中固定种子；浮点数末位可能随计算环境略有差异。

验证环境：Python {sys.version.split()[0]}。第三方依赖版本见 `requirements.txt`；仅使用标准库的课程可以直接运行第二条命令。

课程地址：https://quantlabshark.github.io/read/?slug={slug}
'''
        if generated:instructions+='\n代码运行时还会生成：'+ '、'.join(f'`{name}`' for name in generated)+'。本包 `expected-files` 目录保留了验证时生成的文件。\n'
        files={'example.py':code,'README.md':instructions,'requirements.txt':requirement,'expected-output.txt':output}
        files.update({'expected-files/'+name:data for name,data in generated.items()})
        archive=ROOT/f'source-quant/assets/downloads/{folder}/{slug}.zip';write_zip(archive,files)
        for name,data in files.items():
            if not name.startswith('expected-files/'):(dest/name).write_text(data,'utf8')
        url=f'/assets/downloads/{folder}/{slug}.zip'
        row['body']=re.sub(r'\n## 配套代码\n[\s\S]*$','',row['body']).rstrip()+f'\n\n## 配套代码\n\n[下载本节代码（ZIP）]({url})\n\n压缩包包含脚本、运行说明、依赖清单和预期输出。解压后运行 `example.py`，即可复现本节计算。\n'
        row.setdefault('metadata',{})['code_download']={'url':url,'examples':len(blocks)}
        result={'slug':slug,'title':title,'examples':len(blocks),'dependencies':dependencies,'exit_code':run.returncode,'stdout':output,'stderr':run.stderr,'generated_files':list(generated),'url':url,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest()}
        results.append(result)
        group=aggregate[prefix];group['items'].append({k:result[k] for k in ['slug','title','examples','url']})
        # Retain the established flat .py files in aggregate archives.
        group['files'][slug+'.py']=code
        group['files'][slug+'/example.py']=code
        group['files'][slug+'/README.md']=instructions
        group['files'][slug+'/requirements.txt']=requirement
        group['files'][slug+'/expected-output.txt']=output
        for name,data in generated.items():group['files'][slug+'/expected-files/'+name]=data
    for prefix,group in aggregate.items():
        if not group['items']:continue
        _,name,title=GROUPS[prefix]
        group['files']['index.json']=json.dumps(group['items'],ensure_ascii=False,indent=2)+'\n'
        group['files']['README.txt']=f'{title}配套代码\n\n每个 .py 文件对应一个教学单元，同名文件夹包含依赖、运行说明和预期输出。单独运行脚本时，如缺少依赖，请先安装该单元文件夹中的 requirements.txt。\n'
        write_zip(ROOT/'source-quant/assets/downloads'/name,group['files'])
    out=Path(args.output);out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n','utf8')
    (out.parent/(out.stem+'-code-report.json')).write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n','utf8')
    print(json.dumps({'articles':len(rows),'packages':len(results),'examples':sum(x['examples'] for x in results),'failed':0,'output':str(out)},ensure_ascii=False))

if __name__=='__main__':main()
