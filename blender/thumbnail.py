"""CUE HUNTERS store thumbnail (1920x1080) rendered from the real game models.
    python3 blender/thumbnail.py <out.png>
Scene: the long table runs away from the camera through themed halls, the god of billiards towers at the far end,
a glowing cue ball streaks towards a rainbow prize ball in the foreground. Text is added afterwards (thumbnail_text.py)."""
import bpy, math, os, sys
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
E = os.path.join(HERE, "export")
OUT = sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
cache = {}


def rb(x, y, z):  # Roblox -> Blender
    return (x, -z, y)


def place(name, pos, yaw=0.0, scale=1.0):
    if name not in cache:
        bpy.ops.import_scene.fbx(filepath=os.path.join(E, name + ".fbx"))
        o = bpy.context.selected_objects[0]
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        cache[name] = o
    else:
        o = cache[name].copy()
        sc.collection.objects.link(o)
    o.location = rb(*pos)
    o.rotation_euler = (0, 0, yaw)
    o.scale = (scale,) * 3
    return o


def emit(name, color, strength):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    n = m.node_tree.nodes
    n.remove(n["Principled BSDF"])
    e = n.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = (*color, 1)
    e.inputs["Strength"].default_value = strength
    m.node_tree.links.new(e.outputs[0], n["Material Output"].inputs[0])
    return m


THEMES = ["Space", "Candy", "NewYear", "Royal"]
for k, t in enumerate(THEMES):
    zc = 40 + k * 80
    place("TableSegment", (0, 2.3, zc))
    for side in (-1, 1):
        place("Wall" + t, (side * 33.5, 0, zc), 0 if side < 0 else math.pi)
        place("Backdrop" + t, (side * 31.35, 0, zc), 0 if side < 0 else math.pi)
        place("Hero" + t, (side * 25.5, 0, zc + side * 10), 0 if side < 0 else math.pi)
        place("Mid" + t, (side * 24.5, 0, zc - side * 22), 0 if side < 0 else math.pi)
        for dz in (-34, -13, 13, 34):
            place("Rail" + t, (side * 15.17, 4.53, zc + dz), dz * 0.1, 1.15)
    if k < len(THEMES) - 1:  # the last segment is open to the sky so the god can tower over the hall
        place("Ceiling" + t, (0, 0, zc))

# the god of billiards at the far end, giant and glowing
GZ, GS = 40 + len(THEMES) * 80 + 40, 2.6
for name in ("GodTemple", "GodBody", "GodHead", "GodArmR", "GodArmL"):
    bpy.ops.import_scene.gltf(filepath=os.path.join(E, name + ".glb"))
    o = bpy.context.selected_objects[0]
    img = bpy.data.images.load(os.path.join(E, name + ".png"))
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    t = m.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = img
    b = m.node_tree.nodes["Principled BSDF"]
    m.node_tree.links.new(t.outputs["Color"], b.inputs["Base Color"])
    m.node_tree.links.new(t.outputs["Color"], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 0.35
    o.data.materials.clear()
    o.data.materials.append(m)
    off = {"GodArmR": (0, 19.68, 3.456), "GodArmL": (0, 19.68, -3.456)}.get(name, (0, 0, 0))
    feet = (0, 3.36 if name != "GodTemple" else 0, 0)
    # the god faces the camera (-Z in Roblox): turn the +X-facing model by 90 degrees
    o.rotation_euler = (0, 0, math.radians(90))
    rx, ry, rz = off[0] + feet[0], off[1] + feet[1], off[2] + feet[2]
    # rotate the Roblox offset by the same yaw (x -> -z)
    o.location = Vector(rb(rz * 1, ry, -rx)) * GS + Vector(rb(0, 0, GZ))
    o.scale = (GS,) * 3
halo = bpy.data.objects.new("Halo", None)
bpy.ops.mesh.primitive_torus_add(major_radius=7 * GS / 2.2, minor_radius=0.5, location=rb(0, 26 * GS, GZ + 3), rotation=(math.pi / 2, 0, 0))
bpy.context.object.data.materials.append(emit("HaloM", (1, 0.85, 0.4), 25))
for k in range(9):  # god rays
    a = k * 0.7
    bpy.ops.mesh.primitive_cylinder_add(radius=3, depth=160, location=rb(math.cos(a) * 25, 70, GZ - 20 + math.sin(a) * 25), rotation=(0.25 * math.sin(a), 0.25 * math.cos(a), 0))
    r = bpy.context.object
    mm = emit(f"Ray{k}", (1, 0.9, 0.6), 1.2)
    mix = mm.node_tree.nodes.new("ShaderNodeMixShader")
    tr = mm.node_tree.nodes.new("ShaderNodeBsdfTransparent")
    mix.inputs[0].default_value = 0.12
    out = mm.node_tree.nodes["Material Output"]
    mm.node_tree.links.new(tr.outputs[0], mix.inputs[1])
    mm.node_tree.links.new(mm.node_tree.nodes["Emission"].outputs[0], mix.inputs[2])
    mm.node_tree.links.new(mix.outputs[0], out.inputs[0])
    r.data.materials.append(mm)

# foreground: glowing cue ball streaking down the felt, a rainbow prize ball, the legend cue
FELT = 5.4
bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=48, ring_count=24, location=rb(1.5, FELT + 1.0, 52))
cb = bpy.context.object
cb.data.materials.append(emit("CueBall", (1, 0.97, 0.9), 6))
for i in range(14):  # light trail
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.95 - i * 0.06, segments=24, ring_count=12, location=rb(1.5 - i * 0.05, FELT + 1.0, 52 - i * 1.4))
    bpy.context.object.data.materials.append(emit(f"Trail{i}", (1, 0.75 - i * 0.03, 0.3 + i * 0.03), 4 - i * 0.25))
