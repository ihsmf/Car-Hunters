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
EXTRA = 10  # extra table segments past the last zone: the table never visibly ends (fades into the haze)
WALL_H = 56
WALL_MAT = dict(Grass="Fabric", Sand="Sandstone", Snow="Ice", Slate="Slate", Marble="Marble", Smooth="Smooth", Concrete="Concrete")


def club_wall(par, a, b, inward, wood, panel, panel_mat, trim, art):
    """Solid billiard-club wall from a to b: wood wainscot, themed upper panel, brass rails,
    pilasters with sconces and framed felt panels. Collides, plus an invisible extension upwards."""
    (x0, z0), (x1, z1) = a, b
    ln = math.hypot(x1 - x0, z1 - z0)
    ang_ = math.atan2(x1 - x0, z1 - z0)
    if math.cos(ang_) * inward[0] - math.sin(ang_) * inward[1] < 0:
        ang_ += math.pi  # make local +X point into the playable area
    m = cf((x0 + x1) / 2, 0, (z0 + z1) / 2) @ ry(ang_)
    part(par, (3.4, 9, ln), m @ cf(-1.7, 4.5, 0), wood, "Wood")
    part(par, (3, WALL_H - 9.4, ln), m @ cf(-1.9, 9.4 + (WALL_H - 9.4) / 2, 0), panel, panel_mat)
    part(par, (3.9, 0.8, ln), m @ cf(-1.55, 9.3, 0), trim, "Metal")
    part(par, (3.9, 1.4, ln), m @ cf(-1.55, WALL_H, 0), trim, "Metal")
    part(par, (3.6, 0.6, ln), m @ cf(-1.6, 0.3, 0), shade(wood, 0.7), "Wood")
    part(par, (2, 300, ln), m @ cf(-2, WALL_H + 150, 0), WHITE, Transparency=1, name="Wall")
    n = max(1, round(ln / 40))
    for k in range(n + 1):  # pilasters with sconces
        z = -ln / 2 + k * ln / n
        part(par, (1.4, WALL_H - 1, 3.2), m @ cf(0.5, (WALL_H - 1) / 2, z), shade(wood, 1.15), "Wood")
        part(par, (1.8, 1.2, 3.8), m @ cf(0.7, WALL_H - 1.6, z), trim, "Metal")
        part(par, (1.8, 1.2, 3.8), m @ cf(0.7, 0.6, z), trim, "Metal")
        part(par, (0.8, 0.5, 1.2), m @ cf(1.4, 15.5, z), trim, "Metal")
        light(ball(par, 1.4, m @ cf(1.9, 16.3, z), (255, 244, 214), "Glass", CanCollide=False), (255, 226, 170), 28, 1.4)
    for k in range(n):  # framed felt panels between the pilasters
        z = -ln / 2 + (k + 0.5) * ln / n
        w = ln / n - 8
        part(par, (0.5, 12, w * 0.7 + 1.2), m @ cf(0.15, 28, z), trim, "Metal")
        part(par, (0.6, 10.8, w * 0.7), m @ cf(0.2, 28, z), tuple(int(c * 0.6 + 236 * 0.4) for c in art), "Fabric")


def wall_theme(i):
    th = THEMES[min(i, N - 1)]
    wood, rail, felt, trim = th["t"]
    gcol, gmat = th["g"]
    panel = tuple(int(c * 0.45 + d * 0.55) for c, d in zip(gcol, (236, 226, 206)))  # soft theme tint on a cream wall
    return shade(wood, 0.8), panel, WALL_MAT.get(gmat, "Smooth"), trim, felt


