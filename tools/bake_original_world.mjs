import fs from 'node:fs';
import path from 'node:path';
import {createCanvas,DOMMatrix,Path2D} from '@napi-rs/canvas';
import {NativeSceneWriter} from './native_scene_writer.mjs';
const root=path.resolve(import.meta.dirname,'..');
globalThis.location={search:'?route=main',pathname:'/'};

globalThis.ProgressEvent=class{constructor(type,values){this.type=type;Object.assign(this,values)}};
const nativeFetch=globalThis.fetch;
globalThis.fetch=async (input,options)=>{const url=new URL(typeof input==='string'?input:input.url,'http://localhost:8791/');if(url.hostname!=='localhost')return nativeFetch(input,options);const file=path.join(root,'source/extracted/game',decodeURIComponent(url.pathname));try{return new Response(await fs.promises.readFile(file),{status:200});}catch{return new Response('Not found '+file,{status:404});}};
const NativeRequest=globalThis.Request;
globalThis.Request=class extends NativeRequest {constructor(url,options){super(typeof url==='string'?new URL(url,'http://localhost:8791/'):url,options)}};
const look=(await import('./.reference_runtime/Da-Ct4tY.js')).__port;
const route=await import('./.reference_runtime/uwcej6eE.js');
globalThis.window={addEventListener(){},removeEventListener(){},innerWidth:1280,innerHeight:720};
globalThis.DOMMatrix=DOMMatrix;globalThis.Path2D=Path2D;
globalThis.document={createElement(tag){if(tag==='canvas'){const c=createCanvas(1,1);c.style={};c.remove=()=>{};return c;}throw Error('Unsupported element '+tag)},body:{appendChild(){}}};
const {layout:L}=route.buildRouteLevel({},null);
// No GPU or image decoding is required for geometry generation. Keep texture
// names/dimensions so the native loader can load the original bitmap later.
look.z.prototype.load=function(url,onLoad){
 const tex=new look.se();tex.name=url;tex.userData={sourceFile:url};
 tex.image={width:2048,height:2048};
 queueMicrotask(()=>onLoad?.(tex));return tex;
};
look.mo.prototype.loadTextureImage=async function(index,source){return new look.se();};
const shared=look.Hr(look.$r());
const leafTex=new look.se();leafTex.name='./look/fog/leaves.png';leafTex.userData={sourceFile:leafTex.name};
const glowTex=look.ui();
const cells=JSON.parse(fs.readFileSync(path.join(root,'source/extracted/game/look/fog/leaves.json')));
const surface=look.MV(L);
const scene=new look.C();
const game={player:{x:1,y:10,vx:0,vy:0,grounded:true,facing:1},t:0,dt:1/60,
 world:{scene,camera:{aspect:16/9,position:new look.H(1,13,16.4)},renderer:{}},
 runtime:{mgr:{runs:[]}},rig:{hold:null},o:{variants:{}},music:{ready:false}};
