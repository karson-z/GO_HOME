import fs from 'node:fs';
import {createCanvas} from '@napi-rs/canvas';
globalThis.document={baseURI:'http://localhost/',createElement:()=>createCanvas(1,1)};
globalThis.location={search:'?route=main',pathname:'/'};
const a=(await import('./.reference_runtime/2-dEIWs8.js')).__port;
const data=JSON.parse(fs.readFileSync('go_home_mobile/assets/data/original_route_audio.json'));
const rows=[];
const groups=[[],['shaker'],['organ'],['organ','firefly'],['hedgehog','squirrel'],['bassoon','owl','clarinet'],['turtle','bear','horn'],data.song.layers.map(l=>l.id)];
for(const [id,call] of Object.entries(data.calls))for(const ids of groups)for(const earliest of [0,.2,.999999,1,1.01,3.5,8.1,12.7,23.2])for(const fitWithin of [null,1,4]){
 const layers=data.song.layers.filter(l=>ids.includes(l.id)),grid=a.Bt(layers),first=earliest*4,allow=a.Rt(call.animal,data.song.harmonyLoop);
 const q=fitWithin!==null&&grid?a.Wt(call,grid,first,4,fitWithin*4,allow):fitWithin===null?(grid?a.Ut(call,grid,first,4,allow):a.Pt(call,a.At(data.song.harmonyLoop),first,4,allow)):Math.min(a.Pt(call,a.At(data.song.harmonyLoop),first,4,allow),Math.ceil((first-1e-6)/4)*4+fitWithin*4);
 rows.push({id,ids,earliest,fitWithin,bar:Math.floor(q/4)});
}
const chords=['C',' Cmaj ','Dbmin','F#M7','Abmin7','Gsus2','Bb7','Cdim','Daug','C/E','N.C.','Dm6'].map(text=>({text,result:a.kt(text)?[...a.kt(text)]:null}));
fs.writeFileSync('go_home_mobile/test/fixtures/original_call_music.json',JSON.stringify({rows,chords}));
console.log(`Exported ${rows.length} original harmonic searches`);
