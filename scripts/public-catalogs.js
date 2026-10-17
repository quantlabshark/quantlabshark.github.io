'use strict';
const fs=require('node:fs'),path=require('node:path');
// Searchable full text and article examples belong to authenticated reads.
// Replace the source search index with the small public catalog fields.
hexo.extend.filter.register('after_generate',function(){
 for(const name of fs.readdirSync(path.join(this.source_dir,'assets'))){
  if(name!=='search.json')continue;
  const rows=JSON.parse(fs.readFileSync(path.join(this.source_dir,'assets',name),'utf8'));if(!Array.isArray(rows))continue;
  if(!rows.some(r=>r.searchText!==undefined||r.text!==undefined||r.examples!==undefined||r.body!==undefined))continue;
  const safe=rows.map(row=>{const {searchText,text,examples,body,...item}=row;
   if(name==='search.json')item.text=[row.title].join(' ');
   return item;
  });
  this.route.set('assets/'+name,JSON.stringify(safe));
 }
},20);