const writer=new NativeSceneWriter(root,shared);
const manifests=[];
const persistentRoots=[];
const defs=look.bV;
for(const def of defs){
 if(process.argv[2]&&def.segId!==process.argv[2])continue;
 const ids=[def.segId,...(def.covers??[])],items=L.items.filter(item=>ids.includes(item.kind==='seg'?item.def.id:item.def.walk));
 const seg=items.find(item=>(item.def.id??item.def.walk)===def.segId);
 if(!seg){console.log('MISSING',def.segId);continue;}
 const ox=seg.kind==='seg'?seg.ox:seg.x0,oy=seg.kind==='seg'?seg.oy:seg.y0;
 const x0=Math.min(...items.map(i=>i.x0)),x1=Math.max(...items.map(i=>i.x1));
 const previousRoots=new Set(scene.children);
 const group=new look.m();group.name=`SCENE:${def.segId}`;group.position.set(ox,oy,0);scene.add(group);
 const gy=x=>{const t=surface.raw(x+ox);return Number.isFinite(t)?t-oy:oy;};
 const range=[x0-ox,x1-ox];
 const nextFrame=async()=>{};
 const groundHeight=x=>surface.smooth(Math.max(surface.x0,Math.min(surface.x1,x)));
 const actors=new Map();
 const ctx={game,L,seg,ox,oy,root:group,shared,gy,range,scene,surface,
 sunWorld:new look.H(.3,-.05,-1).normalize(),
 ground:{dirt:(o={})=>look.Vs(shared,o.h??groundHeight,{x0:o.x0??range[0],x1:o.x1??range[1],ox,oy,step:o.step,sink:o.sink}),
 grass:(o={})=>{const h=o.h??groundHeight;const meshes=look.zs(shared,x=>h(x+ox)-oy,o.x0??range[0],o.x1??range[1],o.clear??(()=>false),{noiseX:ox});group.add(...meshes);return meshes;}},
 layers:look.Jo(shared,group,gy),windOf:(x,t)=>look.Qo(x,t??0,1),
 quality:{level:3,track(){},scan(){},onChange(){return()=>{}}},
 far:{origin:id=>{const s=L.segs.find(s=>s.def.id===id);return s?{ox:s.ox,oy:s.oy}:null},dev:false},
 actors:{capsule:(id,o)=>{const handle=look.hi(o);actors.set(id,handle);scene.add(handle.group);return handle;},get:id=>actors.get(id)??null},
 parts:()=>[],nextFrame,onDispose(){},worldRoot(){},inView:()=>true,
 assets:{leafTex,cells,glow:glowTex,model:look.Co,texture:async file=>{const tex=new look.se();tex.name=`./look/fog/${file}`;tex.userData={sourceFile:tex.name};tex.image={width:1024,height:1024};return tex;},scene:(name,options)=>look.ls(name,shared,options)}};
 try{
  const built=await def.build(ctx);
  if(!def.keepAll){look.Po(group,x0,x1);look.Io(group);}
  look.Ro(group,x0,x1);
  const atmosphere=new look.li(shared,x=>surface.smooth(x),built.mist??[],built.beams??[]);
  const index=defs.indexOf(def);
  const blend=(a,b)=>Math.min(a?.blend??12,b?.blendIn??b?.blend??12);
  const left=blend(defs[index-1],def),right=blend(def,defs[index+1]);
  atmosphere.setZone(index>0?x0-left:-1e6,index>0?x0+left:-1e6+1,index<defs.length-1?x1-right:1e6,index<defs.length-1?x1+right:1e6+1);
  const air=new look.m();air.name='ATMOSPHERE';air.add(...atmosphere.objects);scene.add(air);
  const roots=scene.children.filter(o=>!previousRoots.has(o));
  // Original Uv/_l registers shared dusk backdrops with the global far scene.
  // They span several chapters and must survive unloading the opening chunk.
  for(const entry of look.gl)entry.o.userData.farVisibility={from:entry.from,until:entry.until};
  const persistent=roots.filter(o=>look.gl.some(entry=>entry.o===o));
  persistentRoots.push(...persistent);
  const localRoots=roots.filter(o=>!persistent.includes(o));
  for(const entry of look.Mo(localRoots.filter(o=>o!==air)))entry.o.userData.portVisibilityBox={min:entry.box.min.toArray(),max:entry.box.max.toArray()};
  const palette=[];const mapping=new look.YS(L,undefined,defs.flatMap(d=>d.timeKeys?[{at:d.segId,keys:d.timeKeys}]:[]));
  for(let x=x0-16;x<=x1+16;x+=.5){
   const state=look.rc(mapping.at(x),new look.ec());
   const night=look.Jr(518.85,538.85,x)*(1-look.Jr(700.85,725,x));
   state.layers[1].multiplyScalar(1-.4*night);state.layers[3].multiplyScalar(1-.3*night);state.layers[4].multiplyScalar(1-.45*night);
   built.tweak?.(state);if(built.bodyOffset){state.sunX+=built.bodyOffset.dx;state.sunY+=built.bodyOffset.dy;state.moonX+=built.bodyOffset.dx;state.moonY+=built.bodyOffset.dy;}
   look.cH(state,x);look.hc(state,x,look.mc(''));look.yc(state,x);look.Cc(state,x);
   palette.push({paletteTime:mapping.at(x),...Object.fromEntries(Object.entries(state).filter(([k,v])=>k!=='wind'&&k!=='t').map(([k,v])=>[k,v?.isColor?[v.r,v.g,v.b]:Array.isArray(v)?v.map(c=>c?.isColor?[c.r,c.g,c.b]:c):v]))});
  }
  const entry=writer.write(def.segId,localRoots,{x0,x1,ox,oy,paletteX0:x0-16,paletteStep:.5,palette,boyGlow:built.boyGlow??null,darkZone:built.darkZone??null,mist:built.mist??[],beams:built.beams??[],view:built.view?.v??null});
  manifests.push({...entry,x0,x1,ox,oy,shownCam:def.shownCam??null});console.log('BUILT',entry.id,entry.bytes,'bytes',entry.nodes,'geometries',entry.materials,'materials','persistent',persistent.map(o=>o.name));
  if(def.segId==='W6'){
   // Execute the original closure, excluding only its GPU reflection pass.
   const samples=[];group.visible=false;
   for(const x of [390,405,411.5,418,ox+24.15,ox+32,ox+44,ox+56,ox+64,ox+72,ox+84,ox+96,ox+108,640,685]){
    built.update({dt:0,player:{...game.player,x}});
    const values={};group.traverse(o=>{
     if(['W6_WATER','W6_WATER_DEPTH','W6_GATE_FOG','W6_FAR_VEIL','W6_HORIZON'].includes(o.name))values[o.name]={y:o.position.y,visible:o.visible,...Object.fromEntries(Object.entries(o.material.uniforms??{}).filter(([k])=>['uFarCut','uAmt'].includes(k)).map(([k,u])=>[k,u.value]))};
    });samples.push({x,values});
   }
   fs.writeFileSync(path.join(root,'go_home_mobile/test/fixtures/original_lake_scenery.json'),JSON.stringify(samples));
  }
  for(const r of roots)scene.remove(r);
 }catch(error){console.error('BUILD FAILED',def.segId,error.stack,error.cause);}
}

