"""CAR HUNTERS economy simulator.

Reads the real Luau configs (via lupa) and plays a greedy "average player" through the game:
runs into the best district it can survive, banks loot, throws every part at the trap, parks the best cars,
buys bays/floors/upgrades/perks/districts/skins and rebirths when allowed. Prints the time of each milestone.

  pip install lupa
  python3 tools/econ_sim.py            # one average player
  python3 tools/econ_sim.py --runs 20  # median of 20 seeds
"""
import argparse, math, os, random, statistics

import lupa

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = os.environ.get("ECON_SHARED") or os.path.join(ROOT, "src", "ReplicatedStorage", "Shared")  # override: try configs in a copy

L = lupa.LuaRuntime(unpack_returned_tuples=True)
L.execute("""
Color3 = { fromRGB = function(r, g, b) return { r = r, g = g, b = b, R = r / 255, G = g / 255, B = b / 255,
	Lerp = function(self) return self end } end, new = function() return {} end }
Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }
CFrame = { new = function() return {} end }
math.clamp = function(x, a, b) return math.max(a, math.min(b, x)) end
table.clone = function(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end
""")
_mods = {}


def req(name):
    if name not in _mods:
        src = open(os.path.join(SHARED, name + ".lua"), encoding="utf-8").read()
        loader = L.eval("""function(src, name, req)
			local P = setmetatable({ WaitForChild = function(_, k) return k end }, { __index = function(_, k) return k end })
			local env = setmetatable({ script = { Parent = P }, require = function(n) return req(n) end }, { __index = _G })
			return assert(load(src, name, 't', env))() end""")
        _mods[name] = loader(src, name, req)
    return _mods[name]


def lt(t):
    """lua table -> python (lists for array-like tables)"""
    if lupa.lua_type(t) != "table":
        return t
    keys = list(t.keys())
    if keys and sorted(keys) == list(range(1, len(keys) + 1)):
        return [lt(t[k]) for k in sorted(keys)]
    return {k: lt(v) for k, v in t.items()}


Car, Eco, Map, Part, Shop, Skin = (req(n) for n in ("CarConfig", "EconomyConfig", "MapConfig", "PartConfig", "ShopConfig", "SkinConfig"))
Trap, Gear = req("TrapConfig"), req("GearConfig")
GEAR = {g["id"]: g for g in lt(Gear.List)}
RAR = lt(Car.RarityOrder)
POOL = {r: [d["income"] for d in lt(Car.ByRarity[r])] for r in RAR}
DROP = lt(Car.DropChances)
ZONES = lt(Map.ZoneOrder)
UNLOCK = lt(Eco.ZoneUnlock)
SPAWN = lt(Part.SpawnTables)
PART_OF = lt(Part.PartForRarity)
ORDER = lt(Part.Order)
SLOT_COST = lt(Eco.SlotCosts)
FLOOR_COST = lt(Eco.FloorCosts)
PERKS = {p["id"]: p for p in lt(Shop.Perks)}
SKINS = lt(Skin.Skins)
REB = lt(Skin.Rebirth)
VALUE_MULT, GROWTH, INC_MULT = Car.ValueMultiplier, Car.IncomeGrowth, Car.IncomeMult
UP_BASE, UP_GROW, MAXLV = Car.UpgradeCostBase, Car.UpgradeCostGrowth, Car.MaxLevel
TIER = {z: lt(Map.Zones[z])["tier"] for z in ZONES}
ARENA = {z: bool(lt(Map.Zones[z]).get("arena")) for z in ZONES}

# ---------------------------------------------------------------- player model (tweak here, not in the game)
P = dict(
    pick_rate=0.22,          # parts per second while hunting (walk, dodge, spawn cooldowns)
    lane_speed=40,           # average running speed incl. speed lanes (studs/s)
    death={1: [0.06, 0.12, 0.18, 0.25, 0.28], 2: [0.3, 0.32, 0.36, 0.34, 0.33], 3: [0.4, 0.42, 0.45, 0.48, 0.42]},
    batch_ui=6,              # seconds looking at the reel / results grid per batch
    session_h=2, away_h=10,  # play 2 h, then away 10 h (offline earnings, capped by the game)
    think=20,                # seconds per cycle spent in menus / walking in the garage
    risk_mix=(0.55, 0.35, 0.10),  # share of safe / risky / road pickups
    gear_every=600,          # v24: tries to put a Cash Turbo (v25: x2 for 5 min) on its best car every 10 min ...
    gear_budget=0.10,        # ... when the price is below 10% of its money (and Tony has one in stock)
    gear_id="cashturbo",
    gears=True, trap=True,   # --no-gears / --no-trap switch the v24 models off
)


