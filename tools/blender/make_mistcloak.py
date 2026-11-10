# Capa de bruma de Vin desde cero: una sola tela del cuello a los tobillos, abierta adelante, con cuello
# alzado y broche, sin capucha. Se cuelga con simulación de tela sobre Vin (brazos y piernas en su pose de reposo de
# Idle_12, torso en el reposo del esqueleto) y se riguea con cadenas de huesos para el SpringBoneSimulator3D.
# Abajo se rasga en tiras: cortes desde el borde entre cadena y cadena, de distinto largo; cada tira se
# mueve con su cadena. Los bordes rotos, las puntas y los agujeros los corta el shader
# (shaders/mistcloak.gdshader), que calcula los mismos cortes (slit_col, slit_v).
#
# Uso: blender -b -P tools/blender/make_mistcloak.py -- <salida.glb> [vista.png]
# Ejes de Blender: Vin mira a -Y, arriba es +Z. El origen del .glb queda en el cuello (hueso Neck).
import math
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

VIN = r"C:/Users/gabih/Proyectos/Mister/assets/meshy/Vin.glb"
args = sys.argv[sys.argv.index("--") + 1:]
OUT = args[0]
SHOT = args[1] if len(args) > 1 else None

NU = 73  # columnas alrededor (impar: una en el centro de la espalda)
NV = 46  # filas del cuello al borde
LENGTH = 1.24  # largo de la tela del cuello al borde, sobre la espalda
GAP_TOP, GAP_HEM = 0.1, 0.62  # medio ángulo de la abertura de adelante (rad), arriba y abajo
CHAINS = 17  # cadenas de huesos alrededor
CHAIN_BONES = 6
START_ROW = 6  # fila donde la tela deja los hombros y empiezan las cadenas
FRAMES = 60


def slit_col(m):
    """Columna del corte m (entre la cadena m y la m + 1)."""
    return round((m + 0.5) * (NU - 1) / (CHAINS - 1))


def slit_v(m):
    """Desde dónde (v, 0 = cuello) está rasgado el corte m. Igual que en el shader."""
    return 0.45 + 0.05 * ((m * 7) % 5)


SLITS = {slit_col(m): round(slit_v(m) * (NV - 1)) for m in range(CHAINS - 1)}  # columna -> fila donde arranca

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=VIN)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
body_src = next(o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm)
NECK = (arm.matrix_world @ arm.data.bones["Neck"].head_local).copy()

# Pose para colgar la tela: brazos y piernas de Idle_12, torso, cuello y cabeza en reposo (la capa se ata
# al hueso del torso en reposo; si el torso se inclinara acá, en el juego quedaría corrida).
sc = bpy.context.scene
arm.animation_data.action = bpy.data.actions["Idle_12"]
sc.frame_set(1)
LIMBS = ("Shoulder", "Arm", "ForeArm", "Hand", "UpLeg", "Leg", "Foot", "Toe")
keep = {pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones
        if any(pb.name.replace("Left", "").replace("Right", "").startswith(k) for k in LIMBS)
        and ("Left" in pb.name or "Right" in pb.name)}
arm.animation_data.action = None
for pb in arm.pose.bones:
    pb.matrix_basis = keep.get(pb.name, pb.matrix_basis.__class__())
bpy.context.view_layer.update()
J = {pb.name: arm.matrix_world @ pb.head - NECK for pb in arm.pose.bones}
dg = bpy.context.evaluated_depsgraph_get()
body = bpy.data.objects.new("Body", bpy.data.meshes.new_from_object(body_src.evaluated_get(dg)))
body.matrix_world = body_src.matrix_world
sc.collection.objects.link(body)
for o in list(bpy.data.objects):
    if o is not body:
        bpy.data.objects.remove(o)
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
body.location -= NECK  # todo con el cuello en el origen
bpy.context.view_layer.update()
bpy.context.view_layer.objects.active = body
body.select_set(True)
bpy.ops.object.transform_apply(location=True)
# Para chocar: un cuerpo simple de cápsulas sobre los huesos (la malla de Meshy tiene capas de ropa
# superpuestas y la tela se traba entre ellas). Sin cabeza: la capucha cae hacia atrás sola.
bm = bmesh.new()


