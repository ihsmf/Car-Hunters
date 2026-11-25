"""Upload every Blender mesh of the place to Roblox as mesh assets, so the game uses real MeshParts.
    python3 tools/meshassets.py <creatorUserId>
Each mesh (Shared.Meshes ModuleScript in studio/CueHunters.rbxlx) is split per palette slot (one colour each,
max 9000 triangles per piece, both windings so it renders double-sided), written as GLB, uploaded through Open Cloud
(assetType Model), and the MeshId of the imported MeshPart is read back from the asset. Results are cached in
tools/mesh_assets.json: pieces per mesh (slot, offset from the model origin, size) + GLB hash -> [MeshId, InitialSize], so a re-run
uploads only new or changed pieces. The API key is added by the session proxy (x-api-key for apis.roblox.com)."""
import hashlib, json, math, os, re, struct, sys, time, urllib.request, uuid, gzip

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
import meshdata, rbxm  # noqa: E402

ROOT = os.path.dirname(TOOLS)
PLACE = os.path.join(ROOT, "studio", "CueHunters.rbxlx")
CACHE = os.path.join(TOOLS, "mesh_assets.json")
API = "https://apis.roblox.com"
MAX_TRIS = 9000
CREATOR = [None]


def glb(tris):
    """tris: list of (a, b, c) points -> binary glTF with flat normals, front + back faces."""
    pos, nor = [], []
    for a, b, c in tris:
        u = [b[i] - a[i] for i in range(3)]
        v = [c[i] - a[i] for i in range(3)]
        n = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
        L = math.sqrt(sum(k * k for k in n)) or 1
        n = [k / L for k in n]
        pos += [a, b, c, a, c, b]
        nor += [n] * 3 + [[-k for k in n]] * 3
    # Roblox's glTF import mirrors the X axis: write X negated so the mesh comes out the right way round
    pos = [(-p[0], p[1], p[2]) for p in pos]
    nor = [(-n[0], n[1], n[2]) for n in nor]
    bp = b"".join(struct.pack("<3f", *p) for p in pos)
    bn = b"".join(struct.pack("<3f", *p) for p in nor)
    lo = [min(p[i] for p in pos) for i in range(3)]
    hi = [max(p[i] for p in pos) for i in range(3)]
    doc = {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0, "name": "M"}],
           "meshes": [{"primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1}}]}],
           "buffers": [{"byteLength": len(bp) + len(bn)}],
           "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": len(bp)}, {"buffer": 0, "byteOffset": len(bp), "byteLength": len(bn)}],
           "accessors": [{"bufferView": 0, "componentType": 5126, "count": len(pos), "type": "VEC3", "min": lo, "max": hi},
                         {"bufferView": 1, "componentType": 5126, "count": len(nor), "type": "VEC3"}]}
    js = json.dumps(doc, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    binc = bp + bn
    out = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(binc))
    return out + struct.pack("<I4s", len(js), b"JSON") + js + struct.pack("<I4s", len(binc), b"BIN\x00") + binc


def pieces(d):
    """[(slot, offset_from_origin, size, glb_bytes)] for one mesh."""
    v, t = d["verts"], d["tris"]
    P = lambda i: (v[3 * i - 3], v[3 * i - 2], v[3 * i - 1])
    out = []
    for slot in sorted(set(d["colors"])):
        faces = [(P(t[3 * f]), P(t[3 * f + 1]), P(t[3 * f + 2])) for f, c in enumerate(d["colors"]) if c == slot]
        for k in range(0, len(faces), MAX_TRIS):
            chunk = faces[k:k + MAX_TRIS]
            pts = [p for f in chunk for p in f]
            lo = [min(p[i] for p in pts) for i in range(3)]
            hi = [max(p[i] for p in pts) for i in range(3)]
            mid = [(lo[i] + hi[i]) / 2 for i in range(3)]
            size = [max(hi[i] - lo[i], 0.01) for i in range(3)]
            local = [tuple(tuple(p[i] - mid[i] for i in range(3)) for p in f) for f in chunk]
            out.append((d["palette"][slot - 1][0], [d["center"][i] + mid[i] for i in range(3)], size, glb(local)))
    return out


def call(url, data=None, headers=None, method=None):
    for attempt in range(6):
        try:
            req = urllib.request.Request(url, data=data, method=method, headers={"x-api-key": "set-by-proxy", **(headers or {})})
            with urllib.request.urlopen(req, timeout=120) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            body = e.read()[:300]
            if e.code in (429, 500, 502, 503, 504):
                time.sleep(5 * (attempt + 1))
                continue
            raise RuntimeError(f"{e.code} {body!r}")
        except (urllib.error.URLError, TimeoutError):
            time.sleep(5 * (attempt + 1))
    raise RuntimeError("giving up on " + url)


def upload(name, blob, creator):
    b = uuid.uuid4().hex
    req = json.dumps({"assetType": "Model", "displayName": name[:50], "description": "Cue Hunters mesh",
                      "creationContext": {"creator": {"userId": str(creator)}}})
    body = (f"--{b}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n{req}\r\n"
            f"--{b}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{name}.glb\"\r\n"
            f"Content-Type: model/gltf-binary\r\n\r\n").encode() + blob + f"\r\n--{b}--\r\n".encode()
    op = json.loads(call(API + "/assets/v1/assets", body, {"Content-Type": f"multipart/form-data; boundary={b}"}, "POST"))
    for _ in range(60):
        if op.get("done"):
            break
        time.sleep(2)
        op = json.loads(call(API + "/assets/v1/" + op["path"]))
    if "response" not in op:
        raise RuntimeError(f"{name}: {op}")
    return op["response"]["assetId"]


