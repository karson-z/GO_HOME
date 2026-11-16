import fs from 'node:fs';import path from 'node:path';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port,p=(await import('./.reference_runtime/2-dEIWs8.js')).__port;
const traces=[];
for(const id of ['stump','wake-ball-bridge','ball-coast','round-top']){
 const h=Object.create(c.yb.prototype);Object.assign(h,{pusher:new c.Nh(),mode:'sleep',h:{x:5,y:1.5999999999999999,dir:1,t:0,vx:0},puff:0,curls:0,rolls:0,snagState:'stand',snagT:0,hitAt:null,coast:0,coasted:0});
 h.stump=h.pusher.add(new c.jh('stump',-2.5,0,.9,.9,{speed:1,rests:[.55],bounds:{minX:-6.2,minY:-3}}));
 h.ball=h.pusher.add(new c.jh('ball',5,1.9,.8,.8,{speed:1.5,bounds:{minY:-3},drawInset:c.rb(false),dead:b=>b.y<1.4,deadAfter:.6}));h.ball.enabled=false;
 h.snag=h.pusher.add(new c.jh('snag',12.9,0,.4,4.6,{heavy:true}));
 const spawn=id==='stump'?[-4,0]:id==='round-top'?[5.1,2.7]:[3.8,1.9];
 const player=p.A(...spawn),ctx={dt:1/60,t:0,player,soundAt(){},variant:(k,v)=>v};
 if(id==='wake-ball-bridge')h.mode='wake';if(id==='ball-coast'||id==='round-top')h.curl(ctx);
 const samples=[];
 for(let frame=0;frame<1500;frame++){
  ctx.t+=ctx.dt;const input={move:id==='round-top'?0:id==='wake-ball-bridge'&&frame<100?0:id==='ball-coast'?(frame<100?1:0):1,jump:id==='stump'&&frame%200>130&&frame%200<170};
  const actual={...input};h.beforeStep(ctx,actual);p.j(player,actual,1/60,[...c.hb,...h.platforms()]);
  samples.push(structuredClone({input,move:actual.move,player:{x:player.x,y:player.y,vx:player.vx,vy:player.vy,grounded:player.grounded},state:{mode:h.mode,snagState:h.snagState,snagT:h.snagT,h:h.h,curls:h.curls,rolls:h.rolls,hitAt:h.hitAt,coast:h.coast,coasted:h.coasted},bodies:h.pusher.bodies.map(b=>({x:b.x,y:b.y,roll:b.roll,enabled:b.enabled,fade:b.fade,alpha:b.alpha}))}));
 }
 traces.push({id,spawn,world:c.hb,samples});console.log(id,h.mode,h.snagState,player.x,player.y);
}
fs.writeFileSync(path.resolve(import.meta.dirname,'../go_home_mobile/test/fixtures/original_hedgehog.json'),JSON.stringify(traces));
