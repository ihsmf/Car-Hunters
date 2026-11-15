"""Monster-truck boss arena kit (Blender). One FBX per model in assets/arena/, merges ModelSizes.lua.
  python3 blender/make_arena.py [--only A_A,A_B] [--render [--render-out path.png]]
Sizes are in studs (1 Blender unit = 1 stud). Meshes are named by look (ModelLooks.lua); the map builder (BuildCityMap
buildArena) recolours Accent per arena and writes the arena name on the Jumbotron's Screen (its +X face).

Axes: everything is modelled with Blender +X = Roblox +X (front), Blender +Z = Roblox up, Blender -Y = Roblox +Z.
The FBX import into Roblox maps Blender (x, y, z) to Roblox (-x, z, y) (checked on the uploaded MonsterTruck / FoodTruck
rbxm: their +X noses landed on Roblox -X), so the mesh data is turned 180 degrees about Z just for the export.
Every model has its origin at the bottom centre."""
import math, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import bmesh
from mathutils import Matrix, Vector, noise
import make_cars as mc

OUT = os.path.join(mc.ROOT, "assets", "arena")
os.makedirs(OUT, exist_ok=True)
mc.reset()

# ---------------------------------------------------------------- looks (colours from ModelLooks.lua, sRGB -> linear)
LOOKS_LUA = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "src", "ReplicatedStorage", "Shared", "ModelLooks.lua")
LOOK = {}
for name, mat_, r, g_, b in re.findall(r"(\w+) = \{ M\.(\w+), C\((\d+), (\d+), (\d+)\)", open(LOOKS_LUA).read()):
    col = tuple((int(v) / 255) ** 2.2 for v in (r, g_, b)) + (1,)
    LOOK[name] = (col, 0.85 if mat_ == "Metal" else 0.0, 0.3 if mat_ == "Metal" else (0.05 if mat_ == "Glass" else 0.5))
LOOK.setdefault("Frame", (((58 / 255) ** 2.2, (62 / 255) ** 2.2, (70 / 255) ** 2.2, 1), 0.85, 0.35))


def M(look):
    c, metal, rough = LOOK[look]
    return mc.mat(look, c, metal=metal, rough=rough, emit=c if look == "Glow" else None, alpha=0.45 if look == "Glass" else 1.0)


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
        ob.data.transform(ob.matrix_basis)  # origin on the model origin, so the export flip turns about it
        ob.matrix_basis = Matrix.Identity(4)
        for p in ob.data.polygons:
            p.use_smooth = True
        ob.data.set_sharp_from_angle(angle=math.radians(40))
        ob.parent = root
    return root


def G(*looks):
    return {k: [] for k in looks}


# ---------------------------------------------------------------- primitives
def box(loc, size, bev=0.0, seg=2, rot=(0, 0, 0)):
    b = mc.prim("box", "b", loc, size, rot=rot)
    if bev:
        mc.bevel(b, bev, seg)
    return b


def bx(x0, x1, y0, y1, z0, z1, bev=0.0, seg=2):
    """box from coordinate ranges"""
    return box(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)), bev, seg)


def cyl(loc, r, h, axis="z", verts=24, bev=0.0):
    rot = {"z": (0, 0, 0), "x": (0, math.pi / 2, 0), "y": (math.pi / 2, 0, 0)}[axis]
    o = mc.prim("cyl", "c", loc, (2 * r, 2 * r, h), rot=rot, verts=verts)
    if bev:
        mc.bevel(o, bev, 2)
    return o


def cyl_ab(a, b, r, verts=12, bev=0.0):
    """cylinder from point a to point b"""
    a, b = Vector(a), Vector(b)
    d = b - a
    o = cyl((0, 0, 0), r, d.length, verts=verts)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    o.location = (a + b) / 2
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)
    if bev:
        mc.bevel(o, bev, 2)
    return o


def sphere(loc, r, seg=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=loc)
    return bpy.context.active_object


def torus(loc, R, r, axis="z", seg=40, minor=8):
    rot = {"z": (0, 0, 0), "x": (0, math.pi / 2, 0), "y": (math.pi / 2, 0, 0)}[axis]
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=seg, minor_segments=minor, location=loc, rotation=rot)
    return bpy.context.active_object


