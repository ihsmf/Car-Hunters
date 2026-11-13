"""Upload CAR HUNTERS sounds and create donation products through Roblox Open Cloud.

Usage:
  ROBLOX_API_KEY=... python3 tools/roblox_open_cloud.py sounds   --creator-user 123456      (or --creator-group 123)
  ROBLOX_API_KEY=... python3 tools/roblox_open_cloud.py products --universe 987654
  ROBLOX_API_KEY=... python3 tools/roblox_open_cloud.py models   --creator-user 123456      (Blender FBX -> Model assets)
  ROBLOX_API_KEY=... python3 tools/roblox_open_cloud.py publish  --universe 987654 --place 123456 [--version-type Saved]
The API key needs: Assets (read+write) for sounds/models/icons; Developer Products + Game Passes (write) for products;
universe-places (write) for publish, with the experience in the key's Access list.
In a Claude cloud session the key is injected by the network proxy, so ROBLOX_API_KEY may be any placeholder.
Results are written into src/ReplicatedStorage/Shared/SoundIds.lua and ProductIds.lua; rebuild with tools/build_place.py.
"""
import argparse, json, os, re, sys, time, urllib.request, uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared")
API = "https://apis.roblox.com"
KEY = os.environ.get("ROBLOX_API_KEY", "proxy-injected")


