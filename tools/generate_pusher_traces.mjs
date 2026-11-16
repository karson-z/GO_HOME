import fs from 'node:fs';import path from 'node:path';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const physics=(await import('./.reference_runtime/2-dEIWs8.js')).__port;
const floor={name:'floor',minX:-10,maxX:10,minY:-6,maxY:0};
const scenarios=[
{id:'stump-ramp-rest-and-return',spawn:[-3.2,0],bodies:[['stump',-2.5,0,.9,.9,{speed:1,rests:[.55],bounds:{minX:-6.2,minY:-3}}]],world:[floor,{name:'ledge',minX:1,maxX:7,minY:0,maxY:1.9}],frames:1000,input:i=>({move:i<500?1:-1,jump:false})},
{id:'heavy-tree-strain',spawn:[0,0],bodies:[['snag',.6,0,.4,4.6,{heavy:true}]],world:[floor],frames:280,input:i=>({move:i<200?1:-1,jump:false})},
{id:'ball-edge-tip-gravity-and-dead-reset',spawn:[0,0],bodies:[['ball',.65,0,.8,.8,{speed:1.5,bounds:{minY:-3},dead:'low',deadAfter:.6}]],world:[{...floor,maxX:2}],frames:380,input:i=>({move:1,jump:false})},
{id:'corner-reset',spawn:[-3,0],bodies:[['box',.5,0,.9,.9,{}]],world:[floor,{name:'wall',minX:1,maxX:2,minY:0,maxY:5}],frames:300,input:i=>({move:0,jump:false})},
{id:'multiple-bodies',spawn:[-2,0],bodies:[['a',0,0,.9,.9,{}],['b',2,0,.8,.8,{}]],world:[floor],frames:720,input:i=>({move:i<400?1:-1,jump:i%240>180&&i%240<205})},
];
for(const s of scenarios){
 const push=new c.Nh();for(const b of s.bodies){const opts=structuredClone(b[5]);if(opts.dead==='low')opts.dead=b=>b.y<-.5;push.add(new c.jh(...b.slice(0,5),opts));}
 const p=physics.A(...s.spawn);s.samples=[];
 for(let frame=0;frame<s.frames;frame++){
  const input=s.input(frame),actual={...input};const r=push.step(p,actual,1/60,s.world);physics.j(p,actual,1/60,[...s.world,...push.platforms()]);
  s.samples.push(structuredClone({input,move:actual.move,result:{moved:r.moved.map(b=>b.id),started:r.started.map(b=>b.id),reset:r.reset.map(b=>b.id)},
   player:{x:p.x,y:p.y,vx:p.vx,vy:p.vy,grounded:p.grounded,pose:p.pose},
   bodies:push.bodies.map(b=>Object.fromEntries(['x','y','vy','alpha','fade','pushing','roll','resets','lastReset','effort','blockedT','cornerT','deadT'].map(k=>[k,b[k]])))}));
 }
 delete s.input;
}
fs.writeFileSync(path.resolve(import.meta.dirname,'../go_home_mobile/test/fixtures/original_pusher.json'),JSON.stringify(scenarios));
console.log('Wrote',scenarios.reduce((n,s)=>n+s.frames,0),'source pushing frames');
