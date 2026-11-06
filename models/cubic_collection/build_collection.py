"""Blender 4.3+: blender -b -t 6 --python build_collection.py -- OUTPUT [--no-render]
Replaces the scene; use a fresh Blender process. No external assets/add-ons.
All exported surfaces are flat-shaded orthogonal cuboids. No lids or bevels.
"""
import bpy, os, sys, json, math, random
import numpy as np
from mathutils import Vector
from pathlib import Path

args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
OUT=Path(args[0]) if args else Path(__file__).resolve().parent
OUT.mkdir(parents=True,exist_ok=True)
RENDER='--no-render' not in args
ONLY=next((set(a.split('=',1)[1].split(',')) for a in args if a.startswith('--only=')),None)
VARIANTS=[('01_Toilet','Toilet','PORCELAIN'),('02_Crab','Crab','CRIMSON'),('03_Shark','Shark','TIDAL'),
 ('04_Frog','Frog','MOSS'),('05_Mystic','Mystic','ABYSS'),('06_Paradise','Paradise','AUREOLE'),
 ('07_Pumpkin','Pumpkin','EMBER'),('08_Pizza','Pizza','EXTRA CHEESE'),('09_Chicken','Chicken','SUNNY'),('10_Glitch','Glitch','ERROR 404')]
# Four pixel-textured values of each palette color, 64 tiles total.
COLORS={'white':(244,244,225),'ivory':(232,211,161),'ink':(20,25,40),'slate':(48,63,87),
 'gold':(255,195,27),'orange':(239,104,20),'red':(214,49,45),'maroon':(120,26,43),
 'aqua':(40,218,225),'blue':(47,122,196),'green':(97,190,54),'moss':(48,103,49),
 'purple':(80,41,121),'violet':(188,95,247),'pink':(251,73,159),'brown':(138,84,48)}
KEYS=list(COLORS); T={k:i*4 for i,k in enumerate(KEYS)}
atlas_path=OUT/'Voxel_Atlas.png'
rng=np.random.default_rng(3001)
pix=np.ones((1024,1024,4),np.float32)
for key,base in COLORS.items():
 for shade in range(4):
  tile=T[key]+shade; x=tile%8*128; y=tile//8*128
  mosaic=rng.choice([-.055,-.025,0,.025,.045],size=(16,16,1),p=[.08,.14,.55,.16,.07])
  mosaic=np.repeat(np.repeat(mosaic,8,axis=0),8,axis=1)
  color=np.array(base)/255*(1-shade*.085)
  cell=np.clip(color+mosaic,0,1)
  # Sparse squared flecks; no filtered noise, gradients or smooth textures.
  cell[24:32,40:64]=np.clip(color+.065,0,1)
  cell[88:96,88:104]=np.clip(color-.075,0,1)
  pix[y:y+128,x:x+128,:3]=cell
im=bpy.data.images.new('Voxel_Atlas',width=1024,height=1024)
im.pixels.foreach_set(pix.ravel()); im.filepath_raw=str(atlas_path); im.file_format='PNG'; im.save()
# Optional uploaded particle mask. Runtime has geometric pixel FX without uploads.
mask=bpy.data.images.new('Pixel_Particle',width=16,height=16,alpha=True)
mp=np.ones((16,16,4),np.float32); mp[:,:,3]=0; mp[3:13,3:13,3]=1
mask.pixels.foreach_set(mp.ravel()); mask.filepath_raw=str(OUT/'Pixel_Particle.png'); mask.file_format='PNG'; mask.save()

FONT={'?':['01110','11011','00011','00110','00100','00000','00100'],
 'P':['1110','1001','1110','1000','1000'],'I':['111','010','010','010','111'],
 'Z':['1111','0001','0010','0100','1111'],'A':['0110','1001','1111','1001','1001']}
FACES=[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(4,0,3,7)]

