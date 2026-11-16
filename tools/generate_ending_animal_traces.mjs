import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const l=(await import('./.reference_runtime/Da-Ct4tY.js')).__port;
const scenarios=[];
for(const [kind,art] of Object.entries({hedgehog:'hedgehog-side',hedgehogOld:'hedgehog',squirrel:'squirrel',bat:'bat-side',batFront:'bat',woodpecker:'woodpecker',owl:'owl',turtle:'turtle',turtle2:'turtle2'})) {
 const raw=JSON.parse(fs.readFileSync(`go_home_mobile/assets/characters/${art}.json`));
 const spec=l.jd(raw,{colorSpace:''}),rig=new c.Bg(spec,c.ug(),{ppm:280*Math.max(1,l.bE[kind].k)});
 rig.setScale(l.bE[kind].k);
 const driver=new l.SE(kind,rig),frames=[];
 for(let i=0;i<480;i++) {
  const dt=i%117===6?0:i%71===9?.09:1/60,time=i/60;
  const hidden=i>=190&&i<210;
  const input={x:4+Math.sin(time*2.1)*.65,y:.3+Math.max(0,Math.sin(time*1.3))*.3,z:Math.sin(time)*.2,floorY:.3,progress:(time%2)/2,time,dt,swapFx:i>=240};
  if(hidden)driver.hide();else driver.drive({x:input.x,y:input.y,z:input.z},input.floorY,input.progress,time,dt,.6,input.swapFx);
  frames.push({input,hidden,state:{dist:driver.dist,air:driver.air,shownT:driver.shownT,wasShown:driver.wasShown},
   position:rig.group.position.toArray(),facing:rig.facing,opacity:rig.propU.uOpacity.value,footY:rig.quadMat.uniforms.uFootY.value,
   clipY:rig.propU.uClipY.value,clipSoft:rig.quadMat.uniforms.uClipSoft.value,
   out:Object.fromEntries([...rig.nodes].map(([id,n])=>[id,{x:n.joint.position.x,y:n.joint.position.y,rot:n.joint.rotation.z,sx:n.joint.scale.x,sy:n.joint.scale.y,frame:n.frame,visible:n.joint.visible}]))});
 }
 scenarios.push({kind,art,frames});rig.dispose();
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_ending_animal_motion.json',JSON.stringify(scenarios));
console.log(`Exported ${scenarios.length*480} original SE animal skeleton frames`);
