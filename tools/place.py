"""Генерирует готовый плейс BilliardHunters.rbxlx: карта целиком лежит в Workspace
(видна в Studio без запуска), скрипты из src/ вставляются в нужные сервисы.
  python3 tools/place.py            -> BilliardHunters.rbxlx + tools/scene.json (для превью)
"""
import json, math, os, re, random
import numpy as np
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
cfg = open(os.path.join(ROOT, "src/shared/Config.luau"), encoding="utf-8").read()
RAR = [(n, (int(r), int(g), int(b))) for n, r, g, b in re.findall(r'\{ "([^"]+)", rgb\((\d+), (\d+), (\d+)\), "', cfg)]
TL, TW, TSZ, LANES = (float(v) for v in re.search(r"Length = (\d+), Width = (\d+), StartZ = (\d+), Lanes = (\d+)", cfg).groups())
SLOTS = int(re.search(r"C.MaxEquipped = (\d+)", cfg).group(1))
N = len(RAR)
ZL = TL / N
END = TSZ + TL

# ---------- CFrame ----------
def cf(x=0, y=0, z=0):
    m = np.eye(4); m[:3, 3] = (x, y, z); return m
def rx(a): c, s = math.cos(a), math.sin(a); m = np.eye(4); m[1:3, 1:3] = [[c, -s], [s, c]]; return m
def ry(a): c, s = math.cos(a), math.sin(a); m = np.eye(4); m[0, 0], m[0, 2], m[2, 0], m[2, 2] = c, s, -s, c; return m
def rz(a): c, s = math.cos(a), math.sin(a); m = np.eye(4); m[:2, :2] = [[c, -s], [s, c]]; return m
def ang(a=0, b=0, c=0): return rx(a) @ ry(b) @ rz(c)
def look(pos, at):
    f = np.array(at, float) - pos; f /= np.linalg.norm(f)
    r = np.cross(f, [0, 1, 0]); r /= np.linalg.norm(r); u = np.cross(r, f)
    m = np.eye(4); m[:3, 0], m[:3, 1], m[:3, 2], m[:3, 3] = r, u, -f, pos; return m

MAT = dict(Plastic=256, Smooth=272, Neon=288, Wood=512, Planks=528, Marble=784, Slate=800, Concrete=816, Brick=848,
           Pebble=864, Cobble=880, Rock=896, Sandstone=912, Metal=1088, Grass=1280, Sand=1296, Fabric=1312, Snow=1328,
           Ice=1536, Glass=1568, ForceField=1584)
SHAPE = dict(Ball=0, Block=1, Cyl=2)

class Inst:
    def __init__(s, cls, name, parent=None, **p):
        s.cls, s.name, s.p, s.kids = cls, name, p, []
        if parent is not None: parent.kids.append(s)

def part(parent, size, m, color, mat="Smooth", shape="Block", name="Part", cls="Part", **kw):
    return Inst(cls, name, parent, size=size, cf=m, color=color, mat=mat, shape=shape, **kw)
def ycyl(parent, d, h, m, color, mat="Smooth", **kw):  # цилиндр вдоль Y
    return part(parent, (h, d, d), m @ rz(math.pi / 2), color, mat, "Cyl", **kw)
def ball(parent, d, m, color, mat="Smooth", **kw):
    return part(parent, (d, d, d), m, color, mat, "Ball", **kw)
def light(p, color, rng, b=1.5): Inst("PointLight", "Light", p, Color=color, Range=rng, Brightness=b)
def label(p, face, text, color=(255, 255, 255), pps=40, name="Label"):
    g = Inst("SurfaceGui", name, p, Face=face, PixelsPerStud=pps)
    t = Inst("TextLabel", "Text", g, Text=text, TextColor3=color)
    Inst("UIStroke", "UIStroke", t)
    return t
def prompt(p, action, obj): Inst("ProximityPrompt", "Prompt", p, ActionText=action, ObjectText=obj)
FACE = dict(Right=0, Top=1, Back=2, Left=3, Bottom=4, Front=5)

WOOD, DARK, GOLD, WHITE = (115, 56, 20), (76, 36, 13), (255, 190, 50), (255, 255, 255)
BALLS = [(255, 220, 40), (40, 90, 255), (255, 50, 50), (140, 40, 200), (255, 130, 20), (30, 160, 60), (130, 30, 30)]
rnd = random.Random(7)

# ---------- Models. Visible part-built fallbacks; the client swaps them for the Blender
# meshes (src/shared/Meshes.luau) via a "Mesh" StringValue tag on a pivot part.
def tag_mesh(p, mesh, scale=None, vscale=None, **colors):
    Inst("StringValue", "Mesh", p, Value=mesh)
    if scale: Inst("NumberValue", "Scale", p, Value=scale)
    if vscale: Inst("Vector3Value", "Scale", p, Value=vscale)
    for k, c in colors.items(): Inst("Color3Value", k, p, Value=c)
    return p

def pivot(m, o, mesh, **kw):  # invisible model origin; whole model is replaced by the mesh
    return tag_mesh(part(m, (0.2, 0.2, 0.2), o, WHITE, Transparency=1, CanCollide=False, name="MeshPivot"), mesh, **kw)