def init(slug):
 global G,R,MATS,ATLAS,SLUG
 bpy.ops.wm.read_factory_settings(use_empty=True)
 SLUG=slug; G={}; R=random.Random(193+KEYS.index('gold')+sum(map(ord,slug)))
 ATLAS=bpy.data.images.load(str(atlas_path),check_existing=True); ATLAS.pack()
 MATS=[]
 for glow in (False,True):
  m=bpy.data.materials.new('VoxelGlow' if glow else 'VoxelPlastic'); m.use_nodes=True
  bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Roughness'].default_value=.73
  tex=m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=ATLAS; tex.interpolation='Closest'
  m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
  if glow:
   m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Emission Color']); bs.inputs['Emission Strength'].default_value=1.5
  MATS.append(m)

def box(loc,dims,color,group='Body',shade=0):
 verts,faces,tiles=G.setdefault(group,([],[],[])); start=len(verts)
 x,y,z=loc; dx,dy,dz=[d/2 for d in dims]
 verts.extend([(x-dx,y-dy,z-dz),(x+dx,y-dy,z-dz),(x+dx,y+dy,z-dz),(x-dx,y+dy,z-dz),
               (x-dx,y-dy,z+dz),(x+dx,y-dy,z+dz),(x+dx,y+dy,z+dz),(x-dx,y+dy,z+dz)])
 for f in FACES: faces.append(tuple(start+i for i in f)); tiles.append(T[color]+shade)

def frame(center,width,height,thick,color,group='Body',face='front'):
 x,y,z=center
 for side in (-1,1):
  if face=='front':
   box((x+side*(width-thick)/2,y,z),(thick,.11,height),color,group)
   box((x,y,z+side*(height-thick)/2),(width-2*thick,.11,thick),color,group)
  elif face=='top':
   box((x+side*(width-thick)/2,y,z),(thick,height,.12),color,group)
   box((x,y+side*(height-thick)/2,z),(width-2*thick,thick,.12),color,group)

def glyph(text,center,p=.17,color='white',face='front',outline=True,group='Body'):
 rows=FONT[text]; h=len(rows); w=len(rows[0]); on={(j,h-1-i) for i,row in enumerate(rows) for j,c in enumerate(row) if c=='1'}
 border={(x+dx,z+dz) for x,z in on for dx in (-1,0,1) for dz in (-1,0,1)}
 def pixel(j,k,col,depth):
  a=(j-(w-1)/2)*p; b=(k-(h-1)/2)*p; x,y,z=center
  if face=='front': box((x+a,y-depth,z+b),(p*.98,.08,p*.98),col,group)
  elif face=='side': box((x+depth,y+a,z+b),(.08,p*.98,p*.98),col,group)
  else: box((x+a,y+b,z+depth),(p*.98,p*.98,.08),col,group)
 if outline:
  for j,k in border: pixel(j,k,'ink',0)
 for j,k in on: pixel(j,k,color,.05)

def core(color,edge='ink',sideq=True):
 box((0,0,1.8),(2.6,2.4,2.6),edge)
 # Individual fixed voxel plates on all six surfaces, including the closed top.
 for axis,extent,uaxis,vaxis,uw,vh in [(1,1.21,0,2,2.58,2.58),(0,1.31,1,2,2.38,2.58),(2,1.8+1.31,0,1,2.58,2.38)]:
  for sign in (-1,1):
   if axis==2 and sign==-1: plane=.49
   else: plane=extent*sign if axis!=2 else extent
   for a in range(6):
    for b in range(6):
     pos=[0,0,1.8]; pos[axis]=plane
     pos[uaxis]=(a-2.5)*uw/6; pos[vaxis]=(b-2.5)*vh/6+(1.8 if vaxis==2 else 0)
     dims=[0,0,0]; dims[axis]=.07; dims[uaxis]=uw/6-.013; dims[vaxis]=vh/6-.013
     shade=R.choices([0,1,2],[.72,.24,.04])[0]
     box(pos,dims,color,shade=shade)
 if sideq: glyph('?',(1.37,0,1.8),.18,'gold' if color!='gold' else 'white','side')

def eye(x,z,size=.44,color='white',group='Body',y=-1.31):
 box((x,y,z),(size,.12,size),color,group)
 box((x+.04,y-.085,z-.015),(size*.52,.08,size*.62),'ink',group)
 box((x+.005,y-.135,z+size*.19),(size*.18,.035,size*.18),'white',group)

