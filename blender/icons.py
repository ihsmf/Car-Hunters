"""CUE HUNTERS shop icons (512x512): what the player gets, rendered in Blender on a transparent background.
    python3 blender/icons.py            -> blender/export/icons/<Key>_raw.png  (then tools/icon_text.py adds bg + text)
Keys: Cash2x, Luck2x, DragonCue, GoldStick, GoldenBall, Pack1, Pack2, Pack3."""
import bpy, math, os, random, sys
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
E = os.path.join(HERE, "export")
OUT = os.path.join(E, "icons")
os.makedirs(OUT, exist_ok=True)
R = random.Random(5)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgb, metal=0.0, rough=0.35, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    c = tuple((v / 255) ** 2.2 for v in rgb) + (1,)
    b.inputs["Base Color"].default_value = c
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = c
        b.inputs["Emission Strength"].default_value = emit
    return m


def obj_mat(o, m):
    o.data.materials.clear()
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def coin(loc, rot=(0, 0, 0), r=1.0, m=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=r, depth=0.22 * r, location=loc, rotation=rot)
    o = obj_mat(bpy.context.object, m)
    bev = o.modifiers.new("b", "BEVEL")
    bev.width, bev.segments = 0.05 * r, 3
    bpy.ops.mesh.primitive_torus_add(major_radius=0.72 * r, minor_radius=0.05 * r, location=loc, rotation=rot)
    obj_mat(bpy.context.object, m)  # embossed ring
    return o


def bill(loc, rot, m, band):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = (1.6, 0.8, 0.03)
    obj_mat(o, m)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.25, depth=0.07, location=loc, rotation=rot)
    obj_mat(bpy.context.object, band)


def sparkles(n, center, radius, m):
    for k in range(n):
        a, b = R.uniform(0, 6.28), R.uniform(-1, 1)
        p = Vector(center) + Vector((math.cos(a) * radius, b * radius * 0.7, math.sin(a) * radius * 0.6 + 0.3))
        bpy.ops.mesh.primitive_ico_sphere_add(radius=R.uniform(0.04, 0.1), subdivisions=1, location=p)
        obj_mat(bpy.context.object, m)


def gold():
    return mat("Gold", (255, 196, 60), 1.0, 0.22)


def import_fbx(name):
    bpy.ops.import_scene.fbx(filepath=os.path.join(E, name + ".fbx"))
    o = bpy.context.selected_objects[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return o


def fit(o, size):
    d = max(o.dimensions)
    o.scale = (size / d,) * 3
    bpy.context.view_layer.update()
    bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
    ctr = sum(bb, Vector()) / 8
    o.location -= ctr


# ---------- the offers ----------
def cash2x():
    G, green, band = gold(), mat("Bill", (70, 190, 90), 0, 0.5), mat("Band", (240, 250, 230), 0, 0.5)
    for k in range(9):  # coin stack + scattered coins
        coin((-0.6, 0.2, -1.1 + k * 0.23), (0, 0, k * 0.3), 1.0, G)
    for k, (x, y, z, rx) in enumerate(((0.9, -0.4, -1.0, 0.3), (1.3, 0.5, -0.9, -0.5), (0.2, -1.0, -0.95, 0.8))):
        coin((x, y, z), (rx, 0.2, k), 0.8, G)
    for k in range(3):
        bill((0.8, 0.3 - k * 0.12, -0.2 + k * 0.25), (0.25, -0.35, 0.4 + k * 0.25), green, band)
    sparkles(14, (0, 0, 0), 1.7, mat("Spark", (255, 250, 220), 0, 0.2, 8))


def luck2x():
    leaf, stem = mat("Leaf", (20, 150, 55), 0, 0.25), mat("Stem", (20, 100, 40), 0, 0.4)
    for k in range(4):  # four heart-shaped leaves
        a = k * math.pi / 2 + math.pi / 4
        for s in (-1, 1):
            c = Vector((math.cos(a) * 0.75 + math.cos(a + s * 0.5) * 0.35, math.sin(a) * 0.75 + math.sin(a + s * 0.5) * 0.35, 0.25))
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.55, segments=32, ring_count=16, location=c)
            o = bpy.context.object
            o.scale = (1, 1, 0.18)
            obj_mat(o, leaf)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.25, location=(0, 0, 0.3))
    obj_mat(bpy.context.object, stem)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.1, depth=1.6, location=(0.35, -0.75, -0.3), rotation=(0.9, 0.3, 0))
    obj_mat(bpy.context.object, stem)
    rainbow = [(255, 80, 80), (255, 200, 60), (90, 230, 120), (80, 160, 255), (200, 100, 255)]
    for k in range(20):
        a = k * 2 * math.pi / 20
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.08, subdivisions=2, location=(math.cos(a) * 1.85, math.sin(a) * 1.85, 0.3 + 0.3 * math.sin(a * 3)))
        obj_mat(bpy.context.object, mat(f"R{k}", rainbow[k % 5], 0, 0.2, 10))
    clover = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in clover:  # bigger and tilted up towards the camera
        o.location = o.location * 1.45
        o.scale = o.scale * 1.45
        o.location.z += 0.2
    piv = bpy.data.objects.new("Piv", None)
    bpy.context.scene.collection.objects.link(piv)
    for o in clover:
        o.parent = piv
    piv.rotation_euler = (math.radians(55), 0, 0)


