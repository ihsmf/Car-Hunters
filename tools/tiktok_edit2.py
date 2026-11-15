"""TikTok edit #2: "collected parts and caught a RARE car" - vertical 1080x1920, 24.8 s, silent (music added in TikTok).

  python3 tools/tiktok_edit2.py --clips DIR [--out docs/promo/tiktok_camaro.mp4] [--frame SECONDS]

DIR: d1.mp4, d2.mov, d3.mov, d4.mp4 (phone recordings, ~500 px tall). Layout: a big 0.98:1 window of the game in the
middle over a blurred, darkened copy filling the screen; captions above / below it. 150 BPM grid (0.4 s), the drop
(RARE reveal) at 14.8 s. Story: hook (the reveal) -> run & grab parts -> throw -> COMMON... -> one more try ->
glow build-up -> RARE!! -> drive into the garage -> end card.
"""
import argparse, math, os, subprocess, sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tiktok_edit import font, probe  # noqa: E402

W, H, FPS = 1080, 1920, 30
WIN_W, WIN_H, WIN_Y = 1080, 1100, 410  # game window in the middle
EXT = {"d1": "mp4", "d2": "mov", "d3": "mov", "d4": "mp4"}

# clip, src in, src out (src out < in = rewind), out seconds, cam start (cx, cy, zoom) -> end, fx, captions
# captions: list of (start s, end s, line1, line2, colour of line 2, y)
YEL, WHT, RED, GRY, GLD = (255, 214, 64), (255, 255, 255), (255, 70, 80), (190, 194, 204), (255, 196, 40)
SEG = [
    # 0.0 hook: flash-forward to the RARE reveal, then a rewind glitch
    ("d2", 10.55, 10.6, 1.2, (0.5, 0.42, 1.7), (0.5, 0.42, 2.2), {"flash": 1, "chroma": 0.4, "shake": 1, "rays": 1},
     [(0.0, 1.2, "WAIT FOR IT...", "DREAM CAR DROP?!", YEL, 150)]),
    ("d2", 10.6, 9.4, 0.4, (0.5, 0.42, 2.2), (0.5, 0.5, 1.0), {"glitch": 1}, []),
    # 1.6 run across the roads
    ("d4", 0.2, 4.2, 1.6, (0.5, 0.55, 1.1), (0.5, 0.55, 1.3), {"whip": 1}, [(0.0, 1.6, "STEP 1", "GRAB CAR PARTS", YEL, 150)]),
    ("d1", 2.4, 4.4, 1.2, (0.55, 0.55, 1.2), (0.42, 0.55, 1.6), {"whip": 1, "shake": 0.6}, [(0.2, 1.2, "", "DODGE TRAFFIC!", RED, 190)]),
    ("d1", 4.6, 7.8, 1.2, (0.5, 0.55, 1.2), (0.5, 0.55, 1.35), {"whip": 1, "counter": (1, 8)}, []),
    ("d4", 4.6, 8.0, 1.2, (0.5, 0.55, 1.2), (0.5, 0.55, 1.4), {"whip": 1, "counter": (8, 12)}, []),
    # 5.2 throw menu filling up
    ("d3", 2.6, 9.8, 1.6, (0.45, 0.5, 1.15), (0.6, 0.55, 1.6), {"punch": 1}, [(0.0, 1.6, "STEP 2", "THROW THEM ALL", YEL, 150)]),
    ("d3", 10.4, 13.0, 1.2, (0.5, 0.5, 1.2), (0.5, 0.55, 1.7), {"flash": 1, "dark_out": 1}, []),
    # 8.0 first try: COMMON...
    ("d3", 13.8, 15.8, 1.6, (0.5, 0.5, 1.5), (0.5, 0.5, 1.8), {"desat": 1}, [(0.3, 1.6, "TRY #1", "COMMON...", GRY, 150)]),
    ("d3", 15.8, 13.8, 0.4, (0.5, 0.5, 1.8), (0.5, 0.5, 1.0), {"glitch": 1}, []),
    # 10.0 one more try
    ("d2", 1.6, 5.0, 1.6, (0.62, 0.5, 1.2), (0.72, 0.62, 1.9), {"whip": 1}, [(0.0, 1.6, "ONE MORE", "TRY!", YEL, 150)]),
    ("d2", 5.6, 8.8, 1.6, (0.5, 0.5, 1.2), (0.5, 0.5, 2.0), {"build": 1}, [(0.6, 1.6, "", "COME ON...", WHT, 190)]),
    # 14.8 THE DROP: RARE reveal in slow motion, then a freeze on the car with a shockwave
    ("d2", 9.0, 10.55, 2.0, (0.5, 0.5, 1.15), (0.5, 0.45, 1.5), {"flash": 1, "chroma": 0.5, "shake": 1.4, "rays": 1},
     [(0.15, 2.0, "NEW CAR!!", "IT'S RARE!", GLD, 150)]),
    ("d2", 10.58, 10.6, 0.8, (0.5, 0.42, 1.9), (0.5, 0.42, 2.3), {"flash": 1, "shake": 1.2, "rays": 1, "ring": 1, "chroma": 0.5},
     [(0.0, 0.8, "LOOK AT", "THIS BEAST!!", GLD, 150)]),
    # 16.0 drives into the garage
    ("d2", 10.85, 14.6, 1.6, (0.5, 0.55, 1.3), (0.55, 0.55, 1.1), {"flash": 1, "whip": 1}, [(0.0, 1.6, "STRAIGHT TO", "MY GARAGE", YEL, 150)]),
    ("d2", 14.6, 18.4, 2.4, (0.5, 0.55, 1.1), (0.5, 0.5, 1.35), {"whip": 1}, [(0.4, 2.4, "", "+ $ EVERY SECOND", (110, 240, 140), 190)]),
    # 20.0 end card over the parked car
    ("d2", 16.5, 18.4, 3.2, (0.5, 0.5, 1.35), (0.5, 0.5, 1.6), {"end": 1}, []),
]