def long_table(world):
    long = Inst("Model", "LongTable", world)
    walls = Inst("Folder", "CorridorWalls", world)
    for i in range(N + EXTRA):
        z0 = TSZ + i * ZL
        zc = z0 + ZL / 2
        wood, rail, felt, trim = THEMES[min(i, N - 1)]["t"]
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
            wood_w, panel, pmat, trim_w, art = wall_theme(i)
            club_wall(walls, (sx * 48, z0 - (2 if i == 0 else 0)), (sx * 48, z0 + ZL), (-sx, 0), wood_w, panel, pmat, trim_w, art)
    part(long, (TW + 2 * RAIL_W, RAIL_H + 1.4, 1), cf(0, 1.6 + (RAIL_H + 1.4) / 2, TSZ - 0.5), THEMES[0]["t"][1], "Wood")  # head cushion
    far = TSZ + (N + EXTRA) * ZL
    part(walls, (100, 300, 2), cf(0, 150, far + 1), WHITE, Transparency=1, name="Wall")  # far end, deep in the haze


# ---------- Player base: only the billiard table; the gym and the cue shop stand in front of it ----------
def player_base(world, i, o, col):
    b = Inst("Model", f"Base{i + 1}", world)
    ycyl(b, 62, 1.0, o @ cf(0, 0.5, 0), col)
    ycyl(b, 60, 0.3, o @ cf(0, 1.1, 0), (240, 226, 200), "Planks", name="Floor")
    top = o @ cf(0, 1.25, 0)
    pool_table(b, top)
    slots = Inst("Folder", "Slots", b)
    for s in range(SLOTS):  # where the characters stand around the table
        a = math.radians(-150 + s * 300 / (SLOTS - 1))
        ycyl(slots, 4.6, 0.2, top @ cf(math.sin(a) * 17, 0.1, -math.cos(a) * 17), GOLD, "Metal", name=f"Slot{s + 1}")
    sign = part(b, (16, 2.6, 0.6), top @ cf(0, 1.3, 29), shade(col, 0.85), name="Sign")
    label(sign, FACE["Back"], "Free Base")
    part(b, (4, 1, 4), top @ cf(0, 0.5, 23), WHITE, Transparency=1, CanCollide=False, name="SpawnPoint")
    Inst("Folder", "Chars", b)
    gym_station(b, o @ cf(-16, 0, 39))
    cue_shop(b, o @ cf(16, 0, 39), col)


def gym_station(b, o):
    part(b, (10, 0.3, 7), o @ cf(0, 0.15, 0), (44, 44, 58))
    dumbbell(b, o @ cf(0, 0.75, 0.5))
    for sx in (-1, 1):  # small weight rack behind the dumbbell
        part(b, (0.5, 5, 0.5), o @ cf(sx * 3.6, 2.5, -2.6), (60, 60, 72), "Metal")
        part(b, (0.4, 2.2, 2.2), o @ cf(sx * 2.6, 4.2, -2.6), (240, 60, 70), shape="Cyl")
    part(b, (8.2, 0.45, 0.45), o @ cf(0, 4.2, -2.6), (215, 220, 232), "Metal", "Cyl")
    hit = part(b, (8, 3, 5), o @ cf(0, 1.5, 0.5), WHITE, Transparency=1, CanCollide=False, name="DumbbellHit")
    prompt(hit, "Lift", "Dumbbell")
    Inst("ProximityPrompt", "UpgradePrompt", hit, ActionText="Upgrade", ObjectText="Dumbbell", Key=114)  # R
    label(part(b, (5, 1.4, 0.3), o @ cf(0, 6.2, -2.6), (44, 44, 58)), FACE["Back"], "💪 GYM")


