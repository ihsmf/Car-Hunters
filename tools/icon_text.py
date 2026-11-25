"""Finish the shop icons: radial gradient background, glow behind the object, big outlined label.
    python3 tools/icon_text.py   (reads blender/export/icons/<Key>_raw.png, writes <Key>.png + a preview sheet)
Font: Luckiest Guy (SIL Open Font License), blender/fonts/LuckiestGuy.ttf."""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "blender", "export", "icons")
FONT = os.path.join(ROOT, "blender", "fonts", "LuckiestGuy.ttf")
# key: (label, inner colour, outer colour, label colour)
ICONS = {
    "Cash2x": ("x2 CASH", (120, 240, 120), (20, 110, 50), (255, 230, 70)),
    "Luck2x": ("x2 LUCK", (150, 255, 170), (30, 90, 160), (255, 255, 255)),
    "DragonCue": ("DRAGON", (255, 170, 80), (130, 10, 30), (255, 220, 90)),
    "GoldStick": ("+50%", (255, 230, 130), (170, 90, 10), (255, 255, 255)),
    "GoldenBall": ("GOLDEN", (255, 240, 160), (180, 110, 20), (255, 255, 255)),
    "Pack1": ("$5K", (170, 240, 255), (40, 90, 190), (255, 230, 70)),
    "Pack2": ("$50K", (220, 180, 255), (90, 40, 170), (255, 230, 70)),
    "Pack3": ("$500K", (255, 200, 120), (160, 50, 120), (255, 230, 70)),
}
S = 512


def radial(inner, outer):
    img = Image.new("RGB", (S, S))
    px = img.load()
    for y in range(S):
        for x in range(S):
            d = min(1, (((x - S / 2) ** 2 + (y - S * 0.45) ** 2) ** 0.5) / (S * 0.72))
            px[x, y] = tuple(int(inner[i] * (1 - d) + outer[i] * d) for i in range(3))
    rays = Image.new("L", (S, S), 0)
    dr = ImageDraw.Draw(rays)
    for k in range(16):  # soft sunburst
        if k % 2 == 0:
            dr.pieslice((-S, -S, 2 * S, 2 * S), k * 22.5, k * 22.5 + 11, fill=40)
    return Image.composite(Image.new("RGB", (S, S), (255, 255, 255)), img, rays.filter(ImageFilter.GaussianBlur(6)))


def make(key):
    label, inner, outer, ink = ICONS[key]
    bg = radial(inner, outer).convert("RGBA")
    obj = Image.open(os.path.join(D, key + "_raw.png")).convert("RGBA")
    glow = Image.new("RGBA", (S, S), (255, 255, 230, 0))
    glow.putalpha(obj.split()[3].filter(ImageFilter.GaussianBlur(18)).point(lambda a: int(a * 0.85)))
    bg.alpha_composite(glow)
    obj = obj.resize((int(S * 0.92), int(S * 0.92)), Image.LANCZOS)
    bg.alpha_composite(obj, ((S - obj.width) // 2, int(S * 0.0)))
    if os.environ.get("ICON_ONLY"):  # store icons: just the object, outlined, bigger
        bg = radial(inner, outer).convert("RGBA")
        raw = Image.open(os.path.join(D, key + "_ol.png")).convert("RGBA").resize((int(S * 1.05), int(S * 1.05)), Image.LANCZOS)
        bg.alpha_composite(raw, ((S - raw.width) // 2, (S - raw.height) // 2))
        bg.convert("RGB").save(os.path.join(D, key + ".png"))
        return bg
    draw = ImageDraw.Draw(bg)
    size = 112 if len(label) <= 6 else 96
    font = ImageFont.truetype(FONT, size)
    w = draw.textlength(label, font=font)
    x, y = (S - w) / 2, S - size - 34
    draw.text((x + 6, y + 8), label, font=font, fill=(30, 10, 40, 200))  # drop shadow
    draw.text((x, y), label, font=font, fill=ink, stroke_width=9, stroke_fill=(35, 20, 60))
    bg.convert("RGB").save(os.path.join(D, key + ".png"))
    return bg


if __name__ == "__main__":
    tiles = [make(k) for k in ICONS]
    sheet = Image.new("RGB", (S * 4, S * 2))
    for i, t in enumerate(tiles):
        sheet.paste(t.convert("RGB"), ((i % 4) * S, (i // 4) * S))
    sheet.resize((S * 2, S)).save(os.path.join(D, "sheet.png"))
    print("icons:", ", ".join(ICONS))
