"""Swap the block-built scenery beside the long table (World.TableLandscapes) for the Blender Land* models.
Each object (e.g. a Trunk with the Canopy and Fruit around it) is wrapped in a Model "Land:<mesh>" with an invisible
MeshPivot tagged with the mesh, scaled to the object's height and recoloured from its parts. The original parts stay
inside the model as the fallback (Visuals hides them once the mesh is built). Re-running unwraps first, so the
result is always fresh. Used by tools/studio.py pack."""
import math, os, re
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MESHES = os.path.join(ROOT, "src", "shared", "Meshes")
# anchor part, companions, mesh, cluster radius (XZ), colour slots taken from parts
FAMILIES = [
    ("Trunk", ["Canopy", "Fruit"], "LandTree", 5, {"Main": "Canopy", "Accent": "Trunk", "Detail": "Fruit"}),
    ("Bridge cap", ["Bridge pier", "Water"], "LandBridge", 7, {"Main": "Bridge pier", "Detail": "Bridge cap", "Glow": "Water"}),
    ("Candy stick", ["Swirl", "Candy centre"], "LandLollipop", 3, {"Main": "Swirl", "Detail": "Candy centre"}),
    ("Coral stem", ["Branch", "Pearl"], "LandCoral", 4, {"Main": "Coral stem", "Detail": "Pearl"}),
    ("Sandstone terrace", ["Sandstone terrace"], "LandMesa", 2, {"Main": "Sandstone terrace"}),
    ("Ice spire", ["Ice spire"], "LandIceSpire", 3, {"Main": "Ice spire"}),
    ("Lava flow", ["Basalt stack", "Molten rim"], "LandBasalt", 3, {"Main": "Basalt stack", "Glow": "Lava flow", "Detail": "Molten rim"}),
    ("Bamboo", ["Bamboo", "Node"], "LandBamboo", 2.5, {"Main": "Bamboo", "Accent": "Node"}),
    ("Moon", ["Orbital shard", "Crater rim"], "LandMoonRock", 4, {"Main": "Moon", "Accent": "Crater rim", "Detail": "Orbital shard"}),
    ("Flywheel", ["Gear tooth", "Axle"], "LandFlywheel", 4.5, {"Main": "Flywheel", "Accent": "Axle"}),
    ("Thunderhead", ["Lightning"], "LandStormCloud", 3, {"Main": "Thunderhead", "Glow": "Lightning"}),
    ("Lily pad", ["Petal", "Pollen"], "LandLotus", 4, {"Main": "Lily pad", "Accent": "Petal", "Detail": "Pollen"}),
    ("Pixel stair", ["Pixel stair", "Power cube"], "LandPixel", 4.5, {"Main": "Pixel stair", "Detail": "Power cube"}),
    ("Planet", ["Equatorial disc", "Satellite"], "LandPlanet", 4, {"Main": "Planet", "Accent": "Equatorial disc", "Detail": "Satellite"}),
    ("Royal dais", ["Crown point"], "LandThrone", 3, {"Main": "Royal dais", "Accent": "Crown point"}),
    ("Floating jewel", [], "LandGem", 0, {"Main": "Floating jewel"}),
    ("Beacon", [], "LandBeacon", 0, {"Glow": "Beacon"}),
]
CENTRED = {"LandGem"}  # pivot at the object's centre instead of its base
# flat decor on the old painted backdrop, now covered by the Blender diorama (tools/hall.py Backdrop<Theme>)
HIDE = {"Cyclorama", "Sun disc", "Moonrise", "Orbit glint", "Star", "Heraldic panel", "Sky ribbon", "Celestial lintel",
        "Faceted horizon", "Peak line", "Distant hills"}


def hide(item):
    t = prop(item, "Transparency")
    if t is None:
        t = ET.SubElement(item.find("Properties"), "float", {"name": "Transparency"})
    t.text = "1"
    c = prop(item, "CanCollide")
    if c is not None:
        c.text = "false"


def mesh_box(name):
    src = open(os.path.join(MESHES, name + ".luau"), encoding="utf-8").read()
    c = [float(v) for v in re.search(r"center = Vector3\.new\(([^)]*)\)", src).group(1).split(",")]
    s = [float(v) for v in re.search(r"size = Vector3\.new\(([^)]*)\)", src).group(1).split(",")]
    return c, s


def prop(item, key):
    for c in item.find("Properties"):
        if c.get("name") == key:
            return c
    return None


def name_of(item):
    return prop(item, "Name").text


def part_info(item):
    cf = prop(item, "CFrame")
    pos = [float(cf.find(k).text) for k in ("X", "Y", "Z")]
    rot = [float(cf.find(k).text) for k in ("R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22")]
    size = [float(prop(item, "size").find(k).text) for k in ("X", "Y", "Z")]
    # half extent along world Y of the rotated box
    hy = abs(rot[3]) * size[0] / 2 + abs(rot[4]) * size[1] / 2 + abs(rot[5]) * size[2] / 2
    col = int(prop(item, "Color3uint8").text) & 0xFFFFFF
    return pos, hy, ((col >> 16) & 255, (col >> 8) & 255, col & 255)


