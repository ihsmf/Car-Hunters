"""Realistic pickup parts + tuning parts (Blender). Out: assets/parts/parts.fbx, docs/renders/parts.jpg.
Each root empty is named Part_<id> or Tune_<family>; meshes are named by look (Rubber, Metal, Chrome, Dark, Copper,
Accent, Glow, Carbon, Blue, Gold, Green, White) and styled in Studio by CarModelTool.ApplyImported.
No two pieces share a face plane: touching faces are offset >= 0.02 or clearly interpenetrate (no z-fighting in Roblox)."""
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
    "White": ((0.9, 0.9, 0.88, 1), 0.0, 0.3),
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
    g["Metal"].append(cyl((x, y, z + (L + 0.1) / 2), 0.2, L + 0.1, verts=16))  # shank runs 0.1 into the head
    for k in range(int(L / 0.14)):
        g["Metal"].append(torus((x, y, z + 0.1 + k * 0.14), 0.2, 0.045, seg=14, minor=4))
    g["Metal"].append(cyl((x, y, z + L), 0.5, 0.08, verts=24))  # washer face (straddles the head bottom)


def nut(g, x, y, z):
    g["Chrome"].append(cyl((x, y, z), 0.48, 0.38, verts=6))
    g["Dark"].append(cyl((x, y, z), 0.22, 0.46, verts=16))  # 0.04 proud of both nut faces


def washer(g, x, y, z):
    g["Metal"].append(torus((x, y, z), 0.42, 0.11, seg=28))


roots = []
# ---------------------------------------------------------------- pickups
g = {"Metal": [], "Chrome": [], "Dark": []}
bolt(g, -0.6, 0, 0)
bolt(g, 0.5, 0.5, 0, L=1.2)
nut(g, 0.7, -0.6, 0.2)
nut(g, -0.2, -1.05, 0.2)  # clear of the other nut (no shared top/bottom planes)
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
            g["Rubber"].append(box((math.cos(a) * (r_out - 0.04), 0, z + math.sin(a) * (r_out - 0.04)), (0.18, width * 0.8, 0.28), rot=(0, -a, 0)))
    for sy in (-1, 1):  # rim lips
        g[rim].append(torus((0, sy * width * 0.36, z), rim_r, 0.08, rot=Y90, seg=40, minor=8))
    g["Dark"].append(cyl((0, width * 0.12, z), rim_r * 0.96, width * 0.6, rot=Y90, verts=40))  # recessed barrel (face 0.03+ behind the spokes)
    for k in range(spokes):  # alternating spoke thickness: overlapping spokes never share a face plane
        a = k / spokes * 2 * math.pi
        rc = rim_r * 0.6375  # spoke runs from r 0.3 (inside the hub) to 0.975 (into the rim lip)
        g[rim].append(box((math.cos(a) * rc, -width * 0.32, z + math.sin(a) * rc), (rim_r * 0.675, 0.12 if k % 2 else 0.17, 0.2), rot=(0, -a, 0)))
    hy = -width * 0.32 - 0.085  # hub y: front 0.115+ ahead of the spokes, back 0.03 inside them
    g[rim].append(cyl((0, hy, z), rim_r * 0.34, 0.23, rot=Y90))  # hub cap
    for k in range(5):  # lug bolts, sunk 0.04 into the hub face
        a = k / 5 * 2 * math.pi
        g["Metal"].append(cyl((math.cos(a) * rim_r * 0.18, hy - 0.125, z + math.sin(a) * rim_r * 0.18), 0.05, 0.1, rot=Y90, verts=8))


g = {"Rubber": [], "Chrome": [], "Dark": [], "Metal": []}
wheel(g)
roots.append(finish("Part_tire", g))


