"""Garage kit + glass lift cab (Blender). One FBX per model in assets/garage/, merges ModelSizes.lua.
  python3 blender/make_garage.py [--only G_A,G_B] [--render [--render-out path.png]]
Sizes are in studs (1 Blender unit = 1 stud). Meshes are named by look (ModelLooks.lua); the garage skin recolours
Frame (dark steel), Accent (hazard yellow) and Wall (light door slats) in Luau.

Axes: everything is modelled with Blender +X = Roblox +X (front), Blender +Z = Roblox up, Blender -Y = Roblox +Z.
The FBX import into Roblox maps Blender (x, y, z) to Roblox (-x, z, y) (checked on the uploaded MonsterTruck / FoodTruck
rbxm: their +X noses landed on Roblox -X), so the mesh data is turned 180 degrees about Z just for the export."""
import math, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import bmesh
from mathutils import Matrix, Vector
import make_cars as mc

OUT = os.path.join(mc.ROOT, "assets", "garage")
os.makedirs(OUT, exist_ok=True)
mc.reset()

# ---------------------------------------------------------------- looks (colours from ModelLooks.lua, sRGB -> linear)
LOOKS_LUA = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "src", "ReplicatedStorage", "Shared", "ModelLooks.lua")
LOOK = {}
for name, mat_, r, g_, b in re.findall(r"(\w+) = \{ M\.(\w+), C\((\d+), (\d+), (\d+)\)", open(LOOKS_LUA).read()):
    col = tuple((int(v) / 255) ** 2.2 for v in (r, g_, b)) + (1,)
    LOOK[name] = (col, 0.85 if mat_ == "Metal" else 0.0, 0.3 if mat_ == "Metal" else (0.05 if mat_ == "Glass" else 0.5))
LOOK.setdefault("Frame", (((58 / 255) ** 2.2, (62 / 255) ** 2.2, (70 / 255) ** 2.2, 1), 0.85, 0.35))
# the garage skin paints Accent hazard yellow (ModelLooks' default Accent is red); show that in the renders
LOOK["Accent"] = (((255 / 255) ** 2.2, (196 / 255) ** 2.2, (20 / 255) ** 2.2, 1), 0.0, 0.45)


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


# ---------------------------------------------------------------- hand tools (shared by the pegboard and the workbench)
def spanner(F, L, s=1.0, n0=0.0, n1=0.06):
    """combination spanner: ring end at v = L, open jaw at v = 0, lying in the (u, v) plane of F"""
    w, R1, R2 = 0.15 * s, 0.19 * s, 0.21 * s
    body = prism(F, [(-w / 2, 0), (w / 2, 0), (w / 2, L), (-w / 2, L)], n0, n1)
    e1 = prism(F, circle(0, L, R1), n0, n1)
    e2 = prism(F, circle(0, 0, R2), n0, n1)
    boolean(body, [e1, e2], "UNION")
    hole = prism(F, circle(0, L, R1 * 0.5, 12), n0 - 0.1, n1 + 0.1)
    jaw = prism(F, [(-R2 * 0.42, -R2 - 0.1), (R2 * 0.42, -R2 - 0.1), (R2 * 0.42, 0.02 * s), (-R2 * 0.42, 0.02 * s)], n0 - 0.1, n1 + 0.1)
    return boolean(body, [hole, jaw], "DIFFERENCE")


def spanner_outline(L, s, m=0.07):
    w, R1, R2 = 0.15 * s, 0.19 * s, 0.21 * s
    return [[(-w / 2 - m, 0), (w / 2 + m, 0), (w / 2 + m, L), (-w / 2 - m, L)], circle(0, L, R1 + m), circle(0, 0, R2 + m)]


def hammer(g, F, L, n0, n1, nh0, nh1):
    """Wood handle v 0..L, Dark claw head on top (v L..L+0.24)"""
    g["Wood"].append(prism(F, [(-0.065, 0), (0.065, 0), (0.065, L), (-0.065, L)], n0, n1, bev=0.025))
    g["Dark"].append(prism(F, [(-0.36, L + 0.03), (-0.24, L), (0.1, L), (0.34, L + 0.07), (0.34, L + 0.13), (0.1, L + 0.24), (-0.24, L + 0.24),
                               (-0.36, L + 0.21)], nh0, nh1, bev=0.03))


def hammer_outline(L, m=0.07):
    return [[(-0.065 - m, -m), (0.065 + m, -m), (0.065 + m, L), (-0.065 - m, L)], [(-0.36 - m, L - m), (0.34 + m, L - m), (0.34 + m, L + 0.24 + m), (-0.36 - m, L + 0.24 + m)]]