def feet(color='brown'):
 for s in (-1,1):
  g='LegL' if s<0 else 'LegR'
  box((s*.76,-.1,.43),(.37,.42,.55),color,g)
  for i in (-1,0,1): box((s*.76+i*.18,-.50,.17),(.15,.85,.22),color,g)

def toilet():
 box((0,.05,.40),(2.25,2.1,.6),'ivory')
 box((0,-.05,1.10),(2.55,2.35,1.05),'white')
 for x in (-1.16,1.16): box((x,-.15,1.82),(.36,2.4,.32),'white')
 for y in (-1.17,.87): box((0,y,1.82),(1.96,.36,.32),'white')
 box((0,-.15,1.66),(1.95,1.72,.08),'blue')
 for i in range(10):
  box((R.uniform(-.8,.8),R.uniform(-.8,.5),1.72),(R.uniform(.14,.3),.16,.04),'aqua','Glow')
 box((0,.89,2.75),(2.55,.70,1.95),'white')
 for x in (-.84,0,.84): box((x,.515,2.83),(.80,.04,1.55),'white',shade=1)
 box((.82,.46,3.22),(.4,.12,.24),'slate'); box((.82,.38,3.23),(.23,.06,.12),'aqua','Glow')
 for x in (-.55,.55): eye(x,2.91,.37,y=.47)
 glyph('?',(1.33,-.08,1.09),.105,'blue','side')
 for i in range(3): box((-.57+i*.55,-.2,2.05+i*.14),(.13,.13,.13),'aqua',f'Bubble{i+1:02}')

def crab():
 core('red','maroon')
 for s in (-1,1):
  for i,y in enumerate([-.65,0,.65]):
   g='LegL' if s<0 else 'LegR'
   box((s*1.55,y,.77),(.65,.24,.26),'maroon',g)
   box((s*1.88,y-.1,.49),(.25,.46,.50),'red',g)
   box((s*2.05,y-.25,.24),(.48,.65,.22),'orange',g)
  g='ClawL' if s<0 else 'ClawR'
  box((s*1.48,-.92,1.64),(.65,.38,.35),'maroon',g)
  box((s*1.97,-1.00,2.05),(.67,.52,.68),'red',g)
  box((s*2.18,-1.00,2.60),(.26,.52,.66),'orange',g)
  box((s*1.74,-1.00,2.49),(.25,.52,.45),'red',g)
  box((s*.68,-.6,3.3),(.19,.21,.64),'maroon')
  eye(s*.68,3.61,.47,y=-.75)
 for i in (-1,0,1): box((i*.3,-1.31,1.73),(.25,.10,.14),'ink')

def shark():
 core('blue','slate')
 box((0,-1.29,1.45),(2.1,.13,.95),'white')
 box((0,-1.40,1.54),(1.64,.10,.51),'ink')
 for i in range(6):
  for z in (1.34,1.76): box((-.69+i*.275,-1.47,z),(.17,.07,.22),'white')
 for x in (-.82,.82): eye(x,2.62,.4)
 for s in (-1,1):
  g='FinL' if s<0 else 'FinR'
  for i in range(3): box((s*(1.42+i*.24),.08,2.02-i*.19),(.35,.9-i*.14,.23),'blue',g,shade=i%2)
  for y in (-.64,-.25,.14): box((s*1.38,y,2.43),(.04,.075,.43),'ink')
 for i in range(3): box((0,.30+i*.20,3.2+i*.19),(.22,.64-i*.15,.30),'slate','Dorsal')
 box((0,1.48,1.81),(.45,.55,.43),'blue','Tail')
 for z in (1.29,2.32): box((0,1.85,z),(.30,.39,.68),'slate','Tail')
 for i in range(3): box((.9-i*.32,-.3,3.51+i*.22),(.12,.12,.12),'aqua',f'Bubble{i+1:02}')

