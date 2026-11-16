import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const fixtures=[];
for(const id of ['asleep','rise-both','rider-spring','falling-landing','second-bank']){
 const ctx={dt:1/60,player:null,soundAt(){},foley(){}};
 const turtle=Object.assign(Object.create(c.CS.prototype),{ctx,cast2d:true,rings2d:true,crossed:false,surfaces:0,lastTop:[],lastOn:null,trail:[],ring(){},puffBubble(){},T:c.xx.map((x,k)=>({k,pos:{x,top:c.Ix},up:false,riseT:0,riseFrom:c.Ix}))});
 const samples=[];
 for(let frame=0;frame<900;frame++){
  const player={x:0,y:0,safeX:0,safeY:0,grounded:true,coyote:0,vy:0,jumping:false};
  if(id==='rider-spring'&&frame>180&&frame<600){const ps=turtle.shellPlats(turtle.T[0]);player.x=turtle.T[0].pos.x;player.y=c.hS(ps,player.x);player.safeX=8;}
  if(id==='falling-landing'&&frame>180){player.x=turtle.T[0].pos.x;player.y=c.hS(turtle.shellPlats(turtle.T[0]),player.x)-.025;player.vy=-1;player.grounded=false;}
  if(id==='second-bank')player.safeX=frame<200?14.4:20;
  ctx.player={...player};let surface=null;
  if(id!=='asleep'&&frame===20){surface=0;turtle.surface(ctx,turtle.T[0]);}
  if(['rise-both','second-bank'].includes(id)&&frame===150){surface=1;turtle.surface(ctx,turtle.T[1]);}
  turtle.beforeStep(ctx);
  samples.push({player,surface,result:ctx.player,side:turtle.side(),crossed:turtle.crossed,surfaces:turtle.surfaces,shells:turtle.T.map(t=>({x:t.pos.x,top:t.pos.top,riseTime:t.riseT,riseFrom:t.riseFrom,up:t.up,sink:structuredClone(t.sink??{x:0,v:0})})),platforms:turtle.platforms()});
 }
 fixtures.push({id,samples});
}
fs.writeFileSync(new URL('../go_home_mobile/test/fixtures/original_turtle.json',import.meta.url),JSON.stringify(fixtures));
console.log('Generated',fixtures.length*900,'original turtle frames.');
