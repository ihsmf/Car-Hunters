"""TikTok edit #3: "61 PARTS IN ONE THROW -> EPIC SUPERCAR -> TUNED IT" - vertical 1080x1920, 20 s, silent.

  python3 tools/tiktok_edit3.py --clips DIR [--out docs/promo/tiktok_epic.mp4] [--frame SECONDS]

DIR: e1.mov (throw 61 parts -> EPIC! -> ORBITAL SEVEN-TWENTY -> drive-in), e2.mov (Big Tony), e3.mp4 (garage + tuning).
Same renderer as tiktok_edit2.py (window over a blurred copy, captions, flashes, glitches, rays, shockwave); 150 BPM grid
(0.4 s), the drop (EPIC! title) at 4.8 s, the reveal at 6.0 s.
"""
import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tiktok_edit2 as E  # noqa: E402

YEL, WHT, GLD, PNK, GRN = E.YEL, E.WHT, E.GLD, (255, 90, 150), (110, 240, 140)
E.EXT.update({"e1": "mov", "e2": "mov", "e3": "mp4"})
E.SEG[:] = [
    # 0.0 hook: freeze on the EPIC car, then rewind
    ("e1", 6.4, 6.42, 1.2, (0.5, 0.55, 1.5), (0.5, 0.55, 1.95), {"flash": 1, "chroma": 0.5, "shake": 1, "rays": 1},
     [(0.0, 1.2, "I THREW 61 PARTS", "AT ONCE...", YEL, 150)]),
    ("e1", 6.4, 4.9, 0.4, (0.5, 0.55, 1.95), (0.5, 0.5, 1.0), {"glitch": 1}, []),
    # 1.6 the throw menu: 61 parts, zoom on the button
    ("e1", 0.0, 1.3, 1.2, (0.52, 0.5, 1.0), (0.64, 0.74, 2.0), {"whip": 1}, [(0.0, 1.2, "ALL MY PARTS", "61 PARTS!", YEL, 150)]),
    # 2.8 the trap charges (sped up), pressure builds
    ("e1", 1.4, 4.6, 2.0, (0.45, 0.6, 1.1), (0.45, 0.62, 1.7), {"build": 1, "flash": 1}, [(0.3, 2.0, "", "COME ON...", WHT, 190)]),
    # 4.8 THE DROP: EPIC! title
    ("e1", 4.75, 5.45, 1.2, (0.45, 0.45, 1.5), (0.45, 0.45, 1.2), {"flash": 1, "chroma": 0.6, "shake": 1.5, "ring": 1}, []),
    # 6.0 reveal in slow motion
    ("e1", 5.95, 8.2, 2.8, (0.5, 0.55, 1.15), (0.5, 0.55, 1.6), {"flash": 1, "rays": 1, "shake": 0.8, "chroma": 0.3},
     [(0.1, 2.8, "IT'S EPIC!!", "SUPERCAR!", PNK, 150)]),
    # 8.8 drives home
    ("e1", 8.6, 11.0, 1.6, (0.5, 0.6, 1.4), (0.5, 0.55, 1.1), {"flash": 1, "whip": 1}, [(0.0, 1.6, "STRAIGHT TO", "MY GARAGE", YEL, 150)]),
    ("e1", 11.0, 14.0, 1.6, (0.5, 0.55, 1.05), (0.5, 0.6, 1.3), {"whip": 1}, [(0.2, 1.6, "", "+ $601 / SEC", GRN, 190)]),
    # 12.0 Big Tony builds tuning parts
    ("e2", 1.0, 3.3, 1.2, (0.5, 0.45, 1.05), (0.42, 0.42, 1.35), {"whip": 1}, [(0.0, 1.2, "BUT THAT'S", "NOT ENOUGH...", YEL, 150)]),
    # 13.2 tune it: 601/s -> 661/s
    ("e3", 11.0, 12.7, 2.0, (0.5, 0.5, 1.05), (0.42, 0.33, 1.7), {"punch": 1, "flash": 1},
     [(0.0, 0.9, "CHIP TUNE", "INSTALLED", YEL, 150), (0.9, 2.0, "", "+10% INCOME!", GRN, 150)]),
    # 15.2 the garage, both supercars
    ("e3", 0.2, 2.2, 1.6, (0.55, 0.45, 1.2), (0.6, 0.42, 1.45), {"flash": 1, "whip": 1}, [(0.0, 1.6, "MY GARAGE", "IS GROWING", YEL, 150)]),
    # 16.8 end card over the parked car
    ("e1", 12.6, 14.0, 3.2, (0.5, 0.6, 1.3), (0.5, 0.6, 1.55), {"end": 1}, []),
]

if __name__ == "__main__":
    if "--out" not in sys.argv and "--frame" not in sys.argv:
        sys.argv += ["--out", "docs/promo/tiktok_epic.mp4"]
    E.main()
