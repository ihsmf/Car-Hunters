"""HUD icons rendered from real 3D models (transparent PNG, 256x256) -> assets/icons/<name>.png.
Parts come from make_parts.py; coin, shop bag, clipboard and backpack are modelled here."""
import math, os, runpy, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector

saved = sys.argv
sys.argv = [saved[0]]
P = runpy.run_path(os.path.join(os.path.dirname(os.path.abspath(__file__)), "make_parts.py"))
sys.argv = saved
mc, finish, box, cyl, torus, cone = P["mc"], P["finish"], P["box"], P["cyl"], P["torus"], P["cone"]
X90, Y90 = P["X90"], P["Y90"]
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
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.8, 0.9, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.7
sc.world = world


def light(name, kind, energy, loc, size=4):
    l = bpy.data.lights.new(name, kind)
    l.energy = energy
    if kind == "AREA":
        l.size = size
    o = bpy.data.objects.new(name, l)
    o.location = loc
    o.rotation_euler = (Vector((0, 0, 1)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(o)


light("key", "AREA", 900, (6, -8, 9), 6)
light("rim", "AREA", 700, (-7, 6, 6), 4)
light("fill", "AREA", 250, (-6, -8, 2), 8)
cam = bpy.data.cameras.new("cam")
cam.type = "ORTHO"
co = bpy.data.objects.new("cam", cam)
sc.collection.objects.link(co)
sc.camera = co

for r in roots.values():
    r.hide_render = True
    for c in r.children:
        c.hide_render = True

for name, r in roots.items():
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
    cam.ortho_scale = ext * (1.5 if name in ("gift", "trade") else 1.18)
    key = name.replace("Part_", "")
    sc.render.filepath = os.path.join(OUT, key + ".png")
    bpy.ops.render.render(write_still=True)
print("icons ok", sorted(os.listdir(OUT)))
