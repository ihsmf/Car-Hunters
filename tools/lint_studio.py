"""Lint the scripts extracted from the Studio place: python3 tools/lint_studio.py"""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lint_luau as L

SRC = os.path.join(L.ROOT, "studio", "src")
cfg = open(os.path.join(SRC, "Config.luau"), encoding="utf-8").read()
keys = {"C": set(re.findall(r"^C\.(\w+)\s*=", cfg, re.M)) | set(re.findall(r"^function C\.(\w+)", cfg, re.M)) | {"Rarities", "Balls"},
        "UI": set(re.findall(r"^\t(\w+)\s*=", cfg[cfg.index("C.UI = {"):cfg.index("\n}\n", cfg.index("C.UI = {"))], re.M))}
bad = 0
for f in sorted(os.listdir(SRC)):
    errs = L.check(os.path.join(SRC, f), keys)
    bad += len(errs)
    print(("OK   " if not errs else "FAIL ") + f)
    for e in errs[:40]:
        print("     " + e)
sys.exit(1 if bad else 0)
