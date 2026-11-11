"""CAR HUNTERS - car models for Roblox, built in Blender (bpy). Generator v2.

Run:  blender -b -P blender/make_cars.py     (or: python3 blender/make_cars.py with `pip install bpy`)
      args after "--":  norender | notraffic | <car ids...>
Out:  assets/cars/cars_collection.fbx (20 collectible cars), assets/cars/cars_traffic.fbx (11 traffic kinds),
      assets/cars/<id>.fbx, docs/renders/*.png
Cars are *inspired by* real-world body styles and design cues. No logos, badges or real names are modelled.
Convention: nose +X, wheels on the ground plane. Parts are split by look:
Body, Glass, Trim, Stripe, Chrome, Tire, Rim, Caliper, HeadLight, TailLight, Cargo
(ServerStorage.Tools.CarModelTool.ApplyImported maps them to Roblox materials).
"""
import math, os, sys
import bpy, bmesh
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "cars")
RENDERS = os.path.join(ROOT, "docs", "renders")
os.makedirs(OUT, exist_ok=True)
os.makedirs(RENDERS, exist_ok=True)

# ---------------------------------------------------------------- dimensions (studs) = VehicleKinds.lua
KINDS = {
    "compact": dict(L=11.5, W=5.8, H=4.6, wr=1.2, clear=0.7), "sedan": dict(L=14.5, W=6.2, H=4.7, wr=1.3, clear=0.8),
    "taxi": dict(L=14.5, W=6.2, H=4.7, wr=1.3, clear=0.8), "van": dict(L=14.5, W=6.6, H=6.6, wr=1.4, clear=0.9),
    "minibus": dict(L=18, W=6.8, H=7.0, wr=1.4, clear=0.9), "sport": dict(L=14.8, W=6.6, H=3.9, wr=1.25, clear=0.55),
    "supercar": dict(L=15.2, W=7.0, H=3.5, wr=1.25, clear=0.45), "pickup": dict(L=16.5, W=6.6, H=5.6, wr=1.5, clear=1.0),
    "service": dict(L=15.5, W=6.6, H=6.2, wr=1.4, clear=0.9), "truck": dict(L=26, W=7.6, H=8.8, wr=2.0, clear=1.4),
    "proto": dict(L=15.8, W=7.0, H=3.7, wr=1.25, clear=0.5), "suv": dict(L=15.5, W=6.8, H=6.2, wr=1.5, clear=1.0),
    "muscle": dict(L=16.0, W=6.8, H=4.5, wr=1.35, clear=0.7),
}

def rgb(r, g, b):
    return (r / 255, g / 255, b / 255, 1)

# ---------------------------------------------------------------- fascia shapes (unit size, centred)
def s_rr(rad=0.3, n=4):
    pts = []
    for cx, cy, a0 in ((0.5 - rad, 0.5 - rad, 0), (-0.5 + rad, 0.5 - rad, 90), (-0.5 + rad, -0.5 + rad, 180), (0.5 - rad, -0.5 + rad, 270)):
        for k in range(n + 1):
            a = math.radians(a0 + 90 * k / n)
            pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
    return pts

def s_el(n=18):
    return [(0.5 * math.cos(2 * math.pi * k / n), 0.5 * math.sin(2 * math.pi * k / n)) for k in range(n)]

def s_hex(c=0.3):
    return [(0.5, 0), (c, 0.5), (-c, 0.5), (-0.5, 0), (-c, -0.5), (c, -0.5)]

def s_trap(k=0.7):  # k = bottom width / top width
    return [(0.5, 0.5), (-0.5, 0.5), (-0.5 * k, -0.5), (0.5 * k, -0.5)]

def s_slant(sk=0.3):  # outer (+u) edge raised by sk
    return [(0.5, 0.5 + sk), (-0.5, 0.5), (-0.5, -0.5), (0.5, -0.5 + sk)]

def s_wedge(sk=0.6):  # thin at inner end, tall at outer end
    return [(0.5, 0.5), (-0.5, 0.5 - sk), (-0.5, -0.5 + sk * 0.2), (0.5, -0.5)]

RR, EL, HEX = s_rr(), s_el(), s_hex()

def it(mat, shape, cu, cv, su, sv, depth=0.07, frame=None):
    return dict(mat=mat, shape=shape, cu=cu, cv=cv, su=su, sv=sv, depth=depth, frame=frame)

PLATE = it("Plate", s_rr(0.1, 1), 0, 0.3, 0.3, 0.16, 0.04)

# ---------------------------------------------------------------- body families
def base(**kw):
    d = dict(sm=0.02, psm=0.03, box=0.75, tumble=0.74, edge=0.14, belt=[(0, 0.60), (1, 0.56)], axle=(0.19, 0.82),
             plan=[(0, 0.80), (0.04, 0.96), (0.25, 1), (0.75, 1), (0.95, 0.95), (1, 0.78)], pillars=[], doors=[],
             roof="body", spokes=5, rim=0.74, wheel=1.0, front=[], rear=[], extras={}, stripes=None, pillar_mat="Body")
    d.update(kw)
    return d

def sedan(**kw):
    d = base(top=[(0, .52), (.02, .62), (.13, .66), (.30, .98), (.40, 1.0), (.56, .97), (.72, .64), (.96, .58), (1, .46)],
             cab=(.13, .30, .56, .72), side=(.25, .69), pillars=[.45], doors=[.27, .45, .66])
    d.update(kw)
    return d

def coupe(**kw):
    d = base(top=[(0, .54), (.03, .66), (.11, .70), (.33, .98), (.46, .98), (.62, .66), (.96, .60), (1, .46)],
             cab=(.11, .33, .46, .62), side=(.30, .59), pillars=[], doors=[.36, .56], tumble=0.72)
    d.update(kw)
    return d

def mid(**kw):  # mid-engine supercar
    d = base(top=[(0, .60), (.03, .72), (.26, .82), (.42, 1.0), (.52, 1.0), (.74, .58), (.96, .42), (1, .32)],
             cab=(.26, .42, .52, .74), side=(.40, .70), doors=[.42, .66], tumble=0.66, belt=[(0, .66), (.5, .64), (1, .40)],
             plan=[(0, .84), (.04, .99), (.3, 1), (.62, .97), (.92, .93), (1, .72)], axle=(.18, .81), rim=0.8, spokes=10, wheel=0.9,
             extras={"intake": True, "caliper": (1, 0.8, 0.05, 1)})
    d.update(kw)
    return d

def suv(**kw):
    d = base(top=[(0, .50), (.015, .90), (.06, .99), (.58, 1.0), (.70, .66), (.97, .63), (1, .52)],
             cab=(.015, .06, .58, .70), side=(.05, .68), pillars=[.24, .45], doors=[.24, .45, .65], tumble=0.84, box=0.55,
             belt=[(0, .62), (1, .60)], plan=[(0, .90), (.03, .99), (.5, 1), (.96, .98), (1, .88)], axle=(.17, .82), rim=0.68)
    d.update(kw)
    return d

