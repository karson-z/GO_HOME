#!/usr/bin/env python3
"""Real, all-angle 3D reconstruction inspired by the user's two reference images.
No source-image planes, alpha cutouts, projected facades or image textures.
Closed petal/leaf meshes, architectural openings, inset doors/windows, 3D terrain.
Python + NumPy only. Rebuilds individual GLBs and an assembled scene.
"""
from pathlib import Path
import json, math
import numpy as np
from gltf_mesh import GLB
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models';DOC=ROOT/'docs/garden3d';DOC.mkdir(exist_ok=True)
PI=math.pi

def unit(v):
 v=np.asarray(v,dtype=float);return v/max(np.linalg.norm(v),1e-10)
def linear(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
def rgb(hexcode):return tuple(linear(int(hexcode[i:i+2],16)/255) for i in (0,2,4))+(1,)
PALETTE={
 'plaster':'F1DFB0','plaster_warm':'E3C88D','stone':'C5B382','ivory':'FFF0C5',
 'petal':'FFEEB1','petal_light':'FFF7D8','petal_shadow':'E8CB87','seam':'AC8D54',
 'wood':'EDDFB3','wood_edge':'C5B17E','sage':'9DAE75','sage_dark':'738451',
 'glass':'D3DFB2','gold':'DAAA38','pollen':'F3CC54','flower_white':'FFF7D9',
 'leaf':'8C9B62','leaf_light':'B1B77D','leaf_dark':'697F54','stem':'7F8E50',
 'grass':'B9BD7D','moss':'C5C78A','hill':'D6D8AA','hill_far':'E1E3C1',
 'road':'EFDCAC','soil':'B7AC75','cloud':'FFFAEA',
}

class Builder:
 def __init__(self,g):self.g=g;self.groups={};self.mats={}
 def material(self,name):
  if name not in self.mats:self.mats[name]=self.g.mat(name,rgb(PALETTE[name]))
  return self.mats[name]
 def add(self,name,p,ix,mat,parent):
  key=(name,mat,parent);bucket=self.groups.setdefault(key,[[],[]]);offset=len(bucket[0])
  bucket[0].extend(np.asarray(p).tolist());bucket[1].extend((np.asarray(ix,dtype=int)+offset).tolist())
 def finish(self):
  for (name,mat,parent),(p,ix) in self.groups.items():
   p=np.asarray(p);f=.91+.09*(.5+.5*np.sin(p[:,0]*2.7+p[:,1]*3.1)*np.cos(p[:,2]*2.2-p[:,1]*1.7))
   colors=np.repeat(f[:,None],3,axis=1)
   if name == 'Terrain / volumetric rolling hills':
    # Merge the hill foot into the meadow colour instead of a pale rectangle.
    t=np.clip(p[:,1]/3.0,0,1)[:,None]
    grass=np.array(rgb(PALETTE['grass'])[:3]);hill=np.array(rgb(PALETTE['hill_far'])[:3])
    colors=((1-t)*grass+t*hill)/np.array(rgb(PALETTE['ivory'])[:3])*f[:,None]
   mesh=self.g.mesh(name,p,ix,self.material(mat),colors=colors)
   self.g.node(name,mesh,parent)
 def sphere(self,name,c,r,mat,parent,nx=14,ny=9):
  p=[];ix=[]
  for j in range(ny+1):
   t=PI*j/ny
   for i in range(nx+1):
    a=2*PI*i/nx;p.append(np.array(c)+np.array(r)*[math.sin(t)*math.cos(a),math.cos(t),math.sin(t)*math.sin(a)])
  for j in range(ny):
   for i in range(nx):
    q=j*(nx+1)+i;ix.extend([[q,q+1,q+nx+1],[q+1,q+nx+2,q+nx+1]])
  self.add(name,p,ix,mat,parent)
 def box(self,name,c,size,mat,parent,bevel=.04):
  # Face-separated normals preserve readable edges; bevel strips soften corners.
  lo=np.array(c)-np.array(size)/2;hi=np.array(c)+np.array(size)/2
  p=[];ix=[]
  for axis in range(3):
   others=[i for i in range(3) if i!=axis]
   for sign in [-1,1]:
    corners=[]
    for a,b in [(-1,-1),(1,-1),(1,1),(-1,1)]:
     v=np.array(c,dtype=float);v[axis]=hi[axis] if sign>0 else lo[axis]
     v[others[0]]+=a*size[others[0]]/2;v[others[1]]+=b*size[others[1]]/2;corners.append(v)
    # Correct winding for this face.
    n=np.cross(corners[1]-corners[0],corners[2]-corners[0])
    if n[axis]*sign<0:corners.reverse()
    off=len(p);p.extend(corners);ix.extend([[off,off+1,off+2],[off,off+2,off+3]])
  self.add(name,p,ix,mat,parent)
 def tube(self,name,points,radius,mat,parent,sides=7,cap=True):
  points=np.asarray(points);p=[];ix=[]
  for j,point in enumerate(points):
   tangent=unit(points[min(j+1,len(points)-1)]-points[max(0,j-1)])
   ref=[0,1,0] if abs(tangent[1])<.9 else [1,0,0]
   u=unit(np.cross(tangent,ref));v=np.cross(tangent,u)
   r=radius if np.isscalar(radius) else radius[j]
   for k in range(sides):p.append(point+r*(math.cos(k*2*PI/sides)*u+math.sin(k*2*PI/sides)*v))
  for j in range(len(points)-1):
   for k in range(sides):
    a=j*sides+k;b=j*sides+(k+1)%sides;c=a+sides;d=b+sides;ix.extend([[a,b,c],[b,d,c]])
  if cap:
   for ring,sign in [(0,-1),(len(points)-1,1)]:
    center=len(p);p.append(points[ring]);offset=ring*sides
    for k in range(sides):
     t=[center,offset+k,offset+(k+1)%sides];ix.append(t if sign<0 else t[::-1])
  self.add(name,p,ix,mat,parent)
 def polygon(self,name,outline,z,depth,mat,parent):
  # Convex XY outline with real front/rear caps and walls.
  outline=np.asarray(outline);n=len(outline);p=[];ix=[]
  for dz in [0,-depth]:p.extend([[x,y,z+dz] for x,y in outline])
  for i in range(1,n-1):ix.extend([[0,i,i+1],[n,n+i+1,n+i]])
  for i in range(n):j=(i+1)%n;ix.extend([[i,n+i,j],[j,n+i,n+j]])
  self.add(name,p,ix,mat,parent)
 def leaf(self,name,base,tip,width,mat,parent,bend=None,thickness=.025,segments=9,roll=0):
  base=np.asarray(base,dtype=float);tip=np.asarray(tip,dtype=float);axis=unit(tip-base)
  u=unit(np.cross(axis,[0,0,1] if abs(axis[2])<.85 else [0,1,0]));normal=unit(np.cross(u,axis))
  u=unit(u*math.cos(roll)+normal*math.sin(roll));normal=unit(np.cross(u,axis))
  if bend is None:bend=normal*np.linalg.norm(tip-base)*.18
  bend=np.asarray(bend);across=4;p=[];ix=[]
  for back in [False,True]:
   for j in range(segments+1):
    s=j/segments;center=base+(tip-base)*s+bend*math.sin(PI*s)
    half=width*max(.015,math.sin(PI*s)**.72)
    for i in range(across+1):
     t=-1+2*i/across
     ridge=normal*(.18*width*(1-t*t)*math.sin(PI*s)+(-thickness/2 if back else thickness/2))
     p.append(center+u*t*half+ridge)
  face=(segments+1)*(across+1)
  for j in range(segments):
   for i in range(across):
    q=j*(across+1)+i;tri=[[q,q+across+1,q+1],[q+1,q+across+1,q+across+2]]
    ix.extend(tri);ix.extend([[c+face,b+face,a+face] for a,b,c in tri])
  for j in range(segments):
   for i in [0,across]:
    a=j*(across+1)+i;b=(j+1)*(across+1)+i;ix.extend([[a,b,a+face],[b,b+face,a+face]])
  for j in [0,segments]:
   for i in range(across):
    a=j*(across+1)+i;b=a+1;ix.extend([[a,a+face,b],[b,a+face,b+face]])
  self.add(name,p,ix,mat,parent)
 def petal(self,name,center,normal,angle,length,width,mat,parent,segments=10):
  n=unit(normal);u=unit(np.cross([0,1,0],n)) if abs(n[1])<.9 else np.array([1.,0,0]);v=np.cross(n,u)
  radial=u*math.cos(angle)+v*math.sin(angle);side=-u*math.sin(angle)+v*math.cos(angle)
  p=[];ix=[];across=4
  for back in [False,True]:
   for j in range(segments+1):
    s=j/segments;half=width*max(.015,math.sin(PI*s)**.65)
    for i in range(across+1):
     t=-1+2*i/across
     bulge=length*(.12*math.sin(PI*s)+.15*s*s)+.12*length*t*t*math.sin(PI*s)
     p.append(np.array(center)+radial*(.08*length+s*length)+side*t*half+n*(bulge+(-.018 if back else .018)))
  face=(segments+1)*(across+1)
  for j in range(segments):
   for i in range(across):
    q=j*(across+1)+i;ts=[[q,q+1,q+across+1],[q+1,q+across+2,q+across+1]]
    ix.extend(ts);ix.extend([[c+face,b+face,a+face] for a,b,c in ts])
  for j in range(segments):
   for i in [0,across]:
    a=j*(across+1)+i;b=a+across+1;ix.extend([[a,a+face,b],[b,a+face,b+face]])
  for j in [0,segments]:
   for i in range(across):
    a=j*(across+1)+i;b=a+1;ix.extend([[a,b,a+face],[b,b+face,a+face]])
  self.add(name,p,ix,mat,parent)

 def flower(self,name,c,r,parent,normal=(0,.12,1),daffodil=False,petals=6):
  n=unit(normal);c=np.asarray(c,dtype=float)
  for k in range(petals):self.petal(name+' / sculpted petals',c,n,k*2*PI/petals,r,r*.38,'petal_light' if daffodil else 'flower_white',parent,segments=8 if r>.5 else 5)
  # A cup is a thin-walled trumpet, not a painted centre circle.
  if daffodil:
   u=unit(np.cross([0,1,0],n));v=np.cross(n,u);p=[];ix=[];sides=24;rings=5
   for inner in [False,True]:
    for j in range(rings):
     s=j/(rings-1);radius=r*(.15+.13*s)+(-.022 if inner else .022)
     for i in range(sides):
      a=2*PI*i/sides;rr=radius*(1+.1*math.sin(a*8)*s*s)
      p.append(c+n*(.04*r+.43*r*s)+rr*(u*math.cos(a)+v*math.sin(a)))
   half=sides*rings
   for j in range(rings-1):
    for i in range(sides):
     a=j*sides+i;b=j*sides+(i+1)%sides;d=a+sides;e=b+sides
     ix.extend([[a,b,d],[b,e,d],[a+half,d+half,b+half],[b+half,d+half,e+half]])
   for i in range(sides):
    a=(rings-1)*sides+i;b=(rings-1)*sides+(i+1)%sides;ix.extend([[a,b,a+half],[b,b+half,a+half]])
   self.add(name+' / hollow trumpet',p,ix,'pollen',parent)
   self.sphere(name+' / stamen',c+n*r*.12,(r*.13,)*3,'gold',parent,nx=9,ny=6)
  else:self.sphere(name+' / pollen dome',c+n*r*.12,(r*.23,r*.23,r*.16),'pollen',parent,nx=9,ny=6)

def torus(b,name,c,radius,tube_radius,mat,parent,normal=(0,0,1)):
 n=unit(normal);u=unit(np.cross([0,1,0],n)) if abs(n[1])<.9 else np.array([1.,0,0]);v=np.cross(n,u)
 p=[];ix=[];sides=32;section=8
 for i in range(sides+1):
  a=2*PI*i/sides;radial=u*math.cos(a)+v*math.sin(a)
  for j in range(section+1):
   t=2*PI*j/section;p.append(np.array(c)+radial*(radius+tube_radius*math.cos(t))+n*tube_radius*math.sin(t))
 for i in range(sides):
  for j in range(section):
   q=i*(section+1)+j;ix.extend([[q,q+section+1,q+1],[q+1,q+section+1,q+section+2]])
 b.add(name,p,ix,mat,parent)

def cottage(b,parent):
 # Thick hollow plaster wall, with real front door and front/rear window openings.
 nx=160;ny=64;p=[];ix=[];valid=set()
 def radius(y):return 3.65+.45*math.sin(PI*min(y,5.7)/5.7)
 for inner in [False,True]:
  for j in range(ny+1):
   y=5.7*j/ny;r=radius(y)-(.18 if inner else 0);d=3.0-(.18 if inner else 0)
   for i in range(nx+1):
    a=2*PI*i/nx;s=math.sin(a);c=math.cos(a)
    p.append([r*s,y,d*math.copysign(abs(c)**.4,c)])
 face=(nx+1)*(ny+1)
 for j in range(ny):
  y=(j+.5)*5.7/ny
  for i in range(nx):
   a=(i+.5)*2*PI/nx;x=radius(y)*math.sin(a);z=3*math.cos(a)
   door=z>0 and abs(x-1.55)<1.04 and .12<y<3.0+math.sqrt(max(0,1.04**2-(x-1.55)**2))
   front_window=z>0 and (x+1.7)**2+(y-2.8)**2<.95**2
   back_window=z<0 and x*x+(y-2.85)**2<.83**2
   if door or front_window or back_window:continue
   valid.add((i,j));q=j*(nx+1)+i;ts=[[q,q+1,q+nx+1],[q+1,q+nx+2,q+nx+1]]
   ix.extend(ts);ix.extend([[c+face,b+face,a+face] for a,b,c in ts])
 # Reveal thickness along architectural holes, as well as top and bottom rims.
 for i,j in valid:
  q=j*(nx+1)+i
  for nb,edge in [(((i-1)%nx,j),(q,q+nx+1)),(((i+1)%nx,j),(q+1,q+nx+2)),((i,j-1),(q,q+1)),((i,j+1),(q+nx+1,q+nx+2))]:
   if nb in valid:continue
   a,c=edge;ix.extend([[a,a+face,c],[c,a+face,c+face]])
 b.add('House / thick shell with architectural openings',p,ix,'plaster',parent)
 b.sphere('House / stone foundation',(0,.13,0),(4.13,.23,3.14),'stone',parent,nx=40,ny=8)
 # Interior floor. Opening the actual door reveals this space.
 b.box('House / interior floor',(0,.19,0),(6.2,.14,4.8),'plaster_warm',parent)
 # Door jamb, lintel and planked door on a hinge.
 pts=[[.48,.2,3.03],[.48,3.0,3.03]]
 pts += [[1.55+1.07*math.cos(a),3+1.07*math.sin(a),3.03] for a in np.linspace(PI,0,28)]
 pts += [[2.62,.2,3.03]]
 b.tube('House / bevelled door surround',pts,.18,'plaster_warm',parent,sides=10)
 hinge=b.g.node('DoorHinge',parent=parent,translation=[.55,.22,3.04])
 for k in range(7):
  x0=k*2/7+.012;x1=(k+1)*2/7-.012
  outline=[[x0,0],[x1,0]]
  outline += [[x,2.78+math.sqrt(max(0,1-(x-1)**2))] for x in np.linspace(x1,x0,6)]
  b.polygon('Door / individual rounded planks',outline,-.035,.15,'sage',hinge)
  for j in [0,1]:
   gx=x0+(x1-x0)*(.3+.35*j);height=2.78+math.sqrt(max(0,1-(gx-1)**2))
   pts=[[gx+.008*math.sin(t*9+j),t*height,-.024] for t in np.linspace(.05,.94,13)]
   b.tube('Door / carved grain',pts,.006,'sage_dark',hinge,sides=4)
 b.sphere('Door / brass handle',(1.75,1.72,.12),(.115,.115,.10),'gold',hinge)
 b.tube('Door / handle spindle',[[1.75,1.72,-.02],[1.75,1.72,.12]],.045,'gold',hinge)
 for y in [.75,2.55]:b.box('Door / hinge straps',(.06,y,.04),(.16,.12,.08),'wood_edge',hinge)
 b.box('House / entrance step',(1.55,.13,3.4),(2.7,.26,1.3),'plaster_warm',parent)
 b.box('House / entrance step lower',(1.55,.045,3.87),(2.95,.09,.55),'stone',parent)
 # Windows are inset glass volumes, real timber rings and mullions.
 for center,r,n in [((-1.7,2.8,2.99),.91,(0,0,1)),((0,2.85,-3.03),.79,(0,0,-1))]:
  torus(b,'Windows / timber circular frame',center,r,.115,'wood_edge',parent,n)
  b.sphere('Windows / inset opaque glass',np.array(center)-np.array(n)*.13,(r*.94,r*.94,.07),'glass',parent,nx=24,ny=14)
  cx,cy,cz=center
  b.box('Windows / horizontal mullion',(cx,cy,cz+.06*n[2]),(r*1.85,.095,.13),'wood',parent)
  b.box('Windows / vertical mullion',(cx,cy,cz+.06*n[2]),(.095,r*1.85,.13),'wood',parent)
 # Side windows also have side-facing volume, to avoid an empty back/side model.
 for sign in [-1,1]:
  c=(sign*4.05,2.75,0);torus(b,'Windows / side round frame',c,.68,.10,'wood_edge',parent,(sign,0,0))
  b.sphere('Windows / side glass',c,(.06,.60,.60),'glass',parent,nx=18,ny=12)
  b.box('Windows / side mullions',c,(.14,.08,1.15),'wood',parent)
  b.box('Windows / side mullions',c,(.14,1.15,.08),'wood',parent)
 # Large closed sculpted roof petals, radiating in all directions.
 for layer,(count,length,width,height) in enumerate([(9,5.55,1.85,6.6),(7,3.4,1.6,7.05)]):
  for k in range(count):
   angle=k*2*PI/count+(0 if layer==0 else .28)
   radial=np.array([math.cos(angle),0,math.sin(angle)]);side=np.array([-math.sin(angle),0,math.cos(angle)])
   p=[];ix=[];long=16;cross=6
   for back in [False,True]:
    for j in range(long+1):
     s=j/long;half=width*max(.012,math.sin(PI*s)**.58)
     for i in range(cross+1):
      t=-1+2*i/cross
      y=height-(1.25 if layer==0 else .70)*s+.38*math.sin(PI*s)-.28*s**3+.23*(1-t*t)*math.sin(PI*s)
      point=radial*(.18+length*s)+side*half*t+np.array([0,y+(-.065 if back else .065),0])
      p.append(point)
   face=(long+1)*(cross+1)
   for j in range(long):
    for i in range(cross):
     q=j*(cross+1)+i;ts=[[q,q+1,q+cross+1],[q+1,q+cross+2,q+cross+1]]
     ix.extend(ts);ix.extend([[c+face,b+face,a+face] for a,b,c in ts])
   for j in range(long):
    for i in [0,cross]:
     a=j*(cross+1)+i;c=a+cross+1;ix.extend([[a,c,a+face],[c,c+face,a+face]])
   for j in [0,long]:
    for i in range(cross):
     a=j*(cross+1)+i;c=a+1;ix.extend([[a,a+face,c],[c,a+face,c+face]])
   b.add(f'Roof / petal tier {layer+1}',p,ix,'petal_light' if k%3 else 'petal',parent)
   # A shallow sculpted vein makes curvature readable in grazing light.
   points=[]
   for s in np.linspace(.18,.92,18):
    y=height-(1.25 if layer==0 else .70)*s+.38*math.sin(PI*s)-.28*s**3+.23*math.sin(PI*s)+.073
    points.append(radial*(.18+length*s)+[0,y,0])
   b.tube('Roof / raised petal veins',points,.012,'petal_shadow',parent,sides=5)
 # Closed flower bud, a lobed lathe with sculpted seams and pointed sepals.
 profile=[(0,.3),(.35,.85),(.9,1.18),(1.5,1.15),(2.1,.88),(2.65,.15),(2.75,.035)]
 p=[];ix=[];sides=48
 for y,r in profile:
  for i in range(sides+1):
   a=2*PI*i/sides;rr=r*(1+.075*math.cos(a*6));p.append([rr*math.cos(a),6.95+y,rr*math.sin(a)])
 for j in range(len(profile)-1):
  for i in range(sides):
   q=j*(sides+1)+i;ix.extend([[q,q+1,q+sides+1],[q+1,q+sides+2,q+sides+1]])
 b.add('Roof / six-lobed flower bud',p,ix,'ivory',parent)
 for k in range(6):
  a=k*PI/3;pts=[[r*(1.08)*math.cos(a),6.95+y,r*1.08*math.sin(a)] for y,r in profile]
  b.tube('Roof / bud petal seams',pts,.018,'petal_shadow',parent,sides=5)
  b.leaf('Roof / bud sepals',[.25*math.cos(a),7.0,.25*math.sin(a)],[1.45*math.cos(a),7.3,1.45*math.sin(a)],.3,'sage',parent)
 # Creeping vines and fully modelled daisies cover the eaves and door sides.
 rng=np.random.default_rng(40)
 for side in [-1,1]:
  x=(-3.0 if side<0 else 2.9);pts=[[x+.25*math.sin(t*9),.4+t*5,2.4-.18*t] for t in np.linspace(0,1,35)]
  b.tube('Ivy / winding stems',pts,.035,'stem',parent)
  for j in range(22):
   t=j/22;point=np.array([x+.25*math.sin(t*9),.4+t*5,2.45-.18*t]);sgn=(-1)**j
   tip=point+[sgn*.5,.2,.20+float(rng.uniform(-.15,.15))]
   b.leaf('Ivy / separate leaves',point,tip,.23,'leaf' if j%2 else 'leaf_light',parent,segments=6)
   if j%4==0:b.flower('Ivy / daisies',tip+[0,.08,.14],.22,parent,petals=5)
 for k in range(28):
  a=k*2*PI/28;x=3.5*math.sin(a);z=2.95*math.cos(a)
  base=np.array([x,4.9+.17*math.sin(a*3),z]);tip=base+[.3*math.cos(a),-.48,.2*math.sin(a)]
  b.leaf('Eaves / hanging leaves',base,tip,.24,'leaf_light' if k%2 else 'leaf',parent,segments=6)
  if k%3==0:b.flower('Eaves / daisies',base+unit([x,.5,z])*.22,.24,parent,normal=unit([x,.9,z]),petals=5)

def grass_clump(b,parent,center,spread,height,count=15,seed=1):
 rng=np.random.default_rng(seed);center=np.array(center)
 for j in range(count):
  a=float(rng.uniform(0,2*PI));r=float(rng.uniform(.1,spread));base=center+[r*.25*math.cos(a),0,r*.25*math.sin(a)]
  tip=center+[r*math.cos(a),height*float(rng.uniform(.6,1.15)),r*math.sin(a)]
  b.leaf('Plants / curved grass blades',base,tip,.10+height*.045,['leaf','leaf_light','leaf_dark'][j%3],parent,bend=[.25*math.cos(a),height*.2,.25*math.sin(a)],segments=7,roll=a)

def daffodil_plant(b,parent,large=False,seed=2):
 rng=np.random.default_rng(seed)
 heads=[(-.65,4.8,.15,.8),(.7,3.5,.4,.65)] if not large else [(-1.3,6.7,.15,1.23),(1.55,4.6,.6,1.0),(.8,6.8,-.65,.45)]
 for i,(x,y,z,r) in enumerate(heads):
  pts=[[x*t+.10*math.sin(t*PI),y*t,z*t-.15*math.sin(t*PI)] for t in np.linspace(0,1,15)]
  b.tube('Daffodil / flexible round stems',pts,.035 if large else .028,'stem',parent)
  b.flower('Daffodil',np.array([x,y,z]),r,parent,normal=((.32,-.65,.75)[i%3],.12+.08*i,1),daffodil=True)
 grass_clump(b,parent,[0,0,0],2.9 if large else 1.6,4.6 if large else 3.0,21 if large else 13,seed)
 # Basal leaves splay in depth, as well as across the frontal view.
 for i in range(8):
  a=i*PI/4;b.leaf('Daffodil / basal leaves',[0,.1,0],[2.2*math.cos(a),1.5,1.7*math.sin(a)],.18,'leaf_light',parent,segments=8,roll=a*.7)


def bush(b,parent,width=4,height=2.5,seed=3,flowers=True):
 rng=np.random.default_rng(seed)
 for i in range(14):
  a=float(rng.uniform(0,2*PI));r=float(rng.uniform(0,1));c=[math.cos(a)*width*.34*r,.18+float(rng.uniform(.1,.45)),math.sin(a)*width*.22*r]
  b.sphere('Shrub / moss volumes',c,(width*.20,.4,width*.16),'moss' if i%2 else 'grass',parent,nx=10,ny=6)
 for i in range(64):
  theta=float(rng.uniform(0,2*PI));t=float(rng.uniform(-.4,1));r=math.sqrt(max(0,1-t*t));pos=np.array([r*math.cos(theta)*width*.42,.35+(t+.4)*height*.68,r*math.sin(theta)*width*.27])
  radial=unit([math.cos(theta),float(rng.uniform(.3,1)),math.sin(theta)])
  base=pos-radial*.25;tip=pos+radial*float(rng.uniform(.3,.55))
  b.leaf('Shrub / individual folded leaves',base,tip,float(rng.uniform(.22,.38)),['leaf','leaf_light','leaf_dark'][i%3],parent,segments=5)
  if flowers and i%7==0:
   flower_c=tip+[0,.05,.12];b.flower('Shrub / daisies',flower_c,float(rng.uniform(.18,.30)),parent,normal=unit([radial[0]*.25,.3,.8]),petals=5)
 for i in range(5):
  c=[float(rng.uniform(-width*.35,width*.35)),height*.7+float(rng.uniform(-.3,.2)),float(rng.uniform(-.5,.5))]
  b.flower('Shrub / top flowers',c,.25,parent,normal=unit([0,.7,1]),petals=5)


def arch(b,parent):
 def path(z):
  pts=[[-2.7,0,z],[-2.7,3.3,z]]
  pts += [[2.7*math.cos(a),3.3+2.7*math.sin(a),z] for a in np.linspace(PI,0,45)]
  return pts+[[2.7,0,z]]
 for z in [-.43,.43]:b.tube('Arch / front and rear timber ribs',path(z),.16,'wood',parent,sides=10)
 for a in np.linspace(0,PI,9):
  x=2.7*math.cos(a);y=3.3+2.7*math.sin(a)
  b.tube('Arch / depth ties',[[x,y,-.43],[x,y,.43]],.09,'wood_edge',parent)
 for x in [-2.7,2.7]:
  b.box('Arch / raised stone feet',(x,.15,0),(.7,.3,1.25),'stone',parent)
  for y in [1.1,2.2]:b.box('Arch / column cross braces',(x,y,0),(.18,.10,.95),'wood_edge',parent)
 rng=np.random.default_rng(14)
 # Geometry grows all around both sides of the frame, not just toward the camera.
 route=path(0)
 for j,pt in enumerate(route[1:-1]):
  if j%2:continue
  point=np.asarray(pt)
  outward=unit([point[0],point[1]-3.3,0]) if point[1]>3.3 else np.array([math.copysign(1,point[0]),.1,0])
  for side in [-1,1]:
   c=point+outward*.20+[0,0,side*.46]
   tip=c+outward*.40+[float(rng.uniform(-.2,.2)),float(rng.uniform(-.15,.25)),side*.22]
   b.leaf('Arch / three-dimensional ivy',c,tip,.26,'leaf_light' if j%4 else 'leaf',parent,segments=6)
   tip2=c-outward*.25+[.15,-.3,side*.16]
   b.leaf('Arch / crossing ivy',c,tip2,.20,'leaf',parent,segments=5)
   if j%4==0:
    b.flower('Arch / flowers front and rear',c+outward*.18+[0,0,side*.22],.35 if point[1]>4 else .29,parent,normal=(0,.15,side),petals=5)
 # The lower columns have additional climbing leaves and ground plants.
 for side in [-1,1]:
  x=side*2.7
  points=[[x+.18*math.sin(t*PI*7),t*3.4,.34*math.cos(t*PI*7)] for t in np.linspace(0,1,35)]
  b.tube('Arch / winding vine stems',points,.035,'stem',parent)
  for j in range(13):
   y=.3+j*.23;c=[x,y,(-1)**j*.38]
   b.leaf('Arch / column leaves',c,[x+side*.45,y+.3,(-1)**j*.56],.23,'leaf_light',parent,segments=5)
   if j%4==0:b.flower('Arch / column daisies',[x+side*.27,y+.2,.65],.26,parent,petals=5)
  grp=b.g.node('Arch / foot planting',parent=parent,translation=[x,0,0],scale=[.55,.55,.55]);bush(b,grp,2.3,1.7,seed=32+side)


def fence(b,parent):
 for x in [-2.8,0,2.8]:
  b.box('Fence / solid timber posts',(x,1.18,0),(.30,2.36,.38),'wood',parent)
  b.sphere('Fence / rounded post caps',(x,2.36,0),(.15,.20,.19),'wood',parent,nx=12,ny=8)
  for y in [.3,1.1,1.95]:b.tube('Fence / wood grain relief',[[x-.08,y, .201],[x-.07,y+.25,.201],[x-.09,y+.35,.201]],.009,'wood_edge',parent,sides=4)
 for y in [.72,1.58]:
  b.box('Fence / rails',(0,y,-.06),(5.9,.23,.26),'wood',parent)
  b.tube('Fence / inset rail edge',[[-2.7,y-.07,.08],[2.7,y-.07,.08]],.012,'wood_edge',parent,sides=4)
 for k in range(3):
  x=-2+k*2.0
  pts=[[x+.18*math.sin(t*8),.15+1.5*t,.20+.13*math.cos(t*8)] for t in np.linspace(0,1,18)]
  b.tube('Fence / climbing vines',pts,.025,'stem',parent)
  for j in range(6):
   c=[x,.25+j*.22,.27];b.leaf('Fence / vine leaves',c,[x+(-1)**j*.35,.4+j*.22,.42],.17,'leaf',parent,segments=5)
  b.flower('Fence / daisies',[x,1.15,.47],.24,parent,petals=5)


def terrain(b,parent,width,depth,height,seed=10,far=False):
 rng=np.random.default_rng(seed);nx=70 if far else 24;ny=24 if far else 16;p=[];ix=[]
 peaks=[(-width*.33,depth*.15,height*.8,width*.24,depth*.7),(width*.28,-depth*.1,height,width*.3,depth*.7),(width*.02,-depth*.2,height*.5,width*.3,depth*.5)]
 for j in range(ny+1):
  z=-depth/2+depth*j/ny
  for i in range(nx+1):
   x=-width/2+width*i/nx;y=0
   for px,pz,h,sx,sz in peaks:y+=h*math.exp(-((x-px)/sx)**2-((z-pz)/sz)**2)
   edge=math.sin(PI*i/nx)**.4*math.sin(PI*j/ny)**.45
   y*=edge
   y+=.06*math.sin(x*2+z)*edge
   p.append([x,y,z])
 for j in range(ny):
  for i in range(nx):
   q=j*(nx+1)+i;ix.extend([[q,q+nx+1,q+1],[q+1,q+nx+1,q+nx+2]])
 # Close the hill against a shallow underside around its complete perimeter.
 perimeter=list(range(nx+1))+[j*(nx+1)+nx for j in range(1,ny+1)]+[ny*(nx+1)+i for i in range(nx-1,-1,-1)]+[j*(nx+1) for j in range(ny-1,0,-1)]
 center=len(p);p.append([0,-.12,0])
 for k,a in enumerate(perimeter):c=perimeter[(k+1)%len(perimeter)];ix.append([center,c,a])
 b.add('Terrain / volumetric rolling hills' if far else 'Terrain / rounded meadow mound',p,ix,'ivory' if far else 'grass',parent)
 if not far:
  for k in range(7):
   x=float(rng.uniform(-width*.35,width*.35));z=float(rng.uniform(-depth*.3,depth*.3));y=0
   for px,pz,h,sx,sz in peaks:y+=h*math.exp(-((x-px)/sx)**2-((z-pz)/sz)**2)
   edge=math.sin(PI*(x/width+.5))**.4*math.sin(PI*(z/depth+.5))**.45;y*=edge
   grass_clump(b,parent,[x,y,z],.35,.45,5,seed+k)
   if k%2==0:b.flower('Meadow / small daisies',[x,y+.35,z],.14,parent,normal=(0,.8,.6),petals=5)


def asset(g,kind):
 root=g.node('Garden3D / '+kind);b=Builder(g)
 if kind=='cottage':cottage(b,root)
 elif kind=='flower_arch':arch(b,root)
 elif kind=='fence':fence(b,root)
 elif kind=='daffodil':daffodil_plant(b,root)
 elif kind in ['flowers_left','flowers_right']:
  daffodil_plant(b,root,large=True,seed=7 if kind=='flowers_left' else 9)
  for x,z,s in [(-2,0,.8),(1.7,1,.65),(0,-1,.7)]:
   p=g.node('Flower patch / ground foliage',parent=root,translation=[x,0,z],scale=[s,s,s]);bush(b,p,3,1.7,seed=20+int(x*2))
 elif kind=='bush':bush(b,root,4.7,3.1,seed=4)
 elif kind=='small_flowers':bush(b,root,4.0,1.7,seed=6)
 elif kind=='meadow':terrain(b,root,12.5,6.5,1.2)
 elif kind=='grass_patch':terrain(b,root,12,4,.38,seed=18)
 elif kind=='hills':terrain(b,root,50,17,4.6,far=True)
 elif kind=='cloud':
  for c,r in [((-2.8,.45,0),(1.7,.6,.8)),((-1.1,.85,0),(1.7,.95,1.1)),((.5,1.35,0),(1.5,1.4,1.3)),((2,.65,0),(1.9,.8,1.0)),((3.2,.35,0),(1.3,.42,.65))]:b.sphere('Cloud / soft volume',c,r,'cloud',root,nx=20,ny=12)
 b.finish();return root


def ground(g):
 root=g.node('Garden3D / ground');b=Builder(g);nx=100;nz=72;p=[];ix=[]
 def ground_y(x,z):
  flatten=1-math.exp(-((z-.5)/3.9)**6)
  return -.09+(.09*math.sin(x*.31+z*.17)+.06*math.cos(x*.52-z*.22))*flatten
 for j in range(nz+1):
  z=-29+64*j/nz
  for i in range(nx+1):
   x=-34+68*i/nx;p.append([x,ground_y(x,z),z])
 for j in range(nz):
  for i in range(nx):
   q=j*(nx+1)+i;ts=[[q,q+nx+1,q+1],[q+1,q+nx+1,q+nx+2]]
   ix.extend(ts)
 b.add('Ground / undulating meadow',p,ix,'grass',root)
 # A continuous curved ribbon follows the ground; its silhouette is not snapped to cells.
 p=[];ix=[];steps=160;across=8
 for i in range(steps+1):
  x=-34+68*i/steps;edge=3.1+.18*math.sin(x*.42)+.1*math.cos(x*.9)
  for j in range(across+1):
   z=.5+edge*(-1+2*j/across);p.append([x,ground_y(x,z)+.018,z])
 for i in range(steps):
  for j in range(across):
   q=i*(across+1)+j;ix.extend([[q,q+1,q+across+1],[q+1,q+across+2,q+across+1]])
 b.add('Ground / sandy walking road',p,ix,'road',root)
 rng=np.random.default_rng(19)
 for i in range(95):
  x=float(rng.uniform(-26,26));z=float(rng.choice([-1,1]))*float(rng.uniform(3.8,16))
  grass_clump(b,root,[x,0,z],.23,.27,3,seed=i)
 for i in range(40):
  x=float(rng.uniform(-25,25));z=float(rng.uniform(-1.7,2.8))
  b.sphere('Road / small rounded pebbles',[x,-.03,z],(.09,.035,.055),'plaster_warm',root,nx=6,ny=4)
 b.finish();return root

KINDS=['cottage','flower_arch','fence','daffodil','flowers_left','flowers_right','bush','small_flowers','meadow','grass_patch','hills','cloud']
PLACEMENTS=[
 ('hills',0,0,-19,1.0,0,'far'),
 ('cloud',-17,6,-24,1.1,0,'far'),('cloud',13,5.5,-24,1.0,0,'far'),
 ('cottage',-10.5,0,-5.0,1.0,-4,'middle'),('flower_arch',8.2,0,-5.0,1.08,0,'middle'),
 ('fence',0,0,-6.4,1.0,0,'middle'),('fence',15,0,-6.4,1.0,0,'middle'),
 ('grass_patch',-13,-.12,-7,1.0,0,'middle'),('grass_patch',0,-.12,-7,1.0,0,'middle'),('grass_patch',13,-.12,-7,1.0,0,'middle'),
 ('bush',-17,0,-5,1.1,15,'middle'),('bush',1.6,0,-5.6,.9,-20,'middle'),('bush',18,0,-5.8,1.0,0,'middle'),
 ('daffodil',-17,0,-2.8,1.05,12,'middle'),('daffodil',-3.6,0,-3.5,.8,-9,'middle'),('daffodil',18,0,-3,1.0,-12,'middle'),
 ('small_flowers',-14,0,-1.5,1.0,20,'middle'),('small_flowers',-5,0,-1.4,.7,-20,'middle'),('small_flowers',2.4,0,-1.7,.9,0,'middle'),('small_flowers',13.7,0,-1.5,.95,0,'middle'),
 ('meadow',-14,-.1,12,1.2,4,'front'),('meadow',0,-.1,15,1.3,0,'front'),('meadow',14,-.1,12,1.2,-5,'front'),
 ('flowers_left',-17.5,0,19,1.1,-8,'front'),('flowers_right',17.5,0,19,1.1,8,'front'),
 ('small_flowers',-9.5,0,21,1.2,12,'front'),('bush',10,0,21,1.0,-8,'front'),
]

if __name__=='__main__':
 for kind in KINDS:
  g=GLB();asset(g,kind);g.write(OUT/f'garden3d_{kind}.glb');print(kind,len(g.doc['meshes']))
 g=GLB();ground(g);g.write(OUT/'garden3d_ground.glb')
 g=GLB();root=g.node('Flower Garden / fully modelled 3D');gr=ground(g);g.doc['scenes'][0]['nodes'].remove(gr);g.doc['nodes'][root].setdefault('children',[]).append(gr)
 templates={}
 for kind in KINDS:
  idx=asset(g,kind);g.doc['scenes'][0]['nodes'].remove(idx);templates[kind]=idx
 def clone(index,parent):
  node=g.doc['nodes'][index];new={k:v for k,v in node.items() if k!='children'};idx=len(g.doc['nodes']);g.doc['nodes'].append(new);g.doc['nodes'][parent].setdefault('children',[]).append(idx)
  for child in node.get('children',[]):clone(child,idx)
  return idx
 for i,(kind,x,y,z,scale,rotation,layer) in enumerate(PLACEMENTS):
  idx=clone(templates[kind],root);g.doc['nodes'][idx].update(name=f'{i:02d} / {kind}',translation=[x,y,z],scale=[scale]*3,rotation=[0,math.sin(math.radians(rotation)/2),0,math.cos(math.radians(rotation)/2)])
 g.doc['cameras']=[{'name':'Composition / orthographic','type':'orthographic','orthographic':{'xmag':23,'ymag':15.333,'znear':.1,'zfar':200}}]
 idx=g.node('Reference camera',translation=[0,5+70*math.sin(.34),70*math.cos(.34)],rotation=[-math.sin(.17),0,0,math.cos(.17)]);g.doc['nodes'][idx]['camera']=0
 g.write(OUT/'garden3d_complete.glb')
 enum={'cottage':'cottage','flower_arch':'flowerArch','fence':'gardenFence','daffodil':'daffodil','flowers_left':'flowersLeft','flowers_right':'flowersRight','bush':'flowerBush','small_flowers':'smallFlowers','meadow':'gardenMeadow','grass_patch':'gardenGrass','hills':'gardenHills','cloud':'gardenCloud'}
 scene={'schema':'forest-workshop','version':1,'theme':'garden','road':True,'fog':0,'warmth':.65,'lesson':0,'items':[{'id':f'garden3d-{i:02d}','kind':enum[k],'layer':layer,'x':x,'y':y,'z':z,'scale':s,'rotation':r} for i,(k,x,y,z,s,r,layer) in enumerate(PLACEMENTS)]}
 (ROOT/'examples/flower_garden_3d.json').write_text(json.dumps(scene,ensure_ascii=False,indent=2))
 manifest={'type':'Fully geometric 3D reconstruction','referenceImagesOnly':True,'imageTextures':0,'alphaCutoutMeshes':0,'units':'metres','up':'+Y','front':'+Z','placements':len(PLACEMENTS),
 'modelling':{'house':'Thick hollow shell, real architectural openings, inset glass, separate mullions, individual planks on DoorHinge, closed sculpted roof petals and bud.','flowers':'Each petal is a closed curved mesh, trumpet has inner and outer walls, stems are tubes.','leaves':'Closed curved lanceolate meshes with raised midribs, distributed in three dimensions.','terrain':'3D heightfields with a sandy path, volumetric distant hills and cloud volumes.'},
 'assets':[{'file':f'garden3d_{k}.glb','bytes':(OUT/f'garden3d_{k}.glb').stat().st_size} for k in KINDS]}
 (DOC/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
