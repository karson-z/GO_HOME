// Offline extraction of the supplied distribution. Never shipped as game code.
import fs from 'node:fs';
import path from 'node:path';
import {parse} from 'acorn';
const root=path.resolve(import.meta.dirname,'..');
const source=path.join(root,'source/readable');
const cache=path.join(root,'tools/.reference_runtime');
fs.mkdirSync(cache,{recursive:true});
fs.writeFileSync(path.join(cache,'package.json'),'{"type":"module"}');
for(const filename of fs.readdirSync(source).filter(n=>n.endsWith('.js'))){
 const code=fs.readFileSync(path.join(source,filename),'utf8');
 const ast=parse(code,{ecmaVersion:'latest',sourceType:'module'});
 const names=[];
 for(const n of ast.body){
  if(n.type==='ImportDeclaration') for(const s of n.specifiers) names.push(s.local.name);
  if(n.type==='VariableDeclaration')for(const d of n.declarations)if(d.id.type==='Identifier')names.push(d.id.name);
  if((n.type==='FunctionDeclaration'||n.type==='ClassDeclaration')&&n.id)names.push(n.id.name);
 }
 fs.writeFileSync(path.join(cache,filename),code+'\nexport const __port = {'+names.join(',')+'};\n');
}
globalThis.location={search:'?route=main',pathname:'/'};
const route=await import(path.join(cache,'uwcej6eE.js'));
const core=(await import(path.join(cache,'BiOZAGIX.js'))).__port;
const look=(await import(path.join(cache,'Da-Ct4tY.js'))).__port;
const physics=(await import(path.join(cache,'2-dEIWs8.js'))).__port;
const result=route.buildRouteLevel({},null);
const data=path.join(root,'go_home_mobile/assets/data');
fs.writeFileSync(path.join(data,'original_route.json'),JSON.stringify(result,(k,v)=>typeof v==='function'?undefined:v));
const strings={};
for(const [module,values] of Object.entries({core,look}))for(const [name,value] of Object.entries(values)){
 if(typeof value==='string'&&(value.includes('void main')||value.includes('uniform ')||value.includes('vec3 '))) strings[module+'_'+name]=value;
}
fs.writeFileSync(path.join(data,'original_shaders.json'),JSON.stringify(strings));
const plain = value => value!==null&&typeof value==='object'&&(Array.isArray(value)||Object.getPrototypeOf(value)===Object.prototype);
const configs={};
for(const [module,values] of Object.entries({core,look,physics,route:route.__port}))for(const [name,value] of Object.entries(values)){
 if(!plain(value))continue;
 try{
  const json=JSON.stringify(value,(k,v)=>typeof v==='function'?undefined:v);
  if(json.length<500000&&!json.includes('"metadata"')&&!json.includes('"isVector')) configs[module+'_'+name]=JSON.parse(json);
 }catch{}
}
fs.writeFileSync(path.join(data,'original_config.json'),JSON.stringify(configs));
fs.writeFileSync(path.join(root,'tools/reference_symbols.json'),JSON.stringify(Object.fromEntries(Object.entries({core,look,physics,route:route.__port}).map(([m,obj])=>[m,Object.entries(obj).map(([n,v])=>({name:n,type:typeof v,length:typeof v==='string'?v.length:undefined,keys:plain(v)?Object.keys(v).slice(0,30):undefined}))])),null,2));
console.log('Extracted',result.layout.items.length,'route items,',result.layout.terrain.length,'colliders,',Object.keys(strings).length,'shader sources,',Object.keys(configs).length,'configurations.');
