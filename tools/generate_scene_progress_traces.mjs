// Offline oracle for the shipped tj/ZA checkpoint indicator, including its SVG.
import fs from 'node:fs';
globalThis.location = {search: '?route=main', pathname: '/'};
const c = (await import('./.reference_runtime/BiOZAGIX.js')).__port;
class Element {
  attrs = {}; style = {}; children = []; innerHTML = '';
  setAttribute(k, v) { this.attrs[k] = String(v); }
  append(...children) { this.children.push(...children); }
  replaceChildren(...children) { this.children = children; }
  remove() {}
}
globalThis.document = {createElement: () => new Element(),
  createElementNS: () => new Element(), body: new Element()};
function paths(el) {
  return [...(el.attrs.d ? [el.attrs.d] : []),
    ...[...el.innerHTML.matchAll(/ d="([^"]+)"/g)].map(m => m[1]),
    ...el.children.flatMap(paths)];
}
const chapters = JSON.parse(fs.readFileSync('go_home_mobile/assets/data/original_route.json')).layout.segs.map(s => s.def.chapter);
const data = {n: chapters.length, cur: 3, done: chapters.map((_, i) => i < 3), chapters, cleared: false};
const traces = [];
for (const kind of ['enter', 'done']) {
  const toast = new c.tj();
  toast.show(data, kind === 'enter' ? 3 : 2, kind);
  const frames = [];
  for (let i = 0; i < 180; i++) {
    const dt = i % 23 === 0 ? .033 : 1/60;
    toast.update(dt);
    frames.push({dt, age: toast.t, active: toast.active,
      opacity: toast.active ? c.ej(toast.t) : 0,
      swapped: toast.swapped,
      paths: toast.active && [0, 14, 29, 59, 149].includes(i) ? paths(toast.path.svg) : null});
  }
  traces.push({kind, frames});
}
const path = new c.ZA(data, 140, 18, {scale: .8});
fs.writeFileSync('go_home_mobile/test/fixtures/original_scene_progress.json', JSON.stringify({chapters, points: path.pts, traces}));
console.log('Exported 360 original checkpoint frames and SVG geometry');
