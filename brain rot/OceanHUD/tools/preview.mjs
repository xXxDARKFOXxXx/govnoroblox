// Offline projection of the actual GUI tree + block geometry exported by check.luau.
// The preview is not a Studio screenshot. No external image assets are used by the HUD.
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
const require = createRequire('C:/Users/frumpers/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/');
const sharp = require('sharp');
const root = path.resolve(import.meta.dirname, '..');
const tree = JSON.parse(fs.readFileSync(path.join(root, 'tools/preview-tree.json'), 'utf8'));
function normalize(object) { object.children = Array.isArray(object.children) ? object.children : []; object.children.forEach(normalize); }
normalize(tree);
const rgb = c => `rgb(${c.map(v => Math.round(v)).join(',')})`;
const esc = s => String(s).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
let id = 0;
const norm = a => {const d = Math.hypot(...a); return a.map(v => v / d);};
const dot = (a,b) => a.reduce((s,v,i) => s+v*b[i],0);
const sub = (a,b) => a.map((v,i) => v-b[i]);
const cross = (a,b) => [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const transform = (cf,v) => [0,1,2].map(i => cf[i] + cf[3+i*3]*v[0] + cf[4+i*3]*v[1] + cf[5+i*3]*v[2]);
function icon(viewport, x, y, w, h) {
  const cam = viewport.children.find(c=>c.class==='Camera');
  const model = viewport.children.find(c=>c.class==='Model');
  const camPos = cam.cf.slice(0,3);
  const right = [cam.cf[3],cam.cf[6],cam.cf[9]], up=[cam.cf[4],cam.cf[7],cam.cf[10]], back=[cam.cf[5],cam.cf[8],cam.cf[11]];
  const f = h / (2*Math.tan(cam.fov*Math.PI/360));
  const project = p => {const rel = sub(p,camPos), d=-dot(rel,back);return [x+w/2+f*dot(rel,right)/d,y+h/2-f*dot(rel,up)/d,d];};
  const corners=[[-.5,-.5,-.5],[.5,-.5,-.5],[.5,.5,-.5],[-.5,.5,-.5],[-.5,-.5,.5],[.5,-.5,.5],[.5,.5,.5],[-.5,.5,.5]];
  const faces=[[0,3,2,1],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]];
  const polygons=[];
  for (const part of model.children.filter(c=>c.class==='Part')) {
    const world=corners.map(v=>transform(part.cf,v.map((n,i)=>n*part.size3[i])));
    for(const face of faces) {
      const pts=face.map(i=>world[i]);
      const normal=norm(cross(sub(pts[1],pts[0]),sub(pts[2],pts[0])));
      const centre=[0,1,2].map(i=>pts.reduce((s,p)=>s+p[i],0)/4);
      if(dot(normal,sub(camPos,centre))<=0) continue;
      const shade=.62+.38*Math.max(0,dot(normal,norm([1,2,4])));
      const p=pts.map(project);
      polygons.push({depth:p.reduce((s,v)=>s+v[2],0)/4,points:p.map(v=>v.slice(0,2).map(n=>n.toFixed(3)).join(',')).join(' '),color:rgb(part.color.map(v=>v*shade))});
    }
  }
  polygons.sort((a,b)=>b.depth-a.depth);
  return polygons.map(p=>`<polygon points="${p.points}" fill="${p.color}" stroke="${p.color}" stroke-width="0.35"/>`).join('');
}
function render(object, bounds, inheritedScale=1) {
  if(object.visible===false) return '';
  if(!object.size) return object.children.map(c=>render(c,bounds,inheritedScale)).join('');
  const ownScale=object.children.find(c=>c.class==='UIScale')?.scale??1;
  const s=inheritedScale*ownScale;
  const w=(object.size[0]*bounds.w+object.size[1]*inheritedScale)*ownScale;
  const h=(object.size[2]*bounds.h+object.size[3]*inheritedScale)*ownScale;
  const x=bounds.x+object.pos[0]*bounds.w+object.pos[1]*inheritedScale-object.anchor[0]*w;
  const y=bounds.y+object.pos[2]*bounds.h+object.pos[3]*inheritedScale-object.anchor[1]*h;
  if(w<=0||h<=0)return '';
  const radius=(object.children.find(c=>c.class==='UICorner')?.radius??0)*s;
  const outline=object.children.find(c=>c.class==='UIStroke');
  const grad=object.children.find(c=>c.class==='UIGradient');
  let body='';
  if(object.alpha>0) {
    let fill=rgb(object.bg);
    if(grad){const gid=`g${++id}`;body+=`<defs><linearGradient id="${gid}" x2="0" y2="1"><stop stop-color="${rgb(grad.from)}"/><stop offset="1" stop-color="${rgb(grad.to)}"/></linearGradient></defs>`;fill=`url(#${gid})`;}
    body+=`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${radius}" fill="${fill}" fill-opacity="${object.alpha}"/>`;
  }
  if(outline&&object.class!=='TextLabel')body+=`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${radius}" fill="none" stroke="${rgb(outline.color)}" stroke-opacity="${outline.alpha}" stroke-width="${outline.thickness*s}"/>`;
  if(object.class==='ViewportFrame') body+=icon(object,x,y,w,h);
  if(object.text) {
    const anchor=object.align==='Left'?'start':object.align==='Right'?'end':'middle';
    const tx=object.align==='Left'?x:object.align==='Right'?x+w:x+w/2;
    body+=`<text x="${tx}" y="${y+h/2}" text-anchor="${anchor}" dominant-baseline="central" font-family="Arial, sans-serif" font-weight="900" font-size="${object.fontSize*s}" fill="${rgb(object.textColor)}" stroke="#071824" stroke-width="${(outline?.thickness??1.6)*s*2}" stroke-linejoin="round" paint-order="stroke">${esc(object.text)}</text>`;
  }
  const childBody=object.children.filter(c=>c.size).sort((a,b)=>(a.z??1)-(b.z??1)).map(c=>render(c,{x,y,w,h},s)).join('');
  if(object.clip){const cid=`c${++id}`;body+=`<defs><clipPath id="${cid}"><rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${radius}"/></clipPath></defs><g clip-path="url(#${cid})">${childBody}</g>`;}
  else body+=childBody;
  return body;
}
const svgWrap=(body,w,h)=>`<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`;
const hud=render(tree,{x:0,y:0,w:1440,h:840});
const map=fs.readFileSync(path.resolve(root,'../OceanMap/previews/spawn-v4.png')).toString('base64');
const scene=`<image width="1440" height="840" preserveAspectRatio="xMidYMid slice" xlink:href="data:image/png;base64,${map}"/><rect width="1440" height="840" fill="#06313a" fill-opacity=".12"/>`;
const note=`<text x="1418" y="28" text-anchor="end" font-family="Arial" font-size="13" font-weight="700" fill="#e4ffff">ПРЕВЬЮ КОМПОНОВКИ · НЕ СКРИНШОТ STUDIO</text>`;
await sharp(Buffer.from(svgWrap(scene+hud+note,1440,840))).png().toFile(path.join(root,'OceanHUD-preview.png'));
await sharp(Buffer.from(svgWrap(hud,1440,840))).png().toFile(path.join(root,'OceanHUD-transparent-preview.png'));
const nav=tree.children.find(c=>c.name==='SafeArea').children.find(c=>c.name==='Navigation');
const counterTree=tree.children.find(c=>c.name==='SafeArea').children.find(c=>c.name==='Counters');
const icons=[];
for(const slot of nav.children.filter(c=>c.name.endsWith('Slot'))){const button=slot.children.find(c=>c.class==='TextButton');icons.push([button.children.find(c=>c.class==='ViewportFrame'),button.children.find(c=>c.name==='Caption').text]);}
for(const counter of counterTree.children.filter(c=>c.name.endsWith('Counter')))icons.push([counter.children.find(c=>c.class==='ViewportFrame'),counter.children.find(c=>c.name==='Caption').text]);
let sheet='<rect width="1320" height="300" rx="24" fill="#0e3141"/>';
for(let i=0;i<icons.length;i++){
  sheet+=icon(icons[i][0],i*220+15,10,190,220);
  sheet+=`<text x="${i*220+110}" y="267" text-anchor="middle" font-family="Arial" font-weight="900" font-size="${i===0?19:23}" fill="#f1feff">${esc(icons[i][1])}</text>`;
}
await sharp(Buffer.from(svgWrap(sheet,1320,300))).png().toFile(path.join(root,'OceanHUD-icons.png'));
console.log('Rendered preview from the client-created UI and its actual block geometry.');
