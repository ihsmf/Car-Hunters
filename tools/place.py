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

MAT = dict(Plastic=256, Smooth=272, Wood=512, Planks=528, Marble=784, Slate=800, Concrete=816, Brick=848,
           Pebble=864, Cobble=880, Rock=896, Sandstone=912, Metal=1088, Grass=1280, Sand=1296, Fabric=1312, Snow=1328,
           Ice=1536, Glass=1568, ForceField=1584)
SHAPE = dict(Ball=0, Block=1, Cyl=2)

class Inst:
    def __init__(s, cls, name, parent=None, **p):
        s.cls, s.name, s.p, s.kids = cls, name, p, []
        if parent is not None: parent.kids.append(s)

def part(parent, size, m, color, mat="Smooth", shape="Block", name="Part", cls="Part", **kw):
    return Inst(cls, name, parent, size=size, cf=m, color=color, mat=mat, shape=shape, **kw)
def ycyl(parent, d, h, m, color, mat="Smooth", **kw):  # cylinder along Y
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
    part(par, (3.4, 0.2, 9.4), o @ cf(0, 10.65, 0), (255, 245, 200), "Glass")
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
# ---------- The long table: 25 Blender table segments, each with its own scenery on both sides ----------
RAINBOW = [(255, 60, 60), (255, 150, 30), (255, 230, 40), (80, 220, 80), (50, 160, 255), (90, 80, 230), (190, 80, 255)]
RAIL_W, RAIL_H = 3, 4.2


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


