"""Reproducibly convert the supplied Electron distribution to native Flutter assets.
Run tools/.venv/bin/python tools/prepare_assets.py from the workspace root.
No original JavaScript is executed or shipped in the Flutter application.
"""
from pathlib import Path
import json, shutil, subprocess, io, wave, hashlib, sys
import numpy as np
from PIL import Image, ImageDraw
from fontTools.ttLib import TTFont
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'source/extracted/game'
OUT=ROOT/'go_home_mobile/assets'
RATE=24000
packs=json.loads((SRC/'packs.json').read_text())
cache={}

def sample(inst,midi,vel=.75):
    key=(inst,midi,round(vel,1))
    if key in cache:return cache[key]
    spec=json.loads((SRC/f'score/instruments/{inst}/instrument.json').read_text())
    candidates=[s for s in spec['samples'] if s.get('loMidi',0)<=midi<=s.get('hiMidi',127)] or spec['samples']
    s=min(candidates,key=lambda s:abs(s['rootMidi']-midi)+(0 if s.get('vel',[0,1])[0]<=vel<=s.get('vel',[0,1])[1] else 20))
    p=f'score/instruments/{inst}/'
    offset,length=packs[p]['m4a'][s['file']+'.m4a']
    data=(SRC/p/'m4a.pack').read_bytes()[offset:offset+length]
    result=subprocess.run(['ffmpeg','-v','error','-i','pipe:0','-f','f32le','-ac','1','-ar',str(RATE),'pipe:1'],input=data,capture_output=True,check=True)
    pcm=np.frombuffer(result.stdout,dtype='<f4').copy()
    ratio=2**((midi-s['rootMidi'])/12)
    if ratio!=1:pcm=np.interp(np.arange(0,len(pcm),ratio),np.arange(len(pcm)),pcm).astype('float32')
    cache[key]=pcm
    return pcm

def save_audio(name,pcm):
    target=OUT/'audio'/f'{name}.m4a'
    target.parent.mkdir(parents=True,exist_ok=True)
    pcm=np.clip(pcm,-.98,.98).astype('<f4')
    subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(RATE),'-ac','1','-i','pipe:0','-c:a','aac','-b:a','80k',str(target)],input=pcm.tobytes(),check=True)

def render(notes,inst,step=.125,length=None,loop=False):
    length=length or max((n['bar']*16+n['step']+n['len'])*step+1.1 for n in notes)
    out=np.zeros(int(length*RATE),dtype='float32')
    for n in notes:
        pcm=sample(inst,n['midi'],n.get('vel',.7)).copy()
        duration=n['len']*step
        # Keep percussive tails; sustained samples receive an offline release envelope.
        if inst not in ['musicbox','harp','cello-pizz','balafon','marimba','shaker','bells','celesta','glock','bongos']:
            sustain=int(duration*RATE);release=int(.24*RATE)
            pcm=pcm[:sustain+release]
            if len(pcm)>sustain:pcm[sustain:]*=np.linspace(1,0,len(pcm)-sustain)
        pcm*=n.get('vel',.7)
        start=int((n['bar']*16+n['step'])*step*RATE)
        if loop:
            indexes=(np.arange(len(pcm))+start)%len(out)
            np.add.at(out,indexes,pcm)
        elif start<len(out):out[start:min(start+len(pcm),len(out))]+=pcm[:max(0,min(len(pcm),len(out)-start))]
    return out

if '--calls-only' in sys.argv:
    ids = sys.argv[sys.argv.index('--calls-only') + 1:]
    target = OUT/'data/calls.json'
    data = json.loads(target.read_text())
    for name in ids:
        call = json.loads((SRC/f'score/calls/{name}.json').read_text())
        save_audio('calls/'+name, render(call['notes'], call['instrument']))
        data[name] = call
    target.write_text(json.dumps(data, ensure_ascii=False, indent=2))
    sys.exit(0)

calls={}
for p in (SRC/'score/calls').glob('*.json'):calls[p.stem]=json.loads(p.read_text())
ff=[([1],[0],[73],[8]),([3],[0],[77],[8]),([1,3,5],[0,4,8],[73,77,80],[2,2,4]),([5,3,2,1],[0,4,6,8],[80,77,75,73],[2,1,1,3])]
for i,(keys,steps,midis,lens) in enumerate(ff,1):
    calls[f'firefly-flute-{i}']={'id':f'firefly-flute-{i}','animal':'firefly','instrument':'flute','bars':1,'keys':keys,'notes':[dict(bar=0,step=s,midi=m,len=l,vel=.48) for s,m,l in zip(steps,midis,lens)]}
