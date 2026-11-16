"""Builds labelled contact sheets of Creator Store car models for every CarConfig id, so the most realistic model
can be picked by eye and written into CarStoreTool.Candidates by hand.
The real model names below are only search keywords for this dev tool; the game shows parody names.
  python3 tools/pick_store_cars.py [--out DIR] [--only id,id] [--per-image 3]
For each car: search the model words (no brand words: the toolbox filters them), then a class word as a fallback;
keep up to 12 Car/Vehicle models that have MeshParts and 15k-150k triangles; skip kits, chassis, toys, wrecks...
Writes DIR/<id>.png (current pick first, marked CURRENT), DIR/sheet_NN.png (several cars per image) and
DIR/candidates.json (id -> list of {id, name, tris, meshParts}).
  python3 tools/pick_store_cars.py --overview 3       # DIR/overview_N.png from the final Candidates (first id per car)
"""
import argparse, json, os, re, sys, time, urllib.parse, urllib.request

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(ROOT, "src", "ServerStorage", "Tools", "CarStoreTool.lua")
CONFIG = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "CarConfig.lua")
API = "https://apis.roblox.com/toolbox-service/v1"
THUMBS = "https://thumbnails.roblox.com/v1/assets"

# model words (brand words are filtered by the toolbox search), most specific first
MODEL = {
    "furd_fiasta": ["fiesta"], "dodje_caravon": ["grand caravan", "caravan", "minivan"], "furd_f150": ["f150", "f-150", "raptor"],
    "awdi_a4": ["a4", "rs4"], "bmv_m3": ["m3", "e46 m3"], "mursides_e": ["e class", "e63", "w213"], "tezla_model3": ["model 3"],
    "jagwar_xe": ["xe", "xf"], "furd_mustank": ["mustang", "gt500"], "dodje_chalenjer": ["challenger", "hellcat"],
    "ranje_rover": ["range rover", "rover"], "bmv_m4": ["m4", "m4 competition"], "mursides_g": ["g wagon", "g63", "g class"],
    "awdi_r8": ["r8"], "jagwar_ftype": ["f type", "f-type"], "mazeratti_gt": ["granturismo", "gran turismo"],
    "lamborgini_hurakan": ["huracan"], "tezla_cybertrak": ["cybertruck"], "mazeratti_mc20": ["mc20"],
    "lamborgini_aventadoor": ["aventador", "svj"], "fiat_500": ["500 abarth", "abarth", "cinquecento"],
    "mini_kooper": ["cooper s", "cooper"], "volksvagen_gulf": ["golf gti", "golf", "gti"], "hunda_civik": ["civic type r", "civic"],
    "jeap_rangler": ["wrangler"], "mazta_miyata": ["miata", "mx5", "mx-5"], "subaroo_wrx": ["wrx sti", "wrx", "impreza"],
    "chevy_kamaro": ["camaro"], "toyoda_supera": ["supra"], "chevy_korvette": ["corvette"], "nisan_gtr": ["gtr r35", "gt-r", "gtr"],
    "porshe_911": ["911 gt3", "911", "992"], "bentli_kontinental": ["continental gt", "continental"],
    "rolz_fantom": ["phantom", "ghost", "cullinan"], "maklaren_p1": ["p1"], "ferarri_488": ["488"],
    "ferarri_laferarri": ["laferrari", "la ferrari"], "pagany_wyra": ["zonda"], "konigseg_agera": ["agera"],
    "bugati_shiron": ["chiron"], "hunda_jazzy": ["jazz", "fit"], "toyoda_korolla": ["corolla"], "nisan_mikra": ["micra", "march"],
    "kia_soal": ["soul"], "hyunday_elantro": ["elantra"], "skodda_oktavia": ["octavia"], "shevy_spork": ["spark"],
    "volvoo_240": ["240", "240 wagon"], "toyoda_takoma": ["tacoma"], "furd_brongo": ["bronco"], "hunda_akkord": ["accord"],
    "volksvagen_bitle": ["beetle"], "awdi_tt": ["tt rs", "tt"], "lexxus_is": ["is350", "is300", "is f"],
    "dodje_ramm": ["ram 1500", "ram trx", "ram"], "mitsubishy_evo": ["lancer evo", "evolution", "lancer"], "nisan_350z": ["350z"],
    "bmv_x5": ["x5"], "kadillak_eskalade": ["escalade"], "toyoda_landkruiser": ["land cruiser", "landcruiser"],
    "shelbi_kobra": ["cobra 427", "cobra"], "pontiak_firebyrd": ["firebird", "trans am"], "porshe_kayen": ["cayenne"],
    "mursides_amg": ["amg gt"], "astin_db11": ["db11"], "lamborgini_uroos": ["urus"], "ferarri_romma": ["roma"],
    "porshe_taykun": ["taycan"], "maklaren_720": ["720s"], "awdi_rs6": ["rs6", "rs6 avant"], "bentli_bentaiga": ["bentayga"],
    "mursides_maibah": ["maybach", "s class"], "bugati_veiron": ["veyron"], "konigseg_jesko": ["jesko"], "ferarri_sf90": ["sf90"],
    "lamborgini_sian": ["sian"], "maklaren_senna": ["senna"], "astin_valkyry": ["valkyrie"], "pagany_huayrar": ["huayra"],
    "rimak_nevara": ["nevera"], "golden_magnat_gt": ["supercar"],
    "toyoda_priuz": ["prius"], "hunda_odysee": ["odyssey", "minivan"], "furd_fokus": ["focus rs", "focus"],
    "toyoda_kamry": ["camry"], "toyoda_rav4": ["rav4", "rav 4"], "furd_eksplorer": ["explorer"],
    "hunda_s2000": ["s2000", "s2k"], "kia_stingar": ["stinger"], "dodje_chardjer": ["charger", "charger srt"],
    "mazta_rx7": ["rx7", "rx-7", "fd rx7"], "nisan_skylain": ["skyline r34", "skyline", "r34"], "hunda_nsx": ["nsx"],
    "mursides_sls": ["sls amg", "sls"], "lexxus_lfa": ["lfa"], "dodje_vipur": ["viper", "viper acr"], "ferarri_f40": ["f40"],
    "porshe_918": ["918 spyder", "918"], "ferarri_enzo": ["enzo"], "lamborgini_revuelto": ["revuelto"],
    "konigseg_regera": ["regera"],
}
CLASS = {
    "compact": "hatchback", "sedan": "sedan", "sport": "sports car", "supercar": "supercar", "proto": "hypercar",
    "suv": "suv", "pickup": "pickup truck", "van": "minivan", "muscle": "muscle car",
}
SKIP = ("chassis", "kit", "fob", "police", "wreck", "toy", "lego")
KEEP = 12
MIN_TRIS, MAX_TRIS = 15000, 150000


