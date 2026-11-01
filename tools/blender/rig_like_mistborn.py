"""Le pone a un personaje en pose T (malla sin esqueleto, p. ej. de Meshy) el esqueleto del Mistborn
y sus animaciones: los pesos se copian de la malla del Mistborn por cercanía.

Uso (desde la carpeta del proyecto):
  blender -b -P tools/blender/rig_like_mistborn.py -- <salida.glb> <personaje.glb>

- El personaje tiene que mirar hacia -Y (el frente de glTF) con los brazos en cruz, como el Mistborn.
- Se escala para que muñecas y hombros caigan sobre los del esqueleto (el juego lo reescala a su
  altura igual): el esqueleto no se toca, así las animaciones se ven igual que en el Mistborn.
"""
import os
import sys

import bpy
from mathutils import Vector

TEXTURE_SIZE = 1024
MISTBORN = "assets/mixamo/Mistborn.glb"
WRIST_Z = 1.293  # altura de hand_l en el esqueleto del Mistborn

out_path, char_path = sys.argv[sys.argv.index("--") + 1:]


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path, bone_heuristic="TEMPERANCE")
    return [o for o in bpy.data.objects if o not in before]


bpy.ops.wm.read_factory_settings(use_empty=True)
source = import_glb(MISTBORN)
arm = next(o for o in source if o.type == "ARMATURE")
donor = next(o for o in source if o.type == "MESH" and o.parent == arm)
actions = list(bpy.data.actions)
if arm.animation_data:  # el import deja una animación puesta: los pesos se copian en reposo
    arm.animation_data.action = None
for pb in arm.pose.bones:
    pb.matrix_basis.identity()

new = import_glb(char_path)
body = next(o for o in new if o.type == "MESH")
for o in new:  # vaciar padres y transformaciones del import
    if o != body:
        bpy.data.objects.remove(o)
bpy.context.view_layer.objects.active = body
body.select_set(True)
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Altura de las muñecas del personaje: la de los vértices de las manos (los más alejados en X).
verts = [v.co for v in body.data.vertices]
span = max(abs(v.x) for v in verts)
hands = [v for v in verts if abs(v.x) > span * 0.8]
wrist_z = sum(v.z for v in hands) / len(hands)
body.scale = (1.0, 1.0, WRIST_Z / wrist_z)
bpy.ops.object.transform_apply(scale=True)
print("ESCALA Z", WRIST_Z / wrist_z)

# Pesos: grupos de vértices y valores copiados de la superficie más cercana del Mistborn.
for g in donor.vertex_groups:
    body.vertex_groups.new(name=g.name)
dt = body.modifiers.new("pesos", "DATA_TRANSFER")
dt.object = donor
dt.use_vert_data = True
dt.data_types_verts = {"VGROUP_WEIGHTS"}
dt.vert_mapping = "POLYINTERP_NEAREST"
dt.layers_vgroup_select_src = "ALL"
dt.layers_vgroup_select_dst = "NAME"
bpy.ops.object.modifier_apply(modifier=dt.name)

for o in source:
    if o != arm:
        bpy.data.objects.remove(o)
body.parent = arm
mod = body.modifiers.new("Armature", "ARMATURE")
mod.object = arm

# Cada animación del Mistborn en su pista NLA (el exportador glTF exporta una por pista).
ad = arm.animation_data or arm.animation_data_create()
ad.action = None
for track in list(ad.nla_tracks):
    ad.nla_tracks.remove(track)
for action in actions:
    track = ad.nla_tracks.new()
    track.name = action.name
    strip = track.strips.new(action.name, int(action.frame_range[0]), action)
    if hasattr(strip, "action_slot") and strip.action_slot is None and len(action.slots):
        strip.action_slot = action.slots[0]
    track.mute = True

for img in bpy.data.images:
    if img.size[0] > TEXTURE_SIZE:
        img.scale(TEXTURE_SIZE, TEXTURE_SIZE)

bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                          export_image_format="JPEG", export_image_quality=88)
print("EXPORTADO", out_path, [a.name for a in actions])
