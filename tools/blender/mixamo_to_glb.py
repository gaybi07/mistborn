"""Junta un personaje de Mixamo y sus animaciones en un solo .glb para el juego.

Uso (desde la carpeta del proyecto):
  blender -b -P tools/blender/mixamo_to_glb.py -- <salida.glb> <modelo.fbx> [animación.fbx ...]

- <modelo.fbx>: un FBX bajado "With Skin" (de ahí salen la malla y el esqueleto; si trae una
  animación también se incluye).
- Cada animación se llama como su archivo ("Jumping Down.fbx" -> "Jumping_Down"); ese nombre
  es el que va en ModelRig.ANIMS.
- Se quita el prefijo "mixamorig:" de los huesos.
- Animaciones "en el lugar": la cadera no avanza ni se va de costado, y la subida o bajada
  total se reparte para que empiece y termine a la altura de reposo (el juego mueve al
  personaje; si la animación también lo moviera, el modelo se separaría de su cápsula).
- Texturas reducidas a TEXTURE_SIZE para que el juego no pese de más.
"""
import bpy, os, sys

TEXTURE_SIZE = 1024
PREFIX = "mixamorig:"

out_path, model_path, *anim_paths = sys.argv[sys.argv.index("--") + 1:]


def fcurves(action):
    if hasattr(action, "layers"):
        return [fc for l in action.layers for s in l.strips for cb in s.channelbags for fc in cb.fcurves]
    return list(action.fcurves)


def anim_name(path):
    return os.path.splitext(os.path.basename(path))[0].strip().replace(" ", "_")


def import_fbx(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == "ARMATURE")
    action = arm.animation_data.action if arm.animation_data else None
    return new, arm, action


def clean_action(action, name, scale):
    action.name = name
    for fc in fcurves(action):
        fc.data_path = fc.data_path.replace(PREFIX, "")
        if fc.data_path.endswith(".location"):
            # El esqueleto venía a escala 0,01 (centímetros): pasar los desplazamientos a metros.
            for k in fc.keyframe_points:
                k.co[1] *= scale
                k.handle_left[1] *= scale
                k.handle_right[1] *= scale
    # Cadera en el lugar (ejes locales de Mixamo: 0 = costado, 1 = arriba, 2 = adelante).
    for fc in fcurves(action):
        if fc.data_path != 'pose.bones["Hips"].location':
            continue
        keys = fc.keyframe_points
        if len(keys) < 2:
            continue
        first, last = keys[0].co[1], keys[-1].co[1]
        t0, t1 = keys[0].co[0], keys[-1].co[0]
        for k in keys:
            if fc.array_index == 1:
                drift = first + (last - first) * (k.co[0] - t0) / max(t1 - t0, 1e-6)
                delta = k.co[1] - drift
            else:
                delta = 0.0
            k.co[1] = delta
            k.handle_left[1] = delta
            k.handle_right[1] = delta
    action.use_fake_user = True


bpy.ops.wm.read_factory_settings(use_empty=True)
objs, arm, first_action = import_fbx(model_path)
for b in arm.data.bones:
    b.name = b.name.replace(PREFIX, "")
for o in objs:
    for vg in getattr(o, "vertex_groups", []):
        vg.name = vg.name.replace(PREFIX, "")
arm.name = "Armature"
# Mixamo trae el esqueleto girado 90° y a escala 0,01: aplicarlo para que todo quede en metros
# y sin transformaciones (si no, el juego mide mal la altura del modelo).
scale = arm.scale.x
bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

actions = []
if first_action:
    clean_action(first_action, anim_name(model_path), scale)
    actions.append(first_action)
for path in anim_paths:
    if os.path.abspath(path) == os.path.abspath(model_path):
        continue
    extra, extra_arm, action = import_fbx(path)
    if action:
        extra_arm.animation_data.action = None
        clean_action(action, anim_name(path), extra_arm.scale.x)
        actions.append(action)
    for o in extra:
        bpy.data.objects.remove(o)

# Cada animación en su pista NLA: el exportador glTF exporta una animación por pista.
arm.animation_data_create()
arm.animation_data.action = None
for action in actions:
    track = arm.animation_data.nla_tracks.new()
    track.name = action.name
    strip = track.strips.new(action.name, int(action.frame_range[0]), action)
    if hasattr(strip, "action_slot") and strip.action_slot is None and len(action.slots):
        strip.action_slot = action.slots[0]
    track.mute = True

# Los materiales de Mixamo salen muy brillantes (parecen plástico): tela mate, sin metal.
for mat in bpy.data.materials:
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if mat.node_tree else None
    if bsdf:
        for key, value in (("Roughness", 0.85), ("Metallic", 0.0)):
            for link in list(bsdf.inputs[key].links):
                mat.node_tree.links.remove(link)
            bsdf.inputs[key].default_value = value

for img in bpy.data.images:
    if img.size[0] > TEXTURE_SIZE:
        img.scale(TEXTURE_SIZE, TEXTURE_SIZE)

bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                          export_image_format="JPEG", export_image_quality=88)
print("EXPORTADO", out_path, [a.name for a in actions])
