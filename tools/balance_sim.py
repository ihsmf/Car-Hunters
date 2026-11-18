"""Progression simulator: how long does a typical player need to reach each table?
    python3 tools/balance_sim.py
Mirrors the formulas in src/shared/Config.luau (keep the two in sync)."""
import math, random, re, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
cfg = open(os.path.join(ROOT, "src/shared/Config.luau"), encoding="utf-8").read()
N = len(re.findall(r'\{ "[^"]+", rgb\(\d+, \d+, \d+\), "', cfg))
LENGTH = float(re.search(r"Length = (\d+)", cfg).group(1))
ZONE = LENGTH / N
CUES = [(float(m), float(p)) for m, p in re.findall(r'\{ "\w+", ([\d.]+), ([\de.]+), rgb', cfg)]
VARIANTS = [(1, None)] + [(int(m), int(o)) for m, o in re.findall(r"mult = (\d+), oneIn = (\d+)", cfg)]
TRAIN_REP = 1.2


def lift_cost(lvl): return math.floor(100 * 3 ** (lvl - 1))
def threshold(k): return 80 * k * (1 + (k - 1) / 9)


def distance(power, strength, cue):
    raw, prev = power * (40 + 14 * strength ** (1 / 3)) * CUES[cue - 1][0], 0
    for k in range(1, N + 1):
        if raw < threshold(k):
            return (k - 1 + (raw - prev) / (threshold(k) - prev)) * ZONE
        prev = threshold(k)
    return LENGTH


def roll_time(dist, full): return 1.4 + dist / 300 if full else 0.8 + dist / 700
def throw_time(dist, full): return (2.2 + 0.8 if full else 0.6 + 0.3) + roll_time(dist, full)


def variant(rnd):
    r, acc = rnd.random(), 0
    for v in range(len(VARIANTS) - 1, 0, -1):
        acc += 1 / VARIANTS[v][1]
        if r < acc:
            return v
    return 0


def luck_track(start, tables, rnd):
    L = start
    for _ in range(tables):
        L += 0.03 + rnd.random() * 0.09
        if rnd.random() < 0.06:
            L += 0.5 + rnd.random() * 1.5
    return L


def luck_bonus(L, rnd):
    if rnd.random() >= 1 - 1 / L: return 0
    if L < 5 or rnd.random() >= 1 - 5 / L: return 1
    if L < 20 or rnd.random() >= 1 - 20 / L: return 2
    return 3


def simulate(hours=80, seed=1):
    rnd = random.Random(seed)
    t, cash, strength, dumb, cue = 0.0, 0.0, 0.0, 1, 1
    team = []  # incomes of characters on the base (max 8)
    best, reached, found = 0, {}, set()
    next_shot = 0.0
    while t < hours * 3600:
        inc = sum(team)
        cash += inc
        while cue < len(CUES) and cash >= CUES[cue][1]:  # greedy: next cue first
            cash -= CUES[cue][1]; cue += 1
        while cash >= lift_cost(dumb) and lift_cost(dumb) < max(200, inc * 120):
            cash -= lift_cost(dumb); dumb += 1
        if t >= next_shot:
            power = min(1, max(0.3, rnd.gauss(0.85, 0.1)))
            dist = distance(power, strength, cue)
            zone = max(1, min(N, math.ceil(dist / ZONE)))
            L = luck_track(1, zone, rnd)
            rarity = min(N, zone + luck_bonus(L, rnd))
            v = variant(rnd)
            found.add((rarity, v))
            income = math.floor(2.2 ** (rarity - 1)) * VARIANTS[v][0]
            team = sorted(team + [income], reverse=True)[:8]
            full = rarity >= 4 and rarity >= best - 2
            best = max(best, rarity)
            reached.setdefault(zone, t)
            next_shot = t + throw_time(dist, full) + 1
        else:  # trains while waiting: one rep every TRAIN_REP seconds
            strength += 3 * dumb / TRAIN_REP
        t += 1
    return reached, cue, dumb, strength, len(found)


if __name__ == "__main__":
    reached, cue, dumb, strength, found = simulate()
    print(f"{N} tables, {len(CUES)} cues")
    print("table  first reached")
    for z in sorted(reached):
        m = reached[z] / 60
        print(f"{z:5d}  {m:8.1f} min" if m < 120 else f"{z:5d}  {m / 60:8.1f} h")
    print(f"after 80 h: cue tier {cue}, dumbbell lvl {dumb}, strength {strength:.3g}, collection {found} / {N * len(VARIANTS)}")
