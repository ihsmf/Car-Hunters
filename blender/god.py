"""CUE HUNTERS — the god of billiards for the grand finale, as realistic as Roblox allows: anatomy from metaballs
(muscles, face, eye sockets), beard and hair from tapered curve strands, a folded robe and toga, gold laurel and belt,
a marble cloud temple. Each piece gets UVs and a baked colour+AO texture.
    python3 blender/god.py            -> blender/export/God<Part>.glb + .png, src/shared/Meshes/God<Part>.luau
    python3 blender/god.py render     -> blender/export/god_preview.png (textured preview)
Pieces (Roblox axes, studs, model origin = feet centre on the floor, facing +X):
    GodBody (torso, robe, toga, belt, legs), GodHead (head, beard, hair, laurel), GodArmR / GodArmL (posed holding a
    cue along +X, pivot = shoulder, see SHOULDER), GodTemple (marble platform + columns, origin = floor centre)."""
import bpy, bmesh, math, os, random, sys
import mathutils
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "export")
LUAU_DIR = os.path.join(HERE, "..", "src", "shared", "Meshes")
SCALE = 3.2  # modelled at human size (~8 units tall), shipped ~26 studs tall
SHOULDER = {"GodArmR": (0.0, -1.08, 6.15), "GodArmL": (0.0, 1.08, 6.15)}  # Blender coords before SCALE
TEX = 1024
R = random.Random(11)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# ---------- materials (procedural, baked to textures later) ----------
def node_mat(name, base, rough=0.5, metal=0.0, noise=0.0, noise_scale=8.0, tint=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    lin = tuple((c / 255) ** 2.2 for c in base) + (1,)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = 0.0  # metallic surfaces bake to black; the shine comes from the texture
    if noise > 0:  # subtle colour variation (skin blotches, cloth weave, marble veins)
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = noise_scale
        tex.inputs["Detail"].default_value = 6
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = lin
        t2 = tint or tuple(min(255, c * (1 - noise)) for c in base)
        ramp.color_ramp.elements[1].color = tuple((c / 255) ** 2.2 for c in t2) + (1,)
        nt.links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = lin
    m["rgb"] = list(base)
    return m


def mats():
    return dict(
        Skin=node_mat("Skin", (232, 184, 150), 0.55, noise=0.12, noise_scale=14, tint=(205, 140, 118)),
        Robe=node_mat("Robe", (246, 242, 232), 0.7, noise=0.06, noise_scale=30),
        Gold=node_mat("Gold", (255, 196, 70), 0.25, 1.0, noise=0.15, noise_scale=20, tint=(200, 140, 40)),
        Hair=node_mat("Hair", (236, 236, 240), 0.45, noise=0.18, noise_scale=40, tint=(190, 190, 200)),
        Marble=node_mat("Marble", (240, 238, 232), 0.35, noise=0.12, noise_scale=3, tint=(200, 196, 190)),
        Iris=node_mat("Iris", (255, 220, 120), 0.2),
    )


# ---------- building helpers ----------
def metaball(name, elements, resolution=0.035):
    """elements: (type, (x, y, z), radius, (sx, sy, sz), rotation_euler_degrees, negative)"""
    mb = bpy.data.metaballs.new(name)
    mb.resolution, mb.render_resolution, mb.threshold = resolution, resolution, 0.6
    o = bpy.data.objects.new(name, mb)
    bpy.context.scene.collection.objects.link(o)
    for typ, co, r, size, rot, neg in elements:
        e = mb.elements.new(type=typ)
        e.co, e.radius, e.use_negative = co, r, neg
        if typ in ("ELLIPSOID", "CAPSULE", "CUBE"):
            e.size_x, e.size_y, e.size_z = size
        if rot:
            e.rotation = mathutils.Euler([math.radians(a) for a in rot]).to_quaternion()
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    m = bpy.context.object
    m.name = name
    return m


def E(co, r, size=(1, 1, 1), rot=None, neg=False, typ="ELLIPSOID"):
    return (typ, co, r, size, rot, neg)


def strand(points, r0, r1, mat, res=3, bevel_res=2):
    """Tapered tube along points (hair, beard, folds of the toga)."""
    cu = bpy.data.curves.new("strand", "CURVE")
    cu.dimensions, cu.bevel_depth, cu.bevel_resolution, cu.resolution_u = "3D", 1.0, bevel_res, res
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        sp.points[i].co = (p[0], p[1], p[2], 1)
        sp.points[i].radius = r0 + (r1 - r0) * i / (len(points) - 1)
    sp.use_endpoint_u, sp.order_u = True, min(4, len(points))
    o = bpy.data.objects.new("strand", cu)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def prim_finish(o, mat, smooth=True):
    o.data.materials.append(mat)
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
    return o


def join(name, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target="MESH")
    import build_models
    meshes = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    build_models.separate_coplanar(meshes)
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    return o


def assign(o, mat):
    o.data.materials.clear()
    o.data.materials.append(mat)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def decimate(o, max_tris):
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if tris > max_tris:
        d = o.modifiers.new("Dec", "DECIMATE")
        d.ratio = max_tris / tris
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=d.name)
    return o