# ---------------------------------------------------------------- the 20 collectibles
G_LOWER = it("Trim", s_trap(0.8), 0, 0.14, 1.3, 0.2)
CARS = {
    # ---- Common
    "furd_fiasta": dict(kind="compact", color=rgb(40, 110, 220), spec=base(
        top=[(0, .50), (.02, .84), (.10, .99), (.50, .98), (.72, .62), (.95, .56), (1, .44)], cab=(.02, .10, .50, .72),
        side=(.09, .69), pillars=[.26, .46], doors=[.26, .46, .66], axle=(.17, .82), tumble=0.78,
        front=[it("Trim", s_hex(0.36), 0, .40, .95, .42, frame="Chrome"), it("HeadLight", s_slant(.5), .72, .86, .5, .2), G_LOWER],
        rear=[it("TailLight", RR, .80, .86, .22, .36), PLATE])),
    "dodje_caravon": dict(kind="van", color=rgb(150, 30, 40), spec=base(
        top=[(0, .44), (.015, .88), (.07, .99), (.62, .98), (.82, .56), (.97, .50), (1, .40)], cab=(.015, .07, .62, .82),
        side=(.06, .79), pillars=[.24, .46, .66], doors=[.24, .46, .66], axle=(.17, .82), tumble=0.86, box=0.55,
        belt=[(0, .54), (1, .50)], plan=[(0, .90), (.03, .99), (.5, 1), (.94, .97), (1, .82)],
        front=[it("Trim", s_rr(.2), 0, .62, 1.0, .26, frame="Chrome"), it("HeadLight", s_slant(.25), .74, .66, .44, .26), G_LOWER],
        rear=[it("TailLight", s_rr(.2), .86, .62, .16, .5), PLATE])),
    "furd_f150": dict(kind="pickup", color=rgb(190, 196, 204), spec=base(
        top=[(0, .58), (.01, .64), (.37, .64), (.385, .98), (.44, 1.0), (.60, .98), (.69, .68), (.98, .66), (1, .58)],
        cab=(.37, .385, .60, .69), side=(.40, .67), pillars=[.52], doors=[.40, .52, .65], axle=(.17, .83), tumble=0.86,
        box=0.45, edge=0.08, sm=0.006, belt=[(0, .62), (1, .62)], plan=[(0, .94), (.02, 1), (.97, 1), (1, .92)], rim=0.66,
        top_trim=(.03, .355),
        front=[it("Trim", s_rr(.12), 0, .62, 1.05, .62, frame="Chrome"), it("Chrome", s_rr(.1), 0, .62, 1.0, .1, .1),
               it("HeadLight", s_rr(.15), .80, .68, .3, .5), it("Trim", RR, 0, .1, 1.5, .14)],
        rear=[it("TailLight", s_rr(.15), .88, .62, .14, .56), it("Trim", RR, 0, .08, 1.7, .14), PLATE],
        extras={"flare": "Trim"})),
    "awdi_a4": dict(kind="sedan", color=rgb(196, 200, 206), spec=sedan(
        front=[it("Trim", s_hex(0.38), 0, .46, .78, .70, frame="Chrome"), it("HeadLight", s_slant(.2), .70, .80, .48, .2),
               it("Trim", s_trap(.6), .74, .22, .34, .26)],
        rear=[it("TailLight", s_slant(.1), .68, .80, .56, .16), it("TailLight", RR, 0, .82, .8, .05), PLATE])),
    # ---- Uncommon
    "bmv_m3": dict(kind="sedan", color=rgb(30, 90, 190), spec=sedan(
        front=[it("Trim", s_rr(.35), .17, .58, .30, .40, frame="Chrome"), it("HeadLight", s_slant(.12), .66, .76, .50, .2),
               it("Trim", s_trap(.7), 0, .16, .7, .22), it("Trim", s_slant(.3), .76, .2, .3, .24)],
        rear=[it("TailLight", s_wedge(.5), .68, .80, .56, .24), PLATE, it("Chrome", EL, .5, .08, .12, .12), it("Chrome", EL, .66, .08, .12, .12)],
        extras={"lip": True})),
    "mursides_e": dict(kind="sedan", color=rgb(20, 20, 24), spec=sedan(
        top=[(0, .52), (.02, .62), (.14, .66), (.30, .98), (.40, 1.0), (.55, .97), (.70, .64), (.96, .59), (1, .46)],
        cab=(.14, .30, .55, .70), side=(.25, .67),
        front=[it("Trim", s_trap(.8), 0, .52, .70, .48, frame="Chrome"), it("Chrome", RR, 0, .52, .66, .07, .1),
               it("Chrome", EL, 0, .52, .2, .3, .12), it("HeadLight", s_slant(.25), .70, .76, .44, .24), it("Trim", s_trap(.6), .72, .18, .4, .2)],
        rear=[it("TailLight", s_rr(.4), .66, .80, .6, .2), it("Chrome", RR, 0, .62, 1.0, .04), PLATE])),
    "tezla_model3": dict(kind="sedan", color=rgb(236, 238, 242), spec=sedan(
        top=[(0, .56), (.02, .68), (.09, .72), (.32, .99), (.50, .98), (.71, .60), (.95, .52), (1, .42)],
        cab=(.09, .32, .50, .71), side=(.24, .68), pillars=[.44], doors=[.25, .44, .64], roof="glass", sm=0.03, spokes=10,
        front=[it("HeadLight", s_wedge(.7), .70, .80, .46, .3), it("Trim", s_trap(.8), 0, .12, 1.1, .16)],
        rear=[it("TailLight", s_wedge(.5), .70, .82, .5, .22), PLATE])),
    "jagwar_xe": dict(kind="sedan", color=rgb(16, 70, 50), spec=sedan(
        front=[it("Trim", s_rr(.45), 0, .50, .56, .46, frame="Chrome"), it("HeadLight", s_wedge(.6), .68, .80, .5, .2),
               it("Trim", s_trap(.6), .74, .2, .34, .24)],
        rear=[it("TailLight", s_wedge(.5), .68, .82, .56, .18), PLATE, it("Chrome", EL, .58, .08, .14, .12)])),
    # ---- Rare
    "furd_mustank": dict(kind="muscle", color=rgb(210, 40, 36), spec=coupe(
        top=[(0, .58), (.03, .68), (.09, .72), (.34, .98), (.44, .98), (.60, .68), (.96, .64), (1, .52)],
        cab=(.09, .34, .44, .60), side=(.26, .57), doors=[.36, .55], stripes=(13, 13), box=0.6,
        plan=[(0, .86), (.04, .98), (.3, 1), (.75, 1), (.95, .96), (1, .84)],
        front=[it("Trim", s_hex(0.4), 0, .50, 1.0, .46), it("HeadLight", s_slant(.2), .78, .62, .3, .3), it("Trim", s_trap(.7), 0, .12, 1.0, .14)],
        rear=[it("Trim", RR, 0, .72, 1.8, .34, .04)] + [it("TailLight", s_rr(.2), u, .72, .09, .28, .09) for u in (.52, .66, .80)] + [PLATE, it("Chrome", EL, .62, .06, .16, .14)],
        extras={"spoiler": "lip", "caliper": (0.8, 0.05, 0.05, 1)})),
    "dodje_chalenjer": dict(kind="muscle", color=rgb(255, 120, 20), spec=coupe(
        top=[(0, .62), (.02, .70), (.17, .72), (.29, .98), (.48, .98), (.60, .70), (.97, .68), (1, .58)],
        cab=(.17, .29, .48, .60), side=(.27, .58), doors=[.34, .56], stripes=(12, 13), box=0.45, edge=0.1, sm=0.012, tumble=0.76,
        belt=[(0, .64), (1, .62)], plan=[(0, .92), (.03, 1), (.97, 1), (1, .90)], axle=(.2, .83),
        front=[it("Trim", s_rr(.25), 0, .66, 1.86, .34)] + [it("HeadLight", EL, u, .66, .16, .26, .1) for u in (.58, .80)] + [it("Trim", s_trap(.8), 0, .16, 1.2, .2)],
        rear=[it("TailLight", s_rr(.3), 0, .70, 1.84, .2, .06), it("Trim", s_rr(.3), 0, .70, 1.6, .08, .08), PLATE,
              it("Chrome", RR, .6, .06, .2, .1)],
        extras={"scoop": True, "spoiler": "lip", "caliper": (0.1, 0.1, 0.1, 1)})),
    "ranje_rover": dict(kind="suv", color=rgb(232, 232, 228), spec=suv(
        roof="black", pillar_mat="Trim", sm=0.012, edge=0.08,
        front=[it("Trim", s_rr(.2), 0, .78, .9, .2, frame="Chrome"), it("HeadLight", s_rr(.25), .74, .78, .42, .18),
               it("Trim", s_rr(.2), 0, .2, 1.2, .2), it("Chrome", RR, 0, .06, 1.0, .06)],
        rear=[it("TailLight", s_rr(.2), .88, .58, .1, .46), it("Trim", RR, 0, .70, 1.5, .08), PLATE, it("Chrome", RR, 0, .06, 1.0, .06)],
        extras={"gill": True})),
    "bmv_m4": dict(kind="sport", color=rgb(120, 190, 60), H=4.1, spec=coupe(
        front=[it("Trim", s_rr(.3), .17, .50, .30, .66, frame="Chrome"), it("HeadLight", s_slant(.12), .68, .78, .46, .18),
               it("Trim", s_slant(.3), .74, .24, .34, .3)],
        rear=[it("TailLight", s_wedge(.5), .68, .80, .56, .22), PLATE] + [it("Chrome", EL, u, .08, .11, .12) for u in (.42, .56)],
        extras={"spoiler": "lip", "caliper": (0.1, 0.3, 0.9, 1), "lip": True}, spokes=10)),
    # ---- Epic
    "mursides_g": dict(kind="suv", color=rgb(24, 26, 28), H=6.5, spec=suv(
        top=[(0, .48), (.008, .96), (.03, 1.0), (.61, 1.0), (.665, .64), (.985, .61), (1, .55)], cab=(.008, .03, .61, .665),
        side=(.04, .645), pillars=[.22, .44], doors=[.22, .44, .63], tumble=0.93, box=0.3, edge=0.05, sm=0.004, psm=0.008,
        belt=[(0, .60), (1, .59)], plan=[(0, .97), (.01, 1), (.99, 1), (1, .97)], axle=(.17, .82),
        front=[it("Trim", s_rr(.15), 0, .60, .62, .46, frame="Chrome")] + [it("Chrome", RR, 0, v, .58, .05, .1) for v in (.48, .60, .72)]
              + [it("HeadLight", EL, .70, .62, .3, .44, .1, frame="Chrome"), it("Trim", RR, 0, .1, 1.9, .16)],
        rear=[it("TailLight", RR, .82, .16, .26, .1), it("Trim", RR, 0, .1, 1.9, .14)],
        extras={"spare": True, "flare": "Trim", "indicators": True, "molding": True, "rails": True})),
    "awdi_r8": dict(kind="supercar", color=rgb(200, 204, 210), H=3.7, spec=mid(
        sm=0.022, pillar_mat="Trim",
        front=[it("Trim", s_hex(0.36), 0, .40, .74, .56), it("HeadLight", s_slant(.3), .72, .78, .42, .2), it("Trim", s_trap(.6), .72, .28, .4, .36)],
        rear=[it("TailLight", s_slant(.1), .66, .80, .6, .14), it("Trim", RR, 0, .46, 1.7, .26, .04), PLATE] + [it("Chrome", EL, u, .1, .2, .14) for u in (.7,)],
        extras={"intake": True, "caliper": (0.85, 0.05, 0.05, 1)})),
    "jagwar_ftype": dict(kind="sport", color=rgb(150, 20, 30), spec=coupe(
        top=[(0, .54), (.03, .66), (.08, .70), (.27, .97), (.38, .97), (.55, .66), (.94, .58), (1, .42)],
        cab=(.08, .27, .38, .55), side=(.22, .52), doors=[.30, .50], sm=0.028, tumble=0.68, axle=(.17, .80),
        front=[it("Trim", s_rr(.4), 0, .44, .66, .50, frame="Chrome"), it("HeadLight", s_wedge(.4), .76, .88, .3, .2), it("Trim", s_slant(.3), .76, .3, .3, .3)],
        rear=[it("TailLight", s_wedge(.7), .64, .80, .66, .14), PLATE] + [it("Chrome", EL, u, .1, .13, .14) for u in (.3, .44)],
        extras={"caliper": (0.85, 0.05, 0.05, 1)}, spokes=10)),
    "mazeratti_gt": dict(kind="sport", color=rgb(20, 40, 90), H=4.0, spec=coupe(
        top=[(0, .54), (.03, .66), (.12, .70), (.32, .98), (.44, .98), (.60, .66), (.95, .58), (1, .40)],
        cab=(.12, .32, .44, .60), side=(.27, .57), doors=[.34, .55], sm=0.028,
        front=[it("Trim", s_el(18), 0, .50, .62, .62, frame="Chrome")] + [it("Chrome", RR, u, .50, .03, .5, .1) for u in (-.18, -.09, 0, .09, .18)]
              + [it("HeadLight", s_wedge(.5), .72, .86, .4, .2), it("Trim", EL, .74, .28, .3, .26)],
        rear=[it("TailLight", s_wedge(.6), .68, .80, .56, .2), PLATE] + [it("Chrome", EL, u, .1, .12, .13) for u in (.5, .64)],
        extras={"vents": True, "caliper": (0.85, 0.05, 0.05, 1)}, spokes=10)),
    # ---- Legendary
    "lamborgini_hurakan": dict(kind="supercar", color=rgb(120, 220, 40), spec=mid(
        top=[(0, .58), (.03, .70), (.26, .82), (.44, 1.0), (.50, 1.0), (.76, .56), (.96, .38), (1, .30)], cab=(.26, .44, .50, .76),
        side=(.42, .72), sm=0.008, box=0.5, edge=0.1,
        front=[it("Trim", s_slant(.35), .58, .34, .7, .44), it("HeadLight", s_slant(.6), .76, .86, .36, .12), it("Trim", RR, 0, .1, .5, .12)],
        rear=[it("TailLight", s_slant(.25), .66, .82, .56, .08), it("Trim", s_hex(.42), 0, .50, 1.84, .36, .04), PLATE] + [it("Chrome", RR, u, .12, .16, .12) for u in (.5, .7)],
        extras={"intake": True, "caliper": (1, 0.8, 0.05, 1)})),
    "lamborgini_aventadoor": dict(kind="proto", color=rgb(255, 150, 10), spec=mid(
        top=[(0, .56), (.03, .70), (.30, .84), (.45, 1.0), (.50, 1.0), (.78, .52), (.97, .34), (1, .27)], cab=(.30, .45, .50, .78),
        side=(.43, .74), sm=0.006, box=0.45, edge=0.1, axle=(.19, .80),
        front=[it("Trim", s_slant(.5), .60, .36, .66, .5), it("HeadLight", s_slant(.5), .74, .88, .4, .1), it("HeadLight", s_slant(-.5), .74, .78, .3, .08)],
        rear=[it("TailLight", s_slant(.3), .70, .84, .44, .07), it("TailLight", s_slant(-.3), .70, .76, .34, .06), it("Trim", s_hex(.42), 0, .46, 1.84, .4, .04),
              it("Chrome", s_hex(.3), 0, .18, .4, .2, .1)],
        extras={"intake": True, "wing": True, "caliper": (0.1, 0.1, 0.1, 1)})),
    "tezla_cybertrak": dict(kind="pickup", color=rgb(176, 180, 186), L=17, H=5.6, spec=base(
        top=[(0, .64), (.01, .68), (.56, 1.0), (.60, 1.0), (.99, .52), (1, .46)], cab=(.30, .56, .60, .82),
        side=(.40, .80), pillars=[.60], doors=[.42, .60, .78], axle=(.17, .82), tumble=0.80, box=0.25, edge=0.04, sm=0.003, psm=0.006,
        belt=[(0, .63), (1, .50)], plan=[(0, .96), (.015, 1), (.985, 1), (1, .96)], rim=0.6, rearglass=False, spokes=6, metal=True,
        front=[it("HeadLight", RR, 0, .92, 1.9, .07), it("Trim", RR, 0, .18, 1.9, .3)],
        rear=[it("TailLight", RR, 0, .90, 1.9, .06), it("Trim", RR, 0, .14, 1.9, .22)],
        extras={"flare": "Trim"})),
    "mazeratti_mc20": dict(kind="supercar", color=rgb(240, 240, 236), H=3.7, spec=mid(
        sm=0.026, tumble=0.64,
        front=[it("Trim", s_el(18), 0, .34, .7, .44)] + [it("Chrome", RR, u, .34, .03, .34, .1) for u in (-.14, 0, .14)]
              + [it("HeadLight", s_wedge(.3), .78, .9, .26, .22), it("Trim", EL, .7, .26, .3, .24)],
        rear=[it("TailLight", s_wedge(.7), .66, .82, .6, .12), it("Trim", RR, 0, .44, 1.6, .26, .04), PLATE] + [it("Chrome", EL, u, .5, .14, .2) for u in (.1,)],
        extras={"intake": True, "caliper": (0.1, 0.2, 0.8, 1)})),
}

