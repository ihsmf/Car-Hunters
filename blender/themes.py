"""Themed hall kits for the long table: per theme a wall band, a diorama backdrop, a ceiling with three billiard
lamps, a hero floor piece, a mid floor piece, a rail piece and a ceiling hanger (mesh names <Part><Theme>, e.g.
WallOrchard). Stylised-realistic, Roblox axes (X right, Y up, Z back), studs.
Frames: Wall/Backdrop = left side at the origin, inner face towards +X (wall band y 22..36, backdrop y 0..24);
Ceiling = over one table (x -35..35, z -40..40, underside y 36); props stand on y = 0 (Hang hangs down from y = 0).
Slot "Accent" is recoloured per table (the table's colour) by tools/hall.py."""
import math, random
from build_models import mat, box, cyl, sphere, torus, lathe, rb
import bpy

R = random.Random(7)


def mats(**cols):
    metal = {"Brass", "Gold", "Metal", "Chrome", "Copper"}
    return {k: mat(k, v, 0.85 if k in metal else 0, 0.3 if k in metal else 0.55) for k, v in cols.items()}


def rot(o, rx=0, ry=0, rz=0):
    """Rotate about Roblox axes (degrees): X, Y (vertical), Z — around the object's own centre (the primitives have
    their origin at the world origin after transform_apply)."""
    import mathutils
    bpy.context.view_layer.update()
    vs = o.data.vertices
    world = [o.matrix_world @ v.co for v in vs]  # bake the current transform, then pivot at the centre
    c = sum(world, mathutils.Vector()) / max(1, len(vs))
    for v, w in zip(vs, world):
        v.co = w - c
    o.rotation_euler, o.scale, o.location = (0, 0, 0), (1, 1, 1), c
    o.rotation_euler = (math.radians(rx), math.radians(-rz), math.radians(ry))
    return o


def spin(o, euler):
    """Set a Blender rotation_euler around the object's centre."""
    rot(o)
    o.rotation_euler = euler
    return o


def bumpy(o, amount, seed):
    r = random.Random(seed)
    for v in o.data.vertices:
        if v.co.length > 0:
            v.co += v.co.normalized() * r.uniform(-amount, amount)
    return o


def leafball(d, c, m, seed=0):
    return bumpy(sphere(d, c, m, 9, 6), d * 0.1, seed)


def arch_frame(z, w, y0, h, m, depth=0.5, x=0.0, segs=10):
    """Rounded arch outline (two posts + semicircle of blocks) on the wall plane."""
    box((depth, h - w / 2, 0.5), (x + depth / 2, y0 + (h - w / 2) / 2, z - w / 2), m, 0.08)
    box((depth, h - w / 2, 0.5), (x + depth / 2, y0 + (h - w / 2) / 2, z + w / 2), m, 0.08)
    for k in range(segs):
        a = math.pi * (k + 0.5) / segs
        o = box((depth, 0.5, w * math.pi / 2 / segs + 0.1), (x + depth / 2, y0 + h - w / 2 + math.sin(a) * w / 2, z - math.cos(a) * w / 2), m, 0.04)
        rot(o, rx=-math.degrees(a) + 90)


def window(z, w, h, y0, frame, glass, mullions=2):
    box((0.2, h, w), (0.1, y0 + h / 2, z), glass, 0)
    box((0.5, 0.5, w + 0.6), (0.25, y0, z), frame, 0.08)
    box((0.5, 0.5, w + 0.6), (0.25, y0 + h, z), frame, 0.08)
    for s in (-1, 1):
        box((0.5, h, 0.5), (0.25, y0 + h / 2, z + s * w / 2), frame, 0.08)
    for k in range(1, mullions + 1):
        box((0.3, h, 0.22), (0.25, y0 + h / 2, z - w / 2 + w * k / (mullions + 1)), frame, 0.02)
    box((0.3, 0.22, w), (0.25, y0 + h * 0.62, z), frame, 0.02)


def band(M, wall, trim, accent):
    """Common wall band: plaster above the backdrop, base moulding, cornice and pilasters at the joints."""
    box((1.2, 14, 80), (-0.6, 29, 0), M[wall], 0)
    box((0.7, 0.8, 80.2), (0.2, 22.6, 0), M[trim], 0.15)
    box((1.8, 1.2, 80.2), (0.3, 35.5, 0), M[trim], 0.2)
    box((1.0, 0.4, 80.2), (0.5, 34.6, 0), M[accent], 0.06)


def lamp_billiard(z, shade, brass, glow, style="cone"):
    cyl(0.2, 15.6, (0, 27.6, z), brass, verts=6, bevel=0)
    cyl(1.8, 0.5, (0, 35.3, z), brass, verts=12)
    if style == "cone":
        cyl(3.8, 2.4, (0, 18.2, z), shade, d2=1.2, verts=16)
    elif style == "dome":
        lathe([(1.9, 0), (1.85, 0.6), (1.5, 1.6), (0.8, 2.3), (0.3, 2.6), (0, 2.65)], (0, 17.0, z), shade, 16)
    elif style == "lantern":
        box((2.6, 2.8, 2.6), (0, 18.4, z), shade, 0.3)
        box((3.0, 0.4, 3.0), (0, 19.9, z), brass, 0.1)
    elif style == "drum":
        cyl(3.6, 2.2, (0, 18.2, z), shade, verts=20)
    torus(3.6, 0.18, (0, 17.0, z), brass)
    sphere(1.2, (0, 17.4, z), glow, 10, 6)


def ceiling_base(M, ceil, beam, lamp_shade, brass, glow, style="cone", coffer=None):
    box((70, 1, 80), (0, 36.5, 0), M[ceil], 0)
    for x in (-23.3, 0, 23.3):
        for z in (-26.7, 0, 26.7):
            if coffer:
                box((19, 0.3, 23), (x, 35.9, z), M[coffer], 0.1)
    for x in (-11.7, 11.7, -35, 35):
        box((1.6, 1.4, 80), (x, 35.3, 0), M[beam], 0.15)
    for z in (-40, -13.3, 13.3, 40):
        box((70, 1.4, 1.6), (0, 35.3, z), M[beam], 0.15)
    for z in (-26.7, 0, 26.7):
        lamp_billiard(z, M[lamp_shade], M[brass], M[glow], style)


