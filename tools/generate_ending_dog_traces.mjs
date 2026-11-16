import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const l=(await import('./.reference_runtime/Da-Ct4tY.js')).__port;
const raw=JSON.parse(fs.readFileSync('go_home_mobile/assets/characters/fam-dog.json'));
const rig=new c.Bg(l.jd(raw,{colorSpace:''}),c.ug(),{ppm:200});
const driver=new l.IE('dog',rig),frames=[];
const actions=['run','walk','bounce','pounce','lie','stand','run','lie','stand','walk'];
for(let i=0;i<1080;i++) {
 const dt=i%137===6?0:i%83===9?.09:1/60,time=i/60;
 const hidden=i>=350&&i<370;
 const act=actions[Math.floor(i/108)%actions.length];
 const input={x:4+Math.sin(time*1.1)*1.65,y:.3+Math.max(0,Math.sin(time*1.3))*.3,z:Math.sin(time)*.2,face:i%151<72?1:-1,act,k:Math.min(1,(i%108)/20),time,dt,groundY:.3,alpha:.96-.3*Math.sin(time)**2,lift:.9,mode:i<440?'pre':i<820?'choreo':'leave',touchKey:i>=540&&i<800?'boy:head':''};
 if(i>=240)input.v=i<820?.6+Math.sin(time)*.4:0;
 if(hidden)driver.hide();else driver.drive({p:{x:input.x,y:input.y,z:input.z},face:input.face,act,k:input.k,t:time,dt,groundY:input.groundY,alpha:input.alpha,lift:input.lift,mode:input.mode,paletteT:.6,v:input.v,touch:input.touchKey?{who:'boy',at:'head'}:undefined});
 frames.push({input,hidden,state:{dist:driver.dist,vS:driver.vS,shownFor:driver.shownFor,shown:driver.shown,act:driver.act,mode:driver.mode,touchKey:driver.touchKey},position:rig.group.position.toArray(),facing:rig.facing,squash:rig.squash,flipVisible:rig.flip.visible,opacity:rig.propU.uOpacity.value,lift:rig.quadMat.uniforms.uLift.value,footY:rig.quadMat.uniforms.uFootY.value,out:Object.fromEntries([...rig.nodes].map(([id,n])=>[id,{x:n.joint.position.x,y:n.joint.position.y,rot:n.joint.rotation.z,sx:n.joint.scale.x,sy:n.joint.scale.y}]))});
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_ending_dog_motion.json',JSON.stringify(frames));
rig.dispose();console.log(`Exported ${frames.length} source IE dog skeleton frames`);
