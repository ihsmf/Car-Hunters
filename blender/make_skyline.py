"""Skyline kit (Blender): 10 background buildings seen from 50-300 studs behind the map's perimeter wall.
  python3 blender/make_skyline.py [--only Skyline_Office,...] [--render [--render-out path.png]]
One FBX per model in assets/skyline/, sizes merged into Shared/ModelSizes.lua (other entries kept).
1 Blender unit = 1 stud, origin at the ground centre. Front facade = Blender +X, which the FBX import turns into
Roblox -X (Blender (x, y, z) -> Roblox (-x, z, y)), so no export flip is needed. Every face has facade detail
(the map yaws them randomly). Meshes are named by look (ModelLooks.lua), one mesh per look (split above 18k tris).
Geometry is written straight into mesh data (no bpy.ops per box) so the window grids stay fast; overlays are kept
>= 0.08 studs off any differently coloured face to avoid z-fighting."""
import math, os, random, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import bmesh
from mathutils import Matrix, Vector
import make_cars as mc

OUT = os.path.join(mc.ROOT, "assets", "skyline")
os.makedirs(OUT, exist_ok=True)
ONLY = set(sys.argv[sys.argv.index("--only") + 1].split(",")) if "--only" in sys.argv else None
mc.reset()

# ---------------------------------------------------------------- looks (ModelLooks.lua colours, sRGB -> linear)
LOOKS_LUA = os.path.join(mc.ROOT, "src", "ReplicatedStorage", "Shared", "ModelLooks.lua")
LOOK = {}
for name, mat_, r, g_, b in re.findall(r"(\w+) = \{ M\.(\w+), C\((\d+), (\d+), (\d+)\)", open(LOOKS_LUA).read()):
    col = tuple((int(v) / 255) ** 2.2 for v in (r, g_, b)) + (1,)
    LOOK[name] = (col, 0.85 if mat_ == "Metal" else 0.0, 0.3 if mat_ == "Metal" else (0.08 if mat_ == "Glass" else 0.55))


def M(look):
    c, metal, rough = LOOK[look]
    return mc.mat(look, c, metal=metal, rough=rough, emit=c if look == "Glow" else None)


# ---------------------------------------------------------------- raw geometry (per look vertex/face lists)
GEO = {}  # look -> [verts, faces, smooth flags]


def add(look, verts, faces):
    V, F = GEO.setdefault(look, ([], []))
    b = len(V)
    V.extend(Vector(v) for v in verts)
    F.extend(tuple(i + b for i in f) for f in faces)


BOX_F = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
SIGN = [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]


def box(look, c, s, rot=None):
    """box centred on c with size s; rot = 3x3 rotation matrix (or a z angle in radians)"""
    if isinstance(rot, (int, float)):
        rot = Matrix.Rotation(rot, 3, "Z") if rot else None
    c = Vector(c)
    pts = []
    for sx, sy, sz in SIGN:
        p = Vector((sx * s[0] / 2, sy * s[1] / 2, sz * s[2] / 2))
        pts.append(c + (rot @ p if rot else p))
    add(look, pts, BOX_F)


def bx(look, x0, x1, y0, y1, z0, z1):
    box(look, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)))


def frame(d, side=None):
    """3x3 matrix whose z axis is d (and x axis follows `side` when given)"""
    z = d.normalized()
    if side is None:
        return Vector((0, 0, 1)).rotation_difference(z).to_matrix()
    x = Vector(side)
    x = (x - z * x.dot(z)).normalized()
    y = z.cross(x)
    return Matrix((x, y, z)).transposed()


def strut(look, p1, p2, t, t2=None, side=None):
    """beam from p1 to p2, cross-section t (along `side`) x t2"""
    p1, p2 = Vector(p1), Vector(p2)
    box(look, (p1 + p2) / 2, (t, t2 or t, (p2 - p1).length), frame(p2 - p1, side))


def cyl(look, p1, p2, r1, r2=None, n=16):
    """cylinder / cone / frustum from p1 to p2"""
    r2 = r1 if r2 is None else r2
    p1, p2 = Vector(p1), Vector(p2)
    q = frame(p2 - p1)
    ang = [2 * math.pi * i / n for i in range(n)]
    bot = [p1 + q @ Vector((r1 * math.cos(a), r1 * math.sin(a), 0)) for a in ang]
    if r2 < 1e-3:
        faces = [tuple(reversed(range(n)))] + [(i, (i + 1) % n, n) for i in range(n)]
        add(look, bot + [p2], faces)
        return
    top = [p2 + q @ Vector((r2 * math.cos(a), r2 * math.sin(a), 0)) for a in ang]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    add(look, bot + top, faces)


def zc(look, x, y, z0, z1, r1, r2=None, n=16):
    cyl(look, (x, y, z0), (x, y, z1), r1, r2, n)


def extrude(look, pts, origin, u, v, depth):
    """convex polygon pts (in the u, v plane at origin) extruded along u x v by depth"""
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1]))
    if area < 0:
        pts = list(reversed(pts))
    u, v, o = Vector(u), Vector(v), Vector(origin)
    nrm = u.cross(v).normalized() * depth
    k = len(pts)
    bot = [o + a * u + b * v for a, b in pts]
    top = [p + nrm for p in bot]
    faces = [tuple(reversed(range(k))), tuple(range(k, 2 * k))] + [(i, (i + 1) % k, k + (i + 1) % k, k + i) for i in range(k)]
    add(look, bot + top, faces)


def rrect(w, d, r, seg=6):
    """rounded rectangle outline (CCW), w along x, d along y"""
    pts = []
    for cx, cy, a0 in ((w / 2 - r, d / 2 - r, 0), (-w / 2 + r, d / 2 - r, 90), (-w / 2 + r, -d / 2 + r, 180), (w / 2 - r, -d / 2 + r, 270)):
        for i in range(seg + 1):
            a = math.radians(a0 + 90 * i / seg)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def rprism(look, w, d, r, z0, z1, cx=0.0, cy=0.0, seg=6):
    extrude(look, rrect(w, d, r, seg), (cx, cy, z0), (1, 0, 0), (0, 1, 0), z1 - z0)