def screwdriver(g, look, F, L, nc, r=0.065):
    """handle v 0..0.55 (coloured look), Chrome shaft v 0.55..0.55+L, centred at depth nc"""
    O, U, V, N = (Vector(v) for v in F)
    base = O + N * nc
    g[look].append(cyl_ab(base, base + V * 0.48, r, 12, bev=0.02))
    g["Dark"].append(cyl_ab(base + V * 0.48, base + V * 0.56, r * 0.72, 12))  # ferrule
    g["Chrome"].append(cyl_ab(base + V * 0.56, base + V * (0.56 + L), 0.022, 8))
    g["Chrome"].append(prism(F, [(-0.045, 0.56 + L), (0.045, 0.56 + L), (0.02, 0.56 + L + 0.09), (-0.02, 0.56 + L + 0.09)], nc - 0.012, nc + 0.012))  # tip


def pliers(g, F, p, n0, n1, npv):
    """Metal nose v p-0.08..p+0.58, two Red grips below, Chrome pivot at v = p"""
    g["Metal"].append(prism(F, [(-0.1, p - 0.08), (0.1, p - 0.08), (0.11, p + 0.08), (0.035, p + 0.58), (-0.035, p + 0.58), (-0.11, p + 0.08)], n0, n1, bev=0.015))
    for s in (-1, 1):
        g["Red"].append(prism(F, [(s * 0.012, p - 0.08), (s * 0.1, p - 0.08), (s * 0.27, p - 0.93), (s * 0.15, p - 0.95)], n0, n1, bev=0.02))
    g["Chrome"].append(prism(F, circle(0, p, 0.065, 12), n0 - 0.01, npv - 0.005, bev=0.01))


def pliers_outline(p, m=0.07):
    return [[(-0.15 - m, p - 0.95 - m), (0.29 + m, p - 0.95 - m), (0.11 + m, p + 0.08), (0.035 + m, p + 0.58 + m), (-0.035 - m, p + 0.58 + m), (-0.11 - m, p + 0.08),
             (-0.29 - m, p - 0.95 - m)]]


# ---------------------------------------------------------------- G_RollerDoor: raised roller door for one bay (14.6 x 13.4 x 1.6)
# width along Roblox Z (Blender Y), front +X; the opening |y| < 6.5, z < 11.6 stays empty
g = G("Frame", "Wall", "Accent", "Dark", "Metal", "Chrome", "Rubber")
for s in (-1, 1):
    # U-channel guide rail (web outside at |y| 6.95..7.15, flanges inward), sitting on a foot plate
    prof = [(-0.42, 6.5), (-0.3, 6.5), (-0.3, 6.95), (0.3, 6.95), (0.3, 6.5), (0.42, 6.5), (0.42, 7.15), (-0.42, 7.15)]
    F = ((0, 0, 0), (1, 0, 0), (0, s, 0), (0, 0, 1))
    g["Frame"].append(prism(F, prof, 0.12, 11.8, bev=0.03, tri=True))
    g["Dark"].append(bx(-0.55, 0.55, s * 6.5, s * 7.26, 0, 0.12, bev=0.03))
    for z in (1.6, 5.6, 9.6):  # wall brackets
        g["Metal"].append(bx(-0.3, 0.3, s * 7.15, s * 7.27, z, z + 0.45, bev=0.02))
        for dx in (-0.16, 0.16):
            g["Chrome"].append(cyl((dx, s * 7.25, z + 0.225), 0.05, 0.08, axis="y", verts=6))
    # hood end caps
    g["Frame"].append(bx(-0.8, 0.8, s * 7.1, s * 7.3, 11.8, 13.4, bev=0.05))
# hood: back plate, top (front drip lip), front fascia with a rolled bottom edge
g["Frame"].append(bx(-0.8, -0.68, -7.1, 7.1, 11.8, 13.25))
g["Frame"].append(bx(-0.8, 0.8, -7.1, 7.1, 13.25, 13.4, bev=0.03))
g["Frame"].append(bx(0.6, 0.7, -7.1, 7.1, 12.55, 13.25))
g["Frame"].append(cyl((0.66, 0, 12.55), 0.07, 14.2, axis="y", verts=12))
hazard(g, ((0, 0, 0), (0, 1, 0), (0, 0, 1), (1, 0, 0)), -6.95, 6.95, 12.72, 13.12, 0.68, 0.765, w=0.5)
# rolled-up door drum (slats) on an axle
g["Wall"].append(cyl((-0.1, 0, 12.62), 0.55, 14.2, axis="y", verts=40))
for s in (-1, 1):
    g["Metal"].append(cyl((-0.1, s * 7.0, 12.62), 0.16, 0.2, axis="y", verts=12))  # axle bosses through the end caps
