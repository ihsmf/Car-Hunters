"""Publish studio/CueHunters.rbxlx to an existing Roblox experience via Open Cloud.
    python3 tools/publish.py <universeId> <placeId>
The API key (scope universe-places:write) is never stored here: the session's network proxy adds the x-api-key
header for apis.roblox.com. A new experience is private until you make it public in the Creator Dashboard."""
import json, os, sys, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
universe, place = sys.argv[1], sys.argv[2]
assert universe.isdigit() and place.isdigit(), "universeId and placeId are numbers"
data = open(os.path.join(ROOT, "studio", "CueHunters.rbxlx"), "rb").read()
req = urllib.request.Request(
    f"https://apis.roblox.com/universes/v1/{universe}/places/{place}/versions?versionType=Published",
    data=data, method="POST", headers={"Content-Type": "application/xml", "x-api-key": "set-by-proxy"})
with urllib.request.urlopen(req, timeout=300) as r:
    print("published version", json.load(r).get("versionNumber"))
