"""Check that every Roblox asset ID used by the game exists (sounds, animations, avatar items).
    python3 tools/catalog/verify_assets.py"""
import json, os, re, time, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
src = lambda p: open(os.path.join(ROOT, p), encoding="utf-8").read()
ids = {}
for name, i in re.findall(r'(\w+) = "rbxassetid://(\d+)"', src("src/shared/Config.luau")):
    ids[int(i)] = ("Sound " + name, 3)
for f in ("src/server/Main.server.luau", "src/client/Throw.client.luau", "src/client/UI.client.luau"):
    for i in re.findall(r'"rbxassetid://(\d+)"', src(f)):
        ids.setdefault(int(i), ("Animation", 24))
av = src("src/shared/Avatars.luau")
for k, i in re.findall(r"(shirt|pants) = (\d+)", av):
    ids[int(i)] = (k, 11 if k == "shirt" else 12)
for i, t in re.findall(r"\{ (\d+), (\d+) \}", av):
    ids[int(i)] = ("accessory", int(t))

bad = []
for i, (what, want) in sorted(ids.items(), key=lambda x: x[1][0]):
    time.sleep(0.35)
    try:
        d = json.load(urllib.request.urlopen(f"https://economy.roblox.com/v2/assets/{i}/details", timeout=20))
        ok = d.get("AssetTypeId") == want
        print(("OK  " if ok else "TYPE") + f" {what:14} {i}  {d.get('Name', '')[:40]}  (type {d.get('AssetTypeId')})")
        if not ok:
            bad.append(i)
    except Exception as e:
        print(f"FAIL {what:14} {i}  {e}")
        bad.append(i)
print(f"\n{len(ids)} assets checked, {len(bad)} problems: {bad}")
