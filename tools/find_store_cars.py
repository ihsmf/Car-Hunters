"""Find free Creator Store car models for CarConfig ids and write them into CarStoreTool.Candidates.
The real model names below are only search keywords for this dev tool; the game shows parody names.
  python3 tools/find_store_cars.py            # fills ids that have no candidates yet
"""
import json, os, re, sys, time, urllib.parse, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(ROOT, "src", "ServerStorage", "Tools", "CarStoreTool.lua")
API = "https://apis.roblox.com/toolbox-service/v1"

SEARCH = {
    "hunda_jazzy": "honda fit", "toyoda_korolla": "toyota corolla", "nisan_mikra": "nissan micra", "kia_soal": "kia soul",
    "hyunday_elantro": "hyundai elantra", "skodda_oktavia": "skoda octavia", "shevy_spork": "chevrolet spark", "volvoo_240": "volvo 240",
    "toyoda_takoma": "toyota tacoma", "furd_brongo": "ford bronco", "hunda_akkord": "honda accord", "volksvagen_bitle": "volkswagen beetle",
    "awdi_tt": "audi tt", "lexxus_is": "lexus is", "dodje_ramm": "dodge ram", "mitsubishy_evo": "mitsubishi lancer evo",
    "nisan_350z": "nissan 350z", "bmv_x5": "bmw x5 suv", "kadillak_eskalade": "cadillac escalade", "toyoda_landkruiser": "toyota land cruiser",
    "shelbi_kobra": "shelby cobra", "pontiak_firebyrd": "pontiac firebird", "porshe_kayen": "porsche cayenne", "mursides_amg": "mercedes amg gt",
    "astin_db11": "db11", "lamborgini_uroos": "urus", "ferarri_romma": "roma", "porshe_taykun": "porsche taycan",
    "maklaren_720": "mclaren 720s", "awdi_rs6": "audi rs6", "bentli_bentaiga": "bentley bentayga", "mursides_maibah": "maybach",
    "bugati_veiron": "bugatti veyron", "konigseg_jesko": "koenigsegg jesko", "ferarri_sf90": "ferrari sf90", "lamborgini_sian": "sian",
    "maklaren_senna": "mclaren senna", "astin_valkyry": "valkyrie", "pagany_huayrar": "pagani huayra", "rimak_nevara": "nevera",
}


def get(url):
    for _ in range(3):
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                return json.loads(r.read())
        except Exception:
            time.sleep(1.5)
    return {}


def candidates(keyword):
    res = get(f"{API}/marketplace/10?keyword={urllib.parse.quote(keyword)}&num=30")
    ids = [d["id"] for d in res.get("data", [])][:30]
    if not ids:
        return []
    det = get(f"{API}/items/details?assetIds={','.join(map(str, ids))}")
    words = [w for w in keyword.lower().split() if len(w) > 2]
    scored = []
    for item in det.get("data", []):
        a = item.get("asset", {})
        name = a.get("name", "").lower()
        tech = (a.get("modelTechnicalDetails") or {})
        tris = (tech.get("objectMeshSummary") or {}).get("triangles", 0)
        counts = tech.get("instanceCounts") or {}
        types = a.get("objectTypes") or []
        if "Car" not in types and "Vehicle" not in types:
            continue
        if not all(w in name for w in words[-1:]):  # model word must be in the title
            continue
        if tris == 0 or tris > 120000 or counts.get("meshPart", 0) == 0:
            continue
        v = item.get("voting") or {}
        score = (v.get("upVotes", 0) + 1) / (v.get("voteCount", 0) + 2) + (0.3 if (item.get("creator") or {}).get("isVerifiedCreator") else 0)
        scored.append((score, a["id"]))
    scored.sort(reverse=True)
    return [i for _, i in scored[:3]]


def main():
    src = open(TOOL, encoding="utf-8").read()
    added = []
    for cid, kw in SEARCH.items():
        if re.search(rf"\b{cid} = \{{", src):
            continue
        ids = candidates(kw)
        print(f"{cid:22s} {kw:26s} -> {ids}")
        if ids:
            added.append(f"\t{cid} = {{ {', '.join(map(str, ids))} }},")
        time.sleep(0.3)
    if added:
        anchor = "Tool.Candidates = {\n"
        i = src.index(anchor) + len(anchor)
        src = src[:i] + "\n".join(added) + "\n" + src[i:]
        open(TOOL, "w", encoding="utf-8").write(src)
    print(f"added candidates for {len(added)} cars")


if __name__ == "__main__":
    main()
