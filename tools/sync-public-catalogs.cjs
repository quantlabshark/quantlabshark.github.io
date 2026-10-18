'use strict';
// Refresh public navigation, catalog metadata and search summaries before publishing.
const fs=require('node:fs'),path=require('node:path'),{createClient}=require('@supabase/supabase-js');
const root=path.resolve(__dirname,'..'),config=JSON.parse(fs.readFileSync(path.join(root,'source-quant/assets/auth-config.json'),'utf8'));
async function main(){
 const client=createClient(config.supabaseUrl,config.publishableKey,{auth:{persistSession:false,autoRefreshToken:false}});
 async function pages(table,columns,filters=q=>q){const rows=[];for(let offset=0;;offset+=500){const {data,error}=await filters(client.from(table).select(columns)).order('sort_order').order('id').range(offset,offset+499);if(error)throw error;rows.push(...data);if(data.length<500)return rows;}}
 const nodes=await pages('foamlab_sections','id,key,name,parent_id,href,description,nav_group,visible,sort_order,revision,read_access');
 if(!nodes.some(n=>n.key==='tools')||!nodes.some(n=>n.key==='interview'))throw Error('Missing expected navigation roots');
 const rows=(await pages('foamlab_content','slug,title,summary,kind,status,sort_order,metadata',q=>q.eq('status','published').not('metadata->interview','is',null))).map(r=>({...r,metadata:{interview:r.metadata.interview}}));
 if(!rows.length)throw Error('Empty interview catalog');
 const courses=(await pages('foamlab_content','id,slug,title,summary,kind,status,sort_order,cover_url,metadata',q=>q.eq('status','published').eq('kind','lesson').not('metadata->curriculum','is',null))).map(r=>({...r,metadata:{curriculum:r.metadata.curriculum}}));
 if(courses.length!==66)throw Error('Expected 66 system lessons, received '+courses.length);
 const theory=(await pages('foamlab_content','id,slug,title,summary,kind,status,sort_order,metadata',q=>q.eq('status','published').not('metadata->theory_book','is',null))).map(r=>({...r,metadata:{theory_book:r.metadata.theory_book}}));
 const books=JSON.parse(fs.readFileSync(path.join(root,'tools/content/theory-books.json'),'utf8'));
 for(const book of books){const count=theory.filter(r=>r.metadata.theory_book.book===book.key).length;if(!book.units||count!==book.units)throw Error(`Expected ${book.units} units for ${book.key}, received ${count}`);}
 const topics=(await pages('foamlab_content','id,slug,title,summary,track,series,sort_order,cover_url,metadata,section_ids',q=>q.eq('status','published').not('metadata->topic','is',null))).map(r=>({...r,metadata:{topic:r.metadata.topic}}));
 const modules=JSON.parse(fs.readFileSync(path.join(root,'tools/content/topics.json'),'utf8'));
 for(const module of modules)if(!topics.some(r=>r.metadata.topic.key===module.key))throw Error('Missing topic content: '+module.key);
 const publicMetadata=await pages('foamlab_content','slug,title,summary',q=>q.eq('status','published'));
 const bySlug=new Map(publicMetadata.map(r=>[r.slug,r]));
 const catalog=JSON.parse(fs.readFileSync(path.join(root,'tools/content/catalog-content.json'),'utf8')).map(row=>{
  const current=bySlug.get(row.slug);if(!current)throw Error('Missing published catalog entry: '+row.slug);
  return {...row,title:current.title,summary:current.summary};
 });
 const search=JSON.parse(fs.readFileSync(path.join(root,'source-quant/assets/search.json'),'utf8')).map(row=>{
  const url=new URL(row.url,'https://quantlabshark.github.io');if(url.pathname!=='/read/')return row;
  const slug=url.searchParams.get('slug'),current=bySlug.get(slug);if(!current)throw Error('Missing published search entry: '+slug);
  return {...row,title:current.title,text:current.summary};
 });
 const write=(file,data)=>fs.writeFileSync(path.join(root,file),JSON.stringify(data,null,2)+'\n');
 write('tools/content/navigation.json',nodes);write('tools/content/interview-catalog.json',rows);
 write('tools/content/course-catalog.json',courses);
 write('tools/content/theory-catalog.json',theory);
 write('tools/content/topic-catalog.json',topics);
 write('tools/content/catalog-content.json',catalog);
 write('source-quant/assets/search.json',search);
 write('source-quant/assets/search-scopes.json',nodes.map(({id,key,name,parent_id,href,visible,sort_order})=>({id,key,name,parent_id,href,visible,sort_order})));
 console.log(`Refreshed ${nodes.length} navigation entries, ${courses.length} system lessons, ${rows.length} interview units, ${theory.length} theory units, ${topics.length} topic lessons, ${catalog.length} base entries and ${search.length} search summaries; no article bodies downloaded.`);
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
