'use strict';
(() => {
 const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const lab=window.QuantLab={esc};
 const safeURL=s=>{try{const u=new URL(s,location.origin);return /^https?:$/.test(u.protocol)?u.href:'';}catch{return '';}};
 lab.markdown=body=>{
  const math=[];
  body=window.FoamMathSource.transform(body,({tex,display})=>{
   const i=math.push({tex,display})-1;return '<span data-foam-math="'+i+'"></span>';
  });
  const holder=document.createElement('div');holder.innerHTML=DOMPurify.sanitize(marked.parse(body,{gfm:true,breaks:false}),{USE_PROFILES:{html:true},ALLOW_DATA_ATTR:false,ADD_ATTR:['data-foam-math'],FORBID_TAGS:['style','form','input','button','textarea','select','option','label','iframe','object','embed','video','audio'],FORBID_ATTR:['style','id']});
  holder.querySelectorAll('a').forEach(a=>{const u=safeURL(a.getAttribute('href'));if(!u)a.removeAttribute('href');else{a.href=u;const url=new URL(u),questionImage=a.closest('.book-exercise-pages')&&url.pathname.startsWith('/assets/exercises/')&&/\.(webp|png|jpg)$/i.test(url.pathname);if(url.origin!==location.origin||questionImage){a.target='_blank';a.rel='noopener noreferrer';}}});
  holder.querySelectorAll('img').forEach(img=>{const u=safeURL(img.getAttribute('src'));if(!u)img.remove();else{img.src=u;img.loading='lazy';}});
  holder.querySelectorAll('pre').forEach(pre=>{pre.classList.add('lab-code');pre.tabIndex=0;const panel=document.createElement('div');panel.className='code-panel';pre.replaceWith(panel);const tools=document.createElement('div');tools.className='code-toolbar';const lang=pre.querySelector('code')?.className.match(/language-([\w+-]+)/)?.[1]||'text',label=({cpp:'C++',bash:'Bash / 终端',python:'Python',text:'文本 / 日志',plaintext:'文本 / 日志',prompt:'提示词'})[lang]||lang,lines=Math.max(1,pre.textContent.replace(/\n$/,'').split('\n').length);if(lang==='prompt')panel.classList.add('wrap-lines');pre.setAttribute('aria-label',lang==='prompt'?'可复制的提示词':label+'代码');tools.innerHTML='<span class="code-language">'+esc(label)+'</span><span class="code-lines">'+lines+' 行</span><button type="button" data-lab-wrap aria-pressed="'+(lang==='prompt'?'true':'false')+'">自动换行</button><button type="button" data-lab-copy>'+ (lang==='prompt'?'复制提示词':'复制代码')+'</button>';panel.append(tools,pre);});
  holder.querySelectorAll('table').forEach(table=>{if(table.parentElement.classList.contains('table-scroll'))return;const scroll=document.createElement('div');scroll.className='table-scroll';scroll.tabIndex=0;scroll.setAttribute('role','region');scroll.setAttribute('aria-label','表格，可横向滚动');table.replaceWith(scroll);scroll.append(table);});
  window.FoamInlineCode?.decorate(holder);
  holder.querySelectorAll('h2,h3').forEach((h,i)=>h.id='section-'+i);
  holder.querySelectorAll('h4,h5,h6').forEach((h,i)=>h.id='detail-'+i);
  // Decorate prose and code before expanding formulas into thousands of DOM
  // nodes. Repeated symbols share markup only within this rendering operation.
  const mathMarkup=new Map();
  holder.querySelectorAll('[data-foam-math]').forEach(el=>{const item=math[Number(el.dataset.foamMath)];if(!item){el.remove();return;}if(window.katex){try{const key=String(item.display)+':'+item.tex;if(mathMarkup.has(key))el.replaceChildren(...mathMarkup.get(key).map(node=>node.cloneNode(true)));else{katex.render(item.tex,el,{displayMode:item.display,throwOnError:true,trust:false,maxExpand:1000});mathMarkup.set(key,[...el.childNodes].map(node=>node.cloneNode(true)));}}catch{el.className='math-error';el.textContent=item.tex;}}else{el.className='math-pending';el.dataset.mathDisplay=String(item.display);el.textContent=item.tex;}});
  if(math.length&&!window.katex)window.FoamMathRenderer.enhance();
  return holder.innerHTML;
 };
 const downloadKey=value=>{const href=safeURL(value);if(!href)return '';const u=new URL(href);return [location.origin,'https://quantlabshark.github.io'].includes(u.origin)?u.pathname:u.href;};
 lab.courseDownloads=item=>{
  const manifest=window.QuantDownloadManifest||{},files=new Map();
  for(const d of (Array.isArray(item.metadata?.downloads)?item.metadata.downloads:[])){if(!d||typeof d!=='object'||!safeURL(d.url))continue;const url=safeURL(d.url),key=downloadKey(url),known=manifest[key];files.set(key,{...d,...known,url,label:String(d.label||known?.label||'下载案例')});}
  for(const match of String(item.body||'').matchAll(/\[([^\]]+)\]\(([^\s)]+)\)/g)){const url=safeURL(match[2]),key=downloadKey(url),known=manifest[key];if(known&&!files.has(key))files.set(key,{...known,url,label:known.label||match[1]});}
  // Keep run instructions with the attachment when a section contains only a download and prose.
  const sections=String(item.body||'').replace(/\r/g,'').matchAll(/^#{2,3} (?:配套代码|代码与附件|配套程序|示例代码|代码下载|本课代码|配套示例|本课案例与附件)\s*\n([\s\S]*?)(?=^#{1,3} |$(?![\s\S]))/gm);
  for(const section of sections){const text=section[1];if(/^(?:```|~~~|\|)|!\[/m.test(text))continue;const links=[...text.matchAll(/\[([^\]]+)\]\(([^\s)]+)\)/g)],keys=[...new Set(links.map(m=>downloadKey(m[2])))];if(keys.length!==1||!files.has(keys[0]))continue;const description=text.replace(/\[[^\]]+\]\([^\s)]+\)/g,'').replace(/`([^`]+)`/g,'$1').replace(/^[\s。·|｜,，;；、]+|[\s。·|｜,，;；、]+$/g,'').replace(/\s*\n\s*/g,' ');if(description&&!/[<>]/.test(description))files.get(keys[0]).description=description;}
  return [...files.values()].slice(0,20);
 };
 lab.articleBody=item=>{
  const host=document.createElement('div');host.innerHTML=lab.markdown(item.body);
  const downloads=new Set(lab.courseDownloads(item).map(d=>downloadKey(d.url)));
  for(const h of [...host.querySelectorAll('h2,h3')]){
   if(!/^(配套代码|代码与附件|配套程序|示例代码|代码下载|本课代码|配套示例|本课案例与附件)$/.test(h.textContent.trim()))continue;
   const nodes=[];let next=h.nextElementSibling;while(next&&!/^H[123]$/.test(next.tagName)){nodes.push(next);next=next.nextElementSibling;}
   const links=nodes.flatMap(n=>[...n.querySelectorAll('a[href]')]);
   if(links.length&&links.every(a=>downloads.has(downloadKey(a.href)))&&nodes.every(n=>n.tagName==='P'&&!n.querySelector('pre,img,table,aside,details,ul,ol'))){for(const n of nodes)n.remove();h.remove();}
  }
  for(const p of host.querySelectorAll('p')){
   const links=[...p.querySelectorAll('a[href]')].filter(a=>downloads.has(downloadKey(a.href)));if(!links.length)continue;
   const rest=p.cloneNode(true);rest.querySelectorAll('a[href]').forEach(a=>{if(downloads.has(downloadKey(a.href)))a.remove();});
   const text=rest.textContent.replace(/^[\s。·|｜,，;；、]+|[\s。·|｜,，;；、]+$/g,'');
   if(!rest.querySelector('a,code,pre,img')&&(!text||/^(?:压缩包|代码包|附件)(?:中)?(?:包含|含有|提供)[^。！？\n]*[。]?$/.test(text))){p.remove();continue;}
   // Keep other navigation links while moving the download into its attachment box.
   if([...p.childNodes].every(n=>n.nodeType===3?/^[\s·|｜、。]*$/.test(n.textContent):n.nodeName==='A')){
    for(const a of links){const before=a.previousSibling,after=a.nextSibling;if(before?.nodeType===3)before.textContent=before.textContent.replace(/[\s·|｜、。]+$/,'');else if(after?.nodeType===3)after.textContent=after.textContent.replace(/^[\s·|｜、。]+/,'');a.remove();}
   }
  }
  for(const h of [...host.querySelectorAll('h2,h3')].reverse())if(/^(配套代码|代码与附件|配套程序|示例代码|代码下载|本课代码|配套示例|本课案例与附件)$/.test(h.textContent.trim())&&(!h.nextElementSibling||/^H[23]$/.test(h.nextElementSibling.tagName)))h.remove();
  return host.innerHTML;
 };
 lab.fileSize=n=>Number.isFinite(Number(n))&&Number(n)>0?(n>=1048576?(n/1048576).toFixed(1)+' MB':Math.ceil(n/1024)+' KB'):'';
 lab.downloadLink=(d,cls='')=>'<a class="'+cls+'" href="'+esc(d.url)+'" '+(new URL(d.url).origin===location.origin?'download':'target="_blank" rel="noopener noreferrer"')+'><span>↓ '+esc(d.label)+'</span><span>'+esc(lab.fileSize(d.size_bytes))+'</span></a>';
 lab.topicLinks=item=>{const D=window.FoamDirectory;if(D?.available){const nodes=(item.section_ids||[]).map(D.get).filter(n=>n&&D.isVisible(n));return nodes.length?'<nav class="lesson-topic-links" aria-label="所在目录">'+nodes.map(n=>'<a href="'+esc(D.url(n))+'">'+esc(D.path(n.id))+' →</a>').join('')+'</nav>':'';}const keys=Array.isArray(item.metadata?.topics)?item.metadata.topics:[];return keys.some(x=>lab.topicLabels[x])?'<nav class="lesson-topic-links" aria-label="相关专题">'+keys.filter(x=>lab.topicLabels[x]).map(key=>'<a href="/topics/'+key+'/">'+esc(lab.topicLabels[key])+'专题 →</a>').join('')+'</nav>':'';};
 lab.downloadPanel=item=>{const files=lab.courseDownloads(item);if(!files.length)return '';return '<section class="lesson-downloads" id="lesson-downloads" aria-label="对应案例下载"><header><h2>'+(item.kind==='lesson'?'本课案例与附件':'附件下载')+'</h2><span>'+files.length+' 个附件</span></header>'+files.map(d=>'<div class="lesson-download-row">'+lab.downloadLink(d)+'<p>'+esc(d.description||'下载后先阅读包内说明。')+'</p></div>').join('')+'</section>';};

})();
