"""World.TableHall for the Studio place: walls, ceiling and lamps along the long table + themed props on the rails,
and the New Year set on table 21. Meshes come from Blender (HallWall, HallCeiling, Deco*); every piece has a
part-built fallback, so the hall also works without EditableMesh. Used by tools/studio.py pack."""
import math, os, re
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CFG = open(os.path.join(ROOT, "studio", "src", "Config.luau"), encoding="utf-8").read()
TABLES = re.findall(r'\{ "([^"]+)", Color3\.fromHex\("([0-9a-f]{6})"\) \}', CFG)
START_Z, SEG = 80, 80
RAIL_X, RAIL_TOP = 15.17, 4.53
NEW_YEAR = 21

# props per theme: first keyword that appears in the table name wins (Deco* rail props + the Blender theme kit
# from blender/themes.py: Wall/Backdrop/Ceiling/Hero/Mid/Rail/Hang<Theme>)
KITS = [
    (("new year",), ["DecoTree", "DecoGift", "DecoSnowman", "DecoCandyCane"], "NewYear"),
    (("apple", "orchard", "acorn", "maple", "grove", "blossom"), ["DecoMushroom", "DecoLantern"], "Orchard"),
    (("candy", "waffle", "macaron", "sugar"), ["DecoCandyCane", "DecoGift"], "Candy"),
    (("coral", "pearl", "seahorse", "jellyfish", "reef", "lagoon", "nautilus", "tidal"), ["DecoShell", "DecoCrystal"], "Reef"),
    (("saguaro", "joshua", "agave", "mesa", "dunes", "sandstone", "sun arch"), ["DecoCactus", "DecoTorch"], "Desert"),
    (("frost", "ice", "glacier", "polar", "aurora"), ["DecoCrystal", "DecoSnowman"], "Ice"),
    (("ember", "obsidian", "magma", "firebird", "solar", "forge"), ["DecoTorch", "DecoCrystal"], "Fire"),
    (("bamboo", "koi", "tea", "bonsai", "jade", "lantern", "pagoda"), ["DecoLantern", "DecoLotus"], "Zen"),
    (("crater", "meteor", "comet", "lunar", "orbital", "saturn", "nebula", "galaxy", "saucer", "eclipse", "astral"), ["DecoPlanet", "DecoCrystal"], "Space"),
    (("brass", "pendulum", "copper", "chronometer", "clock", "windmill"), ["DecoGear", "DecoTrophy"], "Clock"),
    (("lotus", "waterlily", "dragonfly", "bloom", "rain"), ["DecoLotus", "DecoMushroom"], "Garden"),
    (("pixel", "joystick", "hologram", "synthwave", "prism"), ["DecoCrystal", "DecoGear"], "Pixel"),
    (("cloud", "storm", "thunder", "tempest", "kites", "sail"), ["DecoLantern", "DecoPlanet"], "Sky"),
    (("royal", "sapphire", "ruby", "opal", "crown", "gallery", "bastion"), ["DecoTrophy", "DecoCrystal"], "Royal"),
    (("canal", "wharf", "beacon", "loft", "harbour"), ["DecoLantern", "DecoShell"], "Harbour"),
]
DEFAULT_KIT = (["DecoTrophy", "DecoPalm"], "Club")


def kit(name):
    """(Deco rail props, Blender theme) for a table name."""
    low = name.lower()
    for words, deco, theme in KITS:
        if any(w in low for w in words):
            return deco, theme
    return DEFAULT_KIT


# ---------- tiny rbxlx writer ----------
ref = iter(range(10 ** 7))


class I:
    def __init__(s, cls, name, parent=None, **p):
        s.cls, s.name, s.p, s.kids = cls, name, p, []
        if parent is not None:
            parent.kids.append(s)


def cf(x, y, z, yaw=0.0):
    c, s = math.cos(yaw), math.sin(yaw)
    return (x, y, z, c, 0, s, 0, 1, 0, -s, 0, c)


MAT = dict(Smooth=272, Wood=512, Planks=528, Marble=784, Metal=1088, Fabric=1312, Neon=288, Glass=1568)