# ---------- sculpting helpers ----------
def ellipsoid(name, c, r, seg=96, rings=64):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = Vector((c[0] + v.co.x * r[0], c[1] + v.co.y * r[1], c[2] + v.co.z * r[2]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def sculpt(o, c, r, h, center=None, mode="normal"):
    """Gaussian push of the surface: h > 0 out, h < 0 in, around point c with radii r (anisotropic)."""
    cen = Vector(center) if center else None
    c, r = Vector(c), Vector(r)
    for v in o.data.vertices:
        d = Vector(((v.co.x - c.x) / r.x, (v.co.y - c.y) / r.y, (v.co.z - c.z) / r.z)).length_squared
        if d > 9:
            continue
        w = math.exp(-d * 1.5) * h
        n = (v.co - cen).normalized() if cen is not None else v.normal
        v.co += n * w
    o.data.update()


def grooves(o, center, amount, freq, zfreq=0.0, phase=0.0, axis_up=True):
    """Hair/beard strands: radial grooves around a vertical axis through center."""
    cen = Vector(center)
    for v in o.data.vertices:
        d = v.co - cen
        a = math.atan2(d.y, d.x)
        g = math.sin(a * freq + v.co.z * zfreq + phase + 0.6 * math.sin(v.co.z * 9 + a * 3))
        v.co += Vector((d.x, d.y, 0)).normalized() * amount * g
    o.data.update()


def sweep(name, pts, radius, mat, ring=24, steps=10, flat=1.0, wave=0.0, wave_freq=8):
    """Tube along a Catmull-Rom path; radius(t) gives the profile (muscles), flat squashes the section."""
    P = [Vector(p) for p in pts]
    path = []
    for i in range(len(P) - 1):
        p0, p1, p2, p3 = P[max(0, i - 1)], P[i], P[i + 1], P[min(len(P) - 1, i + 2)]
        for k in range(steps):
            t = k / steps
            path.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    path.append(P[-1])
    bm = bmesh.new()
    rings_ = []
    up = Vector((0, 0, 1))
    for i, p in enumerate(path):
        t = i / (len(path) - 1)
        tan = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        side = tan.cross(up)
        if side.length < 1e-3:
            side = tan.cross(Vector((1, 0, 0)))
        side.normalize()
        nrm = side.cross(tan).normalized()
        r = radius(t)
        row = []
        for j in range(ring):
            a = 2 * math.pi * j / ring
            rr = r * (1 + wave * math.sin(a * wave_freq + t * 5))
            row.append(bm.verts.new(p + side * math.cos(a) * rr + nrm * math.sin(a) * rr * flat))
        rings_.append(row)
    for i in range(len(rings_) - 1):
        for j in range(ring):
            bm.faces.new((rings_[i][j], rings_[i][(j + 1) % ring], rings_[i + 1][(j + 1) % ring], rings_[i + 1][j]))
    bm.faces.new(rings_[0][::-1])
    bm.faces.new(rings_[-1])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return assign(o, mat)


# ---------- the god ----------
def body(M):
    parts = []
    torso = ellipsoid("Torso", (0, 0, 5.35), (0.55, 0.95, 1.35), 96, 72)
    C = (0, 0, 5.35)
    for v in torso.data.vertices:  # V shape: broad chest and shoulders, narrow waist, flat belly
        k = (v.co.z - 4.0) / 2.6
        v.co.y *= 0.68 + 0.42 * max(0, min(1, k))
        if v.co.x > 0 and v.co.z < 5.4:
            v.co.x *= 0.82
    torso.data.update()
    for y in (-1, 1):
        sculpt(torso, (0.5, y * 0.4, 5.85), (0.25, 0.32, 0.2), 0.12, C)  # pectorals
        sculpt(torso, (0.55, y * 0.4, 5.62), (0.25, 0.35, 0.05), -0.04, C)  # under the pecs
        sculpt(torso, (0.05, y * 0.98, 6.2), (0.35, 0.25, 0.25), 0.2, C)  # deltoid caps
        sculpt(torso, (-0.15, y * 0.45, 6.45), (0.3, 0.3, 0.15), 0.12, C)  # trapezius
        sculpt(torso, (-0.35, y * 0.7, 5.5), (0.2, 0.25, 0.5), 0.08, C)  # lats
        sculpt(torso, (0.35, y * 0.62, 4.9), (0.2, 0.15, 0.35), 0.05, C)  # obliques
        for z in (4.65, 4.95, 5.25):
            sculpt(torso, (0.58, y * 0.15, z), (0.12, 0.1, 0.1), 0.045, C)  # abs
    sculpt(torso, (0.6, 0, 5.0), (0.05, 0.03, 0.55), -0.035, C)  # linea alba
    sculpt(torso, (0, 0, 4.2), (0.7, 0.4, 0.4), -0.12, C)  # waist taper
    torso_n = assign(torso, M["Skin"])
    parts.append(torso_n)
    parts.append(sweep("Neck", [(0.02, 0, 6.35), (0.06, 0, 6.85), (0.08, 0, 7.05)], lambda t: 0.33 - 0.04 * t, M["Skin"], 20, 6))
    # robe: flowing from the hips to the floor, folds deepening towards the hem
    bm = bmesh.new()
    rings, segs = 30, 80
    verts = []
    for i in range(rings + 1):
        z = 4.5 - 4.5 * i / rings
        k = i / rings
        row = []
        for j in range(segs):
            a = 2 * math.pi * j / segs
            r = 0.86 + 0.8 * k ** 1.25
            r += (0.04 + 0.16 * k) * math.sin(9 * a + 1.7 * math.sin(3 * a) + k * 2)
            r += 0.025 * math.sin(23 * a + i * 0.7)
            row.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r * 1.05, max(0.02, z))))
        verts.append(row)
    for i in range(rings):
        for j in range(segs):
            bm.faces.new((verts[i][j], verts[i][(j + 1) % segs], verts[i + 1][(j + 1) % segs], verts[i + 1][j]))
    bm.faces.new(verts[-1][::-1])
    me = bpy.data.meshes.new("Robe")
    bm.to_mesh(me)
    robe = bpy.data.objects.new("Robe", me)
    bpy.context.scene.collection.objects.link(robe)
    robe.modifiers.new("Thick", "SOLIDIFY").thickness = 0.04
    parts.append(assign(robe, M["Robe"]))
    # toga: a wide folded sash from the left shoulder across the body + a drape down the back
    parts.append(sweep("Toga", [(-0.5, 0.95, 6.4), (0.3, 0.8, 6.25), (0.72, 0.25, 5.55), (0.72, -0.35, 4.85), (0.4, -0.85, 4.45), (-0.2, -1.0, 4.3)],
                       lambda t: 0.32, M["Robe"], 40, 8, flat=0.28, wave=0.12, wave_freq=7))
    parts.append(sweep("Drape", [(-0.45, 0.9, 6.35), (-0.8, 0.75, 5.4), (-1.1, 0.6, 3.6), (-1.35, 0.55, 1.6), (-1.5, 0.5, 0.15)],
                       lambda t: 0.35 + 0.25 * t, M["Robe"], 40, 8, flat=0.3, wave=0.18, wave_freq=6))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.9, minor_radius=0.07, major_segments=64, minor_segments=8, location=(0, 0, 4.45))
    parts.append(prim_finish(bpy.context.object, M["Gold"]))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.15, segments=16, ring_count=10, location=(0.9, 0, 4.45))
    parts.append(prim_finish(bpy.context.object, M["Gold"]))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.11, segments=16, ring_count=10, location=(0.42, 0.75, 6.32))
    parts.append(prim_finish(bpy.context.object, M["Gold"]))  # toga brooch
    return join("GodBody", parts)


