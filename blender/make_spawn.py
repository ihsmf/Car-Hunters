"""Spawn / safe-zone models (Blender). One FBX per model in assets/spawn/, render docs/renders/spawn.png.
Sizes are in studs (1 Blender unit = 1 stud). Meshes are named by look (Metal, Chrome, Dark, Accent, Gold, Glow, White,
Marble, Glass, Water, Leaf, Wood, Rubber, Yellow, Blue, Concrete); ModelService styles them in Roblox.
Text/screens are added in Luau (SurfaceGuis need plain parts), the models only carry the geometry."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import make_cars as mc

OUT = os.path.join(mc.ROOT, "assets", "spawn")
os.makedirs(OUT, exist_ok=True)
mc.reset()

LOOK = {
    "Metal": ((0.55, 0.57, 0.6, 1), 0.9, 0.35), "Chrome": ((0.92, 0.93, 0.95, 1), 1.0, 0.08),
    "Dark": ((0.07, 0.075, 0.09, 1), 0.4, 0.45), "Accent": ((0.84, 0.12, 0.1, 1), 0.1, 0.35),
    "Gold": ((1.0, 0.74, 0.22, 1), 1.0, 0.18), "Glow": ((1.0, 0.92, 0.7, 1), 0.0, 0.2),
    "White": ((0.95, 0.95, 0.94, 1), 0.0, 0.4), "Marble": ((0.93, 0.91, 0.88, 1), 0.0, 0.15),
    "Glass": ((0.55, 0.75, 0.9, 1), 0.0, 0.05), "Water": ((0.2, 0.55, 0.85, 1), 0.0, 0.05),
    "Leaf": ((0.2, 0.55, 0.2, 1), 0.0, 0.6), "Wood": ((0.55, 0.36, 0.2, 1), 0.0, 0.6),
    "Rubber": ((0.03, 0.03, 0.035, 1), 0.0, 0.85), "Yellow": ((1.0, 0.78, 0.15, 1), 0.1, 0.4),
    "Blue": ((0.1, 0.45, 0.9, 1), 0.1, 0.35), "Concrete": ((0.62, 0.61, 0.58, 1), 0.0, 0.8),
    "Green": ((0.15, 0.75, 0.3, 1), 0.0, 0.3),
}


def M(look):
    c, metal, rough = LOOK[look]
    return mc.mat(look, c, metal=metal, rough=rough, emit=c if look == "Glow" else None)


def finish(name, groups):
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    for look, objs in groups.items():
        objs = [o for o in objs if o]
        if not objs:
            continue
        for o in objs:
            mc.set_mat(o, M(look))
        ob = mc.join(objs, look)
        for p in ob.data.polygons:
            p.use_smooth = True
        ob.parent = root
    return root


def G(*looks):
    return {k: [] for k in looks}


def box(loc, size, bev=0.0, rot=(0, 0, 0)):
    b = mc.prim("box", "b", loc, size, rot=rot)
    if bev:
        mc.bevel(b, bev, 2)
    return b


def cyl(loc, r, h, rot=(0, 0, 0), verts=32):
    return mc.prim("cyl", "c", loc, (2 * r, 2 * r, h), rot=rot, verts=verts)


def sphere(loc, r, seg=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=loc)
    return bpy.context.active_object


def torus(loc, R, r, rot=(0, 0, 0), seg=48, minor=12):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=seg, minor_segments=minor, location=loc, rotation=rot)
    return bpy.context.active_object


def cone(loc, r1, r2, h, rot=(0, 0, 0), verts=32):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=h, location=loc, rotation=rot)
    return bpy.context.active_object


def beam(g, look, a, b, r=0.18, verts=8):
    """cylinder from point a to point b"""
    ax, ay, az = a
    bx, by, bz = b
    dx, dy, dz = bx - ax, by - ay, bz - az
    L = math.sqrt(dx * dx + dy * dy + dz * dz)
    o = cyl(((ax + bx) / 2, (ay + by) / 2, (az + bz) / 2), r, L, verts=verts)
    o.rotation_mode = "QUATERNION"
    from mathutils import Vector
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector((dx, dy, dz)).normalized())
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    g[look].append(o)


def truss(g, look, a, b, w=1.6, step=2.0, axis="z"):
    """square lattice column/beam between a and b (axis = main direction)"""
    ax, ay, az = a
    bx, by, bz = b
    L = math.dist(a, b)
    n = max(1, int(L / step))
    offs = [(-w / 2, -w / 2), (w / 2, -w / 2), (w / 2, w / 2), (-w / 2, w / 2)]

    def P(t, o):
        x, y, z = ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t
        if axis == "z":
            return (x + o[0], y + o[1], z)
        if axis == "x":
            return (x, y + o[0], z + o[1])
        return (x + o[0], y, z + o[1])
    for o in offs:
        beam(g, look, P(0, o), P(1, o), 0.16)
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        for k in range(4):
            o0, o1 = offs[k], offs[(k + 1) % 4]
            beam(g, look, P(t0, o0), P(t1, o1), 0.08, 6)
            beam(g, look, P(t1, o0), P(t1, o1), 0.08, 6)


roots = []

# ---------------------------------------------------------------- FinishArch: two truss towers + truss bridge, checkered banner, start lights
g = G("Metal", "Dark", "White", "Accent", "Glow", "Concrete", "Yellow")
H, X = 24, 40
for s in (-1, 1):
    truss(g, "Metal", (s * X, 0, 1.2), (s * X, 0, H), w=2.6, step=2.4)
    g["Concrete"].append(box((s * X, 0, 0.6), (5, 5, 1.2), bev=0.2))
    g["Accent"].append(box((s * X, 0, H + 0.6), (3.4, 3.4, 1.2), bev=0.15))
truss(g, "Metal", (-X, 0, H - 1.5), (X, 0, H - 1.5), w=2.6, step=2.6, axis="x")
# checkered banner under the bridge (2 rows)
n = 40
for i in range(n):
    for r in range(2):
        look = "White" if (i + r) % 2 == 0 else "Dark"
        g[look].append(box((-X + 2 + (i + 0.5) * (2 * X - 4) / n, -1.45, H - 4.4 + r * 1.1), ((2 * X - 4) / n, 0.15, 1.1)))
# start light gantry: 5 pods with 2 lamps each
g["Dark"].append(box((0, -1.6, H + 2.2), (14, 1.2, 2.4), bev=0.2))
for k in range(5):
    x = -5.2 + k * 2.6
    g["Dark"].append(cyl((x, -2.25, H + 2.2), 0.95, 0.4, rot=(math.pi / 2, 0, 0)))
    g["Glow"].append(cyl((x, -2.5, H + 2.2), 0.7, 0.12, rot=(math.pi / 2, 0, 0)))
# hazard sleeves at the tower feet
for s in (-1, 1):
    for k in range(4):
        g["Yellow" if k % 2 == 0 else "Dark"].append(box((s * X, 0, 1.6 + k * 0.6), (3.0, 3.0, 0.6)))
roots.append(finish("FinishArch", g))

# ---------------------------------------------------------------- PortalGate: garage car entrance, rounded arch + chevron lights (local +X = outside)
g = G("Dark", "Metal", "Yellow", "Glow", "Accent", "Concrete")
W2, H2 = 10.5, 12
for s in (-1, 1):
    g["Dark"].append(box((0, s * W2, H2 / 2), (2.2, 1.8, H2), bev=0.25))
    g["Concrete"].append(box((0, s * W2, 0.4), (3.2, 2.8, 0.8), bev=0.15))
    for k in range(5):  # chevron lights up the posts
        g["Glow"].append(box((1.15, s * W2, 2 + k * 2), (0.12, 1.0, 0.5)))
# arch: segments of a half circle on top
seg = 18
for i in range(seg):
    a0, a1 = math.pi * i / seg, math.pi * (i + 1) / seg
    y0, z0 = math.cos(a0) * W2, H2 + math.sin(a0) * 4.2
    y1, z1 = math.cos(a1) * W2, H2 + math.sin(a1) * 4.2
    b = box((0, (y0 + y1) / 2, (z0 + z1) / 2), (2.2, math.dist((y0, z0), (y1, z1)) + 0.3, 1.8), rot=(math.atan2(z1 - z0, y1 - y0), 0, 0))
    g["Dark"].append(b)
    g["Yellow" if i % 2 == 0 else "Dark"].append(box((1.15, (y0 + y1) / 2, (z0 + z1) / 2), (0.1, math.dist((y0, z0), (y1, z1)) + 0.1, 0.5), rot=(math.atan2(z1 - z0, y1 - y0), 0, 0)))
# big arrow on the ground in front (pointing in, -X)
g["Yellow"].append(box((4, 0, 0.05), (4.0, 1.2, 0.1)))
for s in (-1, 1):
    g["Yellow"].append(box((1.8, s * 0.9, 0.05), (2.6, 0.9, 0.1), rot=(0, 0, s * math.radians(40))))
roots.append(finish("PortalGate", g))

# ---------------------------------------------------------------- CarStand: glossy turntable podium with light ring + plinth
g = G("Dark", "Chrome", "Glow", "Marble", "Gold")
g["Marble"].append(cyl((0, 0, 0.35), 11, 0.7, verts=64))
g["Dark"].append(cyl((0, 0, 0.95), 10, 0.5, verts=64))
g["Glow"].append(torus((0, 0, 1.2), 10.05, 0.12, seg=96, minor=6))
g["Chrome"].append(cyl((0, 0, 1.25), 9.6, 0.12, verts=64))
for k in range(12):  # turntable seams
    a = k / 12 * 2 * math.pi
    g["Dark"].append(box((math.cos(a) * 4.8, math.sin(a) * 4.8, 1.33), (9.2, 0.06, 0.04), rot=(0, 0, a)))
g["Dark"].append(box((0, -12.2, 1.6), (4.2, 1.4, 3.2), bev=0.2))  # info plinth (screen added in Luau)
g["Gold"].append(box((0, -12.2, 3.3), (4.4, 1.6, 0.2), bev=0.05))
roots.append(finish("CarStand", g))

# ---------------------------------------------------------------- TrophyFountain: round basin, water, gold trophy on a pedestal
g = G("Marble", "Water", "Gold", "Dark", "Glow")
g["Marble"].append(cyl((0, 0, 0.6), 9, 1.2, verts=64))
g["Water"].append(cyl((0, 0, 1.05), 8.2, 0.3, verts=64))
g["Marble"].append(torus((0, 0, 1.25), 8.6, 0.45, seg=96, minor=10))
g["Marble"].append(cyl((0, 0, 2.6), 2.2, 3.0, verts=32))
g["Marble"].append(cyl((0, 0, 4.25), 2.8, 0.3, verts=32))
# trophy: foot, stem, cup, handles
g["Gold"].append(cyl((0, 0, 4.7), 1.6, 0.6, verts=32))
g["Gold"].append(cyl((0, 0, 5.8), 0.45, 1.8, verts=24))
g["Gold"].append(sphere((0, 0, 6.8), 0.8))
cup = cone((0, 0, 8.6), 1.2, 2.6, 3.4, verts=40)
g["Gold"].append(cup)
g["Gold"].append(torus((0, 0, 10.3), 2.6, 0.2, seg=48))
for s in (-1, 1):
    g["Gold"].append(torus((s * 2.5, 0, 8.8), 1.0, 0.18, rot=(math.pi / 2, 0, 0), seg=32))
g["Dark"].append(box((0, -2.9, 2.6), (2.2, 0.1, 1.2)))  # plaque
for k in range(8):  # water jets (glowing spouts)
    a = k / 8 * 2 * math.pi
    g["Glow"].append(cyl((math.cos(a) * 6.5, math.sin(a) * 6.5, 1.25), 0.25, 0.2, verts=12))
roots.append(finish("TrophyFountain", g))

# ---------------------------------------------------------------- Grandstand: 4 seat rows, roof on posts, flags (front = -Y)
g = G("Concrete", "Blue", "Accent", "Metal", "White", "Yellow")
L2 = 30
for r in range(4):
    g["Concrete"].append(box((0, 1.1 + r * 2.2, (r + 1) * 1.2 / 2), (L2, 2.2, (r + 1) * 1.2)))
    for k in range(14):
        look = ["Blue", "Accent", "White", "Yellow"][r]
        g[look].append(box((-L2 / 2 + 1.1 + k * (L2 - 2.2) / 13, 1.1 + r * 2.2 + 0.3, (r + 1) * 1.2 + 0.35), (1.5, 1.2, 0.7), bev=0.15))
for s in (-1, 1):
    for y in (0.2, 8.6):
        g["Metal"].append(cyl((s * (L2 / 2 - 0.5), y, 4.5 + (y > 1) * 1.5), 0.25, 9 + (y > 1) * 3, verts=12))
roof = box((0, 4.4, 10.6), (L2 + 2, 10.5, 0.4), rot=(math.radians(-8), 0, 0))
g["White"].append(roof)
for k in range(5):
    x = -L2 / 2 + 3 + k * (L2 - 6) / 4
    g["Metal"].append(cyl((x, 9.2, 13.5), 0.1, 4, verts=8))
    g[["Accent", "Yellow", "Blue", "White", "Accent"][k]].append(box((x + 1.0, 9.2, 14.6), (2.0, 0.05, 1.3)))
roots.append(finish("Grandstand", g))

# ---------------------------------------------------------------- LeaderboardFrame: big frame on legs + 3 podium steps in front (screen added in Luau)
g = G("Dark", "Gold", "Metal", "White", "Marble", "Glow")
SW, SH, SZ = 24, 14, 9  # screen width/height, screen bottom height
g["Dark"].append(box((0, 0, SZ + SH / 2), (SW + 1.6, 1.2, SH + 1.6), bev=0.3))
g["Gold"].append(box((0, -0.65, SZ + SH + 0.5), (SW + 1.8, 0.2, 0.3)))
g["Gold"].append(box((0, -0.65, SZ - 0.5), (SW + 1.8, 0.2, 0.3)))
g["Dark"].append(box((0, -0.2, SZ + SH + 2.2), (10, 1.0, 3.0), bev=0.3))  # crown header
g["Gold"].append(cone((0, -0.8, SZ + SH + 2.2), 1.0, 0.0, 0.3, rot=(math.pi / 2, 0, 0), verts=5))
for s in (-1, 1):
    g["Metal"].append(box((s * (SW / 2 - 2), 0.4, SZ / 2), (1.2, 1.2, SZ), bev=0.15))
    g["Glow"].append(box((s * (SW / 2 + 0.85), -0.3, SZ + SH / 2), (0.15, 0.6, SH)))
# podium: 2nd (left), 1st (centre), 3rd (right), y = in front of the screen
for x, h, look in ((-6, 3, "White"), (0, 4.5, "Gold"), (6, 2, "Marble")):
    g[look].append(box((x, -6, h / 2), (5.6, 5, h), bev=0.15))
    g["Dark"].append(box((x, -8.55, h * 0.55), (1.6, 0.1, 1.6)))
roots.append(finish("LeaderboardFrame", g))

# ---------------------------------------------------------------- Planter with palm
g = G("Marble", "Dark", "Wood", "Leaf")
g["Marble"].append(box((0, 0, 0.9), (5, 5, 1.8), bev=0.25))
g["Dark"].append(box((0, 0, 1.85), (4.3, 4.3, 0.1)))
for k in range(9):  # curved trunk segments
    t = k / 8
    g["Wood"].append(cyl((math.sin(t * 1.2) * 0.9, 0, 2 + k * 1.1), 0.42 - t * 0.12, 1.15, verts=12))
top = (math.sin(1.2) * 0.9, 0, 12)
for k in range(8):
    a = k / 8 * 2 * math.pi
    for j in range(4):
        d = 1.0 + j * 1.2
        g["Leaf"].append(box((top[0] + math.cos(a) * d, math.sin(a) * d, top[2] - j * j * 0.25), (1.6, 0.9 - j * 0.12, 0.12), rot=(0, math.radians(15 + j * 10), a)))
roots.append(finish("Planter", g))

# ---------------------------------------------------------------- StreetLamp: double-arm lamp
g = G("Dark", "Glow", "Gold")
g["Dark"].append(cyl((0, 0, 0.4), 0.8, 0.8, verts=16))
g["Dark"].append(cyl((0, 0, 7), 0.22, 13, verts=12))
g["Gold"].append(torus((0, 0, 1.0), 0.45, 0.1, seg=24))
for s in (-1, 1):
    beam(g, "Dark", (0, 0, 12.2), (s * 2.2, 0, 13.0), 0.12)
    g["Dark"].append(cone((s * 2.2, 0, 13.0), 0.7, 0.2, 0.6, verts=16))
    g["Glow"].append(sphere((s * 2.2, 0, 12.5), 0.45, 12))
g["Gold"].append(sphere((0, 0, 13.6), 0.3, 12))
roots.append(finish("StreetLamp", g))

# ---------------------------------------------------------------- FoodTruck (front = +X)
g = G("Yellow", "White", "Dark", "Glass", "Rubber", "Chrome", "Accent")
g["Yellow"].append(box((-1.2, 0, 4.2), (10, 6.2, 6.0), bev=0.5))
g["Yellow"].append(box((5.3, 0, 3.0), (3.2, 6.0, 3.6), bev=0.6))
g["Glass"].append(box((6.8, 0, 3.9), (0.2, 5.2, 1.6), rot=(0, math.radians(-15), 0)))
g["Dark"].append(box((-1.2, -3.12, 4.6), (6.0, 0.1, 2.4)))  # serving window
g["White"].append(box((-1.2, -3.4, 3.35), (6.2, 0.7, 0.2)))  # counter
for k in range(8):  # striped awning
    g["Accent" if k % 2 == 0 else "White"].append(box((-4.0 + k * 0.8, -4.2, 6.2), (0.8, 2.2, 0.1), rot=(math.radians(-18), 0, 0)))
for x in (-4.5, 4.8):
    for s in (-1, 1):
        g["Rubber"].append(cyl((x, s * 2.9, 1.1), 1.1, 0.8, rot=(math.pi / 2, 0, 0), verts=24))
        g["Chrome"].append(cyl((x, s * 3.32, 1.1), 0.55, 0.1, rot=(math.pi / 2, 0, 0), verts=16))
g["Chrome"].append(box((6.95, 0, 1.6), (0.3, 6.2, 0.5)))
g["Accent"].append(box((-1.2, 0, 7.6), (3.4, 1.4, 1.4), bev=0.3))  # roof sign block
roots.append(finish("FoodTruck", g))

# ---------------------------------------------------------------- Bench
g = G("Wood", "Dark")
for k in range(3):
    g["Wood"].append(box((0, -0.5 + k * 0.5, 1.6), (6, 0.4, 0.15), bev=0.04))
for k in range(2):
    g["Wood"].append(box((0, 0.75, 2.2 + k * 0.5), (6, 0.12, 0.35), bev=0.03))
for s in (-1, 1):
    g["Dark"].append(box((s * 2.6, 0, 0.8), (0.25, 1.6, 1.6)))
    g["Dark"].append(box((s * 2.6, 0.75, 2.2), (0.25, 0.15, 1.6)))
roots.append(finish("Bench", g))

# ---------------------------------------------------------------- StringLightPole: pole with a crossbar of bulbs
g = G("Dark", "Glow")
g["Dark"].append(cyl((0, 0, 6), 0.18, 12, verts=10))
g["Dark"].append(cyl((0, 0, 0.3), 0.6, 0.6, verts=12))
for k in range(9):
    x = -4 + k
    sag = 11.4 - 0.5 * (1 - (x / 4) ** 2)
    g["Glow"].append(sphere((x, 0, sag), 0.22, 10))
    beam(g, "Dark", (x - 0.5, 0, 11.4 - 0.5 * (1 - ((x - 0.5) / 4) ** 2)), (x + 0.5, 0, 11.4 - 0.5 * (1 - ((x + 0.5) / 4) ** 2)), 0.03, 4)
roots.append(finish("StringLightPole", g))

for r in roots:
    r.location = (0, 0, 0)
tris = {}
for r in roots:
    mc.export([r], os.path.join(OUT, r.name + ".fbx"))
    tris[r.name] = mc.triangles(r)
print("spawn ok", tris)
# real sizes (studs) so ModelService can undo any unit conversion of the FBX importer
from mathutils import Vector
lines = ["-- generated by blender/make_spawn.py: longest side of each spawn model in studs", "return {"]
for r in roots:
    pts = [c.matrix_world @ Vector(v) for c in r.children for v in c.bound_box]
    ext = max(max(p[i] for p in pts) - min(p[i] for p in pts) for i in range(3))
    lines.append(f"\t{r.name} = {ext:.2f},")
lines.append("}")
open(os.path.join(mc.ROOT, "src", "ReplicatedStorage", "Shared", "ModelSizes.lua"), "w").write("\n".join(lines) + "\n")

if "--render" in sys.argv:
    from mathutils import Vector
    sc, cam, co = mc.setup_scene(1800, 1100)
    lay = {"FinishArch": (0, 40, 0), "Grandstand": (-45, 10, 0), "LeaderboardFrame": (40, 12, 0), "TrophyFountain": (0, 0, 0),
           "CarStand": (-22, -18, 0), "PortalGate": (24, -18, 0), "Planter": (-12, -2, 0), "StreetLamp": (12, -2, 0),
           "FoodTruck": (-48, -20, 0), "Bench": (8, -26, 0), "StringLightPole": (50, -20, 0)}
    for r in roots:
        r.location = lay.get(r.name, (0, 0, 0))
    co.location = (0, -110, 70)
    co.rotation_euler = (Vector((0, 8, 6)) - co.location).to_track_quat("-Z", "Y").to_euler()
    cam.lens = 30
    sc.render.filepath = os.path.join(mc.ROOT, "docs", "renders", "spawn.png")
    bpy.ops.render.render(write_still=True)
