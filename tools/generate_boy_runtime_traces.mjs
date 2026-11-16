import fs from 'node:fs';
import {createCanvas} from '@napi-rs/canvas';
globalThis.location={search:'?route=main',pathname:'/'};
globalThis.document={createElement:()=>createCanvas(1,1)};
const c=(await import('./.reference_runtime/Da-Ct4tY.js')).__port;
const spec=JSON.parse(fs.readFileSync('go_home_mobile/assets/characters/boy.json'));
const scenarios=[];
for(const terrain of ['flat','slope','steps','live','cliff']) {
 const b=c.Bi({...spec,parts:spec.parts.map(p=>({...p,tex:{colorSpace:''}}))},{});
 const ground=x=>terrain==='flat'?0:terrain==='slope'?Math.sin(x*.5)*.15:terrain==='steps'?Math.floor(x/1.5)*.025:terrain==='live'?Math.sin(x)*.1:x>3?-1:0;
 const frames=[];let x=0,time=0,serial=0;
 for(let i=0;i<960;i++) {
  const dt=i===0?0:i%37===0?.033:1/60;
  const previous=time;time+=dt;const elapsed=i===0?0:time-previous;
  const t=i/60;
  const vx=t<.5?0:t<1.5?(t-.5)*2:t<3?2:t<3.5?Math.max(0,2-(t-3)*4):t<4.5?0:t<6?-1.3:t<7?0:t<9?1.6:t<10?.7:t<12?0:t<14?-1.7:0;
  x+=vx*dt;
  const air=t>=7.4&&t<8,vy=air?8.6-(t-7.4)*24:0;
  const y=ground(x)+(air?Math.max(0,(t-7.4)*8.6-12*(t-7.4)**2):0);
  const p={x,y,vx,vy,grounded:!air,facing:t<4?1:t<6.5?-1:t<12?1:-1,wind:t>=7.34&&t<7.4?1:0,jumpAir:air,pose:{lean:t>=9&&t<10?.7:0,reach:t>=9&&t<10?.7:0,strain:0,shake:0,inset:t>=9&&t<10?.02:0}};
  if([40,41,120,480].includes(i))serial++;
  b.update(time,p,y,serial,ground,()=>terrain==='live');
  frames.push({dt:elapsed,p,serial,out:Object.fromEntries([...b.rig.nodes].map(([id,n])=>[id,{x:n.joint.position.x,y:n.joint.position.y,rot:n.joint.rotation.z,sx:n.joint.scale.x,sy:n.joint.scale.y}])),dx:b.rig.group.position.x,dy:b.rig.group.position.y,turn:b.rig.turn.scale.x,phase:b.gait.phase,mode:b.gait.mode});
 }
 scenarios.push({terrain,frames});
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_boy_runtime.json',JSON.stringify(scenarios));
console.log('Generated 4800 complete boy runtime reference frames');
