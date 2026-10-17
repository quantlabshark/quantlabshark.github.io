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
const coverage=JSON.parse(fs.readFileSync(path.join(root,'assets/source-coverage.json'),'utf8')),slugs=new Set(questions.map(q=>q.slug));
assert.equal(questions.length,100);assert.equal(coverage.files.length,97);
for(const source of coverage.files)for(const slug of source.unit_slugs)assert(slugs.has(slug),'Missing source destination '+slug);
assert.equal(new Set(coverage.book_coverage.map(x=>x.pdf_page)).size,96);
const theory=JSON.parse(fs.readFileSync(path.join(__dirname,'content/theory-catalog.json'),'utf8')),theoryHTML=fs.readFileSync(path.join(root,'theory/factor-investing/index.html'),'utf8');
assert.equal(theory.length,47);assert.equal((theoryHTML.match(/data-theory-unit/g)||[]).length,47);
const bookCoverage=JSON.parse(fs.readFileSync(path.join(root,'assets/factor-book-coverage.json'),'utf8')),theorySlugs=new Set(theory.map(r=>r.slug));
assert.equal(bookCoverage.coverage.length,422);for(const row of bookCoverage.coverage)for(const slug of row.unit_slugs)assert(theorySlugs.has(slug));
console.log('Checked '+pages+' pages: internal links, service config, navigation, 66 system lessons, 100 interview units, 97 source records and 47 theory units passed.');