def engine(g, cover="Accent"):
    blk = box((0, 0, 1.0), (3.0, 1.8, 1.6), bev=0.12)
    g["Metal"].append(blk)
    g["Dark"].append(box((0, 0, 0.14), (2.5, 1.4, 0.36), bev=0.1))  # oil pan
    g["Metal"].append(box((0, 0, 2.0), (2.9, 1.5, 0.45), bev=0.08))  # head
    g[cover].append(box((0, 0, 2.4), (2.7, 1.2, 0.4), bev=0.15))  # valve cover (sunk 0.025 into the head)
    for k in range(4):
        g["Dark"].append(cyl((-0.95 + k * 0.63, 0, 2.66), 0.12, 0.2, verts=12))  # coil packs
    for k in range(4):  # intake runners
        g["Metal"].append(cyl((-0.95 + k * 0.63, 0.95, 2.05), 0.16, 0.7, rot=Y90, verts=16))
    g["Metal"].append(box((0, 1.35, 2.05), (2.6, 0.4, 0.5), bev=0.1))  # plenum
    for k in range(4):  # exhaust headers
        g["Copper"].append(cyl((-0.95 + k * 0.63, -1.0, 1.7), 0.14, 0.6, rot=Y90, verts=16))  # 0.05 into the head
    g["Copper"].append(cyl((0, -1.35, 1.3), 0.2, 2.4, rot=X90, verts=16))
    # pulleys (x back..front): sunk 0.03+ into block/head, overlapping pulleys on different planes, hubs 0.06 proud
    for (x0, x1, z, rr, hub) in ((1.42, 1.69, 1.6, 0.45, 0.06), (1.47, 1.73, 0.7, 0.32, 0.06), (1.38, 1.6, 2.1, 0.28, 0.13)):
        g["Chrome"].append(cyl(((x0 + x1) / 2, 0, z), rr, x1 - x0, rot=X90))
        h0, h1 = x0 + 0.13, x1 + hub  # hub: back inside the pulley, front proud (and clear of the belt planes)
        g["Dark"].append(cyl(((h0 + h1) / 2, 0, z), rr * 0.4, h1 - h0, rot=X90, verts=12))
    belt = torus((1.6, 0, 1.4), 0.75, 0.05, rot=X90, seg=36)
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
    g["Dark"].append(cyl((x - 0.925 * s, y, z), 0.34 * s, 0.35 * s, rot=X90))  # inlet (dark throat)
    g["Chrome"].append(torus((x - 1.1 * s, y, z), 0.36 * s, 0.07 * s, rot=X90, seg=32, minor=10))  # inlet lip
    g["Metal"].append(cyl((x - 1.13 * s, y, z), 0.1 * s, 0.18 * s, rot=X90, verts=16))  # compressor nut
    for k in range(8):  # compressor blades standing out of the dark throat (overlaps hidden by the nut)
        a = k / 8 * 2 * math.pi
        g["Metal"].append(box((x - 1.12 * s, y + math.cos(a) * 0.17 * s, z + math.sin(a) * 0.17 * s), (0.1 * s, 0.2 * s, 0.05 * s), rot=(a, 0, 0)))
    g["Chrome"].append(cyl((x - 0.55 * s, y + 0.75 * s, z + 0.35 * s), 0.22 * s, 0.6 * s, rot=Y90))  # outlet
    g["Metal"].append(cyl((x, y, z), 0.3 * s, 0.6 * s, rot=X90))  # cartridge
    g[hot].append(torus((x + 0.55 * s, y, z), 0.55 * s, 0.34 * s, rot=X90, seg=40))
    g[hot].append(cyl((x + 0.55 * s, y, z), 0.56 * s, 0.55 * s, rot=X90))
    g[hot].append(box((x + 0.55 * s, y, z - 0.75 * s), (0.6 * s, 0.7 * s, 0.25 * s), bev=0.05))  # flange
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
        g["Metal"].append(cyl((-1.0 + i * 0.5, -0.5 + j * 0.5, 1.42), 0.08, 0.2, verts=12))  # posts through the bus bars
for j in range(3):
    g["Copper"].append(box((0, -0.5 + j * 0.5, 1.46), (2.2, 0.12, 0.06)))
g["Glow"].append(box((0, -0.92, 0.6), (1.6, 0.1, 0.35)))
for s in (-1, 1):
    g["Copper"].append(cyl((s * 0.75, 0.78, 1.2), 0.12, 0.35, verts=12))  # terminals between the cells
roots.append(finish("Part_core", g))

