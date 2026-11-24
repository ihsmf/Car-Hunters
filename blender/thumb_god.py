"""Big transparent render of the god of billiards (3/4 front view) for the thumbnail composite.
    python3 blender/thumb_god.py <out.png>"""
import bpy, math, os, sys
from mathutils import Vector

E = os.path.join(os.path.dirname(os.path.abspath(__file__)), "export")
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
for name in ("GodBody", "GodHead", "GodArmR", "GodArmL"):
    bpy.ops.import_scene.gltf(filepath=os.path.join(E, name + ".glb"))
    o = bpy.context.selected_objects[0]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    t = m.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(os.path.join(E, name + ".png"))
    b = m.node_tree.nodes["Principled BSDF"]
    m.node_tree.links.new(t.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.55
    o.data.materials.clear()
    o.data.materials.append(m)
    off = {"GodArmR": (0, 19.68, 3.456), "GodArmL": (0, 19.68, -3.456)}.get(name, (0, 0, 0))
    o.location = (off[0], -off[2], off[1])
bpy.ops.mesh.primitive_torus_add(major_radius=4.2, minor_radius=0.28, location=(-1.6, 0, 24.8), rotation=(0, math.radians(90), 0))
halo = bpy.context.object
hm = bpy.data.materials.new("Halo")
hm.use_nodes = True
hm.node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = (1, 0.8, 0.3, 1)
hm.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 18
halo.data.materials.append(hm)
for loc, e, col in (((30, -25, 30), 11000, (1, 0.93, 0.8)), ((-20, 25, 25), 7000, (1, 0.75, 0.4)), ((10, 30, 5), 3000, (0.6, 0.7, 1))):
    l = bpy.data.objects.new("L", bpy.data.lights.new("L", "AREA"))
    l.data.energy, l.data.size, l.data.color = e, 10, col
    l.location = loc
    l.rotation_euler = (Vector((0, 0, 16)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(l)
w = bpy.data.worlds.new("w")
sc.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.location = (34, 16, 19)
cam.rotation_euler = (Vector((1, 0, 14.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 50
sc.render.engine = "CYCLES"
sc.cycles.samples = 64
sc.render.film_transparent = True
sc.render.resolution_x, sc.render.resolution_y = 1000, 1400
sc.view_settings.view_transform = "Standard"
sc.render.filepath = sys.argv[-1]
bpy.ops.render.render(write_still=True)
