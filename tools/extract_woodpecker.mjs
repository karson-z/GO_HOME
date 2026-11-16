import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const data=JSON.parse(fs.readFileSync('go_home_mobile/assets/data/calls.json'));
const generated={...c.ZC};
for(const phrase of c.Sw){const call=c.Cw(phrase);generated[call.id]=call;}
for(const [id,call] of Object.entries(generated)){data[id]=call;}
fs.writeFileSync('go_home_mobile/assets/data/calls.json',JSON.stringify(data,null,2));
fs.mkdirSync('artifacts/generated_calls',{recursive:true});
for(const [id,call] of Object.entries(generated))fs.writeFileSync(`artifacts/generated_calls/${id}.json`,JSON.stringify(call));
