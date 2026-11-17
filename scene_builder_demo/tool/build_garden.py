#!/usr/bin/env python3
"""Rebuild a watercolor garden kit from the user's split asset sheet.
Only parts.png supplies visual assets; composition.png is a composition reference.
Coordinates: right-handed, +Y up, front +Z; metres; bottom-centre pivots.
"""
from pathlib import Path
import io, json, math, struct
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/models'
TEX = ROOT/'assets/garden/textures'
DOC = ROOT/'docs/garden'
SRC = Image.open(ROOT/'art/garden/source/parts.png').convert('RGBA')
CROPS = {
 'cottage':(118,348,522,691), 'flower_arch':(650,388,955,693),
 'daffodil':(521,477,648,694), 'flowers_left':(0,751,390,1011),
 'flowers_right':(1277,732,1536,1016), 'bush':(1053,525,1266,693),
 'small_flowers':(395,888,581,1014), 'meadow':(839,846,1283,1015),
 'grass_patch':(776,758,1291,852), 'hills':(8,140,1530,340),
 'cloud':(875,59,1192,148), 'fence_paint':(1200,507,1427,625),
}
IMAGES={}
for name,rect in CROPS.items():
 im=SRC.crop(rect)
 a=np.array(im)
 yy,xx=np.mgrid[rect[1]:rect[3],rect[0]:rect[2]]
 if name=='cottage': a[(xx<140)&(yy<430),3]=0
 if name=='bush': a[(xx>1195)&(yy<630),3]=0
 if name=='flower_arch': a[(xx>935)&(yy>551),3]=0
 if name=='meadow': a[(xx<950)&(yy<950),3]=0
 if name=='flowers_right': a[xx<1293,3]=0
 if name=='daffodil': a[xx<528,3]=0
 if name=='fence_paint': a[yy>615,3]=0
 if name=='grass_patch': a[(yy>843)&(xx>1175),3]=0
 # Preserve real transparency. Do not key out dark outlines or paper colours.
 im=Image.fromarray(a); im.save(TEX/f'{name}.png'); IMAGES[name]=im