def head(M):
    parts = []
    HC = (0.02, 0, 7.45)
    h = ellipsoid("Head", HC, (0.5, 0.4, 0.56), 128, 96)
    for v in h.data.vertices:  # jaw narrows, chin forward, back of the skull rounder
        if v.co.z < 7.35:
            k = (7.35 - v.co.z) / 0.5
            v.co.y *= 1 - 0.28 * k
            v.co.x += 0.06 * k * max(0, v.co.x)
        if v.co.x < -0.1 and v.co.z > 7.2:
            v.co.x -= 0.05
    h.data.update()
    S = lambda c, r, hh: sculpt(h, c, r, hh, HC)
    S((0.48, 0, 7.66), (0.08, 0.3, 0.05), 0.05)  # brow ridge
    for y in (-1, 1):
        S((0.46, y * 0.17, 7.53), (0.07, 0.08, 0.055), -0.07)  # eye sockets
        S((0.42, y * 0.26, 7.44), (0.08, 0.07, 0.05), 0.035)  # cheekbones
        S((0.4, y * 0.24, 7.25), (0.08, 0.07, 0.08), -0.025)  # hollow cheeks
        S((0.5, y * 0.06, 7.31), (0.04, 0.035, 0.03), 0.04)  # nostril wings
        S((0.3, y * 0.33, 7.66), (0.08, 0.06, 0.08), -0.02)  # temples
    S((0.52, 0, 7.47), (0.04, 0.035, 0.12), 0.13)  # nose bridge
    S((0.56, 0, 7.35), (0.055, 0.05, 0.055), 0.2)  # nose tip
    S((0.5, 0, 7.6), (0.03, 0.06, 0.03), -0.025)  # between the brows
    S((0.53, 0, 7.2), (0.03, 0.09, 0.02), 0.025)  # upper lip
    S((0.52, 0, 7.13), (0.03, 0.08, 0.02), 0.03)  # lower lip
    S((0.48, 0, 7.0), (0.06, 0.09, 0.06), 0.04)  # chin
    parts.append(assign(h, M["Skin"]))
    for y in (-1, 1):
        e = ellipsoid("Ear", (0.0, y * 0.38, 7.43), (0.07, 0.03, 0.12), 24, 16)
        sculpt(e, (0.0, y * 0.41, 7.43), (0.04, 0.02, 0.07), -0.015)
        parts.append(assign(e, M["Skin"]))
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.055, segments=20, ring_count=12, location=(0.43, y * 0.17, 7.53))
        parts.append(prim_finish(bpy.context.object, M["Robe"]))  # eyeball
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.028, segments=16, ring_count=10, location=(0.475, y * 0.17, 7.53))
        parts.append(prim_finish(bpy.context.object, M["Iris"]))
        parts.append(sweep("Lid", [(0.46, y * 0.11, 7.555), (0.49, y * 0.17, 7.575), (0.46, y * 0.23, 7.555)], lambda t: 0.022, M["Skin"], 10, 5))
        parts.append(sweep("Brow", [(0.5, y * 0.07, 7.66), (0.52, y * 0.17, 7.69), (0.48, y * 0.28, 7.65)], lambda t: 0.03 - 0.012 * t, M["Hair"], 10, 5, flat=0.6))
    # beard: a full volume with flowing grooves, longer at the front, plus curls on its surface
    bd = ellipsoid("Beard", (0.3, 0, 6.78), (0.3, 0.38, 0.62), 96, 64)
    for v in bd.data.vertices:
        if v.co.z > 7.15:  # follow the jaw line, keep the lips free
            v.co.z = 7.15 + (v.co.z - 7.15) * 0.3
        if v.co.x > 0.35 and v.co.z > 7.08:
            v.co.x -= 0.1
        if v.co.z < 6.5:
            v.co.x += (6.5 - v.co.z) * 0.25  # beard tip juts forward
            v.co.y *= 1 - (6.5 - v.co.z) * 0.9
    bd.data.update()
    grooves(bd, (0.3, 0, 6.8), 0.022, 34, 3.0)
    parts.append(assign(bd, M["Hair"]))
    for k in range(26):  # thick curly clumps over the beard
        a = R.uniform(-1.1, 1.1)
        z = R.uniform(6.3, 7.0)
        rr = 0.33 - (7.0 - z) * 0.12
        c = (0.3 + math.cos(a) * rr + max(0, 6.5 - z) * 0.25, math.sin(a) * rr * 0.9, z)
        cl = ellipsoid("Curl", c, (0.06, 0.07, 0.11), 16, 10)
        grooves(cl, c, 0.012, 6, 8.0, k)
        parts.append(assign(cl, M["Hair"]))
    for y in (-1, 1):  # moustache
        parts.append(sweep("Moustache", [(0.55, y * 0.01, 7.25), (0.56, y * 0.13, 7.22), (0.5, y * 0.24, 7.08), (0.44, y * 0.27, 6.95)], lambda t: 0.045 - 0.035 * t, M["Hair"], 14, 8, wave=0.2, wave_freq=6))
    # hair: a cap with grooves flowing back, and a long mane down to the shoulders
    cap = ellipsoid("Hair", (-0.02, 0, 7.55), (0.52, 0.42, 0.56), 96, 64)
    for v in cap.data.vertices:
        if v.co.x > 0.05 and v.co.z < 7.95:  # receding hairline: the forehead stays free, hair swept back
            v.co.x -= (v.co.x - 0.0) * 0.75 * min(1, (7.95 - v.co.z) / 0.25)
        if v.co.z < 7.25 and v.co.x > -0.15:
            v.co.z = 7.25
    cap.data.update()
    grooves(cap, (-0.02, 0, 7.55), 0.018, 40, 2.0, 1.0)
    parts.append(assign(cap, M["Hair"]))
    mane = sweep("Mane", [(-0.3, 0, 7.6), (-0.48, 0, 7.1), (-0.5, 0, 6.6), (-0.45, 0, 6.15)], lambda t: 0.34 + 0.14 * t, M["Hair"], 48, 8, flat=1.15, wave=0.07, wave_freq=18)
    parts.append(mane)
    for k in range(10):  # locks over the shoulders
        y = (1 if k % 2 else -1) * R.uniform(0.25, 0.4)
        parts.append(sweep("Lock", [(-0.05, y, 7.3), (-0.15, y * 1.2, 6.9), (-0.1, y * 1.45, 6.5), (0.0, y * 1.6, 6.2)], lambda t: 0.06 - 0.035 * t, M["Hair"], 10, 6, wave=0.2, wave_freq=4))
    # laurel crown
    bpy.ops.mesh.primitive_torus_add(major_radius=0.5, minor_radius=0.025, major_segments=48, minor_segments=6, location=(-0.04, 0, 7.84), rotation=(0, math.radians(-14), 0))
    parts.append(prim_finish(bpy.context.object, M["Gold"]))
    for k in range(28):
        a = k * 2 * math.pi / 28
        if math.cos(a) < -0.85:
            continue
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.08, segments=10, ring_count=6, location=(-0.04 + math.cos(a) * 0.51, math.sin(a) * 0.51, 7.86 + 0.07 * math.cos(a) + (0.03 if k % 2 else -0.03)))
        leaf = bpy.context.object
        leaf.scale = (0.4, 1.0, 0.22)
        leaf.rotation_euler = (0.5 * (1 if k % 2 else -1), 0, a + math.pi / 2)
        parts.append(prim_finish(leaf, M["Gold"]))
    return join("GodHead", parts)