# spark plugs: copper tip + ground strap, threaded body, gasket, chrome hex, white ribbed ceramic, terminal
def plug(g, mat_world):
    objs = []
    def add(look, o):
        g[look].append(o)
        objs.append(o)
    add("Copper", cyl((0, 0, 0.18), 0.06, 0.16, verts=12))  # centre electrode (0.04 spark gap to the strap)
    add("Copper", box((0.07, 0, 0.035), (0.22, 0.1, 0.07)))  # ground strap, foot
    add("Copper", box((0.17, 0, 0.155), (0.07, 0.16, 0.25)))  # ground strap, upright (into the body)
    add("Metal", cyl((0, 0, 0.53), 0.22, 0.66, verts=20))  # threaded body z 0.2..0.86 (into the hex)
    for k in range(5):
        add("Metal", torus((0, 0, 0.27 + k * 0.1), 0.22, 0.035, seg=20, minor=6))
    add("Copper", torus((0, 0, 0.8), 0.26, 0.05, seg=28, minor=8))  # gasket
    add("Chrome", cyl((0, 0, 0.975), 0.36, 0.35, verts=6))  # hex z 0.8..1.15
    add("White", cyl((0, 0, 1.24), 0.3, 0.24, verts=28))  # ceramic collar z 1.12..1.36
    add("White", cyl((0, 0, 1.75), 0.23, 1.1, verts=28))  # ceramic body z 1.2..2.3
    for k in range(3):
        add("White", torus((0, 0, 1.86 + k * 0.14), 0.23, 0.05, seg=28, minor=8))
    add("Metal", cyl((0, 0, 2.4), 0.1, 0.3, verts=12))  # terminal z 2.25..2.55
    add("Metal", cyl((0, 0, 2.58), 0.16, 0.16, verts=12))  # terminal nut z 2.5..2.66
    for o in objs:
        o.matrix_world = mat_world @ o.matrix_world


from mathutils import Matrix
g = {"Copper": [], "Metal": [], "Chrome": [], "White": []}
plug(g, Matrix.Translation((0.25, 0.42, 0)) @ Matrix.Rotation(0.3, 4, "Z"))  # standing
plug(g, Matrix.Translation((-1.0, -0.75, 0.36)) @ Matrix.Rotation(math.pi / 2, 4, "Y") @ Matrix.Rotation(math.pi / 6, 4, "Z"))  # lying, hex flat
roots.append(finish("Part_plugs", g))

# round air filter: pleated red element around a dark core, rubber base, chrome lid with a wing nut
g = {"Rubber": [], "Accent": [], "Dark": [], "Chrome": [], "Metal": []}
g["Rubber"].append(cyl((0, 0, 0.07), 1.36, 0.14, verts=48))  # base seal z 0..0.14
g["Dark"].append(cyl((0, 0, 0.57), 0.98, 0.92, verts=48))  # inner core z 0.11..1.03
n = 36
for k in range(n):  # pleats z 0.08..1.06, gaps show the dark core
    a = k / n * 2 * math.pi
    g["Accent"].append(box((math.cos(a) * 1.12, math.sin(a) * 1.12, 0.57), (0.36, 0.09, 0.98), rot=(0, 0, a)))
lid = cyl((0, 0, 1.08), 1.42, 0.16, verts=48)  # z 1.0..1.16
mc.bevel(lid, 0.05, 2)
g["Chrome"].append(lid)
g["Chrome"].append(torus((0, 0, 1.16), 1.0, 0.05, seg=48, minor=8))  # embossed ring
g["Metal"].append(cyl((0, 0, 1.2), 0.22, 0.2, verts=20))  # stud z 1.1..1.3
g["Metal"].append(box((0, 0, 1.32), (0.8, 0.1, 0.26), bev=0.03))  # wing nut z 1.19..1.45
roots.append(finish("Part_filter", g))


# gearbox: aluminium case + bell housing, open front with meshing gears, shifter on top
def gear(g, look, x, y, z, R, teeth, th, phase=0.0):
    g[look].append(cyl((x, y, z), R, th, rot=Y90, verts=40))
    for k in range(teeth):  # teeth inset 0.03 from both disc faces
        a = phase + k / teeth * 2 * math.pi
        g[look].append(box((x + math.cos(a) * (R + 0.06), y, z + math.sin(a) * (R + 0.06)), (0.22, th - 0.06, 0.16), rot=(0, -a, 0)))
    g["Dark"].append(cyl((x, y + 0.1, z), 0.16, th + 0.3, rot=Y90, verts=16))  # axle: 0.05 proud of the front, back deep in the case


