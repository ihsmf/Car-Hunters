"""Round-trip scripts of the Studio place (studio/BilliardHunters.rbxlx), which is the game's source of truth.
    python3 tools/studio.py extract   -> studio/src/<Name>.luau for the scripts listed in EDITED
    python3 tools/studio.py pack      -> writes studio/src back into the place, adds/updates the Blender meshes in
                                         MESHES under ReplicatedStorage.Shared.Meshes, checks the XML and builds
                                         studio/BilliardHunters-Studio-Full.zip (same layout as the original upload)"""
import html, os, re, sys, zipfile
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STUDIO = os.path.join(ROOT, "studio")
PLACE = os.path.join(STUDIO, "BilliardHunters.rbxlx")
SRC = os.path.join(STUDIO, "src")
MESH_DIR = os.path.join(ROOT, "src", "shared", "Meshes")
EDITED = ["Config", "UI", "Throw", "HeavenlyBreak"]
MESHES = ["FinaleComputer", "FinaleCity", "FinaleNature", "HallWall", "HallCeiling", "DecoLantern", "DecoCrystal", "DecoGift",
          "DecoTree", "DecoSnowman", "DecoCandyCane", "DecoMushroom", "DecoCactus", "DecoShell", "DecoGear", "DecoPlanet",
          "DecoPalm", "DecoTorch", "DecoTrophy", "DecoLotus", "DecoGarland"]
NEW = {"CameraDirector": ("LocalScript", "UI")}  # scripts we add: class, inserted next to this existing script


def item_re(name):  # one script Item by its (unique) Name; group 2 = the Source payload
    return re.compile(r'(<Item class="(?:Script|LocalScript|ModuleScript)" referent="[^"]*">\s*<Properties>'
                      r'(?:(?!</Properties>).)*?<string name="Name">' + re.escape(name) +
                      r'</string>(?:(?!</Properties>).)*?<ProtectedString name="Source">)(.*?)(</ProtectedString>)', re.S)


def decode(payload):
    return payload[9:-3] if payload.startswith("<![CDATA[") else html.unescape(payload)


def encode(src):
    assert "]]>" not in src, "a script contains ]]>"
    return "<![CDATA[" + src + "]]>"


def extract():
    x = open(PLACE, encoding="utf-8").read()
    os.makedirs(SRC, exist_ok=True)
    for n in EDITED + [k for k in NEW if item_re(k).search(x)]:
        ms = list(item_re(n).finditer(x))
        assert len(ms) == 1, f"{n}: {len(ms)} matches"
        open(os.path.join(SRC, n + ".luau"), "w", encoding="utf-8").write(decode(ms[0].group(2)))
        print("extracted", n)


def item_end(x, start):  # index just after the </Item> that closes the <Item at `start`
    depth, i = 0, start
    while True:
        a, b = x.find("<Item ", i), x.find("</Item>", i)
        if a != -1 and a < b:
            depth, i = depth + 1, a + 6
        else:
            depth, i = depth - 1, b + 7
            if depth == 0:
                return i


def inject_hall(x):
    """World.TableHall (tools/hall.py): replaced on every pack."""
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import hall
    old = x.find('<Item class="Folder" referent="RBXHall0">')
    if old != -1:
        x = x[:old] + x[item_end(x, old):]
    world = re.search(r'<Item class="Folder" referent="[^"]*"><Properties><string name="Name">World</string></Properties>', x)
    assert world, "World folder not found"
    return x[:world.end()] + hall.build_xml() + x[world.end():]


def pack():
    x = open(PLACE, encoding="utf-8").read()
    for n in EDITED:
        src = open(os.path.join(SRC, n + ".luau"), encoding="utf-8").read()
        x, k = item_re(n).subn(lambda m: m.group(1) + encode(src) + m.group(3), x)
        assert k == 1, f"{n}: replaced {k} times"
    folder = re.search(r'<Item class="Folder" referent="[^"]*"><Properties><string name="Name">Meshes</string></Properties>', x)
    assert folder, "Shared.Meshes folder not found"
    for n, (cls, sibling) in NEW.items():
        src = open(os.path.join(SRC, n + ".luau"), encoding="utf-8").read()
        x, k = item_re(n).subn(lambda m: m.group(1) + encode(src) + m.group(3), x)
        if k == 0:  # first pack: insert the new script right before its sibling, i.e. into the same folder
            sib = item_re(sibling).search(x)
            assert sib, f"{sibling} not found"
            new = (f'<Item class="{cls}" referent="RBXDirector{n}"><Properties><string name="Name">{n}</string>'
                   f'<ProtectedString name="Source">{encode(src)}</ProtectedString></Properties></Item>')
            x = x[:sib.start()] + new + x[sib.start():]
        else:
            assert k == 1, f"{n}: {k} copies"
    for n in MESHES:
        src = open(os.path.join(MESH_DIR, n + ".luau"), encoding="utf-8").read()
        x, k = item_re(n).subn(lambda m: m.group(1) + encode(src) + m.group(3), x)
        if k == 0:  # first pack: insert a new ModuleScript into the Meshes folder
            new = (f'<Item class="ModuleScript" referent="RBXFinale{n}"><Properties><string name="Name">{n}</string>'
                   f'<ProtectedString name="Source">{encode(src)}</ProtectedString></Properties></Item>')
            folder = re.search(r'<Item class="Folder" referent="[^"]*"><Properties><string name="Name">Meshes</string></Properties>', x)
            x = x[:folder.end()] + new + x[folder.end():]
        else:
            assert k == 1, f"{n}: {k} copies"
    x = inject_hall(x)
    ET.fromstring(x)  # the place must still be valid XML
    open(PLACE, "w", encoding="utf-8").write(x)
    out = os.path.join(STUDIO, "BilliardHunters-Studio-Full.zip")
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(PLACE, "BilliardHunters.rbxlx")
        for f in sorted(os.listdir(os.path.join(STUDIO, "Audio"))):
            z.write(os.path.join(STUDIO, "Audio", f), "Audio/" + f)
        z.write(os.path.join(STUDIO, "README.txt"), "README.txt")
    print("packed", len(EDITED) + len(NEW), "scripts,", len(MESHES), "meshes ->", os.path.relpath(out, ROOT), f"{os.path.getsize(out) / 1e6:.1f} MB")


if __name__ == "__main__":
    {"extract": extract, "pack": pack}[sys.argv[1]]()
