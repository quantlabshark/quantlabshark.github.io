/* panda-art.js */
/* QuantLab shark. Inline vectors, no image downloads or account dependencies.
 * Compatibility: foamPandaArt(faceOnly, label); appearance uses ancestor data-*. */
'use strict';
(() => {
  const group = (name, body) => `<g class="${name}">${body}</g>`;
  const safe = text => String(text).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const star = (x,y,size=1) => `<path class="sk-gold" transform="translate(${x} ${y}) scale(${size})" d="M0-6l1.8 4.2 4.2.4-3.2 2.9 1 4.3L0 3.6-3.8 5.8l1-4.3-3.2-2.9 4.2-.4z"/>`;

  // Shared geometry (viewBox 0 0 160 180). The head is a soft dome; the white
  // underside starts at the mouth, the way a real shark is countershaded.
  const dorsal = '<path class="sk-fin sk-outline sk-dorsal" d="M62 38C63 23 77 8 100 3c-8 11-9 23-3 34z"/>';
  const tail = '<g class="sk-tail"><path class="sk-fin sk-outline" d="M96 151c14 7 28 7 38 1 6-4 11-10 16-18 0 8-1 14-3 19 4 4 8 8 11 14-14 1-30-1-42-5-8-2-16-2-24-2z"/><path class="sk-finshine" d="M136 156c5-3 9-7 11-11 0 4-1 7-2 9z"/></g>';
  const fins = '<g class="sk-fin-left"><path class="sk-fin sk-outline" d="M36 95c-13 2-24 9-30 20 13 3 25 0 34-8z"/></g><g class="sk-fin-right"><path class="sk-fin sk-outline" d="M124 95c13 2 24 9 30 20-13 3-25 0-34-8z"/></g>';
  const body = '<path class="sk-body sk-outline" d="M80 28c33 0 54 27 54 61 0 33-18 62-42 69q-12 3-24 0c-24-7-42-36-42-69 0-34 21-61 54-61z"/><path class="sk-belly" d="M41 95c12 6 25 9 39 9s27-3 39-9c4 25-6 48-27 55q-12 4-24 0c-21-7-31-30-27-55z"/><path class="sk-bodyshine" d="M40 64c5-16 17-27 33-30-11 7-19 18-23 32z"/><circle class="sk-bodyshine" cx="43" cy="74" r="2.8"/><path class="sk-gills" d="M30 103q3 4 2 9m4-11q3 5 2 10m92-10q-3 5-2 10m4-8q-3 4-2 9"/>';
  const head = '<path class="sk-body sk-outline" d="M80 28c33 0 54 27 54 60 0 24-22 38-54 38s-54-14-54-38c0-33 21-60 54-60z"/><path class="sk-belly" d="M41 95c12 6 25 9 39 9s27-3 39-9c1 14-15 25-39 25s-40-11-39-25z"/><path class="sk-bodyshine" d="M40 64c5-16 17-27 33-30-11 7-19 18-23 32z"/>';

  const eyes = `<g class="sk-eyes-open"><g class="sk-pupils"><ellipse class="sk-eye" cx="58" cy="80" rx="7.4" ry="9"/><ellipse class="sk-eye" cx="102" cy="80" rx="7.4" ry="9"/><circle class="sk-glint" cx="60.8" cy="76.2" r="2.9"/><circle class="sk-glint" cx="104.8" cy="76.2" r="2.9"/><circle class="sk-glint" cx="55.4" cy="84" r="1.3"/><circle class="sk-glint" cx="99.4" cy="84" r="1.3"/></g></g><g class="sk-eyes-happy"><path class="sk-inkline" d="M51 83q7-9 14 0m30 0q7-9 14 0"/></g><g class="sk-eyes-closed"><path class="sk-inkline" d="M51 80q7 6 14 0m30 0q7 6 14 0"/></g>`;
  const face = `<g class="sk-face"><ellipse class="sk-cheek" cx="44" cy="96" rx="6.2" ry="3.4"/><ellipse class="sk-cheek" cx="116" cy="96" rx="6.2" ry="3.4"/>${eyes}<path class="sk-tooth" d="M69.6 104h4.6l-2.3 4.6zm16.2 0h4.6l-2.3 4.6z"/><path class="sk-inkline sk-smile" d="M63 102q17 5 34 0"/><path class="sk-mouth-open" d="M69 102.5q11 3 22 0c-1 10-5 14-11 14s-10-4-11-14z"/><path class="sk-tongue" d="M74 112.5q6-4 12 0-2 4-6 4t-6-4z"/></g>`;

  const headAccessories = [
    group('sk-o sk-glasses','<g class="sk-glasses-lines"><circle cx="58" cy="80" r="12.5"/><circle cx="102" cy="80" r="12.5"/><path d="M70.5 78q9.5-5 19 0M45.5 77l-10-3m89 3 10-3"/></g>'),
    group('sk-o sk-headphones','<path class="sk-headphone-band" d="M30 84C28 18 132 18 130 84"/><rect class="sk-purple sk-outline" x="19" y="72" width="15" height="27" rx="7.5"/><rect class="sk-purple sk-outline" x="126" y="72" width="15" height="27" rx="7.5"/>'),
    group('sk-o sk-cap sk-hat','<path class="sk-dark sk-outline" d="M57 29v12q23-8 46 0V29z"/><path class="sk-dark sk-outline" d="m80 13 37 13-37 13-37-13z"/><path class="sk-goldline" d="M111 28v17"/><circle class="sk-gold" cx="111" cy="47" r="3.2"/>'),
    group('sk-o sk-hardhat sk-hat','<path class="sk-gold sk-outline" d="M53 40c0-32 54-32 54 0z"/><rect class="sk-gold sk-outline" x="46" y="37" width="68" height="8" rx="4"/><path class="sk-goldline" d="M80 15v21M68 19l4 18m20-18-4 18"/>'),
    group('sk-o sk-strawhat sk-hat','<ellipse class="sk-straw sk-outline" cx="80" cy="40" rx="48" ry="9"/><path class="sk-straw sk-outline" d="M58 38c0-28 44-28 44 0z"/><path class="sk-ribbon" d="M59 32q21 5 42 0"/>'),
    group('sk-o sk-wizard sk-hat',`<path class="sk-purple sk-outline" d="M54 39q14-20 38-42-4 22 14 42z"/><ellipse class="sk-purple sk-outline" cx="80" cy="39" rx="36" ry="6.5"/>${star(86,20,.75)}`),
    group('sk-o sk-beanie sk-hat','<path class="sk-red sk-outline" d="M52 40c-2-30 58-30 56 0z"/><rect class="sk-knit sk-outline" x="49" y="34" width="62" height="11" rx="5.5"/><path class="sk-knitline" d="M57 36v7m8-7v7m8-7v7m8-7v7m8-7v7m8-7v7"/><circle class="sk-knit sk-outline" cx="80" cy="12" r="7"/>'),
    group('sk-o sk-flower','<g transform="translate(110 46) rotate(12)"><path class="sk-petal" d="M0-1C-6-14 6-14 1-1 12-9 15 3 2 2 10 13-2 15-1 3-10 12-15 0-2 0-14-6-8-17 0-1z"/><circle class="sk-gold" cx=".3" cy=".6" r="3.6"/></g>')
  ].join('');
  // The pack sits behind the body; its straps are drawn in front.
  const backAccessories = group('sk-o sk-backpack','<rect class="sk-pack sk-outline" x="6" y="84" width="32" height="50" rx="10"/><path class="sk-strapline" d="M10 100h14"/>');
  const bodyAccessories = [
    group('sk-o sk-backpack','<path class="sk-strap" d="M42 66c-4 24-2 46 6 64m70-64c4 24 2 46-6 64"/>'),
    group('sk-o sk-coat','<path class="sk-coatfill sk-outline" d="M28 104c1 26 14 47 36 54l16 2 16-2c22-7 35-28 36-54l-24 11-28 38-28-38z"/><path class="sk-coatline" d="M104 130h13v10h-13z"/><path class="sk-goldline" d="M108 124v9"/>'),
    group('sk-o sk-raincoat','<path class="sk-gold sk-outline" d="M28 106q52 24 104 0c-1 25-15 46-38 53q-14 3-28 0c-23-7-37-28-38-53z"/><path class="sk-goldline" d="M80 118v42"/><circle class="sk-dark" cx="86" cy="130" r="2.3"/><circle class="sk-dark" cx="86" cy="146" r="2.3"/>'),
    group('sk-o sk-scarf','<path class="sk-teal sk-outline" d="M29 110q51 23 102 0l-1 11q-50 24-100 0z"/><path class="sk-teal sk-outline" d="m97 127 14-3 2 25-13-3z"/><path class="sk-scarfline" d="m101 135 10-1m-9 6 10-1"/>'),
    group('sk-o sk-bowtie','<path class="sk-red sk-outline" d="M80 121 65 112v18zm0 0 15-9v18z"/><circle class="sk-red sk-outline" cx="80" cy="121" r="4.2"/>'),
    group('sk-o sk-book','<path class="sk-bookcover sk-outline" d="M50 124q16-5 30 3 14-8 30-3v27q-16-4-30 3-14-7-30-3z"/><path class="sk-page" d="M54 127q12-3 23 3v20q-11-5-23-3zm29 3q11-6 23-3v20q-12-2-23 3z"/><path class="sk-pageline" d="m58 133 15 2m-15 5 15 2m-15 5 10 1m28-15-15 2m15 3-15 2m15 5-10 1"/>'),
    group('sk-o sk-suit','<circle class="sk-helmet" cx="80" cy="86" r="62"/><path class="sk-helmetshine" d="M36 64q8-21 29-29"/><path class="sk-collar sk-outline" d="M33 126q47 22 94 0l1 10q-48 24-96 0z"/>')
  ].join('');
  const rides = [
    group('sk-ride sk-ride-skateboard','<path class="sk-board sk-outline" d="M34 160h92q6 0 6 5H28q0-5 6-5z"/><circle class="sk-dark" cx="48" cy="170" r="4.5"/><circle class="sk-dark" cx="112" cy="170" r="4.5"/>'),
    group('sk-ride sk-ride-bicycle','<g class="sk-wheels"><circle class="sk-wheel" cx="34" cy="158" r="18"/><circle class="sk-wheel" cx="126" cy="158" r="18"/></g><path class="sk-frame" d="M34 158l26-26h40l26 26M60 132l20 26 20-26M80 158v-8"/>'),
    group('sk-ride sk-ride-balloon','<path class="sk-string" d="M145 115c-6-25 6-44-2-74"/><path class="sk-balloon sk-outline" d="M143 41c-12 0-19-10-19-21s8-19 19-19 19 8 19 19-7 21-19 21z"/><path class="sk-balloonshine" d="M134 13q4-6 10-6"/>')
  ].join('');
  const scene = `<ellipse class="sk-shadow" cx="88" cy="168" rx="50" ry="5"/><g class="sk-decor"><ellipse class="sk-sand" cx="80" cy="168" rx="70" ry="9"/><path class="sk-sandline" d="M22 168h20m70 3h24M60 174h16"/><path class="sk-weed" d="M18 166c-6-10 6-16 0-26s4-14 2-22m120 48c5-9-5-13 0-21"/><g class="sk-bubbles"><circle cx="22" cy="96" r="5"/><circle cx="140" cy="70" r="7"/><circle cx="149" cy="50" r="3.5"/></g></g>`;
  const fx = `<g class="sk-o sk-stars">${star(22,62)}${star(140,58)}${star(128,22,.6)}</g><g class="sk-o sk-sleep"><text x="124" y="50">z</text><text x="136" y="34">Z</text></g><g class="sk-o sk-music"><path class="sk-noteline" d="M22 60V44l10-2v15"/><circle class="sk-teal" cx="19" cy="60" r="3.6"/><circle class="sk-teal" cx="29" cy="57" r="3.6"/></g>`;
  const character = () => `<g class="sk-swimmer">${backAccessories}${tail}${dorsal}${fins}${body}${face}${bodyAccessories}${headAccessories}</g>`;
  const full = label => `<svg class="panda-art shark-art" viewBox="0 0 160 180" role="img" aria-label="${safe(label)}" focusable="false">${scene}<g class="sk-stage">${rides}${character()}</g>${fx}</svg>`;
  const portrait = () => `<svg class="panda-art panda-face shark-art shark-face" viewBox="20 2 120 124" aria-hidden="true" focusable="false">${dorsal}${head}${face}${headAccessories}</svg>`;
  const render = (faceOnly=false, label='小鲨鱼学习伙伴') => faceOnly ? portrait() : full(label);
  window.foamPandaArt = render;
  window.foamSharkArt = render;
  window.quantSharkArt = render;
  window.quantPandaArt = render;
  const mount = () => document.querySelectorAll('.brand-mark').forEach(el => { el.innerHTML=portrait(); });
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',mount);else mount();
})();

