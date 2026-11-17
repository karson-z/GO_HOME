import fs from 'node:fs';
globalThis.location = {search: '?route=main', pathname: '/'};
const c = (await import('./.reference_runtime/BiOZAGIX.js')).__port;
const l = (await import('./.reference_runtime/Da-Ct4tY.js')).__port;
const raw = JSON.parse(fs.readFileSync('go_home_mobile/assets/characters/squirrel.json'));
const scenarios = [];
for (const [mode, facing] of [['sleep', 1], ['sleep', -1], ['home', -1]]) {
  const driver = new c.vy(l.jd(raw, {colorSpace: ''}), c.ug(), c.Ay());
  const sq = new c.x();
  sq.position.set(13.5, 2.2, .02);
  sq.scale.setScalar(.8 * .9 / 1.35);
  sq.rotation.y = facing > 0 ? 0 : Math.PI;
  const state = {mode, pos: {x: 13.5, y: 2.4, z: .45}, sq,
    plan: [], caller: {wrongs: 0}, shake: 0, homeT: 1};
  const frames = [];
  for (let i = 0; i < 240; i++) {
    const dt = i % 97 === 12 ? 0 : i % 71 === 21 ? .09 : 1 / 60;
    state.flick = Math.max(0, 1 - Math.abs(i - 120) / 10);
    driver.sync(state, dt, mode !== 'sleep', {x: 0, y: 0, z: -3.202, holeZ: -.015});
    const rig = driver.rig;
    frames.push({dt, flick: state.flick,
      position: rig.group.position.toArray(), scale: rig.scale,
      clipY: rig.propU.uClipY.value, wake: rig.wake, edge: rig.quadMat.uniforms.uEdgeK.value,
      out: Object.fromEntries([...rig.nodes].map(([id, n]) => [id,
        {x: n.joint.position.x, y: n.joint.position.y, rot: n.joint.rotation.z}]))});
  }
  scenarios.push({mode, facing, frames});
  driver.rig.dispose();
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_squirrel_pose.json', JSON.stringify(scenarios));
console.log(`Exported ${scenarios.length * 240} original vy squirrel frames`);