def dragon_cue():
    cue = import_fbx("Cue")
    fit(cue, 4.6)
    cue.rotation_euler = (0, math.radians(55), math.radians(30))
    red, flame = mat("DragonRed", (200, 30, 30), 0.4, 0.3), mat("Flame", (255, 140, 30), 0, 0.3, 14)
    for s in cue.material_slots:
        s.material = red if s.name.lower().startswith(("shaft", "wrap", "body")) else s.material
    for k in range(26):  # flames licking along the cue
        t = k / 25
        p = Vector((-1.6 + 3.2 * t, 0, -1.6 + 3.2 * t * 0.9)) + Vector((R.uniform(-0.2, 0.2), R.uniform(-0.2, 0.2), R.uniform(0, 0.3)))
        bpy.ops.mesh.primitive_cone_add(radius1=0.2 + 0.15 * (1 - t), depth=0.7, location=p, rotation=(R.uniform(-0.3, 0.3), R.uniform(-0.3, 0.3), 0))
        obj_mat(bpy.context.object, flame if k % 3 else mat(f"F{k}", (255, 220, 80), 0, 0.3, 16))


def gold_stick():
    cue = import_fbx("Cue")
    fit(cue, 4.4)
    cue.rotation_euler = (0, math.radians(-50), math.radians(-20))
    G = gold()
    for s in cue.material_slots:
        s.material = G
    for k in range(7):  # coins rising
        coin((0.6 + R.uniform(-0.8, 0.8), R.uniform(-0.3, 0.3), -0.6 + k * 0.35), (1.2, 0.3 * k, 0), 0.45, G)
    sparkles(16, (0, 0, 0.4), 1.6, mat("Spark", (255, 245, 200), 0, 0.2, 9))


def golden_ball():
    b = import_fbx("PrizeBall")
    fit(b, 2.8)
    G = gold()
    white = mat("Spot", (255, 250, 235), 0, 0.3)
    for s in b.material_slots:
        s.material = white if "spot" in s.name.lower() else G
    for k in range(3):
        bpy.ops.mesh.primitive_torus_add(major_radius=1.9 + k * 0.25, minor_radius=0.03, location=(0, 0, 0), rotation=(1.2 + k * 0.3, 0.2 * k, 0))
        obj_mat(bpy.context.object, mat(f"Orbit{k}", (255, 220, 120), 0, 0.2, 8))
    sparkles(18, (0, 0, 0), 1.9, mat("Spark", (255, 250, 220), 0, 0.2, 10))


