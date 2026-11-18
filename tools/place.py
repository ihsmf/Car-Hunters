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
    assert max(size) <= 2048, f"{name}: Roblox clamps parts to 2048 studs per axis, got {size}"
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

def pool_table(par, o):  # felt top at y=3, playing field 6 x 12 (matches the Blender model)
    m = Inst("Model", "PoolTable", par)
    pivot(m, o, "PoolTable")
    W, L = 6, 12
    part(m, (W + 1.34, 0.62, L + 1.34), o @ cf(0, 2.5, 0), WOOD, "Wood")
    part(m, (W, 0.16, L), o @ cf(0, 2.92, 0), (18, 120, 72), "Fabric")
    for s_ in (-1, 1):
        part(m, (0.62, 0.34, L + 1.24), o @ cf(s_ * (W / 2 + 0.31), 3.03, 0), DARK, "Wood")
        part(m, (W, 0.34, 0.62), o @ cf(0, 3.03, s_ * (L / 2 + 0.31)), DARK, "Wood")
        for t in (-1, 0, 1):
            ycyl(m, 0.6, 2.2, o @ cf(s_ * (W / 2 + 0.05), 1.1, t * (L / 2 - 0.4) if t else 0), DARK, "Wood")
    for k in range(15):
        row = next(r for r in range(5) if k < (r + 1) * (r + 2) // 2)
        j_ = k - row * (row + 1) // 2
        ball(m, 0.42, o @ cf((j_ - row / 2) * 0.43, 3.21, -3 - row * 0.37), BALLS[k % 7], CanCollide=False)
    ball(m, 0.42, o @ cf(0.4, 3.21, 3.6), WHITE, CanCollide=False)

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
    p = part(par, (5.2, 2.3, 2.3), o, (70, 70, 78), "Metal", "Cyl", name="Dumbbell", CanCollide=False)
    return tag_mesh(p, "Dumbbell", scale=1, Plate=(70, 70, 78))

GOLDEN = (230, 180, 70)


def fence(par, a, b):
    """Velvet rope barrier from a to b (x, z) on the floor: Blender segments stretched to fit + invisible collider."""
    (x0, z0), (x1, z1) = a, b
    ln = math.hypot(x1 - x0, z1 - z0)
    n = max(1, round(ln / 30))
    yaw = math.atan2(-(z1 - z0), x1 - x0)
    for k in range(n):
        t = (k + 0.5) / n
        o = cf(x0 + (x1 - x0) * t, 0.17, z0 + (z1 - z0) * t) @ ry(yaw)
        m = Inst("Model", "Fence", par)
        pivot(m, o, "Fence", vscale=(ln / n / 30, 1, 1))
        part(m, (ln / n, 0.22, 0.22), o @ cf(0, 3.1, 0), (170, 20, 40), "Fabric", CanCollide=False)
    part(par, (ln, 4.5, 0.6), cf((x0 + x1) / 2, 2.4, (z0 + z1) / 2) @ ry(yaw), WHITE, Transparency=1, name="FenceCollider")


def post(par, x, z):  # brass stanchion at fence corners and entrance ends
    m = Inst("Model", "Post", par)
    ycyl(m, 1.4, 0.2, cf(x, 0.27, z), GOLDEN, "Metal")
    ycyl(m, 0.26, 3.4, cf(x, 1.9, z), GOLDEN, "Metal")
    ball(m, 0.6, cf(x, 3.75, z), GOLDEN, "Metal")


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


def mix(c, d, f):
    return tuple(int(a * (1 - f) + b * f) for a, b in zip(c, d))


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
TABLE_COLORS = [c for _, c in RAR]
for c in TABLE_COLORS[len(THEMES):]:  # tables 26-50: dark lacquered wood, felt and trim from the rarity colour
    THEMES.append(dict(t=(mix(c, (20, 14, 18), 0.7), mix(c, (20, 14, 18), 0.55), mix(c, (10, 10, 20), 0.35), mix(c, WHITE, 0.55))))
assert len(THEMES) == N
EXTRA = 10  # extra table segments past the last zone: the table never visibly ends (fades into the haze)
WALL_H = 56
WALL_MAT = dict(Grass="Fabric", Sand="Sandstone", Snow="Ice", Slate="Slate", Marble="Marble", Smooth="Smooth", Concrete="Concrete")




def club_wall(par, a, b, inward, band, panel, panel_mat, accent, dot, first=True):
    """Cartoon wall from a to b: bright panel, darker band, chunky white trims, a round rail on top,
    candy-striped columns with balls and big polka dots. Collides, plus an invisible extension upwards."""
    (x0, z0), (x1, z1) = a, b
    ln = math.hypot(x1 - x0, z1 - z0)
    ang_ = math.atan2(x1 - x0, z1 - z0)
    if math.cos(ang_) * inward[0] - math.sin(ang_) * inward[1] < 0:
        ang_ += math.pi  # make local +X point into the playable area
    m = cf((x0 + x1) / 2, 0, (z0 + z1) / 2) @ ry(ang_)
    part(par, (3, WALL_H, ln), m @ cf(-1.5, WALL_H / 2, 0), panel, panel_mat)
    part(par, (3.6, 11, ln), m @ cf(-1.4, 5.5, 0), band)
    part(par, (4.4, 1.6, ln), m @ cf(-1.3, 11.2, 0), WHITE)
    part(par, (4.4, 1.6, ln), m @ cf(-1.3, WALL_H - 0.8, 0), WHITE)
    part(par, (ln, 5, 5), m @ cf(-1.5, WALL_H + 2, 0) @ ry(math.pi / 2), accent, shape="Cyl")  # round rail
    part(par, (2, 300, ln), m @ cf(-2, WALL_H + 150, 0), WHITE, Transparency=1, name="Wall")
    n = max(1, round(ln / 80))
    for k in range(n + (1 if first else 0)):  # candy-striped columns (the next wall piece adds the shared one)
        z = ln / 2 - k * ln / n
        ycyl(par, 3.6, WALL_H, m @ cf(1, WALL_H / 2, z), WHITE)
        for y in range(6, int(WALL_H) - 2, 12):
            ycyl(par, 3.9, 2.4, m @ cf(1, y, z), accent)
        ball(par, 5.6, m @ cf(1, WALL_H + 2.6, z), accent)
    for k in range(n):  # polka dots
        z = -ln / 2 + (k + 0.5) * ln / n
        for dz, y, d in ((-10, 30, 9), (9, 40, 6)):
            part(par, (0.4, d, d), m @ cf(0.1, y, z + dz), dot, shape="Cyl")


def wall_theme(i):
    c = TABLE_COLORS[min(i, N - 1)]
    return mix(c, (0, 0, 0), 0.18), mix(c, WHITE, 0.45), "Smooth", c, mix(c, WHITE, 0.8)


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
            club_wall(walls, (sx * 48, z0 - (2 if i == 0 else 0)), (sx * 48, z0 + ZL), (-sx, 0), wood_w, panel, pmat, trim_w, art, i == 0)
    part(long, (TW + 2 * RAIL_W, RAIL_H + 1.4, 1), cf(0, 1.6 + (RAIL_H + 1.4) / 2, TSZ - 0.5), THEMES[0]["t"][1], "Wood")  # head cushion
    far = TSZ + (N + EXTRA) * ZL
    part(walls, (100, 300, 2), cf(0, 150, far + 1), WHITE, Transparency=1, name="Wall")  # far end, deep in the haze


# ---------- Player base: only the billiard table; the gym and the cue shop stand in front of it ----------
RUG_W, RUG_D, ENTRANCE = 88, 110, 22


def player_base(world, i, o, col, rug):
    b = Inst("Model", f"Base{i + 1}", world)
    stage = Inst("Model", "Stage", b)  # Blender octagonal stage; part twin = collisions + fallback
    pivot(stage, o, "BasePlatform", Rim=col)
    ycyl(stage, 62, 1.2, o @ cf(0, 0.6, 0), col)
    ycyl(stage, 60, 0.16, o @ cf(0, 1.29, 0), (236, 214, 178), "Planks", name="Floor")
    part(stage, (15, 0.7, 2.6), o @ cf(0, 0.35, 31.6), col)
    top = o @ cf(0, 1.37, 0)
    pool_table(b, top)
    slots = Inst("Folder", "Slots", b)
    for s_ in range(SLOTS):  # invisible markers: the brass spots are part of the stage mesh
        a = math.radians(-150 + s_ * 300 / (SLOTS - 1))
        part(slots, (1, 0.2, 1), top @ cf(math.sin(a) * 12, 0.1, -math.cos(a) * 12), WHITE, Transparency=1, CanCollide=False, name=f"Slot{s_ + 1}")
    part(b, (1, 1, 1), top @ cf(0, 17, -4), WHITE, Transparency=1, CanCollide=False, name="AvatarAnchor")  # owner photo floats here
    part(b, (2, 0.2, 2), top @ cf(0, 0.1, 24), WHITE, Transparency=1, CanCollide=False, name="RevealSpot")
    part(b, (4, 1, 4), top @ cf(0, 0.5, 23), WHITE, Transparency=1, CanCollide=False, name="SpawnPoint")
    Inst("Folder", "Chars", b)
    gym_station(b, o @ cf(-17, 0, 41))
    cue_shop(b, o @ cf(17, 0, 41), col)
    # velvet rope around the rug, open towards the hall
    fences = Inst("Folder", "Fences", b)
    x0, x1, z0, z1 = rug
    corners = [(x0 + 1, z1 - 1), (x0 + 1, z0 + 1), (x1 - 1, z0 + 1), (x1 - 1, z1 - 1)]
    cx = (x0 + x1) / 2
    for a, b_ in zip(corners, corners[1:]):
        fence(fences, a, b_)
    fence(fences, corners[3], (cx + ENTRANCE / 2, z1 - 1))
    fence(fences, (cx - ENTRANCE / 2, z1 - 1), corners[0])
    for x, z in corners + [(cx - ENTRANCE / 2, z1 - 1), (cx + ENTRANCE / 2, z1 - 1)]:
        post(fences, x, z)


def gym_station(b, o):
    """Clean gym corner: rubber floor, bench + dumbbell rack, the upgradeable dumbbell, training spot, upgrade ring."""
    g = Inst("Model", "Gym", b)
    part(g, (15, 0.2, 11), o @ cf(0, 0.1, 0), (205, 205, 212), name="FloorEdge")
    part(g, (14.4, 0.24, 10.4), o @ cf(0, 0.12, 0), (46, 46, 54), "Concrete", name="Floor")
    sets = Inst("Model", "GymSet", g)
    pivot(sets, o @ cf(3.6, 0.24, -1.8), "GymSet")
    part(sets, (1.5, 1.9, 4.6), o @ cf(3.6, 1.2, -1.8), (32, 32, 38))
    part(sets, (1.6, 3.2, 4.8), o @ cf(-0.9, 1.84, -1.8), (70, 74, 84), "Metal")
    spot = part(g, (3, 0.06, 3), o @ cf(-4.2, 0.27, 0.2), (255, 255, 255), Transparency=0.6, CanCollide=False, name="TrainSpot", shape="Cyl")
    spot.p["cf"] = spot.p["cf"] @ rz(math.pi / 2)
    spot.p["size"] = (0.06, 3, 3)
    prompt(spot, "Start training", "Dumbbell")
    dumbbell(g, o @ cf(-4.2, 0.24 + 1.15, 2.6))
    label(part(g, (3, 0.05, 1), o @ cf(-4.2, 0.26, -1.9), WHITE, Transparency=1, CanCollide=False), FACE["Top"], "TRAIN", pps=30)
    ring = part(g, (4, 0.3, 4), o @ cf(3.4, 0.4, 3.0), (255, 200, 60), "Smooth", Transparency=1, CanCollide=False, name="UpgradeRingVisual")
    tag_mesh(ring, "Ring", scale=1, Ring=(255, 200, 60))
    hit = part(g, (2.5, 4.4, 4.4), o @ cf(3.4, 1.4, 3.0) @ rz(math.pi / 2), WHITE, shape="Cyl", Transparency=1, CanCollide=False, name="UpgradeRing")
    hit.p["CanTouch"] = True
    label(part(g, (3.6, 0.05, 1), o @ cf(3.4, 0.27, 3.0), WHITE, Transparency=1, CanCollide=False), FACE["Top"], "UPGRADE", (255, 220, 120), pps=30)


def cue_shop(b, o, col):
    """Blender kiosk (counter, felt back panel, curved canopy, sign) + the counter part that holds the prompt."""
    m = Inst("Model", "Kiosk", b)
    pivot(m, o, "CueShop", Accent=col)
    part(m, (12.4, 0.5, 8.4), o @ cf(0, 0.25, -0.6), (92, 50, 24), "Wood")
    part(m, (11, 8.2, 0.8), o @ cf(0, 4.6, -3.6), (92, 50, 24), "Wood")
    for sx in (-1, 1): ycyl(m, 0.55, 9.9, o @ cf(sx * 5.6, 5.2, 3.2), (92, 50, 24), "Wood")
    shop = part(b, (10, 3.2, 2.6), o @ cf(0, 2.1, 1.3), (92, 50, 24), "Wood", name="CueShop")  # counter: prompt lives here
    prompt(shop, "Open", "Cue Shop")
    label(part(m, (8, 1.8, 0.1), o @ cf(0, 12.6, 3.55), WHITE, Transparency=1, CanCollide=False), FACE["Back"], "CUE SHOP")
    light(part(m, (0.4, 0.4, 0.4), o @ cf(0, 9.6, 0.8), WHITE, Transparency=1, CanCollide=False), (255, 228, 180), 18, 2)


def tiles(par, x0, x1, z0, z1, top, thick, color, mat, name="Floor", step=512):
    """Floor made of tiles no larger than `step` (Roblox clamps any part axis to 2048)."""
    nx, nz = max(1, math.ceil((x1 - x0) / step)), max(1, math.ceil((z1 - z0) / step))
    w, d = (x1 - x0) / nx, (z1 - z0) / nz
    for i in range(nx):
        for k in range(nz):
            part(par, (w, thick, d), cf(x0 + (i + 0.5) * w, top - thick / 2, z0 + (k + 0.5) * d), color, mat, name=name)


WALNUT, RUNNER = (92, 56, 34), (32, 84, 54)


def build():
    ws = Inst("Workspace", "Workspace")
    world = Inst("Folder", "World", ws)
    env = Inst("Folder", "Environment", world)
    far = TSZ + (N + EXTRA) * ZL

    # floor: big bright checker tiles in the hall, striped runners in each table's colour along the corridor
    for gx in range(-230, 230, 20):
        for gz in range(-92, 78, 20):
            light_tile = ((gx + gz) // 20) % 2 == 0
            part(env, (20, 2, 20), cf(gx + 10, -1, gz + 10), (255, 246, 222) if light_tile else (255, 222, 170), name="Floor")
    tiles(env, -50, 50, 78, far + 4, 0, 2, (255, 236, 200), "Smooth")
    tiles(env, -46, 46, 48, 78, 0.06, 0.12, (255, 200, 60), "Fabric", name="Aisle")  # sunny carpet to the table
    for x in (-47, 47):
        tiles(env, x - 1, x + 1, 48, 78, 0.08, 0.16, WHITE, "Smooth", name="AisleEdge")
    for i_ in range(N + EXTRA):
        c = TABLE_COLORS[min(i_, N - 1)]
        z0 = TSZ + i_ * ZL
        for sx in (-1, 1):
            xc = sx * (TW / 2 + RAIL_W + 12.5)
            for k in range(8):  # alternating stripes, 10 studs each
                part(env, (24, 0.12, 10), cf(xc, 0.06, z0 + 5 + k * 10), mix(c, WHITE, 0.55) if k % 2 == 0 else WHITE, name="Runner")

    long_table(world)

    # start area: closed on every side by the same club walls
    hall = Inst("Folder", "HallWalls", world)
    wood, panel, pmat, trim, art = wall_theme(0)
    for a, b_, inward in (((-225, -88), (225, -88), (0, 1)), ((-225, -88), (-225, 78), (1, 0)), ((225, -88), (225, 78), (-1, 0)),
                          ((-225, 78), (-48, 78), (0, -1)), ((48, 78), (225, 78), (0, -1))):
        club_wall(hall, a, b_, inward, wood, panel, pmat, trim, art)

    bcol = [(255, 110, 120), (110, 170, 255), (110, 225, 140), (255, 190, 80)]
    for i in range(4):
        x = (i - 1.5) * 105
        part(world, (RUG_W + 5, 0.14, RUG_D + 5), cf(x, 0.07, -6), WHITE, name="RugBorder")  # each base sits on its own bright rug
        part(world, (RUG_W, 0.16, RUG_D), cf(x, 0.09, -6), mix(bcol[i], WHITE, 0.25), "Fabric", name="Rug")
        player_base(world, i, cf(x, 0.17, -20), bcol[i], (x - RUG_W / 2, x + RUG_W / 2, -6 - RUG_D / 2, -6 + RUG_D / 2))
    part(world, (6, 1, 6), cf(0, 0.6, 66), WHITE, cls="SpawnLocation", name="Spawn", Transparency=1, CanCollide=False, Neutral=True)
    return ws

# ---------- Layout check: nothing may intersect or block anything else ----------
def aabb(node):
    """World-space XZ bounds (x0, x1, z0, z1) of every part under node (rotation-aware)."""
    xs, zs = [], []
    def walk(n):
        if "cf" in n.p:
            m, (sx, sy, sz) = n.p["cf"], n.p["size"]
            for cx in (-sx / 2, sx / 2):
                for cz in (-sz / 2, sz / 2):
                    w = m @ np.array([cx, 0, cz, 1])
                    xs.append(w[0]); zs.append(w[2])
        for k in n.kids: walk(k)
    walk(node)
    return (min(xs), max(xs), min(zs), max(zs)) if xs else None


def overlap(a, b, gap=0):
    return a[0] < b[1] + gap and b[0] < a[1] + gap and a[2] < b[3] + gap and b[2] < a[3] + gap


def check_layout(ws):
    world = next(k for k in ws.kids if k.name == "World")
    kid = lambda n, name: next((k for k in n.kids if k.name == name), None)
    rugs = [k for k in world.kids if k.name == "Rug"]
    errs = []
    for a in range(len(rugs)):
        for b_ in range(a + 1, len(rugs)):
            if overlap(aabb(rugs[a]), aabb(rugs[b_]), 2):
                errs.append(f"rugs {a + 1} and {b_ + 1} touch")
    hall = (-225 + 5, 225 - 5, -88 + 5, 78 - 5)  # inside the walls, clear of the candy columns
    for i in range(1, 5):
        base = kid(world, f"Base{i}")
        centre = kid(kid(base, "PoolTable"), "MeshPivot").p["cf"][:3, 3]
        groups = {
            "stage": [kid(base, "Stage"), kid(base, "PoolTable")],
            "gym": [kid(base, "Gym")],
            "shop": [kid(base, "Kiosk"), kid(base, "CueShop")],
        }
        boxes = {}
        for g, nodes in groups.items():
            bs = [aabb(n) for n in nodes if n is not None]
            boxes[g] = (min(b[0] for b in bs), max(b[1] for b in bs), min(b[2] for b in bs), max(b[3] for b in bs))
        rug = min(rugs, key=lambda r: abs(r.p["cf"][0, 3] - centre[0]))
        rb = aabb(rug)
        for g, bx in boxes.items():
            if not (rb[0] <= bx[0] and bx[1] <= rb[1] and rb[2] <= bx[2] and bx[3] <= rb[3]):
                errs.append(f"base {i}: {g} sticks out of its rug")
            if not (hall[0] <= bx[0] and bx[1] <= hall[1] and hall[2] <= bx[2] and bx[3] <= hall[3]):
                errs.append(f"base {i}: {g} touches the hall walls")
        for g1, g2 in (("gym", "shop"), ("stage", "gym"), ("stage", "shop")):
            if overlap(boxes[g1], boxes[g2], 2):
                errs.append(f"base {i}: {g1} and {g2} are closer than 2 studs")
        slots = [s.p["cf"][:3, 3] for s in kid(base, "Slots").kids]
        for a in range(len(slots)):
            if np.linalg.norm((slots[a] - centre)[[0, 2]]) < 10:
                errs.append(f"base {i}: slot {a + 1} is too close to the table")
            for b_ in range(a + 1, len(slots)):
                if np.linalg.norm((slots[a] - slots[b_])[[0, 2]]) < 5:
                    errs.append(f"base {i}: slots {a + 1} and {b_ + 1} overlap")
        gym = kid(base, "Gym")
        prompts = [kid(gym, "TrainSpot").p["cf"][:3, 3], kid(base, "CueShop").p["cf"][:3, 3]]
        ring = kid(gym, "UpgradeRing").p["cf"][:3, 3]
        if np.linalg.norm((ring - prompts[0])[[0, 2]]) < 5:
            errs.append(f"base {i}: upgrade ring overlaps the training spot")
        fences = [f for f in kid(base, "Fences").kids if f.name == "FenceCollider"]
        for f in fences:
            fb = aabb(f)
            for g, bx in boxes.items():
                if overlap(fb, bx, 1):
                    errs.append(f"base {i}: fence touches the {g}")
        front = sorted((aabb(f) for f in fences if abs(f.p["cf"][2, 3] - rb[3]) < 3), key=lambda b: b[0])
        if len(front) != 2 or front[1][0] - front[0][1] < ENTRANCE - 1:
            errs.append(f"base {i}: the entrance is blocked")
        if np.linalg.norm(prompts[0] - prompts[1]) < 10:
            errs.append(f"base {i}: gym and shop prompts are too close")
        spawn = kid(base, "SpawnPoint").p["cf"][:3, 3]
        reveal = kid(base, "RevealSpot").p["cf"][:3, 3]
        for name, pt in (("spawn", spawn), ("reveal spot", reveal)):
            if min(np.linalg.norm((pt - s)[[0, 2]]) for s in slots) < 4:
                errs.append(f"base {i}: {name} stands on a character slot")
    assert not errs, "layout problems:\n  " + "\n  ".join(errs)
    return True


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
                f'<bool name="CanTouch">{str(p.get("CanTouch", True)).lower()}</bool>',
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
    for n in ("Config", "MeshBuilder", "Avatars", "CueFx", "Rig"):
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
    for n in ("UI", "Throw", "Visuals", "Training"):
        Inst("LocalScript", n, cl, Source=src(f"src/client/{n}.client.luau"))
    lt = Inst("Lighting", "Lighting", ClockTime=13.2, Brightness=3.2, EnvironmentDiffuseScale=1, EnvironmentSpecularScale=0.6, OutdoorAmbient=(190, 185, 200), Ambient=(130, 125, 140))
    Inst("Sky", "Sky", lt)
    Inst("Atmosphere", "Atmosphere", lt, Density=0.34, Haze=1.2, Color=(235, 240, 255), Decay=(200, 215, 255))  # bright haze: the table end fades out
    Inst("BloomEffect", "Bloom", lt, Intensity=0.7, Size=28, Threshold=1.4)
    Inst("ColorCorrectionEffect", "Grade", lt, Saturation=0.32, Contrast=0.08, Brightness=0.03)
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
    check_layout(ws)
    data = '<roblox version="4">' + "".join(xml(s) for s in services(ws)) + "</roblox>"
    open(os.path.join(ROOT, "BilliardHunters.rbxlx"), "w", encoding="utf-8").write(data)
    print("parts:", dump_scene(ws, os.path.join(ROOT, "tools/scene.json")), "-> BilliardHunters.rbxlx")
