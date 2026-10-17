'use strict';
(function(root,factory){if(typeof module==='object'&&module.exports)module.exports=factory();else root.QuantTheoryView=factory();})(typeof window==='undefined'?this:window,()=>{
 const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 function chapters(rows){const groups=new Map();for(const row of [...rows].sort((a,b)=>a.sort_order-b.sort_order)){const m=row.metadata.theory_book;if(!groups.has(m.chapter))groups.set(m.chapter,{id:m.chapter,title:m.chapter_title,part:m.part,rows:[]});groups.get(m.chapter).rows.push(row);}return [...groups.values()];}
 function render(rows){let part='';return chapters(rows).map((c,i)=>{const start=c.part!==part;part=c.part;return (start?(i?'</section>':'')+`<section class="fvm-part"><h2>${esc(c.part)}</h2>`:'')+`<details class="fvm-chapter" id="chapter-${esc(c.id)}"${i===0?' open':''}><summary>${/^\d+$/.test(String(c.id))?'第 '+esc(c.id)+' 章 · ':''}${esc(c.title)}<small>${c.rows.length} 节</small></summary><ol>${c.rows.map(r=>`<li data-theory-unit><a href="/read/?slug=${encodeURIComponent(r.slug)}">${esc(r.title)}</a><p>${esc(r.summary)}</p></li>`).join('')}</ol></details>`;}).join('')+(rows.length?'</section>':'');}
 return {chapters,render};
});
