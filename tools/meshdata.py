"""Read the Blender mesh ModuleScripts (ReplicatedStorage.Shared.Meshes) straight from the place file."""
import html, re

NUM = re.compile(r"-?\d+(?:\.\d+)?(?:e-?\d+)?")


def modules(x):
    """{name: source} of every ModuleScript inside the Shared.Meshes folder."""
    m = re.search(r'<Item class="Folder" referent="[^"]*"><Properties><string name="Name">Meshes</string></Properties>', x)
    import studio
    seg = x[m.start():studio.item_end(x, m.start())]
    out = {}
    for n, s in re.findall(r'<Item class="ModuleScript" referent="[^"]*"><Properties><string name="Name">(\w+)</string>'
                           r'<ProtectedString name="Source">(.*?)</ProtectedString>', seg, re.S):
        out[n] = s[9:-3] if s.startswith("<![CDATA[") else html.unescape(s)
    return out


def parse(src):
    def arr(key):
        m = re.search(r"\b" + key + r"\s*=\s*\{([^{}]*)\}", src, re.S)
        return [float(v) for v in NUM.findall(m.group(1))] if m else None
    vec = lambda key: [float(v) for v in NUM.findall(re.search(key + r"\s*=\s*Vector3\.new\(([^)]*)\)", src).group(1))]
    pal = re.findall(r"\{\s*\"(\w+)\",\s*Color3\.fromRGB\((\d+),\s*(\d+),\s*(\d+)\)\s*\}", src)
    verts, tris, colors = arr("verts"), arr("tris"), arr("colors")
    if not (verts and tris and colors and pal):
        return None
    return {"center": vec("center"), "size": vec("size"), "palette": [(n, (int(r), int(g), int(b))) for n, r, g, b in pal],
            "verts": verts, "tris": [int(t) for t in tris], "colors": [int(c) for c in colors]}
