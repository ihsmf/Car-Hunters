"""Vertical 9:16 TikTok edit of CAR HUNTERS gameplay clips (silent - the music is added in TikTok).

  python3 tools/tiktok_edit.py --clips DIR --out docs/promo/tiktok_carhunters.mp4 [--frame SECONDS]

DIR holds c1.mp4 .. c5.mp4 (the owner's recordings). Every cut sits on a 150 BPM grid (0.4 s per beat), the
"drop" (boss shot) lands at 4.4 s. Each frame is cropped 9:16 from the source with a moving / zooming camera,
then flashes, whip blur, shake, chromatic split, darkening and pop-in captions are drawn with numpy + PIL.
--frame renders a single frame to a png (preview).
"""
import argparse, math, os, subprocess, sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

W, H, FPS = 1080, 1920, 30
FONT = next(f for f in ("/usr/share/fonts/opentype/inter/InterDisplay-Black.otf", "/usr/share/fonts/opentype/inter/Inter-Black.otf",
                        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf") if os.path.exists(f))
# content box of each clip in source pixels (c1/c2 are vertical recordings inside a landscape frame)
BOX = {"c1": (663, 0, 1269, 1080), "c2": (933, 0, 1787, 1520), "c3": None, "c4": None, "c5": None}

# clip, src in, src out, out seconds, camera (cx, cy, zoom) at start -> end (normalised to the content box), fx, caption
SEG = [
    ("c5", 1.3, 3.3, 1.6, (0.5, 0.42, 1.0), (0.5, 0.45, 1.3), {"flash": 1, "punch": 1}, ("MY GARAGE MAKES", "$56K / SECOND")),
    ("c2", 0.3, 3.4, 2.8, (0.5, 0.5, 1.05), (0.5, 0.5, 1.18), {"whip_in": 1}, ("DODGE THE", "TRAFFIC")),
    ("c2", 3.4, 6.0, 1.6, (0.5, 0.5, 1.2), (0.5, 0.45, 1.0), {"whip_in": 1}, None),
    ("c3", 1.6, 3.4, 2.4, (0.42, 0.55, 1.0), (0.22, 0.55, 1.15), {"flash": 1, "shake": 1, "red": 1, "chroma": 1}, ("OUTRUN THE", "BOSS")),
    ("c4", 1.8, 4.6, 1.6, (0.5, 0.6, 1.1), (0.58, 0.62, 1.25), {"whip_in": 1}, ("THROW YOUR", "LOOT")),
    ("c4", 6.6, 7.6, 0.8, (0.70, 0.58, 1.55), (0.70, 0.72, 2.3), {"punch": 1}, None),
    ("c4", 10.0, 11.9, 1.6, (0.45, 0.5, 1.55), (0.45, 0.52, 1.7), {"flash": 1, "dark_out": 1}, None),
    ("c4", 12.0, 14.4, 2.4, (0.47, 0.5, 1.7), (0.47, 0.5, 1.55), {"flash": 1, "chroma": 1, "punch": 1}, ("CATCH REAL", "CARS")),
    ("c4", 15.3, 18.6, 2.0, (0.42, 0.5, 1.55), (0.58, 0.5, 1.7), {"whip_in": 1}, None),
    ("c1", 0.0, 9.0, 3.2, (0.5, 0.5, 1.0), (0.5, 0.5, 1.12), {"whip_in": 1}, ("100 CARS TO", "COLLECT")),
    ("c5", 4.0, 10.5, 4.0, (0.5, 0.45, 1.25), (0.5, 0.5, 1.0), {"flash": 1, "end": 1}, None),
]


def probe(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height", "-of", "csv=p=0", path],
                         capture_output=True, text=True).stdout.strip().split(",")
    return int(out[0]), int(out[1])


def read_frames(path, t0, t1, n):
    """n frames evenly from [t0, t1) as RGB arrays (source resolution)."""
    w, h = probe(path)
    fps = n / max(t1 - t0, 1e-3)
    p = subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{t0:.3f}", "-i", path, "-t", f"{t1 - t0:.3f}", "-vf", f"fps={fps:.5f}",
                        "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
    frames = np.frombuffer(p, np.uint8).reshape(-1, h, w, 3)
    if len(frames) < n:  # pad with the last frame
        frames = np.concatenate([frames] + [frames[-1:]] * (n - len(frames)))
    return frames[:n]


def ease(u):
    return u * u * (3 - 2 * u)


def camera(img, box, cam, shake=(0, 0)):
    """crop a 9:16 window (centre cx, cy; zoom) out of the content box and scale it to W x H"""
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    cx, cy, z = cam
    ch = min(bh, bw * 16 / 9) / z
    cw = ch * 9 / 16
    px = x0 + min(max(cx * bw - cw / 2 + shake[0], 0), bw - cw)
    py = y0 + min(max(cy * bh - ch / 2 + shake[1], 0), bh - ch)
    return img.resize((W, H), Image.BILINEAR, box=(px, py, px + cw, py + ch))


_fonts = {}


def font(size):
    if size not in _fonts:
        _fonts[size] = ImageFont.truetype(FONT, size)
    return _fonts[size]


def caption(frame, lines, t, y=330):
    """pop-in two-line caption: line 1 white, line 2 big yellow; scale 1.35 -> 1 in 0.15 s"""
    if t < 0:
        return frame
    s = 1 + 0.35 * max(0.0, 1 - t / 0.15)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    yy = y
    for i, (txt, size, col) in enumerate(((lines[0], 78, (255, 255, 255)), (lines[1], 132, (255, 214, 64)))):
        f = font(int(size * s))
        tw = d.textlength(txt, font=f)
        while tw > W * 0.86 and f.size > 40:
            f = font(f.size - 6)
            tw = d.textlength(txt, font=f)
        d.text(((W - tw) / 2 + 8, yy + 10), txt, font=f, fill=(0, 0, 0, 150))  # drop shadow
        d.text(((W - tw) / 2, yy), txt, font=f, fill=col + (255,), stroke_width=max(6, f.size // 11), stroke_fill=(18, 18, 26, 255))
        yy += int(f.size * 1.05)
    return Image.alpha_composite(frame.convert("RGBA"), layer).convert("RGB")


def end_card(frame, t):
    a = min(1.0, max(0.0, t / 0.5))
    if a <= 0:
        return frame
    dark = Image.new("RGB", (W, H), (8, 8, 14))
    frame = Image.blend(frame, dark, 0.45 * a)
    return caption(frame, ("PLAY NOW ON ROBLOX", "CAR HUNTERS"), t, y=1150)


def fx(img, seg, u, t_local, dur, rng):
    f = seg[6]
    arr = np.asarray(img).astype(np.float32)
    if f.get("chroma") and t_local < 0.35:  # RGB split on impact
        k = int(18 * (1 - t_local / 0.35))
        arr[..., 0] = np.roll(arr[..., 0], k, axis=1)
        arr[..., 2] = np.roll(arr[..., 2], -k, axis=1)
    if f.get("red") and t_local < 0.5:
        arr[..., 0] = arr[..., 0] * (1 + 0.35 * (1 - t_local / 0.5))
    if f.get("flash") and t_local < 0.18:
        a = 0.9 * (1 - t_local / 0.18)
        arr = arr * (1 - a) + 255 * a
    if f.get("dark_out") and dur - t_local < 0.4:
        arr = arr * max(0.0, (dur - t_local) / 0.4)
    # soft vignette + a little contrast/saturation punch
    arr = np.clip((arr - 128) * 1.08 + 128, 0, 255)
    arr *= VIGNETTE
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


yy, xx = np.mgrid[0:H, 0:W]
VIGNETTE = (1 - 0.35 * (((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2) / 2)[..., None].astype(np.float32)


def render_segment(seg, clips, rng, only=None):
    name, s0, s1, dur, c0, c1, f, cap = seg
    n = int(round(dur * FPS))
    path = os.path.join(clips, name + ".mp4")
    w, h = probe(path)
    box = BOX[name] or (0, 0, w, h)
    idx = range(n) if only is None else [only]
    frames = read_frames(path, s0, s1, n)
    out = []
    for i in idx:
        t = i / FPS
        u = ease(i / max(n - 1, 1))
        cam = [c0[k] + (c1[k] - c0[k]) * u for k in range(3)]
        if f.get("punch") and t < 0.3:  # punch-in zoom on the cut
            cam[2] *= 1 + 0.25 * (1 - t / 0.3) ** 2
        sh = (0, 0)
        if f.get("shake"):
            amp = 26 * math.exp(-t * 2.2)
            sh = (rng.uniform(-amp, amp), rng.uniform(-amp, amp))
        img = camera(Image.fromarray(frames[i]), box, cam, sh)
        if f.get("whip_in") and t < 0.13:  # whip-pan blur into the shot
            k = int(90 * (1 - t / 0.13)) + 1
            a = np.asarray(img).astype(np.float32)
            acc = sum(np.roll(a, s, axis=1) for s in range(-k, k + 1, max(1, k // 6)))
            img = Image.fromarray((acc / len(range(-k, k + 1, max(1, k // 6)))).astype(np.uint8))
        img = fx(img, seg, u, t, dur, rng)
        if cap:
            img = caption(img, cap, t - 0.05)
        if f.get("end"):
            img = end_card(img, t - 1.2)
        out.append(img)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--clips", required=True)
    ap.add_argument("--out", default="docs/promo/tiktok_carhunters.mp4")
    ap.add_argument("--frame", type=float)
    a = ap.parse_args()
    rng = np.random.default_rng(7)
    if a.frame is not None:  # preview one frame
        t = a.frame
        for seg in SEG:
            if t < seg[3]:
                img = render_segment(seg, a.clips, rng, only=int(t * FPS))[0]
                img.save(a.out)
                print("saved", a.out)
                return
            t -= seg[3]
        sys.exit("past the end")
    os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)
    enc = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                            "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p", "-movflags", "+faststart", a.out],
                           stdin=subprocess.PIPE)
    total = 0
    for k, seg in enumerate(SEG):
        for img in render_segment(seg, a.clips, rng):
            enc.stdin.write(img.tobytes())
            total += 1
        print(f"segment {k + 1}/{len(SEG)} done ({total} frames)", flush=True)
    enc.stdin.close()
    enc.wait()
    print("wrote", a.out, total / FPS, "s")


if __name__ == "__main__":
    main()
