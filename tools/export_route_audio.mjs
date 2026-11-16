import fs from 'node:fs/promises';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const a=(await import('./.reference_runtime/2-dEIWs8.js')).__port;
const root=new URL('../',import.meta.url);
const read=async p=>JSON.parse(await fs.readFile(new URL(p,root),'utf8'));
const song=a.Tt(await read('source/extracted/game/score/songs/route-main.json'));
for(const l of song.layers)delete l.alt;
const calls=await read('go_home_mobile/assets/data/calls.json');
const config={song,calls,segments:c.ms,chains:c.xs,groups:c.js,entry:c.ys,resume:c.Ps,cueDucks:c.ps,sleepers:c.Cs,occlusion:c.Ts,trail:c.Es,ambience:c.Ds,gates:c.Os,drips:c.ks,delayed:c.Ss,shapes:Object.fromEntries(song.layers.map(l=>[l.id,a.yt(l.id)]).filter(x=>x[1])),priority:a.Gt,mix:a.Dt(),callGains:Object.fromEntries(Object.values(calls).map(call=>[call.id,a.Et(call.animal??call.id.split('-')[0],song.id,undefined,call.id)]))};
const notes=new Map();
for(const l of song.layers)for(const v of l.variants)for(const n of v.notes)register(l.instrument,n);
for(const call of Object.values(calls))for(const n of call.notes)register(call.instrument,n);
for(let d=1;d<=7;d++)register('musicbox',{midi:c.fa(d),len:4});
function register(inst,n){const key=JSON.stringify([inst,n.midi,n.len,n.shape??null]);if(!notes.has(key))notes.set(key,{id:`v${notes.size}`,inst,midi:n.midi,len:n.len,shape:n.shape??null});n.voice=notes.get(key).id;}
config.voices=[...notes.values()];
config.player=Array.from({length:7},(_,i)=>{const n={midi:c.fa(i+1),len:4};register('musicbox',n);return n.voice;});
await fs.writeFile(new URL('go_home_mobile/assets/data/original_route_audio.json',root),JSON.stringify(config));
console.log(`Exported ${song.layers.length} layers, ${notes.size} voices, ${Object.keys(calls).length} calls`);
