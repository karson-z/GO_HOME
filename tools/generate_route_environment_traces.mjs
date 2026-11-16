// Execute the extracted source environment scheduler; no Flutter code is used.
import fs from 'node:fs';
import {createCanvas} from '@napi-rs/canvas';
globalThis.document={baseURI:'http://localhost/',createElement:()=>createCanvas(1,1)};
globalThis.location={search:'?route=main',pathname:'/'};
const core=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const route=(await import('./.reference_runtime/uwcej6eE.js')).__port;
const data=JSON.parse(fs.readFileSync('go_home_mobile/assets/data/original_route_audio.json'));
const layout=JSON.parse(fs.readFileSync('go_home_mobile/assets/data/original_route.json')).layout;
class Param {
  value=1;
  setValueAtTime(x){this.value=x;}
  linearRampToValueAtTime(x){this.value=x;}
  setTargetAtTime(x){this.value=x;}
  cancelScheduledValues(){}
}
const starts=[];
function node(){return {
  gain:new Param(),frequency:new Param(),Q:new Param(),pan:new Param(),playbackRate:new Param(),next:null,
  connect(n){this.next=n;return n},disconnect(){},stop(){},addEventListener(){},
  start(time){
    if(!this.buffer)return;
    let gain=1,pan=0,cutoff=20000;
    for(let n=this.next;n&&n!==engine.ambBus;n=n.next){
      if(n.kind==='gain')gain*=n.gain.value;
      if(n.kind==='pan')pan=n.pan.value;
      if(n.kind==='filter')cutoff=n.frequency.value;
    }
    starts.push({file:this.buffer.id.replaceAll('.','-'),time,gain,pan,cutoff,rate:this.playbackRate.value});
  }
};}
const ctx={currentTime:0,createGain:()=>Object.assign(node(),{kind:'gain'}),createStereoPanner:()=>Object.assign(node(),{kind:'pan'}),createBiquadFilter:()=>Object.assign(node(),{kind:'filter'}),createBufferSource:node};
const engine={ctx,ambBus:node(),ambAuto:node(),hooks:[],setAmbience(){}};
const env=new core.as(engine,'', {...data.environment.manifest,mix:data.mix});
env.load=async s=>({id:s.id});
env.oneshotV='new';
const loops=data.ambience.map(s=>({...s,x0:locate(s.from.at)+s.from.dx,x1:locate(s.to.at)+s.to.dx}));
function locate(id){const s=layout.walks.find(s=>s.def.walk===id)??layout.segs.find(s=>s.def.id===id);if(!s)throw Error('No segment '+id);return s.x0;}
const bed=new route.Et(ctx,engine.ambBus,loops);
for(const s of bed.live)s.buf={id:s.src.name};
// Keep buffers resident so this isolates the source start/apply/release math
// from asynchronous filesystem loading, as the native preloaded backend does.
bed.load=async s=>{s.buf={id:s.src.name};};
const d=data.drips;
const dripOrigin=locate(d.at);
const drips=new route.Dt(ctx,engine.ambBus,{...d,x0:dripOrigin+d.local[0],x1:dripOrigin+d.local[1]});
drips.bufs=d.names.map(id=>({id}));drips.loading=true;
const frames=[];
for(let i=0;i<4800;i++){
  const time=i*.05;
  ctx.currentTime=time;
  const scene=i<1600?'dusk':i<3200?'night':'dawn';
  const changed=i%1600===0;
  if(changed)await env.play(scene,{atBar:Math.floor(time/2),fadeBars:8});
  const lufs=i%31===0?null:-48+24*Math.sin(i*.009);
  env.musicMeter={lufs:()=>lufs,read(){}};
  env.update(time);
  env.tick(time);
  await Promise.resolve();
  const local=i%1600;
  // Traverse all three positional loops, leave them, then return.
  const x=local<800?local*.9:(1600-local)*.9;
  const inZone=i%140<70;
  bed.update(x,inZone);await Promise.resolve();
  drips.update(x);
  const active=bed.live.filter(s=>s.node).map(s=>({file:s.src.name,gain:s.gain.gain.value,pan:s.pan.pan.value,cutoff:s.filter.frequency.value}));
  frames.push({time,scene,changed,lufs,x,inZone,offsetDb:env.offsetDb,target:env.target,nextAt:Object.fromEntries(env.nextAt),shots:starts.splice(0).filter(s=>!data.ambience.some(a=>a.name===s.file)),loops:active});
}
const window=new core.rs(), loudness=[];
for(let i=0;i<18000;i++){
  const time=i*.027;
  const energy=i%53<7?0:10**((-76+54*Math.sin(i*.003)+9*Math.sin(i*.07))/10);
  if(i%19!==0)window.push(time,energy);
  if(i%13===0)loudness.push({time,energy,skip:i%19===0,queries:[.4,1,4,12].map(seconds=>({seconds,value:window.lufs(time,seconds)}))});
  else loudness.push({time,energy,skip:i%19===0});
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_route_environment.json',JSON.stringify({frames,loudness}));
console.log(`Exported ${frames.length} source environment frames and ${loudness.length} gated-energy frames`);