# door lip below the drum: two slats, aluminium bottom bar with rubber seal, D-handle
g["Wall"].append(bx(-0.12, 0.12, -6.85, 6.85, 11.8, 12.2, bev=0.06))
g["Wall"].append(bx(-0.12, 0.12, -6.85, 6.85, 12.24, 12.64, bev=0.06))
g["Metal"].append(bx(-0.16, 0.16, -6.85, 6.85, 11.7, 11.8, bev=0.02))
g["Rubber"].append(bx(-0.08, 0.08, -6.85, 6.85, 11.62, 11.7))
for y in (-0.35, 0.35):
    g["Chrome"].append(cyl_ab((0.1, y, 12.0), (0.3, y, 12.0), 0.04, 8))
    g["Chrome"].append(sphere((0.3, y, 12.0), 0.055, 10))
g["Chrome"].append(cyl_ab((0.3, -0.35, 12.0), (0.3, 0.35, 12.0), 0.045, 10))
roots.append(finish("G_RollerDoor", g))

# ---------------------------------------------------------------- G_Workbench: 8 long (Y), 3 deep (X -1.5..1.5), top at 3.4
g = G("Wood", "Dark", "Metal", "Chrome", "Rubber", "Blue", "Red")
for x0 in (-1.5, -0.5, 0.5):  # butcher-block top: three planks
    g["Wood"].append(bx(x0, x0 + 1.0, -4, 4, 3.0, 3.4, bev=0.05))
for sx in (-1, 1):
    for sy in (-1, 1):
        g["Dark"].append(bx(sx * 1.175, sx * 1.425, sy * 3.625, sy * 3.875, 0.12, 3.0, bev=0.03))
        g["Rubber"].append(cyl((sx * 1.3, sy * 3.75, 0.06), 0.16, 0.12, verts=12))
    for z0, z1 in ((2.7, 3.0), (0.4, 0.62)):  # apron + lower stretcher, front/back and sides
        g["Dark"].append(bx(sx * 1.175, sx * 1.425, -3.625, 3.625, z0, z1))
        g["Dark"].append(bx(-1.175, 1.175, sx * 3.625, sx * 3.875, z0, z1))
g["Metal"].append(bx(-1.175, 1.175, -3.625, 3.625, 0.5, 0.58))  # lower shelf
# drawer unit under the top at the +Y end
g["Metal"].append(bx(-1.15, 1.2, 0.95, 3.55, 0.58, 2.7, bev=0.03))
for z0, z1 in ((0.68, 1.3), (1.36, 1.98), (2.04, 2.62)):
    g["Red"].append(bx(1.18, 1.3, 1.05, 3.45, z0, z1, bev=0.03))
    g["Chrome"].append(bx(1.28, 1.38, 1.9, 2.6, z1 - 0.2, z1 - 0.12, bev=0.02))
# bench vice at the -Y end (Blue body, Dark jaw plates, Chrome screw + T-bar)
g["Blue"].append(bx(0.2, 1.1, -3.6, -2.8, 3.4, 3.55, bev=0.03))
g["Dark"].append(cyl((0.65, -3.2, 3.59), 0.42, 0.08, verts=24))
g["Blue"].append(bx(0.25, 0.6, -3.55, -2.85, 3.63, 4.25, bev=0.04))
g["Blue"].append(bx(0.85, 1.15, -3.55, -2.85, 3.63, 4.25, bev=0.04))
g["Metal"].append(bx(0.6, 0.85, -3.3, -3.1, 3.7, 3.9))
g["Dark"].append(bx(0.58, 0.665, -3.5, -2.9, 3.95, 4.18))
g["Dark"].append(bx(0.785, 0.87, -3.5, -2.9, 3.95, 4.18))
g["Chrome"].append(cyl_ab((1.15, -3.2, 3.85), (1.42, -3.2, 3.85), 0.06, 12))
g["Chrome"].append(cyl_ab((1.42, -3.55, 3.85), (1.42, -2.85, 3.85), 0.04, 8))
for y in (-3.58, -2.82):
    g["Chrome"].append(sphere((1.42, y, 3.85), 0.06, 10))
