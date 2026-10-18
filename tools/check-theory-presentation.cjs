'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{JSDOM}=require('jsdom');
const root=path.resolve(__dirname,'..'),read=file=>fs.readFileSync(path.join(root,file),'utf8');
const V=require('../themes/quant-lab/source/assets/theory-view.js');
const registry=JSON.parse(read('tools/content/theory-books.json')),nodes=JSON.parse(read('tools/content/navigation.json'));
async function check(){
 const dom=new JSDOM(read('docs/theory/index.html'),{url:'https://quantlabshark.github.io/theory/',runScripts:'outside-only'}),w=dom.window,hub=w.document.getElementById('theory-modules');
 const expected=w.document.createElement('div');expected.innerHTML=V.hub(V.booksFromDirectory(registry,nodes));
 assert.equal(hub.innerHTML,expected.innerHTML,'Generated and live theory cards differ');
 // The page outline adds heading anchors before the directory response arrives.
 hub.querySelectorAll('h2,h3').forEach((h,i)=>h.id='page-heading-'+i);
 const cards=[...hub.querySelectorAll('.theory-book-card')];
 let mutations=0;new w.MutationObserver(records=>mutations+=records.length).observe(hub,{childList:true,subtree:true});
 let finish;w.QuantLab={esc:s=>s};w.QuantTheoryView=V;w.FoamDirectory={ready:new Promise(resolve=>finish=resolve)};
 w.eval(read('themes/quant-lab/source/assets/theory.js'));
 finish({available:true,nodes});await new Promise(resolve=>setTimeout(resolve,0));
 assert.equal(mutations,0,'Unchanged live data replaced the initial cards');
 assert(cards.every((card,i)=>hub.querySelectorAll('.theory-book-card')[i]===card),'Card identity changed');
 // Live edits must still be applied, using the same directory resolver.
 const changed=nodes.map(n=>n.key==='mathematical-statistics'?{...n,name:'数理统计课程（更新）'}:n);
 const live=new JSDOM(read('docs/theory/index.html'),{url:'https://quantlabshark.github.io/theory/',runScripts:'outside-only'});
 live.window.QuantLab={esc:s=>s};live.window.QuantTheoryView=V;live.window.FoamDirectory={ready:Promise.resolve({available:true,nodes:changed})};
 live.window.eval(read('themes/quant-lab/source/assets/theory.js'));await new Promise(resolve=>setTimeout(resolve,0));
 assert(live.window.document.getElementById('theory-modules').textContent.includes('数理统计课程（更新）'));
 dom.window.close();live.window.close();

 const noteDOM=new JSDOM('<main><div class="prose"></div></main>',{runScripts:'outside-only'}),n=noteDOM.window,host=n.document.querySelector('.prose');
 host.innerHTML='<blockquote><p><strong>鲨鱼说</strong> 检验先指定参考分布，再比较观测统计量。</p></blockquote>'+
  '<blockquote><p>鲨鱼说：保留 <a href="/theory/">链接</a> 和 <span class="katex">公式</span>。</p></blockquote>'+
  '<blockquote><p>  <strong>鲨鱼说</strong>没有空格的说明。</p></blockquote>'+
  '<aside class="shark-note"><strong>鲨鱼说</strong><p>已有提示框。</p></aside>'+
  '<p><strong>鲨鱼说</strong> 独立段落提示。</p>'+
  '<blockquote><p>鲨鱼说法有不同含义。</p></blockquote>'+
  '<blockquote><p>引用中提及<strong>鲨鱼说</strong>，保留原样。</p></blockquote>';
 n.foamPandaArt=()=>'<svg class="panda-face" aria-hidden="true"></svg>';
 n.eval(read('themes/quant-lab/source/assets/panda-notes.js'));
 assert.equal(host.querySelectorAll('.panda-note').length,5);
 for(const note of host.querySelectorAll('.panda-note')){
  assert.equal(note.querySelectorAll(':scope > .panda-note-label').length,1);
  assert.equal(note.querySelectorAll('.panda-face').length,1);
  assert.equal((note.textContent.match(/鲨鱼说/g)||[]).length,1,'Repeated note label');
 }
 assert(host.querySelector('.panda-note a[href="/theory/"]'));assert(host.querySelector('.panda-note .katex'));
 assert(!host.lastElementChild.classList.contains('panda-note'));
 const normalized=host.innerHTML;n.document.dispatchEvent(new n.Event('foamlab:content-ready'));
 assert.equal(host.innerHTML,normalized,'Repeated enhancement changed a note');
 noteDOM.window.close();
 console.log('Theory cards match before and after live refresh; 5 shark note formats retain one avatar and label.');
}
check().catch(error=>{console.error(error);process.exitCode=1;});
