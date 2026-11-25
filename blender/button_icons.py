"""Button icons for UI v8 (transparent 512px renders, then tools/icon_outline.py adds the black outline):
chunky glossy 3D symbols in the style of the menu icons. Shapes are puffy extruded curves facing the camera (-Y).
    python3 blender/button_icons.py [BtnPlace ...]  -> blender/export/icons/<Key>_raw.png"""
import bpy, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import icons as I

TILT = math.radians(-12)  # lean the symbols back a little so the bevel catches the light


def shape(points, m, depth=0.32, bevel=0.14, loc=(0, 0, 0), rot=0.0, scale=1.0):
    """Extruded, bevelled flat polygon in the XZ plane (points as (x, z)), facing the camera."""
    cu = bpy.data.curves.new("s", "CURVE")
    cu.dimensions = "2D"
    cu.fill_mode = "BOTH"
    cu.extrude, cu.bevel_depth, cu.bevel_resolution = depth, bevel, 6
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for p, (x, z) in zip(sp.points, points):
        p.co = (x * scale, z * scale, 0, 1)
    sp.use_cyclic_u = True
    o = bpy.data.objects.new("s", cu)
    bpy.context.scene.collection.objects.link(o)
    o.rotation_euler = (math.pi / 2 + TILT, rot, 0)
    o.location = loc
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.object
    I.obj_mat(o, m)
    return o


def rounded_bar(w, h, m, loc=(0, 0, 0), rot=0.0, depth=0.6):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=(TILT, rot, 0))
    o = bpy.context.object
    o.scale = (w, depth, h)
    b = o.modifiers.new("b", "BEVEL")
    b.width, b.segments, b.limit_method = min(w, h, depth) * 0.32, 8, "NONE"
    return I.obj_mat(o, m)


def shine(loc, r=0.22):  # a little white highlight dot
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=24, ring_count=12)
    o = bpy.context.object
    o.scale = (1.4, 0.4, 0.8)
    I.obj_mat(o, I.mat("Hi", (255, 255, 255), 0, 0.1, 2.0))


def arrow(m, length=3.2, head=1.7, shaft=0.9, loc=(0, 0, 0), rot=0.0, scale=1.0):
    """Shaft (rounded bar) + head (rounded triangle) as two clean pieces, pointing up (rot = pi: down)."""
    L, hh = length * scale, head * 0.8 * scale
    c, s_ = math.cos(rot), math.sin(rot)
    def at(dz):  # a point dz along the arrow axis from its centre
        return (loc[0] + s_ * dz, loc[1], loc[2] + c * dz)
    rounded_bar(shaft * scale, L - hh * 0.6, m, loc=at(-hh * 0.3), rot=rot, depth=0.62 * scale)
    w = head * scale / 2
    shape([(-w, -hh / 2), (w, -hh / 2), (0, hh / 2)], m, depth=0.34 * scale, bevel=0.16 * scale, loc=at(L / 2 - hh / 2), rot=rot)


def star_pts(r1, r2, n=5):
    return [((r1 if k % 2 == 0 else r2) * math.sin(k * math.pi / n), (r1 if k % 2 == 0 else r2) * math.cos(k * math.pi / n)) for k in range(2 * n)]


GREEN = lambda: I.mat("G", (70, 220, 90), 0, 0.25)
RED = lambda: I.mat("R", (240, 55, 70), 0, 0.25)
BLUE = lambda: I.mat("B", (60, 150, 255), 0, 0.25)


