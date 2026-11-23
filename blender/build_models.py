"""Billiard Hunters — 3D models.
    python3 blender/build_models.py        (or: blender -b -P blender/build_models.py)
Builds PoolTable, Cue, Ball, Dumbbell, Fence and writes:
  * blender/export/<Name>.fbx           — for manual import in Studio (optional)
  * src/shared/Meshes.luau              — triangle data; the game turns it into MeshParts at runtime
  * blender/export/models.png           — preview render
Units are studs. Modelled in Roblox axes (X right, Y up, Z back) and converted to Blender axes."""
import bpy, bmesh, math, os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "export")
LUAU_DIR = os.path.join(HERE, "..", "src", "shared", "Meshes")  # one ModuleScript per model
os.makedirs(OUT, exist_ok=True)


def rb(x, y, z):  # Roblox -> Blender
    return (x, -z, y)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgb, metal=0.0, rough=0.45):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*[(c / 255) ** 2.2 for c in rgb], 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    m["rgb"] = list(rgb)
    return m


def finish(o, m, bevel=0.0, segs=2):
    o.data.materials.append(m)
    if bevel:
        mod = o.modifiers.new("Bevel", "BEVEL")
        mod.width, mod.segments, mod.limit_method = bevel, segs, "ANGLE"
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def box(size, c, m, bevel=0.1):
    bpy.ops.mesh.primitive_cube_add(location=rb(*c))
    o = bpy.context.object
    o.scale = (size[0] / 2, size[2] / 2, size[1] / 2)
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m, bevel)


def cyl(d, h, c, m, axis="Y", d2=None, verts=24, bevel=0.03):
    rot = {"Y": (0, 0, 0), "X": (0, math.pi / 2, 0), "Z": (math.pi / 2, 0, 0)}[axis]
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=d / 2, radius2=(d2 or d) / 2, depth=h, location=rb(*c), rotation=rot)
    return finish(bpy.context.object, m, bevel, 2)


def sphere(d, c, m, seg=16, rings=10, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=d / 2, segments=seg, ring_count=rings, location=rb(*c))
    o = bpy.context.object
    o.scale = (scale[0], scale[2], scale[1])
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m)


def torus(d, t, c, m, axis="Y"):
    rot = {"Y": (0, 0, 0), "X": (0, math.pi / 2, 0)}[axis]
    bpy.ops.mesh.primitive_torus_add(major_radius=d / 2, minor_radius=t / 2, major_segments=16, minor_segments=6, location=rb(*c), rotation=rot)
    return finish(bpy.context.object, m)


# ---------- Palette (cartoon colours, sRGB) ----------
P = dict(
    Wood=(124, 58, 24), WoodDark=(82, 36, 14), Felt=(22, 150, 70), Cushion=(16, 118, 54), Gold=(255, 196, 60),
    Pocket=(18, 14, 20), Pearl=(255, 250, 235), White=(255, 255, 255), Ebony=(34, 20, 14), Wrap=(200, 30, 50),
    Shaft=(236, 196, 132), Tip=(40, 110, 240), Chrome=(215, 220, 232), Plate=(240, 60, 70), Rubber=(44, 44, 58),
    Rail=(255, 250, 238), Cap=(255, 120, 150), Body=(255, 210, 40),
)
BALL_COLORS = [(255, 210, 40), (40, 90, 230), (235, 50, 50), (140, 50, 200), (255, 130, 20), (30, 160, 70), (140, 30, 40), (20, 20, 24)]