def get(url):
    for _ in range(4):
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                return json.loads(r.read())
        except Exception:  # noqa: BLE001 - rate limits / timeouts: retry
            time.sleep(2)
    return {}


def details(ids):
    out = {}
    for i in range(0, len(ids), 30):
        part = ids[i : i + 30]
        res = get(f"{API}/items/details?assetIds={','.join(map(str, part))}")
        for item in res.get("data", []):
            a = item.get("asset", {})
            tech = a.get("modelTechnicalDetails") or {}
            out[a["id"]] = {
                "id": a["id"],
                "name": a.get("name", ""),
                "types": a.get("objectTypes") or [],
                "category": a.get("categoryPath") or "",
                "tris": (tech.get("objectMeshSummary") or {}).get("triangles") or 0,
                "meshParts": (tech.get("instanceCounts") or {}).get("meshPart") or 0,
                "scripts": (tech.get("instanceCounts") or {}).get("script") or 0,
            }
    return out


def acceptable(d):
    name = d["name"].lower()
    is_car = "Car" in d["types"] or "Vehicle" in d["types"] or (not d["types"] and d["category"] == "3d__vehicles")
    return (is_car and d["meshParts"] > 0 and MIN_TRIS <= d["tris"] <= MAX_TRIS
            and not any(re.search(rf"\b{w}", name) for w in SKIP))


