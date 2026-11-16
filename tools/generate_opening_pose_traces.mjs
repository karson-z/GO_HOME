import fs from 'node:fs';
import {createCanvas} from '@napi-rs/canvas';
globalThis.location={search:'?route=main',pathname:'/'};
globalThis.document={createElement:()=>createCanvas(1,1)};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const l=(await import('./.reference_runtime/Da-Ct4tY.js')).__port;
const spec=JSON.parse(fs.readFileSync('go_home_mobile/assets/characters/boy.json'));
const scenarios=[];
for (const mode of ['opening','blend']) {
  Object.assign(c.Vj,{k:0,sleep:0,riseT:-1,mode:'keys'});
  const b=l.Bi({...spec,parts:spec.parts.map(p=>({...p,tex:{colorSpace:''}}))},{});
  const frames=[]; let time=0;
  for (let i=0;i<660;i++) {
    const dt=i===0?0:i%37===0?.033:1/60;
    const previous=time; time+=dt; const elapsed=time-previous;
    const age=time-3;
    const rise=mode==='opening'&&age>=.9 ? Math.min(1,(age-.9)/1.6):null;
    const weight=mode==='opening'?1:Math.max(0,Math.min(1,Math.sin(time*.8)*.7+.3));
    const sleep=mode==='opening'?1-Math.max(0,Math.min(1,age/.7)):.5+.5*Math.sin(time);
    Object.assign(c.Vj,{k:weight,sleep,riseT:rise===null?-1:rise*1.6});
    const p={x:0,y:0,vx:0,vy:0,grounded:true,facing:1,pose:{lean:0,reach:0,strain:0,shake:0,inset:0}};
    b.update(time,p,0,0,()=>0,()=>false);
    for (const [id,n] of b.rig.nodes) {
      for (const v of [n.joint.position.x,n.joint.position.y,n.joint.rotation.z,n.joint.scale.x,n.joint.scale.y]) {
        if (!Number.isFinite(v)) throw new Error(`Invalid reference ${mode} ${i} ${id}`);
      }
    }
    frames.push({dt:elapsed,weight,sleep,rise,out:Object.fromEntries([...b.rig.nodes].map(([id,n])=>[id,{x:n.joint.position.x,y:n.joint.position.y,rot:n.joint.rotation.z,sx:n.joint.scale.x,sy:n.joint.scale.y}]))});
  }
  b.dispose(); scenarios.push({mode,frames});
}
Object.assign(c.Vj,{k:0,sleep:0,riseT:-1});
fs.writeFileSync('go_home_mobile/test/fixtures/original_opening_pose.json',JSON.stringify(scenarios));
console.log('Generated 1320 complete opening pose frames');
