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
HALL_X, HALL_BACK, CORR_X = (float(v) for v in re.search(r"HallHalfWidth = (\d+), HallBack = (-?\d+), CorridorHalfWidth = (\d+)", cfg).groups())
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


def dumbbell(par, o):
    p = part(par, (5.2, 2.3, 2.3), o, (70, 70, 78), "Metal", "Cyl", name="Dumbbell", CanCollide=False)
    return tag_mesh(p, "Dumbbell", scale=1, Plate=(70, 70, 78))

def fence(par, a, b):
    """Wooden fence from a to b (x, z): Blender segments stretched to fit, a part twin and an invisible collider."""
    (x0, z0), (x1, z1) = a, b
    ln = math.hypot(x1 - x0, z1 - z0)
    n = max(1, round(ln / 30))
    yaw = math.atan2(-(z1 - z0), x1 - x0)
    for k in range(n):
        t = (k + 0.5) / n
        o = cf(x0 + (x1 - x0) * t, FLOOR_TOP, z0 + (z1 - z0) * t) @ ry(yaw)
        m = Inst("Model", "Fence", par)
        pivot(m, o, "Fence", vscale=(ln / n / 30, 1, 1))
        for y in (1.2, 2.6):
            part(m, (ln / n, 0.42, 0.28), o @ cf(0, y, 0.38), (150, 96, 52), "Wood", CanCollide=False)
    part(par, (ln, 5, 0.8), cf((x0 + x1) / 2, FLOOR_TOP + 2.5, (z0 + z1) / 2) @ ry(yaw), WHITE, Transparency=1, name="FenceCollider")


def post(par, x, z):  # corner / gate post
    m = Inst("Model", "Post", par)
    part(m, (0.9, 4, 0.9), cf(x, FLOOR_TOP + 2, z), (104, 64, 34), "Wood")
    part(m, (1.1, 0.3, 1.1), cf(x, FLOOR_TOP + 4.1, z), (90, 54, 28), "Wood")


def mix(c, d, f):
    return tuple(int(a * (1 - f) + b * f) for a, b in zip(c, d))


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


# ---------- The long table: 50 Blender table segments, each in its own colours ----------
RAIL_W, RAIL_H = 3, 4.2


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
    part(long, (TW + 2 * RAIL_W, RAIL_H + 1.4, 1), cf(0, 1.6 + (RAIL_H + 1.4) / 2, TSZ - 0.5), THEMES[0]["t"][1], "Wood")  # head cushion
    far = TSZ + (N + EXTRA) * ZL
    for sx in (-1, 1):  # invisible side walls; the Terrain mountains (Map.luau) stand behind them
        z = 78
        while z < far:
            ln = min(2000, far - z)
            part(walls, (2, 300, ln), cf(sx * (CORR_X + 1), 150, z + ln / 2), WHITE, Transparency=1, name="Wall")
            z += ln
    part(walls, (2 * CORR_X, 300, 2), cf(0, 150, far + 1), WHITE, Transparency=1, name="Wall")  # far end, deep in the haze


# ---------- Player base: only the billiard table; the gym and the cue shop stand in front of it ----------
# ---------- Player base: wooden deck with a fence, the pool table in the middle, gym + cue kiosk inside ----------
BASE_W, BASE_D, ENTRANCE, FLOOR_TOP, BASE_GAP = 46, 50, 10, 0.5, 58
SLOT_GRID = [(sx * 1.5, z) for z in (-4.5, -1.5, 1.5, 4.5) for sx in (-1, 1)]  # prize ball spots on the felt (table space)


