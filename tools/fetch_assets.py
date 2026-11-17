"""Downloads every Roblox asset the game uses as a 3D model into assets/rbxm/<id>.rbxm, so tools/bake_models.luau
can embed them into the place (no InsertService:LoadAsset at runtime).
  python3 tools/fetch_assets.py            # Blender models (ModelIds.lua) + Creator Store cars (CarStoreTool.Candidates)
  python3 tools/fetch_assets.py --cars 1   # only the first candidate per car (smaller place)
The Open Cloud key needs the Asset Delivery read scope (legacy-asset:manage). Files already downloaded are skipped."""
import argparse, gzip, json, os, re, sys, time, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared")
OUT = os.path.join(ROOT, "assets", "rbxm")
KEY = os.environ.get("ROBLOX_API_KEY", "proxy-injected")


def get(url, headers=None):
    req = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(req, timeout=90) as r:
        data = r.read()
        if r.headers.get("Content-Encoding") == "gzip" or data[:2] == b"\x1f\x8b":
            data = gzip.decompress(data)
        return data


def fetch(asset_id):
    path = os.path.join(OUT, f"{asset_id}.rbxm")
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return "cached"
    meta = json.loads(get(f"https://apis.roblox.com/asset-delivery-api/v1/assetId/{asset_id}", {"x-api-key": KEY}))
    loc = meta.get("location")
    if not loc:
        raise RuntimeError(f"no location: {meta}")
    data = get(loc)
    if not (data.startswith(b"<roblox!") or data.startswith(b"<roblox")):
        raise RuntimeError(f"not a model file ({data[:20]!r})")
    open(path, "wb").write(data)
    patch_legacy_props(path)
    return f"{len(data) // 1024} KB"


# ---- legacy property names lune drops (v25) ------------------------------------------------------------------------
# Old MeshParts (2016-17 uploads, e.g. car 596656603) store the mesh under the legacy name "MeshID". rbx_binary/lune
# has no alias for it, so the baked MeshPart ends up with no MeshId and renders as a plain box. Fix: rename the
# PROP chunk in the raw .rbxm (same length, same String/Content wire type) and rewrite that chunk uncompressed
# (compressedLength = 0 is valid in the binary format). Idempotent; other chunks are copied byte for byte.
LEGACY_PROPS = {"MeshPart": {b"MeshID": b"MeshId"}}


def _lz4_block(src, size):
    out = bytearray()
    i = 0
    while i < len(src):
        tok = src[i]
        i += 1
        lit = tok >> 4
        if lit == 15:
            while True:
                b = src[i]
                i += 1
                lit += b
                if b != 255:
                    break
        out += src[i : i + lit]
        i += lit
        if i >= len(src):
            break
        off = src[i] | (src[i + 1] << 8)
        i += 2
        m = tok & 15
        if m == 15:
            while True:
                b = src[i]
                i += 1
                m += b
                if b != 255:
                    break
        m += 4
        st = len(out) - off
        if off <= 0 or st < 0:
            raise ValueError("bad lz4 offset")
        for k in range(m):
            out.append(out[st + k])
    if len(out) != size:
        raise ValueError(f"lz4 size {len(out)} != {size}")
    return bytes(out)


def _chunk_body(raw, clen, ulen):
    if not clen:
        return raw
    if raw[:4] == b"\x28\xb5\x2f\xfd":
        import zstandard  # only for zstd chunks (newer Studio saves)

        return zstandard.ZstdDecompressor().decompress(raw, max_output_size=ulen)
    return _lz4_block(raw, ulen)