def mesh_ob(name, build):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    build(bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


def triangulate(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def prism(F, pts, n0, n1, bev=0.0, tri=False):
    """polygon (u, v) in frame F = (O, U, V, N), extruded along N from n0 to n1"""
    O, U, V, N = (Vector(v) for v in F)

    def b(bm):
        a = [bm.verts.new(O + U * u + V * v + N * n0) for u, v in pts]
        c = [bm.verts.new(O + U * u + V * v + N * n1) for u, v in pts]
        bm.faces.new(a)
        bm.faces.new(list(reversed(c)))
        for i in range(len(a)):
            j = (i + 1) % len(a)
            bm.faces.new((a[j], a[i], c[i], c[j]))
    o = mesh_ob("prism", b)
    if tri:
        triangulate(o)
    if bev:
        mc.bevel(o, bev, 2)
    return o


def lathe(prof, axis="z", c=(0, 0, 0), seg=48, closed=False):
    """revolve a (r, h) profile around an axis through c; points with r = 0 lie on the axis"""
    cx, cy, cz = c

    def P(r, a, h):
        ca, sa = math.cos(a) * r, math.sin(a) * r
        if axis == "z":
            return (cx + ca, cy + sa, cz + h)
        if axis == "x":
            return (cx + h, cy + ca, cz + sa)
        return (cx + ca, cy + h, cz + sa)

    def b(bm):
        rings = []
        for r, h in prof:
            if r < 1e-6:
                rings.append([bm.verts.new(P(0, 0, h))])
            else:
                rings.append([bm.verts.new(P(r, k / seg * 2 * math.pi, h)) for k in range(seg)])
        pairs = list(zip(rings, rings[1:])) + ([(rings[-1], rings[0])] if closed else [])
        for p, q in pairs:
            if len(p) == 1 and len(q) == 1:
                continue
            for k in range(seg):
                j = (k + 1) % seg
                if len(p) == 1:
                    bm.faces.new((p[0], q[k], q[j]))
                elif len(q) == 1:
                    bm.faces.new((p[k], q[0], p[j]))
                else:
                    bm.faces.new((p[k], q[k], q[j], p[j]))
    return mesh_ob("lathe", b)


def sweep(pts, r, sides=8, caps=True):
    """round tube along a 3D polyline (parallel-transport frames)"""
    pts = [Vector(p) for p in pts]

    def b(bm):
        rings = []
        N = None
        for i, p in enumerate(pts):
            T = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
            if N is None:
                a = Vector((0, 0, 1)) if abs(T.z) < 0.9 else Vector((1, 0, 0))
                N = (a - T * a.dot(T)).normalized()
            else:
                N = (N - T * N.dot(T)).normalized()
            B = T.cross(N)
            rings.append([bm.verts.new(p + r * (math.cos(k / sides * 2 * math.pi) * N + math.sin(k / sides * 2 * math.pi) * B)) for k in range(sides)])
        for p, q in zip(rings, rings[1:]):
            for k in range(sides):
                j = (k + 1) % sides
                bm.faces.new((p[k], p[j], q[j], q[k]))
        if caps:
            bm.faces.new(rings[0])
            bm.faces.new(list(reversed(rings[-1])))
    return mesh_ob("sweep", b)


def fillet(pts, R, n=6):
    """2D polyline with its inner corners rounded (radius R)"""
    pts = [Vector((p[0], p[1])) for p in pts]
    out = [pts[0]]
    for i in range(1, len(pts) - 1):
        P, A, B = pts[i], pts[i - 1], pts[i + 1]
        d1, d2 = (A - P).normalized(), (B - P).normalized()
        th = math.acos(max(-1, min(1, d1.dot(d2))))
        t = R / math.tan(th / 2)
        bis = (d1 + d2).normalized()
        C = P + bis * (R / math.sin(th / 2))
        T1, T2 = P + d1 * t, P + d2 * t
        a1, a2 = math.atan2(*(T1 - C).yx), math.atan2(*(T2 - C).yx)
        da = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
        for k in range(n + 1):
            a = a1 + da * k / n
            out.append(C + R * Vector((math.cos(a), math.sin(a))))
    out.append(pts[-1])
    return out


def boolean(base, others, op):
    for o in others:
        m = base.modifiers.new("b", "BOOLEAN")
        m.object, m.operation, m.solver = o, op, "EXACT"
    mc.apply_mods(base)
    for o in others:
        bpy.data.objects.remove(o)
    return triangulate(base)


def circle(cu, cv, r, n=20):
    return [(cu + math.cos(k / n * 2 * math.pi) * r, cv + math.sin(k / n * 2 * math.pi) * r) for k in range(n)]


def clip_u(poly, u0, u1):
    """clip a convex (u, v) polygon to u0 <= u <= u1"""
    for sgn, lim in ((1, u0), (-1, u1)):
        out = []
        for i in range(len(poly)):
            p, q = poly[i - 1], poly[i]
            sp, sq = sgn * (p[0] - lim), sgn * (q[0] - lim)
            if sq >= 0:
                if sp < 0:
                    t = sp / (sp - sq)
                    out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
                out.append(q)
            elif sp >= 0:
                t = sp / (sp - sq)
                out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
        poly = out
    return poly


def hazard(g, F, u0, u1, v0, v1, n0, n1, w=0.45):
    """45 degree yellow (Accent) / black (Dark) stripes filling the rectangle u0..u1 x v0..v1 of frame F"""
    h = v1 - v0
    k0 = math.floor((u0 - h) / w) - 1
    for k in range(k0, math.ceil(u1 / w) + 1):
        a = k * w
        poly = clip_u([(a, v0), (a + w, v0), (a + w + h, v1), (a + h, v1)], u0, u1)
        if len(poly) < 3:
            continue
        ar = 0.5 * abs(sum(poly[i - 1][0] * poly[i][1] - poly[i][0] * poly[i - 1][1] for i in range(len(poly))))
        if ar > 1e-3:
            g["Accent" if k % 2 == 0 else "Dark"].append(prism(F, poly, n0, n1))


X_, Y_, Z_ = (1, 0, 0), (0, 1, 0), (0, 0, 1)
roots = []


# ---------------------------------------------------------------- arena helpers
def bake(ob):
    """move the object transform into the mesh data (origin back on the model origin)"""
    ob.data.transform(ob.matrix_basis)
    ob.matrix_basis = Matrix.Identity(4)
    return ob


def xform(ob, Mx):
    bake(ob)
    ob.data.transform(Mx)
    return ob


def crumple(ob, amp, seed, cuts=2, freq=0.9):
    """crushed-metal look: subdivide, push the vertices in and out along their normals with seeded noise"""
    bake(ob)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    bm.normal_update()
    off = Vector((seed * 3.17, seed * 1.71, seed * 2.33))
    for v in bm.verts:
        v.co += v.normal * (amp * (noise.noise(v.co * freq + off) - 0.35))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def dent_radial(ob, dents):
    """push vertices towards the Z axis around (centre, sigma, depth) dents (same field for every barrel piece)"""
    bake(ob)
    for v in ob.data.vertices:
        r = math.hypot(v.co.x, v.co.y)
        if r < 0.5:
            continue
        d = sum(a * math.exp(-(v.co - c).length_squared / (s * s)) for c, s, a in dents)
        v.co.x -= v.co.x / r * d
        v.co.y -= v.co.y / r * d
    return ob


def tyre_prof(R, ri, w, k=0.08, groove=None):
    """closed (r, h) tyre section centred on h = 0; groove = half width of a 0.1 deep band groove round the tread"""
    h = w / 2
    p = [(ri, -h + k), (ri + k, -h), (R - 1.5 * k, -h), (R - 0.3 * k, -h + 0.8 * k), (R, -h + 2 * k)]
    if groove:
        p += [(R, -groove), (R - 0.1, -groove), (R - 0.1, groove), (R, groove)]
    p += [(R, h - 2 * k), (R - 0.3 * k, h - 0.8 * k), (R - 1.5 * k, h), (ri + k, h), (ri, h - k)]
    return p


def band_prof(R, groove):
    """painted band that sits in tyre_prof's groove, 0.02 proud of the tread"""
    return [(R - 0.14, -groove + 0.005), (R + 0.02, -groove + 0.005), (R + 0.02, groove - 0.005), (R - 0.14, groove - 0.005)]


def ring_ab(pts, r, sides=6):
    return sweep(pts, r, sides)


# ---------------------------------------------------------------- A_FloodLight: stadium light tower, 30 high, lamps aimed +X and down
g = G("Concrete", "Dark", "Frame", "Metal", "Accent", "Glow", "Rubber")
g["Concrete"].append(bx(-2, 2, -2, 2, 0, 1.2, bev=0.12))
for U, N in (((0, 1, 0), (1, 0, 0)), ((0, 1, 0), (-1, 0, 0)), ((1, 0, 0), (0, 1, 0)), ((1, 0, 0), (0, -1, 0))):
    hazard(g, ((0, 0, 0), U, Z_, N), -1.7, 1.7, 0.42, 0.86, 2.0, 2.08, w=0.4)
g["Dark"].append(bx(-1.55, 1.55, -1.55, 1.55, 1.2, 1.4, bev=0.05))
LG = lambda z: 1.2 - 0.6 * (z - 1.4) / 23.6  # half width of the tapered mast at height z
CORNERS = [(1, 1), (1, -1), (-1, -1), (-1, 1)]
LEV = [1.4 + k * 2.36 for k in range(11)]  # LEV[10] = 25.0 = platform
P_ = lambda c, z: (c[0] * LG(z), c[1] * LG(z), z)
for c in CORNERS:
    g["Frame"].append(cyl_ab((c[0] * 1.2, c[1] * 1.2, 1.0), P_(c, 25.05), 0.14, 8))
for f in range(4):
    a, b = CORNERS[f], CORNERS[(f + 1) % 4]
    for k in range(1, 10):
        g["Metal"].append(cyl_ab(P_(a, LEV[k]), P_(b, LEV[k]), 0.07, 6))
    for k in range(10):
        g["Metal"].append(cyl_ab(P_(a, LEV[k]), P_(b, LEV[k + 1]), 0.055, 6))
        g["Metal"].append(cyl_ab(P_(b, LEV[k]), P_(a, LEV[k + 1]), 0.055, 6))
# platform + Accent guard rail (open at the ladder, -X)
g["Metal"].append(bx(-2.1, 2.1, -3.0, 3.0, 25.0, 25.25, bev=0.04))
g["Metal"].append(bx(-2.5, -2.1, -0.45, 0.45, 24.95, 25.15, bev=0.03))  # ladder landing
RP = [(2.0, -2.9), (2.0, 0), (2.0, 2.9), (0, 2.9), (-2.0, 2.9), (-2.0, 0.6), (-2.0, -0.6), (-2.0, -2.9), (0, -2.9)]
for x, y in RP:
    g["Accent"].append(cyl_ab((x, y, 25.25), (x, y, 26.2), 0.06, 8))
for (x0, y0), (x1, y1) in (((2.0, -2.9), (2.0, 2.9)), ((2.0, 2.9), (-2.0, 2.9)), ((-2.0, 2.9), (-2.0, 0.6)), ((-2.0, -0.6), (-2.0, -2.9)),
                           ((-2.0, -2.9), (2.0, -2.9))):
    for z in (25.75, 26.2):
        g["Accent"].append(cyl_ab((x0, y0, z), (x1, y1, z), 0.055, 8))
for x, y in ((2.0, -2.9), (2.0, 2.9), (-2.0, 2.9), (-2.0, -2.9), (-2.0, 0.6), (-2.0, -0.6)):
    g["Accent"].append(sphere((x, y, 26.2), 0.085, 10))
# lamp bank: 3 rows x 4 lamps on a plate tilted 20 degrees down, facing +X
t = math.radians(20)
NB, VB, UB = Vector((math.cos(t), 0, -math.sin(t))), Vector((math.sin(t), 0, math.cos(t))), Vector((0, 1, 0))
OB = Vector((0.5, 0, 28.0))
FB = (OB, UB, VB, NB)
rect = lambda u0, u1, v0, v1: [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
g["Dark"].append(prism(FB, rect(-2.75, 2.75, -1.9, 1.9), -0.3, 0.0, bev=0.06))
g["Metal"].append(prism(FB, rect(-2.85, 2.85, 1.9, 2.05), -0.4, 0.5, bev=0.03))  # rain hood
for u in (-2.04, -0.68, 0.68, 2.04):
    for v in (-1.24, 0.0, 1.24):
        g["Frame"].append(prism(FB, circle(u, v, 0.58, 20), 0.0, 0.32, bev=0.04))
        g["Glow"].append(prism(FB, circle(u, v, 0.46, 20), 0.2, 0.42))
g["Dark"].append(prism(FB, rect(-0.5, 0.5, -0.6, 0.4), -0.75, -0.3, bev=0.04))  # junction box
g["Frame"].append(cyl_ab((-0.2, 0, 25.25), (-0.2, 0, 28.2), 0.25, 12))
for s in (-1, 1):
    g["Frame"].append(cyl_ab((-1.2, s * 2.0, 25.25), OB + UB * s * 2.0 - NB * 0.3 - VB * 0.8, 0.1, 8))
# service ladder on the -X side with a safety cage
LX = -2.35
for s in (-1, 1):
    g["Metal"].append(cyl_ab((LX, s * 0.35, 0), (LX, s * 0.35, 26.3), 0.06, 8))
    for k in range(1, 10):
        g["Metal"].append(cyl_ab((LX, s * 0.35, LEV[k]), (-LG(LEV[k]), s * 0.35, LEV[k]), 0.045, 6))
for k in range(31):
    z = 0.5 + k * 0.8
    g["Metal"].append(cyl_ab((LX, -0.35, z), (LX, 0.35, z), 0.04, 6))
cc, cr = LX - 0.3, math.hypot(0.3, 0.35)
a0 = math.atan2(-0.35, 0.3)
for k in range(9):
    z = 4.0 + k * 2.5
    arc = [(cc + cr * math.cos(a0 - (2 * math.pi + 2 * a0) * i / 12), cr * math.sin(a0 - (2 * math.pi + 2 * a0) * i / 12), z) for i in range(13)]
    g["Metal"].append(sweep(arc, 0.035, 6))
# power cable from the junction box down the (-X, +Y) leg to the plinth
cab = [OB + UB * 0.3 - VB * 0.6 - NB * 0.5, Vector((-0.3, 0.3, 25.6)), Vector((-0.45, 0.45, 25.0))]
for k in range(10, -1, -1):
    z = LEV[k] - 0.6 if k else 1.55
    o = LG(z) + 0.2
    cab.append(Vector((-o, o, z)))
cab.append(Vector((-1.45, 1.45, 1.4)))
g["Rubber"].append(sweep(cab, 0.07, 8))
roots.append(finish("A_FloodLight", g))

# ---------------------------------------------------------------- A_Bleachers: 24 (Y) x 9 (X) x 7, six rows stepping up towards -X, stairs at +Y
g = G("Metal", "Frame", "Accent", "Dark", "Chrome")
XF = [4.3 - 1.4 * i for i in range(6)]  # front edge of each tier
ZS = [0.8 + 0.95 * i for i in range(6)]  # seat top
ZF = [0.25 + 0.95 * i for i in range(6)]  # footboard bottom
ST = [(-11.95, -11.55), (-6.02, -5.78), (-0.12, 0.12), (5.78, 6.02), (9.45, 9.65)]  # frame stations (y ranges)
Y0, Y1 = -11.7, 9.5  # bench span (the stair bay is y 9.65..11.8)
for i in range(6):
    xf, zs, zf = XF[i], ZS[i], ZF[i]
    g["Metal"].append(bx(xf - 1.35, xf - 0.97, Y0, Y1, zs - 0.12, zs, bev=0.03))
    g["Metal"].append(bx(xf - 0.93, xf - 0.55, Y0, Y1, zs - 0.12, zs, bev=0.03))
    g["Metal"].append(bx(xf - 0.5, xf, Y0, Y1, zf, zf + 0.1, bev=0.025))
    g["Accent"].append(bx(xf - 0.72, xf - 0.64, Y0, Y1, max(zf - 0.15, 0.06), zs - 0.2))  # riser / kick plate
    for yl, yh in ST:
        yc = (yl + yh) / 2
        g["Frame"].append(bx(xf - 1.4 if i < 5 else -4.45, xf - 0.55, yl, yh, zs - 0.27, zs - 0.12))
        g["Frame"].append(bx(xf - 0.55, xf, yl, yh, zf - 0.15 if i else 0, zf))
        g["Frame"].append(bx(xf - 0.55, xf - 0.43, yl + 0.02, yh - 0.02, zf, zs - 0.27))
        if i:
            g["Frame"].append(cyl_ab((xf - 0.3, yc, 0.08), (xf - 0.3, yc, zf - 0.15), 0.09, 10))
            g["Dark"].append(cyl((xf - 0.3, yc, 0.04), 0.18, 0.08, verts=12))
            if i < 5:
                g["Metal"].append(cyl_ab((xf - 0.3, yc, 0.3), (XF[i + 1] - 0.3, yc, ZF[i + 1] - 0.3), 0.05, 6))
    if i >= 2:
        g["Metal"].append(cyl_ab((xf - 0.3, -11.75, (zf - 0.15) / 2), (xf - 0.3, 9.55, (zf - 0.15) / 2), 0.05, 6))
# stairs in the +Y end bay: 12 treads between two channel stringers
SL = 0.475 / 0.7
for k in range(12):
    zt = 0.25 + 0.475 * k
    g["Metal"].append(bx(4.3 - 0.7 * k - 0.75, 4.3 - 0.7 * k, 9.75, 11.65, zt - 0.12, zt, bev=0.03))
strg = [(4.45 - 0.3 / SL, 0), (4.45, 0), (4.45, 0.3), (-4.2, 0.3 + 8.65 * SL), (-4.2, 8.65 * SL - 0.3)]
for y0 in (9.6, 11.65):
    g["Frame"].append(prism(((0, y0, 0), X_, Z_, Y_), strg, 0, 0.15, bev=0.02))
# railings: back (z 7), -Y side (sloped), +Y stair handrail
rail_z = lambda x: 1.8 + (4.3 - x) / 8.6 * 5.14
for yc in (-11.75, -5.9, 0.0, 5.9, 9.55):
    g["Metal"].append(cyl_ab((-4.3, yc, ZS[5] - 0.27), (-4.3, yc, 6.94), 0.07, 10))
for yc in (-11.85, 11.8):
    g["Metal"].append(cyl_ab((-4.3, yc, 0), (-4.3, yc, 6.94), 0.07, 10))
    g["Dark"].append(cyl((-4.3, yc, 0.04), 0.18, 0.08, verts=12))
g["Chrome"].append(cyl_ab((-4.3, -11.85, 6.94), (-4.3, 11.8, 6.94), 0.07, 12))
g["Chrome"].append(cyl_ab((-4.3, -11.85, 6.25), (-4.3, 11.8, 6.25), 0.05, 10))
g["Chrome"].append(cyl_ab((4.2, -11.85, rail_z(4.2)), (-4.3, -11.85, rail_z(-4.3)), 0.06, 12))
g["Metal"].append(cyl_ab((4.2, -11.85, 0.25), (4.2, -11.85, rail_z(4.2)), 0.06, 8))
for i in range(5):
    x = XF[i] - 1.0
    g["Metal"].append(cyl_ab((x, -11.85, ZS[i] - 0.12), (x, -11.85, rail_z(x)), 0.06, 8))
hr = lambda x: 0.25 + 0.475 * (4.3 - x) / 0.7 + 1.1
stop = lambda x: SL * (4.45 - x) + 0.3
g["Chrome"].append(cyl_ab((4.4, 11.73, hr(4.4)), (-4.3, 11.73, 6.94), 0.06, 12))
for x in (4.2, 2.8, 1.4, 0.0, -1.4, -2.8):
    zr = hr(4.4) + (6.94 - hr(4.4)) * (4.4 - x) / 8.7
    g["Metal"].append(cyl_ab((x, 11.73, stop(x) - 0.05), (x, 11.73, zr), 0.06, 8))
roots.append(finish("A_Bleachers", g))

# ---------------------------------------------------------------- A_Jumbotron: 22 (Y) x 26 screen on two truss towers, Screen faces +X
g = G("Concrete", "Frame", "Metal", "Dark", "Accent", "Screen", "Carbon", "Chrome")
for s in (-1, 1):
    yc = s * 7.0
    g["Concrete"].append(bx(-2.7, 0.3, yc - 1.5, yc + 1.5, 0, 0.6, bev=0.1))
    TC = [(-2.0, yc - 0.8), (-0.4, yc - 0.8), (-0.4, yc + 0.8), (-2.0, yc + 0.8)]
    for x, y in TC:
        g["Dark"].append(bx(x - 0.3, x + 0.3, y - 0.3, y + 0.3, 0.6, 0.7, bev=0.02))
        g["Frame"].append(cyl_ab((x, y, 0.7), (x, y, 12.45), 0.15, 8))
    TL = [0.7 + k * 1.95 for k in range(7)]
    for f in range(4):
        (xa, ya), (xb, yb) = TC[f], TC[(f + 1) % 4]
        for k in range(1, 6):
            g["Metal"].append(cyl_ab((xa, ya, TL[k]), (xb, yb, TL[k]), 0.06, 6))
        for k in range(6):
            p, q = ((xa, ya), (xb, yb)) if k % 2 == 0 else ((xb, yb), (xa, ya))
            g["Metal"].append(cyl_ab((p[0], p[1], TL[k]), (q[0], q[1], TL[k + 1]), 0.05, 6))
    g["Frame"].append(bx(-2.3, -0.1, yc - 1.1, yc + 1.1, 12.4, 12.6, bev=0.03))
    for y in (yc - 0.8, yc + 0.8):  # catwalk struts
        g["Frame"].append(cyl_ab((-2.0, y, 11.2), (-3.3, y, 12.2), 0.07, 8))
# cabinet + cooling ribs on the back
g["Dark"].append(bx(-1.4, 0.6, -10.8, 10.8, 12.6, 25.4, bev=0.15))
for k in range(5):
    z = 14.5 + k * 2.2
    g["Metal"].append(bx(-1.52, -1.3, -10.0, 10.0, z, z + 0.16, bev=0.03))
# Accent frame (one piece with the window cut out) and the Screen behind its 0.2 lip
fr = bx(0.5, 1.3, -11.0, 11.0, 12.4, 26.0, bev=0.12)
g["Accent"].append(boolean(fr, [bx(0.3, 1.5, -9.8, 9.8, 13.7, 24.3)], "DIFFERENCE"))
SCREEN = (0.75, 1.15, -10.0, 10.0, 13.5, 24.5)
g["Screen"].append(bx(*SCREEN))
# speaker cabinets hung under the screen, two woofers each
for s in (-1, 1):
    yc = s * 9.4
    g["Carbon"].append(bx(-1.0, 0.9, yc - 1.4, yc + 1.4, 9.4, 12.75, bev=0.12))
    for z in (10.3, 11.7):
        g["Metal"].append(lathe([(0.58, 0.0), (0.62, 0.04), (0.56, 0.09), (0.48, 0.09)], "x", (0.9, yc, z), 32))
        g["Dark"].append(lathe([(0.48, 0.09), (0.3, -0.05), (0.15, -0.18), (0.12, -0.18)], "x", (0.9, yc, z), 32))
        g["Chrome"].append(lathe([(0.15, -0.18), (0.12, -0.1), (0.0, -0.07)], "x", (0.9, yc, z), 24))
# service catwalk behind the cabinet
g["Metal"].append(bx(-3.4, -1.45, -10.6, 10.6, 12.2, 12.4, bev=0.03))
for k in range(9):
    y = -10.4 + k * 2.6
    g["Metal"].append(cyl_ab((-3.3, y, 12.4), (-3.3, y, 13.5), 0.05, 8))
for z in (12.95, 13.45):
    g["Chrome"].append(cyl_ab((-3.3, -10.4, z), (-3.3, 10.4, z), 0.05, 10))
roots.append(finish("A_Jumbotron", g))


# ---------------------------------------------------------------- A_CarPile: three crushed scrap cars, ~12 x 7 x 6
def crushed_car(g, body, cabin, L, W, at, yaw, roll, pitch, seed, wheels, patches=()):
    parts = []
    b = bx(-L / 2, L / 2, -W / 2, W / 2, 0, 1.25, bev=0.25, seg=1)
    parts.append((body, crumple(b, 0.13, seed)))
    x0, x1 = -L * 0.22 - 1.4, L * 0.12 + 1.0
    c = prism(((0, 0, 0), X_, Z_, Y_), [(x0, 0.9), (x1, 0.9), (x1 - 0.8, 1.75), (x0 + 0.7, 1.75)], -(W / 2 - 0.35), W / 2 - 0.35, bev=0.1)
    parts.append((cabin, crumple(c, 0.1, seed + 7)))
    parts.append(("Dark", bx(x0 + 0.55, x1 - 0.65, -(W / 2 - 0.15), W / 2 - 0.15, 1.33, 1.53)))
    for sx in (-1, 1):
        bu = bx(sx * (L / 2 - 0.1), sx * (L / 2 + 0.25), -(W / 2 - 0.25), W / 2 - 0.25, 0.25, 0.65, bev=0.08)
        parts.append(("Metal", crumple(bu, 0.05, seed + 3 * sx)))
    for px, py, pz, sr in patches:  # rust patches breaking through the paint
        sp = sphere((0, 0, 0), 1.0, 12)
        parts.append(("Rust", xform(sp, Matrix.Translation((px, py * (W / 2), pz)) @ Matrix.Diagonal((sr, 0.12, sr * 0.6, 1)))))
    for wx, side, rz, rx in wheels:
        T = Matrix.Translation((wx, side * (W / 2 + 0.05), 0.8)) @ Matrix.Rotation(math.radians(rz), 4, "Z") @ Matrix.Rotation(math.radians(rx), 4, "X")
        parts.append(("Rubber", xform(lathe(tyre_prof(0.8, 0.42, 0.65), "y", (0, 0, 0), 28, closed=True), T)))
        parts.append(("Rust", xform(lathe([(0, -0.22), (0.46, -0.24), (0.46, 0.2), (0.2, 0.16), (0, 0.18)], "y", (0, 0, 0), 20), T)))
    Mx = Matrix.Translation(at) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Rotation(math.radians(pitch), 4, "Y") @ \
        Matrix.Rotation(math.radians(roll), 4, "X")
    for look, ob in parts:
        g[look].append(xform(ob, Mx))


g = G("Rust", "Accent", "Blue", "Dark", "Metal", "Rubber")
crushed_car(g, "Rust", "Rust", 11.2, 5.2, (0, 0, 0), 3, 0, 0, 1, [(3.4, 1, 18, 0), (-3.5, 1, -12, 0), (3.3, -1, -22, 0), (-3.4, -1, 15, 0)])
crushed_car(g, "Accent", "Rust", 10.6, 5.0, (0.3, 0.1, 1.65), -9, 3, -2, 5, [(3.2, 1, 10, 28), (-3.3, -1, -15, -30)],
            patches=[(2.5, 1, 0.6, 0.6), (-3.0, -1, 0.7, 0.8), (-1.0, 1, 0.5, 0.5)])
crushed_car(g, "Blue", "Rust", 10.2, 5.0, (-0.2, -0.15, 3.3), 7, -3, 2, 9, [(-3.1, 1, 20, -25), (3.0, -1, 0, 32)],
            patches=[(-2.0, 1, 0.7, 0.7), (3.2, -1, 0.5, 0.6), (0.5, -1, 0.8, 0.5)])
lt = lathe(tyre_prof(0.8, 0.42, 0.65), "z", (0, 0, 0), 28, closed=True)  # loose tyre lying on the top car
g["Rubber"].append(xform(lt, Matrix.Translation((-1.6, 0.6, 5.28)) @ Matrix.Rotation(math.radians(8), 4, "X")))
for obs in g.values():  # crumpled undersides of the bottom car stay on the ground
    for ob in obs:
        for v in ob.data.vertices:
            v.co.z = max(v.co.z, 0.0)
roots.append(finish("A_CarPile", g))

# ---------------------------------------------------------------- A_TireWall: 3 layers x 6 tyres, 12 (Y) x 2 (X) x 2.6, on a strap frame
g = G("Rubber", "Accent", "White", "Metal", "Dark", "Chrome")
TR_, TI_, TW_, GR = 0.92, 0.42, 0.8, 0.13
for L_ in range(3):
    for k in range(6):
        y, zc = (k - 2.5) * 1.9, L_ * 0.8 + 0.4
        if L_ == 1:  # middle row plain, top + bottom rows banded Accent / White
            g["Rubber"].append(lathe(tyre_prof(TR_, TI_, TW_), "z", (0, y, zc), 28, closed=True))
        else:
            g["Rubber"].append(lathe(tyre_prof(TR_, TI_, TW_, groove=GR), "z", (0, y, zc), 28, closed=True))
            g["Accent" if (k + L_ // 2) % 2 == 0 else "White"].append(lathe(band_prof(TR_, GR), "z", (0, y, zc), 28, closed=True))
for s in (-1, 1):
    g["Metal"].append(bx(-1.0, 1.0, s * 5.7, s * 6.0, 0, 2.6, bev=0.04))
    for z in (0.4, 2.0):
        g["Chrome"].append(cyl((1.04, s * 5.85, z), 0.06, 0.08, axis="x", verts=8))
        g["Chrome"].append(cyl((-1.04, s * 5.85, z), 0.06, 0.08, axis="x", verts=8))
for L_ in range(3):
    z = L_ * 0.8 + 0.3
    for sx in (-1, 1):
        g["Dark"].append(bx(sx * 0.9, sx * 1.0, -5.7, 5.7, z, z + 0.2))
g["Metal"].append(bx(-0.3, 0.3, -5.7, 5.7, 2.4, 2.6, bev=0.03))
roots.append(finish("A_TireWall", g))

# ---------------------------------------------------------------- A_Ramp: 14 (X) x 8 (Y) x 4 steel jump ramp, low entry at +X, lip at -X
g = G("Metal", "Frame", "Accent", "Dark")
SR = 3.70 / 13.75
g["Metal"].append(prism(((0, 0, 0), X_, Z_, Y_), [(6.52, 0), (7.0, 0), (7.0, 0.12), (-6.75, 3.82), (-6.75, 3.57)], -4, 4, bev=0.05))
B_ = Vector((7.0, 0, 0.12))
US = (Vector((-6.75, 0, 3.82)) - B_)
LS = US.length
US.normalize()
NS = Vector((-US.z, 0, US.x)) if US.x < 0 else Vector((US.z, 0, -US.x))
NS = NS if NS.z > 0 else -NS
FS = (B_, US, Vector(Y_), NS)
for i in range(22):
    for j in range(14):
        cu, cv = 1.3 + i * 0.55, -3.575 + j * 0.55
        d = (0.707, 0.707) if (i + j) % 2 else (0.707, -0.707)
        p = (-d[1], d[0])
        pts = [(cu + d[0] * 0.2, cv + d[1] * 0.2), (cu + p[0] * 0.06, cv + p[1] * 0.06), (cu - d[0] * 0.2, cv - d[1] * 0.2), (cu - p[0] * 0.06, cv - p[1] * 0.06)]
        g["Metal"].append(prism(FS, pts, 0, 0.09))
FH = (B_, Vector(Y_), US, NS)
hazard(g, FH, -3.92, 3.92, 0.15, 0.95, 0, 0.1, w=0.5)
hazard(g, FH, -3.92, 3.92, LS - 0.95, LS - 0.1, 0, 0.1, w=0.5)
g["Frame"].append(bx(-6.95, -6.75, -3.95, 3.95, 0, 3.57, bev=0.03))
hazard(g, ((0, 0, 0), Y_, Z_, (-1, 0, 0)), -3.8, 3.8, 2.85, 3.4, 6.95, 7.03, w=0.5)
zb_ = lambda x: 3.17 - SR * (x + 6.75)  # underside of the stringers
PXS = (-6.4, -3.6, -0.8, 2.0)
for y0 in (-3.6, 0.0, 3.6):
    g["Frame"].append(prism(((0, y0, 0), X_, Z_, Y_), [(5.03, 0), (6.52, 0), (-6.75, 3.57), (-6.75, 3.17)], -0.2, 0.2, bev=0.02))
    g["Frame"].append(bx(-6.75, 5.0, y0 - 0.28, y0 + 0.28, 0, 0.2, bev=0.03))
    for x in PXS:
        g["Frame"].append(bx(x - 0.12, x + 0.12, y0 - 0.12, y0 + 0.12, 0.2, zb_(x - 0.12) + 0.1))
    for xa, xb in zip(PXS, PXS[1:] + (4.2,)):
        g["Metal"].append(cyl_ab((xa, y0, 0.25), (xb, y0, zb_(xb) - 0.05 if xb < 4 else 0.25), 0.05, 6))
for x in PXS[:3]:
    h = zb_(x) * 0.55
    g["Metal"].append(cyl_ab((x, -3.6, h), (x, 3.6, h), 0.06, 8))
roots.append(finish("A_Ramp", g))

# ---------------------------------------------------------------- A_FireBarrel: rusty open drum (d 2, h 3) with a Glow fire
g = G("Rust", "Accent", "Dark", "Glow")
DENTS = [(Vector((math.cos(a), math.sin(a), z)), s, d) for a, z, s, d in ((0.6, 0.6, 0.35, 0.09), (2.5, 1.5, 0.4, 0.07), (4.1, 2.5, 0.3, 0.08),
                                                                          (5.3, 1.25, 0.32, 0.06))]
p1 = [(0, 0), (0.97, 0), (1.0, 0.03), (1.0, 0.11), (0.96, 0.16), (0.96, 0.91), (0.99, 0.96), (1.0, 1.0), (0.99, 1.04), (0.96, 1.09)]
p2 = [(0.96, 1.91), (0.99, 1.96), (1.0, 2.0), (0.99, 2.04), (0.96, 2.09), (0.96, 2.84), (1.0, 2.89), (1.0, 2.97), (0.97, 3.0), (0.93, 3.0),
      (0.91, 2.96), (0.91, 2.3), (0, 2.3)]
g["Rust"].append(dent_radial(lathe(p1, "z", (0, 0, 0), 48), DENTS))
g["Accent"].append(dent_radial(lathe([(0.96, 1.09), (0.96, 1.91)], "z", (0, 0, 0), 48), DENTS))
g["Rust"].append(dent_radial(lathe(p2, "z", (0, 0, 0), 48), DENTS))
for a, b in (((-0.6, -0.3, 2.42), (0.6, 0.35, 2.5)), ((-0.35, 0.55, 2.45), (0.4, -0.55, 2.62)), ((0.55, 0.4, 2.42), (-0.2, -0.6, 2.42))):
    g["Dark"].append(cyl_ab(a, b, 0.12, 8))
FL = [(0, 0), (0.42, 0.18), (0.46, 0.5), (0.36, 0.95), (0.2, 1.45), (0, 1.95)]
for dx, dy, sr, sh, tx, ty in ((0, 0, 1.4, 1.2, 0, 0), (0.35, 0.2, 0.9, 1.0, 0.25, -0.15), (-0.3, 0.25, 0.85, 0.85, -0.2, 0.1),
                               (0.05, -0.38, 0.8, 0.95, 0.1, 0.25), (-0.25, -0.2, 0.7, 1.2, -0.1, -0.25)):
    T = Matrix.Translation((dx, dy, 2.3)) @ Matrix.Rotation(tx, 4, "X") @ Matrix.Rotation(ty, 4, "Y") @ Matrix.Diagonal((sr, sr, sh, 1))
    g["Glow"].append(xform(lathe(FL, "z", (0, 0, 0), 12), T))
roots.append(finish("A_FireBarrel", g))

# ---------------------------------------------------------------- A_Skull: boss skull sign on two posts, 8 wide x 10 high, faces +X
g = G("Concrete", "Dark", "Frame", "Accent", "White", "Glow", "Chrome")
IB = [(-0.3, -0.3), (-0.2, -0.3), (-0.2, -0.05), (0.2, -0.05), (0.2, -0.3), (0.3, -0.3), (0.3, 0.3), (0.2, 0.3), (0.2, 0.05), (-0.2, 0.05),
      (-0.2, 0.3), (-0.3, 0.3)]
for s in (-1, 1):
    y0 = s * 3.0
    g["Concrete"].append(bx(-1.4, -0.1, y0 - 0.65, y0 + 0.65, 0, 0.6, bev=0.08))
    g["Dark"].append(bx(-1.15, -0.35, y0 - 0.4, y0 + 0.4, 0.6, 0.68, bev=0.02))
    g["Frame"].append(prism(((-0.75, y0, 0), X_, Y_, Z_), IB, 0.68, 9.3, bev=0.02, tri=True))
g["Accent"].append(bx(-0.45, -0.2, -4.0, 4.0, 3.0, 10.0, bev=0.12))
g["Dark"].append(bx(-0.25, 0.0, -3.7, 3.7, 3.3, 9.7, bev=0.08))
for y in (-3.75, 3.75):
    for z in (3.25, 9.75):
        g["Chrome"].append(cyl((-0.15, y, z), 0.09, 0.1, axis="x", verts=10))
# crossed bones behind the skull
for (ya, za), (yb, zb), x in (((-3.3, 3.7), (3.3, 9.3), 0.3), ((3.3, 3.7), (-3.3, 9.3), 0.38)):
    g["White"].append(cyl_ab((x, ya, za), (x, yb, zb), 0.3, 16))
    d = Vector((0, yb - ya, zb - za)).normalized()
    pp = Vector((0, -d.z, d.y))
    for (ye, ze), sg in (((ya, za), -1), ((yb, zb), 1)):
        for k in (-1, 1):
            g["White"].append(sphere(Vector((x, ye, ze)) + d * sg * 0.15 + pp * k * 0.3, 0.42, 14))
# skull: cranium with cut eye sockets + nose, cheek block, jaw, teeth; Accent eyes with Glow cores, angry brows
SX = 2.3
cr_ = xform(sphere((0, 0, 0), 2.6, 28), Matrix.Translation((SX, 0, 6.9)) @ Matrix.Diagonal((0.85, 1.0, 0.95, 1)))
nose = lambda z0=5.55, n0=1.2: prism(((0, 0, 0), Y_, Z_, X_), [(-0.4, z0), (0.4, z0), (0, 6.3)], SX + n0, SX + 2.9)
g["White"].append(boolean(cr_, [sphere((SX + 1.95, s * 1.0, 6.6), 0.85, 20) for s in (-1, 1)] + [nose()], "DIFFERENCE"))
mx_ = bx(SX - 0.8, SX + 1.95, -1.75, 1.75, 4.3, 5.7, bev=0.4, seg=3)
g["White"].append(boolean(mx_, [nose(5.42, 1.4)], "DIFFERENCE"))
g["Dark"].append(prism(((0, 0, 0), Y_, Z_, X_), [(-0.48, 5.47), (0.48, 5.47), (0, 6.4)], SX + 1.3, SX + 1.7))
g["White"].append(bx(SX - 0.9, SX + 1.75, -1.6, 1.6, 3.05, 3.95, bev=0.35, seg=3))  # jaw
for k in range(5):
    y = -1.2 + k * 0.6
    g["White"].append(bx(SX + 1.55, SX + 2.0, y - 0.24, y + 0.24, 4.08, 4.55, bev=0.07))
for k in range(4):
    y = -0.9 + k * 0.6
    g["White"].append(bx(SX + 1.45, SX + 1.9, y - 0.24, y + 0.24, 3.7, 4.03, bev=0.07))
for s in (-1, 1):
    g["Accent"].append(sphere((SX + 1.65, s * 1.0, 6.6), 0.6, 18))
    g["Glow"].append(sphere((SX + 2.15, s * 1.0, 6.6), 0.24, 12))
    g["White"].append(cyl_ab((SX + 1.95, s * 0.25, 7.2), (SX + 1.5, s * 1.95, 7.75), 0.28, 12))
roots.append(finish("A_Skull", g))


# ---------------------------------------------------------------- sanity: the Jumbotron Screen is one flat 8-vertex box
for r in roots:
    if r.name == "A_Jumbotron":
        scr = [c for c in r.children if c.name.startswith("Screen")]
        vs = [v.co for c in scr for v in c.data.vertices]
        print(f"Jumbotron Screen pieces {len(scr)}, verts {len(vs)}: Roblox centre ({(SCREEN[0] + SCREEN[1]) / 2:.2f}, {(SCREEN[4] + SCREEN[5]) / 2:.2f}, "
              f"{-(SCREEN[2] + SCREEN[3]) / 2:.2f}), front face X {SCREEN[1]:.2f}")

for r in roots:
    r.location = (0, 0, 0)
# --only A,B: export (and re-measure) just these models, leave the other FBX files untouched
ONLY = set(sys.argv[sys.argv.index("--only") + 1].split(",")) if "--only" in sys.argv else None
tris = {}
FLIP = Matrix.Rotation(math.pi, 4, "Z")  # Roblox's FBX import turns Blender +X into Roblox -X; pre-turn so +X stays +X
for r in roots:
    if ONLY and r.name not in ONLY:
        continue
    for c in r.children:
        c.data.transform(FLIP)
    mc.export([r], os.path.join(OUT, r.name + ".fbx"))
    for c in r.children:
        c.data.transform(FLIP)
        c.data.update()
    tris[r.name] = mc.triangles(r)
print("arena ok", tris)
bpy.context.view_layer.update()  # refresh bound_box after the un-flip (else the last exported model measures mirrored)
# real sizes (studs) so ModelService can undo any unit conversion of the FBX importer
sizes_path = os.path.join(mc.ROOT, "src", "ReplicatedStorage", "Shared", "ModelSizes.lua")
existing = open(sizes_path).read() if os.path.exists(sizes_path) else ""
entries = dict(re.findall(r"\n\t(\w+) = (\{ size = [^\n]*\}),", existing))  # keeps every other entry (city w / d too)
head = existing[: existing.index("return {")].rstrip("\n").split("\n") if "return {" in existing else [
    "-- generated by blender/make_spawn.py + make_city.py + make_garage.py + make_arena.py: longest side (studs), bounding-box centre",
    "-- relative to the model origin in Roblox axes (x, up, z), footprint w/d. ModelService puts the pivot back on the Blender origin."]
for r in roots:
    if ONLY and r.name not in ONLY:
        continue
    pts = [c.matrix_world @ Vector(v) for c in r.children for v in c.bound_box]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    ext = max(hi[i] - lo[i] for i in range(3))
    cx, cy, cz = [(lo[i] + hi[i]) / 2 for i in range(3)]
    entries[r.name] = f"{{ size = {ext:.2f}, c = {{ {cx:.2f}, {cz:.2f}, {-cy:.2f} }} }}"
    print(f"  {r.name}: Roblox X {lo[0]:.2f}..{hi[0]:.2f}  Y {lo[2]:.2f}..{hi[2]:.2f}  Z {-hi[1]:.2f}..{-lo[1]:.2f}")
lines = head + ["return {"] + [f"\t{k} = {entries[k]}," for k in sorted(entries)] + ["}"]
open(sizes_path, "w").write("\n".join(lines) + "\n")

if "--render" in sys.argv:
    out = sys.argv[sys.argv.index("--render-out") + 1] if "--render-out" in sys.argv else os.path.join(mc.ROOT, "docs", "renders", "arena.png")
    sc, cam, co = mc.setup_scene(1800, 1100)
    # 3/4 view from the front (+X) and Roblox +Z (Blender -Y); every model keeps its +X front towards the camera
    lay = {"A_Jumbotron": (-20, 22, 0, 0), "A_FloodLight": (-26, -10, 0, 0), "A_Bleachers": (8, 40, 0, 0), "A_CarPile": (2, 8, 0, 0),
           "A_Ramp": (22, -10, 0, 0), "A_Skull": (26, 16, 0, 0), "A_TireWall": (-2, -14, 0, 0), "A_FireBarrel": (8, -18, 0, 0)}
    for r in roots:
        x, y, z, rz = lay.get(r.name, (0, 0, 0, 0))
        r.location = (x, y, z)
        r.rotation_euler = (0, 0, math.radians(rz))
    cam.type = "ORTHO"
    cam.ortho_scale = 96
    tgt = Vector((0, 10, 12))
    co.location = tgt + Vector((60, -50, 42))
    co.rotation_euler = (tgt - co.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)