def player_base(world, i, o):
    b = Inst("Model", f"Base{i + 1}", world)
    deck = Inst("Model", "Deck", b)
    part(deck, (BASE_W, FLOOR_TOP, BASE_D), o @ cf(0, FLOOR_TOP / 2, 0), (168, 116, 72), "Planks", name="Floor")
    part(deck, (BASE_W + 1, FLOOR_TOP - 0.1, BASE_D + 1), o @ cf(0, (FLOOR_TOP - 0.1) / 2, 0), (112, 74, 44), "Wood", name="FloorEdge")
    table_o = o @ cf(0, FLOOR_TOP, -8)
    pool_table(b, table_o)
    slots = Inst("Folder", "Slots", b)
    for k, (x, z) in enumerate(SLOT_GRID):  # invisible markers on the felt (felt top = 3)
        part(slots, (1, 0.1, 1), table_o @ cf(x, 3.05, z), WHITE, Transparency=1, CanCollide=False, name=f"Slot{k + 1}")
    part(b, (1, 1, 1), table_o @ cf(0, 15, -2), WHITE, Transparency=1, CanCollide=False, name="AvatarAnchor")  # owner photo floats here
    part(b, (4, 1, 4), o @ cf(0, FLOOR_TOP + 0.5, 18), WHITE, Transparency=1, CanCollide=False, name="SpawnPoint")
    Inst("Folder", "Chars", b)
    gym_station(b, o @ cf(-13.5, FLOOR_TOP, 14))
    cue_shop(b, o @ cf(14, FLOOR_TOP, 14.5))
    fences = Inst("Folder", "Fences", b)
    hw, hd = BASE_W / 2 - 0.6, BASE_D / 2 - 0.6
    corners = [(-hw, hd), (-hw, -hd), (hw, -hd), (hw, hd)]
    wc = lambda x, z: tuple((o @ np.array([x, 0, z, 1]))[[0, 2]])
    for a, b_ in zip(corners, corners[1:]):
        fence(fences, wc(*a), wc(*b_))
    fence(fences, wc(hw, hd), wc(ENTRANCE / 2, hd))
    fence(fences, wc(-ENTRANCE / 2, hd), wc(-hw, hd))
    for x, z in corners + [(-ENTRANCE / 2, hd), (ENTRANCE / 2, hd)]:
        post(fences, *wc(x, z))


def gym_station(b, o):
    """Gym corner: rubber mat, bench + dumbbell rack, the upgradeable dumbbell, training spot, green upgrade circle."""
    g = Inst("Model", "Gym", b)
    part(g, (14.4, 0.12, 10.4), o @ cf(0, 0.06, 0), (52, 54, 60), "Concrete", name="Mat")
    sets = Inst("Model", "GymSet", g)
    pivot(sets, o @ cf(3.6, 0.12, -1.8), "GymSet")
    part(sets, (1.5, 1.9, 4.6), o @ cf(3.6, 1.1, -1.8), (32, 32, 38))
    part(sets, (1.6, 3.2, 4.8), o @ cf(-0.9, 1.72, -1.8), (70, 74, 84), "Metal")
    spot = part(g, (0.06, 3, 3), o @ cf(-4.2, 0.15, 0.2) @ rz(math.pi / 2), (255, 255, 255), Transparency=0.6, CanCollide=False, name="TrainSpot", shape="Cyl")
    prompt(spot, "Start training", "Dumbbell")
    dumbbell(g, o @ cf(-4.2, 0.12 + 1.15, 2.6))
    label(part(g, (3, 0.05, 1), o @ cf(-4.2, 0.14, -1.9), WHITE, Transparency=1, CanCollide=False), FACE["Top"], "TRAIN", pps=30)
    ring = part(g, (4, 0.2, 4), o @ cf(3.4, 0.3, 3.0), (60, 220, 90), Transparency=1, CanCollide=False, name="UpgradeRingVisual")
    tag_mesh(ring, "Ring", scale=1, Ring=(60, 220, 90))
    Inst("StringValue", "Pulse", ring, Value="green")  # client: pulsing glow disc + slow spin
    hit = part(g, (2.5, 4.4, 4.4), o @ cf(3.4, 1.4, 3.0) @ rz(math.pi / 2), WHITE, shape="Cyl", Transparency=1, CanCollide=False, name="UpgradeRing")
    hit.p["CanTouch"] = True
    label(part(g, (3.6, 0.05, 1), o @ cf(3.4, 0.16, 3.0), WHITE, Transparency=1, CanCollide=False), FACE["Top"], "UPGRADE", (120, 255, 140), pps=30)


def cue_shop(b, o):
    """Blender kiosk (counter, felt back panel, curved canopy, sign) + the counter part that holds the prompt."""
    col = (220, 70, 60)
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


GRASS, GRASS2 = (96, 166, 78), (88, 156, 72)


