"""Player-base plaza decor (blender/plaza.py models): replaces the block-built cue shop kiosks, adds gym corners,
leaves the gym and its dumbbell untouched, turns the flat "BILLIARD CLUB" / bay number / bullet lettering into 3D Blender signs. Idempotent; used by studio.py pack.
Old parts are hidden (Transparency 1, SurfaceGuis disabled), colliders stay solid."""
import math, re
import xml.etree.ElementTree as ET
import hall, studio

KEEP = {"Collider", "Zone", "FenceCollider"}


def nm(i):
    for c in i.find("Properties"):
        if c.get("name") == "Name":
            return c.text
    return ""


def prop(i, k):
    for c in i.find("Properties"):
        if c.get("name") == k:
            return c
    return None


def pos(i):
    cf = prop(i, "CFrame")
    return [float(cf.find(k).text) for k in "XYZ"]


def hide(item):
    for d in item.iter("Item"):
        if d.get("class") in ("Part", "MeshPart", "WedgePart", "UnionOperation") and nm(d) not in KEEP:
            t = prop(d, "Transparency")
            if t is None:
                t = ET.SubElement(d.find("Properties"), "float", {"name": "Transparency"})
            t.text = "1"
        if d.get("class") in ("SurfaceGui", "BillboardGui", "Decal"):
            e = prop(d, "Enabled")
            if d.get("class") == "Decal":
                tt = prop(d, "Transparency") or ET.SubElement(d.find("Properties"), "float", {"name": "Transparency"})
                tt.text = "1"
            else:
                if e is None:
                    e = ET.SubElement(d.find("Properties"), "bool", {"name": "Enabled"})
                e.text = "false"


def child(parent, name):
    return next((c for c in parent.findall("Item") if nm(c) == name), None)


def apply(x):
    old = x.find('<Item class="Folder" referent="RBXPlaza0">')
    if old != -1:
        x = x[:old] + x[studio.item_end(x, old):]
    ws = x.find('<Item class="Workspace"')
    we = studio.item_end(x, ws)
    tree = ET.fromstring(x[ws:we])
    world = next(i for i in tree.iter("Item") if nm(i) == "World")
    hall.ref = iter(range(10 ** 7))
    deco = hall.I("Folder", "PlazaDecor")

    def place(mesh, at, yaw, scale=1.0):
        pv = hall.part(deco, (0.2, 0.2, 0.2), hall.cf(at[0], at[1], at[2], yaw), (255, 255, 255), transparency=1, name="MeshPivot")
        hall.tag(pv, mesh, scale if scale != 1 else None)

    def yaw_to(dx, dz):  # yaw so the model's +X points along (dx, dz)
        return math.atan2(-dz, dx)

    for b in [c for c in world.findall("Item") if re.fullmatch(r"Base\d", nm(c) or "")]:
        kiosk, pad, table, gym, shop = (child(b, n) for n in ("Kiosk", "ShopPad", "PoolTable", "Gym", "CueShop"))
        counter = next(i for i in kiosk.iter("Item") if nm(i) == "Countertop")
        cp = pos(counter)
        pc = pos(next(i for i in pad.iter("Item") if nm(i) == "Zone"))
        d = (pc[0] - cp[0], pc[2] - cp[2])
        L = math.hypot(*d)
        f = (d[0] / L, d[1] / L)
        place("PlazaCueShop", (cp[0] - f[0] * 1.6, 0.25, cp[2] - f[1] * 1.6), yaw_to(*f))
        # table capacity sign left of the table, facing the walkway; CapFace<n> carries the client's SurfaceGui
        felt = next(i for i in table.iter("Item") if nm(i) == "Felt")
        tp = pos(felt)
        sx, sz = tp[0] - 10.5, 8.0
        place("PlazaCapSign", (sx, 0.45, sz), yaw_to(0, 1))
        hall.part(deco, (7.2, 4.4, 0.1), hall.cf(sx, 6.45, sz + 0.5), (20, 100, 70), transparency=1, name="CapFace" + nm(b)[4:])
        hide(kiosk)
        if shop is not None:
            hide(shop)
    club = child(world, "EmeraldClub")
    face_plaza = yaw_to(0, 1)  # the back wall faces +Z
    for i in list(club.iter("Item")):
        n, cls = nm(i), i.get("class")
        if cls != "Part":
            continue
        if n == "BILLIARD CLUB":
            p = pos(i)
            place("PlazaClubSign", (p[0], p[1], p[2] + 0.1), face_plaza, 1.0)
            hide(i)
        elif n in ("1", "2", "3", "4"):  # one bay number per base: the winged plaque up high; the small one -> gem
            p = pos(i)
            if p[1] > 15:
                place("PlazaBay" + n, (p[0], p[1], p[2] + 0.05), face_plaza, 1.45)
            else:
                place("PlazaGem", (p[0], p[1], p[2] + 0.05), face_plaza, 0.9)
            hide(i)
        elif n == "•":
            p = pos(i)
            place("PlazaGem", (p[0], p[1], p[2] + 0.05), face_plaza, 0.9)
            hide(i)
    new = hall.xml(deco).replace("RBXHall", "RBXPlazaD").replace('referent="RBXPlazaD0"', 'referent="RBXPlaza0"', 1)
    body = ET.tostring(tree, encoding="unicode")
    x = x[:ws] + body + x[we:]
    w = re.search(r'<Item class="Folder" referent="[^"]*"><Properties><string name="Name">World</string></Properties>', x)
    return x[:w.end()] + new + x[w.end():]