def text(look, body, size, loc, yaw, depth=0.5, sy=1.0, offset=0.0):
    """font curve -> mesh; letters stand upright, front facing Rz(yaw) * (0, -1, 0) (yaw 90 deg = +X)"""
    cu = bpy.data.curves.new("txt", "FONT")
    cu.body = body
    cu.size = size
    cu.extrude = depth / 2
    cu.align_x, cu.align_y = "CENTER", "CENTER"
    cu.resolution_u = 3
    cu.offset = offset
    ob = bpy.data.objects.new("txt", cu)
    bpy.context.collection.objects.link(ob)
    ev = ob.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = ev.to_mesh()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="BEAUTY")
    mt = Matrix.Translation(loc) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "X") @ Matrix.Diagonal((1, sy, 1, 1))
    add(look, [mt @ v.co for v in bm.verts], [tuple(v.index for v in f.verts) for f in bm.faces])
    bm.free()
    ev.to_mesh_clear()
    bpy.data.objects.remove(ob)
    bpy.data.curves.remove(cu)


# ---------------------------------------------------------------- facade kit
def tier(cx, cy, w, d, z0, z1, fh=4.0, bay=4.0, glass="Window", pier="Concrete", band="White", pw=0.9, bh=1.2, rec=0.5,
         po=0.0, bo=0.2, cap=("Concrete", 1.0, 0.4), sill=None, muntin=None, bands=True):
    """rectangular block (w along x, d along y) with a window grid on all four faces:
    glass core recessed by `rec`, piers every ~`bay` (outer face `po` proud of the wall line), floor bands every `fh`
    (outer face `bo` proud), a cap slab on top. Returns the floor-line heights."""
    hx, hy = w / 2, d / 2
    if abs(bo - po) < 0.08:  # never coplanar with the piers (z-fighting even in the same colour)
        bo = po - 0.1
    bx(glass, cx - hx + rec, cx + hx - rec, cy - hy + rec, cy + hy - rec, z0, z1)
    cw = max(pw, rec + 0.1)  # one column per corner, shared by both faces
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(pier, cx + sx * (hx - cw), cx + sx * (hx + po), cy + sy * (hy - cw), cy + sy * (hy + po), z0, z1)
    faces = []
    for axis in "xy":
        for s in (-1, 1):
            faces.append((axis, s))
    for axis, s in faces:
        half, L = (hx, d) if axis == "x" else (hy, w)
        n = max(2, round(L / bay))
        a0, a1 = half - rec - 0.1, half + po  # depth range of a pier, measured outward from the centre
        for i in range(1, n):
            p = -L / 2 + i * L / n
            lo, hi = p - pw / 2, p + pw / 2
            if axis == "x":
                bx(pier, cx + s * a0, cx + s * a1, cy + lo, cy + hi, z0, z1)
            else:
                bx(pier, cx + lo, cx + hi, cy + s * a0, cy + s * a1, z0, z1)
        if muntin:
            for i in range(n):
                p = -L / 2 + (i + 0.5) * L / n
                m0, m1 = half - rec - 0.1, half - rec + 0.14
                if axis == "x":
                    bx(muntin, cx + s * m0, cx + s * m1, cy + p - 0.09, cy + p + 0.09, z0, z1)
                else:
                    bx(muntin, cx + p - 0.09, cx + p + 0.09, cy + s * m0, cy + s * m1, z0, z1)
    zs = []
    k = 1
    while z0 + k * fh < z1 - fh * 0.5:
        zs.append(z0 + k * fh)
        k += 1
    if bands:
        for z in zs:
            bx(band, cx - hx - bo, cx + hx + bo, cy - hy - bo, cy + hy + bo, z - bh / 2, z + bh / 2)
    if sill:
        for z in [z0] + zs:
            zt = z + (bh / 2 if z != z0 else 0) + 0.02
            for axis, s in faces:
                half, L = (hx, d) if axis == "x" else (hy, w)
                n = max(2, round(L / bay))
                for i in range(n):
                    p = -L / 2 + (i + 0.5) * L / n
                    sw = (L / n - pw) * 0.5 - 0.05
                    m0, m1 = half - rec - 0.1, half - rec + 0.32
                    if axis == "x":
                        bx(sill, cx + s * m0, cx + s * m1, cy + p - sw, cy + p + sw, zt, zt + 0.25)
                    else:
                        bx(sill, cx + p - sw, cx + p + sw, cy + s * m0, cy + s * m1, zt, zt + 0.25)
    if cap:
        look, h, out = cap
        bx(look, cx - hx - out, cx + hx + out, cy - hy - out, cy + hy + out, z1 - 0.3, z1 + h)
    return zs


def ring(look, cx, cy, w, d, z0, z1, t):
    """four walls (a hollow rectangle) of thickness t, outer size w x d"""
    hx, hy = w / 2, d / 2
    bx(look, cx - hx, cx + hx, cy + hy - t, cy + hy, z0, z1)
    bx(look, cx - hx, cx + hx, cy - hy, cy - hy + t, z0, z1)
    bx(look, cx + hx - t, cx + hx, cy - hy + t, cy + hy - t, z0, z1)
    bx(look, cx - hx, cx - hx + t, cy - hy + t, cy + hy - t, z0, z1)


def roof_box(look, x, y, sx, sy, z, h, grille="Dark"):
    """rooftop plant box with a louvre on the +X / -X sides"""
    bx(look, x - sx / 2, x + sx / 2, y - sy / 2, y + sy / 2, z - 0.2, z + h)
    for s in (-1, 1):
        bx(grille, x + s * (sx / 2 - 0.1), x + s * (sx / 2 + 0.12), y - sy / 2 + 0.5, y + sy / 2 - 0.5, z + 0.5, z + h - 0.5)


# ---------------------------------------------------------------- model assembly
roots = []


def finish(name):
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    for look in sorted(GEO):
        V, F = GEO[look]
        # split meshes above 18k tris (Roblox MeshPart limit is 20k)
        tri = [len(f) - 2 for f in F]
        chunks, cur, cnt = [], [], 0
        for f, t in zip(F, tri):
            if cnt + t > 18000 and cur:
                chunks.append(cur)
                cur, cnt = [], 0
            cur.append(f)
            cnt += t
        chunks.append(cur)
        for ci, faces in enumerate(chunks):
            used = sorted({i for f in faces for i in f})
            remap = {o: n for n, o in enumerate(used)}
            me = bpy.data.meshes.new(look)
            me.from_pydata([V[i] for i in used], [], [tuple(remap[i] for i in f) for f in faces])
            me.validate()
            me.update()
            for p in me.polygons:
                p.use_smooth = True
            me.set_sharp_from_angle(angle=math.radians(40))
            ob = bpy.data.objects.new(look + (str(ci + 1) if ci else ""), me)
            bpy.context.collection.objects.link(ob)
            mc.set_mat(ob, M(look))
            ob.parent = root
    GEO.clear()
    roots.append(root)
    return root


