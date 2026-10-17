'use strict';
const fs=require('node:fs'),path=require('node:path');
const root=hexo.base_dir,target=path.join(root,'themes/quant-lab/source/assets/vendor');
for(const [from,to] of [['dompurify/dist/purify.min.js','purify.min.js'],['marked/lib/marked.umd.js','marked.js'],['katex/dist/katex.min.js','katex/katex.min.js']]){fs.mkdirSync(path.dirname(path.join(target,to)),{recursive:true});fs.copyFileSync(path.join(root,'node_modules',from),path.join(target,to));}
// Reuse the installed dependency; do not ship every language or add a bundler.
// These highlight.js CommonJS files are self-contained (no runtime require).
const wrap=file=>{const code=fs.readFileSync(path.join(root,'node_modules/highlight.js/lib',file),'utf8');if(/\brequire\s*\(/.test(code))throw Error('Unexpected highlight dependency in '+file);return '(function(){const module={exports:{}};\n'+code+'\nreturn module.exports;})()';};
let highlight='/* highlight.js; BSD-3-Clause. See highlight.LICENSE.txt. */\nself.foamHighlight='+wrap('core.js')+';\n';
for(const language of ['bash','cpp','python','json','makefile','plaintext','ini','yaml'])highlight+='self.foamHighlight.registerLanguage('+JSON.stringify(language)+','+wrap('languages/'+language+'.js')+');\n';
highlight+=`self.foamHighlight.registerLanguage('openfoam',h=>({name:'OpenFOAM dictionary',aliases:['foam','dict'],keywords:{keyword:'FoamFile dimensions internalField boundaryField type value uniform nonuniform application solver libs functions include includeIfPresent includeEtc includeFunc code codeInclude codeOptions codeLibs name object class version format location',literal:'true false yes no on off',built_in:'fixedValue zeroGradient noSlip empty wedge symmetryPlane cyclic inletOutlet fixedFluxPressure laminar RAS LES Gauss Euler backward CrankNicolson upwind linear linearUpwind limitedLinear PIMPLE SIMPLE PISO PCG PBiCGStab GAMG smoothSolver'},contains:[h.C_LINE_COMMENT_MODE,h.C_BLOCK_COMMENT_MODE,h.QUOTE_STRING_MODE,h.C_NUMBER_MODE,{className:'meta',begin:/#[A-Za-z{][^\\n]*/},{className:'variable',begin:/\\$[A-Za-z_{][\\w{}./]*/}]}));\n`;
fs.writeFileSync(path.join(target,'highlight-core.js'),highlight);
fs.copyFileSync(path.join(root,'node_modules/highlight.js/LICENSE'),path.join(target,'highlight.LICENSE.txt'));
