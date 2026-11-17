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
def tag_mesh(p, mesh, scale=None, **colors):
    Inst("StringValue", "Mesh", p, Value=mesh)
    if scale: Inst("NumberValue", "Scale", p, Value=scale)
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

# ---------- Карта ----------
def build():
    ws = Inst("Workspace", "Workspace")
    world = Inst("Folder", "World", ws)
    env = Inst("Folder", "Environment", world)

    # Земля: океан, пляж, трава, дорожки
    part(env, (3000, 2, 3200), cf(0, -4, 480), (40, 180, 230), "Glass", Transparency=0.15, Reflectance=0.2, CanCollide=False, name="Ocean")
    part(env, (2950, 1, 3150), cf(0, -8, 480), (20, 110, 170), "Sand", name="SeaFloor")
    part(env, (760, 4, 1220), cf(0, -2.4, 480), (245, 220, 160), "Sand", name="Beach")
    part(env, (700, 4, 1160), cf(0, -2, 480), (105, 205, 85), "Grass", name="Ground")
    part(env, (480, 0.4, 46), cf(0, 0.2, 52), (250, 228, 185), "Pebble", name="Plaza")
    for x in range(-230, 231, 10):
        part(env, (5, 0.42, 5), cf(x, 0.21, 52 + (5 if (x // 10) % 2 else -5)), WHITE, "Marble")
    for s in (-1, 1):  # дорожки вдоль стола
        part(env, (14, 0.3, TL + 40), cf(s * 42, 0.15, TSZ + TL / 2), (250, 228, 185), "Pebble")
    # клумбы с цветами
    for _ in range(140):
        s = rnd.choice((-1, 1))
        p = (s * rnd.uniform(52, 80), rnd.uniform(TSZ, END))
        ball(env, rnd.uniform(1, 1.8), cf(p[0], 0.4, p[1]), rnd.choice([(255, 90, 140), (255, 230, 60), (190, 110, 255), (255, 255, 255), (255, 150, 60)]), CanCollide=False)
    for _ in range(60):
        s = rnd.choice((-1, 1))
        ball(env, rnd.uniform(4, 7), cf(s * rnd.uniform(85, 110), 1, rnd.uniform(TSZ, END)), (70, 175, 70), "Grass")

    # Боковые зоны: пруды, радужные поля цветов, гигантские шары и кии
    deco = Inst("Folder", "Decor", world)
    for s in (-1, 1):
        for pz, pr in ((260, 45), (700, 55)):
            ycyl(deco, pr * 2 + 6, 0.5, cf(s * 210, 0.1, pz), (245, 220, 160), "Sand")
            ycyl(deco, pr * 2, 0.6, cf(s * 210, 0.15, pz), (60, 190, 240), "Glass", Transparency=0.1, Reflectance=0.25, name="Pond")
            for _ in range(8):
                a = rnd.uniform(0, 2 * math.pi); r = rnd.uniform(0, pr - 6)
                ycyl(deco, rnd.uniform(3, 5), 0.2, cf(s * 210 + math.cos(a) * r, 0.5, pz + math.sin(a) * r), (90, 200, 90))
            for k in range(14):  # камни по берегу
                a = k / 14 * 2 * math.pi
                ball(deco, rnd.uniform(3, 6), cf(s * 210 + math.cos(a) * (pr + 3), 0.3, pz + math.sin(a) * (pr + 3)), (200, 195, 185), "Rock")
        rain = [(255, 70, 90), (255, 150, 40), (255, 230, 60), (120, 220, 80), (70, 170, 255), (170, 100, 255)]
        for fz in (430, 870):  # поле цветов-радуга
            for k, c in enumerate(rain):
                for j in range(14):
                    ball(deco, 1.8, cf(s * (150 + k * 5), 0.6, fz + j * 4), c, CanCollide=False)
                    part(deco, (0.3, 1, 0.3), cf(s * (150 + k * 5), 0.3, fz + j * 4), (60, 160, 60))
        for k in range(5):  # гигантские шары
            d = rnd.uniform(14, 22)
            z = 160 + k * 180 + rnd.uniform(-30, 30)
            x = s * rnd.uniform(110, 290)
            if abs(abs(x) - 210) < 70 and (abs(z - 260) < 70 or abs(z - 700) < 80): x = s * 120
            b = cf(x, d / 2 - 0.5, z) @ ang(rnd.uniform(-0.5, 0.5), rnd.uniform(0, 6), rnd.uniform(-0.5, 0.5))
            mesh_ball(deco, d, b, BALLS[(k + (s > 0) * 3) % 7])
        for k in range(3):  # giant cues lying on the grass
            cue(deco, cf(s * 250, 1.5, 330 + k * 260) @ ry(rnd.uniform(-0.6, 0.6)) @ rx(math.pi / 2), BALLS[(k * 2 + (s > 0)) % 7], 3.3)

    # Длинный стол
    long = Inst("Model", "LongTable", world)
    mid = TSZ + TL / 2
    part(long, (TW + 8, 3, TL + 8), cf(0, 1.5, mid), WOOD, "Wood")
    for s in (-1, 1):
        part(long, (2.5, 2.2, TL + 8), cf(s * (TW / 2 + 2.75), 4.1, mid), DARK, "Wood")
        part(long, (0.6, 0.4, TL + 8), cf(s * (TW / 2 + 2.75), 5.3, mid), GOLD, "Neon")
    part(long, (TW + 8, 2.2, 2.5), cf(0, 4.1, END + 2.75), DARK, "Wood")
    for z in np.arange(TSZ, END + 1, 60):
        for s in (-1, 1): ycyl(long, 3, 1, cf(s * (TW / 2 + 1), 0.5, z), GOLD, "Metal")
    for l in range(1, int(LANES)):
        part(long, (0.3, 0.32, TL), cf(-TW / 2 + l * TW / LANES, 3.17, mid), WHITE, Transparency=0.5)
    for i in range(N):
        z0 = TSZ + i * ZL
        name, col = RAR[i]
        part(long, (TW, 0.3, ZL - 0.4), cf(0, 3.15, z0 + ZL / 2), tuple(int(c * 0.65 + d * 0.35) for c, d in zip(col, (20, 120, 60))), "Fabric", name=f"Zone{i + 1}")
        nf = Inst("Folder", f"Neon{i + 1}", long)
        for s in (-1, 1):
            part(nf, (1.6, 16, 1.6), cf(s * (TW / 2 + 5), 8, z0), col, "Neon")
            ball(nf, 3.5, cf(s * (TW / 2 + 5), 17, z0), col, "Neon")
            pc = cf(s * TW / 2, 3.32, z0 + ZL / 2)
            ycyl(long, 4.4, 0.2, pc, (5, 5, 5))
            ycyl(nf, 5.4, 0.15, pc @ cf(0, -0.05, 0), col, "Neon")
        beam = part(long, (TW + 12, 4, 1), cf(0, 17, z0), (40, 25, 60), name=f"Beam{i + 1}")
        part(nf, (TW + 12, 0.5, 1.2), cf(0, 15, z0), col, "Neon")
        light(beam, WHITE, 30, 1)
        label(beam, FACE["Front"], name, col, 20, "Rarity")
        label(beam, FACE["Back"], f"Zone {i + 1}", WHITE, 20)

    # Радужная арка и вывеска
    rain = [(255, 60, 60), (255, 150, 30), (255, 230, 40), (80, 220, 80), (50, 160, 255), (90, 80, 230), (190, 80, 255)]
    arch = Inst("Model", "RainbowArch", world)
    for b, col in enumerate(rain, 1):
        R = 40 - b * 1.6
        for k in range(25):
            a = math.pi * k / 24
            part(arch, (1.6, 1.6, 5.4), cf(math.cos(a) * R, math.sin(a) * R, TSZ - 8) @ rz(a) @ rx(math.pi / 2), col, "Neon", CanCollide=False)
    sign = part(arch, (50, 8, 1), cf(0, 26, TSZ - 8), (255, 110, 170))
    label(sign, FACE["Front"], "🎱 BILLIARD HUNTERS 🎱")

    # Шар «8» на пьедестале
    eight = Inst("Model", "EightBall", world)
    e = cf(0, 32, END + 40)
    ball(eight, 40, e, (15, 15, 20), "Glass", name="Ball", Reflectance=0.15)
    c = part(eight, (1, 18, 18), e @ cf(0, 0, -19.7) @ ry(math.pi / 2), WHITE, shape="Cyl", name="Circle", CanCollide=False)
    label(c, FACE["Right"], "8", (0, 0, 0), 10)
    ycyl(eight, 30, 10, cf(0, 5, END + 40), GOLD, "Metal", name="Pedestal")
    for k in range(1, 4):
        part(eight, (1, 50 + k * 8, 50 + k * 8), e @ ang(k, k * 0.7, 0), rain[k * 2 - 1], "ForceField", "Cyl", name=f"Ring{k}", CanCollide=False)

    # Фонтан
    fc = cf(0, 0, 30)
    fo = Inst("Model", "Fountain", world)
    ycyl(fo, 16, 2, fc @ cf(0, 1, 0), (240, 240, 250), "Marble")
    ycyl(fo, 14, 0.3, fc @ cf(0, 2.05, 0), (80, 200, 255), "Glass", Transparency=0.3)
    ycyl(fo, 4, 8, fc @ cf(0, 5, 0), (240, 240, 250), "Marble")
    ball(fo, 5, fc @ cf(0, 10, 0), (255, 230, 40), "Glass", name="Top")

    # Летающие шары
    fb = Inst("Folder", "FloatBalls", world)
    for k in range(24):
        s = 1 if k % 2 else -1
        mesh_ball(fb, rnd.uniform(8, 16), cf(s * rnd.uniform(130, 280), rnd.uniform(40, 80), rnd.uniform(120, END)), BALLS[k % 7], CanCollide=False)

    # Деревья
    trees = Inst("Folder", "Trees", world)
    for _ in range(170):
        s = rnd.choice((-1, 1))
        x, z = s * rnd.uniform(300, 318) if rnd.random() < 0.4 else s * rnd.uniform(100, 318), rnd.uniform(90, END + 60)
        tree(trees, (x, z), rnd.uniform(9, 15), "round")
    for _ in range(50):  # пальмы по пляжу
        a = rnd.uniform(0, 2 * math.pi)
        tree(trees, (math.cos(a) * 340, 480 + math.sin(a) * 570), rnd.uniform(14, 20), "palm")
    for x in range(-250, 251, 50):  # за базами
        tree(trees, (x + rnd.uniform(-8, 8), -95), rnd.uniform(12, 16), "palm")

    # Фонари вдоль стола
    lamps = Inst("Folder", "Lamps", world)
    for z in np.arange(TSZ + 20, END, 50):
        for s in (-1, 1):
            ycyl(lamps, 1, 14, cf(s * 36, 7, z), (60, 60, 70), "Metal")
            light(ball(lamps, 2.5, cf(s * 36, 15, z), (255, 240, 180), "Neon"), (255, 230, 170), 30)

    # Ограждение по периметру
    wall = Inst("Model", "Barrier", world)
    X0, Z0, Z1 = 330, -110, END + 75
    for m, ln in ((cf(-X0, 0, (Z0 + Z1) / 2), Z1 - Z0), (cf(X0, 0, (Z0 + Z1) / 2), Z1 - Z0),
                  (cf(0, 0, Z0) @ ry(math.pi / 2), 2 * X0), (cf(0, 0, Z1) @ ry(math.pi / 2), 2 * X0)):
        part(wall, (4, 7, ln), m @ cf(0, 3.5, 0), (235, 225, 210), "Cobble")
        part(wall, (4.6, 0.8, ln), m @ cf(0, 7.2, 0), (255, 120, 200), "Neon")
        part(wall, (0.4, 40, ln), m @ cf(0, 27, 0), (150, 200, 255), "ForceField", Transparency=0.3, CanCollide=False, CastShadow=False)
        part(wall, (2, 400, ln), m @ cf(0, 200, 0), WHITE, Transparency=1, name="Invisible")
        n = int(ln // 40)
        for k in range(n + 1):
            pc = m @ cf(0, 0, -ln / 2 + k * ln / n)
            part(wall, (6, 11, 6), pc @ cf(0, 5.5, 0), (250, 240, 225), "Cobble")
            light(ball(wall, 4, pc @ cf(0, 13, 0), BALLS[k % 7], "Neon"), BALLS[k % 7], 25)

    # Горы за стеной
    hills = Inst("Folder", "Mountains", world)
    for _ in range(46):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(60, 110)
        x, z = math.cos(a) * 520, 480 + math.sin(a) * 760
        ball(hills, r * 2, cf(x, -r * 0.35, z), rnd.choice([(120, 170, 110), (100, 150, 100), (140, 130, 120)]), "Rock")
        ball(hills, r * 0.9, cf(x, r * 0.55, z), WHITE, "Snow")

    # 4 базы
    bcol = [(255, 120, 120), (120, 180, 255), (120, 230, 140), (255, 200, 90)]
    for i in range(4):
        o = cf((i - 1.5) * 110, 0, -10)
        col = bcol[i]
        b = Inst("Model", f"Base{i + 1}", world)
        part(b, (90, 1, 90), o @ cf(0, 0.5, 0), (255, 235, 200), "Planks", name="Floor")
        part(b, (92, 0.8, 92), o @ cf(0, 0.3, 0), col)
        for tx in range(9):
            for tz in range(9):
                if (tx + tz) % 2: part(b, (10, 0.1, 10), o @ cf(-40 + tx * 10, 1.03, -40 + tz * 10), tuple(int(c * 0.35 + 255 * 0.65) for c in col))
        ycyl(b, 34, 0.4, o @ cf(0, 1.15, 0), (170, 40, 60), "Fabric")
        ycyl(b, 36, 0.3, o @ cf(0, 1.05, 0), GOLD, "Metal")
        for k in range(4):  # флаги по углам
            fx, fz = (-43, 43)[k % 2], (-43, 43)[k // 2]
            ycyl(b, 0.5, 18, o @ cf(fx, 9, fz), WHITE, "Metal")
            part(b, (0.2, 4, 6), o @ cf(fx, 16, fz + (3 if fz < 0 else -3)), col)
        pool_table(b, o)
        table_lamp(b, o)
        for fx, fz, fr, offs in ((0, -45, 0, (-30, 0, 30)), (0, 45, math.pi, (-30, 30)), (-45, 0, math.pi / 2, (-30, 0, 30)), (45, 0, -math.pi / 2, (-30, 0, 30))):
            for off in offs: fence(b, o @ cf(fx, 1, fz) @ ry(fr) @ cf(off, 0, 0), col)
        for s in (-1, 1):
            ycyl(b, 2.4, 12, o @ cf(s * 15, 6, 45), col)
            light(ball(b, 3, o @ cf(s * 15, 13, 45), col, "Neon"), col, 20)
        dumbbell(b, o @ cf(-30, 1.3, 25))
        prompt(part(b, (6, 3, 3), o @ cf(-30, 2, 25), WHITE, Transparency=1, CanCollide=False, name="DumbbellHit"), "Lift", "Dumbbell")
        part(b, (2, 0.1, 2), o @ cf(-30, 1.06, 25), col, "Neon")
        shop = part(b, (10, 4, 4), o @ cf(30, 3, 25), (120, 200, 255), name="CueShop")
        for k in range(6): part(b, (2, 0.6, 6), o @ cf(25 + k * 2, 10, 25), (255, 90, 90) if k % 2 == 0 else WHITE)
        for s in (-5, 5): part(b, (0.6, 6, 0.6), o @ cf(30 + s, 7, 25), WHITE)
        label(shop, FACE["Back"], "🎱 CUES")
        prompt(shop, "Open", "Cue Shop")
        for k, cc in enumerate(((230, 190, 120), (255, 200, 40), (140, 240, 255)), 1):
            cue(b, o @ cf(27 + k * 1.5, 5 + 4.6, 23.6) @ rz(math.radians(8 - k * 4)), cc)
        sp = part(b, (24, 5, 1), o @ cf(0, 16, 45), col, name="Sign")
        label(sp, FACE["Back"], "Free Base")
        part(b, (32, 1, 1), o @ cf(0, 12, 45), col)
        slots = Inst("Folder", "Slots", b)
        for s in range(SLOTS):
            a = math.radians(-150 + s * 300 / (SLOTS - 1))
            p = o[:3, 3] + np.array([math.sin(a) * 18, 0, -math.cos(a) * 18])
            ycyl(slots, 5, 0.6, cf(p[0], 1.3, p[2]), WHITE, "Marble", name=f"Slot{s + 1}")
            ycyl(b, 5.4, 0.2, cf(p[0], 1.1, p[2]), col, "Neon")
        Inst("Folder", "Chars", b)
    part(world, (6, 1, 6), cf(0, 0.6, 52), WHITE, cls="SpawnLocation", name="Spawn", Transparency=1, CanCollide=False, Neutral=True)
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

def dump_scene(ws, path):  # плоский список деталей для превью в Blender
    out = []
    def walk(i):
        if "cf" in i.p and i.p.get("Transparency", 0) < 1:
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
