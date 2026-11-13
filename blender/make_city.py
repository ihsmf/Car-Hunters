"""City kit (Blender): street props + building archetypes for the districts.
One FBX per model in assets/city/, renders docs/renders/city.png, sizes merged into ModelSizes.lua.
Front of every model = Blender +Y (= Roblox -Z, the street side). 1 unit = 1 stud. Mesh names are looks:
Wall/Trim/Roof are recoloured per district in Luau; the rest use ModelLooks."""
import math, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
import make_cars as mc

OUT = os.path.join(mc.ROOT, "assets", "city")
os.makedirs(OUT, exist_ok=True)
mc.reset()

LOOK = {
    "Wall": ((0.85, 0.72, 0.55, 1), 0.0, 0.7), "Trim": ((0.95, 0.55, 0.15, 1), 0.0, 0.5), "Roof": ((0.55, 0.25, 0.2, 1), 0.0, 0.7),
    "Glass": ((0.35, 0.55, 0.75, 1), 0.2, 0.05), "Dark": ((0.08, 0.085, 0.1, 1), 0.3, 0.5), "Metal": ((0.6, 0.62, 0.66, 1), 0.9, 0.35),
    "White": ((0.95, 0.95, 0.94, 1), 0.0, 0.5), "Concrete": ((0.68, 0.66, 0.62, 1), 0.0, 0.85), "Wood": ((0.55, 0.36, 0.2, 1), 0.0, 0.7),
    "Leaf": ((0.25, 0.6, 0.25, 1), 0.0, 0.7), "Glow": ((1.0, 0.9, 0.7, 1), 0.0, 0.2), "Yellow": ((1.0, 0.78, 0.15, 1), 0.1, 0.4),
    "Accent": ((0.84, 0.12, 0.1, 1), 0.1, 0.4), "Blue": ((0.1, 0.45, 0.9, 1), 0.1, 0.4), "Green": ((0.15, 0.7, 0.3, 1), 0.0, 0.4),
    "Rubber": ((0.03, 0.03, 0.035, 1), 0.0, 0.85), "Brick": ((0.6, 0.28, 0.2, 1), 0.0, 0.85),
}


def M(look):
    c, metal, rough = LOOK[look]
    return mc.mat(look, c, metal=metal, rough=rough, emit=c if look == "Glow" else None)


def finish(name, g):
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    for look, objs in g.items():
        objs = [o for o in objs if o]
        if not objs:
            continue
        for o in objs:
            mc.set_mat(o, M(look))
        ob = mc.join(objs, look)
        for p in ob.data.polygons:
            p.use_smooth = look in ("Leaf", "Metal", "Rubber")
        ob.parent = root
    return root


class G(dict):
    def __missing__(self, k):
        self[k] = []
        return self[k]


def box(g, look, loc, size, bev=0.0, rot=(0, 0, 0)):
    b = mc.prim("box", "b", loc, size, rot=rot)
    if bev:
        mc.bevel(b, bev, 2)
    g[look].append(b)
    return b


def cyl(g, look, loc, r, h, rot=(0, 0, 0), verts=24):
    o = mc.prim("cyl", "c", loc, (2 * r, 2 * r, h), rot=rot, verts=verts)
    g[look].append(o)
    return o


def ball(g, look, loc, r, sx=1, sy=1, sz=1, seg=14):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r, location=loc)
    o = bpy.context.active_object
    o.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    g[look].append(o)
    return o


def windows(g, w, d, h, x0, floors_from=6, floor_h=4, cols=None, depth_front=True):
    """window rows on the front (+Y) face"""
    cols = cols or max(2, int(w / 6))
    fy = d / 2 + 0.05
    z = floors_from
    while z + 2.5 < h - 1:
        for i in range(cols):
            x = x0 - w / 2 + (i + 0.5) * w / cols
            box(g, "Glass", (x, fy, z + 1.2), (w / cols * 0.6, 0.12, 2.2))
            box(g, "White", (x, fy + 0.07, z + 0.05), (w / cols * 0.7, 0.3, 0.25))  # sill 0.16 before the glass
        z += floor_h


roots = []
X = [0]


def place(r):
    roots.append(r)


