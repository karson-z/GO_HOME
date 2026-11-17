// Execute the supplied game's Ky hint against approach, reset and push cases.
import fs from 'node:fs';
import {createCanvas, Path2D} from '@napi-rs/canvas';
globalThis.Path2D = Path2D;
globalThis.location = {search: '?route=main', pathname: '/'};
globalThis.document = {createElement: () => createCanvas(1, 1)};
const c = (await import('./.reference_runtime/BiOZAGIX.js')).__port;
const scenarios = [];
for (const [id, x, y, w, h, seed] of [
  ['stump', -2.5, 0, .9, .9, 53], ['ball', 5, 1.9, .8, .8, 59],
]) {
  const body = new c.jh(id, x, y, w, h);
  const hint = new c.Ky(new c.x(), body, (key, fallback) => fallback, seed);
  const frames = [];
  function frame(label, gap = 1, patch = {}, player = {}, dt = .1) {
    Object.assign(body, {x, y, enabled: true, alpha: 1, fade: 'none', pushing: 0}, patch);
    const p = {x: body.minX - .25 - gap, y, grounded: true, ...player};
    hint.update(dt, p);
    frames.push({label, dt, body: {x: body.x, y: body.y, enabled: body.enabled,
      alpha: body.alpha, fade: body.fade, pushing: body.pushing}, p,
      out: {done: hint.done, on: hint.on, shows: hint.shows, a: hint.tip.a,
        base: hint.tip.base, dodge: hint.tip.dodge, x: hint.tip.cx, y: hint.tip.by,
        drawY: hint.tip.s.position.y, w: hint.tip.w, h: hint.tip.h}});
  }
  frame('outside lead', 3.001);
  frame('at lead', 3);
  for (let i = 0; i < 5; i++) frame('approaching', 2 - i * .3);
  frame('airborne', 1, {}, {grounded: false});
  frame('different level', 1, {}, {y: y + .151});
  frame('standing on body', 0, {}, {y: y + h});
  frame('behind body', -w - .5);
  frame('past contact tolerance', -.051);
  frame('disabled', 1, {enabled: false});
  frame('nearly transparent', 1, {alpha: .499});
  frame('fading out', 1, {fade: 'out'});
  frame('waiting for reset', 1, {fade: 'wait'});
  frame('fading in', 1, {fade: 'in'});
  frame('reset visible again');
  frame('coasting does not finish', 1, {x: x + .4});
  frame('short push', 0, {x: x + .299, pushing: 1});
  frame('completed push', 0, {x: x + .301, pushing: 1});
  for (let i = 0; i < 10; i++) frame('stays completed after reset');
  scenarios.push({id, x, y, w, h, frames});
  hint.dispose();
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_push_hints.json', JSON.stringify(scenarios));
console.log(`Generated ${scenarios.reduce((n, s) => n + s.frames.length, 0)} original push hint frames`);