def frog():
 core('green','moss')
 for x in (-.74,.74):
  box((x,-.53,3.19),(.90,.88,.79),'green')
  eye(x,3.23,.60,y=-1.005)
 for x,z,w in [(-.69,1.76,.2),(0,1.62,1.2),(.69,1.76,.2)]: box((x,-1.31,z),(w,.08,.18),'ink')
 box((0,-1.39,1.49),(.38,.12,.19),'pink')
 feet('green')
 for s in (-1,1):
  g='LegL' if s<0 else 'LegR'
  box((s*1.45,.66,.65),(.66,.89,.71),'moss',g)
  for i in range(3): box((s*1.35,-.8+i*.48,2.2+i*.22),(.15,.20,.19),'moss')
  box((s*.93,-1.32,2.15),(.30,.055,.14),'pink',shade=1)

def mystic():
 core('purple','ink')
 frame((0,-1.31,2.07),1.92,1.0,.17,'ink')
 box((0,-1.40,2.07),(1.43,.10,.63),'violet','Glow')
 box((0,-1.48,2.07),(.28,.08,.65),'ink')
 box((-.32,-1.49,2.22),(.17,.05,.16),'white','Glow')
 for x,z,si in [(-.82,1.13,.27),(.83,1.30,.31),(0,2.83,.22)]: eye(x,z,si,'pink','Glow')
 for s in (-1,1):
  for i in range(3): box((s*(.82+i*.17),.1,3.1+i*.25),(.28,.45,.37),'ink')
  box((s*1.16,.1,3.83),(.21,.32,.17),'violet','Glow')
  g='ClawL' if s<0 else 'ClawR'
  for i in range(4): box((s*(1.35+i*.18),-.1,.91-i*.18),(.34,.45,.29),'ink',g)
  box((s*1.91,-.33,.35),(.28,.23,.24),'pink','Glow')
 for y in (-.7,0,.7): box((1.40,y,2.76),(.06,.19,.14),'violet','Glow')

def paradise():
 core('white','ivory')
 glyph('?',(0,-1.35,1.85),.22,'gold')
 for s in (-1,1):
  g='WingL' if s<0 else 'WingR'
  for i in range(5):
   box((s*(1.39+i*.28),.32,2.26+i*.27),(.47,.38,1.29-i*.13),'gold',g)
   box((s*(1.40+i*.28),.04,2.27+i*.27),(.35,.25,1.11-i*.13),'white',g)
  for x in (-1.15,1.15): box((x,s*1.03,1.8),(.13,.13,2.55),'gold')
 frame((0,0,3.94),1.64,1.47,.19,'gold','Halo','top')
 frame((0,0,3.88),1.35,1.19,.07,'white','Glow','top')
 for i,(x,y,z) in enumerate([(-1.95,-.1,1.32),(1.90,.55,1.60),(.25,1.52,2.86)]):
  for dx,dy,dz,d in [(-.3,0,0,.46),(0,0,.15,.66),(.4,.03,0,.47),(0,.2,-.18,.45)]:
   box((x+dx,y+dy,z+dz),(d,d*.8,d*.75),'white',f'Cloud{i+1:02}',shade=i%2)

def pumpkin():
 core('orange','brown')
 for x in (-.95,-.49,0,.49,.95): box((x,-1.29,1.85),(.10,.04,2.45),'orange',shade=2)
 # Carved pixel mask; bright inset cubes sit behind hard black eye borders.
 for s in (-1,1):
  box((s*.64,-1.35,2.41),(.70,.09,.53),'ink')
  box((s*.64,-1.42,2.41),(.43,.04,.28),'gold','Glow')
  box((s*.91,-1.34,2.72),(.23,.10,.15),'brown')
 for i in range(7):
  z=1.49+(.19 if i in (0,6) else 0)
  box((-.9+i*.3,-1.35,z),(.30,.10,.43),'ink')
  if i%2: box((-.9+i*.3,-1.42,z+.09),(.17,.04,.18),'gold','Glow')
 box((0,.05,3.33),(.44,.42,.55),'moss')
 box((.26,.05,3.61),(.40,.36,.25),'green')
 box((.61,.04,3.42),(.44,.46,.11),'green')
 feet('brown')

