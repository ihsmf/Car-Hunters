"""Promo trailer for the experience page (about 27 s, 1920x1080, 30 fps) -> docs/store/trailer.mp4 and trailer_still_<n>.png.

  python3 blender/make_trailer.py --shot N [--frames A-B] [--samples S]   render the frames of shot N (1..6) to TRAILER_TMP/shotN/
  python3 blender/make_trailer.py --compose                               add the text, upscale and encode the mp4 and stills
  python3 blender/make_trailer.py --all                                   all six shots, then compose

The models come from the game's own builders (make_cars, make_parts, make_spawn, make_city, make_garage). These scripts
export FBX files and rewrite ModelSizes.lua when they load, so load() runs them with export switched off, with the
scene reset made a no-op after the first one, and with every file write outside TRAILER_TMP sent to a scratch file.
The repo stays untouched. Rendering uses Cycles on the CPU at 960x540 (EEVEE needs a GL context), upscaled to 1080p
in --compose. The text is drawn there with PIL."""
import builtins, math, os, random, runpy, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
STORE = os.path.join(ROOT, "docs", "store")
TMP = os.path.abspath(os.environ.get("TRAILER_TMP") or os.path.join(tempfile.gettempdir(), "car_hunters_trailer"))
FPS, SHOT_LEN, NSHOTS = 30, 135, 6
RX, RY = 960, 540
TEXT = {1: "GRAB CAR PARTS", 2: "DODGE THE TRAFFIC", 3: "CATCH 80 CARS", 4: "COMMON TO LEGENDARY", 5: "BEAT THE BOSSES"}
STILLS = {1: (1, 80), 2: (4, 120), 3: (6, 100)}  # still n -> (shot, frame in shot)


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


# ================================================================ scene building (bpy)
def blender_setup():
    global bpy, Vector, mc
    sys.path.insert(0, HERE)
    import bpy
    from mathutils import Vector
    import make_cars as mc
    os.makedirs(TMP, exist_ok=True)
    mc.reset()  # the one real factory reset
    mc.export = lambda *a, **k: None  # never write FBX files
    mc.reset = lambda: mc.MATS.clear()  # builders add to the same scene; looks are re-made per builder
    lib = bpy.data.collections.new("lib")
    bpy.context.scene.collection.children.link(lib)
    bpy.context.view_layer.layer_collection.children["lib"].exclude = True


def load(script):
    """run a builder script, return {model name: root}. Its models are moved to the excluded 'lib' collection."""
    real_open = builtins.open

    def guarded(file, mode="r", *a, **k):
        if isinstance(file, (str, bytes, os.PathLike)) and any(c in mode for c in "wax+"):
            p = os.path.abspath(os.fsdecode(file))
            if not p.startswith(TMP):
                file = os.path.join(TMP, "discard_" + os.path.basename(p))
        return real_open(file, mode, *a, **k)

    saved = sys.argv
    sys.argv = [script]
    builtins.open = guarded
    try:
        ns = runpy.run_path(os.path.join(HERE, script))
    finally:
        builtins.open = real_open
        sys.argv = saved
    out = {}
    for r in ns["roots"]:
        r.location, r.rotation_euler = (0, 0, 0), (0, 0, 0)
        to_lib(r)
        out[r.name] = r
    return out


def to_lib(root):
    lib = bpy.data.collections["lib"]
    for o in [root] + list(root.children_recursive):
        for c in list(o.users_collection):
            c.objects.unlink(o)
        lib.objects.link(o)


def link(o):
    bpy.context.scene.collection.objects.link(o)
    return o


def inst(root, loc=(0, 0, 0), rz=0.0, s=1.0, name=None):
    """a visible copy of a library model (mesh data shared)"""
    e = link(bpy.data.objects.new(name or root.name + "_i", None))

    def cp(src, parent):
        for c in src.children:
            o = link(c.copy())
            o.parent = parent
            o.matrix_parent_inverse = c.matrix_parent_inverse.copy()
            o.hide_render = o.hide_viewport = False
            cp(c, o)

    cp(root, e)
    e.location, e.rotation_euler, e.scale = loc, (0, 0, rz), (s, s, s)
    return e


def car(cid, color=None, design=None, low=False, over=None, dims=None):
    """build a car with make_cars.build_car, keep it as a library model"""
    r = mc.build_car(cid, design or cid, color=color, low=low, over=over, dims=dims)
    r.name = "car_" + cid
    to_lib(r)
    return r


def bounds(root):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in root.children_recursive if o.type == "MESH" for c in o.bound_box]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    return lo, hi


