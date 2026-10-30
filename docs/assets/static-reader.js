'use strict';
(() => {
 const data=document.getElementById('static-article-data'),article=document.getElementById('static-article');if(!data||!article)return;
 const item=JSON.parse(data.textContent),parent=item.parent;
 for(const [id,text] of [['breadcrumb-parent',parent.label],['page-back-link','← 返回'+parent.label]]){const a=document.getElementById(id);if(a){a.href=parent.url;a.textContent=text;}}
 const answers=[...article.querySelectorAll('details.interview-answer')];
 if(answers.length){const bar=document.createElement('div');bar.className='interview-answer-tools';bar.innerHTML='<p>点击题目下方“查看解答”展开</p><button type="button" class="button secondary" aria-expanded="false">展开本页解答</button>';article.querySelector('.prose').before(bar);const b=bar.querySelector('button'),update=()=>{const all=answers.every(d=>d.open);b.textContent=all?'收起本页解答':'展开本页解答';b.setAttribute('aria-expanded',String(all));};b.onclick=()=>{const open=b.getAttribute('aria-expanded')!=='true';answers.forEach(d=>d.open=open);update();};article.addEventListener('toggle',update,true);}
 function reveal(){let id;try{id=decodeURIComponent(location.hash.slice(1));}catch{return;}const node=document.getElementById(id);if(!node)return;for(let p=node.parentElement;p;p=p.parentElement)if(p.matches('details'))p.open=true;requestAnimationFrame(()=>node.scrollIntoView({block:'start'}));}
 window.addEventListener('hashchange',reveal);reveal();
})();
