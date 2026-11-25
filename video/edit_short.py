"""CUE HUNTERS short: edit a 1920x752 gameplay capture into a 1080x1920 (9:16, centre crop) TikTok/Shorts video
with speed ramps, zoom punches, shake, flashes, glitch cuts, captions, a progress bar, an end card and an original
generated beat + game SFX.
    python3 video/edit_short.py <input.mp4> <out.mp4> <workdir>"""
import math, os, random, subprocess, sys, wave
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

SRC, OUT, WORK = sys.argv[1], sys.argv[2], sys.argv[3]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, "blender", "fonts", "LuckiestGuy.ttf")
W, H, FPS, SRC_FPS = 1080, 1920, 30, 50
CW, CX = 422, (1920 - 422) // 2  # 9:16 crop of the 752-high capture, from the middle
os.makedirs(WORK, exist_ok=True)
rnd = random.Random(3)

# (source start, source end, speed, caption, effects)
SEGMENTS = [
    (28.9, 30.3, 0.8, "1 IN 10000000000000...?!", {"hook": 1}),
    (1.6, 3.0, 1.4, "THE LONGEST POOL TABLE IN ROBLOX", {}),
    (12.0, 12.9, 0.45, "WATCH THE LUCK...", {"punch_at": [0.55]}),
    (12.9, 18.2, 1.35, "FROM X1 TO X1,000,000,000,000!", {"punch_every": 0.42, "shake": 0.25}),
    (18.3, 21.0, 1.0, "THE GOD OF BILLIARDS", {"punch_at": [0.6, 1.4]}),
    (21.0, 24.0, 1.15, "PLANET GOES BOOM", {"shake": 1.0, "punch_every": 0.5}),
    (24.0, 26.6, 1.0, "...WAIT WHAT?!", {"glitch": 1}),
    (26.6, 28.6, 1.5, None, {"shake": 0.4}),
    (28.6, 31.0, 0.7, "SUPER AURA UNLOCKED", {"punch_at": [0.3], "flash_at": [0.3]}),
    (31.6, 33.8, 1.0, None, {}),
]
END_CARD = 2.2


def font(size):
    return ImageFont.truetype(FONT, size)


def caption_img(text, size=96, color=(255, 255, 255), width=W - 80):
    f = font(size)
    while f.getlength(text) > width and size > 40:
        size -= 4
        f = font(size)
    tw = int(f.getlength(text)) + 60
    img = Image.new("RGBA", (tw, size + 70), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.text((36, 40), text, font=f, fill=(20, 8, 40, 200))
    d.text((30, 30), text, font=f, fill=color, stroke_width=10, stroke_fill=(30, 15, 60))
    return img


def read_frames(t0, t1):
    """Cropped source frames (CW x 752) between t0 and t1 at the source frame rate."""
    cmd = ["ffmpeg", "-v", "error", "-ss", f"{t0:.3f}", "-to", f"{t1 + 0.1:.3f}", "-i", SRC,
           "-vf", f"crop={CW}:752:{CX}:0", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    n = len(raw) // (CW * 752 * 3)
    return np.frombuffer(raw, np.uint8)[: n * CW * 752 * 3].reshape(n, 752, CW, 3)


def grade(im):
    im = ImageEnhance.Color(im).enhance(1.28)
    im = ImageEnhance.Contrast(im).enhance(1.1)
    return im


VIGNETTE = None


def vignette():
    global VIGNETTE
    if VIGNETTE is None:
        m = Image.new("L", (W, H), 0)
        ImageDraw.Draw(m).ellipse((-350, -300, W + 350, H + 300), fill=255)
        VIGNETTE = m.filter(ImageFilter.GaussianBlur(200))
    return VIGNETTE


# ---------- video ----------
total = sum((b - a) / s for a, b, s, _, _ in SEGMENTS) + END_CARD
nframes = int(total * FPS)
enc = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS),
                        "-i", "-", "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
                        os.path.join(WORK, "video.mp4")], stdin=subprocess.PIPE)
