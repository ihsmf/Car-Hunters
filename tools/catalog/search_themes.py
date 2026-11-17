"""Collect real Roblox catalog items (read-only public search) for the 25 character themes."""
import json, time, urllib.request, urllib.parse, sys

OUT = sys.argv[1]
THEMES = [  # shirt/pants keyword, hat keyword, back keyword (or None), face-accessory keyword (or None)
    ("casual", "baseball cap", None, None), ("hoodie", "beanie", None, "sunglasses"), ("sniper", "headset", None, "aviators"),
    ("tuxedo", "top hat", None, "monocle"), ("king", "crown", "cape", None), ("dragon", "dragon horns", "dragon wings", None),
    ("pharaoh", "pharaoh", None, None), ("winter", "ice crown", None, None), ("fire", "flame", "phoenix wings", None),
    ("hazmat", "gas mask", None, None), ("cyber", "cyber", None, "visor"), ("pirate", "pirate hat", None, "eyepatch"),
    ("samurai", "samurai", "katana", None), ("ghost", "hood", None, None), ("angel", "halo", "angel wings", None),
    ("demon", "demon horns", "demon wings", None), ("celestial", "celestial", "wings", None), ("wizard", "wizard hat", None, None),
    ("astronaut", "astronaut helmet", None, None), ("galaxy", "galaxy", "cape", None), ("rainbow", "unicorn", None, None),
    ("scientist", "goggles", None, None), ("black hoodie", "mask", None, None), ("glitch", "glitch", None, None),
    ("gold suit", "gold crown", "golden wings", None),
]


def search(kw, cat, sub=None, types=None, n=4):
    p = dict(Keyword=kw, Category=cat, Limit=30, SortType=1)
    if sub:
        p["Subcategory"] = sub
    url = "https://catalog.roblox.com/v1/search/items/details?" + urllib.parse.urlencode(p)
    time.sleep(0.6)
    try:
        with urllib.request.urlopen(url, timeout=20) as r:
            data = json.load(r)["data"]
    except Exception as e:
        print("  ! search failed:", kw, cat, sub, e)
        return []
    out = [dict(id=x["id"], type=x["assetType"], name=x["name"], fav=x.get("favoriteCount") or 0)
           for x in data if x.get("itemType") == "Asset" and (types is None or x["assetType"] in types)]
    out.sort(key=lambda x: -x["fav"])
    return out[:n]


result = {"themes": [], "hair": []}
for kw, hat, back, face in THEMES:
    t = dict(kw=kw, shirts=search(kw, 3, 56, {11}), pants=search(kw, 3, 57, {12}),
             hats=search(hat, 11, None, {8, 41, 42}), back=search(back, 11, None, {46, 44, 45, 47}, 2) if back else [],
             face=search(face, 11, 21, {42}, 2) if face else [])
    print(kw, {k: len(v) for k, v in t.items() if k != "kw"})
    result["themes"].append(t)
for kw in ("hair", "messy hair", "long hair", "curly hair"):
    result["hair"] += search(kw, 11, None, {41}, 4)
json.dump(result, open(OUT, "w"), indent=1)
print("hair:", len(result["hair"]))
