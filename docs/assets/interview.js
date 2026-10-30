'use strict';
(() => {
 const L=window.QuantLab,V=window.QuantInterviewView,esc=L.esc;
 const page=document.querySelector('[data-interview-book]'),host=document.getElementById('interview-catalog');
 if(page&&host){
  const query=document.getElementById('interview-query'),difficulty=document.getElementById('interview-difficulty'),expand=document.getElementById('interview-expand'),params=new URLSearchParams(location.search);
  query.value=params.get('q')||'';difficulty.value=params.get('difficulty')||'';
  function filter(save=true){
   const term=query.value.trim().toLocaleLowerCase(),level=difficulty.value;let count=0;
   for(const ch of host.querySelectorAll('.interview-chapter')){let visible=0;const title=ch.querySelector('summary').textContent.toLocaleLowerCase();for(const row of ch.querySelectorAll('[data-interview-question]')){row.hidden=!!((term&&!`${title} ${row.textContent}`.toLocaleLowerCase().includes(term))||(level&&row.dataset.difficulty!==level));if(!row.hidden)visible++;}ch.hidden=visible===0;if((term||level)&&visible)ch.open=true;count+=visible;}
   document.getElementById('interview-result').textContent=`${count} ${term||level?'个匹配的阅读单元':'个阅读单元'}`;
   document.getElementById('interview-empty').hidden=count!==0;
   if(save){const u=new URL(location.href);for(const [key,value] of [['q',query.value],['difficulty',level]])value?u.searchParams.set(key,value):u.searchParams.delete(key);history.replaceState(history.state,'',u);}
   updateExpand();
  }
  function updateExpand(){const chapters=[...host.querySelectorAll('.interview-chapter:not([hidden])')],all=chapters.length>0&&chapters.every(c=>c.open);expand.textContent=all?'收起全部':'展开全部';expand.setAttribute('aria-expanded',String(all));}
  function openHash(){const target=document.getElementById(location.hash.slice(1));if(!target||!host.contains(target))return;if(target.hidden){query.value='';difficulty.value='';filter();}target.open=true;target.scrollIntoView({block:'start'});}
  host.addEventListener('toggle',updateExpand,true);query.addEventListener('input',()=>filter());difficulty.addEventListener('change',()=>filter());
  expand.addEventListener('click',()=>{const open=expand.getAttribute('aria-expanded')!=='true';for(const ch of host.querySelectorAll('.interview-chapter:not([hidden])'))ch.open=open;updateExpand();});
  window.addEventListener('hashchange',openHash);window.addEventListener('popstate',()=>{const u=new URLSearchParams(location.search);query.value=u.get('q')||'';difficulty.value=u.get('difficulty')||'';filter(false);});filter(false);openHash();
 }
 function revealAnswerHash(){let target;try{target=document.getElementById(decodeURIComponent(location.hash.slice(1)));}catch{}if(!target)return;const details=target.closest('.interview-answer');if(details){details.open=true;requestAnimationFrame(()=>target.scrollIntoView({block:'start'}));}}
 window.addEventListener('hashchange',revealAnswerHash);
 async function reader(item){
  const meta=item?.metadata?.interview,article=document.getElementById('live-article'),prose=article?.querySelector('.prose');
  if(!meta||!prose||prose.dataset.interviewReady)return;prose.dataset.interviewReady='true';
  const bookURL='/interview/'+meta.book+'/',label=meta.book==='zhou'?'经典书籍题解':'笔面试实战';
  document.querySelector('.lab-reader')?.classList.add('has-chapters');
  const heading=[...prose.querySelectorAll('h2')].find(h=>h.textContent==='参考解答'),source=[...prose.querySelectorAll('h2')].find(h=>h.textContent==='来源与说明');
  if(heading&&!meta.full_source){const details=document.createElement('details');details.className='interview-answer';const summary=document.createElement('summary');summary.textContent='查看解答与追问';details.append(summary);heading.before(details);let current=heading;while(current&&current!==source){const next=current.nextSibling;details.append(current);current=next;}const revealHash=()=>{let target;try{target=document.getElementById(decodeURIComponent(location.hash.slice(1)));}catch{}if(target&&details.contains(target)){details.open=true;requestAnimationFrame(()=>target.scrollIntoView({block:'start'}));}};revealHash();window.addEventListener('hashchange',revealHash);}
  const answers=[...prose.querySelectorAll('details.interview-answer')];
  if(answers.length){
   const toolbar=document.createElement('div');toolbar.className='interview-answer-tools';toolbar.innerHTML='<p>本页 '+answers.length+' 组解答 · 点击题目下方“查看解答”展开</p><button type="button" class="button secondary" aria-expanded="false">展开本页解答</button>';prose.before(toolbar);
   const button=toolbar.querySelector('button'),update=()=>{const all=answers.every(d=>d.open);button.textContent=all?'收起本页解答':'展开本页解答';button.setAttribute('aria-expanded',String(all));};
   button.addEventListener('click',()=>{const open=button.getAttribute('aria-expanded')!=='true';answers.forEach(d=>d.open=open);update();});prose.addEventListener('toggle',update,true);revealAnswerHash();update();
  }
  const nav=document.createElement('nav');nav.className='lesson-navigation interview-reader-nav';nav.setAttribute('aria-label','阅读单元翻页');nav.innerHTML=`<a href="${bookURL}#chapter-${esc(meta.chapter)}">← 返回${meta.book==='zhou'?'本章':'公司'}目录</a>`;article.querySelector('.lesson-actions')?.before(nav);
  try{
   const D=await window.FoamDirectory.ready;if(!D.available)return;const node=D.nodes.find(n=>n.key==='interview-'+meta.book);if(!node)return;
   const rows=(await D.content(node)).filter(r=>r.metadata?.interview?.book===meta.book).sort((a,b)=>a.sort_order-b.sort_order),index=rows.findIndex(r=>r.slug===item.slug);if(index<0)return;
   const prev=rows[index-1],next=rows[index+1],control=(r,text)=>r?`<a class="chapter-control" href="/read/?slug=${encodeURIComponent(r.slug)}" title="${esc(r.title)}">${text}</a>`:`<button class="chapter-control" type="button" disabled>${text}</button>`;
   nav.innerHTML=`<div class="chapter-heading"><div><span>${label} · ${esc(meta.topic)}</span><strong>第 ${index+1} / ${rows.length} 节</strong></div><a href="${bookURL}#chapter-${esc(meta.chapter)}">${meta.book==='zhou'?'本章':'公司'}目录 ↗</a></div><div class="chapter-controls">${control(prev,'← 上一节')}${control(next,'下一节 →')}</div><div class="chapter-neighbors"><p><span>上一节</span><strong>${esc(prev?.title||'已是第一节')}</strong></p><p><span>下一节</span><strong>${esc(next?.title||'已是最后一节')}</strong></p></div>`;
   const outline=document.getElementById('reader-chapters');if(outline){outline.hidden=false;outline.querySelector('summary').textContent=`本册目录 · ${rows.length} 节`;outline.querySelector('.chapter-series').textContent=label;document.getElementById('chapter-list').innerHTML=V.chapters(rows).map(c=>`<p class="interview-outline-heading">${esc(c.title)}</p>`+c.rows.map(r=>`<a href="/read/?slug=${encodeURIComponent(r.slug)}"${r.slug===item.slug?' aria-current="page"':''}>${String(r.metadata.interview.number).padStart(2,'0')} · ${esc(r.title)}</a>`).join('')).join('');}
  }catch{nav.insertAdjacentHTML('beforeend','<p class="muted">阅读顺序暂时无法读取，请从目录继续。</p>');}
 }
 document.addEventListener('foamlab:content-ready',e=>queueMicrotask(()=>reader(e.detail)));if(window.foamCurrentContent)queueMicrotask(()=>reader(window.foamCurrentContent));
})();
