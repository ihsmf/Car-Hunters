"""Menu icons for UI v6 (transparent 512px renders): Inventory, Cues, Bonus, Shop, Gym, Settings."""
import bpy, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import icons as I

def inventory():  # open backpack with billiard balls
    bag, strap, G = I.mat("Bag", (60, 140, 230), 0, 0.5), I.mat("Strap", (30, 70, 150), 0, 0.5), I.gold()
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, -0.3)); o = bpy.context.object; o.scale = (2.2, 1.3, 2.2)
    b = o.modifiers.new("b", "BEVEL"); b.width, b.segments = 0.45, 6; I.obj_mat(o, bag)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.72, -0.7)); o = bpy.context.object; o.scale = (1.5, 0.3, 1.0)
    b = o.modifiers.new("b", "BEVEL"); b.width, b.segments = 0.2, 4; I.obj_mat(o, strap)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.6, minor_radius=0.12, location=(0, 0, 1.0), rotation=(math.pi / 2, 0, 0)); I.obj_mat(bpy.context.object, strap)
    cols = [(255, 210, 40), (40, 90, 230), (235, 50, 50), (140, 50, 200), (30, 160, 70)]
    for k, c in enumerate(cols):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.42, segments=32, ring_count=16, location=(-0.9 + k * 0.45, -0.1, 0.95 + (k % 2) * 0.25))
        I.obj_mat(bpy.context.object, I.mat(f"B{k}", c, 0, 0.15))
    bpy.ops.mesh.primitive_cylinder_add(radius=0.12, depth=0.1, location=(0, -0.9, -0.5), rotation=(math.pi / 2, 0, 0)); I.obj_mat(bpy.context.object, G)

def cues():  # two crossed cues + cue ball
    wood, tip, wrap, white = I.mat("Wood", (235, 195, 130), 0, 0.4), I.mat("Tip", (60, 120, 240)), I.mat("Wrap", (200, 30, 50)), I.mat("W", (250, 250, 245), 0, 0.1)
    for s in (-1, 1):
        for part, (r1, r2, d, z, m) in enumerate(((0.16, 0.09, 3.6, 0.2, wood), (0.19, 0.16, 1.4, -2.3, wrap), (0.09, 0.09, 0.15, 2.07, tip))):
            bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=d, location=(0, 0, 0), vertices=24)
            o = bpy.context.object; o.location = (math.sin(s * 0.6) * z, 0, math.cos(s * 0.6) * z); o.rotation_euler = (0, s * 0.6, 0); I.obj_mat(o, m)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.7, segments=32, ring_count=16, location=(0, -0.4, -1.2)); I.obj_mat(bpy.context.object, white)
    I.sparkles(12, (0, 0, 0), 1.8, I.mat("S", (255, 250, 220), 0, 0.2, 10))

def bonus():  # gift box with bow
    box, rib = I.mat("Box", (240, 60, 90), 0, 0.35), I.gold()
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, -0.5)); o = bpy.context.object; o.scale = (2.2, 2.2, 1.8); o.modifiers.new("b", "BEVEL").width = 0.08; I.obj_mat(o, box)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.55)); o = bpy.context.object; o.scale = (2.45, 2.45, 0.45); o.modifiers.new("b", "BEVEL").width = 0.08; I.obj_mat(o, box)
    for sx, sy in ((0.4, 2.5), (2.5, 0.4)):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, -0.1)); o = bpy.context.object; o.scale = (sx, sy, 2.4); I.obj_mat(o, rib)
    for s in (-1, 1):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.55, minor_radius=0.18, location=(s * 0.5, 0, 1.25), rotation=(math.pi / 2, s * 0.5, 0)); I.obj_mat(bpy.context.object, rib)
    I.sparkles(14, (0, 0, 0), 1.9, I.mat("S", (255, 250, 220), 0, 0.2, 10))

def shop():  # shopping cart full of coins
    metal, G, wheel = I.mat("M", (90, 220, 120), 0.2, 0.3), I.gold(), I.mat("Wh", (40, 40, 50))
    for x, y, z, sx, sy, sz in ((0, 0, -0.6, 2.4, 1.6, 0.12), (0, -0.8, 0, 2.4, 0.12, 1.3), (0, 0.8, 0, 2.4, 0.12, 1.3), (-1.2, 0, 0, 0.12, 1.6, 1.3), (1.2, 0, 0, 0.12, 1.6, 1.3)):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z)); o = bpy.context.object; o.scale = (sx, sy, sz); I.obj_mat(o, metal)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=1.2, location=(-1.6, 0, 0.9), rotation=(0, 0.6, 0)); I.obj_mat(bpy.context.object, metal)
    for x in (-0.9, 0.9):
        for y in (-0.6, 0.6):
            bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.15, location=(x, y, -1.0), rotation=(math.pi / 2, 0, 0)); I.obj_mat(bpy.context.object, wheel)
    for k in range(14):
        I.coin((I.R.uniform(-0.9, 0.9), I.R.uniform(-0.5, 0.5), 0.5 + I.R.uniform(0, 0.5)), (I.R.uniform(-0.6, 0.6), I.R.uniform(-0.6, 0.6), 0), 0.42, G)

def gym():  # dumbbell
    bar, plate = I.mat("Bar", (200, 205, 215), 0.9, 0.25), I.mat("Plate", (255, 140, 40), 0, 0.3)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.17, depth=3.6, rotation=(0, math.pi / 2, 0.3)); I.obj_mat(bpy.context.object, bar)
    for s in (-1, 1):
        for k, (r, d) in enumerate(((1.0, 0.35), (0.8, 0.3))):
            x = s * (1.1 + k * 0.33)
            bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=d, vertices=40, location=(x * math.cos(0.3), x * math.sin(0.3), 0), rotation=(0, math.pi / 2, 0.3))
            o = bpy.context.object; o.modifiers.new("b", "BEVEL").width = 0.05; I.obj_mat(o, plate)

def settings():  # gear
    m = I.mat("Gear", (170, 180, 200), 0.85, 0.3)
    bpy.ops.mesh.primitive_cylinder_add(radius=1.3, depth=0.5, vertices=48, rotation=(math.pi / 2, 0, 0)); I.obj_mat(bpy.context.object, m)
    for k in range(10):
        a = k * math.pi / 5
        bpy.ops.mesh.primitive_cube_add(size=1, location=(math.cos(a) * 1.45, 0, math.sin(a) * 1.45), rotation=(0, -a, 0))
        o = bpy.context.object; o.scale = (0.5, 0.5, 0.5); I.obj_mat(o, m)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.5, depth=0.7, vertices=32, rotation=(math.pi / 2, 0, 0)); I.obj_mat(bpy.context.object, I.mat("H", (60, 60, 80)))

I.ICONS = {"MenuInventory": inventory, "MenuCues": cues, "MenuBonus": bonus, "MenuShop": shop, "MenuGym": gym, "MenuSettings": settings}
for k in I.ICONS:
    I.render(k); print("icon", k)
