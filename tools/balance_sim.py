"""Progression simulator: how long does a typical player need to reach each table?
    python3 tools/balance_sim.py
Mirrors the formulas in src/shared/Config.luau (keep the two in sync)."""
import math, random

N, ZONE = 25, 80
RAR_INCOME = [math.floor(2.2 ** r) for r in range(N)]                # base income of rarity r+1
CUES = [(1, 0), (1.25, 500), (1.5, 1e4), (1.8, 3e5), (2.2, 1e7), (2.6, 4e8), (3.1, 2e10), (3.7, 1e12), (4.4, 6e13), (5.2, 4e15)]
LUCK = [1, 2, 3, 5, 10]


def lift_cost(lvl): return math.floor(100 * 3 ** (lvl - 1))
def distance(power, strength, cue): return min(2000, power * (40 + 6 * strength ** (1 / 3)) * CUES[cue - 1][0])
def throw_time(dist, full): return (1.6 + 1.4 + dist / 260 + 0.8) if full else (0.5 + 0.8 + dist / 600 + 0.3)


def luck_bonus(L, r1, r2):
    b = 1 if r1 < 1 - 1 / L else 0
    if b and L >= 5 and r2 < 1 - 5 / L:
        b = 2
    return b


def simulate(hours=40, seed=1):
    rnd = random.Random(seed)
    t, cash, strength, dumb, cue = 0.0, 0.0, 0, 1, 1
    team = []  # incomes of characters on the base (max 8)
    best_zone, reached = 0, {}
    next_shot = 0.0
    while t < hours * 3600:
        dt = 1.0
        inc = sum(team)
        cash += inc * dt
        # greedy shopping: next cue first, then the dumbbell if cheap relative to income
        while cue < len(CUES) and cash >= CUES[cue][1]:
            cash -= CUES[cue][1]; cue += 1
        while cash >= lift_cost(dumb) and lift_cost(dumb) < max(200, inc * 120):
            cash -= lift_cost(dumb); dumb += 1
        if t >= next_shot:
            power = min(1, max(0.3, rnd.gauss(0.85, 0.1)))
            dist = distance(power, strength, cue)
            zone = max(1, min(N, math.ceil(dist / ZONE)))
            L = LUCK[int(t // 30) % len(LUCK)]
            rarity = min(N, zone + luck_bonus(L, rnd.random(), rnd.random()))
            income = math.floor(RAR_INCOME[rarity - 1] * (1 + rnd.randrange(4) * 0.3))
            team = sorted(team + [income], reverse=True)[:8]
            cash += 0  # extra characters get sold: 30x income (ignored, minor)
            best_zone = max(best_zone, zone)
            reached.setdefault(zone, t)
            next_shot = t + throw_time(dist, rarity >= 4) + 1
            t += 1
            continue
        strength += dumb * 2.5  # ~2.5 lifts per second while waiting
        t += dt
    return reached, cue, dumb, strength


if __name__ == "__main__":
    reached, cue, dumb, strength = simulate()
    print("table  first reached")
    for z in sorted(reached):
        m = reached[z] / 60
        print(f"{z:5d}  {m:8.1f} min" if m < 120 else f"{z:5d}  {m / 60:8.1f} h")
    print(f"after 40 h: cue tier {cue}, dumbbell lvl {dumb}, strength {strength:.0f}")
