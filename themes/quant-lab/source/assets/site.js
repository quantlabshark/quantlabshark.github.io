'use strict';
(() => {
 const $=(s,r=document)=>r.querySelector(s),$$=(s,r=document)=>[...r.querySelectorAll(s)];
 const safeRead=(key,fallback)=>{try{return JSON.parse(localStorage.getItem(key))||fallback;}catch{return fallback;}};
 const notify=message=>{const t=$('.toast');t.textContent=message;t.hidden=false;clearTimeout(notify.timer);notify.timer=setTimeout(()=>t.hidden=true,2600);};
 window.foamNotify=notify;
 // Keep directory filters in the address, so reload and browser history restore them.
 const listState={
  write(values,push=false){if(!Object.hasOwn(values,'page'))values={...values,page:''};const u=new URL(location.href);for(const [key,value]of Object.entries(values)){if(value&&value!=='全部')u.searchParams.set(key,value);else u.searchParams.delete(key);}const target=u.pathname+u.search+u.hash;if(target!==location.pathname+location.search+location.hash)history[push?'pushState':'replaceState'](history.state,'',target);},
  remember(host){if(!host)return;host.addEventListener('click',e=>{const a=e.target.closest('a[href]');if(!a||!host.contains(a)||a.hasAttribute('download'))return;try{const target=new URL(a.href,location.href);if(target.origin!==location.origin||target.pathname===location.pathname)return;const value=location.pathname+location.search+location.hash;sessionStorage.setItem('foamlab.returnTo:'+location.pathname,value);sessionStorage.setItem('foamlab.returnFor:'+target.pathname+target.search,value);}catch{}});}
 };
 window.foamListState=listState;

 const menu=$('.mobile-menu'),sidebar=$('#sidebar'),mobileNav=matchMedia('(max-width:760px)');
 const navFocusable=()=>sidebar?[...sidebar.querySelectorAll('a[href],button:not([disabled]),[tabindex]:not([tabindex="-1"])')].filter(el=>el.getClientRects().length&&!el.hidden):[];
 function setNavigation(open,restoreFocus=false){
  open=!!open&&mobileNav.matches;
  if(!open&&restoreFocus)menu?.focus();
  document.body.classList.toggle('nav-open',open);menu?.setAttribute('aria-expanded',String(open));
  if(!sidebar)return;
  sidebar.inert=mobileNav.matches?!open:document.documentElement.classList.contains('sidebar-collapsed');
  if(sidebar.inert)sidebar.setAttribute('aria-hidden','true');else sidebar.removeAttribute('aria-hidden');
  if(open){sidebar.setAttribute('role','dialog');sidebar.setAttribute('aria-modal','true');sidebar.setAttribute('aria-label','网站导航');navFocusable()[0]?.focus();}
  else{sidebar.removeAttribute('role');sidebar.removeAttribute('aria-modal');sidebar.removeAttribute('aria-label');}
 }
 menu?.addEventListener('click',()=>setNavigation(!document.body.classList.contains('nav-open'),document.body.classList.contains('nav-open')));
 $('[data-close-nav]')?.addEventListener('click',()=>setNavigation(false,true));
 document.addEventListener('click',event=>{if(!document.body.classList.contains('nav-open'))return;if(event.target.closest('.sidebar a[href]'))setNavigation(false);else if(!event.target.closest('.sidebar,.mobile-menu'))setNavigation(false,sidebar?.contains(document.activeElement));});
 document.addEventListener('keydown',event=>{
  if(!mobileNav.matches||!document.body.classList.contains('nav-open'))return;
  if(event.key==='Escape'){event.preventDefault();setNavigation(false,true);return;}
  if((event.ctrlKey||event.metaKey)&&event.key.toLowerCase()==='k'){setNavigation(false);return;}
  if(event.key!=='Tab')return;
  const items=navFocusable(),first=items[0],last=items.at(-1);if(!first)return;
  if(event.shiftKey&&(document.activeElement===first||!sidebar.contains(document.activeElement))){event.preventDefault();last.focus();}
  else if(!event.shiftKey&&(document.activeElement===last||!sidebar.contains(document.activeElement))){event.preventDefault();first.focus();}
 });
 mobileNav.addEventListener('change',()=>setNavigation(false,mobileNav.matches&&sidebar?.contains(document.activeElement)));
 setNavigation(false);
 async function copy(text){try{await navigator.clipboard.writeText(text);notify('已复制到剪贴板');return true;}catch{notify('浏览器未允许复制，请选中代码复制');return false;}}
 window.foamCopy=copy;
 function addCopy(pre){const code=$('code',pre);if(!code)return;let panel=pre.parentElement;if(!panel.classList.contains('code-panel')){panel=document.createElement('div');panel.className='code-panel';pre.before(panel);panel.append(pre);const bar=document.createElement('div');bar.className='code-toolbar';const name=document.createElement('span');name.className='code-language';name.textContent=pre.dataset.label||'Bash / 终端';const lines=document.createElement('span');lines.className='code-lines';lines.textContent=code.textContent.trimEnd().split('\n').length+' 行';const wrap=document.createElement('button');wrap.type='button';wrap.className='code-wrap';wrap.textContent='自动换行';wrap.setAttribute('aria-pressed','false');const copyButton=document.createElement('button');copyButton.type='button';copyButton.className='copy-code';copyButton.textContent='复制';copyButton.setAttribute('aria-label','复制代码');bar.append(name,lines,wrap,copyButton);panel.prepend(bar);}if(panel.dataset.enhanced)return;panel.dataset.enhanced='true';$('.copy-code',panel)?.addEventListener('click',async()=>{if(await copy(code.textContent))window.dispatchEvent(new Event('foamlab:code-copied'));});$('.code-wrap',panel)?.addEventListener('click',e=>{const enabled=panel.classList.toggle('wrap-lines');e.currentTarget.setAttribute('aria-pressed',String(enabled));});}
 $$('.prose pre').forEach(addCopy);window.foamEnhanceCode=addCopy;
 const toc=$('#toc');
 if(toc){const heads=$$('.prose h2,.prose h3');heads.forEach((h,i)=>{h.id=h.id||'section-'+i;const a=document.createElement('a');a.href='#'+h.id;a.textContent=h.textContent.replace(/源码$/,'').trim();toc.append(a);});if('IntersectionObserver' in window){const observer=new IntersectionObserver(entries=>{entries.forEach(entry=>{if(entry.isIntersecting){$$('a',toc).forEach(a=>a.classList.toggle('current',a.hash==='#'+entry.target.id));}});},{rootMargin:'-100px 0px -65% 0px'});heads.forEach(h=>observer.observe(h));}}
 // Search text is untrusted content: every result is built with textContent.
 const dialog=$('#search-dialog'),input=$('#global-search'),results=$('#search-results');let timer,searchVersion=0,searchRequest,searchManifest;const searchIndexes=new Map();
 const publicSearchItem=item=>{if(item.status&&item.status!=='published'||item.admin_only||item.metadata?.admin_only)return false;let url;try{url=new URL(item.url||'/',location.origin);}catch{return false;}const slug=item.slug||url.searchParams.get('slug');return !['site-maintenance','site-design'].includes(slug)&&!/^\/(?:admin|maintenance|design)(?:\/|$)/.test(url.pathname);};


 async function localSearch(q,scope,current){
  let url='/assets/search-live.json';
  if(scope){searchManifest||=fetch('/assets/search-manifest.json').then(r=>r.ok?r.json():null).catch(()=>null);const manifest=await searchManifest;const candidate=manifest?.scopes?.[scope];if(typeof candidate==='string'&&/^\/assets\/search-scopes\/[a-z0-9-]+\.json$/.test(candidate))url=candidate;}
  if(!current())return [];
  if(!searchIndexes.has(url)){const pending=fetch(url).then(r=>{if(!r.ok)throw Error('Search index unavailable');return r.json();}).then(async rows=>{
    const index=[];for(let i=0;i<rows.length;i++){const item=rows[i];if(publicSearchItem(item))index.push({item,title:String(item.title||'').toLowerCase(),body:String(item.text||'').toLowerCase()});if(i%200===199)await new Promise(resolve=>setTimeout(resolve,0));}return index;
   }).catch(error=>{searchIndexes.delete(url);throw error;});searchIndexes.set(url,pending);}
  let index;try{index=await searchIndexes.get(url);}catch(error){if(url!=='/assets/search-live.json')return localSearch(q,'',current).then(rows=>rows.filter(item=>window.FoamSearchScope?.matches(item,scope)));throw error;}
  const tokens=window.FoamSearch.terms(q),found=[];
  for(let i=0;i<index.length;i++){if(i%200===0){if(!current())return [];if(i)await new Promise(resolve=>setTimeout(resolve,0));}const {item,title,body}=index[i];if((window.FoamSearchScope?.matches(item,scope)??!scope)&&tokens.every(t=>(title+' '+body).includes(t)))found.push({...item,score:tokens.filter(t=>body.includes(t)).length*10+(body.includes(q)?20:0)+(title.includes(q)?1:0)});}
  return found.sort((a,b)=>b.score-a.score);
 }

 async function search(){
  searchRequest?.abort();const request=searchRequest=new AbortController();const version=++searchVersion,q=input.value.trim().toLowerCase().slice(0,120),scope=window.FoamSearchScope?.key()||'',current=()=>dialog.open&&version===searchVersion&&input.value.trim().toLowerCase().slice(0,120)===q&&(window.FoamSearchScope?.key()||'')===scope;
  results.replaceChildren();
  if(!q){results.textContent='输入关键词查找文章；登录后可搜索正文和代码。';return;}
  results.textContent='正在查找匹配内容…';
  try{
   let found=null;
   try{
    await window.QuantLab.contentReady;if(!current())return;
    const timeout=setTimeout(()=>request.abort(),10000);let r;try{r=await window.QuantLab.client.rpc(window.QuantLab.user&&!window.QuantLab.user.is_anonymous?'foamlab_search_content_scoped':'foamlab_search_catalog',{query:q,section_key:scope||null}).abortSignal(request.signal);}finally{clearTimeout(timeout);}if(!current())return;
    if(!r.error&&Array.isArray(r.data))found=r.data.filter(publicSearchItem).map(x=>({...x,url:'/read/?slug='+encodeURIComponent(x.slug),kind:({lesson:'课程',tool:'工具',log:'日志',article:'分享',resource:'资料',module:'专题',reference:'参考'})[x.kind]||'参考',text:x.excerpt}));
   }catch{}
   const cached=found===null;
   if(cached)found=await localSearch(q,scope,current);
   if(!current())return;
   results.replaceChildren();
   if(!found.length){results.textContent='没有找到匹配内容，试试更短的关键词。';return;}
   const count=document.createElement('p');count.className='search-count';count.textContent=(cached?'当前显示本地索引 · ':'')+(window.FoamSearchScope?.label()||'全站')+' · 显示 '+Math.min(found.length,40)+' 篇匹配内容'+(found.length>=40?'（最多 40 篇，可缩小查找范围或调整关键词）':'')+' · 点击打开原文';results.append(count);
   for(const item of found.slice(0,40)){const a=window.FoamSearch.card(item,q);if(a)results.append(a);}
  }catch{if(current())results.textContent='搜索索引暂时无法加载。请重试，或直接进入课程目录。';}
 }
 async function openSearch(query='',scope){if(!dialog)return;if(!dialog.open)dialog.showModal();input.focus();if(typeof query==='string'&&query)input.value=query;if(typeof scope==='string'){await window.FoamSearchScope?.ready;window.FoamSearchScope?.set(scope);}if(input.value)void search();}
 window.foamOpenSearch=openSearch;
 document.addEventListener('foamlab:search-scope',()=>{++searchVersion;searchRequest?.abort();clearTimeout(timer);if(dialog.open)void search();});
 dialog?.addEventListener('close',()=>{++searchVersion;searchRequest?.abort();clearTimeout(timer);});
 $$('[data-open-search]').forEach(b=>b.addEventListener('click',openSearch));$('[data-close-dialog]')?.addEventListener('click',()=>dialog.close());dialog?.addEventListener('click',e=>{if(e.target===dialog){const r=dialog.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)dialog.close();}});
 input?.addEventListener('input',()=>{++searchVersion;searchRequest?.abort();clearTimeout(timer);timer=setTimeout(search,160);});document.addEventListener('keydown',e=>{if(e.key==='Escape'&&dialog?.open){e.preventDefault();dialog.close();}if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='k'){e.preventDefault();openSearch();}if(e.key==='/'&&!/INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName)&&$('#command-query')){e.preventDefault();$('#command-query').focus();}});
})();
