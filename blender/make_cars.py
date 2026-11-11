"""CAR HUNTERS - procedural car models for Roblox, built in Blender (bpy).

Run:  blender -b -P blender/make_cars.py            (or: python3 blender/make_cars.py with `pip install bpy`)
Out:  assets/cars/cars_collection.fbx  (20 collectible cars, one empty per car id)
      assets/cars/cars_traffic.fbx     (11 traffic kinds)
      assets/cars/<id>.fbx             (single cars, optional import)
      docs/renders/*.png               (preview renders)
Convention: nose points +X, wheels on Y=0 ground (Blender Z-up -> Roblox Y-up on export).
Each car = parts split by material: Body, Glass, Trim, Chrome, Tire, Rim, HeadLight, TailLight, Neon.
The Roblox side (ServerStorage.Tools.CarModelTool.ApplyImported) maps these names to Roblox materials.
"""
import math, os, random, sys
import bpy, bmesh
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "cars")
RENDERS = os.path.join(ROOT, "docs", "renders")
os.makedirs(OUT, exist_ok=True)
os.makedirs(RENDERS, exist_ok=True)

# ---------------------------------------------------------------- dimensions (studs, = VehicleKinds.lua)
KINDS = {
    "compact": dict(L=11.5, W=5.8, H=4.6, wr=1.2, clear=0.7, fam="hatch"),
    "sedan": dict(L=14.5, W=6.2, H=4.7, wr=1.3, clear=0.8, fam="sedan"),
    "taxi": dict(L=14.5, W=6.2, H=4.7, wr=1.3, clear=0.8, fam="sedan", taxi=True),
    "van": dict(L=14.5, W=6.6, H=6.6, wr=1.4, clear=0.9, fam="van"),
    "minibus": dict(L=18, W=6.8, H=7.0, wr=1.4, clear=0.9, fam="bus"),
    "sport": dict(L=14.8, W=6.6, H=3.9, wr=1.25, clear=0.55, fam="sport"),
    "supercar": dict(L=15.2, W=7.0, H=3.5, wr=1.25, clear=0.45, fam="super"),
    "pickup": dict(L=16.5, W=6.6, H=5.6, wr=1.5, clear=1.0, fam="pickup"),
    "service": dict(L=15.5, W=6.6, H=6.2, wr=1.4, clear=0.9, fam="van", lightbar=True),
    "truck": dict(L=26, W=7.6, H=8.8, wr=2.0, clear=1.4, fam="truck"),
    "proto": dict(L=15.8, W=7.0, H=3.7, wr=1.25, clear=0.5, fam="super", neon=True),
}

# side profile per family. f: 0 = rear bumper, 1 = front bumper. belt = shoulder line (fraction of H).
# cab = (rear glass base, roof rear, roof front, windshield base). panel = greenhouse part that is body, not glass.
FAM = {
    "hatch": dict(belt=[(0, .46), (.05, .57), (.5, .58), (.82, .56), (.95, .48), (1, .40)], cab=(.04, .14, .56, .74), axle=(.17, .83), plan=5),
    "sedan": dict(belt=[(0, .42), (.06, .55), (.25, .57), (.75, .55), (.93, .48), (1, .38)], cab=(.20, .33, .60, .74), axle=(.19, .81), plan=6),
    "sport": dict(belt=[(0, .50), (.08, .62), (.3, .64), (.7, .54), (.95, .40), (1, .32)], cab=(.16, .36, .55, .73), axle=(.18, .80), plan=6),
    "super": dict(belt=[(0, .56), (.1, .66), (.35, .68), (.7, .48), (.95, .34), (1, .28)], cab=(.22, .42, .56, .78), axle=(.18, .80), plan=7),
    "van": dict(belt=[(0, .50), (.1, .52), (.85, .52), (.95, .45), (1, .36)], cab=(.0, .02, .80, .93), axle=(.16, .80), plan=8, panel=.66),
    "bus": dict(belt=[(0, .40), (.9, .40), (1, .34)], cab=(.0, .02, .93, .99), axle=(.15, .82), plan=9),
    "pickup": dict(belt=[(0, .56), (.92, .56), (1, .46)], cab=(.43, .46, .64, .77), axle=(.17, .82), plan=7, bed=(.02, .42)),
    "truck": dict(belt=[(0, .30), (.95, .30), (1, .26)], cab=(.73, .75, .95, .99), axle=(.12, .30, .86), plan=9, box=(.02, .70)),
}

