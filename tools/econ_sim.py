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
SHARED = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared")

L = lupa.LuaRuntime(unpack_returned_tuples=True)
L.execute("""
Color3 = { fromRGB = function(r, g, b) return { r = r, g = g, b = b, R = r / 255, G = g / 255, B = b / 255,
	Lerp = function(self) return self end } end, new = function() return {} end }
Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }
CFrame = { new = function() return {} end }
math.clamp = function(x, a, b) return math.max(a, math.min(b, x)) end
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


Car, Eco, Map, Part, Shop, Skin, Tun = (req(n) for n in ("CarConfig", "EconomyConfig", "MapConfig", "PartConfig", "ShopConfig", "SkinConfig", "TuningConfig"))
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
VALUE_MULT, GROWTH = Car.ValueMultiplier, Car.IncomeGrowth
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
    tuning_rate={},  # filled from PartConfig.TuningDrops below
)


P["tuning_rate"] = {z: v["chance"] for z, v in lt(Part.TuningDrops).items()}


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

    def reset(self, first=False):
        self.money = 0 if first else REB["startMoney"] * self.rebirths
        self.parts = {k: 0 for k in ORDER}
        self.parts["bolts"] = 2 if first else 3
        self.cars = []  # [income, level, rarity, tune_mult]
        self.zones = {"city"}
        self.slots = Eco.StartSlots
        self.floors = 1
        self.pity = 0
        self.tune = 0  # tuning parts in the box (each worth ~ +25% on one car)

    # ---------------------------------------------------------------- economy formulas (mirror the Luau code)
    def car_income(self, c):
        return c[0] * (1 + GROWTH * (c[1] - 1)) * c[3]

    def income(self):
        best = sorted((self.car_income(c) for c in self.cars), reverse=True)[: self.slots]
        found = len(self.discovered)
        tiers = sum(1 for r in RAR if all((r, i) in self.discovered for i in range(len(POOL[r]))))
        idx = 1 + tiers * Eco.IndexTierBonus + (Eco.IndexFullBonus if tiers == len(RAR) else 0)
        perk = 1 + 0.08 * self.perks.get("turbo", 0)
        reb = (1 + REB["incomePer"] * self.rebirths) * (1 + self.skin_bonus)
        return sum(best) * idx * perk * reb

    def mark(self, name):
        if name not in self.seen:
            self.seen.add(name)
            self.log.append((name, self.t))

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
        best = max((self.car_income(c) for c in self.cars), default=0)
        ev += P["tuning_rate"].get(z, 0) * 0.25 * best * 3  # a tuning part keeps paying on your best car
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
            if self.rng.random() < P["tuning_rate"].get(z, 0):
                self.tune += 1

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
        luck = min(Eco.MaxLuckShift, 0.015 * self.perks.get("lucky", 0))
        if self.pity >= Eco.PityThreshold - 1:
            leg = min(row["Legendary"] * 3, 20)
            row = {"Common": 0, "Uncommon": 0, "Rare": 0, "Epic": 100 - leg, "Legendary": leg}
        tot = sum(row.values())
        r1 = 1 - (1 - self.rng.random()) * (1 - luck)
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
        self.cars.append([POOL[rar][i], 1, rar, 1.0, i])
        if len(self.cars) > 60:  # sell junk
            self.cars.sort(key=self.car_income)
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
                    opts.append((FLOOR_COST[self.floors + 1], "floor", None, 0.5))
                else:
                    gain = self.gain_from_slot()
                    opts.append((SLOT_COST[nxt], "slot", None, gain))
            # upgrade parked cars
            parked = sorted(self.cars, key=self.car_income, reverse=True)[: self.slots]
            for c in parked:
                if c[1] < MAXLV:
                    cost = c[0] * VALUE_MULT * UP_BASE * UP_GROW ** (c[1] - 1)
                    need = 1 + (c[1] - 1) // 3
                    if self.parts[PART_OF[c[2]]] >= need:
                        opts.append((cost, "up", c, c[0] * GROWTH * c[3]))
            # Pit Stop income perk
            lv = self.perks.get("turbo", 0)
            if lv < 5:
                opts.append((PERKS["turbo"]["costs"][lv], "perk", "turbo", inc * 0.08 / max(1, 1 + 0.08 * lv)))
            for pid in ("backpack", "airbag", "lucky", "sneakers"):
                lv = self.perks.get(pid, 0)
                if lv < PERKS[pid]["max"]:
                    opts.append((PERKS[pid]["costs"][lv], "perk", pid, inc * 0.04))
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
            elif kind == "skin":
                self.skins.add(arg["id"])
                self.skin_bonus = max(self.skin_bonus, arg["bonus"])
            elif kind == "zone":
                self.zones.add(arg)
                self.mark(("R%d " % self.rebirths if self.rebirths else "") + "unlock " + arg)

    def gain_from_slot(self):
        incs = sorted((self.car_income(c) for c in self.cars), reverse=True)
        return incs[self.slots] if len(incs) > self.slots else 0.01

    def use_tuning(self):
        # 7 slots per car, ~+25% average per part; best parked cars first
        for c in sorted(self.cars, key=self.car_income, reverse=True)[: self.slots]:
            while self.tune > 0 and c[3] < 1 + 7 * 0.25:
                c[3] += 0.25
                self.tune -= 1

    def maybe_rebirth(self):
        zone, money = Skin.RebirthNeeds(self.rebirths)
        if self.rebirths >= 3 and "colosseum" not in self.zones:
            return  # finish the final boss first
        if zone in self.zones and self.money >= money:
            self.tokens += min(5, int(self.money // money))
            self.rebirths += 1
            self.reset()
            self.mark(f"rebirth {self.rebirths}")

    def cycle(self):
        # offline earnings after each play session
        if self.t >= getattr(self, "next_away", P["session_h"] * 3600):
            self.next_away = self.t + P["session_h"] * 3600
            self.money += min(P["away_h"], 8) * 3600 * self.income() * 0.15
        self.do_run()
        self.throw_all()
        self.use_tuning()
        self.wait(P["think"])
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


TARGETS = [("first car", 0, 2 / 60), ("unlock highway", 0.2, 0.6), ("unlock neon", 2.5, 5), ("rebirth 1", 4, 8),
           ("R1 unlock docks", 6, 14), ("rebirth 3", 25, 45), ("R3 unlock circuit", 28, 55), ("colosseum (final boss)", 70, 140)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=1)
    ap.add_argument("--hours", type=float, default=200)
    a = ap.parse_args()
    results = {}
    for s in range(a.runs):
        p = simulate(s + 1, a.hours)
        for name, t in p.log:
            results.setdefault(name, []).append(t / 3600)
    order = sorted(results, key=lambda k: statistics.median(results[k]))
    print(f"{'milestone':32s} {'median h':>9s}   target")
    tmap = {n: (lo, hi) for n, lo, hi in TARGETS}
    for k in order:
        med = statistics.median(results[k])
        tgt = tmap.get(k)
        flag = ""
        if tgt:
            flag = f"{tgt[0]:>5.1f}-{tgt[1]:<5.1f} " + ("ok" if tgt[0] <= med <= tgt[1] else "OFF")
        print(f"{k:32s} {med:9.2f}   {flag}")
    for n, _, _ in TARGETS:
        if n not in results:
            print(f"{n:32s}   never reached")


if __name__ == "__main__":
    main()