def search(keyword, pages=2):
    ids, cursor = [], ""
    for _ in range(pages):
        url = f"{API}/marketplace/10?keyword={urllib.parse.quote(keyword)}&num=30" + (f"&cursor={urllib.parse.quote(cursor)}" if cursor else "")
        res = get(url)
        ids += [d["id"] for d in res.get("data", [])]
        cursor = res.get("nextPageCursor") or ""
        if not cursor:
            break
    return ids


def find(car_id, style, taken):
    found, seen = [], set(taken)
    keywords = [f"{m} car" for m in MODEL.get(car_id, [])] + MODEL.get(car_id, []) + [CLASS.get(style, "car")]
    for kw in keywords:
        if len(found) >= KEEP:
            break
        ids = [i for i in search(kw) if i not in seen]
        for d in details(ids).values():
            seen.add(d["id"])
            if acceptable(d) and len(found) < KEEP:
                d["query"] = kw
                found.append(d)
        time.sleep(0.3)
    return found


def cars():
    src = open(CONFIG, encoding="utf-8").read()
    return re.findall(r'id = "([a-z0-9_]+)", name = "[^"]+", rarity = "\w+", style = "(\w+)"', src)


def current():
    src = open(TOOL, encoding="utf-8").read()
    block = src[src.index("Tool.Candidates = {") :]
    block = block[: block.index("\n}\n")]
    return {k: [int(x) for x in re.findall(r"\d{5,}", v)] for k, v in re.findall(r"^\t(\w+) = \{([^}]*)\}", block, re.M)}


def thumbs(ids, folder):
    os.makedirs(folder, exist_ok=True)
    need = [i for i in ids if not os.path.exists(os.path.join(folder, f"{i}.png"))]
    for k in range(0, len(need), 50):
        part = need[k : k + 50]
        for _ in range(3):
            res = get(f"{THUMBS}?assetIds={','.join(map(str, part))}&size=420x420&format=Png")
            pending = [d for d in res.get("data", []) if d.get("state") == "Pending"]
            for d in res.get("data", []):
                if d.get("imageUrl") and d.get("state") == "Completed":
                    try:
                        with urllib.request.urlopen(d["imageUrl"], timeout=30) as r:
                            open(os.path.join(folder, f"{d['targetId']}.png"), "wb").write(r.read())
                    except Exception as e:  # noqa: BLE001
                        print("  thumb", d["targetId"], e)
            if not pending:
                break
            part = [d["targetId"] for d in pending]
            time.sleep(3)


FONT = None


def font(size):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


TILE, LABEL, COLS = 200, 34, 7


