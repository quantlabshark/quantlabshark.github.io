'use strict';
(function(root,factory){if(typeof module==='object'&&module.exports)module.exports=factory();else root.QuantNavTree=factory();})(typeof window==='undefined'?this:window,()=>{
 const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const paths={'interview-experience':'M3 7h18v14H3ZM8 7V3h8v4M3 12h18M10 12v3h4v-3',home:'M3 10 12 3l9 7v11h-6v-7H9v7H3Z',start:'M4 12h16m-6-6 6 6-6 6',courses:'M12 5v16M3 4c4-1 7 0 9 2 2-2 5-3 9-2v16c-4-1-7 0-9 2-2-2-5-3-9-2Z',topics:'M3 3h7v7H3Zm11 0h7v7h-7ZM3 14h7v7H3Zm11 0h7v7h-7Z',interview:'M8 3h8v4H8ZM7 5H4v17h16V5h-3M8 12h8M8 17h5',labs:'M4 3v18h18M8 16v-5m5 5V7m5 9V5',programming:'m5 7 5 5-5 5m8 0h6M2 3h20v18H2Z',tools:'m14 6 4 4m-9 4-6 6 2 2 6-6M13 3a6 6 0 0 0-4 10l2 2a6 6 0 0 0 10-4l-4 2-4-4Z',resources:'M12 3v13m-5-5 5 5 5-5M3 17v5h18v-5',community:'M3 4h18v13H9l-6 5Z',assignments:'M4 3h16v19H4Zm4 7 2 2 5-6M8 17h8',announcements:'M4 17h16l-2-4V8a6 6 0 0 0-12 0v5Zm6 4h4','quick-reference':'M16 16 22 22M18 10a8 8 0 1 1-16 0 8 8 0 0 1 16 0'};
 const levelOf=n=>Number(n)<=12?'beginner':Number(n)<=24?'foundation':'advanced';
 const levels=[['beginner','入门'],['foundation','基础'],['advanced','进阶']];
 function curriculumNodes(nodes,rows){
  const parent=nodes.find(n=>n.key==='courses');if(!parent||!rows?.length)return nodes;
  const excluded=new Set([parent.id]);let size=0;while(size!==excluded.size){size=excluded.size;nodes.forEach(n=>{if(excluded.has(n.parent_id))excluded.add(n.id);});}
  const result=nodes.filter(n=>n.id===parent.id||!excluded.has(n.id));
  for(const [i,[key,name]] of levels.entries()){
   const id='curriculum-level-'+key;result.push({id,key:id,name,parent_id:parent.id,sort_order:i,visible:true,href:'/courses/?level='+key});
   for(const r of rows.filter(r=>levelOf(r.number??r.metadata?.curriculum?.number)===key)){
    const number=r.number??r.metadata?.curriculum?.number;
    result.push({id:'curriculum-lesson-'+r.slug,key:'curriculum-lesson-'+r.slug,name:String(number).padStart(2,'0')+' · '+r.title.replace(/^\d+\s*[·.、]\s*/,''),parent_id:id,sort_order:number,visible:true,href:'/read/?slug='+encodeURIComponent(r.slug),curriculumLeaf:true});
   }
  }return result;
 }
 function curriculumCurrent(href,rows){
  let u;try{u=new URL(href,'https://quantlabshark.github.io');}catch{return '';}
  if(u.pathname==='/read/'&&rows.some(r=>r.slug===u.searchParams.get('slug')))return 'curriculum-lesson-'+u.searchParams.get('slug');
  if(u.pathname==='/courses/'){
   const level=u.searchParams.get('level');if(levels.some(([key])=>key===level))return 'curriculum-level-'+level;
  }return '';
 }
 function render(nodes,{currentId='',isOpen=()=>false,courseRows=[],currentHref=''}={}){
  nodes=curriculumNodes(nodes,courseRows);currentId=curriculumCurrent(currentHref,courseRows)||currentId;
  const byId=new Map(nodes.map(n=>[n.id,n])),children=id=>nodes.filter(n=>(n.parent_id||null)===id).sort((a,b)=>a.sort_order-b.sort_order),active=new Set();
  for(let n=byId.get(currentId);n&&!active.has(n.id);n=byId.get(n.parent_id))active.add(n.id);
  const visible=n=>{const seen=new Set();for(;n&&!seen.has(n.id);n=byId.get(n.parent_id)){seen.add(n.id);if(!n.visible)return false;}return true;};
  const url=n=>typeof n.href==='string'&&/^\/(?!\/)/.test(n.href)&&(!n.href.startsWith('/read/?')||n.curriculumLeaf)?n.href:'/section/?id='+encodeURIComponent(n.id);
  const item=(n,depth=0)=>{const kids=children(n.id).filter(visible),open=isOpen(n.key),id='directory-'+n.id;return `<div class="nav-group" data-directory-id="${esc(n.id)}" data-nav-section="${esc(n.key)}"><div class="nav-parent"><a class="nav-item ${depth?'nav-subitem ':''}${active.has(n.id)?'active':''}" href="${esc(url(n))}"${n.id===currentId?' aria-current="page"':''}>${depth?'':`<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${paths[n.key]||paths.courses}"/></svg>`}<span>${esc(n.name)}</span></a>${kids.length?`<button type="button" class="nav-expand" aria-controls="${esc(id)}" aria-expanded="${open}" aria-label="${open?'收起':'展开'}${esc(n.name)}子目录"><svg viewBox="0 0 20 20" aria-hidden="true"><path d="m7 4 6 6-6 6"/></svg></button>`:''}</div>${kids.length?`<div class="nav-subgroup" id="${esc(id)}" ${open?'':'hidden'}>${kids.map(c=>item(c,depth+1)).join('')}</div>`:''}</div>`;};
  const roots=children(null).filter(visible),groups=[...new Set(roots.map(n=>n.nav_group))];
  return groups.map(g=>`<div class="nav-label">${esc(g)}</div>`+roots.filter(n=>n.nav_group===g).map(n=>item(n)).join('')).join('');
 }
 return {render,curriculumCurrent,levelOf};
});
