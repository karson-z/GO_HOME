import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const look=(await import('./.reference_runtime/Da-Ct4tY.js')).__port;
const file='go_home_mobile/assets/data/original_mechanisms.json';
const data=JSON.parse(fs.readFileSync(file));
data.ending={layout:c.MD(2.8),paths:c.kk('f'),swaps:c.yD,family:c.GP,beasts:c.qP,stages:c.Zk,after:c.$,places:c.MO('f'),sitDx:c.cE.sitDx};
data.ending.environment={base:look.lc(look.tC),treeBar:look.$S};
data.ending.flight={paths:c.CM,stages:c.zM,arrive:c.uM,
 oldBox:{x:look.qI.x,y:look.qI.y+.185,z:look.cR.z+.12},
 colors:{top:look.vC.top.toArray(),mid:look.vC.mid.toArray(),bot:look.vC.bot.toArray()},
 colorsDown:{top:look.yC.top.toArray(),mid:look.yC.mid.toArray(),bot:look.yC.bot.toArray()},
 height:look.xC,veil:look.bC,grade:look._C,
 trail:(()=>{const random=look.Ji(55);return Array.from({length:14},(_,i)=>({dt:(i+1)*.055+random()*.05,a:.45+random()*.55,s:.6+random()*.6,wob:random()*6.28}));})()};
fs.writeFileSync(file,JSON.stringify(data));
for(const name of [...c.GP,'mom','boy','oldman']){
 const src=`source/extracted/game/look/critters/fam-${name}/parts`;
 for(const ext of ['json','png'])fs.copyFileSync(`${src}.${ext}`,`go_home_mobile/assets/characters/fam-${name}.${ext}`);
}
// These are static authored segments, not a sampled animation or a JS runtime.
const fixtures=[];
for(let i=0;i<=6000;i++){
 const bar=i/100;
 fixtures.push({bar,rider:c.PD(c.MD(2.8),bar),paths:Object.fromEntries(['boy',...c.GP].map(who=>[who,c.jk('f',who,bar)])),formation:Object.fromEntries(c.GP.map(who=>[who,c.UO(who,bar)]))});
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_ending.json',JSON.stringify(fixtures));
console.log('Extracted ending segments, 11 original family atlases and 6001 reference frames');

for(const who of [...c.GP.filter(w=>w!=='dog'),'mom','oldman']){
 const src=`source/extracted/game/look/fam2/${who}/parts`;
 const spec=JSON.parse(fs.readFileSync(`${src}.json`)),k=spec.height/1.1;
 spec.originalHeight=spec.height;spec.height=1.1;
 for(const part of spec.parts){part.size=part.size.map(v=>v/k);part.at=part.at.map(v=>v/k);}
 for(const anchor of Object.values(spec.anchors)){anchor.at=anchor.at.map(v=>v/k);}
 fs.writeFileSync(`go_home_mobile/assets/characters/fam2-${who}.json`,JSON.stringify(spec));
 fs.copyFileSync(`${src}.png`,`go_home_mobile/assets/characters/fam2-${who}.png`);
}
