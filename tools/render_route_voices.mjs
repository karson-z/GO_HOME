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
      const target=path.join(output,name+'.wav');await fs.mkdir(path.dirname(target),{recursive:true});
      const args=['-v','error','-y','-f','f32le','-ar','48000','-ac','2','-i',pcm,'-c:a','pcm_f32le',target];
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
    const config=await(await fetch('/go_home_mobile/assets/data/original_route_audio.json')).json();
    const rate=48000, bank=new c.ra(new OfflineAudioContext(2,1,rate),'/source/extracted/game/score/');
    const report=[];
    for(const voice of config.voices){
      const inst=await bank.load(voice.inst),samples=new Map();
      const edges=[...new Set([0,1,...inst.def.samples.flatMap(s=>s.vel??[])])].sort((a,b)=>a-b);
      voice.choices=[];
      for(let i=0;i<edges.length-1;i++){
        const velocity=(edges[i]+edges[i+1])/2, sample=c.ca(inst.def,voice.midi,velocity);
        let row=samples.get(sample.file);
        if(!row){
          const pitch=inst.def.pitched===false?1:2**((voice.midi-sample.rootMidi)/12);
          const lead=(inst.onsets.get(sample.file)??sample.onsetSec??0)/pitch;
          const pre=Math.max(1,lead+.1), duration=voice.len*.125;
          const natural=inst.buffers.get(sample.file).duration/pitch;
          const release=Math.max(.03,inst.def.release);
          const tail=inst.sustain?duration+release*1.5:Math.min(natural-lead,Math.max(duration,.25)+release*3.5);
          const ctx=new OfflineAudioContext(2,Math.ceil((pre+tail+.02)*rate),rate);
          const dest=ctx.createGain();dest.gain.value=1/(velocity*velocity);dest.connect(ctx.destination);
          c.ua(ctx,{...inst,def:{...inst.def,samples:[sample]}},dest,voice.midi,pre,duration,velocity,c.Qi(voice.shape));
          const rendered=await ctx.startRendering(), offset=Math.round((pre-lead)*rate),count=rendered.length-offset;
          const pcm=new Float32Array(count*2);
          let peak=0;
          for(let ch=0;ch<2;ch++)for(let j=0;j<count;j++){const v=rendered.getChannelData(ch)[j+offset];pcm[j*2+ch]=v;peak=Math.max(peak,Math.abs(v));}
          const id=voice.id+'-'+samples.size;
          const response=await fetch('/render?name=voices/'+id,{method:'POST',body:pcm.buffer});if(!response.ok)throw Error(await response.text());
          row={file:id,lead,seconds:count/rate};samples.set(sample.file,row);
          report.push({id,peak,seconds:row.seconds,sample:sample.file});
        }
        voice.choices.push({lo:edges[i],hi:edges[i+1],...row});
      }
    }
    return {config,report};
  };
  const result=await call('Runtime.evaluate',{expression:`(${build.toString()})()`,awaitPromise:true,returnByValue:true});
  if(result.exceptionDetails)throw Error(JSON.stringify(result.exceptionDetails));
  const {config,report}=result.result.value;
  await fs.writeFile(path.join(root,'go_home_mobile/assets/data/original_route_audio.json'),JSON.stringify(config));
  await fs.writeFile(path.join(root,'artifacts/route-voice-render-report.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify(report,null,2));
}finally{
  ws?.close();chrome.kill();server.close();
  await fs.rm(pcmDir,{recursive:true,force:true});
  // Chrome may still hold its profile briefly; this folder contains no user data.
}
