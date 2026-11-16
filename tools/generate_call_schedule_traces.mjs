// Exercise the shipped Qt.sing/cutSing/stopPending implementation, not a
// reimplementation of its queueing rules. The native audio DSP is separate.
import fs from 'node:fs';
import {createCanvas} from '@napi-rs/canvas';
globalThis.document={baseURI:'http://localhost/',createElement:()=>createCanvas(1,1)};
globalThis.location={search:'?route=main',pathname:'/'};
const {Qt}=(await import('./.reference_runtime/2-dEIWs8.js')).__port;
const data=JSON.parse(fs.readFileSync('go_home_mobile/assets/data/original_route_audio.json'));
class Param {
  value=1;
  setValueAtTime(x){this.value=x;}
  linearRampToValueAtTime(x){this.value=x;}
  exponentialRampToValueAtTime(x){this.value=x;}
  setTargetAtTime(x){this.value=x;}
  cancelScheduledValues(){}
}
function node(){return {gain:new Param(),frequency:new Param(),Q:new Param(),pan:new Param(),threshold:new Param(),knee:new Param(),ratio:new Param(),attack:new Param(),release:new Param(),connect(n){return n;},disconnect(){},start(){},stop(){},addEventListener(){}};}
class Context {currentTime=0;baseLatency=0;outputLatency=0;destination=node();createGain=node;createBiquadFilter=node;createStereoPanner=node;createDynamicsCompressor=node;createWaveShaper=node;}
// A returned fake context is deliberately not instanceof this constructor, so
// Qt does not attach a real-time analyser to our parameter-only reference bus.
const ctx=new Context();
globalThis.AudioContext=class {constructor(){return ctx;}};
Qt.prototype.load=async function(){};
const m=new Qt({song:'route-main',seg:'dusk-firefly',breath:'shaker',reward:'violins'},{song:structuredClone(data.song),calls:structuredClone(data.calls),amb:{times:{}}},true);
const e=m.engine;
e.opts.manual=true;e.t0=0;e.running=true;e.resetSong(m.data.song,0);m.ready=true;
e.singCall=()=>null;
const ids=Object.keys(data.calls), frames=[];
let time=0, active=[];
e.activeLayers=bar=>active.filter(s=>bar>=s.from&&bar<s.until).map(s=>s.id);
const normalize=r=>({animal:r.animal,hum:r.hum,start:r.first,end:r.end,cutAt:r.cutAt??null});
for(let i=0;i<560;i++){
  // Bursts fill the 60-entry log; long gaps expire runs and unblock humming.
  time+=i%80===79?180:i%9===0?2.37:.11;
  e.ctx.currentTime=time;
  active=i%13===0?[]:data.song.layers.filter((_,j)=>(i+j)%4===0).map((l,j)=>({id:l.id,from:Math.max(0,Math.floor(time/2)-j%2),until:Math.floor(time/2)+1+j%3}));
  const id=ids[(i*7+Math.floor(i/ids.length))%ids.length];
  const animal=data.calls[id].animal;
  let op;
  if(i%17===7){
    op={type:'stop',animal};m.stopPending(animal);
  }else if(i%19===6&&m.singing.length){
    const index=Math.floor(m.singing.length/2);
    op={type:'cut',index};m.cutSing(m.singing[index]);
  }else{
    op={type:'sing',id,x:(i%81)*3.7,hum:i%4===0,fit:i%5!==0,notBefore:i%6===0?time+5.3:0,fitWithin:i%3===0?1:i%3===1?4:null};
    await m.sing(animal,op.x,{call:data.calls[id],hum:op.hum,fit:op.fit,notBefore:op.notBefore,...op.fitWithin===null?{}:{fitWithin:op.fitWithin}});
  }
  frames.push({time,active,op,runs:m.singing.map(normalize),log:m.singLog.map(normalize),last:[...m.lastSing].map(([animal,p])=>({animal,time:p.t,x:p.x})),blocked:m.humBlocked()});
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_call_schedule.json',JSON.stringify(frames));
console.log(`Exported ${frames.length} source call arbitration frames`);
