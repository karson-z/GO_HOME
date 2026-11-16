import fs from 'node:fs';globalThis.location={search:'?route=main',pathname:'/'};const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
fs.mkdirSync('artifacts/generated_calls',{recursive:true});
const data=JSON.parse(fs.readFileSync('go_home_mobile/assets/data/calls.json'));
for(let stage=0;stage<c.Zf.length;stage++){
 const call=c.Zf[stage];data[call.id]=call;
 fs.writeFileSync(`artifacts/generated_calls/${call.id}.json`,JSON.stringify(call));
 for(let i=0;i<call.notes.length-1;i++){
  const id=`firefly-drill-${stage}-${i}`,v={...call,id,notes:call.notes.slice(i,i+2),keys:call.keys.slice(i,i+2)};
  data[id]=v;fs.writeFileSync(`artifacts/generated_calls/${id}.json`,JSON.stringify(v));
 }
}
const full=c.Zf.at(-1),id='firefly-relay';const relay={...full,id,notes:full.notes.slice(1),keys:full.keys.slice(1)};
data[id]=relay;fs.writeFileSync(`artifacts/generated_calls/${id}.json`,JSON.stringify(relay));
fs.writeFileSync('go_home_mobile/assets/data/calls.json',JSON.stringify(data,null,2));