def mesh_of(model_id):
    loc = json.loads(call(f"{API}/asset-delivery-api/v1/assetId/{model_id}"))["location"]
    raw = urllib.request.urlopen(urllib.request.Request(loc, headers={"Accept-Encoding": "gzip"}), timeout=120).read()
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    ids = re.findall(rb"rbxassetid://(\d+)", raw)
    assert ids, f"no mesh id in model {model_id}"
    cls, props = rbxm.parse(raw)
    t, val = props["MeshPart"]["InitialSize"]
    return ids[0].decode(), [rbxm.untrans_f(val[4 * i:4 * i + 4], 1)[0] for i in range(3)]


TEXTURED = ["GodBody", "GodHead", "GodArmR", "GodArmL", "GodTemple"]  # blender/god.py: GLB with UVs + baked PNG


def upload_image(name, png):
    b = uuid.uuid4().hex
    req = json.dumps({"assetType": "Decal", "displayName": name[:50], "description": "CUE HUNTERS texture",
                      "creationContext": {"creator": {"userId": str(CREATOR[0])}}})
    body = (f"--{b}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n{req}\r\n"
            f"--{b}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{name}.png\"\r\n"
            f"Content-Type: image/png\r\n\r\n").encode() + png + f"\r\n--{b}--\r\n".encode()
    op = json.loads(call(API + "/assets/v1/assets", body, {"Content-Type": f"multipart/form-data; boundary={b}"}, "POST"))
    for _ in range(60):
        if op.get("done"):
            break
        time.sleep(2)
        op = json.loads(call(API + "/assets/v1/" + op["path"]))
    decal = op["response"]["assetId"]
    loc = json.loads(call(f"{API}/asset-delivery-api/v1/assetId/{decal}"))["location"]
    raw = urllib.request.urlopen(urllib.request.Request(loc, headers={"Accept-Encoding": "gzip"}), timeout=120).read()
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    return re.search(rb"asset/\?id=(\d+)", raw).group(1).decode()  # the image behind the decal


def textured(cache, creator):
    """God models: one textured piece each (offset/size from the luau fallback module)."""
    export = os.path.join(ROOT, "blender", "export")
    for name in TEXTURED:
        glb_path, png_path = os.path.join(export, name + ".glb"), os.path.join(export, name + ".png")
        if not os.path.exists(glb_path):
            continue
        glb, png = open(glb_path, "rb").read(), open(png_path, "rb").read()
        src = open(os.path.join(ROOT, "src", "shared", "Meshes", name + ".luau"), encoding="utf-8").read()
        vec = lambda k: [float(v) for v in re.search(k + r" = Vector3\.new\(([^)]*)\)", src).group(1).split(",")]
        h = hashlib.sha1(glb + png).hexdigest()[:16]
        cache["meshes"][name] = [{"slot": "Tex", "offset": vec("center"), "size": vec("size"), "hash": h}]
        if h in cache["meshIds"]:
            continue
        mid, init = mesh_of(upload("CH_" + name, glb, creator))
        tex = upload_image("CH_" + name + "_tex", png)
        cache["meshIds"][h] = [mid, [round(k, 5) for k in init], tex]
        print(name, mid, tex, flush=True)


def main():
    creator = sys.argv[1]
    CREATOR[0] = creator
    cache = json.load(open(CACHE)) if os.path.exists(CACHE) else {"meshIds": {}, "meshes": {}}
    x = open(PLACE, encoding="utf-8").read()
    mods = meshdata.modules(x)
    only = set(sys.argv[2:])
    todo = []
    for name, src in sorted(mods.items()):
        if only and name not in only:
            continue
        d = meshdata.parse(src)
        entry = []
        for slot, off, size, blob in pieces(d):
            h = hashlib.sha1(blob).hexdigest()[:16]
            entry.append({"slot": slot, "offset": [round(k, 4) for k in off], "size": [round(k, 4) for k in size], "hash": h})
            if h not in cache["meshIds"]:
                todo.append((f"BH_{name}_{slot}", h, blob, size))
        cache["meshes"][name] = entry
    print(len(todo), "pieces to upload")
    textured(cache, creator)
    import threading
    from concurrent.futures import ThreadPoolExecutor
    lock, done = threading.Lock(), [0]

    def work(item):
        label, h, blob, size = item
        try:
            mid, init = mesh_of(upload(label, blob, creator))
        except Exception as e:  # keep going; the piece is retried next run
            print("FAILED", label, e, flush=True)
            return
        r = [init[i] / size[i] for i in range(3)]
        if max(r) / min(r) > 1.05 and min(size) > 0.05:
            print("WARNING axis/scale mismatch", label, size, init, flush=True)
        with lock:
            cache["meshIds"][h] = [mid, [round(k, 5) for k in init]]  # MeshId, InitialSize
            done[0] += 1
            print(done[0], label, mid, flush=True)
            if done[0] % 10 == 0:
                json.dump(cache, open(CACHE, "w"), indent=0)

    with ThreadPoolExecutor(6) as pool:
        list(pool.map(work, todo))
    json.dump(cache, open(CACHE, "w"), indent=0)
    missing = sum(1 for e in cache["meshes"].values() for p in e if p["hash"] not in cache["meshIds"])
    print("done; pieces without MeshId:", missing)


if __name__ == "__main__":
    main()
