/* directory.js */
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

 D.ready=Promise.all([fetch('/assets/navigation-data.json').then(r=>r.json()),fetch('/assets/catalog.json').then(r=>r.json())]).then(([nodes,rows])=>{D.nodes=nodes;D.rows=rows;D.available=true;return D;}).catch(()=>D);
 D.content=async node=>{await D.ready;const ids=new Set(D.descendants(node.id));return D.rows.filter(r=>(r.section_ids||[]).some(id=>ids.has(id)));};
 document.dispatchEvent(new Event('foamlab:directory-init'));
})();

;
/* browser-code.js */
'use strict';
(() => {
 const MAX_SIZE=32768,queue=[],seen=new WeakSet();let worker=null,current=null,serial=0,timeout=null,disabled=false;
 const idle=fn=>window.requestIdleCallback?requestIdleCallback(fn,{timeout:300}):setTimeout(fn,16);
 function plain(node){node.dataset.foamHighlight='plain';}
 function dispose(instance){if(!instance||worker!==instance)return;worker=null;instance.onmessage=null;instance.onerror=null;instance.terminate();}
 function finish(data){if(!current||data.id!==current.id)return;clearTimeout(timeout);const {node,source}=current;if(node.isConnected&&node.textContent===source){if(data.html!==undefined){node.innerHTML=data.html;node.classList.add('hljs');node.dataset.foamHighlight='complete';}else plain(node);}current=null;idle(next);}
 function next(){if(current||disabled)return;while(queue.length){const node=queue.shift();if(!node.isConnected)continue;const source=node.textContent;if(!source||source.length>MAX_SIZE){plain(node);continue;}const language=(node.className.match(/language-([\w+-]+)/)?.[1]||'plaintext').toLowerCase();if(['plaintext','text','txt'].includes(language)){plain(node);continue;}
  try{if(!worker){const instance=new Worker('/assets/browser-code-worker.js');worker=instance;instance.onmessage=e=>{if(worker===instance)finish(e.data);};instance.onerror=()=>{if(worker!==instance)return;disabled=true;clearTimeout(timeout);if(current)plain(current.node);current=null;dispose(instance);};}const task=current={id:++serial,node,source},instance=worker;instance.postMessage({id:serial,language,code:source});timeout=setTimeout(()=>{if(current!==task||worker!==instance)return;plain(task.node);current=null;dispose(instance);idle(next);},1200);return;}catch{disabled=true;clearTimeout(timeout);current=null;dispose(worker);plain(node);return;}
 }}
 const observer='IntersectionObserver'in window?new IntersectionObserver(entries=>{for(const entry of entries)if(entry.isIntersecting){observer.unobserve(entry.target);queue.push(entry.target);}idle(next);},{rootMargin:'250px'}):null;
 function scan(root){const nodes=[];if(root.matches?.('pre > code'))nodes.push(root);if(root.querySelectorAll)nodes.push(...root.querySelectorAll('pre > code'));for(const node of nodes){if(seen.has(node)||node.classList.contains('hljs'))continue;seen.add(node);if(node.textContent.length>MAX_SIZE){plain(node);continue;}if(observer)observer.observe(node);else queue.push(node);}if(!observer)idle(next);}
 const changes=new MutationObserver(records=>{for(const record of records)for(const node of record.addedNodes)if(node.nodeType===1)scan(node);});
 const start=()=>{scan(document);changes.observe(document.body,{childList:true,subtree:true});};if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
 window.foamHighlightCode=scan;
 window.addEventListener('pagehide',()=>{clearTimeout(timeout);if(current)plain(current.node);current=null;queue.length=0;dispose(worker);});
})();

