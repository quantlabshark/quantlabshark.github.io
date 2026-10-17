'use strict';
const {JSDOM}=require('jsdom');
const purify=require('../source/assets/vendor/purify.min.js')(new JSDOM('').window);
hexo.extend.helper.register('section_page_content',(key,defaults)=>{
 const saved=(hexo.locals.get('data').section_pages||[]).find(n=>n.key===key);
 const value={...defaults,...(saved?.page_content||{}),name:saved?.name||defaults.name};
 value.html=purify.sanitize(hexo.render.renderSync({text:value.body||'',engine:'markdown'}),{USE_PROFILES:{html:true},ALLOW_DATA_ATTR:false,FORBID_TAGS:['style','form','input','button','textarea','select','iframe'],FORBID_ATTR:['style','name','id']});
 return value;
});