def capsule(a, b, r):
    d = b - a
    rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=r, radius2=r, depth=d.length,
                          matrix=Matrix.Translation((a + b) / 2) @ rot)
    for p in (a, b):
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=r, matrix=Matrix.Translation(p))


def blob(c, rx, ry, rz):
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=1.0,
                              matrix=Matrix.Translation(c) @ Matrix.Diagonal((rx, ry, rz, 1)))


blob(Vector((0, 0.0, -0.10)), 0.15, 0.11, 0.14)  # pecho
blob(Vector((0, 0.0, -0.25)), 0.13, 0.10, 0.12)  # cintura
blob(Vector((0, 0.0, -0.40)), 0.17, 0.12, 0.13)  # cadera
for s in ("Left", "Right"):
    capsule(J[s + "Shoulder"], J[s + "Arm"], 0.045)
    capsule(J[s + "Arm"], J[s + "ForeArm"], 0.055)
    capsule(J[s + "ForeArm"], J[s + "Hand"], 0.045)
    capsule(J[s + "Hand"], J[s + "Hand"] + (J[s + "Hand"] - J[s + "ForeArm"]).normalized() * 0.1, 0.045)  # dedos
    capsule(J[s + "UpLeg"], J[s + "Leg"], 0.085)
    capsule(J[s + "Leg"], J[s + "Foot"], 0.06)
    capsule(J[s + "Foot"], J[s + "ToeBase"], 0.05)
proxy = bpy.data.objects.new("Proxy", bpy.data.meshes.new("Proxy"))
bm.to_mesh(proxy.data)
sc.collection.objects.link(proxy)
proxy.hide_render = True


def gap(v):
    return GAP_TOP + (GAP_HEM - GAP_TOP) * v ** 0.8


def ring(v):
    """Carpa inicial (más grande que el cuerpo; la tela cae sola): cuello, hombros y vuelo hasta abajo.
    Arranca toda afuera de las cápsulas: si empieza adentro, la colisión la despide."""
    if v < 0.06:  # cuello alzado
        t = v / 0.06
        return 0.085 + 0.02 * t, 0.075 + 0.02 * t, 0.09 - 0.02 * t
    if v < 0.16:  # cruza los hombros casi horizontal
        t = (v - 0.06) / 0.1
        return 0.105 + 0.2 * t, 0.095 + 0.12 * t, 0.07 - 0.07 * t
    t = (v - 0.16) / 0.84
    return 0.305 + 0.2 * t, 0.215 + 0.18 * t, -(LENGTH - 0.3) * t  # vuelo ancho: más pliegues


# Malla: filas (v) x columnas (u). theta 0 = centro de la espalda (+Y), ±(pi - gap) = bordes de adelante.
bm = bmesh.new()
uv_of = {}
grid = []
for i in range(NV):
    v = i / (NV - 1)
    rx, ry, z = ring(v)
    th_max = math.pi - gap(v)
    row = []
    for j in range(NU):
        u = j / (NU - 1)
        th = (u * 2 - 1) * th_max
        # El cuello baja adelante (en la foto queda bajo el mentón) y sube en la nuca.
        dz = -0.035 * (1 - math.cos(th)) / 2 * max(0.0, 1 - v / 0.16)
        vert = bm.verts.new((rx * math.sin(th), ry * math.cos(th), z + dz))
        uv_of[vert] = (u, v)
        row.append(vert)
    grid.append(row)
# Tiras: debajo del arranque de cada corte, la columna del corte tiene dos vértices (uno por lado).
twin = {}  # (fila, columna) -> vértice del lado derecho del corte
dup_info = []  # (fila, columna) de cada vértice duplicado, en orden
for j, start in SLITS.items():
    for i in range(start + 1, NV):
        twin[(i, j)] = bm.verts.new(grid[i][j].co)
        uv_of[twin[(i, j)]] = uv_of[grid[i][j]]
        dup_info.append((i, j))