def pizza():
 core('ivory','brown')
 for x in (-1.10,1.10): box((x,-1.29,1.8),(.22,.08,2.53),'red')
 for z in (.66,2.96):
  for i in range(10): box((-1.15+i*.255,-1.34,z),(.25,.08,.18),'red' if i%2 else 'white')
 box((0,-1.31,2.13),(2.15,.11,.88),'red')
 x=-.89
 for char in 'PIZZA':
  width=len(FONT[char][0])*.075
  glyph(char,(x+width/2,-1.39,2.15),.075,'white',outline=False); x+=width+.06
 glyph('?',(0,-1.32,1.11),.12,'gold')
 # Fixed pizza emblem on top: stepped cheese triangle and square pepperoni.
 for row in range(6):
  for col in range(row+1): box(((col-row/2)*.24,-.67+row*.23,3.20),(.24,.23,.10),'gold')
 for x,y in [(-.2,.05),(.21,.37),(0,-.43),(-.39,.43)]: box((x,y,3.27),(.16,.16,.045),'red')
 for x in (-1.17,1.17): box((x,.13,1.18),(.12,1.74,.11),'brown')
 feet('red')

def chicken():
 core('white','ivory')
 for x in (-.73,.73): eye(x,2.61,.44)
 box((0,-1.45,2.13),(.76,.50,.33),'orange')
 box((0,-1.64,2.31),(.64,.35,.21),'gold')
 box((0,-1.42,1.73),(.28,.23,.41),'red')
 for i in range(3): box((0,-.63+i*.46,3.29+i*.12),(.33,.39,.40),'red')
 for s in (-1,1):
  g='WingL' if s<0 else 'WingR'
  for i in range(3): box((s*(1.4+i*.15),.18+i*.18,1.95-i*.22),(.36,.69,.47),'white',g,shade=i%2)
 for i in range(3): box((-.3+i*.3,1.39,2.26+i*.13),(.25,.49,.70),'ivory','Tail')
 feet('orange')

def glitch():
 core('gold','ink',False)
 # Broken ink corners / chunky pixel silhouette, matching the user's reference.
 for s in (-1,1):
  for z in (.60,1.13,2.54,3.04): box((s*1.36,-1.26,z),(.28,.19,.23),'ink')
  box((s*.89,-1.31,3.08),(.42,.16,.18),'ink')
 glyph('?',(-.08,-1.33,1.92),.245,'aqua',outline=False)
 glyph('?',(.07,-1.36,1.88),.245,'pink',outline=False)
 glyph('?',(0,-1.40,1.91),.245,'white')
 for i,(x,y,z) in enumerate([(-1.64,-.1,2.93),(1.65,-.32,2.56),(-1.56,-.53,1.21),(1.59,.42,.71),(.90,.05,3.49),(-.73,.13,.16)]):
  c=['gold','aqua','pink'][i%3]
  box((x,y,z),(.29,.32,.27),c,f'Glitch{i+1:02}')
  box((x+.15,y,z+.13),(.13,.21,.12),'ink',f'Glitch{i+1:02}')
 for i in range(10):
  box((R.uniform(-1.13,1.1),-1.34,R.uniform(.63,3.0)),(.20,.03,.07),'pink' if i%2 else 'aqua','Glow')
 glyph('?',(1.41,0,1.8),.18,'white','side')

