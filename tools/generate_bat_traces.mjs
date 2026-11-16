import fs from 'node:fs';
import {createCanvas} from '@napi-rs/canvas';
globalThis.location={search:'?route=main',pathname:'/'};
globalThis.document={createElement:()=>createCanvas(128,128)};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const v=()=>({set(){}});
const fixtures=[];
for(const id of ['sleep','wake-echoes','alternating-echoes','finish']){
 const b=Object.create(c.dx.prototype),caller={state:'awake',update(){}};
 const ctx={dt:1/60,t:0,jt:0,player:{x:0,y:0,grounded:true},world:{add(){}},music:{ready:true},foley(){},soundAt(){},finish(){}};
 Object.assign(b,{ctx,stage:0,halfT:0,eyeOpen:.2,c1:caller,c2:caller,mode:'sleep',pos:{x:9.6,y:3.55},from:{x:9.6,y:3.55},flyT:0,roost:-1,demoT:-1,demoDone:false,flap:0,twitch:0,
 ledges:c.rx.map(l=>({...l,lit:0,litAt:-99,hold:2.5,shown:0,parts:[]})),rings:[],pending:[],group:null,
 echoCount:0,calls:{5:0,7:0},switches:0,wrongs:0,deadVisits:0,onDeadBefore:false,foot:null,finale:false,night:0,
 look1:null,look2:null,chordLinks:null,chordBlur:{check(){}},bat:{position:v(),rotation:{}},eyes:[],wings:[],ears:[],keyGroup:{position:v()},keyGlyphs:[{material:{}},{material:{}}],keyIcons:[{},{}],hint:'num',keyMoteGroup:null,
 syncRow(){},updateSky(){}});
 const samples=[];
 for(let i=0;i<900;i++){
  ctx.t+=ctx.dt;let action=null;
  if(id!=='sleep'&&i===0){b.halfWake();action='half';}
  if(id!=='sleep'&&i===30){b.stage=2;b.toRoost(0);action='wake';}
  if(id==='alternating-echoes'&&i>120&&i%80===0){const degree=i%160===0?5:7;b.call(degree);action=degree;}
  ctx.player={x:id==='sleep'?0:Math.min(37,i*.045),y:id==='finish'?1.2:0,grounded:true};
  if(id==='alternating-echoes'&&i>350&&i<420)ctx.player={x:17.9,y:1.45,grounded:true};
  b.update(ctx);
  samples.push(structuredClone({action,player:ctx.player,state:Object.fromEntries(['stage','halfT','eyeOpen','mode','pos','from','flyT','roost','demoT','demoDone','flap','twitch','echoCount','calls','switches','wrongs','deadVisits','onDeadBefore','foot','finale','night','group'].map(k=>[k,b[k]])),
   ledges:b.ledges.map(l=>({lit:l.lit,litAt:l.litAt,hold:l.hold,shown:l.shown})),rings:b.rings.map(r=>({x:r.x,y:r.y,degree:r.deg,time:r.t})),pending:b.pending.map(r=>({degree:r.deg,time:r.t}))}));
 }
 fixtures.push({id,samples});console.log(id,b.mode,b.echoCount,b.finale);
}
fs.writeFileSync(new URL('../go_home_mobile/test/fixtures/original_bat.json',import.meta.url),JSON.stringify(fixtures));