SNOWY = dict(Grass=(250, 252, 255), Rock=(185, 198, 214), RockDark=(150, 165, 186), Snow=(255, 255, 255))
# per zone: table (wood, rail, felt, trim), ground (colour, material), near props, far props, optional sea
# prop = (mesh, overrides, scale or (min, max) or Vector3 tuple, height above ground, count)
THEMES = [
    dict(t=((150, 95, 50), (120, 70, 35), (30, 140, 60), (205, 205, 210)), g=((110, 200, 90), "Grass"),
         near=[("Tree", {}, (1.0, 1.3), 0, 3), ("Rock", {}, (0.8, 1.4), 0, 1)], far=[("Tree", {}, (2.2, 3), 0, 3)]),
    dict(t=((95, 55, 30), (80, 45, 25), (25, 130, 70), (230, 180, 70)), g=((100, 190, 85), "Grass"),
         near=[("Pine", {"Snow": (40, 120, 70)}, (1.0, 1.4), 0, 4)], far=[("Pine", {"Snow": (40, 120, 70)}, (2.4, 3.2), 0, 4), ("Tree", {}, (2.4, 3), 0, 1)]),
    dict(t=((70, 45, 30), (60, 35, 20), (40, 90, 200), (210, 215, 225)), g=((120, 200, 140), "Grass"),
         near=[("Tree", {"Leaves": (60, 170, 120)}, (1.0, 1.3), 0, 3), ("Rock", {}, (1, 1.6), 0, 1)], far=[("Rock", {"Rock": (150, 150, 160)}, (5, 8), 0, 2), ("Pine", {"Snow": (40, 120, 70), "Leaves": (50, 140, 110)}, (2.6, 3.2), 0, 3)]),
    dict(t=((110, 30, 40), (90, 20, 30), (120, 50, 180), (240, 195, 80)), g=((90, 170, 80), "Grass"),
         near=[("Column", {}, (0.7, 0.8), 0, 2), ("Tree", {}, (1.0, 1.2), 0, 2)], far=[("Column", {}, (2.2, 2.8), 0, 2), ("Cloud", {}, (1.4, 2), 45, 1)]),
    dict(t=((215, 165, 60), (240, 190, 70), (180, 30, 40), (255, 240, 190)), g=((250, 235, 185), "Marble"),
         near=[("Column", {"Marble": (255, 215, 110), "Gold": (255, 250, 220)}, (0.8, 0.9), 0, 3)],
         far=[("Pyramid", {"Sand": (255, 205, 80)}, (1.6, 2.2), 0, 1), ("Star", {}, (2.5, 3.5), 40, 2)]),
    dict(t=((40, 20, 20), (120, 20, 20), (150, 20, 30), (255, 130, 50)), g=((60, 40, 40), "Slate"),
         near=[("Rock", {"Rock": (70, 50, 50)}, (1.2, 2), 0, 2), ("Crystal", {"Crystal": (220, 40, 40), "CrystalLight": (255, 140, 90)}, (0.9, 1.3), 0, 2)],
         far=[("Volcano", {}, (1.4, 1.9), 0, 2)], fx=("Fire", (255, 110, 30))),
    dict(t=((200, 160, 100), (180, 140, 80), (40, 170, 170), (240, 195, 80)), g=((240, 210, 140), "Sand"),
         near=[("Cactus", {}, (1.0, 1.4), 0, 3), ("Palm", {}, (1.0, 1.2), 0, 1)], far=[("Dune", {}, (1.6, 2.4), 0, 2), ("Pyramid", {}, (2.0, 2.6), 0, 1)]),
    dict(t=((170, 215, 240), (200, 235, 255), (120, 190, 240), (240, 250, 255)), g=((245, 250, 255), "Snow"),
         near=[("Pine", {"Leaves": (40, 100, 80)}, (1.0, 1.5), 0, 3), ("Crystal", {}, (0.8, 1.2), 0, 1)],
         far=[("Mountain", SNOWY, (150, 150, 150), 0, 1), ("Peak", SNOWY, (130, 170, 130), 0, 1), ("Pine", {"Leaves": (40, 100, 80)}, (2.5, 3), 0, 2)], fx=("Snow", (255, 255, 255))),
    dict(t=((50, 40, 40), (70, 50, 45), (200, 70, 20), (255, 150, 50)), g=((55, 45, 45), "Slate"),
         near=[("Rock", {"Rock": (60, 50, 50)}, (1.2, 2.2), 0, 3)], far=[("Volcano", {}, (2.0, 2.6), 0, 2)], fx=("Fire", (255, 120, 30))),
    dict(t=((60, 70, 60), (40, 50, 40), (90, 200, 40), (160, 230, 70)), g=((70, 100, 50), "Grass"),
         near=[("Mushroom", {"Cap": (140, 230, 40), "Spot": (170, 70, 210)}, (1.0, 1.6), 0, 3)],
         far=[("Tree", {"Leaves": (90, 70, 110), "Trunk": (60, 50, 40)}, (2.4, 3), 0, 3), ("Mushroom", {"Cap": (170, 70, 210), "Spot": (140, 230, 40)}, (3, 4), 0, 1)]),
    dict(t=((30, 30, 40), (45, 45, 60), (20, 40, 60), (0, 220, 210)), g=((45, 45, 55), "Concrete"),
         near=[("Crystal", {"Crystal": (0, 200, 200), "CrystalLight": (180, 255, 250)}, (0.7, 1.0), 0, 2)],
         far=[("Tower", {}, (0.9, 1.4), 0, 3), ("Tower", {"Window": (255, 90, 220)}, (0.8, 1.2), 0, 1)]),
    dict(t=((110, 75, 40), (90, 60, 30), (30, 110, 90), (220, 180, 90)), g=((245, 225, 170), "Sand"), sea=True,
         near=[("Palm", {}, (1.0, 1.3), 0, 3), ("Rock", {}, (1, 1.5), 0, 1)], far=[("Palm", {}, (1.6, 2), 0, 2), ("Cloud", {}, (1.5, 2), 45, 1)]),
    dict(t=((25, 20, 20), (200, 30, 40), (230, 220, 200), (240, 195, 80)), g=((120, 190, 100), "Grass"),
         near=[("Tree", {"Leaves": (255, 175, 205)}, (1.0, 1.3), 0, 3)], far=[("Torii", {}, (2.0, 2.4), 0, 1), ("Tree", {"Leaves": (255, 175, 205)}, (2.4, 3), 0, 2)]),
    dict(t=((40, 30, 50), (60, 40, 70), (110, 80, 170), (200, 190, 230)), g=((50, 40, 60), "Slate"),
         near=[("Tree", {"Leaves": (70, 50, 80), "Trunk": (40, 30, 30)}, (1.0, 1.4), 0, 2), ("Mushroom", {"Cap": (120, 60, 180)}, (0.8, 1.2), 0, 2)],
         far=[("Tree", {"Leaves": (70, 50, 80), "Trunk": (40, 30, 30)}, (3, 4), 0, 3), ("Mushroom", {"Cap": (120, 60, 180)}, (3, 4), 0, 1)], fx=("Spirit", (210, 190, 255))),
    dict(t=((250, 250, 245), (255, 255, 250), (240, 240, 230), (240, 195, 80)), g=((255, 255, 255), "Smooth"),
         near=[("Cloud", {}, (0.6, 0.9), 2, 2), ("Column", {}, (0.7, 0.8), 0, 2)], far=[("Cloud", {}, (2.5, 3.5), 30, 2), ("Column", {}, (2.4, 3), 0, 1)]),
    dict(t=((30, 10, 15), (90, 0, 20), (110, 0, 25), (255, 80, 70)), g=((60, 15, 15), "Slate"),
         near=[("Crystal", {"Crystal": (200, 20, 40), "CrystalLight": (255, 120, 100)}, (1.0, 1.5), 0, 3)],
         far=[("Volcano", {"Rock": (45, 12, 12), "Lava": (255, 60, 20)}, (2.0, 2.6), 0, 2)], fx=("Fire", (255, 50, 30))),
    dict(t=((210, 245, 255), (230, 250, 255), (90, 210, 240), (255, 255, 255)), g=((175, 225, 255), "Smooth"),
         near=[("Cloud", {}, (0.7, 1.0), 2, 2)], far=[("Cloud", {}, (2.5, 3.5), 25, 2), ("Tree", {}, (2.2, 2.6), 28, 2)]),
    dict(t=((255, 240, 170), (255, 230, 120), (40, 30, 90), (255, 255, 210)), g=((30, 30, 70), "Smooth"),
         near=[("Star", {}, (1.0, 1.5), 6, 3)], far=[("Star", {}, (4, 6), 30, 2), ("Crystal", {"Crystal": (255, 220, 90), "CrystalLight": (255, 250, 200)}, (2, 2.6), 0, 1)], fx=("Sparkle", (255, 240, 150))),
    dict(t=((60, 30, 120), (80, 40, 160), (30, 15, 70), (170, 120, 255)), g=((25, 15, 50), "Smooth"),
         near=[("Crystal", {"Crystal": (150, 90, 255), "CrystalLight": (220, 200, 255)}, (0.9, 1.3), 0, 2), ("Star", {}, (0.8, 1.2), 8, 2)],
         far=[("Planet", {}, (2.4, 3.2), 50, 1), ("Planet", {"Body": (255, 160, 90), "Ring": (255, 230, 200)}, (1.4, 2), 35, 1)], fx=("Sparkle", (190, 150, 255))),
    dict(t=((25, 15, 60), (40, 20, 90), (15, 10, 40), (100, 150, 255)), g=((12, 12, 35), "Smooth"),
         near=[("Star", {"Star": (190, 210, 255)}, (0.8, 1.2), 7, 3)],
         far=[("Planet", {"Body": (80, 120, 255), "Ring": (200, 220, 255)}, (3, 3.8), 55, 1), ("Planet", {"Body": (90, 230, 200), "Ring": (230, 255, 250)}, (1.6, 2.2), 30, 1)], fx=("Sparkle", (150, 180, 255))),
    dict(t=((255, 255, 255), (255, 120, 170), (255, 120, 255), (255, 230, 90)), g=((255, 230, 245), "Smooth"),
         near=[("Mushroom", {"Cap": (120, 200, 255), "Spot": (255, 240, 120)}, (1.0, 1.4), 0, 2), ("Tree", {"Leaves": (255, 160, 220)}, (1.0, 1.3), 0, 2)],
         far=[("Cloud", {"Cloud": (255, 210, 240)}, (2.5, 3.5), 30, 2), ("Tree", {"Leaves": (160, 220, 255)}, (2.4, 3), 0, 2)]),
    dict(t=((20, 40, 60), (40, 120, 160), (10, 30, 50), (60, 210, 255)), g=((22, 40, 52), "Concrete"),
         near=[("Crystal", {"Crystal": (40, 200, 255), "CrystalLight": (200, 250, 255)}, (1.0, 1.5), 0, 3)],
         far=[("Tower", {"Body": (40, 80, 100), "Window": (140, 240, 255)}, (1.0, 1.4), 0, 3)], fx=("Sparkle", (120, 230, 255))),
    dict(t=((15, 15, 15), (25, 25, 25), (35, 35, 35), (200, 200, 210)), g=((22, 22, 26), "Slate"),
         near=[("Rock", {"Rock": (35, 35, 40)}, (1.2, 2), 0, 3)],
         far=[("Rock", {"Rock": (40, 40, 46)}, (6, 9), 0, 2), ("Crystal", {"Crystal": (30, 30, 36), "CrystalLight": (90, 90, 100)}, (3, 4), 0, 2)]),
    dict(t=((20, 0, 30), (255, 0, 255), (0, 200, 220), (0, 255, 255)), g=((40, 0, 52), "Smooth"),
         near=[("Crystal", {"Crystal": (255, 0, 255), "CrystalLight": (0, 255, 255)}, (1.0, 1.4), 0, 3)],
         far=[("Tower", {"Body": (60, 0, 80), "Window": (255, 0, 255)}, (0.9, 1.3), 0, 2), ("Tower", {"Body": (0, 60, 70), "Window": (0, 255, 255)}, (0.9, 1.2), 0, 1)], fx=("Sparkle", (255, 80, 255))),
    dict(t=((255, 255, 255), (255, 200, 60), (255, 0, 140), (255, 215, 90)), g=((255, 250, 240), "Marble"),
         near=[("Column", {"Marble": (255, 255, 255), "Gold": (255, 200, 60)}, (0.8, 0.9), 0, 2), ("Crystal", {"Crystal": (255, 80, 170), "CrystalLight": (255, 220, 240)}, (1.0, 1.3), 0, 2)],
         far=[("Planet", {"Body": (255, 90, 180), "Ring": (255, 215, 90)}, (2.8, 3.4), 50, 1), ("Star", {}, (5, 7), 35, 1), ("Column", {"Gold": (255, 200, 60)}, (2.6, 3), 0, 1)], fx=("Sparkle", (255, 120, 200))),
]
assert len(THEMES) == N
FALLBACK = dict(  # crude part shapes, only visible if EditableMesh is unavailable
    Tree=("Ball", (8, 8, 8), 9), Pine=("Block", (6, 12, 6), 6), Palm=("Ball", (8, 3, 8), 14), Cactus=("Block", (2, 9, 2), 4.5),
    Rock=("Ball", (5, 4, 5), 1.5), Dune=("Ball", (60, 18, 40), 0), Crystal=("Block", (2.4, 10, 2.4), 5), Volcano=("Block", (60, 46, 60), 23),
    Tower=("Block", (16, 60, 16), 30), Planet=("Ball", (20, 20, 20), 0), Torii=("Block", (15, 14, 1.8), 7), Pyramid=("Block", (40, 24, 40), 12),
    Column=("Block", (3, 16, 3), 8), Mushroom=("Ball", (8, 4, 8), 6), Cloud=("Ball", (20, 10, 14), 0), Star=("Ball", (5, 5, 1.5), 0),
    Mountain=("Block", (0.7, 1, 0.7), 0.5), Peak=("Block", (0.7, 1, 0.7), 0.5))


