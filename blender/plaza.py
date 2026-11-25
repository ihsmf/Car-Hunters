"""CUE HUNTERS plaza (player bases) decor: cue shop booth, gym corner, club sign, bay number plaques.
Built through build_models.py ("plaza" set). Front of every model = +X (Roblox), origin on the floor / wall plane."""
import math, os
import bpy
from build_models import box, cyl, sphere, torus, lathe
import themes
from themes import mats, rot

FONT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fonts", "LuckiestGuy.ttf")


def text3d(s, c, size, m, depth=0.25, bevel=0.06, facing="X"):
    """Extruded 3D lettering; reads from the +X side (facing X) or from +Z (facing Z)."""
    bpy.ops.object.text_add()
    t = bpy.context.object
    t.data.body = s
    t.data.font = bpy.data.fonts.load(FONT, check_existing=True)
    t.data.size, t.data.extrude, t.data.bevel_depth, t.data.bevel_resolution = size, depth, bevel, 1
    t.data.resolution_u = 3
    t.data.align_x, t.data.align_y = "CENTER", "CENTER"
    t.data.materials.append(m)
    # Blender text lies in XY facing +Z; stand it up facing Roblox +X (Blender +X) or Roblox +Z (Blender -Y)
    t.rotation_euler = (math.pi / 2, 0, math.pi / 2) if facing == "X" else (math.pi / 2, 0, math.pi)
    t.location = (c[0], -c[2], c[1])
    return t


