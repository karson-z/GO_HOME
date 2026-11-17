import fs from 'node:fs';
import path from 'node:path';
globalThis.location={search:'?route=main',pathname:'/'};
const root=path.resolve(import.meta.dirname,'..');
const c=(await import('./.reference_runtime/Da-Ct4tY.js')).__port;
const read=id=>JSON.parse(fs.readFileSync(path.join(root,`go_home_mobile/assets/world/${id}.json`)));
const manifest=read('manifest');
const cases=[];
for(const meta of [...manifest,{id:'_global',x0:0,x1:840}]){
  const data=read(meta.id);
  const walk=(n,parent)=>{
    const matrix=new c.ue().multiplyMatrices(parent,new c.ue().fromArray(n.matrix));
    if(n.instances&&n.culled&&n.count>0&&(n.layers&1)){
      const sphere={center:new c.H(...n.boundingSphere.center),radius:n.boundingSphere.radius};
      const geometrySphere=data.geometries[n.geometry].boundingSphere;
      for(const x of [meta.x0,(meta.x0+meta.x1)/2,meta.x1]){
        const camera=new c.Ce(28,16/9,.5,2000);
        camera.position.set(x,8.9,16.4);camera.lookAt(x+2.2,7.9,0);camera.updateMatrixWorld(true);
        const pv=new c.ue().multiplyMatrices(camera.projectionMatrix,camera.matrixWorldInverse);
        const frustum=new c.r().setFromProjectionMatrix(pv);
        const visible=frustum.intersectsObject({matrixWorld:matrix,boundingSphere:sphere});
        const baseVisible=frustum.intersectsObject({matrixWorld:matrix,boundingSphere:{center:new c.H(...geometrySphere.center),radius:geometrySphere.radius}});
        cases.push({scene:meta.id,name:n.name,matrix:matrix.toArray(),sphere:n.boundingSphere,projectionView:pv.toArray(),visible,baseVisible});
      }
    }
    for(const child of n.children)walk(child,matrix);
  };
  for(const n of data.nodes)walk(n,new c.ue());
}
const defs=c.bV.map(d=>({id:d.segId,blend:d.blend??12,blendIn:d.blendIn??d.blend??12}));
const output={cases,defs};
fs.writeFileSync(path.join(root,'go_home_mobile/test/fixtures/original_scene_culling.json'),JSON.stringify(output));
console.log(`Source Three.js: ${cases.length} frustum cases; ${cases.filter(r=>r.visible&&!r.baseVisible).length} visible batches incorrectly rejected by base-geometry culling.`);
