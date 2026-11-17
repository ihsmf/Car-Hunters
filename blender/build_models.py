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


def pool_table():
    M = {k: mat(k, P[k], 1 if k == "Gold" else 0, 0.3 if k in ("Gold", "Pearl") else 0.5) for k in ("Wood", "WoodDark", "Felt", "Cushion", "Gold", "Pocket", "Pearl", "White")}
    L, W = 16, 9
    box((W + 1.8, 1.5, L + 1.8), (0, 3.05, 0), M["Wood"], 0.3)
    box((W + 2.0, 0.25, L + 2.0), (0, 2.35, 0), M["Gold"], 0.1)
    box((W, 0.3, L), (0, 3.85, 0), M["Felt"], 0.02)
    for s in (-1, 1):
        box((1.1, 0.75, L + 2.2), (s * (W / 2 + 0.55), 4.2, 0), M["WoodDark"], 0.3)
        box((W + 2.2, 0.75, 1.1), (0, 4.2, s * (L / 2 + 0.55)), M["WoodDark"], 0.3)
        box((0.35, 0.4, L - 1.6), (s * (W / 2 - 0.1), 4.1, 0), M["Cushion"], 0.12)
        box((W - 1.6, 0.4, 0.35), (0, 4.1, s * (L / 2 - 0.1)), M["Cushion"], 0.12)
        for k in (-2, -1, 1, 2):
            sphere(0.28, (s * (W / 2 + 0.55), 4.6, k * 3.2), M["Pearl"], 8, 6, (1, 0.4, 1))
        for k in (-1, 1):
            sphere(0.28, (k * 2.4, 4.6, s * (L / 2 + 0.55)), M["Pearl"], 8, 6, (1, 0.4, 1))
        for t in (-1, 1):  # turned legs
            x, z = s * W / 2.4, t * L / 2.4
            cyl(1.3, 0.35, (x, 0.18, z), M["Gold"], verts=16)
            cyl(0.75, 1.3, (x, 1.0, z), M["WoodDark"], d2=1.05, verts=16)
            sphere(1.25, (x, 1.75, z), M["WoodDark"], 16, 8)
            cyl(1.05, 0.5, (x, 2.1, z), M["WoodDark"], verts=16)
        for t in (-1, 0, 1):  # pockets
            px, pz = s * (W / 2 + 0.1), t * (L / 2 + 0.1)
            cyl(1.25, 0.35, (px, 4.15, pz), M["Pocket"], verts=16, bevel=0)
            torus(1.35, 0.22, (px, 4.4, pz), M["Gold"])
    rack = [(0, 0)] + [(r, j) for r in range(1, 5) for j in range(r + 1)]
    for i, (r, j) in enumerate(rack):
        c = mat(f"Ball{i % 8}", BALL_COLORS[i % 8], rough=0.15)
        sphere(0.8, ((j - r / 2) * 0.82, 4.4, -3 - r * 0.72), c, 10, 6)
    sphere(0.8, (0, 4.4, 4.5), M["White"], 10, 6)


def cue():
    M = {k: mat(k, P[k], 1 if k == "Gold" else 0, 0.3) for k in ("Ebony", "Wrap", "Shaft", "Gold", "White", "Tip")}
    # centred: total length 9.2 (y -4.6 .. 4.6)
    sphere(0.5, (0, -4.55, 0), M["Ebony"], 12, 8)
    cyl(0.5, 4.2, (0, -2.45, 0), M["Ebony"], d2=0.38, verts=16)
    cyl(0.52, 1.2, (0, -3.5, 0), M["Wrap"], verts=16)
    for y in (-2.8, -0.45):
        cyl(0.46, 0.14, (0, y, 0), M["Gold"], verts=16)
    cyl(0.37, 4.3, (0, 1.8, 0), M["Shaft"], d2=0.22, verts=16)
    cyl(0.23, 0.3, (0, 4.1, 0), M["White"], verts=16)
    cyl(0.22, 0.15, (0, 4.32, 0), M["Tip"], verts=16)


def ball():
    body, white = mat("Body", P["Body"], rough=0.1), mat("White", P["White"], rough=0.1)
    sphere(1, (0, 0, 0), body, 24, 14)
    for z in (-0.47, 0.47):  # white number spots
        cyl(0.5, 0.08, (0, 0, z), white, "Z", verts=20, bevel=0)
        sphere(0.32, (0, 0, z * 1.04), white, 12, 6, (1, 1, 0.25))


def dumbbell():
    M = {k: mat(k, P[k], 1 if k == "Chrome" else 0, 0.25) for k in ("Chrome", "Plate", "Rubber", "White")}
    box((6.4, 0.4, 2.6), (0, -0.3, 0), M["Rubber"], 0.15)
    cyl(0.45, 5.4, (0, 0.9, 0), M["Chrome"], "X", verts=16)
    for s in (-1, 1):
        cyl(1.9, 0.5, (s * 2.0, 0.9, 0), M["Plate"], "X", verts=20, bevel=0.1)
        cyl(1.45, 0.4, (s * 1.6, 0.9, 0), M["Plate"], "X", verts=20, bevel=0.08)
        cyl(0.75, 0.3, (s * 2.42, 0.9, 0), M["Chrome"], "X", verts=20)
        torus(1.2, 0.14, (s * 2.27, 0.9, 0), M["White"], "X")
        sphere(0.6, (s * 2.7, 0.9, 0), M["Chrome"], 12, 8)


def fence():
    M = {k: mat(k, P[k]) for k in ("Rail", "Cap")}
    for i in range(5):  # posts at -12..12: adjacent 30-stud segments keep a 6-stud rhythm without doubled posts
        x = -12 + i * 6
        box((0.9, 4, 0.9), (x, 2, 0), M["Rail"], 0.15)
        sphere(1.2, (x, 4.3, 0), M["Cap"], 10, 6)
    for y in (1.5, 3.2):
        box((30, 0.55, 0.45), (0, y, 0), M["Rail"], 0.15)


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
    cyl(26, 0.06, (0, 1.39, 0), M["Felt"], verts=48, bevel=0)
    torus(27, 0.35, (0, 1.42, 0), M["Trim"])
    cyl(14.5, 0.08, (0, 1.4, 0), M["Inset"], verts=48, bevel=0)
    for k in range(8):  # brass spots where the characters stand
        a = math.radians(-150 + k * 300 / 7)
        x, z = math.sin(a) * 17, -math.cos(a) * 17
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
    for y in (2.2, 7.4):
        cyl(0.32, 9.4, (0, y, -2.9), M["Trim"], "X", verts=12)
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


CORE = [("BasePlatform", base_platform), ("CueShop", cue_shop), ("PoolTable", pool_table), ("Cue", cue), ("Ball", ball), ("Dumbbell", dumbbell), ("Fence", fence), ("TableSegment", table_segment)]
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

main()