def clean_planes(vertices,faces,tiles):
 # Subtract earlier same-plane quads from later ones. Intersecting voxel
 # clusters otherwise create coplanar patches that flicker/turn black in games.
 outv,outf,outt,uvs=[],[],[],[]; occupied={}; eps=1e-7
 for indices,tile in zip(faces,tiles):
  q=[Vector(vertices[i]) for i in indices]
  normal=(q[1]-q[0]).cross(q[3]-q[0]); axis=max(range(3),key=lambda i:abs(normal[i]))
  a,b=[i for i in range(3) if i!=axis]
  rect=(min(p[a] for p in q),min(p[b] for p in q),max(p[a] for p in q),max(p[b] for p in q))
  key=(axis,round(q[0][axis],6),1 if normal[axis]>0 else -1)
  remaining=[rect]
  for prior in occupied.get(key,[]):
   pieces=[]
   for r in remaining:
    x0,y0=max(r[0],prior[0]),max(r[1],prior[1]); x1,y1=min(r[2],prior[2]),min(r[3],prior[3])
    if x1-x0<eps or y1-y0<eps: pieces.append(r); continue
    candidates=[(r[0],r[1],x0,r[3]),(x1,r[1],r[2],r[3]),(x0,r[1],x1,y0),(x0,y1,x1,r[3])]
    pieces.extend(p for p in candidates if p[2]-p[0]>eps and p[3]-p[1]>eps)
   remaining=pieces
   if not remaining: break
  occupied.setdefault(key,[]).extend(remaining)
  ua=max(range(3),key=lambda i:abs(q[1][i]-q[0][i])); va=max(range(3),key=lambda i:abs(q[3][i]-q[0][i]))
  for r in remaining:
   start=len(outv); uv=[]
   for v in q:
    p=v.copy(); p[a]=r[0] if abs(v[a]-rect[0])<eps else r[2]; p[b]=r[1] if abs(v[b]-rect[1])<eps else r[3]
    outv.append(tuple(p)); uv.append(((p[ua]-q[0][ua])/(q[1][ua]-q[0][ua]),(p[va]-q[0][va])/(q[3][va]-q[0][va])))
   outf.append(tuple(start+i for i in range(4))); outt.append(tile); uvs.append(uv)
 return outv,outf,outt,uvs

def finalize(slug):
 allv=[v for verts,_,_ in G.values() for v in verts]
 low=Vector(tuple(min(v[i] for v in allv) for i in range(3)))
 high=Vector(tuple(max(v[i] for v in allv) for i in range(3)))
 # Exact common game envelope: Roblox X=4, Y=3.8, Z=3.4 studs at scale 1.
 factor=Vector((4/(high.x-low.x),3.4/(high.y-low.y),3.8/(high.z-low.z)))
 center=(low+high)/2; objects=[]
 for group,(verts,faces,tiles) in G.items():
  verts,faces,tiles,face_uvs=clean_planes(verts,faces,tiles)
  transformed=[((v[0]-center.x)*factor.x,(v[1]-center.y)*factor.y,(v[2]-low.z)*factor.z) for v in verts]
  name=(f'Body_{slug}' if group=='Body' else f'{group}_{slug}')
  mesh=bpy.data.meshes.new(name); mesh.from_pydata(transformed,[],faces); mesh.update()
  obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
  obj['LuckyPreset']=slug; obj['NoLid']=True
  mesh.materials.append(MATS[1 if group=='Glow' else 0])
  uv=mesh.uv_layers.new(name='UVMap')
  for poly,tile,coords in zip(mesh.polygons,tiles,face_uvs):
   # Cube winding is inward initially; recalculate below without smoothing.
   for li,coord in zip(poly.loop_indices,coords):
    uv.data[li].uv=((tile%8+.02+coord[0]*.96)/8,(tile//8+.02+coord[1]*.96)/8)
  bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
  bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
  for poly in mesh.polygons: poly.use_smooth=False
  tri=obj.modifiers.new('Triangles','TRIANGULATE'); bpy.ops.object.modifier_apply(modifier=tri.name)
  objects.append(obj)
 return objects

def track(o,target): o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
def studio(gallery=False):
 s=bpy.context.scene
 s.render.engine='CYCLES'; s.cycles.samples=24; s.cycles.use_denoising=False
 s.render.resolution_x=900 if not gallery else 2100; s.render.resolution_y=900 if not gallery else 1200; s.render.resolution_percentage=100
 s.render.image_settings.file_format='PNG'; s.view_settings.view_transform='AgX'
 s.world=bpy.data.worlds.new('StudioWorld'); s.world.use_nodes=True
 s.world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.35,.43,.59,1)
 s.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.5
 bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.09)); floor=bpy.context.object; floor.name='STUDIO_Floor'
 m=bpy.data.materials.new('Stage'); m.diffuse_color=(.025,.038,.065,1); m.use_nodes=True
 m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.025,.038,.065,1)
 m.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.86; floor.data.materials.append(m)
 bpy.ops.object.camera_add(location=(9,-15,10) if not gallery else (0,-29,29))
 cam=bpy.context.object; cam.name='STUDIO_Camera'; cam.data.type='ORTHO'; cam.data.ortho_scale=6.8 if not gallery else 30
 track(cam,(0,0,1.8) if not gallery else (0,0,1)); s.camera=cam
 mult=1 if not gallery else 10
 for loc,energy,size,color in [((-4,-6,10),1300,7,(1,.89,.75)),((7,-1,7),1000,6,(.66,.85,1)),((0,5,10),1500,6,(.85,.9,1))]:
  bpy.ops.object.light_add(type='AREA',location=tuple(v*(1 if not gallery else 2.5) for v in loc))
  light=bpy.context.object; light.name='STUDIO_Area'; light.data.energy=energy*mult; light.data.shape='SQUARE'; light.data.size=size*(1 if not gallery else 2.5); light.data.color=color; track(light,(0,0,1))

