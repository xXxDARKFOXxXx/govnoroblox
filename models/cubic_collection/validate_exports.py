"""Run with Blender: blender -b --python validate_exports.py -- COLLECTION_PATH.
Checks one-sided winding against solid volumes, not just normal lengths.
Optional: --baseline=/path/to/broken_v1_toilet.fbx proves the regression test fails v1.
"""
import bpy,sys,json,struct,hashlib
from pathlib import Path
import numpy as np
from mathutils import Vector

args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
root=Path(args[0]) if args else Path(__file__).resolve().parent
manifest=json.loads((root/'collection_manifest.json').read_text())

def load(path):
 bpy.ops.wm.read_factory_settings(use_empty=True)
 if path.suffix=='.fbx': bpy.ops.import_scene.fbx(filepath=str(path),use_anim=False)
 else: bpy.ops.import_scene.gltf(filepath=str(path))
 return [o for o in bpy.data.objects if o.type=='MESH']

def orientation(objects,contract):
 counts={'outward':0,'inward':0,'internal':0,'ambiguous':0}
 for o in objects:
  boxes=np.asarray(contract[o.name],dtype=float); mins=boxes[:,0]; maxs=boxes[:,1]
  # World coordinates also check the export/import axis transformations.
  centers=np.asarray([tuple(o.matrix_world@p.center) for p in o.data.polygons])
  normal_matrix=o.matrix_world.to_3x3().inverted().transposed()
  normals=np.asarray([tuple((normal_matrix@p.normal).normalized()) for p in o.data.polygons])
  def inside(points):
   result=[]
   for p in np.array_split(points,max(1,len(points)//256)):
    result.extend(np.any(np.all(p[:,None]>=mins[None]-2e-6,axis=2)&np.all(p[:,None]<=maxs[None]+2e-6,axis=2),axis=1))
   return np.asarray(result)
  front=inside(centers+normals*1e-4); back=inside(centers-normals*1e-4)
  counts['outward']+=int(np.sum(back&~front)); counts['inward']+=int(np.sum(front&~back))
  counts['internal']+=int(np.sum(front&back)); counts['ambiguous']+=int(np.sum(~front&~back))
 return counts

baseline=next((Path(a.split('=',1)[1]) for a in args if a.startswith('--baseline=')),None)
if baseline:
 contract=json.loads((root/'01_Toilet'/'solid_contract.json').read_text())
 bad=orientation(load(baseline),contract)
 assert bad['inward']>0, 'Regression fixture must reproduce the old inward-face defect'
 (root/'winding_regression.json').write_text(json.dumps({'broken_v1_toilet':bad,
  'baseline_sha256':hashlib.sha256(baseline.read_bytes()).hexdigest(),
  'regression_rejects_v1':True,'method':'solid occupancy probes on both sides of triangle normals'},indent=2))
 print('REGRESSION_V1_REJECTED',json.dumps(bad),flush=True)

results=[]
for item in manifest:
 assert item['format_version']==2
 folder=root/item['id']; contract=json.loads((folder/'solid_contract.json').read_text())
 for ext in ('fbx','glb'):
  path=folder/item['files'][ext]
  if ext=='glb':
   data=path.read_bytes(); length,kind=struct.unpack_from('<II',data,12)
   assert kind==0x4e4f534a
   doc=json.loads(data[20:20+length])
   assert all(not m.get('doubleSided',False) for m in doc['materials']), 'GLB must remain single-sided'
  objects=load(path)
  assert {o.name for o in objects}==set(item['meshes'])
  points=[o.matrix_world@Vector(v) for o in objects for v in o.bound_box]
  lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
  hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
  assert (hi-lo-Vector((4,3.4,3.8))).length<.001,(item['preset'],hi-lo)
  assert abs(lo.z)<.001
  total=0
  for o in objects:
   assert 'lid' not in o.name.lower()
   assert o.data.uv_layers and all(np.isfinite(c) for v in o.data.vertices for c in v.co)
   assert all(-.0001<=c<=1.0001 for uv in o.data.uv_layers.active.data for c in uv.uv)
   o.data.calc_loop_triangles(); count=len(o.data.loop_triangles); total+=count
   assert 0<count<10000
   for p in o.data.polygons:
    n=(o.matrix_world.to_3x3()@p.normal).normalized()
    assert max(abs(n.x),abs(n.y),abs(n.z))>.9999 and p.area>0
   for mat in o.data.materials:
    images=[n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
    assert images and all(tuple(i.size)==(1024,1024) and len(i.pixels)==4194304 for i in images)
  assert total==item['triangles']
  facing=orientation(objects,contract)
  assert facing['inward']==0 and facing['ambiguous']==0 and facing['outward']>0,(item['preset'],ext,facing)
  body=next(o for o in objects if o.name=='Body_'+item['preset'])
  body_points=[body.matrix_world@Vector(v) for v in body.bound_box]
  body_size=[max(p[i] for p in body_points)-min(p[i] for p in body_points) for i in range(3)]
  if item['preset']=='Paradise': assert body_size[0]/body_size[2]>.9,body_size
  row={'preset':item['preset'],'format':ext,'format_version':2,'triangles':total,
   'mesh_count':len(objects),'blender_bounds':[4,3.4,3.8],'body_bounds':body_size,
   'facing':facing,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'status':'PASS'}
  results.append(row); print('V2_EXPORT_PASS',json.dumps(row),flush=True)
(root/'geometry_validation.json').write_text(json.dumps(results,indent=2))
print('CUBIC_V2_GEOMETRY_OK',len(results),'single-sided round trips',flush=True)
