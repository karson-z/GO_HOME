import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const box={x:1.1,y:.405,z:.27};
let live=box;
const arrival=Object.assign(Object.create(c.gM.prototype),{treeX:0,groundY:0,boxWorld:()=>live});
arrival.buildArrive();
const frames=[];
for(let i=0;i<=6000;i++) {
 const t=i/200;
 live={x:box.x+Math.sin(t)*.03,y:box.y+Math.cos(t)*.02,z:box.z};
 frames.push({t,paths:Object.fromEntries(['loop','long','short'].map(key=>{
  const pose=c.kM(key,t);return [key,{...pose,camera:c.AM(pose,15,-7)}];
 })),title:c.MM(t,'loop'),ease:c.vA(t/30,2,.4),blink:c.LA(t,.9),arrival:arrival.arrivePos(t/30,t),live});
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_ending_flight.json',JSON.stringify(frames));
console.log('Generated 6001 camera/easing/blink/arrival reference frames');
