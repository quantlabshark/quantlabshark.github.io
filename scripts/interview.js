'use strict';
const fs=require('node:fs'),path=require('node:path'),view=require('../themes/quant-lab/source/assets/interview-view.js');
let rows=[];
hexo.extend.filter.register('before_generate',()=>{rows=JSON.parse(fs.readFileSync(path.join(hexo.base_dir,'tools/content/interview-catalog.json'),'utf8'));});
hexo.extend.helper.register('interview_rows',book=>rows.filter(r=>!book||r.metadata.interview.book===book));
hexo.extend.helper.register('interview_chapters',book=>view.chapters(rows.filter(r=>r.metadata.interview.book===book)));
hexo.extend.helper.register('interview_catalog',book=>view.render(rows.filter(r=>r.metadata.interview.book===book)));