# ================================================================ street props
# Tree: trunk + three leaf clusters
g = G()
cyl(g, "Wood", (0, 0, 2.5), 0.55, 5, verts=10)
for (x, y, z, r) in ((0, 0, 7, 3.2), (1.6, 0.6, 6, 2.4), (-1.4, -0.8, 6.3, 2.5), (0.2, -1.4, 8.4, 2.1)):
    ball(g, "Leaf", (x, y, z), r)
place(finish("Tree", g))

# Palm: curved trunk + fronds
g = G()
for k in range(10):
    t = k / 9
    cyl(g, "Wood", (math.sin(t * 1.3) * 1.4, 0, 0.6 + k * 1.15), 0.45 - t * 0.12, 1.2, verts=10)
top = (math.sin(1.3) * 1.4, 0, 11.6)
for k in range(8):
    a = k / 8 * 2 * math.pi
    for j in range(4):
        dd = 1.0 + j * 1.25
        box(g, "Leaf", (top[0] + math.cos(a) * dd, math.sin(a) * dd, top[2] - (0, 0.28, 1.12, 2.2)[j]), (1.6, 0.9 - j * 0.12, 0.12), rot=(0, math.radians(18 + j * 10), a))
place(finish("Palm", g))

# Bush
g = G()
for (x, y, r) in ((0, 0, 1.8), (1.2, 0.3, 1.3), (-1.1, -0.2, 1.4)):
    ball(g, "Leaf", (x, y, r * 0.7), r, sz=0.75)
place(finish("Bush", g))

# Lamps (arm along +X like the procedural ones)
g = G()
cyl(g, "Dark", (0, 0, 0.4), 0.7, 0.8, verts=12)
cyl(g, "Dark", (0, 0, 6.45), 0.25, 11.9, verts=12)
box(g, "Dark", (2, 0, 12.3), (4.2, 0.35, 0.35), bev=0.1)
box(g, "Dark", (4, 0, 12.1), (2.2, 1.3, 0.6), bev=0.2)
box(g, "Glow", (4, 0, 11.75), (1.8, 1.0, 0.1))
place(finish("LampA", g))

g = G()
cyl(g, "Dark", (0, 0, 0.4), 0.8, 0.8, verts=12)
cyl(g, "Dark", (0, 0, 6.95), 0.3, 12.9, verts=12)
box(g, "Dark", (0, 0, 13.3), (0.35, 7.2, 0.35), bev=0.1)
for s in (-1, 1):
    box(g, "Dark", (0, s * 3.4, 13.1), (1.5, 1.5, 0.6), bev=0.2)
    box(g, "Glow", (0, s * 3.4, 12.75), (1.2, 1.2, 0.1))
place(finish("LampB", g))

g = G()
cyl(g, "Dark", (0, 0, 0.3), 0.6, 0.6, verts=12)
cyl(g, "Dark", (0, 0, 4.5), 0.22, 8.4, verts=12)
ball(g, "Glow", (0, 0, 9.4), 1.0)
cyl(g, "Dark", (0, 0, 10.5), 1.1, 0.35, verts=16)
place(finish("LampC", g))

# Traffic light with an arm over the road (+Y = towards traffic)
g = G()
cyl(g, "Dark", (0, 0, 5), 0.3, 10, verts=12)
box(g, "Dark", (0, 0.5, 10.6), (1.5, 1.3, 4.2), bev=0.15)
for i, look in enumerate(("Accent", "Yellow", "Green")):
    cyl(g, look, (0, 1.2, 12 - i * 1.3), 0.45, 0.2, rot=(math.pi / 2, 0, 0), verts=16)
    box(g, "Dark", (0, 1.35, 12.45 - i * 1.3), (1.1, 0.5, 0.12))
place(finish("TrafficLight", g))

# Bus stop (open front +Y)
g = G()
box(g, "Trim", (0, 0, 8), (10.4, 3.6, 0.5), bev=0.15)
box(g, "Glass", (0, -1.5, 4.6), (10, 0.2, 6))
for x in (-4.9, 4.9):
    box(g, "Dark", (x, -1.5, 3.95), (0.5, 0.5, 7.9))
box(g, "White", (0, -0.8, 2), (7, 1.4, 0.4), bev=0.1)
for x in (-3, 3):
    box(g, "Dark", (x, -0.8, 1), (0.3, 1.2, 1.9))
