'use strict';
// The learning overview is a page, not a chronological blog index.
hexo.extend.generator.register('index', () => []);
hexo.extend.helper.register('learning', () => hexo.locals.get('data').learning);
hexo.extend.helper.register('breadcrumb_parent', page => {
  const home={url:'/',label:'学习概览'},path=String(page.path||'');
  if(page.layout==='interview-book')return {url:'/interview/',label:'量化笔试与面试'};
  if(page.layout==='theory-book')return {url:'/theory/',label:'基础理论与原理'};
  if(['commands/index.html','dictionaries/index.html'].includes(path))return {url:'/quick-reference/',label:'速查手册'};
  if(/^[^/]+\/index\.html$/.test(path))return home;
  if(page.section==='admin'||path.startsWith('admin/'))return {url:'/admin/',label:'管理平台'};
  const labels={courses:'系统学习',lessons:'课程目录',topics:'专题学习',programming:'Python 实践',tools:'工具生态',resources:'资料中心',recommendations:'资料中心',sharing:'实践与分享',authors:'实践与分享',community:'讨论中心',assignments:'作业与实践',announcements:'网站公告',studio:'个人中心'};
  const section=page.section||path.split('/')[0],name=labels[section];
  if(!name)return home;
  const route=({lessons:'courses',studio:'account',authors:'sharing',recommendations:'resources'})[section]||section;
  if(path===route+'/index.html')return home;
  return {url:'/'+route+'/',label:name};
});
hexo.extend.helper.register('icon', name => {
  const paths = {
    home: '<path d="m3 10 9-7 9 7v10H3z"/><path d="M9 20v-7h6v7"/>',
    chart: '<path d="M4 3v17h17M8 15v-4m5 4V6m5 9V9"/>',
    book: '<path d="M12 6c-3-3-7-3-10-2v15c3-1 7-1 10 2 3-3 7-3 10-2V4c-3-1-7-1-10 2Zm0 0v15"/>',
    terminal: '<path d="m5 7 4 5-4 5m8 0h6"/><rect x="2" y="3" width="20" height="18" rx="3"/>',
    file: '<path d="M14 2H5v20h14V7zM14 2v6h5M8 12h8m-8 4h6"/>',
    bubble: '<circle cx="12" cy="10" r="7"/><path d="M3 22h18M12 17v5"/>',
    task: '<rect x="5" y="4" width="15" height="18" rx="2"/><path d="M9 4V2h6v2m-7 8 2 2 5-5M9 18h7"/>',
    bell: '<path d="M18 8a6 6 0 0 0-12 0c0 8-3 8-3 10h18c0-2-3-2-3-10M9 21h6"/>',
    chat: '<path d="M21 11a9 9 0 0 1-9 9H4l-3 2 2-7a9 9 0 1 1 18-4Z"/><path d="M7 9h9m-9 5h6"/>',
    download: '<path d="M12 2v14m-5-5 5 5 5-5M3 16v6h18v-6"/>',
    search: '<circle cx="10" cy="10" r="7"/><path d="m16 16 5 5"/>',
    arrow: '<path d="M4 12h16m-6-6 6 6-6 6"/>',
    check: '<path d="m5 12 4 4L19 6"/>',
    grid: '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
    github: '<path d="M9 20c-5 1-5-3-7-3m14 5v-4c0-1-.3-2-1-2 4-.5 7-2 7-6 0-2-1-3-2-4 0-1 0-3-1-4-2 0-4 1-4 1-2-.5-4-.5-6 0 0 0-2-1-4-1-1 1-1 3-1 4-1 1-2 2-2 4 0 4 3 5.5 7 6-.7.5-1 1-1 2v4"/>',
    menu:'<path d="M4 6h16M4 12h16M4 18h16"/>'
  };
  return '<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'+(paths[name]||paths.book)+'</svg>';
});

hexo.extend.helper.register('course_count',()=>{const fs=require('node:fs'),path=require('node:path');return JSON.parse(fs.readFileSync(path.join(hexo.base_dir,'tools/content/course-catalog.json'),'utf8')).length;});