events = []  # (time, kind) for the sound design
t_out = 0.0
frame_no = 0
dark = Image.new("RGB", (W, H), (15, 6, 30))
for si, (a, b, speed, cap, fx) in enumerate(SEGMENTS):
    frames = read_frames(a, b)
    seg_len = (b - a) / speed
    n = int(round(seg_len * FPS))
    cap_img = caption_img(cap, 100 if fx.get("hook") else 92, (255, 230, 80) if fx.get("hook") else (255, 255, 255)) if cap else None
    punches = list(fx.get("punch_at", []))
    if fx.get("punch_every"):
        punches += [k * fx["punch_every"] for k in range(1, int(seg_len / fx["punch_every"]) + 1)]
    events.append((t_out, "cut" if si else "hook"))
    for p in punches:
        events.append((t_out + p, "punch"))
    for p in fx.get("flash_at", []):
        events.append((t_out + p, "impact"))
    for k in range(n):
        lt = k / FPS  # local output time
        src_pos = lt * speed * SRC_FPS
        i0 = min(int(src_pos), len(frames) - 1)
        i1 = min(i0 + 1, len(frames) - 1)
        f = src_pos - int(src_pos)
        px = frames[i0].astype(np.float32) * (1 - f) + frames[i1].astype(np.float32) * f if speed < 1 else frames[i0]
        im = Image.fromarray(px.astype(np.uint8)).resize((W, H), Image.LANCZOS)
        im = grade(im)
        # zoom: slow push-in + punches
        z = 1.0 + 0.05 * lt / max(seg_len, 0.1)
        for p in punches:
            if 0 <= lt - p < 0.3:
                z += 0.14 * (1 - (lt - p) / 0.3) ** 2
        if lt < 0.18:  # every cut starts with a punch
            z += 0.1 * (1 - lt / 0.18)
        sx = sy = 0
        if fx.get("shake"):
            amp = 26 * fx["shake"] * (0.6 + 0.4 * math.sin(lt * 23))
            sx, sy = rnd.uniform(-amp, amp), rnd.uniform(-amp, amp)
        if z > 1.001 or sx or sy:
            zw, zh = int(W / z), int(H / z)
            x0 = int((W - zw) / 2 + sx)
            y0 = int((H - zh) / 2 + sy)
            x0, y0 = max(0, min(W - zw, x0)), max(0, min(H - zh, y0))
            im = im.crop((x0, y0, x0 + zw, y0 + zh)).resize((W, H), Image.BILINEAR)
        arr = np.asarray(im).copy()
        # glitch: RGB split + slice offsets at cuts and in glitch segments
        g = (lt < 0.1) or (fx.get("glitch") and rnd.random() < 0.35)
        if g:
            s = rnd.randint(10, 34)
            arr[:, s:, 0] = arr[:, :-s, 0]
            arr[:, :-s, 2] = arr[:, s:, 2]
            for _ in range(rnd.randint(2, 6)):
                y = rnd.randint(0, H - 80)
                hgt = rnd.randint(10, 80)
                arr[y:y + hgt] = np.roll(arr[y:y + hgt], rnd.randint(-80, 80), axis=1)
        im = Image.fromarray(arr)
        im = Image.composite(im, dark, vignette().point(lambda v: int(120 + v * 135 / 255)))
        # flash at cuts and on flash events
        fl = 0.0
        if lt < 0.12 and si:
            fl = 0.75 * (1 - lt / 0.12)
        for p in fx.get("flash_at", []):
            if 0 <= lt - p < 0.35:
                fl = max(fl, 1 - (lt - p) / 0.35)
        if fl > 0:
            im = Image.blend(im, Image.new("RGB", (W, H), (255, 255, 255)), min(1, fl))
        im = im.convert("RGBA")
        if cap_img:  # caption pops in with an overshoot, wobbles slightly
            pop = min(1, lt / 0.22)
            sc = (1.35 - 0.35 * pop) if pop < 1 else 1 + 0.03 * math.sin(lt * 7)
            ci = cap_img.resize((max(1, int(cap_img.width * sc)), max(1, int(cap_img.height * sc))), Image.BILINEAR)
            ci = ci.rotate(2.5 * math.sin(lt * 5), expand=True, resample=Image.BILINEAR)
            cy = 470 if fx.get("hook") else 1380
            im.alpha_composite(ci, ((W - ci.width) // 2, cy - ci.height // 2))
        enc.stdin.write(im.convert("RGB").tobytes())
        frame_no += 1
    t_out += n / FPS

# end card: logo, god cut-out, "PLAY NOW"
events.append((t_out, "end"))
god = Image.open(os.path.join(WORK, "god_cut.png")).convert("RGBA")
god = god.resize((int(god.width * 1500 / god.height), 1500), Image.LANCZOS)
bg = Image.open(os.path.join(ROOT, "blender", "export", "thumbnail.png")).convert("RGB")
bg = bg.crop(((bg.width - int(bg.height * 9 / 16)) // 2 - 300, 0, (bg.width - int(bg.height * 9 / 16)) // 2 - 300 + int(bg.height * 9 / 16), bg.height))
bg = bg.resize((W, H)).filter(ImageFilter.GaussianBlur(14))
bg = ImageEnhance.Brightness(bg).enhance(0.55).convert("RGBA")
logo1, logo2 = caption_img("CUE", 220), caption_img("HUNTERS", 190, (255, 210, 80))
play = caption_img("PLAY NOW ON ROBLOX!", 80, (130, 255, 140))
for k in range(int(END_CARD * FPS)):
    lt = k / FPS
    im = bg.copy()
    glow = Image.new("RGBA", (W, H), (255, 215, 120, 0))
    rays = Image.new("L", (W, H), 0)
    dr = ImageDraw.Draw(rays)
    for r in range(18):
        a0 = r * 20 + lt * 25
        dr.pieslice((-W, -H // 2, 2 * W, int(1.5 * H)), a0, a0 + 9, fill=55)
    glow.putalpha(rays.filter(ImageFilter.GaussianBlur(10)))
    im.alpha_composite(glow)
    gy = int(560 - 80 * (1 - min(1, lt / 0.4)) ** 2)
    im.alpha_composite(god, ((W - god.width) // 2 + 120, gy))
    pop = min(1, lt / 0.25)
    for img, y in ((logo1, 230), (logo2, 430)):
        s = 1.4 - 0.4 * pop
        li = img.resize((int(img.width * s), int(img.height * s)), Image.BILINEAR)
        im.alpha_composite(li, ((W - li.width) // 2, y - li.height // 2))
    if lt > 0.4:
        s = 1 + 0.06 * math.sin(lt * 9)
        pi = play.resize((int(play.width * s), int(play.height * s)), Image.BILINEAR)
        im.alpha_composite(pi, ((W - pi.width) // 2, 1720 - pi.height // 2))
    if lt < 0.12:
        im = Image.blend(im.convert("RGB"), Image.new("RGB", (W, H), (255, 255, 255)), 0.8 * (1 - lt / 0.12)).convert("RGBA")
    enc.stdin.write(im.convert("RGB").tobytes())
enc.stdin.close()
enc.wait()

# ---------- audio: original 140 BPM beat + SFX ----------
SR = 44100
N = int(total * SR) + SR
mix = np.zeros(N, np.float32)
tt = np.arange(N) / SR


def add(sig, at, gain=1.0):
    i = int(at * SR)
    if i >= N:
        return
    sig = sig[: N - i]
    mix[i:i + len(sig)] += sig * gain


def env(n, a=0.002, d=0.2):
    t = np.arange(n) / SR
    return np.minimum(1, t / a) * np.exp(-t / d)


def kick():
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 50 + 120 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.001, 0.18)


def snare():
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    return (np.random.default_rng(1).normal(0, 1, n) * 0.6 + np.sin(2 * np.pi * 190 * t) * 0.5) * env(n, 0.001, 0.07)


def hat():
    n = int(0.06 * SR)
    noise = np.random.default_rng(2).normal(0, 1, n)
    return np.diff(np.concatenate([[0], noise])) * env(n, 0.0005, 0.015)


def bass(freq, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(4 * np.pi * freq * t)
    return np.tanh(s * 1.8) * env(n, 0.005, dur * 0.8)


def whoosh(dur=0.5):
    n = int(dur * SR)
    noise = np.random.default_rng(4).normal(0, 1, n)
    k = np.linspace(0, 1, n)
    out = np.zeros(n)
    acc = 0
    for i in range(n):  # sweeping low-pass
        a = 0.02 + 0.5 * k[i] ** 2
        acc += a * (noise[i] - acc)
        out[i] = acc
    return out * np.sin(np.pi * k) * 1.2


def riser(dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 200 + 1800 * (t / dur) ** 2
    return (np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.4 + np.random.default_rng(5).normal(0, 0.3, n)) * (t / dur) ** 1.5


def impact():
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    sub = np.sin(2 * np.pi * (35 + 60 * np.exp(-t * 6)) * t) * np.exp(-t * 2.2)
    crash = np.random.default_rng(6).normal(0, 1, n) * np.exp(-t * 5) * 0.5
    return sub + crash


def wav(path):
    with wave.open(path) as w:
        d = np.frombuffer(w.readframes(w.getnframes()), np.int16 if w.getsampwidth() == 2 else np.uint8).astype(np.float32)
        d = d / 32768 if w.getsampwidth() == 2 else (d - 128) / 128
        if w.getnchannels() == 2:
            d = d.reshape(-1, 2).mean(1)
        if w.getframerate() != SR:
            d = np.interp(np.arange(0, len(d), w.getframerate() / SR), np.arange(len(d)), d)
        return d


beat = 60 / 140
K, Sn, Hh = kick(), snare(), hat()
notes = [55, 55, 65.4, 49]  # A1 A1 C2 G1
reveal = next(t for t, k in events if k == "impact")
for i in range(int(total / beat) + 1):
    t = i * beat
    drop_gap = reveal - 1.6 <= t < reveal  # silence before the drop, the riser takes over
    if drop_gap:
        continue
    if i % 4 in (0, 2) or (i % 8 == 7):
        add(K, t, 0.9)
    if i % 4 in (1, 3):
        add(Sn, t, 0.45)
    for h in range(2 if t < reveal else 4):
        add(Hh, t + h * beat / (2 if t < reveal else 4), 0.18)
    if i % 2 == 0:
        add(bass(notes[(i // 8) % 4], beat * 1.8), t, 0.35)
add(riser(1.6), reveal - 1.6, 0.5)
add(impact(), reveal, 0.9)
A = os.path.join(ROOT, "studio", "Audio")
sfx = {"Hit": wav(os.path.join(A, "Hit.wav")), "Break": wav(os.path.join(A, "Break.wav")), "Pocket": wav(os.path.join(A, "Pocket.wav")),
       "Reward": wav(os.path.join(A, "CuePurchase.wav"))}
W8 = whoosh()
for t, kind in events:
    if kind in ("cut", "end"):
        add(W8, max(0, t - 0.25), 0.35)
    if kind == "punch":
        add(sfx["Pocket"], t, 0.5)
    if kind == "hook":
        add(impact(), t, 0.6)
    if kind == "end":
        add(sfx["Reward"], t + 0.1, 0.8)
seg_start = [0]
for a, b, s, _, _ in SEGMENTS:
    seg_start.append(seg_start[-1] + (b - a) / s)
add(sfx["Hit"], seg_start[2] + 0.55, 0.9)  # the strike
add(sfx["Break"], seg_start[2] + 0.6, 0.7)
add(impact(), seg_start[5] + 0.3, 0.7)  # planet explodes
mix = mix[: int(total * SR)]
mix = np.tanh(mix * 0.9) * 0.92
with wave.open(os.path.join(WORK, "audio.wav"), "w") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((mix * 32767).astype(np.int16).tobytes())
subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", os.path.join(WORK, "video.mp4"), "-i", os.path.join(WORK, "audio.wav"),
                "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", OUT], check=True)
print("done", OUT, f"{total:.1f}s")