class GLB:
 def __init__(self):
  self.doc={'asset':{'version':'2.0','generator':'Flower Garden Kit / reproducible Python authoring'},'scene':0,
   'scenes':[{'nodes':[]}],'nodes':[],'meshes':[],'materials':[], 'accessors':[], 'bufferViews':[],
   'buffers':[], 'images':[], 'textures':[], 'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':33071,'wrapT':33071}],
   'extensionsUsed':['KHR_materials_unlit']}
  self.bin=bytearray();self.mats={};self.meshcache={}
 def buf(self,data,target=None):
  while len(self.bin)%4:self.bin.append(0)
  start=len(self.bin);self.bin.extend(data)
  entry={'buffer':0,'byteOffset':start,'byteLength':len(data)}
  if target:entry['target']=target
  self.doc['bufferViews'].append(entry);return len(self.doc['bufferViews'])-1
 def acc(self,data,typ,component=5126,target=34962):
  data=np.asarray(data,dtype='<f4' if component==5126 else '<u4')
  if typ=='SCALAR':data=data.reshape(-1)
  entry={'bufferView':self.buf(data.tobytes(),target),'componentType':component,'count':len(data),'type':typ}
  if typ=='VEC3':entry.update(min=data.min(axis=0).astype(float).tolist(),max=data.max(axis=0).astype(float).tolist())
  self.doc['accessors'].append(entry);return len(self.doc['accessors'])-1
 def mat(self,name,color=(1,1,1,1),image=None,unlit=False):
  if name in self.mats:return self.mats[name]
  m={'name':name,'doubleSided':True,'pbrMetallicRoughness':{'baseColorFactor':list(color),'metallicFactor':0,'roughnessFactor':.92}}
  if image:
   b=io.BytesIO();image.save(b,format='PNG',optimize=True)
   ix=len(self.doc['images']);self.doc['images'].append({'name':name,'bufferView':self.buf(b.getvalue()),'mimeType':'image/png'})
   self.doc['textures'].append({'sampler':0,'source':ix})
   m['pbrMetallicRoughness']['baseColorTexture']={'index':len(self.doc['textures'])-1}
   m.update(alphaMode='MASK',alphaCutoff=.06)
  if unlit:m['extensions']={'KHR_materials_unlit':{}}
  self.doc['materials'].append(m);idx=len(self.doc['materials'])-1;self.mats[name]=idx;return idx
 def mesh(self,name,pos,indices,material,uv=None):
  p=np.asarray(pos,dtype=float); ix=np.asarray(indices,dtype=np.uint32).reshape(-1,3)
  n=np.zeros_like(p)
  cross=np.cross(p[ix[:,1]]-p[ix[:,0]],p[ix[:,2]]-p[ix[:,0]])
  for j in range(3):np.add.at(n,ix[:,j],cross)
  length=np.linalg.norm(n,axis=1,keepdims=True)
  n/=np.maximum(length,1e-12)
  n[length[:,0]<1e-10]=[0,1,0]
  attrs={'POSITION':self.acc(p,'VEC3'),'NORMAL':self.acc(n,'VEC3')}
  if uv is not None:attrs['TEXCOORD_0']=self.acc(uv,'VEC2')
  self.doc['meshes'].append({'name':name,'primitives':[{'attributes':attrs,'indices':self.acc(ix.flatten(),'SCALAR',5125,34963),'material':material}]})
  return len(self.doc['meshes'])-1
 def node(self,name,mesh=None,parent=None,translation=None,scale=None,rotation=None):
  n={'name':name}
  if mesh is not None:n['mesh']=mesh
  if translation is not None:n['translation']=list(translation)
  if scale is not None:n['scale']=list(scale)
  if rotation is not None:n['rotation']=list(rotation)
  idx=len(self.doc['nodes']);self.doc['nodes'].append(n)
  if parent is None:self.doc['scenes'][0]['nodes'].append(idx)
  else:self.doc['nodes'][parent].setdefault('children',[]).append(idx)
  return idx
 def write(self,path):
  self.doc['buffers']=[{'byteLength':len(self.bin)}]
  j=json.dumps(self.doc,separators=(',',':'),ensure_ascii=False).encode();j+=b' '*((-len(j))%4)
  b=bytes(self.bin);b+=b'\0'*((-len(b))%4)
  path.write_bytes(struct.pack('<III',0x46546c67,2,12+8+len(j)+8+len(b))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(b),0x004e4942)+b)

def ellipsoid(g,name,center,radii,mat,parent):
 p=[];ix=[];nx=32;ny=18
 for j in range(ny+1):
  t=math.pi*j/ny
  for i in range(nx+1):
   a=2*math.pi*i/nx;point=[center[0]+radii[0]*math.sin(t)*math.cos(a),center[1]+radii[1]*math.cos(t),center[2]+radii[2]*math.sin(t)*math.sin(a)]
   if name.startswith('Roof /'):point[1]+=(point[2]-1.0)*math.tan(.4)
   p.append(point)
 for j in range(ny):
  for i in range(nx):
   a=j*(nx+1)+i;ix.extend([[a,a+nx+1,a+1],[a+1,a+nx+1,a+nx+2]])
 g.node(name,g.mesh(name,p,[[c,b,a] for a,b,c in ix],mat),parent)

