import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const vector=()=>({set(){},setScalar(){}});
const fixture=[];
for(const id of ['sleep','scan-and-command','held-release','falling-ride','ridge-finish']){
 const o=Object.create(c.rE.prototype),caller={state:'awake',update(){}};
 const ctx={dt:1/60,t:0,player:{x:-2,y:0,grounded:true,jumping:false,vy:0,airTime:0},world:{camera:{position:{x:0}}},music:{reward(){}},soundAt(){},foley(){},pops:{spawn(){}},finish(){}};
 Object.assign(o,{ctx,c1:caller,c2:caller,stage:0,halfT:0,eyeOpen:[.15,.15],turn:.9,scanT:-1,wakeFlap:0,mode:'sleep',pos:{...c.oT},from:{...c.oT},to:{...c.oT},flyT:0,flyDur:1,at:null,target:null,puff:0,shake:0,perk:0,
 branches:c.CT.map(b=>({...b,k:0,animT:-1,dir:null,held:false,k0:0,solid:false,steps:c.NT(b,0),stepsK:0,flash:0,tagA:0,wobble:0,leafMat:{}})),
 solved:false,commands:0,refused:0,rides:0,rideSkips:0,ignored:0,landings:[],walked:[],spots:[],song:[],songI:0,songT:0,
 look1:null,look2:null,owl:{position:vector(),rotation:vector(),scale:vector()},glasses:{scale:{}},eyes:[],wings:[],tufts:[],moon:{position:vector()},syncRows(){},drawBranch(){}});
 const samples=[];
 for(let frame=0;frame<900;frame++){
  ctx.t+=ctx.dt;let action=null;
  ctx.player={x:-2,y:0,grounded:true,jumping:false,vy:0,airTime:0};
  if(id!=='sleep'&&frame===0){o.halfWake();action='half';}
  if(id!=='sleep'&&frame===40){o.fullWake();action='wake';}
  if(id==='scan-and-command'&&frame>=80&&frame%130===80){const branch=Math.floor((frame-80)/130)%5;o.command(ctx,branch);action=branch;}
  if((id==='held-release'||id==='falling-ride')&&frame===80){o.command(ctx,0);action=0;}
  if((id==='held-release'||id==='falling-ride')&&frame>=170&&frame<340){
   const step=o.branches[0].steps[12];ctx.player={x:(step.minX+step.maxX)/2,y:step.maxY,grounded:true,jumping:false,vy:0,airTime:0};
   if(id==='falling-ride'){ctx.player.y+=.12;ctx.player.grounded=false;ctx.player.vy=-1;ctx.player.airTime=.1;}
  }
  if((id==='held-release'||id==='falling-ride')&&frame===220){o.command(ctx,1);action=1;}
  if(id==='ridge-finish'&&frame>200){ctx.player={x:26,y:6.3,grounded:true,jumping:false,vy:0,airTime:0};}
  const player=structuredClone(ctx.player);o.update(ctx);
  samples.push({action,player,resultPlayer:ctx.player,state:structuredClone(Object.fromEntries(['stage','halfT','eyeOpen','turn','scanT','wakeFlap','mode','pos','from','to','flyT','flyDur','at','target','puff','shake','perk','solved','commands','refused','rides','rideSkips','ignored','landings','walked','spots','song','songI','songT'].map(k=>[k,o[k]]))),
   branches:o.branches.map(b=>({k:b.k,animT:b.animT,dir:b.dir,held:b.held,k0:b.k0,solid:b.solid,flash:b.flash,tagA:b.tagA,wobble:b.wobble,stepsK:b.stepsK,stepSum:b.steps.reduce((s,p)=>s+p.maxY,0)})),platforms:o.platforms().length});
 }
 fixture.push({id,samples});console.log(id,o.commands,o.rides,o.rideSkips,o.solved);
}
fs.writeFileSync(new URL('../go_home_mobile/test/fixtures/original_owl.json',import.meta.url),JSON.stringify(fixture));