def read_frames(path, t0, t1, n):
    rev = t1 < t0
    a, b = (t1, t0) if rev else (t0, t1)
    w, h = probe(path)
    raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{a:.3f}", "-i", path, "-t", f"{b - a:.3f}", "-vf", f"fps={n / max(b - a, 1e-3):.5f}",
                          "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
    fr = np.frombuffer(raw, np.uint8).reshape(-1, h, w, 3)
    if len(fr) < n:
        fr = np.concatenate([fr] + [fr[-1:]] * (n - len(fr)))
    fr = fr[:n]
    return fr[::-1] if rev else fr


def ease(u):
    return u * u * (3 - 2 * u)


def window(img, cam):
    """crop (cx, cy, zoom) with the window's aspect, scaled to WIN_W x WIN_H"""
    sw, sh = img.size
    cx, cy, z = cam
    asp = WIN_W / WIN_H
    ch = min(sh, sw / asp) / z
    cw = ch * asp
    px = min(max(cx * sw - cw / 2, 0), sw - cw)
    py = min(max(cy * sh - ch / 2, 0), sh - ch)
    return img.resize((WIN_W, WIN_H), Image.BICUBIC, box=(px, py, px + cw, py + ch))


def background(img):
    sw, sh = img.size
    small = img.resize((180, int(180 * sh / sw)))
    k = max(H / small.size[1], W / small.size[0])
    bg = small.resize((int(small.size[0] * k) + 2, int(small.size[1] * k) + 2), Image.BILINEAR).filter(ImageFilter.GaussianBlur(4))
    bx, by = (bg.size[0] - W) // 2, (bg.size[1] - H) // 2
    bg = bg.crop((bx, by, bx + W, by + H)).filter(ImageFilter.GaussianBlur(18))
    return Image.eval(bg, lambda v: int(v * 0.42))


