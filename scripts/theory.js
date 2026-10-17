'use strict';
const fs=require('node:fs'),path=require('node:path'),view=require('../themes/quant-lab/source/assets/theory-view.js');
let rows=[];
hexo.extend.filter.register('before_generate',()=>{rows=JSON.parse(fs.readFileSync(path.join(hexo.base_dir,'tools/content/theory-catalog.json'),'utf8'));});
hexo.extend.helper.register('theory_rows',book=>rows.filter(r=>r.metadata.theory_book.book===book));
hexo.extend.helper.register('theory_catalog',book=>view.render(rows.filter(r=>r.metadata.theory_book.book===book)));