def ball_mesh(d, c, body, white, striped, tilt):
    """Pool ball: stripes = coloured band on white, solids = coloured with a white number spot."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=d / 2)
    me = bpy.data.meshes.new("ball"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("ball", me); bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(body); o.data.materials.append(white)
    for f in me.polygons:  # Blender Z is the ball's axis here
        z = f.center.z / (d / 2)
        f.material_index = int(abs(z) > 0.42) if striped else int(z > 0.8)
        f.use_smooth = True
    o.rotation_euler = tilt
    o.location = rb(*c)
    return o


def pool_table():
    """Real-proportion table at player scale: felt top at y=3, playing field 6 x 12, 15-ball rack + cue ball."""
    M = {k: mat(k, v, 1 if k in ("Brass", "Chrome") else 0, 0.3 if k in ("Brass", "Pearl") else 0.55) for k, v in dict(
        Wood=(96, 48, 22), WoodDark=(62, 30, 14), Felt=(18, 120, 72), Cushion=(14, 100, 60), Brass=(225, 175, 80),
        Pocket=(16, 12, 12), Leather=(60, 36, 22), Pearl=(250, 246, 232)).items()}
    W, L, top, cush, rail = 6.0, 12.0, 3.0, 0.3, 0.62
    box((W, 0.16, L), (0, top - 0.08, 0), M["Felt"], 0.01)
    box((W + 0.3, 0.3, L + 0.3), (0, top - 0.3, 0), M["WoodDark"], 0)
    gap = 0.34  # pocket mouths: corners and the middle of the long sides
    for s in (-1, 1):  # cushions (felt-covered, slightly lighter) and the wooden rails around them
        for k in (-1, 1):
            z0, z1 = k * gap, k * (L / 2 - gap)
            box((cush, 0.2, abs(z1 - z0)), (s * (W / 2 - cush / 2 + 0.02), top + 0.1, (z0 + z1) / 2), M["Cushion"], 0.08)
        box((W - 2 * gap, 0.2, cush), (0, top + 0.1, s * (L / 2 - cush / 2 + 0.02)), M["Cushion"], 0.08)
        box((rail, 0.34, L + 2 * rail), (s * (W / 2 + rail / 2), top + 0.03, 0), M["Wood"], 0.12)
        box((W, 0.34, rail), (0, top + 0.03, s * (L / 2 + rail / 2)), M["Wood"], 0.12)
        for k in (-3, -2, -1, 1, 2, 3):  # diamond sights
            sphere(0.12, (s * (W / 2 + rail / 2), top + 0.2, k * L / 8), M["Pearl"], 8, 4, (1, 0.35, 1.6))
        for k in (-1, 0, 1):
            sphere(0.12, (k * W / 4, top + 0.2, s * (L / 2 + rail / 2)), M["Pearl"], 8, 4, (1.6, 0.35, 1))
        for t in (-1, 0, 1):  # pockets: black hole, leather cup below, brass cap on the rail
            px, pz = s * (W / 2 + 0.05), t * (L / 2 + 0.05)
            cyl(0.62, 0.36, (px, top + 0.05, pz), M["Pocket"], verts=16, bevel=0)
            cyl(0.7, 0.5, (px, top - 0.4, pz), M["Leather"], d2=0.56, verts=16)
            torus(0.78, 0.1, (px, top + 0.21, pz), M["Brass"])
    box((W + 2 * rail + 0.1, 0.62, L + 2 * rail + 0.1), (0, top - 0.5, 0), M["Wood"], 0.14)  # apron
    box((W + 2 * rail + 0.16, 0.08, L + 2 * rail + 0.16), (0, top - 0.8, 0), M["Brass"], 0.02)
    for s in (-1, 1):
        for t in (-1, 0, 1):  # six turned legs
            x, z = s * (W / 2 + 0.05), t * (L / 2 - 0.4) if t else 0
            cyl(0.7, 0.25, (x, 0.12, z), M["Brass"], verts=16)
            cyl(0.5, 1.4, (x, 0.95, z), M["WoodDark"], d2=0.72, verts=16)
            sphere(0.8, (x, 1.75, z), M["WoodDark"], 16, 8)
            cyl(0.7, 0.55, (x, 2.2, z), M["WoodDark"], d2=0.55, verts=16)


def prize_ball():
    """Prize ball, diameter 1: body, equator band (stripe balls), white number spots front/back with a coloured trim.
    Palette Body / Band / Spot / Trim is recoloured per ball and variant."""
    M = [mat(n, c, 0, 0.12) for n, c in (("Body", (230, 60, 60)), ("Band", (230, 60, 60)), ("Spot", (250, 248, 240)), ("Trim", (40, 40, 60)))]
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=20, radius=0.5)
    me = bpy.data.meshes.new("prize"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("prize", me); bpy.context.scene.collection.objects.link(o)
    for m in M:
        o.data.materials.append(m)
    for f in me.polygons:  # Blender Z = Roblox up; Blender Y = Roblox -Z (front/back)
        c = f.center
        f.material_index = 2 if abs(c.y) > 0.44 else 3 if abs(c.y) > 0.4 else 1 if abs(c.z) < 0.22 else 0
        f.use_smooth = True


def cue():
    """Two-piece pool cue, 9.2 long: rubber bumper, butt sleeve, wrap, forearm with inlaid points, steel joint,
    tapered maple shaft, white ferrule, blue tip. Palette slots Shaft/Butt/Inlay/Wrap/Joint are recoloured per tier."""
    names = ["Bumper", "Butt", "Inlay", "Wrap", "Joint", "Shaft", "Ferrule", "Tip"]
    rgb = dict(Bumper=(20, 20, 22), Butt=(110, 64, 32), Inlay=(240, 225, 200), Wrap=(60, 50, 45), Joint=(190, 190, 195),
               Shaft=(222, 184, 128), Ferrule=(250, 250, 245), Tip=(40, 90, 200))
    M = [mat(n, rgb[n], 1 if n == "Joint" else 0, 0.25 if n == "Joint" else 0.4) for n in names]
    # (y, radius, part) rings from the butt end (-4.6) to the tip (+4.6)
    prof = [(-4.6, 0, "Bumper"), (-4.6, 0.17, "Bumper"), (-4.54, 0.2, "Bumper"), (-4.5, 0.205, "Butt"), (-4.2, 0.205, "Butt"),
            (-4.17, 0.205, "Inlay"), (-4.12, 0.2, "Wrap")] + [(-4.12 + 1.5 * t / 6, 0.2 - 0.008 * t / 6, "Wrap") for t in range(1, 7)] + \
           [(-2.6, 0.192, "Inlay"), (-2.55, 0.19, "Points")] + [(-2.55 + 1.95 * t / 32, 0.19 - 0.03 * t / 32, "Points") for t in range(1, 33)] + \
           [(-0.58, 0.162, "Inlay"), (-0.55, 0.165, "Joint"), (-0.35, 0.16, "Joint"), (-0.33, 0.15, "Shaft")] + \
           [(-0.33 + 4.68 * t / 10, 0.15 - 0.066 * (t / 10) ** 0.8, "Shaft") for t in range(1, 11)] + \
           [(4.37, 0.084, "Ferrule"), (4.52, 0.084, "Ferrule"), (4.53, 0.083, "Tip"), (4.58, 0.07, "Tip"), (4.6, 0, "Tip")]
    segs = 40
    bm = bmesh.new()
    rings = []
    for y, r, _ in prof:
        rings.append([bm.verts.new(rb(math.cos(2 * math.pi * k / segs) * r, y, math.sin(2 * math.pi * k / segs) * r)) for k in range(segs)])
    faces = []
    for i in range(len(prof) - 1):
        part = prof[i + 1][2]
        for k in range(segs):
            a, b = rings[i], rings[i + 1]
            f = bm.faces.new((a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]))
            faces.append((f, names.index("Butt" if part == "Points" else part)))
    for p4 in range(4):  # four inlaid spear points on the forearm, narrowing towards the joint
        rows = []
        for j in range(17):
            t = j / 16
            y, r = -2.5 + 1.8 * t, 0.1915 - 0.03 * (0.05 + 0.9 * t) + 0.003
            half = 0.36 * (1 - t) ** 1.2 + 0.004
            a0 = p4 * math.pi / 2
            rows.append([bm.verts.new(rb(math.cos(a0 + h) * r, y, math.sin(a0 + h) * r)) for h in (-half, 0, half)])
        for j in range(16):
            for q in range(2):
                faces.append((bm.faces.new((rows[j][q], rows[j][q + 1], rows[j + 1][q + 1], rows[j + 1][q])), names.index("Inlay")))
    me = bpy.data.meshes.new("cue")
    bm.to_mesh(me)
    for (f, idx), p in zip(faces, me.polygons):
        p.material_index = idx
        p.use_smooth = True
    bm.free()
    o = bpy.data.objects.new("cue", me); bpy.context.scene.collection.objects.link(o)
    for m in M:
        o.data.materials.append(m)


def ball():
    body, white = mat("Body", P["Body"], rough=0.1), mat("White", P["White"], rough=0.1)
    sphere(1, (0, 0, 0), body, 24, 14)
    for z in (-0.47, 0.47):  # white number spots
        cyl(0.5, 0.08, (0, 0, z), white, "Z", verts=20, bevel=0)
        sphere(0.32, (0, 0, z * 1.04), white, 12, 6, (1, 1, 0.25))


def dumbbell():
    """Plate-loaded dumbbell, 5.4 long, handle on the X axis: knurled chrome handle, collars, three plates per side
    (palette slot Plate is recoloured per level band)."""
    M = {k: mat(k, v, 1 if k == "Chrome" else 0, 0.25) for k, v in dict(Chrome=(205, 210, 220), Plate=(70, 70, 78),
                                                                       Rubber=(30, 30, 34), Grip=(120, 124, 132)).items()}
    cyl(0.34, 1.7, (0, 0, 0), M["Grip"], "X", verts=16)
    cyl(0.3, 5.2, (0, 0, 0), M["Chrome"], "X", verts=16)
    for s in (-1, 1):
        cyl(0.62, 0.22, (s * 0.98, 0, 0), M["Chrome"], "X", verts=20, bevel=0.04)
        for k, (dd, w) in enumerate(((2.3, 0.36), (1.9, 0.3), (1.5, 0.26))):
            x = s * (1.3 + sum(ww for _, ww in ((2.3, 0.36), (1.9, 0.3), (1.5, 0.26))[:k]) + w / 2)
            cyl(dd, w, (x, 0, 0), M["Plate"], "X", verts=28, bevel=0.06)
            cyl(dd * 0.42, w + 0.04, (x, 0, 0), M["Rubber"], "X", verts=20, bevel=0.02)
        cyl(0.55, 0.3, (s * 2.38, 0, 0), M["Chrome"], "X", verts=20, bevel=0.06)


def ring():
    """Thin torus, diameter 4, lies flat (scaled per use)."""
    bpy.ops.mesh.primitive_torus_add(major_radius=1.92, minor_radius=0.08, major_segments=48, minor_segments=6)
    finish(bpy.context.object, mat("Ring", (255, 255, 255)))


def gym_set():
    """Weight bench + 2-tier dumbbell rack with 6 small dumbbells (static decor of the gym zone)."""
    M = {k: mat(k, v, 1 if k == "Steel" else 0, 0.3) for k, v in dict(Steel=(70, 74, 84), Pad=(32, 32, 38), Seam=(200, 40, 50),
                                                                     Chrome=(205, 210, 220), Iron=(48, 48, 54)).items()}
    # bench along Z at x = 0
    box((1.5, 0.35, 4.6), (0, 1.75, 0), M["Pad"], 0.15)
    box((1.54, 0.05, 4.64), (0, 1.58, 0), M["Seam"], 0)
    box((0.5, 1.4, 0.5), (0, 0.85, 1.6), M["Steel"], 0.05)
    box((0.5, 1.4, 0.5), (0, 0.85, -1.6), M["Steel"], 0.05)
    for z in (1.6, -1.6):
        box((2.2, 0.25, 0.6), (0, 0.13, z), M["Steel"], 0.06)
    # rack at x = -4.5, along Z
    for z in (-2.3, 2.3):  # A-frame ends
        for sx in (-1, 1):
            o = box((0.22, 3.3, 0.22), (-4.6 + sx * 0.45, 1.6, z), M["Steel"], 0.04)
            o.rotation_euler = (0, -sx * math.radians(10), 0)
        box((1.8, 0.18, 0.3), (-4.6, 0.09, z), M["Steel"], 0.04)
    for y, x in ((1.2, -4.9), (2.4, -4.3)):
        box((1.2, 0.12, 4.8), (x, y, 0), M["Steel"], 0.03)
        for k in range(3):
            z = -1.5 + k * 1.5
            cyl(0.22, 1.2, (x, y + 0.35, z), M["Chrome"], "X", verts=10)
            for sx in (-0.45, 0.45):
                cyl(0.62, 0.22, (x + sx, y + 0.35, z), M["Iron"], "X", verts=6, bevel=0.03)  # hex heads


def fence():
    """Rustic wooden fence segment, 30 long: posts with pointed caps every 6 studs, two rails across the full length."""
    M = {k: mat(k, v, 0, 0.6) for k, v in dict(Wood=(150, 96, 52), WoodDark=(104, 64, 34)).items()}
    for i in range(5):  # posts at -12..12: adjacent segments keep the 6-stud rhythm without doubled posts
        x = -12 + i * 6
        box((0.7, 3.4, 0.7), (x, 1.7, 0), M["WoodDark"], 0.08)
        o = cyl(0.98, 0.5, (x, 3.65, 0), M["WoodDark"], d2=0.05, verts=4, bevel=0)
        o.rotation_euler = (0, 0, math.pi / 4)
    for y in (1.2, 2.6):
        box((30, 0.42, 0.28), (0, y, 0.38), M["Wood"], 0.06)


def mountain(seed):
    """Low-poly faceted peak, base diameter 1 and height 1 (scaled per instance in the game).
    Faces are coloured by height: grass -> rock -> snow."""
    import random
    rnd = random.Random(seed)
    grass, rock, snow = mat("Grass", (96, 176, 82)), mat("Rock", (128, 118, 112)), mat("Snow", (250, 252, 255))
    rock2 = mat("RockDark", (98, 90, 88))
    bm = bmesh.new()
    sides = 9
    rings = [(0.0, 0.5), (0.28, 0.40), (0.55, 0.27), (0.78, 0.15)]
    verts = []
    for h, r in rings:
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides + rnd.uniform(-0.15, 0.15)
            rr = r * rnd.uniform(0.82, 1.12)
            ring.append(bm.verts.new(rb(math.cos(a) * rr, h + (rnd.uniform(-0.04, 0.04) if h else 0), math.sin(a) * rr)))
        verts.append(ring)
    apex = bm.verts.new(rb(rnd.uniform(-0.05, 0.05), 1.0, rnd.uniform(-0.05, 0.05)))
    for i in range(len(rings) - 1):
        for k in range(sides):
            a, b = verts[i][k], verts[i][(k + 1) % sides]
            c, d = verts[i + 1][(k + 1) % sides], verts[i + 1][k]
            bm.faces.new((a, b, c)); bm.faces.new((a, c, d))
    for k in range(sides):
        bm.faces.new((verts[-1][k], verts[-1][(k + 1) % sides], apex))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("Mountain")
    bm.to_mesh(me)
    o = bpy.data.objects.new("Mountain", me)
    bpy.context.scene.collection.objects.link(o)
    for m in (grass, rock, snow, rock2):
        me.materials.append(m)
    for p in me.polygons:
        h = p.center.z + rnd.uniform(-0.06, 0.06)
        p.material_index = 0 if h < 0.2 else 2 if h > 0.66 else (1 if p.index % 3 else 3)


def lathe(profile, c, m, segs=16, axis_rot=None):
    """Surface of revolution around local Y: profile = [(radius, y), ...] from bottom to top."""
    bm = bmesh.new()
    rings = []
    for r, y in profile:
        if r <= 1e-4:
            rings.append([bm.verts.new(rb(0, y, 0))])
            continue
        rings.append([bm.verts.new(rb(math.cos(2 * math.pi * k / segs) * r, y, math.sin(2 * math.pi * k / segs) * r)) for k in range(segs)])
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        for k in range(segs):
            if len(a) == 1:
                bm.faces.new((a[0], b[(k + 1) % segs], b[k]))
            elif len(b) == 1:
                bm.faces.new((a[k], a[(k + 1) % segs], b[0]))
            else:
                bm.faces.new((a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("lathe")
    bm.to_mesh(me)
    o = bpy.data.objects.new("lathe", me)
    bpy.context.scene.collection.objects.link(o)
    o.location = rb(*c)
    if axis_rot:
        o.rotation_euler = axis_rot
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return finish(o, m)


def cut(target, cutter):
    """Boolean difference (both get their modifiers applied first)."""
    cutter.data.materials.append(target.data.materials[0])  # cut faces keep the target's material
    for o in (target, cutter):
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    b = target.modifiers.new("Cut", "BOOLEAN")
    b.operation, b.object = "DIFFERENCE", cutter
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.modifier_apply(modifier=b.name)
    bpy.data.objects.remove(cutter)


# ---------- Long-table segment: one billiard table per zone (80 x 42 studs), recoloured per theme ----------
SEG = dict(Wood=(120, 64, 30), Panel=(150, 86, 44), Rail=(96, 50, 22), Felt=(28, 140, 66), Cushion=(20, 110, 52),
           Trim=(230, 180, 70), Pearl=(255, 250, 235), Pocket=(20, 16, 18), Leg=(90, 46, 20))


def table_segment():
    M = {k: mat(k, v, 1 if k == "Trim" else 0, 0.3) for k, v in SEG.items()}
    L, W, RW = 80, 36, 3.0
    box((W + 2 * RW, 1.4, L), (0, 2.3, 0), M["Wood"], 0.3)
    box((W, 0.3, L), (0, 3.15, 0), M["Felt"], 0)
    for s in (-1, 1):
        rail = box((RW, 4.2, L), (s * (W / 2 + RW / 2), 5.1, 0), M["Rail"], 0.7)
        cush = box((0.9, 1.1, L), (s * (W / 2 + 0.45), 3.85, 0), M["Cushion"], 0.3)
        for o in (rail, cush):  # pocket notch in the middle of the segment
            bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=2.5, depth=12, location=rb(s * W / 2, 5, 0))
            cut(o, bpy.context.object)
        cyl(4.8, 0.5, (s * W / 2, 3.12, 0), M["Pocket"], verts=24, bevel=0)
        liner = cyl(5.1, 4.3, (s * W / 2, 5.0, 0), M["Pocket"], verts=24, bevel=0)  # dark pocket throat in the notch
        bpy.ops.mesh.primitive_cube_add(size=1, location=rb(s * W / 2 - s * 3, 5, 0))
        bpy.context.object.scale = (6, 8, 6)
        cut(liner, bpy.context.object)
        bm = bmesh.new(); bm.from_mesh(liner.data)  # open the throat towards the felt: drop the flat cut face
        mw = liner.matrix_world
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if abs((mw @ f.calc_center_median()).x - s * W / 2) < 0.02 and abs(f.normal.x) > 0.9], context="FACES")
        bm.to_mesh(liner.data); bm.free()
        rim = torus(5.6, 0.45, (s * W / 2, 7.15, 0), M["Trim"])  # brass pocket plate: outer half only
        bpy.ops.mesh.primitive_cube_add(size=1, location=rb(s * W / 2 - s * 3, 7.15, 0))
        bpy.context.object.scale = (6, 8, 3)
        cut(rim, bpy.context.object)
        box((0.35, 0.12, L - 1), (s * (W / 2 + RW / 2), 7.23, 0), M["Trim"], 0.05)  # brass inlay line
        for k in (-35, -25, -15, -8, 8, 15, 25, 35):  # sights
            cyl(1.0, 0.12, (s * (W / 2 + RW / 2), 7.27, k), M["Trim"], verts=12, bevel=0)
            sphere(0.62, (s * (W / 2 + RW / 2), 7.33, k), M["Pearl"], 8, 4, (1, 0.35, 1.4))
        x = s * (W / 2 + RW + 0.12)
        for z in (-28, -12, 12, 28):  # raised apron panels with brass frames
            box((0.3, 0.8, 13), (x, 2.3, z), M["Panel"], 0.12)
            box((0.12, 0.08, 13.4), (x + s * 0.12, 2.74, z), M["Trim"], 0)
            box((0.12, 0.08, 13.4), (x + s * 0.12, 1.86, z), M["Trim"], 0)
        cyl(1.3, 0.25, (x + s * 0.1, 2.3, 0), M["Trim"], "X", verts=16)  # medallion under the pocket
        box((0.3, 0.25, L), (s * (W / 2 + RW + 0.08), 1.72, 0), M["Trim"], 0.05)
        for e in (-1, 1):
            lathe([(0, 0), (0.75, 0), (0.85, 0.25), (0.5, 0.6), (0.95, 1.1), (0.6, 1.6), (0.25, 1.9), (0, 2.15)], (s * (W / 2 + RW / 2), 7.2, e * (L / 2 - 1.6)), M["Trim"], 12)
            lathe([(0, 0), (1.7, 0), (1.75, 0.18), (1.15, 0.38), (1.55, 0.8), (1.05, 1.2), (1.45, 1.5), (1.45, 1.62), (0, 1.62)], (s * (W / 2 + 1), 0, e * (L / 2 - 6)), M["Leg"], 16)
            torus(3.1, 0.3, (s * (W / 2 + 1), 0.15, e * (L / 2 - 6)), M["Trim"])
    for e in (-1, 1):  # brass bands where two tables meet
        box((W + 2 * RW + 0.4, 1.6, 0.5), (0, 2.3, e * (L / 2 - 0.25)), M["Trim"], 0.08)


# ---------- Backdrop props (sizes in studs; recoloured per theme) ----------
def pine():
    t, l, s = mat("Trunk", (110, 70, 40)), mat("Leaves", (40, 120, 70)), mat("Snow", (245, 250, 255))
    cyl(1.4, 4, (0, 2, 0), t, verts=8)
    for k, (d, y) in enumerate(((9, 3), (7, 6.5), (5, 9.5))):
        cyl(d, 4.5, (0, y + 2.25, 0), l, d2=0.3, verts=9, bevel=0)
        cyl(d * 0.45, 1.6, (0, y + 3.9, 0), s, d2=0.2, verts=9, bevel=0)


def tree():
    t, l = mat("Trunk", (120, 76, 40)), mat("Leaves", (80, 180, 70))
    cyl(1.6, 7, (0, 3.5, 0), t, verts=8, d2=1.1)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=4.2, location=rb(0, 9, 0)); finish(bpy.context.object, l)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=3.0, location=rb(2.4, 7.6, 1)); finish(bpy.context.object, l)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=2.8, location=rb(-2.2, 8, -1.2)); finish(bpy.context.object, l)


def palm():
    t, l, n = mat("Trunk", (160, 110, 60)), mat("Leaves", (60, 170, 70)), mat("Nut", (110, 70, 40))
    for k in range(7):
        cyl(1.3 - k * 0.07, 2.1, (k * 0.32, 1 + k * 2, 0), t, verts=8)
    top = (2.2, 14.2, 0)
    for a in range(8):  # drooping leaves: flattened ellipsoids in two segments
        ang = a * 2 * math.pi / 8
        dx, dz = math.cos(ang), math.sin(ang)
        for j, (r, y, ln) in enumerate(((2.2, 0.1, 4.6), (5.2, -1.4, 3.6))):
            o = sphere(1, (top[0] + dx * r, top[1] + y, top[2] + dz * r), l, 10, 6, (ln, 0.18, 1.4 - j * 0.3))
            o.rotation_euler = (0, -0.35 - j * 0.35, -ang)
    for k in range(3):
        sphere(0.9, (top[0] + math.cos(k * 2) * 0.6, top[1] - 0.9, math.sin(k * 2) * 0.6), n, 8, 6)


def cactus():
    b, f = mat("Body", (70, 160, 80)), mat("Flower", (255, 120, 170))
    cyl(2, 8, (0, 4, 0), b, verts=12); sphere(2, (0, 8, 0), b, 12, 6)
    for s, h in ((-1, 3.5), (1, 5)):
        cyl(1.2, 2.4, (s * 1.8, h, 0), b, "X", verts=10)
        cyl(1.2, 3, (s * 3, h + 1.5, 0), b, verts=10); sphere(1.2, (s * 3, h + 3, 0), b, 10, 6)
    sphere(0.9, (0, 9, 0), f, 8, 6)


def rock():
    r = mat("Rock", (130, 125, 120))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=3, location=rb(0, 2, 0))
    o = bpy.context.object
    import random
    rnd = random.Random(5)
    for v in o.data.vertices:
        v.co *= rnd.uniform(0.8, 1.2)
        v.co.z *= 0.75
    finish(o, r)


def dune():
    s, d = mat("Sand", (240, 210, 140)), mat("SandDark", (215, 180, 110))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=1, location=(0, 0, 0))
    o = bpy.context.object
    o.scale = (30, 20, 9)
    bpy.ops.object.transform_apply(scale=True)
    finish(o, s); o.data.materials.append(d)
    for p in o.data.polygons:
        if p.normal.x < -0.2:
            p.material_index = 1


def crystal():
    c, l = mat("Crystal", (120, 200, 255)), mat("CrystalLight", (210, 245, 255))
    for k, (x, z, h, tilt) in enumerate(((0, 0, 10, 0), (2, 1, 7, 0.35), (-2, 0.5, 6, -0.4), (0.5, -2, 5, 0.3), (-1, 2, 4, -0.2))):
        rot = (tilt, 0, tilt * 0.5)
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=1.2, radius2=0, depth=h * 0.3, location=rb(x, h * 0.85, z), rotation=rot)
        finish(bpy.context.object, l)
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=1.2, depth=h * 0.7, location=rb(x, h * 0.35, z), rotation=rot)
        finish(bpy.context.object, c)


def volcano():
    r, lv = mat("Rock", (90, 70, 66)), mat("Lava", (255, 110, 20))
    lathe([(0, 0), (45, 0), (30, 18), (16, 40), (11, 46), (8, 44), (0, 40)], (0, 0, 0), r, 18)
    lathe([(0, 43), (8.2, 43.5), (0, 44)], (0, 0, 0), lv, 18)


def tower():
    b, w = mat("Body", (40, 44, 60)), mat("Window", (120, 230, 255))
    for k, (s, y, h) in enumerate(((16, 0, 30), (12, 30, 20), (8, 50, 12))):
        box((s, h, s), (0, y + h / 2, 0), b, 0.4)
        for j in range(int(h // 4)):
            box((s + 0.2, 0.8, s + 0.2), (0, y + 2 + j * 4, 0), w, 0)
    cyl(0.5, 10, (0, 67, 0), b, verts=6)


def planet():
    b, r = mat("Body", (150, 110, 230)), mat("Ring", (230, 200, 255))
    sphere(20, (0, 0, 0), b, 24, 14)
    bpy.ops.mesh.primitive_torus_add(major_radius=15, minor_radius=1.4, major_segments=32, minor_segments=6, rotation=(0.35, 0.2, 0))
    o = bpy.context.object
    o.scale = (1, 1, 0.25)
    bpy.ops.object.transform_apply(scale=True)
    finish(o, r)


def torii():
    red, blk = mat("Red", (210, 40, 40)), mat("Black", (30, 26, 26))
    for s in (-1, 1):
        cyl(1.4, 13, (s * 5, 6.5, 0), red, verts=12)
        cyl(1.9, 1, (s * 5, 0.5, 0), blk, verts=12)
    box((15, 1.2, 1.8), (0, 13.6, 0), blk, 0.2)
    box((13, 1, 1.4), (0, 12.2, 0), red, 0.15)
    box((12, 0.8, 1.2), (0, 9.8, 0), red, 0.1)


def pyramid():
    s, g = mat("Sand", (230, 195, 120)), mat("Gold", (255, 205, 70), 1, 0.3)
    for k in range(6):
        w = 40 - k * 6.5
        box((w, 4, w), (0, 2 + k * 4, 0), s, 0.2)
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=3.2, radius2=0, depth=4, location=rb(0, 26, 0), rotation=(0, 0, math.pi / 4))
    finish(bpy.context.object, g)


def column():
    m, g = mat("Marble", (245, 242, 235)), mat("Gold", (255, 205, 70), 1, 0.3)
    box((4, 1, 4), (0, 0.5, 0), m, 0.1)
    lathe([(0, 1), (1.6, 1), (1.4, 1.4), (1.3, 15), (1.6, 15.4), (0, 15.4)], (0, 0, 0), m, 16)
    torus(3, 0.3, (0, 15.6, 0), g)
    box((4, 0.8, 4), (0, 16.2, 0), m, 0.1)


def mushroom():
    st, cp, sp = mat("Stem", (245, 235, 215)), mat("Cap", (230, 50, 60)), mat("Spot", (255, 255, 255))
    lathe([(0, 0), (1.4, 0), (1.0, 2), (1.1, 4.5), (0, 4.5)], (0, 0, 0), st, 12)
    lathe([(0, 4.2), (4.2, 4.2), (4, 5.3), (3, 6.8), (1.4, 7.7), (0, 7.9)], (0, 0, 0), cp, 18)
    for k in range(6):
        a = k * 1.05
        sphere(0.9, (math.cos(a) * 2.7, 6.6, math.sin(a) * 2.7), sp, 8, 4, (1, 0.5, 1))


def cloud():
    c = mat("Cloud", (255, 255, 255))
    for x, y, z, d in ((0, 0, 0, 10), (6, -1, 1, 7), (-6, -1, 0, 8), (2, 3, -1, 7), (-3, 2, 2, 6)):
        sphere(d, (x, y, z), c, 12, 8)


def star():
    s = mat("Star", (255, 225, 80), 0.3, 0.3)
    bm = bmesh.new()
    pts = []
    for k in range(10):
        r = 3 if k % 2 == 0 else 1.3
        a = math.pi / 2 + k * math.pi / 5
        pts.append((math.cos(a) * r, math.sin(a) * r))
    top = [bm.verts.new(rb(x, y, -0.6)) for x, y in pts]
    bot = [bm.verts.new(rb(x, y, 0.6)) for x, y in pts]
    cf_, cb = bm.verts.new(rb(0, 0, -1.2)), bm.verts.new(rb(0, 0, 1.2))
    for k in range(10):
        n = (k + 1) % 10
        bm.faces.new((cf_, top[n], top[k])); bm.faces.new((cb, bot[k], bot[n]))
        bm.faces.new((top[k], top[n], bot[n], bot[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("star"); bm.to_mesh(me)
    o = bpy.data.objects.new("star", me); bpy.context.scene.collection.objects.link(o)
    finish(o, s)


# ---------- Character accessories (R15). Head items: origin = head centre. Back items: origin = UpperTorso centre ----------
def acc_mats():
    return mat("Main", (220, 60, 60)), mat("Accent", (255, 210, 70), 1, 0.3), mat("Gem", (90, 200, 255), 0, 0.1)


def acc_cap():
    m, a, g = acc_mats()
    sphere(1.3, (0, 0.35, 0.05), m, 16, 8, (1, 0.75, 1))
    cyl(1.0, 0.08, (0, 0.42, -0.75), m, verts=16, bevel=0)
    bpy.context.object.scale = (1, 1, 0.6)
    sphere(0.22, (0, 0.85, 0.05), a, 8, 4)


def acc_fedora():
    m, a, g = acc_mats()
    cyl(2.1, 0.08, (0, 0.5, 0), m, verts=24, bevel=0.03)
    lathe([(0, 0.5), (0.72, 0.5), (0.68, 1.0), (0.45, 1.15), (0, 1.1)], (0, 0, 0), m, 18)
    cyl(1.46, 0.14, (0, 0.6, 0), a, verts=18, bevel=0)


def acc_tophat():
    m, a, g = acc_mats()
    cyl(1.9, 0.1, (0, 0.55, 0), m, verts=24, bevel=0.03)
    cyl(1.2, 1.3, (0, 1.25, 0), m, verts=20, bevel=0.05)
    cyl(1.24, 0.25, (0, 0.75, 0), a, verts=20, bevel=0)
    sphere(0.3, (0.45, 0.78, -0.45), g, 8, 6)


def acc_crown():
    m, a, g = acc_mats()
    cyl(1.25, 0.35, (0, 0.72, 0), a, verts=20, bevel=0.04)
    for k in range(8):
        ang = k * math.pi / 4
        x, z = math.cos(ang) * 0.58, math.sin(ang) * 0.58
        cyl(0.26, 0.55, (x, 1.15, z), a, d2=0.02, verts=6, bevel=0)
        sphere(0.14, (x, 1.45, z), a, 6, 4)
        if k % 2 == 0:
            sphere(0.2, (math.cos(ang) * 0.64, 0.72, math.sin(ang) * 0.64), g, 8, 4)
    sphere(0.36, (0, 0.95, 0), m, 10, 6, (1, 0.6, 1))


def acc_horns():
    m, a, g = acc_mats()
    for s in (-1, 1):
        for k in range(5):
            t = k / 4
            cyl(0.32 - t * 0.24, 0.32, (s * (0.45 + t * 0.35), 0.55 + t * 0.55, 0.05 - t * 0.12), m if k < 4 else a, verts=8, bevel=0)
            bpy.context.object.rotation_euler = (0, s * (0.35 + t * 0.5), 0)


def acc_halo():
    m, a, g = acc_mats()
    torus(1.25, 0.14, (0, 1.2, 0), a)


def acc_visor():
    m, a, g = acc_mats()
    box((1.32, 0.34, 0.2), (0, 0.08, -0.58), g, 0.08)
    for s in (-1, 1):
        box((0.12, 0.3, 1.0), (s * 0.64, 0.08, -0.15), a, 0.04)


def acc_shades():
    m, a, g = acc_mats()
    for s in (-1, 1):
        box((0.48, 0.28, 0.08), (s * 0.3, 0.1, -0.62), (mat("Lens", (20, 20, 30))), 0.06)
    box((0.2, 0.06, 0.06), (0, 0.16, -0.62), a, 0)
    for s in (-1, 1):
        box((0.06, 0.06, 0.9), (s * 0.56, 0.16, -0.2), a, 0)


def acc_tricorne():
    m, a, g = acc_mats()
    sphere(1.25, (0, 0.55, 0), m, 16, 8, (1, 0.6, 1))
    for k in range(3):
        ang = k * 2 * math.pi / 3 + math.pi / 2
        box((1.3, 0.35, 0.18), (math.cos(ang) * 0.62, 0.62, -math.sin(ang) * 0.62), m, 0.06)
        bpy.context.object.rotation_euler = (0, 0, ang + math.pi / 2)
    sphere(0.3, (0, 0.75, -0.66), a, 8, 6, (1, 1, 0.3))


def acc_kabuto():
    m, a, g = acc_mats()
    sphere(1.35, (0, 0.3, 0.05), m, 16, 8, (1, 0.85, 1))
    for s in (-1, 1):
        box((0.12, 0.7, 0.9), (s * 0.72, -0.05, 0.15), m, 0.05)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.55, minor_radius=0.07, major_segments=16, minor_segments=4, location=rb(0, 0.95, -0.45), rotation=(math.pi / 2, 0, 0))
    finish(bpy.context.object, a)


def acc_bubble():
    m, a, g = acc_mats()
    sphere(1.85, (0, 0.05, 0), m, 18, 10)
    sphere(1.25, (0, 0.1, -0.42), g, 16, 8, (1, 0.8, 0.7))
    torus(1.5, 0.16, (0, -0.68, 0), a)


def acc_hood():
    m, a, g = acc_mats()
    sphere(1.6, (0, 0.12, 0.12), m, 16, 10, (1, 1.05, 1))
    box((1.5, 1.4, 0.2), (0, -0.4, 0.62), m, 0.1)


def acc_nemes():
    m, a, g = acc_mats()
    sphere(1.36, (0, 0.28, 0.05), m, 16, 8, (1, 0.8, 1))
    for s in (-1, 1):
        box((0.3, 1.4, 0.7), (s * 0.68, -0.4, -0.05), m, 0.08)
        for k in range(3):
            box((0.32, 0.1, 0.72), (s * 0.68, -0.05 - k * 0.35, -0.05), a, 0)
    sphere(0.25, (0, 0.62, -0.62), a, 8, 6)


def acc_wings():  # back item
    m, a, g = acc_mats()
    for s in (-1, 1):
        for k in range(4):
            ln = 2.6 - k * 0.45
            box((ln, 0.42, 0.12), (s * (0.6 + ln / 2), 0.9 - k * 0.42, 0.75), m if k else a, 0.12)
            bpy.context.object.rotation_euler = (0, -s * (0.35 + k * 0.08), 0)  # about Roblox Z: outer tips up


def acc_cape():  # back item
    m, a, g = acc_mats()
    box((2.0, 3.4, 0.12), (0, -0.85, 0.62), m, 0.05)
    bpy.context.object.rotation_euler = (math.radians(8), 0, 0)
    box((2.2, 0.3, 0.6), (0, 0.85, 0.35), a, 0.1)
    sphere(0.3, (0, 0.85, -0.05), g, 8, 6)


# ---------- Player base stage and the cue shop (recoloured per base: Rim / Felt / Accent) ----------
def base_platform():
    M = {k: mat(k, v, 1 if k == "Trim" else 0, 0.35) for k, v in dict(Rim=(255, 110, 120), Deck=(214, 176, 124), Groove=(150, 108, 66),
                                                                    Felt=(28, 118, 62), Trim=(235, 185, 70), Inset=(232, 210, 170)).items()}
    rot = (0, 0, math.pi / 8)  # flat side to the front
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=31, depth=1.2, location=rb(0, 0.6, 0), rotation=rot)
    finish(bpy.context.object, M["Rim"], 0.3, 3)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=30.6, depth=0.12, location=rb(0, 1.25, 0), rotation=rot)
    finish(bpy.context.object, M["Trim"], 0.04)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=29.9, depth=0.16, location=rb(0, 1.29, 0), rotation=rot)
    finish(bpy.context.object, M["Deck"], 0.03)
    for k in range(-12, 13):  # plank grooves, clipped to a circle inside the octagon
        x = k * 2.2
        half = math.sqrt(max(0, 27.2 ** 2 - x * x))
        if half > 1:
            box((0.1, 0.04, 2 * half), (x, 1.375, 0), M["Groove"], 0)
    cyl(31, 0.06, (0, 1.39, 0), M["Felt"], verts=48, bevel=0)
    torus(32, 0.35, (0, 1.42, 0), M["Trim"])
    cyl(14.5, 0.08, (0, 1.4, 0), M["Inset"], verts=48, bevel=0)
    for k in range(8):  # brass spots where the characters stand
        a = math.radians(-150 + k * 300 / 7)
        x, z = math.sin(a) * 12, -math.cos(a) * 12
        cyl(4.4, 0.12, (x, 1.43, z), M["Trim"], verts=24, bevel=0.03)
        cyl(3.4, 0.14, (x, 1.45, z), M["Inset"], verts=24, bevel=0)
    box((15, 0.7, 2.6), (0, 0.35, 31.6), M["Rim"], 0.2)
    box((15.2, 0.1, 2.8), (0, 0.72, 31.6), M["Trim"], 0)


def cue_shop():
    M = {k: mat(k, v, 1 if k == "Trim" else 0, 0.3) for k, v in dict(Wood=(92, 50, 24), Accent=(255, 110, 120), Trim=(235, 185, 70),
                                                                   Marble=(246, 242, 234), Felt=(24, 110, 56), White=(250, 248, 242),
                                                                   Lamp=(255, 236, 190)).items()}
    box((12.4, 0.5, 8.4), (0, 0.25, -0.6), M["Wood"], 0.15)
    box((10, 3.2, 2.6), (0, 2.1, 1.3), M["Wood"], 0.3)
    box((8.6, 2.1, 0.2), (0, 2.1, 2.62), M["Accent"], 0.08)
    box((10.3, 0.2, 2.9), (0, 3.62, 1.3), M["Trim"], 0.05)
    box((10.6, 0.3, 3.2), (0, 3.85, 1.35), M["Marble"], 0.1)
    box((11, 8.2, 0.8), (0, 4.6, -3.6), M["Wood"], 0.2)
    o = cyl(11, 0.8, (0, 8.7, -3.6), M["Wood"], "Z", verts=32, bevel=0.1)  # arched top
    o.scale = (1, 0.42, 1)  # squash vertically (local Y is up after the rotation)
    box((9, 6.6, 0.25), (0, 4.9, -3.12), M["Felt"], 0.05)
    for sx in (-1, 1):
        cyl(0.55, 9.9, (sx * 5.6, 5.2, 3.2), M["Wood"], verts=16)
        sphere(0.7, (sx * 5.6, 10.2, 3.2), M["Trim"], 12, 8)
        cyl(0.9, 0.3, (sx * 5.6, 0.65, 3.2), M["Trim"], verts=16)
    # one smooth curved canopy (6 stripes) with a scalloped valance, built as a single sheet
    bm = bmesh.new()
    arc = [(-3.9 + 7.6 * t, 11.7 - 1.5 * t + 0.6 * math.sin(math.pi * t)) for t in [j / 12 for j in range(13)]]
    faces_by_mat = {0: [], 1: []}
    for k in range(6):
        x0, x1 = -6 + k * 2, -4 + k * 2
        col = [(bm.verts.new(rb(x0, y, z)), bm.verts.new(rb(x1, y, z))) for z, y in arc]
        for j in range(12):
            faces_by_mat[k % 2].append(bm.faces.new((col[j][0], col[j][1], col[j + 1][1], col[j + 1][0])))
        zf, yf = arc[-1]
        cx = (x0 + x1) / 2
        fan = [bm.verts.new(rb(cx + math.cos(math.pi * i / 8), yf - math.sin(math.pi * i / 8) * 0.9, zf)) for i in range(9)]
        centre = bm.verts.new(rb(cx, yf, zf))
        for i in range(8):
            faces_by_mat[k % 2].append(bm.faces.new((centre, fan[i], fan[i + 1])))
    me = bpy.data.meshes.new("canopy"); bm.to_mesh(me); bm.free()
    can = bpy.data.objects.new("canopy", me); bpy.context.scene.collection.objects.link(can)
    can.data.materials.append(M["Accent"]); can.data.materials.append(M["White"])
    for f in can.data.polygons:  # stripes alternate by x position
        f.material_index = int((f.center.x + 6) // 2) % 2
    box((12.4, 0.35, 0.35), (0, arc[-1][1] + 0.05, arc[-1][0]), M["Trim"], 0.1)
    for sx in (-2.8, 2.8):  # the sign stands on the canopy
        cyl(0.18, 1.6, (sx, arc[-1][1] + 0.8, arc[-1][0] - 0.3), M["Trim"], verts=8)
    box((8.4, 2.2, 0.3), (0, arc[-1][1] + 2.4, arc[-1][0] - 0.4), M["Trim"], 0.1)
    box((8, 1.8, 0.4), (0, arc[-1][1] + 2.4, arc[-1][0] - 0.3), M["Accent"], 0.12)
    sphere(0.8, (0, 9.9, 0.8), M["Lamp"], 12, 8)
    cyl(0.12, 1.2, (0, 10.8, 0.8), M["Trim"], verts=6)


# ---------- Grand finale scenery (played as a real-time scene on the last table) ----------
def finale_computer():
    """Gaming desk: wooden desk, monitor (screen centre (0, 6.2, -1.56), 6.8 x 3.82, facing +Z), RGB keyboard,
    mouse + pad, glass-side PC tower with fans, speakers and a mug. Desk top at y = 3.375."""
    C_ = dict(Wood=(120, 78, 46), Metal=(40, 42, 48), Bezel=(22, 22, 26), Screen=(8, 10, 16), Glow=(120, 80, 255),
              KeyBase=(30, 30, 36), Key=(58, 58, 66), KeyAccent=(255, 90, 160), Mouse=(36, 36, 42), Pad=(24, 24, 60),
              Case=(28, 28, 34), Glass=(90, 110, 140), Fan=(80, 230, 255), Speaker=(34, 34, 40), Mug=(235, 235, 230))
    M = {k: mat(k, v, 0.6 if k in ("Metal", "Case") else 0, 0.35) for k, v in C_.items()}
    box((12, 0.35, 5.5), (0, 3.2, 0), M["Wood"], 0.06)
    for sx in (-1, 1):
        for sz in (-1, 1):
            box((0.4, 3.0, 0.4), (sx * 5.6, 1.5, sz * 2.45), M["Metal"], 0.04)
    box((2.2, 0.12, 1.4), (0, 3.44, -1.4), M["Metal"], 0.04)  # monitor stand
    box((0.42, 2.1, 0.3), (0, 4.45, -1.62), M["Metal"], 0.04)
    box((7.2, 4.3, 0.3), (0, 6.2, -1.75), M["Bezel"], 0.08)
    box((6.8, 3.82, 0.05), (0, 6.2, -1.585), M["Screen"], 0)
    box((7.0, 0.08, 0.06), (0, 4.03, -1.6), M["Glow"], 0)  # ambient light strip
    box((4.4, 0.18, 1.5), (0, 3.46, 0.9), M["KeyBase"], 0.05)
    for row in range(4):
        for col in range(14):
            accent = (row, col) in ((1, 2), (2, 1), (2, 2), (2, 3))  # glowing WASD
            box((0.25, 0.1, 0.26), (-1.95 + col * 0.3, 3.6, 0.45 + row * 0.31), M["KeyAccent" if accent else "Key"], 0.02)
    box((2.2, 0.04, 1.8), (3.3, 3.37, 0.8), M["Pad"], 0.01)
    sphere(0.55, (3.3, 3.5, 0.8), M["Mouse"], 12, 8, (1, 0.45, 1.5))
    box((1.6, 4.4, 4.2), (-4.9, 5.58, -0.3), M["Case"], 0.06)  # tower on the desk
    box((0.05, 3.8, 3.6), (-4.08, 5.58, -0.3), M["Glass"], 0)
    for k in range(3):
        torus(0.95, 0.12, (-4.0, 4.3 + k * 1.25, -0.3), M["Fan"], "X")
    for sx in (-1, 1):  # speakers
        box((0.9, 1.6, 0.9), (sx * 4.35 + (0.9 if sx < 0 else 0), 4.18, -1.6), M["Speaker"], 0.06)
        cyl(0.6, 0.06, (sx * 4.35 + (0.9 if sx < 0 else 0), 4.4, -1.13), M["Metal"], "Z", verts=16)
    cyl(0.6, 0.75, (2.4, 3.75, -0.7), M["Mug"], verts=16)
    torus(0.42, 0.09, (2.75, 3.78, -0.7), M["Mug"], "X")


def nature_height(x, z):
    """Rolling hills around a lake basin at (0, 30); peaks towards the edges."""
    r = math.hypot(x, z - 30)
    h = 6 + 7 * math.sin(x * 0.031) * math.cos(z * 0.027) + 5 * math.sin((x + z) * 0.052)
    h += max(0, (r - 70) * 0.22) + 18 * max(0, (math.hypot(x, z) - 140) / 40)
    return h - 14 * max(0, 1 - r / 55)


def finale_nature():
    """Valley 360 x 360: faceted hills coloured by height, a lake, pines, oaks and rocks."""
    C_ = dict(Grass=(110, 180, 80), GrassDark=(78, 146, 64), Rock=(128, 120, 112), Snow=(244, 248, 252), Sand=(222, 206, 150),
              Water=(70, 150, 210), Trunk=(110, 74, 44), Pine=(42, 110, 70), Leaves=(96, 168, 70))
    M = {k: mat(k, v, 0, 0.6) for k, v in C_.items()}
    n, size = 34, 360
    bm = bmesh.new()
    grid = [[bm.verts.new(rb(-size / 2 + i * size / n, nature_height(-size / 2 + i * size / n, -size / 2 + j * size / n), -size / 2 + j * size / n))
             for j in range(n + 1)] for i in range(n + 1)]
    faces = []
    for i in range(n):
        for j in range(n):
            a, b_, c, d = grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]
            for tri in ((a, b_, c), (a, c, d)):
                y = sum(v.co.z for v in tri) / 3
                cx, cz = sum(v.co.x for v in tri) / 3, sum(v.co.y for v in tri) / 3
                meadow = "GrassDark" if math.sin(cx * 0.045) + math.cos(cz * 0.06) + 0.5 * math.sin((cx - cz) * 0.11) > 0.6 else "Grass"
                faces.append((bm.faces.new(tri), "Sand" if y < 1.5 else "Snow" if y > 38 else "Rock" if y > 26 else meadow))
    me = bpy.data.meshes.new("valley"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("valley", me); bpy.context.scene.collection.objects.link(o)
    names = list(C_)
    for k in names:
        o.data.materials.append(M[k])
    for (f, k), poly in zip(faces, me.polygons):
        poly.material_index = names.index(k)
    box((104, 0.2, 96), (0, -1.2, 30), M["Water"], 0)
    rnd = __import__("random").Random(11)
    placed = 0
    while placed < 70:
        x, z = rnd.uniform(-160, 160), rnd.uniform(-160, 160)
        y = nature_height(x, z)
        if math.hypot(x, z - 30) < 62 or y > 26 or y < 2:
            continue
        placed += 1
        if rnd.random() < 0.6:  # pine
            k = rnd.uniform(0.8, 1.5)
            cyl(1.2 * k, 3 * k, (x, y + 1.5 * k, z), M["Trunk"], verts=5, bevel=0)
            for t in range(2):
                cyl((7 - t * 2.4) * k, 5.5 * k, (x, y + (4.5 + t * 3.6) * k, z), M["Pine"], d2=0.2, verts=7, bevel=0)
        else:  # oak
            k = rnd.uniform(0.9, 1.6)
            cyl(1.3 * k, 5 * k, (x, y + 2.5 * k, z), M["Trunk"], verts=5, bevel=0)
            sphere(8 * k, (x, y + 7.5 * k, z), M["Leaves"], 7, 5)
    for _ in range(14):
        x, z = rnd.uniform(-150, 150), rnd.uniform(-150, 150)
        sphere(rnd.uniform(3, 7), (x, nature_height(x, z) + 1, z), M["Rock"], 6, 4, (1, 0.7, 1.2))


def finale_city():
    """City 320 x 320 at dusk: 5 x 5 blocks between roads, towers with lit window bands, rooftops, street lamps."""
    C_ = dict(Asphalt=(46, 48, 56), Line=(240, 220, 120), Sidewalk=(150, 148, 146), Concrete=(170, 166, 160), Glass=(80, 120, 160),
              Brick=(150, 82, 64), Window=(255, 214, 120), WindowCool=(150, 210, 255), Roof=(70, 70, 78), Lamp=(255, 236, 180), Pole=(50, 52, 58))
    M = {k: mat(k, v, 0.3 if k == "Glass" else 0, 0.5) for k, v in C_.items()}
    rnd = __import__("random").Random(5)
    box((320, 1, 320), (0, -0.5, 0), M["Asphalt"], 0)
    centres = [-128, -64, 0, 64, 128]
    for road in (-96, -32, 32, 96):  # dashed centre lines
        for k in range(10):
            t = -144 + k * 32
            box((0.4, 0.05, 8), (road, 0.03, t), M["Line"], 0)
            box((8, 0.05, 0.4), (t, 0.03, road), M["Line"], 0)
    for bx in centres:
        for bz in centres:
            box((48, 0.4, 48), (bx, 0.2, bz), M["Sidewalk"], 0)
            centre = 1.6 - math.hypot(bx, bz) / 140  # taller towers downtown
            for qx, qz, w, d in ((-11, -11, 20, 20), (11, -11, 20, 20), (-11, 11, 20, 20), (11, 11, 20, 20)) if rnd.random() < 0.7 else ((0, 0, 40, 40),):
                if rnd.random() < 0.15:
                    continue
                h = rnd.uniform(16, 50) * centre + rnd.uniform(0, 30) * centre
                skin = rnd.choice(("Concrete", "Glass", "Brick", "Glass"))
                x, z = bx + qx, bz + qz
                box((w, h, d), (x, h / 2 + 0.4, z), M[skin], 0)
                warm = rnd.random() < 0.65
                for y in range(5, int(h) - 2, 7):
                    if rnd.random() < 0.5:
                        box((w + 0.12, 1.4, d + 0.12), (x, y + 0.4, z), M["Window" if warm else "WindowCool"], 0)
                box((w * 0.8, 1, d * 0.8), (x, h + 0.9, z), M["Roof"], 0)
                if h > 60 and rnd.random() < 0.6:
                    cyl(0.6, 10, (x, h + 6, z), M["Pole"], verts=6, bevel=0)
            for sx in (-1, 1):  # street lamps on the block corners
                for sz in (-1, 1):
                    x, z = bx + sx * 23, bz + sz * 23
                    cyl(0.35, 7, (x, 3.9, z), M["Pole"], verts=6, bevel=0)
                    sphere(1.1, (x, 7.6, z), M["Lamp"], 6, 4)


# ---------- Long-table hall: wall + ceiling segments (80 studs, one per table) and a themed prop kit ----------
def hall_wall():
    """Left-hand wall segment at the origin, inner face towards +X: pilasters framing the table's painted
    backdrop (which sits at x = 1.5, y 0..24), brass picture rail, upper panels with frames, cornice, sconces."""
    M = {k: mat(k, v, 0.8 if k == "Brass" else 0, 0.45) for k, v in dict(Wall=(122, 52, 60), WallDark=(78, 30, 38), Trim=(236, 224, 200),
                                                                        Brass=(226, 178, 84), Frame=(96, 62, 34), Panel=(48, 92, 70), Glow=(255, 222, 150)).items()}
    box((1.2, 12, 80), (-0.6, 30, 0), M["Wall"], 0)  # upper wall band above the backdrop
    box((0.35, 0.5, 80), (0.15, 24.3, 0), M["Brass"], 0.08)  # picture rail
    box((1.6, 1.1, 80.2), (0.2, 35.5, 0), M["Trim"], 0.2)  # cornice
    box((1.0, 0.5, 80.2), (0.4, 34.7, 0), M["Trim"], 0.1)
    for z in (-26.7, 0, 26.7):  # framed upper panels
        box((0.3, 7.6, 20), (0.05, 29.8, z), M["Frame"], 0.12)
        box((0.32, 6.4, 18.6), (0.1, 29.8, z), M["Panel"], 0.05)
        box((0.36, 0.25, 12), (0.2, 31.6, z), M["Brass"], 0.04)
    for z in (-40, 40):  # pilasters at the table joints (shared by neighbours)
        box((2.4, 36, 2.8), (0.6, 18, z), M["WallDark"], 0.15)
        box((2.8, 1.2, 3.4), (0.7, 0.6, z), M["Trim"], 0.15)
        box((2.9, 1.0, 3.5), (0.8, 33.6, z), M["Trim"], 0.15)
        for y in range(4, 32, 4):
            box((2.5, 0.25, 2.9), (0.65, y, z), M["Frame"], 0.04)
        box((0.6, 1.4, 0.8), (2.0, 18, z), M["Brass"], 0.1)  # sconce
        cyl(1.1, 1.2, (2.6, 19.3, z), M["Glow"], d2=0.7, verts=10)


def hall_ceiling():
    """Ceiling over one table (x -35..35, at y 36): coffers between beams, a long central beam and three green
    billiard lamps hanging over the felt (shade bottom at y 17)."""
    M = {k: mat(k, v, 0.8 if k == "Brass" else 0, 0.45) for k, v in dict(Ceiling=(232, 220, 196), Beam=(92, 56, 32), Coffer=(198, 176, 140),
                                                                        Brass=(226, 178, 84), Shade=(28, 110, 64), Glow=(255, 236, 180)).items()}
    box((70, 1, 80), (0, 36.5, 0), M["Ceiling"], 0)
    for x in (-23.3, 0, 23.3):
        for z in (-26.7, 0, 26.7):
            box((20, 0.3, 24), (x, 35.9, z), M["Coffer"], 0.1)
    for x in (-11.7, 11.7, -35, 35):
        box((1.6, 1.4, 80), (x, 35.3, 0), M["Beam"], 0.15)
    for z in (-40, -13.3, 13.3, 40):
        box((70, 1.4, 1.6), (0, 35.3, z), M["Beam"], 0.15)
    for z in (-26.7, 0, 26.7):  # billiard lamps
        cyl(0.2, 15.5, (0, 27.6, z), M["Brass"], verts=6, bevel=0)
        cyl(1.8, 0.5, (0, 35.2, z), M["Brass"], verts=12)
        cyl(3.6, 2.4, (0, 18.2, z), M["Shade"], d2=1.2, verts=16)  # green conical shade
        torus(3.6, 0.18, (0, 17.0, z), M["Brass"])
        sphere(1.3, (0, 17.4, z), M["Glow"], 10, 6)


def deco_props():
    """Each prop is its own model; returned as (name, builder) pairs. Sizes fit a rail (about 2 studs wide)."""
    def P(name, rgb, metal=0, rough=0.45):
        return mat(name, rgb, metal, rough)
    def lantern():
        M = dict(Main=P("Main", (200, 40, 40)), Accent=P("Accent", (230, 180, 80), 0.8), Glow=P("Glow", (255, 220, 140)))
        cyl(0.3, 0.6, (0, 0.3, 0), M["Accent"], verts=8); sphere(1.6, (0, 1.4, 0), M["Main"], 12, 8, (1, 1.2, 1))
        cyl(0.5, 0.3, (0, 2.45, 0), M["Accent"], verts=8); sphere(0.8, (0, 1.4, 0), M["Glow"], 8, 6)
    def crystal():
        M = dict(Main=P("Main", (130, 210, 255), 0, 0.1), Accent=P("Accent", (220, 245, 255), 0, 0.1), Glow=P("Glow", (90, 160, 255)))
        cyl(1.8, 0.4, (0, 0.2, 0), M["Glow"], verts=6)
        for a, h, s in ((0, 3.4, 0.9), (2.1, 2.4, 0.6), (4.2, 2.0, 0.55)):
            o = cyl(s, h, (math.cos(a) * 0.4, h / 2 + 0.3, math.sin(a) * 0.4), M["Main" if a == 0 else "Accent"], d2=0.05, verts=6, bevel=0)
            o.rotation_euler = (math.radians(10) * math.cos(a), math.radians(10) * math.sin(a), 0)
    def gift():
        M = dict(Main=P("Main", (220, 40, 60)), Accent=P("Accent", (255, 215, 90), 0.6), Glow=P("Glow", (255, 255, 255)))
        box((1.6, 1.4, 1.6), (0, 0.7, 0), M["Main"], 0.08); box((1.7, 1.5, 0.3), (0, 0.72, 0), M["Accent"], 0.02)
        box((0.3, 1.5, 1.7), (0, 0.72, 0), M["Accent"], 0.02)
        for sx in (-1, 1): torus(0.6, 0.16, (sx * 0.3, 1.6, 0), M["Accent"], "X")
    def xmas_tree():
        M = dict(Main=P("Main", (30, 120, 60)), Accent=P("Accent", (110, 70, 40)), Glow=P("Glow", (255, 220, 80)))
        cyl(0.5, 0.8, (0, 0.4, 0), M["Accent"], verts=8)
        for k in range(3): cyl(3.0 - k * 0.8, 1.9, (0, 1.6 + k * 1.3, 0), M["Main"], d2=0.3, verts=10)
        cyl(0.7, 0.5, (0, 5.0, 0), M["Glow"], d2=0.05, verts=5); sphere(0.5, (0, 5.0, 0), M["Glow"], 8, 4)
        for k, (x, y, z) in enumerate(((0.9, 1.4, 0.6), (-0.8, 2.1, 0.5), (0.5, 2.8, -0.7), (-0.4, 3.4, -0.4), (0.7, 2.0, -0.6), (-0.9, 1.2, -0.3))):
            sphere(0.3, (x, y, z), mat(f"Bauble{k}", [(230, 40, 50), (255, 210, 60), (60, 120, 230)][k % 3], 0.6, 0.2), 8, 6)
    def snowman():
        M = dict(Main=P("Main", (248, 250, 255)), Accent=P("Accent", (230, 60, 40)), Glow=P("Glow", (30, 30, 36)))
        sphere(1.8, (0, 0.85, 0), M["Main"], 12, 8); sphere(1.3, (0, 2.2, 0), M["Main"], 12, 8); sphere(0.95, (0, 3.25, 0), M["Main"], 10, 6)
        cyl(0.18, 0.6, (0, 3.25, -0.6), M["Accent"], "Z", d2=0.02, verts=6); torus(1.1, 0.2, (0, 2.75, 0), M["Accent"])
        cyl(1.0, 0.1, (0, 3.68, 0), M["Glow"], verts=12); cyl(0.65, 0.7, (0, 4.0, 0), M["Glow"], verts=12)
    def candy_cane():
        M = dict(Main=P("Main", (250, 250, 250)), Accent=P("Accent", (220, 30, 50)), Glow=P("Glow", (255, 255, 255)))
        for k in range(8): cyl(0.4, 0.38, (0, 0.19 + k * 0.38, 0), M["Main" if k % 2 else "Accent"], verts=8, bevel=0)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.5, minor_radius=0.2, major_segments=12, minor_segments=6, location=rb(0.5, 3.1, 0), rotation=(math.pi / 2, 0, 0))
        finish(bpy.context.object, M["Accent"])
    def mushroom():
        M = dict(Main=P("Main", (230, 50, 60)), Accent=P("Accent", (250, 240, 220)), Glow=P("Glow", (255, 255, 255)))
        cyl(0.7, 1.4, (0, 0.7, 0), M["Accent"], d2=0.55, verts=10); sphere(2.2, (0, 1.6, 0), M["Main"], 12, 6, (1, 0.6, 1))
        for a in range(5): sphere(0.35, (math.cos(a * 1.3) * 0.7, 2.15, math.sin(a * 1.3) * 0.7), M["Glow"], 6, 4, (1, 0.4, 1))
    def cactus():
        M = dict(Main=P("Main", (70, 160, 80)), Accent=P("Accent", (200, 120, 70)), Glow=P("Glow", (255, 120, 170)))
        cyl(1.4, 0.7, (0, 0.35, 0), M["Accent"], d2=1.1, verts=10); cyl(0.8, 2.8, (0, 2.0, 0), M["Main"], verts=10)
        sphere(0.8, (0, 3.4, 0), M["Main"], 10, 6)
        for sx in (-1, 1):
            cyl(0.45, 1.0, (sx * 0.55, 1.9, 0), M["Main"], "X", verts=8); cyl(0.45, 1.0, (sx * 0.95, 2.4, 0), M["Main"], verts=8)
        sphere(0.4, (0, 3.85, 0), M["Glow"], 8, 4)
    def shell():
        M = dict(Main=P("Main", (255, 190, 170)), Accent=P("Accent", (255, 240, 225)), Glow=P("Glow", (255, 255, 255)))
        for k in range(7):
            o = cyl(0.35, 2.0, (0, 0.9, 0), M["Main" if k % 2 else "Accent"], d2=0.05, verts=6, bevel=0)
            o.rotation_euler = (0, math.radians(-60 + k * 20), math.radians(60))
        sphere(0.6, (0, 0.3, 0), M["Accent"], 8, 6)
    def gear():
        M = dict(Main=P("Main", (190, 130, 60), 0.8), Accent=P("Accent", (110, 110, 120), 0.8), Glow=P("Glow", (255, 200, 90)))
        box((1.6, 0.4, 1.0), (0, 0.2, 0), M["Accent"], 0.05); cyl(2.2, 0.4, (0, 1.6, 0), M["Main"], "Z", verts=16)
        for k in range(10): box((0.4, 0.5, 0.4), (math.cos(k * 0.628) * 1.2, 1.6 + math.sin(k * 0.628) * 1.2, 0), M["Main"], 0.03)
        cyl(0.6, 0.6, (0, 1.6, 0), M["Glow"], "Z", verts=10)
    def planet():
        M = dict(Main=P("Main", (240, 170, 90)), Accent=P("Accent", (250, 230, 200)), Glow=P("Glow", (150, 200, 255)))
        cyl(0.2, 1.0, (0, 0.5, 0), M["Accent"], verts=6); sphere(1.8, (0, 1.9, 0), M["Main"], 14, 10)
        o = torus(2.8, 0.14, (0, 1.9, 0), M["Accent"]); o.rotation_euler = (0.4, 0, 0.2)
        sphere(0.4, (1.4, 2.8, 0), M["Glow"], 8, 6)
    def palm():
        M = dict(Main=P("Main", (60, 170, 80)), Accent=P("Accent", (150, 100, 60)), Glow=P("Glow", (120, 80, 40)))
        for k in range(5): cyl(0.5 - k * 0.04, 0.85, (k * 0.08, 0.42 + k * 0.8, 0), M["Accent"], verts=7)
        for a in range(6):
            o = box((2.6, 0.12, 0.7), (math.cos(a * 1.05) * 1.1, 4.0, -math.sin(a * 1.05) * 1.1), M["Main"], 0.05)
            o.rotation_euler = (0, math.radians(25), a * 1.05)
        for k in range(3): sphere(0.4, (math.cos(k * 2) * 0.35, 3.75, math.sin(k * 2) * 0.35), M["Glow"], 6, 4)
    def torch():
        M = dict(Main=P("Main", (90, 60, 40)), Accent=P("Accent", (230, 180, 80), 0.8), Glow=P("Glow", (255, 150, 40)))
        cyl(0.4, 2.4, (0, 1.2, 0), M["Main"], d2=0.3, verts=8); cyl(0.8, 0.5, (0, 2.6, 0), M["Accent"], d2=0.6, verts=10)
        cyl(0.9, 1.4, (0, 3.4, 0), M["Glow"], d2=0.05, verts=8)
    def trophy():
        M = dict(Main=P("Main", (240, 190, 70), 0.9, 0.25), Accent=P("Accent", (70, 40, 30)), Glow=P("Glow", (255, 240, 200)))
        box((1.4, 0.5, 1.4), (0, 0.25, 0), M["Accent"], 0.05); cyl(0.3, 0.8, (0, 0.9, 0), M["Main"], verts=8)
        cyl(1.5, 1.4, (0, 2.0, 0), M["Main"], d2=0.6 / 1.5 * 1.5, verts=14)
        for sx in (-1, 1): torus(0.6, 0.12, (sx * 0.85, 2.1, 0), M["Main"], "X")
        sphere(0.35, (0, 2.85, 0), M["Glow"], 6, 4)
    def lotus():
        M = dict(Main=P("Main", (255, 150, 190)), Accent=P("Accent", (70, 160, 90)), Glow=P("Glow", (255, 230, 120)))
        cyl(2.2, 0.15, (0, 0.08, 0), M["Accent"], verts=14)
        for k in range(8):
            o = sphere(1.0, (math.cos(k * 0.785) * 0.55, 0.6, math.sin(k * 0.785) * 0.55), M["Main"], 8, 5, (0.45, 1, 0.25))
            o.rotation_euler = (0, 0, k * 0.785)
        sphere(0.45, (0, 0.6, 0), M["Glow"], 8, 5)
    def garland():
        """12-stud string of lights sagging between two hooks (hangs on the New Year table rails)."""
        M = dict(Main=P("Main", (30, 110, 60)), Accent=P("Accent", (255, 80, 80)), Glow=P("Glow", (255, 220, 90)))
        pts = [(x, 1.2 - 0.6 * (1 - (x / 6) ** 2), 0) for x in [-6 + k * 0.5 for k in range(25)]]
        for (xa, ya, _), (xb, yb, _) in zip(pts, pts[1:]):
            o = cyl(0.28, math.hypot(xb - xa, yb - ya) + 0.05, ((xa + xb) / 2, (ya + yb) / 2, 0), M["Main"], "X", verts=6, bevel=0)
            o.rotation_euler = (0, math.pi / 2 - math.atan2(yb - ya, xb - xa), 0)
        for k, (x, y, z) in enumerate(pts[1::2]): sphere(0.32, (x, y - 0.25, z), M["Accent" if k % 2 else "Glow"], 6, 4)
    return [("DecoLantern", lantern), ("DecoCrystal", crystal), ("DecoGift", gift), ("DecoTree", xmas_tree), ("DecoSnowman", snowman),
            ("DecoCandyCane", candy_cane), ("DecoMushroom", mushroom), ("DecoCactus", cactus), ("DecoShell", shell), ("DecoGear", gear),
            ("DecoPlanet", planet), ("DecoPalm", palm), ("DecoTorch", torch), ("DecoTrophy", trophy), ("DecoLotus", lotus), ("DecoGarland", garland)]


HALL = [("HallWall", hall_wall), ("HallCeiling", hall_ceiling)] + deco_props()


# ---------- Scenery beside the long table: stylised-realistic replacements for the block-built props ----------
# Base at y = 0 (gem: centred), the side facing the table is +X. Palette Main / Accent / Detail / Glow.
def land_kit():
    rnd = __import__("random").Random(3)
    def M4(main, accent, detail, glow, metal=0.0):
        return dict(Main=mat("Main", main, metal, 0.5), Accent=mat("Accent", accent, metal, 0.5), Detail=mat("Detail", detail, 0, 0.35), Glow=mat("Glow", glow, 0, 0.2))
    def bumpy(o, amount, seed):  # irregular, hand-made look
        r = __import__("random").Random(seed)
        for v in o.data.vertices:
            v.co += v.co.normalized() * r.uniform(-amount, amount) if v.co.length > 0 else v.co * 0
        return o
    def tree():
        M = M4((60, 160, 90), (120, 80, 50), (230, 60, 60), (255, 230, 120))
        lathe([(0.95, 0), (0.75, 0.6), (0.6, 2.5), (0.5, 4.6), (0.35, 5.6)], (0, 0, 0), M["Accent"], 10)
        for a, y, l in ((0.5, 4.4, 2.2), (2.6, 4.9, 2.0), (4.4, 4.2, 1.9)):  # branches
            o = cyl(0.35, l, (math.cos(a) * 0.7, y, math.sin(a) * 0.7), M["Accent"], d2=0.18, verts=6, bevel=0)
            o.rotation_euler = (math.sin(a) * 0.9, -math.cos(a) * 0.9, 0)
        for k, (x, y, z, d) in enumerate(((0, 7.6, 0, 5.4), (1.9, 6.8, 0.9, 3.6), (-1.8, 6.9, -0.8, 3.8), (0.6, 6.6, -2.0, 3.4), (-0.7, 6.4, 2.0, 3.4), (0.2, 9.4, 0.2, 3.2))):
            bumpy(sphere(d, (x, y, z), M["Main"], 10, 7), 0.12 * d, k)
        for k in range(14):  # fruit on the leaf surface
            a, b = rnd.uniform(0, 6.28), rnd.uniform(-0.6, 0.9)
            sphere(0.7, (math.cos(a) * math.cos(b) * 3.2, 7.4 + math.sin(b) * 2.6, math.sin(a) * math.cos(b) * 3.2), M["Detail"], 8, 6)
    def bridge():
        M = M4((150, 140, 130), (110, 100, 95), (240, 200, 120), (70, 190, 235))
        box((8, 0.4, 12), (0, 0.2, 0), M["Glow"], 0.1)  # water
        for r in (1.2, 2.2, 3.2):
            torus(r * 2, 0.06, (1.6, 0.42, -2.6), M["Detail"])
        for sz in (-1, 1):  # banks + piers
            box((7, 1.2, 2.4), (0, 0.6, sz * 5.4), M["Accent"], 0.2)
        for sz in (-1, 1):
            box((2.8, 6.4, 1.4), (0, 3.2, sz * 4.1), M["Main"], 0.1)  # stone piers up to the deck
            box((3.2, 0.6, 1.8), (0, 3.8, sz * 4.1), M["Accent"], 0.08)
        box((2.6, 0.9, 6.8), (0, 5.95, 0), M["Accent"], 0.15)  # beam under the deck
        box((3.0, 0.5, 9.4), (0, 6.65, 0), M["Main"], 0.1)  # deck
        for sx in (-1, 1):
            for k in range(6): cyl(0.22, 0.9, (sx * 1.3, 7.3, -4 + k * 1.6), M["Accent"], verts=6)
            box((0.3, 0.2, 9.4), (sx * 1.3, 7.8, 0), M["Detail"], 0.05)
    def lollipop():
        M = M4((255, 120, 170), (255, 255, 255), (255, 210, 60), (255, 255, 255))
        cyl(0.6, 9.2, (0, 4.6, 0), M["Accent"], verts=10)
        for k in range(8):
            cyl(0.66, 0.35, (0, 0.6 + k * 1.1, 0), M["Main"], verts=10, bevel=0)  # candy stripes
        cyl(6.0, 1.3, (0, 10.0, 0), M["Accent"], "X", verts=28)
        for k, r in enumerate((2.75, 2.15, 1.55, 0.95)):
            torus(r * 2, 0.32, (0.62, 10.0, 0), M["Main" if k % 2 == 0 else "Detail"], "X")
            torus(r * 2, 0.32, (-0.62, 10.0, 0), M["Main" if k % 2 == 0 else "Detail"], "X")
        o = torus(1.8, 0.5, (0, 7.3, 0), M["Main"], "X")  # ribbon bow knot
    def coral():
        M = M4((255, 110, 100), (240, 220, 200), (255, 248, 225), (255, 200, 180))
        def branch(x, y, z, ax, az, l, d, depth):
            o = cyl(d, l, (x, y + l / 2, z), M["Main"], d2=d * 0.7, verts=8, bevel=0)
            o.rotation_euler = (az, -ax, 0)
            tip = (x + math.sin(ax) * l, y + math.cos(ax) * math.cos(az) * l, z + math.sin(az) * l)
            sphere(d * 0.85, tip, M["Main"], 8, 5)
            if depth:
                for s in (-1, 1):
                    branch(*tip, ax + s * 0.45, az + s * 0.25, l * 0.68, d * 0.72, depth - 1)
        branch(0, 0, 0, 0, 0, 3.4, 1.3, 2)
        branch(0.3, 0.5, 0.4, 0.5, -0.3, 2.6, 0.9, 1)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1.4, segments=12, ring_count=8, location=rb(1.6, 0.6, -1.8))  # open clam
        o = bpy.context.object; o.scale = (1, 1, 0.35); finish(o, M["Accent"])
        sphere(1.4, (1.6, 1.2, -1.8), M["Detail"], 10, 8)
    def mesa():
        M = M4((220, 120, 70), (190, 90, 55), (240, 190, 130), (255, 220, 160))
        for k, (r, y, h) in enumerate(((5.4, 0, 2.2), (4.3, 2.2, 2.0), (3.0, 4.2, 1.9))):
            bpy.ops.mesh.primitive_cylinder_add(vertices=11, radius=r, depth=h, location=rb(0, y + h / 2, 0))
            o = bpumpy = bpy.context.object; finish(o, M["Main" if k % 2 == 0 else "Accent"], 0.15)
            bumpy(o, 0.35, k)
            box((r * 1.7, 0.15, 0.4), (0, y + h * 0.4, r * 0.8), M["Detail"], 0)
        for k in range(5):
            sphere(rnd.uniform(0.8, 1.4), (rnd.uniform(-5, 5), 0.4, rnd.uniform(-5, 5)), M["Accent"], 7, 5, (1, 0.6, 1))
    def ice_spire():
        M = M4((120, 200, 240), (200, 240, 255), (80, 150, 220), (220, 250, 255))
        for k, (x, z, h, w, tilt) in enumerate(((0, 0, 8.6, 1.6, 0), (1.3, 0.6, 6.0, 1.2, 0.3), (-1.0, 1.0, 5.2, 1.1, -0.35),
                                                (0.4, -1.3, 4.4, 1.0, 0.25), (-1.4, -0.8, 3.4, 0.9, -0.3))):
            o = cyl(w, h * 0.8, (x, h * 0.4, z), M["Main" if k % 2 == 0 else "Accent"], verts=6, bevel=0)
            t = cyl(w, h * 0.25, (x, h * 0.8 + h * 0.12, z), M["Accent" if k % 2 == 0 else "Main"], d2=0.05, verts=6, bevel=0)
            for ob in (o, t): ob.rotation_euler = (tilt * 0.6, tilt, 0)
        cyl(4.4, 0.4, (0, 0.2, 0), M["Detail"], verts=12)
    def basalt():
        M = M4((70, 50, 60), (50, 36, 44), (255, 140, 40), (255, 200, 80))
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=1, depth=0.4, location=rb(0, 0.2, 0))
        o = bpy.context.object; o.scale = (4, 5.5, 1); finish(o, M["Glow"])  # lava pool
        for k in range(11):
            a, r = k * 0.6, 0.6 + (k % 4) * 0.55
            h = rnd.uniform(3.0, 7.2)
            cyl(1.15, h, (math.cos(a) * r, h / 2, math.sin(a) * r), M["Main" if k % 2 else "Accent"], verts=6, bevel=0.04)
            cyl(1.0, 0.12, (math.cos(a) * r, h + 0.02, math.sin(a) * r), M["Detail"], verts=6, bevel=0)  # glowing tops
        for k in range(6):  # lava cracks
            box((0.25, 0.1, rnd.uniform(2, 4)), (rnd.uniform(-2.5, 2.5), 0.45, rnd.uniform(-3, 3)), M["Detail"], 0)
    def bamboo():
        M = M4((90, 170, 80), (210, 200, 110), (60, 140, 60), (200, 240, 160))
        for k, (x, z, h) in enumerate(((0, 0, 9.2), (0.9, 0.7, 7.8), (-0.8, 0.5, 8.4), (0.3, -0.9, 6.6))):
            n = int(h / 1.5)
            for j in range(n):
                cyl(0.62, 1.4, (x, 0.75 + j * 1.5, z), M["Main"], verts=8, bevel=0)
                cyl(0.72, 0.16, (x, 1.48 + j * 1.5, z), M["Accent"], verts=8, bevel=0)
            for j in range(3):  # leaf sprays: tilted down, fanned around the stalk
                yaw = (k * 3 + j) * 2.1
                o = box((2.4, 0.06, 0.5), (x + math.cos(yaw) * 1.1, h - j * 1.4, z - math.sin(yaw) * 1.1), M["Detail"], 0.03)
                o.rotation_euler = (0, math.radians(25), yaw)
    def moon_rock():
        M = M4((210, 215, 235), (90, 80, 130), (120, 110, 170), (200, 230, 255))
        bpy.ops.mesh.primitive_torus_add(major_radius=3.6, minor_radius=0.9, major_segments=18, minor_segments=6, location=rb(0, 0.3, 0))
        o = bpy.context.object; o.scale = (1, 1, 0.6); finish(o, M["Accent"]); bumpy(o, 0.3, 4)
        cyl(6.4, 0.2, (0, 0.1, 0), M["Detail"], verts=18)
        sphere(6, (0, 8, 0), M["Main"], 18, 12)
        for k in range(9):  # craters on the moon
            a, b = rnd.uniform(0, 6.28), rnd.uniform(-1.1, 1.1)
            n = (math.cos(a) * math.cos(b), math.sin(b), math.sin(a) * math.cos(b))
            sphere(rnd.uniform(0.8, 1.6), (n[0] * 2.85, 8 + n[1] * 2.85, n[2] * 2.85), M["Detail"], 8, 5, (1, 1, 1))
        for k in range(3):
            bumpy(sphere(rnd.uniform(1.0, 1.8), (2.6 + k * 0.4, 4.6 - k * 1.4, 2.4 - k * 2.2), M["Accent"], 7, 5), 0.25, 9 + k)
    def flywheel():
        M = M4((80, 220, 210), (200, 140, 60), (60, 64, 72), (255, 230, 140), 0.6)
        for sz in (-1, 1):  # A-frame stand
            for sy in (-1, 1):
                o = box((0.5, 5.2, 0.5), (0, 2.3, sz * 1.6 + sy * 0.9), M["Detail"], 0.05)
                o.rotation_euler = (sy * 0.33, 0, 0)
            box((1.6, 0.4, 3.2), (0, 0.2, sz * 1.6), M["Detail"], 0.05)
        bpy.ops.mesh.primitive_torus_add(major_radius=3.2, minor_radius=0.35, major_segments=28, minor_segments=6, location=rb(0, 4.0, 0), rotation=(0, math.pi / 2, 0))
        finish(bpy.context.object, M["Main"])
        for k in range(16):  # teeth
            a = k * math.pi / 8
            box((1.2, 0.7, 0.7), (0, 4.0 + math.sin(a) * 3.65, math.cos(a) * 3.65), M["Main"], 0.05)
        cyl(5.6, 0.25, (0, 4.0, 0), M["Accent"], "X", verts=28)  # wheel web
        for k in range(6):  # lightening holes in the web
            a = k * math.pi / 3
            cyl(1.2, 0.32, (0, 4.0 + math.sin(a) * 1.8, math.cos(a) * 1.8), M["Detail"], "X", verts=10, bevel=0)
        cyl(1.4, 1.2, (0, 4.0, 0), M["Glow"], "X", verts=14)
        cyl(0.5, 3.6, (0, 4.0, 0), M["Accent"], "X", verts=10)
    def storm_cloud():
        M = M4((200, 205, 240), (150, 155, 200), (90, 90, 120), (255, 235, 70))
        for k, (x, y, z, d) in enumerate(((0, 9.4, 0, 5.2), (0, 9.0, 2.8, 4.0), (0, 9.0, -2.8, 4.2), (0.6, 10.6, 1.2, 3.6), (-0.4, 10.4, -1.4, 3.4), (0, 8.2, 0, 4.4))):
            bumpy(sphere(d, (x, y, z), M["Main" if k < 3 else "Accent"], 10, 7), 0.1 * d, 20 + k)
        pts = [(0, 7.2, 0.2), (0, 5.6, -0.8), (0, 4.6, 0.4), (0, 2.8, -0.6), (0, 0.4, 0.2)]  # zig-zag bolt
        for a, b in zip(pts, pts[1:]):
            o = cyl(0.45, math.dist(a, b) + 0.15, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2), M["Glow"], verts=4, bevel=0)
            o.rotation_euler = (math.atan2(b[2] - a[2], b[1] - a[1]), 0, 0)
        cyl(3.2, 0.1, (0, 0.05, 0), M["Detail"], verts=14)
    def lotus():
        M = M4((40, 160, 120), (255, 140, 190), (255, 220, 90), (255, 235, 245))
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=4.5, depth=0.25, location=rb(0, 0.8, 0))
        pad = bpy.context.object; finish(pad, M["Main"])
        for k in range(7): box((0.12, 0.05, 4.2), (math.cos(k * 0.9) * 2, 0.95, math.sin(k * 0.9) * 2), M["Detail"], 0).rotation_euler = (0, 0, -k * 0.9)
        for ring, (n, r, tilt, size) in enumerate(((8, 1.3, 0.9, 1.6), (6, 0.7, 0.45, 1.4))):
            for k in range(n):
                a = k * 2 * math.pi / n + ring * 0.4
                o = sphere(size, (math.cos(a) * r, 1.9 + ring * 0.4, math.sin(a) * r), M["Accent" if ring == 0 else "Glow"], 8, 6, (0.45, 1.25, 0.25))
                o.rotation_euler = (0, -a, tilt)
        sphere(1.1, (0, 2.1, 0), M["Detail"], 10, 6, (1, 0.6, 1))
    def pixel():
        M = M4((130, 80, 220), (90, 50, 170), (50, 255, 230), (200, 255, 250))
        for k, (x, y, z) in enumerate(((0, 1.5, 0), (1.0, 4.5, 2.0), (-1.0, 7.5, 4.0))):
            for dx in (-0.75, 0.75):
                for dy in (-0.75, 0.75):
                    for dz in (-0.75, 0.75):
                        box((1.44, 1.44, 1.44), (x + dx, y + dy, z + dz), M["Main" if (dx + dy + dz) > 0 else "Accent"], 0.08)
        o = box((3, 3, 3), (3.0, 10, 3), M["Detail"], 0.25); o.rotation_euler = (0.6, 0.6, 0.6)
        o = box((3.4, 0.2, 0.2), (3.0, 10, 3), M["Glow"], 0); o.rotation_euler = (0.6, 0.6, 0.6)
    def planet():
        M = M4((70, 90, 180), (255, 210, 100), (240, 240, 255), (150, 220, 255))
        bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=2.8)
        me = bpy.data.meshes.new("pl"); bm.to_mesh(me); bm.free()
        o = bpy.data.objects.new("pl", me); bpy.context.scene.collection.objects.link(o)
        o.data.materials.append(M["Main"]); o.data.materials.append(M["Glow"])
        for f in me.polygons:
            f.material_index = int(math.sin(f.center.z * 2.6) > 0.4); f.use_smooth = True
        o.location = rb(0, 5.6, 0)
        bpy.ops.mesh.primitive_torus_add(major_radius=4.3, minor_radius=0.5, major_segments=40, minor_segments=4, location=rb(0, 5.6, 0))
        r = bpy.context.object; r.scale = (1, 1, 0.12); r.rotation_euler = (0.35, 0.25, 0); finish(r, M["Accent"])
        sphere(1.6, (3.2, 9.2, 1.8), M["Detail"], 10, 8)
        cyl(0.3, 2.8, (0, 1.4, 0), M["Accent"], verts=8); cyl(2.4, 0.4, (0, 0.2, 0), M["Accent"], verts=12)
    def throne():
        M = M4((200, 70, 160), (255, 215, 100), (120, 40, 100), (120, 230, 255), 0.4)
        for k, (r, y) in enumerate(((3.6, 0.6), (3.0, 1.8), (2.4, 3.0))):
            cyl(r * 2, 1.2, (0, y, 0), M["Main" if k % 2 == 0 else "Detail"], verts=20, bevel=0.06)
            torus(r * 2, 0.12, (0, y + 0.6, 0), M["Accent"])
        cyl(3.0, 1.0, (0, 6.0, 0), M["Accent"], verts=20)  # crown band
        for k in range(8):
            a = k * math.pi / 4
            cyl(0.9, 2.2, (math.cos(a) * 1.35, 7.6, math.sin(a) * 1.35), M["Accent"], d2=0.05, verts=4, bevel=0)
            sphere(0.45, (math.cos(a) * 1.55, 6.0, math.sin(a) * 1.55), M["Glow"], 8, 6)
        cyl(2.6, 0.3, (0, 5.4, 0), M["Detail"], verts=20)
    def hills():
        M = M4((100, 160, 110), (70, 120, 90), (230, 240, 250), (150, 200, 150))
        for k, (z, h, w) in enumerate(((-12, 9, 18), (0, 13, 22), (13, 10, 18), (-4, 6, 26), (8, 7, 22))):
            bpy.ops.mesh.primitive_uv_sphere_add(radius=1, segments=16, ring_count=8, location=rb(-0.2 * k, 0, z))
            o = bpy.context.object; o.scale = (0.8, w / 2, h); finish(o, M["Main" if k < 3 else "Accent"]); bumpy(o, 0.06, 30 + k)
        for z, h in ((0, 13), (-12, 9)):
            cyl(3.0, 2.0, (0.2, h - 0.6, z), M["Detail"], d2=0.2, verts=8, bevel=0)  # snow caps
    def gem():
        M = M4((80, 200, 255), (220, 250, 255), (40, 120, 220), (255, 255, 255))
        cyl(1.2, 0.6, (0, 0.3, 0), M["Accent"], d2=0.05, verts=8, bevel=0)
        cyl(1.2, 0.9, (0, -0.45, 0), M["Main"], d2=0.05, verts=8, bevel=0).rotation_euler = (math.pi, 0, 0)
    def beacon():
        M = M4((236, 228, 210), (220, 170, 80), (70, 60, 80), (255, 230, 140), 0.3)
        box((2.4, 0.8, 2.4), (0, 0.4, 0), M["Detail"], 0.1); box((1.9, 0.6, 1.9), (0, 1.1, 0), M["Accent"], 0.08)
        lathe([(0.75, 1.4), (0.62, 3), (0.5, 13.5), (0.62, 14)], (0, 0, 0), M["Main"], 12)
        for y in (4, 8, 12): torus(1.15, 0.12, (0, y, 0), M["Accent"])
        cyl(1.6, 0.4, (0, 14.3, 0), M["Accent"], verts=12)
        for k in range(4):
            box((0.12, 2.4, 0.12), (math.cos(k * 1.57) * 0.62, 15.7, math.sin(k * 1.57) * 0.62), M["Accent"], 0)
        sphere(1.1, (0, 15.7, 0), M["Glow"], 12, 8)
        cyl(1.7, 1.0, (0, 17.4, 0), M["Accent"], d2=0.1, verts=12)
    return [("LandTree", tree), ("LandBridge", bridge), ("LandLollipop", lollipop), ("LandCoral", coral), ("LandMesa", mesa),
            ("LandIceSpire", ice_spire), ("LandBasalt", basalt), ("LandBamboo", bamboo), ("LandMoonRock", moon_rock),
            ("LandFlywheel", flywheel), ("LandStormCloud", storm_cloud), ("LandLotus", lotus), ("LandPixel", pixel),
            ("LandPlanet", planet), ("LandThrone", throne), ("LandHills", hills), ("LandGem", gem), ("LandBeacon", beacon)]


LAND = land_kit()


FINALE = [("FinaleComputer", finale_computer), ("FinaleNature", finale_nature), ("FinaleCity", finale_city)]


CORE = [("PrizeBall", prize_ball), ("CueShop", cue_shop), ("PoolTable", pool_table), ("Cue", cue), ("Ball", ball),
        ("Dumbbell", dumbbell), ("Fence", fence), ("TableSegment", table_segment), ("Ring", ring), ("GymSet", gym_set)]
PROPS = [("Mountain", lambda: mountain(3)), ("Peak", lambda: mountain(11)), ("Pine", pine), ("Tree", tree), ("Palm", palm),
         ("Cactus", cactus), ("Rock", rock), ("Dune", dune), ("Crystal", crystal), ("Volcano", volcano), ("Tower", tower),
         ("Planet", planet), ("Torii", torii), ("Pyramid", pyramid), ("Column", column), ("Mushroom", mushroom),
         ("Cloud", cloud), ("Star", star)]
ACCESSORIES = [("AccCap", acc_cap), ("AccFedora", acc_fedora), ("AccTopHat", acc_tophat), ("AccCrown", acc_crown),
               ("AccHorns", acc_horns), ("AccHalo", acc_halo), ("AccVisor", acc_visor), ("AccShades", acc_shades),
               ("AccTricorne", acc_tricorne), ("AccKabuto", acc_kabuto), ("AccBubble", acc_bubble), ("AccHood", acc_hood),
               ("AccNemes", acc_nemes), ("AccWings", acc_wings), ("AccCape", acc_cape)]
MODELS = CORE  # props/accessories are kept as functions but not exported (the map no longer uses them)


def join_triangulate(name):
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.convert(target="MESH")
    if len(bpy.context.selected_objects) > 1:
        bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    es = o.modifiers.new("Split", "EDGE_SPLIT")
    es.split_angle = math.radians(1 if name in ("Mountain", "Peak") else 35)
    tri = o.modifiers.new("Tri", "TRIANGULATE")
    bpy.ops.object.convert(target="MESH")
    return o


def luau_mesh(o):
    """Vertices are centred on the bounding box; `center` restores the model origin."""
    me = o.data
    verts = [(v.co.x, v.co.z, -v.co.y) for v in me.vertices]  # Blender -> Roblox
    lo = [min(v[i] for v in verts) for i in range(3)]
    hi = [max(v[i] for v in verts) for i in range(3)]
    ctr = [(a + b) / 2 for a, b in zip(lo, hi)]
    mats = [m for m in me.materials]
    pal = [m.name for m in mats]
    tris, cols = [], []
    for p in me.polygons:
        tris.extend(i + 1 for i in p.vertices)
        cols.append(p.material_index + 1)
    f = lambda x: f"{x:.3f}".rstrip("0").rstrip(".") if abs(x) >= 0.0005 else "0"
    flat = ",".join(f(v[i] - ctr[i]) for v in verts for i in range(3))
    palette = ", ".join(f'{{ "{n}", Color3.fromRGB({m["rgb"][0]}, {m["rgb"][1]}, {m["rgb"][2]}) }}' for n, m in zip(pal, mats))
    return (f'return {{\n\tcenter = Vector3.new({f(ctr[0])}, {f(ctr[1])}, {f(ctr[2])}),\n'
            f'\tsize = Vector3.new({f(hi[0] - lo[0])}, {f(hi[1] - lo[1])}, {f(hi[2] - lo[2])}),\n'
            f'\tpalette = {{ {palette} }},\n\tverts = {{ {flat} }},\n'
            f'\ttris = {{ {",".join(map(str, tris))} }},\n\tcolors = {{ {",".join(map(str, cols))} }},\n}}\n'), len(me.polygons)


def render_group(names, filename, cols, cell=12, dummy=False):
    """Preview sheet: every model normalised to one grid cell (accessories: real size on a dummy R15 body)."""
    reset()
    sc = bpy.context.scene
    rows = (len(names) + cols - 1) // cols
    skin, shirt = mat("Skin", (255, 210, 170)), mat("Shirt", (90, 140, 230))
    for k, name in enumerate(names):
        bpy.ops.import_scene.fbx(filepath=os.path.join(OUT, name + ".fbx"))
        o = bpy.context.selected_objects[0]
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        cx, cz = (k % cols - (cols - 1) / 2) * cell, -(k // cols - (rows - 1) / 2) * cell * (2.6 if dummy else 1.3)
        if dummy:  # head centre at y=4.5, UpperTorso centre at y=2.9 (Roblox R15 proportions)
            back = name in ("AccWings", "AccCape")
            o.location = (cx, 0, 2.9 if back else 4.5)
            o.location.z += cz
            box((1.2, 1.2, 1.2), (cx, 4.5 + cz, 0), skin, 0.25); box((2, 1.6, 1), (cx, 2.9 + cz, 0), shirt, 0.1)
            box((2, 2, 1), (cx, 1.1 + cz, 0), shirt, 0.1)
            continue
        dims = max(o.dimensions) or 1
        f = cell * 0.8 / dims
        o.scale = (f, f, f)
        lo = min((o.matrix_world @ v.co).z for v in o.data.vertices)
        o.location = (cx, cz, -lo * f)
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.8, 1, 1)
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sun.data.energy = 4
    sun.rotation_euler = (math.radians(45), 0, math.radians(30)); sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type, cam.data.ortho_scale = "ORTHO", max(cols, rows * 1.9) * cell * 1.05
    cam.location = (0, -200, 120); cam.rotation_euler = (math.radians(60), 0, 0)
    if dummy:  # front view (Roblox front = -Z = Blender +Y), slightly from the side
        cam.location = (0, 200, 4 + 200 * math.tan(math.radians(10))); cam.rotation_euler = (math.radians(80), 0, math.radians(180))
        cam.data.ortho_scale = max(cols * cell, rows * cell * 2.6 * 16 / 9) * 1.05
    sc.render.engine = "CYCLES"; sc.cycles.samples = 24
    sc.render.resolution_x, sc.render.resolution_y = 1600, 900
    sc.view_settings.view_transform = "Standard"
    sc.render.filepath = os.path.join(OUT, filename)
    bpy.ops.render.render(write_still=True)


def main():
    import sys
    if "theme" in sys.argv:  # themed hall kits (blender/themes.py); optional theme names after "theme"
        import themes
        sets = themes.kit(set(sys.argv[sys.argv.index("theme") + 1:]) or None)
    elif "finale" in sys.argv or "hall" in sys.argv or "land" in sys.argv:
        sets = FINALE if "finale" in sys.argv else HALL if "hall" in sys.argv else LAND
    if "theme" in sys.argv or "finale" in sys.argv or "hall" in sys.argv or "land" in sys.argv:  # only these sets, next to the existing meshes
        for name, fn in sets:
            reset()
            fn()
            o = join_triangulate(name)
            bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, name + ".fbx"), apply_unit_scale=True, axis_forward="-Z", axis_up="Y")
            text, n = luau_mesh(o)
            with open(os.path.join(LUAU_DIR, name + ".luau"), "w", encoding="utf-8") as fh:
                fh.write("-- AUTO-GENERATED by blender/build_models.py — do not edit by hand.\n"
                         "-- Roblox axes, studs; vertices centred on bbox, `center` = offset from the model origin.\n" + text)
            print(f"{name}: {n} triangles, {len(o.data.vertices)} vertices")
        return
    chunks = []
    for name, fn in MODELS:
        reset()
        fn()
        o = join_triangulate(name)
        bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, name + ".fbx"), apply_unit_scale=True, axis_forward="-Z", axis_up="Y")
        text, n = luau_mesh(o)
        chunks.append(text)
        print(f"{name}: {n} triangles")
    import shutil
    shutil.rmtree(LUAU_DIR, ignore_errors=True)
    os.makedirs(LUAU_DIR)
    for (name, _), text in zip(MODELS, chunks):
        with open(os.path.join(LUAU_DIR, name + ".luau"), "w", encoding="utf-8") as fh:
            fh.write("-- AUTO-GENERATED by blender/build_models.py — do not edit by hand.\n"
                     "-- Roblox axes, studs; vertices centred on bbox, `center` = offset from the model origin.\n" + text)
    render_group([n for n, _ in CORE], "models.png", 3)

if __name__ == "__main__":
    main()