def pack(level):
    G = gold()
    if level == 1:  # a small pile
        for k in range(12):
            coin((R.uniform(-0.9, 0.9), R.uniform(-0.6, 0.6), -0.8 + (k // 4) * 0.3), (R.uniform(-0.5, 0.5), R.uniform(-0.5, 0.5), 0), 0.95, G)
        sparkles(10, (0, 0, -0.2), 1.6, mat("Spark", (255, 250, 220), 0, 0.2, 10))
    elif level == 2:  # a money bag
        bag = mat("Bag", (120, 70, 30), 0, 0.75)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1.2, segments=40, ring_count=24, location=(0, 0, -0.35))
        o = bpy.context.object
        o.scale = (1, 1, 1.05)
        obj_mat(o, bag)
        bpy.ops.mesh.primitive_cone_add(radius1=0.45, radius2=0.7, depth=0.7, location=(0, 0, 1.0))
        obj_mat(bpy.context.object, bag)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.45, minor_radius=0.08, location=(0, 0, 0.72))
        obj_mat(bpy.context.object, G)
        for k in range(6):
            coin((R.uniform(-1.2, 1.2), -1.0, -1.3 + R.uniform(0, 0.2)), (1.3, 0, R.uniform(0, 3)), 0.5, G)
        coin((0, -1.18, -0.3), (math.radians(80), 0, 0), 0.6, G)  # a big gold medallion on the bag
        for k in range(8):  # coins spilling from the top
            coin((R.uniform(-0.4, 0.4), R.uniform(-0.3, 0.3), 1.25 + k * 0.05), (R.uniform(-0.6, 0.6), R.uniform(-0.6, 0.6), 0), 0.35, G)
    else:  # a treasure chest overflowing with coins
        wood, iron = mat("Wood", (130, 70, 30), 0, 0.6), mat("Iron", (60, 60, 70), 0.8, 0.4)
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, -0.7))
        o = bpy.context.object
        o.scale = (2.6, 1.6, 1.2)
        obj_mat(o, wood)
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.8, depth=2.6, location=(0, 0.25, 0.1), rotation=(0, math.pi / 2, 0))
        lid = bpy.context.object
        lid.scale = (1, 1, 1)
        lid.rotation_euler = (math.radians(-35), math.pi / 2, 0)
        lid.location = (0, 0.9, 0.35)
        obj_mat(lid, wood)
        for x in (-1.0, 1.0):
            bpy.ops.mesh.primitive_cube_add(size=1, location=(x, 0, -0.7))
            o = bpy.context.object
            o.scale = (0.15, 1.65, 1.25)
            obj_mat(o, iron)
        for k in range(30):  # heap of coins
            coin((R.uniform(-1.1, 1.1), R.uniform(-0.6, 0.5), -0.05 + R.uniform(0, 0.6) * (1 - abs(R.uniform(-1, 1)) * 0.5)), (R.uniform(-0.8, 0.8), R.uniform(-0.8, 0.8), 0), 0.42, G)
        sparkles(16, (0, 0, 0.3), 1.9, mat("Spark", (255, 250, 220), 0, 0.2, 10))


ICONS = {"Cash2x": cash2x, "Luck2x": luck2x, "DragonCue": dragon_cue, "GoldStick": gold_stick, "GoldenBall": golden_ball,
         "Pack1": lambda: pack(1), "Pack2": lambda: pack(2), "Pack3": lambda: pack(3)}


def render(key):
    reset()
    ICONS[key]()
    sc = bpy.context.scene
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.9, 0.85, 1.0, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    for loc, e, col in (((4, -5, 6), 900, (1, 0.95, 0.85)), ((-5, -2, 3), 400, (0.7, 0.8, 1)), ((0, 5, 4), 700, (1, 0.8, 0.5))):
        l = bpy.data.objects.new("L", bpy.data.lights.new("L", "AREA"))
        l.data.energy, l.data.size, l.data.color = e, 4, col
        l.location = loc
        l.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(l)
    cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.location = (0, -8.5, 4.2)
    cam.rotation_euler = (Vector((0, 0, -0.05)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 50
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 64
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = 512
    sc.view_settings.view_transform = "Standard"
    sc.render.filepath = os.path.join(OUT, key + "_raw.png")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    for key in (sys.argv[1:] or ICONS):
        render(key)
        print("icon", key)
