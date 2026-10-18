'use strict';
const fs=require('node:fs'),path=require('node:path');
hexo.extend.helper.register('interview_experience',()=>JSON.parse(fs.readFileSync(path.join(hexo.base_dir,'tools/content/interview-experience.json'),'utf8')));
