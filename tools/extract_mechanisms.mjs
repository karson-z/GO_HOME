// Serialize only source constants and collision profiles for Dart.
import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const turtle={x:c.xx,rocks:c.Sx,far:c.Ex,top:c.Fx,asleep:c.Ix,height:c.Lx,riseSeconds:c.Vx,
  shift:c.xx.map((_,i)=>c.eS(i)),shells:c.xx.map((_,i)=>c.pS(i,0,0)),profiles:c.xx.map((_,i)=>{c.fS(i);return c.lS[i];})};
const squirrel={fruits:c.hv,mid:c.Mv(true),act:c.ov('branch'),speed:c.rv,
  home:c.E_,perch:c.M_,bridgeStart:c.Av,bridgeEnd:c.jv,door:c.N_,homeRadius:c.k_,homeSeconds:c.D_,homeSpeed:c.O_,taskLimit:c.sv};
fs.writeFileSync(new URL('../go_home_mobile/assets/data/original_mechanisms.json',import.meta.url),JSON.stringify({turtle,squirrel,firefly:{stems:c.Rm,center:c.Bm,stations:c.th,home:c.gh,bush:c.ph,glide:c.oh,scoutHeight:[1,2,3,4,5,6,7].map(c.lh)}}));
console.log('Extracted turtle collision profiles and squirrel navigation constants.');
