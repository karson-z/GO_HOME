import fs from 'node:fs';
import {createCanvas,GlobalFonts,Path2D} from '@napi-rs/canvas';
globalThis.Path2D=Path2D;
globalThis.location={search:'?route=main',pathname:'/'};
globalThis.document={createElement:()=>createCanvas(1,1)};
GlobalFonts.registerFromPath('go_home_mobile/assets/fonts/gaegu.ttf','TGJ Gaegu');
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const scenarios=[];
for(const ring of [false,true]) {
 const g=new c.x(),cap=ring?new c.pm(g,3,0,0,.67):new c.xu(g,{items:[{label:'J'}],look:'hand',seed:31});
 const frames=[];
 for(let i=0;i<480;i++) {
  const dt=i%31===0?.033:1/60;
  const player={x:i>160&&i<220?.1:5,y:0};
  const want=i<300,capValue=i>100&&i<180?.45:1,nudge=i>30&&i<280;
  cap.show(want);cap.dimTo(capValue);cap.nudge(nudge);cap.update(dt,player);
  frames.push({dt,player,want,cap:capValue,nudge,out:{a:cap.a,base:cap.base,dodge:cap.dodge,capNow:cap.capNow,push:cap.push,x:cap.s.position.x,y:cap.s.position.y,sx:cap.s.scale.x}});
 }
 scenarios.push({kind:ring?'ring':'cap',frames});cap.dispose();
}
for(const mode of ['first','remind','sweep','point']) {
 const memory={keys:false};const store={get:()=>memory,learned:k=>memory[k]=true};
 const h=new c.w_(new c.x(),store,'comb');const frames=[];
 for(let i=0;i<720;i++) {
  const dt=i%41===0?.033:1/60;
  const p={x:i<260?0:(i-260)*.012,y:i>340&&i<400?.8:0,facing:i>440?-1:1,grounded:!(i>340&&i<400)};
  const frame={dt,p,pxPerM:42,first:mode=='first'||mode=='point',quiet:i>75,singing:i>100&&i<160,remind:mode=='remind',idle:i/60+6,early:true,point:mode=='point'&&i>160?3:0,sweep:mode=='sweep',sweepClearY:0,nears:i>200&&i<380?[{x:p.x+1,y:1.5}]:[]};
  if(mode=='point'&&i==0)memory.keys=true;
  if(frame.first)h.first();if(frame.quiet)h.quiet();if(frame.singing)h.singing();
  if(frame.remind)h.remind(frame.idle,'firefly');h.sweep(frame.sweep,frame.sweepClearY);if(frame.point)h.point(frame.point);
  for(const n of frame.nears)h.near(n.x,n.y);
  if(mode=='first'&&[250,270,290,310,330,350].includes(i)){frame.press=(i-250)/20%4+1;h.press(frame.press);}
  h.update(dt,p,{pxPerM:42});
  frame.out={mode:h.mode,alpha:h.alpha,cap:h.cap,scale:h.scNow,bx:h.bx,by:h.by,side:h.sideNow,over:h.overNow,swap:h.swapK,lid:h.lidOpen(),grows:h.teeth.map(t=>t.grow),plucks:h.teeth.map(t=>t.pluck),numLit:h.numLit,glide:h.glide.map(s=>({x:s.position.x,y:s.position.y,size:s.scale.x,alpha:s.material.opacity}))};
  // Snapshot mutable arrays; they must not share the final frame's backing store.
  frame.out=structuredClone(frame.out);frames.push(frame);
 }
 scenarios.push({kind:'comb',mode,frames});h.dispose();
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_hints.json',JSON.stringify(scenarios));

const keys=[1,3,5,3,6,5],onsets=[0,.5,1,1.5,2,2.5];
const view={x0:-7,x1:7,y0:-2,y1:7.973120113727229};
c.nu(view);
const row=new c.Ip({variant:(k,v)=>v,chapter:'night'},{kind:'a',assist:'auto',onsets,keys,parent:new c.x(),light:0,anchor:()=>({x:2,y:.4,z:.8})});
const frames=[];
for(let i=0;i<540;i++) {
 const dt=i%31==0?.033:1/60,state=i<20?'sleep':i<170?'sing':i<300?'listen':i<460?'sing':'awake';
 const p={x:i>230&&i<300?2:-3,y:0,facing:1,grounded:true};c.au(p);
 const heardIndex=i>=30&&i<=130&&(i-30)%20==0?(i-30)/20:i>=320&&i<=420&&(i-320)%20==0?(i-320)/20:null;
 if(heardIndex!==null)row.heard(keys[heardIndex],heardIndex,'sing');
 const taps=i>=200&&i<240?[{deg:1,t:4},{deg:3,t:4.5}]:[];
 if(i===200)row.showMine(taps,1,false);
 const wrongs=i>=240?2:0;
 row.update({dt,player:p},{state,wrongs,judge:{progress:taps.length,lastFail:null}});
 frames.push({dt,state,p,heard:heardIndex,taps,wrongs,out:{scale:row.k,x:row.g.position.x,y:row.g.position.y,haze:row.hazeA,hazeLength:row.hazeLen,prime:row.primeA,box:row.rowBox,motes:row.ms.map(m=>({degree:m.deg,dx:m.dx,alpha:m.a,target:m.target,rise:m.rise,boost:m.boost,near:m.near,phase:m.phase,x:m.s.position.x,y:m.s.position.y,size:m.s.scale.x,opacity:m.s.material.opacity})),echoes:row.rings.map(r=>({degree:r.deg,dx:r.dx,alpha:r.a,phase:r.phase,x:r.s.position.x,y:r.s.position.y,size:r.s.scale.x}))}});
}
scenarios.push({kind:'motes',keys,onsets,view,frames});
fs.writeFileSync('go_home_mobile/test/fixtures/original_hints.json',JSON.stringify(scenarios));
const routeSource=fs.readFileSync('source/readable/uwcej6eE.js','utf8');
const tutorialSource=routeSource.slice(routeSource.indexOf('var Z = {'),routeSource.indexOf('  Pr = `tgjd02:save`'));
const {Dr,Nr}=new Function('ge','Ne','Re','Fe','de',tutorialSource.replace(/,\s*$/,';')+';return {Dr,Nr};')(c.xu,{slash:true},()=>({x0:-7,x1:7,y0:-2,y1:8}),.36,.06);
for(const kind of ['move','jump']) {
 const memory={move:false,jump:false},store={get:()=>memory,learned:k=>memory[k]=true};
 const h=kind=='move'?new Nr(new c.x(),store,'hand','ahead',true):new Dr(new c.x(),{x0:5,x1:5.8,ground:0,top:.62},store,'hand');
 if(kind=='move')h.arm(0,0,1);
 const frames=[];
 for(let i=0;i<660;i++) {
  const dt=i%41==0?.033:1/60;
  const p={x:kind=='move'?i<420?0:(i-420)*.05:1+i*.012,y:0,grounded:!(i>350&&i<395),facing:1};
  const input={move:i>280?1:0,jump:i>=350&&i<365};h.beforeStep(input);h.update(dt,p,true);
  frames.push({dt,p,input,out:{done:h.done,on:kind=='move'?h.on:h.tipShown,shows:h.shows,a:h.tip.a,x:h.tip.cx,y:h.tip.by,base:h.tip.base,push:h.tip.push}});
 }
 scenarios.push({kind,frames});h.dispose();
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_hints.json',JSON.stringify(scenarios));
const talkFrames=[];
const memory={jUsed:false,jText:0};
c.hd({get:()=>memory,jTextShown:()=>memory.jText++});
const talk=new c.Od(new c.x());
const tex=c.Ed();
for(let i=0;i<480;i++) {
 const dt=i%31===0?.033:1/60;
 const p={x:i>130&&i<190?1:5,y:0};
 const on=i<230||(i>300&&i<400);
 talk.update(dt,on,1,1.8,1.7,p);
 talkFrames.push({dt,p,on,out:{alpha:talk.a,textBase:talk.textBase,textDodge:talk.textDodge,scale:talk.tk,side:talk.sideNow,capA:talk.cap.a,capX:talk.cap.s.position.x,capY:talk.cap.s.position.y,stripX:talk.strip.position.x,stripY:talk.strip.position.y,stripA:talk.strip.material.opacity}});
}
scenarios.push({kind:'talk',view,stripW:tex.w,stripH:tex.h,frames:talkFrames});
fs.writeFileSync('go_home_mobile/test/fixtures/original_hints.json',JSON.stringify(scenarios));
console.log(`Generated ${scenarios.reduce((n,s)=>n+s.frames.length,0)} original hint frames`);
const five = new c.WC(new c.x());
const fiveFrames=[];
c.nu(view);
for(let i=0;i<480;i++) {
 const dt=i%31===0?.033:1/60;
 const p={x:i<200?0:5.8,y:i>250&&i<300?.5:0};
 const on=i<360,beat=i/25;
 const press=i===130||i===150;
 if(press)five.pressed();
 five.update(dt,on,p,.7,beat);
 fiveFrames.push({dt,p,on,beat,press,out:{alpha:five.a,digitAlpha:five.digitA,flash:five.flash,dx:five.dx,draw:[five.lid,five.digit,five.box,five.lit,...five.sparks.map(s=>s.s)].map(s=>({x:s.position.x,y:s.position.y,z:s.position.z,w:s.scale.x,h:s.scale.y,alpha:s.material.opacity}))}});
}
scenarios.push({kind:'five',view,frames:fiveFrames});
fs.writeFileSync('go_home_mobile/test/fixtures/original_hints.json',JSON.stringify(scenarios));
console.log(`Generated ${scenarios.reduce((n,s)=>n+s.frames.length,0)} original hint frames`);

// Run the original nT cue methods directly, including its real ring geometry.
const woodCueFrames=[];
for (const mode of ['listen','drum','idle']) {
 const h=Object.create(c.nT.prototype);
 Object.assign(h,{mode,win:{start:10,take:{opensAt:-.0625}},run:{loud:true},
  drumLine:{at:6,span:.5},cursor:new c.x(),cursorMat:new c.I(),
  pips:new c.x(),pipMats:[],approach:new c.H(new c.n(.15,.185,32),new c.U()),
  firstFlash:new c.w(new c.I())});
 h.approachMat=h.approach.material;h.firstFlashMat=h.firstFlash.material;
 Object.defineProperty(h,'cueK',{value:.6});
 for(let i=0;i<4;i++){const mat=new c.I();h.pipMats.push(mat);const s=new c.w(mat);s.position.x=i*.26;h.pips.add(s);}
 for(const now of [5.9,6,6.25,6.55,6.6,7.2,8,8.3,8.75,9.49,9.5,9.75,9.99,10,10.08,10.16,10.4]) {
  h.updateCursor(now);
  const draw=[];
  if(h.cursor.visible)draw.push({x:h.cursor.position.x,y:h.cursor.position.y,w:.8*h.cursor.scale.x,alpha:h.cursorMat.opacity});
  if(h.pips.visible)for(const s of h.pips.children)draw.push({x:h.pips.position.x+s.position.x,y:h.pips.position.y,w:s.scale.x,alpha:s.material.opacity});
  if(h.firstFlash.visible)draw.push({x:h.firstFlash.position.x,y:h.firstFlash.position.y,w:h.firstFlash.scale.x,alpha:h.firstFlashMat.opacity});
  const approach=h.approach.visible?{x:h.approach.position.x,y:h.approach.position.y,w:h.approach.scale.x,alpha:h.approachMat.opacity}:null;
  woodCueFrames.push({mode,now,draw,approach});
 }
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_wood_hint_cues.json',JSON.stringify(woodCueFrames));