G_BOX = dict(top=[(0, .48), (.008, .96), (.03, 1.0), (.61, 1.0), (.665, .64), (.985, .61), (1, .55)], cab=(.008, .03, .61, .665),
             side=(.04, .645), pillars=[.22, .44], doors=[.22, .44, .63], tumble=0.93, box=0.3, edge=0.05, sm=0.004, psm=0.008,
             belt=[(0, .60), (1, .59)], plan=[(0, .97), (.01, 1), (.99, 1), (1, .97)], axle=(.17, .82))
HATCH = dict(top=[(0, .50), (.02, .84), (.10, .99), (.50, .98), (.72, .62), (.95, .56), (1, .44)], cab=(.02, .10, .50, .72),
             side=(.09, .69), pillars=[.40], doors=[.40, .66], axle=(.18, .82), tumble=0.78)
MID2 = dict(top=[(0, .58), (.03, .70), (.26, .82), (.44, 1.0), (.50, 1.0), (.76, .56), (.96, .38), (1, .30)], cab=(.26, .44, .50, .76), side=(.42, .72))
EX2 = [it("Chrome", EL, .5, .1, .13, .14), it("Chrome", EL, .66, .1, .13, .14)]
CARS.update({
    # ---- Common
    "fiat_500": dict(kind="compact", L=10.2, color=rgb(150, 220, 190), spec=base(**HATCH, sm=0.035, roof="contrast",
        front=[it("HeadLight", EL, .66, .80, .28, .30, frame="Chrome"), it("HeadLight", EL, .70, .46, .16, .16), it("Chrome", RR, 0, .62, .5, .05, .1), it("Trim", s_trap(.8), 0, .16, .9, .2)],
        rear=[it("TailLight", s_rr(.4), .82, .70, .2, .4), PLATE])),
    "mini_kooper": dict(kind="compact", L=10.8, color=rgb(200, 30, 40), spec=base(**HATCH, roof="contrast", box=0.5, sm=0.012, edge=0.08, stripes=(13, 13),
        front=[it("Trim", s_hex(.4), 0, .44, .7, .5, frame="Chrome"), it("HeadLight", EL, .72, .78, .3, .36, frame="Chrome"), it("HeadLight", EL, .5, .2, .12, .14)],
        rear=[it("TailLight", s_rr(.3), .84, .64, .16, .44, frame="Chrome"), PLATE, it("Chrome", EL, 0, .08, .12, .12)])),
    "volksvagen_gulf": dict(kind="compact", color=rgb(236, 236, 236), spec=base(**HATCH,
        front=[it("Trim", s_rr(.3), 0, .74, 1.0, .14), it("TailLight", RR, 0, .66, 1.0, .025, .09), it("HeadLight", s_slant(.15), .74, .76, .44, .2), it("Trim", s_trap(.8), 0, .22, 1.3, .26)],
        rear=[it("TailLight", s_wedge(.4), .76, .80, .4, .2), PLATE] + EX2, extras={"spoiler": "lip"})),
    "hunda_civik": dict(kind="sedan", color=rgb(250, 250, 250), spec=sedan(sm=0.014,
        front=[it("Trim", s_trap(.7), 0, .62, 1.3, .2), it("HeadLight", s_wedge(.6), .72, .74, .44, .18), it("Trim", s_hex(.4), 0, .22, .8, .3), it("Trim", s_slant(.3), .78, .22, .28, .3)],
        rear=[it("TailLight", s_wedge(.6), .7, .8, .5, .26), PLATE] + [it("Chrome", EL, u, .1, .1, .12) for u in (-.1, 0, .1)],
        extras={"wing": True, "lip": True, "caliper": (0.85, 0.05, 0.05, 1)})),
    # ---- Uncommon
    "jeap_rangler": dict(kind="suv", color=rgb(250, 190, 20), H=6.3, spec=suv(**G_BOX, roof="black", pillar_mat="Trim",
        front=[it("Trim", s_rr(.4), u, .64, .07, .4) for u in (-.36, -.24, -.12, 0, .12, .24, .36)] + [it("HeadLight", EL, .72, .66, .28, .42, .1), it("Trim", RR, 0, .1, 2.0, .18, .2)],
        rear=[it("TailLight", RR, .84, .5, .16, .2), it("Trim", RR, 0, .1, 2.0, .16, .2)],
        extras={"spare": True, "flare": "Trim", "indicators": True})),
    "mazta_miyata": dict(kind="sport", L=12.4, H=3.8, color=rgb(220, 30, 30), spec=coupe(roof="black", pillar_mat="Trim", sm=0.03,
        front=[it("Trim", EL, 0, .34, .8, .36), it("HeadLight", EL, .72, .84, .34, .2), it("HeadLight", EL, .78, .4, .12, .14)],
        rear=[it("TailLight", EL, .72, .76, .4, .26), PLATE, it("Chrome", EL, .5, .1, .13, .14)])),
    "subaroo_wrx": dict(kind="sedan", color=rgb(20, 70, 180), spec=sedan(sm=0.016,
        front=[it("Trim", s_hex(.38), 0, .58, .7, .36, frame="Chrome"), it("HeadLight", s_wedge(.5), .72, .74, .44, .22), it("Trim", s_trap(.8), 0, .16, .8, .2), it("HeadLight", EL, .78, .2, .14, .16)],
        rear=[it("TailLight", s_wedge(.5), .72, .8, .46, .24), PLATE] + EX2 + [it("Chrome", EL, -.5, .1, .13, .14), it("Chrome", EL, -.66, .1, .13, .14)],
        extras={"scoop": True, "wing": True})),
    "chevy_kamaro": dict(kind="muscle", color=rgb(255, 200, 0), spec=coupe(
        top=[(0, .62), (.02, .70), (.15, .72), (.29, .98), (.46, .98), (.60, .70), (.97, .66), (1, .56)], cab=(.15, .29, .46, .60),
        side=(.27, .58), doors=[.34, .56], stripes=(12, 13), box=0.5, edge=0.1, sm=0.014, tumble=0.70, belt=[(0, .66), (1, .64)],
        plan=[(0, .90), (.03, 1), (.96, 1), (1, .86)], axle=(.2, .83),
        front=[it("Trim", s_rr(.25), 0, .74, 1.86, .16), it("HeadLight", s_slant(.1), .76, .74, .3, .1, .1), it("Trim", s_hex(.42), 0, .30, 1.3, .44), it("HeadLight", RR, .8, .34, .16, .06)],
        rear=[it("TailLight", s_rr(.3), .62, .74, .26, .14), it("TailLight", s_rr(.3), .86, .74, .18, .14), PLATE, it("Chrome", RR, .6, .06, .2, .1)],
        extras={"spoiler": "lip", "caliper": (0.85, 0.05, 0.05, 1)})),
    # ---- Rare
    "toyoda_supera": dict(kind="sport", color=rgb(255, 110, 20), spec=coupe(sm=0.03, tumble=0.68,
        front=[it("Trim", s_trap(.7), 0, .28, .6, .4), it("Trim", s_slant(.3), .7, .26, .34, .34), it("HeadLight", s_wedge(.4), .7, .84, .44, .2)],
        rear=[it("Trim", RR, 0, .74, 1.8, .26, .04)] + [it("TailLight", EL, u, .74, .16, .22, .09) for u in (.48, .68, .86)] + [PLATE, it("Chrome", EL, .6, .08, .2, .16)],
        extras={"wing": True, "caliper": (0.1, 0.1, 0.1, 1)}, spokes=6)),
    "chevy_korvette": dict(kind="sport", color=rgb(210, 20, 30), spec=coupe(
        top=[(0, .54), (.03, .66), (.08, .70), (.27, .97), (.38, .97), (.55, .64), (.94, .56), (1, .40)],
        cab=(.08, .27, .38, .55), side=(.22, .52), doors=[.30, .50], sm=0.012, box=0.55, edge=0.1, tumble=0.66, axle=(.17, .80),
        front=[it("Trim", s_trap(.6), 0, .36, 1.0, .4), it("HeadLight", s_wedge(.7), .74, .84, .4, .2), it("Trim", RR, 0, .08, 1.5, .08)],
        rear=[it("TailLight", s_slant(.2), u, .78, .16, .18) for u in (.5, .76)] + [PLATE] + [it("Chrome", RR, u, .1, .1, .12) for u in (-.18, -.06, .06, .18)],
        extras={"spoiler": "lip", "caliper": (1, 0.8, 0.05, 1), "lip": True}, spokes=10)),
    "nisan_gtr": dict(kind="sport", H=4.2, color=rgb(236, 236, 240), spec=coupe(sm=0.012, box=0.5, edge=0.1, tumble=0.74,
        front=[it("Trim", s_hex(.4), 0, .36, 1.0, .56), it("HeadLight", s_slant(.8), .76, .86, .22, .2), it("HeadLight", RR, .7, .3, .2, .05)],
        rear=[it("TailLight", EL, u, .76, .17, .24, .09, frame="Trim") for u in (.52, .78)] + [PLATE] + EX2 + [it("Chrome", EL, -.5, .1, .13, .14), it("Chrome", EL, -.66, .1, .13, .14)],
        extras={"wing": True, "caliper": (1, 0.6, 0.05, 1), "lip": True}, spokes=6)),
    "porshe_911": dict(kind="sport", color=rgb(255, 200, 0), spec=coupe(
        top=[(0, .50), (.03, .62), (.12, .72), (.36, .98), (.48, .98), (.64, .64), (.94, .52), (1, .40)], cab=(.12, .36, .48, .64),
        side=(.28, .61), doors=[.38, .59], sm=0.034, tumble=0.66, axle=(.16, .80), plan=[(0, .84), (.05, .99), (.3, 1), (.7, .95), (.94, .9), (1, .74)],
        front=[it("HeadLight", EL, .72, .92, .3, .3), it("Trim", s_rr(.3), 0, .2, .7, .22), it("Trim", s_rr(.3), .72, .2, .36, .22), it("HeadLight", RR, .72, .36, .3, .04)],
        rear=[it("TailLight", s_rr(.4), 0, .82, 1.8, .07), it("Trim", s_rr(.2), 0, .62, 1.2, .16, .04), PLATE] + EX2 + [it("Chrome", EL, -.5, .1, .13, .14), it("Chrome", EL, -.66, .1, .13, .14)],
        extras={"spoiler": "lip", "caliper": (0.85, 0.05, 0.05, 1)}, spokes=10)),
    # ---- Epic
    "bentli_kontinental": dict(kind="sport", H=4.4, L=15.6, color=rgb(110, 16, 30), spec=coupe(sm=0.03,
        front=[it("Trim", s_rr(.2), 0, .52, .7, .6, frame="Chrome"), it("HeadLight", EL, .58, .76, .2, .3, frame="Chrome"), it("HeadLight", EL, .82, .78, .14, .22, frame="Chrome"), it("Trim", s_rr(.3), .7, .2, .4, .2)],
        rear=[it("TailLight", EL, .68, .76, .44, .2, frame="Chrome"), PLATE, it("Chrome", EL, .6, .1, .26, .14), it("Chrome", EL, -.6, .1, .26, .14)],
        extras={"vents": True}, spokes=10)),
    "rolz_fantom": dict(kind="sedan", L=17.5, H=5.3, W=6.6, color=rgb(240, 236, 222), spec=sedan(
        top=[(0, .54), (.02, .64), (.15, .66), (.24, .98), (.40, 1.0), (.56, .98), (.66, .66), (.97, .64), (1, .56)], cab=(.15, .24, .56, .66),
        side=(.22, .64), pillars=[.42], doors=[.24, .42, .62], sm=0.01, box=0.45, edge=0.08, tumble=0.84, stripes=(12, 14),
        belt=[(0, .62), (1, .60)], plan=[(0, .92), (.02, 1), (.97, 1), (1, .9)],
        front=[it("Chrome", s_rr(.08), 0, .56, .5, .78, .14)] + [it("Trim", RR, u, .54, .035, .64, .16) for u in (-.18, -.09, 0, .09, .18)]
              + [it("HeadLight", s_rr(.2), .7, .74, .36, .14), it("HeadLight", EL, .72, .5, .12, .16), it("Chrome", RR, 0, .1, 1.7, .08)],
        rear=[it("TailLight", s_rr(.3), .8, .66, .14, .34, frame="Chrome"), it("Chrome", RR, 0, .1, 1.7, .08), PLATE], spokes=10)),
    "maklaren_p1": dict(kind="supercar", color=rgb(0, 150, 200), spec=mid(sm=0.03, tumble=0.62, pillar_mat="Trim", roof="black",
        front=[it("HeadLight", s_wedge(.8), .7, .8, .44, .3), it("Trim", s_wedge(.6), .68, .56, .5, .2), it("Trim", s_trap(.7), 0, .18, .9, .2)],
        rear=[it("Trim", s_rr(.2), 0, .5, 1.84, .6, .04), it("TailLight", s_rr(.4), 0, .86, 1.7, .05, .08), it("Chrome", s_trap(.8), 0, .34, .26, .2, .1)],
        extras={"intake": True, "wing": True, "caliper": (1, 0.5, 0, 1)})),
    "ferarri_488": dict(kind="supercar", color=rgb(220, 16, 20), spec=mid(sm=0.026,
        front=[it("Trim", s_trap(.7), .46, .26, .6, .36), it("HeadLight", s_slant(1.2), .8, .84, .16, .22), it("Trim", RR, 0, .08, 1.2, .07)],
        rear=[it("TailLight", EL, .72, .78, .2, .3, .09, frame="Trim"), it("Trim", s_hex(.42), 0, .4, 1.5, .36, .04), PLATE] + [it("Chrome", EL, u, .34, .14, .18) for u in (.3,)],
        extras={"intake": True, "caliper": (1, 0.8, 0.05, 1)})),
    # ---- Legendary
    "ferarri_laferarri": dict(kind="proto", color=rgb(190, 0, 16), spec=mid(**MID2, sm=0.02, roof="black", pillar_mat="Trim", tumble=0.60,
        front=[it("Trim", s_trap(.6), 0, .3, .5, .44), it("Trim", s_slant(.4), .62, .3, .5, .4), it("HeadLight", s_slant(1.4), .82, .86, .14, .2)],
        rear=[it("TailLight", EL, .76, .8, .18, .26, .09), it("Trim", s_hex(.42), 0, .44, 1.7, .5, .04), it("TailLight", RR, 0, .3, .08, .2, .09)] + [it("Chrome", EL, u, .5, .14, .16) for u in (.34,)],
        extras={"intake": True, "caliper": (1, 0.8, 0.05, 1)})),
    "pagany_wyra": dict(kind="proto", color=rgb(120, 140, 165), spec=mid(sm=0.03, tumble=0.60, metal=True,
        front=[it("Trim", EL, 0, .3, .8, .36), it("HeadLight", EL, .7, .86, .12, .16), it("HeadLight", EL, .84, .8, .12, .16), it("Trim", EL, .74, .34, .26, .26)],
        rear=[it("TailLight", EL, .56, .8, .14, .2, .09), it("TailLight", EL, .76, .8, .14, .2, .09), it("TailLight", EL, .92, .76, .1, .14, .09), it("Trim", EL, 0, .42, 1.3, .5, .04)]
             + [it("Chrome", EL, u, v, .09, .13, .12) for u in (-.055, .055) for v in (.36, .5)],
        extras={"intake": True, "caliper": (0.6, 0.1, 0.1, 1)})),
    "konigseg_agera": dict(kind="proto", color=rgb(244, 244, 244), spec=mid(**MID2, sm=0.024, pillar_mat="Trim", tumble=0.58, stripes=(13, 13),
        front=[it("HeadLight", s_wedge(.5), .76, .82, .3, .3), it("Trim", s_trap(.7), 0, .24, .7, .3), it("Trim", EL, .72, .26, .3, .26)],
        rear=[it("TailLight", s_slant(.6), .74, .82, .36, .1), it("Trim", s_hex(.42), 0, .42, 1.8, .5, .04), it("Chrome", s_trap(.7), 0, .3, .3, .22, .1)],
        extras={"intake": True, "wing": True, "caliper": (0.1, 0.4, 0.9, 1)})),
    "bugati_shiron": dict(kind="proto", color=rgb(20, 70, 180), spec=mid(sm=0.034, roof="black", pillar_mat="Trim", tumble=0.64, stripes=(14, 14),
        plan=[(0, .88), (.04, 1), (.3, 1), (.62, .98), (.92, .95), (1, .78)],
        front=[it("Trim", EL, 0, .46, .3, .62, frame="Chrome")] + [it("HeadLight", s_rr(.3), u, .8, .09, .12) for u in (.5, .62, .74, .86)] + [it("Trim", s_rr(.3), .66, .3, .5, .3)],
        rear=[it("TailLight", s_rr(.4), 0, .84, 1.84, .07, .08), it("Trim", s_rr(.2), 0, .46, 1.84, .5, .04), it("Chrome", s_rr(.3), 0, .2, .5, .16, .1)],
        extras={"intake": True, "caliper": (0.2, 0.5, 1, 1)})),
})

