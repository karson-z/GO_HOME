// Native binary scene format. Preserves source geometry, instance attributes,
// matrices, shaders and linear colour values; contains no executable JavaScript.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {createCanvas,ImageData} from '@napi-rs/canvas';
export class NativeSceneWriter {
 constructor(root,shared={}){this.shared=shared;this.root=root;this.output=path.join(root,'go_home_mobile/assets/world');fs.mkdirSync(this.output,{recursive:true});fs.mkdirSync(path.join(this.output,'textures'),{recursive:true});this.textures={};this.textureIds=new Map();this.shaders={};}
 hash(value){return crypto.createHash('sha256').update(value).digest('hex').slice(0,20);}
 shader(source){if(!source)return null;const id=this.hash(source);this.shaders[id]=source;return id;}
 texture(tex){
  if(this.textureIds.has(tex))return this.textureIds.get(tex);
  let bytes,extension='png';
  if(tex.userData?.sourceFile){const original=path.join(this.root,'source/extracted/game',tex.userData.sourceFile);if(fs.existsSync(original)){bytes=fs.readFileSync(original);extension=path.extname(original).slice(1);}}
  const image=tex.image;
  if(!bytes&&image?.toBuffer)bytes=image.toBuffer('image/png');
  if(!bytes&&image?.data&&image.width&&image.height){
   const raw=image.data;
   // Keep float/half-float data textures as typed bytes, without PNG quantization.
   const typed=Buffer.from(raw.buffer,raw.byteOffset,raw.byteLength);
   const id=this.hash(Buffer.concat([Buffer.from(`${image.width},${image.height},${tex.format},${tex.type}`),typed]));
   fs.writeFileSync(path.join(this.output,'textures',id+'.bin'),typed);
   this.textures[id]={file:`textures/${id}.bin`,raw:true,width:image.width,height:image.height,format:tex.format,type:tex.type,flipY:tex.flipY,wrapS:tex.wrapS,wrapT:tex.wrapT,minFilter:tex.minFilter,magFilter:tex.magFilter,colorSpace:tex.colorSpace};
   this.textureIds.set(tex,id);return id;
  }
  if(!bytes){this.textureIds.set(tex,null);return null;}
  const id=this.hash(bytes);fs.writeFileSync(path.join(this.output,'textures',id+'.'+extension),bytes);
  this.textures[id]={file:`textures/${id}.${extension}`,flipY:tex.flipY,wrapS:tex.wrapS,wrapT:tex.wrapT,minFilter:tex.minFilter,magFilter:tex.magFilter,colorSpace:tex.colorSpace,premultiplyAlpha:tex.premultiplyAlpha};
  this.textureIds.set(tex,id);return id;
 }
 uniform(value){
  if(value==null||typeof value==='number'||typeof value==='boolean'||typeof value==='string')return value;
  if(value.isTexture)return {texture:this.texture(value)};
  if(value.isColor)return {color:[value.r,value.g,value.b]};
  if(value.isVector2||value.isVector3||value.isVector4)return {vector:value.toArray()};
  if(value.isMatrix3||value.isMatrix4)return {matrix:value.toArray()};
  if(Array.isArray(value)||ArrayBuffer.isView(value))return Array.from(value,v=>this.uniform(v));
  return null;
 }
 write(id,roots,extra={}){
  const buffers=[],geometries={},materials={},geometryIds=new Map(),materialIds=new Map();let offset=0;
  const append=typed=>{const data=Buffer.from(typed.buffer,typed.byteOffset,typed.byteLength);const result={offset,length:typed.length};buffers.push(data);offset+=data.byteLength;return result;};
  const attr=(a,index=false)=>{
   const array=index?Uint32Array.from(a.array):new Float32Array(a.count*a.itemSize);
   if(!index)for(let i=0;i<a.count;i++)for(let c=0;c<a.itemSize;c++)array[i*a.itemSize+c]=a.getComponent(i,c);
   return {...append(array),size:a.itemSize,integer:index,instanced:!!a.isInstancedBufferAttribute,meshPerAttribute:a.meshPerAttribute??1};
  };
  const geometry=g=>{
   if(geometryIds.has(g))return geometryIds.get(g);
   const gid=`g${geometryIds.size}`;geometryIds.set(g,gid);
   geometries[gid]={attributes:Object.fromEntries(Object.entries(g.attributes).map(([k,v])=>[k,attr(v)])),index:g.index?attr(g.index,true):null,groups:g.groups,drawRange:{start:g.drawRange.start,count:Number.isFinite(g.drawRange.count)?g.drawRange.count:null},instanced:!!g.isInstancedBufferGeometry,instanceCount:Number.isFinite(g.instanceCount)?g.instanceCount:null};return gid;
  };
  const material=m=>{
   if(materialIds.has(m))return materialIds.get(m);
   const mid=`m${materialIds.size}`;materialIds.set(m,mid);
   const data={type:m.type,name:m.name};
   for(const key of ['fog','lights','sizeAttenuation','rotation','side','transparent','depthWrite','depthTest','blending','blendSrc','blendDst','blendEquation','blendSrcAlpha','blendDstAlpha','blendEquationAlpha','alphaTest','opacity','premultipliedAlpha','toneMapped','colorWrite','vertexColors','wireframe','polygonOffset','polygonOffsetFactor','polygonOffsetUnits'])if(m[key]!==undefined)data[key]=m[key];
   if(m.vertexShader){data.vertex=this.shader(m.vertexShader);data.fragment=this.shader(m.fragmentShader);data.defines=m.defines;data.uniforms=Object.fromEntries(Object.entries(m.uniforms).map(([k,v])=>[k,this.uniform(v.value)]));data.sharedBindings=Object.fromEntries(Object.entries(m.uniforms).flatMap(([k,v])=>{const found=Object.entries(this.shared).find(([key,ref])=>ref===v);return found?[[k,found[0]]]:[]}));}
   else {data.color=this.uniform(m.color);data.map=m.map?this.texture(m.map):null;data.alphaMap=m.alphaMap?this.texture(m.alphaMap):null;}
   materials[mid]=data;return mid;
  };
  const node=o=>{
   if(o.matrixAutoUpdate)o.updateMatrix();
   const out={type:o.type,name:o.name,visible:o.visible,matrix:o.matrix.toArray(),order:o.renderOrder,culled:o.frustumCulled,userData:{...(o.userData.spec?{spec:o.userData.spec}:{}),...(o.userData.farVisibility?{farVisibility:o.userData.farVisibility}:{})}};
   if(o.geometry)out.geometry=geometry(o.geometry);
   if(o.material)out.material=Array.isArray(o.material)?o.material.map(material):material(o.material);
   if(o.instanceMatrix){out.instances=attr(o.instanceMatrix);out.count=o.count;if(o.instanceColor)out.instanceColor=attr(o.instanceColor);}
   out.children=o.children.map(node);return out;
  };
  const nodes=roots.map(node);
  const result={version:2,...extra,geometries,materials,nodes};
  fs.writeFileSync(path.join(this.output,id+'.json'),JSON.stringify(result));
  fs.writeFileSync(path.join(this.output,id+'.bin'),Buffer.concat(buffers));
  return {id,bytes:offset,nodes:geometryIds.size,materials:materialIds.size};
 }
 finish(){fs.writeFileSync(path.join(this.output,'resources.json'),JSON.stringify({textures:this.textures,shaders:this.shaders}));}
}
