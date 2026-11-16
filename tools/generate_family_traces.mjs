import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/Da-Ct4tY.js')).__port;
const scenarios=[];
for(const who of ['dad','mom','sister','brother','grandpaP','grandpaM','granny','grandma','oldman','soul']) {
 const spec=JSON.parse(fs.readFileSync(`go_home_mobile/assets/characters/${who==='soul'?'boy':'fam2-'+who}.json`));
 const scale=(spec.originalHeight??1.1)/1.1;
 const raw={...spec,height:spec.originalHeight??1.1,anchors:{},parts:spec.parts.map(p=>({...p,at:p.at.map(v=>v*scale),size:p.size.map(v=>v*scale),tex:{colorSpace:''}}))};
 const b=new c.uT(raw,{},c.nT[who]??{});
 const ground=x=>Math.sin(x*.7)*.03;
 const frames=[];let x=0,time=0;
 for(let i=0;i<600;i++) {
  const dt=i===0?0:i%29===0?.033:1/60;time+=dt;
  const v=i<30?0:i<140?1.5:i<230?-1.1:0;
  x+=v*dt;
  const sit=i>=240&&i<360?{k:Math.min(1,(i-240)/20),slump:i<300?0:(i-300)/60}:undefined;
  const reaches=i>=380&&i<450?[{side:'F',p:{x:x+.5,y:ground(x)+.7},w:.7}]:i>=450&&i<500?[{side:'B',p:{x:x-.3,y:ground(x)+1.0},w:1,palm:1.0}]:i>=500&&i<550?[{side:'F',p:{x:x-.1,y:ground(x)+.65},w:1,palm:.6},{side:'B',p:{x:x-.16,y:ground(x)+.65},w:.9,palm:.4}]:undefined;
  const e={time,x,y:ground(x),z:.3,face:i<140?1:-1,alpha:1,sit,lean:i>=380&&i<550?.4*Math.sin((i-380)/170*Math.PI):0,reach:reaches,look:i>=300?{x:x+.5,y:ground(x)+.8}:undefined,shrink:i>=550?(i-550)/50:0};
  b.update({...e,groundAt:ground});
  frames.push({input:e,out:Object.fromEntries([...b.rig.nodes].map(([id,n])=>[id,{x:n.joint.position.x,y:n.joint.position.y,rot:n.joint.rotation.z,sx:n.joint.scale.x,sy:n.joint.scale.y}])),turn:b.rig.turn.scale.x,points:Object.fromEntries(['head','face','shoulder','back','hand','waist','arm','armpit'].map(id=>{const p=b.point(id);return[id,{x:p.x,y:p.y}]}))});
 }
 scenarios.push({who,frames});
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_family.json',JSON.stringify(scenarios));
console.log('Generated 6000 family skeleton and anchor reference frames');
