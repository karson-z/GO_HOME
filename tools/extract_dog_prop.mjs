import fs from 'node:fs';
globalThis.location={search:'?route=main',pathname:'/'};
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const l=(await import('./.reference_runtime/Da-Ct4tY.js')).__port;
const data=JSON.parse(fs.readFileSync('go_home_mobile/assets/characters/fam-dog.json'));
const rig=new c.Bg(l.jd(data,{colorSpace:''}),c.ug(),{ppm:200});
const prop=rig.wear('bat','neck',{x:-.06,y:-.03,u:.068,tilt:.35});
const geometries=[],materials=[],gs=new Map(),ms=new Map();
function node(o) {
 o.updateMatrix();
 const n={name:o.name,matrix:o.matrix.toArray(),visible:o.visible,order:o.renderOrder,children:o.children.map(node)};
 if(o.geometry) {
  if(!gs.has(o.geometry)) {
   gs.set(o.geometry,geometries.length);
   const g=o.geometry;
   geometries.push({attributes:Object.fromEntries(Object.entries(g.attributes).map(([k,a])=>[k,{size:a.itemSize,values:Array.from(a.array)}])),index:g.index?Array.from(g.index.array):null});
  }
  n.geometry=gs.get(o.geometry);
 }
 if(o.material) {
  const m=o.material;
  if(!ms.has(m)) {
   ms.set(m,materials.length);
   materials.push({vertex:m.vertexShader,fragment:m.fragmentShader,
    uniforms:Object.fromEntries(Object.entries(m.uniforms).map(([k,u])=>[k,u.value?.isColor?{color:u.value.toArray()}:u.value])),
    depthTest:m.depthTest,depthWrite:m.depthWrite,side:m.side,transparent:m.transparent});
  }
  n.material=ms.get(m);
 }
 return n;
}
const root=node(prop);
fs.writeFileSync('go_home_mobile/assets/characters/fam-dog-prop.json',JSON.stringify({anchor:'neck',geometries,materials,root}));
rig.dispose();
console.log(`Exported original mounted dog bat: ${geometries.length} meshes, ${materials.length} source prop shader materials`);
