'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../docs');let pages=0;const missing=new Set();
function walk(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const file=path.join(dir,e.name);if(e.isDirectory())walk(file);else if(e.name.endsWith('.html')){pages++;const s=fs.readFileSync(file,'utf8');assert(!/nmkforbzmbstasnjxlid|foamlabshark\.github\.io/.test(s),'Old service in '+file);for(const m of s.matchAll(/(?:src|href)=["'](\/[^"'#?]*)(?:[?#][^"']*)?["']/g)){const target=path.join(root,decodeURIComponent(m[1]),m[1].endsWith('/')?'index.html':'');if(!fs.existsSync(target))missing.add(m[1]);}}}}
walk(root);const config=JSON.parse(fs.readFileSync(path.join(root,'assets/auth-config.json')));assert.equal(config.supabaseUrl,'https://skqoondpsqzvybnmcaas.supabase.co');assert.equal(missing.size,0,'Missing internal routes/assets: '+[...missing].join(', '));
// Navigation must exist before account/network requests finish, on every shell.
for(const route of ['index.html','start/index.html','courses/index.html','tools/index.html','read/index.html','interview/index.html','interview/zhou/index.html','interview/practice/index.html','theory/index.html','theory/factor-investing/index.html']){const html=fs.readFileSync(path.join(root,route),'utf8'),nav=html.match(/<nav aria-label="主要导航">([\s\S]*?)<\/nav>/)?.[1];assert(nav,'Missing main navigation '+route);for(const key of ['tools','interview','interview-zhou','interview-practice','theory','factor-investing'])assert(nav.includes('data-nav-section="'+key+'"'),'Missing fallback '+key+' in '+route);}
const questions=JSON.parse(fs.readFileSync(path.join(__dirname,'content/interview-catalog.json'),'utf8'));
for(const book of ['zhou','practice']){const html=fs.readFileSync(path.join(root,'interview',book,'index.html'),'utf8');assert.equal((html.match(/data-interview-question /g)||[]).length,questions.filter(r=>r.metadata.interview.book===book).length,'Incomplete static question catalog');}
const courses=JSON.parse(fs.readFileSync(path.join(__dirname,'content/course-catalog.json'),'utf8')),courseHTML=fs.readFileSync(path.join(root,'courses/index.html'),'utf8');
assert.equal(courses.length,66);assert.equal((courseHTML.match(/data-course-row /g)||[]).length,66);assert.equal((courseHTML.match(/class="curriculum-stage"/g)||[]).length,11);
for(const course of courses){
 const cover=course.metadata.curriculum.cover;assert(cover&&cover.startsWith('/assets/illustrations/courses/'),'Missing course cover '+course.slug);assert(fs.existsSync(path.join(root,cover)),'Missing cover image '+course.slug);
 const archive=path.join(root,'assets/downloads/courses',course.slug+'.zip');assert(fs.existsSync(archive),'Missing lesson code '+course.slug);assert.equal(fs.readFileSync(archive).subarray(0,4).toString('hex'),'504b0304','Invalid lesson archive '+course.slug);
 const figure=path.join(root,'assets/figures/curriculum','course-'+String(course.metadata.curriculum.number).padStart(2,'0')+'.svg');assert(fs.existsSync(figure),'Missing lesson figure '+course.slug);
}
assert.equal((courseHTML.match(/class="curriculum-cover"/g)||[]).length,66);
for(const [level,count] of [['beginner',12],['foundation',12],['advanced',42]])assert(courseHTML.includes('data-nav-section="curriculum-level-'+level+'"'),'Missing level '+level);
assert.equal((courseHTML.match(/data-nav-section="curriculum-lesson-/g)||[]).length,66);
const coverage=JSON.parse(fs.readFileSync(path.join(root,'assets/source-coverage.json'),'utf8')),slugs=new Set(questions.map(q=>q.slug));
assert.equal(questions.length,100);assert.equal(coverage.files.length,97);
for(const source of coverage.files)for(const slug of source.unit_slugs)assert(slugs.has(slug),'Missing source destination '+slug);
assert.equal(new Set(coverage.book_coverage.map(x=>x.pdf_page)).size,96);
const theory=JSON.parse(fs.readFileSync(path.join(__dirname,'content/theory-catalog.json'),'utf8')),books=JSON.parse(fs.readFileSync(path.join(__dirname,'content/theory-books.json'),'utf8'));
const theoryHub=fs.readFileSync(path.join(root,'theory/index.html'),'utf8');assert.equal((theoryHub.match(/class="theory-category"/g)||[]).length,3);assert.equal((theoryHub.match(/class="lab-card theory-book-card"/g)||[]).length,books.length);
for(const book of books){const rows=theory.filter(r=>r.metadata.theory_book.book===book.key),html=fs.readFileSync(path.join(root,'theory',book.key,'index.html'),'utf8');assert.equal(rows.length,book.units,book.key);assert.equal((html.match(/data-theory-unit/g)||[]).length,book.units,book.key);assert.equal(new Set(rows.map(r=>String(r.metadata.theory_book.chapter)).filter(c=>/^\d+$/.test(c))).size,book.chapters,book.key);}
const bookCoverage=JSON.parse(fs.readFileSync(path.join(root,'assets/factor-book-coverage.json'),'utf8')),theorySlugs=new Set(theory.map(r=>r.slug));
assert.equal(bookCoverage.coverage.length,422);for(const row of bookCoverage.coverage)for(const slug of row.unit_slugs)assert(theorySlugs.has(slug));
const harrisCoverage=JSON.parse(fs.readFileSync(path.join(root,'assets/harris-book-coverage.json'),'utf8'));
assert.equal(harrisCoverage.chapters.length,29);for(const chapter of harrisCoverage.chapters){assert(chapter.unit_slugs.length>0);for(const slug of chapter.unit_slugs)assert(theorySlugs.has(slug));assert.equal(chapter.missing_sections.length,0,'Missing Harris sections: '+chapter.chapter);}
const expansion=JSON.parse(fs.readFileSync(path.join(__dirname,'content/theory-expansion-coverage.json'),'utf8'));
for(const book of expansion.books){assert.equal(theory.filter(r=>r.metadata.theory_book.book===book.key).length,book.unit_count);assert.equal(book.coverage.length,book.numbered_section_count);for(const section of book.coverage){assert(section.units.length>0);for(const slug of section.units)assert(theorySlugs.has(slug),'Unlinked textbook section '+slug);}}
const practice=questions.filter(r=>r.metadata.interview.book==='practice'),groups=new Map();
for(const row of practice){const m=row.metadata.interview;assert.equal(m.topic,m.company||'其他');assert(!/[0-9]|回忆|扫描|图像|有限合伙/.test(m.topic));if(!groups.has(m.topic))groups.set(m.topic,m.chapter);assert.equal(groups.get(m.topic),m.chapter);}
for(const route of ['index.html','start/index.html','interview/practice/index.html','theory/trading-and-exchanges/index.html']){const html=fs.readFileSync(path.join(root,route),'utf8');assert(html.indexOf('data-nav-section="topics"')<html.indexOf('data-nav-section="theory"'));assert(html.includes('data-nav-section="trading-and-exchanges"'));}
const topics=JSON.parse(fs.readFileSync(path.join(__dirname,'content/topic-catalog.json'),'utf8'));
assert.equal(topics.length,136);
for(const [key,count] of [['ai',10],['alpha101',106],['factors',10],['timing',10]]){
 const html=fs.readFileSync(path.join(root,'topics',key,'index.html'),'utf8');assert.equal((html.match(/data-topic-unit /g)||[]).length,count,key);
 assert.equal(topics.filter(r=>r.metadata.topic.key===key).length,count,key);
}
const library=JSON.parse(fs.readFileSync(path.join(__dirname,'content/resource-library.json'),'utf8')),resourceHTML=fs.readFileSync(path.join(root,'resources/index.html'),'utf8');
assert.equal(library.entries.length,249);assert.equal(new Set(library.entries.map(r=>r.category)).size,12);
assert.equal((resourceHTML.match(/data-level=/g)||[]).length,library.entries.length);
assert(!resourceHTML.includes('source_document')&&!resourceHTML.includes('source_pages'));
for(const entry of library.entries)assert(/^https?:\/\//.test(entry.url),entry.title);
const experience=JSON.parse(fs.readFileSync(path.join(__dirname,'content/interview-experience.json'),'utf8'));
assert.equal(experience.entries.length,23);assert.equal(experience.platform_links.length,3);
assert(!fs.existsSync(path.join(root,'2022')),'Legacy blog in deployment');
console.log('Checked '+pages+' pages: internal links, service config, navigation, 66 system lessons, 100 interview units, '+theory.length+' theory units, 136 topic lessons, 249 resources and 23 experience records passed.');
