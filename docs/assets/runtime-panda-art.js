/* panda-art.js */
/* QuantLab shark. Inline vectors, no image downloads or account dependencies.
 * Compatibility: foamPandaArt(faceOnly, label); appearance uses ancestor data-*.
 * Load shark-art.css after any legacy mascot stylesheet. */
'use strict';
(() => {
  const group = (name, body) => `<g class="${name}">${body}</g>`;
  const safe = text => String(text).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const star = (x,y,size=1) => `<path class="sk-gold" transform="translate(${x} ${y}) scale(${size})" d="M0-6l2 4 4 .6-3 3 .7 4.4L0 4l-3.7 2 .7-4.4-3-3L-2-2z"/>`;
  const eyes = `<g class="sk-eyes-open"><g class="sk-pupils"><ellipse class="sk-eye" cx="62" cy="80" rx="5.8" ry="7.2"/><ellipse class="sk-eye" cx="98" cy="80" rx="5.8" ry="7.2"/><circle fill="#fff" cx="64" cy="77.5" r="2"/><circle fill="#fff" cx="100" cy="77.5" r="2"/></g></g><g class="sk-eyes-happy"><path class="sk-inkline" d="M56 82q6-8 12 0m24 0q6-8 12 0"/></g><g class="sk-eyes-closed"><path class="sk-inkline" d="M56 80q6 6 12 0m24 0q6 6 12 0"/></g>`;
  const face = `<g class="sk-face"><path class="sk-snout" d="M40 96c8-9 19-13 40-13s32 4 40 13c-4 17-20 28-40 28S44 113 40 96z"/><ellipse class="sk-cheek" cx="49" cy="94" rx="7" ry="3.5"/><ellipse class="sk-cheek" cx="111" cy="94" rx="7" ry="3.5"/>${eyes}<path class="sk-inkline sk-smile" d="M67 99q13 13 26 0"/><path class="sk-tooth" d="M69 101l5 2-2 5zm17 2 5-2-3 7z"/><path class="sk-mouth-open" d="M68 99q12 5 24 0c-1 16-22 16-24 0z"/><path class="sk-gills" d="M45 106l-3 7m9-5-2 7m8-4-1 6m59-11 3 7m-9-5 2 7m-8-4 1 6"/></g>`;
  const headAccessories = [
    group('sk-o sk-glasses', '<g class="sk-glasses-lines"><circle cx="62" cy="80" r="12"/><circle cx="98" cy="80" r="12"/><path d="M74 79q6-4 12 0M50 78l-9-3m69 3 9-3"/></g>'),
    group('sk-o sk-headphones','<path class="sk-headphone-band" d="M36 77c0-47 88-47 88 0"/><rect class="sk-purple sk-outline" x="30" y="73" width="13" height="24" rx="6"/><rect class="sk-purple sk-outline" x="117" y="73" width="13" height="24" rx="6"/>'),
    group('sk-o sk-cap sk-hat','<path class="sk-dark sk-outline" d="M57 55V45h46v10q-23-8-46 0z"/><path class="sk-dark sk-outline" d="m80 27 35 12-35 12-35-12z"/><path class="sk-goldline" d="M109 41v18"/><circle class="sk-gold" cx="109" cy="61" r="3"/>'),
    group('sk-o sk-hardhat sk-hat','<path class="sk-gold sk-outline" d="M51 49c0-31 58-31 58 0z"/><rect class="sk-gold sk-outline" x="46" y="45" width="68" height="7" rx="3.5"/><path class="sk-goldline" d="M80 23v20"/>'),
    group('sk-o sk-strawhat sk-hat','<ellipse class="sk-straw sk-outline" cx="80" cy="48" rx="46" ry="9"/><path class="sk-straw sk-outline" d="M59 45q0-38 42 0z"/><path fill="none" stroke="#c77760" stroke-width="5" d="M60 40q20 5 40 0"/>'),
    group('sk-o sk-wizard sk-hat',`<path class="sk-purple sk-outline" d="M54 48q12-24 36-40-3 23 16 40z"/><ellipse class="sk-purple sk-outline" cx="80" cy="48" rx="36" ry="6"/>${star(82,29,.7)}`),
    group('sk-o sk-flower','<g transform="translate(112 52)"><path fill="#f2b6ae" d="M0 0C-15-16 4-22 4-5C21-17 24 4 6 4C18 21-4 24-4 6C-22 15-22-6-5-4z"/><circle class="sk-gold" cx="1" cy="1" r="4"/></g>')
  ].join('');
  const dorsal = '<path class="sk-fin sk-outline sk-dorsal" d="M69 52c-3-15 4-32 16-38-1 16 5 23 14 36z"/>';
  const tail = '<g class="sk-tail"><path class="sk-fin sk-outline" d="M112 130q19-5 25-21l5 20 14 13q-14 5-24-3l-17 12z"/><path class="sk-finshine" d="m132 131 8-13 1 13 8 8q-10-1-17-8z"/></g>';
  const silhouette = '<path class="sk-body sk-outline" d="M80 44c28 0 45 24 45 55 0 34-17 61-45 61s-45-27-45-61c0-31 17-55 45-55z"/><path class="sk-bodyshine" d="M45 76c6-16 16-24 31-26-14 9-22 20-25 35z"/><path class="sk-belly" d="M80 97c19 0 32 17 32 35 0 17-14 26-32 26s-32-9-32-26c0-18 13-35 32-35z"/>';
  const fins = '<g class="sk-fin-left"><path class="sk-fin sk-outline" d="M41 108c-15 5-23 20-25 33 17-4 26-13 30-25z"/></g><g class="sk-fin-right"><path class="sk-fin sk-outline" d="M119 108c15 5 23 20 25 33-17-4-26-13-30-25z"/></g><path class="sk-fin sk-outline" d="M56 150l-7 14q12 1 18-8m26 0q6 9 18 8l-7-14"/>';
  const bodyAccessories = [
    group('sk-o sk-backpack','<path class="sk-pack sk-outline" d="M36 118v-11q0-8 10-8h11v47H43q-7 0-7-8z"/><path class="sk-strap" d="M54 104v40"/>'),
    group('sk-o sk-coat','<path class="sk-coatfill sk-outline" d="M49 117l16 7 15 30 15-30 16-7 6 25-15 17H58l-15-17z"/><path class="sk-gills" d="M80 143v16m12-22h14v9H92z"/>'),
    group('sk-o sk-raincoat','<path class="sk-gold sk-outline" d="M48 117q32 13 64 0l5 26q-10 19-37 19t-37-19z"/><path class="sk-goldline" d="M80 125v36"/><circle class="sk-dark" cx="80" cy="135" r="2"/><circle class="sk-dark" cx="80" cy="147" r="2"/>'),
    group('sk-o sk-scarf','<path class="sk-teal sk-outline" d="M48 116q32 14 64 0l-2 10q-30 12-60 0z"/><path class="sk-teal sk-outline" d="m94 124 14-2 1 22-12-2z"/><path stroke="#b4ded0" stroke-width="2" d="m98 132 10 1m-10 4 10 1"/>'),
    group('sk-o sk-book','<path fill="#446c63" class="sk-outline" d="M51 130q15-4 29 3 14-7 29-3v26q-15-3-29 3-14-6-29-3z"/><path fill="#fff9e9" d="M55 133q13-2 23 3v19q-12-5-23-3zm27 3q10-5 23-3v19q-11-2-23 3z"/><path stroke="#b4baa6" stroke-width="1.6" d="m59 139 14 2m-14 4 14 2m-14 4 9 1m26-12-14 2m14 4-14 2m14 4-9 1"/>'),
    group('sk-o sk-suit','<circle class="sk-helmet" cx="80" cy="82" r="54"/><path stroke="#fff" stroke-width="3" stroke-linecap="round" fill="none" d="M43 63q7-16 22-21"/><path fill="#c6d8dc" class="sk-outline" d="M46 119q34 17 68 0v8q-34 17-68 0z"/>')
  ].join('');
  const scene = `<ellipse class="sk-shadow" cx="80" cy="169" rx="42" ry="5"/><g class="sk-decor"><ellipse fill="#cae5df" cx="80" cy="169" rx="70" ry="10"/><path stroke="#fff" fill="none" stroke-width="2" d="M22 168h22m66 4h25M61 175h17"/><g class="sk-bubbles"><circle cx="22" cy="104" r="5"/><circle cx="139" cy="76" r="7"/><circle cx="147" cy="55" r="3.5"/></g></g>`;
  const fx = `<g class="sk-o sk-stars">${star(24,66)}${star(139,62)}${star(130,28,.6)}</g><g class="sk-o sk-sleep"><text x="127" y="52">z</text><text x="138" y="37">Z</text></g><g class="sk-o sk-music"><path fill="none" stroke="#4a8c79" stroke-width="2.5" d="M22 58V43l9-2v14"/><circle class="sk-teal" cx="19" cy="58" r="3.5"/><circle class="sk-teal" cx="28" cy="55" r="3.5"/></g>`;
  const character = () => `<g class="sk-swimmer">${tail}${dorsal}${silhouette}${fins}${face}${bodyAccessories}${headAccessories}</g>`;
  const full = label => `<svg class="panda-art shark-art" viewBox="0 0 160 180" role="img" aria-label="${safe(label)}" focusable="false">${scene}<g class="sk-stage">${character()}</g>${fx}</svg>`;
  const portrait = () => `<svg class="panda-art panda-face shark-art shark-face" viewBox="28 10 104 120" aria-hidden="true" focusable="false">${dorsal}<path class="sk-body sk-outline" d="M80 44c28 0 45 23 45 47 0 22-20 34-45 34s-45-12-45-34c0-24 17-47 45-47z"/>${face}${headAccessories}</svg>`;
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
  (document.querySelector('#town-app')||document.body).append(d);d.showModal();
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