# tools lying on the top: hammer, spanner, screwdriver
hammer(g, ((-0.4, -1.9, 3.4), Y_, (1, 0, 0), Z_), 1.0, 0.0, 0.1, 0.0, 0.2)
g["Chrome"].append(spanner(((0.5, -0.4, 3.4), X_, Y_, Z_), 1.3, 1.0, 0.0, 0.06))
screwdriver(g, "Red", ((-0.5, 1.4, 3.4), (1, 0, 0), (0, -1, 0), Z_), 0.6, 0.065)
roots.append(finish("G_Workbench", g))

# ---------------------------------------------------------------- G_Pegboard: 8 (Y) x 4.4 (Z) x 0.3 (X), origin = back face centre at the bottom
g = G("Wood", "Metal", "Dark", "White", "Chrome", "Red", "Yellow", "Blue", "Green")
B = 0.15  # trim width
g["Metal"].append(bx(0, 0.18, -4, -4 + B, 0, 4.4, bev=0.03))
g["Metal"].append(bx(0, 0.18, 4 - B, 4, 0, 4.4, bev=0.03))
g["Metal"].append(bx(0, 0.18, -4 + B, 4 - B, 0, B, bev=0.03))
g["Metal"].append(bx(0, 0.18, -4 + B, 4 - B, 4.4 - B, 4.4, bev=0.03))
g["Wood"].append(bx(0, 0.1, -4 + B, 4 - B, B, 4.4 - B))
FP = lambda y, z, down=False: ((0, y, z), (0, 1, 0), (0, 0, -1 if down else 1), (1, 0, 0))
shapes = []  # (frame, outline polygons)
pegs = []
# hammer, head up, left
shapes.append((FP(-3.2, 1.2), hammer_outline(1.8)))
hammer(g, FP(-3.2, 1.2), 1.8, 0.19, 0.27, 0.17, 0.3)
pegs += [(-3.2 - 0.17, 3.0 - 0.05), (-3.2 + 0.17, 3.0 - 0.05)]
# spanners, ring end up
for k, (L, s) in enumerate(((1.1, 0.8), (1.4, 0.9), (1.7, 1.0), (2.0, 1.1))):
    y = -2.0 + k * 0.55
    z0 = 1.0
    shapes.append((FP(y, z0), spanner_outline(L, s)))
    g["Chrome"].append(spanner(FP(y, z0), L, s, 0.19, 0.25))
    pegs.append((y, z0 + L))
# screwdrivers, handle up, shaft down
for k, (look, L) in enumerate((("Red", 0.9), ("Yellow", 1.1), ("Blue", 1.3), ("Green", 1.0))):
    y = 0.55 + k * 0.42
    top = 3.6
    shapes.append((FP(y, top, True), [[(-0.13, -0.07), (0.13, -0.07), (0.13, 0.56 + L + 0.15), (-0.13, 0.56 + L + 0.15)]]))
    screwdriver(g, look, FP(y, top, True), L, 0.235)
    pegs += [(y - 0.13, top - 0.6), (y + 0.13, top - 0.6)]
# pliers, nose up, right
for k, y in enumerate((2.75, 3.35)):
    pz = 2.4 + k * 0.25
    shapes.append((FP(y, 0), pliers_outline(pz)))
    pliers(g, FP(y, 0), pz, 0.18, 0.235, 0.3)
    pegs.append((y, pz - 0.98))
for F, polys in shapes:
    parts = [prism(F, p, 0.08, 0.165) for p in polys]
    g["White"].append(boolean(parts[0], parts[1:], "UNION") if len(parts) > 1 else parts[0])
for y, z in pegs:
    g["Chrome"].append(cyl_ab((0.05, y, z), (0.26, y, z), 0.03, 8))
    g["Chrome"].append(sphere((0.26, y, z), 0.035, 8))


def in_outline(y, z):
    for F, polys in shapes:
        O, U, V = Vector(F[0]), Vector(F[1]), Vector(F[2])
        for p in polys:
            pts = [O + U * u + V * v for u, v in p]
            if min(q.y for q in pts) - 0.12 < y < max(q.y for q in pts) + 0.12 and min(q.z for q in pts) - 0.12 < z < max(q.z for q in pts) + 0.12:
                return True
    return False


for i in range(19):
    for j in range(10):
        y, z = -3.6 + i * 0.4, 0.4 + j * 0.4
        if not in_outline(y, z) and not any(abs(y - py) < 0.1 and abs(z - pz) < 0.1 for py, pz in pegs):
            g["Dark"].append(cyl((0.12, y, z), 0.045, 0.08, axis="x", verts=8))
roots.append(finish("G_Pegboard", g))