random.seed(7)

# ================================================================ Skyline_Office: glass tower, mullions, crown
W = 40
bx("Concrete", -24, 24, -24, 24, 0, 0.8)
tier(0, 0, 46, 46, 0.8, 11, fh=5, bay=5.5, pier="Concrete", band="Concrete", pw=1.4, rec=0.8, bo=0.3, bh=1.0,
     cap=("Concrete", 1.2, 0.6))
bx("Teal", 23.2, 28, -9, 9, 7.0, 7.8)  # entrance canopy
for y in (-8, 8):
    bx("Metal", 27.2, 27.8, y - 0.3, y + 0.3, 0.8, 7.1)
zs = tier(0, 0, W, W, 12, 140, fh=4.2, bay=4.0, pier="Metal", band="White", pw=0.45, po=0.35, rec=0.3, bh=0.6, bo=0.15,
          cap=None)
for sx in (-1, 1):  # teal corner columns, full height
    for sy in (-1, 1):
        bx("Teal", sx * (W / 2 - 1.3), sx * (W / 2 + 0.6), sy * (W / 2 - 1.3), sy * (W / 2 + 0.6), 11.5, 141.5)
bx("White", -W / 2 - 0.5, W / 2 + 0.5, -W / 2 - 0.5, W / 2 + 0.5, 139.7, 141.2)
# mechanical floor with louvres
bx("Dark", -W / 2 + 1.5, W / 2 - 1.5, -W / 2 + 1.5, W / 2 - 1.5, 141, 148)
for k in range(8):
    z = 141.6 + k * 0.8
    bx("Metal", -W / 2 + 1.2, W / 2 - 1.2, -W / 2 + 1.2, W / 2 - 1.2, z, z + 0.3)
bx("White", -W / 2 + 1, W / 2 - 1, -W / 2 + 1, W / 2 - 1, 147.8, 148.6)
# crown: fins rising from the plant floor + a teal ring beam
for axis in "xy":
    for s in (-1, 1):
        for i in range(9):
            p = -W / 2 + 3 + i * (W - 6) / 8
            o0, o1 = W / 2 - 1.6, W / 2 - 0.6
            if axis == "x":
                bx("Metal", s * o0, s * o1, p - 0.3, p + 0.3, 148.4, 156.2)
            else:
                bx("Metal", p - 0.3, p + 0.3, s * o0, s * o1, 148.4, 156.2)
ring("Teal", 0, 0, W - 0.6, W - 0.6, 156, 157.6, 1.6)
roof_box("Metal", -6, 4, 8, 6, 148.6, 3)
zc("Metal", 6, -6, 148.6, 155, 0.35, n=8)
zc("Glow", 6, -6, 155, 156, 0.6, n=8)
finish("Skyline_Office")

# ================================================================ Skyline_Apartment: brick, balconies, AC units
w, d = 32, 44
tier(0, 0, w, d, 0, 7, fh=20, bay=5.5, pier="Concrete", band="Concrete", pw=1.2, rec=0.6, cap=("White", 0.8, 0.45))
for s in (-1, 1):  # shop awnings front + back
    for i in range(8):
        y = -d / 2 + (i + 0.5) * d / 8
        box("Accent" if i % 2 == 0 else "White", (s * (w / 2 + 1.35), y, 5.9), (2.8, d / 8 - 0.6, 0.2), Matrix.Rotation(s * 0.3, 3, "Y"))
zs = tier(0, 0, w, d, 7.5, 63, fh=4.0, bay=4.4, pier="Brick", band="Brick", pw=1.4, bh=1.6, rec=0.5, po=0, bo=0,
          cap=("Concrete", 1.4, 0.5), sill="White", muntin="White")
# balconies on the front and back
for z in zs:
    for s in (-1, 1):
        for i in (1, 3, 6, 8):
            n = round(d / 4.4)
            y = -d / 2 + (i + 0.5) * d / n
            bw = d / n - 0.5
            x0, x1 = s * (w / 2 - 0.1), s * (w / 2 + 1.9)
            bx("White", x0, x1, y - bw / 2, y + bw / 2, z + 0.5, z + 0.8)
            bx("Metal", s * (w / 2 + 1.72), s * (w / 2 + 1.86), y - bw / 2 + 0.05, y + bw / 2 - 0.05, z + 0.8, z + 1.9)
            for e in (-1, 1):
                bx("Metal", x0, s * (w / 2 + 1.72), y + e * (bw / 2 - 0.12) - 0.06, y + e * (bw / 2 - 0.12) + 0.06, z + 0.8, z + 1.9)
# AC units hanging under side windows
for z in [7.5] + zs:
    for s in (-1, 1):
        n = round(w / 4.4)
        for i in range(n):
            if random.random() < 0.4:
                x = -w / 2 + (i + 0.5) * w / n
                bx("Metal", x - 0.8, x + 0.8, s * (d / 2 - 0.1), s * (d / 2 + 1.0), z - 0.55, z + 0.45)
                bx("Dark", x - 0.6, x + 0.6, s * (d / 2 + 0.95), s * (d / 2 + 1.1), z - 0.4, z + 0.3)
# roof: stair house, water heater, antennas
roof_box("Concrete", -6, 8, 8, 7, 64.4, 4.5)
bx("Dark", -6 + 4 - 0.1, -6 + 4 + 0.12, 9.5, 11, 64.4, 67.4)
zc("Metal", 6, -10, 64.4, 68, 1.8, n=14)
zc("Dark", 6, -10, 68, 68.6, 2.0, n=14)
for x, y in ((8, 10), (10, 4)):
    zc("Metal", x, y, 64.4, 70, 0.12, n=6)
    bx("Metal", x - 1, x + 1, y - 0.06, y + 0.06, 69, 69.15)
finish("Skyline_Apartment")

