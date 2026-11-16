// Uses the actual source tweak expressions and their closure values. No palette
// formula is reimplemented in this reference fixture generator.
import fs from 'node:fs';
import {parse} from 'acorn';
globalThis.location={search:'?route=main',pathname:'/'};
const l=(await import('./.reference_runtime/Da-Ct4tY.js')).__port;
const route=await import('./.reference_runtime/uwcej6eE.js');
const {layout}=route.buildRouteLevel({},null);
const source=fs.readFileSync(new URL('../source/readable/Da-Ct4tY.js',import.meta.url),'utf8');
const ast=parse(source,{ecmaVersion:'latest',sourceType:'module',locations:true});
const nodes=[];
function walk(n){if(!n||typeof n!=='object')return;if(n.type)nodes.push(n);for(const v of Object.values(n)){if(Array.isArray(v))v.forEach(walk);else if(v&&typeof v==='object')walk(v);}}
walk(ast);
function expressionAt(line,kind='Property'){
 const n=nodes.find(n=>n.type===kind&&n.loc.start.line===line&&(kind!=='Property'||n.key?.name==='tweak'));
 if(!n)throw Error('No source expression at '+line);
 const value=kind==='Property'?n.value:n.init;
 return source.slice(value.start,value.end);
}
function evaluate(expression,locals){const scope={...l,...locals};return Function(...Object.keys(scope),'return ('+expression+');')(...Object.values(scope));}
const chunks=l.bV.map(def=>{
 const ids=[def.segId,...(def.covers??[])],items=layout.items.filter(i=>ids.includes(i.kind==='seg'?i.def.id:i.def.walk));
 const seg=items.find(i=>(i.def.id??i.def.walk)===def.segId);
 return {id:def.segId,x0:Math.min(...items.map(i=>i.x0)),x1:Math.max(...items.map(i=>i.x1)),ox:seg.kind==='seg'?seg.ox:seg.x0,blend:def.blend??12,blendIn:def.blendIn??def.blend??12,stateTime:def.stateTime??false};
});
const offsets={W0:{dx:0,dy:.19},'dusk-squirrel':{dx:-.055,dy:-.15},'night-owl':l.mp,'night-turtle':{dx:.345,dy:-.04}};
const config=JSON.parse(fs.readFileSync(new URL('../go_home_mobile/assets/data/original_palette.json',import.meta.url)));
Object.assign(config,{chunks,offsets,windPath:l.$o,owlTime:l.pp,caveEnd:l.Tm,turtleRays:l.Ib,
 dawnHorizon:[l.oS.r,l.oS.g,l.oS.b],dawnLight:[l.sS.r,l.sS.g,l.sS.b],
 dawn:{horizon:[l.Cw.r,l.Cw.g,l.Cw.b],light:[l.ww.r,l.ww.g,l.ww.b]},endingSunPath:l.XR,endingSunX:l.YR.x,endingSunGain:l.JR});
fs.writeFileSync(new URL('../go_home_mobile/assets/data/original_palette.json',import.meta.url),JSON.stringify(config));
const expressions={
 'night-owl':expressionAt(15805),'cave-bat':expressionAt(17458),
 'dusk-hedgehog':expressionAt(26350),'night-turtle':expressionAt(28532),
 W6:expressionAt(30780),W7:expressionAt(68727),'dawn-bear':expressionAt(69639),
 'dawn-woodpecker':expressionAt(70912),'route-ending':expressionAt(67391,'VariableDeclarator')};
function localPalette(chunk,time,x,impact,bar){
 const p=l.rc(time,new l.ec()),q=l.rc(l.pp,new l.ec()),a=x-chunk.ox;
 const night=l.Jr(518.85,538.85,x)*(1-l.Jr(700.85,725,x));
 p.layers[1].multiplyScalar(1-.4*night);p.layers[3].multiplyScalar(1-.3*night);p.layers[4].multiplyScalar(1-.45*night);
 let offset=offsets[chunk.id];
 if(expressions[chunk.id]){
  const locals={De:q,be:q,U:a,Se:l.Tm-chunk.ox,ge:impact,ze:a,He:1.35,Ue:true,l:l.Jr,pe:l.Jr(695,702,x),me:bar,_e:{dx:0,dy:0},he:0};
  evaluate(expressions[chunk.id],locals)(p);
  if(chunk.id==='route-ending')offset=locals._e;
 }
 if(chunk.id==='cave-bat'){
  const f=l.Jr(33.5,37.8,a);
  offset={dx:.97+(q.moonX+l.mp.dx-.97)*f-p.moonX,dy:.2+(q.moonY+l.mp.dy-.2)*f-p.moonY};
 }
 if(offset){p.sunX+=offset.dx;p.sunY+=offset.dy;p.moonX+=offset.dx;p.moonY+=offset.dy;}
 return p;
}
const encode=p=>Object.fromEntries(Object.entries(p).filter(([k])=>k!=='wind').map(([k,v])=>[k,v?.isColor?[v.r,v.g,v.b]:Array.isArray(v)?v.map(c=>[c.r,c.g,c.b]):v]));
const samples=[];
for(const chunk of chunks)for(let i=0;i<=30;i++){
 const x=chunk.x0+(chunk.x1-chunk.x0)*i/30,time=(i%11)/10,impact=i%3===0?-1:(i%8)*.21,bar=-4+i*1.8;
 const p=localPalette(chunk,time,x,impact,bar);
 samples.push({id:chunk.id,x,time,impact,bar,p:encode(p)});
}
const blends=[];
for(let i=1;i<chunks.length;i++)for(let j=0;j<=10;j++){
 const a=chunks[i-1],b=chunks[i],x=b.x0+j-5,time=j/10,k=j/20;
 const p=localPalette(a,time,x,-1,-4),q=localPalette(b,time,x,-1,-4);l.sc(p,q,k);
 l.cH(p,x);l.hc(p,x,l.mc(''));l.yc(p,x);l.Cc(p,x);
 blends.push({a:a.id,b:b.id,x,time,k,p:encode(p)});
}
const clock=new l.XS(),clocks=[];
for(let i=0;i<600;i++){
 const target=(i%200)/200,dt=[1/60,.1,0,1/30][i%4],snap=i%173===0;
 clocks.push({target,dt,snap,t:clock.step(target,dt,snap)});
}
fs.writeFileSync(new URL('../go_home_mobile/test/fixtures/original_scene_palette.json',import.meta.url),JSON.stringify({samples,blends,clocks}));
console.log('Extracted',samples.length,'source chunk palettes,',blends.length,'blends,',clocks.length,'clock frames.');
