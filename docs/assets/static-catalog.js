'use strict';
(() => {
 const host=document.querySelector('[data-static-catalog]');if(!host)return;
 const input=document.getElementById('catalog-query'),cards=[...host.children],count=document.getElementById('catalog-count');
 function filter(){const q=input.value.trim().toLowerCase();let n=0;cards.forEach(c=>{c.hidden=!!q&&!c.textContent.toLowerCase().includes(q);if(!c.hidden)n++;});count.textContent=n+' 个条目';}
 input.value=new URLSearchParams(location.search).get('q')||'';input.addEventListener('input',filter);filter();
})();
