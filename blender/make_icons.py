"""HUD icons rendered from real 3D models (transparent PNG, 256x256) -> assets/icons/<name>.png.
Parts come from make_parts.py; coin, shop bag, clipboard and backpack are modelled here.
Every icon is fitted to its real silhouette (object fills ~88% of the canvas, 6% margin, never cropped) and lit bright
with lighter "icon" versions of the dark looks so the small HUD buttons stay readable.
Render only some icons:  python3 blender/make_icons.py --only teleport,garage   (or ICONS_ONLY=teleport,garage)."""
import math, os, runpy, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import bmesh  # after bpy (bmesh only exists once bpy is loaded)
from mathutils import Quaternion, Vector

saved = sys.argv
ONLY = os.environ.get("ICONS_ONLY", "")
if "--only" in saved:
    ONLY = saved[saved.index("--only") + 1]
ONLY = {n.strip() for n in ONLY.split(",") if n.strip()}
sys.argv = [saved[0]]
P = runpy.run_path(os.path.join(os.path.dirname(os.path.abspath(__file__)), "make_parts.py"))
sys.argv = saved
mc, finish, box, cyl, torus, cone = P["mc"], P["finish"], P["box"], P["cyl"], P["torus"], P["cone"]
X90, Y90 = P["X90"], P["Y90"]
# extra looks for the menu icons (P["LOOK"] is the same dict make_parts.M reads)
P["LOOK"].update({
    "White": ((0.92, 0.92, 0.9, 1), 0.0, 0.35), "Orange": ((1.0, 0.42, 0.05, 1), 0.0, 0.3),
    "Teal": ((0.05, 0.7, 0.65, 1), 0.3, 0.25), "Wood": ((0.45, 0.24, 0.1, 1), 0.0, 0.55),
    "Flame": ((1.0, 0.55, 0.1, 1), 0.0, 0.3), "Cream": ((0.95, 0.85, 0.65, 1), 0.0, 0.45),
})
VIEW = Vector((1.0, -1.25, 0.8)).normalized()
HVIEW = Vector((VIEW.x, VIEW.y, 0)).normalized()  # horizontal direction towards the camera
OUT = os.path.join(mc.ROOT, "assets", "icons")
os.makedirs(OUT, exist_ok=True)

roots = {r.name: r for r in P["roots"] if r.name.startswith("Part_")}
for r in P["roots"]:
    if not r.name.startswith("Part_"):
        r.hide_render = True
        for c in r.children:
            c.hide_render = True

# coin: thick gold disc, raised rim, embossed $ (S curve from boxes + bar)
g = {"Gold": [], "Copper": []}
g["Gold"].append(cyl((0, 0, 0), 1.6, 0.42, rot=X90, verts=64))  # face points along -X/+X
g["Gold"].append(torus((-0.2, 0, 0), 1.45, 0.1, rot=X90, seg=64))
for (z, w, y) in ((0.75, 1.0, 0), (0, 1.0, 0), (-0.75, 1.0, 0)):
    g["Copper"].append(box((-0.24, y, z), (0.08, w, 0.24)))
g["Copper"].append(box((-0.24, 0.42, 0.38), (0.08, 0.24, 0.75)))
g["Copper"].append(box((-0.24, -0.42, -0.38), (0.08, 0.24, 0.75)))
g["Copper"].append(box((-0.26, 0, 0), (0.08, 0.14, 2.1)))
roots["coin"] = finish("coin", g)

# shop: gold shopping bag with handles
g = {"Gold": [], "Dark": [], "Accent": []}
g["Gold"].append(box((0, 0, 1.2), (2.4, 1.2, 2.4), bev=0.12))
g["Accent"].append(box((0, -0.62, 1.6), (2.0, 0.06, 0.5)))
for s in (-1, 1):
    g["Dark"].append(torus((s * 0.55, 0, 2.5), 0.38, 0.07, rot=X90, seg=24, minor=8))
roots["shop"] = finish("shop", g)

# jobs: clipboard + paper lines + a wrench
g = {"Copper": [], "Chrome": [], "Dark": [], "Metal": []}
g["Copper"].append(box((0, 0, 1.4), (2.2, 0.15, 2.8), bev=0.1))
paper = box((0, -0.1, 1.3), (1.8, 0.05, 2.3))
g["Chrome"].append(paper)
for k in range(4):
    g["Dark"].append(box((0, -0.14, 2.0 - k * 0.42), (1.3, 0.03, 0.1)))
