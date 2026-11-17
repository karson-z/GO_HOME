from pathlib import Path
import io, json, math, struct
import numpy as np

class GLB:
 def __init__(self):
  self.doc={'asset':{'version':'2.0','generator':'Flower Garden / fully geometric 3D authoring'},'scene':0,
   'scenes':[{'nodes':[]}],'nodes':[],'meshes':[],'materials':[], 'accessors':[], 'bufferViews':[],
   'buffers':[], 'images':[], 'textures':[], 'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':33071,'wrapT':33071}],
   'extensionsUsed':[]}
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
 def mesh(self,name,pos,indices,material,uv=None,colors=None):
  p=np.asarray(pos,dtype=float); ix=np.asarray(indices,dtype=np.uint32).reshape(-1,3)
  n=np.zeros_like(p)
  cross=np.cross(p[ix[:,1]]-p[ix[:,0]],p[ix[:,2]]-p[ix[:,0]])
  for j in range(3):np.add.at(n,ix[:,j],cross)
  length=np.linalg.norm(n,axis=1,keepdims=True)
  n/=np.maximum(length,1e-12)
  n[length[:,0]<1e-10]=[0,1,0]
  attrs={'POSITION':self.acc(p,'VEC3'),'NORMAL':self.acc(n,'VEC3')}
  if uv is not None:attrs['TEXCOORD_0']=self.acc(uv,'VEC2')
  if colors is not None:attrs['COLOR_0']=self.acc(colors,'VEC3')
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
  for key in ['images','textures','extensionsUsed']:
   if not self.doc.get(key):self.doc.pop(key,None)
  if not self.doc.get('textures'):self.doc.pop('samplers',None)
  self.doc['buffers']=[{'byteLength':len(self.bin)}]
  j=json.dumps(self.doc,separators=(',',':'),ensure_ascii=False).encode();j+=b' '*((-len(j))%4)
  b=bytes(self.bin);b+=b'\0'*((-len(b))%4)
  path.write_bytes(struct.pack('<III',0x46546c67,2,12+8+len(j)+8+len(b))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(b),0x004e4942)+b)
