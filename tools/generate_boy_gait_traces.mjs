import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const spec=JSON.parse(fs.readFileSync('go_home_mobile/assets/characters/boy.json'));
const scenarios=[];
for(const terrain of ['flat','slope','steps']) {
 const rig=new c._g({...spec,parts:spec.parts.map(p=>({...p,tex:{colorSpace:''}}))});
 const gait=new c.ko(rig,{runArm:c._o.small,downKnee:true,standStart:true,landFix:true});
 const anim=new c.so('crank',180,{jumpWind:'delay',airTuck:true});
 const ground=x=>terrain==='flat'?0:terrain==='slope'?Math.sin(x*.5)*.15:Math.floor(x/1.5)*.025;
 gait.groundAt=ground;
 const frames=[];let x=0,y=0,previousTurn=1;
 for(let i=0;i<720;i++) {
  const dt=1/60,t=i/60;
  const vx=t<.5?0:t<1.5?(t-.5)*2:t<3?2:t<3.5?Math.max(0,2-(t-3)*4):t<4.5?0:t<6?-1.3:t<7?0:t<9?1.6:t<10?.7:0;
  x+=vx*dt;
  const air=t>=7.4&&t<8,vy=air?8.6-(t-7.4)*24:0;
  y=ground(x)+(air?Math.max(0,(t-7.4)*8.6-12*(t-7.4)**2):0);
  const p={vx,vy,grounded:!air,facing:t<4?1:t<6.5?-1:1,wind:t>=7.34&&t<7.4?1:0,pose:{lean:t>=9&&t<10?.7:0,reach:t>=9&&t<10?.7:0,strain:0,shake:0}};
  const frame={rootX:x,rootY:y,facing:p.facing,turnX:previousTurn<0?-1:1};
  const strum=[40,41,120,480].includes(i);if(strum)anim.strum();
  const a=anim.step(dt,p);c.uo(rig,a,spec.parts.find(p=>p.id==='body').at[1]);
  previousTurn=a.turnX;
  gait.snapAnim();gait.step(dt,a.windup&&a.windup.phase!=='release'&&p.grounded?{...p,grounded:false}:p,frame,a);
  frames.push({dt,p,frame,strum,out:Object.fromEntries([...rig.nodes].map(([id,n])=>[id,{x:n.joint.position.x,y:n.joint.position.y,rot:n.joint.rotation.z,sx:n.joint.scale.x,sy:n.joint.scale.y}])),state:{mode:gait.mode,phase:gait.phase,w:gait.w,g:gait.g,reach:gait.reachMiss}});
 }
 scenarios.push({terrain,frames});
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_boy_gait.json',JSON.stringify(scenarios));
console.log('Generated 2160 full skeleton gait reference frames');
