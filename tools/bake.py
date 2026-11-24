"""Bake the uploaded Blender meshes (tools/mesh_assets.json, made by tools/meshassets.py) into the place:
- ReplicatedStorage.MeshAssets.<Name>: a Model of MeshParts (one per colour slot) posed around the model origin, which
  Shared.MeshBuilder clones at runtime (cues, balls, rings, UI previews, finale) instead of building EditableMeshes;
- every Workspace part tagged with a "Mesh" StringValue gets its MeshParts written in as a "MeshVisual" child
  (recoloured by its Color3Value overrides, scaled by Scale/WideScale), the part-built fallback is made invisible and
  the tag is renamed "BakedMesh" so the client does not rebuild it. The models are therefore real geometry: visible
  in the Studio editor and instantly in game. Meshes not uploaded yet keep the runtime path. Used by studio.py pack."""
import base64, json, math, os, re, struct, sys
import xml.etree.ElementTree as ET

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
import meshdata, studio  # noqa: E402

CACHE = os.path.join(TOOLS, "mesh_assets.json")
NEON_SLOTS = {"Glow"}
NO_NEON = {"LandBridge"}  # its Glow slot is water
ref = [0]


def attrs(d):
    out = struct.pack("<I", len(d))
    for k, v in d.items():
        out += struct.pack("<I", len(k)) + k.encode()
        if isinstance(v, str):
            out += b"\x02" + struct.pack("<I", len(v)) + v.encode()
        elif isinstance(v, (list, tuple)):
            out += b"\x11" + struct.pack("<3f", *v)
        else:
            out += b"\x06" + struct.pack("<d", v)
    return base64.b64encode(out).decode()


def mat_mul(a, b):  # 3x3 row-major
    return [sum(a[r * 3 + k] * b[k * 3 + c] for k in range(3)) for r in range(3) for c in range(3)]


def cframe(pos, rot):
    keys = ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]
    return '<CoordinateFrame name="CFrame">' + "".join(f"<{k}>{v:.5f}</{k}>" for k, v in zip(keys, list(pos) + list(rot))) + "</CoordinateFrame>"


def v3(name, v):
    return f'<Vector3 name="{name}"><X>{v[0]:.5f}</X><Y>{v[1]:.5f}</Y><Z>{v[2]:.5f}</Z></Vector3>'


def meshpart(name, pos, rot, size, init, mesh_id, color, neon, shadow, attributes=None, anchored=True, tex=None):
    ref[0] += 1
    col = 0xFF000000 | (color[0] << 16) | (color[1] << 8) | color[2]
    a = f'<BinaryString name="AttributesSerialize">{attrs(attributes)}</BinaryString>' if attributes else ""
    return ET.fromstring(
        f'<Item class="MeshPart" referent="RBXBake{ref[0]}"><Properties><string name="Name">{name}</string>'
        f'{cframe(pos, rot)}{v3("size", size)}{v3("InitialSize", init)}'
        f'<Content name="MeshId"><url>rbxassetid://{mesh_id}</url></Content>'
        + (f'<Content name="TextureID"><url>rbxassetid://{tex}</url></Content>' if tex else "") +
        f'<Color3uint8 name="Color3uint8">{col}</Color3uint8><token name="Material">{288 if neon else 272}</token>'
        f'<bool name="Anchored">{str(anchored).lower()}</bool><bool name="CanCollide">false</bool><bool name="CanQuery">false</bool>'
        f'<bool name="CanTouch">false</bool><bool name="CastShadow">{str(shadow).lower()}</bool><bool name="Massless">true</bool>'
        f'<token name="CollisionFidelity">2</token><token name="RenderFidelity">0</token>{a}</Properties></Item>')


def load():
    if not os.path.exists(CACHE):
        return {}
    c = json.load(open(CACHE))
    ready = {}
    for name, pieces in c["meshes"].items():
        if pieces and all(p["hash"] in c["meshIds"] for p in pieces):
            ready[name] = [dict(p, id=c["meshIds"][p["hash"]][0], init=c["meshIds"][p["hash"]][1],
                                tex=(c["meshIds"][p["hash"]] + [None])[2]) for p in pieces]
    return ready


def prop(item, key):
    for c in item.find("Properties"):
        if c.get("name") == key:
            return c
    return None


def name_of(item):
    n = prop(item, "Name")
    return n.text if n is not None else ""


def build(mesh, pieces, palette, pos, rot, scale, overrides, shadow_min=6):
    """MeshParts of one mesh; the biggest piece first (named MeshVisual), the others nested under it."""
    order = sorted(pieces, key=lambda p: -p["size"][0] * p["size"][1] * p["size"][2])
    parts = []
    for p in order:
        off = [p["offset"][i] * scale[i] for i in range(3)]
        world = [pos[i] + sum(rot[i * 3 + k] * off[k] for k in range(3)) for i in range(3)]
        size = [p["size"][i] * scale[i] for i in range(3)]
        color = overrides.get(p["slot"]) or palette.get(p["slot"], (255, 255, 255))
        neon = p["slot"] in NEON_SLOTS and mesh not in NO_NEON
        parts.append(meshpart(p["slot"], world, rot, size, p["init"], p["id"], color, neon, max(size) >= shadow_min, tex=p.get("tex")))
    parts[0].find("Properties")[0].text = "MeshVisual"
    for p in parts[1:]:
        parts[0].append(p)
    return parts[0]


