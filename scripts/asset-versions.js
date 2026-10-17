'use strict';
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
let versions=new Map();
hexo.extend.filter.register('before_generate',()=>{versions=new Map();});

// GitHub Pages caches files by URL. Couple every rendered page to the exact
// scripts/styles it was built with, including page-specific entry points.
hexo.extend.filter.register('after_render:html',html=>String(html).replace(
 /(<(?:script|link)\b[^>]*\b(?:src|href)\s*=\s*)(["'])(\/assets\/[^"']+\.(?:js|css)(?:[?#][^"']*)?)\2/gi,
 (tag,prefix,quote,value)=>{
  const url=new URL(value.replaceAll('&amp;','&'),'https://foamlab.invalid');
  if(!versions.has(url.pathname)){
   const bundled=hexo.foamAssetBundles?.get(url.pathname);
   if(bundled!==undefined){versions.set(url.pathname,crypto.createHash('sha256').update(bundled).digest('hex').slice(0,12));}
   else {
   const roots=[path.join(hexo.theme_dir,'source'),hexo.source_dir];
   const file=roots.map(root=>path.resolve(root,'.'+url.pathname)).find(file=>fs.existsSync(file)&&fs.statSync(file).isFile());
   if(!file)throw new Error('Referenced asset is missing: '+url.pathname);
   versions.set(url.pathname,crypto.createHash('sha256').update(fs.readFileSync(file,'utf8').replaceAll('\r\n','\n')).digest('hex').slice(0,12));
   }
  }
  url.searchParams.set('v',versions.get(url.pathname));
  return prefix+quote+(url.pathname+url.search+url.hash).replaceAll('&','&amp;')+quote;
 }
),30);
