'use strict';
const fs=require('node:fs'),path=require('node:path');

// Keep original order and licenses. These files are build outputs, not source
// mutations; the release inventory and versioned asset URLs remain reproducible.
const groups={
 'site-extras.css':['search-matches.css'],
 'site-core.css':['vendor/katex/katex.min.css','site.css','presentation.css','lab.css','home.css','support.css','footer-contact.css','lesson-navigation.css','refinements.css','typography.css','courses.css','topics.css','reader.css','page-outline.css','navigation.css','panda-pet.css','panda-animation.css','panda-character.css','foamlab-theme.css','palettes.css','directory.css','resources-hub.css','sidebar-resize.css'],
 'runtime-content.js':['vendor/purify.min.js','static-core.js'],
 'runtime-math.js':['vendor/katex/katex.min.js'],
 'runtime-ui.js':['directory.js','browser-code.js','footer-contact.js','refinements.js','figure-viewer.js','page-outline.js'],
 'runtime-panda-art.js':['panda-art.js'],
};
hexo.foamAssetBundles=new Map();
hexo.extend.helper.register('foam_bundle_url',name=>{
 const url='/assets/'+name,body=hexo.foamAssetBundles.get(url);
 if(body===undefined)throw Error('Missing asset bundle: '+name);
 return url+'?v='+require('node:crypto').createHash('sha256').update(body).digest('hex').slice(0,12);
});
function build(){
 hexo.foamAssetBundles.clear();
 for(const [name,files] of Object.entries(groups)){
  const css=name.endsWith('.css');
  const body=files.map(file=>{
   let text=fs.readFileSync(path.join(hexo.theme_dir,'source/assets',file),'utf8').replaceAll('\r\n','\n');
   if(css)text=text.replace(/url\(\s*(['"]?)([^'"\s)]+)\1\s*\)/g,(match,quote,url)=>{
    if(/^(?:[a-z][a-z\d+.-]*:|\/|#)/i.test(url))return match;
    const resolved=new URL(url,'https://assets.invalid/assets/'+file);
    return 'url("'+resolved.pathname+resolved.search+resolved.hash+'")';
   });
   return '/* '+file+' */\n'+text;
  }).join(css?'\n':'\n;\n');
  hexo.foamAssetBundles.set('/assets/'+name,body+'\n');
 }
}
hexo.extend.filter.register('before_generate',build);
hexo.extend.generator.register('foam-asset-bundles',()=>[...hexo.foamAssetBundles].map(([url,data])=>({path:url.slice(1),data})));