def patch_legacy_props(path):
    """Renames legacy property names in a binary .rbxm in place; returns how many PROP chunks were renamed.
    A class that already has the modern property keeps both chunks as they are (most 2017-19 saves carry both
    and lune reads the modern one)."""
    import struct

    d = open(path, "rb").read()
    if not d.startswith(b"<roblox!"):
        return 0  # XML models keep their names as text; lune reads those aliases itself
    chunks, p = [], 32
    while p + 16 <= len(d):
        name = d[p : p + 4]
        clen, ulen, reserved = struct.unpack("<III", d[p + 4 : p + 16])
        nxt = p + 16 + (clen or ulen)
        chunks.append((p, nxt, name, clen, ulen, reserved))
        p = nxt
        if name == b"END\x00":
            break
    # pass 1: class names and which properties each class already has
    classes, have, bodies = {}, {}, {}
    for i, (p, nxt, name, clen, ulen, _) in enumerate(chunks):
        if name in (b"INST", b"PROP"):
            body = _chunk_body(d[p + 16 : nxt], clen, ulen)
            cid, nl = struct.unpack("<II", body[:8])
            if name == b"INST":
                classes[cid] = body[8 : 8 + nl].decode("utf-8", "replace")
            else:
                have.setdefault(cid, set()).add(body[8 : 8 + nl])
                bodies[i] = (cid, nl, body)
    # pass 2: rename only where the modern name is missing
    out, renamed, last = bytearray(d[:32]), 0, 32
    for i, (p, nxt, name, clen, ulen, reserved) in enumerate(chunks):
        last = nxt
        if i in bodies:
            cid, nl, body = bodies[i]
            pname = body[8 : 8 + nl]
            new = LEGACY_PROPS.get(classes.get(cid), {}).get(pname)
            if new and len(new) == len(pname) and new not in have.get(cid, ()):
                body = body[:8] + new + body[8 + nl :]
                out += name + struct.pack("<III", 0, len(body), reserved) + body
                renamed += 1
                continue
        out += d[p:nxt]
    out += d[last:]  # anything after END (none in practice)
    if renamed:
        open(path, "wb").write(bytes(out))
    return renamed


def patch_all(directory=OUT):
    total = 0
    for f in sorted(os.listdir(directory)):
        if f.endswith(".rbxm"):
            try:
                n = patch_legacy_props(os.path.join(directory, f))
            except Exception as e:  # noqa: BLE001 - leave the file as it is, report it
                print(f"  ! patch {f}: {e}")
                continue
            if n:
                print(f"  patched legacy property names in {f} ({n} chunk(s))")
                total += n
    return total


def ids():
    models = [int(v) for v in re.findall(r"=\s*(\d{6,})", open(os.path.join(SHARED, "ModelIds.lua")).read())]
    tool = open(os.path.join(ROOT, "src", "ServerStorage", "Tools", "CarStoreTool.lua")).read()
    block = tool[tool.index("Tool.Candidates = {"):]
    block = block[: block.index("\n}\n")]
    cars = [[int(x) for x in re.findall(r"\d{5,}", m)] for m in re.findall(r"=\s*\{([^}]*)\}", block)]
    return models, cars


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--cars", type=int, default=3, help="candidates per car to download")
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    models, cars = ids()
    ok = bad = 0
    used = []

    def try_fetch(i):
        got = True
        try:
            print(f"  {i}: {fetch(i)}")
        except Exception as e:  # noqa: BLE001 - report and continue
            print(f"  ! {i}: {e}")
            got = False
        time.sleep(0.2)
        return got

    for i in models:
        if try_fetch(i):
            ok += 1
            used.append(i)
        else:
            bad += 1
    # each car: the first candidate that downloads (up to --cars tries); the game uses the first embedded one
    for c in cars:
        for i in c[: a.cars]:
            if try_fetch(i):
                ok += 1
                used.append(i)
                break  # one model per car keeps the place ~38 MB; a car whose model fails to install uses the built-in body
            else:
                bad += 1
    # the baker embeds only these ids (old versions left in assets/rbxm would only make the place bigger)
    with open(os.path.join(OUT, "used.txt"), "w") as f:
        f.write("\n".join(str(i) for i in used) + "\n")
    print(f"downloaded/cached {ok}, failed {bad}  ({len(models)} Blender models, {len(cars)} cars)")
    sys.exit(0 if ok else 1)
