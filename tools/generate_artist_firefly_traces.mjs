import fs from 'node:fs';
import {DOMMatrix,DOMPoint} from '@napi-rs/canvas';
globalThis.location={search:'?route=main',pathname:'/'};
Object.assign(globalThis,{DOMMatrix,DOMPoint});
const l=(await import('./.reference_runtime/Da-Ct4tY.js')).__port;
const parts=l._M.firefly2.parts;
const ids=new Map(Object.entries(parts).map(([k,v])=>[v,k]));
const frames=[];
for(const move of ['fly','hover','land','rest','takeoff']) {
 for(let i=0;i<360;i++) {
  const t=i/60-.15,climb=Math.sin(t*2)*1.4,glow=i%3===0?.12:l.tP(t);
  const c=l.sP.moves[move](t,{glow,climb:Math.round(climb*4)/4});
  frames.push({t,move,climb,glow,lamp:c.lamp,parts:c.parts.map(e=>({id:ids.get(e.part),m:[e.m.a,e.m.b,e.m.c,e.m.d,e.m.e,e.m.f],alpha:e.alpha??1,far:e.far??false,v:e.v??null,g:e.g??0,b:e.b??0}))});
 }
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_artist_firefly.json',JSON.stringify(frames));
console.log(`Exported ${frames.length} source sP/iP firefly matrix frames`);
