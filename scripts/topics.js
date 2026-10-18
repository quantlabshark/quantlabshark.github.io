'use strict';
const fs=require('node:fs'),path=require('node:path'),view=require('../themes/quant-lab/source/assets/topics-view.js');
let modules=[],rows=[];
hexo.extend.filter.register('before_generate',()=>{modules=JSON.parse(fs.readFileSync(path.join(hexo.base_dir,'tools/content/topics.json'),'utf8'));rows=JSON.parse(fs.readFileSync(path.join(hexo.base_dir,'tools/content/topic-catalog.json'),'utf8'));});
hexo.extend.helper.register('topic_modules',()=>modules);
hexo.extend.helper.register('topic_module',key=>{const m=modules.find(m=>m.key===key);if(!m)throw Error('Unknown topic '+key);return m;});
hexo.extend.helper.register('topic_rows',key=>rows.filter(r=>r.metadata.topic.key===key));
hexo.extend.helper.register('topic_hub',()=>view.hub(modules,rows));
hexo.extend.helper.register('topic_catalog',key=>view.cards(rows.filter(r=>r.metadata.topic.key===key),modules.find(m=>m.key===key)));