# ================================================================ Skyline_Deco: art-deco setback tower with spire
bx("Cream", -24, 24, -24, 24, 0, 9)
bx("Gold", 23.8, 24.4, -6, 6, 1, 8.4)  # entrance frame
bx("Dark", 24.2, 24.6, -4.5, 4.5, 0, 7)
bx("Gold", -24.2, 24.2, -24.2, 24.2, 8.2, 8.8)  # gold band round the base
TIERS = [(46, 9, 64), (36, 64, 104), (28, 104, 128), (20, 128, 140)]
for i, (tw, z0, z1) in enumerate(TIERS):
    tier(0, 0, tw, tw, z0, z1, fh=4.4, bay=3.4, pier="Cream", band="Dark", pw=1.2, po=0.6, rec=0.8, bh=1.4, bo=-0.3,
         cap=("Cream", 1.6, 0.9))
    hz = z1 + 1.6
    # ziggurat parapet steps + gold fin at the middle of each face
    for axis in "xy":
        for s in (-1, 1):
            for k, (hw, hh) in enumerate(((5.5, 1.6), (3.6, 3.2), (1.8, 4.6))):
                o0, o1 = tw / 2 - 1.0 + 0.0, tw / 2 + 0.9 - 0.15 * k
                if axis == "x":
                    bx("Cream", s * (tw / 2 - 1.2), s * o1, -hw, hw, hz - 0.2, hz + hh)
                else:
                    bx("Cream", -hw, hw, s * (tw / 2 - 1.2), s * o1, hz - 0.2, hz + hh)
            if axis == "x":
                bx("Gold", s * (tw / 2 + 0.5), s * (tw / 2 + 1.1), -0.5, 0.5, z1 - 10, hz + 4.0)
            else:
                bx("Gold", -0.5, 0.5, s * (tw / 2 + 0.5), s * (tw / 2 + 1.1), z1 - 10, hz + 4.0)
# spire
zc("Cream", 0, 0, 141.4, 146, 7.5, n=8)
zc("Gold", 0, 0, 144.6, 145.6, 7.85, n=8)
zc("Cream", 0, 0, 146, 150, 5.4, 5.0, n=8)
zc("Gold", 0, 0, 150, 153, 3.6, 3.2, n=8)
zc("Cream", 0, 0, 153, 157, 2.8, 0.6, n=8)
zc("Metal", 0, 0, 156.5, 160, 0.3, 0.08, n=6)
finish("Skyline_Deco")

# ================================================================ Skyline_Parking: open decks, ramps, parked cars
w, d = 40, 56
LV = [0.4, 7.5, 15, 22.5, 30, 37.5, 45]
CAR = ["Red", "Blue", "White", "Yellow", "Red", "Blue", "White"]
bx("Concrete", -w / 2, w / 2, -d / 2, d / 2, 0, 0.4)
for z in LV[1:]:
    bx("Concrete", -w / 2 + 0.2, w / 2 - 0.2, -d / 2 + 0.2, 16, z - 0.8, z)  # deck (ramp bay y > 16 left open)
    ring("Concrete", 0, 0, w + 0.4, d + 0.4, z - 0.9, z + 1.2, 0.5)  # spandrel / parapet
    for (x0, x1, y0, y1) in ((-w / 2 - 0.3, w / 2 + 0.3, d / 2 + 0.2, d / 2 + 0.32), (-w / 2 - 0.3, w / 2 + 0.3, -d / 2 - 0.32, -d / 2 - 0.2),
                             (w / 2 + 0.2, w / 2 + 0.32, -d / 2 - 0.3, d / 2 + 0.3), (-w / 2 - 0.32, -w / 2 - 0.2, -d / 2 - 0.3, d / 2 + 0.3)):
        bx("Yellow", x0, x1, y0, y1, z + 0.5, z + 0.9)
for x in (-18.6, -6.2, 6.2, 18.6):
    for y in (-26.6, -14, -1.5, 15.4, 26.6):
        bx("Concrete", x - 0.7, x + 0.7, y - 0.7, y + 0.7, 0.4, 44.8)  # tops end inside the roof slab
# switch-back ramps in the +Y bay
for l in range(len(LV) - 1):
    xa, xb = (-15.5, 15.5) if l % 2 == 0 else (15.5, -15.5)
    pa, pb = Vector((xa, 21.3, LV[l] - 0.3)), Vector((xb, 21.3, LV[l + 1] - 0.3))
    strut("Concrete", pa, pb, 10.4, 0.6, side=(0, 1, 0))
    strut("Yellow", pa + Vector((0, 5.0, 0.55)), pb + Vector((0, 5.0, 0.55)), 0.35, 0.5, side=(0, 1, 0))
    for e in (pa, pb):  # landings joining the ramp to the deck level
        bx("Concrete", e.x - 2.6 if e.x > 0 else e.x - 0.4, e.x + 0.4 if e.x > 0 else e.x + 2.6, 16, 26.5, e.z - 0.3, e.z + 0.3)
# parked cars along the open sides


def car(x, y, z, look, along_x=True):
    L, Wd = (7.2, 3.6) if along_x else (3.6, 7.2)
    bx("Dark", x - L / 2 + 0.6 * along_x, x + L / 2 - 0.6 * along_x, y - Wd / 2 + 0.6 * (not along_x), y + Wd / 2 - 0.6 * (not along_x), z, z + 0.9)
    bx(look, x - L / 2, x + L / 2, y - Wd / 2 + 0.1 * along_x, y + Wd / 2 - 0.1 * along_x, z + 0.5, z + 2.0)
    cl = (3.8, 3.0) if along_x else (3.0, 3.8)
    bx("Window", x - cl[0] / 2 - 0.4 * along_x, x + cl[0] / 2 - 0.4 * along_x, y - cl[1] / 2, y + cl[1] / 2, z + 2.0, z + 3.1)


for li, z in enumerate(LV):
    for s in (-1, 1):
        for k in range(8):
            if random.random() < 0.65:
                car(s * 15.0, -25 + k * 5.2, z, random.choice(CAR))
    for k in range(5):
        if random.random() < 0.5:
            car(-10 + k * 5.0, -23.2, z, random.choice(CAR), along_x=False)
# stair / lift tower + P signs
bx("Concrete", -w / 2 - 0.4, -w / 2 + 7.6, -d / 2 - 0.4, -d / 2 + 7.6, 0, 56)
bx("Concrete", -w / 2 - 0.8, -w / 2 + 8.0, -d / 2 - 0.8, -d / 2 + 8.0, 55.8, 57)
for yaw, x in ((math.pi / 2, -w / 2 + 7.6), (-math.pi / 2, -w / 2 - 0.4)):
    s = 1 if x > -w / 2 else -1
    bx("Blue", x - 0.1 * s if s > 0 else x - 0.3, x + 0.3 if s > 0 else x + 0.1, -d / 2 + 0.6, -d / 2 + 6.6, 47.5, 54.5)
    text("White", "P", 6.5, Vector((x + s * 0.45, -d / 2 + 3.6, 51)), yaw, depth=0.5)
