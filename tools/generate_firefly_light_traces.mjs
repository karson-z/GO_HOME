// Execute the shipped fog-look controllers; this is reference tooling only.
import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};
const l=(await import('./.reference_runtime/Da-Ct4tY.js')).__port;
const nodes=[];
const root={add(...items){nodes.push(...items);}};
const camera={position:{x:0,y:0,z:22}};
const source=l.ay({game:{world:{camera}},actors:new Map([['hero',{group:root}]])});
const size=[];
for(const distance of [0,3,4,8,14,22,35,80]) {
 for(const glow of [0,.3,.65,1]) {
  Object.assign(l.ur,{active:false,startFF:{on:true,x:0,y:0,z:0,glow}});
  camera.position.z=distance;
  source.update();
  const get=name=>nodes.find(n=>n.name==='start-firefly-'+name);
  size.push({distance,glow,returningTime:null,size:{glow:get('glow').scale.x,core:get('core').scale.x,coreAlpha:get('core').material.opacity,amber:get('amber').scale.x,amberAlpha:get('amber').material.opacity,amberVisible:get('amber').visible}});
 }
}
for(const time of [14,14.2,14.8,15,15.002001,15.2,15.8,16,17.5]) {
 Object.assign(l.ur,{active:true,down:true,key:'loop',t:time,ff:{x:0,y:0,z:0},glow:.7,startFF:{on:false}});
 source.update();
 const get=name=>nodes.find(n=>n.name==='start-firefly-'+name);
 size.push({distance:l.An('loop',time).D,glow:.7,returningTime:time,size:{glow:get('glow').scale.x,core:get('core').scale.x,coreAlpha:get('core').material.opacity,amber:get('amber').scale.x,amberAlpha:get('amber').material.opacity,amberVisible:get('amber').visible}});
}
const tex=l.iy().image;
const leadNodes=[];
const ground=x=>10-Math.max(0,Math.min(28,x-20))*.125;
const lead=l.ly({scene:{add(...n){leadNodes.push(...n);}},worldRoot(){},ox:0,surface:{x0:-100,x1:100,smooth:ground}});
const frames=[];
for(let i=0;i<1800;i++) {
 const dt=i%13===0?1/30:1/60;
 let x=i<900?3.28+i*.08:i<1100?75.28-(i-900)*.2:3.28+(i-1100)*.11;
 const opening=i<30?{on:true,x:9.28,y:10.275,z:-.7}: {on:false};
 Object.assign(l.ur,{startFF:opening,active:i>=1720&&i<1740});
 lead.update({dt,player:{x}});
 let light=null;
 lead.glows((x,y,z,r,c,k)=>{light={x,y,z,r,color:[c.r,c.g,c.b],k};});
 const [a,b]=leadNodes;
 frames.push({dt,x,opening:opening.on?opening:null,endingActive:l.ur.active,visible:a.visible,position:{x:a.position.x,y:a.position.y,z:a.position.z},alpha:a.material.opacity,coreAlpha:b.material.opacity,light});
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_firefly_light.json',JSON.stringify({texture:Buffer.from(tex.data).toString('base64'),size,frames}));
console.log('Exported source iy/ay/ly: '+size.length+' sizes, '+frames.length+' motion frames.');