def apply(x):
    ready = load()
    if not ready:
        print("bake: no uploaded meshes yet (run tools/meshassets.py)")
        return x
    mods = meshdata.modules(x)
    palettes = {n: dict(meshdata.parse(s)["palette"]) for n, s in mods.items() if n in ready}
    for n in ready:
        palettes.setdefault(n, {})  # textured models (blender/god.py) have no module in the place
    ref[0] = 0
    # 1) ReplicatedStorage.MeshAssets templates
    old = x.find('<Item class="Folder" referent="RBXAssets0">')
    if old != -1:
        x = x[:old] + x[studio.item_end(x, old):]
    folder = ET.fromstring('<Item class="Folder" referent="RBXAssets0"><Properties><string name="Name">MeshAssets</string></Properties></Item>')
    ident = [1, 0, 0, 0, 1, 0, 0, 0, 1]
    for mesh, pieces in sorted(ready.items()):
        ref[0] += 1
        model = ET.fromstring(f'<Item class="Model" referent="RBXBake{ref[0]}"><Properties><string name="Name">{mesh}</string></Properties></Item>')
        for p in pieces:
            model.append(meshpart(p["slot"], p["offset"], ident, p["size"], p["init"], p["id"], palettes[mesh].get(p["slot"], (255, 255, 255)),
                                  p["slot"] in NEON_SLOTS and mesh not in NO_NEON, True,
                                  {"Slot": p["slot"], "Offset": p["offset"], "Volume": p["size"][0] * p["size"][1] * p["size"][2]}, tex=p.get("tex")))
        folder.append(model)
    rs = re.search(r'<Item class="ReplicatedStorage" referent="[^"]*">\s*<Properties>.*?</Properties>', x, re.S)
    x = x[:rs.end()] + ET.tostring(folder, encoding="unicode") + x[rs.end():]
    # 2) Workspace tagged parts
    ws = x.find('<Item class="Workspace"')
    we = studio.item_end(x, ws)
    tree = ET.fromstring(x[ws:we])
    parent = {c: p for p in tree.iter("Item") for c in p.findall("Item")}
    baked, skipped = 0, {}
    for tag in [i for i in tree.iter("Item") if i.get("class") == "StringValue" and name_of(i) == "Mesh"]:
        mesh = prop(tag, "Value").text
        part = parent[tag]
        anchored = prop(part, "Anchored")
        if mesh not in ready or part.get("class") not in ("Part", "MeshPart") or anchored is None or anchored.text != "true":
            skipped[mesh] = skipped.get(mesh, 0) + 1
            continue
        cf = prop(part, "CFrame")
        pos = [float(cf.find(k).text) for k in "XYZ"]
        rot = [float(cf.find(k).text) for k in ("R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22")]
        scale, overrides = [1, 1, 1], {}
        for c in part.findall("Item"):
            n = name_of(c)
            if c.get("class") == "Color3Value":
                v = prop(c, "Value")
                overrides[n] = tuple(round(float(v.find(k).text) * 255) for k in "RGB")
            elif n == "Scale" and c.get("class") == "NumberValue":
                scale = [float(prop(c, "Value").text)] * 3
            elif n == "Scale" and c.get("class") == "Vector3Value":
                v = prop(c, "Value")
                scale = [float(v.find(k).text) for k in "XYZ"]
        wide = [c for c in part.findall("Item") if name_of(c) == "WideScale"]
        if wide:
            w = float(prop(wide[0], "Value").text)
            scale = [scale[0] * w, scale[1], scale[2] * w]
        for c in [c for c in part.findall("Item") if name_of(c) == "MeshVisual"]:
            part.remove(c)
        part.append(build(mesh, ready[mesh], palettes[mesh], pos, rot, scale, overrides))
        prop(tag, "Name").text = "BakedMesh"
        hidden = []
        if name_of(part) == "MeshPivot":  # the part-built fallback model around the pivot
            hidden = [i for i in parent[part].iter("Item") if i.get("class") in ("Part", "WedgePart", "CornerWedgePart", "TrussPart", "UnionOperation")
                      and i is not part and not any(i is d for d in part.iter("Item"))]
        else:
            hidden = [part]
        for h in hidden:
            t = prop(h, "Transparency")
            if t is None:
                t = ET.SubElement(h.find("Properties"), "float", {"name": "Transparency"})
            t.text = "1"
            for d in h.findall("Item"):  # decals / textures on hidden blocks
                if d.get("class") in ("Decal", "Texture"):
                    tt = prop(d, "Transparency")
                    if tt is None:
                        tt = ET.SubElement(d.find("Properties"), "float", {"name": "Transparency"})
                    tt.text = "1"
        baked += 1
    print(f"bake: {len(ready)} meshes as assets, {baked} world objects baked, runtime: {skipped or 'none'}")
    return x[:ws] + ET.tostring(tree, encoding="unicode") + x[we:]
