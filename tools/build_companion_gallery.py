"""Build Moss's cutout rig, transparent animation frames, and offline viewer.

Requires tools/.venv (Pillow, numpy). Motion is exported by the Dart game code,
not approximated by this renderer. Generated artwork is kept in source/.
"""
from pathlib import Path
import base64
import io
import json
import math
import shutil
import zipfile
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/companion-moss'
PARTS = OUT / 'parts'
FONT = '/System/Library/Fonts/STHeiti Medium.ttc'
ORDER = ['body','hem','head','musicbox','upperArmF','foreArmF','handF','thighF','shinF','footF','upperArmB','foreArmB','handB','thighB','shinB','footB']
LAYERS = {'upperArmB':20,'foreArmB':21,'handB':22,'thighB':10,'shinB':11,'footB':12,'thighF':40,'shinF':41,'footF':42,'body':50,'hem':52,'head':60,'upperArmF':80,'foreArmF':81,'handF':86,'musicbox':85}


def unmatte(im):
    """Remove the generated white matte, including white antialiased fringes."""
    arr = np.array(im.convert('RGB')).astype(float)
    # Use nearby opaque paint to recover edge alpha, instead of retaining the
    # white source matte around dark hair and cloth.
    solid=Image.fromarray(((arr.min(axis=2)<215)*255).astype('uint8')).filter(ImageFilter.MinFilter(3))
    core=np.array(solid)>0
    nearest=arr.copy();distance=np.full(core.shape,99,dtype='uint8');distance[core]=0
    queue=deque(zip(*np.where(core)))
    height,width=core.shape
    while queue:
        y,x=queue.popleft();dist=int(distance[y,x])+1
        if dist>5:continue
        for ny,nx in ((y-1,x),(y+1,x),(y,x-1),(y,x+1)):
            if 0<=ny<height and 0<=nx<width and distance[ny,nx]>dist:
                distance[ny,nx]=dist;nearest[ny,nx]=nearest[y,x];queue.append((ny,nx))
    ink=255-nearest;observed=255-arr
    alpha=np.clip((observed*ink).sum(axis=2)/np.maximum(1,(ink*ink).sum(axis=2)),0,1)
    alpha[core]=1;alpha[(distance>5)|(arr.min(axis=2)>246)]=0
    rgb=arr.copy();rgb[~core]=nearest[~core]
    result = Image.fromarray(np.dstack((rgb,alpha*255)).astype('uint8'))
    bbox = result.getchannel('A').point(lambda v:255 if v>160 else 0).getbbox()
    if not bbox:
        raise ValueError('Empty art slot')
    return result.crop(bbox)


def data_url(im):
    buf=io.BytesIO();im.save(buf,format='PNG')
    return 'data:image/png;base64,'+base64.b64encode(buf.getvalue()).decode()


