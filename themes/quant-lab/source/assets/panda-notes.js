'use strict';
(() => {
 const mark=window.foamPandaArt(true);
 const namedPrefix=/^\s*鲨鱼说(?:\s*[：:]\s*|\s+|$)/;
 function notePrefix(el){
  const host=el.matches('p,h2,h3,h4,h5,h6,summary,strong,b')?el:el.firstElementChild||el,named=host.textContent.match(namedPrefix);if(named)return named[0].length;
  const label=host.matches('strong,b')?host:host.querySelector(':scope > strong:first-child,:scope > b:first-child');
  if(label?.textContent.trim()==='鲨鱼说'){
   const prefix=document.createRange();prefix.setStart(host,0);prefix.setEndBefore(label);
   if(!prefix.toString().trim()){prefix.setEndAfter(label);return prefix.toString().length;}
  }
  return 0;
 }
 const containers='blockquote,.tip,.callout-tip,.note,.panda-note,.shark-note';
 function headingIcon(el){
  if(!el.querySelector(':scope > .panda-face'))el.insertAdjacentHTML('afterbegin',mark);
  el.classList.add('panda-note-heading');
 }
 function removePrefix(element,length){
  const walker=document.createTreeWalker(element,NodeFilter.SHOW_TEXT);
  let node=walker.nextNode(),remaining=length;
  while(node&&remaining>0){
   const count=Math.min(node.textContent.length,remaining);
   node.textContent=node.textContent.slice(count);remaining-=count;
   node=walker.nextNode();
  }
  element.querySelectorAll('strong,b').forEach(el=>{if(!el.textContent.trim())el.remove();});
 }
 function enhance(){
  // Explicit learning notes can also be paragraphs or section headings.
  // Preserve their original content, links, formulas and heading anchors.
  document.querySelectorAll('.prose p,.prose h2,.prose h3,.prose h4,.prose h5,.prose h6,.prose summary').forEach(el=>{
   if(!notePrefix(el)||el.closest('pre,code,.lab-preview,.panda-note-label'))return;
   if(el.closest(containers))return;
   if(el.matches('p')){const note=document.createElement('aside');note.className='note';el.before(note);note.append(el);}
   else headingIcon(el);
  });
  // Only explicit short learning tips, never source quotations or warnings.
  document.querySelectorAll('.prose blockquote,.prose .tip,.prose .callout-tip,.prose .note,.prose .panda-note,.prose .shark-note').forEach(el=>{
   if(el.closest('pre,code,.lab-preview'))return;
   const existing=el.querySelector(':scope > .panda-note-label');
   if(existing){headingIcon(existing);el.dataset.pandaNote='true';el.classList.add('panda-note');return;}
   const first=el.firstElementChild,lead=first?.querySelector(':scope > strong:first-child');
   const named=notePrefix(el);
   const explicit=el.matches('.tip,.callout-tip,.note,.shark-note');
   if(!named&&(el.querySelector('pre,figure,table')||el.textContent.length>450))return;
   if(!named&&!explicit&&!(lead&&/^(提示|小提示|小技巧|操作提示|学习提示)[：:]?$/.test(lead.textContent.trim())))return;
   el.dataset.pandaNote='true';el.classList.add('panda-note');
   if(named){
    // The match and removal must use the same subtree: indentation before
    // the first element is not part of the visible title.
    const prefixHost=first||el;
    removePrefix(prefixHost,named);
    if(first&&!first.id&&!first.textContent.trim()&&!first.querySelector('img,svg,math,code'))first.remove();
   }else if(lead)lead.remove();
   const label=document.createElement('div');label.className='panda-note-label panda-note-heading';label.innerHTML=mark+'<span>鲨鱼说</span>';el.prepend(label);
  });
 }
 enhance();window.addEventListener('foamlab:content-ready',enhance);document.addEventListener('foamlab:content-ready',enhance);
 const main=document.querySelector('main');if(main){let queued=false;new MutationObserver(()=>{if(queued)return;queued=true;requestAnimationFrame(()=>{queued=false;enhance();});}).observe(main,{childList:true,subtree:true});}
})();