def cue_shop(b, o, col):
    """Mini cue shop: counter, back wall with a 3-cue display (current / next / locked), awning, signs."""
    part(b, (12, 0.3, 9), o @ cf(0, 0.15, -1), (150, 96, 54), "Planks")
    shop = part(b, (10, 3.4, 2.6), o @ cf(0, 1.85, 0), (96, 52, 24), "Wood", name="CueShop")
    label(shop, FACE["Back"], "🎱 CUE SHOP", (255, 230, 150))
    prompt(shop, "Open", "Cue Shop")
    part(b, (10.4, 0.3, 3), o @ cf(0, 3.7, 0), (245, 240, 230), "Marble")
    part(b, (10.6, 0.2, 3.2), o @ cf(0, 3.5, 0), GOLD, "Metal")
    part(b, (11, 9, 0.6), o @ cf(0, 4.5, -4.2), (110, 60, 28), "Wood")
    part(b, (11.4, 0.6, 0.8), o @ cf(0, 9.1, -4.2), GOLD, "Metal")
    for y in (1.6, 7.6):
        part(b, (9, 0.35, 0.35), o @ cf(0, y, -3.7), GOLD, "Metal", "Cyl")
    stands = Inst("Folder", "Stands", b)
    for k, x in enumerate((-3, 0, 3), 1):  # server puts the owner's current / next / locked cue here
        part(stands, (0.4, 0.4, 0.4), o @ cf(x, 4.9, -3.4), WHITE, Transparency=1, CanCollide=False, name=f"Stand{k}")
        ycyl(b, 1, 0.3, o @ cf(x, 0.45, -3.4), GOLD, "Metal")
    for sx in (-1, 1):
        part(b, (0.5, 10, 0.5), o @ cf(sx * 5.4, 5, 2.4), WHITE, "Wood")
    for k in range(6):  # striped awning
        part(b, (2, 0.4, 7.6), o @ cf(-5 + k * 2, 10.2, -0.6) @ rx(-0.18), (230, 60, 70) if k % 2 == 0 else WHITE)
    lamp = part(b, (1, 0.4, 1), o @ cf(0, 9.5, 0.5), (60, 60, 70), "Metal")
    light(lamp, (255, 230, 180), 18, 2)
    label(part(b, (9, 1.8, 0.4), o @ cf(0, 11.9, 3), shade(col, 0.9)), FACE["Back"], "UPGRADE YOUR CUE!")
    for k in range(3):  # chalk cubes and a cue ball on the counter
        part(b, (0.45, 0.45, 0.45), o @ cf(-3.8 + k * 0.6, 4.08, 0.4), (60, 140, 230))
    mesh_ball(b, 0.8, o @ cf(3.6, 4.25, 0.3), WHITE)


def build():
    ws = Inst("Workspace", "Workspace")
    world = Inst("Folder", "World", ws)
    env = Inst("Folder", "Environment", world)

    part(env, (1400, 4, END + EXTRA * ZL + 600), cf(0, -2, (END + EXTRA * ZL) / 2), (105, 200, 85), "Grass", name="Ground")
    part(env, (450, 0.4, 30), cf(0, 0.2, 63), (250, 228, 185), "Pebble", name="Plaza")
    for sx in (-1, 1):  # walkways along the long table
        part(env, (25, 0.3, TL + EXTRA * ZL), cf(sx * (TW / 2 + RAIL_W + 12.5), 0.15, TSZ + (TL + EXTRA * ZL) / 2), (250, 228, 185), "Pebble")

    long_table(world)

    # start area: closed on every side by the same club walls
    hall = Inst("Folder", "HallWalls", world)
    wood, panel, pmat, trim, art = wall_theme(0)
    for a, b_, inward in (((-225, -88), (225, -88), (0, 1)), ((-225, -88), (-225, 78), (1, 0)), ((225, -88), (225, 78), (-1, 0)),
                          ((-225, 78), (-48, 78), (0, -1)), ((48, 78), (225, 78), (0, -1))):
        club_wall(hall, a, b_, inward, wood, panel, pmat, trim, art)

    bcol = [(255, 110, 120), (110, 170, 255), (110, 225, 140), (255, 190, 80)]
    for i in range(4):
        player_base(world, i, cf((i - 1.5) * 105, 0, -20), bcol[i])
    part(world, (6, 1, 6), cf(0, 0.6, 66), WHITE, cls="SpawnLocation", name="Spawn", Transparency=1, CanCollide=False, Neutral=True)
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
    if i.cls == "ProximityPrompt" and "Key" in p: out.append(f'<token name="KeyboardKeyCode">{p["Key"]}</token>')
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
    for n in ("Config", "MeshBuilder", "Avatars"):
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
    Inst("Atmosphere", "Atmosphere", lt, Density=0.38, Haze=1.6, Color=(215, 225, 240), Decay=(150, 165, 200))  # far end of the table fades out
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