# ---------------------------------------------------------------- G_ToolCabinet: red rolling chest, 3 (Y) x 2 (X) x 4.2, front +X
g = G("Red", "Chrome", "Dark", "Rubber", "Metal")
g["Red"].append(bx(-1.0, 0.85, -1.42, 1.42, 0.5, 3.85, bev=0.08))
g["Red"].append(bx(-1.0, 0.92, -1.45, 1.45, 3.85, 4.1, bev=0.06))  # lid
g["Dark"].append(bx(-0.9, 0.82, -1.35, 1.35, 4.04, 4.2, bev=0.03))  # rubber top mat
g["Chrome"].append(cyl_ab((0.95, -0.8, 3.97), (0.95, 0.8, 3.97), 0.035, 10))
for y in (-0.7, 0.7):
    g["Chrome"].append(cyl_ab((0.9, y, 3.97), (0.95, y, 3.97), 0.025, 8))
z = 0.6
for h in (0.66, 0.58, 0.46, 0.42, 0.36, 0.36):
    g["Red"].append(bx(0.83, 0.93, -1.32, 1.32, z, z + h, bev=0.03))
    zh = z + h - 0.12
    g["Chrome"].append(cyl_ab((0.965, -1.0, zh), (0.965, 1.0, zh), 0.035, 10))
    for y in (-0.9, 0.9):
        g["Chrome"].append(cyl_ab((0.92, y, zh), (0.965, y, zh), 0.025, 8))
    g["Dark"].append(bx(0.92, 0.99, -0.22, 0.22, z + 0.08, z + 0.2))  # label holder
    z += h + 0.06
for s in (-1, 1):  # side grab handles
    g["Chrome"].append(cyl_ab((-0.55, s * 1.465, 3.3), (0.35, s * 1.465, 3.3), 0.035, 10))
    for x in (-0.45, 0.25):
        g["Chrome"].append(cyl_ab((x, s * 1.4, 3.3), (x, s * 1.465, 3.3), 0.025, 8))
for x in (-0.75, 0.6):  # castors
    for y in (-1.1, 1.1):
        g["Rubber"].append(cyl((x, y, 0.19), 0.19, 0.14, axis="y", verts=20, bev=0.03))
        g["Chrome"].append(cyl((x, y, 0.19), 0.05, 0.4, axis="y", verts=8))
        for dy in (-1, 1):
            g["Metal"].append(bx(x - 0.12, x + 0.12, y + dy * 0.1, y + dy * 0.13, 0.12, 0.36))
        g["Metal"].append(bx(x - 0.12, x + 0.12, y - 0.13, y + 0.13, 0.36, 0.46))
        g["Dark"].append(cyl((x, y, 0.5), 0.1, 0.14, verts=12))  # swivel z 0.43..0.57
roots.append(finish("G_ToolCabinet", g))

# ---------------------------------------------------------------- G_TireRack: 6.4 (Y) x 2.6 (X) x 5.4, 2 shelves, 6 upright tyres
g = G("Blue", "Orange", "Metal", "Dark", "Rubber", "Chrome")
for sx in (-1, 1):
    for sy in (-1, 1):
        g["Blue"].append(bx(sx * 1.1, sx * 1.3, sy * 3.0, sy * 3.2, 0.08, 5.4, bev=0.03))
        g["Dark"].append(bx(sx * 1.04, sx * 1.3, sy * 2.94, sy * 3.2, 0, 0.08))
for sy in (-1, 1):  # end frames: cross bars + diagonals
    for z in (0.3, 5.15):
        g["Blue"].append(bx(-1.1, 1.1, sy * 3.05, sy * 3.15, z, z + 0.12))
    for za, zb in ((0.42, 2.8), (2.8, 5.15)):
        g["Metal"].append(cyl_ab((-1.1, sy * 3.1, za), (1.1, sy * 3.1, zb), 0.045, 8))
for zb in (0.5, 2.9):  # shelf: front/back beams, end cross members, two tyre bars
    for sx in (-1, 1):
        g["Orange"].append(bx(sx * 1.12, sx * 1.28, -3.0, 3.0, zb, zb + 0.3, bev=0.03))
    for sy in (-1, 1):
        g["Orange"].append(bx(-1.12, 1.12, sy * 2.9, sy * 3.0, zb + 0.1, zb + 0.3))
    for x in (-0.2, 0.2):
        g["Metal"].append(cyl((x, 0, zb + 0.23), 0.07, 5.8, axis="y", verts=12))
