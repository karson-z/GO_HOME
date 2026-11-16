import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const l=(await import('./.reference_runtime/Da-Ct4tY.js')).__port;
const raw=JSON.parse(fs.readFileSync('go_home_mobile/assets/characters/bear.json'));
const smooth=(a,b,x)=>{const t=Math.max(0,Math.min(1,(x-a)/(b-a)));return t*t*(3-2*t)};
const ground=x=>-1.75*smooth(9.85,10.55,x)*(1-smooth(13.65,14.35,x));
const scenarios=[];
for(const name of ['sleep-wake-walk','turn-stop','leap-sit-getoff','bank','sniff-teleport']) {
 const spec={...raw,box:Object.fromEntries(['x0','y0','x1','y1'].map((k,i)=>[k,raw.box[i]])),tex:{colorSpace:''},anchors:raw.anchors??{},parts:raw.parts.map(p=>({...p,rest:p.rest??0,frame0:p.frame0??Object.keys(p.frames)[0]}))};
 const rig=new c.Bg(spec,c.ug(),{accent:'#a33a31',sleepProp:.6});
 const motion=new l.WT(rig,l.iE({}).motion);motion.turnCut=true;
 let x=name==='bank'?8:0;
 const frames=[];
 for(let i=0;i<900;i++) {
  const dt=i===700?0:i===701?.12:1/60,t=i/60;
  let mode='follow',v=0,face=1,y=0,arcT=0,sniffT=0,puff=0,keys=0;
  if(name==='sleep-wake-walk') {mode=t<3?'sleep':t<5?'aside':'follow';v=t>=5&&t<13?Math.min(2,(t-5)*.8):0;puff=t<2?(Math.sin(t*6)+1)*.5:0;keys=t>=2&&t<3?Math.floor((t-2)*8):0;}
  if(name==='turn-stop') {v=t<1?0:t<4?1.4:t<5?0:t<8?-1.7:t<9?0:t<12?.4:0;face=t<4.5||t>=9?1:-1;}
  if(name==='leap-sit-getoff') {mode=t<1?'follow':t<1.2?'leap':t<2.2?'leap':t<4?'sit':t<5?'stay':t<6?'getoff':t<8?'follow':t<9?'leap':t<11?'sit':t<12?'getoff':'follow';arcT=t<1.2?-1:t<2.2?t-1.2:t<6?t-5:t<9?t-8:t<12?t-11:0;v=mode==='getoff'?(t<6?.7:-.7):mode==='follow'?.4:mode==='leap'&&arcT>=0?1:0;y=mode==='leap'&&arcT>=0?Math.max(0,4*arcT*(1-arcT)):0;}
  if(name==='bank') {mode=t<1?'follow':t<3?'wade':t<9?'ford':t<12?'climb':'follow';v=t<1?1:t<3?.8:t<9?.25:t<12?1:.4;y=mode==='ford'?-1.265:ground(x);arcT=mode==='wade'?(t-1)/2:mode==='climb'?(t-9)/3:0;}
  if(name==='sniff-teleport') {mode=t<1?'sleep':t<3?'aside':t<9?'follow':t<11?'aside':'follow';v=t>=7&&t<9?1.8:t>=11?-.6:0;face=t<11?1:-1;sniffT=t>=3&&t<6.9?6.9-t:0;puff=(Math.sin(t*5)+1)*.2;if(i===720)x+=5;}
  x+=v*dt;
  const inp={dt,x,y,mode,face,puff,sniffT,keys,arcT,girlOnBack:name==='bank'&&t>=4&&t<8,girlX:x+Math.cos(t)*2,girlY:y+1.2+Math.sin(t),hasSit:true};
  if(name==='bank') inp.bank={G:ground,minX:10,maxX:14.2,fordY:-1.115,waterY:-.35};
  motion.step(inp);rig.update(Math.min(.1,dt));
  const {bank,...input}=inp;
  frames.push({input,out:Object.fromEntries([...rig.nodes].map(([id,n])=>[id,{x:n.joint.position.x,y:n.joint.position.y,rot:n.joint.rotation.z,sx:n.joint.scale.x,sy:n.joint.scale.y,frame:n.frame,visible:n.joint.visible}])),root:[rig.root.position.x,rig.root.position.y],state:{phase:motion.phase,vf:motion.vf,facing:motion.facing,pitch:motion.lastPitch,hipY:motion.hipY,shoulderY:motion.shoulderY,bodyFrame:motion.bodyFrame,footfalls:[...motion.footfalls]}});
 }
 scenarios.push({name,frames});rig.dispose();
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_bear_motion.json',JSON.stringify(scenarios));
console.log('Generated 4500 original bear full skeleton frames');