class Player:
    def __init__(self, seed):
        self.rng = random.Random(seed)
        self.t = 0.0
        self.reset(first=True)
        self.discovered = set()
        self.perks = {}
        self.rebirths = 0
        self.tokens = 0
        self.skin_bonus = 0.0
        self.skins = {"classic"}
        self.log = []
        self.seen = set()
        self.inc_at = {}  # milestone -> gear-less income/s at that moment
        self.trap = 1  # v24 throw platform level (kept on rebirth)
        self.next_gear = 0.0
        self.gear_log = []  # (hour, gain / price) of every gear bought
        self.gear_spent = 0.0

    def reset(self, first=False):
        self.money = 0 if first else REB["startMoney"] * self.rebirths
        self.parts = {k: 0 for k in ORDER}
        self.parts["bolts"] = 2 if first else 3
        self.cars = []  # [income, level, rarity, gear mult, pool index, gear expiry time]
        # v24 GearConfig.Price follows the best gear-less single parked car income of this run; v25: a rebirth keeps 30%
        self.peak = 0.0 if first else math.floor(self.peak * 0.3)
        if first:  # v18: a rebirth keeps districts, floors and bays
            self.zones = {"city"}
            self.slots = Eco.StartSlots
            self.floors = 1
        self.pity = 0

    # ---------------------------------------------------------------- economy formulas (mirror the Luau code)
    def car_income(self, c, gears=True):
        m = c[3] if gears and c[5] > self.t else 1
        return c[0] * INC_MULT * (1 + GROWTH * (c[1] - 1)) * m

    def shared_mult(self):
        tiers = sum(1 for r in RAR if all((r, i) in self.discovered for i in range(len(POOL[r]))))
        idx = 1 + tiers * Eco.IndexTierBonus + (Eco.IndexFullBonus if tiers == len(RAR) else 0)
        perk = 1 + 0.08 * self.perks.get("turbo", 0)
        reb = (1 + REB["incomePer"] * self.rebirths) * (1 + self.skin_bonus)
        return idx * perk * reb

    def parked(self):
        # the game parks by plain income (a geared car stays parked: it is the best one anyway)
        return sorted(self.cars, key=lambda c: self.car_income(c, False), reverse=True)[: self.slots]

    def income(self, gears=True):
        return sum(self.car_income(c, gears) for c in self.parked()) * self.shared_mult()

    def luck(self):
        # v24 Shop.LuckMult: x(1 + 2 * shift of the old sources) x platform level (real TrapConfig.LuckMult), cap x3
        m = (1 + 2 * PERKS["lucky"]["per"] * self.perks.get("lucky", 0)) * Trap.LuckMult(self.trap)
        return min(m, 3.0)

    def use_gears(self):
        """v24: every gear_every seconds put an income gear on the best parked car if it is cheap enough"""
        if self.cars:  # IncomeService.Recalc: data.peakCarIncome = best parked car, no gear, x shared mults
            self.peak = max(self.peak, self.car_income(self.parked()[0], False) * self.shared_mult())
        if not P["gears"] or self.t < self.next_gear or not self.cars:
            return
        self.next_gear = self.t + P["gear_every"]
        g = GEAR[P["gear_id"]]
        # Tony's stock rolls every Window s; over gear_every s the bot sees gear_every / Window windows
        windows = max(1, int(P["gear_every"] // Gear.Window))
        if all(self.rng.random() >= g["stock"]["chance"] for _ in range(windows)):
            return
        price = Gear.Price(Gear.ById[g["id"]], self.peak)
        if price > P["gear_budget"] * self.money:
            return
        best = self.parked()[0]
        if best[5] > self.t:
            return
        self.money -= price
        self.gear_spent += price
        best[3], best[5] = g["effects"]["income"], self.t + g["seconds"]
        gain = (g["effects"]["income"] - 1) * self.car_income(best, False) * self.shared_mult() * g["seconds"]
        self.gear_log.append((self.t / 3600, gain / price, self.slots))

    def mark(self, name):
        if name not in self.seen:
            self.seen.add(name)
            self.log.append((name, self.t))
            self.inc_at[name] = self.income(False)

    def wait(self, sec):
        self.t += sec
        self.money += self.income() * sec

    # ---------------------------------------------------------------- one cycle: run, bank, throw, spend
    def best_zone(self):
        """zone with the best expected value per second of parts (deeper = better parts, longer trip, more deaths)"""
        best, bestv = "city", -1
        for z in ZONES:
            if z not in self.zones:
                continue
            v = self.zone_value(z)
            if v > bestv:
                best, bestv = z, v
        return best

    def run_stats(self, z):
        zone = lt(Map.Zones[z])
        dist = zone["zMin"] + 80 + 200  # from the garages to the middle of the district
        cap = Eco.CarryCapacity + 5 * self.perks.get("backpack", 0)
        hunt = cap / P["pick_rate"]
        trip = dist / P["lane_speed"] + 4  # teleport out, run home with the loot
        tier = TIER[z]
        k = [x for x in ZONES if TIER[x] == tier].index(z)
        pdeath = P["death"][tier][min(k, 4)] * (1 - 0.15 * self.perks.get("airbag", 0))
        return cap, hunt + trip, pdeath

    def zone_value(self, z):
        cap, dur, pd = self.run_stats(z)
        ev = 0
        for (risk, share) in zip(("safe", "risky", "road"), P["risk_mix"]):
            table = SPAWN[z].get(risk) or SPAWN[z]["safe"]
            tot = sum(w for _, w in table)
            ev += share * sum(w / tot * self.part_value(p) for p, w in table)
        return ev * cap * (1 - pd) / dur

    def part_value(self, part):
        row = DROP[part]
        tot = sum(row.values())
        return sum(row[r] / tot * statistics.mean(POOL[r]) for r in RAR)

    def do_run(self):
        z = self.best_zone()
        cap, dur, pd = self.run_stats(z)
        self.wait(dur)
        if self.rng.random() < pd:
            self.wait(3)  # respawn, loot lost
            return
        for _ in range(cap):
            table_risk = self.rng.choices(("safe", "risky", "road"), P["risk_mix"])[0]
            table = SPAWN[z].get(table_risk) or SPAWN[z]["safe"]
            p = self.rng.choices([a for a, _ in table], [w for _, w in table])[0]
            self.parts[p] += 1

    def throw_all(self):
        # keep a few parts of each kind for upgrades
        n = 0
        for part in ORDER:
            keep = 4 if part in ("tire", "engine", "turbo", "core") else 0
            while self.parts[part] > keep:
                self.parts[part] -= 1
                self.throw(part)
                n += 1
        if n:  # one batch: reel + grid instead of a cinematic per part
            self.wait(2.5 + 0.05 * n + P["batch_ui"])

    def throw(self, part):
        row = dict(DROP[part])
        if self.pity >= Eco.PityThreshold - 1:
            leg = min(row["Legendary"] * 3, 20)
            row = {"Common": 0, "Uncommon": 0, "Rare": 0, "Epic": 100 - leg, "Legendary": leg}
        # v24 luck multiplier through the real CarConfig.ApplyLuck (Lucky perk x platform level, capped x3)
        row = lt(Car.ApplyLuck(L.table_from(row), self.luck()))
        tot = sum(row.values())
        r1 = self.rng.random()
        x, acc, rar = r1 * tot, 0, "Legendary"
        for r in RAR:
            acc += row[r]
            if row[r] > 0 and x < acc:
                rar = r
                break
        self.pity = 0 if rar in ("Epic", "Legendary") else self.pity + 1
        i = self.rng.randrange(len(POOL[rar]))
        if (rar, i) not in self.discovered:
            self.discovered.add((rar, i))
            self.money += POOL[rar][i] * VALUE_MULT * Eco.DiscoverBonusMult
        copy = None
        for c in self.cars:
            if c[2] == rar and len(c) > 4 and c[4] == i and (copy is None or c[1] > copy[1]):
                copy = c
        if copy and copy[1] < Eco.MergeMaxLevel:
            copy[1] += 1  # merge duplicate
            return
        self.cars.append([POOL[rar][i], 1, rar, 1.0, i, 0.0])
        if len(self.cars) > 60:  # sell junk
            self.cars.sort(key=lambda c: self.car_income(c, False))
            junk = self.cars.pop(0)
            self.money += junk[0] * VALUE_MULT * Eco.SellFraction
        self.mark("first car")
        if rar == "Legendary":
            self.mark("first Legendary")

    def coll_value(self):
        return sum(c[0] * VALUE_MULT * (1 + 0.3 * (c[1] - 1)) for c in self.cars)

    def spend(self):
        for _ in range(200):
            inc = self.income()
            opts = []
            # next bay / floor
            nxt = self.slots + 1
            if nxt <= 24:
                if nxt > self.floors * 6:
                    # a floor is worth the car it lets you park (ranked with the price of its first bay)
                    fc = FLOOR_COST[self.floors + 1]
                    opts.append((fc, "floor", None, self.gain_from_slot() * fc / (fc + SLOT_COST[nxt])))
                else:
                    gain = self.gain_from_slot()
                    opts.append((SLOT_COST[nxt], "slot", None, gain))
            # upgrade parked cars
            for c in self.parked():
                if c[1] < MAXLV:
                    cost = c[0] * VALUE_MULT * UP_BASE * UP_GROW ** (c[1] - 1)
                    need = 1 + (c[1] - 1) // 3
                    if self.parts[PART_OF[c[2]]] >= need:
                        # (unit kept from v19 so the ROI order is unchanged; v25: x10 income -> scaled with IncomeMult / 3.25)
                        opts.append((cost, "up", c, c[0] * GROWTH * INC_MULT / 3.25))
            # Pit Stop income perk
            lv = self.perks.get("turbo", 0)
            if lv < 5:
                opts.append((PERKS["turbo"]["costs"][lv], "perk", "turbo", inc * 0.08 / max(1, 1 + 0.08 * lv)))
            for pid in ("backpack", "airbag", "lucky", "sneakers"):
                lv = self.perks.get(pid, 0)
                if lv < PERKS[pid]["max"]:
                    opts.append((PERKS[pid]["costs"][lv], "perk", pid, inc * 0.04))
            # v24 throw platform: +LuckPerLevel on the multiplier; valued like the Lucky perk
            # (Lucky Lv = +3% luck mult ~ inc x 0.04), scaled by the relative luck gain of the level
            if P["trap"] and self.trap < Trap.MaxLevel and self.luck() < 3.0:
                rel = Trap.LuckPerLevel / Trap.LuckMult(self.trap)
                opts.append((Trap.NextCost(self.trap), "trap", None, inc * 0.04 * rel / 0.03))
            # skins
            for s in SKINS:
                if s["id"] not in self.skins and s.get("money"):
                    opts.append((s["money"], "skin", s, inc * (s["bonus"] - self.skin_bonus)))
            # districts: buy as soon as allowed (they are the progression)
            for i, z in enumerate(ZONES):
                if z in self.zones:
                    continue
                req = UNLOCK.get(z)
                if req and ZONES[i - 1] in self.zones and self.rebirths >= req.get("rebirths", 0) and self.coll_value() >= req["minValue"]:
                    opts.append((req["cost"], "zone", z, 1e18))
                break
            # pick best ROI the player can afford; save up if the best is too expensive
            opts = [o for o in opts if o[3] > 0]
            if not opts:
                return
            opts.sort(key=lambda o: o[0] / o[3])
            cost, kind, arg, _ = opts[0]
            if cost > self.money:
                return
            self.money -= cost
            if kind == "slot":
                self.slots += 1
            elif kind == "floor":
                self.floors += 1
                self.mark(f"floor {self.floors}")
            elif kind == "up":
                arg[1] += 1
                self.parts[PART_OF[arg[2]]] -= 1 + (arg[1] - 2) // 3
            elif kind == "perk":
                self.perks[arg] = self.perks.get(arg, 0) + 1
            elif kind == "trap":
                self.trap += 1
                self.mark(f"platform Lv{self.trap}")
            elif kind == "skin":
                self.skins.add(arg["id"])
                self.skin_bonus = max(self.skin_bonus, arg["bonus"])
            elif kind == "zone":
                self.zones.add(arg)
                self.mark(("R%d " % self.rebirths if self.rebirths else "") + "unlock " + arg)

    def gain_from_slot(self):
        incs = sorted((self.car_income(c, False) for c in self.cars), reverse=True)
        return incs[self.slots] if len(incs) > self.slots else 0.01

    def maybe_rebirth(self):
        zone, money = Skin.RebirthNeeds(self.rebirths)
        if self.rebirths >= 3 and "colosseum" not in self.zones:
            return  # finish the final boss first
        if zone in self.zones and self.money >= money:
            before = self.income(False)
            self.tokens += min(5, int(self.money // money))
            self.rebirths += 1
            self.reset()
            self.mark(f"rebirth {self.rebirths}")
            self.inc_at[f"rebirth {self.rebirths}"] = before  # income just before the reset

    def cycle(self):
        # offline earnings after each play session
        if self.t >= getattr(self, "next_away", P["session_h"] * 3600):
            self.next_away = self.t + P["session_h"] * 3600
            self.money += min(P["away_h"], 8) * 3600 * self.income(False) * 0.15  # gears run out while away
        self.do_run()
        self.throw_all()
        self.wait(P["think"])
        self.use_gears()
        self.spend()
        self.maybe_rebirth()
        if len(self.discovered) == sum(len(v) for v in POOL.values()):
            self.mark("full collection")
        if "colosseum" in self.zones:
            self.mark("colosseum (final boss)")


def simulate(seed, hours):
    p = Player(seed)
    while p.t < hours * 3600 and "colosseum (final boss)" not in p.seen:
        p.cycle()
    return p


# v19 targets in bot hours (a real player is ~1.3-1.6x slower): highway ~15 min, rebirth 1 ~2 h, final boss ~18 h real
TARGETS = [("first car", 0, 0.05), ("unlock highway", 0.02, 0.2), ("unlock neon", 0.2, 0.8), ("rebirth 1", 0.6, 1.4),
           ("R1 unlock docks", 1.0, 2.5), ("rebirth 3", 4.5, 9), ("R3 unlock circuit", 5.5, 10), ("colosseum (final boss)", 10, 16)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=1)
    ap.add_argument("--hours", type=float, default=200)
    ap.add_argument("--no-gears", action="store_true")
    ap.add_argument("--no-trap", action="store_true")
    ap.add_argument("--quiet", action="store_true", help="milestones only")
    a = ap.parse_args()
    P["gears"], P["trap"] = not a.no_gears, not a.no_trap
    if not a.quiet:
        print("income per car (CarConfig.IncomeAt, per second, before index/perk/rebirth multipliers)")
        print(f"{'rarity':10s} {'min Lv1':>8s} {'avg Lv1':>8s} {'max Lv1':>8s} {'avg Lv10':>9s} {'max Lv10':>9s}")
        for r in RAR:
            defs = list(Car.ByRarity[r].values())
            l1 = [Car.IncomeAt(d, 1) for d in defs]
            l10 = [Car.IncomeAt(d, 10) for d in defs]
            print(f"{r:10s} {min(l1):8.0f} {statistics.mean(l1):8.0f} {max(l1):8.0f} {statistics.mean(l10):9.0f} {max(l10):9.0f}")
        gm = Car.ById["golden_magnat_gt"]
        print(f"{'Golden GT':10s} {Car.IncomeAt(gm, 1):8.0f} {'':8s} {'':8s} {Car.IncomeAt(gm, 10):9.0f}")
        print()
    results, incs, gears, spent = {}, {}, [], []
    for s in range(a.runs):
        p = simulate(s + 1, a.hours)
        for name, t in p.log:
            results.setdefault(name, []).append(t / 3600)
            incs.setdefault(name, []).append(p.inc_at.get(name, 0))
        gears += p.gear_log
        spent.append(p.gear_spent)
    order = sorted(results, key=lambda k: statistics.median(results[k]))
    print(f"{'milestone':32s} {'median h':>9s} {'income/s':>9s}   target")
    tmap = {n: (lo, hi) for n, lo, hi in TARGETS}
    for k in order:
        med = statistics.median(results[k])
        tgt = tmap.get(k)
        flag = ""
        if tgt:
            flag = f"{tgt[0]:>5.1f}-{tgt[1]:<5.1f} " + ("ok" if tgt[0] <= med <= tgt[1] else "OFF")
        print(f"{k:32s} {med:9.2f} {fmt(statistics.median(incs[k])):>9s}   {flag}")
    for n, _, _ in TARGETS:
        if n not in results:
            print(f"{n:32s}   never reached")
    if gears and not a.quiet:
        print(f"\n{P['gear_id']} bought {len(gears) / a.runs:.0f}x per run, {fmt(statistics.median(spent))} spent; "
              "payback = extra income over its timer / price (1.0 = break-even):")
        for lo, hi in ((0, 1), (1, 3), (3, 6), (6, 10), (10, 1e9)):
            g = [x for h, x, _ in gears if lo <= h < hi]
            if g:
                print(f"  {lo:>4.0f}-{hi if hi < 1e9 else 'end':>4} h: median x{statistics.median(g):.2f}  (n={len(g)})")


def fmt(x):
    for d, u in ((1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")):
        if x >= d:
            return f"{x / d:.1f}{u}"
    return f"{x:.0f}"


if __name__ == "__main__":
    main()
