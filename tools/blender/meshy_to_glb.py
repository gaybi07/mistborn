"""Junta un personaje de Meshy (FBX "All animation", esqueleto de Mixamo) en un solo .glb para el juego.

Uso (desde la carpeta del proyecto):
  blender -b -P tools/blender/meshy_to_glb.py -- <salida.glb> <textura.png> <modelo.fbx> [más_clips.fbx ...]

- <modelo.fbx> da la malla, el esqueleto y sus clips; los demás FBX (otras tandas del mismo personaje,
  con el mismo esqueleto) solo suman clips. Si un clip se repite queda el primero.
- Los clips se llaman como en Meshy ("SmartRigArmature|Walking|BaseLayer" -> "Walking") y los huesos
  pierden "mixamorig:".
- Clips en el lugar: la cadera no avanza ni queda corrida (el juego mueve al personaje), su altura se respeta.
"""
import re
import sys

import bpy

TEXTURE_SIZE = 1024
PREFIX = r"mixamorig[0-9]*:"
BLOAT = 12.0  # segundos: los clips más largos no se usan y pesan mucho

out_path, texture, model_path, *more = sys.argv[sys.argv.index("--") + 1:]


def fcurves(action):
    return [fc for l in action.layers for s in l.strips for cb in s.channelbags for fc in cb.fcurves]


def channelbags(action):
    return [cb for l in action.layers for s in l.strips for cb in s.channelbags]


def clean(action, name):
    action.name = name
    for bag in channelbags(action):
        for fc in list(bag.fcurves):
            if not fc.data_path.startswith("pose.bones"):
                bag.fcurves.remove(fc)  # el objeto no se mueve: solo los huesos
                continue
            fc.data_path = re.sub(PREFIX, "", fc.data_path)
            if fc.data_path != 'pose.bones["Hips"].location' or fc.array_index == 1:
                continue
            keys = fc.keyframe_points
            first = keys[0].co[1]
            travels = max(abs(k.co[1] - first) for k in keys) > 0.08
            # Algunos clips arrancan con la cadera corrida (hasta 1,35 m): siempre vuelve a su lugar.
            for k in keys:
                k.co[1] = k.handle_left[1] = k.handle_right[1] = 0.0 if travels else k.co[1] - first
    action.use_fake_user = True


def clip_name(action):
    parts = action.name.split("|")
    return parts[1] if len(parts) > 1 else action.name


def import_fbx(path):
    known = set(bpy.data.actions)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path)
    return [o for o in bpy.data.objects if o not in before], [a for a in bpy.data.actions if a not in known]


bpy.ops.wm.read_factory_settings(use_empty=True)
objs, new_actions = import_fbx(model_path)
arm = next(o for o in objs if o.type == "ARMATURE")
body = next(o for o in objs if o.type == "MESH")
if arm.animation_data:
    arm.animation_data_clear()
for b in arm.data.bones:
    b.name = re.sub(PREFIX, "", b.name)
for vg in body.vertex_groups:
    vg.name = re.sub(PREFIX, "", vg.name)
arm.name = "Armature"
# El esqueleto viene girado 90°: aplicarlo para que todo quede sin transformaciones (como Mixamo).
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

clips = {}
for path in [None] + more:
    if path:
        objs2, new_actions = import_fbx(path)
        for o in objs2:
            bpy.data.objects.remove(o)
    for a in new_actions:
        name = clip_name(a)
        if name not in clips and name != "rest" and (a.frame_range[1] - a.frame_range[0]) / 30.0 <= BLOAT:
            clips[name] = a
            clean(a, name)

ad = arm.animation_data_create()
ad.action = None
for name, action in clips.items():
    track = ad.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, int(action.frame_range[0]), action)
    if strip.action_slot is None and len(action.slots):
        strip.action_slot = action.slots[0]
    track.mute = True

# La textura viene aparte: mate, sin metal.
img = bpy.data.images.load(texture)
if img.size[0] > TEXTURE_SIZE:
    img.scale(TEXTURE_SIZE, TEXTURE_SIZE)
for slot in body.material_slots:
    nt = slot.material.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    for n in [n for n in nt.nodes if n.type == "TEX_IMAGE"]:
        nt.nodes.remove(n)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Metallic"].default_value = 0.0

for o in bpy.data.objects:
    if o not in (arm, body):
        bpy.data.objects.remove(o)
bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                          export_image_format="JPEG", export_image_quality=88)
print("EXPORTADO", out_path, list(clips))