;
/* footer-contact.js */
'use strict';
(() => {
  const wrap = document.querySelector('[data-footer-contact]');
  if (!wrap) return;
  const trigger = wrap.querySelector('button');
  const panel = wrap.querySelector('.footer-contact-panel');
  let opened = false;
  const position = () => {
    panel.style.setProperty('--contact-shift', '0px');
    const bounds = panel.getBoundingClientRect();
    const edge = 12;
    const shift = bounds.left < edge ? edge - bounds.left
      : bounds.right > innerWidth - edge ? innerWidth - edge - bounds.right : 0;
    panel.style.setProperty('--contact-shift', shift + 'px');
  };
  const hide = () => {
    opened = false;
    panel.hidden = true;
    trigger.setAttribute('aria-expanded', 'false');
  };
  const show = () => {
    opened = true;
    panel.hidden = false;
    trigger.setAttribute('aria-expanded', 'true');
    position();
  };
  wrap.addEventListener('pointerenter', event => {
    if (event.pointerType === 'mouse' && matchMedia('(hover: hover)').matches) show();
  });
  wrap.addEventListener('pointerleave', event => {
    if (event.pointerType === 'mouse') hide();
  });
  wrap.addEventListener('focusin', event => {
    if (event.target !== trigger || matchMedia('(hover: hover)').matches) show();
  });
  wrap.addEventListener('focusout', () => {
    setTimeout(() => { if (!wrap.contains(document.activeElement)) hide(); }, 0);
  });
  trigger.addEventListener('click', () => {
    if (matchMedia('(hover: hover)').matches || !opened) show();
    else hide();
  });
  document.addEventListener('pointerdown', event => {
    if (opened && !wrap.contains(event.target)) hide();
  });
  document.addEventListener('keydown', event => {
    if (opened && event.key === 'Escape') {
      if (panel.contains(document.activeElement)) trigger.focus();
      hide();
    }
  });
  window.addEventListener('resize', () => { if (opened) position(); });
})();

;
/* refinements.js */
'use strict';

// Passive visual feedback; navigation, form submission and text selection remain native.
(() => {
  if (window.foamRefinementsReady) return;
  window.foamRefinementsReady = true;
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
  const forcedColours = matchMedia('(forced-colors: active)');
  let layer;
  let pointerStart;

  document.addEventListener('pointerdown', event => {
    pointerStart = event.isPrimary && event.button === 0
      ? { x: event.clientX, y: event.clientY, id: event.pointerId } : undefined;
  }, { passive: true });
  document.addEventListener('pointercancel', () => { pointerStart = undefined; }, { passive: true });

  document.addEventListener('click', event => {
    if (window.foamPandaParticles) return;
    if (reducedMotion.matches || forcedColours.matches || !event.isTrusted || event.detail === 0) return;
    if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    const target = event.target instanceof Element ? event.target : null;
    if (!target || target.closest('input, textarea, select, option, [contenteditable="true"], [disabled], [aria-disabled="true"]')) return;
    // Ignore drags and text selections; keyboard activation uses the visible focus outline.
    if (pointerStart && Math.hypot(event.clientX - pointerStart.x, event.clientY - pointerStart.y) > 10) return;
    pointerStart = undefined;
    if (window.getSelection()?.toString()) return;
    if (!target.closest('main, .topbar, .sidebar, .footer, dialog')) return;
    if (!layer) {
      layer = document.createElement('div');
      layer.className = 'foam-ripple-layer';
      layer.setAttribute('aria-hidden', 'true');
      document.body.append(layer);
    }
    // Keep the number of temporary decorative nodes bounded, including rapid repeated input.
    while (layer.childElementCount >= 6) layer.firstElementChild.remove();
    const ripple = document.createElement('span');
    ripple.className = 'foam-ripple';
    ripple.style.left = event.clientX + 'px';
    ripple.style.top = event.clientY + 'px';
    layer.append(ripple);
    setTimeout(() => ripple.remove(), 750);
  }, { passive: true });

  function clearRings() { if (reducedMotion.matches || forcedColours.matches) layer?.replaceChildren(); }
  reducedMotion.addEventListener('change', clearRings);
  forcedColours.addEventListener('change', clearRings);
})();