box(g, "Dark", (4.4, 1.6, 4), (0.2, 0.2, 8))
cyl(g, "Trim", (4.4, 1.6, 6.6), 0.9, 0.4, rot=(math.pi / 2, 0, 0))  # sign below the roof
place(finish("BusStop", g))

# Bin
g = G()
cyl(g, "Green", (0, 0, 1.4), 1.0, 2.6, verts=20)
cyl(g, "Dark", (0, 0, 2.8), 1.1, 0.3, verts=20)
place(finish("Bin", g))

# Jersey barrier
g = G()
mc_pts = [(-0.9, 0), (0.9, 0), (0.5, 0.6), (0.35, 1.7), (-0.35, 1.7), (-0.5, 0.6)]
pr = mc.prism("barrier", mc_pts, -3.5, 7)
g["Concrete"].append(pr)
# yellow stripe on the sloped front face ((0.5, 0.6) -> (0.35, 1.7)): 0.16 thick, front 0.06 proud, 0.1 short of the ends
_t = math.atan2(0.15, 1.1)
_fy = 0.5 - (1.25 - 0.6) / 1.1 * 0.15
box(g, "Yellow", (0, _fy - 0.02 * math.cos(_t), 1.25 - 0.02 * math.sin(_t)), (6.8, 0.16, 0.25), rot=(_t, 0, 0))
place(finish("Barrier", g))

# Barrel
g = G()
cyl(g, "Accent", (0, 0, 1.8), 1.4, 3.6, verts=24)
for z in (0.9, 2.7):
    cyl(g, "Dark", (0, 0, z), 1.52, 0.2, verts=24)
place(finish("Barrel", g))

# Pallet with crates
g = G()
for x in (-1.6, 0, 1.6):
    box(g, "Wood", (x, 0, 0.3), (0.5, 4.2, 0.6))
for y in (-1.6, -0.5, 0.5, 1.6):
    box(g, "Wood", (0, y, 0.68), (4.2, 0.8, 0.15))
box(g, "Wood", (-0.9, 0, 1.75), (2, 3.8, 2), bev=0.08)
box(g, "Blue", (1.1, -0.9, 1.55), (1.8, 1.8, 1.6), bev=0.08)
place(finish("Pallet", g))

# Shipping container (ribbed)
g = G()
box(g, "Trim", (0, 0, 2.15), (12, 5, 4.3))
for k in range(17):
    box(g, "Trim", (-5.7 + k * 0.72, 0, 2.15), (0.12, 5.2, 4.1))  # ribs 0.1 proud
box(g, "Dark", (0.045, 2.575, 2.15), (11.79, 0.25, 0.2))  # stripe front 0.1 before the ribs, ends clear of the end ribs
for x in (-6.04, 6.04):
    box(g, "Metal", (x, 0, 2.15), (0.12, 4.6, 4.0))  # doors 0.1 proud
place(finish("Container", g))

# Forklift (forks to +Y)
g = G()
box(g, "Yellow", (0, -0.5, 1.6), (3.2, 4.2, 1.8), bev=0.25)
box(g, "Dark", (0, -1.8, 1.3), (3.0, 1.4, 1.6), bev=0.15)
for x in (-1.4, 1.4):
    box(g, "Dark", (x, 0.2, 3.6), (0.15, 0.15, 3.6))
    box(g, "Dark", (x, -1.8, 3.6), (0.15, 0.15, 3.6))
box(g, "Dark", (0, -0.8, 5.45), (3.0, 2.3, 0.15))
for x in (-1.2, 1.2):
    box(g, "Metal", (x, 1.95, 2.65), (0.2, 0.2, 5.1))
    box(g, "Metal", (x, 3.25, 0.3), (0.35, 2.6, 0.12))
for x in (-1.7, 1.7):
    for y in (-1.6, 0.9):
        cyl(g, "Rubber", (x, y, 0.65), 0.65, 0.5, rot=(0, math.pi / 2, 0), verts=16)
place(finish("Forklift", g))