def pool_table(par, o):
    m = Inst("Model", "PoolTable", par)
    pivot(m, o, "PoolTable")
    L, W = 16, 9
    part(m, (W + 1.8, 1.5, L + 1.8), o @ cf(0, 3.05, 0), WOOD, "Wood")
    part(m, (W, 0.3, L), o @ cf(0, 3.85, 0), (22, 150, 70), "Fabric")
    for s in (-1, 1):
        part(m, (1.1, 0.75, L + 2.2), o @ cf(s * (W / 2 + 0.55), 4.2, 0), DARK, "Wood")
        part(m, (W + 2.2, 0.75, 1.1), o @ cf(0, 4.2, s * (L / 2 + 0.55)), DARK, "Wood")
        for t in (-1, 1):
            leg = o @ cf(s * W / 2.4, 0, t * L / 2.4)
            ycyl(m, 0.9, 2.3, leg @ cf(0, 1.15, 0), DARK, "Wood")
            ycyl(m, 1.3, 0.35, leg @ cf(0, 0.18, 0), GOLD, "Metal")
        for t in (-1, 0, 1):
            pc = o @ cf(s * (W / 2 + 0.1), 0, t * (L / 2 + 0.1))
            ycyl(m, 1.25, 0.35, pc @ cf(0, 4.15, 0), (18, 14, 20))
    for i, c in enumerate(BALLS):
        ball(m, 0.8, o @ cf(-2 + (i % 4) * 1.3, 4.4, -3 + (i // 4) * 1.3), c, CanCollide=False)
    ball(m, 0.8, o @ cf(0, 4.4, 4.5), WHITE, CanCollide=False)

def table_lamp(par, o):
    lamp = part(par, (4, 0.6, 10), o @ cf(0, 11, 0), (20, 90, 40), name="Lamp")
    part(par, (3.4, 0.2, 9.4), o @ cf(0, 10.65, 0), (255, 245, 200), "Neon")
    for s in (-1, 1): part(par, (0.15, 4.4, 0.15), o @ cf(0, 13.4, s * 4), (40, 40, 40), "Metal")
    light(lamp, (255, 240, 200), 18, 2)

def cue(par, o, color, k=1):  # centred on o, along local Y, length 9.2 * k
    m = Inst("Model", "Cue", par)
    pivot(m, o, "Cue", scale=k if k != 1 else None, Shaft=color)
    ycyl(m, 0.45 * k, 4.4 * k, o @ cf(0, -2.4 * k, 0), (34, 20, 14), "Wood")
    ycyl(m, 0.5 * k, 1.2 * k, o @ cf(0, -3.5 * k, 0), (200, 30, 50), "Fabric")
    ycyl(m, 0.3 * k, 4.3 * k, o @ cf(0, 1.8 * k, 0), color, "Wood")
    ycyl(m, 0.23 * k, 0.3 * k, o @ cf(0, 4.1 * k, 0), (245, 245, 235))
    ycyl(m, 0.22 * k, 0.15 * k, o @ cf(0, 4.32 * k, 0), (40, 110, 240), "Fabric")

def mesh_ball(par, d, m, color, **kw):  # visible sphere fallback; swapped for the Blender ball mesh
    return tag_mesh(ball(par, d, m, color, **kw), "Ball", scale=d, Body=color)

def dumbbell(par, o):
    m = Inst("Model", "Dumbbell", par)
    pivot(m, o, "Dumbbell")
    x = o @ cf(0, 0.9, 0)
    part(m, (5.4, 0.45, 0.45), x, (215, 220, 232), "Metal", "Cyl")
    for s in (-1, 1):
        part(m, (0.5, 1.9, 1.9), x @ cf(s * 2, 0, 0), (240, 60, 70), shape="Cyl")
        part(m, (0.4, 1.45, 1.45), x @ cf(s * 1.6, 0, 0), (240, 60, 70), shape="Cyl")
        part(m, (0.3, 0.75, 0.75), x @ cf(s * 2.42, 0, 0), (215, 220, 232), "Metal", "Cyl")
    part(m, (6.4, 0.4, 2.6), o @ cf(0, -0.3, 0), (44, 44, 58))

def fence(par, o, color):
    m = Inst("Model", "Fence", par)
    pivot(m, o, "Fence", Cap=color)
    for i in range(5):
        x = -12 + i * 6
        part(m, (0.9, 4, 0.9), o @ cf(x, 2, 0), (255, 250, 238))
        ball(m, 1.2, o @ cf(x, 4.3, 0), color)
    for y in (1.5, 3.2): part(m, (30, 0.55, 0.45), o @ cf(0, y, 0), (255, 250, 238))

def tree(par, pos, h, kind):
    m = Inst("Model", "Tree", par)
    x, z = pos
    if kind == "palm":
        for k in range(6):
            ycyl(m, 1.6 - k * 0.1, h / 6 + 0.2, cf(x + k * 0.35, h / 12 + k * h / 6, z) @ rz(-0.06 * k), (150, 100, 55), "Wood")
        top = cf(x + 2.1, h, z)
        for a in range(6):
            part(m, (9, 0.4, 2.4), top @ ry(a * math.pi / 3) @ cf(4, -1, 0) @ rz(-0.35), (60, 170, 60), "Grass")
        for k in range(3): ball(m, 1.1, top @ cf(0.6 * math.cos(k * 2), -0.8, 0.6 * math.sin(k * 2)), (120, 80, 40))
    else:
        ycyl(m, 1.8, h, cf(x, h / 2, z), (120, 75, 40), "Wood")
        g = rnd.choice([(80, 190, 70), (60, 170, 80), (110, 200, 60), (255, 160, 200)])
        for dx, dy, dz, d in ((0, h + 2, 0, 11), (3, h, 2, 8), (-3, h + 0.5, -1.5, 8), (0.5, h + 5, -0.5, 7)):
            ball(m, d, cf(x + dx, dy, z + dz), g, "Grass")

# ---------- Map: start area with 4 bases + a very long, narrow billiard corridor, all walled by mountains ----------
# Each zone of the long table is its own billiard table, and every next one is fancier (see THEMES).
THEMES = [  # frame, frame material, rail, rail material, felt, trim (neon/metal) or None, trim material, decoration
    ((150, 95, 50), "Wood", (120, 70, 35), "Wood", (30, 140, 60), None, "Metal", "lamps"),
    ((95, 55, 30), "Wood", (80, 45, 25), "Wood", (25, 130, 70), (200, 160, 80), "Metal", "plants"),
    ((70, 45, 30), "Wood", (60, 35, 20), "Wood", (40, 90, 200), (210, 215, 225), "Metal", "balls"),
    ((110, 30, 40), "Wood", (90, 20, 30), "Wood", (120, 50, 180), (255, 200, 60), "Metal", "lamps"),
    ((255, 190, 50), "Metal", (240, 170, 40), "Metal", (180, 30, 40), (255, 230, 120), "Neon", "pillars"),
    ((40, 20, 20), "Slate", (120, 20, 20), "Smooth", (150, 20, 30), (255, 80, 30), "Neon", "fire"),
    ((220, 190, 130), "Sandstone", (200, 170, 110), "Sandstone", (40, 170, 170), (255, 210, 80), "Metal", "obelisks"),
    ((170, 220, 255), "Ice", (200, 235, 255), "Ice", (120, 190, 240), (230, 250, 255), "Neon", "crystals"),
    ((50, 40, 40), "Slate", (70, 50, 45), "Slate", (200, 70, 20), (255, 120, 20), "Neon", "fire"),
    ((60, 70, 60), "Metal", (40, 50, 40), "Metal", (90, 200, 40), (150, 255, 40), "Neon", "barrels"),
    ((20, 20, 30), "Glass", (30, 30, 45), "Smooth", (20, 40, 60), (0, 255, 220), "Neon", "pylons"),
    ((110, 75, 40), "Planks", (90, 60, 30), "Planks", (30, 110, 90), (220, 180, 90), "Metal", "barrels"),
    ((25, 20, 20), "Smooth", (200, 30, 40), "Smooth", (230, 220, 200), (255, 200, 60), "Metal", "torii"),
    ((220, 225, 255), "Glass", (200, 210, 255), "Glass", (110, 80, 170), (220, 200, 255), "Neon", "spirits"),
    ((250, 250, 245), "Marble", (255, 255, 250), "Marble", (240, 240, 230), (255, 210, 80), "Neon", "pillars"),
    ((30, 10, 15), "Slate", (90, 0, 20), "Smooth", (110, 0, 25), (255, 30, 60), "Neon", "spikes"),
    ((210, 245, 255), "Glass", (230, 250, 255), "Marble", (90, 210, 240), (120, 255, 255), "Neon", "clouds"),
    ((255, 240, 170), "Metal", (255, 230, 120), "Metal", (40, 30, 90), (255, 255, 190), "Neon", "stars"),
    ((60, 30, 120), "Glass", (80, 40, 160), "Glass", (30, 15, 70), (170, 110, 255), "Neon", "planets"),
    ((25, 15, 60), "Glass", (40, 20, 90), "Smooth", (15, 10, 40), (90, 140, 255), "Neon", "planets"),
    ((255, 255, 255), "Smooth", (255, 80, 80), "Smooth", (255, 120, 255), (255, 255, 255), "Neon", "rainbow"),
    ((20, 40, 60), "Glass", (40, 200, 255), "ForceField", (10, 30, 50), (40, 200, 255), "Neon", "crystals"),
    ((15, 15, 15), "Smooth", (25, 25, 25), "Smooth", (35, 35, 35), (255, 255, 255), "Neon", "pylons"),
    ((20, 0, 30), "Smooth", (255, 0, 255), "Neon", (0, 200, 220), (0, 255, 255), "Neon", "glitch"),
    ((255, 255, 255), "Glass", (255, 200, 60), "Metal", (255, 0, 140), (255, 0, 140), "Neon", "crowns"),
]
RAINBOW = [(255, 60, 60), (255, 150, 30), (255, 230, 40), (80, 220, 80), (50, 160, 255), (90, 80, 230), (190, 80, 255)]
RAIL_W, RAIL_H = 3, 4.2
WALK = TW / 2 + RAIL_W + 12  # walkway decoration line


def fx(par, pos, color, kind="Sparkle"):  # Map.luau turns these into particle emitters
    p = part(par, (1, 1, 1), cf(*pos), WHITE, Transparency=1, CanCollide=False, name="Fx")
    Inst("Color3Value", kind, p, Value=color)
    return p


def mountain(par, x, z, d, h, rot, kind):
    m = Inst("Model", "Mountain", par)
    o = cf(x, 0, z) @ ry(rot)
    tag_mesh(part(m, (0.2, 0.2, 0.2), o, WHITE, Transparency=1, CanCollide=False, name="MeshPivot"), kind, vscale=(d, h, d))
    for k, (col, mt) in enumerate((((96, 176, 82), "Grass"), ((128, 118, 112), "Rock"), ((110, 102, 98), "Rock"), ((250, 252, 255), "Snow"))):
        w = d * (0.92 - k * 0.24)
        part(m, (w, h / 4 + 1, w), o @ cf(0, h / 8 + k * h / 4, 0) @ ry(math.pi / 4 * (k % 2)), col, mt)


def ridge(par, a, b, out, spacing=42):
    ax, az = a; bx, bz = b
    n = max(1, int(math.hypot(bx - ax, bz - az) // spacing))
    for row in (0, 1):
        for k in range(n + 1):
            t = k / n
            d = rnd.uniform(110, 150) * (1.3 if row else 1)
            h = rnd.uniform(100, 150) * (1.4 if row else 1)
            off = d * (0.33 + row * 0.6)
            x = ax + (bx - ax) * t + out[0] * off + rnd.uniform(-6, 6)
            z = az + (bz - az) * t + out[1] * off + rnd.uniform(-6, 6)
            mountain(par, x, z, d, h, rnd.uniform(0, 6.28), "Peak" if (k + row) % 2 else "Mountain")


def deco(par, kind, x, z, trim, zi):
    s = 1 if x > 0 else -1
    t = trim or (255, 220, 150)
    if kind == "lamps":
        ycyl(par, 1, 14, cf(x, 7, z), (60, 60, 70), "Metal")
        light(ball(par, 2.6, cf(x, 15, z), (255, 240, 180), "Neon"), (255, 230, 170), 30)
    elif kind == "plants":
        part(par, (5, 2, 5), cf(x, 1, z), (150, 90, 50), "Wood")
        for k in range(3): ball(par, 3.5, cf(x + rnd.uniform(-1, 1), 3 + k * 1.2, z + rnd.uniform(-1, 1)), (60, 170, 70), "Grass")
    elif kind == "balls":
        ycyl(par, 5, 3, cf(x, 1.5, z), (240, 240, 245), "Marble")
        mesh_ball(par, 6, cf(x, 6, z) @ ry(rnd.uniform(0, 6)), BALLS[zi % 7])
    elif kind == "pillars":
        ycyl(par, 3, 16, cf(x, 8, z), (250, 248, 240), "Marble")
        ycyl(par, 4, 1, cf(x, 0.5, z), t, "Metal"); ycyl(par, 4, 1, cf(x, 16.5, z), t, "Metal")
        light(ball(par, 3, cf(x, 18.5, z), t, "Neon"), t, 28, 2)
    elif kind == "fire":
        ycyl(par, 4, 5, cf(x, 2.5, z), (40, 35, 35), "Slate")
        ball(par, 3, cf(x, 5.5, z), t, "Neon")
        fx(par, (x, 6, z), t, "Fire")
    elif kind == "obelisks":
        part(par, (3, 18, 3), cf(x, 9, z), (220, 190, 130), "Sandstone")
        part(par, (2, 2, 2), cf(x, 18.6, z) @ ry(math.pi / 4) @ rx(math.pi / 4), t, "Metal")
    elif kind == "crystals":
        for k in range(3):
            part(par, (2.2, rnd.uniform(7, 13), 2.2), cf(x + rnd.uniform(-2, 2), 4, z + rnd.uniform(-2, 2)) @ ang(rnd.uniform(-0.4, 0.4), rnd.uniform(0, 3), rnd.uniform(-0.4, 0.4)), t, "Glass", Transparency=0.2)
        fx(par, (x, 6, z), t)
    elif kind == "barrels":
        for k in range(2):
            ycyl(par, 3.6, 4.5, cf(x + (k - 0.5) * 4, 2.25, z), (130, 85, 45) if zi != 9 else (60, 160, 50), "Wood")
            ycyl(par, 3.8, 0.4, cf(x + (k - 0.5) * 4, 3.6, z), t, "Metal")
    elif kind == "pylons":
        part(par, (2, 20, 2), cf(x, 10, z), (20, 20, 25), "Smooth")
        for y in (5, 10, 15): part(par, (2.3, 0.5, 2.3), cf(x, y, z), t, "Neon")
    elif kind == "torii":
        for o in (-4, 4): ycyl(par, 1.6, 14, cf(x + o, 7, z), (200, 30, 40))
        part(par, (12, 1.2, 1.6), cf(x, 14.6, z), (25, 20, 20)); part(par, (10, 0.8, 1.2), cf(x, 12, z), (200, 30, 40))
    elif kind == "spirits":
        ball(par, 3, cf(x, 9 + rnd.uniform(-2, 2), z), (230, 220, 255), "Neon", Transparency=0.3, CanCollide=False)
        fx(par, (x, 9, z), t, "Spirit")
    elif kind == "spikes":
        for k in range(4): part(par, (1.5, 8, 1.5), cf(x, 3, z) @ ang(rnd.uniform(-0.5, 0.5), 0, rnd.uniform(-0.5, 0.5)), (60, 0, 15), "Slate")
        fx(par, (x, 4, z), t, "Fire")
    elif kind == "clouds":
        for k in range(4): ball(par, rnd.uniform(4, 7), cf(x + rnd.uniform(-3, 3), 14 + rnd.uniform(-1, 1), z + rnd.uniform(-3, 3)), WHITE, CanCollide=False)
    elif kind == "stars":
        st = cf(x, 13, z) @ rx(math.pi / 2)
        for a in range(3): part(par, (1, 7, 1.4), st @ ry(0) @ rz(a * math.pi / 3), t, "Neon", CanCollide=False)
        ycyl(par, 0.6, 9, cf(x, 4.5, z), (200, 200, 210), "Metal"); fx(par, (x, 13, z), t)
    elif kind == "planets":
        p = cf(x, 14, z) @ ang(0.4, rnd.uniform(0, 3), 0.3)
        ball(par, 7, p, t, "Glass", CanCollide=False)
        part(par, (0.3, 12, 12), p @ rz(math.pi / 2), t, "ForceField", "Cyl", CanCollide=False)
    elif kind == "rainbow":
        for k, c in enumerate(RAINBOW): part(par, (3, 2.2, 3), cf(x, 1.1 + k * 2.2, z), c, "Neon")
    elif kind == "glitch":
        for k in range(5): part(par, (rnd.uniform(1, 3),) * 3, cf(x + rnd.uniform(-3, 3), rnd.uniform(2, 12), z + rnd.uniform(-3, 3)), rnd.choice([(255, 0, 255), (0, 255, 255), (255, 255, 255)]), "Neon", CanCollide=False)
    elif kind == "crowns":
        ycyl(par, 6, 4, cf(x, 2, z), (255, 255, 255), "Marble")
        ycyl(par, 5, 2, cf(x, 6, z), (255, 200, 60), "Metal")
        for a in range(6): ball(par, 1.2, cf(x + math.cos(a) * 2.3, 7.4, z + math.sin(a) * 2.3), (255, 0, 140), "Neon")
        light(part(par, (0.5, 0.5, 0.5), cf(x, 9, z), WHITE, Transparency=1, CanCollide=False), (255, 0, 140), 30, 3)
        fx(par, (x, 8, z), (255, 0, 140))


def long_table(world):
    long = Inst("Model", "LongTable", world)
    for i in range(N):
        z0 = TSZ + i * ZL
        zc = z0 + ZL / 2
        frame, fmat, rail, rmat, felt, trim, tmat, kind = THEMES[i]
        rarity, rcol = RAR[i]
        seg = Inst("Model", f"Table{i + 1}", long)
        tr = dict(Transparency=0.35) if fmat == "Glass" else {}
        # body on legs: frame from y 1.6 to 3.0, felt on top, high rails along both sides
        part(seg, (TW + 2 * RAIL_W, 1.4, ZL), cf(0, 2.3, zc), frame, fmat, **tr)
        part(seg, (TW, 0.3, ZL - 0.2), cf(0, 3.15, zc), felt, "Fabric", name=f"Zone{i + 1}")
        for sx in (-1, 1):
            rc = RAINBOW[(i + (sx > 0)) % 7] if kind == "rainbow" else rail
            part(seg, (RAIL_W, RAIL_H, ZL), cf(sx * (TW / 2 + RAIL_W / 2), 3 + RAIL_H / 2, zc), rc, rmat, **(dict(Transparency=0.3) if rmat in ("Glass", "ForceField") else {}))
            part(seg, (0.7, 1.1, ZL), cf(sx * (TW / 2 + 0.35), 3.85, zc), tuple(int(c * 0.75) for c in felt), "Fabric")
            if trim:
                part(seg, (RAIL_W + 0.4, 0.5, ZL), cf(sx * (TW / 2 + RAIL_W / 2), 3 + RAIL_H + 0.25, zc), trim, tmat)
            for k in range(1, 8):  # sights on the rail
                part(seg, (0.8, 0.12, 0.8), cf(sx * (TW / 2 + RAIL_W / 2), 3 + RAIL_H + (0.55 if trim else 0.06), z0 + k * ZL / 8) @ ry(math.pi / 4), trim or (255, 250, 235), "Neon" if i >= 4 else "Smooth")
            if i >= 4:  # underglow
                part(seg, (0.4, 0.4, ZL - 2), cf(sx * (TW / 2 + RAIL_W + 0.2), 1.7, zc), trim, "Neon")
            for lz in (z0 + 4, z0 + ZL - 4):  # turned legs
                leg = cf(sx * (TW / 2 + 1), 0, lz)
                ycyl(seg, 2.6, 1.6, leg @ cf(0, 0.8, 0), frame if i < 4 else (255, 200, 60), fmat if i < 4 else "Metal")
                ycyl(seg, 3.4, 0.4, leg @ cf(0, 0.2, 0), (60, 40, 30) if i < 4 else (255, 220, 120), "Metal")
            if i >= 7:
                fx(seg, (sx * (TW / 2 + RAIL_W / 2), 8, z0 + 2), trim)
            for dz in (20, 60):
                deco(seg, kind, sx * WALK, z0 + dz, trim, i)
        # gate with the rarity name at the start of every zone
        nf = Inst("Folder", f"Neon{i + 1}", long)
        for sx in (-1, 1):
            part(nf, (1.8, 20, 1.8), cf(sx * (TW / 2 + RAIL_W + 3), 10, z0), rcol, "Neon")
            ball(nf, 4, cf(sx * (TW / 2 + RAIL_W + 3), 21, z0), rcol, "Neon")
            pc = cf(sx * TW / 2, 3.32, zc)
            ycyl(seg, 4.4, 0.2, pc, (5, 5, 5))
            ycyl(nf, 5.4, 0.15, pc @ cf(0, -0.05, 0), rcol, "Neon")
        beam = part(long, (TW + 2 * RAIL_W + 10, 5, 1.2), cf(0, 21, z0), (40, 25, 60), name=f"Beam{i + 1}")
        part(nf, (TW + 2 * RAIL_W + 10, 0.6, 1.4), cf(0, 18.3, z0), rcol, "Neon")
        light(beam, WHITE, 34, 1.2)
        label(beam, FACE["Front"], rarity, rcol, 20, "Rarity")
        label(beam, FACE["Back"], f"Table {i + 1}", WHITE, 20)
    part(long, (TW + 2 * RAIL_W, RAIL_H + 1.4, RAIL_W), cf(0, 1.6 + (RAIL_H + 1.4) / 2, END + RAIL_W / 2), THEMES[-1][2], "Metal")
    part(long, (TW + 2 * RAIL_W, RAIL_H + 1.4, 1), cf(0, 1.6 + (RAIL_H + 1.4) / 2, TSZ - 0.5), THEMES[0][2], "Wood")  # head cushion


def player_base(world, i, o, col):
    b = Inst("Model", f"Base{i + 1}", world)
    light_col = tuple(int(c * 0.3 + 255 * 0.7) for c in col)
    # round raised platform with a coloured rim
    ycyl(b, 96, 2, o @ cf(0, 1, 0), col)
    ycyl(b, 92, 0.6, o @ cf(0, 2.1, 0), (250, 240, 225), "Planks", name="Floor")
    ycyl(b, 97, 0.4, o @ cf(0, 2.05, 0), col, "Neon")
    top = o @ cf(0, 2.4, 0)
    ycyl(b, 40, 0.2, top @ cf(0, 0.05, 0), (170, 40, 60), "Fabric")
    ycyl(b, 42, 0.15, top @ cf(0, 0.0, 0), GOLD, "Metal")
    for k in range(3):  # front stairs
        part(b, (24, 0.8, 3), o @ cf(0, 0.4 + k * 0.8 - 0.4, 49.5 - k * 2.2 + 2), (250, 240, 225), "Planks")
    pool_table(b, top)
    table_lamp(b, top)
    # pergola over the table
    for px, pz in ((-11, -13), (11, -13), (-11, 13), (11, 13)):
        ycyl(b, 2.2, 15, top @ cf(px, 7.5, pz), (250, 248, 240), "Marble")
        ycyl(b, 3, 0.8, top @ cf(px, 15.2, pz), GOLD, "Metal")
        ycyl(b, 3, 0.6, top @ cf(px, 0.3, pz), GOLD, "Metal")
    for pz in (-13, 13): part(b, (25, 1.2, 1.6), top @ cf(0, 16, pz), (250, 248, 240), "Marble")
    for px in (-11, 11): part(b, (1.6, 1.2, 29), top @ cf(px, 16, 0), (250, 248, 240), "Marble")
    for k in range(-5, 6): part(b, (23, 0.4, 0.8), top @ cf(0, 16.8, k * 2.4), col)
    # podiums for the characters (arc around the table)
    slots = Inst("Folder", "Slots", b)
    for s in range(SLOTS):
        a = math.radians(-150 + s * 300 / (SLOTS - 1))
        x, z = math.sin(a) * 23, -math.cos(a) * 23
        ycyl(b, 7, 0.8, top @ cf(x, 0.4, z), (240, 240, 245), "Marble")
        ycyl(b, 7.4, 0.25, top @ cf(x, 0.8, z), col, "Neon")
        ycyl(slots, 5.4, 0.6, top @ cf(x, 1.1, z), WHITE, "Marble", name=f"Slot{s + 1}")
        light(part(b, (0.4, 0.4, 0.4), top @ cf(x, 9, z), WHITE, Transparency=1, CanCollide=False), light_col, 12, 1.5)
    # trophy wall at the back with the owner's name
    for k in range(-4, 5):
        wall = top @ ry(-math.radians(k * 10.4)) @ cf(0, 0, -41)
        part(b, (7.4, 10, 1.4), wall @ cf(0, 5, 0), (250, 245, 235), "Marble")
        part(b, (7.4, 0.6, 1.8), wall @ cf(0, 10.3, 0), col, "Neon")
        mesh_ball(b, 2.2, wall @ cf(0, 6, 1.4), BALLS[k % 7])
        ycyl(b, 1.6, 2, wall @ cf(0, 1, 1.4), GOLD, "Metal")
    sign = part(b, (30, 7, 1.4), top @ cf(0, 16, -42), col, name="Sign")
    label(sign, FACE["Back"], "Free Base")
    part(b, (32, 0.8, 1.8), top @ cf(0, 12.2, -42), GOLD, "Metal")
    # fence: 9-gon of Blender fence segments, open at the front for the stairs
    R = 15 / math.sin(math.pi / 9)
    for k in range(9):
        a = 2 * math.pi * k / 9
        if k in (0, 4, 5):  # front = entrance, back = trophy wall
            continue
        mid = top @ ry(-a) @ cf(0, 0, R * math.cos(math.pi / 9) - 0.5)
        fence(b, mid, col)
    # entrance arch
    for sx in (-1, 1):
        ycyl(b, 2.6, 14, top @ cf(sx * 13, 7, 43), col)
        light(ball(b, 3.2, top @ cf(sx * 13, 14.8, 43), col, "Neon"), col, 22)
    gate = part(b, (28, 3, 1.2), top @ cf(0, 13, 43), (250, 245, 235), "Marble")
    label(gate, FACE["Back"], "🎱 WELCOME 🎱", col)
    # gym corner: mat, dumbbell, weight rack
    part(b, (12, 0.25, 9), top @ cf(-27, 0.12, 22), (44, 44, 58))
    dumbbell(b, top @ cf(-27, 0.7, 22))
    prompt(part(b, (7, 3, 4), top @ cf(-27, 1.5, 22), WHITE, Transparency=1, CanCollide=False, name="DumbbellHit"), "Lift", "Dumbbell")
    for sx in (-1, 1): part(b, (0.6, 5, 0.6), top @ cf(-27 + sx * 4, 2.5, 17), (60, 60, 70), "Metal")
    part(b, (8.6, 0.5, 0.5), top @ cf(-27, 4.2, 17), (215, 220, 232), "Metal", "Cyl")
    for sx in (-1, 1): part(b, (0.5, 2.4, 2.4), top @ cf(-27 + sx * 3, 4.2, 17), (240, 60, 70), shape="Cyl")
    # cue kiosk with a striped awning
    shop = part(b, (9, 3.6, 3.6), top @ cf(27, 1.8, 24), (120, 200, 255), name="CueShop")
    part(b, (9.6, 0.4, 4.2), top @ cf(27, 3.8, 24), (250, 245, 235), "Marble")
    part(b, (9, 8, 0.6), top @ cf(27, 4, 20), (90, 160, 230))
    for k in range(5): part(b, (2, 0.5, 5.5), top @ cf(23 + k * 2, 9.2, 22.6) @ rx(-0.25), (255, 90, 90) if k % 2 == 0 else WHITE)
    for sx in (-4.3, 4.3): part(b, (0.5, 9, 0.5), top @ cf(27 + sx, 4.5, 25.5), WHITE)
    label(shop, FACE["Back"], "🎱 CUES")
    prompt(shop, "Open", "Cue Shop")
    for k, cc in enumerate(((230, 190, 120), (255, 200, 40), (140, 240, 255)), 1):
        cue(b, top @ cf(23.5 + k * 1.8, 4.6 + 0.4, 20.6) @ rz(math.radians(6 - k * 3)), cc)
    # planters with small palms on the sides
    for sx in (-1, 1):
        for pz in (-6, 6):
            ycyl(b, 4.5, 2, top @ cf(sx * 37, 1, pz), col)
            ball(b, 4, top @ cf(sx * 37, 2.6, pz), (70, 175, 70), "Grass")
    part(b, (4, 1, 4), top @ cf(0, 0.5, 34), WHITE, Transparency=1, CanCollide=False, name="SpawnPoint")
    Inst("Folder", "Chars", b)


def build():
    ws = Inst("Workspace", "Workspace")
    world = Inst("Folder", "World", ws)
    env = Inst("Folder", "Environment", world)

    part(env, (1600, 4, END + 900), cf(0, -2, END / 2), (105, 200, 85), "Grass", name="Ground")
    part(env, (450, 0.4, 46), cf(0, 0.2, 60), (250, 228, 185), "Pebble", name="Plaza")
    for x in range(-220, 221, 10):
        part(env, (5, 0.42, 5), cf(x, 0.21, 60 + (5 if (x // 10) % 2 else -5)), WHITE, "Marble")
    for sx in (-1, 1):  # walkways along the long table
        part(env, (24, 0.3, TL + 20), cf(sx * (TW / 2 + RAIL_W + 12.5), 0.15, TSZ + TL / 2), (250, 228, 185), "Pebble")
        for z in np.arange(TSZ + 10, END, 18):  # bushes at the mountain foot
            ball(env, rnd.uniform(4, 7), cf(sx * rnd.uniform(44, 47), 1, z + rnd.uniform(-4, 4)), rnd.choice([(70, 175, 70), (90, 190, 80), (255, 150, 200)]), "Grass")

    long_table(world)

    # rainbow arch + title over the head of the table
    arch = Inst("Model", "RainbowArch", world)
    for b, col in enumerate(RAINBOW, 1):
        R = 34 - b * 1.6
        for k in range(25):
            a = math.pi * k / 24
            part(arch, (1.6, 1.6, 4.6), cf(math.cos(a) * R, math.sin(a) * R, TSZ - 8) @ rz(a) @ rx(math.pi / 2), col, "Neon", CanCollide=False)
    label(part(arch, (44, 7, 1), cf(0, 22, TSZ - 8), (255, 110, 170)), FACE["Front"], "🎱 BILLIARD HUNTERS 🎱")

    # giant 8-ball at the far end
    eight = Inst("Model", "EightBall", world)
    e = cf(0, 34, END + 55)
    ball(eight, 40, e, (15, 15, 20), "Glass", name="Ball", Reflectance=0.15)
    c = part(eight, (1, 18, 18), e @ cf(0, 0, -19.7) @ ry(math.pi / 2), WHITE, shape="Cyl", name="Circle", CanCollide=False)
    label(c, FACE["Right"], "8", (0, 0, 0), 10)
    ycyl(eight, 30, 12, cf(0, 6, END + 55), GOLD, "Metal", name="Pedestal")
    for k in range(1, 4):
        part(eight, (1, 50 + k * 6, 50 + k * 6), e @ ang(k, k * 0.7, 0), RAINBOW[k * 2 - 1], "ForceField", "Cyl", name=f"Ring{k}", CanCollide=False)

    fb = Inst("Folder", "FloatBalls", world)
    for k in range(30):
        sx = 1 if k % 2 else -1
        mesh_ball(fb, rnd.uniform(6, 11), cf(sx * rnd.uniform(28, 42), rnd.uniform(30, 60), rnd.uniform(140, END)), BALLS[k % 7], CanCollide=False)

    trees = Inst("Folder", "Trees", world)
    for x in range(-210, 211, 30):  # behind the bases
        tree(trees, (x + rnd.uniform(-6, 6), -78 + rnd.uniform(-6, 6)), rnd.uniform(12, 16), "palm" if (x // 30) % 2 else "round")
    for sx in (-1, 1):
        for z in range(-60, 60, 28):
            tree(trees, (sx * rnd.uniform(212, 222), z), rnd.uniform(11, 15), "round")
        for x in range(60, 210, 30):
            tree(trees, (sx * x, rnd.uniform(84, 92)), rnd.uniform(12, 16), "palm")

    # mountains: a closed ring around the start area and the long corridor
    hills = Inst("Folder", "Mountains", world)
    ridge(hills, (-260, -115), (260, -115), (0, -1))
    for sx in (-1, 1):
        ridge(hills, (sx * 260, -115), (sx * 260, 130), (sx, 0))
        ridge(hills, (sx * 260, 130), (sx * 150, 130), (0, 1))  # stops short of the corridor mouth
        ridge(hills, (sx * 72, 150), (sx * 72, END + 125), (sx, 0), 40)
    ridge(hills, (-72, END + 125), (72, END + 125), (0, 1))
    # invisible walls exactly along the playable shape
    walls = Inst("Folder", "Walls", world)
    H = 400
    def wall(x0, z0, x1, z1):
        ln = math.hypot(x1 - x0, z1 - z0)
        part(walls, (2, H, ln), cf((x0 + x1) / 2, H / 2, (z0 + z1) / 2) @ ry(math.atan2(x1 - x0, z1 - z0)), WHITE, Transparency=1, name="Wall")
    wall(-225, -88, 225, -88)
    for sx in (-1, 1):
        wall(sx * 225, -88, sx * 225, 78)
        wall(sx * 225, 78, sx * 48, 78)
        wall(sx * 48, 78, sx * 48, END + 95)
    wall(-48, END + 95, 48, END + 95)

    bcol = [(255, 110, 120), (110, 170, 255), (110, 225, 140), (255, 190, 80)]
    for i in range(4):
        player_base(world, i, cf((i - 1.5) * 105, 0, -10), bcol[i])
    part(world, (6, 1, 6), cf(0, 0.6, 62), WHITE, cls="SpawnLocation", name="Spawn", Transparency=1, CanCollide=False, Neutral=True)
    return ws
# ---------- rbxlx ----------
ref = iter(range(10 ** 9))
def v3(n, v): return f'<Vector3 name="{n}"><X>{v[0]:.4f}</X><Y>{v[1]:.4f}</Y><Z>{v[2]:.4f}</Z></Vector3>'
def c3(n, c): return f'<Color3 name="{n}"><R>{c[0] / 255:.4f}</R><G>{c[1] / 255:.4f}</G><B>{c[2] / 255:.4f}</B></Color3>'
def props(i):
    p, out = i.p, [f'<string name="Name">{escape(i.name)}</string>']
    if "cf" in p:
        m = p["cf"]
        out.append('<CoordinateFrame name="CFrame">' + "".join(f"<{k}>{m[a, b]:.5f}</{k}>" for k, (a, b) in zip(
            ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"],
            [(0, 3), (1, 3), (2, 3), (0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2), (2, 0), (2, 1), (2, 2)])) + "</CoordinateFrame>")
        out += [v3("size", p["size"]), f'<Color3uint8 name="Color3uint8">{(255 << 24) | (p["color"][0] << 16) | (p["color"][1] << 8) | p["color"][2]}</Color3uint8>',
                f'<token name="Material">{MAT[p["mat"]]}</token>', f'<token name="shape">{SHAPE[p["shape"]]}</token>',
                f'<bool name="Anchored">{str(p.get("Anchored", True)).lower()}</bool>', f'<bool name="CanCollide">{str(p.get("CanCollide", True)).lower()}</bool>',
                f'<bool name="CastShadow">{str(p.get("CastShadow", True)).lower()}</bool>',
                f'<float name="Transparency">{p.get("Transparency", 0)}</float>', f'<float name="Reflectance">{p.get("Reflectance", 0)}</float>',
                '<token name="TopSurface">0</token><token name="BottomSurface">0</token>']
        if "Neutral" in p: out.append('<bool name="Neutral">true</bool><bool name="AllowTeamChangeOnTouch">false</bool>')
    if i.cls == "SurfaceGui":
        out += [f'<token name="Face">{p["Face"]}</token>', '<token name="SizingMode">1</token>', f'<float name="PixelsPerStud">{p["PixelsPerStud"]}</float>', '<float name="LightInfluence">0</float>']
    if i.cls == "TextLabel":
        out += ['<UDim2 name="Size"><XS>1</XS><XO>0</XO><YS>1</YS><YO>0</YO></UDim2>', '<float name="BackgroundTransparency">1</float>', '<bool name="TextScaled">true</bool>',
                f'<string name="Text">{escape(p["Text"])}</string>', c3("TextColor3", p["TextColor3"]),
                '<Font name="FontFace"><Family><url>rbxasset://fonts/families/FredokaOne.json</url></Family><Weight>700</Weight><Style>Normal</Style></Font>']
    if i.cls == "UIStroke": out += [c3("Color", (40, 20, 60)), '<float name="Thickness">4</float>']
    if i.cls == "PointLight": out += [c3("Color", p["Color"]), f'<float name="Range">{p["Range"]}</float>', f'<float name="Brightness">{p["Brightness"]}</float>']
    if i.cls == "ProximityPrompt": out += [f'<string name="ActionText">{p["ActionText"]}</string>', f'<string name="ObjectText">{p["ObjectText"]}</string>', '<float name="HoldDuration">0</float>']
    if i.cls == "StringValue": out.append(f'<string name="Value">{escape(p["Value"])}</string>')
    if i.cls == "NumberValue": out.append(f'<double name="Value">{p["Value"]}</double>')
    if i.cls == "Color3Value": out.append(c3("Value", p["Value"]))
    if i.cls == "Vector3Value": out.append(v3("Value", p["Value"]))
    if "Source" in p: out.append(f'<ProtectedString name="Source"><![CDATA[{p["Source"]}]]></ProtectedString>')
    for k in ("ClockTime", "Brightness", "Density", "Haze", "Intensity", "Size", "Threshold", "Saturation", "Contrast", "EnvironmentDiffuseScale", "EnvironmentSpecularScale"):
        if k in p and i.cls != "PointLight": out.append(f'<float name="{k}">{p[k]}</float>')
    for k in ("Color", "Decay", "OutdoorAmbient", "Ambient"):
        if k in p and i.cls not in ("PointLight",): out.append(c3(k, p[k]))
    return "".join(out)
def xml(i):
    return f'<Item class="{i.cls}" referent="RBX{next(ref)}"><Properties>{props(i)}</Properties>{"".join(xml(k) for k in i.kids)}</Item>'

def src(path): return open(os.path.join(ROOT, path), encoding="utf-8").read()

def services(ws):
    rs = Inst("ReplicatedStorage", "ReplicatedStorage")
    shared = Inst("Folder", "Shared", rs)
    for n in ("Config", "Meshes", "MeshBuilder"):
        Inst("ModuleScript", n, shared, Source=src(f"src/shared/{n}.luau"))
    sss = Inst("ServerScriptService", "ServerScriptService")
    sv = Inst("Folder", "Server", sss)
    Inst("Script", "Main", sv, Source=src("src/server/Main.server.luau"))
    Inst("ModuleScript", "Map", sv, Source=src("src/server/Map.luau"))
    sp = Inst("StarterPlayer", "StarterPlayer")
    cl = Inst("Folder", "Client", Inst("StarterPlayerScripts", "StarterPlayerScripts", sp))
    for n in ("UI", "Throw", "Visuals"):
        Inst("LocalScript", n, cl, Source=src(f"src/client/{n}.client.luau"))
    lt = Inst("Lighting", "Lighting", ClockTime=14.6, Brightness=3, EnvironmentDiffuseScale=1, EnvironmentSpecularScale=1, OutdoorAmbient=(150, 140, 170), Ambient=(90, 80, 110))
    Inst("Sky", "Sky", lt)
    Inst("Atmosphere", "Atmosphere", lt, Density=0.22, Haze=0.6, Color=(200, 225, 255), Decay=(120, 150, 210))
    Inst("BloomEffect", "Bloom", lt, Intensity=0.7, Size=28, Threshold=1.4)
    Inst("ColorCorrectionEffect", "Grade", lt, Saturation=0.22, Contrast=0.06)
    Inst("SunRaysEffect", "SunRays", lt, Intensity=0.06)
    return [ws, rs, sss, sp, lt]

def dump_scene(ws, path):  # flat list for tools/preview.py; tagged parts are drawn with the Blender meshes
    out = []
    def mesh_of(p):
        tag = next((k for k in p.kids if k.cls == "StringValue" and k.name == "Mesh"), None)
        if not tag: return None
        sc = next((k.p["Value"] for k in p.kids if k.name == "Scale"), 1)
        sc = list(sc) if isinstance(sc, tuple) else [sc] * 3
        return dict(mesh=tag.p["Value"], m=p.p["cf"].tolist(), sc=sc)
    def walk(i):
        piv = next((k for k in i.kids if k.name == "MeshPivot"), None) if i.cls == "Model" else None
        if piv:
            out.append(mesh_of(piv))
            return
        if "cf" in i.p:
            ms = mesh_of(i)
            if ms: out.append(ms)
            elif i.p.get("Transparency", 0) < 1:
                out.append(dict(m=i.p["cf"].tolist(), s=i.p["size"], c=i.p["color"], mat=i.p["mat"], sh=i.p["shape"], t=i.p.get("Transparency", 0)))
        for k in i.kids: walk(k)
    walk(ws)
    json.dump(out, open(path, "w"))
    return len(out)

if __name__ == "__main__":
    ws = build()
    data = '<roblox version="4">' + "".join(xml(s) for s in services(ws)) + "</roblox>"
    open(os.path.join(ROOT, "BilliardHunters.rbxlx"), "w", encoding="utf-8").write(data)
    print("parts:", dump_scene(ws, os.path.join(ROOT, "tools/scene.json")), "-> BilliardHunters.rbxlx")
