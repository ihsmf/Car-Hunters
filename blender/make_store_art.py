"""Game icon + store thumbnails for the Roblox game page, rendered from the Blender car models.
  python3 blender/make_store_art.py         -> docs/store/icon_raw.png (1024x1024), thumb_<n>_raw.png (1920x1080)
Text is added afterwards by tools/store_art_text.py (PIL)."""
import math, os
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CARS = os.path.join(ROOT, "assets", "cars")
OUT = os.path.join(ROOT, "docs", "store")
os.makedirs(OUT, exist_ok=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 64
    sc.cycles.use_denoising = True
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Punchy"
    return sc


def world(sc, top, horizon, strength=1.0):
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    nt = w.node_tree
    bg = nt.nodes["Background"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = horizon
    ramp.color_ramp.elements[1].position = 0.45
    ramp.color_ramp.elements[1].color = top
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = strength
    sc.world = w


def floor(color=(0.05, 0.055, 0.07, 1), rough=0.32):
    bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, 0))
    o = bpy.context.active_object
    m = bpy.data.materials.new("Floor")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = color
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = 0.2
    o.data.materials.append(m)


def light(name, energy, loc, size, color=(1, 1, 1)):
    l = bpy.data.lights.new(name, "AREA")
    l.energy, l.size, l.color = energy, size, color
    o = bpy.data.objects.new(name, l)
    o.location = loc
    o.rotation_euler = (Vector((0, 0, 0.8)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(o)


def car(name, loc, yaw, length=4.6, folder=CARS):
    """yaw = direction the car's nose points, degrees (0 = +X): imported models face +X"""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(folder, name + ".fbx"))
    objs = [o for o in bpy.data.objects if o not in before]
    root = bpy.data.objects.new(name + "_root", None)
    bpy.context.scene.collection.objects.link(root)
    for o in objs:
        if o.parent is None:
            o.parent = root
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objs if o.type == "MESH" for c in o.bound_box]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    s = length / max(hi.x - lo.x, hi.y - lo.y) if length else 1.0
    root.scale = (s, s, s)
    centre = (lo + hi) / 2
    root.location = Vector(loc) - Vector((centre.x, centre.y, lo.z)) * s
    # rotate around the car's own centre
    pivot = bpy.data.objects.new(name + "_pivot", None)
    bpy.context.scene.collection.objects.link(pivot)
    pivot.location = loc
    root.location = root.location - Vector(loc)
    root.parent = pivot
    pivot.rotation_euler = (0, 0, math.radians(yaw))
    return pivot


CITY = os.path.join(ROOT, "assets", "city")


def skyline(y0, spread, n=9):
    """city-kit buildings far behind the cars, out of focus"""
    names = ["B_tower", "B_apartment", "B_neontower", "B_tower", "B_shop", "B_apartment", "B_tower", "B_dealership", "B_neontower"]
    for i in range(n):
        x = -spread + 2 * spread * i / (n - 1)
        car(names[i % len(names)], (x, y0 + (i % 3) * 6, 0), 90 + (i * 37) % 30, length=10 + (i * 7) % 6, folder=CITY)


def camera(sc, loc, target, lens):
    cam = bpy.data.cameras.new("cam")
    cam.lens = lens
    cam.dof.use_dof = True
    cam.dof.aperture_fstop = 4.0
    co = bpy.data.objects.new("cam", cam)
    sc.collection.objects.link(co)
    co.location = loc
    co.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam.dof.focus_distance = (Vector(target) - Vector(loc)).length
    sc.camera = co


def render(sc, path, rx, ry):
    sc.render.resolution_x, sc.render.resolution_y = rx, ry
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


# 1) icon: hero supercar head-on, 3/4 view, warm sunset
sc = reset()
world(sc, (0.03, 0.04, 0.14, 1), (0.95, 0.42, 0.12, 1), 1.0)
floor()
skyline(40, 40, 7)
car("lamborgini_hurakan", (0, 0, 0), 280)
light("key", 1600, (5, -6, 6), 5, (1.0, 0.85, 0.7))
light("rim", 2200, (-5, 6, 4), 6, (0.4, 0.6, 1.0))
light("top", 500, (0, 0, 9), 8)
camera(sc, (5.4, -5.0, 1.5), (0, 0, 0.7), 50)
render(sc, os.path.join(OUT, "icon_raw.png"), 1024, 1024)

# 2) thumbnail 1: line-up of three rarities
sc = reset()
world(sc, (0.03, 0.04, 0.14, 1), (0.95, 0.4, 0.15, 1), 1.0)
floor()
skyline(45, 60, 9)
car("furd_mustank", (-5.4, 1.4, 0), 305)
car("lamborgini_hurakan", (0, 0, 0), 255)
car("bugati_shiron", (5.4, 1.4, 0), 235)
light("key", 2600, (6, -8, 7), 8, (1.0, 0.85, 0.7))
light("rim", 3000, (-6, 8, 5), 8, (0.4, 0.6, 1.0))
light("top", 900, (0, 0, 10), 12)
camera(sc, (0, -13.5, 2.4), (0, 0.6, 0.9), 40)
render(sc, os.path.join(OUT, "thumb_1_raw.png"), 1920, 1080)

# 3) thumbnail 2: low close-up of a legendary on a dark showroom floor, cool blue
sc = reset()
world(sc, (0.02, 0.03, 0.08, 1), (0.15, 0.35, 0.9, 1), 1.0)
floor((0.03, 0.03, 0.04, 1), 0.08)
skyline(40, 50, 7)
car("ferarri_laferarri", (0, 0, 0), 205)
light("key", 2000, (-5, -5, 5), 6, (0.9, 0.95, 1.0))
light("rim", 2600, (5, 5, 3), 6, (1.0, 0.35, 0.25))
camera(sc, (-4.6, -4.4, 0.8), (0, 0, 0.6), 35)
render(sc, os.path.join(OUT, "thumb_2_raw.png"), 1920, 1080)
print("store art ok")
