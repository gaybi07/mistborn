"""Genera el modelo base del alomántico (pose T) para subir a Mixamo.

Uso (desde la carpeta del proyecto):
    blender --background --factory-startup --python tools/blender/make_allomancer.py -- assets/characters/allomancer

Crea en esa carpeta:
    allomancer.fbx   -> el archivo que se sube a Mixamo
    allomancer.blend -> para retocarlo a mano en Blender
    preview_front.png / preview_side.png -> vistas de comprobación

El cuerpo se construye con un "esqueleto" de vértices y el modificador Skin (como un muñeco de
alambre al que se le da volumen), se suaviza con Subdivision y se colorea por zonas.
Sin capa ni armas: la capa de bruma es procedural en el juego y las armas se enganchan a las manos.
Coordenadas de Blender: Z arriba, el personaje mira hacia -Y, brazos en cruz a lo largo de X.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

OUT_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
os.makedirs(OUT_DIR, exist_ok=True)

COLORS = {
    "skin": (0.9, 0.77, 0.67),
    "shirt": (0.15, 0.15, 0.17),
    "pants": (0.12, 0.12, 0.13),
    "boots": (0.07, 0.06, 0.06),
    "belt": (0.2, 0.15, 0.1),
    "bracers": (0.14, 0.1, 0.08),
    "hair": (0.07, 0.05, 0.05),
    "eyes": (0.03, 0.03, 0.03),
    "vial": (0.45, 0.7, 1.0),
}


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def make_material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.8
        if name == "vial":
            bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
            bsdf.inputs["Emission Strength"].default_value = 1.5
    return mat


# --------------------------------------------------------------------------- cuerpo

# nombre: (posición, (radio_x, radio_y))
JOINTS = {
    "pelvis": ((0, 0, 0.95), (0.145, 0.11)),
    "waist": ((0, 0, 1.08), (0.125, 0.095)),
    "chest": ((0, -0.005, 1.28), (0.17, 0.12)),
    "upper": ((0, 0, 1.42), (0.175, 0.105)),
    "neck0": ((0, 0, 1.5), (0.055, 0.055)),
    "neck1": ((0, 0, 1.57), (0.05, 0.05)),
}
for side, s in (("L", 1), ("R", -1)):
    JOINTS.update({
        f"shoulder{side}": ((s * 0.2, 0, 1.44), (0.072, 0.07)),
        f"elbow{side}": ((s * 0.45, 0, 1.44), (0.045, 0.045)),
        f"wrist{side}": ((s * 0.69, 0, 1.44), (0.034, 0.03)),
        f"palm{side}": ((s * 0.76, 0, 1.44), (0.045, 0.02)),
        f"tip{side}": ((s * 0.83, 0, 1.44), (0.03, 0.015)),
        f"thumb{side}": ((s * 0.745, -0.05, 1.43), (0.015, 0.015)),
        f"hip{side}": ((s * 0.095, 0, 0.92), (0.085, 0.085)),
        f"thigh{side}": ((s * 0.1, 0, 0.72), (0.075, 0.075)),
        f"knee{side}": ((s * 0.1, 0, 0.5), (0.056, 0.056)),
        f"calf{side}": ((s * 0.1, 0.005, 0.33), (0.058, 0.058)),
        f"ankle{side}": ((s * 0.1, 0, 0.09), (0.046, 0.046)),
        f"toe{side}": ((s * 0.1, -0.13, 0.035), (0.042, 0.026)),
    })

BONES = [
    ("pelvis", "waist"), ("waist", "chest"), ("chest", "upper"), ("upper", "neck0"), ("neck0", "neck1"),
]
for side in ("L", "R"):
    BONES += [
        ("upper", f"shoulder{side}"), (f"shoulder{side}", f"elbow{side}"), (f"elbow{side}", f"wrist{side}"),
        (f"wrist{side}", f"palm{side}"), (f"palm{side}", f"tip{side}"), (f"wrist{side}", f"thumb{side}"),
        ("pelvis", f"hip{side}"), (f"hip{side}", f"thigh{side}"), (f"thigh{side}", f"knee{side}"),
        (f"knee{side}", f"calf{side}"), (f"calf{side}", f"ankle{side}"), (f"ankle{side}", f"toe{side}"),
    ]


# --------------------------------------------------------------------------- cuerpo musculoso
# Metaballs: cada músculo es una forma blanda; al solaparse se funden como arcilla.
# Medidas en metros = radio VISIBLE (calibrado: con rigidez 3 la superficie queda a ~0,63 del radio).
STIFFNESS = 3.0
VISIBLE = 0.63


def _q_from_x(direction):
    return Vector((1, 0, 0)).rotation_difference(Vector(direction).normalized())


def muscle(mb, center, radius, size=(1, 1, 1), direction=None):
    """Elipsoide: radius en metros, size estira cada eje (direction orienta el eje X local)."""
    e = mb.elements.new(type="ELLIPSOID")
    e.co = center
    e.radius = radius / VISIBLE
    e.size_x, e.size_y, e.size_z = size
    e.stiffness = STIFFNESS
    if direction:
        e.rotation = _q_from_x(direction)
    return e


def limb(mb, a, b, radius):
    """Cápsula (hueso con carne alrededor) entre dos puntos."""
    a, b = Vector(a), Vector(b)
    e = mb.elements.new(type="CAPSULE")
    e.co = (a + b) / 2
    e.radius = radius / VISIBLE
    e.size_x = (b - a).length / 2
    e.rotation = _q_from_x(b - a)
    e.stiffness = STIFFNESS
    return e


def build_body_muscular():
    mb = bpy.data.metaballs.new("Body")
    mb.resolution = 0.007
    mb.render_resolution = 0.007
    obj = bpy.data.objects.new("Body", mb)
    bpy.context.collection.objects.link(obj)

    # Torso
    muscle(mb, (0, 0.005, 0.95), 0.125, (1.0, 0.8, 0.75))          # pelvis
    muscle(mb, (0, -0.005, 1.1), 0.125, (1.05, 0.78, 1.1))         # abdomen y oblicuos
    muscle(mb, (0, -0.045, 1.1), 0.07, (0.85, 0.55, 1.35))         # recto abdominal
    muscle(mb, (0, 0.0, 1.28), 0.14, (1.1, 0.85, 1.05))            # caja torácica
    muscle(mb, (0, 0.0, 1.41), 0.11, (1.45, 0.75, 0.5))            # línea de hombros / clavículas
    limb(mb, (0, 0.01, 1.45), (0, 0.0, 1.6), 0.048)                # cuello
    for s in (1, -1):
        muscle(mb, (s * 0.07, -0.07, 1.36), 0.06, (1.5, 0.45, 0.65))      # pectorales (planos y anchos)
        muscle(mb, (s * 0.12, 0.035, 1.27), 0.08, (0.7, 0.7, 1.4))       # dorsales (espalda en V)
        muscle(mb, (s * 0.075, 0.04, 1.46), 0.06, (1.3, 0.65, 0.6), (s * 1, 0, -0.45))  # trapecios
        muscle(mb, (s * 0.07, 0.07, 0.9), 0.072, (1.0, 0.9, 1.0))        # glúteos

        # Brazo (en cruz, a lo largo de X)
        muscle(mb, (s * 0.215, 0.0, 1.44), 0.068, (1.15, 1.0, 0.95))      # deltoides
        limb(mb, (s * 0.22, 0, 1.44), (s * 0.46, 0, 1.44), 0.04)          # húmero
        muscle(mb, (s * 0.33, -0.022, 1.443), 0.045, (1.7, 0.9, 0.85))    # bíceps
        muscle(mb, (s * 0.31, 0.024, 1.44), 0.046, (1.8, 0.9, 0.85))      # tríceps
        limb(mb, (s * 0.46, 0, 1.44), (s * 0.69, 0, 1.44), 0.03)          # cúbito/radio
        muscle(mb, (s * 0.52, 0, 1.445), 0.042, (1.7, 0.95, 0.85))        # antebrazo
        muscle(mb, (s * 0.765, 0, 1.44), 0.042, (1.35, 0.55, 0.95))       # mano
        limb(mb, (s * 0.72, -0.03, 1.432), (s * 0.765, -0.065, 1.425), 0.013)  # pulgar

        # Pierna
        limb(mb, (s * 0.1, 0, 0.93), (s * 0.105, 0, 0.5), 0.06)          # fémur
        muscle(mb, (s * 0.1, -0.02, 0.73), 0.075, (0.9, 0.85, 2.0))       # cuádriceps
        muscle(mb, (s * 0.125, -0.01, 0.76), 0.045, (0.8, 0.8, 2.0))      # vasto externo
        muscle(mb, (s * 0.1, 0.03, 0.74), 0.065, (0.85, 0.8, 1.8))        # isquiotibiales
        muscle(mb, (s * 0.105, -0.015, 0.5), 0.045, (1.0, 1.0, 0.9))      # rodilla
        limb(mb, (s * 0.105, 0, 0.5), (s * 0.105, 0, 0.09), 0.045)       # tibia
        muscle(mb, (s * 0.105, 0.025, 0.37), 0.055, (0.9, 0.9, 1.5))      # gemelos
        limb(mb, (s * 0.105, 0.015, 0.055), (s * 0.105, -0.12, 0.03), 0.035)  # pie

    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    body = bpy.context.active_object
    body.name = "Body"
    # Malla limpia y uniforme (mejor para el rigging automático), suavizada y aligerada.
    body.data.remesh_voxel_size = 0.006
    bpy.ops.object.voxel_remesh()
    smooth = body.modifiers.new("Smooth", "SMOOTH")
    smooth.factor = 0.6
    smooth.iterations = 4
    dec = body.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = min(1.0, 22000 / max(len(body.data.polygons) * 2, 1))
    apply_modifiers(body)
    bpy.ops.object.shade_smooth()
    body.select_set(False)
    return body


def section(obj, z, tolerance=0.006):
    """Medio ancho (x) y profundidad (y mín, y máx) del cuerpo a la altura z."""
    pts = [obj.matrix_world @ v.co for v in obj.data.vertices if abs((obj.matrix_world @ v.co).z - z) < tolerance]
    pts = [p for p in pts if abs(p.x) < 0.3]  # solo el tronco, sin brazos
    return max(abs(p.x) for p in pts), min(p.y for p in pts), max(p.y for p in pts)


def build_body():
    names = list(JOINTS)
    index = {n: i for i, n in enumerate(names)}
    mesh = bpy.data.meshes.new("Body")
    mesh.from_pydata([JOINTS[n][0] for n in names], [(index[a], index[b]) for a, b in BONES], [])
    obj = bpy.data.objects.new("Body", mesh)
    bpy.context.collection.objects.link(obj)
    skin = obj.modifiers.new("Skin", "SKIN")
    skin.use_smooth_shade = True
    for i, n in enumerate(names):
        v = mesh.skin_vertices[0].data[i]
        v.radius = JOINTS[n][1]
        v.use_root = n == "pelvis"
    sub = obj.modifiers.new("Subdivision", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2
    apply_modifiers(obj)
    return obj


def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)


def add_primitive(kind, location, scale, material, rotation=(0, 0, 0), **kw):
    if kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=location, rotation=rotation, **kw)
    elif kind == "cylinder":
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, location=location, rotation=rotation, **kw)
    elif kind == "cube":
        bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation, **kw)
    obj = bpy.context.active_object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return obj


def color_body(body, mats):
    """Asigna material a cada cara según la zona del cuerpo."""
    order = ["skin", "shirt", "pants", "boots", "belt", "bracers"]
    for key in order:
        body.data.materials.append(mats[key])
    for poly in body.data.polygons:
        c = body.matrix_world @ poly.center
        ax = abs(c.x)
        if ax > 0.7:
            zone = "skin"  # manos
        elif ax > 0.58 and c.z > 1.3:
            zone = "bracers"
        elif c.z > 1.49 and ax < 0.09:
            zone = "skin"  # cuello
        elif c.z > 0.955:
            zone = "shirt"  # el borde con el pantalón lo tapa la pieza del cinturón
        elif c.z > 0.31:
            zone = "pants"
        else:
            zone = "boots"
        poly.material_index = order.index(zone)


def build_head(mats):
    parts = []
    head_c = Vector((0, -0.005, 1.67))
    parts.append(add_primitive("sphere", head_c, (0.088, 0.1, 0.112), mats["skin"], radius=1))
    parts.append(add_primitive("sphere", head_c + Vector((0, -0.02, -0.07)), (0.064, 0.06, 0.04), mats["skin"], radius=1))  # mandíbula
    parts.append(add_primitive("sphere", head_c + Vector((0, -0.097, -0.012)), (0.01, 0.016, 0.02), mats["skin"], radius=1))  # nariz
    for s in (1, -1):
        parts.append(add_primitive("sphere", head_c + Vector((s * 0.034, -0.086, 0.016)), (0.012, 0.007, 0.009), mats["eyes"], radius=1))
        parts.append(add_primitive("sphere", head_c + Vector((s * 0.087, 0.005, 0.0)), (0.01, 0.018, 0.026), mats["skin"], radius=1))  # orejas
    # Pelo: casquete detrás y arriba, más una melena hasta los hombros.
    parts.append(add_primitive("sphere", head_c + Vector((0, 0.018, 0.028)), (0.095, 0.104, 0.108), mats["hair"], radius=1))
    parts.append(add_primitive("sphere", head_c + Vector((0, 0.055, -0.085)), (0.082, 0.048, 0.11), mats["hair"], radius=1))
    # Cuello de la camisa: tapa el borde entre piel y tela.
    parts.append(add_primitive("cylinder", (0, 0.005, 1.5), (0.062, 0.06, 0.02), mats["shirt"], radius=1, depth=2))
    return parts


def build_gear(mats, body):
    """Cinturón ajustado a la cintura medida, frascos de metales y bolsa de monedas."""
    parts = []
    half_w, y_front, y_back = section(body, 0.955)
    cy = (y_front + y_back) / 2
    half_d = (y_back - y_front) / 2
    # Cinturón: un aro que sigue la cintura y tapa el borde entre camisa y pantalón.
    parts.append(add_primitive("cylinder", (0, cy, 0.955), (half_w + 0.008, half_d + 0.008, 0.028), mats["belt"], radius=1, depth=2))
    parts.append(add_primitive("cube", (0, y_front - 0.007, 0.955), (0.03, 0.006, 0.024), mats["bracers"], size=2))  # hebilla
    for x in (-0.6, -0.35, 0.55):
        px = x * half_w
        parts.append(add_primitive("cylinder", (px, y_front + 0.012, 0.915), (0.016, 0.016, 0.032), mats["vial"], radius=1, depth=2))
        parts.append(add_primitive("cylinder", (px, y_front + 0.012, 0.955), (0.011, 0.011, 0.008), mats["belt"], radius=1, depth=2))
    parts.append(add_primitive("cube", (half_w * 0.8, cy + half_d * 0.5, 0.915), (0.04, 0.025, 0.04), mats["belt"], size=2))  # bolsa
    return parts


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    return obj


def render_previews(target):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x = 700
    scene.render.resolution_y = 900
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.0
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    for name, loc, rot in (
        ("preview_front.png", (0, -4, 0.9), (math.radians(90), 0, 0)),
        ("preview_side.png", (4, 0, 0.9), (math.radians(90), 0, math.radians(90))),
    ):
        cam.location = loc
        cam.rotation_euler = rot
        scene.render.filepath = os.path.join(os.path.abspath(OUT_DIR), name)
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


def main():
    clear_scene()
    mats = {k: make_material(k, c) for k, c in COLORS.items()}
    body = build_body_muscular()
    color_body(body, mats)
    parts = [body] + build_head(mats) + build_gear(mats, body)
    character = join(parts, "Allomancer")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    tris = sum(len(p.vertices) - 2 for p in character.data.polygons)
    height = max((character.matrix_world @ v.co).z for v in character.data.vertices)
    print(f"Personaje: {tris} triángulos, altura {height:.2f} m")

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(os.path.abspath(OUT_DIR), "allomancer.blend"))
    bpy.ops.object.select_all(action="DESELECT")
    character.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(os.path.abspath(OUT_DIR), "allomancer.fbx"),
        use_selection=True,
        object_types={"MESH"},
        apply_scale_options="FBX_SCALE_ALL",
        mesh_smooth_type="FACE",
    )
    render_previews(character)
    print("Hecho:", os.path.abspath(OUT_DIR))


main()
