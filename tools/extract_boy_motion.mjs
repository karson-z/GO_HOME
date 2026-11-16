import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
fs.writeFileSync('go_home_mobile/assets/data/original_boy_motion.json',JSON.stringify({tuning:c.Ka,poses:c.Xa('low',true),crank:c.Fa,riseKeys:c.Wj,gait:c.go,curves:c.ho,runArm:c._o.small}));
const scenarios=[];
for(const mode of ['lift','shake','crank'])for(const wind of ['anim','delay','off']) {
 const a=new c.so(mode,180,{jumpWind:wind,airTuck:true});
 const frames=[];
 for(let i=0;i<960;i++) {
  const dt=i%31===0?.05:1/60,t=i/60;
  const air=t>=2&&t<2.7||t>=5&&t<6.1||t>=9&&t<9.6;
  const vy=t>=9&&t<9.6?-3-(t-9)*24:air?(t<3?8.6-(t-2)*24:8.6-(t-5)*24):0;
  const vx=t<1?0:t<4?1.4:t<7?2:t<8?0:t<11?-1.2:0;
  const p={vx,vy,grounded:!air,facing:t<7?1:-1,lead:t<4?'B':'F',wind:t>=1.94&&t<2||t>=4.94&&t<5?1:0,pose:{reach:t>12?.6:0,lean:t>12?.8:0,strain:t>12?.5:0,shake:t>13&&t<14?t-13:0}};
  const strum=[30,35,190,620,624,625].includes(i);
  if(strum)a.strum();
  frames.push({dt,p,strum,out:a.step(dt,p)});
 }
 scenarios.push({mode,wind,frames});
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_boy_motion.json',JSON.stringify(scenarios));
console.log('Wrote 8640 source animation reference frames');