# Kiosk (window to +Y)
g = G()
box(g, "Wall", (0, 0, 3.5), (7, 6, 7), bev=0.1)
box(g, "Trim", (0, 0, 7.3), (8.4, 7.4, 0.6), bev=0.1)
box(g, "Glass", (0, 3.02, 4.4), (5, 0.2, 2.6))  # front 0.12 proud
box(g, "White", (0, 3.4, 3.0), (5.6, 0.8, 0.2))
for k in range(6):
    box(g, "Accent" if k % 2 == 0 else "White", (-2.5 + k, 2.9 + 0.8 * math.cos(math.radians(25)), 6.2), (1.0, 1.6, 0.1), rot=(math.radians(-25), 0, 0))
place(finish("Kiosk", g))

# Flower bed
g = G()
box(g, "Concrete", (0, 0, 0.5), (8, 5, 1), bev=0.1)
box(g, "Leaf", (0, 0, 1.05), (7.2, 4.2, 0.2))
cols = ("Accent", "Yellow", "White", "Blue")
for i in range(6):
    for j in range(3):
        ball(g, cols[(i + j) % 4], (-3 + i * 1.2, -1.3 + j * 1.3, 1.5), 0.42)
place(finish("FlowerBed", g))

# ================================================================ buildings (footprint W x D, front +Y)
def base_box(g, w, d, h, look="Wall"):
    box(g, look, (0, 0, h / 2), (w, d, h))
    box(g, "Concrete", (0, 0, 0.4), (w + 0.4, d + 0.4, 0.8))


# Shop: storefront, awning, upper windows, parapet
g = G(); w, d, h = 30, 24, 13
base_box(g, w, d, h)
box(g, "Trim", (0, 0, h + 0.4), (w + 1, d + 1, 0.8))
box(g, "Glass", (-2, d / 2 + 0.05, 2.7), (w * 0.62, 0.15, 3.6))
for i in range(4):
    box(g, "White", (-2 - w * 0.31 + i * w * 0.62 / 3, d / 2 + 0.15, 2.7), (0.3, 0.3, 3.8))
box(g, "Dark", (w * 0.36, d / 2 + 0.15, 2.3), (3, 0.3, 4.6))  # door, 0.1 before the plinth
for k in range(10):
    box(g, "Trim" if k % 2 == 0 else "White", (-w * 0.45 + (k + 0.5) * w * 0.09, d / 2 + 1.6, 5.3), (w * 0.09, 3.2, 0.25), rot=(math.radians(-15), 0, 0))
windows(g, w, d, h, 0, floors_from=7.5, cols=5)
box(g, "Dark", (0, d / 2 + 0.15, h - 1.8), (w * 0.6, 0.5, 2.2))  # sign board (text in Luau), 0.1 into the wall
box(g, "Metal", (w / 4, 0, h + 1.6), (3.4, 3.4, 1.6))
place(finish("B_shop", g))

# Cafe: terrace, striped awning, tables
g = G(); w, d, h = 26, 22, 9
base_box(g, w, d, h)
box(g, "Roof", (0, 0, h + 0.3), (w + 0.6, d + 0.6, 0.6))
box(g, "Glass", (0, d / 2 + 0.05, 3), (w * 0.75, 0.15, 3.8))
for k in range(12):
    box(g, "Accent" if k % 2 == 0 else "White", (-w * 0.48 + (k + 0.5) * w * 0.08, d / 2 + 2.2, 5.6), (w * 0.08, 4.2, 0.2), rot=(math.radians(-18), 0, 0))
for x in (-7, 0, 7):
    cyl(g, "White", (x, d / 2 + 4.5, 1.6), 1.0, 0.15)
    cyl(g, "Dark", (x, d / 2 + 4.5, 0.775), 0.12, 1.55, verts=8)
    cyl(g, "Accent", (x, d / 2 + 4.5, 4.2), 1.8, 0.15, verts=16)
    cyl(g, "White", (x, d / 2 + 4.5, 2.885), 0.06, 2.57, verts=6)
box(g, "Dark", (0, d / 2 + 0.15, h - 1.4), (w * 0.5, 0.5, 1.8))  # sign board, 0.1 into the wall
place(finish("B_cafe", g))

