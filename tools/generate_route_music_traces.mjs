import fs from 'node:fs';
import {createCanvas} from '@napi-rs/canvas';
globalThis.document={baseURI:'http://localhost/',createElement:()=>createCanvas(1,1)};
globalThis.location={search:'?route=main',pathname:'/'};
const a=(await import('./.reference_runtime/2-dEIWs8.js')).__port;
const w=(await import('./.reference_runtime/uwcej6eE.js')).__port;
const data=JSON.parse(fs.readFileSync('go_home_mobile/assets/data/original_route_audio.json'));
const layout=JSON.parse(fs.readFileSync('go_home_mobile/assets/data/original_route.json')).layout;
class Param{value=1;setValueAtTime(x){this.value=x;}linearRampToValueAtTime(x){this.value=x;}exponentialRampToValueAtTime(x){this.value=x;}setTargetAtTime(x){this.value=x;}cancelScheduledValues(){}}
function node(){return {gain:new Param(),frequency:new Param(),Q:new Param(),pan:new Param(),threshold:new Param(),knee:new Param(),ratio:new Param(),attack:new Param(),release:new Param(),connect(n){return n},disconnect(){},start(){},stop(){},addEventListener(){}}}
class Context{currentTime=0;baseLatency=0;outputLatency=0;destination=node();createGain=node;createBiquadFilter=node;createStereoPanner=node;createDynamicsCompressor=node;createWaveShaper=node;}
globalThis.AudioContext=Context;
a.Qt.prototype.load=async function(){};
// Avoid meter construction while retaining all Qt class-field initializers.
const ctx=new Context();globalThis.AudioContext=class{constructor(){return ctx;}};
const m=new a.Qt({song:'route-main',seg:'dusk-firefly',breath:'shaker',reward:'violins'}, {song:structuredClone(data.song),calls:{},amb:{times:{}}},true);
const e=m.engine;e.opts.manual=true;e.t0=0;e.running=true;e.resetSong(m.data.song,0);m.ready=true;
for(const l of data.song.layers)e.bank.loaded.set(l.instrument,{def:{samples:[{file:'silent',rootMidi:60}]},buffers:new Map(),onsets:new Map()});
let f;
const director=new w.kt(m,layout,{playerX:()=>f.x,done:i=>f.done.includes(i),live:i=>i===f.segment,release(){},cue:id=>f.cues[id]});
director.amb.update=()=>{};if(director.drips)director.drips.update=()=>{};director.farHum=()=>{};
m.ambienceTo=(key,bar)=>{};m.preload=async()=>{};
const frames=[];let time=0,done=[];
for(let i=0;i<9*480;i++){
 time+=.05;const segment=Math.min(8,Math.floor(i/480)),local=i%480,seg=layout.segs[segment];
 if(segment<8&&local===220)done.push(segment);
 f={time,dt:.05,segment,x:seg.ox+Math.min(seg.x1-seg.ox,local*.08),inZone:local>=40&&local<220,zoneDist:local<40?20:local<220?0:18,done:[...done],awake:done.map(j=>data.sleepers[layout.segs[j].def.id]?.animal).filter(Boolean),animalX:{},cues:{'dusk-squirrel':local%150<75?'door':null}};
 director.enter(segment);
 for(const id of f.awake)m.wake(id);
 if(done.includes(segment))m.reward();
 m.inZone=f.inZone;m.zoneDist=f.zoneDist;
 ctx.currentTime=time;
 e.tick();m.update(f.dt,f.x);director.update();
 frames.push({...f,nextStep:e.nextStep,active:e.activeLayers(Math.floor(time/2)),adds:m.adds.map(({id,kind,bar,shown})=>({id,kind,bar,shown})),removes:m.removes.map(({id,bar})=>({id,bar})),want:m.wantQ.map(({id,kind,notBefore})=>({id,kind,notBefore})),retired:[...m.retired],bassoon:director.bassoonMode,chains:director.chainLog.map(({seg,anchorBar})=>({seg,anchorBar})),notes:e.events.splice(0).map(({t,layer,midi,dur,vel})=>({time:t,layer,midi,duration:dur,velocity:vel}))});
}
const spaces=[];for(const spec of [{x:13,radius:32},{x:13,radius:32,curve:'db',edge:10.4},{x:13,radius:32,curve:'db',edge:10.4,floorDb:-4}])for(let x=-100;x<100;x+=.37)spaces.push({spec,x,...a.U(spec,x)});
fs.writeFileSync('go_home_mobile/test/fixtures/original_route_music.json',JSON.stringify({frames,spaces}));
console.log(`Exported ${frames.length} source director frames and ${spaces.length} distance curves`);