uv_layer = bm.loops.layers.uv.new("UVMap")
for i in range(NV - 1):
    for j in range(NU - 1):
        q = (twin.get((i, j), grid[i][j]), grid[i][j + 1], grid[i + 1][j + 1], twin.get((i + 1, j), grid[i + 1][j]))
        f = bm.faces.new(q)
        for loop in f.loops:
            loop[uv_layer].uv = uv_of[loop.vert]
me = bpy.data.meshes.new("Mistcloak")
bm.to_mesh(me)
cape = bpy.data.objects.new("Mistcloak", me)
sc.collection.objects.link(cape)
n_grid = NV * NU
n_cloth = n_grid + len(dup_info)
pin = cape.vertex_groups.new(name="pin")
pin.add([j for j in range(NU)] + [NU + j for j in range(NU)], 1.0, "REPLACE")  # cuello alzado
for p in me.polygons:
    p.use_smooth = True

# Colgar la tela.
proxy.modifiers.new("Collision", "COLLISION")
proxy.collision.thickness_outer = 0.012
proxy.collision.cloth_friction = 8.0
cloth = cape.modifiers.new("Cloth", "CLOTH")
s = cloth.settings
s.quality = 10
s.mass = 0.3
s.tension_stiffness = s.compression_stiffness = 150.0  # más blanda rebota como un elástico y se arruga
s.tension_damping = s.compression_damping = 25.0
s.shear_stiffness = 15.0
s.bending_stiffness = 0.15
s.air_damping = 5.0
s.vertex_group_mass = "pin"
cs = cloth.collision_settings
cs.distance_min = 0.008
cs.use_self_collision = False  # en el cuello los puntos quedan a menos de la distancia mínima y la tela explota
cs.self_distance_min = 0.006
cloth.point_cache.frame_start = 1
cloth.point_cache.frame_end = FRAMES
sc.frame_start, sc.frame_end = 1, FRAMES
for f in range(1, FRAMES + 1):
    sc.frame_set(f)
bpy.context.view_layer.objects.active = cape
bpy.ops.object.modifier_apply(modifier="Cloth")

# Broche: una barrita de metal en el cuello, adelante.
P = [cape.data.vertices[NU + j].co for j in (0, NU - 1)]
clasp_at = (P[0] + P[1]) / 2 + Vector((0, -0.012, 0))
bpy.ops.mesh.primitive_cube_add(size=1, location=clasp_at)
clasp = bpy.context.active_object
clasp.name = "Clasp"
clasp.scale = (0.055, 0.008, 0.016)
bpy.ops.object.transform_apply(scale=True)

# Esqueleto: raíz (va al torso) y cadenas que bajan por la tela ya colgada.
V = [v.co.copy() for v in cape.data.vertices]
rows = [round(START_ROW + (NV - 1 - START_ROW) * k / CHAIN_BONES) for k in range(CHAIN_BONES + 1)]
chain_cols = [round(m * (NU - 1) / (CHAINS - 1)) for m in range(CHAINS)]
bpy.ops.object.armature_add(location=(0, 0, 0))
rig = bpy.context.active_object
rig.name = "CloakRig"
bpy.ops.object.mode_set(mode="EDIT")
eb = rig.data.edit_bones
root = eb[0]
root.name = "cloak_root"
root.head, root.tail = Vector((0, 0, -0.1)), Vector((0, 0, 0))
for m, c in enumerate(chain_cols):
    parent = root
    for k in range(CHAIN_BONES):
        b = eb.new(f"cloak_{m}_{k}")
        b.head = V[rows[k] * NU + c]
        b.tail = V[rows[k + 1] * NU + c]
        b.parent = parent
        b.use_connect = k > 0
        parent = b
bpy.ops.object.mode_set(mode="OBJECT")