# =====================================================================================================  ORCHARD
def orchard():
    def wall():
        M = mats(Wall=(236, 222, 190), Timber=(110, 70, 38), Trim=(150, 100, 55), Accent=(200, 60, 50), Glass=(150, 200, 230), Leaf=(80, 150, 70))
        band(M, "Wall", "Timber", "Accent")
        for z in (-40, -20, 0, 20, 40):  # half-timbering
            box((0.5, 13, 1.0), (0.25, 29, z), M["Timber"], 0.08)
        for z in (-30, -10, 10, 30):
            o = box((0.45, 0.8, 14), (0.22, 29, z), M["Timber"], 0.06); rot(o, rx=38)
        for z in (-26.7, 0, 26.7):
            window(z, 5, 6, 25.5, M["Trim"], M["Glass"])
            box((1.4, 0.5, 6.2), (0.7, 25.2, z), M["Timber"], 0.1)  # flower box
            for k in range(5):
                leafball(1.0, (1.0, 25.9, z - 2.2 + k * 1.1), M["Leaf"], k)
                sphere(0.4, (1.4, 26.2, z - 2.2 + k * 1.1), M["Accent"], 6, 4)
    def backdrop():
        M = mats(Sky=(170, 215, 245), Hill=(110, 170, 80), HillFar=(140, 190, 120), Trunk=(110, 70, 40), Leaf=(70, 150, 70), Accent=(220, 60, 50), Barn=(170, 50, 40), Roof=(90, 60, 50))
        box((0.4, 24, 80), (-0.2, 12, 0), M["Sky"], 0)
        for k, z in enumerate(range(-36, 40, 18)):
            o = sphere(26, (-0.3, 0, z), M["HillFar"], 16, 8, (0.06, 0.5, 1)); bumpy(o, 0.3, k)
        for k, z in enumerate(range(-40, 41, 26)):
            sphere(30, (0.4, -3, z + 6), M["Hill"], 16, 8, (0.06, 0.4, 1))
        for k in range(14):  # orchard rows
            z = -37 + k * 5.6 + R.uniform(-1, 1); y = 3 + R.uniform(0, 2)
            cyl(0.5, 2.4, (1.2, y + 1, z), M["Trunk"], verts=6)
            leafball(2.8, (1.3, y + 3, z), M["Leaf"], k)
            for j in range(3):
                sphere(0.45, (2.4, y + 2.4 + R.uniform(0, 1.2), z + R.uniform(-1, 1)), M["Accent"], 6, 4)
        box((1.6, 5, 7), (0.8, 4.5, 18), M["Barn"], 0.1)  # barn
        o = box((1.8, 0.5, 5.2), (0.9, 8.4, 16.2), M["Roof"], 0.05); rot(o, rx=-35)
        o = box((1.8, 0.5, 5.2), (0.9, 8.4, 19.8), M["Roof"], 0.05); rot(o, rx=35)
    def ceiling():
        M = mats(Ceil=(240, 228, 200), Beam=(110, 70, 38), Shade=(40, 120, 60), Brass=(226, 178, 84), Glow=(255, 236, 180), Leaf=(80, 150, 70), Accent=(220, 60, 50))
        ceiling_base(M, "Ceil", "Beam", "Shade", "Brass", "Glow", "dome")
        for x in (-11.7, 11.7):  # vines along the beams
            for k in range(16):
                leafball(1.3, (x, 34.4, -38 + k * 5), M["Leaf"], k)
                if k % 2:
                    sphere(0.5, (x + 0.6, 33.8, -38 + k * 5), M["Accent"], 6, 4)
    def hero():  # wooden well with roof and bucket
        M = mats(Stone=(150, 140, 125), Wood=(120, 76, 40), Roof=(160, 60, 40), Metal=(120, 120, 130), Accent=(200, 60, 50), Water=(70, 150, 200))
        lathe([(2.6, 0), (2.7, 0.3), (2.6, 2.6), (2.8, 2.8), (2.8, 3.2), (2.1, 3.2), (2.1, 0.4), (0, 0.4)], (0, 0, 0), M["Stone"], 18)
        cyl(4.2, 0.1, (0, 2.6, 0), M["Water"], verts=18)
        for s in (-1, 1):
            box((0.5, 6.2, 0.5), (0, 6.1, s * 2.4), M["Wood"], 0.06)
        cyl(0.5, 5, (0, 7.6, 0), M["Wood"], axis="Z", verts=8)
        for s in (-1, 1):
            o = box((4.2, 0.35, 3.6), (s * 1.3, 9.8, 0), M["Roof"], 0.05); rot(o, rz=s * -32)
        cyl(1.2, 1.3, (0, 5, 0), M["Wood"], d2=1.5, verts=10)
        cyl(0.08, 2.5, (0, 6.4, 0), M["Metal"], verts=4, bevel=0)
        for k in range(6):
            sphere(0.5, (1.8 + R.uniform(-0.3, 0.3), 0.3, -2.6 + k * 0.9), M["Accent"], 6, 4)
    def mid():  # crate of apples
        M = mats(Wood=(170, 120, 70), WoodDark=(120, 80, 45), Accent=(210, 45, 45), Leaf=(80, 150, 70))
        box((2.6, 1.6, 2.0), (0, 0.8, 0), M["Wood"], 0.06)
        for y in (0.4, 1.2):
            box((2.7, 0.3, 2.1), (0, y, 0), M["WoodDark"], 0.04)
        for k in range(12):
            sphere(0.62, (-0.9 + (k % 4) * 0.6, 1.75 + (k // 4) * 0.12, -0.6 + (k // 4) * 0.6), M["Accent"], 8, 6)
        box((2.2, 1.2, 1.7), (0.3, 0.6, 2.2), M["Wood"], 0.06)
        for k in range(6):
            sphere(0.6, (-0.3 + (k % 3) * 0.6, 1.4, 1.9 + (k // 3) * 0.6), M["Accent"], 8, 6)
    def rail():  # wicker basket with apples
        M = mats(Wicker=(200, 160, 90), Accent=(210, 45, 45), Leaf=(80, 150, 70))
        lathe([(0.5, 0), (0.75, 0.15), (0.85, 0.8), (0.78, 0.82), (0.68, 0.2), (0, 0.2)], (0, 0, 0), M["Wicker"], 14)
        torus(1.1, 0.08, (0, 1.2, 0), M["Wicker"], "X")
        for k in range(5):
            sphere(0.42, (math.cos(k * 1.3) * 0.35, 0.85, math.sin(k * 1.3) * 0.35), M["Accent"], 8, 5)
        leafball(0.3, (0.1, 1.15, 0), M["Leaf"])
    def hang():  # hanging basket of flowers
        M = mats(Chain=(90, 80, 70), Wicker=(170, 120, 60), Leaf=(70, 150, 70), Accent=(240, 90, 120))
        cyl(0.1, 6, (0, -3, 0), M["Chain"], verts=4, bevel=0)
        lathe([(0, -8.2), (1.4, -7.8), (1.8, -6.6), (1.6, -6.5)], (0, 0, 0), M["Wicker"], 14)
        for k in range(10):
            a = k * 0.63
            leafball(1.0, (math.cos(a) * 1.4, -6.4 - (k % 3) * 0.6, math.sin(a) * 1.4), M["Leaf"], k)
            sphere(0.45, (math.cos(a) * 1.7, -6.2, math.sin(a) * 1.7), M["Accent"], 6, 4)
    return dict(Wall=wall, Backdrop=backdrop, Ceiling=ceiling, Hero=hero, Mid=mid, Rail=rail, Hang=hang)


# =====================================================================================================  CANDY
def candy():
    def wall():
        M = mats(Wall=(255, 214, 230), Icing=(255, 250, 245), Trim=(140, 80, 50), Accent=(255, 90, 150), Mint=(120, 220, 190), Glow=(255, 240, 200))
        band(M, "Wall", "Trim", "Accent")
        for k in range(40):  # icing drips under the cornice
            z = -39 + k * 2
            sphere(1.2, (0.4, 34.3, z), M["Icing"], 8, 5, (0.6, 0.8, 1))
            cyl(0.5, 0.9 + (k % 3) * 0.5, (0.45, 33.6 - (k % 3) * 0.25, z + 0.6), M["Icing"], verts=6)
        for z in (-26.7, 0, 26.7):  # lollipop rosettes
            cyl(0.4, 6, (0.4, 27.5, z), M["Icing"], verts=8)
            cyl(6.4, 0.6, (0.8, 29.5, z), M["Accent"], axis="X", verts=24)
            for r in (2.4, 1.4):
                torus(r * 2, 0.35, (1.15, 29.5, z), M["Mint"], "X")
            sphere(0.9, (1.3, 29.5, z), M["Glow"], 8, 6)
        for z in (-13.3, 13.3):
            for k in range(4):
                sphere(1.0, (0.6, 25.5 + k * 2.2, z), [M["Accent"], M["Mint"]][k % 2], 8, 6)
    def backdrop():
        M = mats(Sky=(255, 220, 240), Hill=(255, 170, 200), Choco=(110, 60, 35), Icing=(255, 250, 245), Accent=(255, 90, 150), Mint=(120, 220, 190), Ginger=(200, 120, 60))
        box((0.4, 24, 80), (-0.2, 12, 0), M["Sky"], 0)
        for k, z in enumerate(range(-40, 41, 16)):  # candy mountains with icing caps
            cyl(18, 16 + (k % 3) * 3, (0.2, 8, z), M["Hill"] if k % 2 else M["Choco"], d2=2, verts=12)
            cyl(6, 3, (0.4, 15.5 + (k % 3) * 3, z), M["Icing"], d2=1, verts=12)
        for k, z in enumerate((-30, -6, 18)):  # gingerbread houses
            box((2.2, 4, 5), (1.2, 2, z), M["Ginger"], 0.15)
            for s in (-1, 1):
                o = box((2.6, 0.5, 3.6), (1.2, 5.2, z + s * 1.3), M["Icing"], 0.1); rot(o, rx=s * 40)
            box((0.3, 1.8, 1.2), (2.4, 0.9, z), M["Choco"], 0.05)
            for d in (-1.5, 1.5):
                sphere(0.6, (2.4, 2.8, z + d), M["Accent"], 6, 4)
        for k in range(10):  # lollipop trees
            z = -36 + k * 8
            cyl(0.3, 5, (2.2, 2.5, z), M["Icing"], verts=6)
            cyl(2.6, 0.4, (2.3, 5.6, z), [M["Accent"], M["Mint"]][k % 2], axis="X", verts=16)
    def ceiling():
        M = mats(Ceil=(255, 236, 244), Beam=(140, 80, 50), Shade=(255, 120, 170), Brass=(240, 200, 120), Glow=(255, 240, 210), Mint=(120, 220, 190), Accent=(255, 90, 150))
        ceiling_base(M, "Ceil", "Beam", "Shade", "Brass", "Glow", "dome")
        for x in (-11.7, 11.7):  # striped candy beams wrap
            for k in range(20):
                cyl(1.9, 0.9, (x, 34.4, -38 + k * 4), [M["Accent"], M["Mint"]][k % 2], axis="Z", verts=10)
    def hero():  # giant cupcake
        M = mats(Wrap=(255, 170, 200), Cake=(200, 130, 80), Icing=(255, 245, 250), Accent=(255, 90, 150), Cherry=(220, 30, 50), Sprinkle=(120, 220, 190))
        lathe([(2.2, 0), (3.0, 3.6), (3.1, 3.7), (0, 3.7)], (0, 0, 0), M["Wrap"], 24)
        for k in range(12):
            a = k * math.pi / 6
            rot(box((0.3, 3.6, 0.5), (math.cos(a) * 2.65, 1.8, math.sin(a) * 2.65), M["Icing"], 0.05), ry=math.degrees(-a))
        lathe([(3.3, 3.6), (3.6, 4.4), (3.2, 5.4), (2.4, 6.2), (2.6, 6.6), (1.7, 7.4), (1.0, 8.4), (0.3, 9.0), (0, 9.1)], (0, 0, 0), M["Icing"], 24)
        sphere(1.4, (0, 9.6, 0), M["Cherry"], 12, 8)
        for k in range(30):
            a, y = R.uniform(0, 6.28), R.uniform(4.6, 8.0)
            r = 3.4 - (y - 4.4) * 0.6
            o = cyl(0.18, 0.6, (math.cos(a) * r, y, math.sin(a) * r), [M["Accent"], M["Sprinkle"]][k % 2], verts=4, bevel=0); rot(o, rx=R.uniform(0, 90), rz=R.uniform(0, 90))
    def mid():  # gumball machine
        M = mats(Base=(220, 40, 60), Metal=(220, 220, 230), Glass=(220, 240, 255), Accent=(255, 90, 150), Ball1=(255, 210, 60), Ball2=(90, 200, 255))
        cyl(2.2, 2.4, (0, 1.2, 0), M["Base"], d2=1.6, verts=16)
        box((0.4, 0.6, 0.8), (0.9, 1.6, 0), M["Metal"], 0.1)
        for k in range(26):
            a, b = R.uniform(0, 6.28), R.uniform(-1.2, 1.2)
            r = 1.15 * math.cos(b * 0.8)
            sphere(0.55, (math.cos(a) * r * 0.8, 3.7 + math.sin(b) * 0.9, math.sin(a) * r * 0.8), [M["Accent"], M["Ball1"], M["Ball2"]][k % 3], 6, 4)
        cyl(1.2, 0.5, (0, 5.0, 0), M["Base"], verts=12)
        sphere(0.5, (0, 5.4, 0), M["Metal"], 8, 5)
    def rail():  # mini cupcake
        M = mats(Wrap=(255, 170, 200), Icing=(255, 245, 250), Accent=(255, 90, 150), Cherry=(220, 30, 50))
        lathe([(0.45, 0), (0.6, 0.6), (0, 0.6)], (0, 0, 0), M["Wrap"], 12)
        lathe([(0.68, 0.55), (0.6, 0.9), (0.35, 1.2), (0, 1.35)], (0, 0, 0), M["Accent"], 12)
        sphere(0.3, (0, 1.45, 0), M["Cherry"], 8, 5)
    def hang():  # candy garland
        M = mats(String=(255, 250, 240), Accent=(255, 90, 150), Mint=(120, 220, 190), Wrap=(255, 210, 60))
        cyl(0.08, 4, (0, -2, 0), M["String"], verts=4, bevel=0)
        for k in range(7):
            y = -4.4 - k * 0.9
            cyl(0.9, 0.5, (0, y, 0), [M["Accent"], M["Mint"], M["Wrap"]][k % 3], axis="X", verts=12)
            for s in (-1, 1):
                cyl(0.5, 0.4, (0, y, s * 0.6), M["String"], axis="Z", d2=0.05, verts=6)
    return dict(Wall=wall, Backdrop=backdrop, Ceiling=ceiling, Hero=hero, Mid=mid, Rail=rail, Hang=hang)


# =====================================================================================================  REEF
def reef():
    def wall():
        M = mats(Wall=(40, 90, 120), Trim=(220, 200, 160), Accent=(255, 130, 90), Brass=(210, 170, 90), Water=(60, 170, 210), Fish=(255, 180, 60), Weed=(60, 170, 110))
        band(M, "Wall", "Trim", "Accent")
        for z in (-26.7, 0, 26.7):  # aquarium portholes
            cyl(7.4, 0.3, (0.15, 29, z), M["Water"], axis="X", verts=28)
            torus(7.6, 0.7, (0.4, 29, z), M["Brass"], "X")
            for k in range(8):
                a = k * math.pi / 4
                sphere(0.5, (0.7, 29 + math.sin(a) * 3.8, z + math.cos(a) * 3.8), M["Brass"], 6, 4)
            for k in range(3):  # fish
                fz, fy = z - 1.5 + k * 1.4, 28 + k * 0.9
                sphere(1.0, (0.5, fy, fz), M["Fish"], 8, 5, (0.4, 0.6, 1))
                o = cyl(0.7, 0.5, (0.5, fy, fz + 0.7), M["Fish"], axis="Z", d2=0.05, verts=4)
            for k in range(4):
                cyl(0.3, 2 + k * 0.4, (0.4, 26.5 + k * 0.2, z - 2 + k * 1.2), M["Weed"], verts=5)
    def backdrop():
        M = mats(Sea=(30, 110, 160), Sand=(230, 210, 160), Rock=(90, 100, 110), Accent=(255, 110, 120), Coral2=(255, 170, 70), Weed=(50, 160, 100), Shell=(255, 230, 220))
        box((0.4, 24, 80), (-0.2, 12, 0), M["Sea"], 0)
        sphere(80, (0.3, -2, 0), M["Sand"], 20, 8, (0.03, 0.06, 1))
        for k in range(8):
            z = -36 + k * 10 + R.uniform(-2, 2)
            bumpy(sphere(6, (0.6, 1.5, z), M["Rock"], 10, 6, (0.4, 0.8, 1)), 0.4, k)
        for k in range(16):  # branching corals + kelp
            z, y = -38 + k * 5 + R.uniform(-1, 1), R.uniform(1, 3)
            if k % 3 == 0:
                for j in range(5):
                    o = cyl(0.5, 4 + j * 0.6, (1.4, y + 2, z + (j - 2) * 0.6), M["Accent"] if k % 2 else M["Coral2"], d2=0.25, verts=6); rot(o, rx=(j - 2) * 14)
            elif k % 3 == 1:
                for j in range(6):
                    cyl(0.4, 1.6, (1.6, y + 0.8 + j * 1.5, z + math.sin(j) * 0.5), M["Weed"], verts=5)
            else:
                bumpy(sphere(2.6, (1.4, y + 0.6, z), M["Coral2"], 10, 7), 0.2, k)
                sphere(0.9, (2.6, 0.6, z + 1.4), M["Shell"], 8, 5, (1, 0.5, 1))
    def ceiling():
        M = mats(Ceil=(30, 90, 130), Beam=(200, 180, 140), Shade=(40, 150, 170), Brass=(210, 170, 90), Glow=(200, 240, 255), Wave=(80, 180, 220))
        ceiling_base(M, "Ceil", "Beam", "Shade", "Brass", "Glow", "dome")
        for x in (-23.3, 23.3):  # rippling water surface panels
            for k in range(8):
                sphere(9, (x, 35.6, -35 + k * 10), M["Wave"], 12, 6, (1, 0.08, 0.6))
    def hero():  # treasure chest + anchor
        M = mats(Wood=(120, 70, 35), Gold=(250, 200, 70), Metal=(80, 85, 95), Accent=(255, 110, 120), Sand=(230, 210, 160), Pearl=(250, 245, 255))
        sphere(9, (0, 0, 0), M["Sand"], 14, 6, (1, 0.12, 1))
        box((4, 2.4, 2.6), (0, 1.6, 0), M["Wood"], 0.12)
        o = cyl(2.6, 4, (0, 2.8, -0.4), M["Wood"], axis="X", verts=14); o.scale = (1, 1, 0.8)
        for x in (-1.6, 0, 1.6):
            box((0.3, 2.5, 2.7), (x, 1.6, 0), M["Gold"], 0.04)
        for k in range(14):
            cyl(0.55, 0.15, (R.uniform(-1.6, 1.6), 3.0 + R.uniform(0, 0.5), R.uniform(-0.4, 1.6)), M["Gold"], verts=10)
        sphere(0.7, (0.6, 3.6, 0.8), M["Pearl"], 8, 6)
        cyl(0.5, 7, (3.4, 3.5, 1.4), M["Metal"], verts=8)  # anchor
        torus(1.2, 0.3, (3.4, 7.3, 1.4), M["Metal"], "X")
        o = torus(4.4, 0.45, (3.4, 1.4, 1.4), M["Metal"], "X")
        cyl(3.4, 0.4, (3.4, 6, 1.4), M["Metal"], axis="Z", verts=8)
    def mid():  # brass diving helmet on a crate
        M = mats(Wood=(150, 110, 70), Brass=(210, 160, 70), Glass=(160, 220, 240), Accent=(255, 110, 120))
        box((2.4, 1.6, 2.4), (0, 0.8, 0), M["Wood"], 0.08)
        sphere(2.4, (0, 3, 0), M["Brass"], 16, 10)
        for a in (0, 90, 270):
            o = cyl(0.9, 0.25, (math.cos(math.radians(a)) * 1.15, 3, math.sin(math.radians(a)) * 1.15), M["Glass"], axis="X", verts=12)
            rot(o, ry=-a)
        cyl(2.0, 0.5, (0, 1.85, 0), M["Brass"], verts=16)
        torus(1.0, 0.2, (1.15, 3, 0), M["Accent"], "X")
    def rail():  # scallop shell with pearl
        M = mats(Shell=(255, 210, 200), Accent=(255, 130, 120), Pearl=(250, 245, 255))
        for k in range(7):
            a = math.radians(-60 + k * 20)
            o = cyl(0.3, 1.3, (math.sin(a) * 0.55, 0.35, math.cos(a) * 0.55 - 0.3), M["Shell"] if k % 2 else M["Accent"], axis="Z", d2=0.1, verts=6)
            rot(o, ry=math.degrees(-a))
        sphere(1.4, (0, 0.6, 0.15), M["Shell"], 12, 6, (1, 0.3, 0.8))
        sphere(0.5, (0, 0.8, 0.4), M["Pearl"], 10, 6)
    def hang():  # jellyfish
        M = mats(Bell=(255, 160, 220), Glow=(255, 220, 255), Tentacle=(200, 120, 220))
        cyl(0.06, 3, (0, -1.5, 0), M["Tentacle"], verts=4, bevel=0)
        lathe([(0, -3), (1.4, -3.3), (1.9, -4.2), (1.8, -4.9), (1.5, -4.8), (0, -4.6)], (0, 0, 0), M["Bell"], 16)
        sphere(1.6, (0, -4.3, 0), M["Glow"], 10, 6, (1, 0.5, 1))
        for k in range(8):
            a = k * math.pi / 4
            for j in range(4):
                cyl(0.18, 1.0, (math.cos(a) * 1.2 + math.sin(j) * 0.2, -5.4 - j * 0.95, math.sin(a) * 1.2), M["Tentacle"], verts=4, bevel=0)
    return dict(Wall=wall, Backdrop=backdrop, Ceiling=ceiling, Hero=hero, Mid=mid, Rail=rail, Hang=hang)


# =====================================================================================================  DESERT
def desert():
    def wall():
        M = mats(Wall=(225, 180, 130), Trim=(170, 110, 70), Accent=(60, 150, 170), Tile=(240, 220, 180), Wood=(120, 80, 45), Glow=(255, 200, 120))
        band(M, "Wall", "Trim", "Accent")
        for z in (-26.7, 0, 26.7):  # adobe arches with tile mosaic
            arch_frame(z, 6.4, 23.5, 9, M["Trim"], 0.8)
            box((0.3, 9, 6.4), (0.1, 28, z), M["Accent"], 0)
            for k in range(5):
                for j in range(4):
                    if (k + j) % 2:
                        box((0.35, 0.9, 0.9), (0.25, 24.5 + k * 1.4, z - 2.1 + j * 1.4), M["Tile"], 0.05)
        for k in range(20):  # vigas (protruding roof beams)
            cyl(0.7, 2.2, (0.9, 33.4, -38 + k * 4), M["Wood"], axis="X", verts=8)
    def backdrop():
        M = mats(Sky=(255, 200, 150), Sun=(255, 160, 90), Dune=(240, 190, 120), Mesa=(200, 110, 70), MesaDark=(160, 80, 50), Cactus=(70, 140, 80), Accent=(60, 150, 170))
        box((0.4, 24, 80), (-0.2, 12, 0), M["Sky"], 0)
        cyl(9, 0.3, (0, 15, -10), M["Sun"], axis="X", verts=28)
        for k, z in enumerate((-28, 8, 30)):  # mesas
            o = box((2, 8 + k * 2, 14), (0.4, 4 + k, z), M["Mesa"], 0.5); bumpy(o, 0.0, k)
            box((2.2, 1, 15), (0.5, 8.5 + k * 2, z), M["MesaDark"], 0.3)
        for k in range(6):
            sphere(22, (1.0, -2, -40 + k * 16), M["Dune"], 14, 6, (0.08, 0.3, 1))
        for k in range(7):  # saguaros
            z = -35 + k * 11
            cyl(0.9, 5, (2.0, 2.5, z), M["Cactus"], verts=8)
            for s in (-1, 1):
                cyl(0.6, 1.4, (2.0, 2.6 + k % 2, z + s * 0.9), M["Cactus"], axis="Z", verts=6)
                cyl(0.6, 1.8, (2.0, 3.4 + k % 2, z + s * 1.5), M["Cactus"], verts=6)
    def ceiling():
        M = mats(Ceil=(235, 200, 150), Beam=(120, 80, 45), Shade=(200, 110, 60), Brass=(200, 150, 80), Glow=(255, 210, 150), Cane=(220, 190, 130))
        ceiling_base(M, "Ceil", "Beam", "Shade", "Brass", "Glow", "lantern")
        for x in range(-33, 34, 3):  # latilla cane ceiling
            box((0.8, 0.5, 80), (x, 35.7, 0), M["Cane"], 0.15)
    def hero():  # clay pottery stack + saguaro in pot
        M = mats(Clay=(200, 110, 70), Paint=(240, 220, 180), Accent=(60, 150, 170), Cactus=(70, 140, 80), Spine=(250, 240, 200))
        lathe([(1.8, 0), (2.4, 0.6), (2.6, 1.6), (2.0, 2.6), (2.1, 2.9), (0, 2.9)], (0, 0, 0), M["Clay"], 18)
        torus(5.0, 0.25, (0, 1.6, 0), M["Accent"])
        cyl(1.8, 7.5, (0, 6.2, 0), M["Cactus"], verts=10)
        sphere(1.8, (0, 9.9, 0), M["Cactus"], 10, 6)
        for s in (-1, 1):
            cyl(1.1, 2.2, (0, 5.2 + (s > 0), s * 1.8), M["Cactus"], axis="Z", verts=8)
            cyl(1.1, 3.2, (0, 6.5 + (s > 0), s * 2.9), M["Cactus"], verts=8)
            sphere(1.1, (0, 8.1 + (s > 0), s * 2.9), M["Cactus"], 8, 5)
        sphere(0.7, (0, 10.6, 0), M["Accent"], 8, 5)
    def mid():  # amphora pair
        M = mats(Clay=(190, 100, 60), Paint=(240, 220, 180), Accent=(60, 150, 170))
        for k, (x, z, s) in enumerate(((0, 0, 1), (1.4, 1.0, 0.7))):
            lathe([(0.5 * s, 0), (1.1 * s, 0.8 * s), (1.2 * s, 2.0 * s), (0.5 * s, 3.2 * s), (0.6 * s, 3.8 * s), (0, 3.8 * s)], (x, 0, z), M["Clay"], 16)
            torus(2.3 * s, 0.15, (x, 2.0 * s, z), M["Accent"])
            torus(1.9 * s, 0.12, (x, 1.3 * s, z), M["Paint"])
    def rail():  # potted barrel cactus with flower
        M = mats(Clay=(200, 110, 70), Cactus=(70, 140, 80), Accent=(255, 90, 140))
        lathe([(0.45, 0), (0.6, 0.6), (0.65, 0.65), (0, 0.65)], (0, 0, 0), M["Clay"], 12)
        bumpy(sphere(1.0, (0, 1.05, 0), M["Cactus"], 10, 6, (1, 1.1, 1)), 0.04, 1)
        sphere(0.35, (0, 1.6, 0), M["Accent"], 8, 5)
    def hang():  # punched tin lantern
        M = mats(Chain=(80, 70, 60), Metal=(200, 170, 110), Glow=(255, 190, 110))
        cyl(0.08, 5, (0, -2.5, 0), M["Chain"], verts=4, bevel=0)
        cyl(1.8, 2.6, (0, -6.3, 0), M["Metal"], verts=8)
        cyl(1.9, 1.0, (0, -4.6, 0), M["Metal"], d2=0.4, verts=8)
        sphere(1.4, (0, -6.3, 0), M["Glow"], 8, 6)
        cyl(1.3, 0.6, (0, -7.9, 0), M["Metal"], d2=0.3, verts=8)
    return dict(Wall=wall, Backdrop=backdrop, Ceiling=ceiling, Hero=hero, Mid=mid, Rail=rail, Hang=hang)


# =====================================================================================================  ICE
def ice():
    def wall():
        M = mats(Wall=(200, 230, 250), Trim=(240, 250, 255), Accent=(120, 190, 255), Ice=(170, 220, 255), Glow=(220, 245, 255))
        band(M, "Wall", "Trim", "Accent")
        for k in range(36):  # icicles
            z = -39 + k * 2.2 + R.uniform(-0.3, 0.3)
            cyl(0.7, 1.5 + (k * 7 % 5) * 0.5, (0.6, 34 - (k * 7 % 5) * 0.25, z), M["Ice"], d2=0.05, verts=6)
        for z in (-26.7, 0, 26.7):  # snowflakes
            for a in range(6):
                o = box((0.3, 7, 0.45), (0.4, 28.6, z), M["Glow"], 0.05); rot(o, rx=a * 30)
                for s in (-1, 1):
                    o = box((0.3, 1.6, 0.35), (0.45, 28.6 + math.cos(math.radians(a * 60)) * 2.4, z + math.sin(math.radians(a * 60)) * 2.4), M["Glow"], 0.04)
                    rot(o, rx=a * 60 + s * 45)
            torus(9, 0.4, (0.4, 28.6, z), M["Accent"], "X")
    def backdrop():
        M = mats(Sky=(150, 190, 240), Aurora=(120, 255, 190), Snow=(245, 250, 255), Ice=(170, 220, 255), Rock=(120, 140, 170), Accent=(120, 190, 255))
        box((0.4, 24, 80), (-0.2, 12, 0), M["Sky"], 0)
        for k in range(5):  # aurora ribbons
            o = box((0.2, 1.4, 22), (0.1, 19 + math.sin(k) * 2, -30 + k * 15), M["Aurora"], 0.3); rot(o, rx=12 * math.sin(k * 2))
        for k, z in enumerate(range(-36, 40, 14)):  # glacier peaks
            cyl(14, 14 + (k % 3) * 3, (0.3, 7, z), M["Rock"], d2=1, verts=6)
            cyl(7, 6, (0.6, 12 + (k % 3) * 3, z), M["Snow"], d2=0.8, verts=6)
        for k in range(9):
            cyl(2.4, 5 + k % 3, (1.6, 2.5, -36 + k * 9), M["Ice"], d2=0.3, verts=5)
        lathe([(3, 0), (2.7, 1.4), (1.8, 2.6), (0, 3.1)], (1.6, 0, 14), M["Snow"], 14)  # igloo
        box((1.4, 1.6, 1.6), (3.6, 0.8, 14), M["Snow"], 0.4)
        sphere(80, (0.3, -2, 0), M["Snow"], 20, 8, (0.04, 0.05, 1))
    def ceiling():
        M = mats(Ceil=(220, 238, 252), Beam=(170, 210, 240), Shade=(120, 190, 255), Brass=(210, 225, 240), Glow=(230, 248, 255), Ice=(170, 220, 255))
        ceiling_base(M, "Ceil", "Beam", "Shade", "Brass", "Glow", "dome")
        for x in (-23.3, 23.3):
            for k in range(24):
                cyl(0.8, 1.5 + k % 4, (x + R.uniform(-6, 6), 35 - (k % 4) * 0.5, -38 + k * 3.3), M["Ice"], d2=0.05, verts=6)
    def hero():  # ice castle tower
        M = mats(Ice=(180, 225, 255), Snow=(245, 250, 255), Accent=(120, 190, 255), Glow=(220, 245, 255))
        cyl(5, 8, (0, 4, 0), M["Ice"], d2=4.4, verts=10)
        for k in range(10):
            a = k * math.pi / 5
            box((0.9, 1, 0.9), (math.cos(a) * 2.2, 8.5, math.sin(a) * 2.2), M["Ice"], 0.1)
        cyl(4.6, 3, (0, 10.5, 0), M["Accent"], d2=0.1, verts=10)
        for y in (3, 6):
            box((0.4, 1.6, 0.9), (2.3, y, 0), M["Glow"], 0.1)
        sphere(10, (0, 0, 0), M["Snow"], 12, 6, (1, 0.12, 1))
        for k in range(5):
            cyl(1.4, 3 + k % 2, (math.cos(k * 1.3) * 3.4, 1.5, math.sin(k * 1.3) * 3.4), M["Ice"], d2=0.2, verts=5)
    def mid():  # penguin
        M = mats(Black=(40, 45, 60), White=(245, 248, 255), Accent=(255, 170, 50), Scarf=(220, 60, 70))
        sphere(2.2, (0, 1.6, 0), M["Black"], 14, 9, (1, 1.4, 1))
        sphere(1.6, (0.4, 1.5, 0), M["White"], 12, 8, (0.8, 1.4, 1))
        sphere(1.6, (0, 3.6, 0), M["Black"], 12, 8)
        for s in (-1, 1):
            sphere(0.35, (0.7, 3.8, s * 0.35), M["White"], 6, 4)
            sphere(0.9, (0, 1.8, s * 1.1), M["Black"], 8, 5, (0.4, 1.4, 0.3))
            sphere(0.6, (0.4, 0.15, s * 0.5), M["Accent"], 6, 4, (1.4, 0.4, 1))
        cyl(0.4, 0.6, (0.9, 3.5, 0), M["Accent"], axis="X", d2=0.05, verts=6)
        torus(2.0, 0.35, (0, 2.9, 0), M["Scarf"])
    def rail():  # snow globe
        M = mats(Base=(120, 80, 60), Glass=(220, 240, 255), Snow=(250, 250, 255), Accent=(120, 190, 255))
        cyl(1.2, 0.5, (0, 0.25, 0), M["Base"], d2=1.0, verts=14)
        sphere(1.3, (0, 1.1, 0), M["Glass"], 14, 8)
        cyl(0.4, 0.8, (0, 1.0, 0), M["Accent"], d2=0.05, verts=6)
        sphere(0.9, (0, 0.6, 0), M["Snow"], 10, 5, (1, 0.3, 1))
    def hang():  # icicle chandelier
        M = mats(Chain=(200, 210, 230), Ice=(180, 225, 255), Glow=(230, 248, 255))
        cyl(0.08, 4, (0, -2, 0), M["Chain"], verts=4, bevel=0)
        torus(3.6, 0.3, (0, -4.2, 0), M["Chain"])
        for k in range(12):
            a = k * math.pi / 6
            cyl(0.5, 1.6 + (k % 3) * 0.8, (math.cos(a) * 1.8, -5.0 - (k % 3) * 0.4, math.sin(a) * 1.8), M["Ice"], d2=0.05, verts=6)
        sphere(1.2, (0, -4.6, 0), M["Glow"], 10, 6)
    return dict(Wall=wall, Backdrop=backdrop, Ceiling=ceiling, Hero=hero, Mid=mid, Rail=rail, Hang=hang)


# =====================================================================================================  FIRE
def fire():
    def wall():
        M = mats(Wall=(60, 45, 45), Trim=(110, 80, 70), Accent=(255, 110, 40), Lava=(255, 120, 30), Metal=(60, 60, 70), Glow=(255, 200, 90))
        band(M, "Wall", "Trim", "Accent")
        for k in range(14):  # lava seams in the rock
            z, y = -38 + k * 5.6, 25 + (k * 5 % 7)
            o = box((0.25, 0.5, 4 + k % 3), (0.1, y, z), M["Lava"], 0.05); rot(o, rx=(k * 37 % 50) - 25)
        for z in (-26.7, 0, 26.7):  # iron braziers on brackets
            box((1.6, 0.4, 0.4), (0.8, 27, z), M["Metal"], 0.05)
            lathe([(0.3, 0), (1.4, 1.0), (1.5, 1.3), (0, 1.3)], (1.6, 27, z), M["Metal"], 10)
            for k in range(3):
                cyl(1.6 - k * 0.4, 1.4 + k * 0.5, (1.6, 28.8 + k * 0.6, z), [M["Accent"], M["Lava"], M["Glow"]][k], d2=0.1, verts=7)
    def backdrop():
        M = mats(Sky=(80, 30, 30), Smoke=(70, 60, 60), Rock=(50, 40, 40), Lava=(255, 120, 30), Glow=(255, 200, 90), Accent=(255, 80, 40))
        box((0.4, 24, 80), (-0.2, 12, 0), M["Sky"], 0)
        for k, z in enumerate((-26, 10, 32)):  # volcanoes
            cyl(22, 16 + k * 2, (0.4, 8 + k, z), M["Rock"], d2=5, verts=10)
            cyl(5.2, 1, (0.6, 16.5 + k * 2, z), M["Lava"], verts=10)
            for j in range(4):
                o = box((0.5, 9, 1), (1.2, 10 + k, z + (j - 1.5) * 2), M["Lava"], 0.2); rot(o, rx=(j - 1.5) * 18)
            for j in range(3):
                sphere(4, (0.3, 20 + k * 2 + j * 2, z + j), M["Smoke"], 8, 5)
        sphere(80, (0.3, -2, 0), M["Rock"], 20, 8, (0.04, 0.06, 1))
        for k in range(8):
            box((1, 0.3, 6), (2.0, 0.6, -36 + k * 10), M["Glow"], 0.1)
    def ceiling():
        M = mats(Ceil=(50, 40, 40), Beam=(30, 25, 25), Shade=(120, 50, 30), Metal=(90, 80, 80), Glow=(255, 200, 120), Lava=(255, 120, 30))
        ceiling_base(M, "Ceil", "Beam", "Shade", "Metal", "Glow", "drum")
        for x in (-23.3, 23.3):
            for k in range(6):
                o = box((14, 0.2, 0.5), (x, 35.9, -34 + k * 13), M["Lava"], 0.05); rot(o, ry=R.uniform(-30, 30))
    def hero():  # stone brazier with fire
        M = mats(Stone=(90, 80, 80), Metal=(60, 60, 70), Fire=(255, 120, 30), Flame=(255, 200, 80), Accent=(255, 80, 40))
        lathe([(2.4, 0), (2.4, 0.8), (1.4, 1.4), (1.1, 4.5), (1.6, 5.2), (3.0, 6.0), (3.2, 6.6), (0, 6.6)], (0, 0, 0), M["Stone"], 12)
        for k in range(9):
            a = k * 0.7
            cyl(1.6 - (k % 3) * 0.3, 2.5 + (k % 3) * 1.2, (math.cos(a) * 1.2, 7.8 + (k % 3) * 0.6, math.sin(a) * 1.2), [M["Fire"], M["Flame"], M["Accent"]][k % 3], d2=0.05, verts=6)
        for k in range(4):
            box((0.5, 5, 0.5), (math.cos(k * 1.57) * 1.3, 3, math.sin(k * 1.57) * 1.3), M["Metal"], 0.05)
    def mid():  # anvil on stump
        M = mats(Wood=(110, 70, 40), Metal=(70, 72, 80), Accent=(255, 110, 40), Glow=(255, 180, 60))
        cyl(2.4, 2.2, (0, 1.1, 0), M["Wood"], verts=12)
        box((1.0, 0.8, 1.4), (0, 2.6, 0), M["Metal"], 0.1)
        box((1.4, 0.8, 3.0), (0, 3.4, 0), M["Metal"], 0.15)
        cyl(0.8, 1.2, (0, 3.4, 2.0), M["Metal"], axis="Z", d2=0.1, verts=8)
        box((0.25, 0.3, 1.6), (0.5, 3.95, -0.2), M["Glow"], 0.05)
    def rail():  # candle cluster
        M = mats(Wax=(245, 230, 200), Flame=(255, 190, 70), Metal=(90, 80, 70))
        cyl(1.4, 0.2, (0, 0.1, 0), M["Metal"], verts=12)
        for k, (x, z, h) in enumerate(((0, 0, 1.6), (0.45, 0.3, 1.0), (-0.4, 0.35, 1.2))):
            cyl(0.4, h, (x, h / 2 + 0.2, z), M["Wax"], verts=8)
            cyl(0.2, 0.4, (x, h + 0.45, z), M["Flame"], d2=0.02, verts=5)
    def hang():  # iron cage lantern with fire
        M = mats(Chain=(60, 55, 55), Metal=(70, 70, 80), Fire=(255, 130, 40))
        cyl(0.1, 5, (0, -2.5, 0), M["Chain"], verts=4, bevel=0)
        for k in range(6):
            a = k * math.pi / 3
            box((0.15, 2.6, 0.15), (math.cos(a) * 0.9, -6.3, math.sin(a) * 0.9), M["Metal"], 0)
        cyl(2.2, 0.3, (0, -5.0, 0), M["Metal"], verts=8)
        cyl(2.2, 0.3, (0, -7.6, 0), M["Metal"], verts=8)
        cyl(1.2, 2.0, (0, -6.4, 0), M["Fire"], d2=0.1, verts=6)
    return dict(Wall=wall, Backdrop=backdrop, Ceiling=ceiling, Hero=hero, Mid=mid, Rail=rail, Hang=hang)


# =====================================================================================================  ZEN
def zen():
    def wall():
        M = mats(Wall=(245, 238, 220), Wood=(80, 45, 30), Paper=(250, 245, 230), Accent=(200, 50, 50), Moon=(255, 235, 180), Pine=(60, 110, 70))
        band(M, "Wall", "Wood", "Accent")
        for z in (-26.7, 26.7):  # shoji screens
            box((0.2, 9, 12), (0.1, 28.5, z), M["Paper"], 0)
            for k in range(7):
                box((0.4, 9, 0.25), (0.25, 28.5, z - 6 + k * 2), M["Wood"], 0.02)
            for k in range(5):
                box((0.4, 0.25, 12), (0.25, 24 + k * 2.25, z), M["Wood"], 0.02)
        torus(9, 0.6, (0.4, 28.8, 0), M["Wood"], "X")  # moon window with pine branch
        cyl(8.6, 0.2, (0.1, 28.8, 0), M["Moon"], axis="X", verts=28)
        cyl(0.4, 6, (0.4, 27.5, -0.5), M["Wood"], axis="Z", verts=6)
        for k in range(5):
            sphere(1.4, (0.5, 27.8 + (k % 2) * 0.6, -2.8 + k * 1.2), M["Pine"], 8, 5, (0.4, 0.5, 1))
    def backdrop():
        M = mats(Sky=(255, 220, 200), Mount=(150, 140, 170), MountFar=(190, 180, 200), Snow=(250, 250, 255), Pagoda=(200, 60, 50), Roof=(60, 50, 50), Blossom=(255, 180, 200), Trunk=(80, 50, 40))
        box((0.4, 24, 80), (-0.2, 12, 0), M["Sky"], 0)
        for k, z in enumerate((-30, -2, 26)):
            cyl(30, 18 + k * 3, (0.2, 9, z), M["MountFar"] if k % 2 else M["Mount"], d2=2, verts=8)
            cyl(8, 4, (0.4, 16 + k * 3, z), M["Snow"], d2=1, verts=8)
        for j in range(4):  # pagoda
            box((2, 2.2, 4.6 - j * 0.7), (1.2, 2 + j * 2.6, 12), M["Pagoda"], 0.1)
            box((2.6, 0.5, 7 - j * 1.1), (1.4, 3.3 + j * 2.6, 12), M["Roof"], 0.2)
        cyl(0.3, 2, (1.4, 13.6, 12), M["Roof"], verts=6)
        for k in range(6):  # cherry trees
            z = -36 + k * 8 + (6 if k > 3 else 0)
            cyl(0.6, 4, (2.0, 2, z), M["Trunk"], verts=6)
            for j in range(4):
                leafball(2.4, (2.0, 4.4 + (j % 2), z - 1 + j * 0.7), M["Blossom"], j + k)
        sphere(80, (0.3, -2, 0), M["Mount"], 20, 8, (0.04, 0.05, 1))
    def ceiling():
        M = mats(Ceil=(240, 232, 214), Beam=(80, 45, 30), Shade=(250, 240, 220), Wood=(80, 45, 30), Glow=(255, 230, 180), Accent=(200, 50, 50))
        ceiling_base(M, "Ceil", "Beam", "Shade", "Wood", "Glow", "lantern")
        for x in range(-33, 34, 6):
            box((0.4, 0.4, 80), (x, 35.7, 0), M["Beam"], 0.05)
    def hero():  # stone lantern (toro) + bonsai
        M = mats(Stone=(160, 155, 145), Moss=(90, 140, 80), Glow=(255, 220, 150), Wood=(90, 60, 40), Leaf=(60, 120, 70), Pot=(70, 90, 120))
        cyl(2.6, 0.8, (0, 0.4, 0), M["Stone"], verts=6)
        cyl(0.9, 3.4, (0, 2.5, 0), M["Stone"], verts=6)
        cyl(3.0, 0.8, (0, 4.6, 0), M["Stone"], verts=6)
        box((2.0, 1.8, 2.0), (0, 5.9, 0), M["Stone"], 0.1)
        box((2.1, 0.9, 1.0), (0, 5.9, 0), M["Glow"], 0.05)
        cyl(4.6, 1.4, (0, 7.5, 0), M["Stone"], d2=0.6, verts=6)
        sphere(0.8, (0, 8.5, 0), M["Stone"], 8, 5)
        sphere(1.6, (0.6, 7.6, 1.2), M["Moss"], 8, 5, (1, 0.3, 1))
        box((2.4, 1.0, 1.6), (2.8, 0.5, -2.2), M["Pot"], 0.15)  # bonsai
        o = cyl(0.4, 2.6, (2.8, 2.1, -2.2), M["Wood"], d2=0.2, verts=6); rot(o, rz=20)
        for j in range(3):
            sphere(1.6, (2.5 + j * 0.4, 3.2 + (j % 2) * 0.5, -2.8 + j * 0.6), M["Leaf"], 8, 5, (1, 0.45, 1))
    def mid():  # koi basin
        M = mats(Stone=(150, 145, 135), Water=(70, 130, 160), Koi=(255, 120, 40), White=(250, 250, 250), Leaf=(70, 140, 80))
        lathe([(2.4, 0), (2.6, 0.9), (2.3, 1.0), (2.1, 0.6), (0, 0.6)], (0, 0, 0), M["Stone"], 18)
        cyl(4.2, 0.1, (0, 0.8, 0), M["Water"], verts=18)
        for k in range(3):
            sphere(0.9, (math.cos(k * 2) * 1.0, 0.85, math.sin(k * 2) * 1.0), [M["Koi"], M["White"]][k % 2], 8, 4, (0.4, 0.2, 1))
        cyl(1.4, 0.1, (-0.8, 0.86, 0.9), M["Leaf"], verts=10)
    def rail():  # tea set
        M = mats(Tray=(80, 45, 30), Cup=(240, 235, 220), Accent=(70, 120, 90))
        box((1.6, 0.15, 1.2), (0, 0.08, 0), M["Tray"], 0.05)
        lathe([(0.3, 0.15), (0.45, 0.4), (0.4, 0.75), (0.15, 0.9), (0, 0.95)], (0, 0, 0), M["Accent"], 12)
        cyl(0.15, 0.5, (0.45, 0.55, 0), M["Accent"], axis="X", d2=0.08, verts=6)
        for z in (-0.4, 0.4):
            cyl(0.35, 0.3, (-0.5, 0.3, z), M["Cup"], d2=0.28, verts=10)
    def hang():  # paper lantern
        M = mats(String=(60, 40, 30), Paper=(220, 50, 50), Wood=(40, 30, 25), Glow=(255, 220, 160))
        cyl(0.06, 4, (0, -2, 0), M["String"], verts=4, bevel=0)
        cyl(1.0, 0.4, (0, -4.2, 0), M["Wood"], verts=12)
        lathe([(0.5, -4.3), (1.6, -5.2), (1.8, -6.2), (1.6, -7.2), (0.5, -8.1)], (0, 0, 0), M["Paper"], 16)
        for y in (-5.2, -6.2, -7.2):
            torus(3.3 if y == -6.2 else 3.0, 0.08, (0, y, 0), M["Wood"])
        cyl(1.0, 0.4, (0, -8.2, 0), M["Wood"], verts=12)
    return dict(Wall=wall, Backdrop=backdrop, Ceiling=ceiling, Hero=hero, Mid=mid, Rail=rail, Hang=hang)


# =====================================================================================================  SPACE
def space():
    def wall():
        M = mats(Wall=(40, 40, 70), Trim=(150, 160, 190), Accent=(120, 90, 255), Space=(15, 15, 40), Star=(255, 255, 230), Planet=(255, 150, 90), Metal=(180, 185, 200))
        band(M, "Wall", "Trim", "Accent")
        for z in (-26.7, 0, 26.7):  # observatory windows
            box((0.2, 9, 10), (0.1, 28.6, z), M["Space"], 0)
            for k in range(10):
                sphere(0.3 + (k % 3) * 0.1, (0.3, 24.6 + (k * 7 % 9), z - 4.5 + (k * 13 % 10) * 0.95), M["Star"], 5, 3)
            sphere(2.6, (0.4, 30, z + 2), M["Planet"], 14, 8, (0.3, 1, 1))
            torus(5, 0.2, (0.5, 30, z + 2), M["Metal"], "X")
            box((0.8, 0.8, 11), (0.4, 33.4, z), M["Metal"], 0.15)
            box((0.8, 0.8, 11), (0.4, 23.8, z), M["Metal"], 0.15)
            for s in (-1, 1):
                box((0.8, 10.4, 0.8), (0.4, 28.6, z + s * 5.3), M["Metal"], 0.15)
                for j in range(4):
                    cyl(0.4, 0.3, (0.9, 25 + j * 2.6, z + s * 5.3), M["Accent"], axis="X", verts=8)
    def backdrop():
        M = mats(Space=(20, 20, 50), Star=(255, 255, 230), Moon=(190, 190, 200), Crater=(140, 140, 150), Planet=(255, 150, 90), Ring=(220, 200, 160), Accent=(120, 90, 255))
        box((0.4, 24, 80), (-0.2, 12, 0), M["Space"], 0)
        for k in range(60):
            sphere(0.2 + R.random() * 0.25, (0.1, R.uniform(4, 23.5), R.uniform(-39, 39)), M["Star"], 4, 3)
        sphere(9, (0.4, 17, -22), M["Planet"], 18, 10, (0.15, 1, 1))
        o = torus(15, 0.8, (0.5, 17, -22), M["Ring"], "X"); o.scale = (1, 1, 0.35); rot(o, rx=20)
        sphere(4, (0.4, 19, 20), M["Accent"], 12, 8, (0.2, 1, 1))
        sphere(84, (0.6, -1, 0), M["Moon"], 32, 10, (0.06, 0.1, 1))  # lunar ground
        for k in range(9):
            sphere(5 + k % 3, (1.2, 0.5 + (k % 3) * 0.6, -36 + k * 9), M["Moon"], 12, 6, (0.5, 0.45, 1))  # hills
            o = torus(2.6 + k % 2, 0.45, (2.4, 1.6 + (k % 2) * 0.3, -32 + k * 9), M["Crater"]); rot(o, rz=-25)
        o = lathe([(0.9, 0), (1.0, 3), (0.7, 4.6), (0, 5.6)], (1.8, 2, 8), M["Ring"], 10)  # tiny rocket on the moon
    def ceiling():
        M = mats(Ceil=(30, 30, 60), Beam=(150, 160, 190), Shade=(70, 60, 140), Metal=(190, 195, 210), Glow=(220, 230, 255), Star=(255, 255, 230))
        ceiling_base(M, "Ceil", "Beam", "Shade", "Metal", "Glow", "dome")
        for k in range(70):
            sphere(0.25 + R.random() * 0.2, (R.uniform(-34, 34), 35.95, R.uniform(-39, 39)), M["Star"], 4, 3)
    def hero():  # rocket on launch pad
        M = mats(Body=(240, 240, 250), Accent=(220, 60, 60), Window=(90, 180, 255), Metal=(150, 155, 170), Flame=(255, 170, 60))
        cyl(5, 0.6, (0, 0.3, 0), M["Metal"], verts=12)
        lathe([(1.3, 1.6), (1.6, 3), (1.7, 6), (1.5, 8.5), (1.0, 10.5), (0.4, 11.8), (0, 12.3)], (0, 0, 0), M["Body"], 16)
        torus(3.4, 0.25, (0, 6.2, 0), M["Accent"])
        cyl(1.4, 0.3, (1.5, 7.5, 0), M["Window"], axis="X", verts=14)
        torus(1.6, 0.18, (1.62, 7.5, 0), M["Metal"], "X")
        for k in range(4):
            a = k * math.pi / 2
            o = box((0.3, 3, 1.6), (math.cos(a) * 1.9, 2.8, math.sin(a) * 1.9), M["Accent"], 0.1); rot(o, ry=math.degrees(-a))
        cyl(1.6, 1.0, (0, 1.2, 0), M["Metal"], d2=1.1, verts=12)
        cyl(1.2, 1.2, (0, 0.6, 0), M["Flame"], d2=0.2, verts=8)
    def mid():  # satellite dish
        M = mats(Metal=(190, 195, 210), Dish=(240, 240, 250), Accent=(120, 90, 255), Dark=(60, 60, 80))
        box((2.4, 0.6, 2.4), (0, 0.3, 0), M["Dark"], 0.1)
        cyl(0.5, 3, (0, 2, 0), M["Metal"], verts=8)
        o = lathe([(0, 0), (1.0, 0.1), (2.0, 0.45), (2.6, 0.9)], (0, 0, 0), M["Dish"], 18, axis_rot=None)
        o.location = rb(0.3, 3.6, 0); spin(o, (0, math.radians(-50), 0))
        cyl(0.15, 1.8, (0.9, 4.4, 0), M["Metal"], verts=4, bevel=0)
        sphere(0.4, (1.4, 4.9, 0), M["Accent"], 6, 4)
    def rail():  # mini planet on stand
        M = mats(Stand=(60, 60, 80), Planet=(255, 150, 90), Ring=(220, 200, 160))
        cyl(0.9, 0.2, (0, 0.1, 0), M["Stand"], verts=10)
        cyl(0.12, 0.6, (0, 0.4, 0), M["Stand"], verts=5)
        sphere(0.9, (0, 1.2, 0), M["Planet"], 12, 8)
        o = torus(1.6, 0.08, (0, 1.2, 0), M["Ring"]); rot(o, rx=25)
    def hang():  # planet mobile
        M = mats(Wire=(200, 200, 220), P1=(255, 150, 90), P2=(120, 200, 255), P3=(255, 220, 120), Accent=(120, 90, 255))
        cyl(0.06, 3, (0, -1.5, 0), M["Wire"], verts=4, bevel=0)
        cyl(0.08, 6, (0, -3, 0), M["Wire"], axis="X", verts=4, bevel=0)
        cyl(0.08, 6, (0, -3, 0), M["Wire"], axis="Z", verts=4, bevel=0)
        for k, (x, z, d, m) in enumerate(((3, 0, 1.4, "P1"), (-3, 0, 1.0, "P2"), (0, 3, 1.2, "P3"), (0, -3, 0.9, "Accent"))):
            cyl(0.05, 1.5 + k * 0.5, (x, -3.75 - k * 0.25, z), M["Wire"], verts=4, bevel=0)
            sphere(d, (x, -4.6 - k * 0.5, z), M[m], 10, 6)
        sphere(1.8, (0, -3.2, 0), M["P3"], 12, 8)
    return dict(Wall=wall, Backdrop=backdrop, Ceiling=ceiling, Hero=hero, Mid=mid, Rail=rail, Hang=hang)


# =====================================================================================================  CLOCK
def clock():
    def gear(c, d, t, m, teeth=12, axis="X"):
        cyl(d, t, c, m, axis=axis, verts=24)
        for k in range(teeth):
            a = 2 * math.pi * k / teeth
            if axis == "X":
                o = box((t, d * 0.14, d * 0.14), (c[0], c[1] + math.sin(a) * d / 2, c[2] + math.cos(a) * d / 2), m, 0.02); rot(o, rx=-math.degrees(a))
            else:
                o = box((d * 0.14, t, d * 0.14), (c[0] + math.cos(a) * d / 2, c[1], c[2] + math.sin(a) * d / 2), m, 0.02); rot(o, ry=math.degrees(-a))
    def wall():
        M = mats(Wall=(70, 50, 40), Trim=(150, 110, 60), Accent=(40, 110, 100), Brass=(220, 170, 80), Copper=(200, 120, 70), Face=(245, 235, 210), Ink=(30, 25, 20))
        band(M, "Wall", "Trim", "Accent")
        cyl(9.6, 0.4, (0.2, 29, 0), M["Face"], axis="X", verts=32)  # big clock face
        torus(10, 0.7, (0.5, 29, 0), M["Brass"], "X")
        for k in range(12):
            a = k * math.pi / 6
            box((0.3, 0.9 if k % 3 else 1.5, 0.3), (0.5, 29 + math.cos(a) * 3.9, math.sin(a) * 3.9), M["Ink"], 0)
        o = box((0.3, 3.4, 0.4), (0.7, 30.4, 0.5), M["Ink"], 0.05); rot(o, rx=-20)
        o = box((0.3, 2.3, 0.4), (0.7, 28.5, -0.8), M["Ink"], 0.05); rot(o, rx=-120)
        for z, d in ((-26.7, 8), (-20, 4), (26.7, 8), (21, 4.5), (-31, 3.4), (31, 3)):
            gear((0.4, 28.5 + (d < 5) * 3, z), d, 0.5, M["Brass"] if d > 5 else M["Copper"], 14 if d > 5 else 9)
            cyl(d * 0.25, 0.7, (0.6, 28.5 + (d < 5) * 3, z), M["Accent"], axis="X", verts=10)
    def backdrop():
        M = mats(Sky=(250, 200, 150), City=(120, 90, 70), CityFar=(170, 130, 100), Brass=(220, 170, 80), Copper=(200, 120, 70), Steam=(240, 235, 230), Glow=(255, 210, 120))
        box((0.4, 24, 80), (-0.2, 12, 0), M["Sky"], 0)
        for k in range(12):  # clockwork city skyline
            z, h = -37 + k * 6.6, 6 + (k * 7 % 9)
            box((1.2, h, 5), (0.4, h / 2, z), M["CityFar"] if k % 2 else M["City"], 0.1)
            for j in range(int(h // 2)):
                box((0.3, 0.7, 0.8), (1.05, 1.2 + j * 1.8, z + 1.2), M["Glow"], 0.02)
            if k % 3 == 0:
                cyl(1.2, 3, (0.8, h + 1.5, z), M["Copper"], verts=8)
                for j in range(3):
                    sphere(2 + j, (0.6, h + 4 + j * 2, z + j), M["Steam"], 8, 5)
        gear((0.9, 16, 12), 9, 0.6, M["Brass"], 16)
        cyl(2, 1.2, (1.4, 16, 12), M["Copper"], axis="X", verts=12)
        sphere(8, (1.2, 20, -16), M["Copper"], 16, 8, (0.3, 0.35, 1))
        box((0.8, 0.8, 2.4), (1.4, 18.2, -16), M["City"], 0.1)
    def ceiling():
        M = mats(Ceil=(80, 60, 45), Beam=(150, 110, 60), Shade=(40, 110, 100), Brass=(220, 170, 80), Glow=(255, 220, 160), Copper=(200, 120, 70))
        ceiling_base(M, "Ceil", "Beam", "Shade", "Brass", "Glow", "dome")
        for x in (-23.3, 23.3):
            for z in (-26.7, 0, 26.7):
                gear((x, 35.6, z), 9, 0.5, M["Copper"], 14, axis="Y")
                cyl(2, 0.8, (x, 35.3, z), M["Brass"], verts=12)
        for x in (-11.7, 11.7):  # copper pipes
            cyl(0.8, 80, (x + 1.5, 34.3, 0), M["Copper"], axis="Z", verts=10)
    def hero():  # grandfather clock
        M = mats(Wood=(110, 60, 35), Trim=(220, 170, 80), Face=(245, 235, 210), Ink=(30, 25, 20), Glass=(180, 210, 230), Brass=(220, 170, 80))
        box((2.6, 1.0, 1.8), (0, 0.5, 0), M["Wood"], 0.1)
        box((2.0, 6.4, 1.4), (0, 4.2, 0), M["Wood"], 0.1)
        box((0.2, 4.6, 1.0), (1.0, 4.0, 0), M["Glass"], 0)
        cyl(0.12, 3.4, (1.05, 4.6, 0), M["Brass"], verts=4, bevel=0)
        cyl(1.1, 0.2, (1.1, 2.8, 0), M["Brass"], axis="X", verts=14)
        box((2.8, 3.0, 2.0), (0, 8.9, 0), M["Wood"], 0.15)
        cyl(2.2, 0.2, (1.05, 8.9, 0), M["Face"], axis="X", verts=20)
        torus(2.3, 0.15, (1.15, 8.9, 0), M["Trim"], "X")
        for k in range(12):
            a = k * math.pi / 6
            box((0.1, 0.35, 0.1), (1.2, 8.9 + math.cos(a) * 0.85, math.sin(a) * 0.85), M["Ink"], 0)
        o = box((3.2, 0.6, 2.2), (0, 10.6, 0), M["Wood"], 0.2)
        sphere(0.6, (0, 11.2, 0), M["Trim"], 8, 5)
    def mid():  # gear sculpture on stand
        M = mats(Stand=(80, 60, 45), Brass=(220, 170, 80), Copper=(200, 120, 70), Accent=(40, 110, 100))
        box((2.6, 0.6, 1.4), (0, 0.3, 0), M["Stand"], 0.1)
        cyl(0.4, 3, (0, 1.8, 0), M["Stand"], verts=8)
        gear((0, 3.6, -0.4), 3.2, 0.4, M["Brass"], 12, axis="Z")
        gear((0, 2.4, 0.2), 1.8, 0.4, M["Copper"], 8, axis="Z")
        cyl(0.7, 0.8, (0, 3.6, 0), M["Accent"], axis="Z", verts=10)
    def rail():  # pocket watch on stand
        M = mats(Brass=(220, 170, 80), Face=(245, 235, 210), Ink=(30, 25, 20), Wood=(110, 60, 35))
        box((1.2, 0.2, 0.8), (0, 0.1, 0), M["Wood"], 0.04)
        o = box((0.12, 1.4, 0.12), (-0.2, 0.8, 0), M["Brass"], 0)
        cyl(1.1, 0.25, (0, 1.0, 0), M["Brass"], axis="X", verts=18)
        cyl(0.9, 0.08, (0.15, 1.0, 0), M["Face"], axis="X", verts=18)
        box((0.05, 0.4, 0.05), (0.2, 1.15, 0), M["Ink"], 0)
        torus(0.4, 0.06, (0, 1.65, 0), M["Brass"], "X")
    def hang():  # pendulum
        M = mats(Brass=(220, 170, 80), Copper=(200, 120, 70), Rod=(110, 90, 60))
        cyl(0.15, 7, (0, -3.5, 0), M["Rod"], verts=6, bevel=0)
        cyl(2.0, 0.4, (0, -7.4, 0), M["Brass"], axis="X", verts=20)
        torus(2.1, 0.2, (0.15, -7.4, 0), M["Copper"], "X")
        gear((0, -0.8, 0), 2.4, 0.3, M["Copper"], 10)
    return dict(Wall=wall, Backdrop=backdrop, Ceiling=ceiling, Hero=hero, Mid=mid, Rail=rail, Hang=hang)


# =====================================================================================================  GARDEN (lotus / rain)
def garden():
    def wall():
        M = mats(Wall=(220, 240, 225), Frame=(250, 250, 245), Accent=(240, 120, 170), Glass=(190, 230, 220), Leaf=(70, 150, 80), Vine=(60, 120, 60))
        band(M, "Wall", "Frame", "Accent")
        for z in (-26.7, 0, 26.7):  # greenhouse arches
            box((0.2, 9, 9), (0.1, 28, z), M["Glass"], 0)
            arch_frame(z, 9, 23.5, 10, M["Frame"], 0.5)
            for j in (-2.2, 0, 2.2):
                box((0.35, 9, 0.2), (0.3, 27.5, z + j), M["Frame"], 0)
        for k in range(30):  # climbing vine with flowers
            z = -40 + k * 2.75
            leafball(1.3, (0.6, 24 + abs(math.sin(k * 0.7)) * 9, z), M["Leaf"], k)
            if k % 2:
                sphere(0.6, (1.1, 24.6 + abs(math.sin(k * 0.7)) * 9, z), M["Accent"], 6, 4)
    def backdrop():
        M = mats(Sky=(200, 235, 230), Water=(90, 170, 190), Pad=(70, 150, 80), Lotus=(255, 170, 200), Accent=(240, 120, 170), Leaf=(60, 130, 70), Reed=(120, 150, 70))
        box((0.4, 24, 80), (-0.2, 12, 0), M["Sky"], 0)
        for k in range(6):
            sphere(22, (0.3, 0, -36 + k * 14), M["Leaf"], 12, 6, (0.08, 0.45, 1))
        box((3, 0.3, 80), (1.5, 0.3, 0), M["Water"], 0.1)
        for k in range(12):  # pads + lotus
            z = -36 + k * 6.4
            cyl(2.2 + k % 2, 0.15, (1.8, 0.5, z), M["Pad"], verts=12)
            if k % 2 == 0:
                for j in range(6):
                    a = j * math.pi / 3
                    o = sphere(0.9, (1.8 + math.cos(a) * 0.5, 1.0, z + math.sin(a) * 0.5), M["Lotus"], 6, 4, (0.5, 1, 0.5)); rot(o, rx=math.degrees(a) * 0.2)
                sphere(0.6, (1.8, 1.2, z), M["Accent"], 6, 4)
        for k in range(16):
            cyl(0.15, 3 + k % 3, (1.0, 2, -38 + k * 5), M["Reed"], verts=4, bevel=0)
    def ceiling():
        M = mats(Ceil=(235, 248, 240), Beam=(250, 250, 245), Shade=(240, 140, 180), Brass=(220, 200, 150), Glow=(255, 240, 220), Glass=(200, 235, 230), Leaf=(70, 150, 80))
        box((70, 1, 80), (0, 36.5, 0), M["Glass"], 0)
        for x in range(-35, 36, 7):
            box((0.5, 0.8, 80), (x, 35.7, 0), M["Beam"], 0.08)
        for z in range(-40, 41, 8):
            box((70, 0.8, 0.5), (0, 35.7, z), M["Beam"], 0.08)
        for z in (-26.7, 0, 26.7):
            lamp_billiard(z, M["Shade"], M["Brass"], M["Glow"], "dome")
        for k in range(20):
            leafball(1.6, (R.choice((-23, 23)) + R.uniform(-8, 8), 35, R.uniform(-38, 38)), M["Leaf"], k)
    def hero():  # tiered fountain
        M = mats(Stone=(230, 225, 215), Water=(110, 190, 220), Accent=(240, 120, 170), Moss=(90, 150, 90))
        lathe([(3.4, 0), (3.5, 1.2), (3.1, 1.2), (3.1, 0.4), (0, 0.4)], (0, 0, 0), M["Stone"], 20)
        cyl(6.2, 0.1, (0, 1.0, 0), M["Water"], verts=20)
        cyl(0.8, 4, (0, 3, 0), M["Stone"], verts=10)
        lathe([(0.6, 4.4), (2.2, 5.0), (2.3, 5.4), (0, 5.2)], (0, 0, 0), M["Stone"], 16)
        cyl(0.5, 2.4, (0, 6.4, 0), M["Stone"], verts=8)
        lathe([(0.4, 7.4), (1.3, 7.8), (1.4, 8.1), (0, 8.0)], (0, 0, 0), M["Stone"], 14)
        sphere(0.8, (0, 8.6, 0), M["Accent"], 8, 6)
        for k in range(8):
            a = k * math.pi / 4
            o = cyl(0.25, 1.6, (math.cos(a) * 2.0, 4.6, math.sin(a) * 2.0), M["Water"], d2=0.1, verts=4); rot(o, rx=0)
        for k in range(6):
            sphere(0.8, (math.cos(k) * 3.4, 1.2, math.sin(k) * 3.4), M["Moss"], 6, 4)
    def mid():  # flower pot
        M = mats(Pot=(200, 110, 70), Leaf=(70, 150, 80), Accent=(240, 120, 170), Center=(255, 220, 90))
        lathe([(0.9, 0), (1.3, 1.6), (1.45, 1.8), (0, 1.8)], (0, 0, 0), M["Pot"], 14)
        for k in range(5):
            a = k * 1.25
            cyl(0.15, 2 + k % 2, (math.cos(a) * 0.5, 2.6 + (k % 2) * 0.5, math.sin(a) * 0.5), M["Leaf"], verts=4, bevel=0)
            for j in range(5):
                b = j * 1.256
                sphere(0.6, (math.cos(a) * 0.5 + math.cos(b) * 0.4, 3.6 + (k % 2), math.sin(a) * 0.5 + math.sin(b) * 0.4), M["Accent"], 6, 4)
            sphere(0.4, (math.cos(a) * 0.5, 3.7 + (k % 2), math.sin(a) * 0.5), M["Center"], 6, 4)
            leafball(0.8, (math.cos(a) * 0.9, 2.2, math.sin(a) * 0.9), M["Leaf"], k)
    def rail():  # potted succulent
        M = mats(Pot=(240, 240, 235), Leaf=(110, 170, 120), Accent=(240, 120, 170))
        cyl(0.9, 0.7, (0, 0.35, 0), M["Pot"], d2=1.1, verts=12)
        for k in range(8):
            a = k * math.pi / 4
            o = sphere(0.5, (math.cos(a) * 0.3, 0.9, math.sin(a) * 0.3), M["Leaf"], 6, 4, (0.6, 1.4, 0.6)); spin(o, (math.sin(a) * 0.6, -math.cos(a) * 0.6, 0))
        sphere(0.3, (0, 1.2, 0), M["Accent"], 6, 4)
    def hang():  # hanging fern
        M = mats(Chain=(100, 90, 80), Pot=(240, 240, 235), Leaf=(70, 150, 80))
        cyl(0.08, 5, (0, -2.5, 0), M["Chain"], verts=4, bevel=0)
        lathe([(0, -6.8), (1.0, -6.6), (1.2, -5.2), (0, -5.2)], (0, 0, 0), M["Pot"], 12)
        for k in range(12):
            a = k * math.pi / 6
            o = cyl(0.5, 2.8, (math.cos(a) * 1.4, -6.2, math.sin(a) * 1.4), M["Leaf"], d2=0.1, verts=4); spin(o, (math.sin(a) * 1.0, -math.cos(a) * 1.0, 0))
    return dict(Wall=wall, Backdrop=backdrop, Ceiling=ceiling, Hero=hero, Mid=mid, Rail=rail, Hang=hang)


# =====================================================================================================  PIXEL
def pixel():
    def wall():
        M = mats(Wall=(30, 25, 55), Trim=(60, 50, 110), Accent=(0, 230, 255), Neon2=(255, 60, 200), Neon3=(255, 230, 60), Glow=(120, 255, 120))
        band(M, "Wall", "Trim", "Accent")
        HEART = ["01100110", "11111111", "11111111", "01111110", "00111100", "00011000"]
        for z, m in ((-26.7, "Neon2"), (0, "Neon3"), (26.7, "Glow")):  # pixel art icons
            for r, row in enumerate(HEART):
                for c, ch in enumerate(row):
                    if ch == "1":
                        box((0.5, 1.0, 1.0), (0.3, 32 - r * 1.05, z - 3.7 + c * 1.05), M[m], 0.05)
        for y in (24.4, 34.2):
            box((0.3, 0.3, 80), (0.3, y, 0), M["Accent"], 0)
        for z in (-13.3, 13.3):
            for k in range(8):
                box((0.4, 0.8, 0.8), (0.3, 24.8 + k * 1.15, z), [M["Accent"], M["Neon2"]][k % 2], 0.03)
    def backdrop():
        M = mats(Sky=(40, 20, 80), Grid=(255, 60, 200), Sun=(255, 160, 60), Mount=(80, 40, 140), Accent=(0, 230, 255), Block=(70, 180, 90), Dirt=(140, 90, 50))
        box((0.4, 24, 80), (-0.2, 12, 0), M["Sky"], 0)
        for k in range(6):  # synth sun stripes
            box((0.3, 1.2, 14 - k * 1.5), (0.1, 18 - k * 1.8, 0), M["Sun"], 0)
        for k in range(16):  # voxel mountains
            z = -39 + k * 5
            h = 3 + (k * 5 % 7)
            for j in range(h):
                box((1.2, 1.6, 5), (0.5, 0.8 + j * 1.6, z), M["Mount"] if j < h - 1 else M["Accent"], 0)
        for k in range(20):  # neon floor grid
            box((3, 0.2, 0.2), (1.6, 0.2, -38 + k * 4), M["Grid"], 0)
        box((0.2, 0.2, 80), (2.8, 0.2, 0), M["Grid"], 0)
        for k in range(5):  # blocky trees
            z = -30 + k * 14
            box((1.2, 3, 1.2), (2.0, 1.5, z), M["Dirt"], 0)
            box((2.4, 2.4, 3.6), (2.0, 4.2, z), M["Block"], 0)
    def ceiling():
        M = mats(Ceil=(25, 20, 45), Beam=(60, 50, 110), Shade=(255, 60, 200), Metal=(180, 180, 200), Glow=(220, 255, 255), Accent=(0, 230, 255))
        ceiling_base(M, "Ceil", "Beam", "Shade", "Metal", "Glow", "lantern")
        for x in (-23.3, 23.3):
            for k in range(9):
                box((0.4, 0.3, 14), (x - 8 + k * 2, 35.8, 0), M["Accent"] if k % 2 else M["Shade"], 0)
    def hero():  # arcade cabinet
        M = mats(Body=(40, 30, 80), Accent=(0, 230, 255), Screen=(60, 255, 170), Panel=(30, 30, 40), Button=(255, 60, 200), Marquee=(255, 230, 60))
        box((3.0, 8, 2.6), (0, 4, 0), M["Body"], 0.1)
        box((0.2, 3.0, 2.2), (1.5, 6.0, 0), M["Screen"], 0)
        o = box((1.6, 0.4, 2.4), (1.6, 4.2, 0), M["Panel"], 0.05); rot(o, rz=-18)
        for z in (-0.6, 0, 0.6):
            cyl(0.35, 0.3, (1.9, 4.5, z), M["Button"], verts=10)
        cyl(0.2, 0.7, (1.8, 4.7, -0.9), M["Panel"], verts=6)
        sphere(0.45, (1.8, 5.1, -0.9), M["Button"], 8, 5)
        box((0.4, 1.2, 2.6), (1.4, 8.3, 0), M["Marquee"], 0.05)
        for s in (-1, 1):
            box((3.0, 8.4, 0.2), (0, 4.2, s * 1.35), M["Accent"], 0.02)
    def mid():  # pixel heart statue
        M = mats(Base=(40, 30, 80), Accent=(255, 60, 200), Shine=(255, 200, 240))
        box((3, 0.6, 1.4), (0, 0.3, 0), M["Base"], 0.05)
        HEART = ["0110110", "1111111", "1111111", "0111110", "0011100", "0001000"]
        for r, row in enumerate(HEART):
            for c, ch in enumerate(row):
                if ch == "1":
                    box((0.7, 0.7, 0.7), (0, 4.6 - r * 0.7, -2.1 + c * 0.7), M["Shine"] if (r, c) == (1, 1) else M["Accent"], 0.02)
    def rail():  # spinning coin
        M = mats(Gold=(255, 210, 60), Shine=(255, 250, 200), Base=(40, 30, 80))
        cyl(0.8, 0.2, (0, 0.1, 0), M["Base"], verts=8)
        cyl(1.3, 0.25, (0, 1.0, 0), M["Gold"], axis="X", verts=8)
        box((0.3, 0.6, 0.15), (0.15, 1.0, 0), M["Shine"], 0)
    def hang():  # neon cube
        M = mats(Wire=(180, 180, 200), Accent=(0, 230, 255), Neon2=(255, 60, 200))
        cyl(0.06, 4, (0, -2, 0), M["Wire"], verts=4, bevel=0)
        for a in (-1, 1):
            for b in (-1, 1):
                box((0.25, 2.6, 0.25), (a * 1.2, -5.3, b * 1.2), M["Accent"], 0)
                box((2.6, 0.25, 0.25), (0, -5.3 + a * 1.2, b * 1.2), M["Neon2"], 0)
                box((0.25, 0.25, 2.6), (a * 1.2, -5.3 + b * 1.2, 0), M["Accent"], 0)
    return dict(Wall=wall, Backdrop=backdrop, Ceiling=ceiling, Hero=hero, Mid=mid, Rail=rail, Hang=hang)


# =====================================================================================================  SKY (cloud / storm / kites / sail)
def sky():
    def cloud(c, s, m, seed=0):
        for k, (x, y, z, d) in enumerate(((0, 0, 0, 1.0), (0, 0.15, 0.7, 0.8), (0, 0.1, -0.7, 0.75), (0, 0.45, 0.2, 0.8), (0, 0.4, -0.3, 0.7))):
            bumpy(sphere(d * s, (c[0] + x * s, c[1] + y * s, c[2] + z * s), m, 10, 6), 0.03 * s, seed + k)
    def wall():
        M = mats(Wall=(170, 210, 245), Trim=(250, 250, 255), Accent=(255, 200, 80), Cloud=(255, 255, 255), Bolt=(255, 230, 90), Kite=(240, 80, 80))
        band(M, "Wall", "Trim", "Accent")
        for k, z in enumerate((-30, -10, 10, 30)):
            cloud((0.6, 29 + (k % 2) * 2, z), 4.2, M["Cloud"], k * 7)
        for z in (-20, 20):  # kites
            o = box((0.3, 3, 3), (0.5, 30, z), M["Kite"], 0.05); rot(o, rx=45)
            o = box((0.25, 3.2, 0.12), (0.55, 30, z), M["Trim"], 0); rot(o, rx=45)
            for j in range(5):
                box((0.2, 0.6, 0.3), (0.45, 27.8 - j * 0.7, z + math.sin(j) * 0.5), [M["Accent"], M["Kite"]][j % 2], 0)
        for z in (-38, 38):
            o = box((0.3, 3, 0.5), (0.6, 31, z), M["Bolt"], 0); rot(o, rx=25)
            o = box((0.3, 3, 0.5), (0.6, 28.6, z + 0.4), M["Bolt"], 0); rot(o, rx=-25)
    def backdrop():
        M = mats(Sky=(150, 200, 250), Cloud=(255, 255, 255), CloudDark=(200, 210, 230), Island=(120, 170, 90), Rock=(150, 130, 110), Accent=(255, 200, 80), Balloon=(240, 80, 80))
        box((0.4, 24, 80), (-0.2, 12, 0), M["Sky"], 0)
        for k in range(10):
            cloud((0.5 + (k % 2), 3 + (k * 7 % 16), -36 + k * 8), 3 + k % 3, M["Cloud"] if k % 3 else M["CloudDark"], k)
        for k, (z, y) in enumerate(((-18, 12), (16, 16))):  # floating islands
            cyl(9, 1.4, (1.2, y, z), M["Island"], verts=12)
            cyl(8, 4, (1.2, y - 2.6, z), M["Rock"], d2=1, verts=10)
            leafball(3, (1.4, y + 2, z - 1.5), M["Island"], k)
            cyl(0.5, 2, (1.4, y + 1, z - 1.5), M["Rock"], verts=6)
        lathe([(0, 8), (1.6, 8.6), (2.4, 10), (2.3, 11.6), (1.4, 12.8), (0, 13.2)], (1.6, 0, 2), M["Balloon"], 14)  # balloon
        box((0.9, 0.8, 0.9), (1.6, 7, 2), M["Rock"], 0.1)
    def ceiling():
        M = mats(Ceil=(160, 205, 250), Beam=(250, 250, 255), Shade=(255, 200, 80), Brass=(230, 230, 240), Glow=(255, 250, 230), Cloud=(255, 255, 255))
        ceiling_base(M, "Ceil", "Beam", "Shade", "Brass", "Glow", "dome")
        for k in range(10):
            cloud((R.choice((-23, 23)) + R.uniform(-7, 7), 34.2, R.uniform(-36, 36)), 3.5, M["Cloud"], k)
    def hero():  # hot air balloon
        M = mats(Balloon=(240, 80, 80), Stripe=(255, 220, 90), Basket=(170, 120, 60), Rope=(120, 90, 60), Accent=(90, 160, 240))
        box((2.4, 1.6, 2.4), (0, 1.6, 0), M["Basket"], 0.15)
        for a in (-1, 1):
            for b in (-1, 1):
                cyl(0.1, 3, (a * 1.0, 3.9, b * 1.0), M["Rope"], verts=4, bevel=0)
        lathe([(0.8, 5.4), (1.6, 6.2), (3.4, 8.6), (4.0, 10.6), (3.6, 12.6), (2.2, 14), (0, 14.5)], (0, 0, 0), M["Balloon"], 16)
        for y, r in ((8.6, 3.5), (10.6, 4.1), (12.6, 3.7)):
            torus(r * 2, 0.3, (0, y, 0), M["Stripe"] if y != 10.6 else M["Accent"])
        cyl(4, 0.4, (0, 0.2, 0), M["Rope"], verts=12)
    def mid():  # weather vane on post
        M = mats(Post=(90, 90, 100), Metal=(60, 60, 70), Accent=(255, 200, 80), Base=(150, 130, 110))
        cyl(1.6, 0.8, (0, 0.4, 0), M["Base"], verts=8)
        cyl(0.3, 5, (0, 3.2, 0), M["Post"], verts=6)
        cyl(0.1, 2.4, (0, 5.2, 0), M["Metal"], axis="X", verts=4, bevel=0)
        cyl(0.1, 2.4, (0, 5.2, 0), M["Metal"], axis="Z", verts=4, bevel=0)
        box((0.2, 0.8, 2.6), (0, 6.2, 0), M["Accent"], 0.05)
        cyl(0.6, 0.6, (0, 6.2, -1.6), M["Accent"], axis="Z", d2=0.05, verts=4)
    def rail():  # cloud lamp
        M = mats(Cloud=(255, 255, 255), Glow=(255, 240, 180), Base=(90, 160, 240))
        cyl(0.8, 0.25, (0, 0.12, 0), M["Base"], verts=10)
        cyl(0.1, 0.5, (0, 0.5, 0), M["Base"], verts=4)
        cloud((0, 1.1, 0), 0.9, M["Cloud"])
        o = box((0.12, 0.6, 0.3), (0.45, 0.9, 0), M["Glow"], 0)
    def hang():  # kite with tail
        M = mats(String=(240, 240, 240), Kite=(240, 80, 80), Accent=(255, 200, 80), Frame=(120, 90, 60))
        cyl(0.05, 4, (0, -2, 0), M["String"], verts=4, bevel=0)
        o = box((0.2, 3.4, 3.4), (0, -6, 0), M["Kite"], 0.05); rot(o, rx=45)
        o = box((0.15, 4.6, 0.15), (0.12, -6, 0), M["Frame"], 0)
        o = box((0.15, 0.15, 4.6), (0.12, -6, 0), M["Frame"], 0)
        for j in range(5):
            box((0.15, 0.4, 0.8), (0, -8.8 - j * 0.6, math.sin(j) * 0.4), [M["Accent"], M["Kite"]][j % 2], 0)
    return dict(Wall=wall, Backdrop=backdrop, Ceiling=ceiling, Hero=hero, Mid=mid, Rail=rail, Hang=hang)


# =====================================================================================================  ROYAL
def royal():
    def wall():
        M = mats(Wall=(110, 30, 50), Trim=(240, 230, 210), Accent=(70, 60, 180), Gold=(240, 190, 70), Canvas=(80, 120, 160), Canvas2=(200, 150, 90))
        band(M, "Wall", "Gold", "Accent")
        for z, cm in ((-26.7, "Canvas"), (0, "Canvas2"), (26.7, "Canvas")):  # gilded paintings
            box((0.3, 8, 10), (0.15, 28.6, z), M["Gold"], 0.2)
            box((0.32, 6.6, 8.6), (0.25, 28.6, z), M[cm], 0)
            sphere(3, (0.35, 27.5, z + 1.5), M["Canvas2"] if cm == "Canvas" else M["Canvas"], 10, 6, (0.05, 0.6, 1))
            box((0.6, 1.0, 2.2), (0.4, 33.4, z), M["Gold"], 0.2)
        for z in (-13.3, 13.3):  # crests with crossed banners
            box((0.4, 4, 3), (0.3, 29, z), M["Accent"], 0.4)
            box((0.45, 1.2, 1.2), (0.5, 29.5, z), M["Gold"], 0.1)
            for s in (-1, 1):
                o = box((0.25, 6, 0.25), (0.6, 29, z), M["Gold"], 0); rot(o, rx=s * 30)
    def backdrop():
        M = mats(Sky=(150, 180, 230), Hill=(90, 150, 80), Castle=(210, 205, 195), Roof=(70, 60, 180), Flag=(220, 40, 60), Gold=(240, 190, 70), Accent=(70, 60, 180))
        box((0.4, 24, 80), (-0.2, 12, 0), M["Sky"], 0)
        for k in range(5):
            sphere(26, (0.3, -2, -36 + k * 18), M["Hill"], 14, 6, (0.06, 0.4, 1))
        box((1.4, 8, 20), (0.8, 6, 0), M["Castle"], 0.1)  # castle
        for k in range(10):
            box((1.5, 1, 1.2), (0.8, 10.5, -9.5 + k * 2.1), M["Castle"], 0.05)
        for z, h in ((-11, 14), (11, 14), (0, 18)):
            cyl(4.4, h, (1.2, h / 2, z), M["Castle"], verts=12)
            cyl(5.4, 4, (1.2, h + 2, z), M["Roof"], d2=0.1, verts=12)
            cyl(0.15, 2.4, (1.2, h + 5, z), M["Gold"], verts=4, bevel=0)
            box((0.1, 1, 1.6), (1.2, h + 5.6, z + 0.8), M["Flag"], 0)
        arch_frame(0, 4, 2, 5, M["Gold"], 0.4, x=1.4)
    def ceiling():
        M = mats(Ceil=(245, 238, 225), Beam=(240, 190, 70), Shade=(70, 60, 180), Gold=(240, 190, 70), Glow=(255, 240, 200), Crystal=(230, 240, 255), Fresco=(150, 180, 230))
        box((70, 1, 80), (0, 36.5, 0), M["Ceil"], 0)
        for x in (-23.3, 23.3):
            for z in (-26.7, 0, 26.7):
                box((18, 0.2, 22), (x, 35.95, z), M["Fresco"], 0)
                box((19, 0.5, 0.6), (x, 35.8, z - 11.3), M["Gold"], 0.05)
                box((19, 0.5, 0.6), (x, 35.8, z + 11.3), M["Gold"], 0.05)
        for x in (-11.7, 11.7, -35, 35):
            box((1.6, 1.4, 80), (x, 35.3, 0), M["Beam"], 0.15)
        for z in (-26.7, 0, 26.7):
            lamp_billiard(z, M["Shade"], M["Gold"], M["Glow"], "dome")
    def hero():  # knight armour statue on plinth
        M = mats(Stone=(220, 215, 205), Metal=(190, 195, 210), Accent=(220, 40, 60), Gold=(240, 190, 70), Dark=(60, 60, 70))
        box((3.4, 1.6, 3.4), (0, 0.8, 0), M["Stone"], 0.15)
        for s in (-1, 1):
            cyl(0.9, 3.4, (0, 3.3, s * 0.55), M["Metal"], verts=10)
        sphere(3.0, (0, 6.3, 0), M["Metal"], 14, 9, (0.8, 1.1, 1))
        box((0.3, 2.2, 2.2), (1.05, 6.3, 0), M["Accent"], 0.1)
        for s in (-1, 1):
            sphere(1.4, (0, 7.4, s * 1.4), M["Metal"], 10, 6)
            cyl(0.8, 2.8, (0.2, 5.8, s * 1.6), M["Metal"], verts=8)
        sphere(1.6, (0, 8.8, 0), M["Metal"], 12, 8)
        box((0.2, 0.25, 1.0), (0.82, 8.9, 0), M["Dark"], 0)
        cyl(0.4, 1.4, (0, 10.0, 0), M["Accent"], d2=0.1, verts=6)
        cyl(0.25, 7, (0.9, 6.5, -2.2), M["Gold"], verts=6)
        box((0.15, 2, 0.8), (0.9, 9.7, -2.2), M["Metal"], 0.02)
    def mid():  # banner on stand
        M = mats(Pole=(240, 190, 70), Banner=(70, 60, 180), Accent=(220, 40, 60), Base=(80, 50, 35))
        cyl(1.8, 0.4, (0, 0.2, 0), M["Base"], verts=10)
        cyl(0.25, 7, (0, 3.7, 0), M["Pole"], verts=8)
        sphere(0.6, (0, 7.4, 0), M["Pole"], 8, 5)
        cyl(0.15, 3, (0, 6.6, 0), M["Pole"], axis="Z", verts=6)
        box((0.15, 4, 2.8), (0.1, 4.6, 0), M["Banner"], 0.02)
        box((0.18, 1.2, 1.2), (0.12, 5.2, 0), M["Accent"], 0.02)
        for s in (-1, 1):
            o = box((0.15, 1.2, 1.0), (0.1, 2.3, s * 0.7), M["Banner"], 0); rot(o, rx=s * 30)
    def rail():  # crown on cushion
        M = mats(Cushion=(220, 40, 60), Gold=(240, 190, 70), Gem=(90, 200, 255), Tassel=(240, 190, 70))
        box((1.4, 0.5, 1.4), (0, 0.25, 0), M["Cushion"], 0.2)
        lathe([(0.5, 0.5), (0.55, 0.95), (0, 0.95)], (0, 0, 0), M["Gold"], 12)
        for k in range(5):
            a = k * 2 * math.pi / 5
            cyl(0.22, 0.5, (math.cos(a) * 0.5, 1.15, math.sin(a) * 0.5), M["Gold"], d2=0.02, verts=4)
            sphere(0.15, (math.cos(a) * 0.55, 0.75, math.sin(a) * 0.55), M["Gem"], 5, 3)
    def hang():  # crystal chandelier
        M = mats(Gold=(240, 190, 70), Crystal=(230, 240, 255), Glow=(255, 240, 200))
        cyl(0.12, 4, (0, -2, 0), M["Gold"], verts=6, bevel=0)
        torus(4.4, 0.25, (0, -5.4, 0), M["Gold"])
        torus(2.6, 0.2, (0, -4.6, 0), M["Gold"])
        for k in range(10):
            a = k * math.pi / 5
            cyl(0.3, 0.6, (math.cos(a) * 2.2, -5.0, math.sin(a) * 2.2), M["Glow"], verts=6)
            cyl(0.5, 1.2, (math.cos(a) * 2.2, -6.0, math.sin(a) * 2.2), M["Crystal"], d2=0.05, verts=5)
        cyl(1.0, 2.2, (0, -6.4, 0), M["Crystal"], d2=0.05, verts=8)
    return dict(Wall=wall, Backdrop=backdrop, Ceiling=ceiling, Hero=hero, Mid=mid, Rail=rail, Hang=hang)


# =====================================================================================================  HARBOUR
def harbour():
    def wall():
        M = mats(Brick=(160, 80, 60), Trim=(235, 225, 205), Accent=(40, 90, 150), Wood=(110, 75, 45), Brass=(220, 170, 80), Rope=(200, 170, 120), Glass=(160, 210, 235))
        box((1.2, 14, 80), (-0.6, 29, 0), M["Brick"], 0)
        for r in range(12):  # brick courses
            for k in range(27):
                z = -40 + k * 3 + (1.5 if r % 2 else 0)
                if z < 40:
                    box((0.25, 0.9, 2.8), (0.1, 22.6 + r * 1.1, z + 1.4), M["Brick"], 0)
        box((0.7, 0.8, 80.2), (0.2, 22.6, 0), M["Trim"], 0.15)
        box((1.8, 1.2, 80.2), (0.3, 35.5, 0), M["Trim"], 0.2)
        for z in (-26.7, 26.7):  # portholes
            cyl(5, 0.3, (0.3, 29, z), M["Glass"], axis="X", verts=24)
            torus(5.4, 0.6, (0.5, 29, z), M["Brass"], "X")
        cyl(7, 0.3, (0.6, 29, 0), M["Wood"], axis="X", verts=24)  # ship wheel
        torus(7, 0.5, (0.9, 29, 0), M["Wood"], "X")
        for k in range(8):
            a = k * math.pi / 4
            o = box((0.4, 9, 0.4), (0.9, 29, 0), M["Wood"], 0.05); rot(o, rx=k * 22.5)
            sphere(0.6, (0.9, 29 + math.sin(a) * 4.5, math.cos(a) * 4.5), M["Wood"], 6, 4)
        cyl(1.4, 0.8, (1.0, 29, 0), M["Brass"], axis="X", verts=12)
        for k in range(20):  # rope trim
            sphere(0.6, (0.6, 34.5, -38 + k * 4), M["Rope"], 6, 4, (1, 1, 2.4))
    def backdrop():
        M = mats(Sky=(170, 210, 240), Sea=(50, 120, 170), House=(240, 230, 210), Roof=(200, 70, 50), Accent=(40, 90, 150), Light=(255, 255, 255), Stripe=(220, 50, 50), Sail=(250, 250, 245))
        box((0.4, 24, 80), (-0.2, 12, 0), M["Sky"], 0)
        box((2.6, 2, 80), (1.3, 1, 0), M["Sea"], 0.1)
        lathe([(2.2, 0), (1.8, 12), (2.0, 12.2), (0, 12.2)], (1.6, 0, -26), M["Light"], 12)  # lighthouse
        for y in (2, 6, 10):
            torus(4.0 - y * 0.03, 0.6, (1.6, y, -26), M["Stripe"])
        cyl(2.4, 2.4, (1.6, 13.4, -26), M["Accent"], verts=10)
        cyl(3, 1.4, (1.6, 15.2, -26), M["Roof"], d2=0.2, verts=10)
        for k in range(7):  # harbour houses
            z = -14 + k * 4.6
            h = 4 + (k * 3 % 4)
            box((1.6, h, 4), (0.8, 2 + h / 2, z), [M["House"], M["Accent"], M["Roof"]][k % 3] if k % 3 != 2 else M["House"], 0.08)
            o = box((1.8, 0.4, 2.6), (0.9, 2 + h + 0.6, z - 0.9), M["Roof"], 0.03); rot(o, rx=-35)
            o = box((1.8, 0.4, 2.6), (0.9, 2 + h + 0.6, z + 0.9), M["Roof"], 0.03); rot(o, rx=35)
        for k, z in enumerate((-36, -6, 18)):  # sailing boats
            box((1.2, 0.8, 4), (2.2, 2.4, z), M["Roof"], 0.3)
            cyl(0.15, 5, (2.2, 5, z), M["House"], verts=4, bevel=0)
            o = box((0.1, 4, 2.4), (2.2, 5.4, z + 1.2), M["Sail"], 0)
    def ceiling():
        M = mats(Ceil=(220, 205, 175), Beam=(100, 65, 40), Shade=(40, 90, 150), Brass=(220, 170, 80), Glow=(255, 230, 170), Net=(200, 170, 120))
        ceiling_base(M, "Ceil", "Beam", "Shade", "Brass", "Glow", "lantern")
        for x in (-23.3, 23.3):  # fishing nets
            for k in range(8):
                cyl(0.12, 20, (x - 9 + k * 2.6, 35.2, 0), M["Net"], axis="Z", verts=4, bevel=0)
                cyl(0.12, 18, (x, 35.2, -9 + k * 2.6), M["Net"], axis="X", verts=4, bevel=0)
    def hero():  # mini lighthouse
        M = mats(Light=(250, 250, 250), Stripe=(220, 50, 50), Glass=(255, 240, 160), Roof=(40, 60, 90), Rock=(120, 115, 110))
        bumpy(sphere(7, (0, 0, 0), M["Rock"], 12, 6, (1, 0.35, 1)), 0.25, 3)
        lathe([(1.8, 0.8), (1.3, 9), (1.5, 9.2), (0, 9.2)], (0, 0, 0), M["Light"], 14)
        for y in (2.5, 5.5):
            lathe([(1.75 - y * 0.06, y), (1.65 - y * 0.06, y + 1.4), (0, y + 1.4)], (0, 0, 0), M["Stripe"], 14)
        cyl(1.8, 1.6, (0, 10, 0), M["Glass"], verts=10)
        cyl(2.6, 1.4, (0, 11.5, 0), M["Roof"], d2=0.2, verts=10)
        torus(3.4, 0.15, (0, 9.4, 0), M["Roof"])
    def mid():  # barrels with rope
        M = mats(Wood=(140, 90, 50), Metal=(70, 70, 80), Rope=(200, 170, 120), Accent=(40, 90, 150))
        for k, (x, z, y) in enumerate(((0, -0.8, 0), (0, 0.9, 0), (0, 0, 2.2))):
            lathe([(0.8, y), (0.95, y + 1.1), (0.8, y + 2.2), (0, y + 2.2)], (x, 0, z), M["Wood"], 14)
            for yy in (0.3, 1.9):
                torus(1.75, 0.1, (x, y + yy, z), M["Metal"])
        torus(1.6, 0.35, (1.4, 0.2, 1.5), M["Rope"])
        torus(1.1, 0.35, (1.4, 0.55, 1.5), M["Rope"])
    def rail():  # ship in a bottle
        M = mats(Glass=(200, 235, 220), Wood=(110, 70, 40), Sail=(250, 250, 245), Cork=(180, 140, 90))
        o = cyl(0.9, 2.0, (0, 0.5, 0), M["Glass"], axis="Z", verts=12)
        cyl(0.4, 0.6, (0, 0.5, 1.3), M["Glass"], axis="Z", verts=10)
        cyl(0.35, 0.3, (0, 0.5, 1.7), M["Cork"], axis="Z", verts=8)
        box((0.4, 0.25, 1.1), (0, 0.25, 0), M["Wood"], 0.05)
        box((0.05, 0.5, 0.5), (0, 0.65, 0), M["Sail"], 0)
    def hang():  # ship lantern
        M = mats(Chain=(70, 70, 80), Brass=(220, 170, 80), Glass=(255, 230, 160))
        cyl(0.08, 5, (0, -2.5, 0), M["Chain"], verts=4, bevel=0)
        torus(0.6, 0.1, (0, -5.1, 0), M["Brass"], "X")
        cyl(1.6, 0.6, (0, -5.6, 0), M["Brass"], d2=0.6, verts=10)
        cyl(1.3, 1.8, (0, -6.9, 0), M["Glass"], verts=10)
        for k in range(4):
            box((0.12, 1.8, 0.12), (math.cos(k * 1.57) * 0.7, -6.9, math.sin(k * 1.57) * 0.7), M["Brass"], 0)
        cyl(1.6, 0.4, (0, -8.0, 0), M["Brass"], verts=10)
    return dict(Wall=wall, Backdrop=backdrop, Ceiling=ceiling, Hero=hero, Mid=mid, Rail=rail, Hang=hang)


# =====================================================================================================  CLUB (default)
def club():
    def wall():
        M = mats(Wall=(40, 80, 60), Wood=(100, 55, 30), Trim=(220, 180, 100), Accent=(170, 40, 50), Cue=(230, 200, 150), Brass=(226, 178, 84), Felt=(30, 120, 70))
        band(M, "Wall", "Trim", "Accent")
        for z in (-40, -20, 0, 20, 40):
            box((0.5, 13, 1.2), (0.25, 29, z), M["Wood"], 0.08)
        for z in (-26.7, 26.7):  # cue racks
            box((0.6, 7, 6), (0.3, 28.5, z), M["Wood"], 0.15)
            for k in range(6):
                cyl(0.25, 6.4, (0.75, 28.3, z - 2.5 + k), M["Cue"], d2=0.15, verts=6)
                cyl(0.28, 1.6, (0.75, 25.9, z - 2.5 + k), M["Accent"] if k % 2 else M["Wood"], verts=6)
            box((0.8, 0.5, 6.4), (0.4, 25, z), M["Brass"], 0.08)
        box((0.4, 7, 9), (0.2, 28.5, 0), M["Trim"], 0.2)  # scoreboard
        box((0.45, 6, 8), (0.3, 28.5, 0), M["Felt"], 0)
        for r in range(2):
            cyl(0.1, 7, (0.6, 27.5 + r * 2, 0), M["Brass"], axis="Z", verts=4, bevel=0)
            for k in range(8):
                sphere(0.5, (0.65, 27.5 + r * 2, -3.2 + k * 0.9), M["Cue"] if k % 3 else M["Accent"], 6, 4)
    def backdrop():
        M = mats(Sky=(30, 30, 60), City=(50, 50, 80), CityFar=(70, 70, 110), Window=(255, 220, 130), Neon=(255, 70, 120), Accent=(170, 40, 50), Moon=(250, 245, 220))
        box((0.4, 24, 80), (-0.2, 12, 0), M["Sky"], 0)
        sphere(4, (0.3, 19, 24), M["Moon"], 12, 8, (0.2, 1, 1))
        for k in range(16):
            z, h = -38 + k * 5, 6 + (k * 11 % 12)
            box((1.0 + (k % 2), h, 4.4), (0.5, h / 2, z), M["CityFar"] if k % 2 else M["City"], 0.05)
            for j in range(int(h // 1.6)):
                if (j + k) % 3:
                    box((0.2, 0.6, 0.7), (1.05 + (k % 2), 1 + j * 1.6, z - 1 + (j % 2) * 1.6), M["Window"], 0)
        box((0.3, 1.2, 8), (2.0, 3, -6), M["Neon"], 0.2)
    def ceiling():
        M = mats(Ceil=(60, 40, 30), Beam=(100, 55, 30), Shade=(30, 120, 70), Brass=(226, 178, 84), Glow=(255, 236, 180), Coffer=(80, 50, 35))
        ceiling_base(M, "Ceil", "Beam", "Shade", "Brass", "Glow", "cone", coffer="Coffer")
    def hero():  # jukebox
        M = mats(Body=(110, 55, 30), Accent=(170, 40, 50), Glow=(255, 200, 120), Chrome=(220, 225, 235), Glass=(160, 200, 230), Neon=(255, 70, 120))
        box((3.2, 5, 2.2), (0, 2.5, 0), M["Body"], 0.2)
        cyl(3.2, 2.2, (0, 5, 0), M["Body"], axis="Z", verts=20)
        cyl(2.6, 0.3, (0, 5.2, 1.1), M["Glass"], axis="Z", verts=18)
        for x in (-1.2, 1.2):
            box((0.35, 5.6, 0.3), (x, 3.2, 1.15), M["Neon"], 0.05)
        box((2.2, 1.6, 0.2), (0, 2.6, 1.15), M["Chrome"], 0.05)
        for k in range(5):
            box((0.25, 1.2, 0.25), (-0.8 + k * 0.4, 2.6, 1.3), M["Glow"], 0)
        box((2.8, 0.6, 0.3), (0, 0.8, 1.15), M["Accent"], 0.05)
    def mid():  # bar table with stools
        M = mats(Wood=(100, 55, 30), Chrome=(220, 225, 235), Seat=(170, 40, 50), Top=(60, 35, 20))
        cyl(2.4, 0.3, (0, 3.6, 0), M["Top"], verts=16)
        cyl(0.3, 3.4, (0, 1.8, 0), M["Chrome"], verts=8)
        cyl(1.6, 0.2, (0, 0.1, 0), M["Chrome"], verts=12)
        for s in (-1, 1):
            cyl(0.2, 2.4, (s * 1.8, 1.2, 0), M["Chrome"], verts=6)
            cyl(1.2, 0.4, (s * 1.8, 2.5, 0), M["Seat"], verts=12)
            torus(1.0, 0.08, (s * 1.8, 0.8, 0), M["Chrome"])
    def rail():  # chalk cube + ball rack
        M = mats(Chalk=(70, 140, 230), Wood=(100, 55, 30), Ball=(240, 200, 60), Ball2=(200, 40, 50))
        box((0.5, 0.5, 0.5), (0.3, 0.25, -0.4), M["Chalk"], 0.05)
        for k, (x, z) in enumerate(((0, 0.3), (-0.45, 0.55), (-0.45, 0.05))):
            sphere(0.5, (x - 0.1, 0.25, z), [M["Ball"], M["Ball2"]][k % 2], 10, 6)
        o = box((0.12, 0.12, 1.4), (-0.3, 0.06, 0.3), M["Wood"], 0)
    def hang():  # green glass lamp
        M = mats(Chain=(200, 160, 80), Glass=(30, 120, 70), Glow=(255, 236, 180))
        cyl(0.08, 5, (0, -2.5, 0), M["Chain"], verts=4, bevel=0)
        lathe([(0.3, -5.0), (1.6, -6.0), (1.8, -6.4), (0, -6.2)], (0, 0, 0), M["Glass"], 16)
        sphere(0.8, (0, -6.3, 0), M["Glow"], 8, 5)
    return dict(Wall=wall, Backdrop=backdrop, Ceiling=ceiling, Hero=hero, Mid=mid, Rail=rail, Hang=hang)


# =====================================================================================================  NEW YEAR
def newyear():
    def wall():
        M = mats(Wall=(150, 30, 45), Trim=(250, 245, 235), Accent=(255, 200, 70), Pine=(30, 110, 60), Berry=(220, 30, 40), Bulb=(255, 230, 120), Ribbon=(220, 30, 40))
        band(M, "Wall", "Trim", "Accent")
        for z in (-26.7, 0, 26.7):  # wreaths
            for k in range(16):
                a = k * math.pi / 8
                leafball(1.6, (0.6, 29 + math.sin(a) * 2.8, z + math.cos(a) * 2.8), M["Pine"], k)
            for k in range(6):
                a = k * math.pi / 3 + 0.3
                sphere(0.5, (1.3, 29 + math.sin(a) * 2.8, z + math.cos(a) * 2.8), M["Berry"], 6, 4)
            box((0.5, 1.2, 1.6), (1.3, 26.2, z), M["Ribbon"], 0.2)
        for k in range(40):  # garland with bulbs
            z = -39 + k * 2
            y = 33 - abs(math.sin(k * math.pi / 5)) * 2.2
            leafball(1.1, (0.6, y, z), M["Pine"], k)
            if k % 2:
                sphere(0.45, (1.1, y - 0.5, z), [M["Bulb"], M["Berry"], M["Accent"]][k % 3], 6, 4)
    def backdrop():
        M = mats(Sky=(30, 40, 90), Snow=(245, 250, 255), Pine=(30, 100, 60), House=(160, 80, 50), Roof=(245, 250, 255), Window=(255, 210, 120), Star=(255, 240, 160), Accent=(220, 30, 40))
        box((0.4, 24, 80), (-0.2, 12, 0), M["Sky"], 0)
        for k in range(40):
            sphere(0.25 + R.random() * 0.2, (0.1, R.uniform(10, 23.5), R.uniform(-39, 39)), M["Star"], 4, 3)
        for k in range(5):
            sphere(26, (0.3, -2, -36 + k * 18), M["Snow"], 14, 6, (0.06, 0.4, 1))
        for k in range(6):  # snowy village
            z = -32 + k * 12
            box((1.8, 3.6, 5), (1.0, 3.6, z), M["House"], 0.1)
            for s in (-1, 1):
                o = box((2.2, 0.5, 3.4), (1.0, 6.2, z + s * 1.2), M["Roof"], 0.2); rot(o, rx=s * 40)
            for d in (-1.2, 1.2):
                box((0.2, 1.0, 1.0), (1.95, 3.8, z + d), M["Window"], 0)
            cyl(0.6, 1.6, (1.0, 7.6, z + 1.5), M["House"], verts=6)
        for k in range(8):  # firs with lights
            z = -38 + k * 11
            for j in range(3):
                cyl(3.6 - j * 1.0, 2.4, (2.0, 1.6 + j * 1.6, z), M["Pine"], d2=0.4, verts=8)
                cyl(3.2 - j * 1.0, 0.4, (2.0, 0.8 + j * 1.6, z), M["Snow"], verts=8)
            sphere(0.6, (2.0, 6.2, z), M["Star"], 6, 4)
            for j in range(4):
                sphere(0.3, (2.9, 2 + j * 1.1, z + (j - 1.5) * 0.5), [M["Accent"], M["Window"]][j % 2], 5, 3)
    def ceiling():
        M = mats(Ceil=(250, 245, 235), Beam=(150, 30, 45), Shade=(30, 110, 60), Gold=(255, 200, 70), Glow=(255, 236, 180), Pine=(30, 110, 60), Bulb=(255, 230, 120), Accent=(220, 30, 40))
        ceiling_base(M, "Ceil", "Beam", "Shade", "Gold", "Glow", "cone")
        for x in (-11.7, 11.7):  # garlands along the beams
            for k in range(26):
                leafball(1.3, (x, 34.3, -39 + k * 3.1), M["Pine"], k)
                if k % 2:
                    sphere(0.5, (x + 0.7, 33.7, -39 + k * 3.1), [M["Bulb"], M["Accent"], M["Gold"]][k % 3], 6, 4)
    def hero():  # sleigh full of gifts
        M = mats(Sleigh=(200, 30, 40), Gold=(255, 200, 70), Gift1=(60, 140, 230), Gift2=(80, 180, 90), Ribbon=(255, 240, 200), Runner=(220, 225, 235))
        for s in (-1, 1):  # runners
            box((0.3, 0.3, 7), (s * 1.6, 0.3, 0), M["Runner"], 0.08)
            o = torus(2.0, 0.3, (s * 1.6, 1.0, 3.5), M["Runner"], "X")
            for z in (-2, 1.5):
                box((0.25, 1.2, 0.25), (s * 1.6, 1.0, z), M["Runner"], 0)
        box((3.6, 2.2, 5.4), (0, 2.6, -0.4), M["Sleigh"], 0.4)
        box((3.6, 3.4, 1.2), (0, 3.8, -2.8), M["Sleigh"], 0.4)
        o = torus(3.4, 0.4, (0, 3.4, 2.4), M["Sleigh"], "X")
        box((3.8, 0.3, 5.6), (0, 3.8, -0.4), M["Gold"], 0.1)
        for k, (x, y, z, s, m) in enumerate(((-0.6, 4.6, -0.8, 1.6, "Gift1"), (0.8, 4.4, 0.6, 1.2, "Gift2"), (0, 5.8, -0.2, 1.1, "Gold"), (0.6, 4.4, -1.8, 1.0, "Gift2"))):
            box((s, s, s), (x, y, z), M[m], 0.06)
            box((s + 0.05, s + 0.05, 0.25), (x, y, z), M["Ribbon"], 0)
            box((0.25, s + 0.05, s + 0.05), (x, y, z), M["Ribbon"], 0)
    def mid():  # stack of gifts
        M = mats(Gift1=(220, 30, 40), Gift2=(60, 140, 230), Gift3=(255, 200, 70), Ribbon=(255, 250, 240), Accent=(80, 180, 90))
        for k, (x, y, z, s, m) in enumerate(((0, 1, 0, 2, "Gift1"), (1.6, 0.7, 0.8, 1.4, "Gift2"), (0.2, 2.7, 0.1, 1.4, "Gift3"), (-1.2, 0.6, 1.2, 1.2, "Accent"), (0.2, 3.95, 0.1, 1.1, "Gift2"))):
            box((s, s, s), (x, y, z), M[m], 0.06)
            box((s + 0.05, s + 0.05, 0.25), (x, y, z), M["Ribbon"], 0)
            box((0.25, s + 0.05, s + 0.05), (x, y, z), M["Ribbon"], 0)
            torus(0.6, 0.15, (x, y + s / 2 + 0.2, z), M["Ribbon"], "X")
    def rail():  # ornament bauble pair
        M = mats(B1=(220, 30, 40), B2=(255, 200, 70), Cap=(220, 225, 235), Pine=(30, 110, 60))
        leafball(1.0, (0, 0.3, 0), M["Pine"], 2)
        for k, (x, z, m) in enumerate(((0.3, 0.3, "B1"), (-0.35, -0.2, "B2"))):
            sphere(0.9, (x, 0.75, z), M[m], 12, 8)
            cyl(0.3, 0.25, (x, 1.25, z), M["Cap"], verts=8)
    def hang():  # star ornament with bells
        M = mats(String=(255, 240, 200), Gold=(255, 200, 70), Bell=(220, 30, 40), Glow=(255, 240, 160))
        cyl(0.06, 4, (0, -2, 0), M["String"], verts=4, bevel=0)
        for k in range(5):
            a = k * 2 * math.pi / 5
            o = cyl(1.0, 1.8, (0, -5.6 + math.cos(a) * 0.9, math.sin(a) * 0.9), M["Gold"], axis="X", d2=0.05, verts=4)
            spin(o, (math.pi / 2 - a, math.pi / 2, 0))
        sphere(1.0, (0, -5.6, 0), M["Glow"], 8, 6)
        for s in (-1, 1):
            cyl(0.04, 1.6, (0, -7.2, s * 0.6), M["String"], verts=4, bevel=0)
            lathe([(0, -8.2), (0.2, -8.3), (0.6, -9.0), (0.7, -9.2), (0, -9.2)], (0, 0, s * 0.6), M["Bell"], 10)
    return dict(Wall=wall, Backdrop=backdrop, Ceiling=ceiling, Hero=hero, Mid=mid, Rail=rail, Hang=hang)


THEMES = dict(Orchard=orchard, Candy=candy, Reef=reef, Desert=desert, Ice=ice, Fire=fire, Zen=zen, Space=space, Clock=clock,
              Garden=garden, Pixel=pixel, Sky=sky, Royal=royal, Harbour=harbour, Club=club, NewYear=newyear)


def kit(only=None):
    out = []
    for t, fn in THEMES.items():
        if only and t not in only:
            continue
        for part, build in fn().items():
            out.append((part + t, build))
    return out