g["Orange"].append(bx(-1.12, 1.12, -3.0, 3.0, 5.25, 5.4, bev=0.03))  # top deck plate
# tyres: lathe profile with rounded shoulders + 2 tread grooves, axis X
TR, TI, TW = 0.95, 0.55, 0.38
tyre = [(TI, -TW + 0.06), (TI + 0.06, -TW), (TR - 0.12, -TW), (TR - 0.02, -TW + 0.08), (TR, -TW + 0.16), (TR, -0.14), (TR - 0.05, -0.12),
        (TR - 0.05, -0.06), (TR, -0.04), (TR, 0.04), (TR - 0.05, 0.06), (TR - 0.05, 0.12), (TR, 0.14), (TR, TW - 0.16), (TR - 0.02, TW - 0.08),
        (TR - 0.12, TW), (TI + 0.06, TW), (TI, TW - 0.06)]
rim = [(0, -0.2), (0.58, -0.26), (0.58, 0.26), (0.48, 0.26), (0.42, 0.14), (0.2, 0.14), (0.15, 0.2), (0, 0.2)]
for zb, rims in ((0.5, True), (2.9, False)):
    zc = zb + 0.3 + TR
    for y in (-2.05, 0, 2.05):
        g["Rubber"].append(lathe(tyre, "x", (0, y, zc), 48, closed=True))
        if rims:
            g["Chrome"].append(lathe(rim, "x", (0, y, zc), 32))
            g["Dark"].append(cyl((0.21, y, zc), 0.13, 0.06, axis="x", verts=16))
roots.append(finish("G_TireRack", g))

# ---------------------------------------------------------------- G_WallLamp: caged industrial lamp, origin = back plate centre, sticks out +X
g = G("Dark", "Green", "Metal", "Glow", "Chrome")
g["Dark"].append(cyl((0.05, 0, 0), 0.42, 0.1, axis="x", verts=32, bev=0.03))
for z in (-0.28, 0.28):
    g["Chrome"].append(cyl((0.11, 0, z), 0.05, 0.04, axis="x", verts=8))
g["Dark"].append(cyl((0.26, 0, 0), 0.3, 0.32, axis="x", verts=32, bev=0.04))  # socket housing x 0.1..0.42
g["Green"].append(lathe([(0.3, 0.32), (0.7, 0.74), (0.7, 0.8), (0.64, 0.8), (0.26, 0.38), (0.26, 0.32)], "x", (0, 0, 0), 48, closed=True))
g["Metal"].append(cyl((0.48, 0, 0), 0.12, 0.14, axis="x", verts=16))
g["Glow"].append(lathe([(0, 0.54), (0.1, 0.55), (0.12, 0.6), (0.22, 0.66), (0.26, 0.74), (0.25, 0.82), (0.19, 0.9), (0.1, 0.94), (0, 0.95)], "x"))
g["Metal"].append(torus((0.8, 0, 0), 0.67, 0.035, axis="x", seg=48, minor=6))
for xr, rr in ((0.93, 0.6), (1.06, 0.44)):
    g["Metal"].append(torus((xr, 0, 0), rr, 0.025, axis="x", seg=40, minor=6))
for k in range(6):
    a = k / 6 * 2 * math.pi
    ca, sa = math.cos(a), math.sin(a)
    path = [(0.8, 0.67, ), (0.93, 0.6), (1.06, 0.44), (1.14, 0.25), (1.16, 0.13)]
    g["Metal"].append(sweep([(x, ca * r, sa * r) for x, r in path], 0.025, 6))
g["Metal"].append(cyl((1.17, 0, 0), 0.15, 0.06, axis="x", verts=16))
roots.append(finish("G_WallLamp", g))

# ---------------------------------------------------------------- G_OilDrum: d 2, h 3, rolling hoops, recessed lid with two bungs
g = G("Blue", "Metal")
prof = [(0, 0), (0.97, 0), (1.0, 0.03), (1.0, 0.11), (0.96, 0.16)]
for zr in (1.0, 2.0):
    prof += [(0.96, zr - 0.09), (0.99, zr - 0.04), (1.0, zr), (0.99, zr + 0.04), (0.96, zr + 0.09)]
prof += [(0.96, 2.84), (1.0, 2.89), (1.0, 2.97), (0.97, 3.0), (0.93, 3.0), (0.92, 2.92), (0, 2.92)]
g["Blue"].append(lathe(prof, "z", (0, 0, 0), 56))
g["Metal"].append(lathe([(0, 2.86), (0.2, 2.86), (0.2, 2.95), (0.16, 2.99), (0, 2.99)], "z", (0.5, 0.15, 0), 20))
g["Metal"].append(lathe([(0, 2.86), (0.11, 2.86), (0.11, 2.94), (0.09, 2.97), (0, 2.97)], "z", (-0.55, -0.2, 0), 16))
roots.append(finish("G_OilDrum", g))

