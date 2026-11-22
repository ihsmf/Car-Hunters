"""Lightweight Luau checker (no external tools): python3 tools/lint_luau.py
- block balance (function/if/do/repeat vs end/until) and bracket balance
- names used but never declared (typos), minus Roblox/Luau globals
- C.<key> / C.UI.<key> / U.<key> accesses that don't exist in Config.luau"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GLOBALS = set("""game workspace script Instance Vector3 Vector2 CFrame Color3 UDim2 UDim Enum TweenInfo ColorSequence
ColorSequenceKeypoint NumberSequence NumberSequenceKeypoint NumberRange Random Font Content math string table os task
typeof type pairs ipairs next print warn error pcall xpcall tostring tonumber select require setmetatable getmetatable
rawget rawset rawequal _G unpack bit32 utf8 coroutine tick time debug buffer PhysicalProperties Ray RaycastParams
BrickColor DateTime self assert""".split())
KEYWORDS = set("and break do else elseif end false for function if in local nil not or repeat return then true until while continue".split())
TOKEN = re.compile(r"""
 (?P<lcomment>--\[(?P<eq1>=*)\[.*?\](?P=eq1)\]) |
 (?P<comment>--[^\n]*) |
 (?P<lstring>\[(?P<eq2>=*)\[.*?\](?P=eq2)\]) |
 (?P<string>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'|`(?:\\.|[^`\\])*`) |
 (?P<number>0[xX][0-9a-fA-F_]+|\d[\d_]*\.?\d*(?:[eE][+-]?\d+)?|\.\d+) |
 (?P<name>[A-Za-z_][A-Za-z0-9_]*) |
 (?P<op>\.\.\.|\.\.=?|[=~<>]=|//=?|[+\-*/%^]=|::|->|[{}()\[\];:,.=<>#+\-*/%^]) |
 (?P<ws>\s+) |
 (?P<bad>.)
""", re.S | re.X)


def tokens(src):
    out, line = [], 1
    for m in TOKEN.finditer(src):
        kind = m.lastgroup if m.lastgroup not in ("eq1", "eq2") else None
        for k in ("lcomment", "comment", "lstring", "string", "number", "name", "op", "ws", "bad"):
            if m.group(k) is not None:
                kind = k
                break
        text = m.group(0)
        if kind not in ("ws", "comment", "lcomment"):
            out.append((kind, text, line))
        line += text.count("\n")
    return out


EXPR_PREV = {"=", "(", ",", "{", "return", "and", "or", "..", "+", "-", "*", "/", "not", "["}  # "if" here is an if-expression


def check(path, cfg_keys):
    src = open(path, encoding="utf-8").read()
    toks = tokens(src)
    errs = []
    stack = []
    pairs_ = {"(": ")", "[": "]", "{": "}"}
    declared = set()
    for i, (k, t, ln) in enumerate(toks):
        prev = toks[i - 1][1] if i else ""
        if k == "bad":
            errs.append(f"{ln}: unexpected character {t!r}")
        if k == "op" and t in pairs_:
            stack.append((t, ln))
        elif k == "op" and t in pairs_.values():
            if not stack or pairs_.get(stack[-1][0]) != t:
                errs.append(f"{ln}: unbalanced {t!r}")
            else:
                stack.pop()
        elif k == "name" and (t in ("function", "do", "repeat") or (t == "if" and prev not in EXPR_PREV)):
            stack.append((t, ln))
        elif k == "name" and t in ("end", "until"):
            want = "repeat" if t == "until" else None
            if not stack or stack[-1][0] in pairs_:
                errs.append(f"{ln}: '{t}' without an open block")
            else:
                top = stack.pop()
                if (want and top[0] != "repeat") or (not want and top[0] == "repeat"):
                    errs.append(f"{ln}: '{t}' closes '{top[0]}' from line {top[1]}")
        # declarations
        if k == "name" and prev in ("local", "function", "for", ",", "(") and t not in KEYWORDS:
            declared.add(t)
        if k == "name" and prev == "function" and i + 1 < len(toks) and toks[i + 1][1] in (".", ":"):
            declared.add(t)
    for t, ln in stack:
        errs.append(f"{ln}: '{t}' is never closed")
    # undeclared names
    for i, (k, t, ln) in enumerate(toks):
        if k != "name" or t in KEYWORDS or t in GLOBALS or t in declared:
            continue
        prev = toks[i - 1][1] if i else ""
        nxt = toks[i + 1][1] if i + 1 < len(toks) else ""
        if prev in (".", ":", "::") or (nxt == "=" and prev in ("{", ",", ";")):
            continue
        errs.append(f"{ln}: undeclared name '{t}'")
    # Config key checks
    for i in range(len(toks) - 2):
        a, dot, b = toks[i], toks[i + 1], toks[i + 2]
        if dot[1] != "." or b[0] != "name":
            continue
        if a[1] == "C" and (i == 0 or toks[i - 1][1] != ".") and b[1] not in cfg_keys["C"]:
            errs.append(f"{b[2]}: Config has no C.{b[1]}")
        if a[1] == "UI" and i > 1 and toks[i - 1][1] == "." and toks[i - 2][1] == "C" and b[1] not in cfg_keys["UI"]:
            errs.append(f"{b[2]}: Config has no C.UI.{b[1]}")
        if a[1] == "U" and "local U = C.UI" in src and b[1] not in cfg_keys["UI"]:
            errs.append(f"{b[2]}: Config has no C.UI.{b[1]} (via U)")
    return errs


def config_keys():
    src = open(os.path.join(ROOT, "src/shared/Config.luau"), encoding="utf-8").read()
    c = set(re.findall(r"^C\.(\w+)\s*=", src, re.M)) | set(re.findall(r"^function C\.(\w+)", src, re.M))
    c |= {"Rarities", "Balls"}  # assigned as "C.Rarities, C.Balls = {}, {}"
    ui_block = src[src.index("C.UI = {"):src.index("\n}\n", src.index("C.UI = {"))]
    ui = set(re.findall(r"^\t(\w+)\s*=", ui_block, re.M))
    return {"C": c, "UI": ui}


if __name__ == "__main__":
    keys = config_keys()
    bad = 0
    for d, _, files in os.walk(os.path.join(ROOT, "src")):
        for f in sorted(files):
            if f.endswith(".luau") and not d.endswith("Meshes"):
                p = os.path.join(d, f)
                errs = check(p, keys)
                bad += len(errs)
                print(("OK   " if not errs else "FAIL ") + os.path.relpath(p, ROOT))
                for e in errs:
                    print("     " + e)
    # client <-> server contract: every action the client calls exists, every Fx kind the server fires is handled
    rd = lambda f: open(os.path.join(ROOT, f), encoding="utf-8").read()
    server = rd("src/server/Main.server.luau")
    client = "".join(rd("src/client/" + f) for f in sorted(os.listdir(os.path.join(ROOT, "src/client"))))
    actions = set(re.findall(r"function actions\.(\w+)", server))
    called = set(re.findall(r'(?:InvokeServer|call)\("(\w+)"', client))
    for a, b in re.findall(r'call\([\w.]+ and "(\w+)" or "(\w+)"\)', client):  # call(cond and "A" or "B")
        called |= {a, b}
    for a in sorted(called - actions):
        print(f"FAIL client calls unknown server action '{a}'"); bad += 1
    fired = set(re.findall(r'Fire(?:All)?Clients?\((?:plr, )?"(\w+)"', server))
    handled = set(re.findall(r'kind [=~]= "(\w+)"', client))
    for k in sorted(fired - handled):
        print(f"FAIL server fires '{k}' but no client handles it"); bad += 1
    print(f"contract: {len(called)} client actions, {len(fired)} server events checked")
    sys.exit(1 if bad else 0)
