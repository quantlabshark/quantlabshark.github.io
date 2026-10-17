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
