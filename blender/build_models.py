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
LUAU = os.path.join(HERE, "..", "src", "shared", "Meshes.luau")
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


MODELS = [("PoolTable", pool_table), ("Cue", cue), ("Ball", ball), ("Dumbbell", dumbbell), ("Fence", fence),
          ("Mountain", lambda: mountain(3)), ("Peak", lambda: mountain(11))]


def join_triangulate(name):
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.convert(target="MESH")
    if len(bpy.context.selected_objects) > 1:
        bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
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
    return (f'M.{o.name} = {{\n\tcenter = Vector3.new({f(ctr[0])}, {f(ctr[1])}, {f(ctr[2])}),\n'
            f'\tsize = Vector3.new({f(hi[0] - lo[0])}, {f(hi[1] - lo[1])}, {f(hi[2] - lo[2])}),\n'
            f'\tpalette = {{ {palette} }},\n\tverts = {{ {flat} }},\n'
            f'\ttris = {{ {",".join(map(str, tris))} }},\n\tcolors = {{ {",".join(map(str, cols))} }},\n}}\n'), len(me.polygons)


def render_preview(objs):
    sc = bpy.context.scene
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.75, 1, 1)
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sun.data.energy = 4
    sun.rotation_euler = (math.radians(50), 0, math.radians(35)); sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.location = (0, -40, 26); cam.rotation_euler = (math.radians(66), 0, 0)
    sc.render.engine = "CYCLES"; sc.cycles.samples = 32
    sc.render.resolution_x, sc.render.resolution_y = 1280, 720
    sc.view_settings.view_transform = "Standard"
    sc.render.filepath = os.path.join(OUT, "models.png")
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
    with open(LUAU, "w", encoding="utf-8") as fh:
        fh.write("-- AUTO-GENERATED by blender/build_models.py — do not edit by hand.\n"
                 "-- Roblox axes, studs; vertices centred on bbox, `center` = offset from the model origin.\nlocal M = {}\n\n"
                 + "\n".join(chunks) + "\nreturn M\n")
    reset()  # preview: re-import the exported models side by side
    objs = []
    for i, (name, _) in enumerate(MODELS):
        bpy.ops.import_scene.fbx(filepath=os.path.join(OUT, name + ".fbx"))
        o = bpy.context.selected_objects[0]
        o.location = {"PoolTable": (0, 0, 0), "Cue": (-11, -2, 4.6), "Ball": (10, -7, 1.5), "Dumbbell": (12, 3, 0.7), "Fence": (0, 13, 0),
                      "Mountain": (-26, 40, 0), "Peak": (26, 40, 0)}[name]
        if name == "Ball":
            o.scale = (3, 3, 3)
        if name in ("Mountain", "Peak"):
            o.scale = (30, 30, 34)
        objs.append(o)
    render_preview(objs)


main()