g = {"Metal": [], "Dark": [], "Gold": [], "Chrome": [], "Accent": []}
g["Metal"].append(box((0, 0, 0.8), (2.6, 1.6, 1.5), bev=0.2))  # case z 0.05..1.55, front face y -0.8
g["Metal"].append(cone((-1.55, 0, 0.8), 0.95, 0.72, 0.7, rot=(0, -math.pi / 2, 0), verts=40))  # bell housing x -1.9..-1.2
g["Dark"].append(box((0, 0, 0.15), (2.2, 1.3, 0.3), bev=0.06))  # oil pan z 0..0.3
g["Dark"].append(box((0.05, -0.82, 0.85), (2.0, 0.16, 1.0)))  # open window y -0.9..-0.74 (case face -0.8)
gear(g, "Gold", -0.56, -0.95, 0.85, 0.55, 14, 0.24)  # discs y -1.07..-0.83, teeth -1.04..-0.86
gear(g, "Chrome", 0.73, -0.95, 0.85, 0.36, 10, 0.24, phase=math.pi / 10)  # tips 0.04 apart: no shared planes
g["Dark"].append(cyl((1.55, 0, 0.8), 0.2, 0.6, rot=X90, verts=20))  # output shaft x 1.25..1.85
g["Chrome"].append(cyl((1.82, 0, 0.8), 0.36, 0.12, rot=X90, verts=24))  # flange
g["Dark"].append(cyl((0.6, 0.35, 1.825), 0.07, 0.85, verts=12))  # shift lever z 1.4..2.25
g["Metal"].append(cyl((0.6, 0.35, 1.52), 0.24, 0.12, verts=20))  # lever boot plate z 1.46..1.58
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=0.22, location=(0.6, 0.35, 2.3))
g["Accent"].append(bpy.context.active_object)  # knob
roots.append(finish("Part_gearbox", g))

# intercooler: finned core between two chrome end tanks, inlet/outlet pipes with blue couplers
g = {"Dark": [], "Metal": [], "Chrome": [], "Blue": []}
g["Dark"].append(box((0, 0, 0.95), (2.2, 0.4, 1.54)))  # core z 0.18..1.72
for k in range(12):  # fins stand 0.04 proud front and back
    g["Metal"].append(box((0, 0, 0.3 + k * 0.12), (2.0, 0.48, 0.05)))
for zc in (0.16, 1.74):  # frame rails
    g["Metal"].append(box((0, 0, zc), (2.3, 0.52, 0.12)))
for s in (-1, 1):
    g["Chrome"].append(box((s * 1.26, 0, 0.95), (0.4, 0.6, 1.8), bev=0.08))  # end tank x 1.06..1.46 (core ends 0.04 inside)
    pz = 1.35 if s > 0 else 0.55
    g["Chrome"].append(cyl((s * 1.65, 0, pz), 0.2, 0.6, rot=X90, verts=24))  # pipe x 1.35..1.95
    g["Blue"].append(cyl((s * 1.6, 0, pz), 0.25, 0.18, rot=X90, verts=24))  # coupler
    g["Chrome"].append(torus((s * 1.95, 0, pz), 0.2, 0.05, rot=X90, seg=24, minor=8))  # pipe lip
    g["Dark"].append(cyl((s * 1.945, 0, pz), 0.16, 0.09, rot=X90, verts=20))  # pipe mouth
roots.append(finish("Part_intercooler", g))

