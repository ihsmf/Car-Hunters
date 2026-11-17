"""Build the 25 x 4 outfit table from the catalog searches, and a thumbnail contact sheet to check them."""
import json, sys, time, urllib.request, io, os

S = os.path.dirname(os.path.abspath(__file__))
c1 = json.load(open(os.path.join(S, "catalog.json")))["themes"]
c2 = json.load(open(os.path.join(S, "catalog2.json")))
hair = json.load(open(os.path.join(S, "hair.json")))
BAD = ("one piece", "naruto", "king von", "fnaf", "stitch", "lilo", "tanjiro", "zenitsu", "bleach", "balenciaga", "twice",
       "barbie", "lethal company", "free fire", "freefire", "agnes", "glitch-trap", "mm2", "dress", "skirt", "girl", "lyrab", "gin ichimaru",
       "sukamii", "kawaii", "kitty", "cat ")
THEME1 = {t["kw"]: t for t in c1}


def ok(x):
    return not any(b in x["name"].lower() for b in BAD)


PREFER = {("pharaoh", "hats"): ("headdress", "crown"), ("astronaut", "hats"): ("astronaut",), "hat_dominus": ("dominus empyreus", "fire dominus", "dominus"),
          ("hazmat", "hats"): ("gas", "mask")}


def pick(src):  # source: "key" from pass 2, or ("theme", field) from pass 1
    items = c2[src] if isinstance(src, str) else THEME1[src[0]][src[1]]
    items = [x for x in items if ok(x)]
    pref = PREFER.get(src if isinstance(src, str) else tuple(src), ())
    rank = lambda x: next((i for i, w in enumerate(pref) if w in x["name"].lower()), len(pref))
    items = [x for x in items if not pref or rank(x) < len(pref)] or items
    seen, out = set(), []
    for x in sorted(items, key=lambda x: (rank(x), -x["fav"])):  # preferred names first, then most favourited
        if x["name"].lower().strip() not in seen:
            seen.add(x["name"].lower().strip()); out.append(x["id"])
    return out


HAIRS = [hair[k][0]["id"] for k in ("brown hair", "black hair", "messy hair", "blonde hair", "white hair", "red hair") if hair[k]]
PLAN = [  # shirt, pants, head, extra (back / face accessory or None)
    (("casual", "shirts"), "pants_jeans", ("casual", "hats"), None),
    ("shirt_hoodie", "pants_black", ("hoodie", "hats"), ("hoodie", "face")),
    (("sniper", "shirts"), "pants_black", ("sniper", "hats"), ("sniper", "face")),
    ("shirt_vest", "pants_suit", "hat_tophat", ("tuxedo", "face")),
    ("shirt_royal", "pants_gold", "hat_crown", "back_cape"),
    ("shirt_dragon", "pants_armor", "hat_dragon", "back_dragon"),
    (("pharaoh", "shirts"), ("pharaoh", "pants"), ("pharaoh", "hats"), None),
    ("shirt_ice", "pants_white", "hat_icecrown", "back_ice"),
    ("shirt_fire", "pants_armor", "hat_fire", "back_fire"),
    (("hazmat", "shirts"), ("hazmat", "pants"), ("hazmat", "hats"), None),
    ("shirt_cyber", "pants_cyber", "hat_visor", None),
    ("shirt_captain", "pants_black", "hat_pirate", ("pirate", "face")),
    (("samurai", "shirts"), ("samurai", "pants"), ("samurai", "hats"), ("samurai", "back")),
    ("shirt_ninja", "pants_ninja", "hat_hood", None),
    ("shirt_angel", "pants_white", ("angel", "hats"), "back_angel"),
    ("shirt_demon", "pants_black", ("demon", "hats"), "back_demon"),
    ("shirt_knight", "pants_armor", "hat_valk", "back_gold"),
    ("shirt_wizard", "pants_galaxy", "hat_wizard", None),
    (("astronaut", "shirts"), ("astronaut", "pants"), ("astronaut", "hats"), None),
    ("shirt_galaxy", "pants_galaxy", "hat_galaxy", "back_galaxy"),
    (("rainbow", "shirts"), ("rainbow", "pants"), "hat_unicorn", None),
    (("scientist", "shirts"), ("scientist", "pants"), ("scientist", "hats"), None),
    ("shirt_hoodie", "pants_black", ("black hoodie", "hats"), None),
    ("shirt_cyber", "pants_galaxy", "hat_dominus", "back_galaxy"),
    ("shirt_gold", "pants_gold", "hat_dominus", "back_gold"),
]
out = []
for r, (sh, pa, hd, ex) in enumerate(PLAN):
    S_, P_, H_, E_ = pick(sh), pick(pa), pick(hd), pick(ex) if ex else []
    assert S_ and P_ and H_, (r, sh, pa, hd)
    variants = []
    for i in range(4):
        sh_i = S_[(i + (r == 23) * 2) % len(S_)]  # Glitch reuses cyber shirts: start further down the list
        variants.append(dict(shirt=sh_i, pants=P_[i % len(P_)], head=H_[i % len(H_)] if r != 23 else H_[min(2, len(H_) - 1)],
                             extra=E_[i % len(E_)] if E_ else 0, hair=HAIRS[(r + i) % len(HAIRS)]))
    out.append(variants)
json.dump(out, open(os.path.join(S, "outfits.json"), "w"))

if "--sheet" in sys.argv:  # contact sheet: one row per rarity, variant 1 items
    from PIL import Image
    ids = sorted({v[k] for row in out for v in row[:1] for k in ("shirt", "pants", "head", "extra") if v[k]})
    urls = {}
    for k in range(0, len(ids), 50):
        q = ",".join(map(str, ids[k:k + 50]))
        d = json.load(urllib.request.urlopen(f"https://thumbnails.roblox.com/v1/assets?assetIds={q}&size=150x150&format=Png", timeout=30))
        urls.update({x["targetId"]: x.get("imageUrl") for x in d["data"]})
        time.sleep(0.5)
    sheet = Image.new("RGB", (4 * 110, 25 * 110), (235, 240, 250))
    for r, row in enumerate(out):
        for c, key in enumerate(("shirt", "pants", "head", "extra")):
            u = urls.get(row[0][key])
            if not u:
                continue
            img = Image.open(io.BytesIO(urllib.request.urlopen(u, timeout=30).read())).convert("RGBA").resize((106, 106))
            sheet.paste(img, (c * 110 + 2, r * 110 + 2), img)
    sheet.save(os.path.join(S, "outfits.png"))
    missing = [i for i in ids if not urls.get(i)]
    print("thumbnails:", len(urls), "missing:", missing)
print("ok", len(out))
