'use strict';
const inline=require('../themes/quant-lab/source/assets/inline-code.js');
const mathSource=require('../themes/quant-lab/source/assets/math-source.js');
const katex=require('katex');const cheerio=require('cheerio');const hljs=require('highlight.js/lib/core').newInstance();
for(const lang of ['bash','cpp','python','json','yaml','makefile','ini','plaintext','powershell','latex'])hljs.registerLanguage(lang,require('highlight.js/lib/languages/'+lang));
const escape=s=>String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
function guess(code){
 if(/^\s*#include\s*["<]|\bstd::/m.test(code))return 'cpp';
 if(/^(?:from \w+ import |import \w+|def \w+\(|class \w+[(:]|print\()/m.test(code))return 'python';
 if(/(?:^|\n)(?:\$ |#!.*(?:bash|sh)|source |cd |cp |rm |mkdir |echo |export |conda |pip |grep |git |npm |node |python )/.test(code))return 'bash';
 if(/^\s*[\[{]/.test(code)){try{JSON.parse(code);return 'json';}catch{}}
 return 'plaintext';
}
const labels={bash:'Bash / 终端',cpp:'C++',python:'Python',makefile:'Makefile',plaintext:'文本 / 日志',json:'JSON',yaml:'YAML',powershell:'PowerShell',ini:'配置文件',tex:'TeX / LaTeX',latex:'TeX / LaTeX'};
function codeHTML(source,language){if(language==='prompt')return {source,language:'prompt',label:'提示词',html:escape(source)};const lang=hljs.getLanguage(language)?language:guess(source);return {source,language:lang,label:labels[lang]||lang,html:hljs.highlight(source,{language:lang,ignoreIllegals:true}).value};}
function protectMath(markdown){
 // HTML code blocks can share a line with a preceding HTML paragraph. Encode
 // their line breaks before Markdown parsing so blank lines cannot end that
 // HTML block and turn indented source into a second, nested code block.
 return mathSource.transform(markdown,({tex,display})=>{
   const attribute=escape(tex).replace(/\r/g,'&#13;').replace(/\n/g,'&#10;').replace(/\|/g,'&#124;');
   return '<span class="tex-source" data-display="'+display+'" data-tex="'+attribute+'"></span>';
 });
}
function render(content){const $=cheerio.load(content,{},false);
 const texts=[];function walk(node){if(node.type==='text')texts.push(node);else for(const child of node.children||[])walk(child);}walk($.root()[0]);
 for(const node of texts){const parent=$(node).parent();if(parent.closest(inline.skip).length||!parent.closest(inline.prose).length)continue;
  const cell=parent.closest('td'),parameter=cell.length&&cell.index()===0&&inline.isParameterHeader(cell.closest('table').find('tr').first().children('th,td').first().text());
  const split=inline.parts(node.data,parameter);if(split.some(p=>p.code))$(node).replaceWith(split.map(p=>p.code?'<code>'+escape(p.text)+'</code>':escape(p.text)).join(''));
 }
 $('.tex-source').each((_,node)=>{const el=$(node),tex=el.attr('data-tex')||'',display=el.attr('data-display')==='true';const result=katex.renderToString(tex,{displayMode:display,throwOnError:true,trust:false,strict:'error',output:'htmlAndMathml',maxExpand:1000});el.replaceWith('<span class="math-formula'+(display?' math-display':'')+'" data-tex="'+escape(tex)+'">'+result+'</span>');});
 $('pre > code').each((_,node)=>{const code=$(node),pre=code.parent();if(pre.parent().hasClass('code-panel'))return;const source=code.text();const result=codeHTML(source,(code.attr('class')||'').match(/language-([\w-]+)/)?.[1]);code.attr('class','hljs language-'+result.language).html(result.html);pre.attr('tabindex','0').attr('aria-label',result.label+'代码');pre.wrap('<div class="code-panel'+(result.language==='prompt'?' wrap-lines':'')+'" data-language="'+result.language+'"></div>');pre.before('<div class="code-toolbar"><span class="code-language">'+result.label+'</span><span class="code-lines">'+result.source.replace(/\n$/,'').split('\n').length+' 行</span><button type="button" class="code-wrap" aria-pressed="'+(result.language==='prompt'?'true':'false')+'">自动换行</button><button type="button" class="copy-code" aria-label="复制代码">复制</button></div>');});
 $('table').each((_,node)=>{const table=$(node);if(!table.parent().hasClass('table-scroll'))table.wrap('<div class="table-scroll" tabindex="0" role="region" aria-label="表格，可横向滚动"></div>');});
 return $.html();}
module.exports={protectMath,render,codeHTML,guess};