def text_block(d, line1, line2, col, y, t):
    s = 1 + 0.4 * max(0.0, 1 - t / 0.14)  # pop-in
    yy = y
    for txt, size, c in ((line1, 70, WHT), (line2, 128, col)):
        if not txt:
            continue
        f = font(int(size * s))
        tw = d.textlength(txt, font=f)
        while tw > W * 0.9 and f.size > 40:
            f = font(f.size - 6)
            tw = d.textlength(txt, font=f)
        x = (W - tw) / 2
        d.text((x + 8, yy + 10), txt, font=f, fill=(0, 0, 0, 160))
        d.text((x, yy), txt, font=f, fill=c + (255,), stroke_width=max(6, f.size // 10), stroke_fill=(16, 16, 24, 255))
        yy += int(f.size * 1.08)


def overlay_rays(layer, t, strength):
    d = ImageDraw.Draw(layer)
    cx, cy = W / 2, WIN_Y + WIN_H / 2
    for k in range(24):
        a = k / 24 * math.tau + t * 0.6
        r0, r1 = 120, 1400
        pts = [(cx + math.cos(a - 0.05) * r0, cy + math.sin(a - 0.05) * r0), (cx + math.cos(a) * r1, cy + math.sin(a) * r1),
               (cx + math.cos(a + 0.05) * r0, cy + math.sin(a + 0.05) * r0)]
        d.polygon(pts, fill=(255, 220, 120, int(40 * strength)))


def render(seg, clips, only=None):
    name, s0, s1, dur, c0, c1, f, caps = seg
    n = int(round(dur * FPS))
    path = os.path.join(clips, f"{name}.{EXT[name]}")
    frames = read_frames(path, s0, s1, n)
    rng = np.random.default_rng(int(s0 * 100) + n)
    out = []
    for i in (range(n) if only is None else [only]):
        t = i / FPS
        u = ease(i / max(n - 1, 1))
        cam = [c0[k] + (c1[k] - c0[k]) * u for k in range(3)]
        if f.get("punch") and t < 0.3:
            cam[2] *= 1 + 0.3 * (1 - t / 0.3) ** 2
        if f.get("build"):  # zoom keeps pushing in, faster and faster
            cam[2] *= 1 + 0.25 * u * u
        src = Image.fromarray(frames[i])
        win = window(src, cam)
        canvas = background(src)
        ox, oy = 0, 0
        amp = 0
        if f.get("shake"):
            amp = 30 * f["shake"] * math.exp(-t * 2.5)
        if f.get("build"):
            amp = 4 + 22 * u * u
        if amp:
            ox, oy = int(rng.uniform(-amp, amp)), int(rng.uniform(-amp, amp))
        canvas.paste(win, (ox, WIN_Y + oy))
        a = np.asarray(canvas).astype(np.float32)
        if f.get("whip") and t < 0.12:  # whip-pan smear
            k = int(80 * (1 - t / 0.12)) + 1
            steps = list(range(-k, k + 1, max(1, k // 6)))
            a = sum(np.roll(a, s, axis=1) for s in steps) / len(steps)
        if f.get("glitch"):  # rewind glitch: torn horizontal slices + RGB split
            for _ in range(10):
                y0 = int(rng.uniform(0, H - 60))
                hgt = int(rng.uniform(10, 90))
                a[y0:y0 + hgt] = np.roll(a[y0:y0 + hgt], int(rng.uniform(-140, 140)), axis=1)
            a[..., 0] = np.roll(a[..., 0], 14, axis=1)
            a[..., 2] = np.roll(a[..., 2], -14, axis=1)
        if f.get("chroma") and t < 0.5:
            k = int(26 * f["chroma"] * 2 * (1 - t / 0.5))
            a[..., 0] = np.roll(a[..., 0], k, axis=1)
            a[..., 2] = np.roll(a[..., 2], -k, axis=1)
        if f.get("desat"):  # sad grey + dark edges
            g = a.mean(axis=2, keepdims=True)
            a = a * 0.25 + g * 0.75
            a *= 0.85
        if f.get("build"):  # light builds up towards the drop
            a = a * (1 + 0.5 * u * u)
        if f.get("flash") and t < 0.2:
            al = 0.95 * (1 - t / 0.2)
            a = a * (1 - al) + 255 * al
        if f.get("dark_out") and dur - t < 0.35:
            a *= max(0.0, (dur - t) / 0.35)
        a = np.clip((a - 128) * 1.1 + 128, 0, 255) * VIG
        img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).convert("RGBA")
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        if f.get("rays"):
            overlay_rays(layer, t, min(1, t / 0.2) * (1 if dur - t > 0.3 else (dur - t) / 0.3))
        d = ImageDraw.Draw(layer)
        if f.get("ring") and t < 0.9:  # shockwave ring from the car
            r = 80 + t / 0.9 * 1200
            cx, cy = W / 2, WIN_Y + WIN_H / 2
            d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(255, 230, 140, int(220 * (1 - t / 0.9))), width=int(26 * (1 - t / 0.9)) + 2)
        if f.get("counter"):  # parts counter climbing
            lo, hi = f["counter"]
            v = int(lo + (hi - lo) * u)
            d.rounded_rectangle((W / 2 - 220, WIN_Y + WIN_H + 40, W / 2 + 220, WIN_Y + WIN_H + 150), radius=30, fill=(20, 22, 30, 210),
                                outline=YEL + (255,), width=6)
            txt = f"PARTS: {v}"
            fo = font(72)
            d.text(((W - d.textlength(txt, font=fo)) / 2, WIN_Y + WIN_H + 52), txt, font=fo, fill=YEL + (255,))
        for (a0, a1, l1, l2, col, y) in caps:
            if a0 <= t < a1:
                text_block(d, l1, l2, col, y, t - a0)
        if f.get("end"):
            k = min(1.0, t / 0.4)
            d.rectangle((0, 0, W, H), fill=(6, 6, 12, int(150 * k)))
            if t > 0.2:
                text_block(d, "PLAY NOW ON ROBLOX", "CAR HUNTERS", YEL, 780, t - 0.2)
            if t > 0.8:
                text_block(d, "", "CATCH YOUR DREAM CAR", WHT, 1090, t - 0.8)
        out.append(Image.alpha_composite(img, layer).convert("RGB"))
    return out


yy, xx = np.mgrid[0:H, 0:W]
VIG = (1 - 0.32 * (((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2) / 2)[..., None].astype(np.float32)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--clips", required=True)
    ap.add_argument("--out", default="docs/promo/tiktok_camaro.mp4")
    ap.add_argument("--frame", type=float)
    a = ap.parse_args()
    if a.frame is not None:
        t = a.frame
        for seg in SEG:
            if t < seg[3]:
                render(seg, a.clips, only=int(t * FPS))[0].save(a.out)
                return
            t -= seg[3]
        sys.exit("past the end")
    os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)
    enc = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                            "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p", "-movflags", "+faststart", a.out], stdin=subprocess.PIPE)
    total = 0
    for k, seg in enumerate(SEG):
        for img in render(seg, a.clips):
            enc.stdin.write(img.tobytes())
            total += 1
        print(f"segment {k + 1}/{len(SEG)} ({total} frames)", flush=True)
    enc.stdin.close()
    enc.wait()
    print("wrote", a.out, total / FPS, "s")


if __name__ == "__main__":
    main()
