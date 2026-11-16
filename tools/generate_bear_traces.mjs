import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const dummy=()=>({position:{set(){}},rotation:{},scale:{set(){}},visible:false});
const fixtures=[];
for(const id of ['sleep','follow-sniff','ford-cross-return','strong-seesaw','weak-seesaw']){
 const ctx={dt:1/60,t:0,jt:0,player:null,soundAt(){},foley(){},variant:(k,v)=>v,keys:null};
 const b=Object.assign(Object.create(c.SC.prototype),{ctx,saw:new c.sf(c.MS,-1),bearMode:'sleep',bearPos:{x:4,y:0,z:-.2},bearFrom:{x:0,y:0},bearTo:{x:0,y:0},bearT:0,bearDur:.7,walkV:1.5,bearAccel:true,bearV:0,chase:false,trailing:false,followGap:true,bearArc:2.2,bearPuff:0,bearRear:0,seat:'left',CALL:c.ma(c._C),callLock:new c.Ob(c.ma(c._C),c.id(c._C),c.td.dawn,undefined,1),callGlyphs:[],side:'left',fordFrom:'left',launched:false,launches:0,weak:0,slams:0,calls:0,fords:0,returns:0,scoops:0,sniffT:0,sniffed:false,offPlankT:1,carryVx:0,offT:0,offDir:-1,offTurn:false,backHold:0,flight:'none',look:null,cmdLook:null,rowParent:null,sweepHint:null,sleepTop:c.RS.top,fordHalf:c.HS.half,fordRoot:c.HS.root,fordShift:c.HS.shift,fordX:c.HS.x,
 caller:{judge:{},update(){},state:'awake'},chordBlur:{check(){return false;}},bear:{...dummy(),userData:{head:dummy()}},bearBody:dummy(),seatPaw:dummy(),plank:dummy()});
 b.litCall=()=>{};
 const samples=[];
 for(let frame=0;frame<2400;frame++){
  ctx.t+=ctx.dt;ctx.jt=ctx.t;
  const p={x:1,y:0,vx:0,vy:0,facing:1,grounded:true,jumping:false,airTime:0};
  let action=null;
  if(id!=='sleep'&&frame===20){b.bearMode='aside';action='wake';}
  if(id==='follow-sniff'){p.x=Math.min(34,frame*.025);}
  if(id==='ford-cross-return'){
   p.x=frame<320?8.7:frame<700?12.1:frame<1100?16:frame<1500?18:8;
   p.y=frame>=500&&frame<700?.3:0;
   if(frame===260&&b.fordCallable()){b.called(ctx,true);action='call';}
  }
  if(id.includes('seesaw')){
   p.x=id==='strong-seesaw'?42.05:41.3;
   p.y=c.SC.prototype.support.call(b,p.x,4,.5,b.segs(),.1);
   if(frame===30){b.bearMode='wait';b.bearPos={x:33,y:0,z:-.2};action='place';}
   if(frame===180){b.called(ctx,false);action='call';}
  }
  ctx.player={...p};b.beforeStep(ctx);b.update(ctx);
  samples.push({player:p,action,result:structuredClone(ctx.player),state:structuredClone(Object.fromEntries(['bearMode','bearPos','bearFrom','bearTo','bearT','bearDur','bearV','bearArc','bearPuff','bearRear','seat','side','fordFrom','launched','launches','weak','slams','calls','fords','returns','scoops','sniffT','sniffed','offPlankT','carryVx','offT','offDir','backHold','flight','trailing'].map(k=>[k,b[k]]))),saw:{tilt:b.saw.tilt,target:b.saw.target,slamming:b.saw.slamming,slammed:b.saw.slammed}});
 }
 fixtures.push({id,samples});console.log(id,b.bearMode,b.launches,b.fords);
}
fs.writeFileSync(new URL('../go_home_mobile/test/fixtures/original_bear.json',import.meta.url),JSON.stringify(fixtures));
