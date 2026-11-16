// Offline original EN/gN artwork and deterministic noise. No JS is shipped.
import fs from 'node:fs';
import {createCanvas,loadImage} from '@napi-rs/canvas';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const dir='go_home_mobile/assets/startup';fs.mkdirSync(dir,{recursive:true});
const svg=s=>s.replace(/<svg /,'<svg xmlns="http://www.w3.org/2000/svg" ').replace(/currentColor/g,'#fbf8f2');
fs.writeFileSync(`${dir}/headphones.svg`,svg(c.Hl()));
const phones=c.Hl();
const groups=[...phones.matchAll(/<g class="ui-(cup|wave)"[^>]*>[\s\S]*?<\/g>/g)];
const frame=body=>svg('<svg viewBox="-14 0 148 100">'+body+'</svg>');
const body=phones.slice(phones.indexOf('>')+1,phones.lastIndexOf('</svg>'));
fs.writeFileSync(`${dir}/headphones-base.svg`,frame(body.replace(/<g class="ui-(cup|wave)"[^>]*>[\s\S]*?<\/g>/g,'')));
let cup=0,wave=0;
for(const g of groups)fs.writeFileSync(`${dir}/headphones-${g[1]}-${g[1]==='cup'?cup++:wave++}.svg`,frame(g[0]));
for(const name of ['tap','spkLo','spkHi']) fs.writeFileSync(`${dir}/${name}.svg`,svg(c.fl(name,name,{size:'24px'})));
const field=c.gN.makeField(368,228),canvas=createCanvas(736,228),ctx=canvas.getContext('2d'),im=ctx.createImageData(736,228);
const bytes=new Uint8Array(field.buffer);
for(let i=0;i<field.length;i++){
 const j=i*8;im.data.set([bytes[i*4],bytes[i*4+1],bytes[i*4+2],255,bytes[i*4+3],0,0,255],j);
}
ctx.putImageData(im,0,0);fs.writeFileSync(`${dir}/fog-field.png`,canvas.toBuffer('image/png'));
fs.writeFileSync(`${dir}/fog-field.f32`,Buffer.from(field.buffer));
const noise=decodeURIComponent(c.Hc.slice(c.Hc.indexOf(',')+1,-2));
const grain=await loadImage(Buffer.from(noise));const nc=createCanvas(160,160);nc.getContext('2d').drawImage(grain,0,0);fs.writeFileSync(`${dir}/grain.png`,nc.toBuffer('image/png'));
const launch=createCanvas(320,180),lc=launch.getContext('2d');const gradient=lc.createLinearGradient(0,0,0,180);gradient.addColorStop(0,'#6e7380');gradient.addColorStop(.48,'#595d6b');gradient.addColorStop(1,'#4e525f');lc.fillStyle=gradient;lc.fillRect(0,0,320,180);fs.writeFileSync(`${dir}/launch-fog.png`,launch.toBuffer('image/png'));
fs.copyFileSync('source/extracted/game/ui/tuning-c1.m4a','go_home_mobile/assets/audio/music/original-tuning-c1.m4a');
fs.writeFileSync(`${dir}/original_startup.json`,JSON.stringify({timing:c.vN,logo:c.Dj.b,rows:c.Oj,source:'EN, gN, Ul, Pj/Bj default route=main'}));
console.log('Exported original startup SVGs, grain, packed Float32 fog field and tuning audio');

globalThis.document={createElementNS:()=>({style:{},append(){},setAttribute(){},innerHTML:''})};
const slider=new c.aN({clientWidth:384,clientHeight:28,append(){}},3);slider.focus(true);
fs.writeFileSync(`${dir}/slider-knob.svg`,svg('<svg viewBox="-12 -24 38 38" style="color:#ffd9a0">'+slider.knobBody.innerHTML+'</svg>').replaceAll('#fbf8f2','#ffd9a0'));

fs.writeFileSync(`${dir}/dot.svg`,decodeURIComponent(c.zl('#fbf8f2','#ffffff').split(',')[1].slice(0,-2)));

// Exercise the original EN prototype, without a browser or a rewritten clock.
const trace=[];
const en=Object.create(c.EN.prototype);
Object.assign(en,{phase:'loading',back:false,willCal:false,root:{isConnected:true,style:{},insertBefore(){}},phones:{style:{}},line:{style:{}},tap:{style:{}},loadDot:{style:{}},grain:{style:{}},fogCv:{draw(){}},fogA:1,noiseClear:true,clicked:false,clickT:null,T:null,A:null,host:{release(){}},unhush(){},finish(phase){this.phase=phase;this.fogA=0;}});
en.phase='phones';en.clicked=true;
for(let frame=0;frame<=180;frame++){
 const time=frame/60;en.tick(time);
 trace.push({time,phase:en.phase,clickAt:en.clickT,outAt:en.T,arriveAt:en.A,fog:en.fogA});
}
const pixels=[];
for(const progress of [0,.125,.25,.375,.5,.625,.75,.875,1]){
 const fog=Object.create(c.gN.prototype),cv=createCanvas(320,180),g=cv.getContext('2d');
 Object.assign(fog,{g,img:g.createImageData(320,180),field,FW:368});fog.draw(progress);
 const data=fog.img.data, samples=[];
 for(let y=0;y<180;y+=7)for(let x=0;x<320;x+=7){const p=(y*320+x)*4;samples.push([x,y,...data.subarray(p,p+4)]);}
 pixels.push({progress,samples});
}
const tracks=[];
for(const width of [220,384,420])for(const bend of [0,1.6,-2.1])for(const boil of [0,1,3]){
 slider.w=width;slider.v=.65;slider.bend=bend;slider.boil=boil;slider.drawTrack();
 tracks.push({width,bend,boil,body:slider.track.innerHTML});
}
fs.writeFileSync('go_home_mobile/test/fixtures/original_startup.json',JSON.stringify({trace,tracks}));
const metadata=JSON.parse(fs.readFileSync(`${dir}/original_startup.json`));metadata.fogPixels=pixels;
fs.writeFileSync(`${dir}/original_startup.json`,JSON.stringify(metadata));