def tile(folder, d, mark=None):
    im = Image.new("RGB", (TILE, TILE + LABEL), (255, 255, 255))
    p = os.path.join(folder, f"{d['id']}.png")
    if os.path.exists(p):
        t = Image.open(p).convert("RGBA")
        bg = Image.new("RGBA", t.size, (235, 238, 242, 255))
        bg.alpha_composite(t)
        im.paste(bg.convert("RGB").resize((TILE, TILE)), (0, 0))
        blank = t.getchannel("A").getextrema()[1] == 0
    else:
        blank = True
    dr = ImageDraw.Draw(im)
    if blank:
        dr.text((40, TILE // 2), "(no thumbnail)", fill=(150, 0, 0), font=font(14))
    dr.text((3, TILE + 1), str(d["id"]), fill=(0, 0, 0), font=font(13))
    dr.text((3, TILE + 17), f"{d.get('tris', 0) // 1000}k tri {d.get('meshParts', 0)}mp", fill=(60, 60, 60), font=font(12))
    if mark:
        dr.rectangle([0, 0, TILE - 1, 22], fill=(200, 20, 30))
        dr.text((4, 3), mark, fill=(255, 255, 255), font=font(14))
        dr.rectangle([0, 0, TILE - 1, TILE + LABEL - 1], outline=(200, 20, 30), width=3)
    return im


def car_block(folder, title, entries):
    rows = (len(entries) + COLS - 1) // COLS or 1
    im = Image.new("RGB", (COLS * TILE + (COLS - 1) * 4, 30 + rows * (TILE + LABEL + 4)), (255, 255, 255))
    ImageDraw.Draw(im).text((4, 4), title, fill=(0, 0, 0), font=font(18))
    for n, (d, mark) in enumerate(entries):
        im.paste(tile(folder, d, mark), ((n % COLS) * (TILE + 4), 30 + (n // COLS) * (TILE + LABEL + 4)))
    return im


def stack(blocks):
    w = max(b.width for b in blocks)
    im = Image.new("RGB", (w, sum(b.height + 10 for b in blocks)), (180, 180, 180))
    y = 0
    for b in blocks:
        im.paste(b, (0, y))
        y += b.height + 10
    return im


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "store_cars"))
    ap.add_argument("--only", default="")
    ap.add_argument("--per-image", type=int, default=3)
    ap.add_argument("--overview", default="", help="number of overview images to write from the final Candidates")
    a = ap.parse_args()
    folder = os.path.join(a.out, "thumbs")
    cur = current()
    all_cars = cars()
    if a.overview:
        n = int(a.overview)
        picks = [(cid, cur.get(cid, [0])[0]) for cid, _ in all_cars]
        info = details([p for _, p in picks])
        thumbs([p for _, p in picks], folder)
        cols, per = 7, (len(picks) + n - 1) // n
        for k in range(n):
            chunk = picks[k * per : (k + 1) * per]
            rows = (len(chunk) + cols - 1) // cols
            im = Image.new("RGB", (cols * (TILE + 4), rows * (TILE + LABEL + 22)), (255, 255, 255))
            for j, (cid, pid) in enumerate(chunk):
                d = dict(info.get(pid, {"id": pid}))
                t = tile(folder, d)
                x, y = (j % cols) * (TILE + 4), (j // cols) * (TILE + LABEL + 22)
                im.paste(t, (x, y + 20))
                ImageDraw.Draw(im).text((x + 3, y + 2), cid, fill=(0, 0, 160), font=font(15))
            p = os.path.join(a.out, f"overview_{k + 1}.png")
            im.save(p)
            print("wrote", p)
        return
    only = set(filter(None, a.only.split(",")))
    cache_path = os.path.join(a.out, "candidates.json")
    os.makedirs(a.out, exist_ok=True)
    cache = json.load(open(cache_path)) if os.path.exists(cache_path) else {}
    blocks, sheet = [], 1
    for cid, style in all_cars:
        if only and cid not in only:
            continue
        if cid not in cache:
            cache[cid] = find(cid, style, cur.get(cid, []))
            json.dump(cache, open(cache_path, "w"), indent=1)
        old = cur.get(cid, [])
        oinfo = details(old) if old else {}
        entries = [(oinfo.get(i, {"id": i}), "CURRENT" if n == 0 else f"backup {n}") for n, i in enumerate(old)]
        entries += [(d, None) for d in cache[cid]]
        thumbs([d["id"] for d, _ in entries], folder)
        b = car_block(folder, f"{cid}  ({style})  queries: {', '.join(MODEL.get(cid, []))} / {CLASS.get(style)}", entries)
        b.save(os.path.join(a.out, f"{cid}.png"))
        print(f"{cid:22s} {len(cache[cid]):2d} found", flush=True)
        blocks.append(b)
        if len(blocks) == a.per_image:
            stack(blocks).save(os.path.join(a.out, f"sheet_{sheet:02d}.png"))
            blocks, sheet = [], sheet + 1
    if blocks:
        stack(blocks).save(os.path.join(a.out, f"sheet_{sheet:02d}.png"))


if __name__ == "__main__":
    sys.exit(main())