def prop(par, name, x, y, z, scale, rot, overrides, color):
    m = Inst("Model", name, par)
    o = cf(x, y, z) @ ry(rot)
    vec = isinstance(scale, tuple)
    piv = part(m, (0.2, 0.2, 0.2), o, WHITE, Transparency=1, CanCollide=False, name="MeshPivot")
    tag_mesh(piv, name, scale=None if vec else scale, vscale=scale if vec else None, **overrides)
    shape, size, cy = FALLBACK[name]
    k = scale if vec else (scale, scale, scale)
    part(m, tuple(a * b for a, b in zip(size, k)), o @ cf(0, cy * k[1], 0), color, shape=shape, CanCollide=False)


def scenery(par, i, z0):
    th = THEMES[i]
    gcol, gmat = th["g"]
    for sx in (-1, 1):
        part(par, (380, 1, ZL), cf(sx * (48 + 190), -0.45, z0 + ZL / 2), gcol, gmat, name="Ground")
        if th.get("sea"):
            part(par, (260, 1.2, ZL), cf(sx * (160 + 130), -0.3, z0 + ZL / 2), (60, 170, 220), "Glass", Transparency=0.1, Reflectance=0.25)
        part(par, (1.6, 3, ZL), cf(sx * 48.8, 1.5, z0 + ZL / 2), shade(th["t"][1], 1.1), "Wood" if i < 6 else "Smooth", name="Edge")
        for band, (lo, hi) in (("near", (56, 100)), ("far", (115, 270))):
            for name, ov, sc, h, cnt in th[band]:
                for _ in range(cnt):
                    s = sc if len(sc) == 3 else rnd.uniform(*sc)
                    x = sx * rnd.uniform(lo, hi)
                    z = z0 + rnd.uniform(6, ZL - 6)
                    prop(par, name, x, h, z, s, rnd.uniform(0, 6.28), ov, next(iter(ov.values()), gcol))
        if th.get("fx"):
            kind, col = th["fx"]
            for _ in range(2):
                p = part(par, (1, 1, 1), cf(sx * rnd.uniform(52, 90), 6, z0 + rnd.uniform(5, ZL - 5)), WHITE, Transparency=1, CanCollide=False, name="Fx")
                Inst("Color3Value", kind, p, Value=col)


