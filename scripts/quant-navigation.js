'use strict';
const fs=require('node:fs'),path=require('node:path');
const tree=require('../themes/quant-lab/source/assets/navigation-tree.js');
let nodes=[];
hexo.extend.filter.register('before_generate',()=>{nodes=JSON.parse(fs.readFileSync(path.join(hexo.base_dir,'tools/content/navigation.json'),'utf8'));});
hexo.extend.helper.register('quant_navigation',page=>tree.render(nodes,{currentId:nodes.find(n=>n.href==='/'+page.path.replace(/index\.html$/,''))?.id}));