g["Metal"].append(box((0, -0.12, 2.8), (0.9, 0.2, 0.35), bev=0.05))
roots["jobs"] = finish("jobs", g)

# backpack
g = {"Accent": [], "Dark": [], "Metal": []}
g["Accent"].append(box((0, 0, 1.3), (2.0, 1.2, 2.6), bev=0.45))
g["Accent"].append(box((0, -0.72, 0.9), (1.5, 0.4, 1.1), bev=0.2))
g["Dark"].append(torus((0, 0, 2.7), 0.4, 0.08, rot=X90, seg=24, minor=8))
g["Metal"].append(box((0, -0.95, 1.25), (0.5, 0.05, 0.12)))
roots["backpack"] = finish("backpack", g)

# gift: box with a ribbon and bow
g = {"Accent": [], "Gold": []}
g["Accent"].append(box((0, 0, 1.0), (2.2, 2.2, 1.8), bev=0.12))
g["Accent"].append(box((0, 0, 2.05), (2.45, 2.45, 0.45), bev=0.1))
g["Gold"].append(box((0, 0, 1.15), (0.42, 2.3, 2.3)))
g["Gold"].append(box((0, 0, 1.15), (2.3, 0.42, 2.3)))
for s_ in (-1, 1):
    g["Gold"].append(torus((s_ * 0.45, 0, 2.55), 0.42, 0.14, rot=(math.pi / 2, 0, s_ * 0.5), seg=24, minor=8))
roots["gift"] = finish("gift", g)

# trade: two arrows in opposite directions
g = {"Blue": [], "Gold": []}
for s_, look in ((1, "Blue"), (-1, "Gold")):
    g[look].append(box((0, 0, 1.4 + s_ * 0.55), (2.2, 0.5, 0.5), bev=0.12))
    g[look].append(cone((s_ * 1.35, 0, 1.4 + s_ * 0.55), 0.55, 0.0, 0.8, rot=(0, s_ * math.pi / 2, 0), verts=4))
roots["trade"] = finish("trade", g)

