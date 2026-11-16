import fs from 'node:fs';
import {createCanvas,GlobalFonts,Path2D} from '@napi-rs/canvas';
globalThis.Path2D=Path2D;
globalThis.location={search:'?route=main',pathname:'/'};
globalThis.document={createElement:()=>createCanvas(1,1)};
GlobalFonts.registerFromPath('go_home_mobile/assets/fonts/gaegu.ttf','TGJ Gaegu');
GlobalFonts.registerFromPath('go_home_mobile/assets/fonts/wenkai.ttf','TGJ Xiaolai');
const c=(await import('./.reference_runtime/BiOZAGIX.js')).__port;
const out='go_home_mobile/assets/hints'; fs.mkdirSync(out,{recursive:true});
const data={textures:{},constants:{comb:c.$g,firefly:c.sm,motes:c.vp,move:{delay:.15,fadeIn:.7,fadeOut:1.2,awayK:.5,above:1.45},jump:{lead:3.5,above:2.25,pass:.4}},source:'BiOZAGIX.js xu, Od, w_, Ip, pm; uwcej6eE.js Nr/Dr'};
function save(name,t,w=1,h=1){
 const texture=t?.tex??t;
 if(!texture?.image?.toBuffer)throw Error('Missing original hint canvas: '+name);
 fs.writeFileSync(`${out}/${name}.png`,texture.image.toBuffer('image/png'));
 data.textures[name]={w:t?.w??w,h:t?.h??h};
}
const slash={slash:true};
const items=[{label:'A'},{label:'D'},slash,{arrow:'left'},{arrow:'right'}];
for (const [name,opts] of Object.entries({move:{items,seed:41},jump:{items:[{label:'Space',w:1/.36},slash,{arrow:'up'}],seed:23},talk:{items:[{label:'J'}],seed:31}})) {
 save(name,c.pu(opts.items,'hand',opts.seed));
}
// Exact original keyghost replacement textures, including holes in unlit keys.
for(const [name,selected] of Object.entries({move_left:[0,3],move_right:[1,4]})) {
 const group=new c.x();const cap=new c.xu(group,{items,seed:41,look:'hand',lightable:true});
 cap.light(selected);cap.show(true);cap.update(1,null);
 const canvas=createCanvas(cap.s.material.map.image.width,cap.s.material.map.image.height);
 const ctx=canvas.getContext('2d');ctx.drawImage(cap.s.material.map.image,0,0);
 for(const lit of cap.lits.filter(l=>l.a>0)) {
  const tex=lit.s.material.map,im=tex.image;
  const sx=tex.offset.x*im.width,sh=tex.repeat.y*im.height,sw=tex.repeat.x*im.width,sy=im.height-(tex.offset.y*im.height+sh);
  const px=canvas.width/cap.w;
  ctx.drawImage(im,sx,sy,sw,sh,(cap.w/2+lit.cx-lit.s.scale.x/2)*px,(cap.h/2-lit.cy-lit.s.scale.y/2+.03)*px,lit.s.scale.x*px,lit.s.scale.y*px);
 }
 save(name,{image:canvas},cap.w,cap.h);cap.dispose();
}
save('ear',c.Ed());save('one',c.__(1),.5,.62);
for(let d=1;d<=7;d++) {save(`tag-${d}`,c.v_(d),.5,.62);save(`ring-${d}`,c.fm(d),.5,.5);save(`num-${d}`,c.l_(d),.16,.18);save(`tooth-${d}`,c.d_(d));}
save('lid-right',c.u_());save('lid-left',c.u_(true));save('beam',c.c_(false));save('spark',c.p_());
for(const [name,fn] of Object.entries({mote:c.Ap,tail:c.Np,pad:c.kp,echo:c.Mp,haze:c.Pp,teachRing:c.em,teachSpark:c.Qp,teachTail:c.nm}))save(name,fn());
save('five-lid',c.RC());save('five-box',c.zC());save('five-digit',c.BC(false));save('five-lit',c.BC(true));save('five-spark',c.HC());save('wood-pip',c.Uw());
fs.writeFileSync(`${out}/original_hints.json`,JSON.stringify(data));
console.log(`Exported ${Object.keys(data.textures).length} original hint textures`);