# House: pitched roof, porch, chimney
g = G(); w, d, h = 24, 20, 9
base_box(g, w, d, h)
roof = mc.prism("roof", [(-d / 2 - 1, 0), (d / 2 + 1, 0), (0, 7)], -w / 2 - 0.8, w + 1.6)
roof.location.z = h
bpy.context.view_layer.objects.active = roof
g["Roof"].append(roof)
box(g, "Brick", (w / 4, -d / 6, h + 6), (2, 2, 6))
box(g, "Wood", (0, d / 2 + 2, 0.45), (10, 4, 0.9))  # porch deck on the ground, top 0.1 above the plinth
for x in (-4.6, 4.6):
    box(g, "White", (x, d / 2 + 3.7, 2.4), (0.4, 0.4, 4))
box(g, "Roof", (0, d / 2 + 2.2, 4.6), (11, 4.8, 0.4), rot=(math.radians(-10), 0, 0))
box(g, "Wood", (0, d / 2 + 0.15, 2.2), (2.4, 0.3, 4.2))
for x in (-6.5, 6.5):
    box(g, "Glass", (x, d / 2 + 0.05, 4), (3.4, 0.12, 2.6))
    box(g, "White", (x, d / 2 + 0.1, 2.6), (4, 0.25, 0.3))
place(finish("B_house", g))

# Apartment: 6 floors, balconies
g = G(); w, d, h = 30, 24, 26
base_box(g, w, d, h)
box(g, "Trim", (0, 0, h + 0.5), (w + 0.8, d + 0.8, 1))
z = 4
while z < h - 3:
    for i in range(4):
        x = -w / 2 + (i + 0.5) * w / 4
        box(g, "Glass", (x, d / 2 + 0.05, z + 1.4), (3.6, 0.12, 2.6))
        if (i + int(z)) % 2 == 0:
            box(g, "White", (x, d / 2 + 1.0, z), (4.6, 2.0, 0.3))
            box(g, "Metal", (x, d / 2 + 1.85, z + 0.6), (4.4, 0.1, 1.1))
    z += 4
box(g, "Dark", (0, d / 2 + 0.15, 2), (4, 0.3, 3.6))
for k in range(3):
    box(g, "Metal", (-w / 3 + k * w / 3, 0, h + 1.6), (2.2, 2.2, 1.6))
place(finish("B_apartment", g))

# Tower: glass office, mullions, crown
g = G(); w, d, h = 28, 24, 44
box(g, "Glass", (0, 0, h / 2), (w, d, h))
box(g, "Concrete", (0, 0, 2), (w + 0.6, d + 0.6, 4))
for i in range(8):
    x = -w / 2 + (i + 0.5) * w / 8
    box(g, "Metal", (x, d / 2 + 0.2, h / 2), (0.35, 0.4, h - 2))
    box(g, "Metal", (x, -d / 2 - 0.2, h / 2), (0.35, 0.4, h - 2))
for zz in range(6, int(h), 6):
    box(g, "Metal", (0, 0, zz), (w + 0.25, d + 0.25, 0.4))
box(g, "Trim", (0, 0, h + 1.2), (w - 4, d - 4, 2.4))
place(finish("B_tower", g))

# Dealership: glass showroom with a big flat canopy
g = G(); w, d, h = 40, 26, 9
box(g, "Glass", (0, 2, (h + 0.1) / 2), (w - 4, d - 6, h + 0.1))
box(g, "Wall", (0, -d / 2 + 3, h / 2), (w, 6, h))
box(g, "Trim", (0, 0, h + 0.5), (w + 2, d + 2, 1))
for x in range(-16, 17, 8):
    box(g, "Metal", (x, d / 2 - 1, h / 2), (0.5, 0.5, h))
box(g, "Concrete", (0, 0, 0.3), (w + 2, d + 2, 0.6))
box(g, "Dark", (0, d / 2 + 1, h + 2.2), (w * 0.5, 0.5, 2.6))
place(finish("B_dealership", g))

# Garage: two roller doors
g = G(); w, d, h = 28, 22, 9
base_box(g, w, d, h)
box(g, "Roof", (0, 0, h + 0.4), (w + 0.8, d + 0.8, 0.8))
for x in (-6.5, 6.5):
    box(g, "Metal", (x, d / 2 + 0.15, 3), (9, 0.3, 6))  # front 0.1 before the plinth
    for k in range(10):
        box(g, "Dark", (x, d / 2 + 0.32, 0.3 + k * 0.6), (8.8, 0.2, 0.08))  # slats 0.12 proud
