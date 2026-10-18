'use strict';
(()=>{
 const host=document.getElementById('curriculum-catalog');if(!host)return;
 const V=window.QuantCurriculumView,L=window.QuantLab,query=document.getElementById('curriculum-query'),pager=document.getElementById('curriculum-pagination'),all=document.getElementById('curriculum-all');
 const PAGE_SIZE=6,levels=['beginner','foundation','advanced'],labels={beginner:'入门',foundation:'基础',advanced:'进阶'};
 let level='',page=1;
 const legacy={'Python与数据':'stage-02','统计与信号':'stage-03','回测与验证':'stage-04','组合与研究':'stage-07'};
 const initial=new URLSearchParams(location.search);
 if(legacy[initial.get('track')]&&!location.hash){const u=new URL(location.href);u.hash=legacy[initial.get('track')];u.searchParams.delete('track');history.replaceState(history.state,'',u);}
 function readLocation(){const p=new URLSearchParams(location.search);query.value=p.get('q')||'';level=levels.includes(p.get('level'))?p.get('level'):'';const n=Number(p.get('page'));page=Number.isSafeInteger(n)&&n>0?n:1;}
 function rowLevel(row){const n=Number(row.querySelector('.curriculum-lesson-number').textContent.match(/\d+/)?.[0]);return n<=12?'beginner':n<=24?'foundation':'advanced';}
 function matched(){const term=query.value.trim().toLocaleLowerCase();return [...host.querySelectorAll('[data-course-row]')].filter(row=>(!level||rowLevel(row)===level)&&(!term||`${row.closest('[data-stage]').querySelector('h2').textContent} ${row.textContent}`.toLocaleLowerCase().includes(term)));}
 function save(mode='replace',hash=''){const u=new URL(location.href);for(const [k,v] of [['q',query.value.trim()],['level',level],['page',page>1?String(page):'']])v?u.searchParams.set(k,v):u.searchParams.delete(k);u.hash=hash;history[mode==='push'?'pushState':'replaceState'](history.state,'',u);document.dispatchEvent(new Event('quantlab:curriculum-change'));}
 function pages(total){const selected=new Set([1,total]);for(let n=Math.max(1,page-2);n<=Math.min(total,page+2);n++)selected.add(n);if(page<4)for(let n=1;n<=Math.min(total,5);n++)selected.add(n);if(page>total-3)for(let n=Math.max(1,total-4);n<=total;n++)selected.add(n);return [...selected].sort((a,b)=>a-b);}
 function render(){
  const rows=matched(),total=Math.max(1,Math.ceil(rows.length/PAGE_SIZE));page=Math.min(page,total);const visible=new Set(rows.slice((page-1)*PAGE_SIZE,page*PAGE_SIZE));
  for(const row of host.querySelectorAll('[data-course-row]'))row.hidden=!visible.has(row);
  for(const stage of host.querySelectorAll('[data-stage]')){const shown=stage.querySelectorAll('[data-course-row]:not([hidden])').length;stage.hidden=!shown;stage.querySelector('header>.pill').textContent=`${shown} 课`;}
  host.dataset.page=String(page);host.dataset.pages=String(total);host.dataset.level=level;
  document.getElementById('curriculum-count').textContent=`${level?labels[level]+' · ':''}${rows.length} ${query.value.trim()?'门匹配课程':'课'}`;
  document.getElementById('curriculum-empty').hidden=rows.length>0;
  for(const a of document.querySelectorAll('[data-curriculum-level]')){const active=a.dataset.curriculumLevel===level;a.classList.toggle('active',active);active?a.setAttribute('aria-current','true'):a.removeAttribute('aria-current');}
  all.setAttribute('aria-pressed',String(!level));
  const button=(n,text,disabled=false,current=false)=>`<button type="button" data-page="${n}" ${disabled?'disabled':''} ${current?'aria-current="page"':''} aria-label="${/^\d+$/.test(text)?'第 '+text+' 页':text}">${text}</button>`;
  let previous=0;const numbers=pages(total).map(n=>{const gap=previous&&n>previous+1?'<span class="curriculum-page-gap" aria-hidden="true">…</span>':'';previous=n;return gap+button(n,String(n),false,n===page);}).join('');
  pager.hidden=!rows.length;pager.innerHTML=`<p>第 ${page} / ${total} 页</p><div>${button(1,'首页',page===1)}${button(page-1,'上一页',page===1)}${numbers}${button(page+1,'下一页',page===total)}${button(total,'末页',page===total)}</div>`;
 }
 function jumpHash(){const stage=document.getElementById(location.hash.slice(1));if(!stage||!host.contains(stage))return false;let rows=matched(),index=rows.findIndex(r=>stage.contains(r));if(index<0){level='';query.value='';rows=matched();index=rows.findIndex(r=>stage.contains(r));}if(index<0)return false;page=Math.floor(index/PAGE_SIZE)+1;render();save('replace',location.hash);stage.scrollIntoView({block:'start'});return true;}
 function progress(){const done=new Set(window.foamAuth?.progress||[]);host.querySelectorAll('[data-course-row]').forEach(row=>{const complete=done.has(row.dataset.courseId),dot=row.querySelector('.curriculum-complete');dot.classList.toggle('done',complete);dot.setAttribute('aria-label',complete?'已完成':'未标记完成');});}
 function top(){host.scrollIntoView({block:'start'});host.focus({preventScroll:true});}
 pager.addEventListener('click',e=>{const button=e.target.closest('button[data-page]');if(!button||button.disabled)return;page=Number(button.dataset.page);render();save('push');top();});
 document.getElementById('curriculum-levels').addEventListener('click',e=>{const a=e.target.closest('[data-curriculum-level]');if(!a||e.ctrlKey||e.metaKey||e.shiftKey||e.altKey)return;e.preventDefault();level=a.dataset.curriculumLevel;query.value='';page=1;render();save('push');top();});
 all.addEventListener('click',()=>{level='';page=1;render();save('push');});
 query.addEventListener('input',()=>{page=1;render();save();});
 window.addEventListener('foam-auth-change',progress);window.addEventListener('hashchange',jumpHash);
 window.addEventListener('popstate',()=>{readLocation();render();if(!jumpHash())top();});
 readLocation();render();requestAnimationFrame(jumpHash);
 (async()=>{try{const D=await window.FoamDirectory.ready;if(!D.available)throw Error('directory');const node=D.nodes.find(n=>n.key==='courses');const rows=(await D.content(node)).filter(r=>r.kind==='lesson'&&r.metadata?.curriculum).sort((a,b)=>a.sort_order-b.sort_order);if(!rows.length)throw Error('empty');host.innerHTML=V.render(rows);document.getElementById('curriculum-toc').innerHTML=V.stages(rows).map(s=>`<a href="#stage-${String(s.id).padStart(2,'0')}"><span>${String(s.id).padStart(2,'0')}</span>${L.esc(s.name)}</a>`).join('');host.dataset.live='true';render();jumpHash();await window.foamAuth.profileReady;progress();}catch{document.getElementById('curriculum-sync').textContent='当前显示发布时的课程目录；实时进度暂时无法读取。';}})();
})();
