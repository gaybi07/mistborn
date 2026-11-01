"""Genera las armas y objetos de mano del juego (un .glb cada uno) con detalle: hojas con filo y
canal, empuñaduras con vendas, escudo con remaches, frasco con líquido y moneda con canto.

Uso (desde la carpeta del proyecto):
    blender -b --factory-startup -P tools/blender/make_weapons.py -- assets/weapons [preview.png]

Crea en esa carpeta un .glb por objeto (dagger_obsidian.glb, sword_steel.glb, shield.glb...) y,
si se pasa, una imagen con todos en fila.

Convención (la misma que las armas procedurales de HumanoidRig): el origen es el punto de agarre,
la hoja apunta a +Z en Blender (+Y en Godot) y lo plano de la hoja mira a ±Y (±Z en Godot).
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["."]
OUT_DIR = ARGS[0]
PREVIEW = ARGS[1] if len(ARGS) > 1 else ""
os.makedirs(OUT_DIR, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)

# nombre: (color, metálico, rugosidad, alfa)
MATERIALS = {
    "obsidian": ((0.015, 0.014, 0.02), 0.0, 0.06, 1.0),
    "glass": ((0.55, 0.75, 0.8), 0.0, 0.04, 0.45),
    "steel": ((0.62, 0.64, 0.68), 1.0, 0.25, 1.0),
    "dark_steel": ((0.22, 0.22, 0.24), 1.0, 0.45, 1.0),
    "brass": ((0.78, 0.56, 0.26), 1.0, 0.35, 1.0),
    "bronze": ((0.62, 0.38, 0.2), 1.0, 0.4, 1.0),
    "leather": ((0.2, 0.12, 0.07), 0.0, 0.75, 1.0),
    "wrap": ((0.32, 0.25, 0.18), 0.0, 0.9, 1.0),
    "wood": ((0.36, 0.23, 0.13), 0.0, 0.7, 1.0),
    "dark_wood": ((0.14, 0.08, 0.05), 0.0, 0.45, 1.0),
    "cork": ((0.62, 0.47, 0.3), 0.0, 0.9, 1.0),
    "vial_glass": ((0.8, 0.88, 0.9), 0.0, 0.03, 0.3),
    "metal_flakes": ((0.55, 0.5, 0.4), 0.6, 0.4, 0.85),
}
_mats = {}


def mat(name):
    if name not in _mats:
        color, metal, rough, alpha = MATERIALS[name]
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Alpha"].default_value = alpha
        m.diffuse_color = (*color, alpha)
        if alpha < 1.0:
            m.surface_render_method = "BLENDED"
        _mats[name] = m
    return _mats[name]


def new_object(name, bm, material, parent, smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    me.materials.append(mat(material))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = parent
    return ob


def lathe(name, profile, material, parent, segs=24, z=0.0, transform=None, smooth=True, caps=True):
    """Superficie de revolución alrededor de Z: profile = [(radio, altura), ...] de abajo arriba."""
    bm = bmesh.new()
    rings = []
    for r, h in profile:
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), h + z)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if caps and profile[0][0] > 1e-5:
        bm.faces.new(list(reversed(rings[0])))
    if caps and profile[-1][0] > 1e-5:
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if transform:
        bmesh.ops.transform(bm, matrix=transform, verts=bm.verts)
    return new_object(name, bm, material, parent, smooth)


def box(name, size, center, material, parent, bevel=0.002):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bmesh.ops.translate(bm, vec=center, verts=bm.verts)
    if bevel:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=2, affect="EDGES", profile=0.5)
    return new_object(name, bm, material, parent, smooth=True)


def blade(name, material, parent, z0, length, width, thick, tip, fuller=0.0, taper=0.8):
    """Hoja de sección romboidal (con canal si fuller > 0) que se afina hasta la punta."""
    bm = bmesh.new()
    rings = []
    body = length - tip
    stations = [i / 10 * body for i in range(11)] + [body + tip * k for k in (0.25, 0.5, 0.75, 0.92)]
    for s in stations:
        u = s / length
        w = width * (1 - (1 - taper) * min(s / body, 1.0))
        if s > body:
            k = (s - body) / tip
            w *= (1 - k) ** 0.75
        t = thick * (w / width) ** 0.5
        groove = 1.0 - fuller if 0.06 < u < 0.7 else 1.0  # canal (vaceo) en la parte ancha de la hoja
        section = [(-w, 0), (-w * 0.45, t), (0, t * groove), (w * 0.45, t),
                   (w, 0), (w * 0.45, -t), (0, -t * groove), (-w * 0.45, -t)]
        rings.append([bm.verts.new((x, y, z0 + s)) for x, y in section])
    for a, b in zip(rings, rings[1:]):
        for i in range(8):
            j = (i + 1) % 8
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(rings[0])))
    point = bm.verts.new((0, 0, z0 + length))
    for i in range(8):
        bm.faces.new((rings[-1][i], rings[-1][(i + 1) % 8], point))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_object(name, bm, material, parent)


def wrapped_grip(name, material, parent, z0, length, radius, bands=9):
    """Empuñadura con vendas: el radio sube y baja como tiras enrolladas."""
    profile = [(radius * 0.8, z0)]
    n = bands * 4
    for i in range(n + 1):
        h = z0 + length * i / n
        profile.append((radius * (1 + 0.12 * abs(math.sin(math.pi * i / 4))), h))
    profile.append((radius * 0.8, z0 + length))
    return lathe(name, profile, material, parent, segs=16)


def root(name):
    ob = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(ob)
    return ob


# --------------------------------------------------------------------------- armas

def dagger(variant):
    r = root(f"dagger_{variant}")
    edge = variant  # obsidian / glass / steel
    blade(f"{r.name}_blade", edge, r, 0.045, 0.22, 0.017, 0.0045, 0.06, fuller=0.0 if edge != "steel" else 0.45)
    box(f"{r.name}_guard", (0.075, 0.016, 0.014), (0, 0, 0.038), "dark_steel" if edge == "steel" else "bronze", r)
    for s in (-1, 1):  # extremos de la guarda
        lathe(f"{r.name}_quillon{s}", [(0, -0.009), (0.009, -0.004), (0.009, 0.004), (0, 0.009)],
              "dark_steel" if edge == "steel" else "bronze", r, segs=12,
              transform=Matrix.Translation((s * 0.041, 0, 0.038)))
    wrapped_grip(f"{r.name}_grip", "leather", r, -0.055, 0.09, 0.013)
    lathe(f"{r.name}_pommel", [(0, -0.085), (0.012, -0.08), (0.016, -0.07), (0.012, -0.058), (0.008, -0.055)],
          "dark_steel" if edge == "steel" else "bronze", r, segs=12)
    return r


def sword(variant):
    r = root(f"sword_{variant}")
    edge = variant  # obsidian / steel
    blade(f"{r.name}_blade", edge, r, 0.07, 0.5, 0.024, 0.0055, 0.09, fuller=0.5 if edge == "steel" else 0.0, taper=0.85)
    guard_mat = "steel" if edge == "steel" else "dark_steel"
    box(f"{r.name}_guard", (0.16, 0.024, 0.02), (0, 0, 0.06), guard_mat, r, bevel=0.004)
    for s in (-1, 1):
        lathe(f"{r.name}_quillon{s}", [(0, -0.014), (0.013, -0.007), (0.013, 0.007), (0, 0.014)],
              guard_mat, r, segs=14, transform=Matrix.Translation((s * 0.088, 0, 0.06)))
    lathe(f"{r.name}_ricasso", [(0.02, 0.05), (0.022, 0.07)], guard_mat, r, segs=16)
    wrapped_grip(f"{r.name}_grip", "wrap", r, -0.1, 0.15, 0.015, bands=12)
    lathe(f"{r.name}_pommel", [(0, -0.15), (0.017, -0.145), (0.024, -0.128), (0.02, -0.112), (0.011, -0.104), (0.011, -0.1)],
          guard_mat, r, segs=16)
    return r


def cane():
    """Bastón de duelo: madera oscura lustrada, puño de latón y regatón de acero."""
    r = root("dueling_cane")
    lathe(f"{r.name}_shaft", [(0.012, 0.0), (0.0125, 0.4), (0.0105, 0.82), (0.0105, 0.83)], "dark_wood", r, segs=16)
    lathe(f"{r.name}_ferrule", [(0.0108, 0.82), (0.0112, 0.85), (0.008, 0.865), (0, 0.868)], "steel", r, segs=16)
    lathe(f"{r.name}_collar", [(0.0125, -0.005), (0.015, 0.0), (0.015, 0.012), (0.0125, 0.017)], "brass", r, segs=20)
    lathe(f"{r.name}_knob", [(0, -0.075), (0.016, -0.072), (0.024, -0.058), (0.022, -0.035), (0.016, -0.02),
                             (0.014, -0.005)], "brass", r, segs=24)
    return r


def shield():
    """Rodela de madera con borde de acero, umbo y remaches. Frente hacia -Y (Blender), agarre en el origen."""
    r = root("shield")
    face = Matrix.Rotation(math.radians(90), 4, "X")  # eje del disco: Z -> -Y
    front = Matrix.Translation((0, -0.035, 0)) @ face
    lathe(f"{r.name}_board", [(0, 0.0), (0.29, 0.0), (0.29, 0.014), (0.2, 0.022), (0, 0.026)], "wood", r, segs=48,
          transform=front)
    lathe(f"{r.name}_rim", [(0.284, -0.004), (0.3, -0.002), (0.304, 0.008), (0.3, 0.018), (0.284, 0.02), (0.284, -0.004)],
          "dark_steel", r, segs=48, transform=front, caps=False)
    lathe(f"{r.name}_boss", [(0.085, 0.024), (0.085, 0.03), (0.07, 0.04), (0.045, 0.06), (0.02, 0.068), (0, 0.07)],
          "steel", r, segs=32, transform=front)
    for i in range(12):
        a = 2 * math.pi * i / 12
        for rad in (0.26, 0.1):
            if rad == 0.1 and i % 2:
                continue
            lathe(f"{r.name}_rivet{i}_{rad}", [(0.007, 0.0), (0.006, 0.004), (0, 0.006)], "brass", r, segs=8,
                  transform=front @ Matrix.Translation((rad * math.cos(a), rad * math.sin(a), 0.016 + (rad < 0.2) * 0.008)))
    # Asa y correa en la parte de atrás.
    box(f"{r.name}_handle", (0.03, 0.03, 0.13), (0, 0.0, 0), "leather", r, bevel=0.006)
    for z in (-0.075, 0.075):
        box(f"{r.name}_bracket{z}", (0.04, 0.035, 0.02), (0, -0.015, z), "dark_steel", r, bevel=0.003)
    return r


def vial():
    """Frasco de metales: vidrio, alcohol con escamas de metal, corcho y cápsula."""
    r = root("vial")
    lathe(f"{r.name}_glass", [(0, 0.0), (0.016, 0.0), (0.019, 0.006), (0.019, 0.06), (0.01, 0.072), (0.008, 0.08),
                              (0.0095, 0.085)], "vial_glass", r, segs=20)
    lathe(f"{r.name}_liquid", [(0, 0.003), (0.0165, 0.003), (0.0175, 0.008), (0.0175, 0.05), (0, 0.05)],
          "metal_flakes", r, segs=20)
    lathe(f"{r.name}_cork", [(0.0075, 0.075), (0.0085, 0.09), (0.0075, 0.096), (0, 0.097)], "cork", r, segs=12)
    lathe(f"{r.name}_cap", [(0.0092, 0.082), (0.0105, 0.084), (0.0105, 0.088), (0.0092, 0.089)], "brass", r, segs=16)
    return r


def coin():
    """Moneda (un "clip"): disco con canto marcado y el centro hundido."""
    r = root("coin")
    lathe(f"{r.name}_body", [(0, 0.0003), (0.009, 0.0003), (0.0098, 0.0011), (0.011, 0.0011), (0.0115, 0.0),
                             (0.0115, -0.0005), (0.011, -0.0016), (0.0098, -0.0016), (0.009, -0.0008), (0, -0.0008)],
          "bronze", r, segs=32)
    # Muescas del canto.
    for i in range(24):
        a = 2 * math.pi * i / 24
        box(f"{r.name}_notch{i}", (0.0008, 0.0008, 0.0024), (0.0116 * math.cos(a), 0.0116 * math.sin(a), -0.00025),
            "bronze", r, bevel=0)
    return r


BUILDERS = [
    ("dagger_obsidian", lambda: dagger("obsidian")),
    ("dagger_glass", lambda: dagger("glass")),
    ("dagger_steel", lambda: dagger("steel")),
    ("sword_obsidian", lambda: sword("obsidian")),
    ("sword_steel", lambda: sword("steel")),
    ("dueling_cane", cane),
    ("shield", shield),
    ("vial", vial),
    ("coin", coin),
]


def export(r):
    bpy.ops.object.select_all(action="DESELECT")
    r.select_set(True)
    for c in r.children_recursive:
        c.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT_DIR, r.name + ".glb"), export_format="GLB",
                              use_selection=True, export_yup=True)
    print("EXPORTADO", r.name)


def render_preview(roots):
    x = 0.0
    for r in roots:
        r.location.x = x
        x += 0.35 if r.name == "shield" else 0.12
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.show_specular_highlight = True
    sc.render.resolution_x, sc.render.resolution_y = 1600, 1000
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(x + 0.1, 1.9)
    cam.location = (x / 2 - 0.06, -3, 0.27)
    cam.rotation_euler = (math.radians(90), 0, 0)
    sc.render.filepath = os.path.abspath(PREVIEW)
    bpy.ops.render.render(write_still=True)


roots = []
for _name, build in BUILDERS:
    r = build()
    export(r)
    roots.append(r)
if PREVIEW:
    render_preview(roots)