selected=[*[f'firefly-flute-{i}' for i in range(1,5)],'hedgehog-pizz','squirrel-harp-head','squirrel-harp','squirrel-harp-door','bat-v1','bat-v2','owl-v1','owl-v2','turtle-v1','turtle-v2','turtle-v3','bear-v1','woodpecker-v1','woodpecker-v2']
for k in selected:
    c=calls[k]
    save_audio('calls/'+k,render(c['notes'],c['instrument']))
(OUT/'data/calls.json').write_text(json.dumps({k:calls[k] for k in selected},ensure_ascii=False,indent=2))
for period,midis in {'dusk':[73,75,77,78,80,82,84],'night':[73,75,77,78,80,82,84],'dawn':[73,75,77,78,80,82,84]}.items():
    # Native music box uses the original Db diatonic samples.
    for k,m in enumerate(midis,1):
        if period=='dusk':save_audio(f'notes/{k}',sample('musicbox',m)*.8)

songs=['puzzle-firefly','puzzle-hedgehog','puzzle-squirrel','puzzle-cave-bat','puzzle-night-owl','puzzle-night-turtle','puzzle-dawn-bear','puzzle-dawn-woodpecker','route-ending']
for song_id in songs:
    song=json.loads((SRC/f'score/songs/{song_id}.json').read_text())
    step=60/song['bpm']/4
    bars=8;length=bars*16*step
    mix=np.zeros(int(length*RATE),dtype='float32')
    for layer in song['layers']:
        if layer.get('animal'):continue # Calls remain audible above the backing track.
        variants=layer.get('variants',[])
        if not variants:continue
        order=layer.get('variantOrder',[variants[0]['id']])
        for start_bar in range(0,bars,layer.get('loopBars',4)):
            variant=next((v for v in variants if v['id']==order[(start_bar//layer.get('loopBars',4))%len(order)]),variants[0])
            notes=[dict(n,bar=n['bar']+start_bar) for n in variant.get('notes',[])]
            if notes:
                track=render(notes,layer['instrument'],step,length,True)
                mix+=track*10**(layer.get('gainDb',-12)/20)
    peak=max(.01,float(np.max(np.abs(mix))))
    save_audio('music/'+song_id,mix*min(.7/peak,1.5))
    print('Rendered',song_id,flush=True)
for p in (SRC/'ambience').glob('*/bed.m4a'):
    dest=OUT/'audio/ambience'/f'{p.parent.name}.m4a';dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest)
for name in ['jump_1','land_dirt_1','step_dirt_1','ui_back_1','ui_confirm_1','tree_fall_big_1','stone_door_sink_1','fall_water_1','hedgehog_roll_1','bear_wake_1','launch_1']:
    p=SRC/f'sfx/{name}.m4a'
    if p.exists():
        d=OUT/'audio/sfx'/p.name;d.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,d)
for p in (SRC/'look/fog').rglob('*.glb'):
    # Preserve all source scene transforms. Flatten only the asset path.
    shutil.copy2(p,OUT/'models'/('_'.join(p.relative_to(SRC/'look/fog').parts)))
characters={'boy':'boy-b','firefly':'critters/firefly','hedgehog':'critters/hedgehog','squirrel':'critters/squirrel','bat':'critters/bat','owl':'critters/owl','turtle':'critters/turtle1','turtle2':'critters/turtle2','bear':'critters/bear','woodpecker':'critters/woodpecker','dad':'critters/fam-dad','mom':'critters/fam-mom','sister':'critters/fam-sister','brother':'critters/fam-brother','dog':'critters/fam-dog'}
characters.update({'hedgehog-side':'critters/hedgehog-side', 'bat-side':'critters/bat-side', 'bear-turn':'critters/bear-turn'})
for name,path in characters.items():
    for ext in ['png','json']:shutil.copy2(SRC/f'look/{path}/parts.{ext}',OUT/'characters'/f'{name}.{ext}')
for name in ['wenkai','gaegu','xiaolai']:
    font=TTFont(SRC/f'fonts/{name}-sub.woff2');font.flavor=None;font.save(OUT/'fonts'/f'{name}.ttf')
for p in (SRC/'fonts').glob('OFL*'):shutil.copy2(p,OUT/'fonts'/p.name)
# Small radial sprite for fireflies, music particles and the soft sun.
im=Image.new('RGBA',(128,128));a=np.arange(128)-63.5;x,y=np.meshgrid(a,a);v=np.exp(-(x*x+y*y)/(2*20**2));rgba=np.zeros((128,128,4),dtype='uint8');rgba[:,:,:3]=255;rgba[:,:,3]=(v*255).astype('uint8');Image.fromarray(rgba).save(OUT/'characters/glow.png')
manifest=[]
for p in sorted(OUT.rglob('*')):
    if p.is_file():manifest.append({'path':str(p.relative_to(OUT)),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(OUT/'data/asset_manifest.json').write_text(json.dumps(manifest,indent=2))
print('Prepared',len(manifest),'assets',sum(p['bytes'] for p in manifest)//1024//1024,'MiB')
