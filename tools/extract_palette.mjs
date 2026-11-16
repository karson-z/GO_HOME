import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};
const l=(await import('./.reference_runtime/Da-Ct4tY.js')).__port;
const route=await import('./.reference_runtime/uwcej6eE.js');
const {layout}=route.buildRouteLevel({},null);
const mapping=new l.YS(layout,undefined,l.bV.flatMap(d=>d.timeKeys?[{at:d.segId,keys:d.timeKeys}]:[]));
const config={frames:l.Ks,defaults:l.Us,bodies:l.nc,timePoints:mapping.points,sunPath:l.iH,moonPath:l.aH,caveMoon:l.oH};
fs.writeFileSync(new URL('../go_home_mobile/assets/data/original_palette.json',import.meta.url),JSON.stringify(config));
const encode=p=>Object.fromEntries(Object.entries(p).filter(([k])=>!['wind'].includes(k)).map(([k,v])=>[k,v?.isColor?[v.r,v.g,v.b]:Array.isArray(v)?v.map(c=>[c.r,c.g,c.b]):v]));
const samples=[];
for(let i=0;i<=500;i++){
 const t=i/500,base=encode(l.rc(t,new l.ec()));
 const x=i*1.7,p=l.rc(mapping.at(x),new l.ec());
 l.cH(p,x);l.hc(p,x,l.mc(''));l.yc(p,x);l.Cc(p,x);
 samples.push({t,base,x,at:mapping.at(x),routed:encode(p)});
}
fs.writeFileSync(new URL('../go_home_mobile/test/fixtures/original_palette.json',import.meta.url),JSON.stringify(samples));
console.log('Extracted original OKLab palette, route time curve and 501 reference frames.');