def request(method, url, body=None, headers=None, timeout=60):
    h = {"x-api-key": KEY}
    h.update(headers or {})
    req = urllib.request.Request(url, data=body, method=method, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        txt = e.read().decode("utf-8", "replace")
        return e.code, {"error": txt}


def multipart(fields, files):
    b = "----ch" + uuid.uuid4().hex
    out = []
    for k, v in fields.items():
        out.append(f'--{b}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode())
    for k, (fname, ctype, data) in files.items():
        out.append(f'--{b}\r\nContent-Disposition: form-data; name="{k}"; filename="{fname}"\r\nContent-Type: {ctype}\r\n\r\n'.encode() + data + b"\r\n")
    out.append(f"--{b}--\r\n".encode())
    return b"".join(out), {"Content-Type": f"multipart/form-data; boundary={b}"}


def write_ids(path, key, mapping):
    s = open(path, encoding="utf-8").read()
    for name, val in mapping.items():
        s, n = re.subn(rf"(\b{re.escape(name)}\s*=\s*)\d+", rf"\g<1>{val}", s, count=1)
        if n == 0:
            print("  ! no slot for", name, "in", os.path.basename(path))
    open(path, "w", encoding="utf-8").write(s)


def upload_sounds(args):
    creator = {"userId": str(args.creator_user)} if args.creator_user else {"groupId": str(args.creator_group)}
    folder = os.path.join(ROOT, "assets", "sounds")
    done = {}
    for fn in sorted(os.listdir(folder)):
        if not fn.endswith(".mp3"):
            continue
        name = fn[:-4]
        if args.only and name not in args.only.split(","):
            continue
        meta = {"assetType": "Audio", "displayName": f"CarHunters {name}", "description": "CAR HUNTERS sound effect (ElevenLabs)",
                "creationContext": {"creator": creator}}
        body, hdr = multipart({"request": json.dumps(meta)}, {"fileContent": (fn, "audio/mpeg", open(os.path.join(folder, fn), "rb").read())})
        st, res = request("POST", f"{API}/assets/v1/assets", body, hdr)
        if st >= 300:
            print(f"  ! {name}: {st} {res}")
            continue
        op = res.get("path") or res.get("operationId")
        asset = None
        for _ in range(30):
            st2, r2 = request("GET", f"{API}/assets/v1/{op}" if op and op.startswith("operations") else f"{API}/assets/v1/operations/{op}")
            if r2.get("done"):
                asset = (r2.get("response") or {}).get("assetId")
                break
            time.sleep(2)
        if asset:
            done[name] = int(asset)
            print(f"  {name}: {asset}")
        else:
            print(f"  ! {name}: upload did not finish ({r2})")
    write_ids(os.path.join(SHARED, "SoundIds.lua"), "sounds", done)
    print(f"uploaded {len(done)} sounds")


def upload_models(args):
    """every FBX in assets/spawn, assets/city, assets/garage + assets/parts/parts.fbx + assets/props/props.fbx -> Model assets -> ModelIds.lua"""
    creator = {"userId": str(args.creator_user)} if args.creator_user else {"groupId": str(args.creator_group)}
    files = []
    for folder in ("spawn", "city", "garage"):
        d = os.path.join(ROOT, "assets", folder)
        if not os.path.isdir(d):
            continue
        files += [os.path.join(d, f) for f in sorted(os.listdir(d)) if f.endswith(".fbx")]
    files += [os.path.join(ROOT, "assets", "parts", "parts.fbx"), os.path.join(ROOT, "assets", "props", "props.fbx")]
    ids_path = os.path.join(SHARED, "ModelIds.lua")
    done = {}
    for path in files:
        name = os.path.basename(path)[:-4]
        name = {"parts": "PartsKit", "props": "PropsKit"}.get(name, name)
        if args.only and name not in args.only.split(","):
            continue
        meta = {"assetType": "Model", "displayName": f"CarHunters {name}", "description": "CAR HUNTERS map model (Blender)",
                "creationContext": {"creator": creator}}
        body, hdr = multipart({"request": json.dumps(meta)}, {"fileContent": (os.path.basename(path), "model/fbx", open(path, "rb").read())})
        st, res = request("POST", f"{API}/assets/v1/assets", body, hdr)
        if st >= 300:
            print(f"  ! {name}: {st} {res}")
            continue
        op = res.get("path") or res.get("operationId")
        asset, r2 = None, {}
        for _ in range(60):
            st2, r2 = request("GET", f"{API}/assets/v1/{op}" if op and op.startswith("operations") else f"{API}/assets/v1/operations/{op}")
            if r2.get("done"):
                asset = (r2.get("response") or {}).get("assetId")
                break
            time.sleep(3)
        if asset:
            done[name] = int(asset)
            print(f"  {name}: {asset}")
        else:
            print(f"  ! {name}: upload did not finish ({r2})")
    old = {}
    if os.path.exists(ids_path):
        for m in re.finditer(r"(\w+) = (\d+)", open(ids_path, encoding="utf-8").read()):
            old[m.group(1)] = int(m.group(2))
    old.update(done)
    lines = ["-- Blender models uploaded as Roblox Model assets (tools/roblox_open_cloud.py models). ModelService loads them.", "return {"]
    lines += [f"\t{k} = {v}," for k, v in sorted(old.items())]
    lines.append("}")
    open(ids_path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print(f"uploaded {len(done)} models")


def upload_icons(args):
    """assets/icons/*.png -> Decal assets -> IconIds.lua (shown in game via rbxthumb://type=Asset)"""
    creator = {"userId": str(args.creator_user)} if args.creator_user else {"groupId": str(args.creator_group)}
    folder = os.path.join(ROOT, "assets", "icons")
    done = {}
    for fn in sorted(os.listdir(folder)):
        if not fn.endswith(".png"):
            continue
        name = fn[:-4]
        if args.only and name not in args.only.split(","):
            continue
        meta = {"assetType": "Decal", "displayName": f"CarHunters icon {name}", "description": "CAR HUNTERS HUD icon (Blender render)",
                "creationContext": {"creator": creator}}
        body, hdr = multipart({"request": json.dumps(meta)}, {"fileContent": (fn, "image/png", open(os.path.join(folder, fn), "rb").read())})
        st, res = request("POST", f"{API}/assets/v1/assets", body, hdr)
        if st >= 300:
            print(f"  ! {name}: {st} {res}")
            continue
        op = res.get("path") or res.get("operationId")
        asset, r2 = None, {}
        for _ in range(40):
            st2, r2 = request("GET", f"{API}/assets/v1/{op}" if op and op.startswith("operations") else f"{API}/assets/v1/operations/{op}")
            if r2.get("done"):
                asset = (r2.get("response") or {}).get("assetId")
                break
            time.sleep(2)
        if asset:
            done[name] = int(asset)
            print(f"  {name}: {asset}")
        else:
            print(f"  ! {name}: upload did not finish ({r2})")
    path = os.path.join(SHARED, "IconIds.lua")
    old = {}
    if os.path.exists(path):
        for m in re.finditer(r"(\w+) = (\d+)", open(path, encoding="utf-8").read()):
            old[m.group(1)] = int(m.group(2))
    old.update(done)
    lines = ["-- HUD icons rendered in Blender (blender/make_icons.py), uploaded as Decals (tools/roblox_open_cloud.py icons).", "return {"]
    lines += [f"\t{k} = {v}," for k, v in sorted(old.items())]
    lines.append("}")
    open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print(f"uploaded {len(done)} icons")


def lua_list(path, var):
    """read id/name/desc/price entries of DonateConfig.<var>"""
    s = open(path, encoding="utf-8").read()
    block = s[s.index(f"DonateConfig.{var} = {{"):]
    block = block[: block.index("\n}\n")]
    out = []
    for m in re.finditer(r'id = "(\w+)".*?name = "([^"]+)", desc = "([^"]+)", price = (\d+)', block):
        out.append(dict(id=m.group(1), name=m.group(2), desc=m.group(3), price=int(m.group(4))))
    return out


def create_products(args):
    cfg = os.path.join(SHARED, "DonateConfig.lua")
    u = args.universe
    prods, passes = {}, {}
    # re-runs are safe: items that already have an id in ProductIds.lua are skipped (no duplicates on Roblox)
    have = {m.group(1): int(m.group(2)) for m in re.finditer(r"(\w+) = (\d+)", open(os.path.join(SHARED, "ProductIds.lua"), encoding="utf-8").read())}
    for it in lua_list(cfg, "Products"):
        if have.get(it["id"], 0) > 0:
            continue
        body, hdr = multipart({"name": it["name"], "description": it["desc"], "price": str(it["price"]), "isForSale": "true"}, {})
        st, res = request("POST", f"{API}/developer-products/v2/universes/{u}/developer-products", body, hdr)
        pid = res.get("productId") or res.get("id")
        print(f"  product {it['id']}: {st} {pid or res}")
        if pid:
            prods[it["id"]] = int(pid)
    for it in lua_list(cfg, "Passes"):
        if have.get(it["id"], 0) > 0:
            continue
        body, hdr = multipart({"name": it["name"], "description": it["desc"], "price": str(it["price"]), "isForSale": "true"}, {})
        st, res = request("POST", f"{API}/game-passes/v1/universes/{u}/game-passes", body, hdr)
        gid = res.get("gamePassId") or res.get("id")
        print(f"  pass {it['id']}: {st} {gid or res}")
        if gid:
            passes[it["id"]] = int(gid)
    write_ids(os.path.join(SHARED, "ProductIds.lua"), "products", {**prods, **passes})
    print(f"created {len(prods)} products, {len(passes)} passes")


def publish_place(args):
    """Upload CarHunters.rbxl as a new version of an existing place (Open Cloud Place Publishing)."""
    path = os.path.join(ROOT, "CarHunters.rbxl")
    if not os.path.exists(path):
        sys.exit("CarHunters.rbxl not found - run python3 tools/build_place.py first")
    newest_src = max(os.path.getmtime(os.path.join(d, f)) for d, _, fs in os.walk(os.path.join(ROOT, "src")) for f in fs)
    if os.path.getmtime(path) < newest_src:
        sys.exit("CarHunters.rbxl is older than src/ - run python3 tools/build_place.py first")
    data = open(path, "rb").read()
    url = f"{API}/universes/v1/{args.universe}/places/{args.place}/versions?versionType={args.version_type}"
    print(f"uploading {len(data) / 1e6:.1f} MB to universe {args.universe}, place {args.place} ({args.version_type}) ...")
    st, res = request("POST", url, data, {"Content-Type": "application/octet-stream"}, timeout=600)
    if st == 200:
        print("published: version", res.get("versionNumber"))
    elif st in (401, 403):
        sys.exit(f"{st}: the API key lacks universe-places:write or this experience is not in its Access list\n{res}")
    else:
        sys.exit(f"publish failed ({st}): {res}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("what", choices=["sounds", "products", "models", "icons", "publish"])
    ap.add_argument("--creator-user", type=int)
    ap.add_argument("--creator-group", type=int)
    ap.add_argument("--universe", type=int)
    ap.add_argument("--place", type=int)
    ap.add_argument("--version-type", default="Published", choices=["Published", "Saved"])
    ap.add_argument("--only", help="comma-separated sound names to upload")
    a = ap.parse_args()
    if a.what == "icons":
        if not (a.creator_user or a.creator_group):
            sys.exit("need --creator-user or --creator-group")
        upload_icons(a)
    elif a.what == "models":
        if not (a.creator_user or a.creator_group):
            sys.exit("need --creator-user or --creator-group")
        upload_models(a)
    elif a.what == "sounds":
        if not (a.creator_user or a.creator_group):
            sys.exit("need --creator-user or --creator-group")
        upload_sounds(a)
    elif a.what == "publish":
        if not (a.universe and a.place):
            sys.exit("need --universe and --place")
        publish_place(a)
    else:
        if not a.universe:
            sys.exit("need --universe")
        create_products(a)