for y in (-d / 2 - 0.4, -d / 2 + 7.6):
    s = 1 if y > -d / 2 else -1
    bx("Blue", -w / 2 + 0.6, -w / 2 + 6.6, y - 0.1 if s > 0 else y - 0.3, y + 0.3 if s > 0 else y + 0.1, 47.5, 54.5)
    text("White", "P", 6.5, Vector((-w / 2 + 3.6, y + s * 0.45, 51)), 0 if s < 0 else math.pi, depth=0.5)
# roof light poles
for x, y in ((-8, -10), (8, -10), (-8, 8), (8, 8)):
    zc("Metal", x, y, 45, 51, 0.22, n=8)
    bx("Dark", x - 1.0, x + 1.0, y - 0.4, y + 0.4, 51, 51.5)
    bx("White", x - 0.8, x + 0.8, y - 0.3, y + 0.3, 50.85, 51.05)
finish("Skyline_Parking")

# ================================================================ Skyline_Tank: block with rooftop water tanks + fire escapes
w, d = 36, 40
tier(0, 0, w, d, 0, 7, fh=20, bay=5, pier="Dark", band="Dark", pw=1.0, rec=0.5, cap=("Brick", 0.9, 0.4))
zs = tier(0, 0, w, d, 7.5, 66, fh=4.5, bay=4.0, pier="Sand", band="Sand", pw=1.6, bh=1.9, rec=0.5, bo=0, po=0,
          cap=("Brick", 1.2, 0.5), sill="White")
for z in zs[1::3]:  # brick string courses
    bx("Brick", -w / 2 - 0.2, w / 2 + 0.2, -d / 2 - 0.2, d / 2 + 0.2, z - 0.95, z - 0.55)


def fire_escape(axis, s, c0, c1):
    half = (w if axis == "x" else d) / 2
    P = lambda o, a, z: Vector((s * (half + o), a, z)) if axis == "x" else Vector((a, s * (half + o), z))
    side = (1, 0, 0) if axis == "x" else (0, 1, 0)
    fl = zs
    for k, z in enumerate(fl):
        zp = z + 0.9
        a0, a1 = P(-0.1, c0, zp - 0.2), P(2.0, c1, zp)
        bx("Dark", min(a0.x, a1.x), max(a0.x, a1.x), min(a0.y, a1.y), max(a0.y, a1.y), zp - 0.2, zp)
        r0, r1 = P(1.86, c0, zp + 1.0), P(1.98, c1, zp + 1.1)
        bx("Dark", min(r0.x, r1.x), max(r0.x, r1.x), min(r0.y, r1.y), max(r0.y, r1.y), zp + 1.0, zp + 1.12)
        for c in (c0 + 0.1, (c0 + c1) / 2, c1 - 0.1):
            p0, p1 = P(1.86, c - 0.06, zp), P(1.98, c + 0.06, zp)
            bx("Dark", min(p0.x, p1.x), max(p0.x, p1.x), min(p0.y, p1.y), max(p0.y, p1.y), zp, zp + 1.12)
        if k + 1 < len(fl):
            zn = fl[k + 1] + 0.9
            a, b = (c0 + 1.0, c1 - 1.0) if k % 2 == 0 else (c1 - 1.0, c0 + 1.0)
            strut("Dark", P(1.0, a, zp - 0.1), P(1.0, b, zn - 0.1), 1.3, 0.2, side=side)
            strut("Dark", P(1.7, a, zp + 1.0), P(1.7, b, zn + 1.0), 0.1, 0.1, side=side)
    # drop ladder down to the shop canopy
    p0, p1 = P(1.0, c0 + 1.0, 3.0), P(1.2, c0 + 1.8, fl[0] + 0.7)
    bx("Dark", min(p0.x, p1.x), max(p0.x, p1.x), min(p0.y, p1.y), max(p0.y, p1.y), 3.0, fl[0] + 0.7)


fire_escape("x", 1, -12.5, -2.5)
fire_escape("x", -1, 2.5, 12.5)
fire_escape("y", 1, -10, 0)
fire_escape("y", -1, 2, 12)


def water_tank(x, y, z, r, h):
    for a in range(4):
        ang = math.pi / 4 + a * math.pi / 2
        lx, ly = x + math.cos(ang) * r * 0.75, y + math.sin(ang) * r * 0.75
        bx("Dark", lx - 0.3, lx + 0.3, ly - 0.3, ly + 0.3, z - 0.2, z + 5.2)
    strut("Dark", (x - r * 0.53, y - r * 0.53, z + 0.3), (x + r * 0.53, y + r * 0.53, z + 4.8), 0.18)
    strut("Dark", (x - r * 0.53, y + r * 0.53, z + 0.3), (x + r * 0.53, y - r * 0.53, z + 4.8), 0.18)
    zc("Dark", x, y, z + 5.0, z + 5.5, r + 0.9, n=16)
    zc("Wood", x, y, z + 5.5, z + 5.5 + h, r, n=18)
    for t in (0.2, 0.5, 0.8):
        zc("Metal", x, y, z + 5.5 + h * t - 0.15, z + 5.5 + h * t + 0.15, r + 0.12, n=18)
    zc("Dark", x, y, z + 5.4 + h, z + 5.5 + h + 3.2, r + 0.45, 0.0, n=18)
    strut("Metal", (x + r + 0.3, y, z + 5.5), (x + r + 0.3, y, z + 5.5 + h + 0.5), 0.15, 0.9, side=(0, 1, 0))


water_tank(-6, 7, 67.2, 5.0, 8)
water_tank(8, -9, 67.2, 4.0, 6.5)
roof_box("Brick", 8, 9, 7, 6, 67.2, 4)
finish("Skyline_Tank")

# ================================================================ Skyline_Billboard: mid-rise + rooftop billboard
w, d = 34, 44
zs = tier(0, 0, w, d, 0, 54, fh=4.5, bay=5.5, pier="Concrete", band="White", pw=0.8, po=0.1, bh=2.0, bo=0.3, rec=0.4,
          cap=("Blue", 1.2, 0.5), muntin="Dark")
for z in zs[2::3]:  # blue stripes on every third spandrel
    bx("Blue", -w / 2 - 0.42, w / 2 + 0.42, -d / 2 - 0.42, d / 2 + 0.42, z - 0.35, z + 0.35)
