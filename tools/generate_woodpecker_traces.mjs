import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const noop=()=>{};
const fixtures=[];
for(const id of ['success','split-third','miss-and-retry','leave-and-return']){
 let now=0;
 const ctx={dt:1/60,t:0,jt:0,player:{x:16,y:0,grounded:true},soundAt:noop,foley:noop,finish:noop,world:{scene:{}},music:{setAnimalX:noop,ready:true,now:()=>now,engine:{barTime:x=>x*2,outputDelay:()=>0},wake:noop,reward:noop,humBlocked:()=>false,keysOf:()=>c.ma(c._w),sing:async(animal,x,req)=>{
   const start=Math.ceil((Math.max(now+.4,req.notBefore??0))/2-1e-6)*2;
   return{bar:start/2,expected:req.call.notes.map((n,i)=>({t:start+(n.bar*16+n.step)*.125,key:req.call.keys[i]}))};
 }}};
 const rules={input:noop,ended:noop,leave:noop,failed:noop,newRound:noop,sang:noop,canAuto:false,talked:()=>false,nudgeDue:()=>false,hint:{update:noop,host:noop},fx:{update:noop}};
 const b=Object.assign(Object.create(c.nT.prototype),{ctx,baseCall:c._w,round:0,split:null,rounds:0,r3Fails:0,roundFails:0,halves:0,mode:'idle',modeT:0,angle:c.nw,omega:0,crack:0,joined:false,drums:0,hums:0,fails:0,wrongKeys:0,offBeats:0,misses:0,empties:0,ignored:0,win:null,lastWin:null,run:null,waiting:false,token:0,nextHum:-Infinity,wantDrum:false,lastEnd:0,crackBumped:false,peckPlan:[],beatK:null,lag:new c.XC('auto',()=>0),lagRestored:true,gapBars:1,loose:true,rules,wood2:true,jcue:new c.Ad(),five:{a:0,update:noop,pressed:noop},fiveTurns:0,fiveT:0,fiveWasTurn:false,holes:[],dots:[],tapLog:[],glyphs:{},pegs:null,crackLine:{},drumLine:null,crackLen:0,birdHTo:1.05,birdH:1.05,birdLx:.42,birdOffX:0,jab:0,bob:0,fallStart:0,perchT:Infinity,perchChipped:true,stump:{visible:false},fiveWasTurn:false});
 b.setTarget();for(const k of ['updateCursor','updatePegs','updateLights','draw','clearDots','resetHoles','clearMarks','goHome','puff','spawnChips'])b[k]=noop;
 b.heardPeck=noop;b.addMark=()=>({});b.lightOf=()=>({showMine:noop,breakMine:noop});b.beakAt=()=>({x:0,y:0});
 const samples=[];let fedStart=null;
 for(let frame=0;frame<4800;frame++){
   now+=ctx.dt;ctx.t=ctx.jt=now;
   ctx.player={x:id==='leave-and-return'&&frame>700&&frame<1050?3:16,y:0,grounded:true,vy:0};
   const notes=[];
   if(b.win&&b.mode==='listen'){
    for(let i=0;i<b.keys.length;i++){
     const at=b.win.start+b.onsets[i]+b.lag.now;
     if(now-ctx.dt<at&&now>=at){
      if(id==='miss-and-retry'&&b.fails<1&&i===2)continue;
      const degree=id==='split-third'&&b.round===2&&b.split===null&&i===2?3:b.keys[i];
      b.onNote(ctx,degree);notes.push(degree);
     }
    }
   }
   b.update(ctx);await Promise.resolve();await Promise.resolve();
   samples.push({player:structuredClone(ctx.player),notes,state:{mode:b.mode,round:b.round,split:b.split,rounds:b.rounds,r3Fails:b.r3Fails,halves:b.halves,modeTime:b.modeT,angle:b.angle,omega:b.omega,crack:b.crack,drums:b.drums,hums:b.hums,fails:b.fails,empties:b.empties,ignored:b.ignored,lag:b.lag.shift,start:b.win?.start??null}});
 }
 fixtures.push({id,samples});console.log(id,b.mode,b.rounds,b.fails,b.halves);
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_woodpecker.json',JSON.stringify(fixtures));