def long_table(world):
    long = Inst("Model", "LongTable", world)
    scen = Inst("Folder", "Scenery", world)
    for i in range(N):
        z0 = TSZ + i * ZL
        zc = z0 + ZL / 2
        wood, rail, felt, trim = THEMES[i]["t"]
        seg = Inst("Model", f"Table{i + 1}", long)
        tag_mesh(part(seg, (0.2, 0.2, 0.2), cf(0, 0, zc), WHITE, Transparency=1, CanCollide=False, name="MeshPivot"), "TableSegment",
                 Wood=wood, Panel=shade(wood, 1.25), Rail=rail, Felt=felt, Cushion=shade(felt, 0.75), Trim=trim, Leg=shade(wood, 0.8))
        # part-built twin of the Blender segment (collisions + fallback look)
        part(seg, (TW + 2 * RAIL_W, 1.4, ZL), cf(0, 2.3, zc), wood, "Wood")
        part(seg, (TW, 0.3, ZL), cf(0, 3.15, zc), felt, "Fabric", name=f"Zone{i + 1}")
        for sx in (-1, 1):
            part(seg, (RAIL_W, RAIL_H, ZL), cf(sx * (TW / 2 + RAIL_W / 2), 3 + RAIL_H / 2, zc), rail, "Wood")
            part(seg, (RAIL_W + 0.2, 0.15, ZL), cf(sx * (TW / 2 + RAIL_W / 2), 7.25, zc), trim, "Metal")
            ycyl(seg, 4.8, 0.5, cf(sx * TW / 2, 3.12, zc), (20, 16, 18))
            for e in (-1, 1):
                ycyl(seg, 3, 1.6, cf(sx * (TW / 2 + 1), 0.8, zc + e * (ZL / 2 - 6)), shade(wood, 0.8), "Wood")
        scenery(scen, i, z0)
    part(long, (TW + 2 * RAIL_W, RAIL_H + 1.4, RAIL_W), cf(0, 1.6 + (RAIL_H + 1.4) / 2, END + RAIL_W / 2), THEMES[-1]["t"][1], "Metal")
    part(long, (TW + 2 * RAIL_W, RAIL_H + 1.4, 1), cf(0, 1.6 + (RAIL_H + 1.4) / 2, TSZ - 0.5), THEMES[0]["t"][1], "Wood")  # head cushion


