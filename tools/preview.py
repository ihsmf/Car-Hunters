"""Рендер превью карты из tools/scene.json: python3 tools/preview.py out.png camX camY camZ lookX lookY lookZ [fov]"""
import bpy, bmesh, json, math, os, sys
import numpy as np
from mathutils import Matrix, Vector

out, *nums = sys.argv[1:]
cam_pos, look = nums[:3], nums[3:6]
fov = float(nums[6]) if len(nums) > 6 else 60
scene_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "scene.json")
bpy.ops.wm.read_factory_settings(use_empty=True)
P = np.array([[1, 0, 0, 0], [0, 0, -1, 0], [0, 1, 0, 0], [0, 0, 0, 1]], float)  # Roblox (Y-up) -> Blender (Z-up)

def base_mesh(kind):
    bm = bmesh.new()
    if kind == "Block": bmesh.ops.create_cube(bm, size=1)
    elif kind == "Ball": bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=0.5)
    else:
        bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=0.5, radius2=0.5, depth=1)
        bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))  # ось X как в Roblox
    me = bpy.data.meshes.new(kind); bm.to_mesh(me); me.materials.append(None)
    for p in me.polygons: p.use_smooth = kind != "Block"
    return me
meshes = {k: base_mesh(k) for k in ("Block", "Ball", "Cyl")}
mats = {}
def material(c, kind, t):
    key = (tuple(c), kind, round(t, 2))
    if key in mats: return mats[key]
    m = bpy.data.materials.new(str(key)); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    col = tuple((v / 255) ** 2.2 for v in c) + (1,)
    b.inputs["Base Color"].default_value = col
    b.inputs["Roughness"].default_value = 0.25 if kind in ("Glass", "Metal", "Smooth") else 0.8
    b.inputs["Metallic"].default_value = 1 if kind == "Metal" else 0
    if kind == "Neon":
        b.inputs["Emission Color"].default_value = col; b.inputs["Emission Strength"].default_value = 4
    if kind == "ForceField": t = max(t, 0.85)
    if t > 0:
        b.inputs["Alpha"].default_value = 1 - t
    mats[key] = m
    return m

for d in json.load(open(scene_path)):
    o = bpy.data.objects.new("p", meshes[d["sh"]])
    o.matrix_world = Matrix((P @ np.array(d["m"]) @ np.diag(list(d["s"]) + [1])).tolist())
    bpy.context.scene.collection.objects.link(o)
    o.material_slots[0].link = "OBJECT"
    o.material_slots[0].material = material(d["c"], d["mat"], d["t"])

sc = bpy.context.scene
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
bg = w.node_tree.nodes["Background"]; bg.inputs[0].default_value = (0.45, 0.65, 1, 1); bg.inputs[1].default_value = 1.2
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sun.data.energy = 4
sun.rotation_euler = (math.radians(50), math.radians(20), math.radians(30)); sc.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.angle = math.radians(fov); cam.data.clip_end = 5000
cp = Vector((P @ np.array([*map(float, cam_pos), 1]))[:3]); lp = Vector((P @ np.array([*map(float, look), 1]))[:3])
cam.location = cp; cam.rotation_euler = (lp - cp).to_track_quat("-Z", "Y").to_euler()
sc.render.engine = "CYCLES"; sc.cycles.samples = 24; sc.cycles.use_denoising = False
sc.render.resolution_x, sc.render.resolution_y = 1280, 720
sc.view_settings.view_transform = "Standard"
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
