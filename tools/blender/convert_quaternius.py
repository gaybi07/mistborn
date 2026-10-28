"""Convierte los .blend del pack "RPG Characters" de Quaternius a .glb (texturas incrustadas).

Uso:
    blender --background --factory-startup --python tools/blender/convert_quaternius.py -- <carpeta del pack> <carpeta de salida>
"""

import os
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
PACK, OUT = args[0], args[1]
os.makedirs(OUT, exist_ok=True)
blends = os.path.join(PACK, "Blends")
textures = os.path.join(PACK, "Textures")

for name in sorted(os.listdir(blends)):
    if not name.endswith(".blend"):
        continue
    bpy.ops.wm.open_mainfile(filepath=os.path.join(blends, name))
    # Las imágenes apuntan a rutas del autor: se redirigen a la carpeta Textures del pack.
    for img in bpy.data.images:
        base = os.path.basename(img.filepath.replace("\\", "/")) or img.name
        candidate = os.path.join(textures, base)
        if os.path.exists(candidate):
            img.filepath = candidate
            img.reload()
    # Los materiales usan "Diffuse BSDF", que el exportador glTF ignora: se cambia por un
    # Principled BSDF con la textura conectada al color base.
    for mat in bpy.data.materials:
        tree = mat.node_tree
        if tree is None:
            continue
        tex = next((n for n in tree.nodes if n.type == "TEX_IMAGE"), None)
        out = next((n for n in tree.nodes if n.type == "OUTPUT_MATERIAL"), None)
        if tex is None or out is None:
            continue
        for n in [n for n in tree.nodes if n.type == "BSDF_DIFFUSE"]:
            tree.nodes.remove(n)
        bsdf = tree.nodes.new("ShaderNodeBsdfPrincipled")
        bsdf.inputs["Roughness"].default_value = 0.85
        tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
        print(f"  material {mat.name}: textura {tex.image.name if tex.image else '-'} conectada")
    out = os.path.join(OUT, name.replace(".blend", ".glb"))
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=True)
    anims = sorted(a.name for a in bpy.data.actions)
    print(f"CONVERTIDO {name} -> {out} | {len(anims)} animaciones: {', '.join(anims)}")