HANDS = {"GodArmR": (0.62, -0.32, 5.0), "GodArmL": (1.75, 0.1, 5.32)}  # both hands on the cue line (model units)


def arm(M, side):
    """side = +1 (left, front hand) / -1 (right, back hand). Muscular sweep shoulder -> elbow -> wrist, a hand
    closed around the cue."""
    name = "GodArmL" if side > 0 else "GodArmR"
    sh = Vector(SHOULDER[name])
    hand = Vector(HANDS[name])
    elbow = Vector((0.85, 0.85, 5.62)) if side > 0 else Vector((-0.22, -1.2, 5.25))
    wrist = hand - (hand - elbow).normalized() * 0.22
    def prof(t):  # deltoid -> biceps -> elbow -> forearm -> wrist
        return 0.3 + 0.05 * math.exp(-((t - 0.25) / 0.12) ** 2) - 0.07 * math.exp(-((t - 0.5) / 0.05) ** 2) + 0.03 * math.exp(-((t - 0.62) / 0.08) ** 2) - 0.14 * t
    parts = [sweep("Arm", [sh + Vector((0, 0, 0.05)), sh.lerp(elbow, 0.5), elbow, elbow.lerp(wrist, 0.5), wrist], prof, M["Skin"], 32, 12, flat=0.92)]
    parts.append(assign(ellipsoid("Shoulder", tuple(sh + Vector((0, 0, 0.02))), (0.36, 0.38, 0.36), 32, 20), M["Skin"]))  # rounded deltoid closes the arm
    cue_dir = (Vector(HANDS["GodArmL"]) - Vector(HANDS["GodArmR"])).normalized()
    palm = ellipsoid("Palm", tuple(hand), (0.14, 0.11, 0.16), 24, 16)
    parts.append(assign(palm, M["Skin"]))
    up = Vector((0, 0, 1))
    side_v = cue_dir.cross(up).normalized()
    for f in range(4):  # fingers wrapped around the cue
        base = hand + cue_dir * (-0.09 + f * 0.065) + up * 0.08
        pts = [base, base + side_v * side * 0.1 + up * 0.02, base + side_v * side * 0.12 - up * 0.1, base + side_v * side * 0.04 - up * 0.17]
        parts.append(sweep("Finger", pts, lambda t: 0.035 - 0.008 * t, M["Skin"], 10, 4))
    thumb = hand + up * 0.1 - side_v * side * 0.06
    parts.append(sweep("Thumb", [thumb, thumb + cue_dir * 0.1 + up * 0.03, thumb + cue_dir * 0.18 - side_v * side * 0.04], lambda t: 0.04 - 0.01 * t, M["Skin"], 10, 4))
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.2, depth=0.3, location=tuple(elbow.lerp(wrist, 0.75)))
    cuff = bpy.context.object
    cuff.rotation_euler = Vector((0, 0, 1)).rotation_difference(wrist - elbow).to_euler()
    parts.append(prim_finish(cuff, M["Gold"]))  # golden bracer
    return join(name, parts)