bpy.ops.import_scene.fbx(filepath=os.path.join(E, "PrizeBall.fbx"))
pb = bpy.context.selected_objects[0]
pb.location, pb.scale = rb(-4.5, FELT + 1.9, 40), (2.6, 2.6, 2.6)
rainbow = bpy.data.materials.new("Rainbow")
rainbow.use_nodes = True
nt = rainbow.node_tree
grad = nt.nodes.new("ShaderNodeTexGradient")
ramp = nt.nodes.new("ShaderNodeValToRGB")
cols = [(1, 0.15, 0.2), (1, 0.8, 0.1), (0.2, 1, 0.4), (0.2, 0.5, 1), (0.8, 0.2, 1)]
ramp.color_ramp.elements[0].color = (*cols[0], 1)
ramp.color_ramp.elements[1].color = (*cols[-1], 1)
for i, c in enumerate(cols[1:-1], 1):
    e = ramp.color_ramp.elements.new(i / (len(cols) - 1))
    e.color = (*c, 1)
coord = nt.nodes.new("ShaderNodeTexCoord")
mapn = nt.nodes.new("ShaderNodeMapping")
mapn.inputs["Rotation"].default_value = (0.6, 0.3, 0.8)
nt.links.new(coord.outputs["Object"], mapn.inputs[0])
nt.links.new(mapn.outputs[0], grad.inputs[0])
nt.links.new(grad.outputs["Fac"], ramp.inputs[0])
bs = nt.nodes["Principled BSDF"]
nt.links.new(ramp.outputs["Color"], bs.inputs["Base Color"])
nt.links.new(ramp.outputs["Color"], bs.inputs["Emission Color"])
bs.inputs["Emission Strength"].default_value = 1.2
bs.inputs["Roughness"].default_value = 0.15
for s in pb.material_slots:
    s.material = rainbow
for k in range(24):  # sparkles around the prize
    a = k * 2 * math.pi / 24
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.12 + (k % 3) * 0.06, location=rb(-4.5 + math.cos(a) * 2.6, FELT + 1.9 + math.sin(a * 2) * 1.6, 40 + math.sin(a) * 2.6))
    bpy.context.object.data.materials.append(emit(f"Spark{k}", (1, 0.95, 0.7), 12))
bpy.ops.import_scene.fbx(filepath=os.path.join(E, "Cue.fbx"))
cue = bpy.context.selected_objects[0]
cue.location, cue.rotation_euler, cue.scale = rb(4.5, FELT + 2.5, 34), (math.radians(80), 0, math.radians(8)), (1.3, 1.3, 1.3)

gl = bpy.data.objects.new("GodLight", bpy.data.lights.new("GodLight", "AREA"))
gl.data.energy, gl.data.size, gl.data.color = 250000, 40, (1, 0.9, 0.7)
gl.location = rb(0, 60, GZ - 60)
gl.rotation_euler = (Vector(rb(0, 30, GZ)) - gl.location).to_track_quat("-Z", "Y").to_euler()
sc.collection.objects.link(gl)
# lights: warm lamps over every table, a cool fill, the world
for k in range(len(THEMES)):
    l = bpy.data.objects.new("L", bpy.data.lights.new("L", "AREA"))
    l.data.energy, l.data.size, l.data.color = 16000, 14, (1, 0.9, 0.75)
    l.location = rb(0, 17, 40 + k * 80)
    sc.collection.objects.link(l)
sun = bpy.data.objects.new("S", bpy.data.lights.new("S", "SUN"))
sun.data.energy, sun.data.color = 3.0, (1, 0.92, 0.8)
sun.rotation_euler = (math.radians(60), 0, math.radians(20))
sc.collection.objects.link(sun)
w = bpy.data.worlds.new("w")
sc.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (1.0, 0.72, 0.45, 1)  # golden heaven behind the god
w.node_tree.nodes["Background"].inputs[1].default_value = 1.4

cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.location = rb(3, 13, 14)
cam.rotation_euler = (Vector(rb(0, 15, 300)) - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 20
cam.data.dof.use_dof = True
cam.data.dof.focus_distance = 30
cam.data.dof.aperture_fstop = 5.6
sc.render.engine = "CYCLES"
sc.cycles.samples = 64
sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
sc.view_settings.view_transform = "AgX" if "AgX" in [i.identifier for i in sc.view_settings.bl_rna.properties["view_transform"].enum_items] else "Filmic"
sc.view_settings.look = "None"
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