def place():  # a glossy yellow billiard ball landing on a green felt pad, green arrow pointing down at it
    pad = I.mat("Felt", (40, 180, 95), 0, 0.55)
    bpy.ops.mesh.primitive_cylinder_add(radius=1.75, depth=0.4, vertices=64, location=(0, 0.3, -1.7))
    o = bpy.context.object
    o.modifiers.new("b", "BEVEL").width = 0.14
    I.obj_mat(o, pad)
    bpy.ops.mesh.primitive_torus_add(major_radius=1.75, minor_radius=0.16, location=(0, 0.3, -1.5))
    I.obj_mat(bpy.context.object, I.gold())
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=48, ring_count=24, location=(0, 0, -0.55))
    I.obj_mat(bpy.context.object, I.mat("Ball", (255, 200, 30), 0, 0.12))
    bpy.ops.mesh.primitive_cylinder_add(radius=0.42, depth=0.2, location=(0, -0.93, -0.45), rotation=(math.pi / 2, 0, 0))
    I.obj_mat(bpy.context.object, I.mat("Spot", (255, 255, 250), 0, 0.2))
    shine((-0.4, -0.9, -0.05), 0.16)
    arrow(GREEN(), 1.9, 1.5, 0.62, loc=(0, -0.2, 1.55), rot=math.pi)


def remove():  # red rounded minus chip
    bpy.ops.mesh.primitive_cylinder_add(radius=1.75, depth=0.6, vertices=64, location=(0, 0.2, 0), rotation=(math.pi / 2 + TILT, 0, 0))
    o = bpy.context.object
    b = o.modifiers.new("b", "BEVEL")
    b.width, b.segments = 0.22, 8
    I.obj_mat(o, RED())
    rounded_bar(2.1, 0.62, I.mat("W", (255, 255, 255), 0, 0.2), loc=(0, -0.25, 0), depth=0.3)
    shine((-0.8, -0.25, 1.05), 0.2)


def star():  # fat golden star
    shape(star_pts(2.2, 1.0), I.mat("Gold", (255, 200, 40), 0.4, 0.2), depth=0.35, bevel=0.22)
    shine((-0.45, -0.75, 0.85), 0.2)


def sort():  # blue up + down arrows side by side
    arrow(BLUE(), 3.4, 1.7, 0.75, loc=(-0.85, 0, 0.05), scale=0.95)
    arrow(I.mat("B2", (40, 110, 230), 0, 0.25), 3.4, 1.7, 0.75, loc=(0.85, 0, -0.05), rot=math.pi, scale=0.95)


def up():  # big green up arrow
    arrow(GREEN(), 4.0, 2.9, 1.3)
    shine((-0.35, -0.55, 1.1), 0.18)


def play():  # green rounded play triangle
    shape([(-1.2, -1.6), (1.7, 0), (-1.2, 1.6)], GREEN(), depth=0.4, bevel=0.3)
    shine((-0.55, -0.7, 0.75), 0.18)


def stop():  # red rounded square
    rounded_bar(2.9, 2.9, RED(), depth=0.8)
    shine((-0.75, -0.45, 0.85), 0.2)


def check():  # green check mark
    shape([(-1.9, 0.1), (-1.1, 0.9), (-0.45, 0.2), (1.35, 2.0), (2.1, 1.25), (-0.45, -1.3)], GREEN(), depth=0.4, bevel=0.2)


def close():  # red cross from two rounded bars
    m = RED()
    for a in (math.pi / 4, -math.pi / 4):
        rounded_bar(4.2, 1.15, m, rot=a, depth=0.8)


def lock():  # golden padlock (not enough money)
    G = I.gold()
    rounded_bar(3.0, 2.4, G, loc=(0, -0.1, -0.7), depth=1.0)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.95, minor_radius=0.26, location=(0, 0.15, 0.45), rotation=(math.pi / 2 + TILT, 0, 0))
    I.obj_mat(bpy.context.object, I.mat("Steel", (190, 195, 210), 0.9, 0.25))
    bpy.ops.mesh.primitive_cylinder_add(radius=0.3, depth=0.3, location=(0, -0.45, -0.55), rotation=(math.pi / 2, 0, 0))
    I.obj_mat(bpy.context.object, I.mat("Hole", (60, 40, 20)))


I.ICONS = {"BtnPlace": place, "BtnRemove": remove, "BtnStar": star, "BtnSort": sort, "BtnUp": up, "BtnPlay": play,
           "BtnStop": stop, "BtnCheck": check, "BtnClose": close, "BtnLock": lock}
if __name__ == "__main__":
    for k in (sys.argv[1:] or I.ICONS):
        I.render(k)
        print("icon", k)