def temple(M):
    parts = []
    for k, (r, h) in enumerate(((7.5, 0.35), (6.8, 0.35), (6.1, 0.35))):  # three marble steps
        bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=r, depth=h, location=(0, 0, h / 2 + k * h))
        parts.append(prim_finish(bpy.context.object, M["Marble"], smooth=False))
    for k in range(8):  # fluted columns with capitals
        a = k * 2 * math.pi / 8 + math.pi / 8
        if abs(math.cos(a)) > 0.9 and math.cos(a) > 0:
            continue  # keep the front open towards the cue ball
        x, y = math.cos(a) * 5.6, math.sin(a) * 5.6
        bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.42, depth=7.2, location=(x, y, 1.05 + 3.6))
        col = bpy.context.object
        for v in col.data.vertices:  # flutes
            ang = math.atan2(v.co.y, v.co.x)
            f = 1 - 0.06 * (0.5 + 0.5 * math.cos(ang * 20))
            v.co.x *= f
            v.co.y *= f
        parts.append(prim_finish(col, M["Marble"]))
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, 8.45))
        cap = bpy.context.object
        cap.scale = (1.15, 1.15, 0.35)
        parts.append(prim_finish(cap, M["Marble"], smooth=False))
        bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.55, depth=0.35, location=(x, y, 1.2))
        parts.append(prim_finish(bpy.context.object, M["Marble"], smooth=False))
    bpy.ops.mesh.primitive_torus_add(major_radius=5.6, minor_radius=0.35, major_segments=64, minor_segments=8, location=(0, 0, 8.85))
    parts.append(prim_finish(bpy.context.object, M["Gold"]))  # golden ring architrave
    return join("GodTemple", parts)


