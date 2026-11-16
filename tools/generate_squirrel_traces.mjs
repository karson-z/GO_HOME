import fs from 'node:fs';
import {createCanvas} from '@napi-rs/canvas';
globalThis.location={search:'?route=main',pathname:'/'};globalThis.document={createElement:()=>createCanvas(128,128)};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const fixtures=[];
for(const id of ['collect-all','busy-wrong-and-repeat','abort-carry','door-response']){
 const ctx={dt:1/60,t:0,jt:0,player:{x:14,y:0},soundAt(){},foley(){},pops:{spawn(){}},variant:(k,v)=>v,
 music:{now:()=>ctx.t,ready:true,reward(){},sing:async()=>({expected:c.Y_.map((key,i)=>({key,t:ctx.t+.12+c.X_[i]}))})}};
 const squirrel=Object.assign(Object.create(c.zv.prototype),{ctx,pos:c.kv(c.E_.x,c.E_.y),mode:'sleep',plan:[],act:null,actT:0,taskT:0,target:-1,dir:1,vert:0,climbV:c.rv.climb,downV:c.rv.down,runV:c.rv.run,longMid:c.Mv(true),hang:true,climbOld:false,sq2Old:false,bagMode:'branch',actSec:c.ov('branch'),outT:0,homeT:-1,homeFrom:null,homeFace:1,flick:0,shake:0,pickShow:0,
 commands:0,refused:0,ignored:0,lostCount:0,aborted:0,caller:{state:'awake',feed:()=>false},look:null,cmdMode:'key',
 fruits:c.hv.map(f=>({...f,state:'hang',x:f.hang.x,y:f.hang.y,t:0,ring:0,flash:0,socket:{material:{}},bellKey:{visible:false,position:{y:1},material:{}}})),
 doorJudge:new c.ad(c.Y_,c.X_,c.td.dusk),doorLook:{snap(){},played(){},heard(){},update(){},rowOpacity:0,fallback:false},doorLike:{},doorGlow:{material:{},visible:false},doorTok:0,doorRun:null,doorWaiting:false,bellsSung:false,allT:-1,callT:0,chimeQ:[],doorIdle:0,doorFailPending:false,doorSings:0,doorWrongs:0,doorY:0,doorShake:0,doorOpen:false,chimeT:-1,sunT:0,sunset:0,numbersSwitch:false});
 const samples=[];let next=0,doorStart=null;
 for(let frame=0;frame<4800;frame++){
  ctx.t+=ctx.dt;ctx.jt=ctx.t;
  if(squirrel.allBells)ctx.player.x=18;
  const actions=[];
  if(frame===20){squirrel.mode='out';squirrel.outT=0;actions.push('wake');}
  if(squirrel.mode==='perch'&&next<3){const degree=[6,7,1][next++];squirrel.onNote(ctx,degree);actions.push(degree);}
  if(id==='busy-wrong-and-repeat'&&frame>80&&frame%37===0){squirrel.onNote(ctx,2);actions.push(2);}
  if(id==='abort-carry'&&squirrel.mode==='carry'&&squirrel.aborted===0){squirrel.taskT=31;actions.push('timeout');}
  if(id==='door-response'&&squirrel.bellsSung&&doorStart===null)doorStart=frame+150;
  if(doorStart!==null){const j=c.X_.findIndex(t=>frame===doorStart+Math.round(t*60));if(j>=0){const key=c.Y_[j];squirrel.onNote(ctx,key);actions.push(key);}}
  squirrel.stepSquirrel(ctx);
  if(squirrel.mode!=='home'){squirrel.homeT=-1;squirrel.homeFrom=null;}
  if(squirrel.mode==='perch'&&(squirrel.doorOpen||squirrel.allBells))squirrel.mode='home';
  squirrel.flick=Math.max(0,squirrel.flick-ctx.dt*4);squirrel.shake=Math.max(0,squirrel.shake-ctx.dt);
  squirrel.stepDoor(ctx);await Promise.resolve();
  samples.push({actions,player:{...ctx.player},state:structuredClone(Object.fromEntries(['mode','pos','act','actT','taskT','target','dir','vert','outT','homeT','homeFace','homeFrom','commands','refused','ignored','lostCount','aborted','doorOpen','doorWrongs','doorSings','doorIdle','chimeT','bellsSung','doorWaiting','allT','callT','doorFailPending'].map(k=>[k,squirrel[k]]))),fruits:squirrel.fruits.map(f=>f.state),plan:structuredClone(squirrel.plan)});
 }
 fixtures.push({id,samples});console.log(id,squirrel.fruits.map(f=>f.state),squirrel.doorOpen,squirrel.commands);
}
fs.writeFileSync(new URL('../go_home_mobile/test/fixtures/original_squirrel.json',import.meta.url),JSON.stringify(fixtures));
