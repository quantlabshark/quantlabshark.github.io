'use strict';
const fs=require('node:fs'),path=require('node:path'),{Marked}=require('marked'),{JSDOM}=require('jsdom'),DOMPurify=require('dompurify'),presentation=require('./presentation.cjs');
const marked=new Marked({gfm:true,breaks:false});
const window=new JSDOM('',{url:'https://quantlabshark.github.io'}).window;
const purify=DOMPurify(window),esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const base='https://quantlabshark.github.io';
const url=slug=>'/read/'+encodeURIComponent(slug)+'/';
function rewrite(html){return html.replace(/(href=["'])(?:https:\/\/quantlabshark\.github\.io)?\/read\/\?slug=([a-z0-9-]+)(?:&amp;[^"'#]*)?(#[^"']*)?(["'])/g,(_,a,s,h,b)=>a+url(s)+(h||'')+b);}
let renderer;
function render(item){
 if(!renderer){
  // Use the established reader's Markdown/download cleanup so duplicate code
  // links and attachment descriptions retain their existing presentation.
  window.QuantDownloadManifest=JSON.parse(fs.readFileSync(path.join(__dirname,'../source-quant/assets/downloads-manifest.js'),'utf8').split('=',2)[1].trim().replace(/;$/,''));
  window.DOMPurify=purify;window.marked=marked;
  window.FoamMathSource=require('../themes/quant-lab/source/assets/math-source.js');
  window.FoamMathRenderer={enhance(){}};
  window.FoamInlineCode={decorate(){}};
  const original=fs.readFileSync(path.join(__dirname,'reader-renderer.js'),'utf8');
  window.eval=undefined;
  new Function('window','document','location','DOMPurify','marked',original)(window,window.document,window.location,purify,marked);
  renderer=window.QuantLab;
 }
 const raw=renderer.articleBody(item),holder=window.document.createElement('div');holder.innerHTML=raw;
 holder.querySelectorAll('.math-pending').forEach(el=>{el.className='tex-source';el.dataset.tex=el.textContent;el.dataset.display=el.dataset.mathDisplay;});
 holder.querySelectorAll('img').forEach(img=>{if(img.src.startsWith(base))img.setAttribute('src',img.src.slice(base.length));});
 holder.querySelectorAll('a').forEach(a=>{if(a.href.startsWith(base))a.setAttribute('href',a.href.slice(base.length));});
 return {html:rewrite(presentation.render('<div class="prose">'+holder.innerHTML+'</div>')),downloads:rewrite(renderer.downloadPanel(item))};
}
function group(row){const m=row.metadata||{};return m.interview?'interview:'+m.interview.book:m.theory_book?'theory:'+m.theory_book.book:m.topic?'topic:'+m.topic.key:m.curriculum?'curriculum':row.series?'series:'+row.series:'';}
function parent(row){const m=row.metadata||{};if(m.interview)return {url:'/interview/'+m.interview.book+'/',label:m.interview.book==='zhou'?'经典书籍题解':'笔面试实战'};if(m.theory_book)return {url:'/theory/'+m.theory_book.book+'/',label:row.series||'基础理论与原理'};if(m.topic)return {url:'/topics/'+m.topic.key+'/',label:row.series||'专题学习'};if(m.curriculum)return {url:'/courses/',label:'系统学习'};const k={tool:['tools','工具生态'],resource:['resources','资料中心'],recommendation:['resources','资料中心'],assignment:['assignments','作业与实践'],announcement:['announcements','网站公告'],reference:['quick-reference','速查手册'],article:['sharing','实践与分享']};const p=k[row.kind]||['programming','Python 实践'];return {url:'/'+p[0]+'/',label:p[1]};}
function title(row){const n=row.metadata?.topic?.number;return n?String(n).padStart(2,'0')+' · '+row.title:row.title;}
function card(r){return `<article class="lab-card"><a class="lab-card-main" href="${url(r.slug)}">${r.cover_url?`<img src="${esc(r.cover_url)}" alt="" loading="lazy">`:''}<div class="lab-card-body"><span class="lab-meta">${esc(r.track||r.series||'QuantLab')}</span><h3>${esc(r.title)}</h3><p>${esc(r.summary)}</p><span class="lab-card-link">阅读全文 →</span></div></a></article>`;}
module.exports={esc,url,rewrite,render,group,parent,title,card};