# ---------------------------------------------------------------- G_LiftCab: one storey of a glass lift, 9 x 9 x 14, doorway on -X
# inside (|x| <= 3.6, |y| <= 3.6, z 0..12.5) stays empty; no floor plate
g = G("Frame", "Glass", "Metal", "Chrome", "Glow", "Dark", "Rubber", "Accent")
PX0, PX1, PY = (-4.37, -3.77), (3.8, 4.4), (3.8, 4.4)
for (x0, x1) in (PX0, PX1):
    for s in (-1, 1):
        g["Frame"].append(bx(x0, x1, s * PY[0], s * PY[1], 0, 12.6, bev=0.12, seg=3))
hdr = bx(-4.5, 4.5, -4.5, 4.5, 12.6, 14.0, bev=0.1, seg=2)
boolean(hdr, [bx(-2.2, 2.2, -2.2, 2.2, 12.5, 12.85), bx(-4.6, -4.38, -0.9, 0.9, 13.0, 13.6)], "DIFFERENCE")
g["Frame"].append(hdr)
g["Glow"].append(bx(-2.0, 2.0, -2.0, 2.0, 12.7, 12.87))  # recessed ceiling light
g["Glow"].append(bx(-4.46, -4.3, -0.75, 0.75, 13.08, 13.52))  # floor indicator in its recess
# doorway wall (-X): transom, jamb stiles, fixed glass beside the opening, parked door leaves in their track
g["Frame"].append(bx(PX0[0], PX0[1], -3.8, 3.8, 10.5, 12.6, bev=0.04))
for s in (-1, 1):
    g["Frame"].append(bx(PX0[0], PX0[1], s * 3.0, s * 3.2, 0, 10.5, bev=0.04))
    g["Glass"].append(bx(-4.13, -4.07, s * 3.17, s * 3.83, 0, 10.5))
    g["Metal"].append(bx(-3.75, -3.61, s * 3.06, s * 4.34, 0.08, 10.5, bev=0.03))  # leaf
    g["Rubber"].append(bx(-3.73, -3.63, s * 3.0, s * 3.06, 0.08, 10.5))  # leading-edge seal
g["Metal"].append(bx(-3.76, -3.61, -4.36, 4.36, 10.5, 10.72))  # top track
g["Metal"].append(bx(-3.77, -3.61, -4.36, 4.36, 0, 0.08))  # sill track
# call-button plate on the right post (Roblox +Z = Blender -Y), -X face, height 4
g["Chrome"].append(bx(-4.438, -4.35, -4.3, -3.9, 3.5, 4.5, bev=0.02))
for z in (3.8, 4.2):
    g["Glow"].append(cyl((-4.46, -4.1, z), 0.09, 0.08, axis="x", verts=16))
# side walls (|y| ~ 4.1): kick panel, glass, mullions, transom bar
for s in (-1, 1):
    g["Metal"].append(bx(-3.58, 3.8, s * 3.96, s * 4.24, 0, 0.5, bev=0.03))
    g["Glass"].append(bx(-3.52, 3.82, s * 4.07, s * 4.13, 0.5, 12.6))
    for x0, x1 in ((-3.58, -3.44), (-1.26, -1.14), (1.14, 1.26)):
        g["Metal"].append(bx(x0, x1, s * 3.99, s * 4.21, 0.5, 12.6))
    g["Metal"].append(bx(-3.5, 3.8, s * 3.91, s * 4.29, 10.44, 10.56))
# back wall (+X)
g["Metal"].append(bx(3.64, 3.92, -3.8, 3.8, 0, 0.5, bev=0.03))
g["Glass"].append(bx(3.75, 3.81, -3.82, 3.82, 0.5, 12.6))
for y in (-1.3, 1.3):
    g["Metal"].append(bx(3.67, 3.89, y - 0.06, y + 0.06, 0.5, 12.6))
g["Metal"].append(bx(3.605, 3.95, -3.8, 3.8, 10.44, 10.56))
# handrail on the three glass sides at height 3.2, returning to the side glass at the doorway end
rail = fillet([(-3.3, -4.07), (-3.3, -3.7), (3.68, -3.7), (3.68, 3.7), (-3.3, 3.7), (-3.3, 4.07)], 0.12, 5)
g["Chrome"].append(sweep([(p.x, p.y, 3.2) for p in rail], 0.05, 10))
for s in (-1, 1):
    for x in (-2.3, 0.0, 2.3):
        g["Chrome"].append(cyl_ab((x, s * 3.7, 3.2), (x, s * 4.07, 3.2), 0.03, 8))