# ---------- baking + export ----------
def bake(o, size=TEX):
    """Smart UVs, then bake diffuse colour x ambient occlusion into one texture; the object gets that texture."""
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 24
    sc.cycles.device = "CPU"
    imgs = {}
    for kind in ("DIFFUSE", "AO"):
        img = bpy.data.images.new(o.name + kind, size, size)
        imgs[kind] = img
        for m in o.data.materials:
            nt = m.node_tree
            for n in [n for n in nt.nodes if n.name == "BakeTarget"]:
                nt.nodes.remove(n)
            n = nt.nodes.new("ShaderNodeTexImage")
            n.name, n.image = "BakeTarget", img
            nt.nodes.active = n
        if kind == "DIFFUSE":
            sc.render.bake.use_pass_direct, sc.render.bake.use_pass_indirect, sc.render.bake.use_pass_color = False, False, True
        bpy.ops.object.bake(type=kind, margin=6)
    import numpy as np
    d = np.array(imgs["DIFFUSE"].pixels[:]).reshape(-1, 4)
    a = np.array(imgs["AO"].pixels[:]).reshape(-1, 4)
    ao = 0.35 + 0.65 * a[:, :1]
    out = d.copy()
    out[:, :3] = d[:, :3] * ao
    final = bpy.data.images.new(o.name + "Tex", size, size)
    final.pixels[:] = out.ravel()
    final.filepath_raw = os.path.join(OUT, o.name + ".png")
    final.file_format = "PNG"
    final.save()
    # one material showing the baked texture (for the GLB / previews)
    m = bpy.data.materials.new(o.name + "Baked")
    m.use_nodes = True
    t = m.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = final
    m.node_tree.links.new(t.outputs["Color"], m.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
    keep = [mm for mm in o.data.materials]
    o["palette"] = [(mm.name, list(mm["rgb"])) for mm in keep]
    o["matidx"] = [p.material_index for p in o.data.polygons]
    o.data.materials.clear()
    o.data.materials.append(m)
    return final


def luau_mesh(o, palette, matidx):
    """Vertex-colour fallback (EditableMesh path): same layout as build_models.luau_mesh."""
    me = o.data
    verts = [(v.co.x, v.co.z, -v.co.y) for v in me.vertices]
    lo = [min(v[i] for v in verts) for i in range(3)]
    hi = [max(v[i] for v in verts) for i in range(3)]
    ctr = [(a + b) / 2 for a, b in zip(lo, hi)]
    f = lambda x: f"{x:.3f}".rstrip("0").rstrip(".") if abs(x) >= 0.0005 else "0"
    tris, cols = [], []
    for p, mi in zip(me.polygons, matidx):
        tris.extend(i + 1 for i in p.vertices)
        cols.append(mi + 1)
    pal = ", ".join(f'{{ "{n}", Color3.fromRGB({c[0]}, {c[1]}, {c[2]}) }}' for n, c in palette)
    flat = ",".join(f(v[i] - ctr[i]) for v in verts for i in range(3))
    return (f'return {{\n\tcenter = Vector3.new({f(ctr[0])}, {f(ctr[1])}, {f(ctr[2])}),\n'
            f'\tsize = Vector3.new({f(hi[0] - lo[0])}, {f(hi[1] - lo[1])}, {f(hi[2] - lo[2])}),\n'
            f'\tpalette = {{ {pal} }},\n\tverts = {{ {flat} }},\n'
            f'\ttris = {{ {",".join(map(str, tris))} }},\n\tcolors = {{ {",".join(map(str, cols))} }},\n}}\n'), lo, hi


def finish(o, max_tris, pivot=(0, 0, 0)):
    """Scale to studs, move the pivot to the origin, triangulate, decimate, bake, export GLB + PNG + luau."""
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    o.location = (-pivot[0] * SCALE, -pivot[1] * SCALE, -pivot[2] * SCALE)
    o.scale = (SCALE, SCALE, SCALE)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    tri = o.modifiers.new("Tri", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=tri.name)
    decimate(o, max_tris)
    tri = o.modifiers.new("Tri", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=tri.name)
    bake(o)
    text, lo, hi = luau_mesh(o, o["palette"], o["matidx"])
    with open(os.path.join(LUAU_DIR, o.name + ".luau"), "w", encoding="utf-8") as fh:
        fh.write("-- AUTO-GENERATED by blender/god.py — do not edit by hand. Textured: blender/export/" + o.name + ".png\n"
                 "-- Roblox axes, studs; vertices centred on bbox, `center` = offset from the model origin.\n" + text)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    o.scale = (-1, 1, 1)  # Roblox's glTF import mirrors X: pre-mirror so the god faces the right way in game
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.flip_normals()
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, o.name + ".glb"), use_selection=True, export_format="GLB",
                              export_yup=True, export_texcoords=True, export_normals=True, export_materials="NONE")
    print(f"{o.name}: {len(o.data.polygons)} triangles")
    return o


