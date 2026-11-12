"""Realistic pickup parts + tuning parts (Blender). Out: assets/parts/parts.fbx, docs/renders/parts.jpg.
Each root empty is named Part_<id> or Tune_<family>; meshes are named by look (Rubber, Metal, Chrome, Dark, Copper,
Accent, Glow, Carbon, Blue, Gold, Green) and styled in Studio by CarModelTool.ApplyImported."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import make_cars as mc

OUT = os.path.join(mc.ROOT, "assets", "parts")
os.makedirs(OUT, exist_ok=True)
mc.reset()

LOOK = {
    "Rubber": ((0.025, 0.025, 0.03, 1), 0.0, 0.85), "Metal": ((0.62, 0.64, 0.67, 1), 0.9, 0.35),
    "Chrome": ((0.92, 0.93, 0.95, 1), 1.0, 0.08), "Dark": ((0.08, 0.085, 0.1, 1), 0.6, 0.45),
    "Copper": ((0.72, 0.38, 0.2, 1), 1.0, 0.3), "Accent": ((0.8, 0.08, 0.07, 1), 0.2, 0.3),
    "Glow": ((0.2, 0.9, 1.0, 1), 0.0, 0.2), "Carbon": ((0.05, 0.05, 0.055, 1), 0.3, 0.25),
    "Blue": ((0.08, 0.3, 0.85, 1), 0.3, 0.25), "Gold": ((1.0, 0.72, 0.2, 1), 1.0, 0.2), "Green": ((0.05, 0.4, 0.15, 1), 0.0, 0.5),
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


def cyl(loc, r, h, rot=(0, 0, 0), verts=32, name="c"):
    return mc.prim("cyl", name, loc, (2 * r, 2 * r, h), rot=rot, verts=verts)


def box(loc, size, bev=0.0, rot=(0, 0, 0)):
    b = mc.prim("box", "b", loc, size, rot=rot)
    if bev:
        mc.bevel(b, bev, 2)
    return b


def torus(loc, R, r, rot=(0, 0, 0), seg=40, minor=14):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=seg, minor_segments=minor, location=loc, rotation=rot)
    return bpy.context.active_object


def cone(loc, r1, r2, h, rot=(0, 0, 0), verts=32):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=h, location=loc, rotation=rot)
    return bpy.context.active_object


X90 = (0, math.pi / 2, 0)  # cylinder axis along X
Y90 = (math.pi / 2, 0, 0)  # cylinder axis along Y


def bolt(g, x, y, z, rot=(0, 0, 0), L=1.6):
    """hex head + threaded shank (thread = stack of thin rings)"""
    head = cyl((x, y, z + L + 0.18), 0.42, 0.36, verts=6)
    g["Metal"].append(head)
    g["Metal"].append(cyl((x, y, z + L / 2), 0.2, L, verts=16))
    for k in range(int(L / 0.14)):
        g["Metal"].append(torus((x, y, z + 0.1 + k * 0.14), 0.2, 0.045, seg=14, minor=4))
    g["Metal"].append(cyl((x, y, z + L - 0.02), 0.5, 0.06, verts=24))  # washer face


def nut(g, x, y, z):
    g["Chrome"].append(cyl((x, y, z), 0.48, 0.38, verts=6))
    g["Dark"].append(cyl((x, y, z), 0.22, 0.4, verts=16))


def washer(g, x, y, z):
    g["Metal"].append(torus((x, y, z), 0.42, 0.11, seg=28))


roots = []
# ---------------------------------------------------------------- pickups
g = {"Metal": [], "Chrome": [], "Dark": []}
bolt(g, -0.6, 0, 0)
bolt(g, 0.5, 0.5, 0, L=1.2)
nut(g, 0.7, -0.6, 0.2)
nut(g, -0.1, -0.9, 0.2)
washer(g, 1.3, 0.2, 0.06)
washer(g, -1.2, -0.7, 0.06)
roots.append(finish("Part_bolts", g))


def wheel(g, r_out=1.6, width=1.0, rim_r=1.0, spokes=5, rim="Chrome", slick=False):
    z = r_out  # sits on the ground
    t = torus((0, 0, z), r_out - width * 0.45, width * 0.48, rot=Y90, seg=48)
    t.scale = (1, 1.15, 1)
    g["Rubber"].append(t)
    if not slick:
        n = 30
        for k in range(n):
            a = k / n * 2 * math.pi
            g["Rubber"].append(box((math.cos(a) * (r_out - 0.04), 0, z + math.sin(a) * (r_out - 0.04)), (0.18, width * 0.9, 0.28), rot=(0, -a, 0)))
    for sy in (-1, 1):  # rim lips
        g[rim].append(torus((0, sy * width * 0.36, z), rim_r, 0.08, rot=Y90, seg=40, minor=8))
    g["Dark"].append(cyl((0, 0.05, z), rim_r * 0.96, width * 0.6, rot=Y90, verts=40))  # recessed barrel
    for k in range(spokes):
        a = k / spokes * 2 * math.pi
        g[rim].append(box((math.cos(a) * rim_r * 0.5, -width * 0.3, z + math.sin(a) * rim_r * 0.5), (rim_r * 0.95, 0.12, 0.2), rot=(0, -a, 0)))
    g[rim].append(cyl((0, -width * 0.3, z), rim_r * 0.26, 0.22, rot=Y90))
    for k in range(5):
        a = k / 5 * 2 * math.pi
        g["Metal"].append(cyl((math.cos(a) * rim_r * 0.15, -width * 0.43, z + math.sin(a) * rim_r * 0.15), 0.04, 0.08, rot=Y90, verts=8))


g = {"Rubber": [], "Chrome": [], "Dark": [], "Metal": []}
wheel(g)
roots.append(finish("Part_tire", g))


def engine(g, cover="Accent"):
    blk = box((0, 0, 1.0), (3.0, 1.8, 1.6), bev=0.12)
    g["Metal"].append(blk)
    g["Dark"].append(box((0, 0, 0.12), (2.6, 1.5, 0.4), bev=0.1))  # oil pan
    g["Metal"].append(box((0, 0, 2.0), (2.9, 1.5, 0.45), bev=0.08))  # head
    g[cover].append(box((0, 0, 2.42), (2.7, 1.2, 0.4), bev=0.15))  # valve cover
    for k in range(4):
        g["Dark"].append(cyl((-0.95 + k * 0.63, 0, 2.66), 0.12, 0.2, verts=12))  # coil packs
    for k in range(4):  # intake runners
        g["Metal"].append(cyl((-0.95 + k * 0.63, 0.95, 2.05), 0.16, 0.7, rot=Y90, verts=16))
    g["Metal"].append(box((0, 1.35, 2.05), (2.6, 0.4, 0.5), bev=0.1))  # plenum
    for k in range(4):  # exhaust headers
        g["Copper"].append(cyl((-0.95 + k * 0.63, -1.05, 1.7), 0.14, 0.6, rot=Y90, verts=16))
    g["Copper"].append(cyl((0, -1.35, 1.3), 0.2, 2.4, rot=X90, verts=16))
    for (x, z, rr) in ((1.6, 1.6, 0.45), (1.6, 0.7, 0.32), (1.6, 2.1, 0.28)):  # pulleys + belt
        g["Chrome"].append(cyl((x, 0, z), rr, 0.18, rot=X90))
        g["Dark"].append(cyl((x + 0.02, 0, z), rr * 0.4, 0.2, rot=X90, verts=12))
    belt = torus((1.62, 0, 1.4), 0.75, 0.05, rot=X90, seg=36)
    belt.scale = (1, 1, 1.4)
    g["Rubber"].append(belt)


g = {"Metal": [], "Dark": [], "Accent": [], "Copper": [], "Chrome": [], "Rubber": []}
engine(g)
roots.append(finish("Part_engine", g))


def turbo(g, x=0.0, y=0.0, z=1.2, s=1.0, hot="Copper"):
    # compressor side (cold, polished) and turbine side (hot, darker), cartridge in the middle
    t = torus((x - 0.55 * s, y, z), 0.62 * s, 0.38 * s, rot=X90, seg=40)
    g["Chrome"].append(t)
    g["Chrome"].append(cyl((x - 0.55 * s, y, z), 0.65 * s, 0.6 * s, rot=X90))
    g["Dark"].append(cyl((x - 0.95 * s, y, z), 0.36 * s, 0.4 * s, rot=X90))  # inlet
    g["Metal"].append(cyl((x - 1.0 * s, y, z), 0.3 * s, 0.42 * s, rot=X90))
    for k in range(8):  # compressor blades seen through the inlet
        a = k / 8 * 2 * math.pi
        g["Metal"].append(box((x - 1.12 * s, y + math.cos(a) * 0.14 * s, z + math.sin(a) * 0.14 * s), (0.04, 0.22 * s, 0.05 * s), rot=(a, 0, 0)))
    g["Chrome"].append(cyl((x - 0.55 * s, y + 0.75 * s, z + 0.35 * s), 0.22 * s, 0.6 * s, rot=Y90))  # outlet
    g["Metal"].append(cyl((x, y, z), 0.3 * s, 0.6 * s, rot=X90))  # cartridge
    g[hot].append(torus((x + 0.55 * s, y, z), 0.55 * s, 0.34 * s, rot=X90, seg=40))
    g[hot].append(cyl((x + 0.55 * s, y, z), 0.56 * s, 0.55 * s, rot=X90))
    g[hot].append(box((x + 0.55 * s, y, z - 0.75 * s), (0.7 * s, 0.7 * s, 0.25 * s), bev=0.05))  # flange
    g["Dark"].append(cyl((x + 0.9 * s, y, z), 0.3 * s, 0.3 * s, rot=X90))  # downpipe


g = {"Chrome": [], "Dark": [], "Metal": [], "Copper": []}
turbo(g)
roots.append(finish("Part_turbo", g))

# energy core: hybrid battery module with cells, bus bars and a glowing status window
g = {"Dark": [], "Metal": [], "Copper": [], "Glow": [], "Blue": []}
g["Dark"].append(box((0, 0, 0.55), (2.6, 1.8, 1.1), bev=0.12))
for i in range(5):
    for j in range(3):
        g["Blue"].append(cyl((-1.0 + i * 0.5, -0.5 + j * 0.5, 1.2), 0.2, 0.3, verts=20))
        g["Metal"].append(cyl((-1.0 + i * 0.5, -0.5 + j * 0.5, 1.37), 0.08, 0.06, verts=12))
for j in range(3):
    g["Copper"].append(box((0, -0.5 + j * 0.5, 1.42), (2.2, 0.12, 0.05)))
g["Glow"].append(box((0, -0.91, 0.6), (1.6, 0.04, 0.35)))
for s in (-1, 1):
    g["Copper"].append(cyl((s * 1.05, 0.75, 1.25), 0.12, 0.35, verts=12))
roots.append(finish("Part_core", g))

# ---------------------------------------------------------------- tuning parts
# ECU (chip tune): finned aluminium box, connector, exposed board with a gold chip
g = {"Metal": [], "Dark": [], "Green": [], "Gold": []}
g["Metal"].append(box((0, 0, 0.35), (2.0, 1.4, 0.5), bev=0.06))
for k in range(7):
    g["Metal"].append(box((-0.75 + k * 0.25, 0, 0.68), (0.08, 1.3, 0.2)))
g["Dark"].append(box((1.1, 0, 0.35), (0.3, 1.0, 0.36), bev=0.03))
g["Green"].append(box((-0.2, -0.85, 0.2), (1.4, 0.3, 0.06)))
g["Gold"].append(box((-0.2, -0.85, 0.25), (0.4, 0.2, 0.06)))
roots.append(finish("Tune_ecu", g))

# turbo kit: turbo + intercooler + piping
g = {"Chrome": [], "Dark": [], "Metal": [], "Copper": [], "Blue": []}
turbo(g, x=-0.6, z=1.0, s=0.8)
g["Metal"].append(box((1.2, 0, 1.0), (0.4, 2.4, 1.4), bev=0.05))  # intercooler core
for k in range(9):
    g["Dark"].append(box((1.0, 0, 0.45 + k * 0.14), (0.05, 2.3, 0.04)))
g["Blue"].append(cyl((0.4, 0.9, 1.6), 0.16, 1.4, rot=X90, verts=16))
roots.append(finish("Tune_turbo", g))

# supercharger (roots blower) with ribbed case, pulley, inlet hat
g = {"Accent": [], "Chrome": [], "Dark": [], "Metal": []}
case = box((0, 0, 0.9), (2.4, 1.4, 1.1), bev=0.3)
g["Accent"].append(case)
for k in range(9):
    g["Accent"].append(box((-1.0 + k * 0.25, 0, 1.5), (0.08, 1.2, 0.18)))
g["Chrome"].append(cyl((1.35, 0, 0.9), 0.45, 0.25, rot=X90))
g["Dark"].append(cyl((1.5, 0, 0.9), 0.2, 0.1, rot=X90, verts=12))
g["Chrome"].append(cyl((0, 0, 1.85), 0.55, 0.4))
g["Dark"].append(cyl((0, 0, 2.06), 0.48, 0.05))
g["Metal"].append(box((0, 0, 0.25), (2.6, 1.6, 0.2), bev=0.05))
roots.append(finish("Tune_super", g))

# sport exhaust: oval muffler + twin polished tips
g = {"Metal": [], "Chrome": [], "Dark": []}
m = cyl((0, 0, 0.7), 0.6, 2.2, rot=X90, verts=32)
m.scale = (1, 1.5, 1)
g["Metal"].append(m)
g["Metal"].append(cyl((-1.6, 0, 0.7), 0.18, 1.2, rot=X90, verts=16))
for s in (-1, 1):
    g["Chrome"].append(cyl((1.5, s * 0.4, 0.7), 0.26, 0.8, rot=X90))
    g["Dark"].append(cyl((1.92, s * 0.4, 0.7), 0.2, 0.05, rot=X90))
roots.append(finish("Tune_exhaust", g))

# cold air intake: cone filter + mandrel pipe
g = {"Accent": [], "Chrome": [], "Dark": []}
g["Accent"].append(cone((0.6, 0, 0.8), 0.75, 0.5, 1.4, rot=X90))
for k in range(10):
    g["Dark"].append(torus((0.0 + k * 0.13, 0, 0.8), 0.72 - k * 0.025, 0.03, rot=X90, seg=28, minor=4))
g["Chrome"].append(cyl((1.45, 0, 0.8), 0.52, 0.2, rot=X90))
g["Chrome"].append(cyl((-0.6, 0, 0.8), 0.34, 1.2, rot=X90))
roots.append(finish("Tune_intake", g))

# nitro: blue bottle, chrome valve, braided line
g = {"Blue": [], "Chrome": [], "Dark": []}
g["Blue"].append(cyl((0, 0, 0.5), 0.45, 2.4, rot=X90))
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=0.45, location=(1.2, 0, 0.5))
g["Blue"].append(bpy.context.active_object)
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=0.45, location=(-1.2, 0, 0.5))
g["Blue"].append(bpy.context.active_object)
g["Chrome"].append(cyl((1.75, 0, 0.5), 0.14, 0.4, rot=X90, verts=16))
g["Chrome"].append(box((2.0, 0, 0.5), (0.2, 0.5, 0.25), bev=0.03))
for s in (-1, 1):
    g["Dark"].append(torus((s * 0.6, 0, 0.5), 0.47, 0.04, rot=X90, seg=28))
roots.append(finish("Tune_nitro", g))

# racing slick on a gold rim
g = {"Rubber": [], "Gold": [], "Dark": [], "Metal": []}
wheel(g, r_out=1.6, width=1.5, rim_r=1.1, spokes=10, rim="Gold", slick=True)
roots.append(finish("Tune_tires", g))

# aero: carbon rear wing with end plates and swan-neck uprights
g = {"Carbon": [], "Metal": [], "Accent": []}
wing = box((0, 0, 1.8), (0.9, 3.6, 0.12), bev=0.04, rot=(0, math.radians(-8), 0))
g["Carbon"].append(wing)
g["Carbon"].append(box((0.35, 0, 2.0), (0.3, 3.5, 0.08), rot=(0, math.radians(-25), 0)))
for s in (-1, 1):
    g["Carbon"].append(box((0, s * 1.84, 1.85), (1.1, 0.06, 0.6), bev=0.02))
    g["Metal"].append(box((-0.15, s * 0.8, 1.0), (0.12, 0.1, 1.6), rot=(0, math.radians(12), 0)))
    g["Accent"].append(box((-0.3, s * 0.8, 0.15), (0.5, 0.3, 0.1)))
roots.append(finish("Tune_aero", g))

for r in roots:
    r.location.x = 0
mc.export(roots, os.path.join(OUT, "parts.fbx"))
tris = {r.name: mc.triangles(r) for r in roots}
print("parts ok", tris)

if "--render" in sys.argv:
    for r in roots:
        r.scale = (3.2, 3.2, 3.2)
    mc.render_grid(roots, os.path.join(mc.ROOT, "docs", "renders", "parts.png"), 5)
