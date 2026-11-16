import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const L=c.MD(2.8),fixtures=[];
for(const aspect of [16/9,19.5/9]){
 const ctx={player:{x:1,y:0},t:0,world:{camera:{aspect}}};
 const e=Object.assign(Object.create(c.JP.prototype),{ctx,L,swapFx:'mist',finaleV:'f',swapped:{},api:{e2:true,camRight:0},members:new Map(c.GP.map(w=>[w,{who:w,rig:w==='dog'?c.aO():c.iO(w),at:null}])),beasts:new Map(c.qP.map(id=>[id,{id,g:c.sO(id).g}])),bear:c.sO('bear').g,boy:c.oO(),reflections:new c.x(),puddleFace:{material:{}},boyPos:{x:1,y:0,z:.25}});
 const frames=[];
 for(let i=0;i<6000;i++){
  const bar=i/120;ctx.t=bar*2;
  if(bar>=34)e.api.camRight=(.25-.16)*2*c.lE(22,aspect)*c.Q((bar-36)/1.5);
  for(const s of c.yD)if((bar-s.change)*2>=-.033)e.swapped[s.id]=true;
  e.shot=e.cameraAt(bar);e.updateRider(bar,bar*4);e.updateAnimals(bar,bar*4);e.updateFamily(bar,bar*4);e.updateBoy(bar,bar*4);
  frames.push({bar,camera:e.shot,bear:{x:e.bear.position.x,y:e.bear.position.y,z:e.bear.position.z,lie:e.bearLie},boy:e.boyPos,family:Object.fromEntries([...e.members].map(([w,m])=>[w,{x:m.x,y:m.y,z:m.z,face:m.face,shown:m.shown}])),animals:Object.fromEntries([...e.beasts].map(([w,m])=>[w,{x:m.x,y:m.y,z:m.z,shown:m.shown}]))});
  ctx.player.x=e.boyPos.x;ctx.player.y=e.boyPos.y;
 }
 fixtures.push({aspect,frames});
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_ending_ride.json',JSON.stringify(fixtures));
console.log('Generated 12000 ending ride/actor/camera frames');
