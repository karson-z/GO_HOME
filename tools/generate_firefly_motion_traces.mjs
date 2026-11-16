import fs from 'node:fs';
import {createCanvas} from '@napi-rs/canvas';
globalThis.document={createElement:()=>createCanvas(1,1)};
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
fs.writeFileSync('go_home_mobile/assets/characters/firefly-lamp.png',c.Hy().image.toBuffer('image/png'));
const l=(await import('./.reference_runtime/Da-Ct4tY.js')).__port;
fs.writeFileSync('go_home_mobile/assets/characters/firefly-halo.png',l.ui().image.toBuffer('image/png'));
const config=JSON.parse(fs.readFileSync('go_home_mobile/assets/data/original_mechanisms.json')).firefly;
function motion() {
 const rig={group:{visible:true},flip:{scale:{x:1}},set:{parts:[{id:'body',frames:{qfront:{}}}]},anchors:new Map(),rot:{},frame:'side',turn:null,solo:null,
  setOpacity(x){this.opacity=x;},setFrame(id,frame){this.frame=frame;},setSolo(x){this.solo=x;},applyTurn(x){this.turn=x;},
  resetPose(){this.rot={};},pose(id,p){this.rot[id]=p;},setWake(x){this.wake=x;},setAccent(){},update(){},at(){},mount(){return null;}};
 const b=Object.assign(Object.create(c.By.prototype),{k:.8,rig,glowAt:new c.L(),lastX:null,lastY:0,facing:1,turner:new c.Eg(.15,.06),wantT:0,clip:null,goneT:0,pitch:new c.bg(3,.7),ely:0,flapPh:0,flapF:0,flapA:0,liftT:99,liftDelay:0,relT:1,off:{x:0,y:0},jT:99,cymT:99,nodT:99,acc:new c.R(),hue:new c.R(),lamp:null,lanternW:.1084,follow:new c.Dg(.034),posLerp:new c.Hu(),perchK:0,flapSlow:c.Ry(15,.8),flapHover:c.Ry(20,.8),perchMode:'sit',turnMode:'front',dbg:{},wx:0,wy:0});
 b.t34=new c.Yg(rig,['head'],'body','qfront',true);return b;
}
const actors=Array.from({length:7},motion),frames=[];
let time=0,previous=Array(7).fill(0);
for(let i=0;i<720;i++) {
 const dt=i%31===0?1/30:1/60; time+=dt;
 const phase=i<100?'sleep':i<200?'sing':i<260?'cheer':i<340?'rise':i<540?'lead':'home';
 const begin=i<100?0:i<200?100:i<260?200:i<340?260:i<540?340:540;
 const phaseT=(i-begin)/60;
 const flies=config.stems.map((s,j)=>{
  const airborne=['rise','lead','home'].includes(phase);
  const x=airborne?7+Math.sin(i*.03+j)*2+j*.1:s.x;
  const y=airborne?2+Math.cos(i*.02+j)*.4:s.top+.14;
  return {deg:j+1,x,y,z:.3,flash: i%50<8?1:i%50<20?.5:0,hurt:i>=440&&i<470?(470-i)/30:0,back:i<500?1:.5,vis:i>660?Math.max(0,1-(i-660)/35):1,gone:i>=700,scout:phase==='lead'&&j%2&&i>=400&&i<500?{t:(i-400)/60}:null,color:new c.R('#ffd9a0')};
 });
 const up=flies.map((f,j)=>f.flash>previous[j]+.25),cym=phase==='lead'&&up.filter(Boolean).length>=5;
 const state={phase,phaseT,stems:config.stems,flies};
 const out=actors.map((a,j)=>{const light=a.step(state,j,flies[j].flash,dt,time,{flashUp:up[j],layerFlash:up[j],cym});return {rot:a.rig.rot,off:{...a.off},turn:a.rig.turn,front:a.t34.on,wake:a.rig.wake,opacity:a.rig.opacity,visible:a.rig.group?.visible,light};});
 previous=flies.map(f=>f.flash);
 frames.push({dt,time,phase,phaseTime:phaseT,flies:flies.map(({color,...f})=>f),up,cym,out});
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_firefly_motion.json',JSON.stringify(frames));
console.log('Exported '+frames.length*7+' source By appearance frames.');
