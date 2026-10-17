'use strict';
const fs=require('node:fs'),path=require('node:path'),view=require('../themes/quant-lab/source/assets/curriculum-view.js');
let rows=[];
hexo.extend.filter.register('before_generate',()=>{rows=JSON.parse(fs.readFileSync(path.join(hexo.base_dir,'tools/content/course-catalog.json'),'utf8'));});
hexo.extend.helper.register('curriculum_rows',()=>rows);
hexo.extend.helper.register('curriculum_stages',()=>view.stages(rows));
hexo.extend.helper.register('curriculum_catalog',()=>view.render(rows));
