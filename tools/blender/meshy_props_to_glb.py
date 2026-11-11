"""Convierte modelos sueltos de Meshy (FBX + textura, sin rig) en .glb para el juego: a tamaño real (alto, o largo si
están acostados), apoyados en el piso y centrados, con menos triángulos cuando se van a repetir mucho.

Uso (desde la carpeta del proyecto):
  blender -b --factory-startup -P tools/blender/meshy_props_to_glb.py -- <carpeta con los zips descomprimidos> <salida>

Cada subcarpeta de la entrada tiene un .fbx y un .png (como vienen los zips de Meshy "texture_fbx"). PROPS dice, por
nombre de carpeta: el nombre del .glb, la medida en metros (alto; o largo si "lay") y cuántos triángulos dejar.
"""
import glob
import os
import sys

import bpy
from mathutils import Vector

# carpeta: [nombre de salida, metros, triángulos como mucho, medida = "alto" o "largo"]
PROPS = {
    "Bonewatch_Tower": ["KolossTorre", 9.0, 5000, "alto"],
    "Bonehide_Shelter": ["KolossRefugio", 3.4, 2500, "alto"],
    "Throne_of_Bones": ["KolossTrono", 3.4, 4000, "alto"],
    "Bonebound_Cage": ["KolossJaula", 2.6, 2500, "alto"],
    "Bonebound_War_Drum": ["KolossTambor", 1.7, 2000, "alto"],
    "Bone_Totem_Effigies": ["KolossEfigies", 3.2, 3000, "alto"],
    "Bonefire_Totem": ["KolossTotem", 4.6, 2500, "alto"],
    "Bonebound_Barricade": ["KolossBarricada", 2.6, 1500, "alto"],
    "Bonebound_Crate": ["KolossCajon", 1.2, 1500, "alto"],
    "Forgotten_Barrel": ["KolossBarril", 1.1, 1200, "alto"],
    "Relic_Blade": ["KolossEspada1", 2.6, 1500, "largo"],
    "Rustbound_Relic": ["KolossEspada2", 2.6, 1500, "largo"],
    "Rustfang": ["KolossEspada3", 2.6, 1500, "largo"],
}


def convert(folder, out_dir):
    name, meters, max_tris, measure = PROPS[os.path.basename(folder)]
    fbx = glob.glob(os.path.join(folder, "**", "*.fbx"), recursive=True)[0]
    png = glob.glob(os.path.join(folder, "**", "*.png"), recursive=True)[0]
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    bpy.ops.import_scene.fbx(filepath=fbx)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    ob = meshes[0]
    if len(meshes) > 1:
        with bpy.context.temp_override(active_object=ob, selected_editable_objects=meshes):
            bpy.ops.object.join()
    ob.name = name
    for o in list(bpy.context.scene.objects):
        if o != ob:
            bpy.data.objects.remove(o)
    ob.parent = None
    mat = bpy.data.materials.new(name)
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(png)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    with bpy.context.temp_override(object=ob, active_object=ob, selected_objects=[ob], selected_editable_objects=[ob]):
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    if tris > max_tris:
        dec = ob.modifiers.new("menos", "DECIMATE")
        dec.ratio = max_tris / tris
        with bpy.context.temp_override(object=ob, active_object=ob):
            bpy.ops.object.modifier_apply(modifier=dec.name)
    vs = [v.co for v in ob.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    size = hi - lo
    s = meters / (size.z if measure == "alto" else max(size.x, size.y))
    off = Vector(((lo.x + hi.x) / 2.0, (lo.y + hi.y) / 2.0, lo.z))
    for v in ob.data.vertices:
        v.co = (v.co - off) * s
    ob.data.update()
    path = os.path.join(out_dir, name + ".glb")
    for o in bpy.context.scene.objects:
        o.select_set(o == ob)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_image_format="WEBP")
    after = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    print("PROP %s tris %d -> %d medida=(%.1f, %.1f, %.1f)" % (name, tris, after, size.x * s, size.y * s, size.z * s))


def main():
    src, out_dir = sys.argv[sys.argv.index("--") + 1:][:2]
    os.makedirs(out_dir, exist_ok=True)
    for folder in sorted(glob.glob(os.path.join(src, "*"))):
        if os.path.basename(folder) in PROPS:
            convert(folder, out_dir)


main()
