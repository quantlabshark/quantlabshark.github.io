'use strict';
(() => {
 const L=window.QuantLab,esc=L.esc;
 const D=window.FoamDirectory={nodes:[],available:false};
 const directoryIndexes=new WeakMap();
 function indexFor(nodes=D.nodes){
  let index=directoryIndexes.get(nodes);if(index)return index;
  const byId=new Map(nodes.map(n=>[n.id,n])),children=new Map();
  for(const n of nodes){const parent=n.parent_id||null;if(!children.has(parent))children.set(parent,[]);children.get(parent).push(n.id);}
  for(const list of children.values())list.sort((a,b)=>(byId.get(a).sort_order||0)-(byId.get(b).sort_order||0)||String(byId.get(a).name||'').localeCompare(String(byId.get(b).name||'')));
  index={byId,children,descendants:new Map(),ancestors:new Map()};directoryIndexes.set(nodes,index);return index;
 }
 D.get=id=>indexFor().byId.get(id);
 D.children=id=>(indexFor().children.get(id||null)||[]).map(D.get);
 // Flatten the same sibling lists used by the sidebar, keeping each branch
 // together instead of interleaving unrelated nodes by their numeric order.
 D.orderedNodes=(rootId=null)=>{
  const result=[],seen=new Set();
  const visit=node=>{if(!node||seen.has(node.id))return;seen.add(node.id);result.push(node);D.children(node.id).forEach(visit);};
  if(rootId)visit(D.get(rootId));
  else{D.children(null).forEach(visit);D.nodes.forEach(visit);}
  return result;
 };
 D.descendants=(id,nodes=D.nodes)=>{
  const index=indexFor(nodes);
  if(!index.descendants.has(id)){const seen=new Set([id]),queue=[id];for(let i=0;i<queue.length;i++)for(const child of index.children.get(queue[i])||[])if(!seen.has(child)){seen.add(child);queue.push(child);}index.descendants.set(id,queue);}
  return [...index.descendants.get(id)];
 };
 D.ancestors=id=>{const index=indexFor();if(!index.ancestors.has(id)){const out=[],seen=new Set();for(let n=D.get(id);n&&!seen.has(n.id);n=D.get(n.parent_id)){seen.add(n.id);out.unshift(n);}index.ancestors.set(id,out);}return [...index.ancestors.get(id)];};
 D.path=id=>D.ancestors(id).map(n=>n.name).join(' / ');
 D.isVisible=n=>D.ancestors(n.id).every(x=>x.visible);
 // A database array is an unordered set of placements. Prefer the programming
 // module for its lessons, even when they are also referenced by a physics topic.
 D.primary=item=>(item?.section_ids||[]).map(D.get).find(n=>n&&D.isVisible(n));
 D.url=n=>{if(n?.href&&!n.href.startsWith('/read/?')&&!(n.key==='programming-examples'&&n.href.startsWith('/programming/?'))){try{const u=new URL(n.href,location.origin);if(u.origin===location.origin)return u.pathname+u.search+u.hash;}catch{}}return '/section/?id='+encodeURIComponent(n.id);};
 D.locations=row=>(row.section_ids||[]).map(D.path).filter(Boolean);
 D.optionLabel=node=>{const depth=Math.max(0,D.ancestors(node.id).length-1);return '　'.repeat(Math.min(depth,8))+(depth?'↳ ':'')+D.path(node.id);};
 D.option=(node,selected='')=>'<option value="'+esc(node.id)+'" title="'+esc(D.path(node.id))+'" '+(node.id===selected?'selected':'')+'>'+esc(D.optionLabel(node))+'</option>';
 D.options=(selected='',exclude=[],rootId=null)=>(rootId?'':'<option value="">顶层模块</option>')+D.orderedNodes(rootId).filter(n=>!exclude.includes(n.id)).map(n=>D.option(n,selected)).join('');
 D.current=(nodes=D.nodes)=>{const u=new URL(location.href),id=u.searchParams.get('id');if(u.pathname==='/section/')return nodes.find(n=>n.id===id);return nodes.filter(n=>n.href&&n.href!=='/admin/'&&(()=>{const v=new URL(n.href,location.origin);return v.pathname===u.pathname&&(!v.hash||v.hash===u.hash)&&[...v.searchParams].every(([k,x])=>u.searchParams.get(k)===x);})()).sort((a,b)=>(new URL(b.href,location.origin).search+new URL(b.href,location.origin).hash).length-(new URL(a.href,location.origin).search+new URL(a.href,location.origin).hash).length)[0];};
 const contentReads=new Map(),hintKey='foamlab.directory-hint.v1';
 const columns='id,slug,kind,title,summary,track,series,cover_url,metadata,section_ids,author_id,author_name,sort_order,pinned,published_at,created_at,updated_at';
 function readContent(ids){
  const key=[...ids].sort().join(',');if(contentReads.has(key))return contentReads.get(key);
  const pending=(async()=>{const rows=[];for(let start=0;;start+=500){const batch=L.check(await L.client.from('foamlab_content').select(columns).eq('status','published').overlaps('section_ids',ids).order('sort_order').order('id').range(start,start+499));
   rows.push(...batch);if(batch.length<500)return rows;}})().catch(error=>{contentReads.delete(key);throw error;});
  contentReads.set(key,pending);return pending;
 }
 function prefetchCatalog(){
  // Cached IDs only schedule a fresh request. Never render cached names or rows.
  const catalog=document.querySelector('[data-lab-catalog]');if(!catalog)return;
  try{const saved=JSON.parse(sessionStorage.getItem(hintKey)||'null');if(saved&&saved.user===(L.user?.id||null)&&Date.now()-saved.at<86400000&&Array.isArray(saved.nodes)&&saved.nodes.length<=2000){
   const nodes=saved.nodes,key=catalog.dataset.labCatalog||'topics',node=D.current(nodes)||nodes.find(n=>n.key===key);
   if(node){void readContent(D.descendants(node.id,nodes)).catch(()=>{});return;}
  }}catch{}
  try{const hint=JSON.parse(document.getElementById('catalog-hint')?.textContent||'null');if(hint?.path===location.pathname&&Array.isArray(hint.ids)&&hint.ids.length&&hint.ids.length<=2000&&!new URLSearchParams(location.search).has('topic'))void readContent(hint.ids).catch(()=>{});}catch{}
 }
 D.load=async()=>{await L.contentReady;prefetchCatalog();const nodes=[];for(let start=0;;start+=500){const r=L.check(await L.client.from('foamlab_sections').select('id,key,name,parent_id,href,description,nav_group,visible,sort_order,revision,created_at,updated_at,read_access').order('sort_order').order('id').range(start,start+499));nodes.push(...r);if(r.length<500)break;}D.nodes=nodes;D.available=true;
  try{sessionStorage.setItem(hintKey,JSON.stringify({user:L.user?.id||null,at:Date.now(),nodes:nodes.map(({id,key,href,parent_id})=>({id,key,href,parent_id}))}));}catch{}
  return D;
 };
 D.ready=D.load().catch(e=>{D.error=e;return D;});
 document.dispatchEvent(new Event('foamlab:directory-init'));
 D.content=node=>readContent(D.descendants(node.id));
 D.picker=(host,ids=[],editable=true)=>{
  host.innerHTML='<h3>所在位置</h3><p class="cms-muted">可选择多个目录，同一篇正文会同时出现在这些位置。</p><div class="cms-selected-locations" role="status"></div><input type="search" class="cms-location-search" placeholder="查找模块或子模块" aria-label="查找发布位置"><div class="cms-location-picker">'+D.orderedNodes().map(n=>'<label data-location-label="'+esc(D.path(n.id).toLowerCase())+'" style="padding-inline-start:'+Math.min(7+Math.max(0,D.ancestors(n.id).length-1)*14,119)+'px"><input type="checkbox" name="section_ids" value="'+n.id+'" '+(ids.includes(n.id)?'checked':'')+' '+(!editable?'disabled':'')+'><span>'+esc(D.path(n.id))+'</span></label>').join('')+'</div>';
  const selected=()=>{const paths=D.readPicker(host).map(D.path);host.querySelector('.cms-selected-locations').textContent=paths.length?'已选择：'+paths.join('；'):'未归类';};selected();host.addEventListener('change',selected);
  host.querySelector('input[type=search]').oninput=e=>host.querySelectorAll('[data-location-label]').forEach(row=>row.hidden=!row.dataset.locationLabel.includes(e.target.value.trim().toLowerCase()));
 };
 D.readPicker=host=>[...host.querySelectorAll('[name=section_ids]:checked')].map(x=>x.value);
 D.nav=()=>{
  if(!D.available)return;const nav=document.querySelector('#sidebar nav');if(!nav)return;
  const scroller=document.getElementById('sidebar'),scrollTop=scroller.scrollTop;
  const focus=nav.contains(document.activeElement)?{key:document.activeElement.closest('[data-nav-section]')?.dataset.navSection,arrow:document.activeElement.matches('.nav-expand')}:null;
  nav.innerHTML=window.QuantNavTree.render(D.nodes,{currentId:(D.current()||D.nodes.find(n=>n.key===document.body.dataset.navSection))?.id,isOpen:key=>window.FoamNavigation?.isOpen(key)===true,courseRows:window.QuantCourseNavigation||[],currentHref:location.href});
  scroller.scrollTop=scrollTop;
  if(focus?.key){const group=[...nav.querySelectorAll('[data-nav-section]')].find(g=>g.dataset.navSection===focus.key);group?.querySelector(focus.arrow?':scope > .nav-parent > .nav-expand':':scope > .nav-parent > a')?.focus({preventScroll:true});}
 };
 D.breadcrumb=item=>{
  if(item?.metadata?.curriculum){
   const level=window.QuantNavTree.levelOf(item.metadata.curriculum.number),name={beginner:'入门',foundation:'基础',advanced:'进阶'}[level];
   let href='/courses/?level='+level;try{const from=new URL(sessionStorage.getItem('foamlab.returnFor:'+location.pathname+location.search)||href,location.origin);if(from.origin===location.origin&&from.pathname==='/courses/')href=from.pathname+from.search+from.hash;}catch{}
   const link=document.querySelector('#breadcrumb-parent'),back=document.querySelector('#page-back-link');if(link){link.href=href;link.textContent='系统学习 / '+name;}if(back){back.href=href;back.textContent='← 返回'+name+'课程';}D.nav();return;
  }
  const ids=(item?.section_ids||[]).filter(id=>D.get(id)&&D.isVisible(D.get(id)));if(!ids.length)return;
  let node=D.primary(item)||D.get(ids[0]),returnTo='';try{const from=sessionStorage.getItem('foamlab.returnFor:'+location.pathname+location.search);if(from){const url=new URL(from,location.origin),matches=D.nodes.filter(n=>{const target=new URL(D.url(n),location.origin);return url.origin===location.origin&&target.pathname===url.pathname&&[...target.searchParams].every(([k,v])=>url.searchParams.get(k)===v);}).sort((a,b)=>new URL(D.url(b),location.origin).search.length-new URL(D.url(a),location.origin).search.length),found=matches[0];if(found&&ids.some(id=>D.descendants(found.id).includes(id))){node=found;returnTo=url.pathname+url.search+url.hash;}}}catch{}
  // A directory's own page returns to its parent, or the overview at the root.
  const target=new URL(D.url(node),location.origin),current=new URL(location.href);
  const isSelf=target.pathname===current.pathname&&[...target.searchParams].every(([k,v])=>current.searchParams.get(k)===v);
  let rootPage=false;if(isSelf){const parent=D.get(node.parent_id);rootPage=!parent;node=parent||node;returnTo='';}
  const parentURL=rootPage?'/':returnTo||D.url(node),parentName=rootPage?'学习概览':node.name;
  const link=document.querySelector('#breadcrumb-parent'),back=document.querySelector('#page-back-link');if(link){link.href=parentURL;link.textContent=rootPage?'学习概览':D.path(node.id);}if(back){back.href=parentURL;back.textContent='← 返回'+parentName;}
  const nav=document.querySelector('#sidebar nav');nav?.querySelectorAll('.active,[aria-current=page]').forEach(a=>{a.classList.remove('active');a.removeAttribute('aria-current');});
  for(const n of D.ancestors(node.id)){const group=nav?.querySelector('[data-directory-id="'+n.id+'"]');const link=group?.querySelector('.nav-parent>a');link?.classList.add('active');if(n.id===node.id)link?.setAttribute('aria-current','page');}
 };
 document.addEventListener('foamlab:content-ready',e=>D.ready.then(()=>D.breadcrumb(e.detail)));
 D.ready.then(async()=>{
  D.nav();if(window.foamCurrentContent)D.breadcrumb(window.foamCurrentContent);
  if(!D.available)return;
  const courseRoot=D.nodes.find(n=>n.key==='courses');
  if(courseRoot)void D.content(courseRoot).then(rows=>{const courses=rows.filter(r=>r.kind==='lesson'&&r.metadata?.curriculum).sort((a,b)=>a.sort_order-b.sort_order);if(courses.length){window.QuantCourseNavigation=courses.map(r=>({slug:r.slug,title:r.title,number:r.metadata.curriculum.number}));D.nav();}}).catch(()=>{});
  // Home, quick start and functional pages can host newly placed content too.
  const current=D.current();
  if(current&&!document.querySelector('[data-lab-catalog],#live-article,.article[data-cms-slug],#cms-root')&&!location.pathname.startsWith('/admin/')){
   try{
    const host=document.querySelector('main .page-wrap')||document.querySelector('main'),links=new Set([...host.querySelectorAll('a[href]')].map(a=>new URL(a.href).pathname+new URL(a.href).search));
    const children=D.children(current.id).filter(n=>D.isVisible(n)&&!links.has(n.href)&&!links.has(D.url(n)));
    const rows=(await D.content(current)).filter(r=>!links.has(r.metadata?.canonical_path)&&!links.has('/read/?slug='+encodeURIComponent(r.slug)));
    if(children.length||rows.length){const section=document.createElement('section');section.className='directory-supplement';section.innerHTML='<h2>本目录内容</h2><nav class="directory-children">'+children.map(n=>'<a href="'+esc(D.url(n))+'">'+esc(n.name)+' →</a>').join('')+'</nav><div class="lab-card-grid"></div>';host.append(section);if(rows.length){const grid=section.querySelector('.lab-card-grid');await L.names(rows.filter(r=>['article','log'].includes(r.kind)).map(r=>r.author_id));const render=()=>{grid.innerHTML=window.FoamPagination.slice(grid,rows,render,12).map(L.card).join('');};render();window.addEventListener('popstate',render);window.foamListState.remember(grid);}}
   }catch{}
  }
 });
 window.addEventListener('popstate',()=>D.nav());
})();