def material(name, color, metal=0.0, rough=0.5, emit=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = color
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = color
        b.inputs["Emission Strength"].default_value = emit
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
    return m


def slab(name, x0, x1, y0, y1, z0, z1, m):
    bpy.ops.mesh.primitive_cube_add(size=1, location=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    o = bpy.context.active_object
    o.name = name
    o.scale = (x1 - x0, y1 - y0, z1 - z0)
    o.data.materials.append(m)
    return o


def disc(name, loc, r, h, m, verts=64):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(m)
    return o


def ring(name, loc, R, r, m):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=64, minor_segments=10, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(m)
    return o


def render_setup(samples):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    cy = sc.cycles
    cy.device = "CPU"
    cy.samples = samples
    cy.use_adaptive_sampling = True
    cy.adaptive_threshold = 0.05
    cy.denoising_quality, cy.denoising_prefilter = "BALANCED", "FAST"  # ACCURATE/HIGH costs ~5 s a frame on 4 CPUs
    cy.use_denoising = True
    cy.denoiser = "OPENIMAGEDENOISE"
    cy.max_bounces, cy.diffuse_bounces, cy.glossy_bounces = 4, 2, 2
    cy.transmission_bounces, cy.volume_bounces, cy.transparent_max_bounces = 2, 0, 4
    cy.caustics_reflective = cy.caustics_refractive = False
    cy.blur_glossy = 1.0
    sc.render.use_persistent_data = True
    sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = RX, RY, 100
    sc.render.fps = FPS
    sc.render.image_settings.file_format = "PNG"
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Punchy"
    sc.view_settings.exposure = 0.25
    return sc


def sky(top=(0.04, 0.28, 1.0, 1), horizon=(0.7, 0.88, 1.0, 1), strength=1.2):
    w = bpy.data.worlds.new("sky")
    w.use_nodes = True
    nt = w.node_tree
    bg = nt.nodes["Background"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[0].color = 0.0, horizon
    ramp.color_ramp.elements[1].position, ramp.color_ramp.elements[1].color = 0.5, top
    nt.links.new(tc.outputs["Window"], sep.inputs[0])  # the gradient follows the screen: horizon low, deep blue high
    nt.links.new(sep.outputs["Y"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = strength
    bpy.context.scene.world = w


def sun(energy=4.0, rot=(50, 0, 140), color=(1.0, 0.95, 0.85)):
    l = bpy.data.lights.new("sun", "SUN")
    l.energy, l.angle, l.color = energy, math.radians(2), color
    o = link(bpy.data.objects.new("sun", l))
    o.rotation_euler = tuple(math.radians(a) for a in rot)
    return o


def camera(lens=35, fstop=None):
    cam = bpy.data.cameras.new("cam")
    cam.lens = lens
    cam.clip_end = 3000
    if fstop:
        cam.dof.use_dof = True
        cam.dof.aperture_fstop = fstop
    co = link(bpy.data.objects.new("cam", cam))
    bpy.context.scene.camera = co
    return co


def aim(co, loc, target, f, focus=None):
    co.location = loc
    co.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    co.keyframe_insert("location", frame=f)
    co.keyframe_insert("rotation_euler", frame=f)
    if co.data.dof.use_dof:
        co.data.dof.focus_distance = (Vector(focus or target) - Vector(loc)).length
        co.data.dof.keyframe_insert("focus_distance", frame=f)


def key(o, f, loc=None, rz=None, rot=None):
    if loc is not None:
        o.location = loc
        o.keyframe_insert("location", frame=f)
    if rz is not None:
        o.rotation_euler = (o.rotation_euler[0], o.rotation_euler[1], rz)
        o.keyframe_insert("rotation_euler", frame=f)
    if rot is not None:
        o.rotation_euler = rot
        o.keyframe_insert("rotation_euler", frame=f)


def beam_material(color, strength=1.6, fac=0.14):
    m = bpy.data.materials.new("beam")
    m.use_nodes = True
    nt = m.node_tree
    for nd in list(nt.nodes):
        if nd.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(nd)
    out = next(nd for nd in nt.nodes if nd.type == "OUTPUT_MATERIAL")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = color
    em.inputs["Strength"].default_value = strength
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs["Fac"].default_value = fac
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return m


PCOL = [(0.25, 0.9, 1.0, 1), (1.0, 0.8, 0.2, 1), (0.3, 1.0, 0.5, 1), (1.0, 0.35, 0.8, 1)]


def glow_part(root, loc, s, color=(0.25, 0.9, 1.0, 1)):
    """a pickup as it looks in game: the part, a glowing ring under it, a soft halo and a light"""
    p = inst(root, loc, s=s)
    lo, hi = bounds(p)
    ctr = (lo + hi) / 2
    rad = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z) * 0.5
    beam_m = beam_material(color)
    ring_m = material("ring", color, emit=12.0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=rad * 0.75, depth=18, location=(loc[0], loc[1], 0.7 + 9), end_fill_type="NOTHING")
    halo = bpy.context.active_object  # light beam rising from the pickup ring, as in game
    halo.data.materials.append(beam_m)
    halo.visible_shadow = False
    rg = ring("ring", (loc[0], loc[1], 0.75), rad * 0.85, 0.16 * s, ring_m)
    rg.visible_shadow = False
    rg.visible_camera = True
    l = bpy.data.lights.new("pl", "POINT")
    l.energy, l.color, l.shadow_soft_size = 600 * s, color[:3], 1.0
    lo_ = link(bpy.data.objects.new("pl", l))
    lo_.location = ctr
    # part, halo and light bob together; the part also spins
    piv = link(bpy.data.objects.new("bob", None))
    piv.location = (0, 0, 0)
    lo_.parent = piv
    # the part spins about its own centre: offset under a spin empty
    spin = link(bpy.data.objects.new("spin", None))
    spin.location = ctr
    p.location = Vector(loc) - ctr
    p.parent = spin
    spin.parent = piv
    return piv, spin, rg


def animate_pickup(piv, spin, f0, f1, phase=0.0, rate=0.06):
    for f in range(f0, f1 + 1):
        t = f + phase * 40
        key(piv, f, loc=(0, 0, 0.6 * math.sin(t * 0.09)))
        key(spin, f, rot=(0.25 * math.sin(t * 0.05), 0, t * rate))


# ---------------------------------------------------------------- city street (shots 1, 2)
def city_street(city, frames, traffic_lanes=True):
    road = material("asphalt", (0.16, 0.165, 0.18, 1), rough=0.8)
    walk = material("sidewalk", (0.72, 0.70, 0.66, 1), rough=0.8)
    curb = material("curb", (0.85, 0.84, 0.8, 1), rough=0.6)
    paint = material("paint", (0.95, 0.95, 0.92, 1), rough=0.5)
    yellow = material("yellowline", (1.0, 0.75, 0.1, 1), rough=0.5)
    grass = material("grass", (0.25, 0.55, 0.2, 1), rough=0.9)
    slab("road", -600, 600, -14, 14, -0.2, 0, road)
    slab("grass", -600, 600, -400, 400, -0.5, -0.25, grass)
    for s in (-1, 1):
        slab("walk", -600, 600, *sorted((s * 14.4, s * (34 if s > 0 else 90))), -0.2, 0.6, walk)
        slab("curb", -600, 600, *sorted((s * 14, s * 14.6)), -0.2, 0.7, curb)
    slab("yl1", -600, 600, -0.45, -0.15, 0, 0.03, yellow)
    slab("yl2", -600, 600, 0.15, 0.45, 0, 0.03, yellow)
    for x in range(-600, 600, 16):
        for s in (-1, 1):
            slab("dash", x, x + 8, s * 7.15 - 0.15, s * 7.15 + 0.15, 0, 0.03, paint)
    # far side: a row of buildings (front = +Y, turn them to face the street at -Y)
    names = ["B_shop", "B_apartment", "B_cafe", "B_tower", "B_dealership", "B_shop", "B_neontower", "B_cafe", "B_apartment",
             "B_motel", "B_tower", "B_house", "B_shop", "B_apartment"]
    x = -260
    i = 0
    while x < 260:
        r = city[names[i % len(names)]]
        lo, hi = bounds(r)
        w, d = hi.x - lo.x, hi.y - lo.y
        b = inst(r, (x + w / 2 + (lo.x + hi.x) / 2, 36 + hi.y, 0.6), rz=math.pi)
        x += w + 3
        i += 1
    for x in range(-260, 260, 32):
        inst(city["Tree"], (x + 8, 30, 0.6))
        inst(city["LampA"], (x - 6, 16.5, 0.6), rz=math.pi)
    inst(city["TrafficLight"], (40, -16.5, 0.6))
    inst(city["BusStop"], (-70, 22, 0.6), rz=math.pi)
    inst(city["Bin"], (-30, -17, 0.6))
    inst(city["Tree"], (-90, -26, 0.6))
    inst(city["Tree"], (95, -26, 0.6))
    # near side back: a low fence of bushes so the far ground isn't empty when the camera looks along the street
    if not traffic_lanes:
        return
    # traffic: every kind from make_cars.TRAFFIC, in bright paints
    paints = [(0.9, 0.1, 0.08, 1), (0.05, 0.35, 0.95, 1), (1.0, 0.75, 0.05, 1), (0.95, 0.95, 0.95, 1), (0.1, 0.75, 0.3, 1),
              (1.0, 0.4, 0.05, 1), (0.6, 0.15, 0.85, 1), (0.08, 0.7, 0.8, 1)]
    kinds = ["compact", "sedan", "taxi", "van", "sport", "supercar", "pickup", "service", "truck", "proto"]
    lib = [car(k + str(i), color=paints[i % len(paints)], design=mc.TRAFFIC[k][0], low=True, over=mc.TRAFFIC[k][1], dims=k)
           for i, k in enumerate(kinds)]
    rnd = random.Random(7)
    f0, f1 = frames
    n = f1 - f0
    for lane, (y, d) in enumerate(((-7.2, 1), (7.2, -1))):
        v = 2.3 if lane == 0 else 2.0  # studs per frame (about 65 studs/s)
        gap = 46
        count = int((n * v + 520) / gap) + 1
        for k in range(count):
            r = lib[(k * 3 + lane * 5) % len(lib)]
            c = inst(r, rz=0 if d > 0 else math.pi)
            start = -d * (260 + k * gap + rnd.uniform(-8, 8)) + d * 120
            key(c, f0, loc=(start, y, 0))
            key(c, f1, loc=(start + d * v * n, y, 0))


def linear_all():
    for a in bpy.data.actions:
        try:
            fcs = a.fcurves
        except AttributeError:
            fcs = [fc for layer in a.layers for strip in layer.strips for cb in strip.channelbags for fc in cb.fcurves]
        for fc in fcs:
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"


# ================================================================ the shots (frames 1..135 each)
def shot1(sc):
    city = load("make_city.py")
    parts = load("make_parts.py")
    city_street(city, (1, SHOT_LEN))
    sky()
    sun(4.2, (48, 0, 150))
    picks = [("Part_turbo", -12, 1.5), ("Part_bolts", 6, 1.6), ("Part_core", 24, 1.5), ("Part_gearbox", 42, 1.4), ("Part_engine", -30, 1.2)]
    for i, (n, x, s) in enumerate(picks):
        piv, spin, rg = glow_part(parts[n], (x, -23, 4.2), s, color=PCOL[i % len(PCOL)])
        animate_pickup(piv, spin, 1, SHOT_LEN, phase=i * 0.7)
    co = camera(30, fstop=8)
    for f in range(1, SHOT_LEN + 1):
        t = ease((f - 1) / (SHOT_LEN - 1))
        x = -30 + 30 * t
        aim(co, (x, -46, 7.0), (x + 6, 0, 4.0), f, focus=(x + 6, -23, 4))


def shot2(sc):
    city = load("make_city.py")
    parts = load("make_parts.py")
    city_street(city, (1, SHOT_LEN))
    sky()
    sun(4.2, (48, 0, 150))
    piv, spin, rg = glow_part(parts["Part_turbo"], (0, -22, 2.4), 2.3)
    animate_pickup(piv, spin, 1, SHOT_LEN, rate=0.045)
    piv2, spin2, _ = glow_part(parts["Part_core"], (16, -19, 3.0), 1.5, color=(0.3, 1.0, 0.6, 1))
    animate_pickup(piv2, spin2, 1, SHOT_LEN, phase=1.3)
    piv3, spin3, _ = glow_part(parts["Part_bolts"], (-17, -18, 3.0), 1.4, color=(1.0, 0.8, 0.2, 1))
    animate_pickup(piv3, spin3, 1, SHOT_LEN, phase=2.1)
    co = camera(32, fstop=2.0)
    for f in range(1, SHOT_LEN + 1):
        t = ease((f - 1) / (SHOT_LEN - 1))
        a = math.radians(-125 + 45 * t)
        R = 19 - 6 * t
        aim(co, (R * math.cos(a), -22 + R * math.sin(a), 2.4 + 0.6 * t), (0, -19, 6.2), f, focus=(0, -22, 5.0))


def shot3(sc):
    gar = load("make_garage.py")
    sky()
    sun(4.0, (40, 0, 205))  # sun from outside the doors (+X), shining in
    floor = material("floor", (0.55, 0.56, 0.58, 1), rough=0.35)
    wall = material("wall", (0.86, 0.84, 0.8, 1), rough=0.8)
    trim = material("walltrim", (0.15, 0.4, 0.85, 1), rough=0.5)
    yel = material("bayline", (1.0, 0.78, 0.1, 1), rough=0.5)
    out = material("apron", (0.3, 0.31, 0.33, 1), rough=0.8)
    grass = material("grass", (0.3, 0.6, 0.22, 1), rough=0.9)
    slab("floor", -24, 20, -30, 30, -0.3, 0, floor)
    slab("apron", 20, 120, -30, 30, -0.35, -0.02, out)
    slab("grass", -300, 300, -300, 300, -0.6, -0.3, grass)
    X0, X1, Y, H = -24, 20, 30, 34
    slab("backwall", X0 - 1, X0, -Y, Y, 0, H, wall)
    slab("backstripe", X0 - 0.02, X0 + 0.02, -Y, Y, 1.2, 2.6, trim)
    for s in (-1, 1):
        slab("sidewall", X0 - 1, X1 + 1, *sorted((s * Y, s * (Y + 1))), 0, H, wall)
    doors = (-15, 0, 15)
    edges = [-Y] + [y + d for y in doors for d in (-7.3, 7.3)] + [Y]
    for a, b in zip(edges[0::2], edges[1::2]):
        slab("frontwall", X1, X1 + 1, a, b, 0, H, wall)
    slab("frontwall_top", X1, X1 + 1, -Y, Y, 13.4, H, wall)
    for y in doors:
        inst(gar["G_RollerDoor"], (X1 + 0.5, y, 0))
        for s in (-1, 1):
            slab("bayline", -16, X1, y + s * 7.2 - 0.25, y + s * 7.2 + 0.25, 0, 0.03, yel)
    # back wall: tool wall, workbench, cabinet, drums; side: tire rack, lift
    # side wall (y = +Y) facing the camera: tool wall over the workbench, tool cabinet, lamps, drums, lift in the back corner
    S = -math.pi / 2  # model front +X -> -Y
    inst(gar["G_Pegboard"], (-2, Y - 0.3, 0), rz=S)
    inst(gar["G_Workbench"], (-2, Y - 1.8, 0), rz=S)
    inst(gar["G_ToolCabinet"], (9, Y - 1.6, 0), rz=S)
    inst(gar["G_WallLamp"], (-12, Y - 0.2, 9), rz=S)
    inst(gar["G_WallLamp"], (8, Y - 0.2, 9), rz=S)
    inst(gar["G_OilDrum"], (15, Y - 2.2, 0))
    inst(gar["G_OilDrum"], (16.5, Y - 4.2, 0))
    inst(gar["G_LiftCab"], (X0 + 5, Y - 5, 0), rz=math.pi / 2)
    inst(gar["G_TireRack"], (X0 + 1.5, -6, 0))
    slab("sidestripe", X0, X1, Y - 0.02, Y + 0.02, 1.2, 2.6, trim)
    # soft interior fill so the back of the room isn't in the dark
    l = bpy.data.lights.new("fill", "AREA")
    l.energy, l.size, l.color = 9000, 30, (1.0, 0.97, 0.92)
    fo = link(bpy.data.objects.new("fill", l))
    fo.location = (-2, 0, H + 6)
    # the car rolls in through the middle door and eases to a stop in its bay
    lib = car("chevy_kamaro")
    c = inst(lib, rz=math.pi)
    for f in range(1, SHOT_LEN + 1):
        t = ease(min(1.0, (f - 1) / 105))
        key(c, f, loc=(70 - 72 * (1 - (1 - t) ** 1.6) - 0 * t, 0, 0))
    co = camera(24)
    for f in range(1, SHOT_LEN + 1):
        t = ease((f - 1) / (SHOT_LEN - 1))
        aim(co, lerp((-14, -27, 13), (-9, -22, 10), t), lerp((10, 10, 5), (2, 8, 4), t), f)


RARITY = [((0.75, 0.77, 0.8, 1), "furd_fiasta", None), ((0.1, 0.45, 1.0, 1), "bmv_m4", (0.05, 0.3, 0.95, 1)),
          ((0.65, 0.2, 1.0, 1), "awdi_r8", (0.4, 0.08, 0.75, 1)), ((1.0, 0.72, 0.1, 1), "lamborgini_aventadoor", (1.0, 0.55, 0.06, 1))]


def gold_up(root):
    for o in root.children_recursive:
        if o.type == "MESH":
            for m in o.data.materials:
                if m and m.name.startswith("Body"):
                    b = m.node_tree.nodes["Principled BSDF"]
                    b.inputs["Metallic"].default_value = 0.9
                    b.inputs["Roughness"].default_value = 0.28


def turntable(loc, color, r=9.0):
    base = material("tt_base", (0.12, 0.13, 0.16, 1), metal=0.6, rough=0.3)
    top = material("tt_top", (0.9, 0.9, 0.92, 1), rough=0.35)
    glow = material("tt_glow", color, emit=10.0)
    disc("tt_base", (loc[0], loc[1], 0.35), r + 0.4, 0.7, base)
    t = disc("tt_top", (loc[0], loc[1], 0.85), r, 0.3, top)
    ring("tt_ring", (loc[0], loc[1], 0.72), r + 0.25, 0.38, glow)
    return t


def shot4(sc):
    city = load("make_city.py")
    sky()
    sun(4.0, (50, 0, 160))
    fl = material("plaza", (0.86, 0.86, 0.84, 1), rough=0.4)
    tile = material("plazaline", (0.7, 0.72, 0.74, 1), rough=0.5)
    slab("plaza", -400, 400, -400, 400, -0.3, 0, fl)
    for x in range(-200, 200, 12):
        slab("tl", x, x + 0.25, -200, 200, 0, 0.01, tile)
    for y in range(-200, 200, 12):
        slab("tl", -200, 200, y, y + 0.25, 0, 0.01, tile)
    for i, n in enumerate(["B_dealership", "B_tower", "B_apartment", "B_neontower", "B_tower", "B_shop", "B_apartment"]):
        r = city[n]
        inst(r, (-120 + i * 45, 120, 0), rz=math.pi)
    for x in range(-100, 160, 30):
        inst(city["Palm"], (x, 40, 0))
    spinners = []
    for i, (col, cid, paint) in enumerate(RARITY):
        x = i * 22
        turntable((x, 0, 0), col)
        lib = car(cid, color=paint)
        if i == 3:
            gold_up(lib)
        c = inst(lib, (x, 0, 1.0))
        spinners.append(c)
    for f in range(1, SHOT_LEN + 1):
        for i, c in enumerate(spinners):
            key(c, f, rz=math.radians(-30 + i * 25 + f * 1.4))
    co = camera(30, fstop=8)
    for f in range(1, SHOT_LEN + 1):
        t = ease((f - 1) / (SHOT_LEN - 1))
        x = 8 + 50 * t
        aim(co, (x - 22, -46 + 12 * t, 10 - 3 * t), (x + 2, 0, 2.0), f, focus=(x + 4, 0, 2))


def shot5(sc):
    spawn = load("make_spawn.py")
    city = load("make_city.py")
    sky((0.35, 0.55, 0.85, 1), (1.0, 0.82, 0.6, 1), 1.0)
    sun(4.5, (58, 0, 120), (1.0, 0.88, 0.7))
    dirt = bpy.data.materials.new("dirt")
    dirt.use_nodes = True
    nt = dirt.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.95
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 0.08
    nz.inputs["Detail"].default_value = 6
    rmp = nt.nodes.new("ShaderNodeValToRGB")
    rmp.color_ramp.elements[0].color = (0.45, 0.3, 0.16, 1)
    rmp.color_ramp.elements[1].color = (0.78, 0.6, 0.38, 1)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    nt.links.new(nz.outputs["Fac"], rmp.inputs["Fac"])
    nt.links.new(rmp.outputs["Color"], b.inputs["Base Color"])
    bpy.ops.mesh.primitive_plane_add(size=800, location=(0, 0, 0))
    g = bpy.context.active_object
    g.data.materials.append(dirt)
    # arena ring: barriers, barrels and tyres; grandstands behind; a dirt mound
    R = 46
    for k in range(40):
        a = 2 * math.pi * k / 40
        inst(city["Barrier"], (R * math.cos(a), R * math.sin(a), 0), rz=a + math.pi / 2)
    for k in range(14):
        a = 2 * math.pi * (k + 0.5) / 14
        inst(city["Barrel"], ((R - 3) * math.cos(a), (R - 3) * math.sin(a), 0))
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.3
        inst(spawn["Grandstand"], ((R + 22) * math.cos(a), (R + 22) * math.sin(a), 0), rz=a + math.pi / 2)
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.1
        inst(spawn["StreetLamp"], ((R + 6) * math.cos(a), (R + 6) * math.sin(a), 0))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=10, location=(-20, 16, -7.5))
    bpy.context.active_object.data.materials.append(dirt)
    mt = inst(spawn["MonsterTruck"])
    for f in range(1, SHOT_LEN + 1):
        key(mt, f, loc=(0, 0, 0.25 * abs(math.sin(f * 0.18))), rot=(0, 0.02 * math.sin(f * 0.18), math.radians(-20)))
    co = camera(28)
    for f in range(1, SHOT_LEN + 1):
        t = ease((f - 1) / (SHOT_LEN - 1))
        a = math.radians(-125 + 110 * t)
        R2 = 36 - 6 * t
        aim(co, (R2 * math.cos(a), R2 * math.sin(a), 2.2 + 1.5 * t), (0, 0, 7.5), f)


def shot6(sc):
    city = load("make_city.py")
    sky()
    sun(4.0, (45, 0, 200))
    fl = material("plaza", (0.86, 0.86, 0.84, 1), rough=0.3)
    slab("plaza", -400, 400, -400, 400, -0.3, 0, fl)
    for i, n in enumerate(["B_tower", "B_neontower", "B_apartment", "B_tower", "B_dealership", "B_tower", "B_neontower"]):
        a = math.radians(-60 + i * 30 + 90)
        inst(city[n], (110 * math.cos(a), 110 * math.sin(a), 0), rz=a + math.pi / 2)
    for k in range(10):
        a = math.radians(30 + k * 12)
        inst(city["Palm"], (45 * math.cos(a), 45 * math.sin(a), 0))
    turntable((0, 0, 0), (1.0, 0.72, 0.1, 1), r=10)
    col, cid, paint = RARITY[-1]
    lib = car(cid, color=paint)
    gold_up(lib)
    c = inst(lib, (0, 0, 1.0))
    for f in range(1, SHOT_LEN + 1):
        key(c, f, rz=math.radians(200 + f * 0.6))
    co = camera(30, fstop=4)
    for f in range(1, SHOT_LEN + 1):
        t = ease((f - 1) / (SHOT_LEN - 1))
        a = math.radians(-100 + 25 * t)
        aim(co, (27 * math.cos(a), 27 * math.sin(a), 4.5), (0, 0, 7.5 - t), f, focus=(0, 0, 2))


def merge_static():
    """join every mesh that never moves into one object per material group, so each frame syncs a few objects, not thousands"""
    sc = bpy.context.scene
    lib = bpy.data.collections["lib"]

    def moving(o):
        while o:
            if o.animation_data and o.animation_data.action:
                return True
            o = o.parent
        return False

    stat = [o for o in sc.objects if o.type == "MESH" and lib not in o.users_collection and not moving(o)
            and o.visible_shadow and o.visible_camera]
    for o in stat:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
        o.data = o.data.copy()
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in stat:
        o.select_set(True)
    if len(stat) > 1:
        bpy.context.view_layer.objects.active = stat[0]
        bpy.ops.object.join()
    print("merged", len(stat), "static meshes", flush=True)


def render_shot(n, frames, samples):
    blender_setup()
    sc = render_setup(samples)
    globals()["shot%d" % n](sc)
    linear_all()
    merge_static()
    out = os.path.join(TMP, "shot%d" % n)
    os.makedirs(out, exist_ok=True)
    sc.frame_start, sc.frame_end = frames
    sc.render.filepath = os.path.join(out, "####")
    sc.render.use_file_extension = True
    bpy.ops.render.render(animation=True)


# ================================================================ text + encode (PIL, ffmpeg)
FONTS = ("/usr/share/fonts/opentype/inter/InterDisplay-Black.otf", "/usr/share/fonts/opentype/inter/Inter-Black.otf",
         "/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")
INK = (22, 24, 34)
W, H = 1920, 1080
SAFE = (W * 0.1, H * 0.1, W * 0.9, H * 0.9)


def text_layer(text, size, top, bottom, maxw):
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
    font_path = next(f for f in FONTS if os.path.exists(f))
    while True:
        font = ImageFont.truetype(font_path, size)
        stroke = max(5, size // 8)
        l, t, r, b = font.getbbox(text, stroke_width=stroke)
        if r - l + 40 <= maxw or size < 40:
            break
        size -= 4
    pad = 30
    w, h = r - l + 2 * pad, b - t + 2 * pad
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((pad - l + size // 24, pad - t + size // 14), text, font=font, fill=(0, 0, 0, 170), stroke_width=stroke, stroke_fill=(0, 0, 0, 170))
    layer.alpha_composite(sh.filter(ImageFilter.GaussianBlur(max(2, size // 28))))
    ImageDraw.Draw(layer).text((pad - l, pad - t), text, font=font, fill=INK, stroke_width=stroke, stroke_fill=INK)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text((pad - l, pad - t), text, font=font, fill=255)
    grad = Image.new("RGBA", (w, h))
    gd = ImageDraw.Draw(grad)
    for y in range(h):
        a = min(1.0, max(0.0, (y - pad) / max(1, h - 2 * pad)))
        gd.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * a) for i in range(3)) + (255,))
    layer.paste(grad, (0, 0), mask)
    return layer


def place(img, layer, cx, cy, scale=1.0, alpha=1.0, angle=0.0):
    from PIL import Image
    L = layer
    if angle:
        L = L.rotate(angle, resample=Image.BICUBIC, expand=True)
    if abs(scale - 1.0) > 1e-3:
        L = L.resize((max(1, int(L.width * scale)), max(1, int(L.height * scale))), Image.LANCZOS)
    if alpha < 1:
        a = L.getchannel("A").point(lambda v: int(v * alpha))
        L.putalpha(a)
    x, y = int(cx - L.width / 2), int(cy - L.height / 2)
    img.alpha_composite(L, (x, y))
    return x, y, x + L.width, y + L.height


def check_safe(box, what):
    # the layer has a 30 px transparent pad; the glyphs themselves must stay inside the centre 80%
    x0, y0, x1, y1 = box[0] + 25, box[1] + 25, box[2] - 25, box[3] - 25
    assert x0 >= SAFE[0] and y0 >= SAFE[1] and x1 <= SAFE[2] and y1 <= SAFE[3], (what, box, SAFE)


def pop(i, start=4, dur=9):
    """scale for a pop-in: 0.55 -> 1.08 -> 1.0"""
    t = (i - start) / dur
    if t <= 0:
        return 0.0
    if t >= 1:
        return 1.0
    return 0.55 + 0.53 * math.sin(t * math.pi * 0.62) / math.sin(math.pi * 0.62) - 0.08 * max(0, (t - 0.62) / 0.38)


def compose():
    from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
    os.makedirs(STORE, exist_ok=True)
    layers = {n: text_layer(t, 128, (255, 255, 255), (255, 236, 150), 1450) for n, t in TEXT.items()}
    title = text_layer("CAR HUNTERS", 240, (255, 240, 110), (255, 150, 20), 1480)
    play = text_layer("PLAY NOW", 120, (255, 255, 255), (190, 230, 255), 900)
    # vignette and a bottom shade for the caption band
    vig = Image.new("L", (W, H), 0)
    ImageDraw.Draw(vig).ellipse((-W * 0.3, -H * 0.3, W * 1.3, H * 1.3), fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(160))
    dark = Image.new("RGBA", (W, H), (0, 0, 0, 120))
    vignette = Image.composite(Image.new("RGBA", (W, H), (0, 0, 0, 0)), dark, vig)
    rnd = random.Random(3)
    dust = [(rnd.uniform(0, W), rnd.uniform(H * 0.45, H), rnd.uniform(60, 220), rnd.uniform(-3, 3)) for _ in range(26)]
    mp4 = os.path.join(STORE, "trailer.mp4")
    ff = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS),
                           "-i", "-", "-an", "-c:v", "libx264", "-preset", "slow", "-crf", "19", "-pix_fmt", "yuv420p",
                           "-profile:v", "high", "-movflags", "+faststart", mp4], stdin=subprocess.PIPE)
    stills = {v: k for k, v in STILLS.items()}
    for n in range(1, NSHOTS + 1):
        for i in range(1, SHOT_LEN + 1):
            src = os.path.join(TMP, "shot%d" % n, "%04d.png" % i)
            img = Image.open(src).convert("RGB").resize((W, H), Image.LANCZOS)
            img = ImageEnhance.Sharpness(img).enhance(1.35).convert("RGBA")
            if n == 5:  # dust haze drifting across the arena floor
                haze = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                hd = ImageDraw.Draw(haze)
                for (x, y, r, vx) in dust:
                    xx = (x + vx * i * 3) % (W + 400) - 200
                    hd.ellipse((xx - r * 1.6, y - r * 0.6, xx + r * 1.6, y + r * 0.6), fill=(235, 200, 150, 38))
                haze = haze.filter(ImageFilter.GaussianBlur(40))
                grad = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                gd = ImageDraw.Draw(grad)
                for y in range(H // 2, H):
                    gd.line([(0, y), (W, y)], fill=(230, 190, 140, int(70 * (y - H / 2) / (H / 2))))
                img.alpha_composite(grad)
                img.alpha_composite(haze)
            img.alpha_composite(vignette)
            if n in TEXT:
                s = pop(i)
                fade = min(1.0, (SHOT_LEN - i) / 6)
                if s > 0:
                    box = place(img, layers[n], W / 2, H * 0.80, scale=s, alpha=max(0.0, fade), angle=-3)
                    if s == 1.0:
                        check_safe(box, TEXT[n])
            else:  # end card
                s = pop(i, 3, 10)
                if s > 0:
                    box = place(img, title, W / 2, H * 0.31, scale=s, angle=-4)
                    if s == 1.0:
                        check_safe(box, "title")
                s2 = pop(i, 18, 9)
                if s2 > 0:
                    pulse = 1.0 + (0.05 * math.sin((i - 27) * 0.25) if i > 27 else 0.0)
                    box = place(img, play, W / 2, H * 0.555, scale=s2 * pulse)
                    if s2 == 1.0:
                        check_safe(box, "play")
            # cut flash at the start of each shot, fade in from black at the very start
            if i <= 4 and n > 1:
                img = Image.blend(img, Image.new("RGBA", (W, H), (255, 255, 255, 255)), (5 - i) * 0.16)
            if n == 1 and i <= 10:
                img = Image.blend(Image.new("RGBA", (W, H), (0, 0, 0, 255)), img, i / 10)
            rgb = img.convert("RGB")
            if (n, i) in stills:
                rgb.save(os.path.join(STORE, "trailer_still_%d.png" % stills[(n, i)]))
            ff.stdin.write(rgb.tobytes())
        print("composed shot", n, flush=True)
    ff.stdin.close()
    ff.wait()
    print("wrote", mp4, os.path.getsize(mp4) // 1024, "KB")


if __name__ == "__main__":
    if "--compose" in sys.argv:
        compose()
    elif "--shot" in sys.argv:
        n = int(arg("--shot"))
        fr = arg("--frames", "1-%d" % SHOT_LEN).split("-")
        render_shot(n, (int(fr[0]), int(fr[-1])), int(arg("--samples", "4")))
    elif "--all" in sys.argv:
        for n in range(1, NSHOTS + 1):
            subprocess.check_call([sys.executable, __file__, "--shot", str(n)])
        compose()
    else:
        print(__doc__)