# quantum chip: dark board, gold pins on all four sides, gold traces, metal frame around a glowing core
g = {"Dark": [], "Gold": [], "Metal": [], "Glow": []}
g["Dark"].append(box((0, 0, 0.17), (2.6, 2.6, 0.3), bev=0.06))  # board z 0.02..0.32
for side in range(4):
    rz = side * math.pi / 2
    c, sn = math.cos(rz), math.sin(rz)
    def place(u, v, z, size):  # u along the edge normal, v along the edge
        g["Gold"].append(box((c * u - sn * v, sn * u + c * v, z), size, rot=(0, 0, rz)))
    for p in (-1.0, -0.6, -0.2, 0.2, 0.6, 1.0):
        place(1.345, p, 0.12, (0.45, 0.14, 0.08))  # pin, out of the board edge
        place(1.49, p, 0.065, (0.1, 0.08, 0.13))  # pin foot
    for p in (-0.6, -0.2, 0.2, 0.6):
        place(0.925, p, 0.33, (0.45, 0.08, 0.08))  # traces z 0.29..0.37
g["Metal"].append(box((0, 0, 0.4), (1.3, 1.3, 0.24), bev=0.04))  # frame z 0.28..0.52
g["Glow"].append(box((0, 0, 0.55), (0.9, 0.9, 0.3), bev=0.06))  # core z 0.40..0.70
for sx in (-1, 1):
    for sy in (-1, 1):
        g["Glow"].append(cyl((sx * 0.98, sy * 0.98, 0.34), 0.1, 0.1, verts=16))  # corner LEDs z 0.29..0.39
roots.append(finish("Part_chip", g))

# ---------------------------------------------------------------- tuning parts
# ECU (chip tune): finned aluminium box, connector, exposed board with a gold chip
g = {"Metal": [], "Dark": [], "Green": [], "Gold": []}
g["Metal"].append(box((0, 0, 0.35), (2.0, 1.4, 0.5), bev=0.06))
for k in range(7):
    g["Metal"].append(box((-0.75 + k * 0.25, 0, 0.7), (0.08, 1.3, 0.26)))
g["Dark"].append(box((1.1, 0, 0.35), (0.3, 1.0, 0.36), bev=0.03))
g["Green"].append(box((-0.2, -0.84, 0.2), (1.4, 0.32, 0.06)))  # board sunk 0.02 into the case
g["Gold"].append(box((-0.2, -0.86, 0.26), (0.4, 0.2, 0.1)))
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
g["Chrome"].append(cyl((0, 0, 1.76), 0.55, 0.4))  # inlet hat sits in the ribs (was floating)
g["Dark"].append(cyl((0, 0, 1.97), 0.48, 0.1))
g["Metal"].append(box((0, 0, 0.28), (2.6, 1.6, 0.2), bev=0.05))
roots.append(finish("Tune_super", g))

# sport exhaust: oval muffler + twin polished tips
g = {"Metal": [], "Chrome": [], "Dark": []}
m = cyl((0, 0, 0.7), 0.6, 2.2, rot=X90, verts=32)
m.scale = (1, 1.5, 1)
g["Metal"].append(m)
g["Metal"].append(cyl((-1.6, 0, 0.7), 0.18, 1.2, rot=X90, verts=16))
for s in (-1, 1):
    g["Chrome"].append(cyl((1.45, s * 0.4, 0.7), 0.26, 0.8, rot=X90))  # 0.05 into the muffler
    g["Dark"].append(cyl((1.86, s * 0.4, 0.7), 0.2, 0.1, rot=X90))
roots.append(finish("Tune_exhaust", g))

# cold air intake: cone filter + mandrel pipe
g = {"Accent": [], "Chrome": [], "Dark": []}
g["Accent"].append(cone((0.6, 0, 0.8), 0.75, 0.5, 1.4, rot=X90))
for k in range(10):
    g["Dark"].append(torus((0.0 + k * 0.13, 0, 0.8), 0.72 - k * 0.025, 0.03, rot=X90, seg=28, minor=4))
g["Chrome"].append(cyl((1.37, 0, 0.8), 0.52, 0.2, rot=X90))  # end cap touches the cone (was floating)
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
g["Carbon"].append(box((0.35, 0, 2.0), (0.3, 3.62, 0.08), rot=(0, math.radians(-25), 0)))
for s in (-1, 1):
    g["Carbon"].append(box((0, s * 1.82, 1.85), (1.1, 0.1, 0.6), bev=0.02))  # wing ends 0.03 inside the plates
    g["Metal"].append(box((-0.15, s * 0.8, 0.95), (0.12, 0.1, 1.7), rot=(0, math.radians(12), 0)))
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
