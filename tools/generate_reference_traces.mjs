// Executes only the original CPU simulation, offline, to produce Dart parity fixtures.
import fs from 'node:fs';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'..');
globalThis.location={search:'?route=main',pathname:'/'};
const physics=(await import('./.reference_runtime/2-dEIWs8.js')).__port;
const core=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const route=JSON.parse(fs.readFileSync(path.join(root,'go_home_mobile/assets/data/original_route.json')));
const floor={name:'floor',minX:-20,maxX:20,minY:-6,maxY:0};
const scenarios=[
 {id:'held-jump',spawn:[0,0],colliders:[floor],frames:180,input:i=>({move:i<100?1:0,jump:i>=12&&i<65})},
 {id:'tap-jump-and-reverse',spawn:[0,0],colliders:[floor],frames:180,input:i=>({move:i<60?1:-1,jump:(i>=12&&i<14)||(i>=100&&i<113)})},
 {id:'stairs-and-ceiling',spawn:[-2,0],colliders:[floor,{name:'step',minX:0,maxX:1,minY:0,maxY:.3},{name:'wall',minX:4,maxX:5,minY:0,maxY:5},{name:'ceiling',minX:1,maxX:4,minY:2.1,maxY:3}],frames:300,input:i=>({move:i<180?1:-1,jump:i%60>=10&&i%60<35})},
 {id:'coyote-buffer-and-respawn',spawn:[0,0],colliders:[{...floor,maxX:1},{name:'far',minX:4,maxX:7,minY:-6,maxY:0}],frames:480,input:i=>({move:1,jump:i%90>=35&&i%90<60})},
 {id:'unsafe-platform-checkpoint',spawn:[0,0],colliders:[{...floor,maxX:1},{name:'unsafe',minX:1,maxX:3,minY:-6,maxY:0,unsafe:true}],frames:300,input:i=>({move:1,jump:false})},
 {id:'original-opening-walk',spawn:[1,10],colliders:route.layout.terrain,frames:2200,input:i=>({move:i<2050?1:0,jump:i%270>=110&&i%270<135})},
];
const numberKeys=['x','y','vx','vy','facing','coyote','buffer','airTime','safeX','safeY','lock','holdT','wind','tapT','tapCut'];
const boolKeys=['grounded','jumping','prevJump','holdOn','tapped','jumpAir','windJump'];
const traces=[];
for(const scenario of scenarios){
 const p=physics.A(...scenario.spawn),samples=[];
 for(let i=0;i<scenario.frames;i++){
  const input=scenario.input(i), result=physics.j(p,input,1/60,scenario.colliders);
  samples.push({input,state:Object.fromEntries([...numberKeys.map(k=>[k,p[k]??0]),...boolKeys.map(k=>[k,p[k]??false])]),result});
 }
 traces.push({id:scenario.id,spawn:scenario.spawn,colliders:scenario.colliders,samples});
}
const cameras=[];
for(const aspect of [16/9,19.5/9,4/3]){
 const cam={aspect,position:{set(x,y,z){cam.pos=[x,y,z]}},lookAt(x,y,z){cam.look=[x,y,z]},updateProjectionMatrix(){}};
 const rig=new core.$s(cam,route.layout.zones);
 rig.snap(1,10);
 const samples=[];
 for(let i=0;i<1600;i++){
  const x=1+i*.53,y=i<100?10:6.5+Math.sin(i*.01)*6,grounded=i%120<80,vx=Math.sin(i*.02)*2;
  rig.hold=i>=300&&i<350?{pos:[160,14,22],look:[162,9,0],smooth:.6,release:1}:null;
  rig.update(1/60,x,y,vx,2,grounded);
  samples.push({input:{x,y,vx,grounded,hold:rig.hold},state:{x:rig.x,y:rig.y,d:rig.dist,ahead:rig.ahead,groundY:rig.groundY,framing:rig.framing,pos:cam.pos,look:cam.look}});
 }
 cameras.push({aspect,samples});
}
const out=path.join(root,'go_home_mobile/test/fixtures');
fs.mkdirSync(out,{recursive:true});
fs.writeFileSync(path.join(out,'original_physics.json'),JSON.stringify(traces));
fs.writeFileSync(path.join(out,'original_camera.json'),JSON.stringify(cameras));
console.log(`${traces.reduce((n,s)=>n+s.samples.length,0)} physics frames, ${cameras.reduce((n,s)=>n+s.samples.length,0)} camera frames`);
