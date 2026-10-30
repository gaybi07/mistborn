"""Junta los .glb de ActionForge (un personaje con una animación cada uno) en un solo .glb.

Uso (desde la carpeta del proyecto):
  blender -b -P tools/blender/actionforge_to_glb.py -- <salida.glb> <anim1.glb> [anim2.glb ...]

- Malla y esqueleto (rig de Quaternius, nombres tipo Unreal: pelvis, spine_01, upperarm_l...)
  salen del primer archivo; de los demás solo la animación.
- Cada animación se llama como su archivo sin "_adjusted_fit" ni "_loop" ("sprint_loop_adjusted_fit.glb"
  -> "sprint"; Godot quitaría "_loop" al importar de todos modos). Ese nombre es el que va en
  ModelRig.ANIMS; qué se repite lo decide ModelRig.LOOPING.
- Animaciones "en el lugar": se anula el desplazamiento del hueso root (el juego mueve al
  personaje). La cadera conserva su subida y bajada (caer, agacharse).
- ActionForge exporta el color como emisión (se vería sin sombras): se pasa a color base.
"""
import bpy, os, sys

TEXTURE_SIZE = 1024
SUFFIX = "_adjusted_fit"

out_path, *anim_paths = sys.argv[sys.argv.index("--") + 1:]


def fcurves(action):
    if hasattr(action, "layers"):
        return [fc for l in action.layers for s in l.strips for cb in s.channelbags for fc in cb.fcurves]
    return list(action.fcurves)


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path, bone_heuristic="TEMPERANCE")
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == "ARMATURE")
    action = arm.animation_data.action if arm.animation_data else None
    return new, arm, action


bpy.ops.wm.read_factory_settings(use_empty=True)
arm = None
actions = []
for i, path in enumerate(anim_paths):
    objs, a, action = import_glb(path)
    if action:
        action.name = os.path.splitext(os.path.basename(path))[0].replace(SUFFIX, "").removesuffix("_loop")
        for fc in fcurves(action):
            if fc.data_path == 'pose.bones["root"].location':
                for k in fc.keyframe_points:
                    k.co[1] = k.handle_left[1] = k.handle_right[1] = 0.0
        action.use_fake_user = True
        actions.append(action)
    if i == 0:
        arm = a
        continue
    for o in objs:
        bpy.data.objects.remove(o)

for o in arm.children:
    if o.type == "MESH":
        # Viene sin índices (cada triángulo con sus vértices): unirlos reduce el archivo.
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=0.00001)
        bpy.ops.object.mode_set(mode="OBJECT")

# Cada animación en su pista NLA: el exportador glTF exporta una animación por pista.
arm.animation_data.action = None
for track in list(arm.animation_data.nla_tracks):  # la que deja el importador, con el nombre original
    arm.animation_data.nla_tracks.remove(track)
for action in actions:
    track = arm.animation_data.nla_tracks.new()
    track.name = action.name
    strip = track.strips.new(action.name, int(action.frame_range[0]), action)
    if hasattr(strip, "action_slot") and strip.action_slot is None and len(action.slots):
        strip.action_slot = action.slots[0]
    track.mute = True

for mat in bpy.data.materials:
    if not mat.node_tree:
        continue
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    if not bsdf:
        continue
    emit = bsdf.inputs["Emission Color"]
    if emit.links:
        links.new(emit.links[0].from_socket, bsdf.inputs["Base Color"])
        links.remove(emit.links[0])
    emit.default_value = (0, 0, 0, 1)
    bsdf.inputs["Emission Strength"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Metallic"].default_value = 0.0

for img in bpy.data.images:
    if img.size[0] > TEXTURE_SIZE:
        img.scale(TEXTURE_SIZE, TEXTURE_SIZE)

bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                          export_image_format="JPEG", export_image_quality=88)
print("EXPORTADO", out_path, [a.name for a in actions])
