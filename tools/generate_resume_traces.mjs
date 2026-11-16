// Execute the shipped nP/EN prototypes offline; no reference JS ships at runtime.
import fs from 'node:fs';
globalThis.location = {search: '?route=main', pathname: '/'};
const c = (await import('./.reference_runtime/BiOZAGIX.js')).__port;
globalThis.document = {
  createElement: () => ({style: {}, remove() {}}),
  body: {appendChild() {}}, querySelector: () => null,
};
const traces = [];
for (const readyAt of [1.6, 99]) {
  const r = Object.create(c.nP.prototype);
  let resolve, fog = 0, time = 0;
  Object.assign(r, {
    rs: null, resumes: 0, ctx: {t: 0},
    handed: false, resumeVeil: null,
    scene: {boy: {g: {}}, ff: {g: {}}},
    saveHooks: {resume: () => new Promise(r => {resolve = r;}), abandon() {}},
    handOver() {this.handed = true;},
  });
  r.beginResume('dusk-hedgehog', 'chapter');
  const frames = [];
  for (let i = 0; i < 850 && r.rs; i++) {
    time += 1 / 60;
    r.ctx.t = time;
    if (resolve && time >= readyAt) {resolve(true); resolve = null; await Promise.resolve();}
    const ready = r.rs.ready;
    r.stepResume(r.ctx);
    fog = r.resumeVeil?.fog ?? 0;
    frames.push({time, ready, phase: r.rs?.phase ?? 'done', opacity: fog});
  }
  traces.push({readyAt, frames});
}
const back = Object.create(c.EN.prototype);
Object.assign(back, {
  back: true, phase: 'clear', A: null, T: null, clickT: null,
  root: {isConnected: true, style: {}}, grain: {style: {}}, grainA: .13,
  fogCv: {draw() {}}, noiseClear: true, host: {},
  finish(p) {this.phase = p;},
});
const backFrames = [];
for (let i = 0; i <= 30; i++) {
  const time = i / 60;
  back.tick(time);
  backFrames.push({time, progress: c.Q(time / c.CN)});
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_resume.json', JSON.stringify({timing: c.XN, shade: c.ZN(c.YN), traces, backFrames}));
console.log('Exported original resume, timeout and back-menu clocks');
