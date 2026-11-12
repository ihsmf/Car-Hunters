"""Adds the CAR HUNTERS title to the Blender store renders (docs/store/*_raw.png) -> icon.png, thumb_1.png, thumb_2.png.
  python3 tools/store_art_text.py
Roblox sizes: game icon 512x512 (upload the 1024 version, Roblox downsizes), thumbnails 1920x1080."""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "docs", "store")
FONT = next((f for f in ("/usr/share/fonts/opentype/inter/InterDisplay-Black.otf", "/usr/share/fonts/opentype/inter/Inter-Black.otf",
                         "/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf") if os.path.exists(f)))
INK = (27, 31, 42)


def title(img, text, cx, cy, size, top=(255, 236, 120), bottom=(255, 140, 30), stroke=None, angle=-4):
    font = ImageFont.truetype(FONT, size)
    stroke = stroke or max(4, size // 9)
    l, t, r, b = font.getbbox(text, stroke_width=stroke)
    w, h = r - l + 40, b - t + 40
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # shadow
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((20 - l + size // 22, 20 - t + size // 14), text, font=font, fill=(0, 0, 0, 150), stroke_width=stroke, stroke_fill=(0, 0, 0, 150))
    layer.alpha_composite(sh.filter(ImageFilter.GaussianBlur(size // 30)))
    # outline
    ImageDraw.Draw(layer).text((20 - l, 20 - t), text, font=font, fill=INK, stroke_width=stroke, stroke_fill=INK)
    # gradient fill through a text mask
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text((20 - l, 20 - t), text, font=font, fill=255)
    grad = Image.new("RGBA", (w, h))
    gd = ImageDraw.Draw(grad)
    for y in range(h):
        a = y / max(1, h - 1)
        gd.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * a) for i in range(3)) + (255,))
    layer.paste(grad, (0, 0), mask)
    layer = layer.rotate(angle, resample=Image.BICUBIC, expand=True)
    img.alpha_composite(layer, (int(cx - layer.width / 2), int(cy - layer.height / 2)))


def vignette(img, strength=0.55):
    w, h = img.size
    v = Image.new("L", (w, h), 0)
    ImageDraw.Draw(v).ellipse((-w * 0.25, -h * 0.25, w * 1.25, h * 1.25), fill=255)
    v = v.filter(ImageFilter.GaussianBlur(min(w, h) // 6))
    dark = Image.new("RGBA", (w, h), (0, 0, 0, int(255 * strength)))
    img.alpha_composite(Image.composite(Image.new("RGBA", (w, h), (0, 0, 0, 0)), dark, v))


icon = Image.open(os.path.join(D, "icon_raw.png")).convert("RGBA")
vignette(icon, 0.45)
title(icon, "CAR", 512, 150, 230)
title(icon, "HUNTERS", 512, 330, 190, top=(255, 255, 255), bottom=(120, 210, 255))
icon.convert("RGB").save(os.path.join(D, "icon.png"))
icon.convert("RGB").resize((512, 512), Image.LANCZOS).save(os.path.join(D, "icon_512.png"))

t1 = Image.open(os.path.join(D, "thumb_1_raw.png")).convert("RGBA")
vignette(t1, 0.4)
title(t1, "CAR HUNTERS", 960, 170, 190)
title(t1, "80 CARS TO COLLECT", 960, 930, 84, top=(255, 255, 255), bottom=(160, 220, 255), angle=0)
t1.convert("RGB").save(os.path.join(D, "thumb_1.png"))

t2 = Image.open(os.path.join(D, "thumb_2_raw.png")).convert("RGBA")
vignette(t2, 0.4)
title(t2, "WIN LEGENDARY CARS", 960, 150, 130, top=(255, 230, 120), bottom=(255, 120, 40))
title(t2, "TRADE WITH FRIENDS", 960, 940, 84, top=(255, 255, 255), bottom=(160, 220, 255), angle=0)
t2.convert("RGB").save(os.path.join(D, "thumb_2.png"))
print("store art text ok")
