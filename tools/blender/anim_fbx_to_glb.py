"""FBX de solo animación (esqueleto de Mixamo, sin malla, p. ej. lo que exporta ActionForge) -> .glb para usar de donante.

Uso (desde la carpeta del proyecto):
  blender -b -P tools/blender/anim_fbx_to_glb.py -- <salida.glb> <clips.fbx> [más.fbx ...]
  "<archivo.fbx>=<nombre>" renombra su único clip (los de Mixamo se llaman todos "mixamo.com").

- Los huesos pierden "mixamorig:"; los clips se llaman como en el FBX ("Armature|punch_jab" -> "punch_jab").
- El juego los copia a cada personaje con BoneTools.Retargeter, así que el reposo del esqueleto no tiene que coincidir.
"""
import re
import sys

import bpy

PREFIX = r"mixamorig[0-9]*:"
out_path, *paths = sys.argv[sys.argv.index("--") + 1:]

bpy.ops.wm.read_factory_settings(use_empty=True)
arm = None
clips = {}
for path in paths:
    path, _, rename = path.partition("=")
    known = set(bpy.data.actions)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.type == "ARMATURE" and arm is None:
            arm = o
        elif o != arm:
            bpy.data.objects.remove(o)
    for a in bpy.data.actions:
        if a in known:
            continue
        parts = a.name.split("|")  # "Armature|clip" o, de Meshy, "SmartRigArmature|clip|BaseLayer"
        name = rename or (parts[1] if len(parts) > 2 else parts[-1])
        if name in clips or name == "rest":
            continue
        a.name = name
        for layer in a.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        fc.data_path = re.sub(PREFIX, "", fc.data_path)
        a.use_fake_user = True
        clips[name] = a

for b in arm.data.bones:
    b.name = re.sub(PREFIX, "", b.name)
arm.name = "Armature"
if arm.animation_data:
    arm.animation_data_clear()
ad = arm.animation_data_create()
for name, action in clips.items():
    track = ad.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, int(action.frame_range[0]), action)
    if strip.action_slot is None and len(action.slots):
        strip.action_slot = action.slots[0]
    track.mute = True
bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_force_sampling=True)
print("EXPORTADO", out_path, list(clips))