bx("Concrete", -w / 2 - 0.3, w / 2 + 0.3, -d / 2 - 0.3, d / 2 + 0.3, 0, 2.2)  # plinth
bx("Dark", w / 2 + 0.2, w / 2 + 0.5, -4, 4, 0, 3.8)  # door
RZ = 55.2  # roof top
BZ0, BZ1, BW = 61, 75, 42
for y in (-16, -5.5, 5.5, 16):
    bx("Dark", -0.4, 0.4, y - 0.4, y + 0.4, RZ - 0.2, BZ0 + 0.2)
    for s in (-1, 1):
        strut("Dark", (s * 5, y, RZ), (0, y, BZ0 - 0.5), 0.45)
        bx("Dark", s * 5 - 0.6, s * 5 + 0.6, y - 0.6, y + 0.6, RZ - 0.2, RZ + 0.3)
strut("Dark", (0, -16, BZ0 - 2.5), (0, 16, BZ0 - 2.5), 0.4)
bx("White", -0.5, 0.5, -BW / 2, BW / 2, BZ0, BZ1)  # board (two-sided)
for (y0, y1, z0, z1) in ((-BW / 2 - 0.8, BW / 2 + 0.8, BZ0 - 0.8, BZ0), (-BW / 2 - 0.8, BW / 2 + 0.8, BZ1, BZ1 + 0.8),
                         (-BW / 2 - 0.8, -BW / 2, BZ0, BZ1), (BW / 2, BW / 2 + 0.8, BZ0, BZ1)):
    bx("Yellow", -0.75, 0.75, y0, y1, z0, z1)
for s in (-1, 1):
    yaw = math.pi / 2 if s > 0 else -math.pi / 2
    text("Red", "CAR HUNTERS", 5.7, Vector((s * 0.6, 0, (BZ0 + BZ1) / 2 + 1.4)), yaw, depth=0.6, sy=1.55, offset=0.03)
    f0, f1 = (0.42, 0.8) if s > 0 else (-0.8, -0.42)
    bx("Red", f0, f1, -13, 13, BZ0 + 1.5, BZ0 + 2.3)  # underline stripe
    for e in (-1, 1):  # chequered-flag patches in the lower corners
        for a in range(5):
            for b in range(2):
                if (a + b) % 2 == 0:
                    y = e * (19.4 - a * 0.9)
                    bx("Dark", f0, f1, y - 0.45, y + 0.45, BZ0 + 0.9 + b * 0.9, BZ0 + 1.8 + b * 0.9)
    # catwalk + rail + lamps
    bx("Dark", s * 0.5 if s > 0 else -2.6, 2.6 if s > 0 else -0.5, -BW / 2, BW / 2, BZ0 - 1.25, BZ0 - 1.0)
    bx("Dark", s * 2.45 if s > 0 else -2.6, 2.6 if s > 0 else -2.45, -BW / 2, BW / 2, BZ0 - 0.1, BZ0 + 0.05)
    for y in range(-20, 21, 5):
        bx("Dark", s * 2.45 if s > 0 else -2.6, 2.6 if s > 0 else -2.45, y - 0.08, y + 0.08, BZ0 - 1.0, BZ0 - 0.1)
    for y in (-15, -5, 5, 15):
        strut("Dark", (s * 0.7, y, BZ1 + 0.8), (s * 3.2, y, BZ1 + 2.0), 0.25)
        bx("Dark", s * 2.6 if s > 0 else -3.8, 3.8 if s > 0 else -2.6, y - 0.9, y + 0.9, BZ1 + 1.7, BZ1 + 2.4)
        bx("Glow", s * 2.8 if s > 0 else -3.6, 3.6 if s > 0 else -2.8, y - 0.7, y + 0.7, BZ1 + 1.55, BZ1 + 1.75)
roof_box("Concrete", -10, -14, 7, 6, RZ, 3.5)
finish("Skyline_Billboard")

# ================================================================ Skyline_Stepped: stepped skyscraper + antenna
STEPS = [(52, 0, 56), (42, 56, 96), (32, 96, 124), (22, 124, 140)]
for i, (tw, z0, z1) in enumerate(STEPS):
    tier(0, 0, tw, tw, z0 + (0 if i == 0 else 1.2), z1, fh=4.0, bay=3.5, pier="White", band="Teal", pw=0.5, po=0.3, rec=0.3,
         bh=1.4, bo=0.15, cap=("White", 1.2, 0.6))
    if i < len(STEPS) - 1:  # plant boxes on the setback terraces
        nw = STEPS[i + 1][0]
        off = (tw + nw) / 4
        roof_box("Metal", off, -nw / 4, 3.5, 6, z1 + 1.2, 2.2)
        roof_box("Metal", -off, nw / 4, 3.5, 6, z1 + 1.2, 2.2)
bx("Teal", -27, 27, -27, 27, 0, 3.5)  # lobby base band
bx("White", -4, 4, -4, 4, 141, 145)
zc("Metal", 0, 0, 145, 153, 1.3, 0.7, n=10)
zc("Metal", 0, 0, 153, 160, 0.35, 0.15, n=8)
for z in (148, 152):
    for a in range(3):
        ang = a * 2 * math.pi / 3
        strut("Metal", (0, 0, z), (math.cos(ang) * 2.6, math.sin(ang) * 2.6, z), 0.18)
zc("Accent", 0, 0, 158.4, 159.2, 0.5, n=8)
finish("Skyline_Stepped")

# ================================================================ Skyline_Warehouse: wide industrial, saw-tooth roof, chimney
w, d, H = 44, 60, 22
tier(0, 0, w, d, 0, H, fh=11, bay=6, pier="Brick", band="Brick", pw=2.0, bh=6, rec=0.5, po=0, bo=0,
     cap=("Concrete", 1.0, 0.4), muntin="Dark")
bx("Brick", -w / 2 - 0.2, w / 2 + 0.2, -d / 2 - 0.2, d / 2 + 0.2, 0, 3)  # plinth
for y in (-18, 0, 18):  # loading doors
    bx("Metal", w / 2 - 0.1, w / 2 + 0.35, y - 4, y + 4, 0, 7.6)
    for k in range(10):
        bx("Dark", w / 2 + 0.3, w / 2 + 0.47, y - 3.9, y + 3.9, 0.5 + k * 0.72, 0.62 + k * 0.72)
    bx("Yellow", w / 2 - 0.1, w / 2 + 0.6, y - 4.6, y + 4.6, 7.6, 8.4)
    bx("Yellow", w / 2 + 0.35, w / 2 + 1.6, y - 4.8, y + 4.8, 0, 0.3)  # dock edge
