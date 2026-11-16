/** Build-time WebAudio rendering of the supplied score. No browser/JS runtime
 * is bundled in Flutter. Requires local Chrome and ffmpeg, no npm dependency. */
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const source=path.join(root,'source/extracted/game');
const packs=JSON.parse(await fs.readFile(path.join(source,'packs.json'),'utf8'));
const output=path.join(root,'go_home_mobile/assets/audio');
const pcmDir=await fs.mkdtemp(path.join(os.tmpdir(),'gohome-audio-'));
const profile=await fs.mkdtemp(path.join(os.tmpdir(),'gohome-chrome-'));
const pending=new Map();
const server=http.createServer(async(req,res)=>{
  try{
    const url=new URL(req.url,'http://localhost');
    if(req.method==='POST'&&url.pathname==='/render'){
      const chunks=[];for await(const chunk of req)chunks.push(chunk);
      const name=url.searchParams.get('name');
      if(!/^[\w/-]+$/.test(name))throw Error('Invalid render name');
      const pcm=path.join(pcmDir,name.replaceAll('/','_')+'.f32');
      await fs.writeFile(pcm,Buffer.concat(chunks));
      const target=path.join(output,name+'.m4a');await fs.mkdir(path.dirname(target),{recursive:true});
      const args=['-v','error','-y','-f','f32le','-ar','48000','-ac','2','-i',pcm,'-c:a','aac','-b:a','160k',target];
      await new Promise((ok,fail)=>{const p=spawn('ffmpeg',args,{stdio:'inherit'});p.on('exit',n=>n===0?ok():fail(Error('ffmpeg '+n)));p.on('error',fail);});
      await fs.unlink(pcm);res.end('ok');return;
    }
    if(url.pathname==='/'){res.setHeader('Content-Type','text/html');res.end('<!doctype html><title>GoHome offline audio build</title>');return;}
    const relative=decodeURIComponent(url.pathname).slice(1);
    const file=path.resolve(root,relative);
    if(!file.startsWith(root+path.sep))throw Error('Invalid path');
    let data;
    try{data=await fs.readFile(file);}catch(e){
      const rel=path.relative(source,file).replaceAll(path.sep,'/');
      const match=rel.match(/^(.*\/)([^/]+)\.(ogg|m4a)$/);
      const item=match&&packs[match[1]]?.[match[3]]?.[match[2]+'.'+match[3]];
      if(!item)throw e;
      const pack=await fs.readFile(path.join(source,match[1],match[3]+'.pack'));
      data=pack.subarray(item[0],item[0]+item[1]);
    }
    res.setHeader('Content-Type',file.endsWith('.js')?'text/javascript':file.endsWith('.json')?'application/json':'application/octet-stream');res.end(data);
  }catch(e){res.statusCode=404;res.end(String(e));}
});
await new Promise(ok=>server.listen(0,'127.0.0.1',ok));
const origin=`http://127.0.0.1:${server.address().port}`;
const chrome=spawn(process.env.GOHOME_CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',[
  '--headless=new','--no-first-run','--no-default-browser-check','--remote-debugging-port=0',`--user-data-dir=${profile}`,origin,
],{stdio:'ignore'});
let ws;
try{
  let port;
  for(let i=0;i<100;i++){
    try{port=(await fs.readFile(path.join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0];break;}catch{}
    await new Promise(ok=>setTimeout(ok,100));
  }
  if(!port)throw Error('Chrome did not start');
  const pages=await(await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  ws=new WebSocket(pages.find(p=>p.type==='page').webSocketDebuggerUrl);
  await new Promise(ok=>ws.addEventListener('open',ok,{once:true}));
  let id=0;
  ws.addEventListener('message',e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(Error(JSON.stringify(m.error))):p.resolve(m.result);}});
  const call=(method,params)=>new Promise((resolve,reject)=>{const n=++id;pending.set(n,{resolve,reject});ws.send(JSON.stringify({id:n,method,params}));});
  const build=async()=>{
    const c=(await import('/tools/.reference_runtime/BiOZAGIX.js')).__port;
    const calls=await(await fetch('/go_home_mobile/assets/data/calls.json')).json();
    const rate=48000,pre=.25;
    const cache=new Map();
    async function bank(ctx,base){
      let b=cache.get(base);
      if(!b){b=new c.ra(ctx,base);cache.set(base,b);}
      return b;
    }
    function bus(ctx){
      const g=ctx.createGain();g.gain.value=.8;
      const limiter=ctx.createDynamicsCompressor();
      Object.assign(limiter.threshold,{value:-6});limiter.knee.value=6;limiter.ratio.value=8;limiter.attack.value=.003;limiter.release.value=.15;
      g.connect(limiter).connect(ctx.destination);return g;
    }
    async function save(name,ctx,start=pre,length=null){
      const b=await ctx.startRendering(),count=Math.min(b.length-Math.round(start*rate),Math.round((length??b.duration-start)*rate));
      const pcm=new Float32Array(count*2),offset=Math.round(start*rate);
      let peak=0,energy=0;
      for(let ch=0;ch<2;ch++){const d=b.getChannelData(ch);for(let i=0;i<count;i++){const v=d[i+offset];pcm[i*2+ch]=v;peak=Math.max(peak,Math.abs(v));energy+=v*v;}}
      if(!Number.isFinite(peak)||peak<1e-7)throw Error('Silent/invalid audio '+name);
      const response=await fetch('/render?name='+encodeURIComponent(name),{method:'POST',body:pcm.buffer});
      if(!response.ok)throw Error(await response.text());
      return {name,seconds:count/rate,peak,rms:Math.sqrt(energy/(count*2))};
    }
    const report=[];
    // The original instrument loader performs leading/onset detection and ua
    // performs sample selection, velocity-squared gain and exponential release.
    for(const [id,call] of Object.entries(calls)){
      const length=Math.max(...call.notes.map(n=>(n.bar*16+n.step+n.len)*.125))+3;
      const ctx=new OfflineAudioContext(2,Math.ceil((pre+length)*rate),rate);
      const b=await bank(ctx,'/source/extracted/game/score/'),inst=await b.load(call.instrument),dest=bus(ctx);
      for(const n of call.notes)c.ua(ctx,inst,dest,n.midi,pre+(n.bar*16+n.step)*.125,n.len*.125,n.vel??.8,c.Qi(n.shape));
      report.push(await save('calls/'+id,ctx));
    }
    for(let degree=1;degree<=7;degree++){
      const ctx=new OfflineAudioContext(2,Math.ceil((pre+8)*rate),rate),b=await bank(ctx,'/source/extracted/game/score/');
      c.ua(ctx,await b.load('musicbox'),bus(ctx),c.fa(degree),pre,.5,.8);
      report.push(await save('notes/'+degree,ctx));
    }
    const endingCalls=Object.fromEntries(c.pE.map(a=>[a.id,calls[a.callFile]]));
    const plan=c.GE(c.uD(endingCalls),{woods:'A'});
    const ctx=new OfflineAudioContext(2,Math.ceil((pre+plan.waitBar*2+4)*rate),rate),dest=bus(ctx);
    const game=await bank(ctx,'/source/extracted/game/score/'),bed=await bank(ctx,'/source/extracted/game/ending-bed/');
    const engine={ctx,musicBus:dest,playerBus:dest,bank:game,bankFor:()=>bed,hooks:[],heardTime:()=>ctx.currentTime};
    const score=new c.fD(engine,endingCalls,{woods:'A'});
    await Promise.all(score.rows.map(r=>score.bankOf(r).load(r.inst)));
    score.start(pre);
    for(let bar=score.nextBar;bar<plan.waitBar;bar++)score.scheduleBar(bar);
    if(score.missed)throw Error('Missing ending voices '+score.missed);
    report.push({...await save('music/original-ending',ctx),events:score.sched.length,bars:plan.waitBar});
    const tail=new OfflineAudioContext(2,Math.ceil((pre+13)*rate),rate);
    c.oD(tail,await game.load('musicbox'),bus(tail),pre);
    report.push(await save('music/original-ending-tail',tail));
    return {renderer:'original ra/ua/fD/oD in OfflineAudioContext',sampleRate:rate,channels:2,preRoll:pre,reports:report};
  };
  const result=await call('Runtime.evaluate',{expression:`(${build.toString()})()`,awaitPromise:true,returnByValue:true});
  if(result.exceptionDetails)throw Error(JSON.stringify(result.exceptionDetails));
  const report=result.result.value;
  await fs.writeFile(path.join(root,'artifacts/audio-render-report.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify(report,null,2));
}finally{
  ws?.close();chrome.kill();server.close();
  await fs.rm(pcmDir,{recursive:true,force:true});
  // Chrome may still hold its profile briefly; this folder contains no user data.
}
