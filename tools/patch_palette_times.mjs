// Upgrade existing native scene bakes without regenerating geometry.
import fs from 'node:fs';
import path from 'node:path';
globalThis.location={search:'?route=main',pathname:'/'};
const look=(await import('./.reference_runtime/Da-Ct4tY.js')).__port;
const route=await import('./.reference_runtime/uwcej6eE.js');
const {layout}=route.buildRouteLevel({},null);
const mapping=new look.YS(layout,undefined,look.bV.flatMap(d=>d.timeKeys?[{at:d.segId,keys:d.timeKeys}]:[]));
const dir=path.resolve(import.meta.dirname,'../go_home_mobile/assets/world');
for(const meta of JSON.parse(fs.readFileSync(path.join(dir,'manifest.json')))){
  const file=path.join(dir,`${meta.id}.json`),data=JSON.parse(fs.readFileSync(file));
  for(let i=0;i<data.palette.length;i++)data.palette[i].paletteTime=mapping.at(data.paletteX0+i*data.paletteStep);
  fs.writeFileSync(file,JSON.stringify(data));
}
console.log('Preserved source palette time in every native chunk.');