def build():
    ws = Inst("Workspace", "Workspace")
    world = Inst("Folder", "World", ws)
    env = Inst("Folder", "Environment", world)
    far = TSZ + (N + EXTRA) * ZL
    # grass everywhere (soft two-tone stripes, no glare); Terrain block mountains close the area (Map.luau)
    for k, z in enumerate(range(int(HALL_BACK), 78, 20)):
        part(env, (2 * HALL_X, 2, 20), cf(0, -1, z + 10), GRASS if k % 2 == 0 else GRASS2, "Grass", name="Floor")
    tiles(env, -CORR_X, CORR_X, 78, far + 4, 0, 2, GRASS, "Grass")
    long_table(world)
    hall = Inst("Folder", "HallWalls", world)  # invisible: the mountains are the visible border
    for size, pos in (((2 * HALL_X, 300, 2), (0, 150, HALL_BACK - 1)), ((2, 300, 78 - HALL_BACK), (-HALL_X - 1, 150, (78 + HALL_BACK) / 2)),
                      ((2, 300, 78 - HALL_BACK), (HALL_X + 1, 150, (78 + HALL_BACK) / 2)),
                      ((HALL_X - CORR_X, 300, 2), (-(HALL_X + CORR_X) / 2, 150, 79)), ((HALL_X - CORR_X, 300, 2), ((HALL_X + CORR_X) / 2, 150, 79))):
        part(hall, size, cf(*pos), WHITE, Transparency=1, name="Wall")
    for i in range(4):
        player_base(world, i, cf((i - 1.5) * BASE_GAP, 0, -24))
    part(world, (6, 1, 6), cf(0, 0.6, 60), WHITE, cls="SpawnLocation", name="Spawn", Transparency=1, CanCollide=False, Neutral=True)
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
    errs = []
    hall = (-HALL_X, HALL_X, HALL_BACK, 78)
    decks = []
    for i in range(1, 5):
        base = kid(world, f"Base{i}")
        deck = aabb(kid(kid(base, "Deck"), "Floor"))
        decks.append(deck)
        if not (hall[0] + 4 <= deck[0] and deck[1] <= hall[1] - 4 and hall[2] + 4 <= deck[2] and deck[3] <= hall[3] - 4):
            errs.append(f"base {i}: deck touches the hall border")
        boxes = {g: aabb(kid(base, n)) for g, n in (("table", "PoolTable"), ("gym", "Gym"), ("shop", "Kiosk"))}
        boxes["shop"] = tuple(f(a, b) for f, a, b in zip((min, max, min, max), boxes["shop"], aabb(kid(base, "CueShop"))))
        for g, bx in boxes.items():
            if not (deck[0] + 1 <= bx[0] and bx[1] <= deck[1] - 1 and deck[2] + 1 <= bx[2] and bx[3] <= deck[3] - 1):
                errs.append(f"base {i}: {g} sticks out of the deck")
        for g1, g2 in (("gym", "shop"), ("table", "gym"), ("table", "shop")):
            if overlap(boxes[g1], boxes[g2], 2):
                errs.append(f"base {i}: {g1} and {g2} are closer than 2 studs")
        fences = [f for f in kid(base, "Fences").kids if f.name == "FenceCollider"]
        for f in fences:
            for g, bx in boxes.items():
                if overlap(aabb(f), bx, 0.5):
                    errs.append(f"base {i}: fence touches the {g}")
        front = sorted((aabb(f) for f in fences if abs(f.p["cf"][2, 3] - deck[3]) < 3), key=lambda b: b[0])
        if len(front) != 2 or front[1][0] - front[0][1] < ENTRANCE - 1:
            errs.append(f"base {i}: the entrance is blocked")
        gym = kid(base, "Gym")
        spot, ring = kid(gym, "TrainSpot").p["cf"][:3, 3], kid(gym, "UpgradeRing").p["cf"][:3, 3]
        if np.linalg.norm((ring - spot)[[0, 2]]) < 5:
            errs.append(f"base {i}: upgrade ring overlaps the training spot")
        spawn = kid(base, "SpawnPoint").p["cf"][:3, 3]
        for g, bx in boxes.items():
            if bx[0] - 2 < spawn[0] < bx[1] + 2 and bx[2] - 2 < spawn[2] < bx[3] + 2:
                errs.append(f"base {i}: spawn point is inside the {g}")
        if len(kid(base, "Slots").kids) != SLOTS:
            errs.append(f"base {i}: needs {SLOTS} ball spots")
    for a in range(4):
        for b_ in range(a + 1, 4):
            if overlap(decks[a], decks[b_], 6):
                errs.append(f"bases {a + 1} and {b_ + 1} are closer than 6 studs")
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
    for n in ("Config", "MeshBuilder", "CueFx", "Rig"):
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
    lt = Inst("Lighting", "Lighting", ClockTime=13.2, Brightness=2.6, EnvironmentDiffuseScale=1, EnvironmentSpecularScale=0.6, OutdoorAmbient=(190, 185, 200), Ambient=(130, 125, 140))
    Inst("Sky", "Sky", lt)
    Inst("Atmosphere", "Atmosphere", lt, Density=0.34, Haze=1.2, Color=(235, 240, 255), Decay=(200, 215, 255))  # bright haze: the table end fades out
    Inst("BloomEffect", "Bloom", lt, Intensity=0.25, Size=20, Threshold=2.2)  # soft: nothing glares
    Inst("ColorCorrectionEffect", "Grade", lt, Saturation=0.12, Contrast=0.05, Brightness=0)
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