# Pesos: arriba de START_ROW (cuello y hombros) todo a la raíz. Más abajo, entre los cortes la
# tela mezcla las dos cadenas vecinas (a lo ancho) para moverse entera; ya rasgada, cada tira va solo con
# su cadena, para que se separen. A lo largo, siempre mezcla los dos huesos vecinos.
groups = {b.name: cape.vertex_groups.new(name=b.name) for b in rig.data.bones}
if "pin" in cape.vertex_groups:
    cape.vertex_groups.remove(cape.vertex_groups["pin"])
step = (NU - 1) / (CHAINS - 1)  # columnas entre cadena y cadena
for idx in range(len(V)):
    if idx >= n_cloth:
        groups["cloak_root"].add([idx], 1.0, "REPLACE")
        continue
    if idx < n_grid:
        i, j = divmod(idx, NU)
        c_eff = j - 0.5 if (i, j) in twin else j  # el original queda del lado izquierdo del corte
    else:
        i, j = dup_info[idx - n_grid]
        c_eff = j + 0.5
    if i <= START_ROW:
        groups["cloak_root"].add([idx], 1.0, "REPLACE")
        continue
    f = (i - START_ROW) / (NV - 1 - START_ROW) * CHAIN_BONES
    b0 = min(int(f), CHAIN_BONES - 1)
    b1 = min(b0 + 1, CHAIN_BONES - 1)
    fb = f - b0 if b1 != b0 else 0.0
    cf = j / step
    m0 = min(int(cf), CHAINS - 1)
    m1 = min(m0 + 1, CHAINS - 1)
    fm = cf - m0 if m1 != m0 else 0.0
    # Cuánto ya es tira: según el corte más cercano, de 3 filas antes de su arranque a 2 después.
    near = min(SLITS, key=lambda c: abs(c - c_eff))
    p = min(1.0, max(0.0, (i - SLITS[near] + 3) / 5))
    owner = min(CHAINS - 1, max(0, round(c_eff / step)))
    w = {}
    for m, wm in ((m0, (1 - fm) * (1 - p)), (m1, fm * (1 - p)), (owner, p)):
        for b, wb in ((b0, 1 - fb), (b1, fb)):
            if wm * wb > 0:
                w[(m, b)] = w.get((m, b), 0.0) + wm * wb
    for (m, b), x in w.items():
        groups[f"cloak_{m}_{b}"].add([idx], x, "REPLACE")
# Broche: a la raíz.
clasp.vertex_groups.new(name="cloak_root").add(list(range(len(clasp.data.vertices))), 1.0, "REPLACE")
for o in (cape, clasp):
    o.parent = rig
    o.modifiers.new("Armature", "ARMATURE").object = rig

if SHOT:
    # Hoja de revisión: frente, costado y espalda, con el cuerpo.
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "OBJECT"
    sc.render.resolution_x, sc.render.resolution_y = 600, 900
    body.color = (0.75, 0.7, 0.65, 1)
    cape.color = (0.12, 0.12, 0.13, 1)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.7
    sc.camera = cam
    for name, ang in (("frente", 0), ("costado", 90), ("espalda", 180), ("tres_cuartos", 35)):
        a = math.radians(ang)
        cam.location = (4 * math.sin(a), -4 * math.cos(a), -0.55)
        cam.rotation_euler = (math.pi / 2, 0, a)
        sc.render.filepath = SHOT.replace(".png", f"_{name}.png")
        bpy.ops.render.render(write_still=True)

bpy.data.objects.remove(body)
bpy.data.objects.remove(proxy)
# Una sola malla con dos superficies: tela (0) y broche (1).
for o, m in ((cape, "Cloth"), (clasp, "Clasp")):
    o.data.materials.append(bpy.data.materials.new(m))
bpy.ops.object.select_all(action="DESELECT")
clasp.select_set(True)
cape.select_set(True)
bpy.context.view_layer.objects.active = cape
bpy.ops.object.join()
rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_skins=True,
                          export_animations=False, export_yup=True)
print("CLOAK", {"verts": len(V), "bones": len(rig.data.bones), "hem_z": round(min(v.z for v in V), 3),
                "neck_z": round(NECK.z, 3), "out": OUT})
