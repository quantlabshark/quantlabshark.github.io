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
  const mount = () => {
    document.querySelectorAll('.brand-mark').forEach(el => { el.innerHTML=portrait(); });
    document.querySelectorAll('[data-panda-portrait]').forEach(el => {
      el.innerHTML=full('小鲨陪你学量化');
      el.addEventListener('click',()=>{if(!matchMedia('(prefers-reduced-motion: reduce)').matches)el.animate([{transform:'rotate(0)'},{transform:'rotate(-5deg)'},{transform:'rotate(5deg)'},{transform:'rotate(0)'}],{duration:600});});
    });
  };
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',mount);else mount();
})();