def part(parent, size, at, color, mat="Smooth", name="Part", shape=1, transparency=0, collide=False):
    return I("Part", name, parent, size=size, cf=at, color=color, mat=mat, shape=shape, t=transparency, collide=collide)


def tag(p, mesh, scale=None, **colors):
    I("StringValue", "Mesh", p, value=mesh)
    if scale:
        I("NumberValue", "Scale", p, value=scale)
    for k, c in colors.items():
        I("Color3Value", k, p, color=c)


def c3(n, c):
    return f'<Color3 name="{n}"><R>{c[0] / 255:.4f}</R><G>{c[1] / 255:.4f}</G><B>{c[2] / 255:.4f}</B></Color3>'


def props(i):
    p, out = i.p, [f'<string name="Name">{escape(i.name)}</string>']
    if i.cls == "Part":
        m = p["cf"]
        out.append('<CoordinateFrame name="CFrame">' + "".join(f"<{k}>{v:.5f}</{k}>" for k, v in zip(
            ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"], m)) + "</CoordinateFrame>")
        out += [f'<Vector3 name="size"><X>{p["size"][0]:.4f}</X><Y>{p["size"][1]:.4f}</Y><Z>{p["size"][2]:.4f}</Z></Vector3>',
                f'<Color3uint8 name="Color3uint8">{(255 << 24) | (p["color"][0] << 16) | (p["color"][1] << 8) | p["color"][2]}</Color3uint8>',
                f'<token name="Material">{MAT[p["mat"]]}</token>', f'<token name="shape">{p["shape"]}</token>',
                '<bool name="Anchored">true</bool>', f'<bool name="CanCollide">{"true" if p["collide"] else "false"}</bool>',
                '<bool name="CanQuery">false</bool>', '<bool name="CanTouch">false</bool>', '<bool name="CastShadow">false</bool>',
                f'<float name="Transparency">{p["t"]}</float>', '<token name="TopSurface">0</token><token name="BottomSurface">0</token>']
    elif i.cls == "StringValue":
        out.append(f'<string name="Value">{escape(p["value"])}</string>')
    elif i.cls == "NumberValue":
        out.append(f'<double name="Value">{p["value"]}</double>')
    elif i.cls == "Color3Value":
        out.append(c3("Value", p["color"]))
    elif i.cls in ("SpotLight", "PointLight"):
        out += [c3("Color", p["color"]), f'<float name="Range">{p["range"]}</float>', f'<float name="Brightness">{p["brightness"]}</float>',
                '<bool name="Shadows">false</bool>']
        if i.cls == "SpotLight":
            out += [f'<float name="Angle">{p["angle"]}</float>', '<token name="Face">4</token>']  # Bottom
    elif i.cls == "ParticleEmitter":  # gentle snowfall
        out += ['<ColorSequence name="Color">0 1 1 1 0 1 1 1 1 0 </ColorSequence>', '<float name="Rate">40</float>',
                '<NumberRange name="Lifetime">6 9 </NumberRange>', '<NumberRange name="Speed">2 4 </NumberRange>',
                '<NumberSequence name="Size">0 0.25 0 1 0.25 0 </NumberSequence>',
                '<NumberSequence name="Transparency">0 0.1 0 1 0.6 0 </NumberSequence>',
                '<Vector3 name="Acceleration"><X>0</X><Y>-1.5</Y><Z>0</Z></Vector3>', '<token name="EmissionDirection">4</token>',
                '<Vector2 name="SpreadAngle"><X>25</X><Y>25</Y></Vector2>', '<float name="LightEmission">0.4</float>']
    return "".join(out)


def xml(i):
    return f'<Item class="{i.cls}" referent="RBXHall{next(ref)}"><Properties>{props(i)}</Properties>{"".join(xml(k) for k in i.kids)}</Item>'


def prop(parent, mesh, at, size, color, scale, **colors):
    """Blender prop: an invisible pivot at the prop's base (mesh origin) + a simple block as the fallback look."""
    m = I("Model", mesh, parent)
    tag(part(m, (0.2, 0.2, 0.2), at, (255, 255, 255), transparency=1, name="MeshPivot"), mesh, scale, **colors)
    x, y, z = at[:3]
    part(m, size, (x, y + size[1] / 2) + at[2:], color)
    return m


def mix(a, b, f):
    return tuple(int(x * (1 - f) + y * f) for x, y in zip(a, b))


# wall styles cycle through 6 colourways (few EditableMesh variants keep memory low)
WALL_STYLES = [((122, 52, 60), (78, 30, 38), (48, 92, 70)), ((40, 70, 110), (24, 42, 70), (150, 110, 60)),
               ((60, 96, 70), (34, 60, 44), (130, 40, 50)), ((110, 80, 130), (64, 44, 80), (40, 100, 110)),
               ((150, 110, 70), (96, 66, 40), (40, 60, 100)), ((40, 40, 50), (24, 24, 30), (120, 30, 60))]


def free_slots(taken, side, need, lo=-36, hi=36):
    """z offsets (table-local) on one side, at least `need` studs from the scenery already standing there."""
    out = []
    for z in [lo + k * 0.5 for k in range(int((hi - lo) / 0.5) + 1)]:
        if all(abs(z - t) >= need for t in taken):
            out.append(z)
    best, picked = None, []
    for z in sorted(out, key=lambda z: min([abs(z - t) for t in taken] or [99]), reverse=True):  # widest gaps first
        if all(abs(z - p) >= need for p in picked):
            picked.append(z)
    return sorted(picked)


def scenery(x):
    """{table index: {side: [z offsets]}} of the Land scenery between the table and the backdrop."""
    if not x:
        return {}
    import landscape
    anchors = {f[0] for f in landscape.FAMILIES if f[2] not in ("LandHills",)}
    out = {}
    for m in re.finditer(r'<string name="Name">(' + "|".join(re.escape(a) for a in anchors) + r')</string>(?:<token name="shape">\d</token>)?<CoordinateFrame name="CFrame"><X>([^<]*)</X><Y>[^<]*</Y><Z>([^<]*)</Z>', x):
        px, pz = float(m.group(2)), float(m.group(3))
        k = int((pz - START_Z) // SEG) + 1
        if 1 <= k <= len(TABLES) and 16 < abs(px) < 31:
            out.setdefault(k, {}).setdefault(1 if px > 0 else -1, []).append(pz - (START_Z + (k - 0.5) * SEG))
    return out


def build(x=None):
    hall = I("Folder", "TableHall")
    occupied = scenery(x)
    for k, (name, hexcol) in enumerate(TABLES, 1):
        zc = START_Z + (k - 0.5) * SEG
        style = WALL_STYLES[(k - 1) % len(WALL_STYLES)]
        tcol = tuple(int(hexcol[i:i + 2], 16) for i in (0, 2, 4))
        accent = mix(tcol, (255, 255, 255), 0.15)
        deco_kit, theme = kit("New Year Square" if k == NEW_YEAR else name)
        seg = I("Model", f"Hall{k:02d}", hall)
        for side in (-1, 1):  # walls + backdrop diorama: Blender, part fallback (upper band, cornice, pilasters)
            yaw = 0 if side < 0 else math.pi
            wall = I("Model", "Wall", seg)
            pv = part(wall, (0.2, 0.2, 0.2), cf(side * 33.5, 0, zc, yaw), (255, 255, 255), transparency=1, name="MeshPivot")
            tag(pv, "Wall" + theme, Accent=accent)
            part(wall, (1.2, 12, 80), cf(side * 34.1, 30, zc), style[0])
            part(wall, (1.6, 1.1, 80.2), cf(side * 33.3, 35.5, zc), (236, 224, 200))
            part(wall, (2.4, 36, 2.8), cf(side * 32.9, 18, zc - 40), style[1])
            back = I("Model", "Backdrop", seg)
            pv = part(back, (0.2, 0.2, 0.2), cf(side * 31.35, 0, zc, yaw), (255, 255, 255), transparency=1, name="MeshPivot")
            tag(pv, "Backdrop" + theme, Accent=accent)
            part(back, (0.4, 24, 80), cf(side * 31.3, 12, zc), mix(tcol, (255, 255, 255), 0.5))
        ceil = I("Model", "Ceiling", seg)  # themed ceiling with three billiard lamps
        pv = part(ceil, (0.2, 0.2, 0.2), cf(0, 0, zc), (255, 255, 255), transparency=1, name="MeshPivot")
        tag(pv, "Ceiling" + theme, Accent=accent)
        part(ceil, (70, 1, 80), cf(0, 36.5, zc), (232, 220, 196))
        for dz in (-26.7, 0, 26.7):
            shade = part(ceil, (3.6, 2.4, 3.6), cf(0, 18.2, zc + dz), (28, 110, 64), name="LampShade")
            if dz == 0:  # one real light per table keeps the light count low
                I("SpotLight", "LampLight", shade, color=(255, 226, 170), range=30, brightness=2.4, angle=75)
        deco = I("Folder", "Deco", seg)
        for n, dz in enumerate((-34, -21, -13, 13, 21, 34)):  # rails: theme piece / Deco prop, clear of pockets and sights
            for side in (-1, 1):
                z = zc + dz * -side  # mirrored, so the two rails differ
                if (n + (side > 0)) % 2:
                    prop(deco, "Rail" + theme, cf(side * RAIL_X, RAIL_TOP, z, k * 0.9 + n), (1.2, 1.4, 1.2), accent, 1.15, Accent=accent)
                else:
                    mesh = deco_kit[(n // 2 + (side > 0)) % len(deco_kit)]
                    prop(deco, mesh, cf(side * RAIL_X, RAIL_TOP, z, k * 0.7 + n), (1.4, 2.6, 1.4), mix(tcol, (255, 255, 255), 0.3), 1.25)
        for side in (-1, 1):  # floor: hero piece + mid pieces in the gaps between the Land scenery
            yaw = 0 if side < 0 else math.pi
            taken = list(occupied.get(k, {}).get(side, []))
            spots = free_slots(taken, side, 6.5)
            if spots:
                hz = min(spots, key=lambda z: abs(z - side * 10))
                prop(deco, "Hero" + theme, cf(side * 25.5, 0, zc + hz, yaw), (4, 8, 4), accent, 1.0, Accent=accent)
                taken.append(hz)
            for mz in free_slots(taken, side, 4.5)[:4]:
                prop(deco, "Mid" + theme, cf(side * 24.5, 0, zc + mz, yaw + (mz % 3 - 1) * 0.4), (2.4, 3.5, 2.4), accent, 1.0, Accent=accent)
            for n, dz in enumerate((-30, -10, 10, 30)):  # hangers under the ceiling, over the scenery
                prop(deco, "Hang" + theme, cf(side * (22 + (n % 2) * 4), 35.6, zc + dz, n * 0.8), (0.3, 0.3, 0.3), accent, 1.0, Accent=accent)
        if k == NEW_YEAR:  # the New Year set: big tree, gifts, snowmen, garlands, snowfall
            ny = I("Folder", "NewYear", seg)
            prop(ny, "DecoTree", cf(-25, 0, zc + 14), (5, 12, 5), (30, 120, 60), 2.6)
            for g, (gx, gz) in enumerate(((-21.5, 10), (-22, 18.5), (-28.5, 18), (-28, 9.5))):
                prop(ny, "DecoGift", cf(gx, 0, zc + gz, g), (2, 2, 2), (220, 40, 60), 1.4)
            prop(ny, "DecoSnowman", cf(25, 0, zc - 12, math.pi), (3.5, 8, 3.5), (248, 250, 255), 2.1)
            prop(ny, "DecoCandyCane", cf(24, 0, zc + 16), (1.2, 6, 1.2), (220, 30, 50), 1.8)
            for side in (-1, 1):  # light garlands along the outside of both rails
                for dz in (-27, -9, 9, 27):
                    prop(ny, "DecoGarland", cf(side * (RAIL_X + 1.3), RAIL_TOP - 0.4, zc + dz, math.pi / 2), (12, 1, 0.4), (30, 110, 60), 1)
            snow = part(ny, (60, 1, 80), cf(0, 33, zc), (255, 255, 255), transparency=1, name="Snowfall")
            I("ParticleEmitter", "Snow", snow)
    return hall


def build_xml(x=None):
    global ref
    ref = iter(range(10 ** 7))
    return xml(build(x))


if __name__ == "__main__":
    s = build_xml()
    print(len(TABLES), "tables,", s.count("<Item "), "items,", f"{len(s) / 1e6:.2f} MB")