RZ = H + 1.0
for k in range(5):
    xa = -w / 2 + 0.6 + k * (w - 1.2) / 5
    xb = xa + (w - 1.2) / 5
    extrude("Metal", [(xa, RZ - 0.2), (xb, RZ - 0.2), (xb, RZ + 6)], (0, d / 2 - 0.6, 0), (1, 0, 0), (0, 0, 1), d - 1.2)
    bx("Window", xb - 0.1, xb + 0.15, -d / 2 + 1.2, d / 2 - 1.2, RZ + 0.5, RZ + 5.4)
    for j in range(15):
        y = -d / 2 + 1.2 + j * (d - 2.4) / 14
        bx("Dark", xb - 0.1, xb + 0.28, y - 0.15, y + 0.15, RZ + 0.4, RZ + 5.5)
# chimney
CX, CY = -14, 22
bx("Brick", CX - 3.5, CX + 3.5, CY - 3.5, CY + 3.5, RZ - 0.3, RZ + 4)
zc("Brick", CX, CY, RZ + 3.8, 67, 2.7, 2.1, n=16)
zc("White", CX, CY, 60, 61.2, 2.42, 2.4, n=16)
zc("White", CX, CY, 62.5, 63.7, 2.34, 2.32, n=16)
zc("Dark", CX, CY, 66.4, 68, 2.5, n=16)
for x, y in ((6, -20), (6, 10), (-4, -6)):
    zc("Metal", x, y, RZ, RZ + 8.0, 0.8, n=10)  # vents poking up between the teeth
    zc("Dark", x, y, RZ + 8.0, RZ + 8.6, 1.2, n=10)
finish("Skyline_Warehouse")

# ================================================================ Skyline_Hotel: curved corners, trim bands, HOTEL sign
w, d, R = 34, 50, 9
BZ, TZ, FH = 9, 95, 4.0
rprism("Window", w - 0.8, d - 0.8, R - 0.4, 0, TZ)
rprism("Cream", w + 0.4, d + 0.4, R + 0.2, 0, 1.0)  # plinth
rprism("Cream", w + 0.8, d + 0.8, R + 0.4, BZ - 1.4, BZ)  # lobby fascia
k = 0
z = BZ + FH
while z < TZ - 1:
    rprism("Cream", w, d, R, z - 0.7, z + 0.7)
    if k % 3 == 1:
        rprism("Teal", w + 0.5, d + 0.5, R + 0.25, z - 0.35, z + 0.35)
    z += FH
    k += 1
# mullion fins along the outline (arc-length spaced)
pts = rrect(w - 0.3, d - 0.3, R - 0.15, seg=12)
seg_l = [(Vector(a) - Vector(b)).length for a, b in zip(pts, pts[1:] + pts[:1])]
per = sum(seg_l)
nf = int(per / 3.6)
acc, si = 0.0, 0
for i in range(nf):
    t = i * per / nf
    while acc + seg_l[si] < t:
        acc += seg_l[si]
        si += 1
    a, b = Vector(pts[si]), Vector(pts[(si + 1) % len(pts)])
    p = a.lerp(b, (t - acc) / seg_l[si])
    tang = (b - a).normalized()
    nrm = Vector((tang.y, -tang.x))
    c = p + nrm * 0.0
    box("Cream", (c.x, c.y, (BZ + TZ) / 2), (0.36, 0.9, TZ - BZ), math.atan2(nrm.y, nrm.x))
# lobby: canopy + gold columns on the front
bx("Accent", w / 2 + 0.2, w / 2 + 5.5, -10, 10, 6.4, 7.2)
for y in (-9.2, 9.2):
    bx("Gold", w / 2 + 4.6, w / 2 + 5.2, y - 0.3, y + 0.3, 1.0, 6.5)
# crown + penthouse
rprism("Teal", w + 0.6, d + 0.6, R + 0.3, TZ - 0.4, TZ + 0.6)
rprism("Cream", w + 0.2, d + 0.2, R + 0.1, TZ + 0.6, TZ + 2.2)
rprism("Cream", w - 10, d - 14, R - 5, TZ + 2.0, TZ + 7)
rprism("Teal", w - 9.4, d - 13.4, R - 4.7, TZ + 7, TZ + 7.8)
# HOTEL sign on a steel frame, letters both sides
SZ0 = TZ + 7.8
for y in (-13, -4.5, 4.5, 13):
    bx("Dark", -0.5, 0.5, y - 0.4, y + 0.4, SZ0 - 0.2, SZ0 + 11)
    for s in (-1, 1):
        strut("Dark", (s * 3.5, y, SZ0), (0, y, SZ0 + 5), 0.3)
bx("Dark", -0.3, 0.3, -15.5, 15.5, SZ0 + 3.4, SZ0 + 11.2)
for s in (-1, 1):
    text("Red", "HOTEL", 9.5, Vector((s * 0.38, 0, SZ0 + 7.3)), math.pi / 2 if s > 0 else -math.pi / 2, depth=0.5, sy=0.95, offset=0.02)
finish("Skyline_Hotel")

# ================================================================ Skyline_Radio: lattice radio tower on a small building
w, d = 30, 34
tier(0, 0, w, d, 0, 18, fh=6, bay=5, pier="Concrete", band="Concrete", pw=1.0, bh=2.2, rec=0.5, po=0, bo=0.2,
     cap=("White", 1.0, 0.4), sill="White")
bx("Dark", w / 2 - 0.1, w / 2 + 0.3, -2, 2, 0, 4)
TZ0, TZ1, HW0, HW1, NS = 19, 146, 7.5, 1.1, 16
for sx in (-1, 1):
    for sy in (-1, 1):
        bx("Concrete", sx * HW0 - 1.2, sx * HW0 + 1.2, sy * HW0 - 1.2, sy * HW0 + 1.2, TZ0 - 0.3, TZ0 + 1.0)
