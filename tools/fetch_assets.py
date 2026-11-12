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
    return f"{len(data) // 1024} KB"


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
    todo = models + [i for c in cars for i in c[: a.cars]]
    ok = bad = 0
    for i in todo:
        try:
            print(f"  {i}: {fetch(i)}")
            ok += 1
        except Exception as e:  # noqa: BLE001 - report and continue
            print(f"  ! {i}: {e}")
            bad += 1
        time.sleep(0.2)
    print(f"downloaded/cached {ok}, failed {bad}  ({len(models)} Blender models, {len(cars)} cars)")
    sys.exit(0 if ok else 1)
