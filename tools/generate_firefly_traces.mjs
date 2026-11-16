import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const noop=()=>{};
function node(){return{position:{set:noop},rotation:{z:0},scale:{setScalar:noop},visible:true};}
function material(){const color={copy(){return this;},lerp:noop};return{opacity:1,color};}
const fixtures=[];
for(const id of ['whole-shortcut','four-round-relay','wrong-drill','follow-scout-home']){
 let now=0;
 const ctx={dt:1/60,t:0,jt:0,player:{x:4,y:0,facing:1,grounded:true},finish:noop,pops:{spawn:noop},hud:{flash:noop},music:{ready:true,now:()=>now,wake:noop,setAnimalX:noop,humBlocked:()=>false,beatPos:()=>({bars:now/2}),sing:async(animal,x,req)=>{
  const start=Math.ceil(Math.max(now+.4,req.notBefore??0)/2-1e-6)*2;
  const keys=c.ma(req.call);
  return{bar:start/2,expected:req.call.notes.map((n,i)=>({t:start+(n.bar*16+n.step)*.125,key:keys[i]}))};
 }}};
 const full=c.Zf.at(-1),steps=c.Zf;
 const b=Object.assign(Object.create(c.kh.prototype),{ctx,hint:'num',flies:c.Rm.map((s,i)=>({deg:i+1,x:s.x,y:s.top+.14,z:-.35,flash:0,hurt:0,hold:0,back:1,gone:false,g:node(),belly:{material:material(),scale:{setScalar:noop}},halo:{material:material(),scale:{setScalar:noop}},color:{}})),keys:full.keys,full,steps,ladder:new c.Yf(steps.map(e=>({keys:c.ma(e),onsets:c.id(e)})),c.td.dusk),whole:c.od(full,c.td.dusk),lays:steps.map(e=>c.cd(c.id(e))),failPending:false,phase:'sleep',run:null,waiting:false,token:0,wantSing:false,nextHum:-Infinity,phaseT:0,idleT:0,slotGroup:node(),newLook:true,assist:'auto',numbersSwitch:false,fallback:false,fbLook:'white',rowOp:0,slotsOn:false,slots:[],shards:[],slices:[],cliffs:[],blades:[],boughs:[],scoutLog:[],scoutN:0,swarm:{x:c.Bm,y:2},at:0,swarmGlow:{...node(),material:material()},teach:null,shownStage:-1,bushBlades:[],stems:c.Rm,stemGroups:c.Rm.map(()=>node()),relayOn:true,v17:true,glide:{v:0,t:0,to:-1},finished:false,homeGlow:1,relays:0,drill:null,wantDrill:false,drills:0,rules:{sang:noop,ended:noop,leave:noop,failed:noop,input:noop,newRound:noop,talked:()=>false,nudgeDue:()=>false,afterFail:()=>false,second:()=>false,canAuto:false,hint:{},update:noop,fx:{hit:noop}},lateAt:0,swayK:0,flashes:[],sings:0,hums:0,wrongs:0,shatters:0,rounds:0,humEnd:0,cueSung:{i:-1,until:0}});
 let phrase=null,pos=[];
 b.teach={tap:noop,show(e){phrase=e;pos=c.Up(e,c.Rm);},hide(){phrase=null;},slotOf(d){const i=phrase?.keys.indexOf(d)??-1;return i<0?null:{...pos[i],z:.55};},quiet:d=>!!phrase&&!phrase.keys.includes(d),arrivedDeg:noop,demo:noop,sung:noop,pressed:noop,fadeMarks:noop,cue:noop,boyAt:noop,update:noop,degAt:i=>phrase?.keys[i]??0};
 b.buildSlots=()=>{b.slots=b.ladder.target.map(()=>({}));};b.paintSlots=noop;b.shatter=d=>{b.fly(d).hurt=1;b.shatters++;};b.sawBy=()=>[];
 const samples=[];let sequence=null,sequenceAt=0,sequenceI=0,sequenceStage=-1,lastPhase='',bad=false;
 for(let frame=0;frame<3600;frame++){
  now+=ctx.dt;ctx.t=ctx.jt=now;
  ctx.player={x:b.awake&&id==='follow-scout-home'?Math.min(29,4+(now-4)*1.1):4,y:0,facing:1,grounded:true};
  const notes=[];
  if(id==='whole-shortcut'&&frame>=120&&frame<=180){const index=[120,150,165,180].indexOf(frame);if(index>=0)notes.push(full.keys[index]);}
  if(id!=='whole-shortcut'&&!b.awake&&b.phase==='listen'){
   if(sequenceStage!==b.ladder.stage||sequence===null){sequence=[...b.ladder.target];sequenceAt=now+.25;sequenceI=0;sequenceStage=b.ladder.stage;}
   const ons=c.id(b.steps[b.ladder.stage]);
   if(sequenceI<sequence.length&&now>=sequenceAt+ons[sequenceI]){
    let deg=sequence[sequenceI];
    if(id==='wrong-drill'&&b.ladder.stage===2&&sequenceI===1&&!bad){sequenceAt-=.4;bad=true;}
    else{notes.push(deg);sequenceI++;}
   }
  }
  if(b.phase==='wrong'){sequence=null;sequenceStage=-1;}
  if(b.phase==='lead'&&id==='follow-scout-home'&&frame%120===0)notes.push(frame/120%7+1);
  for(const degree of notes)b.onNote(ctx,degree);
  b.update(ctx);await Promise.resolve();await Promise.resolve();
  samples.push({player:structuredClone(ctx.player),notes,state:{phase:b.phase,stage:b.ladder.stage,progress:b.ladder.progress,phaseTime:b.phaseT,rounds:b.rounds,wrongs:b.wrongs,shatters:b.shatters,sings:b.sings,hums:b.hums,relays:b.relays,drills:b.drills,station:b.at,scouts:b.scoutN,swarmX:b.swarm.x,swarmY:b.swarm.y,glideV:b.glide.v,finished:b.finished,flies:b.flies.map(f=>({x:f.x,y:f.y,z:f.z,flash:f.flash,hurt:f.hurt,gone:f.gone}))}});
 }
 fixtures.push({id,samples});console.log(id,b.phase,b.rounds,b.wrongs,b.sings,b.drills);
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_firefly.json',JSON.stringify(fixtures));