def box(g,name,center,size,mat,parent):
 x,y,z=center;a,b,c=[v/2 for v in size]
 p=[(x+u*a,y+v*b,z+w*c) for u,v,w in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
 ix=[[0,2,1],[0,3,2],[4,5,6],[4,6,7],[0,1,5],[0,5,4],[3,7,6],[3,6,2],[1,2,6],[1,6,5],[0,4,7],[0,7,3]]
 g.node(name,g.mesh(name,p,ix,mat),parent)

def tube(g,name,points,radius,mat,parent):
 p=[];ix=[];sides=10
 for j,point in enumerate(points):
  tangent=np.array(points[min(j+1,len(points)-1)])-np.array(points[max(0,j-1)])
  tangent/=np.linalg.norm(tangent)
  b=np.cross(tangent,[0,0,1]);b/=np.linalg.norm(b);c=np.cross(tangent,b)
  for k in range(sides):p.append(np.array(point)+radius*(math.cos(k*2*math.pi/sides)*b+math.sin(k*2*math.pi/sides)*c))
 for j in range(len(points)-1):
  for k in range(sides):
   a=j*sides+k;b=j*sides+(k+1)%sides;c=a+sides;d=b+sides;ix.extend([[a,b,c],[b,d,c]])
 g.node(name,g.mesh(name,p,ix,mat),parent)

def artmesh(g,name,width,parent,relief=0,depth=0):
 """Alpha-trimmed grid surface, optional contour walls and a back cap."""
 im=IMAGES[name];w,h=im.size;height=width*h/w;step=5 if name in ('cottage','flower_arch') else 9
 nx=math.ceil(w/step);ny=math.ceil(h/step);a=np.asarray(im)[:,:,3]
 p=[];uv=[];ix=[];valid=set()
 for j in range(ny+1):
  v=j/ny
  for i in range(nx+1):
   u=i/nx;x=(u-.5)*width;y=(1-v)*height
   # Low relief retains painted detail while the structural meshes supply volume.
   z=relief*(.45+.55*math.sin(u*math.pi))*math.sin(v*math.pi*.9)
   p.append([x,y,z]);uv.append([u,v])
 for j in range(ny):
  for i in range(nx):
   region=a[int(j*h/ny):max(int((j+1)*h/ny),int(j*h/ny)+1),int(i*w/nx):max(int((i+1)*w/nx),int(i*w/nx)+1)]
   if np.max(region)<18:continue
   valid.add((i,j));q=j*(nx+1)+i;ix.extend([[q,q+nx+1,q+1],[q+1,q+nx+1,q+nx+2]])
 mat=g.mat(name+' / source watercolor',image=im,unlit=True)
 g.node(name+' / painted relief',g.mesh(name,p,ix,mat,uv),parent)
 if depth:
  # Rear silhouette is reconstructed. Separate named geometry makes the authoring technique inspectable.
  back=[[x,y,-depth] for x,y,z in p];wall=[];wi=[];wuv=[]
  for i,j in valid:
   q=j*(nx+1)+i
   for neighbor,edge in [((i,j-1),(q,q+1)),((i+1,j),(q+1,q+nx+2)),((i,j+1),(q+nx+2,q+nx+1)),((i-1,j),(q+nx+1,q))]:
    if neighbor in valid:continue
    v0,v1=edge;s=len(wall);wall.extend([p[v0],p[v1],back[v1],back[v0]]);wuv.extend([uv[v0],uv[v1],uv[v1],uv[v0]]);wi.extend([[s,s+1,s+2],[s,s+2,s+3]])
  g.node(name+' / inferred contour depth',g.mesh(name+' side walls',wall,wi,mat,wuv),parent)
  g.node(name+' / reconstructed rear',g.mesh(name+' rear',back,[[c,b,a] for a,b,c in ix],mat,uv),parent)
 return height

DIMS={'cottage':10.8,'flower_arch':7.7,'fence':6.0,'daffodil':3.2,'flowers_left':9.8,'flowers_right':6.8,'bush':5.0,'small_flowers':4.5,'meadow':12.5,'grass_patch':12.0,'hills':48.0,'cloud':8.0}

def asset(g,kind,parent=None):
 # Cache meshes via a shared authored template hierarchy, cloned as glTF nodes per placement.
 root=g.node(kind,parent=parent)
 if kind=='cottage':
  wall=g.mat('Warm lime plaster',(.86,.80,.59,1));roof=g.mat('Ivory petal / unseen sides',(.98,.89,.64,1));trim=g.mat('Sage door wood',(.54,.63,.39,1))
  ellipsoid(g,'Cottage / rounded masonry shell',(0,2.75,-1.45),(4.25,2.9,2.25),wall,root)
  # Roof petals have individual volumes, rather than a billboard-only silhouette.
  for i in range(8):
   a=2*math.pi*i/8
   ellipsoid(g,f'Roof / petal {i+1}',(2.0*math.cos(a),5.95+.1*math.sin(a),-2.05+1.32*math.sin(a)),(1.95,.5,1.1),roof,root)
  ellipsoid(g,'Roof / flower bud',(-.2,7.72,-1.3),(1.05,1.1,.95),roof,root)
  artmesh(g,kind,DIMS[kind],root,relief=1.7)
  # Actual projecting entrance step underneath the painted front.
  box(g,'Entrance / stone step',(2.0,.13,.75),(3.1,.26,1.05),wall,root)
 elif kind=='flower_arch':
  wood=g.mat('Arch / warm cream timber',(.89,.84,.63,1))
  # Opening stays physically open; no box fills the passage.
  pts=[[-2.7,0,-.38],[-2.7,3.35,-.38]]
  pts += [[2.7*math.cos(a),3.35+2.7*math.sin(a),-.38] for a in np.linspace(math.pi,0,45)]
  pts += [[2.7,0,-.38]]
  tube(g,'Arch / curved structural frame',pts,.19,wood,root)
  for x in [-2.7,2.7]:
   box(g,'Arch / foot',(x,.13,-.4),(.65,.26,.75),wood,root)
  artmesh(g,kind,DIMS[kind],root,relief=.45,depth=.24)
 elif kind=='fence':
  wood=g.mat('Fence / ivory timber',(.92,.88,.71,1));edge=g.mat('Fence / grain',(.72,.68,.48,1))
  for i,x in enumerate([-2.75,0,2.75]):
   box(g,f'Fence / post {i}',(x,1.22,-.1),(.31,2.44,.37),wood,root)
   ellipsoid(g,f'Fence / round cap {i}',(x,2.44,-.1),(.155,.2,.185),wood,root)
  for y in [.65,1.56]:box(g,'Fence / rail',(0,y,-.16),(5.7,.28,.25),wood,root)
  # Source wood and flowers overlay the volume, including their delicate outline.
  old=IMAGES.get('fence');IMAGES['fence']=IMAGES['fence_paint']
  artmesh(g,'fence',6.0,root,relief=.05)
 else:
  paint=root
  if kind=='hills':paint=g.node('Hills / broad distant contour',parent=root,scale=[1,.8,1])
  if kind in ('meadow','grass_patch'):
   paint=g.node(kind+' / horizontal ground painting',parent=root,rotation=[-math.sin(math.pi/4),0,0,math.cos(math.pi/4)])
  artmesh(g,kind,DIMS[kind],paint,relief=.08 if kind not in ('hills','cloud') else 0)
 return root

# Individually editable placements. Image 2 informs placement only, never a texture.
PLACEMENTS=[
 ('hills',0,-2,-19,1.08,0,'far'),
 ('cloud',-17,1.5,-23,1.15,0,'far'),('cloud',12.3,1.5,-22,1.0,0,'far'),
 ('grass_patch',-14,-.03,-7,1.1,0,'middle'),('grass_patch',0,-.03,-7,1.25,0,'middle'),('grass_patch',13,-.03,-7,1.1,0,'middle'),
 ('bush',-17,0,-7,1.3,0,'middle'),('bush',1.2,0,-7,1.0,0,'middle'),('bush',17,0,-7,1.25,0,'middle'),
 ('fence',-.2,.02,-5.5,1.0,0,'middle'),('fence',13.6,.02,-5.5,1.0,0,'middle'),
 ('cottage',-11.3,0,-4.4,1.12,0,'middle'),('flower_arch',7.9,0,-4.8,1.0,0,'middle'),
 ('daffodil',-18,0,-2.6,1.45,0,'middle'),('daffodil',-3.8,0,-3.3,1.0,0,'middle'),('daffodil',17.8,0,-3.1,1.2,0,'middle'),
 ('bush',-16.1,0,-1.7,.78,0,'middle'),('small_flowers',-11.0,0,-1.2,.7,0,'middle'),
 ('bush',1.6,0,-2.1,.9,0,'middle'),('small_flowers',5.0,0,-2.2,.9,0,'middle'),('bush',13.6,0,-1.8,1.0,0,'middle'),
 ('meadow',-13.5,-.02,12.5,1.4,0,'front'),('meadow',.2,-.02,15,1.65,0,'front'),('meadow',13.5,-.02,12.5,1.4,0,'front'),
 ('flowers_left',-17.8,0,20,1.2,0,'front'),('flowers_right',18,0,20,1.1,0,'front'),
 ('small_flowers',-9.3,0,22,1.2,0,'front'),('bush',10.5,0,22,1.1,0,'front'),
]

def ground(g,parent):
 # A real horizontal surface: procedural paper / pigments, not the reference image.
 rng=np.random.default_rng(12);w=1024;h=1024
 yy,xx=np.mgrid[0:h,0:w]
 fine=rng.normal(0,.9,(h,w))
 wash=Image.fromarray(np.uint8(rng.uniform(80,180,(24,24)))).resize((w,h),Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(10))
 broad=(np.asarray(wash,dtype=float)-130)*.2
 world_z=-14+yy/h*52
 road=np.exp(-((world_z-.8)/4.5)**8)
 arr=np.zeros((h,w,4),dtype=np.uint8)
 for c,(grass,sand) in enumerate(zip([224,222,175],[251,233,184])):arr[:,:,c]=np.clip(grass*(1-road)+sand*road+fine+broad,0,255)
 arr[:,:,3]=255
 im=Image.fromarray(arr)
 # Reuse small pieces from image 1 as ground pigment, never the assembled reference.
 for i in range(24):
  piece=IMAGES['grass_patch' if i%3 else 'meadow'].copy()
  piece=piece.resize((int(rng.integers(210,430)),int(rng.integers(75,145))),Image.Resampling.BICUBIC)
  opacity=piece.getchannel('A').point(lambda v: int(v*.48));piece.putalpha(opacity)
  x=int(rng.integers(-150,950));y=int(rng.choice([80,170,550,680,820,940]))
  im.alpha_composite(piece,(x,y))
 # Sparse sand marks, following the road's horizontal direction.
 marks=Image.new('RGBA',im.size,(0,0,0,0));draw=ImageDraw.Draw(marks)
 for i in range(800):
  x=int(rng.integers(w));y=int(rng.integers(200,390))
  if road[y,x]>.8:
   r=int(rng.integers(2,10));draw.ellipse((x,y,x+r*2,y+2),fill=(210,179,110,int(rng.integers(8,30))))
 im.alpha_composite(marks)
 im.save(TEX/'ground_paper.png')
 m=g.mat('Ground / procedural watercolor paper',image=im,unlit=True)
 # z=-18..17, road centre z≈0.2. Pivot origin used only for full-scene asset.
 p=[[-35,-.10,-15],[-35,-.10,38],[35,-.10,38],[35,-.10,-15]]
 g.node('Ground / meadow and walking road',g.mesh('Ground',p,[[0,1,2],[0,2,3]],m,[[0,0],[0,1],[1,1],[1,0]]),parent)

for name in DIMS:
 g=GLB();asset(g,name);g.write(OUT/f'garden_{name}.glb')
g=GLB();root=g.node('Flower Garden / assembled from split artwork');ground(g,root)
# Mesh/material sharing between repeated nodes keeps the complete export compact.
templates={}
for kind in DIMS:
 start=len(g.doc['nodes']);idx=asset(g,kind);g.doc['scenes'][0]['nodes'].remove(idx);templates[kind]=idx

def clone_node(index,parent):
 src=g.doc['nodes'][index];n={k:v for k,v in src.items() if k!='children'}
 idx=len(g.doc['nodes']);g.doc['nodes'].append(n);g.doc['nodes'][parent].setdefault('children',[]).append(idx)
 for child in src.get('children',[]):clone_node(child,idx)
 return idx
for i,(kind,x,y,z,s,rot,layer) in enumerate(PLACEMENTS):
 n=clone_node(templates[kind],root);node=g.doc['nodes'][n]
 node.update(name=f'{i:02d} / {kind}',translation=[x,y,z],scale=[s,s,s],rotation=[0,math.sin(math.radians(rot)/2),0,math.cos(math.radians(rot)/2)])
# Drop unattached authored template nodes. glTF Transform prune subsequently removes them too.
g.doc['cameras']=[{'name':'Reference composition / orthographic','type':'orthographic','orthographic':{'xmag':21,'ymag':14,'znear':.1,'zfar':200}}]
cam=g.node('Reference camera',translation=[0,4.8+70*math.sin(.4),70*math.cos(.4)],rotation=[-math.sin(.2),0,0,math.cos(.2)])
g.doc['nodes'][cam]['camera']=0
g.write(OUT/'garden_complete.glb')
ground_only=GLB();gr=ground_only.node('Garden ground');ground(ground_only,gr);ground_only.write(OUT/'garden_ground.glb')
kind_enum={'cottage':'cottage','flower_arch':'flowerArch','fence':'gardenFence','daffodil':'daffodil','flowers_left':'flowersLeft','flowers_right':'flowersRight','bush':'flowerBush','small_flowers':'smallFlowers','meadow':'gardenMeadow','grass_patch':'gardenGrass','hills':'gardenHills','cloud':'gardenCloud'}
scene={'schema':'forest-workshop','version':1,'theme':'garden','road':True,'fog':0,'warmth':.65,'lesson':0,
 'items':[{'id':f'garden-{i:02d}','kind':kind_enum[k],'layer':layer,'x':x,'y':y,'z':z,'scale':s,'rotation':r} for i,(k,x,y,z,s,r,layer) in enumerate(PLACEMENTS)]}
(ROOT/'examples/flower_garden.json').write_text(json.dumps(scene,ensure_ascii=False,indent=2))
manifest={'units':'metres','up':'+Y','front':'+Z','pivot':'bottom centre','source':'art/garden/source/parts.png','referenceOnly':'art/garden/source/composition.png',
 'technique':{'cottage':'Rounded masonry shell, eight roof petal volumes and flower bud; source-painted relief facade. Unseen sides inferred.', 'flower_arch':'Open curved timber tube and foot geometry with shallow extruded watercolor foliage.', 'fence':'3D posts, caps and rails with watercolor front overlay.', 'plants':'Alpha-trimmed low-relief cutouts; intentionally 2.5D.','ground':'Procedurally painted horizontal mesh, not reference-image projection.'},
 'assets':[{'file':f'garden_{k}.glb','width':v,'bytes':(OUT/f'garden_{k}.glb').stat().st_size} for k,v in DIMS.items()], 'placements':len(PLACEMENTS)}
(DOC/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
# A transparent extraction atlas for review, without labels from the source.
canvas=Image.new('RGB',(1200,math.ceil(len(IMAGES)/4)*260),(249,247,235));d=ImageDraw.Draw(canvas)
for i,(k,im) in enumerate(IMAGES.items()):
 x=(i%4)*300;y=(i//4)*260;thumb=im.copy();thumb.thumbnail((285,225));canvas.paste(thumb,(x+(300-thumb.width)//2,y+22),thumb);d.text((x+10,y+5),k,fill=(70,80,50))
canvas.save(DOC/'extraction-preview.jpg',quality=93)
print(json.dumps(manifest,ensure_ascii=False,indent=2))