# traffic kind -> (design id, overrides)
TRAFFIC = {
    "compact": ("furd_fiasta", {}), "sedan": ("awdi_a4", {}), "taxi": ("mursides_e", {"taxi": True}), "van": ("dodje_caravon", {}),
    "minibus": ("dodje_caravon", {"lightbar": False}), "sport": ("furd_mustank", {}), "supercar": ("lamborgini_hurakan", {}),
    "pickup": ("furd_f150", {}), "service": ("dodje_caravon", {"lightbar": True}), "truck": ("furd_f150", {"cargo": True}),
    "proto": ("mazeratti_mc20", {}),
}
TRAFFIC_COLOR = rgb(220, 60, 60)

# ---------------------------------------------------------------- blender helpers
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATS.clear()

MATS = {}
def mat(name, color, metal=0.0, rough=0.4, emit=None, alpha=1.0):
    key = (name, tuple(round(c, 3) for c in color))
    if key in MATS:
        return MATS[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if emit:
        bsdf.inputs["Emission Color"].default_value = emit
        bsdf.inputs["Emission Strength"].default_value = 2.5
    if alpha < 1:
        bsdf.inputs["Alpha"].default_value = alpha
    m.diffuse_color = color
    MATS[key] = m
    return m

def apply_mods(ob):
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.selected_objects:
        o.select_set(False)
    ob.select_set(True)
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)

