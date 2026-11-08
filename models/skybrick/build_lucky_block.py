"""Skybrick Lucky Block — Blender 4.3+, no add-ons or external downloads.
Run: blender -b --python build_lucky_block.py -- /absolute/output/directory
Rebuilds only this scene; run in a fresh Blender file.
"""
import bpy, math, sys, os, json
from mathutils import Vector
import numpy as np

OUT = os.path.abspath(sys.argv[sys.argv.index('--')+1]) if '--' in sys.argv else os.path.dirname(os.path.abspath(__file__))
os.makedirs(OUT, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for datablock in list(bpy.data.materials):
    bpy.data.materials.remove(datablock)

# One UV atlas for the entire asset. Materials remain usable in Studio even if
# its importer collapses multiple FBX materials to a single texture per mesh.
palette = [(.94,.57,.025), (1.,.77,.055), (.59,.29,.014), (.90,.86,.69),
           (.985,.98,.91), (.035,.075,.12), (.025,.65,.65), (.24,.13,.028)]
SIZE=1024
rng=np.random.default_rng(781)
pixels=np.ones((SIZE,SIZE,4),dtype=np.float32)
for tile, col in enumerate(palette):
    x=(tile%4)*256; y=(tile//4)*512
    noise=rng.normal(0,.0028,(512,256,1))
    yy,xx=np.mgrid[0:512,0:256]
    grain=(.002*np.sin(xx*.32)+.001*np.sin(yy*.53))[:,:,None]
    pixels[y:y+512,x:x+256,:3]=np.clip(np.array(col)+noise+grain,0,1)
atlas=bpy.data.images.new('Skybrick_Atlas',width=SIZE,height=SIZE)
atlas.pixels.foreach_set(pixels.ravel())
atlas.filepath_raw=os.path.join(OUT,'Skybrick_Atlas.png')
atlas.file_format='PNG'; atlas.save()
mats=[]
for idx,label in enumerate(['HoneyGold','SunGold','AntiqueGold','Ivory','Porcelain','Midnight','Aqua','Recess']):
    m=bpy.data.materials.new(label); m.use_nodes=True
    m.diffuse_color=(*palette[idx],1)
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Metallic'].default_value=.5 if idx in (0,1,2) else .05
    bs.inputs['Roughness'].default_value=.29 if idx in (0,1,2) else .34
    tex=m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=atlas
    m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    # Fine molded plastic grain in the .blend; baked atlas supplies color grain
    # in FBX. No claim that procedural bump transfers through FBX.
    noise=m.node_tree.nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=160
    bump=m.node_tree.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.1
    bump.inputs['Distance'].default_value=.012
    m.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height'])
    m.node_tree.links.new(bump.outputs['Normal'],bs.inputs['Normal'])
    mats.append(m)

groups={k:[] for k in ['Body','Lid','WingL','WingR']}
def finish(o,name,tile,group,bevel=.035):
    o.name=name
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Molded edge radii','BEVEL'); mod.width=bevel; mod.segments=3
        mod.affect='EDGES'
        bpy.context.view_layer.objects.active=o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    # An explicit UV projection also handles freshly constructed polygon caps.
    if not o.data.uv_layers:
        uv=o.data.uv_layers.new(name='UVMap')
        for poly in o.data.polygons:
            normal=poly.normal
            axes=(0,2) if abs(normal.y)>.5 else ((0,1) if abs(normal.z)>.5 else (1,2))
            for li in poly.loop_indices:
                v=o.data.vertices[o.data.loops[li].vertex_index].co
                uv.data[li].uv=((v[axes[0]]*.16)%1,(v[axes[1]]*.16)%1)
    for uv in o.data.uv_layers.active.data:
        u,v=uv.uv
        uv.uv=((tile%4+.025+u*.95)/4,(tile//4+.025+v*.95)/2)
    o.data.materials.clear(); o.data.materials.append(mats[tile])
    for p in o.data.polygons: p.use_smooth=True
    weighted=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
    weighted.keep_sharp=True; weighted.weight=50
    bpy.ops.object.modifier_apply(modifier=weighted.name)
    groups[group].append(o)
    return o

def box(name,loc,dims,tile,group,bevel=.04,rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=bpy.context.object; o.dimensions=dims
    if rot: o.rotation_euler=rot
    return finish(o,name,tile,group,bevel)

def cylinder(name,loc,radius,depth,tile,group,axis='Z',vertices=20):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc)
    o=bpy.context.object
    if axis=='Y': o.rotation_euler.x=math.pi/2
    if axis=='X': o.rotation_euler.y=math.pi/2
    return finish(o,name,tile,group,.025)

def slab(name,coords,y,depth,tile,group,bevel=.045):
    n=len(coords)
    verts=[(x,y-depth/2,z) for x,z in coords]+[(x,y+depth/2,z) for x,z in coords]
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    o=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(o)
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
    return finish(o,name,tile,group,bevel)

# Shell, inset framed faces, rounded corner pillars and physically raised symbols.
box('Main rounded shell',(0,0,1.65),(3.2,2.8,2.8),0,'Body',.17)
box('Bottom plinth',(0,0,.28),(3.28,2.88,.30),2,'Body',.09)
box('Bottom bright reveal',(0,0,.46),(3.23,2.83,.075),1,'Body',.025)
box('Top dark opening seam',(0,0,3.075),(3.13,2.73,.13),7,'Body',.05)
for side in [-1,1]:
    box('Face inset',(0,side*1.407,1.72),(2.73,.09,2.27),2,'Body',.13)
    box('Face field',(0,side*1.46,1.72),(2.48,.055,2.02),1,'Body',.105)
    box('Side inset',(side*1.607,0,1.72),(.09,2.32,2.27),2,'Body',.13)
    box('Side field',(side*1.66,0,1.72),(.055,2.07,2.02),0,'Body',.10)
    for x in [-1.32,1.32]:
        for z in [.64,2.79]:
            cylinder('Corner fastener',(x,side*1.48,z),.095,.07,2,'Body','Y')
            cylinder('Fastener cap',(x,side*1.52,z),.045,.025,1,'Body','Y',12)
for x in [-1.47,1.47]:
    for y in [-1.27,1.27]:
        box('Corner rail',(x,y,1.68),(.20,.20,2.45),1,'Body',.065)

q=[(-.63,.45),(-.63,.77),(-.38,1.02),(.35,1.02),(.64,.73),(.64,.22),(.39,-.03),(.15,-.16),(.15,-.39),(-.20,-.39),(-.20,.08),(.03,.25),(.27,.38),(.27,.63),(.13,.76),(-.15,.76),(-.28,.63),(-.28,.45)]
for side in [-1,1]:
    # front/back symbol and its darker undercut provide a deep, readable outline
    for layer,depth,tile in [(0,.12,2),(1,.16,4)]:
        coords=[(x*(1.08 if layer==0 else 1),z+1.64) for x,z in q]
        slab('Raised question',coords,side*(1.52+layer*.065),depth,tile,'Body',.033)
    box('Question dot',(0,side*1.60,.91),(.39,.19,.34),4,'Body',.045)
    # Side symbols use the same physical shape, rotated around the center.
    o=slab('Side question',[(x,z+1.64) for x,z in q],-1.77,.14,4,'Body',.033)
    o.rotation_euler.z=side*math.pi/2
    o=box('Side dot',(0,-1.77,.91),(.39,.14,.34),4,'Body',.045)
    o.rotation_euler.z=side*math.pi/2
    o.location=(side*1.77,0,.91)

# Separate lift-off lid, with eight unmistakable brick studs.
box('Lid underside',(0,0,3.17),(3.13,2.73,.14),2,'Lid',.055)
box('Lid beveled cap',(0,0,3.34),(3.32,2.92,.26),1,'Lid',.10)
box('Lid top inset',(0,0,3.485),(2.98,2.58,.055),0,'Lid',.05)
for x in [-1.08,-.36,.36,1.08]:
    for y in [-.66,.66]:
        cylinder('Stud lower ring',(x,y,3.56),.255,.14,2,'Lid')
        cylinder('Stud molded top',(x,y,3.65),.235,.17,1,'Lid')
        cylinder('Stud top recess',(x,y,3.737),.147,.012,0,'Lid')
        # Delicate raised dash instead of a third-party logo.
        box('Stud stamp',(x,y,3.747),(.12,.028,.018),1,'Lid',.008)

# Angel wings: stepped silhouette, offset layered brick feathers, gold upper spar.
outline=[(1.52,2.08),(2.28,2.02),(3.02,2.34),(3.38,2.70),(3.80,2.70),(4.13,3.13),
         (4.48,3.13),(4.80,3.62),(5.12,3.62),(5.43,4.17),(5.70,4.17),(5.98,5.20),
         (5.02,5.07),(4.13,4.90),(3.20,4.55),(2.48,3.87),(1.86,3.05)]
def mirror(points,s): return [(x*s,z) for x,z in points][::s]
for s,group in [(-1,'WingL'),(1,'WingR')]:
    cylinder('Hinge mount',(s*1.70,.0,2.56),.36,.29,2,group,'X')
    cylinder('Hinge gold rim',(s*1.85,-.02,2.56),.28,.12,1,group,'X')
    slab('Stepped wing silhouette',mirror(outline,s),.30,.44,2,group,.065)
    inner=[(1.67,2.18),(2.28,2.16),(2.94,2.46),(3.31,2.85),(3.73,2.85),(4.06,3.28),
           (4.40,3.28),(4.73,3.77),(5.04,3.77),(5.35,4.31),(5.57,4.31),(5.79,5.02),
           (4.98,4.91),(4.15,4.75),(3.30,4.41),(2.62,3.79),(1.99,2.98)]
    slab('Ivory wing base',mirror(inner,s),.02,.30,3,group,.045)
    # Five individually shaped long feathers separated by visible dark seams.
    feathers=[[(2.16,2.42),(2.67,2.48),(3.42,3.18),(3.22,3.64),(2.65,3.45)],
              [(2.63,2.73),(3.08,2.92),(4.00,3.68),(3.79,4.17),(3.22,3.91)],
              [(3.19,3.10),(3.58,3.20),(4.58,4.17),(4.33,4.58),(3.77,4.35)],
              [(3.83,3.53),(4.20,3.58),(5.11,4.60),(4.92,4.88),(4.42,4.75)],
              [(4.46,4.00),(4.83,4.08),(5.68,4.94),(5.70,5.08),(5.18,4.98)]]
    for i,pts in enumerate(feathers):
        slab('Layered brick feather %d'%i,mirror(pts,s),-.22-.018*i,.25,4,group,.055)
        # Two round sockets on each feather make the toy construction readable.
        a=Vector(pts[-1]); b=Vector(pts[1])
        for t in [.34,.66]:
            v=a.lerp(b,t)
            cylinder('Feather stud',(s*v.x,-.385-.018*i,v.y),.105,.10,3,group,'Y',16)
            cylinder('Feather stud face',(s*v.x,-.44-.018*i,v.y),.068,.018,4,group,'Y',16)
    # Crown of shorter overlapping coverts.
    for i,(x,z,ang) in enumerate([(2.10,2.85,-.50),(2.49,3.39,-.62),(2.99,3.96,-.77),(3.61,4.41,-1.00)]):
        o=box('Gold leading brick',(s*x,-.19,z),(.44,.35,.67),1,group,.07)
        o.rotation_euler.y=s*ang
        cylinder('Leading stud',(s*x,-.41,z),.12,.12,0,group,'Y')
    cylinder('Shoulder rosette',(s*1.98,-.36,2.57),.32,.22,1,group,'Y')
    cylinder('Shoulder dark socket',(s*1.98,-.49,2.57),.215,.06,5,group,'Y')
    cylinder('Shoulder aqua center',(s*1.98,-.535,2.57),.14,.07,6,group,'Y',8)

# Four separately movable meshes with meaningful local origins.
origins={'Body':(0,0,0),'Lid':(0,0,3.15),'WingL':(-1.7,0,2.56),'WingR':(1.7,0,2.56)}
objects=[]
for group,parts in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join()
    o=bpy.context.object; o.name=group; o.data.name=group+'_Mesh'
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    bpy.context.scene.cursor.location=origins[group]; bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    tri=o.modifiers.new('Game triangles','TRIANGULATE'); bpy.ops.object.modifier_apply(modifier=tri.name)
    objects.append(o)
bpy.context.scene.cursor.location=(0,0,0)

# Export a clean static model. Animation and effects are supplied as Luau.
bpy.ops.object.select_all(action='DESELECT')
for o in objects: o.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT,'Skybrick_Lucky_Block.fbx'),use_selection=True,
    object_types={'MESH'},apply_unit_scale=True,axis_forward='-Z',axis_up='Y',
    use_mesh_modifiers=True,add_leaf_bones=False,bake_anim=False,path_mode='COPY',embed_textures=True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'Skybrick_Lucky_Block.glb'),export_format='GLB',
    use_selection=True,export_yup=True,export_apply=True)
stats={'mesh_names':[o.name for o in objects], 'triangles':sum(len(o.data.polygons) for o in objects),
       'vertices':sum(len(o.data.vertices) for o in objects), 'blender_version':bpy.app.version_string,
       'wingspan_blender_units':11.96,'materials':'Single UV color atlas; no external assets or add-ons'}
with open(os.path.join(OUT,'model_info.json'),'w') as f: json.dump(stats,f,indent=2)

# Native Blender opening preview. Timeline: anticipation > wings flare > lid pop.
scene=bpy.context.scene; scene.render.fps=30; scene.frame_start=1; scene.frame_end=108
body,lid,wl,wr=objects
for o in objects:
    base=o.location.copy()
    for frame,height in [(1,0),(15,.05),(27,-.13),(38,.55),(54,.55),(85,0),(108,0)]:
        o.location=base+Vector((0,0,height))
        if o==lid and frame>=38: o.location.z += 1.55 if frame<=54 else 0
        o.keyframe_insert(data_path='location',frame=frame)
    o.location=base
for o,sign in [(wl,-1),(wr,1)]:
    for frame,angle in [(1,0),(15,8),(27,-9),(38,23),(54,14),(85,0),(108,0)]:
        o.rotation_euler.y=math.radians(-angle*sign); o.keyframe_insert(data_path='rotation_euler',frame=frame)
for f in [1,27,38,54,85,108]:
    lid.rotation_euler.y=math.radians(-13 if f in (38,54) else 0)
    lid.keyframe_insert(data_path='rotation_euler',frame=f)
scene.frame_set(1)

# Studio-lit product presentation; these objects are NOT exported to FBX/GLB.
def track(o,target): o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.06)); floor=bpy.context.object; floor.name='STUDIO_Floor'
fm=bpy.data.materials.new('Studio ink'); fm.diffuse_color=(.018,.032,.055,1); fm.use_nodes=True
fm.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.018,.032,.055,1)
fm.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.58; floor.data.materials.append(fm)
bpy.ops.object.camera_add(location=(10,-19,10.0)); camera=bpy.context.object; camera.name='STUDIO_Camera'
track(camera,(0,0,2.45)); camera.data.type='ORTHO'; camera.data.ortho_scale=15.0; scene.camera=camera
for name,loc,power,size,color in [('Key',(-4,-7,11),1900,7,(1,.88,.65)),('Fill',(7,-4,6),1500,6,(.65,.84,1)),('Rim',(1,5,9),2200,5,(.7,.9,1))]:
    bpy.ops.object.light_add(type='AREA',location=loc); light=bpy.context.object; light.name='STUDIO_'+name
    light.data.energy=power; light.data.shape='DISK'; light.data.size=size; light.data.color=color; track(light,(0,0,2))
scene.world.color=(.18,.18,.18)
scene.render.engine='CYCLES'; scene.cycles.samples=80; scene.cycles.use_denoising=False
scene.render.resolution_x=1600; scene.render.resolution_y=1100; scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG'; scene.render.filepath=os.path.join(OUT,'Preview.png')
atlas.pack()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'Skybrick_Lucky_Block.blend'))
bpy.ops.render.render(write_still=True)
print('SKYBRICK_BUILD_OK',json.dumps(stats))
