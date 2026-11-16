import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};
const l=(await import('./.reference_runtime/Da-Ct4tY.js')).__port;
const encode=p=>Object.fromEntries(Object.entries(p).filter(([k])=>!['wind','t'].includes(k)).map(([k,v])=>[k,v?.isColor?[v.r,v.g,v.b]:Array.isArray(v)?v.map(c=>[c.r,c.g,c.b]):v]));
const target=l.rc(.97,new l.ec());
const frames=Array.from({length:601},(_,i)=>{
 const bar=i/20,fade=l.iC(bar),p=l.cc(new l.ec(),l.tC,target,fade);
 p.cloud=.199*(1-fade);return {bar,fade,look:encode(p)};
});
fs.writeFileSync('go_home_mobile/test/fixtures/original_ending_look.json',JSON.stringify({target:encode(target),frames}));