;
/* figure-viewer.js */
'use strict';
(() => {
 const dialog=document.createElement('dialog');dialog.id='figure-dialog';dialog.setAttribute('aria-label','查看课程配图');
 dialog.innerHTML='<div class="figure-dialog-bar"><p id="figure-dialog-title"></p><div class="figure-dialog-actions"><button class="button secondary" type="button" data-figure-size aria-pressed="false">原始尺寸</button><button class="icon-button" type="button" data-figure-close aria-label="关闭图片">×</button></div></div><div class="figure-dialog-image"><img alt=""></div><p class="figure-dialog-source"></p>';
 document.body.append(dialog);const frame=dialog.querySelector('.figure-dialog-image'),large=frame.querySelector('img'),size=dialog.querySelector('[data-figure-size]');let origin=null;
 function open(img){origin=img;large.src=img.currentSrc||img.src;large.alt=img.alt;dialog.querySelector('#figure-dialog-title').textContent=img.alt||'课程配图';frame.classList.remove('original');size.setAttribute('aria-pressed','false');size.textContent='原始尺寸';const source=dialog.querySelector('.figure-dialog-source');source.replaceChildren();const caption=img.closest('figure')?.querySelector('figcaption');if(caption){const safe=document.createElement('div');safe.innerHTML=window.DOMPurify?DOMPurify.sanitize(caption.innerHTML,{ALLOWED_TAGS:['a','span','em','strong','code'],ALLOWED_ATTR:['href','target','rel']}):'';while(safe.firstChild)source.append(safe.firstChild);}else source.textContent='点击“原始尺寸”查看图中细节。';dialog.showModal();}
 size.onclick=()=>{const on=frame.classList.toggle('original');size.setAttribute('aria-pressed',String(on));size.textContent=on?'适应窗口':'原始尺寸';};dialog.querySelector('[data-figure-close]').onclick=()=>dialog.close();dialog.addEventListener('close',()=>origin?.focus({preventScroll:true}));dialog.addEventListener('click',e=>{if(e.target===dialog){const r=dialog.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)dialog.close();}});
 function enhance(){document.querySelectorAll('.prose img:not(.figure-viewable)').forEach(img=>{if(img.closest('a'))return;img.classList.add('figure-viewable');img.tabIndex=0;img.setAttribute('role','button');img.setAttribute('aria-label',(img.alt||'课程配图')+'，点击放大');img.addEventListener('click',()=>open(img));img.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();open(img);}});});}
 let scheduled=false;new MutationObserver(()=>{if(!scheduled){scheduled=true;requestAnimationFrame(()=>{scheduled=false;enhance();});}}).observe(document.querySelector('main'),{childList:true,subtree:true});enhance();
})();

;
/* page-outline.js */
'use strict';
(() => {
 const main=document.querySelector('#main');if(!main||main.querySelector('.fl-home'))return;
 const dock=document.createElement('details');dock.className='page-outline';dock.innerHTML='<summary aria-label="打开本页跳转目录"><svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M8 6h13M8 12h13M8 18h13M3.5 6h.01M3.5 12h.01M3.5 18h.01"/></svg> 本页目录</summary><nav aria-label="本页跳转目录"></nav>';
 const toolbar=document.createElement('div');toolbar.className='page-outline-toolbar';
 main.before(toolbar);toolbar.append(dock);
 const topbar=document.querySelector('.topbar'),root=document.documentElement;
 root.classList.add('has-page-outline');
 const mobile=window.matchMedia('(max-width:760px)');
 const nav=dock.querySelector('nav');let serial=0,timer,last='';
 function measureToolbar(){
  const headerHeight=Math.ceil(topbar?.getBoundingClientRect().height||0);
  const toolbarHeight=mobile.matches?Math.ceil(toolbar.getBoundingClientRect().height):0;
  root.style.setProperty('--page-topbar-height',headerHeight+'px');
  root.style.setProperty('--page-outline-height',toolbarHeight+'px');
 }
 if(window.ResizeObserver){const observer=new ResizeObserver(measureToolbar);if(topbar)observer.observe(topbar);observer.observe(toolbar);}
 mobile.addEventListener('change',measureToolbar);
 function update(){
  const headings=[...main.querySelectorAll('h1,h2,h3')].filter(h=>h.getClientRects().length&&!h.closest('[hidden],dialog,details:not([open])'));
  const signature=headings.map(h=>h.tagName+'|'+h.textContent+'|'+h.id).join('\n');if(signature===last)return;
  nav.replaceChildren();
  headings.forEach(h=>{if(!h.id)h.id='page-heading-'+(++serial);const a=document.createElement('a');a.href='#'+encodeURIComponent(h.id);a.textContent=h.textContent.trim();a.className='outline-'+h.tagName.toLowerCase();a.addEventListener('click',()=>{dock.open=false;});nav.append(a);});
  if(!headings.length){const a=document.createElement('a');a.href='#main';a.textContent='页面顶部';nav.append(a);}
  last=headings.map(h=>h.tagName+'|'+h.textContent+'|'+h.id).join('\n');
 }
 new MutationObserver(()=>{clearTimeout(timer);timer=setTimeout(update,150);}).observe(main,{childList:true,subtree:true,characterData:true});
 document.addEventListener('toggle',event=>{if(event.target!==dock&&main.contains(event.target))update();},true);
 document.addEventListener('click',event=>{if(dock.open&&!dock.contains(event.target))dock.open=false;});
 document.addEventListener('keydown',event=>{if(event.key==='Escape'&&dock.open){dock.open=false;dock.querySelector('summary').focus();}});
 update();measureToolbar();window.addEventListener('resize',()=>{measureToolbar();clearTimeout(timer);timer=setTimeout(update,150);});
})();