# ---------------------------------------------------------------- collectible cars (= CarConfig.lua)
def rgb(r, g, b):
    return (r / 255, g / 255, b / 255, 1)

CARS = [
    ("rusty_compact", "compact", rgb(176, 108, 70), {}), ("pocket_hatch", "compact", rgb(120, 210, 180), {"short": True}),
    ("dusty_sedan", "sedan", rgb(160, 162, 170), {}), ("mule_pickup", "pickup", rgb(206, 170, 112), {}),
    ("street_runner", "sedan", rgb(60, 128, 236), {"sporty": True}), ("city_taxi", "taxi", rgb(255, 206, 50), {}),
    ("cargo_hopper", "van", rgb(80, 180, 110), {}), ("boulevard_gt", "sedan", rgb(250, 146, 60), {"spoiler": True, "sporty": True}),
    ("night_phantom", "sport", rgb(34, 32, 44), {"neon": rgb(40, 200, 255)}), ("iron_hauler", "truck", rgb(118, 126, 140), {}),
    ("redline_coupe", "sport", rgb(225, 46, 52), {"spoiler": True}), ("volt_cruiser", "sedan", rgb(50, 178, 184), {"neon": rgb(60, 240, 255)}),
    ("turbo_vortex", "sport", rgb(255, 124, 36), {"spoiler": True, "neon": rgb(255, 150, 40)}), ("chrome_viper", "supercar", rgb(206, 214, 226), {"chrome": True}),
    ("apex_predator", "supercar", rgb(36, 120, 70), {"spoiler": True, "neon": rgb(90, 255, 120)}), ("solar_flare", "supercar", rgb(255, 214, 50), {"neon": rgb(255, 190, 40)}),
    ("neon_specter", "proto", rgb(26, 30, 46), {"neon": rgb(40, 230, 255)}), ("hyper_nova", "proto", rgb(40, 20, 24), {"neon": rgb(255, 60, 90), "spoiler": True}),
    ("quantum_drift", "proto", rgb(236, 240, 255), {"neon": rgb(110, 150, 255)}), ("eclipse_titan", "proto", rgb(18, 18, 22), {"neon": rgb(255, 190, 40), "spoiler": True}),
]
TRAFFIC_COLOR = rgb(220, 60, 60)

# ---------------------------------------------------------------- helpers
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

