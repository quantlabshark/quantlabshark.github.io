'use strict';
const fs=require('node:fs'),path=require('node:path');
let nodes=[];
hexo.extend.filter.register('before_generate',()=>{
 nodes=JSON.parse(fs.readFileSync(path.join(hexo.source_dir,'assets/search-scopes.json'),'utf8'));
});
hexo.extend.helper.register('foam_appearance_initial',()=>fs.readFileSync(path.join(hexo.theme_dir,'source/assets/appearance-initial.js'),'utf8'));
hexo.extend.helper.register('foam_catalog_hint',page=>{
 if(!['home','catalog','topics','fvm-book','turbulence-book','heat-transfer-book','kolev-book'].includes(page.layout))return '';
 const url='/'+page.path.replace(/index\.html$/,''),root=page.layout==='home'?nodes.find(n=>n.key==='topics'):nodes.find(n=>n.href===url);
 if(!root)return '';
 const ids=new Set([root.id]);let changed=true;
 while(changed){changed=false;for(const node of nodes)if(ids.has(node.parent_id)&&!ids.has(node.id)){ids.add(node.id);changed=true;}}
 // IDs only, never cached titles or course bodies. The live tree must match
 // these placements before the parallel response can be used on the page.
 return JSON.stringify({path:url,key:root.key,ids:[...ids]}).replaceAll('<','\\u003c');
});
