'use strict';
const fs=require('node:fs'),path=require('node:path'),S=require('../lib/static-content.cjs');
let rows=[],nodes=[];
hexo.extend.filter.register('before_generate',()=>{
 rows=fs.readdirSync(path.join(hexo.base_dir,'tools/content/articles')).filter(f=>f.endsWith('.json')).map(f=>JSON.parse(fs.readFileSync(path.join(hexo.base_dir,'tools/content/articles',f),'utf8'))).sort((a,b)=>(a.sort_order||0)-(b.sort_order||0)||a.slug.localeCompare(b.slug));
 nodes=JSON.parse(fs.readFileSync(path.join(hexo.base_dir,'tools/content/navigation.json'),'utf8'));
});
function catalog(key){const n=nodes.find(n=>n.key===key),ids=new Set(n?[n.id]:[]);let prior=-1;while(prior!==ids.size){prior=ids.size;for(const node of nodes)if(ids.has(node.parent_id))ids.add(node.id);}const matched=rows.filter(r=>(r.section_ids||[]).some(id=>ids.has(id)));if(!matched.length&&key==='programming')return rows.filter(r=>r.kind==='lesson'&&!['curriculum','theory_book','topic','interview'].some(k=>r.metadata?.[k]));return matched;}
hexo.extend.helper.register('static_catalog',catalog);
hexo.extend.helper.register('static_card',S.card);
hexo.extend.helper.register('static_item',slug=>rows.find(r=>r.slug===slug));
hexo.extend.helper.register('static_latest',()=>rows.filter(r=>r.metadata?.curriculum).slice(0,3));
hexo.extend.helper.register('static_body',S.render);
hexo.extend.helper.register('static_title',S.title);
hexo.extend.helper.register('static_parent',S.parent);
hexo.extend.helper.register('static_json',r=>JSON.stringify(r).replace(/</g,'\\u003c'));
hexo.extend.helper.register('static_siblings',r=>{const key=S.group(r);return key?rows.filter(x=>S.group(x)===key):[];});
hexo.extend.helper.register('static_url',S.url);
hexo.extend.generator.register('static-articles',()=>{
 const metadata=rows.map(({body,...r})=>r);
 const search=rows.map(r=>({slug:r.slug,title:r.title,url:S.url(r.slug),kind:r.kind,section_ids:r.section_ids,scope_keys:[],text:r.body.replace(/<[^>]+>/g,' ').replace(/[#*`]/g,'')}));
 return [...rows.map(item=>({path:'read/'+item.slug+'/index.html',layout:['static-read'],data:{title:S.title(item),description:item.summary,section:'read',layout:'static-read',item,path:'read/'+item.slug+'/index.html'}})),
 {path:'assets/catalog.json',data:JSON.stringify(metadata)},
 {path:'assets/navigation-data.json',data:JSON.stringify(nodes)},
 {path:'assets/search-manifest.json',data:JSON.stringify({scopes:{}})},
 {path:'assets/search-live.json',data:JSON.stringify(search)}];
});
hexo.extend.filter.register('after_render:html',S.rewrite,40);
