"""Upload the outlined UI icons (blender/export/icons/<Name>_ol.png) as Roblox images; ids -> tools/ui_icons.json."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import meshassets
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "blender", "export", "icons")
NAMES = {"Cash": "MenuCash", "Strength": "MenuGym", "Settings": "MenuSettings", "Inventory": "MenuInventory", "Bonus": "MenuBonus",
         "Shop": "MenuShop", "Cues": "MenuCues", "Luck": "Luck2x"}
meshassets.CREATOR[0] = sys.argv[1]
out = {}
for key, f in NAMES.items():
    out[key] = meshassets.upload_image("CH_UI_" + key, open(os.path.join(D, f + "_ol.png"), "rb").read())
    print(key, out[key], flush=True)
json.dump(out, open(os.path.join(ROOT, "tools", "ui_icons.json"), "w"), indent=1)
