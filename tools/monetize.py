"""Create (or update) the CUE HUNTERS Game Passes and Developer Products through Open Cloud, with the rendered icons,
and write their ids + prices + icon image ids into studio/src/Config.luau.
    python3 tools/monetize.py <universeId>
Icons: blender/export/icons/<Key>.png (blender/icons.py + tools/icon_text.py). Idempotent: offers are matched by name."""
import json, os, re, sys, time, urllib.request, uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, "studio", "src", "Config.luau")
ICONS = os.path.join(ROOT, "blender", "export", "icons")
API = "https://apis.roblox.com"
PASSES = [  # key, name, description, price (Robux)
    ("Cash2x", "x2 Cash", "Double income from every ball you own. Forever.", 150),
    ("Luck2x", "x2 Luck", "Every shot starts with double luck: rarer balls on every table.", 200),
    ("DragonCue", "Dragon Cue", "A blazing dragon cue: x3 luck on every ball until you own a better cue.", 149),
    ("GoldStick", "Income Boost", "+50% income from every ball you own.", 99),
    ("GoldenBall", "Golden Ball", "Your cue ball turns gold with a sparkling trail.", 49),
]
PRODUCTS = [("Pack1", "$5K Cash", "Instantly get $5,000.", 5, 5000), ("Pack2", "$50K Cash", "Instantly get $50,000.", 20, 50000),
            ("Pack3", "$500K Cash", "Instantly get $500,000.", 80, 500000)]


def call(url, data=None, ctype=None, method=None):
    h = {"x-api-key": "set-by-proxy"}
    if ctype:
        h["Content-Type"] = ctype
    for attempt in range(5):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, data=data, method=method, headers=h), timeout=120) as r:
                body = r.read()
                return json.loads(body) if body else {}
        except urllib.error.HTTPError as e:
            msg = e.read()[:400]
            if e.code in (429, 500, 502, 503):
                time.sleep(4 * (attempt + 1))
                continue
            raise RuntimeError(f"{method or 'GET'} {url}: {e.code} {msg!r}")
    raise RuntimeError("giving up " + url)


def form(fields, image):
    b = uuid.uuid4().hex
    out = b""
    for k, v in fields.items():
        out += f"--{b}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode()
    out += (f"--{b}\r\nContent-Disposition: form-data; name=\"imageFile\"; filename=\"icon.png\"\r\nContent-Type: image/png\r\n\r\n").encode()
    out += image + f"\r\n--{b}--\r\n".encode()
    return out, f"multipart/form-data; boundary={b}"


def main():
    u = sys.argv[1]
    have = {p["name"]: p for p in call(f"{API}/game-passes/v1/universes/{u}/game-passes?pageSize=50").get("gamePasses", [])}
    passes = {}
    for key, name, desc, price in PASSES:
        img = open(os.path.join(ICONS, key + ".png"), "rb").read()
        fields = {"name": name, "description": desc, "isForSale": "true", "price": str(price)}
        body, ct = form(fields, img)
        if name in have:
            gid = have[name]["id"]
            call(f"{API}/game-passes/v1/universes/{u}/game-passes/{gid}", body, ct, "PATCH")
        else:
            gid = call(f"{API}/game-passes/v1/universes/{u}/game-passes", body, ct, "POST")["gamePassId"]
        info = next((g for g in call(f"{API}/game-passes/v1/universes/{u}/game-passes?pageSize=50").get("gamePasses", []) if g["id"] == gid), {})
        passes[key] = (gid, price, info.get("displayIconImageAssetId") or 0)
        print("pass", key, gid, price, passes[key][2])
    have = {p["name"]: p for p in call(f"{API}/developer-products/v2/universes/{u}/developer-products/creator?pageSize=50").get("developerProducts", [])}
    products = []
    for key, name, desc, price, cash in PRODUCTS:
        img = open(os.path.join(ICONS, key + ".png"), "rb").read()
        fields = {"name": name, "description": desc, "isForSale": "true", "price": str(price)}
        body, ct = form(fields, img)
        if name in have:
            pid = have[name].get("productId") or have[name]["id"]
            call(f"{API}/developer-products/v2/universes/{u}/developer-products/{pid}", body, ct, "PATCH")
        else:
            pid = call(f"{API}/developer-products/v2/universes/{u}/developer-products", body, ct, "POST")["productId"]
        info = next((d for d in call(f"{API}/developer-products/v2/universes/{u}/developer-products/creator?pageSize=50").get("developerProducts", []) if (d.get("productId") or d.get("id")) == pid), {})
        products.append((pid, price, cash, info.get("iconImageAssetId") or info.get("displayIconImageAssetId") or 0))
        if not products[-1][3]:
            print("  product fields:", sorted(info))
        print("product", key, pid, price, products[-1][3])
    src = open(CONFIG, encoding="utf-8").read()
    for key, (gid, price, icon) in passes.items():
        src, n = re.subn(r'(\{ key = "' + key + r'", id = )\d+(, )(?:price = \d+, icon = \d+, )?', lambda m: f"{m.group(1)}{gid}{m.group(2)}price = {price}, icon = {icon}, ", src)
        assert n == 1, key
    block = "C.Products = {\n" + "".join(f"\t{{ id = {pid}, cash = {cash}, price = {price}, icon = {icon} }},\n" for pid, price, cash, icon in products) + "}"
    src, n = re.subn(r"C\.Products = \{\n(?:\t\{[^\n]*\},\n)+\}", block, src)
    assert n == 1
    open(CONFIG, "w", encoding="utf-8").write(src)
    json.dump({"passes": passes, "products": products}, open(os.path.join(ROOT, "tools", "monetize.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
