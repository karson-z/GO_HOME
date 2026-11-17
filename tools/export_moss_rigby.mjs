// Convert the existing Moss cutout rig to a native Rigby2D workfile.
// Requires the upstream checkout at tools/.reference_runtime/rigby2d (no npm install).
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Skeleton, makeBone, makeSlot, makeAttachment } from './.reference_runtime/rigby2d/src/core/model.js';
import { Affine, transform } from './.reference_runtime/rigby2d/src/core/math.js';
import { Animation, makeKey } from './.reference_runtime/rigby2d/src/core/animation.js';
import { Pose } from './.reference_runtime/rigby2d/src/core/pose.js';
import { zip, unzip } from './.reference_runtime/rigby2d/src/editor/zip.js';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = path.join(root, 'artifacts/companion-moss');
const output = path.join(source, 'rigby2d');
const units = 800;
const rig = JSON.parse(await fs.readFile(path.join(source, 'moss-rig.json'), 'utf8'));
const motion = JSON.parse(await fs.readFile(path.join(source, 'motion.json'), 'utf8'));
const parts = [];
const remaining = [...rig.parts];
while (remaining.length) {
  const i = remaining.findIndex(p => !p.parent || parts.some(q => q.id === p.parent));
  if (i < 0) throw new Error('Cyclic part hierarchy');
  parts.push(remaining.splice(i, 1)[0]);
}
const indices = new Map(parts.map((p, i) => [p.id, i + 1]));
const affine = values => new Affine(...values.slice(0, 4), values[4] * units, values[5] * units);
const local = (frame, part) => {
  const world = affine(frame.bones[part.id]);
  if (!part.parent) return world.decompose();
  const parent = affine(frame.bones[part.parent]);
  if (Math.abs(parent.determinant()) < 1e-9) throw new Error(`Singular parent: ${part.parent}`);
  return parent.inverse().mul(world).decompose();
};
const unwrap = (value, previous) => previous === undefined ? value : value + Math.round((previous - value) / 360) * 360;
const doc = new Skeleton();
doc.name = 'Moss / 苔音';
doc.workspace = 'game';
doc.settings = { fps: 30, width: 512, height: 512, background: null,
  frame: { x: .0912 * units, y: .8664 * units, scale: 2.28 * units / 512 } };
doc.settingsInFile = true;
const setupFrame = motion.clips.find(c => c.id === 'idle').frames[0];
for (const part of parts) {
  doc.bones.push(makeBone(part.id, part.parent ? indices.get(part.parent) : 0, local(setupFrame, part), 0));
}
const entries = [];
for (const part of [...parts].sort((a,b) => a.layer - b.layer)) {
  const bytes = new Uint8Array(await fs.readFile(path.join(source, part.image)));
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  doc.images.push({ name: part.id, path: `images/${part.id}.png`, width: view.getUint32(16), height: view.getUint32(20) });
  const offset = transform((.5 - part.pivot[0]) * part.size[0] * units,
    (.5 - part.pivot[1]) * part.size[1] * units);
  doc.slots.push(makeSlot(part.id, indices.get(part.id),
    makeAttachment(part.id, part.id, offset, part.size[0] * units, part.size[1] * units)));
  entries.push({ path: `images/${part.id}.png`, bytes });
}
for (const clip of motion.clips) {
  const anim = new Animation(clip.id, clip.duration);
  for (const part of parts) {
    const index = indices.get(part.id);
    const setup = doc.bones[index].setup;
    const tl = anim.boneTimelineMut(index);
    let previousRotation = setup.rotation, previousShear = setup.shear_y;
    for (const frame of clip.frames) {
      const value = local(frame, part);
      value.rotation = unwrap(value.rotation, previousRotation);
      value.shear_y = unwrap(value.shear_y, previousShear);
      previousRotation = value.rotation; previousShear = value.shear_y;
      tl.translate.push(makeKey(frame.t, [value.x - setup.x, value.y - setup.y]));
      tl.rotate.push(makeKey(frame.t, value.rotation - setup.rotation));
      tl.scale.push(makeKey(frame.t, [value.scale_x / setup.scale_x, value.scale_y / setup.scale_y]));
      tl.shear.push(makeKey(frame.t, [value.shear_x - setup.shear_x, value.shear_y - setup.shear_y]));
    }
    // Hold the last sampled pose for the remainder of its 1/30 second frame.
    if (clip.duration > clip.frames.at(-1).t) {
      for (const channel of ['translate', 'rotate', 'scale', 'shear'])
        tl[channel].push(makeKey(clip.duration, tl[channel].at(-1).value));
    }
  }
  doc.animations.push(anim);
}
const validation = doc.validate();
if (validation) throw new Error(validation);
const json = doc.toJson();
const file = zip([{ path: 'project.json', bytes: new TextEncoder().encode(json) }, ...entries]);
// Reload the actual native archive with upstream's ZIP reader and model parser.
const reopened = Skeleton.fromJson(new TextDecoder().decode(unzip(file).get('project.json')));
const reports = [];
let maxError = 0;
const preview = { units, parts: rig.parts, clips: [] };
for (const clip of motion.clips) {
  const anim = reopened.animations.find(a => a.name === clip.id);
  const pose = new Pose(reopened);
  let error = 0;
  const frames = [];
  for (const frame of clip.frames) {
    pose.reset(reopened);
    pose.apply(reopened, anim, frame.t, 1);
    pose.updateWorld(reopened);
    const bones = {};
    for (const part of parts) {
      const actual = pose.world[indices.get(part.id)];
      const expected = affine(frame.bones[part.id]);
      for (const key of ['a','b','c','d','tx','ty']) error = Math.max(error, Math.abs(actual[key] - expected[key]));
      bones[part.id] = [actual.a,actual.b,actual.c,actual.d,actual.tx/units,actual.ty/units];
    }
    frames.push({ ...frame, bones });
  }
  maxError = Math.max(maxError, error);
  reports.push({ clip: clip.id, title: clip.title, frames: clip.frames.length, duration: clip.duration, maxAffineError: error });
  preview.clips.push({ ...clip, frames });
}
if (maxError > 1e-6) throw new Error(`Runtime pose mismatch: ${maxError}`);
await fs.mkdir(output, { recursive: true });
await fs.writeFile(path.join(output, 'Moss-苔音.rigby'), file);
await fs.writeFile(path.join(output, 'project.json'), json);
await fs.writeFile(path.join(output, 'runtime-poses.json'), JSON.stringify(preview));
const report = { upstream: 'https://github.com/jaisurya-dev-art/rigby2d',
  commit: 'db59320a749ad7960d84ebb0409abec7fdfb6e02', version: '0.5.1',
  bones: reopened.bones.length, slots: reopened.slots.length, images: entries.length,
  animationCount: reports.length, sourceFrameCount: reports.reduce((n,c) => n+c.frames, 0),
  maxAffineError: maxError, nativeArchiveReload: 'passed', officialRuntimePoseComparison: 'passed', clips: reports };
await fs.writeFile(path.join(output, 'validation.json'), JSON.stringify(report, null, 2));
console.log(JSON.stringify(report, null, 2));