def prim(kind, name, loc, size, rot=(0, 0, 0), verts=24):
    if kind == "box":
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=0.5, depth=1, location=loc, rotation=rot)
    elif kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.5, location=loc, rotation=rot)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return ob

def bevel(ob, w=0.15, seg=2):
    m = ob.modifiers.new("bv", "BEVEL")
    m.width = w
    m.segments = seg
    m.limit_method = "ANGLE"
    apply_mods(ob)

def set_mat(ob, m):
    ob.data.materials.clear()
    ob.data.materials.append(m)

def join(objs, name):
    objs = [o for o in objs if o]
    if not objs:
        return None
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = name
    return ob

def prism(name, pts_yz, x, depth):
    """extrude polygon (y,z) from x to x+depth"""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    a = [bm.verts.new((x, y, z)) for y, z in pts_yz]
    b = [bm.verts.new((x + depth, y, z)) for y, z in pts_yz]
    n = len(a)
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[j], a[i], b[i], b[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob

def lin(pts, f):
    if f <= pts[0][0]:
        return pts[0][1]
    for (a, ya), (b, yb) in zip(pts, pts[1:]):
        if a <= f <= b:
            return ya + (yb - ya) * (f - a) / max(b - a, 1e-9)
    return pts[-1][1]

def smo(pts, f, s):
    c = lambda v: min(1.0, max(0.0, v))
    return (lin(pts, c(f - s)) + 2 * lin(pts, f) + lin(pts, c(f + s))) / 4

# ---------------------------------------------------------------- car builder
NJ = 16  # points per half ring
MAT_IDX = {"Body": 0, "Glass": 1, "Trim": 2, "Stripe": 3}

def build_car(cid, design, color=None, low=False, over=None, dims=None):
    car = CARS[design]
    S = dict(car["spec"])
    S["extras"] = dict(S["extras"])
    S["extras"].update(over or {})
    ex = S["extras"]
    k = dict(KINDS[dims or car["kind"]])
    if not dims:
        k.update({n: car[n] for n in ("L", "H", "W") if n in car})
    L, W, H, clear = k["L"], k["W"], k["H"], k["clear"]
    wr = k["wr"] * S["wheel"]
    color = color or car["color"]
    x0 = -L / 2
    rg, rr, rf, wsb = S["cab"]
    sg0, sg1 = S["side"]
    beltmid = lin(S["belt"], 0.5) * H

    M = {
        "Body": mat("Body", color, metal=0.9 if S.get("metal") else 0.3, rough=0.35 if S.get("metal") else 0.25),
        "Glass": mat("Glass", (0.03, 0.05, 0.07, 1), rough=0.05),
        "Trim": mat("Trim", (0.03, 0.03, 0.035, 1), rough=0.55),
        "Stripe": mat("Stripe", (0.95, 0.95, 0.95, 1) if sum(color[:3]) < 1.9 else (0.04, 0.04, 0.05, 1), rough=0.3),
        "Chrome": mat("Chrome", (0.85, 0.86, 0.9, 1), metal=1, rough=0.1),
        "Tire": mat("Tire", (0.025, 0.025, 0.03, 1), rough=0.9),
        "Rim": mat("Rim", (0.7, 0.72, 0.76, 1), metal=1, rough=0.2),
        "Caliper": mat("Caliper", ex.get("caliper") or (0.3, 0.3, 0.3, 1), rough=0.4),
        "HeadLight": mat("HeadLight", (1, 0.97, 0.88, 1), emit=(1, 0.97, 0.88, 1)),
        "TailLight": mat("TailLight", (0.9, 0.04, 0.06, 1), emit=(1, 0.03, 0.06, 1)),
        "Plate": mat("Plate", (0.92, 0.92, 0.9, 1), rough=0.5),
        "Cargo": mat("Cargo", (0.94, 0.94, 0.96, 1), rough=0.5),
    }
    parts = {n: [] for n in M}

    def hwf(f):
        return smo(S["plan"], f, S["psm"]) * W / 2

    def ztop0(f):
        return smo(S["top"], f, S["sm"]) * H

    def bump(f):  # fenders always clear the wheels
        x = x0 + f * L
        d = min(abs(x - x0 - a * L) for a in S["axle"])
        R = wr * 1.16
        if d < R * 0.9:
            return wr + math.sqrt(R * R - d * d) + 0.28
        e = wr + math.sqrt(R * R * 0.19) + 0.28
        t = (d - R * 0.9) / (wr * 1.2)
        return e * (0.5 + 0.5 * math.cos(math.pi * t)) if t < 1 else 0.0

    ztop = ztop0

    def zbelt(f):
        return max(min(lin(S["belt"], f) * H, ztop0(f) - 0.035 * H), bump(f))

    def zbot(f):
        e = max(0.0, (abs(2 * f - 1) - 0.9) / 0.1)
        return clear + 0.12 * H * e * e

    def ring(f):
        hw, zt, zl, zb = hwf(f), ztop(f), zbelt(f), zbot(f)
        g = zt - zl
        r = min(1.0, max(0.0, g / max(H - beltmid, 0.1)))
        y0 = hw * 0.955
        rw = hw * (0.93 - (0.93 - S["tumble"]) * r)
        ze = zt - g * S["edge"]
        hs = zl - zb
        p = [(0, zb), (0.55 * hw, zb), (0.9 * hw, zb + 0.03), (0.985 * hw, zb + min(0.25, hs * 0.2)), (hw, zb + 0.45 * hs), (0.997 * hw, zb + 0.8 * hs), (y0, zl)]
        ay, az = y0 - 0.035 * hw * r, zl + 0.02
        for t in (0, 1 / 3, 2 / 3, 1):
            p.append((ay + (rw - ay) * t, az + (ze - az) * t))
        e = S["box"]
        for n in range(1, 6):
            a = n / 5 * math.pi / 2
            p.append((rw * math.cos(a) ** e if n < 5 else 0.0, ze + (zt - ze) * math.sin(a) ** e))
        bz = bump(f)
        if bz > 0:  # keep the fender top closed over the wheel pocket
            yin = W / 2 - 1.3
            p = [(y, max(z, bz)) if (j >= 7 and y > yin) else (y, z) for j, (y, z) in enumerate(p)]
        return p

    # ---- stations
    N = 34 if low else 60
    keys = [0.0, 1.0, sg0, sg1] + [f for f, _ in S["top"]]
    for c in S["cab"]:
        keys += [c - 0.006, c + 0.006]
    for p in S["pillars"]:
        keys += [p - 0.007, p + 0.007]
    if not low:
        for d in S["doors"]:
            keys += [d - 0.0035, d + 0.0035]
    fs = sorted(set([i / N for i in range(N + 1)] + [min(1, max(0, v)) for v in keys]))
    out = [fs[0]]
    protect = set(round(d + s, 4) for d in S["doors"] for s in (-0.0035, 0.0035))
    for f in fs[1:]:
        if f - out[-1] > 0.004 or round(f, 4) in protect:
            out.append(f)
    fs = out

    def mat_of(fm, j):
        gh = (ztop(fm) - zbelt(fm)) > 0.10 * H and rg - 0.01 < fm < wsb + 0.01
        in_p = any(abs(fm - p) < 0.0075 for p in S["pillars"])
        if gh and 7 <= j <= 9:
            if sg0 < fm < sg1:
                return S["pillar_mat"] if in_p else "Glass"
        if gh and 11 <= j <= 14:
            if rf < fm < wsb - 0.004:
                return "Glass"
            if rg + 0.004 < fm < rr and S.get("rearglass", True):
                return "Glass"
            if rr <= fm <= rf and S["roof"] != "body":
                return {"glass": "Glass", "contrast": "Stripe"}.get(S["roof"], "Trim")
        if gh and j == 10 and S["pillar_mat"] == "Trim" and rg < fm < wsb:
            return "Trim"
        tt = S.get("top_trim")
        if tt and 11 <= j <= 14 and tt[0] < fm < tt[1]:
            return "Trim"
        if S["stripes"] and S["stripes"][0] <= j <= S["stripes"][1]:
            return "Stripe"
        if 3 <= j <= 6 and not low and any(abs(fm - d) < 0.003 for d in S["doors"]):
            return "Trim"
        return "Body"

    me = bpy.data.meshes.new(cid + "_shell")
    bm = bmesh.new()
    Rv, Lv = [], []
    for f in fs:
        x = x0 + f * L
        pts = ring(f)
        r = [bm.verts.new((x, y, z)) for y, z in pts]
        l = [r[0]] + [bm.verts.new((x, -y, z)) for y, z in pts[1:-1]] + [r[-1]]
        Rv.append(r)
        Lv.append(l)
    for i in range(len(fs) - 1):
        fm = (fs[i] + fs[i + 1]) / 2
        for j in range(NJ - 1):
            mi = MAT_IDX[mat_of(fm, j)]
            for V in (Rv, Lv):
                try:
                    fc = bm.faces.new((V[i][j], V[i][j + 1], V[i + 1][j + 1], V[i + 1][j]))
                    fc.material_index = mi
                    fc.smooth = True
                except ValueError:
                    pass
    for i in (0, len(fs) - 1):
        loop = Rv[i] + list(reversed(Lv[i][1:-1]))
        try:
            bm.faces.new(loop)
        except ValueError:
            pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    shell = bpy.data.objects.new(cid + "_shell", me)
    bpy.context.collection.objects.link(shell)
    for n in ("Body", "Glass", "Trim", "Stripe"):
        shell.data.materials.append(M[n])

    # ---- wheel arches
    axles = [x0 + a * L for a in S["axle"]]
    if ex.get("cargo"):
        axles.insert(1, x0 + (S["axle"][0] + 0.13) * L)
    for ax in axles:
        for s in (-1, 1):
            cut = prim("cyl", "cut", (ax, s * (W / 2 + 0.2), wr), (wr * 2.32, wr * 2.32, 2.64), rot=(math.pi / 2, 0, 0), verts=28 if low else 40)
            m = shell.modifiers.new("arch", "BOOLEAN")
            m.object = cut
            m.operation = "DIFFERENCE"
            m.solver = "EXACT"
            apply_mods(shell)
            bpy.data.objects.remove(cut)
    try:
        shell.data.set_sharp_from_angle(angle=math.radians(38))
    except Exception:
        pass

    # ---- wheels
    tw = 1.0 if k["wr"] < 1.9 else 1.3
    rimr = wr * S["rim"]
    for ax in axles:
        for s in (-1, 1):
            y = s * (W / 2 - tw / 2 - 0.04)
            t = prim("cyl", "tire", (ax, y, wr), (wr * 2, wr * 2, tw), rot=(math.pi / 2, 0, 0), verts=20 if low else 32)
            bevel(t, 0.2, 2 if low else 3)
            parts["Tire"].append(t)
            ry = y + s * (tw / 2 - 0.02)
            parts["Trim"].append(prim("cyl", "well", (ax, ry - s * 0.08, wr), (rimr * 2, rimr * 2, 0.2), rot=(math.pi / 2, 0, 0), verts=20))
            parts["Rim"].append(prim("cyl", "hub", (ax, ry, wr), (rimr * 0.5, rimr * 0.5, 0.26), rot=(math.pi / 2, 0, 0), verts=12))
            bpy.ops.mesh.primitive_torus_add(major_radius=rimr * 0.96, minor_radius=0.09, major_segments=20 if low else 32, minor_segments=6,
                                             location=(ax, ry, wr), rotation=(math.pi / 2, 0, 0))
            parts["Rim"].append(bpy.context.active_object)
            ns = 5 if low else S["spokes"]
            for n in range(ns):
                a = n * 2 * math.pi / ns
                parts["Rim"].append(prim("box", "spoke", (ax + math.cos(a) * rimr * 0.5, ry, wr + math.sin(a) * rimr * 0.5),
                                         (rimr * 0.95, 0.14, rimr * (0.22 if ns <= 6 else 0.11)), rot=(0, -a, 0)))
            if ex.get("caliper") and not low:
                parts["Caliper"].append(prim("box", "caliper", (ax + rimr * 0.55, ry - s * 0.1, wr + rimr * 0.4), (rimr * 0.5, 0.12, rimr * 0.7), rot=(0, 0.6, 0)))
            if ex.get("flare") and not low:
                bpy.ops.mesh.primitive_torus_add(major_radius=wr * 1.2, minor_radius=0.16, major_segments=28, minor_segments=6,
                                                 location=(ax, s * (hwf((ax - x0) / L) - 0.02), wr), rotation=(math.pi / 2, 0, 0))
                fl = bpy.context.active_object
                bmf = bmesh.new()
                bmf.from_mesh(fl.data)
                bmesh.ops.delete(bmf, geom=[v for v in bmf.verts if (fl.matrix_world @ v.co).z < zbot(0.5) + 0.05], context="VERTS")
                bmf.to_mesh(fl.data)
                bmf.free()
                parts[ex["flare"]].append(fl)

    # ---- fascias
    def fascia(items, front):
        f = 1.0 if front else 0.0
        hw = hwf(f) * 0.96
        z0, z1 = zbot(f), ztop(f)
        xf = x0 + f * L
        sgn = 1 if front else -1
        for I in items:
            for mir in ((1, -1) if abs(I["cu"]) > 1e-6 else (1,)):
                pts = [((I["cu"] + u * I["su"]) * mir * hw, z0 + (I["cv"] + v * I["sv"]) * (z1 - z0)) for u, v in I["shape"]]
                pts = [(max(-hw * 1.02, min(hw * 1.02, y)), z) for y, z in pts]
                d = I["depth"]
                ob = prism(I["mat"], pts, xf - 0.1 * sgn, (0.1 + d) * sgn)
                parts[I["mat"]].append(ob)
                if I["frame"] and not low:
                    cy = I["cu"] * mir * hw
                    cz = z0 + I["cv"] * (z1 - z0)
                    fp = [(cy + (y - cy) * 1.12, cz + (z - cz) * 1.12) for y, z in pts]
                    parts[I["frame"]].append(prism("frame", fp, xf - 0.1 * sgn, (0.1 + d * 0.6) * sgn))

    fascia(S["front"], True)
    fascia(S["rear"], False)

    # ---- side details
    fx = lambda f: x0 + f * L
    for s in (-1, 1):
        mf = wsb - 0.015
        m = prim("box", "mirror", (fx(mf), s * (hwf(mf) + 0.22), zbelt(mf) + 0.3), (0.45, 0.6, 0.36))
        bevel(m, 0.1, 2)
        parts["Body"].append(m)
        if not low:
            for d in S["doors"][:-1]:
                hf = d + 0.04
                parts["Chrome" if ex.get("molding") else "Body"].append(prim("box", "handle", (fx(hf), s * (hwf(hf) * 0.99 + 0.03), zbelt(hf) - 0.32), (0.55, 0.1, 0.13)))
        if ex.get("intake"):
            f = S["axle"][0] + 0.15
            parts["Trim"].append(prism("intake", [(s * (hwf(f) + 0.03), zbot(f) + 0.5), (s * (hwf(f) + 0.03), zbelt(f) - 0.25), (s * (hwf(f) - 0.25), zbelt(f) - 0.25), (s * (hwf(f) - 0.25), zbot(f) + 0.5)], fx(f) - 0.5, 1.1))
        if ex.get("blade"):
            f = S["axle"][0] + 0.2
            parts["Trim"].append(prim("box", "blade", (fx(f), s * hwf(f) * 0.985, (zbelt(f) + ztop(f)) / 2), (0.9, 0.12, ztop(f) - zbelt(f) + 0.5)))
        if ex.get("vents") and not low:
            for n in range(3):
                f = S["axle"][1] - 0.115 - n * 0.022
                parts["Chrome"].append(prim("cyl", "vent", (fx(f), s * (hwf(f) * 0.998), zbelt(f) - 0.42), (0.2, 0.2, 0.1), rot=(math.pi / 2, 0, 0), verts=10))
        if ex.get("gill") and not low:
            f = S["axle"][1] - 0.12
            parts["Trim"].append(prim("box", "gill", (fx(f), s * hwf(f), zbelt(f) - 0.6), (0.2, 0.1, 1.0)))
        if ex.get("molding"):
            parts["Trim"].append(prim("box", "molding", (fx(0.5), s * (hwf(0.5) + 0.02), clear + (zbelt(0.5) - clear) * 0.55), (L * 0.5, 0.1, 0.22)))
        if ex.get("indicators"):
            parts["HeadLight"].append(prim("box", "indicator", (fx(0.95), s * hwf(0.95) * 0.8, ztop(0.95) + 0.1), (0.6, 0.3, 0.2)))
        if ex.get("rails"):
            f0, f1 = rr + 0.03, rf - 0.03
            parts["Trim"].append(prim("box", "rail", (fx((f0 + f1) / 2), s * hwf(0.4) * S["tumble"] * 0.86, H + 0.12), ((f1 - f0) * L, 0.14, 0.14)))
    if ex.get("lip"):
        parts["Trim"].append(prim("box", "splitter", (fx(1) - 0.2, 0, zbot(1) - 0.02), (0.7, hwf(1) * 1.9, 0.1)))
    sp = ex.get("spoiler")
    if sp == "lip":
        parts["Body"].append(prim("box", "ducktail", (fx(0.012) + 0.25, 0, ztop(0.02) + 0.08), (0.5, hwf(0.03) * 1.7, 0.16), rot=(0, 0.25, 0)))
    if ex.get("wing"):
        zt = ztop(0.06)
        for s in (-1, 1):
            parts["Trim"].append(prim("box", "wingpost", (fx(0.06), s * W * 0.3, zt + 0.35), (0.5, 0.14, 0.9)))
        w = prim("box", "wing", (fx(0.05), 0, zt + 0.85), (1.3, W * 0.96, 0.14), rot=(0, 0.14, 0))
        parts["Trim"].append(w)
    if ex.get("scoop"):
        f = (wsb + 1) / 2
        sc = prim("box", "scoop", (fx(f), 0, ztop(f) + 0.05), (L * 0.14, W * 0.22, 0.22))
        bevel(sc, 0.08, 2)
        parts["Stripe" if S["stripes"] else "Body"].append(sc)
    if ex.get("spare"):
        sw = prim("cyl", "spare", (fx(0) - 0.45, 0, zbelt(0.02) + 0.1), (wr * 1.95, wr * 1.95, 0.8), rot=(0, math.pi / 2, 0), verts=28)
        bevel(sw, 0.15, 2)
        parts["Trim"].append(sw)
        parts["Chrome"].append(prim("cyl", "sparecap", (fx(0) - 0.88, 0, zbelt(0.02) + 0.1), (wr * 1.1, wr * 1.1, 0.06), rot=(0, math.pi / 2, 0), verts=20))
    if ex.get("taxi"):
        ts = prim("box", "taxisign", (fx((rr + rf) / 2), 0, H + 0.28), (1.3, 2.2, 0.5))
        bevel(ts, 0.1, 2)
        parts["HeadLight"].append(ts)
    if ex.get("lightbar"):
        parts["HeadLight"].append(prim("box", "lightbar", (fx(rf - 0.05), 0, H + 0.2), (0.8, W * 0.55, 0.32)))
    if ex.get("cargo"):
        a, b = 0.02, rg - 0.02
        cz0 = ztop(0.2)
        c = prim("box", "cargo", (fx((a + b) / 2), 0, (cz0 + H * 1.12) / 2), ((b - a) * L, W * 0.98, H * 1.12 - cz0))
        bevel(c, 0.15, 2)
        parts["Cargo"].append(c)

    # ---- assemble: split shell by material, join everything per look
    root = bpy.data.objects.new(cid, None)
    bpy.context.collection.objects.link(root)
    for o in bpy.context.selected_objects:
        o.select_set(False)
    shell.select_set(True)
    bpy.context.view_layer.objects.active = shell
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="MATERIAL")
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in list(bpy.context.selected_objects):
        if not o.data.polygons:
            bpy.data.objects.remove(o)
            continue
        idx = o.data.polygons[0].material_index
        name = o.data.materials[idx].name.split(".")[0]
        set_mat(o, M[name])
        for p in o.data.polygons:
            p.material_index = 0
        parts[name].append(o)
    for name, objs in parts.items():
        if not objs:
            continue
        for o in objs:
            set_mat(o, M[name])
            if o.data.polygons and not o.name.startswith(cid):
                for p in o.data.polygons:
                    p.use_smooth = False
        ob = join(objs, name)
        ob.parent = root
    return root

