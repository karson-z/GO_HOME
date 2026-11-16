// Offline-only: Dart GLTFLoader does not provide a native meshopt decoder.
// Expand the source buffer views once, preserving quantized accessors and nodes.
import fs from 'node:fs';
import path from 'node:path';
import { MeshoptDecoder } from 'meshoptimizer';
await MeshoptDecoder.ready;
const root = path.resolve(import.meta.dirname, '../go_home_mobile/assets/models');
let count = 0;
for (const filename of fs.readdirSync(root)) {
  if (!filename.endsWith('.glb')) continue;
  const file = path.join(root,filename), input = fs.readFileSync(file);
  const jsonLength=input.readUInt32LE(12);
  const json=JSON.parse(input.subarray(20,20+jsonLength).toString());
  if (!json.extensionsUsed?.includes('EXT_meshopt_compression')) continue;
  const binary=input.subarray(28+jsonLength);
  let cursor=0, chunks=[];
  for (const view of json.bufferViews) {
    const ext=view.extensions?.EXT_meshopt_compression;
    let out;
    if (ext) {
      out=new Uint8Array(ext.count*ext.byteStride);
      MeshoptDecoder.decodeGltfBuffer(out,ext.count,ext.byteStride,binary.subarray(ext.byteOffset||0,(ext.byteOffset||0)+ext.byteLength),ext.mode,ext.filter);
      delete view.extensions.EXT_meshopt_compression;
      if (Object.keys(view.extensions).length===0) delete view.extensions;
    } else out=binary.subarray(view.byteOffset||0,(view.byteOffset||0)+view.byteLength);
    view.buffer=0;view.byteOffset=cursor;view.byteLength=out.length;
    chunks.push(Buffer.from(out));cursor+=out.length;
    const pad=(4-cursor%4)%4;if(pad){chunks.push(Buffer.alloc(pad));cursor+=pad;}
  }
  json.buffers=[{byteLength:cursor}];
  for (const key of ['extensionsUsed','extensionsRequired']) {
    if(json[key]) json[key]=json[key].filter(x=>x!=='EXT_meshopt_compression');
  }
  let jsonBytes=Buffer.from(JSON.stringify(json));
  jsonBytes=Buffer.concat([jsonBytes,Buffer.alloc((4-jsonBytes.length%4)%4,32)]);
  const bin=Buffer.concat(chunks), header=Buffer.alloc(20), binHeader=Buffer.alloc(8);
  header.writeUInt32LE(0x46546c67,0);header.writeUInt32LE(2,4);header.writeUInt32LE(28+jsonBytes.length+bin.length,8);
  header.writeUInt32LE(jsonBytes.length,12);header.writeUInt32LE(0x4e4f534a,16);
  binHeader.writeUInt32LE(bin.length,0);binHeader.writeUInt32LE(0x004e4942,4);
  fs.writeFileSync(file,Buffer.concat([header,jsonBytes,binHeader,bin]));count++;
}
console.log(`Expanded ${count} GLB files for native loading.`);
