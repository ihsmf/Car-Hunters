"""Street props for the map (Blender). Out: assets/props/props.fbx with empties TireStack, Cone, Hydrant.
Parts are named by look: Rubber, Orange, White, Red, Metal, Yellow (CarModelTool.ApplyImported styles them)."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import make_cars as mc

OUT = os.path.join(mc.ROOT, "assets", "props")
os.makedirs(OUT, exist_ok=True)
mc.reset()
COL = {"Rubber": (0.03, 0.03, 0.035, 1), "Orange": (1, 0.45, 0.05, 1), "White": (0.95, 0.95, 0.95, 1),
       "Red": (0.85, 0.1, 0.1, 1), "Metal": (0.7, 0.72, 0.75, 1), "Yellow": (1, 0.8, 0.2, 1)}

def finish(name, groups):
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    for look, objs in groups.items():
        for o in objs:
            mc.set_mat(o, mc.mat(look, COL[look]))
        ob = mc.join(objs, look)
        for p in ob.data.polygons:
            p.use_smooth = True
        ob.parent = root
    return root

def torus(loc, R, r):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=28, minor_segments=12, location=loc)
    return bpy.context.active_object

roots = []
# tire stack
g = {"Rubber": [], "Yellow": []}
for i in range(3):
    t = torus((0.1 * (i % 2), 0, 0.7 + i * 1.35), 1.35, 0.68)
    t.scale = (1, 1, 1.05)
    g["Rubber"].append(t)
    g["Yellow"].append(mc.prim("cyl", "rim", (0.1 * (i % 2), 0, 0.7 + i * 1.35), (1.6, 1.6, 0.9)))
r = finish("TireStack", g); r.location.x = 0; roots.append(r)
# traffic cone
g = {"Orange": [], "White": [], "Rubber": []}
bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.75, radius2=0.12, depth=2.6, location=(0, 0, 1.5))
g["Orange"].append(bpy.context.active_object)
g["White"].append(mc.prim("cyl", "band", (0, 0, 1.55), (1.2, 1.2, 0.45), verts=24))
base = mc.prim("box", "base", (0, 0, 0.12), (2.0, 2.0, 0.24)); mc.bevel(base, 0.12, 2)
g["Rubber"].append(base)
r = finish("Cone", g); r.location.x = 6; roots.append(r)
# hydrant
g = {"Red": [], "Metal": []}
g["Red"].append(mc.prim("cyl", "body", (0, 0, 1.2), (1.3, 1.3, 2.0), verts=20))
bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=0.66, location=(0, 0, 2.2))
g["Red"].append(bpy.context.active_object)
for a in (0, math.pi / 2, math.pi):
    g["Red"].append(mc.prim("cyl", "nozzle", (math.cos(a) * 0.75, math.sin(a) * 0.75, 1.5), (0.5, 0.5, 0.5), rot=(0, math.pi / 2, a), verts=12))
g["Metal"].append(mc.prim("cyl", "foot", (0, 0, 0.15), (1.7, 1.7, 0.3), verts=20))
g["Metal"].append(mc.prim("cyl", "cap", (0, 0, 2.85), (0.4, 0.4, 0.3), verts=8))
r = finish("Hydrant", g); r.location.x = 12; roots.append(r)
for r in roots:
    r.location.x = 0
mc.export(roots, os.path.join(OUT, "props.fbx"))
print("props ok")