# ---------------------------------------------------------------- menu icons
def sphere(loc, r, scale=(1, 1, 1), rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=r, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return o


def slab(pts_xz, y0, depth, name="s"):
    """polygon in the XZ plane extruded along +Y from y0 (front face looks at -Y)"""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    a = [bm.verts.new((x, y0, z)) for x, z in pts_xz]
    b = [bm.verts.new((x, y0 + depth, z)) for x, z in pts_xz]
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    n = len(a)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[j], a[i], b[i], b[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    return o


def arc_tube(R, r, a0, a1, z0=0.0):
    """part of a torus lying in the XZ plane (centre (0,0,z0)), angles in radians, CCW from +X"""
    t = torus((0, 0, z0), R, r, rot=(math.pi / 2, 0, 0), seg=72, minor=16)
    bm = bmesh.new()
    bm.from_mesh(t.data)
    kill = []
    for v in bm.verts:
        a = math.atan2(v.co.y, v.co.x) % (2 * math.pi)  # mesh is in local XY; the X90 object rotation maps local y -> world z
        if not (a0 <= a <= a1 or a0 <= a + 2 * math.pi <= a1):
            kill.append(v)
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(t.data)
    bm.free()
    return t


def face_camera(root, f):
    """turn the whole icon so its -Y face points (fraction f) towards the camera"""
    q = Vector((0, -1, 0)).rotation_difference(VIEW)
    root.rotation_euler = Quaternion().slerp(q, f).to_euler()


HW = math.atan2(HVIEW.x, -HVIEW.y)  # z rotation that turns the -Y axis towards the camera

# teleport: toy rocket leaning up-right, flame underneath
g = {"White": [], "Accent": [], "Blue": [], "Chrome": [], "Orange": [], "Gold": []}
g["White"].append(cyl((0, 0, 1.6), 0.7, 2.2, verts=48))
g["White"].append(sphere((0, 0, 0.5), 0.7, scale=(1, 1, 0.45)))
g["Accent"].append(cone((0, 0, 3.25), 0.72, 0.0, 1.1, verts=48))
g["Accent"].append(cyl((0, 0, 0.55), 0.74, 0.25, verts=48))
for k in range(3):
    a = HW + math.pi / 2 + k * 2 * math.pi / 3 + math.pi / 6
    g["Accent"].append(slab([(0.55, 0.0), (1.25, -0.35), (1.25, 0.45), (0.55, 1.35)], -0.09, 0.18))
    o = g["Accent"][-1]
    o.rotation_euler = (0, 0, a)
win = (HVIEW.x * 0.66, HVIEW.y * 0.66, 2.05)
g["Blue"].append(cyl(win, 0.34, 0.2, rot=(math.pi / 2, 0, HW), verts=32))
g["Chrome"].append(torus(win, 0.36, 0.08, rot=(math.pi / 2, 0, HW), seg=32, minor=10))
g["Orange"].append(cone((0, 0, -0.35), 0.0, 0.5, 1.2, verts=32))
g["Gold"].append(cone((0, 0, -0.05), 0.0, 0.3, 0.75, verts=24))
for o in g["Accent"][-3:]:
    bpy.context.view_layer.objects.active = o
    for x in bpy.context.selected_objects:
        x.select_set(False)
    o.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
roots["teleport"] = finish("teleport", g)
roots["teleport"].rotation_euler = Quaternion(-HVIEW, 0.55).to_euler()  # lean the nose to the upper right of the image

# garage: building with a roller door and a checkered flag on the roof
g = {"Cream": [], "Accent": [], "Metal": [], "Dark": [], "White": [], "Chrome": []}
g["Cream"].append(box((0, 0, 0.9), (2.6, 2.0, 1.8), bev=0.06))
g["Accent"].append(box((0, 0, 1.95), (2.9, 2.3, 0.3), bev=0.06))
g["Dark"].append(box((0, -0.96, 0.75), (1.9, 0.12, 1.5)))
g["Metal"].append(box((0, -1.02, 0.72), (1.76, 0.08, 1.4)))
for k in range(6):
    g["Chrome"].append(box((0, -1.07, 0.18 + k * 0.23), (1.76, 0.05, 0.05)))
g["Accent"].append(box((0, -1.05, 1.58), (2.0, 0.1, 0.2)))
g["Metal"].append(cyl((0.9, 0.3, 2.85), 0.06, 1.6, verts=12))
g["Gold"] = [sphere((0.9, 0.3, 3.68), 0.11)]
for i in range(4):
    for j in range(3):
        look = "White" if (i + j) % 2 == 0 else "Dark"
        g[look].append(box((0.9 - 0.2 - i * 0.3, 0.3, 3.45 - j * 0.3), (0.3, 0.08, 0.3)))
roots["garage"] = finish("garage", g)

# index: car collection album (cover facing the camera, pages on the side, gold car on the cover)
g = {"Blue": [], "White": [], "Gold": [], "Dark": []}
g["Blue"].append(box((0, 0, 1.4), (2.2, 0.16, 2.8), bev=0.06))
g["Blue"].append(box((0, 0.62, 1.4), (2.2, 0.16, 2.8), bev=0.06))
g["Blue"].append(box((-1.05, 0.31, 1.4), (0.2, 0.75, 2.8), bev=0.08))
g["White"].append(box((0.05, 0.31, 1.4), (2.05, 0.5, 2.62)))
g["Gold"].append(box((0, -0.09, 2.6), (1.8, 0.04, 0.12)))
g["Gold"].append(box((0, -0.09, 0.2), (1.8, 0.04, 0.12)))
car = [(-0.85, 1.05), (0.85, 1.05), (0.88, 1.4), (0.35, 1.48), (0.12, 1.85), (-0.45, 1.85), (-0.7, 1.48), (-0.88, 1.4)]
g["Gold"].append(slab(car, -0.2, 0.14))
for x in (-0.48, 0.48):
    g["Dark"].append(cyl((x, -0.16, 1.05), 0.24, 0.14, rot=Y90, verts=24))
    g["Gold"].append(cyl((x, -0.2, 1.05), 0.1, 0.12, rot=Y90, verts=16))
roots["index"] = finish("index", g)
face_camera(roots["index"], 0.35)

# rebirth: two chunky arrows chasing each other around a circle (gold + teal)
g = {"Gold": [], "Teal": []}
R, r = 1.25, 0.3
for look, a0 in (("Gold", math.radians(25)), ("Teal", math.radians(205))):
    a1 = a0 + math.radians(115)
    g[look].append(arc_tube(R, r, a0 - 0.02, a1))
    g[look].append(sphere((R * math.cos(a0), 0, R * math.sin(a0)), r))
    tx, tz = -math.sin(a1), math.cos(a1)
    head = cone((R * math.cos(a1) + tx * 0.32, 0, R * math.sin(a1) + tz * 0.32), 0.62, 0.0, 0.75, rot=(0, -a1, 0), verts=32)
    head.scale = (1, 0.55, 1)
    g[look].append(head)
roots["rebirth"] = finish("rebirth", g)
face_camera(roots["rebirth"], 0.8)

# settings: metal cog with a gold hub
g = {"Metal": [], "Gold": [], "Dark": []}
disc = cyl((0, 0, 0), 1.15, 0.5, rot=(math.pi / 2, 0, 0), verts=64)
mc.bevel(disc, 0.08, 3)  # bevelled edge so the smooth-shaded caps stay flat
g["Metal"].append(disc)
for k in range(8):
    a = k * math.pi / 4
    g["Metal"].append(box((math.cos(a) * 1.2, 0, math.sin(a) * 1.2), (0.6, 0.5, 0.5), bev=0.08, rot=(0, -a, 0)))
hub = cyl((0, -0.12, 0), 0.55, 0.5, rot=(math.pi / 2, 0, 0), verts=48)
mc.bevel(hub, 0.06, 3)
g["Gold"].append(hub)
g["Dark"].append(cyl((0, -0.2, 0), 0.24, 0.5, rot=(math.pi / 2, 0, 0), verts=32))
roots["settings"] = finish("settings", g)
face_camera(roots["settings"], 0.75)

# home: house with a red roof, door and windows
g = {"Cream": [], "Accent": [], "Wood": [], "Gold": [], "Blue": [], "White": []}
top = 1.6
g["Cream"].append(box((0, 0, top / 2), (2.2, 2.0, top), bev=0.04))
g["Cream"].append(mc.prism("gable", [(-1.0, top - 0.01), (1.0, top - 0.01), (0.0, top + 1.1)], -1.1, 2.2))
sl = math.atan2(1.1, 1.0)
L = math.hypot(1.0, 1.1) + 0.35
for s_ in (-1, 1):
    d = Vector((0, s_ * math.cos(sl), -math.sin(sl)))
    n = Vector((0, s_ * math.sin(sl), math.cos(sl)))
    c = Vector((0, s_ * 0.5, top + 0.55)) + n * 0.1 + d * 0.175
    g["Accent"].append(box(tuple(c), (2.6, L, 0.2), bev=0.04, rot=(-s_ * sl, 0, 0)))
g["Accent"].append(cyl((0, 0, top + 1.18), 0.13, 2.6, rot=X90, verts=16))
g["Accent"].append(box((-0.6, 0.45, top + 0.75), (0.35, 0.35, 0.9)))
g["Wood"].append(box((0.35, -1.0, 0.55), (0.6, 0.1, 1.1), bev=0.03))
g["Gold"].append(sphere((0.53, -1.07, 0.55), 0.06))
g["White"].append(box((-0.5, -1.0, 0.95), (0.62, 0.08, 0.62)))
g["Blue"].append(box((-0.5, -1.03, 0.95), (0.48, 0.08, 0.48)))
g["White"].append(box((1.1, 0.0, 0.95), (0.08, 0.62, 0.62)))
g["Blue"].append(box((1.13, 0.0, 0.95), (0.08, 0.48, 0.48)))
roots["home"] = finish("home", g)

# music: two beamed eighth notes
g = {"Blue": [], "Gold": []}
for x, zt in ((-0.75, 2.5), (0.75, 2.9)):
    g["Blue"].append(sphere((x - 0.32, 0, 0.0), 0.42, scale=(1.35, 0.8, 0.95), rot=(0, math.radians(25), 0)))
    g["Blue"].append(cyl((x + 0.17, 0, zt / 2), 0.1, zt, verts=16))
beam = slab([(-0.68, 2.25), (0.92, 2.65), (0.92, 3.05), (-0.68, 2.65)], -0.14, 0.28)
g["Gold"].append(beam)
g["Gold"].append(slab([(-0.68, 1.75), (0.92, 2.15), (0.92, 2.42), (-0.68, 2.02)], -0.14, 0.28))
roots["music"] = finish("music", g)
face_camera(roots["music"], 0.7)

# scene: transparent background, key + rim + fill
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 48
sc.cycles.use_denoising = True
sc.render.film_transparent = True
sc.render.resolution_x = sc.render.resolution_y = 256
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
sc.view_settings.view_transform = "Standard"
sc.view_settings.look = "Medium High Contrast"  # a touch of contrast = darker edges / soft rim around the bright faces
sc.view_settings.exposure = 0.0
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.85, 0.88, 0.95, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
sc.world = world

# icon-only material tweaks (nothing is exported from here): lift the near-black looks, saturate the colours
ICON_LOOK = {
    "Rubber": ((0.2, 0.2, 0.22, 1), 0.0, 0.32), "Dark": ((0.16, 0.17, 0.2, 1), 0.5, 0.35), "Carbon": ((0.16, 0.16, 0.18, 1), 0.3, 0.3),
    "Metal": ((0.75, 0.77, 0.8, 1), 0.85, 0.3), "Chrome": ((0.95, 0.96, 0.98, 1), 1.0, 0.12),
    "Accent": ((0.95, 0.07, 0.05, 1), 0.1, 0.3), "Blue": ((0.05, 0.35, 1.0, 1), 0.2, 0.25), "Green": ((0.05, 0.6, 0.2, 1), 0.0, 0.4),
    "Gold": ((1.0, 0.75, 0.15, 1), 1.0, 0.22), "Copper": ((0.9, 0.45, 0.2, 1), 1.0, 0.28),
}
for m in bpy.data.materials:
    look = m.name.split(".")[0]
    if look in ICON_LOOK and m.use_nodes:
        col, metal, rough = ICON_LOOK[look]
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = col
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rough


def light(name, kind, energy, loc, size=4):
    l = bpy.data.lights.new(name, kind)
    l.energy = energy
    if kind == "AREA":
        l.size = size
    o = bpy.data.objects.new(name, l)
    o.location = loc
    o.rotation_euler = (Vector((0, 0, 1)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(o)


light("key", "AREA", 1200, (6, -8, 9), 6)
light("rim", "AREA", 900, (-7, 6, 6), 4)
light("fill", "AREA", 400, (-6, -8, 2), 8)
light("top", "AREA", 250, (0, 0, 12), 10)
cam = bpy.data.cameras.new("cam")
cam.type = "ORTHO"
co = bpy.data.objects.new("cam", cam)
sc.collection.objects.link(co)
sc.camera = co

for r in roots.values():
    r.hide_render = True
    for c in r.children:
        c.hide_render = True

bpy.context.view_layer.update()
for name, r in roots.items():
    key = name.replace("Part_", "")
    if ONLY and key not in ONLY:
        continue
    for o in roots.values():
        for c in o.children:
            c.hide_render = o is not r
    pts = [c.matrix_world @ Vector(v) for c in r.children for v in c.bound_box]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    centre = (lo + hi) / 2
    ext = max(hi - lo)
    view = Vector((1.0, -1.25, 0.8)).normalized() if name not in ("coin",) else Vector((-1.0, -0.3, 0.2)).normalized()
    co.location = centre + view * (ext * 4)
    co.rotation_euler = (centre - co.location).to_track_quat("-Z", "Y").to_euler()
    # fit the real silhouette: long side = 88% of the frame (6% margin on each side), centred
    rot = co.rotation_euler.to_matrix()
    right, up = rot.col[0], rot.col[1]
    vs = [c.matrix_world @ v.co for c in r.children for v in c.data.vertices]
    xs, ys = [v.dot(right) for v in vs], [v.dot(up) for v in vs]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    co.location = co.location + right * (cx - co.location.dot(right)) + up * (cy - co.location.dot(up))
    cam.ortho_scale = max(max(xs) - min(xs), max(ys) - min(ys)) / 0.88
    sc.render.filepath = os.path.join(OUT, key + ".png")
    bpy.ops.render.render(write_still=True)
print("icons ok", sorted(ONLY) if ONLY else sorted(os.listdir(OUT)))
