"""Black outline around transparent icon renders: blender/export/icons/<X>_raw.png -> <X>_ol.png"""
import glob, os
from PIL import Image, ImageFilter
D = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "blender", "export", "icons")
for f in glob.glob(os.path.join(D, "*_raw.png")):
    im = Image.open(f).convert("RGBA")
    a = im.split()[3].point(lambda v: 255 if v > 40 else 0)
    a = a.filter(ImageFilter.MinFilter(9)).filter(ImageFilter.MaxFilter(9))  # small sparkles get no outline
    ring = a.filter(ImageFilter.MaxFilter(17)).filter(ImageFilter.GaussianBlur(1))
    out = Image.new("RGBA", im.size, (20, 10, 30, 0))
    out.putalpha(ring)
    out.alpha_composite(im)
    out.save(f.replace("_raw.png", "_ol.png"))
