"""Render the exported map geometry for an offline layout review, not Studio."""
import bpy, json, math, os, sys
from mathutils import Vector, Matrix
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
with open(os.path.join(ROOT, 'tools', 'geometry.json'), encoding='utf8') as f:
    parts = json.load(f)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def linear(v):
    v = v / 255
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

# Merge blocks by surface/material to keep offline rendering inexpensive.
groups = defaultdict(lambda: [[], []])
cube = [(-.5,-.5,-.5),(.5,-.5,-.5),(.5,.5,-.5),(-.5,.5,-.5),(-.5,-.5,.5),(.5,-.5,.5),(.5,.5,.5),(-.5,.5,.5)]
faces = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
for p in parts:
    if p['name'] in ('Bubble', 'BubbleHighlight'):
        continue
    # Rear faces outside the scene are culled in the preview for the overview.
    key = (tuple(p['color']), p['material'], round(p['alpha'], 2), p['studs'])
    vertices, polygons = groups[key]
    start = len(vertices)
    r = p['rotation']; xyz = p['position']; size = p['size']
    for vertex in cube:
        v = [vertex[j]*size[j] for j in range(3)]
        q = [xyz[i] + sum(r[i*3+j]*v[j] for j in range(3)) for i in range(3)]
        # Roblox Y-up to Blender Z-up, maintaining handedness.
        vertices.append((q[0], -q[2], q[1]))
    polygons.extend(tuple(start + i for i in f) for f in faces)

for idx, ((rgb, mat_id, alpha, studs), (vertices, polygons)) in enumerate(groups.items()):
    mesh = bpy.data.meshes.new('MapMesh')
    mesh.from_pydata(vertices, [], polygons)
    mesh.update()
    obj = bpy.data.objects.new('MapSurface', mesh)
    bpy.context.collection.objects.link(obj)
    mat = bpy.data.materials.new('Surface')
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    output = nodes.new('ShaderNodeOutputMaterial')
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    col = (*[linear(c) for c in rgb], 1)
    bsdf.inputs['Base Color'].default_value = col
    bsdf.inputs['Roughness'].default_value = .64
    if mat_id == 288:
        bsdf.inputs['Emission Color'].default_value = col
        bsdf.inputs['Emission Strength'].default_value = .35
    if alpha:
        if mat_id == 1568:
            # Clear surface preview, with the same footprint as Terrain water.
            bsdf.inputs['Alpha'].default_value = .24
            bsdf.inputs['Roughness'].default_value = .19
        else:
            bsdf.inputs['Alpha'].default_value = 1-alpha
        mat.surface_render_method = 'DITHERED'
    if studs and alpha == 0:
        geom = nodes.new('ShaderNodeNewGeometry')
        separate = nodes.new('ShaderNodeSeparateXYZ')
        links.new(geom.outputs['Position'], separate.inputs[0])
        axes=[]
        # Periodic square dimples approximate Roblox's built-in stud normal map.
        for axis in ('X','Y','Z'):
            mult=nodes.new('ShaderNodeMath'); mult.operation='MULTIPLY'; mult.inputs[1].default_value=1.0
            links.new(separate.outputs[axis], mult.inputs[0])
            ping=nodes.new('ShaderNodeMath'); ping.operation='PINGPONG'; ping.inputs[1].default_value=.5
            links.new(mult.outputs[0], ping.inputs[0])
            less=nodes.new('ShaderNodeMath'); less.operation='LESS_THAN'; less.inputs[1].default_value=.26
            links.new(ping.outputs[0], less.inputs[0]); axes.append(less)
        combine=nodes.new('ShaderNodeMath'); combine.operation='MULTIPLY'
        links.new(axes[0].outputs[0],combine.inputs[0]); links.new(axes[1].outputs[0],combine.inputs[1])
        bump=nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.14; bump.inputs['Distance'].default_value=.08
        links.new(combine.outputs[0],bump.inputs['Height']); links.new(bump.outputs['Normal'],bsdf.inputs['Normal'])
    obj.data.materials.append(mat)

world = bpy.data.worlds.new('MarineSky')
world.use_nodes=True
world.node_tree.nodes.clear()
background = world.node_tree.nodes.new('ShaderNodeBackground')
worldout = world.node_tree.nodes.new('ShaderNodeOutputWorld')
world.node_tree.links.new(background.outputs[0], worldout.inputs[0])
background.inputs[0].default_value=(.43,.69,.76,1)
background.inputs[1].default_value=.8
bpy.context.scene.world=world
bpy.ops.object.light_add(type='SUN', location=(0,0,300))
sun=bpy.context.object; sun.rotation_euler=(math.radians(20),math.radians(-25),math.radians(-32)); sun.data.energy=2; sun.data.angle=.3
bpy.ops.object.camera_add()
camera=bpy.context.object
scene=bpy.context.scene; scene.camera=camera
scene.render.engine='CYCLES'
scene.cycles.samples=24
scene.cycles.use_denoising=True
scene.render.resolution_x=1600; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard'
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=False

def render(name, pos, target, lens):
    camera.location=(pos[0],-pos[2],pos[1])
    point=Vector((target[0],-target[2],target[1]))
    camera.rotation_euler=(point-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.lens=lens
    camera.data.clip_end=4000
    scene.render.filepath=os.path.join(ROOT,'previews',name+'.png')
    bpy.ops.render.render(write_still=True)

if '--detail' not in sys.argv:
    render('spawn-v4', [184,171,-280], [0,0,10], 30)
render('seabed-v4', [10,-22,290], [4,-37,365], 26)