g["Chrome"].append(cyl_ab((3.68, 0, 3.2), (3.75, 0, 3.2), 0.03, 8))
# guide rails + counterweight outside the +X glass
for s in (-1, 1):
    g["Metal"].append(bx(4.0, 4.4, s * 1.1, s * 1.18, 0, 12.6))
    g["Metal"].append(bx(4.16, 4.24, s * 0.98, s * 1.1, 0, 12.6))
    g["Dark"].append(bx(4.04, 4.36, s * 0.8, s * 0.95, 5.0, 9.0, bev=0.02))
    g["Dark"].append(cyl((4.2, s * 0.3, 10.8), 0.04, 3.6, verts=8))  # ropes up into the header
for z0, z1 in ((5.0, 5.3), (8.7, 9.0)):
    g["Dark"].append(bx(4.04, 4.36, -0.8, 0.8, z0, z1, bev=0.02))
for k in range(6):
    z0 = 5.3 + k * (3.4 / 6)
    g["Metal"].append(bx(4.08, 4.32, -0.8, 0.8, z0, z0 + 3.4 / 6, bev=0.04))
hazard(g, ((0, 0, 0), (0, 1, 0), (0, 0, 1), (1, 0, 0)), -0.95, 0.95, 5.0, 5.3, 4.34, 4.44, w=0.3)
roots.append(finish("G_LiftCab", g))


# ---------------------------------------------------------------- sanity: keep-out volumes stay empty
def verts_in(root, lo, hi):
    n = 0
    for c in root.children:
        for v in c.data.vertices:
            p = c.matrix_world @ v.co
            if all(lo[i] < p[i] < hi[i] for i in range(3)):
                n += 1
                print("   inside:", c.name, tuple(round(q, 3) for q in p))
    return n


for r in roots:
    if r.name == "G_LiftCab":
        print("LiftCab verts inside the cab volume:", verts_in(r, (-3.6, -3.6, 0.001), (3.6, 3.6, 12.5)))
    if r.name == "G_RollerDoor":
        print("RollerDoor verts in the opening:", verts_in(r, (-0.9, -6.5, -1), (0.9, 6.5, 11.6)))

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
print("garage ok", tris)
# real sizes (studs) so ModelService can undo any unit conversion of the FBX importer
sizes_path = os.path.join(mc.ROOT, "src", "ReplicatedStorage", "Shared", "ModelSizes.lua")
existing = open(sizes_path).read() if os.path.exists(sizes_path) else ""
entries = dict(re.findall(r"\n\t(\w+) = (\{ size = [^\n]*\}),", existing))  # keeps every other entry (city w / d too)
head = existing[: existing.index("return {")].rstrip("\n").split("\n") if "return {" in existing else [
    "-- generated by blender/make_spawn.py + make_city.py + make_garage.py: longest side (studs), bounding-box centre relative to the",
    "-- model origin in Roblox axes (x, up, z), footprint w/d. ModelService puts the pivot back on the Blender origin."]
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
    out = sys.argv[sys.argv.index("--render-out") + 1] if "--render-out" in sys.argv else os.path.join(mc.ROOT, "docs", "renders", "garage.png")
    sc, cam, co = mc.setup_scene(1800, 1100)
    # 3/4 view from the front (+X) and Roblox +Z (Blender -Y); the lift cab is turned so its doorway (-X) faces the camera
    lay = {"G_RollerDoor": (-6, 9, 0, 0), "G_LiftCab": (6, -7, 0, 180), "G_TireRack": (-12, -10, 0, 0), "G_Workbench": (12, 18, 0, 0),
           "G_Pegboard": (6, 14, 0, 0), "G_ToolCabinet": (9, 6, 0, 0), "G_WallLamp": (10, 2, 2.5, 0), "G_OilDrum": (11, -1.5, 0, 0)}
    for r in roots:
        x, y, z, rz = lay.get(r.name, (0, 0, 0, 0))
        r.location = (x, y, z)
        r.rotation_euler = (0, 0, math.radians(rz))
    cam.type = "ORTHO"
    cam.ortho_scale = 46
    tgt = Vector((0, 4, 4))
    co.location = tgt + Vector((60, -50, 42))
    co.rotation_euler = (tgt - co.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)