counter = [0]


def element(cls, props_xml, children=()):
    counter[0] += 1
    e = ET.fromstring(f'<Item class="{cls}" referent="RBXLand{counter[0]}"><Properties>{props_xml}</Properties></Item>')
    for c in children:
        e.append(c)
    return e


def c3(name, c):
    return f'<Color3 name="{name}"><R>{c[0] / 255:.4f}</R><G>{c[1] / 255:.4f}</G><B>{c[2] / 255:.4f}</B></Color3>'


def pivot(x, y, z, yaw, mesh, scale, colors):
    c, s = math.cos(yaw), math.sin(yaw)
    m = (x, y, z, c, 0, s, 0, 1, 0, -s, 0, c)
    cf = "".join(f"<{k}>{v:.5f}</{k}>" for k, v in zip(["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"], m))
    kids = [element("StringValue", f'<string name="Name">Mesh</string><string name="Value">{mesh}</string>'),
            element("NumberValue", f'<string name="Name">Scale</string><double name="Value">{scale:.4f}</double>')]
    kids += [element("Color3Value", f'<string name="Name">{slot}</string>{c3("Value", col)}') for slot, col in colors.items()]
    return element("Part", '<string name="Name">MeshPivot</string>'
                   f'<CoordinateFrame name="CFrame">{cf}</CoordinateFrame>'
                   '<Vector3 name="size"><X>0.2</X><Y>0.2</Y><Z>0.2</Z></Vector3>'
                   '<bool name="Anchored">true</bool><bool name="CanCollide">false</bool><bool name="CanQuery">false</bool>'
                   '<bool name="CanTouch">false</bool><float name="Transparency">1</float>', kids)


def process(table, boxes, report):
    for m in [k for k in table.findall("Item") if k.get("class") == "Model" and name_of(k).startswith("Land:")]:
        for k in m.findall("Item"):  # unwrap an earlier run
            if name_of(k) != "MeshPivot":
                table.append(k)
        table.remove(m)
    for k in table.findall("Item"):
        n = name_of(k)
        if k.get("class") == "Part" and n in HIDE:
            hide(k)
        elif k.get("class") == "Model" and not n.startswith("Land:") and not n.startswith("ClubTable"):
            for d in k.iter("Item"):  # the block-built theme composition: replaced by the Blender theme kit
                if d.get("class") in ("Part", "WedgePart", "CornerWedgePart", "UnionOperation"):
                    hide(d)
    parts = [k for k in table.findall("Item") if k.get("class") == "Part" and name_of(k) not in HIDE]
    info = {id(p): part_info(p) for p in parts}
    used = set()
    for anchor, companions, mesh, radius, slots in FAMILIES:
        for a in parts:
            if id(a) in used or name_of(a) != anchor:
                continue
            ap = info[id(a)][0]
            group = [a]
            used.add(id(a))
            for p in parts:
                if id(p) in used or name_of(p) not in companions:
                    continue
                pp = info[id(p)][0]
                if math.hypot(pp[0] - ap[0], pp[2] - ap[2]) <= radius:
                    group.append(p)
                    used.add(id(p))
            xs = [info[id(p)][0][0] for p in group]
            zs = [info[id(p)][0][2] for p in group]
            bottom = min(info[id(p)][0][1] - info[id(p)][1] for p in group)
            top = max(info[id(p)][0][1] + info[id(p)][1] for p in group)
            centre, size = boxes[mesh]
            x, z = (min(xs) + max(xs)) / 2, (min(zs) + max(zs)) / 2
            if mesh in CENTRED:
                scale = (top - bottom) / size[1]
                y = (top + bottom) / 2 - centre[1] * scale
            else:
                scale = max(0.3, (top - max(bottom, 0)) / (size[1] + min(0, centre[1] - size[1] / 2)))
                y = max(bottom, 0) - (centre[1] - size[1] / 2) * scale  # mesh bottom on the object's base
            colors = {slot: info[id(next(p for p in group if name_of(p) == pname))][2]
                      for slot, pname in slots.items() if any(name_of(p) == pname for p in group)}
            model = element("Model", f'<string name="Name">Land:{mesh}</string>')
            model.append(pivot(x, y, z, 0 if x < 0 else math.pi, mesh, scale, colors))
            for p in group:
                table.remove(p)
                model.append(p)
            table.append(model)
            report[mesh] = report.get(mesh, 0) + 1


def apply(x):
    """Rewrite the TableLandscapes folder inside the place XML string."""
    import studio  # item_end
    start = re.search(r'<Item class="Folder" referent="[^"]*"><Properties><string name="Name">TableLandscapes</string></Properties>', x)
    assert start, "TableLandscapes not found"
    end = studio.item_end(x, start.start())
    folder = ET.fromstring(x[start.start():end])
    boxes = {f[2]: mesh_box(f[2]) for f in FAMILIES}
    report = {}
    counter[0] = 0
    for table in folder.findall("Item"):
        process(table, boxes, report)
    print("landscape objects:", sum(report.values()), dict(sorted(report.items())))
    return x[:start.start()] + ET.tostring(folder, encoding="unicode") + x[end:]