const sky=look.EV(shared);sky.mesh.name='SKY';sky.mat.uniforms.uCloudAmt.value=.7;
const particles=new look.li(shared,()=>0,[],[]).points;
const far=look.Al({...shared,uFarK:{value:1}},{x0:0,x1:L.length,origin:id=>{const s=L.segs.find(s=>s.def.id===id);return s?{ox:s.ox,oy:s.oy}:null;}});
await Promise.all(['owl_FarMount','owl_FarRidge','ending_peak_tall'].map(name=>look.Co(name))).then(([farMount,farRidge,peak])=>far.setModels({farMount,farRidge,peak}));
far.update(1,13);
for(const entry of look.gl)entry.o.userData.farVisibility={from:entry.from,until:entry.until};
const common=writer.write('_global',[sky.mesh,far.group,...persistentRoots,particles],{farConfig:{nightFrom:look.vl,seaFrom:look.yl,dawn:look.El,peak:look.kl,sea:look.ol,endingOx:L.segs.find(s=>s.def.id==='route-ending').ox},shared:Object.fromEntries(Object.entries(shared).map(([k,v])=>[k,writer.uniform(v.value)])),heightX0:surface.x0,heightStep:.1,heights:Array.from({length:Math.ceil((surface.x1-surface.x0)/.1)+1},(_,i)=>surface.smooth(surface.x0+i*.1))});
console.log('BUILT common',common);
writer.finish();fs.writeFileSync(path.join(writer.output,'manifest.json'),JSON.stringify(manifests));