def cue_shop():
    M = mats(Wood=(120, 70, 35), WoodDark=(75, 40, 20), Felt=(30, 150, 80), Glass=(190, 230, 245), Gold=(255, 200, 70),
             Red=(220, 40, 55), White=(250, 248, 240), Accent=(30, 30, 40), Bulb=(255, 230, 140))
    # counter with a glass display case full of balls
    box((3.2, 3.4, 11), (1.6, 1.7, 0), M["Wood"], 0.15)
    box((3.4, 0.35, 11.3), (1.6, 3.55, 0), M["WoodDark"], 0.1)
    for z in (-5, 0, 5):
        box((0.2, 2.6, 0.3), (3.25, 1.7, z), M["Gold"], 0.03)
    box((3.0, 0.3, 10.8), (1.6, 3.85, 0), M["Felt"], 0.05)  # felt tray on the counter, balls on display
    for z in (-5.3, 5.3):
        box((3.0, 0.5, 0.25), (1.6, 3.95, z), M["Gold"], 0.04)
    cols = [(255, 210, 40), (40, 90, 230), (235, 50, 50), (140, 50, 200), (255, 130, 20), (30, 160, 70), (140, 30, 40), (20, 20, 24)]
    for k in range(16):
        sphere(0.9, (1.0 + (k % 2) * 1.1, 4.45, -4.6 + (k // 2) * 1.3), mats(**{f"B{k}": cols[k % 8]})[f"B{k}"], 16, 10)
    # back wall with a rack of tier-coloured cues
    box((0.6, 9, 12), (-3.5, 4.5, 0), M["WoodDark"], 0.15)
    box((0.3, 7, 10.8), (-3.1, 4.6, 0), M["Felt"], 0.05)
    tiers = [(200, 160, 110), (90, 200, 120), (80, 160, 255), (180, 100, 255), (255, 170, 40), (255, 80, 80), (255, 230, 90), (120, 255, 240), (255, 120, 220)]
    for k, c in enumerate(tiers):
        z = -4.6 + k * 1.15
        m = mats(**{f"T{k}": c})[f"T{k}"]
        cyl(0.22, 6.2, (-2.75, 4.7, z), M["White"], d2=0.12, verts=10)
        cyl(0.28, 2.2, (-2.75, 2.6, z), m, d2=0.24, verts=10)
        cyl(0.13, 0.25, (-2.75, 7.85, z), m, verts=8)
    box((0.5, 0.4, 11), (-2.8, 1.3, 0), M["Gold"], 0.05)
    # posts + striped awning + string lights
    for z in (-5.8, 5.8):
        cyl(0.5, 10, (2.8, 5, z), M["WoodDark"], verts=12)
        cyl(0.9, 0.5, (2.8, 10.1, z), M["Gold"], verts=12)
    for k in range(10):
        o = box((5.0, 0.25, 1.25), (0.5, 9.4, -5.65 + k * 1.25), M["Red"] if k % 2 else M["White"], 0.05)
        rot(o, rz=-14)
    for k in range(10):
        sphere(0.36, (3.3, 8.3 - 0.4 * math.sin(k / 9 * math.pi), -5.4 + k * 1.2), M["Bulb"], 8, 6)
    # sign: backplate, 3D "CUE SHOP", a giant cue over an 8-ball
    box((0.6, 3.2, 12.5), (-1.2, 12.3, 0), M["Accent"], 0.4)
    box((0.7, 2.6, 11.9), (-1.1, 12.3, 0), M["Red"], 0.35)
    text3d("CUE SHOP", (-0.65, 12.3, 0), 2.3, M["Gold"], 0.35, 0.08)
    sphere(2.6, (-1.0, 15.5, 0), M["Accent"], 24, 16)
    cyl(1.3, 0.3, (0.25, 15.5, 0), M["White"], axis="X", verts=20)
    text3d("8", (0.45, 15.5, 0), 1.2, M["Accent"], 0.12, 0.02)
    o = cyl(0.35, 13, (-0.3, 15.5, 0), M["Wood"], d2=0.2, verts=12)
    rot(o, rx=70)


def gym_corner():
    M = mats(Mat=(60, 60, 75), Metal=(200, 205, 215), Dark=(40, 40, 50), Plate=(255, 140, 40), Pad=(220, 50, 60), Kettle=(50, 50, 60), Gold=(255, 200, 70), Accent=(80, 180, 255))
    box((9, 0.2, 10), (0, 0.1, 0), M["Mat"], 0.1)
    # dumbbell rack
    for z in (-3.5, 3.5):
        o = box((0.4, 3.8, 0.4), (-3.2, 1.9, z), M["Dark"], 0.05)
    for y in (1.6, 3.2):
        o = box((1.6, 0.25, 7.4), (-3.0, y, 0), M["Metal"], 0.03)
        rot(o, rz=-12)
        for k in range(6):
            z = -3 + k * 1.2
            cyl(0.12, 1.0, (-2.9, y + 0.35, z), M["Metal"], axis="X", verts=8)
            for s in (-1, 1):
                cyl(0.55 + 0.05 * k, 0.25, (-2.9 + s * 0.45, y + 0.35, z), M["Plate"] if k % 2 else M["Dark"], axis="X", verts=16)
    # bench press
    box((1.4, 0.4, 4.5), (1.2, 1.6, 0), M["Pad"], 0.2)
    for z in (-1.8, 1.8):
        box((0.3, 1.4, 0.3), (1.2, 0.7, z), M["Dark"], 0.03)
    for z in (-2.6, 2.6):
        box((0.3, 3.4, 0.3), (1.2, 1.7, z), M["Dark"], 0.03)
    cyl(0.14, 7, (1.2, 3.3, 0), M["Metal"], axis="Z", verts=8)
    for z in (-3.0, 3.0):
        cyl(2.0, 0.35, (1.2, 3.3, z), M["Plate"], axis="Z", verts=24)
    # kettlebells
    for k, (x, z) in enumerate(((3.2, -3.5), (3.6, -2.3), (3.3, 3.4))):
        sphere(1.0 - k * 0.12, (x, 0.65, z), M["Kettle"], 16, 10)
        torus(0.7, 0.12, (x, 1.25, z), M["Kettle"], "X")
    # sign
    for z in (-3.0, 3.0):
        cyl(0.3, 7, (-4.2, 3.5, z), M["Dark"], verts=10)
    box((0.5, 2.4, 7.2), (-4.0, 7.6, 0), M["Accent"], 0.3)
    text3d("GYM", (-3.65, 7.6, 0), 2.0, M["Gold"], 0.3, 0.07)


def club_sign():
    """Main plaza sign on the back wall: faces +X (placed rotated to face the plaza)."""
    M = mats(Plate=(20, 90, 60), Rim=(255, 200, 70), Gold=(255, 205, 80), Accent=(30, 30, 40), White=(250, 248, 240), Glow=(255, 240, 180))
    box((0.5, 4.6, 26), (0.0, 0, 0), M["Rim"], 0.5)
    box((0.6, 4.0, 25.4), (0.1, 0, 0), M["Plate"], 0.45)
    text3d("CUE HUNTERS", (0.5, 0.05, 0.9), 3.0, M["Gold"], 0.45, 0.1)
    sphere(3.4, (0.6, 0, -11.4), M["Accent"], 24, 16)
    cyl(1.7, 0.3, (2.25, 0, -11.4), M["White"], axis="X", verts=20)
    text3d("8", (2.45, 0, -11.4), 1.5, M["Accent"], 0.12, 0.02)
    for z in range(-12, 13, 2):
        sphere(0.35, (0.5, 2.55, z), M["Glow"], 8, 6)
        sphere(0.35, (0.5, -2.55, z), M["Glow"], 8, 6)


def bay_number(n):
    def build():
        M = mats(Plate=(20, 110, 70), Rim=(255, 200, 70), Gold=(255, 210, 90))
        cyl(2.6, 0.35, (0.15, 0, 0), M["Rim"], axis="X", verts=32)
        cyl(2.2, 0.4, (0.25, 0, 0), M["Plate"], axis="X", verts=32)
        text3d(str(n), (0.5, -0.05, 0), 1.9, M["Gold"], 0.25, 0.05)
    return build


def gem_stud():
    M = mats(Gold=(255, 200, 70), Gem=(60, 220, 140))
    cyl(1.0, 0.25, (0.1, 0, 0), M["Gold"], axis="X", verts=16)
    o = sphere(0.7, (0.35, 0, 0), M["Gem"], 8, 4)
    o.scale = (0.6, 1, 1)


def kit():
    return [("PlazaCueShop", cue_shop), ("PlazaGym", gym_corner), ("PlazaClubSign", club_sign), ("PlazaGem", gem_stud)] + \
           [(f"PlazaBay{n}", bay_number(n)) for n in range(1, 5)]