def build(only=None):
    jobs = [("GodBody", body, 19000, (0, 0, 0)), ("GodHead", head, 19000, (0, 0, 0)),
            ("GodArmR", lambda M: arm(M, -1), 9000, SHOULDER["GodArmR"]), ("GodArmL", lambda M: arm(M, 1), 9000, SHOULDER["GodArmL"]),
            ("GodTemple", temple, 12000, (0, 0, 0))]
    for name, fn, budget, pivot in jobs:
        if only and name not in only:
            continue
        reset()
        M = mats()
        o = fn(M)
        finish(o, budget, pivot)


def render():
    reset()
    sc = bpy.context.scene
    for name in ("GodTemple", "GodBody", "GodHead", "GodArmR", "GodArmL"):
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, name + ".glb"))
        o = bpy.context.selected_objects[0]
        img = bpy.data.images.load(os.path.join(OUT, name + ".png"))
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = img
        m.node_tree.links.new(t.outputs["Color"], m.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
        o.data.materials.clear()
        o.data.materials.append(m)
        if name in SHOULDER:  # arms were exported around the shoulder pivot
            p = SHOULDER[name]
            o.location = (o.location.x + p[0] * SCALE, o.location.y + p[1] * SCALE, o.location.z + p[2] * SCALE)
        if name != "GodTemple":
            o.location.z += 1.05 * SCALE  # standing on the top step
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.6, 0.75, 1)
    sun = bpy.data.objects.new("s", bpy.data.lights.new("s", "SUN")); sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), 0, math.radians(-30)); sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera = cam
    view = sys.argv[sys.argv.index("render") + 1] if len(sys.argv) > sys.argv.index("render") + 1 else "full"
    if view == "face":
        cam.location = (9.0, 3.0, 28.0); cam.data.lens = 55
        tgt = Vector((0.8, 0, 26.6))
    else:
        cam.location = (30, 16, 18); cam.data.lens = 35
        tgt = Vector((2, 0, 13))
    cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.engine = "CYCLES"; sc.cycles.samples = 32
    sc.render.resolution_x, sc.render.resolution_y = 1200, 1200
    sc.view_settings.view_transform = "Standard"
    sc.render.filepath = os.path.join(OUT, f"god_{view}.png")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    if "render" in sys.argv:
        render()
    else:
        build(set(a for a in sys.argv[1:] if a.startswith("God")) or None)
