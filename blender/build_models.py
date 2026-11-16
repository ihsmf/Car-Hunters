"""Генерация моделей для плейса: blender -b -P blender/build_models.py
Размеры в стадах (1 BU = 1 stud). FBX кладутся в blender/export/.
Импорт в Studio: 3D Importer -> положить в ReplicatedStorage/Models с именами файлов."""
import bpy, math, os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "export")
os.makedirs(OUT, exist_ok=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgb, metal=0.0, rough=0.5, emit=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*rgb, 1)
        b.inputs["Emission Strength"].default_value = emit
    return m


def finish(obj, material, bevel=0.0, smooth=True):
    obj.data.materials.append(material)
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width, mod.segments = bevel, 3
    if smooth:
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.shade_smooth()
    return obj


def cube(size, loc, material, bevel=0.08):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.scale = [s / 2 for s in size]
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, material, bevel)


def cyl(r, depth, loc, material, rot=(0, 0, 0), r2=None, verts=32):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r if r2 is None else r2, depth=depth, location=loc, rotation=rot)
    return finish(bpy.context.object, material, 0.02)


def export(name):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.convert(target="MESH")  # применяет модификаторы
    if len(bpy.context.selected_objects) > 1:
        bpy.ops.object.join()
    bpy.context.object.name = name
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, name + ".fbx"), apply_unit_scale=True, axis_forward="-Z", axis_up="Y")


WOOD = (0.45, 0.22, 0.08)
DARK = (0.3, 0.14, 0.05)


def pool_table():
    reset()
    wood, dark = mat("Wood", WOOD, rough=0.35), mat("DarkWood", DARK, rough=0.4)
    felt, black, gold = mat("Felt", (0.05, 0.5, 0.2), rough=0.9), mat("Pocket", (0.02, 0.02, 0.02)), mat("Gold", (1, 0.75, 0.2), metal=1, rough=0.25)
    L, W = 16, 9
    cube((W + 1.6, L + 1.6, 1.2), (0, 0, 3.2), wood, 0.25)
    cube((W, L, 0.2), (0, 0, 3.9), felt, 0)
    for s in (-1, 1):
        cube((0.8, L + 1.6, 0.6), (s * (W / 2 + 0.4), 0, 4.1), dark, 0.15)
        cube((W + 1.6, 0.8, 0.6), (0, s * (L / 2 + 0.4), 4.1), dark, 0.15)
        for t in (-1, 1):  # точёные ножки
            x, y = s * W / 2.3, t * L / 2.3
            cyl(0.55, 2.6, (x, y, 1.3), dark, r2=0.35)
            cyl(0.7, 0.3, (x, y, 2.5), gold)
    for s in (-1, 1):
        for t in (-1, 0, 1):
            cyl(0.55, 0.25, (s * W / 2, t * L / 2, 4.0), black)
            bpy.ops.mesh.primitive_torus_add(major_radius=0.6, minor_radius=0.1, location=(s * W / 2, t * L / 2, 4.15))
            finish(bpy.context.object, gold)
    export("PoolTable")


def cue():
    reset()
    wood, dark = mat("Maple", (0.85, 0.65, 0.4), rough=0.3), mat("Ebony", (0.08, 0.04, 0.02), rough=0.3)
    white, blue = mat("Ferrule", (0.95, 0.95, 0.9)), mat("Tip", (0.1, 0.3, 0.9), rough=0.9)
    cyl(0.22, 4.5, (0, 0, 2.25), dark, r2=0.17)      # турняк
    cyl(0.23, 0.6, (0, 0, 1.2), mat("Wrap", (0.6, 0.05, 0.05), rough=0.8))
    cyl(0.17, 4.3, (0, 0, 6.65), wood, r2=0.1)       # шафт
    cyl(0.1, 0.25, (0, 0, 8.9), white)
    cyl(0.1, 0.08, (0, 0, 9.06), blue)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.23, location=(0, 0, 0))
    finish(bpy.context.object, dark)
    export("Cue")


def ball():
    reset()
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1, segments=48, ring_count=24)
    o = finish(bpy.context.object, mat("BallWhite", (1, 1, 1), rough=0.1))
    o.data.materials.append(mat("BallStripe", (1, 0.8, 0.1), rough=0.1))
    for p in o.data.polygons:  # полоса как у «полосатых» шаров
        if abs(p.center.z) < 0.4:
            p.material_index = 1
    export("Ball")


def dumbbell():
    reset()
    steel, red = mat("Steel", (0.8, 0.8, 0.85), metal=1, rough=0.2), mat("Plate", (0.95, 0.2, 0.2), rough=0.4)
    rot = (0, math.pi / 2, 0)
    cyl(0.25, 5, (0, 0, 0.9), steel, rot)
    for x in (-2, 2):
        cyl(0.9, 0.5, (x, 0, 0.9), red, rot)
        cyl(0.7, 0.4, (x * 0.82, 0, 0.9), red, rot)
        cyl(0.35, 0.3, (x * 1.15, 0, 0.9), steel, rot)
    export("Dumbbell")


def fence(length=30):
    reset()
    white, yellow = mat("Post", (1, 0.97, 0.92), rough=0.4), mat("Rail", (1, 0.8, 0.3), rough=0.4)
    n = int(length // 6)
    for i in range(n + 1):
        x = -length / 2 + i * length / n
        cube((0.8, 0.8, 4), (x, 0, 2), white, 0.2)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.55, location=(x, 0, 4.2))
        finish(bpy.context.object, white)
    for z in (1.5, 3.2):
        cube((length, 0.4, 0.5), (0, 0, z), yellow, 0.12)
    export("Fence")


for build in (pool_table, cue, ball, dumbbell, fence):
    build()
print("Models exported to", OUT)
