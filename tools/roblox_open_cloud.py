"""Upload CAR HUNTERS sounds and create donation products through Roblox Open Cloud.

Usage:
  ROBLOX_API_KEY=... python3 tools/roblox_open_cloud.py sounds   --creator-user 123456      (or --creator-group 123)
  ROBLOX_API_KEY=... python3 tools/roblox_open_cloud.py products --universe 987654
The API key needs: Assets (read+write) for sounds; Developer Products + Game Passes (write) for products.
In a Claude cloud session the key is injected by the network proxy, so ROBLOX_API_KEY may be any placeholder.
Results are written into src/ReplicatedStorage/Shared/SoundIds.lua and ProductIds.lua; rebuild with tools/build_place.py.
"""
import argparse, json, os, re, sys, time, urllib.request, uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared")
API = "https://apis.roblox.com"
KEY = os.environ.get("ROBLOX_API_KEY", "proxy-injected")


def request(method, url, body=None, headers=None):
    h = {"x-api-key": KEY}
    h.update(headers or {})
    req = urllib.request.Request(url, data=body, method=method, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
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
    for it in lua_list(cfg, "Products"):
        body, hdr = multipart({"name": it["name"], "description": it["desc"], "price": str(it["price"]), "isForSale": "true"}, {})
        st, res = request("POST", f"{API}/developer-products/v2/universes/{u}/developer-products", body, hdr)
        pid = res.get("productId") or res.get("id")
        print(f"  product {it['id']}: {st} {pid or res}")
        if pid:
            prods[it["id"]] = int(pid)
    for it in lua_list(cfg, "Passes"):
        body, hdr = multipart({"name": it["name"], "description": it["desc"], "price": str(it["price"]), "isForSale": "true"}, {})
        st, res = request("POST", f"{API}/game-passes/v1/universes/{u}/game-passes", body, hdr)
        gid = res.get("gamePassId") or res.get("id")
        print(f"  pass {it['id']}: {st} {gid or res}")
        if gid:
            passes[it["id"]] = int(gid)
    write_ids(os.path.join(SHARED, "ProductIds.lua"), "products", {**prods, **passes})
    print(f"created {len(prods)} products, {len(passes)} passes")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("what", choices=["sounds", "products"])
    ap.add_argument("--creator-user", type=int)
    ap.add_argument("--creator-group", type=int)
    ap.add_argument("--universe", type=int)
    ap.add_argument("--only", help="comma-separated sound names to upload")
    a = ap.parse_args()
    if a.what == "sounds":
        if not (a.creator_user or a.creator_group):
            sys.exit("need --creator-user or --creator-group")
        upload_sounds(a)
    else:
        if not a.universe:
            sys.exit("need --universe")
        create_products(a)
