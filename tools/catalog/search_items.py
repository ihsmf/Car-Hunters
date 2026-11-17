"""Second pass: relevance-sorted searches with precise keywords; prints candidates for manual curation."""
import json, time, urllib.request, urllib.parse, sys

OUT = sys.argv[1]
BAD = ("one piece", "naruto", "king von", "fnaf", "stitch", "lilo", "tanjiro", "zenitsu", "bleach", "balenciaga", "twice",
       "barbie", "lethal company", "free fire", "freefire", "agnes", "glitch-trap", "mm2", "dress", "skirt", "girl")
QUERIES = {  # name: (keyword, category, subcategory, asset types)
    "shirt_vest": ("vest suit", 3, 56, {11}), "shirt_tshirt": ("white t shirt jeans", 3, 56, {11}),
    "shirt_polo": ("polo shirt", 3, 56, {11}), "shirt_hoodie": ("black hoodie", 3, 56, {11}),
    "shirt_royal": ("royal robe", 3, 56, {11}), "shirt_dragon": ("dragon armor", 3, 56, {11}),
    "shirt_ice": ("ice armor", 3, 56, {11}), "shirt_fire": ("fire armor", 3, 56, {11}),
    "shirt_angel": ("angel armor", 3, 56, {11}), "shirt_demon": ("demon armor", 3, 56, {11}),
    "shirt_knight": ("knight armor", 3, 56, {11}), "shirt_galaxy": ("galaxy suit", 3, 56, {11}),
    "shirt_gold": ("gold suit", 3, 56, {11}), "shirt_cyber": ("cyborg", 3, 56, {11}), "shirt_ninja": ("ninja", 3, 56, {11}),
    "shirt_captain": ("pirate captain", 3, 56, {11}), "shirt_wizard": ("wizard robe", 3, 56, {11}),
    "pants_jeans": ("blue jeans", 3, 57, {12}), "pants_black": ("black pants", 3, 57, {12}), "pants_suit": ("suit pants", 3, 57, {12}),
    "pants_armor": ("armor pants", 3, 57, {12}), "pants_gold": ("gold pants", 3, 57, {12}), "pants_white": ("white pants", 3, 57, {12}),
    "pants_ninja": ("ninja pants", 3, 57, {12}), "pants_cyber": ("cyborg pants", 3, 57, {12}), "pants_galaxy": ("galaxy pants", 3, 57, {12}),
    "hat_pirate": ("pirate captain hat", 11, None, {8}), "hat_tophat": ("top hat", 11, None, {8}), "hat_wizard": ("wizard hat", 11, None, {8}),
    "hat_crown": ("king crown", 11, None, {8}), "hat_icecrown": ("ice crown", 11, None, {8}), "hat_fedora": ("fedora", 11, None, {8}),
    "hat_ninja": ("ninja headband", 11, None, {8, 42}), "hat_hood": ("dark hood", 11, None, {8}), "hat_visor": ("cyber visor", 11, None, {8, 42}),
    "hat_dragon": ("dragon helmet", 11, None, {8}), "hat_fire": ("fire crown", 11, None, {8}), "hat_unicorn": ("unicorn horn", 11, None, {8}),
    "hat_galaxy": ("galaxy crown", 11, None, {8}), "hat_valk": ("valkyrie helm", 11, None, {8}), "hat_dominus": ("dominus", 11, None, {8}),
    "back_cape": ("royal cape", 11, None, {46}), "back_fire": ("fire wings", 11, None, {46}), "back_ice": ("ice wings", 11, None, {46}),
    "back_dragon": ("dragon wings", 11, None, {46}), "back_demon": ("demon wings", 11, None, {46}), "back_angel": ("angel wings", 11, None, {46}),
    "back_galaxy": ("galaxy wings", 11, None, {46}), "back_gold": ("golden wings", 11, None, {46}), "back_sword": ("sword back", 11, None, {46, 47}),
    "hair_m1": ("brown hair", 11, None, {41}), "hair_m2": ("black hair", 11, None, {41}), "hair_m3": ("messy hair", 11, None, {41}),
    "hair_m4": ("blonde hair", 11, None, {41}), "hair_m5": ("white hair", 11, None, {41}),
}


def search(kw, cat, sub, types):
    p = dict(Keyword=kw, Category=cat, Limit=30)
    if sub:
        p["Subcategory"] = sub
    time.sleep(0.6)
    try:
        url = "https://catalog.roblox.com/v1/search/items/details?" + urllib.parse.urlencode(p)
        with urllib.request.urlopen(url, timeout=20) as r:
            data = json.load(r)["data"]
    except Exception as e:
        print("  ! failed", kw, e)
        return []
    out = []
    for x in data:
        n = x["name"].lower()
        if x.get("itemType") == "Asset" and x["assetType"] in types and not any(b in n for b in BAD):
            out.append(dict(id=x["id"], type=x["assetType"], name=x["name"], fav=x.get("favoriteCount") or 0))
    return out[:8]


res = {k: search(*v) for k, v in QUERIES.items()}
json.dump(res, open(OUT, "w"), indent=1)
for k, v in res.items():
    print(k.ljust(14), " | ".join(f"{x['name'][:26]}" for x in v[:6]))