allstats=[]
for folder,slug,label in VARIANTS:
 if ONLY and slug not in ONLY:
  allstats.append(json.loads((OUT/folder/'model_info.json').read_text())); continue
 print('BUILDING',slug,flush=True); dest=OUT/folder; dest.mkdir(exist_ok=True)
 init(slug); globals()[slug.lower()](); objects=finalize(slug)
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects: o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]
 bpy.ops.export_scene.fbx(filepath=str(dest/f'LB_{folder}.fbx'),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',bake_anim=False,path_mode='COPY',embed_textures=True)
 bpy.ops.export_scene.gltf(filepath=str(dest/f'LB_{folder}.glb'),use_selection=True,export_format='GLB',export_apply=True,export_yup=True,export_extras=True)
 stats={'id':folder,'preset':slug,'label':label,'meshes':[o.name for o in objects],
  'triangles':sum(len(o.data.polygons) for o in objects),'vertices':sum(len(o.data.vertices) for o in objects),
  'roblox_target_size':[4,3.8,3.4],'no_lid':True,'flat_shaded':True,'surface':'orthogonal cuboids + nearest-filtered pixel atlas'}
 allstats.append(stats); (dest/'model_info.json').write_text(json.dumps(stats,indent=2))
 studio(); bpy.context.scene.render.filepath=str(dest/'Preview.png')
 bpy.ops.wm.save_as_mainfile(filepath=str(dest/f'LB_{folder}.blend'))
 if RENDER: bpy.ops.render.render(write_still=True)

(OUT/'collection_manifest.json').write_text(json.dumps(allstats,indent=2))
# Collection scene: actual meshes, presentation labels, no compositing or AI image.
bpy.ops.wm.read_factory_settings(use_empty=True)
for index,(folder,slug,label) in enumerate(VARIANTS):
 path=OUT/folder/f'LB_{folder}.blend'
 with bpy.data.libraries.load(str(path),link=False) as (data,loaded): loaded.objects=[n for n in data.objects if not n.startswith('STUDIO_')]
 x=(index%5-2)*5.6; y=(.5-index//5)*8.4
 for obj in loaded.objects:
  if obj: bpy.context.collection.objects.link(obj); obj.location+=Vector((x,y,.08))
 bpy.ops.object.text_add(location=(x,y-2.26,.06))
 txt=bpy.context.object; txt.name='STUDIO_Label'; txt.data.body=f'{index+1:02}  {slug.upper()}'; txt.data.align_x='CENTER'; txt.data.size=.34; txt.data.extrude=0
 mat=bpy.data.materials.get('Label') or bpy.data.materials.new('Label'); mat.diffuse_color=(.78,.88,1,1); txt.data.materials.append(mat)
studio(True); bpy.context.scene.render.filepath=str(OUT/'Collection_Preview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Cubic_Collection.blend'))
if RENDER: bpy.ops.render.render(write_still=True)
print('CUBIC_COLLECTION_BUILD_OK',json.dumps({x['preset']:x['triangles'] for x in allstats}),flush=True)