box(g, "Yellow", (0, d / 2 + 0.05, 6.6), (w - 2, 0.3, 0.6))  # 0.1 into the wall, 0.2 proud
place(finish("B_garage", g))

# Gas station: canopy on columns, pumps, small shop at the back
g = G(); w, d, h = 44, 30, 8
box(g, "Wall", (0, -d / 2 + 4.05, 4), (w * 0.5, 7.9, 8))  # back 0.1 inside the forecourt slab edge
box(g, "Glass", (0, -d / 2 + 8.05, 3), (w * 0.4, 0.12, 3.6))
box(g, "Trim", (0, 4, h + 0.6), (w * 0.8, 14, 1.2), bev=0.2)
box(g, "White", (0, 4, h + 1.35), (w * 0.82, 14.2, 0.3))
for x in (-12, 0, 12):
    box(g, "White", (x, 4, h / 2), (1, 1, h))
    for s in (-1, 1):
        box(g, "Trim", (x + s * 3.5, 4, 1.5), (1.4, 1.0, 3), bev=0.1)
        box(g, "Dark", (x + s * 3.5, 4.52, 2.2), (0.9, 0.2, 0.8))  # screen 0.12 proud
box(g, "Concrete", (0, 0, 0.15), (w, d, 0.3))
place(finish("B_gasstation", g))

# Motel: two floors, open walkway, doors
g = G(); w, d, h = 46, 14, 10
base_box(g, w, d, h)
box(g, "Roof", (0, 0, h + 0.4), (w + 1, d + 3, 0.8))
box(g, "Concrete", (0, d / 2 + 1.4, 5), (w, 2.8, 0.4))
for x in range(-20, 21, 5):
    for zz in (0, 5):
        box(g, "Trim", (x, d / 2 + 0.15, zz + 2.1), (1.8, 0.3, 3.6))  # doors 0.1 before the plinth
        box(g, "Glass", (x + 2.1, d / 2 + 0.06, zz + 2.6), (1.6, 0.12, 1.4))
box(g, "Metal", (0, d / 2 + 2.75, 6.2), (w, 0.1, 1))
for x in [-22.7] + [-16.5 + 5 * i for i in range(8)] + [22.7]:  # posts (between the rooms): ground -> 0.1 above the rail
    box(g, "Metal", (x, d / 2 + 2.75, 3.4), (0.3, 0.3, 6.8))
place(finish("B_motel", g))

# Warehouse: ribbed metal, big door
g = G(); w, d, h = 44, 30, 14
box(g, "Wall", (0, 0, h / 2), (w, d, h))
for k in range(int(w / 2)):
    box(g, "Wall", (-w / 2 + 1 + k * 2, d / 2 + 0.1, h / 2), (0.25, 0.25, h))
box(g, "Roof", (0, 0, h + 0.6), (w + 1, d + 1, 1.2))
box(g, "Metal", (0, d / 2 + 0.25, 4.5), (w * 0.4, 0.3, 9))  # 0.175 before the ribs
box(g, "Yellow", (0, d / 2 + 0.25, 9.4), (w * 0.4, 0.5, 0.8))
place(finish("B_warehouse", g))

# Silo: two tall cylinders + catwalk
g = G(); w, d, h = 28, 16, 26
for x in (-6.5, 6.5):
    cyl(g, "Metal", (x, 0, h / 2), 6, h, verts=32)
    for zz in range(4, int(h), 5):
        cyl(g, "Dark", (x, 0, zz), 6.1, 0.3, verts=32)
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=6.2, radius2=0.6, depth=4, location=(x, 0, h + 2))
    g["Roof"].append(bpy.context.active_object)
box(g, "Dark", (0, 0, h - 2.5), (8, 1.2, 0.3))
place(finish("B_silo", g))

# Factory: sawtooth roof + chimney
g = G(); w, d, h = 40, 28, 14
box(g, "Brick", (0, 0, h / 2), (w, d, h))
for k in range(5):
    tooth = mc.prism("saw", [(-d / 2, 0), (d / 2, 0), (d / 2, 4)], -w / 2 + k * w / 5, w / 5 - 0.2)
    tooth.location.z = h
    tooth.rotation_euler = (0, 0, 0)
    g["Roof"].append(tooth)
