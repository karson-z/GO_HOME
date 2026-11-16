import fs from 'node:fs';import path from 'node:path';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const scenarios=[];
for(const chord of [false,true])for(const chapter of ['dusk','night','dawn'])for(const mode of ['normal','slow','fast','wrong','late','random']){
 const keys=chord?[1,3,5,2,4,6,7]:[1,3,5,2,4,6,7],onsets=chord?[0,0,0,1,1,2,2]:[0,.5,1,1.25,1.75,2.5,3];
 const tol=c.td[chapter],judge=chord?new c.Eb(keys,onsets,tol):new c.ad(keys,onsets,tol);
 const actions=[];let seed=17,t=0;const rnd=()=>((seed=(seed*1664525+1013904223)>>>0)/4294967296);
 for(let trial=0;trial<7;trial++){
   actions.push({kind:'reset'});t+=10;
   for(let i=0;i<keys.length;i++){
    const dt=mode==='random'?rnd()*1.5:(onsets[i]-(onsets[i-1]??0))*(mode==='slow'?1.45:mode==='fast'?.75:1);
    t+=dt;
    actions.push({kind:'check',time:t});
    actions.push({kind:'feed',key:mode==='wrong'&&i===3?7:mode==='random'?1+Math.floor(rnd()*7):keys[i],time:t});
    if(mode==='late'&&i===2){t+=3;actions.push({kind:'check',time:t});}
    if(chord&&i===0){actions.push({kind:'feed',key:keys[i],time:t+.03});}
   }
 }
 const samples=[];
 for(const action of actions){const result=action.kind==='reset'?(judge.reset(),null):action.kind==='check'?judge.check(action.time):judge.feed(action.key,action.time);
 samples.push(structuredClone({action,result,state:{progress:judge.progress,lo:judge.lo,hi:judge.hi,scale:judge.scale,taps:judge.taps,fails:judge.fails,lastDone:judge.lastDone,lastFail:judge.lastFail,...(chord?{starts:judge.starts,open:judge.open,repeats:judge.repeats,spread:judge.spread,lastSpread:judge.lastSpread,lastChord:judge.lastChord}: {})}}));
 }
 scenarios.push({id:`${chord?'chords':'notes'}-${chapter}-${mode}`,chord,keys,onsets,tol,samples});
}
const out=path.resolve(import.meta.dirname,'../go_home_mobile/test/fixtures/original_rhythm.json');fs.writeFileSync(out,JSON.stringify(scenarios));console.log(scenarios.length,'scenarios',scenarios.reduce((n,s)=>n+s.samples.length,0),'actions');