def giant_rail(par, x0, z0, x1, z1, ix, iz):
    """Boundary of the start area: a giant billiard-table cushion (wood, felt, brass, pearl sights)."""
    ln = math.hypot(x1 - x0, z1 - z0)
    a = math.atan2(x1 - x0, z1 - z0)
    m = cf((x0 + x1) / 2, 0, (z0 + z1) / 2) @ ry(a)  # local Z runs along the wall
    inward = 1 if math.cos(a) * ix - math.sin(a) * iz > 0 else -1  # local X axis = (cos a, 0, -sin a)
    H = 26
    part(par, (10, H, ln), m @ cf(0, H / 2, 0), (110, 58, 26), "Wood")
    part(par, (10.6, 1.2, ln + 0.6), m @ cf(0, 0.6, 0), (230, 180, 70), "Metal")
    part(par, (10.6, 1, ln + 0.6), m @ cf(0, H - 2.5, 0), (230, 180, 70), "Metal")
    part(par, (3, 4, ln), m @ cf(inward * 4.6, H - 6, 0), (28, 140, 66), "Fabric")  # felt cushion nose
    part(par, (10.2, 1.2, ln), m @ cf(0, H + 0.4, 0), (90, 46, 20), "Wood")
    for k in range(int(ln // 22)):
        zz = -ln / 2 + 11 + k * 22
        ball(par, 2, m @ cf(0, H + 1.1, zz), (255, 250, 235), CanCollide=False)
        part(par, (0.4, 6, 3), m @ cf(inward * 5.1, H / 2 - 2, zz), (150, 86, 44), "Wood")  # carved panel
    part(par, (2, 400, ln), m @ cf(0, 200, 0), WHITE, Transparency=1, name="Wall")


def pocket_tower(par, x, z):
    ycyl(par, 20, 30, cf(x, 15, z), (90, 46, 20), "Wood")
    ycyl(par, 21, 1.4, cf(x, 30.4, z), (230, 180, 70), "Metal")
    ycyl(par, 15, 1.2, cf(x, 30.6, z), (20, 16, 18))
    mesh_ball(par, 11, cf(x, 33, z) @ ry(rnd.uniform(0, 6)), BALLS[rnd.randrange(7)])
    ycyl(par, 21, 1.4, cf(x, 0.7, z), (230, 180, 70), "Metal")


def player_base(world, i, o, col):
    b = Inst("Model", f"Base{i + 1}", world)
    light_col = tuple(int(c * 0.3 + 255 * 0.7) for c in col)
    # round raised platform with a coloured rim
    ycyl(b, 96, 2, o @ cf(0, 1, 0), col)
    ycyl(b, 92, 0.6, o @ cf(0, 2.1, 0), (250, 240, 225), "Planks", name="Floor")
    ycyl(b, 97, 0.4, o @ cf(0, 2.05, 0), GOLD, "Metal")
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
        ycyl(b, 7.4, 0.25, top @ cf(x, 0.8, z), GOLD, "Metal")
        ycyl(slots, 5.4, 0.6, top @ cf(x, 1.1, z), WHITE, "Marble", name=f"Slot{s + 1}")
        light(part(b, (0.4, 0.4, 0.4), top @ cf(x, 9, z), WHITE, Transparency=1, CanCollide=False), light_col, 12, 1.5)
    # trophy wall at the back with the owner's name
    for k in range(-4, 5):
        wall = top @ ry(-math.radians(k * 10.4)) @ cf(0, 0, -41)
        part(b, (7.4, 10, 1.4), wall @ cf(0, 5, 0), (250, 245, 235), "Marble")
        part(b, (7.4, 0.6, 1.8), wall @ cf(0, 10.3, 0), col)
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
        light(ball(b, 3.2, top @ cf(sx * 13, 14.8, 43), (255, 245, 220), "Glass"), col, 22)
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

    part(env, (1400, 4, END + 1000), cf(0, -2, END / 2), (105, 200, 85), "Grass", name="Ground")
    part(env, (450, 0.4, 46), cf(0, 0.2, 60), (250, 228, 185), "Pebble", name="Plaza")
    for x in range(-220, 221, 10):
        part(env, (5, 0.42, 5), cf(x, 0.21, 60 + (5 if (x // 10) % 2 else -5)), WHITE, "Marble")
    for sx in (-1, 1):  # walkways along the long table
        part(env, (25, 0.3, TL + 20), cf(sx * (TW / 2 + RAIL_W + 12.5), 0.15, TSZ + TL / 2), (250, 228, 185), "Pebble")

    long_table(world)

    arch = Inst("Model", "RainbowArch", world)
    for b, col in enumerate(RAINBOW, 1):
        R = 34 - b * 1.6
        for k in range(25):
            a = math.pi * k / 24
            part(arch, (1.6, 1.6, 4.6), cf(math.cos(a) * R, math.sin(a) * R, TSZ - 8) @ rz(a) @ rx(math.pi / 2), col, "Smooth", CanCollide=False)

    eight = Inst("Model", "EightBall", world)
    e = cf(0, 34, END + 55)
    ball(eight, 40, e, (15, 15, 20), "Glass", name="Ball", Reflectance=0.15)
    c = part(eight, (1, 18, 18), e @ cf(0, 0, -19.7) @ ry(math.pi / 2), WHITE, shape="Cyl", name="Circle", CanCollide=False)
    label(c, FACE["Right"], "8", (0, 0, 0), 10)
    ycyl(eight, 30, 12, cf(0, 6, END + 55), GOLD, "Metal", name="Pedestal")
    for k in range(1, 4):
        part(eight, (1, 50 + k * 6, 50 + k * 6), e @ ang(k, k * 0.7, 0), RAINBOW[k * 2 - 1], "ForceField", "Cyl", name=f"Ring{k}", CanCollide=False)

    fb = Inst("Folder", "FloatBalls", world)
    for k in range(16):
        sx = 1 if k % 2 else -1
        mesh_ball(fb, rnd.uniform(5, 9), cf(sx * rnd.uniform(30, 44), rnd.uniform(28, 45), rnd.uniform(140, END)), BALLS[k % 7], CanCollide=False)

    # start area boundary: giant billiard cushions with pocket towers in the corners
    border = Inst("Model", "Border", world)
    for (x0, z0, x1, z1, ix, iz) in ((-225, -88, 225, -88, 0, 1), (-225, -88, -225, 78, 1, 0), (225, -88, 225, 78, -1, 0),
                                     (-225, 78, -60, 78, 0, -1), (60, 78, 225, 78, 0, -1)):
        giant_rail(border, x0, z0, x1, z1, ix, iz)
    for x, z in ((-225, -88), (225, -88), (-225, 78), (225, 78), (-60, 78), (60, 78)):
        pocket_tower(border, x, z)
    walls = Inst("Folder", "Walls", world)
    def wall(x0, z0, x1, z1):
        ln = math.hypot(x1 - x0, z1 - z0)
        part(walls, (2, 400, ln), cf((x0 + x1) / 2, 200, (z0 + z1) / 2) @ ry(math.atan2(x1 - x0, z1 - z0)), WHITE, Transparency=1, name="Wall")
    for sx in (-1, 1):
        wall(sx * 60, 78, sx * 48, 78)
        wall(sx * 48, 78, sx * 48, END + 95)
    wall(-48, END + 95, 48, END + 95)

    trees = Inst("Folder", "Trees", world)  # forest behind the cushions
    for _ in range(70):
        side = rnd.randrange(3)
        if side == 0:
            x, z = rnd.uniform(-300, 300), rnd.uniform(-170, -110)
        else:
            x, z = (1 if side == 1 else -1) * rnd.uniform(250, 320), rnd.uniform(-170, 70)
        prop(trees, "Tree" if rnd.random() < 0.6 else "Pine", x, 0, z, rnd.uniform(2.6, 3.6), rnd.uniform(0, 6.28), {"Snow": (40, 120, 70)}, (80, 170, 70))
    for x in range(-200, 201, 40):  # small palms in front of the back cushion
        tree(trees, (x + rnd.uniform(-5, 5), -76), rnd.uniform(12, 15), "palm")

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
    for n in ("Config", "MeshBuilder"):
        Inst("ModuleScript", n, shared, Source=src(f"src/shared/{n}.luau"))
    meshes = Inst("Folder", "Meshes", shared)
    for f in sorted(os.listdir(os.path.join(ROOT, "src/shared/Meshes"))):
        Inst("ModuleScript", f[:-5], meshes, Source=src(f"src/shared/Meshes/{f}"))
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
        ov = {k.name: list(k.p["Value"]) for k in p.kids if k.cls == "Color3Value"}
        return dict(mesh=tag.p["Value"], m=p.p["cf"].tolist(), sc=sc, ov=ov)
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
