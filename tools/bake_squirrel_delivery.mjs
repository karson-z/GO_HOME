// Bake the shipped default vy rig, including its contact solver and bag.
// Movement is indexed by logical path distance; actions by actT. The runtime
// still owns commands, timing, routes and fruit state (no recorded gameplay).
import fs from 'node:fs';
globalThis.location = {search: '?route=main', pathname: '/'};
const c = (await import('./.reference_runtime/BiOZAGIX.js')).__port;
const l = (await import('./.reference_runtime/Da-Ct4tY.js')).__port;
const raw = JSON.parse(fs.readFileSync('go_home_mobile/assets/characters/squirrel.json'));
const trace = JSON.parse(fs.readFileSync('go_home_mobile/test/fixtures/original_squirrel.json'))[0].samples;
const driver = new c.vy(l.jd(raw, {colorSpace: ''}), c.ug(), c.Ay());
const proxy = new c.x();
const ids = [...driver.rig.nodes.keys()];
const frameNames = ids.map(id => Object.keys(driver.rig.nodes.get(id).part.frames));
const geometries = [], materials = [], gs = new Map(), ms = new Map();
function node(o) {
  o.updateMatrix();
  const n = {name:o.name, matrix:o.matrix.toArray(), visible:o.visible,
    order:o.renderOrder, children:o.children.map(node)};
  if (o.geometry) {
    if (!gs.has(o.geometry)) {
      gs.set(o.geometry, geometries.length);
      geometries.push({attributes:Object.fromEntries(Object.entries(o.geometry.attributes).map(([k,a]) =>
        [k,{size:a.itemSize,values:Array.from(a.array)}])),index:o.geometry.index?Array.from(o.geometry.index.array):null});
    }
    n.geometry=gs.get(o.geometry);
  }
  if (o.material) {
    const m=o.material;
    if (!ms.has(m)) {
      ms.set(m, materials.length);
      materials.push({vertex:m.vertexShader,fragment:m.fragmentShader,
        uniforms:Object.fromEntries(Object.entries(m.uniforms).map(([k,u])=>[k,u.value?.isColor?{color:u.value.toArray()}:u.value])),
        depthTest:m.depthTest,depthWrite:m.depthWrite,side:m.side,transparent:m.transparent});
    }
    n.material=ms.get(m);
  }
  return n;
}
const prop=node(driver.sat.g.parent);
fs.writeFileSync('go_home_mobile/assets/characters/squirrel-bag.json', JSON.stringify({geometries,materials,root:prop}));
const clips = {};
let target=0;
for (let index=0; index<trace.length; index++) {
  const sample=trace[index], s=sample.state;
  if (s.target>=0) target=s.target;
  const flick=Math.max(0,1-s.taskT*4);
  const inHole=s.mode==='sleep'||(s.mode==='home'&&Math.hypot(s.pos.x-c.E_.x,s.pos.y-c.E_.y)<c.k_);
  proxy.scale.setScalar(inHole?.8*.9/1.35:.8*(1+flick*.06));
  proxy.rotation.y=(['sleep','perch','out','home'].includes(s.mode)?sample.player.x>=s.pos.x:s.dir>0)?0:Math.PI;
  // Replay the plan object identity as zv does: it mutates the array in place.
  // vy captures the full route once when go()/startCarry()/finishAct() replaces it.
  const key=`${target}:${s.mode}:${s.act??''}`;
  if (!driver._stage || driver._stage!==`${target}:${s.mode}`) {
    driver._stage=`${target}:${s.mode}`;
    driver._plan=[];
  }
  driver._plan.splice(0,driver._plan.length,...sample.plan.map(p=>p.to?{to:p.to}:{act:p.act}));
  driver.sync({...s, sq:proxy, plan:driver._plan, flick, shake:0,
    caller:{wrongs:0}, waiting:s.mode==='perch', climbV:c.rv.climb,downV:c.rv.down,runV:c.rv.run},1/60,true,{x:0,y:0,z:0,holeZ:-.015});
  if (!['go','carry','back'].includes(s.mode)) continue;
  const rig=driver.rig, carry=driver.carryView({x:25,y:c.hv[target].socketY},.04);
  const data=[...rig.group.position.toArray().map((v,i)=>v-[s.pos.x,s.pos.y,s.pos.z][i]),
    rig.group.rotation.z,rig.group.scale.x,rig.group.scale.y,rig.flip.scale.x,
    rig.root.position.x,rig.root.position.y];
  for (const id of ids) {
    const n=rig.nodes.get(id),j=n.joint;
    data.push(j.position.x,j.position.y,j.rotation.z,j.scale.x,j.scale.y,frameNames[ids.indexOf(id)].indexOf(n.frame),+j.visible);
  }
  data.push(['bag','mouth','paw','socket'].indexOf(carry.at),carry.x-s.pos.x,carry.y-s.pos.y,carry.s,carry.sx,carry.sy);
  // The prop hierarchy is static except these three source nodes.
  for (const o of [driver.sat.g,driver.sat.body,driver.sat.flap]) data.push(o.position.x,o.position.y,o.scale.x,o.scale.y);
  data.push(driver.bagHoleA);
  (clips[key]??=[]).push([s.act?s.actT:0,s.pos.x,s.pos.y,s.pos.z,sample.plan.filter(p=>p.to).length,...data].map(v=>+v.toFixed(9)));
}
fs.writeFileSync('go_home_mobile/assets/characters/squirrel-delivery.json',JSON.stringify({version:1,fps:60,ids,frameNames,clips}));
console.log(Object.entries(clips).map(([k,v])=>`${k}: ${v.length}`).join('\n'));
console.log('bag meshes',geometries.length,'materials',materials.length);