MATS = {}
def mat(name, color, metal=0.0, rough=0.4, emit=None, alpha=1.0):
    key = (name, tuple(round(c, 3) for c in color))
    if key in MATS:
        return MATS[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if emit:
        bsdf.inputs["Emission Color"].default_value = emit
        bsdf.inputs["Emission Strength"].default_value = 3.0
    if alpha < 1:
        bsdf.inputs["Alpha"].default_value = alpha
    m.diffuse_color = color
    MATS[key] = m
    return m

def interp(pts, f):
    for (a, ya), (b, yb) in zip(pts, pts[1:]):
        if a <= f <= b:
            t = (f - a) / max(b - a, 1e-6)
            t = t * t * (3 - 2 * t)
            return ya + (yb - ya) * t
    return pts[-1][1]

def squircle(n, k):
    """unit squircle points (y, z) in [-1,1], counter-clockwise, k points."""
    out = []
    for i in range(k):
        a = 2 * math.pi * i / k
        c, s = math.cos(a), math.sin(a)
        out.append((math.copysign(abs(s) ** (2 / n), s), math.copysign(abs(c) ** (2 / n), c)))
    return out

def loft(name, rings, mats_fn=None, closed=True, cap=True):
    """rings: list of lists of Vector. builds quads between rings (+ end caps)."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    vrings = [[bm.verts.new(p) for p in r] for r in rings]
    k = len(rings[0])
    seg = k if closed else k - 1
    for a, b in zip(vrings, vrings[1:]):
        for i in range(seg):
            j = (i + 1) % k
            try:
                bm.faces.new((a[i], a[j], b[j], b[i]))
            except ValueError:
                pass
    if cap and closed:
        for r, rev in ((vrings[0], True), (vrings[-1], False)):
            try:
                f = bm.faces.new(list(reversed(r)) if rev else r)
            except ValueError:
                pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob

def apply_mods(ob):
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.selected_objects:
        o.select_set(False)
    ob.select_set(True)
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)

def subsurf(ob, lvl=1):
    m = ob.modifiers.new("ss", "SUBSURF")
    m.levels = lvl
    m.render_levels = lvl
    apply_mods(ob)
    for p in ob.data.polygons:
        p.use_smooth = True

def prim(kind, name, loc, size, rot=(0, 0, 0), verts=24):
    if kind == "box":
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=0.5, depth=1, location=loc, rotation=rot)
    elif kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.5, location=loc, rotation=rot)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return ob

def bevel(ob, w=0.15, seg=2):
    m = ob.modifiers.new("bv", "BEVEL")
    m.width = w
    m.segments = seg
    m.limit_method = "ANGLE"
    apply_mods(ob)

def set_mat(ob, m):
    ob.data.materials.clear()
    ob.data.materials.append(m)

def join(objs, name):
    objs = [o for o in objs if o]
    if not objs:
        return None
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = name
    return ob

# ---------------------------------------------------------------- car builder
def build_car(cid, kind, color, opt, seed, low=False):
    rnd = random.Random(seed)
    k = dict(KINDS[kind])
    fam = FAM[k["fam"]]
    L = k["L"] * (0.92 if opt.get("short") else 1.0)
    W, H, wr, clear = k["W"], k["H"], k["wr"], k["clear"]
    jit = lambda v, a: v * (1 + rnd.uniform(-a, a))
    roofH = jit(H, 0.03)
    beltK = jit(1.0, 0.03) * (0.96 if opt.get("sporty") else 1.0)
    neon = opt.get("neon") or ((0.2, 0.9, 1, 1) if k.get("neon") else None)

    M = {
        "Body": mat("Body", color, metal=0.6 if opt.get("chrome") else 0.25, rough=0.15 if opt.get("chrome") else 0.3),
        "Glass": mat("Glass", (0.10, 0.16, 0.22, 1), rough=0.05, alpha=0.6),
        "Trim": mat("Trim", (0.05, 0.05, 0.06, 1), rough=0.6),
        "Chrome": mat("Chrome", (0.85, 0.86, 0.9, 1), metal=1, rough=0.12),
        "Tire": mat("Tire", (0.03, 0.03, 0.035, 1), rough=0.9),
        "Rim": mat("Rim", (0.75, 0.77, 0.8, 1) if not neon else (0.12, 0.12, 0.14, 1), metal=1, rough=0.2),
        "HeadLight": mat("HeadLight", (1, 0.97, 0.85, 1), emit=(1, 0.97, 0.85, 1)),
        "TailLight": mat("TailLight", (1, 0.08, 0.12, 1), emit=(1, 0.05, 0.1, 1)),
    }
    if neon:
        M["Neon"] = mat("Neon", neon, emit=neon)
    M["Cargo"] = mat("Cargo", (0.94, 0.94, 0.96, 1), rough=0.5)
    parts = {n: [] for n in M}

    x0 = -L / 2
    plan = fam["plan"]
    def half_w(f):  # plan view rounding at both ends
        u = abs(f * 2 - 1)
        return W / 2 * (0.58 + 0.42 * (max(0.0, 1 - u ** plan)) ** (1 / plan))

    bmin = 2 * wr + 0.55  # shoulder line always clears the wheel arches

    def belt(f):
        b = interp(fam["belt"], f) * H * beltK
        edge = min(1.0, min(f, 1 - f) / 0.12)  # allow a lower nose/tail
        return max(b, bmin * (0.82 + 0.18 * edge))

    # ---- lower body (squircle sections)
    N, K = (26, 16) if low else (44, 24)
    sq = squircle(5, K)
    rings = []
    for i in range(N + 1):
        f = i / N
        f = 0.5 - 0.5 * math.cos(f * math.pi)  # denser at the ends
        x = x0 + f * L
        hw = half_w(f)
        bot = clear + 0.25 * (abs(f * 2 - 1) ** 6)
        top = belt(f)
        cy, hy = (top + bot) / 2, (top - bot) / 2
        ring = []
        for (sy, sz) in sq:
            tumble = 1 - 0.07 * max(0, sy)
            ring.append(Vector((x, sz * hw * tumble, cy + sy * hy)))
        rings.append(ring)
    body = loft(cid + "_body", rings)
    subsurf(body, 1)
    # wheel arches
    axles = [x0 + a * L for a in fam["axle"]]
    for ax in axles:
        cut = prim("cyl", "cut", (ax, 0, wr), (wr * 2.3, wr * 2.3, W * 1.4), rot=(math.pi / 2, 0, 0), verts=32)
        m = body.modifiers.new("arch", "BOOLEAN")
        m.object = cut
        m.operation = "DIFFERENCE"
        m.solver = "EXACT"
        apply_mods(body)
        bpy.data.objects.remove(cut)
    set_mat(body, M["Body"])
    parts["Body"].append(body)

    # ---- greenhouse (glass + roof/pillars as body)
    rg, rr, rf, ws = fam["cab"]
    if opt.get("sporty"):
        rr, rf = rr + 0.02, rf - 0.02
    def roof(f):
        if f <= rg or f >= ws:
            return None
        if f < rr:
            t = (f - rg) / (rr - rg)
        elif f > rf:
            t = (ws - f) / (ws - rf)
        else:
            t = 1
        t = math.sin(t * math.pi / 2) ** 0.8
        return belt(f) + (roofH - belt(f)) * t
    NG, KG = (18, 14) if low else (30, 20)
    sqg = squircle(7, KG)
    grings, fl = [], []
    for i in range(NG + 1):
        f = rg + (ws - rg) * (i / NG)
        f = min(max(f, rg + 1e-3), ws - 1e-3)
        r_top = roof(f) or belt(f) + 0.02
        b = belt(f) - 0.05
        cy, hy = (r_top + b) / 2, max((r_top - b) / 2, 0.01)
        hw = half_w(f) * 0.93
        ring = []
        for (sy, sz) in sqg:
            v = (sy + 1) / 2
            ring.append(Vector((x0 + f * L, sz * hw * (1 - 0.24 * v), cy + sy * hy)))
        grings.append(ring)
        fl.append(f)
    gh = loft(cid + "_cabin", grings)
    gh.data.materials.append(M["Glass"])
    gh.data.materials.append(M["Body"])
    panel = fam.get("panel", -1)
    for p in gh.data.polygons:
        c = p.center
        f = (c.x - x0) / L
        top = roof(min(max(f, rg + 1e-3), ws - 1e-3)) or 0
        is_roof = p.normal.z > 0.72 and rr - 0.03 < f < rf + 0.03
        is_pillar = (abs(f - rf) < 0.025 or abs(f - rr) < 0.03 or abs(f - (rr + rf) / 2) < 0.012) and abs(c.y) > 0.25 * W
        is_low = c.z < belt(f) + 0.12
        is_panel = f < panel and abs(c.y) > 0.2 * W
        if is_roof or is_pillar or is_low or is_panel:
            p.material_index = 1
    for p in gh.data.polygons:
        p.use_smooth = True
    parts["Glass"].append(gh)

    # ---- pickup bed / truck cargo box
    if "bed" in fam:
        a, b = fam["bed"]
        xa, xb, y0 = x0 + a * L, x0 + b * L, belt(0.2)
        bw = half_w(0.2) * 2 * 0.96
        parts["Trim"].append(prim("box", "bedfloor", ((xa + xb) / 2, 0, y0 - 0.05), (xb - xa, bw, 0.2)))
        for s in (-1, 1):
            parts["Body"].append(prim("box", "bedwall", ((xa + xb) / 2, s * (bw / 2 - 0.12), y0 + 0.45), (xb - xa, 0.24, 0.9)))
        parts["Body"].append(prim("box", "tailgate", (xa + 0.12, 0, y0 + 0.45), (0.24, bw, 0.9)))
    if "box" in fam:
        a, b = fam["box"]
        xa, xb = x0 + a * L, x0 + b * L
        cargo = prim("box", "cargo", ((xa + xb) / 2, 0, (belt(0.3) + H) / 2), (xb - xa, W * 0.98, H - belt(0.3)))
        bevel(cargo, 0.2, 2)
        parts["Cargo"].append(cargo)
        stripe = prim("box", "stripe", ((xa + xb) / 2, 0, (belt(0.3) + H) / 2), (xb - xa - 0.4, W * 0.99, 0.8))
        parts["Body"].append(stripe)

    # ---- wheels
    tw = 0.95 if k["fam"] != "truck" else 1.3
    for ax in axles:
        for s in (-1, 1):
            y = s * (W / 2 - tw / 2 - 0.05)
            t = prim("cyl", "tire", (ax, y, wr), (wr * 2, wr * 2, tw), rot=(math.pi / 2, 0, 0), verts=28)
            bevel(t, 0.22, 3)
            parts["Tire"].append(t)
            ry = y + s * (tw / 2 - 0.1)
            parts["Rim"].append(prim("cyl", "rim", (ax, ry, wr), (wr * 1.3, wr * 1.3, 0.22), rot=(math.pi / 2, 0, 0), verts=24))
            parts["Chrome"].append(prim("cyl", "hub", (ax, ry + s * 0.08, wr), (wr * 0.36, wr * 0.36, 0.2), rot=(math.pi / 2, 0, 0), verts=12))
            for n in range(5):
                a = n * 2 * math.pi / 5
                sp = prim("box", "spoke", (ax + math.cos(a) * wr * 0.32, ry + s * 0.05, wr + math.sin(a) * wr * 0.32), (wr * 0.6, 0.16, wr * 0.16), rot=(0, -a, 0))
                parts["Rim"].append(sp)
            parts["Trim"].append(prim("cyl", "disc", (ax, y, wr), (wr * 1.1, wr * 1.1, tw * 0.6), rot=(math.pi / 2, 0, 0), verts=16))

    # ---- lights, grille, bumpers, mirrors, exhaust
    fx = x0 + L
    def front_x(fz, inset=0.08):
        # x of the plan outline at lateral offset fz near the nose / tail
        for i in range(200):
            f = 1 - i / 400
            if half_w(f) >= fz:
                return x0 + f * L - inset
        return fx
    def rear_x(fz, inset=0.08):
        for i in range(200):
            f = i / 400
            if half_w(f) >= fz:
                return x0 + f * L + inset
        return x0
    hz = belt(0.97) - 0.25
    for s in (-1, 1):
        z = s * W * 0.33
        h = prim("sphere", "head", (front_x(abs(z)), z, hz), (0.35, W * 0.2, 0.32))
        parts["HeadLight"].append(h)
        tz = belt(0.03) - 0.25
        t = prim("box", "tail", (rear_x(abs(s * W * 0.32)), s * W * 0.32, tz), (0.2, W * 0.24, 0.3))
        parts["TailLight"].append(t)
        m = prim("box", "mirror", (x0 + ws * L - 0.4, s * (half_w(ws) + 0.25), belt(ws) + 0.25), (0.5, 0.55, 0.38))
        bevel(m, 0.1, 2)
        set_mat(m, M["Body"])
        parts["Body"].append(m)
    parts["Trim"].append(prim("box", "grille", (front_x(W * 0.18, 0.02), 0, clear + (belt(1) - clear) * 0.45), (0.25, W * 0.42, (belt(1) - clear) * 0.45)))
    for nm, bx in (("bumperF", front_x(W * 0.3, 0.12)), ("bumperR", rear_x(W * 0.3, 0.12))):
        bp = prim("box", nm, (bx, 0, clear + 0.35), (0.4, W * 0.78, 0.36))
        bevel(bp, 0.12, 2)
        parts["Trim"].append(bp)
    pipes = (-1, 1) if k["fam"] in ("sport", "super") else (1,)
    for s in pipes:
        parts["Chrome"].append(prim("cyl", "exhaust", (rear_x(W * 0.25, -0.15), s * W * 0.25, clear + 0.3), (0.42, 0.42, 0.7), rot=(0, math.pi / 2, 0), verts=12))
    if opt.get("spoiler"):
        sx = x0 + 0.06 * L
        top = belt(0.06)
        for s in (-1, 1):
            parts["Trim"].append(prim("box", "wingpost", (sx, s * W * 0.28, top + 0.4), (0.3, 0.2, 0.8)))
        wing = prim("box", "wing", (sx - 0.1, 0, top + 0.85), (1.4, W * 0.95, 0.16), rot=(0, 0.12, 0))
        bevel(wing, 0.05, 1)
        set_mat(wing, M["Body"])
        parts["Body"].append(wing)
    if k.get("taxi"):
        ts = prim("box", "taxisign", (x0 + (rr + rf) / 2 * L, 0, roofH + 0.3), (1.4, 2.4, 0.55))
        bevel(ts, 0.12, 2)
        parts["HeadLight"].append(ts)
    if k.get("lightbar"):
        lb = prim("box", "lightbar", (x0 + (rf - 0.05) * L, 0, roofH + 0.2), (0.8, W * 0.6, 0.35))
        parts["HeadLight"].append(lb)
    if neon:
        for s in (-1, 1):
            parts["Neon"].append(prim("box", "sideglow", (0, s * (W / 2 - 0.15), clear + 0.15), (L * 0.66, 0.12, 0.12)))
        parts["Neon"].append(prim("box", "lightstrip", (front_x(W * 0.25, 0.05), 0, belt(0.98) - 0.05), (0.1, W * 0.62, 0.08)))

    # ---- join per material -> one object each, parented to an empty named by car id
    root = bpy.data.objects.new(cid, None)
    bpy.context.collection.objects.link(root)
    for name, objs in parts.items():
        if not objs:
            continue
        for o in objs:
            if not o.data.materials:
                set_mat(o, M[name])
        ob = join(objs, name)
        if name in ("Glass",):  # greenhouse carries Glass + Body faces: split them
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.mesh.separate(type="MATERIAL")
            bpy.ops.object.mode_set(mode="OBJECT")
            for o in bpy.context.selected_objects:
                mn = o.active_material.name.split(".")[0]
                o.name = "Glass" if mn == "Glass" else "Body"
                o.parent = root
            continue
        ob.parent = root
    # merge duplicates created by the split (Body + Body.001 ...)
    groups = {}
    for o in list(root.children):
        groups.setdefault(o.name.split(".")[0], []).append(o)
    for name, objs in groups.items():
        if len(objs) > 1:
            ob = join(objs, name)
            ob.parent = root
        for o in root.children:
            if o.name.split(".")[0] == name:
                o.name = name
        # keep one material per object (Roblox MeshPart = one material)
    for o in root.children:
        if o.type == "MESH" and len(o.data.materials) > 1:
            keep = o.data.materials[0]
            for p in o.data.polygons:
                p.material_index = 0
            o.data.materials.clear()
            o.data.materials.append(keep)
    return root

def triangles(root):
    n = 0
    for o in root.children:
        if o.type == "MESH":
            n += sum(len(p.vertices) - 2 for p in o.data.polygons)
    return n

def export(roots, path):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for r in roots:
        r.select_set(True)
        for c in r.children:
            c.select_set(True)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"EMPTY", "MESH"}, apply_unit_scale=True,
                             axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", add_leaf_bones=False, bake_space_transform=True)

# ---------------------------------------------------------------- render
def render_grid(roots, path, cols, title):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 24
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 1600, int(1600 * 0.62)
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.82, 1.0, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.55
    sc.world = world
    sp = 0
    rows = math.ceil(len(roots) / cols)
    for i, r in enumerate(roots):
        cx, cy = (i % cols) * 30, -(i // cols) * 16
        r.location = (cx, cy, 0)
    bpy.ops.mesh.primitive_plane_add(size=2000, location=(0, 0, 0))
    g = bpy.context.active_object
    set_mat(g, mat("Ground", (0.45, 0.47, 0.5, 1), rough=0.8))
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
    sc.collection.objects.link(so)
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    w = cols * 30
    cam.ortho_scale = w * 0.78
    co = bpy.data.objects.new("cam", cam)
    sc.collection.objects.link(co)
    cx, cy = (cols - 1) * 15, -(rows - 1) * 8
    co.location = (cx + 50, cy - 70, 55)
    direction = Vector((cx, cy, 0)) - co.location
    co.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    sc.camera = co
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)

def main():
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    no_render = "norender" in only
    # collection
    reset()
    roots = []
    sel = [c for c in CARS if c[0] in only] or CARS
    for i, (cid, kind, color, opt) in enumerate(sel):
        r = build_car(cid, kind, color, opt, seed=i * 31 + 7)
        print(cid, "tris", triangles(r))
        roots.append(r)
    for r in roots:
        export([r], os.path.join(OUT, r.name + ".fbx"))
    export(roots, os.path.join(OUT, "cars_collection.fbx"))
    if not no_render:
        render_grid(roots, os.path.join(RENDERS, "collection.png"), 5, "Collection")
    if "notraffic" in only:
        return
    # traffic
    reset()
    MATS.clear()
    troots = []
    for i, kind in enumerate(KINDS):
        r = build_car(kind, kind, TRAFFIC_COLOR, {}, seed=100 + i, low=True)
        print(kind, "tris", triangles(r))
        troots.append(r)
    export(troots, os.path.join(OUT, "cars_traffic.fbx"))
    if not no_render:
        render_grid(troots, os.path.join(RENDERS, "traffic.png"), 4, "Traffic")

if __name__ == "__main__":
    main()