;
/* profile-avatars.js */
'use strict';
(() => {
 const A=window.foamAuth;if(!A)return;
 const presets=[
  ['bamboo','海洋伙伴','海洋日常','cub','scarf','#e2edda'],['breeze','清风小鲨','海洋日常','cub','none','#e0eeeb'],['music','听歌鲨鱼','海洋日常','cub','headphones','#e4e3f0'],['ribbon','礼服小客','海洋日常','cub','bowtie','#f3e5dc'],
  ['scholar','博学先生','学习伙伴','master','coat','#e3e9dd'],['engineer','数据工程师','学习伙伴','engineer','goggles','#e1e9ef'],['explorer','深海探索家','学习伙伴','explorer','backpack','#eae7d6'],['space','星空旅人','学习伙伴','astronaut','spacesuit','#e2e1f2'],
  ['spring','春日花花','四季伙伴','cub','flower','#f2e2e7'],['summer','夏日草帽','四季伙伴','cub','strawhat','#ecedcc'],['autumn','秋日围巾','四季伙伴','cub','redscarf','#f3e4cc'],['winter','冬日暖帽','四季伙伴','cub','beanie','#dceaf2']
 ];
 const records=new Map();let owner=null,loading=null,dialog=null;
 const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const fallback=id=>({user_id:id,avatar:'bamboo',photo_path:null});
 function photoURL(row){return row?.photo_path&&new RegExp('^'+row.user_id+'/[0-9a-f-]{36}\\.webp$').test(row.photo_path)?A.client?.storage.from('foamlab-avatars').getPublicUrl(row.photo_path).data.publicUrl:'';}
 function markup(row,compact=false){const photo=row?.avatar==='photo'?photoURL(row):'';if(photo)return `<img class="profile-avatar-photo" src="${esc(photo)}" alt="" loading="lazy">`;
  const p=presets.find(p=>p[0]===row?.avatar)||presets[0];return `<span class="profile-avatar-art" data-form="${p[3]}" data-outfit="${p[4]}" data-decoration="no-decor" data-quiet="true" style="--avatar-bg:${p[5]}">${window.foamPandaArt?.(compact)||''}</span>`;
 }
 function render(){document.querySelectorAll('[data-self-avatar],#account-avatar,#account-panel-avatar').forEach(el=>{el.innerHTML=A.user?markup(records.get(A.user.id)):'<span aria-hidden="true">Q</span>';});document.querySelectorAll('[data-avatar-open]').forEach(b=>b.disabled=!A.user);}
 async function load(){const id=A.user?.id||null;if(owner===id)return loading;owner=id;if(!id){render();return;}
  render();loading=(async()=>{const {data,error}=await A.client.from('foamlab_avatars').select('user_id,avatar,photo_path').eq('user_id',id).maybeSingle();if(error){owner=null;return;}records.set(id,data||fallback(id));if(A.user?.id===id)render();})();return loading;
 }
 async function fetchMany(ids){const missing=[...new Set(ids)].filter(id=>id&&!records.has(id));if(!missing.length)return;const {data,error}=await A.client.from('foamlab_avatars').select('user_id,avatar,photo_path').in('user_id',missing);if(!error)for(const id of missing)records.set(id,(data||[]).find(x=>x.user_id===id)||fallback(id));}
 function close(){if(!dialog)return;dialog.close();dialog.remove();dialog=null;}
 async function open(){await A.ready;if(!A.user)return;await load();if(dialog)return;
  const id=A.user.id,current=records.get(id)||fallback(id);let selection=current.avatar,photoPath=current.photo_path,img=null,blobURL=null,dirtyPhoto=false,busy=false,zoom=1,pan={x:0,y:0},drag=null;
  const d=document.createElement('dialog');dialog=d;d.className='avatar-dialog';d.setAttribute('aria-labelledby','avatar-dialog-title');
  d.innerHTML=`<header><div><p class="eyebrow">我的头像</p><h2 id="avatar-dialog-title">选一个喜欢的自己</h2></div><button type="button" class="icon-button" data-avatar-close aria-label="关闭头像设置">×</button></header>
  <div class="avatar-editor-top"><div class="avatar-large" data-avatar-preview></div><div><strong>自定义照片</strong><p>上传 JPG、PNG 或 WebP 图片，拖动并缩放调整头像。</p><div class="avatar-upload-actions"><label class="button secondary avatar-upload">上传照片<input type="file" accept="image/jpeg,image/png,image/webp" data-avatar-file></label><button type="button" class="button secondary" data-avatar-edit ${photoPath?'':'hidden'}>调整已上传照片</button></div><small>支持 10 MB 以内的图片。</small></div></div>
  <section class="avatar-crop" hidden><canvas width="512" height="512" tabindex="0" aria-label="头像裁剪预览，拖动或用方向键调整位置"></canvas><label>缩放 <input type="range" min="1" max="3" step="0.01" value="1" data-avatar-zoom></label><p>拖动照片调整位置；键盘方向键也可微调。</p></section>
  <section class="avatar-presets" aria-label="默认鲨鱼头像">${[...new Set(presets.map(p=>p[2]))].map(group=>`<h3>${group}</h3><div class="avatar-preset-grid">${presets.filter(p=>p[2]===group).map(p=>`<button type="button" data-avatar-preset="${p[0]}" aria-pressed="${selection===p[0]}"><span class="avatar-choice-picture">${markup({avatar:p[0]})}</span><span>${p[1]}</span></button>`).join('')}</div>`).join('')}</section>
  <footer><p class="avatar-message" role="status"></p><div><button type="button" class="button secondary" data-avatar-close>取消</button><button type="button" class="button" data-avatar-save>保存头像</button></div></footer>`;
  document.body.append(d);d.showModal();
  const q=s=>d.querySelector(s),canvas=q('canvas'),ctx=canvas.getContext('2d'),crop=q('.avatar-crop'),message=q('.avatar-message');
  const preview=()=>{q('[data-avatar-preview]').innerHTML=selection==='photo'&&dirtyPhoto?`<img class="profile-avatar-photo" src="${canvas.toDataURL('image/webp',.8)}" alt="头像预览">`:markup({user_id:id,avatar:selection,photo_path:photoPath});d.querySelectorAll('[data-avatar-preset]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.avatarPreset===selection)));};
  function paint(){if(!img)return;const scale=Math.max(512/img.width,512/img.height)*zoom,w=img.width*scale,h=img.height*scale;pan.x=Math.max(-(w-512)/2,Math.min((w-512)/2,pan.x));pan.y=Math.max(-(h-512)/2,Math.min((h-512)/2,pan.y));ctx.fillStyle='#fffdf8';ctx.fillRect(0,0,512,512);ctx.drawImage(img,(512-w)/2+pan.x,(512-h)/2+pan.y,w,h);preview();}
  function cleanup(){if(blobURL)URL.revokeObjectURL(blobURL);if(dialog===d)dialog=null;d.remove();}
  d.addEventListener('close',cleanup,{once:true});d.addEventListener('cancel',e=>{if(busy)e.preventDefault();});
  d.addEventListener('click',e=>{if(e.target===d||e.target.closest('[data-avatar-close]')){if(!busy)d.close();}const b=e.target.closest('[data-avatar-preset]');if(b&&!busy){selection=b.dataset.avatarPreset;crop.hidden=true;preview();}});
  async function readPhoto(file){if(!['image/jpeg','image/png','image/webp'].includes(file.type))throw Error('请选择 JPG、PNG 或 WebP 图片。');if(file.size>10*1024*1024)throw Error('图片超过 10 MB，请选择小一些的照片。');
   const url=URL.createObjectURL(file),next=new Image();try{next.src=url;await next.decode();if(!next.naturalWidth||!next.naturalHeight)throw Error();}catch{URL.revokeObjectURL(url);throw Error('这张图片无法读取，请换一张。');}
   if(!d.isConnected){URL.revokeObjectURL(url);return;}if(blobURL)URL.revokeObjectURL(blobURL);blobURL=url;img=next;selection='photo';dirtyPhoto=true;zoom=1;pan={x:0,y:0};q('[data-avatar-zoom]').value='1';q('[data-avatar-edit]').hidden=false;crop.hidden=false;message.textContent='';paint();
  }
  q('[data-avatar-file]').onchange=async e=>{const file=e.target.files[0];if(file)try{await readPhoto(file);}catch(error){message.textContent=error.message;}e.target.value='';};
  q('[data-avatar-edit]').onclick=async()=>{if(busy)return;if(img){selection='photo';crop.hidden=false;paint();return;}try{const res=await fetch(photoURL({user_id:id,photo_path:photoPath}));if(!res.ok)throw Error('照片暂时无法读取，请重试或重新上传。');await readPhoto(await res.blob());}catch(error){message.textContent=error.message;}};
  q('[data-avatar-zoom]').oninput=e=>{zoom=Number(e.target.value);paint();};
  canvas.onpointerdown=e=>{if(busy)return;canvas.setPointerCapture(e.pointerId);drag={x:e.clientX,y:e.clientY,px:pan.x,py:pan.y};e.preventDefault();};
  canvas.onpointermove=e=>{if(!drag)return;const scale=512/canvas.getBoundingClientRect().width;pan={x:drag.px+(e.clientX-drag.x)*scale,y:drag.py+(e.clientY-drag.y)*scale};paint();};
  canvas.onpointerup=canvas.onpointercancel=()=>drag=null;
  canvas.onkeydown=e=>{const v={ArrowLeft:[-6,0],ArrowRight:[6,0],ArrowUp:[0,-6],ArrowDown:[0,6]}[e.key];if(v&&!busy){e.preventDefault();pan.x+=v[0];pan.y+=v[1];paint();}};
  q('[data-avatar-save]').onclick=async()=>{if(busy)return;busy=true;message.textContent='正在保存…';d.querySelectorAll('button,input').forEach(b=>b.disabled=true);let uploaded=null;
   try{if(A.user?.id!==id)throw Error('登录账号已变化，请重新打开头像设置。');
    if(selection==='photo'&&dirtyPhoto){const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/webp',.9));if(!blob)throw Error('照片处理失败，请重新选择。');uploaded=id+'/'+crypto.randomUUID()+'.webp';const {error}=await A.client.storage.from('foamlab-avatars').upload(uploaded,blob,{contentType:'image/webp',cacheControl:'31536000',upsert:false});if(error)throw error;photoPath=uploaded;}
    const row={user_id:id,avatar:selection,photo_path:photoPath};const {error}=await A.client.from('foamlab_avatars').upsert(row,{onConflict:'user_id'});if(error)throw error;
    records.set(id,row);render();window.dispatchEvent(new CustomEvent('foam-avatar-change',{detail:{userId:id}}));
    if(uploaded&&current.photo_path&&current.photo_path!==uploaded)A.client.storage.from('foamlab-avatars').remove([current.photo_path]).catch(()=>{});
    d.close();window.foamNotify?.('头像已保存。');
   }catch(error){if(uploaded)A.client.storage.from('foamlab-avatars').remove([uploaded]).catch(()=>{});photoPath=current.photo_path;message.textContent='保存失败，当前选择已保留，请重试。';busy=false;d.querySelectorAll('button,input').forEach(b=>b.disabled=false);}
  };preview();
 }
 window.FoamAvatar={open,render,load,fetchMany,markup,get:id=>records.get(id)};
 document.addEventListener('click',e=>{if(e.target.closest('[data-avatar-open]')){e.preventDefault();open();}});
 window.addEventListener('foam-auth-change',()=>{if(owner!==A.user?.id&&dialog)close();load();render();});
 const fields=document.querySelector('#profile-fields');if(fields)fields.insertAdjacentHTML('afterbegin','<div class="profile-avatar-setting"><span class="avatar-large" data-self-avatar></span><div><h3>个人头像</h3><p>上传自己的照片，或挑选一位鲨鱼伙伴。</p><button type="button" class="button secondary" data-avatar-open>修改头像</button></div></div>');
 A.ready.then(load);render();
})();

