"""Build an offline gallery from native GLES captures; never generates character art."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageStat
import base64, io, json, math

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/boy-actions'
FONT = '/System/Library/Fonts/STHeiti Medium.ttc'
ACTIONS = [
 ('idle','站立与呼吸','基础移动','静止时的呼吸、重心与衣摆微动。'),
 ('walk','步行','基础移动','低速行走，脚掌落点和手臂自然摆动。'),
 ('run','跑动','基础移动','高速步态、躯干前倾和衣摆惯性。'),
 ('start-stop','起步与停步','基础移动','加速、减速、落脚收步和重心稳定。'),
 ('turn','左右转身','基础移动','转向时头部先行、身体翻转和轻微屈膝。'),
 ('slope-up','上坡','地形适应','脚部 IK 贴合上坡地面。'),
 ('slope-down','下坡','地形适应','脚部 IK 贴合下坡地面。'),
 ('steps-up','上台阶','地形适应','落脚高度随台阶变化。'),
 ('steps-down','下台阶','地形适应','下行时足部高度与腿部伸展调整。'),
 ('platform','移动平台上的步态','地形适应','支撑面上下移动时的足部适应。'),
 ('walkoff','走出边缘后下落','地形适应','离开支撑面后转为空中姿态并落地。'),
 ('jump','原地跳跃','跳跃落地','蓄力屈膝 → 蹬地 → 上升 → 顶点 → 下落 → 缓冲。'),
 ('run-jump','跑跳','跳跃落地','水平移动与完整跳跃姿态叠加。'),
 ('land-soft','轻落地','跳跃落地','低处下落后的轻微屈膝缓冲和回弹。'),
 ('land-heavy','重落地','跳跃落地','较高处下落后的较深屈膝与身体回弹。'),
 ('push','伸手推物','推物与音乐盒','伸手、前倾与推行步态；预览省略被推物。'),
 ('push-blocked','推不动时用力','推物与音乐盒','受阻时持续用力与身体颤动，不是受伤动作。'),
 ('crank','原地摇音乐盒','推物与音乐盒','音符触发摇柄、手部 IK 和音乐盒姿态；预览无声。'),
 ('crank-walk','边走边摇音乐盒','推物与音乐盒','步行与摇柄动作叠加。'),
 ('crank-air','空中摇音乐盒','推物与音乐盒','跑跳与摇柄动作叠加。'),
 ('sleep','树下睡姿','开场与坐姿','标题及开场所用的蜷腿、低头睡姿。'),
 ('wake','醒来与起身','开场与坐姿','醒来、重心前移、屈腿、撑起，最后站立。'),
 ('sit','结尾坐下','开场与坐姿','当前渲染器的简化坐姿过渡，尚不能视为原作细分演出的完整复现。'),
]
STORIES = [
 ('ending-14.5.png','熊背骑乘阶段','当前实景：主角跟随熊背的位置移动。骑乘弹簧与抓握细节未接入。'),
 ('ending-26.5.png','父亲肩上阶段','当前实景：在父亲肩上随行。此图展示位置编排。'),
 ('ending-48.5.png','家人汇合阶段','当前实景：结尾汇合过程。被放下、转向与走向树边见动作脚本。'),
 ('finale-1.5.png','树下与母亲互动','当前实景：树下坐姿和母亲互动。主角拥抱、哭泣等细分骨骼仍缺接线。'),
 ('finale-12.0.png','老年形态与离去','当前实景：老年形态和离去演出，属于剧情角色及形态变化。'),
 ('finale-23.0.png','萤火飞行','当前实景：后续萤火飞行段，不属于可操作的人形动作。'),
]

OUT.mkdir(exist_ok=True, parents=True)
(OUT/'animations').mkdir(exist_ok=True)
(OUT/'atlases').mkdir(exist_ok=True)
clips=[]
frames_by_id={}
for ident,title,category,desc in ACTIONS:
    paths=sorted((OUT/'frames'/ident).glob('*.png'))
    expected=48 if ident=='wake' else 36
    assert len(paths)==expected,(ident,len(paths))
    frames=[Image.open(p).convert('RGB') for p in paths]
    assert all(f.size==(540,540) for f in frames)
    for f in frames:
        extrema=f.getextrema()
        assert max(b-a for a,b in extrema)>30, ident
    assert len({f.tobytes() for f in frames})>1, f'{ident} must animate'
    frames_by_id[ident]=frames
    durations=[67,66,67]*(len(frames)//3)
    frames[0].save(OUT/'animations'/f'{ident}.webp',save_all=True,append_images=frames[1:],duration=durations,loop=0,lossless=True)
    sheet=Image.new('RGB',(6*360,math.ceil(len(frames)/6)*360),'#81909e')
    for j,f in enumerate(frames):sheet.paste(f.resize((360,360),Image.Resampling.LANCZOS),((j%6)*360,(j//6)*360))
    buf=io.BytesIO();sheet.save(buf,format='WEBP',lossless=True)
    (OUT/'atlases'/f'{ident}.webp').write_bytes(buf.getvalue())
    clips.append(dict(id=ident,title=title,category=category,description=desc,frames=len(frames),fps=15,duration=len(frames)/15,atlas='data:image/webp;base64,'+base64.b64encode(buf.getvalue()).decode()))

font=lambda n:ImageFont.truetype(FONT,n)
def contact(ids,title,dest,cols,size):
    rows=math.ceil(len(ids)/cols);gap=10;header=86;cw=size;ch=size+58
    frames=[]
    lookup={a[0]:a for a in ACTIONS}
    for t in range(48):
        page=Image.new('RGB',(cols*cw+(cols+1)*gap,header+rows*ch+(rows+1)*gap),'#171f28')
        d=ImageDraw.Draw(page)
        d.text((20,15),title,font=font(28),fill='#f0e4c9')
        d.text((20,53),'当前 Flutter 原生骨骼与 shader · 参数驱动演示 · 无声',font=font(16),fill='#abb8c5')
        for j,ident in enumerate(ids):
            x=gap+(j%cols)*(cw+gap);y=header+gap+(j//cols)*(ch+gap)
            fs=frames_by_id[ident]
            page.paste(fs[min(t,len(fs)-1)].resize((size,size),Image.Resampling.LANCZOS),(x,y))
            d.text((x+8,y+size+7),lookup[ident][1],font=font(17 if size<230 else 20),fill='#e8e5de')
            label='当前简化坐姿' if ident=='sit' else lookup[ident][2]
            d.text((x+8,y+size+32),label,font=font(13),fill='#a8b5c2')
        frames.append(page)
    palette=frames[0].quantize(colors=256)
    quantized=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
    quantized[0].save(OUT/dest,save_all=True,append_images=quantized[1:],duration=[70,60,70]*16,loop=0,optimize=False,disposal=2)
    frames[12].save(OUT/dest.replace('.gif','.jpg'),quality=93)

contact([a[0] for a in ACTIONS],'GO HOME · 主角全部 23 组动作演示','all-actions.gif',6,210)
contact(['walk','run','turn','jump','push-blocked','crank','wake','sit'],'GO HOME · 主角动作预览','featured-actions.gif',4,250)

story_cards=[]
for filename,title,desc in STORIES:
    im=Image.open(ROOT/'artifacts/current-native'/filename).convert('RGB')
    im.thumbnail((1000,500))
    buf=io.BytesIO();im.save(buf,format='JPEG',quality=91)
    story_cards.append(dict(title=title,description=desc,image='data:image/jpeg;base64,'+base64.b64encode(buf.getvalue()).decode(),source=filename))

manifest=dict(title='GO HOME 主角动作图鉴',clips=[{k:v for k,v in c.items() if k!='atlas'} for c in clips],nativeFrames=sum(c['frames'] for c in clips),simulationHz=60,captureFps=15,renderer='NativeBoyRenderer / original two-pass GLSL',paletteTime=.34,notes=['23 组是参数动作演示，不是 23 个离散动画文件。','使用当前 Flutter 移植渲染器，不是原版桌面录像。','背景与地面线仅为看清动作设置；不修改游戏场景。','普通跳跃与跑跳均包含蓄力、起跳、空中和落地阶段。','结尾截图来自原生回归实景；未接入的细分动作不能视作已还原。'])
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))

html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>GO HOME · 主角动作图鉴</title>
<style>
:root{color-scheme:dark;font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;background:#111820;color:#e5e9ee}*{box-sizing:border-box}body{margin:0}main{max-width:1350px;margin:auto;padding:40px 28px 80px}h1{font-size:38px;margin:10px 0 12px;color:#f1e5cd;font-weight:550}h2{font-size:24px;color:#f1e5cd;margin:42px 0 12px}p{line-height:1.8;color:#aab9c8;font-size:15px;max-width:1000px}.eyebrow{color:#ddbc7b;letter-spacing:3px;font-size:12px}.stats{display:flex;gap:12px;margin:24px 0}.stats span{padding:9px 14px;background:#1e2a36;border-radius:6px;font-size:14px}.toolbar{position:sticky;top:0;z-index:5;background:#111820f5;padding:14px 0;display:flex;gap:9px;align-items:center;flex-wrap:wrap;border-bottom:1px solid #324150;backdrop-filter:blur(14px)}button,select{font:inherit;background:#253341;color:#e5e9ee;border:1px solid #425363;border-radius:6px;padding:9px 13px;cursor:pointer}button:hover,button.active{background:#dbbd81;color:#17212c;border-color:#dbbd81}button:focus-visible,select:focus-visible,input:focus-visible{outline:3px solid #f2da98;outline-offset:3px}.filters{display:flex;gap:8px;flex-wrap:wrap;padding:20px 0}.grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:16px}.card{padding:0;overflow:hidden;text-align:left;border:1px solid #354454;border-radius:9px;background:#1a2632;cursor:zoom-in}.card:hover{background:#253746;color:#fff;border-color:#bda578}.card[hidden]{display:none}.card canvas{width:100%;height:auto;display:block}.info{padding:14px 16px;min-height:120px}.category{color:#9bb0c1;font-size:11px}.info h3{margin:8px 0;font-size:17px;font-weight:550;color:#f0e7d5}.info p{margin:0;font-size:12px;line-height:1.6;color:#a9b9c7}.note{padding:18px 22px;background:#252c31;border-left:3px solid #dbbd81;border-radius:0 8px 8px 0;margin:24px 0}.note p{margin:0}.stories{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px}.story{background:#1a2632;border-radius:8px;overflow:hidden}.story img{width:100%;display:block}.story div{padding:16px 20px}.story h3{margin:0;font-size:17px}.story p{font-size:13px;margin:8px 0 0}li{line-height:1.9;color:#bbc7d3;margin-bottom:5px}details{background:#1a2632;border:1px solid #344656;padding:18px;border-radius:8px;margin-top:20px}summary{cursor:pointer;color:#eddbb5}code{font-size:12px;color:#bfd1e0}dialog{background:#15212d;color:#e9edf2;border:1px solid #536779;border-radius:12px;width:min(670px,94vw);max-height:96vh;padding:20px}dialog::backdrop{background:#000b;backdrop-filter:blur(6px)}dialog canvas{display:block;width:min(540px,100%);max-height:57vh;object-fit:contain;margin:auto}dialog h2{margin:10px 0;font-size:22px}dialog p{font-size:13px}dialog .controls{display:flex;gap:9px;align-items:center;flex-wrap:wrap;margin-top:14px}input[type=range]{flex:1;min-width:100px;accent-color:#e4c584}.close{float:right}small{color:#9eb1c3}.foot{margin-top:35px;font-size:12px;color:#8fa5b9}@media(max-width:1000px){.grid{grid-template-columns:repeat(3,1fr)}}@media(max-width:700px){main{padding:24px 15px 50px}h1{font-size:29px}.grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:9px}.info{padding:11px;min-height:138px}.info h3{font-size:15px}.stories{grid-template-columns:1fr}.stats{gap:6px}.stats span{padding:8px;font-size:12px}.toolbar{font-size:13px}}
</style>
<main><div class="eyebrow">GO HOME / CHARACTER MOTION</div><h1>主角动作图鉴</h1><p>主角采用参数驱动的骨骼动画。下面 23 组演示覆盖当前移动版的基础动作、地形适应和常用叠加组合。点击卡片可放大、慢放或逐帧查看。</p><div class="stats"><span>23 组演示</span><span>840 帧原生渲染</span><span>60 Hz 模拟 / 15 fps 预览</span></div>
<div class="note"><p>这是<strong>当前 Flutter 移植版本</strong>的动作展示，使用现有主角贴图、骨骼与原作两遍 GLSL。背景和地面参考线用于看清动作。预览无声；结尾简化姿态和未接入的细分动作在下方单独说明。</p></div>
<div class="toolbar"><button id="play" aria-pressed="true">暂停全部</button><button id="step">下一帧</button><label>速度 <select id="speed"><option value="0.25">0.25×</option><option value="0.5">0.5×</option><option value="1" selected>1×</option><option value="2">2×</option></select></label><small id="status">播放中 · 点击卡片放大</small></div><nav class="filters" aria-label="动作分类"></nav><section class="grid" aria-label="全部动作"></section>
<h2>结尾剧情中的主角</h2><p>以下是已有原生场景截图，包含剧透。它们展示剧情和角色位置，不能替代主角细分骨骼动画的逐帧验收。</p><section class="stories"></section>
<div class="note"><p><strong>尚未接入当前画面的细分动作：</strong>骑熊时的俯仰弹簧、抓握与腿部后摆；与母亲拥抱时主角的后臂和身体响应；哭泣时低头与身体抽动；结尾伸手、握持和受力等过渡。工程中已有相关动作模块，但当前主角绘制路径尚未调用。</p></div>
<details open><summary>完整动作清单与实现边界</summary><ul id="full-list"></ul><p>跳跃包括蓄力屈膝、蹬地、上升、顶点、下落、落地缓冲和站稳；这些是连续阶段。呼吸、头部先行、衣摆惯性、手臂摆动、脚掌贴地属于叠加细节。地形卡片展示同一套步态对环境的适应。</p><p>剧情还包括登上熊背、骑熊、父亲肩上随行、被放下、转向家人、走向树边、坐下，以及老年形态、灵魂与萤火飞行。当前结尾由位置脚本、简化主角姿态和家人渲染共同组成；<code>sit / kneel / curl / crouch / lie</code> 等标签并不代表每种独立动作都已完整接入。</p><p>共享动画库中的舞蹈、喂食、吃东西等通用分支，不算作主角当前实际使用的动作。母亲抚摸、拥抱、亲吻等也不列为主角主动动作。</p></details>
<details><summary>取样与代码依据</summary><p>取样使用 iOS 模拟器原生 GLES，60 Hz 输入推进，15 fps 保存；多数片段 2.4 秒，醒来起身 3.2 秒。动作由预设参数驱动，不是玩家通关录像。场景截图来自先前的原生回归。</p><ul><li><code>native_boy_renderer.dart</code>：贴图合成、GLSL、开场姿态与当前简化结尾坐姿。</li><li><code>original_boy_motion.dart / original_boy_gait.dart / original_boy_runtime.dart</code>：移动、转身、跳跃、落地、地形 IK、推物与音乐盒。</li><li><code>original_opening.dart / original_opening_pose.dart</code>：睡醒、起身及开场时序。</li><li><code>original_ending.dart / original_ending_boy_motion.dart / original_world_view.dart</code>：结尾编排、细分动作模块及实际调用路径。</li></ul></details><p class="foot">动作演示工具不改变游戏运行行为。可离线打开；无外部字体、脚本或图片依赖。</p></main>
<dialog id="detail"><button class="close" id="close">关闭</button><h2 id="detail-title"></h2><canvas id="large" width="540" height="540" aria-label="放大动作预览"></canvas><p id="detail-desc"></p><div class="controls"><button id="detail-play">暂停</button><button id="previous">上一帧</button><button id="next">下一帧</button><input id="scrub" type="range" min="0" value="0" aria-label="动作帧"><small id="frame-label"></small></div></dialog>
<script>
const clips=__CLIPS__, stories=__STORIES__;
const $=s=>document.querySelector(s), grid=$('.grid'), modal=$('#detail'), gallery=[];
let playing=true,speed=1,time=0,last=0,selected=null,detailPlaying=true,detailTime=0;
function draw(item,frame,canvas=item.canvas){const ctx=canvas.getContext('2d');if(!item.image.complete||!item.image.naturalWidth)return;ctx.drawImage(item.image,(frame%6)*360,Math.floor(frame/6)*360,360,360,0,0,canvas.width,canvas.height)}
function globalState(){ $('#play').textContent=playing?'暂停全部':'播放全部';$('#play').setAttribute('aria-pressed',String(playing));$('#status').textContent=playing?'播放中 · 点击卡片放大':'已暂停 · 可逐帧查看'; }
for(const [i,c] of clips.entries()){const card=document.createElement('button');card.className='card';card.setAttribute('aria-label','查看 '+c.title);card.innerHTML=`<canvas width="360" height="360" aria-label="${c.title}"></canvas><div class="info"><span class="category">${String(i+1).padStart(2,'0')} / ${c.category}</span><h3>${c.title}</h3><p>${c.description}</p></div>`;grid.append(card);const image=new Image(),item={...c,card,canvas:card.querySelector('canvas'),image};image.onload=()=>draw(item,0);image.src=c.atlas;gallery.push(item);card.onclick=()=>{selected=item;detailTime=0;detailPlaying=true;$('#detail-title').textContent=item.title;$('#detail-desc').textContent=item.description;$('#scrub').max=item.frames-1;$('#detail-play').textContent='暂停';modal.showModal();drawDetail()}}
for(const cat of ['全部',...new Set(clips.map(c=>c.category))]){const b=document.createElement('button');b.textContent=cat;b.className=cat==='全部'?'active':'';b.setAttribute('aria-pressed',String(cat==='全部'));b.onclick=()=>{for(const a of gallery)a.card.hidden=cat!=='全部'&&a.category!==cat;for(const x of $('.filters').children){x.classList.toggle('active',x===b);x.setAttribute('aria-pressed',String(x===b))}};$('.filters').append(b)}
for(const s of stories){const a=document.createElement('article');a.className='story';a.innerHTML=`<img src="${s.image}" alt="${s.title}的当前原生场景截图" loading="lazy"><div><h3>${s.title}</h3><p>${s.description}</p></div>`;$('.stories').append(a)}
for(const cat of new Set(clips.map(c=>c.category))){const li=document.createElement('li');li.textContent=cat+'：'+clips.filter(c=>c.category===cat).map(c=>c.title).join('、')+'。';$('#full-list').append(li)}
$('#play').onclick=()=>{playing=!playing;globalState()};$('#step').onclick=()=>{playing=false;time+=1/15;globalState();for(const a of gallery)draw(a,Math.floor(time*15+1e-6)%a.frames)};$('#speed').onchange=e=>speed=Number(e.target.value);
function drawDetail(){if(!selected)return;const f=Math.floor(detailTime*15+1e-6)%selected.frames;draw(selected,f,$('#large'));$('#scrub').value=f;$('#frame-label').textContent=`${f+1} / ${selected.frames}`}
function pauseDetail(){detailPlaying=false;$('#detail-play').textContent='播放'}
$('#detail-play').onclick=()=>{detailPlaying=!detailPlaying;$('#detail-play').textContent=detailPlaying?'暂停':'播放'};$('#scrub').oninput=e=>{pauseDetail();detailTime=Number(e.target.value)/15;drawDetail()};$('#previous').onclick=()=>{pauseDetail();detailTime=(Math.floor(detailTime*15+1e-6)+selected.frames-1)%selected.frames/15;drawDetail()};$('#next').onclick=()=>{pauseDetail();detailTime=(Math.floor(detailTime*15+1e-6)+1)%selected.frames/15;drawDetail()};$('#close').onclick=()=>modal.close();modal.onclick=e=>{if(e.target===modal&&e.offsetY>modal.clientHeight)modal.close()};
function tick(now){const dt=last?Math.min((now-last)/1000,.12):0;last=now;if(playing)time+=dt*speed;for(const a of gallery){if(!a.card.hidden)draw(a,Math.floor(time*15)%a.frames)}if(modal.open&&selected){if(detailPlaying)detailTime+=dt*speed;drawDetail()}requestAnimationFrame(tick)}requestAnimationFrame(tick);
</script></html>'''
html=html.replace('__CLIPS__',json.dumps(clips,ensure_ascii=False)).replace('__STORIES__',json.dumps(story_cards,ensure_ascii=False))
(OUT/'actions.html').write_text(html)
md=['# GO HOME 主角动作清单','','当前 Flutter 版本使用程序骨骼动画，动作可以叠加。下列 23 组为参数驱动的原生渲染演示，不是 23 个固定动画文件，也不是原版桌面录像。','','| 演示 | 分类 | 说明 |','| --- | --- | --- |']
md.extend(f'| {i+1}. {t} | {c} | {d} |' for i,(_,t,c,d) in enumerate(ACTIONS))
md+=['','## 结尾剧情','','登上熊背、骑熊、坐父亲肩上随行、被放下、转向家人、走向树边、树下坐姿，以及老年形态、灵魂与萤火飞行。后几项属于剧情角色或形态演出。','','## 目前尚未完整接线的主角动作','','`OriginalEndingBoyMotion` 和 `EndingRideSpring` 已有实现，但 `original_world_view.dart` 当前主角路径仍调用 `poseCinematic`。因此骑乘俯仰、抓握、腿部后摆、拥抱回应、哭泣抽动、结尾伸手握持等不能称为已完整复现。多个坐姿标签也被当前简化处理合并。','','共享库中的舞蹈、喂食、吃东西等通用分支未计入主角实际动作；母亲的抚摸、拥抱、亲吻不是主角主动动作。','','## 查看','','打开 `actions.html`：23 组可放大、暂停、0.25×/0.5×/1×/2×、逐帧。`all-actions.gif` 是全部动作总览；`featured-actions.gif` 是常用动作预览。`animations/` 是各动作独立动画。','','## 导出证据','','840 帧，iOS 模拟器原生 GLES，60 Hz 模拟、15 fps 捕获。所有帧经过非空验证；角色源为当前贴图、骨骼和原作两遍 GLSL，背景与地面线仅为展示设置。预览无声。本轮没有修改游戏运行行为。']
(OUT/'动作清单.md').write_text('\n'.join(md)+'\n')
print(f'Built {len(clips)} clips / {manifest["nativeFrames"]} frames; offline HTML: {len(html.encode()):,} bytes')
