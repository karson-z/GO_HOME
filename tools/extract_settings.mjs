// Preserve the original aN seeded note handles, including the idle head color.
import fs from 'node:fs';
import {createCanvas,loadImage} from '@napi-rs/canvas';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
// The remaining native compatibility action uses the shipped tree icon.
fs.writeFileSync('go_home_mobile/assets/startup/tree.svg',
 c.fl('tree','回到主菜单',{size:'24px'})
  .replace('<svg ','<svg xmlns="http://www.w3.org/2000/svg" ')
  .replaceAll('currentColor','#fbf8f2'));
globalThis.document={createElementNS:()=>({style:{},append(){},setAttribute(){},innerHTML:''})};
for(let seed=3;seed<=28;seed+=5){
 const slider=new c.aN({clientWidth:150,clientHeight:28,append(){}},seed);
 for(const focus of [false,true]){
  slider.focus(focus);
  const svg='<svg xmlns="http://www.w3.org/2000/svg" viewBox="-12 -24 38 38">'+slider.knobBody.innerHTML.replaceAll('currentColor',focus?'#ffd9a0':'#fbf8f2')+'</svg>';
  fs.writeFileSync(`go_home_mobile/assets/startup/settings-knob-${seed}-${focus?'on':'off'}.svg`,svg);
 }
}
console.log('Exported 12 original settings note handles');

const grain=await loadImage(Buffer.from(decodeURIComponent(c.Vc.slice(c.Vc.indexOf(',')+1,-2))));
const canvas=createCanvas(160,160);canvas.getContext('2d').drawImage(grain,0,0);
fs.writeFileSync('go_home_mobile/assets/startup/menu-grain.png',canvas.toBuffer('image/png'));

// H.makeCorner and Gl's warm selection dot, used by the in-game pause layer.
fs.writeFileSync('go_home_mobile/assets/startup/pause-dot.svg',
 decodeURIComponent(c.zl('#ffd9a0','#fff1de').split(',')[1].slice(0,-2)));
const rand=c.Cl(97);
const strokes=[9,16,23].map((y,i)=>c.Ml(
 c.Al(6+rand()*1.2,26-rand()*1.2,y,rand,.6,4),2.1,300+i,
 {taper:.25,faintOp:.3})).join('');
fs.writeFileSync('go_home_mobile/assets/startup/menu-corner.svg',
 `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">${strokes.replaceAll('currentColor','#fbf8f2')}</svg>`);
