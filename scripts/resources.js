'use strict';
const fs=require('node:fs'),path=require('node:path');
hexo.extend.helper.register('quant_resources',()=>JSON.parse(fs.readFileSync(path.join(hexo.base_dir,'tools/content/resource-library.json'),'utf8')));
