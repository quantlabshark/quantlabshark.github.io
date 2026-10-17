'use strict';
const fs=require('node:fs');const path=require('node:path');const presentation=require('../lib/presentation.cjs');
const target=path.join(hexo.base_dir,'themes/quant-lab/source/assets/vendor/katex');fs.mkdirSync(target,{recursive:true});
fs.copyFileSync(path.join(hexo.base_dir,'node_modules/katex/dist/katex.min.css'),path.join(target,'katex.min.css'));
fs.cpSync(path.join(hexo.base_dir,'node_modules/katex/dist/fonts'),path.join(target,'fonts'),{recursive:true});
fs.copyFileSync(path.join(hexo.base_dir,'node_modules/katex/LICENSE'),path.join(target,'LICENSE.txt'));
fs.copyFileSync(path.join(hexo.base_dir,'node_modules/highlight.js/LICENSE'),path.join(target,'highlight-LICENSE.txt'));
hexo.extend.filter.register('before_post_render',data=>{data.content=presentation.protectMath(data.content);return data;},5);
hexo.extend.filter.register('after_post_render',data=>{try{data.content=presentation.render(data.content);}catch(e){throw new Error('Formula/code rendering failed in '+data.source+': '+e.message);}return data;},20);
// Dynamic command cards reuse the same highlighter at build time.
hexo.extend.generator.register('formatted-commands',function(){
 const data=JSON.parse(fs.readFileSync(path.join(this.source_dir,'assets/commands.json'),'utf8')),routes=[];
 const catalog=data.map(c=>{
  const {name,title,description,example,details,category,configs,url}=c;
  const row={name,title,description,example,details,category,configs,url,display:presentation.codeHTML(c.example,'bash'),example_count:c.examples?.length||0};
  if(row.example_count>1){
   const body=JSON.stringify(c.examples.slice(1)),hash=require('node:crypto').createHash('sha256').update(body).digest('hex').slice(0,20);
   row.examples_url='/assets/command-examples/'+hash+'.json';routes.push({path:row.examples_url.slice(1),data:body});
  }
  return row;
 });
 routes.push({path:'assets/commands-display.json',data:JSON.stringify(catalog)});return routes;
});
