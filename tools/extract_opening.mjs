import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const path='go_home_mobile/assets/data/original_mechanisms.json',data=JSON.parse(fs.readFileSync(path));
data.opening={timing:c.sM,tree:c.cE,view:c.iE,arrival:c.uM,riseKeys:c.Wj,firefly:{core:c.TA,halo:c.EA}};
fs.writeFileSync(path,JSON.stringify(data));
const frames=[];
for(let i=0;i<=2000;i++) {
 const u=i/2000;
 frames.push({u,rot:Object.fromEntries(c.Gj.map(k=>[k,c.Kj(u,key=>key.p[k]??0)])),head:c.Kj(u,key=>key.head)});
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_opening.json',JSON.stringify(frames));
