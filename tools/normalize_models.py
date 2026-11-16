"""Expand quantized/interleaved GLB accessors to contiguous Float32 attributes.
This avoids three_js 0.3.0 normalized accessor bounds/interleaving bugs.
Node transforms and mesh topology are preserved. Run after decompress_models.mjs.
"""
from pathlib import Path
import struct,json,hashlib
import numpy as np
root=Path(__file__).resolve().parents[1]/'go_home_mobile/assets'
types={5120:('i1',1),5121:('u1',1),5122:('<i2',2),5123:('<u2',2),5125:('<u4',4),5126:('<f4',4)}
sizes={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT2':4,'MAT3':9,'MAT4':16}
for p in (root/'models').glob('*.glb'):
    data=p.read_bytes();n=struct.unpack_from('<I',data,12)[0];j=json.loads(data[20:20+n]);binary=data[n+28:]
    views=[];chunks=[];cursor=0
    index_accessors={prim['indices'] for mesh in j.get('meshes',[]) for prim in mesh['primitives'] if 'indices' in prim}
    for i,a in enumerate(j['accessors']):
        if 'sparse' in a:raise ValueError(f'Sparse accessor {p}')
        count=a['count'];components=sizes[a['type']];dt,bytes_=types[a['componentType']]
        if 'bufferView' not in a:arr=np.zeros((count,components),dtype=dt)
        else:
            v=j['bufferViews'][a['bufferView']];offset=v.get('byteOffset',0)+a.get('byteOffset',0)
            stride=v.get('byteStride',components*bytes_)
            arr=np.ndarray((count,components),dtype=dt,buffer=binary,offset=offset,strides=(stride,bytes_)).copy()
        if i in index_accessors:
            arr=arr.astype('<u4');a['componentType']=5125
        else:
            arr=arr.astype('<f4')
            if a.get('normalized'):
                info=np.iinfo(np.dtype(dt));arr=np.maximum(arr/info.max,-1).astype('<f4')
            a['componentType']=5126
        if 'min' in a:a['min']=arr.min(axis=0).tolist()
        if 'max' in a:a['max']=arr.max(axis=0).tolist()
        a.pop('normalized',None);a['bufferView']=len(views);a['byteOffset']=0
        b=arr.tobytes();views.append(dict(buffer=0,byteOffset=cursor,byteLength=len(b),target=34963 if i in index_accessors else 34962));chunks.append(b);cursor+=len(b)
        pad=(-cursor)%4;chunks.append(b'\0'*pad);cursor+=pad
    j['bufferViews']=views;j['buffers']=[dict(byteLength=cursor)]
    for key in ['extensionsUsed','extensionsRequired']:
        if key in j:j[key]=[e for e in j[key] if e!='KHR_mesh_quantization']
    s=json.dumps(j,separators=(',',':')).encode();s+=b' '*((-len(s))%4);b=b''.join(chunks)
    p.write_bytes(struct.pack('<IIIII',0x46546c67,2,28+len(s)+len(b),len(s),0x4e4f534a)+s+struct.pack('<II',len(b),0x004e4942)+b)
manifest=[dict(path=str(p.relative_to(root)),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in sorted(root.rglob('*')) if p.is_file() and p.name!='asset_manifest.json']
(root/'data/asset_manifest.json').write_text(json.dumps(manifest,indent=2))
print('Normalized',len(list((root/'models').glob('*.glb'))),'native models')
