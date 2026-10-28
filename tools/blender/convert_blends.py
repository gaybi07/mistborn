"""Convierte todos los .blend de una carpeta a .glb e imprime el tamaño de cada modelo.

Uso:
    blender --background --factory-startup --python tools/blender/convert_blends.py -- <carpeta .blend> <carpeta salida>

Los materiales de estos packs son colores planos; si usan "Diffuse BSDF" (que el exportador
glTF ignora) se cambian por Principled BSDF conservando el color.
"""

import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = args[0], args[1]
os.makedirs(OUT, exist_ok=True)


def fix_materials():
    for mat in bpy.data.materials:
        tree = mat.node_tree
        if tree is None:
            continue
        out = next((n for n in tree.nodes if n.type == "OUTPUT_MATERIAL"), None)
        diffuse = next((n for n in tree.nodes if n.type == "BSDF_DIFFUSE"), None)
        principled = next((n for n in tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if out is None:
            continue
        if principled is not None:
            # Hay un Principled con el color real y, aparte, un Diffuse en otra salida (de otro
            # motor): se borra lo sobrante y el Principled queda conectado a la única salida.
            for n in [n for n in tree.nodes if n.type == "BSDF_DIFFUSE"]:
                tree.nodes.remove(n)
            for n in [n for n in tree.nodes if n.type == "OUTPUT_MATERIAL" and n != out]:
                tree.nodes.remove(n)
            emission = next((n for n in tree.nodes if n.type == "EMISSION"), None)
            if emission is not None:  # ventanas: el brillo pasa al Principled
                principled.inputs["Emission Color"].default_value = emission.inputs["Color"].default_value
                principled.inputs["Emission Strength"].default_value = 2.0
                tree.nodes.remove(emission)
            tree.links.new(principled.outputs["BSDF"], out.inputs["Surface"])
            out.target = "ALL"
            out.is_active_output = True
            continue
        if diffuse is None:
            continue
        color = diffuse.inputs["Color"].default_value[:]
        tex_link = diffuse.inputs["Color"].links[0].from_socket if diffuse.inputs["Color"].links else None
        tree.nodes.remove(diffuse)
        bsdf = tree.nodes.new("ShaderNodeBsdfPrincipled")
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = 0.9
        if tex_link:
            tree.links.new(tex_link, bsdf.inputs["Base Color"])
        tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])


for name in sorted(os.listdir(SRC)):
    if not name.endswith(".blend"):
        continue
    bpy.ops.wm.open_mainfile(filepath=os.path.join(SRC, name))
    fix_materials()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            w = obj.matrix_world @ Vector(corner)
            lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
    size = hi - lo
    out = os.path.join(OUT, name.replace(".blend", ".glb"))
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_apply=True)
    # Blender: Z arriba. Tamaño en metros (ancho X, fondo Y, alto Z) y centro de la base.
    print(f"MODELO {name[:-6]}: ancho {size.x:.2f} fondo {size.y:.2f} alto {size.z:.2f} "
          f"| base x[{lo.x:.2f},{hi.x:.2f}] y[{lo.y:.2f},{hi.y:.2f}] z0 {lo.z:.2f}")
