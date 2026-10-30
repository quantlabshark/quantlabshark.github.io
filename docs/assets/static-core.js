'use strict';
(() => {
 const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 window.QuantLab={esc,$:(s,r=document)=>r.querySelector(s),safeURL(s){try{const u=new URL(s,location.origin);return /^https?:$/.test(u.protocol)?u.href:'';}catch{return '';}},reveal(host){const page=host?.closest('[data-page-state]');if(page)page.dataset.pageState='ready';}};
 const L=window.QuantLab;L.ready=L.contentReady=Promise.resolve(L);
 // Backward-compatible links open the same independently rendered article.
 if(location.pathname==='/read/'){
  const slug=new URLSearchParams(location.search).get('slug');
  if(slug&&/^[a-z0-9-]+$/.test(slug))location.replace('/read/'+slug+'/'+location.hash);
 }
 // Discard obsolete sign-in caches; the public reader never reads a session.
 try{for(const k of Object.keys(localStorage))if(/^sb-.*-auth-token$/.test(k))localStorage.removeItem(k);}catch{}
})();