cyl(g, "Brick", (w / 3, -d / 4, h + 9), 1.6, 18, verts=16)
cyl(g, "Dark", (w / 3, -d / 4, h + 18.2), 1.75, 0.6, verts=16)
for i in range(4):
    box(g, "Glass", (-w * 0.36 + i * w * 0.24, d / 2 + 0.05, h * 0.55), (w * 0.16, 0.12, 4))
box(g, "Metal", (0, d / 2 + 0.15, 3.5), (8, 0.4, 7))
place(finish("B_factory", g))

# Night tower: dark tower with light strips
g = G(); w, d, h = 26, 24, 48
box(g, "Dark", (0, 0, h / 2), (w, d, h))
for zz in range(4, int(h), 4):
    box(g, "Glass", (0, d / 2 + 0.05, zz), (w - 3, 0.12, 2.2))
for s in (-1, 1):
    box(g, "Glow", (s * (w / 2 + 0.05), d / 2 - 0.5, h / 2), (0.15, 0.6, h - 4))
box(g, "Trim", (0, 0, h + 0.8), (w + 0.6, d + 0.6, 1.6))
place(finish("B_neontower", g))

# Club: box with a marquee
g = G(); w, d, h = 34, 24, 11
base_box(g, w, d, h, look="Dark")
box(g, "Trim", (0, d / 2 + 2, 7.5), (w * 0.7, 4, 1.4), bev=0.2)
for k in range(14):
    ball(g, "Glow", (-w * 0.33 + k * w * 0.66 / 13, d / 2 + 4, 7.5), 0.25)
box(g, "Dark", (0, d / 2 + 0.15, 2.6), (4.4, 0.3, 5))  # door 0.1 before the plinth
box(g, "Accent", (0, d / 2 + 2.6, 0.075), (5, 5, 0.15))  # red carpet on the ground, 0.15 thick
place(finish("B_club", g))

# ================================================================ export + sizes
for r in roots:
    r.location = (0, 0, 0)
tris = {}
for r in roots:
    mc.export([r], os.path.join(OUT, r.name + ".fbx"))
    tris[r.name] = mc.triangles(r)
print("city ok", len(roots), "models; max tris", max(tris.values()))

sizes_path = os.path.join(mc.ROOT, "src", "ReplicatedStorage", "Shared", "ModelSizes.lua")
existing = open(sizes_path).read() if os.path.exists(sizes_path) else ""
entries = dict(re.findall(r"\n\t(\w+) = (\{ size = .*? \} \}),", existing))
for r in roots:
    pts = [c.matrix_world @ Vector(v) for c in r.children for v in c.bound_box]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    ext = max(hi[i] - lo[i] for i in range(3))
    cx, cy, cz = [(lo[i] + hi[i]) / 2 for i in range(3)]
    fw, fd = hi[0] - lo[0], hi[1] - lo[1]
    entries[r.name] = f"{{ size = {ext:.2f}, c = {{ {cx:.2f}, {cz:.2f}, {-cy:.2f} }}, w = {fw:.2f}, d = {fd:.2f} }}"
lines = ["-- generated by blender/make_spawn.py + make_city.py: longest side (studs), bounding-box centre relative to the",
         "-- model origin in Roblox axes (x, up, z), footprint w/d. ModelService puts the pivot back on the Blender origin.", "return {"]
for k in sorted(entries):
    lines.append(f"\t{k} = {entries[k]},")
lines.append("}")
open(sizes_path, "w").write("\n".join(lines) + "\n")

if "--render" in sys.argv:
    sc, cam, co = mc.setup_scene(1800, 1100)
    cols = 8
    xs = 0
    for i, r in enumerate(roots):
        r.location = ((i % cols) * 50 - 175, -(i // cols) * 55, 0)
    co.location = (60, 170, 120)  # look at the fronts (+Y)
    co.rotation_euler = (Vector((0, -70, 0)) - co.location).to_track_quat("-Z", "Y").to_euler()
    cam.lens = 32
    sc.render.filepath = os.path.join(mc.ROOT, "docs", "renders", "city.png")
    bpy.ops.render.render(write_still=True)
