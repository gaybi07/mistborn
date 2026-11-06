"""Edificio de Meshy (FBX + texturas, millones de triángulos) -> .glb liviano para repetirlo en la ciudad.

Uso (desde la carpeta del proyecto):
  blender -b -P tools/blender/house_to_glb.py -- <salida.glb> <carpeta_con_el_fbx> [triángulos] [textura]

- Arma una malla nueva de [triángulos] (6000 por defecto) con UV propias y le hornea el color y el relieve de la
  original. Bajar la original sin hornear rompe la textura: sus UV son miles de islitas.
- Deja el origen en el centro de la planta, con la base en el suelo.
"""
import glob
import os
import sys

import bpy
from mathutils import Matrix, Vector

TEXTURE_SIZE = 1024
CAGE = 0.03  # distancia desde la malla nueva a la original al hornear (las casas miden ~1,9)

args = sys.argv[sys.argv.index("--") + 1:]
out_path, folder = args[:2]
target = int(args[2]) if len(args) > 2 else 6000
TEXTURE_SIZE = int(args[3]) if len(args) > 3 else TEXTURE_SIZE

bpy.ops.wm.read_factory_settings(use_empty=True)
fbx = glob.glob(os.path.join(folder, "*.fbx"))[0]
stem = fbx[:-4]
bpy.ops.import_scene.fbx(filepath=fbx)
high = next(o for o in bpy.data.objects if o.type == "MESH")
for o in list(bpy.data.objects):
    if o != high:
        bpy.data.objects.remove(o)
high.parent = None
bpy.context.view_layer.objects.active = high
high.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def source_material():
    mat = bpy.data.materials.new("original")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.9
    color = nt.nodes.new("ShaderNodeTexImage")
    color.image = bpy.data.images.load(stem + ".png")
    if color.image.size[0] > TEXTURE_SIZE:
        color.image.scale(TEXTURE_SIZE, TEXTURE_SIZE)
    nt.links.new(color.outputs[0], bsdf.inputs["Base Color"])
    if os.path.exists(stem + "_normal.png"):
        bump = nt.nodes.new("ShaderNodeTexImage")
        bump.image = bpy.data.images.load(stem + "_normal.png")
        bump.image.colorspace_settings.name = "Non-Color"
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(bump.outputs[0], nm.inputs["Color"])
        nt.links.new(nm.outputs[0], bsdf.inputs["Normal"])
    return mat


def export(obj):
    corners = [Vector(c) for c in obj.bound_box]
    lo = Vector((min(c[i] for c in corners) for i in range(3)))
    hi = Vector((max(c[i] for c in corners) for i in range(3)))
    obj.data.transform(Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))))
    print("MEDIDA", [round(hi[i] - lo[i], 3) for i in range(3)])
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_image_format="JPEG", export_image_quality=85,
                              export_tangents=True, export_animations=False, use_selection=True)
    print("EXPORTADO", out_path)


high.data.materials.clear()
high.data.materials.append(source_material())
# Ya viene liviana (exportada con pocos polígonos): se usa tal cual, con su textura.
if sum(len(p.vertices) - 2 for p in high.data.polygons) <= target:
    print("TRIS", sum(len(p.vertices) - 2 for p in high.data.polygons), "sin recortar")
    export(high)
    sys.exit(0)

# Malla nueva: sin UV, para que el recorte no tenga que respetar las islas.
low = high.copy()
low.data = high.data.copy()
low.name = "casa"
bpy.context.collection.objects.link(low)
while low.data.uv_layers:
    low.data.uv_layers.remove(low.data.uv_layers[0])
tris = sum(len(p.vertices) - 2 for p in high.data.polygons)
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = low
low.select_set(True)
mod = low.modifiers.new("low", "DECIMATE")
mod.ratio = min(1.0, target / tris)
bpy.ops.object.modifier_apply(modifier=mod.name)
print("TRIS", tris, "->", sum(len(p.vertices) - 2 for p in low.data.polygons))
for p in low.data.polygons:
    p.use_smooth = True

bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004)
bpy.ops.object.mode_set(mode="OBJECT")

mat = bpy.data.materials.new("casa")
mat.use_nodes = True
nt = mat.node_tree
bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
bsdf.inputs["Metallic"].default_value = 0.0
bsdf.inputs["Roughness"].default_value = 0.9
low.data.materials.clear()
low.data.materials.append(mat)


def bake_target(name, colorspace):
    img = bpy.data.images.new(name, TEXTURE_SIZE, TEXTURE_SIZE)
    img.colorspace_settings.name = colorspace
    node = nt.nodes.new("ShaderNodeTexImage")
    node.image = img
    return node


scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 4
scene.render.bake.use_selected_to_active = True
scene.render.bake.cage_extrusion = CAGE
scene.render.bake.margin = 6
high.select_set(True)
low.select_set(True)
bpy.context.view_layer.objects.active = low

color_node = bake_target("casa_color", "sRGB")
nt.nodes.active = color_node
scene.render.bake.use_pass_direct = False
scene.render.bake.use_pass_indirect = False
scene.render.bake.use_pass_color = True
bpy.ops.object.bake(type="DIFFUSE")

normal_node = bake_target("casa_normal", "Non-Color")
nt.nodes.active = normal_node
scene.render.bake.normal_space = "TANGENT"
bpy.ops.object.bake(type="NORMAL")

nt.links.new(color_node.outputs[0], bsdf.inputs["Base Color"])
nm = nt.nodes.new("ShaderNodeNormalMap")
nt.links.new(normal_node.outputs[0], nm.inputs["Color"])
nt.links.new(nm.outputs[0], bsdf.inputs["Normal"])
for img in [color_node.image, normal_node.image]:
    img.pack()

bpy.data.objects.remove(high)
export(low)
