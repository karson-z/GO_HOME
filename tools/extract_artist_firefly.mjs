import fs from 'node:fs';
import {createCanvas, DOMMatrix, DOMPoint, Path2D} from '@napi-rs/canvas';
globalThis.location={search:'?route=main',pathname:'/'};
Object.assign(globalThis,{DOMMatrix,DOMPoint,Path2D});
globalThis.document={createElement:()=>createCanvas(1,1)};
const l=(await import('./.reference_runtime/Da-Ct4tY.js')).__port;
const output='go_home_mobile/assets/characters';
fs.writeFileSync(`${output}/artist-firefly.json`, JSON.stringify({
  height:.36,box:[-.32,-.12,.32,.36],
  parts:[{id:'sheet',parent:null,at:[0,0],layer:0,rest:0,
    frames:{a:{uv:[0,0,1,1],size:[.64,.48],pivot:[.5,.25]}},frame0:'a'}],anchors:{},
  vectorParts:l._M.firefly2.parts,
}));
for(const [name,fn] of [['halo',l.VF],['core',l.HF]]) {
 const t=fn(); fs.writeFileSync(`${output}/artist-firefly-${name}.png`, t.image.toBuffer('image/png'));
 t.dispose();
}
console.log('Exported source WF vector outlines, patches and both 128px gradient textures');