lv = [TZ0 + 1.0 + (TZ1 - TZ0 - 1.0) * (i / NS) for i in range(NS + 1)]
hw = [HW0 + (HW1 - HW0) * (i / NS) for i in range(NS + 1)]
CORN = [(1, 1), (-1, 1), (-1, -1), (1, -1)]
for i in range(NS):
    look = "Accent" if (i // 2) % 2 == 0 else "White"
    z0, z1, h0, h1 = lv[i], lv[i + 1], hw[i], hw[i + 1]
    for cxs, cys in CORN:
        strut(look, (cxs * h0, cys * h0, z0 - 0.3), (cxs * h1, cys * h1, z1 + 0.3), 0.7)
    for j in range(4):
        (ax, ay), (bx_, by) = CORN[j], CORN[(j + 1) % 4]
        strut(look, (ax * h1, ay * h1, z1), (bx_ * h1, by * h1, z1), 0.35)
        strut(look, (ax * h0, ay * h0, z0), (bx_ * h1, by * h1, z1), 0.3)
        strut(look, (bx_ * h0, by * h0, z0), (ax * h1, ay * h1, z1), 0.3)
for zi in (6, 11):  # platforms
    z, h = lv[zi], hw[zi] + 1.8
    bx("Dark", -h, h, -h, h, z - 0.3, z)
    ring("Dark", 0, 0, 2 * h, 2 * h, z + 1.0, z + 1.15, 0.12)
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx("Dark", sx * h - 0.12 * (sx > 0), sx * h + 0.12 * (sx < 0), sy * h - 0.12 * (sy > 0), sy * h + 0.12 * (sy < 0), z, z + 1.15)
for zi, ang in ((8, 0.0), (8, math.pi), (13, math.pi / 2)):  # dishes
    z, h = (lv[zi] + lv[zi + 1]) / 2, (hw[zi] + hw[zi + 1]) / 2
    dvec = Vector((math.cos(ang), math.sin(ang), 0))
    base = dvec * (h + 0.2) + Vector((0, 0, z))
    strut("Metal", base - dvec * 0.6, base + dvec * 1.2, 0.3)
    cyl("Metal", base + dvec * 1.0, base + dvec * 2.0, 1.0, 2.6, n=16)
zc("Metal", 0, 0, TZ1, TZ1 + 6, 0.45, 0.25, n=8)
zc("Glow", 0, 0, TZ1 + 6, TZ1 + 7, 0.6, n=8)
roof_box("Metal", -9, 11, 5, 4, 19, 2.5)
roof_box("Metal", 9, -11, 5, 4, 19, 2.5)
finish("Skyline_Radio")

# ================================================================ export + sizes
tris = {}
for r in roots:
    if ONLY and r.name not in ONLY:
        continue
    mc.export([r], os.path.join(OUT, r.name + ".fbx"))
    tris[r.name] = (mc.triangles(r), {c.name: sum(len(p.vertices) - 2 for p in c.data.polygons) for c in r.children})
for k, (t, per) in tris.items():
    print(f"  {k}: {t} tris, {len(per)} meshes {per}")
print("skyline ok", len(tris), "models; max tris", max(t for t, _ in tris.values()))

sizes_path = os.path.join(mc.ROOT, "src", "ReplicatedStorage", "Shared", "ModelSizes.lua")
existing = open(sizes_path).read() if os.path.exists(sizes_path) else ""
entries = dict(re.findall(r"\n\t(\w+) = (\{ size = [^\n]*\}),", existing))  # keeps every other entry
head = existing[: existing.index("return {")].rstrip("\n").split("\n") if "return {" in existing else [
    "-- generated by blender/make_spawn.py + make_city.py + make_garage.py + make_skyline.py: longest side (studs), bounding-box",
    "-- centre relative to the model origin in Roblox axes (x, up, z), footprint w/d. ModelService puts the pivot back on the Blender origin."]
for r in roots:
    if ONLY and r.name not in ONLY:
        continue
    pts = [c.matrix_world @ Vector(v) for c in r.children for v in c.bound_box]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    ext = max(hi[i] - lo[i] for i in range(3))
    cx, cy, cz = [(lo[i] + hi[i]) / 2 for i in range(3)]
    # Blender (x, y, z) -> Roblox (-x, z, y); footprint w = Roblox X extent, d = Roblox Z extent
    entries[r.name] = f"{{ size = {ext:.2f}, c = {{ {-cx + 0:.2f}, {cz:.2f}, {cy + 0:.2f} }}, w = {hi[0] - lo[0]:.2f}, d = {hi[1] - lo[1]:.2f} }}"
lines = head + ["return {"] + [f"\t{k} = {entries[k]}," for k in sorted(entries)] + ["}"]
open(sizes_path, "w").write("\n".join(lines) + "\n")

if "--detail" in sys.argv:  # close-up check render of a few models: --detail out.png [--pick A,B] [--yaw deg]
    out = sys.argv[sys.argv.index("--detail") + 1]
    pick = sys.argv[sys.argv.index("--pick") + 1].split(",") if "--pick" in sys.argv else [r.name for r in roots[:3]]
    yaw = float(sys.argv[sys.argv.index("--yaw") + 1]) if "--yaw" in sys.argv else -28
    sel = [r for r in roots if r.name in pick or r.name.replace("Skyline_", "") in pick]
    for r in roots:
        r.location = (0, 0, -1000) if r not in sel else r.location
    sc, cam, co = mc.setup_scene(1800, 1400, samples=16)
    for i, r in enumerate(sel):
        r.location = (0, (i - (len(sel) - 1) / 2) * 75, 0)
        r.rotation_euler = (0, 0, math.radians(yaw))
    cam.type = "ORTHO"
    hmax = max(max((c.matrix_world @ Vector(v)).z for c in r.children for v in c.bound_box) for r in sel)
    cam.ortho_scale = max(75 * len(sel), hmax * 1800 / 1400 * 1.08)
    tgt = Vector((0, 0, hmax / 2))
    co.location = tgt + Vector((1, 0, 0.25)).normalized() * 900
    co.rotation_euler = (tgt - co.location).to_track_quat("-Z", "Y").to_euler()
    cam.clip_end = 3000
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)
elif "--render" in sys.argv:
    out = sys.argv[sys.argv.index("--render-out") + 1] if "--render-out" in sys.argv else os.path.join(mc.ROOT, "docs", "renders", "skyline.png")
    sc, cam, co = mc.setup_scene(1600, 500, samples=24)
    sp = 72
    for i, r in enumerate(roots):
        r.location = (0, (i - (len(roots) - 1) / 2) * sp, 0)
        r.rotation_euler = (0, 0, math.radians(-28))
    cam.type = "ORTHO"
    cam.ortho_scale = sp * len(roots) + 10
    tgt = Vector((0, 0, 84))
    dirv = Vector((1, 0, 0.12)).normalized()
    co.location = tgt + dirv * 900
    co.rotation_euler = (tgt - co.location).to_track_quat("-Z", "Y").to_euler()
    cam.clip_end = 3000
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("render", out)
