'use strict';
const fs=require('node:fs'),path=require('node:path');
const tree=require('../themes/quant-lab/source/assets/navigation-tree.js');
let nodes=[],courseRows=[];
hexo.extend.filter.register('before_generate',()=>{nodes=JSON.parse(fs.readFileSync(path.join(hexo.base_dir,'tools/content/navigation.json'),'utf8'));courseRows=JSON.parse(fs.readFileSync(path.join(hexo.base_dir,'tools/content/course-catalog.json'),'utf8')).map(r=>({slug:r.slug,title:r.title,number:r.metadata.curriculum.number}));});
hexo.extend.helper.register('quant_course_navigation_data',()=>JSON.stringify(courseRows).replace(/</g,'\\u003c'));
hexo.extend.helper.register('quant_navigation',page=>tree.render(nodes,{currentId:nodes.find(n=>n.href==='/'+page.path.replace(/index\.html$/,''))?.id,courseRows}));