def triangles(root):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in root.children if o.type == "MESH")

def export(roots, path):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for r in roots:
        r.select_set(True)
        for c in r.children:
            c.select_set(True)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"EMPTY", "MESH"}, apply_unit_scale=True,
                             axis_forward="-Z", axis_up="Y", mesh_smooth_type="EDGE", add_leaf_bones=False, bake_space_transform=True)

# ---------------------------------------------------------------- render
def setup_scene(resx, resy, samples=32):
    sc = bpy.context.scene
    if sc.camera:
        sc.render.resolution_x, sc.render.resolution_y = resx, resy
        return sc, sc.camera.data, sc.camera
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = resx, resy
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.78, 1.0, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    sc.world = world
    bpy.ops.mesh.primitive_plane_add(size=2000, location=(0, 0, 0))
    set_mat(bpy.context.active_object, mat("Ground", (0.42, 0.44, 0.47, 1), rough=0.7))
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3
    sun.angle = 0.2
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
    sc.collection.objects.link(so)
    cam = bpy.data.cameras.new("cam")
    co = bpy.data.objects.new("cam", cam)
    sc.collection.objects.link(co)
    sc.camera = co
    return sc, cam, co

def render_grid(roots, path, cols, rear=False):
    rows = math.ceil(len(roots) / cols)
    sc, cam, co = setup_scene(1800, int(1800 * rows / cols * 0.6) + 40)
    for i, r in enumerate(roots):
        r.location = ((i % cols) * 20, -(i // cols) * 20, 0)
        r.rotation_euler = (0, 0, math.radians(145 if rear else -35))
    cam.type = "ORTHO"
    cam.ortho_scale = cols * 20 * 1.0
    cx, cy = (cols - 1) * 10, -(rows - 1) * 10
    co.location = (cx, cy - 120, 55)
    co.rotation_euler = (Vector((cx, cy, 1.5)) - co.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for r in roots:
        r.location = (0, 0, 0)
        r.rotation_euler = (0, 0, 0)

def main():
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    no_render = "norender" in only
    ids = [c for c in CARS if c in only] or list(CARS)
    reset()
    roots = []
    for cid in ids:
        r = build_car(cid, cid)
        print(cid, "tris", triangles(r))
        roots.append(r)
    for r in roots:
        export([r], os.path.join(OUT, r.name + ".fbx"))
    if len(ids) == len(CARS):
        export(roots, os.path.join(OUT, "cars_collection.fbx"))
    if not no_render:
        render_grid(roots, os.path.join(RENDERS, "collection.png"), min(4, len(roots)))
        render_grid(roots, os.path.join(RENDERS, "collection_rear.png"), min(4, len(roots)), rear=True)
    if "notraffic" in only:
        return
    reset()
    troots = []
    for kind, (design, over) in TRAFFIC.items():
        r = build_car(kind, design, color=TRAFFIC_COLOR, low=True, over=over, dims=kind)
        print(kind, "tris", triangles(r))
        troots.append(r)
    export(troots, os.path.join(OUT, "cars_traffic.fbx"))
    if not no_render:
        render_grid(troots, os.path.join(RENDERS, "traffic.png"), 4)

if __name__ == "__main__":
    main()
