"""Compose the CUE HUNTERS thumbnail: hall render background + the god cut-out + logo and badges.
    python3 tools/thumb_text.py <hall.png> <god.png> <out.png>"""
import sys
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

FONT = "blender/fonts/LuckiestGuy.ttf"
W, H = 1920, 1080
hall = Image.open(sys.argv[1]).convert("RGB").resize((W, H))
hall = ImageEnhance.Color(hall).enhance(1.25)
hall = ImageEnhance.Contrast(hall).enhance(1.08).convert("RGBA")
vig = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(vig)
d.ellipse((-300, -250, W + 300, H + 250), fill=255)
vig = vig.filter(ImageFilter.GaussianBlur(160))
dark = Image.new("RGBA", (W, H), (20, 10, 40, 255))
hall = Image.composite(hall, dark, vig.point(lambda v: int(90 + v * 165 / 255)))

god = Image.open(sys.argv[2]).convert("RGBA")
gh = 1230
god = god.resize((int(god.width * gh / god.height), gh), Image.LANCZOS)
gx, gy = W - god.width + 90, -40
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
mask = Image.new("L", (W, H), 0)
mask.paste(god.split()[3], (gx, gy))
glow.paste((255, 215, 120, 255), (0, 0, W, H), mask.filter(ImageFilter.GaussianBlur(40)).point(lambda a: int(a * 0.9)))
hall.alpha_composite(glow)
hall.alpha_composite(god, (gx, gy))

draw = ImageDraw.Draw(hall)


def outlined(xy, text, size, fill, stroke=12, shadow=10, anchor="la"):
    f = ImageFont.truetype(FONT, size)
    x, y = xy
    draw.text((x + shadow, y + shadow), text, font=f, fill=(25, 10, 45, 220), anchor=anchor)
    draw.text((x, y), text, font=f, fill=fill, stroke_width=stroke, stroke_fill=(35, 18, 70), anchor=anchor)
    return f


# logo: two lines, gold gradient on "HUNTERS"
outlined((70, 40), "CUE", 210, (255, 255, 255))
f = ImageFont.truetype(FONT, 210)
txt = Image.new("RGBA", (W, H), (0, 0, 0, 0))
td = ImageDraw.Draw(txt)
td.text((70 + 10, 245 + 10), "HUNTERS", font=f, fill=(25, 10, 45, 220))
td.text((70, 245), "HUNTERS", font=f, fill=(255, 255, 255), stroke_width=12, stroke_fill=(35, 18, 70))
grad = Image.new("RGBA", (W, H))
gd = ImageDraw.Draw(grad)
for y in range(245, 470):
    t = (y - 245) / 225
    gd.line((0, y, W, y), fill=(255, int(235 - 85 * t), int(110 - 80 * t), 255))
letters = Image.new("L", (W, H), 0)
ImageDraw.Draw(letters).text((70, 245), "HUNTERS", font=f, fill=255)
txt.paste(grad, (0, 0), letters)
hall.alpha_composite(txt)

# ribbon + badge
rib = Image.new("RGBA", (W, H), (0, 0, 0, 0))
rd = ImageDraw.Draw(rib)
rd.rounded_rectangle((70, 500, 860, 610), 40, fill=(70, 200, 90, 255), outline=(35, 18, 70), width=8)
hall.alpha_composite(rib)
draw = ImageDraw.Draw(hall)
outlined((465, 556), "LUCK x1,000,000!", 76, (255, 255, 255), stroke=8, shadow=6, anchor="mm")
rd2 = ImageDraw.Draw(hall)
rd2.rounded_rectangle((70, 640, 760, 730), 36, fill=(150, 70, 230, 255), outline=(35, 18, 70), width=8)
outlined((415, 686), "1 IN 796 000 000 000 ...", 54, (255, 235, 120), stroke=6, shadow=5, anchor="mm")
hall.convert("RGB").save(sys.argv[3])
hall.convert("RGB").save(sys.argv[3].rsplit(".", 1)[0] + ".jpg", quality=92)
print("saved", sys.argv[3])
