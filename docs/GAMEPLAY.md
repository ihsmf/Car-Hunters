# CAR HUNTERS — gameplay (v6)

## The core loop (one sentence)
Run into a district, grab car parts without getting hit, carry them home, throw them into your garage trap in one batch,
and watch the cars you win start earning money — which unlocks deeper, more dangerous districts with better parts.

```
HUNT (1–3 min) ──► BANK (run home) ──► THROW (batch) ──► PARK / UPGRADE / TUNE ──► UNLOCK next district
   ▲                                                                                     │
   └──────────────────────── better parts, bigger risk ◄───────────────────────────────┘
                     every ~4 / 14 / 28 h:  REBIRTH (reset for +25 % income forever + tokens)
```

## What each system is for (and only that)
| System | Job in the loop | Uses |
|---|---|---|
| Districts + traffic | Risk vs reward: deeper = better parts, longer run home, one hit = lose the run | parts |
| Running lanes | Fast, readable way out and back — **one pair in the middle of the map** (out / home) | — |
| Combo, road crates, Hot Drop | Second-to-second decisions during a run | parts |
| Trap (batch throw) | Turn parts into cars, the "pack opening" moment | parts → cars |
| Merge duplicates | Duplicates are progress, not clutter: +1 level up to Lv3 | cars |
| Garage bays / floors | Which cars actually earn | money |
| Upgrades & tuning | Make favourite cars stronger (levels 4–10 need money + parts) | money, parts |
| Contracts + Big Tony | Short goals that point at a district / action; Tony pays out and trades parts for tuning | parts, money |
| Bosses | A spike of tension at the end of each tier; scaring the truck pays tuning parts | cheapest part |
| Rebirth | Long-term reset with a permanent bonus | everything |
| Offline earnings | Coming back is rewarded: 15 % of income for up to 8 h away | — |

## Session pacing (target, checked with `tools/econ_sim.py`)
- **First 5 minutes:** spawn → hint "grab a glowing part" → first part → run home → throw → first car parks itself and
  income starts. The hint line always shows exactly one next goal.
- **First hour:** Highway (~12 min), Industrial (~45 min), first Legendary is rare (≈ 45 min–2 h depending on luck),
  second garage floor.
- **First day of play:** Night district, Scrapyard boss, first rebirth (~3.5–4 h of play; the first offline payout
  speeds this up a little), Tier 2 starts (~6 h).
- **Long term:** 2nd/3rd rebirth (~14 h / ~28 h), Tier 3 + Stage 3 tuning (~43 h), Colosseum final boss (~110 h).

## What changed in v6 and why
1. **Batch throw** — the old one-part-one-cinematic loop was the main grind (6+ s per part). Now: choose a count per
   part (stepper, MAX, ALL, x10) and see the expected cars before throwing; a 3-second reel and a results grid replace
   25 cinematics; the best car still gets the full showcase and drive-in.
2. **Merge duplicates** — batch throws produce many repeats; merging levels up the car you own (up to Lv3), so every
   throw counts and the garage stays tidy. Levels 4–10 still need upgrades (money + parts), keeping upgrades meaningful.
3. **Auto-park after throws** — new good cars start earning immediately; no menu trip needed.
4. **Offline earnings** — a reason to come back; capped at 8 h and 15 % so active play stays far better. Optional 2×
   product.
5. **One clear next goal** — the hint line names the next district and its price, or the rebirth requirement.
6. **Central running lanes only** — the lanes to every garage made the plaza noisy and crossed props; one pair down
   the middle is easy to read and always points the same way (out / home).
7. **Economy re-tuned** — district prices ×1.7, rebirth base $150M ×2.2 per rebirth, merge cap 3, offline 15 %,
   so the faster loop does not halve the game.

## Cut or kept deliberately small
- No new currencies (rebirth tokens are the only extra one).
- No daily quest board / battle pass — contracts already give short goals.
- Selling cars is now rare (merge + auto-sell only when storage is full).

## Risks to watch in play tests
- Batch of 100 bolts can feel like spam → the reel always lands on the best car; consider a min 5 parts for batches.
- Offline 2× product must not feel mandatory (it is a one-time doubling of a 15 % share).
- Merge cap 3 may feel low for Commons; raise per rarity if players ask (Common 5, Legendary 3).