def build_parts():
    PARTS.mkdir(exist_ok=True,parents=True)
    raw=Image.open(OUT/'source/parts-raw.png').convert('RGB')
    assert raw.width==raw.height,raw.size
    cell=raw.width/4
    spec=json.loads((ROOT/'go_home_mobile/assets/characters/boy.json').read_text())
    parts={p['id']:p.copy() for p in spec['parts']}
    images={}
    atlas=Image.new('RGBA',(2048,2048))
    full_cape=None
    for i,ident in enumerate(ORDER):
        x=(i%4)*cell;y=(i//4)*cell
        pad=cell*.045
        im=unmatte(raw.crop(tuple(round(v) for v in (x+pad,y+pad,x+cell-pad,y+cell-pad))))
        assert im.width>30 and im.height>30,(ident,im.size)
        p=parts[ident]
        p['layer']=LAYERS[ident]
        p['parent']={
            'hem':'body','head':'body','upperArmF':'body','upperArmB':'body',
            'foreArmF':'upperArmF','foreArmB':'upperArmB','handF':'foreArmF','handB':'foreArmB',
            'thighF':'body','thighB':'body','shinF':'thighF','shinB':'thighB','footF':'shinF','footB':'shinB','musicbox':'handF',
        }.get(ident)
        if ident=='upperArmB':
            p['at']=[-.065,p['at'][1]]
        if ident=='musicbox':
            p['size']=[.104,.165];p['pivot']=[.5,.96]
        if ident=='hem':
            p['size']=[.327,.226]
        if ident=='body':
            p['size']=[.327,.4572]
        target=tuple(max(1,round(v*1100)) for v in p['size'])
        if ident=='body':
            # Cut the upper and lower cape out of ONE continuous painted shape,
            # retaining a shared horizontal scale and overlap at the waist.
            full_cape=im.resize((target[0],round(.6133732*1100)),Image.Resampling.LANCZOS)
            im=full_cape.crop((0,0,target[0],target[1]))
        elif ident=='hem':
            start=round(.3873732*1100)
            im=full_cape.crop((0,start,target[0],start+target[1]))
        else:
            im=im.resize(target,Image.Resampling.LANCZOS)
        if ident in ('upperArmB','foreArmB','handB'):
            arr=np.array(im)
            arr[:,:,:3]=(arr[:,:,:3].astype(float)*.86).astype('uint8')
            im=Image.fromarray(arr)
        if ident=='hem':
            arr=np.array(im)
            fade=np.clip(np.arange(im.height)/(im.height*.34),0,1)
            arr[:,:,3]=(arr[:,:,3]*fade[:,None]).astype('uint8')
            im=Image.fromarray(arr)
        images[ident]=im
        im.save(PARTS/f'{ident}.png')
        ax=(i%4)*512+(512-im.width)//2;ay=(i//4)*512+(512-im.height)//2
        atlas.alpha_composite(im,(ax,ay))
        p['uv']=[ax/2048,1-(ay+im.height)/2048,(ax+im.width)/2048,1-ay/2048]
        p['image']=f'parts/{ident}.png'
    atlas.save(OUT/'moss-atlas.png')
    result={'name':'moss','displayName':'苔音','atlas':[2048,2048],'height':1.1,'textureEncoding':'straight-alpha sRGB RGBA; not the original boy RG mask','parts':[parts[x] for x in ORDER],'anchors':spec['anchors']}
    (OUT/'moss-rig.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
    return result,images


def draw_frame(spec,images,frame,size=512):
    im=Image.new('RGBA',(size,size))
    scale=size/frame.get('cameraSpan',2.28);origin=size*.46;floor=size*.88
    for p in sorted(spec['parts'],key=lambda p:frame.get('layers',{}).get(p['id'],p['layer'])):
        ident=p['id'];a,b,c,d,tx,ty=frame['bones'][ident]
        part=images[ident];w,h=p['size'];px,py=p['pivot'];iw,ih=part.size
        A=scale*a*w/iw;B=-scale*c*h/ih
        C=origin+scale*(-a*px*w+c*(1-py)*h+tx)
        D=-scale*b*w/iw;E=scale*d*h/ih
        F=floor-scale*(-b*px*w+d*(1-py)*h+ty)
        det=A*E-B*D
        if abs(det)<1e-8:continue
        inv=(E/det,-B/det,(B*F-E*C)/det,-D/det,A/det,(D*C-A*F)/det)
        layer=part.transform(im.size,Image.Transform.AFFINE,inv,Image.Resampling.BICUBIC)
        im.alpha_composite(layer)
    return im


def backdrop(im):
    page=Image.new('RGBA',im.size,'#7f8e96')
    d=ImageDraw.Draw(page);floor=round(im.height*.88)
    d.line((0,floor,im.width,floor),fill='#64747c',width=1)
    page.alpha_composite(im)
    return page.convert('RGB')


def make_board(spec,images,motion):
    page=Image.new('RGB',(1600,1000),'#eae6da');d=ImageDraw.Draw(page)
    font=lambda n:ImageFont.truetype(FONT,n)
    d.text((88,68),'GO HOME  /  NEW COMPANION',font=font(19),fill='#6c7864')
    d.text((84,120),'苔音',font=font(84),fill='#303c35')
    d.text((90,224),'M O S S',font=font(27),fill='#81836b')
    d.text((90,310),'替夜路留一盏小灯。',font=font(32),fill='#475448')
    for j,line in enumerate(['安静、敏锐，习惯先听见远处的声音。','短发与叶片发夹，保留孩子的柔软轮廓。','苔绿色斗篷承接森林；琥珀提灯回应主角。']):
        d.text((90,376+j*40),line,font=font(21),fill='#7b8070')
    colors=['#596952','#3d5147','#2e4342','#302d2b','#b6b2a2','#cf9f51']
    for j,color in enumerate(colors):
        x=90+j*88;d.rounded_rectangle((x,573,x+62,635),radius=31,fill=color)
        d.text((x-3,653),color.upper(),font=font(12),fill='#737a6a')
    frame=motion['clips'][0]['frames'][24]
    hero=draw_frame(spec,images,frame,1500)
    bounds=hero.getbbox();hero=hero.crop(bounds);hero.thumbnail((620,690),Image.Resampling.LANCZOS)
    page.paste(hero,(965+(490-hero.width)//2,110),hero)
    d.line((90,825,1500,825),fill='#c9cebe',width=2)
    for j,(title,sub) in enumerate([('同一世界的手绘剪影','低饱和 · 纸张肌理 · 侧面轮廓'),('承接主角的动作语言','小步行走 · 跑跳缓冲 · 衣摆惯性'),('属于她自己的回应','侧耳聆听 · 提灯致意')]):
        x=90+j*490;d.text((x,865),title,font=font(23),fill='#4b5b4c');d.text((x,910),sub,font=font(16),fill='#7e8779')
    page.save(OUT/'character-design.jpg',quality=94)


def verify_and_package(motion):
    checks=[]
    for clip in motion['clips']:
        paths=sorted((OUT/'frames'/clip['id']).glob('*.png'))
        assert len(paths)==len(clip['frames'])
        for path in paths:
            im=Image.open(path)
            assert im.mode=='RGBA' and im.size==(512,512)
            bb=im.getbbox()
            assert bb and bb[0]>0 and bb[1]>0 and bb[2]<512 and bb[3]<512,(clip['id'],path.name,bb)
        animation=Image.open(OUT/'animations'/f"{clip['id']}.webp")
        assert animation.n_frames==len(paths)
        checks.append({'id':clip['id'],'frames':len(paths),'rgba':True,'noClipping':True,'webpFrames':animation.n_frames})
    listen=next(c for c in motion['clips'] if c['id']=='listen')
    for frame in listen['frames']:
        bones=frame['bones']
        # Neither hand reaches the face; the lowered lamp remains upright.
        assert bones['handF'][5]<bones['upperArmF'][5]-.1
        assert bones['handB'][5]<bones['upperArmB'][5]-.2
        assert abs(math.atan2(bones['musicbox'][1],bones['musicbox'][0]))<.025
        assert all(frame.get('layers',{}).get(name,LAYERS[name])<LAYERS['body'] for name in ('upperArmB','foreArmB','handB'))
    for side in ('F','B'):
        heights=[f['bones'][f'foot{side}'][5] for f in listen['frames']]
        assert max(heights)-min(heights)<.002
    assert listen['frames'][30]['bones']['musicbox'][5]<listen['frames'][0]['bones']['musicbox'][5]-.10
    (OUT/'verification.json').write_text(json.dumps({'passed':True,'revision':'listen-lower-lamp-2026-11-17','totalFrames':sum(c['frames'] for c in checks),'clips':checks,'listening':'75 frames / 2.5 seconds: stagger feet, lower lamp, lean head forward, quiet hold, recover. Both hands stay below shoulders; feet remain planted; lamp tilt under 1.5 degrees.'},ensure_ascii=False,indent=2))
    files=[]
    for folder in ('parts','frames','animations','spritesheets'):
        files.extend(sorted((OUT/folder).glob('*')))
    for name in ('README.md','index.html','character-design.jpg','animation-preview.gif','listen-preview.gif','animation-overview.jpg','moss-atlas.png','moss-rig.json','motion.json','manifest.json','verification.json','source/concept-raw.png','source/parts-raw.png','work/design-prompt.txt','work/parts-prompt.txt','work/cutout-layout-reference.png'):
        files.append(OUT/name)
    archive=OUT/'苔音-角色动画素材包.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as package:
        for file in files:
            if file.is_file():package.write(file,Path('苔音-Moss')/file.relative_to(OUT))
    with zipfile.ZipFile(archive) as package:
        assert package.testzip() is None


def build():
    spec,images=build_parts()
    motion=json.loads((OUT/'motion.json').read_text())
    animations=OUT/'animations';animations.mkdir(exist_ok=True)
    sheets=OUT/'spritesheets';sheets.mkdir(exist_ok=True)
    allframes={};manifest=[]
    for clip in motion['clips']:
        ident=clip['id'];folder=OUT/'frames'/ident;folder.mkdir(parents=True,exist_ok=True)
        frames=[draw_frame(spec,images,f) for f in clip['frames']]
        assert len({f.tobytes() for f in frames})>1,ident
        for stale in folder.glob('*.png'):
            if int(stale.stem)>=len(frames):stale.unlink()
        for i,im in enumerate(frames):im.save(folder/f'{i:03}.png')
        durations=[33,33,34]*(len(frames)//3)+[33,33,34][:len(frames)%3]
        frames[0].save(animations/f'{ident}.webp',save_all=True,append_images=frames[1:],duration=durations,loop=0,lossless=True)
        sheet=Image.new('RGBA',(8*256,math.ceil(len(frames)/8)*256))
        for i,f in enumerate(frames):sheet.alpha_composite(f.resize((256,256),Image.Resampling.LANCZOS),((i%8)*256,(i//8)*256))
        sheet.save(sheets/f'{ident}.png')
        allframes[ident]=frames
        manifest.append({k:clip[k] for k in ['id','title','fps','duration','loop']}|{'frames':len(frames),'frameSize':[512,512],'sheetFrameSize':[256,256],'columns':8,'animation':f'animations/{ident}.webp','sheet':f'spritesheets/{ident}.png'})
    make_board(spec,images,motion)
    featured=['idle','walk','run','jump','listen','lantern']
    font=lambda n:ImageFont.truetype(FONT,n)
    previews=[]
    for i in range(72):
        page=Image.new('RGB',(1200,954),'#202d2b');d=ImageDraw.Draw(page)
        d.text((28,20),'苔音  /  MOSS',font=font(31),fill='#ece8d8')
        d.text((28,65),'与主角同源的步态 · 一盏陪你回家的灯',font=font(17),fill='#adb9a5')
        for j,ident in enumerate(featured):
            x=20+(j%3)*394;y=110+(j//3)*412
            f=backdrop(allframes[ident][i%len(allframes[ident])]).resize((376,376),Image.Resampling.LANCZOS)
            page.paste(f,(x,y));title=next(c['title'] for c in motion['clips'] if c['id']==ident)
            d.text((x+8,y+384),title,font=font(22),fill='#e1e6d6')
        previews.append(page)
    previews[18].save(OUT/'animation-overview.jpg',quality=94)
    # GIF is a convenient inline overview; full-alpha lossless files are separate.
    sampled=previews[::2];palette=sampled[0].quantize(colors=256)
    q=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in sampled]
    q[0].save(OUT/'animation-preview.gif',save_all=True,append_images=q[1:],duration=[67,66,67]*12,loop=0,disposal=2,optimize=False)
    listen=allframes['listen']
    bounds=[f.getbbox() for f in listen]
    crop=(max(0,min(b[0] for b in bounds)-30),max(0,min(b[1] for b in bounds)-25),min(512,max(b[2] for b in bounds)+30),min(512,max(b[3] for b in bounds)+20))
    closeups=[backdrop(f).crop(crop) for f in listen[::2]]
    palette=closeups[0].quantize(colors=256)
    closeups=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in closeups]
    durations=[round(min(i+2,len(listen))*1000/30)-round(i*1000/30) for i in range(0,len(listen),2)]
    closeups[0].save(OUT/'listen-preview.gif',save_all=True,append_images=closeups[1:],duration=durations,loop=0,disposal=2,optimize=False)
    (OUT/'manifest.json').write_text(json.dumps({'character':'苔音 / Moss','clips':manifest,'totalFrames':sum(len(c['frames']) for c in motion['clips']),'simulationHz':60,'fps':30,'rendering':'Offline RGBA cutout compositing from actual game skeleton transforms','integration':'Design asset package; not yet wired into Flutter gameplay'},ensure_ascii=False,indent=2))
    payload={'rig':spec,'motion':motion,'images':{k:data_url(v) for k,v in images.items()},'concept':data_url(Image.open(OUT/'character-design.jpg'))}
    template=(ROOT/'tools/companion_gallery.html').read_text()
    (OUT/'index.html').write_text(template.replace('__PAYLOAD__',json.dumps(payload,ensure_ascii=False,separators=(',',':'))))
    verify_and_package(motion)
    print(f'Built {len(manifest)} clips; {sum(len(v) for v in allframes.values())} transparent frames')


if __name__=='__main__':build()
