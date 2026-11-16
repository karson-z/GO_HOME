import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const keys=[1,3,5,3],onsets=[0,.5,1,1.5],traces=[];
for(const id of ['sleep-hum','wake-and-resing','answer-during-sing','quiet-errors','listen-errors','late-and-leave','cue-and-nudge','not-ready','resing-fail']){
 const caller=Object.create(c.Ld.prototype),events=[],ctx={dt:1/60,t:0,jt:0,player:{x:12,y:0,grounded:true},keys:null,pops:{spawn(){}}};
 const schedule=[];
 ctx.music={ready:true,now:()=>ctx.t,setAnimalX(){},humBlocked:()=>false,stopPending(){events.push('stop');},wake(){events.push('wake');},
 sing:async(id,x,request)=>{
  schedule.push({...request});
  const start=Math.max(ctx.t+.12,request.notBefore??0);
  return {expected:keys.map((key,i)=>({key,t:start+onsets[i]})),bar:start/2};
 }};
 Object.assign(caller,{o:{id:'test',x:0,y:0,headY:1,wakeR:3.2,hearR:18,resing:id==='resing-fail'?'fail':'two',onWake(){events.push('onWake');},onWrong(){events.push('onWrong');}},x:0,y:0,keys,state:'sleep',echo:{reset(){}},run:null,waiting:false,token:0,wantSing:false,nextHum:-Infinity,wrongT:0,idleT:0,sings:0,hums:0,wrongs:0,lastSungBar:null,
 judge:new c.ad(keys,onsets,c.td.night),lay:null,slots:[],slotGroup:{visible:false,position:{set(){}}},dots:[],failDot:null,shakeT:0,failPending:false,quietWrongs:0,fade:true,painted:[],lastFail:null,autoSings:0,talks:0,talk:null,hint:null,nudge:new c.Pd(),cue:new c.Ad(),cueShown:false,hintParent:null,jAt:null,hintSide:-1,resing:id==='resing-fail'?'fail':'two',fit:true,
 paint(){},heardNote(e,r,i){events.push([r.kind,r.sung.expected[i].key]);}});
 const samples=[];
 for(let frame=0;frame<2400;frame++){
  ctx.t+=ctx.dt;ctx.jt=ctx.t;events.length=0;schedule.length=0;
  ctx.player={x:id==='sleep-hum'?12:frame<20?12:1,y:0,grounded:true};
  ctx.music.ready=id!=='not-ready'||frame>300;
  if(id==='late-and-leave'&&frame>400&&frame<700)ctx.player.x=20;
  let action=null,result=null;
  if(id==='answer-during-sing'&&[36,66,96,126].includes(frame))action=keys[[36,66,96,126].indexOf(frame)];
  if(id==='quiet-errors'&&[35,45,55,65,75,85].includes(frame))action=[35,45,65,85].includes(frame)?1:7;
  if((id==='listen-errors'||id==='resing-fail')&&frame>180&&frame<800&&frame%40===0)action=frame%80===0?1:7;
  if(id==='late-and-leave'&&[180,210,720].includes(frame))action=frame===210?3:1;
  if(action!==null)result=caller.feed(ctx,action);
  caller.update(ctx);await Promise.resolve();
  const state=Object.fromEntries(['state','waiting','token','wantSing','nextHum','idleT','sings','hums','wrongs','quietWrongs','shakeT','failPending','lastFail','lastSungBar','autoSings','talks','cueShown'].map(k=>[k,caller[k]]));
  samples.push({player:ctx.player,ready:ctx.music.ready,action,result,events:structuredClone(events),schedule:structuredClone(schedule),state:{...state,shown:caller.slotGroup.visible,progress:caller.judge.progress,run:caller.run?{kind:caller.run.kind,index:caller.run.i,end:caller.run.endT}:null,
   cue:Object.fromEntries(['on','why','shows','byWhy','opened','fails','stillT'].map(k=>[k,structuredClone(caller.cue[k])])),
   nudge:Object.fromEntries(['count','total','last','idleT','stillT','fails','sinceNudge','nudgeSinging'].map(k=>[k,caller.nudge[k]]))}});
 }
 traces.push({id,keys,onsets,samples});console.log(id,caller.sings,caller.hums,caller.wrongs,caller.quietWrongs,caller.state);
}
fs.writeFileSync(new URL('../go_home_mobile/test/fixtures/original_caller.json',import.meta.url),JSON.stringify(traces));
