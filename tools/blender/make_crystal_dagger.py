"""Daga de obsidiana tallada con un cristal incrustado (la del Mistborn).

Uso (desde la carpeta del proyecto):
    blender -b --factory-startup -P tools/blender/make_crystal_dagger.py -- assets/weapons/dagger_crystal.glb [preview.png]

- Hoja: obsidiana tallada a golpes (cicatrices de lascas superpuestas en las dos caras, con crestas
  donde se cruzan) y el filo mordido e irregular. Un cristal celeste facetado incrustado a lo largo.
- Guarda redonda de plata martillada con runas grabadas en el canto; mango de tiras de cuero con
  anillos de plata labrados; virolas martilladas; pomo con runas y un racimo de cristales negros.
- Las grietas y huecos se oscurecen con color por vértice (el juego lo multiplica por el material).

Convención (la de las armas del juego): origen en el centro del mango, la hoja hacia +Z en Blender
(+Y en Godot), lo plano de la hoja mirando a ±Y.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["dagger_crystal.glb"]
OUT = ARGS[0]
PREVIEW = ARGS[1] if len(ARGS) > 1 else ""

rng = random.Random(11)
bpy.ops.wm.read_factory_settings(use_empty=True)

# nombre: (color, metálico, rugosidad, alfa, emisión)
MATERIALS = {
    "obsidian": ((0.012, 0.012, 0.016), 0.0, 0.07, 1.0, 0.0),
    "crystal": ((0.3, 0.62, 1.0), 0.0, 0.02, 0.9, 0.35),
    "black_crystal": ((0.02, 0.02, 0.025), 0.0, 0.12, 1.0, 0.0),
    "silver": ((0.55, 0.55, 0.58), 1.0, 0.38, 1.0, 0.0),
    "leather": ((0.035, 0.03, 0.03), 0.0, 0.55, 1.0, 0.0),
}
_mats = {}


def mat(name):
    if name not in _mats:
        color, metal, rough, alpha, emit = MATERIALS[name]
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Alpha"].default_value = alpha
        # Color del material por el color de vértice (suciedad en las grietas).
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs[6].default_value = (*color, 1.0)
        nt.links.new(vc.outputs["Color"], mix.inputs[7])
        nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        if emit > 0:
            bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
            bsdf.inputs["Emission Strength"].default_value = emit
        if alpha < 1.0:
            m.surface_render_method = "BLENDED"
        m.diffuse_color = (*color, alpha)
        _mats[name] = m
    return _mats[name]


def finish(name, bm, material, colors=None, smooth=True, parent=None):
    """colors: lista de grises por vértice (1 = limpio, menos = sucio/hundido)."""
    me = bpy.data.meshes.new(name)
    bm.verts.ensure_lookup_table()
    if colors is not None:
        layer = bm.loops.layers.color.new("Col")
        for f in bm.faces:
            for loop in f.loops:
                g = colors[loop.vert.index]
                loop[layer] = (g, g, g, 1.0)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    if colors is None:
        attr = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
        for d in attr.data:
            d.color = (1, 1, 1, 1)
    me.materials.append(mat(material))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = parent
    return ob


# ------------------------------------------------------------------ ruido y relieve

def hash2(i, j, seed):
    r = random.Random((i * 73856093) ^ (j * 19349663) ^ (seed * 83492791))
    return r.random(), r.random()


def hammer(u, v, cell, seed):
    """Abolladuras de martillo: hundimiento 0..1 según la distancia al golpe más cercano."""
    gi, gj = math.floor(u / cell), math.floor(v / cell)
    best = 9.0
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            a, b = hash2(gi + di, gj + dj, seed)
            px, py = (gi + di + a) * cell, (gj + dj + b) * cell
            best = min(best, math.hypot(u - px, v - py))
    return max(0.0, 1.0 - best / (cell * 0.75)) ** 2


# Runas: cada celda de la banda tiene 2 o 3 trazos (rectas y arcos) en coordenadas 0..1.
STROKES = [
    ("line", (0.5, 0.1), (0.5, 0.9)), ("line", (0.2, 0.2), (0.8, 0.8)), ("line", (0.8, 0.2), (0.2, 0.8)),
    ("line", (0.2, 0.5), (0.8, 0.5)), ("line", (0.25, 0.15), (0.5, 0.5)), ("line", (0.5, 0.5), (0.75, 0.15)),
    ("arc", (0.5, 0.5), 0.3), ("arc", (0.5, 0.25), 0.18), ("line", (0.3, 0.85), (0.7, 0.85)),
]


def rune_depth(u, v, cells, seed):
    """u, v en 0..1 (u alrededor, v a lo alto de la banda): 1 dentro de un trazo grabado."""
    x = u * cells
    i = int(math.floor(x)) % cells
    cu, cv = x - math.floor(x), v
    r = random.Random(i * 977 + seed)
    strokes = r.sample(STROKES, r.choice((2, 3)))
    best = 9.0
    for kind, a, b in strokes:
        if kind == "line":
            ax, ay = a
            bx, by = b
            dx, dy = bx - ax, by - ay
            t = max(0.0, min(1.0, ((cu - ax) * dx + (cv - ay) * dy) / (dx * dx + dy * dy)))
            d = math.hypot(cu - ax - t * dx, cv - ay - t * dy)
        else:
            d = abs(math.hypot(cu - a[0], cv - a[1]) - b)
        best = min(best, d)
    return 1.0 if best < 0.07 else (0.5 if best < 0.1 else 0.0)


def lathe(name, profile, material, parent, segs=96, disp=None, oval=1.0):
    """Superficie de revolución alrededor de Z: profile = [(radio, z)]. disp(a, z, r) -> (dr, gris)."""
    bm = bmesh.new()
    colors = []
    rings = []
    for r, z in profile:
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            dr, g = disp(a, z, r) if (disp and r > 1e-5) else (0.0, 1.0)
            rr = r + dr
            ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a) * oval, z)))
            colors.append(g)
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if profile[0][0] > 1e-5:
        bm.faces.new(list(reversed(rings[0])))
    if profile[-1][0] > 1e-5:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return finish(name, bm, material, colors, parent=parent)


def dense(z0, z1, n, edge=None):
    """Perfil de radio constante con n filas entre z0 y z1 (edge: biselado en las puntas)."""
    return [(1.0, z0 + (z1 - z0) * k / n) for k in range(n + 1)]


# ------------------------------------------------------------------ hoja de obsidiana

BLADE_Z0 = 0.06
BLADE_LEN = 0.23


def half_width(t):
    # Hoja ancha en forma de hoja: se ensancha hasta un tercio y se afina en curva hasta la punta.
    grow = 0.78 + 0.22 * math.sin(min(t / 0.32, 1.0) * math.pi / 2)
    return 0.027 * grow * (1.0 - t) ** 0.7


def half_thick(t):
    return 0.0068 * (1.0 - t) ** 0.55 + 0.0004


def make_flakes(seed):
    """Lascas de una cara: elipses que entran desde los dos filos, inclinadas hacia la punta."""
    r = random.Random(seed)
    flakes = []
    # Tres filas por filo: retoques chicos sobre el filo, lascas medianas y lascas que llegan al
    # centro. Son cuencos: donde dos se tocan queda una cresta.
    for side in (-1, 1):
        for into, ln, wd, step, depth in ((0.12, 0.008, 0.006, 0.02, 0.0017), (0.48, 0.014, 0.011, 0.034, 0.0031),
                                          (0.82, 0.016, 0.013, 0.05, 0.0034)):
            t = r.uniform(0.0, step)
            while t < 0.97:
                size = r.uniform(0.8, 1.2) * (1.0 - 0.45 * t)
                flakes.append({
                    "t": t, "side": side,
                    "len": ln * size, "wid": wd * size,
                    "depth": r.uniform(0.75, 1.0) * depth * (1.0 - 0.4 * t),
                    "ang": r.uniform(0.15, 0.5),
                    "into": into + r.uniform(-0.08, 0.08),
                })
                t += r.uniform(0.75, 1.25) * step * (1.0 - 0.3 * t)
    return flakes


def carve(x, z, flakes):
    """Profundidad tallada en (x, z): la de la lasca que más hondo llega (crestas entre lascas)."""
    best = 0.0
    for f in flakes:
        zc = BLADE_Z0 + f["t"] * BLADE_LEN
        w = half_width(f["t"])
        xc = f["side"] * w * (1.0 - f["into"])
        # Eje largo de la lasca: hacia adentro, inclinado hacia la punta.
        ca, sa = math.cos(f["ang"]), math.sin(f["ang"])
        dx, dz = x - xc, z - zc
        along = -f["side"] * dx * ca + dz * sa
        across = f["side"] * dx * sa + dz * ca
        q = (along / f["len"]) ** 2 + (across / f["wid"]) ** 2
        if q < 1.0:
            # Cicatriz cóncava (concoidea): honda al centro y con borde marcado.
            best = max(best, f["depth"] * (1.0 - q))
    return best


def edge_bite(z, flakes, side):
    """Mordida del filo: cada lasca que llega al filo se lleva un poco de borde."""
    bite = 0.0
    for f in flakes:
        if f["side"] != side or f["into"] > 0.5:
            continue
        zc = BLADE_Z0 + f["t"] * BLADE_LEN
        bite = max(bite, f["wid"] * 0.32 * math.exp(-((z - zc) / (f["wid"] * 0.55)) ** 2))
    return bite


def blade(parent):
    rows, cols = 180, 40
    faces_flakes = [make_flakes(3), make_flakes(8)]
    bm = bmesh.new()
    colors = []
    grids = []
    for face, sign in enumerate((1, -1)):
        flakes = faces_flakes[face]
        grid = []
        for i in range(rows + 1):
            t = i / rows
            z = BLADE_Z0 + t * BLADE_LEN
            w = half_width(t)
            th = half_thick(t)
            row = []
            for j in range(cols + 1):
                s = -1.0 + 2.0 * j / cols
                bite = max(edge_bite(z, faces_flakes[0], 1 if s > 0 else -1),
                           edge_bite(z, faces_flakes[1], 1 if s > 0 else -1)) if abs(s) > 0.999 else 0.0
                x = s * max(w - bite, 0.0)
                h = th * max(0.0, 1.0 - abs(s) ** 1.7) ** 0.7
                c = carve(x, z, flakes) if t < 0.995 else 0.0
                y = sign * max(h - c, h * 0.3)
                row.append(bm.verts.new((x, y, z)))
                # Las crestas entre lascas quedan claras; el fondo de las lascas, más oscuro.
                colors.append(1.0 - min(c / 0.0016, 1.0) * 0.45)
            grid.append(row)
        grids.append(grid)
    for face, grid in enumerate(grids):
        for i in range(rows):
            for j in range(cols):
                quad = (grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j])
                bm.faces.new(quad if face == 0 else tuple(reversed(quad)))
    # Base de la hoja (dentro de la guarda).
    bm.faces.new([grids[0][0][j] for j in range(cols + 1)] + [grids[1][0][j] for j in range(cols - 1, 0, -1)])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # remove_doubles reindexa: recalcular colores por posición del índice viejo no es posible;
    # se vuelven a tomar por vértice (gris según qué tan tallado está).
    bm.verts.ensure_lookup_table()
    cols_out = []
    for v in bm.verts:
        t = (v.co.z - BLADE_Z0) / BLADE_LEN
        h = half_thick(max(min(t, 1.0), 0.0))
        cols_out.append(0.55 + 0.45 * min(abs(v.co.y) / max(h, 1e-5), 1.0))
    return finish("blade", bm, "obsidian", cols_out, parent=parent)


# ------------------------------------------------------------------ cristales

def crystal_prism(name, base, axis, length, rx, ry, tip, material, parent, sides=6, jitter=0.15, seed=0):
    """Prisma facetado con punta (sides caras), con irregularidad en cada vértice."""
    r = random.Random(seed)
    axis = axis.normalized()
    side_v = axis.cross(Vector((0, 1, 0)) if abs(axis.y) < 0.9 else Vector((1, 0, 0))).normalized()
    up_v = axis.cross(side_v).normalized()
    bm = bmesh.new()
    rings = []
    for k, (h, scale) in enumerate(((0.0, 0.9), (length * 0.08, 1.0), (length - tip, 0.95))):
        ring = []
        for i in range(sides):
            a = 2 * math.pi * i / sides + 0.3
            jx = 1.0 + r.uniform(-jitter, jitter)
            p = base + axis * (h + r.uniform(-0.1, 0.1) * tip * (k == 2)) \
                + side_v * math.cos(a) * rx * scale * jx + up_v * math.sin(a) * ry * scale * jx
            ring.append(bm.verts.new(p))
        rings.append(ring)
    apex = bm.verts.new(base + axis * length + side_v * r.uniform(-0.2, 0.2) * rx)
    for a, b in zip(rings, rings[1:]):
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((a[i], a[j], b[j], b[i]))
    for i in range(sides):
        bm.faces.new((rings[-1][i], rings[-1][(i + 1) % sides], apex))
    bm.faces.new(list(reversed(rings[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return finish(name, bm, material, smooth=False, parent=parent)


# ------------------------------------------------------------------ armado

root = bpy.data.objects.new("dagger_crystal", None)
bpy.context.scene.collection.objects.link(root)

blade(root)
# Cristal celeste incrustado: más grueso que la hoja, se ve en las dos caras.
crystal_prism("crystal", Vector((0.003, 0.0, BLADE_Z0 + 0.006)), Vector((-0.05, 0.0, 1.0)), 0.12,
              0.0095, 0.0078, 0.028, "crystal", root, sides=7, jitter=0.18, seed=5)

def silver_hammered(cell=0.0035, depth=0.00035, seed=1):
    def d(a, z, r):
        h = hammer(a * r, z, cell, seed)
        return -h * depth, 1.0 - 0.35 * h
    return d


def silver_runes(z0, z1, cells, seed, depth=0.0005):
    def d(a, z, r):
        v = (z - z0) / (z1 - z0)
        h = hammer(a * r, z, 0.0035, seed) * 0.00025
        if 0.12 < v < 0.88:
            g = rune_depth(a / (2 * math.pi), (v - 0.12) / 0.76, cells, seed)
            if g:
                return -depth * g - h, 0.35
        return -h, 1.0 - 0.3 * h / 0.00025
    return d


def rope(freq=48, pitch=900.0, amp=0.00045):
    def d(a, z, r):
        w = math.sin(freq * a + pitch * z)
        return amp * w, 0.6 + 0.4 * (w * 0.5 + 0.5)
    return d


# Guarda: disco ovalado con el canto grabado y las caras martilladas.
GZ0, GZ1 = 0.05, 0.062
lathe("guard_face", [(0.0, GZ0), (0.024, GZ0), (0.0262, GZ0 + 0.0015)] + [(0.0265, GZ0 + 0.0015 + k * 0.009 / 12) for k in range(13)]
      + [(0.0262, GZ1 - 0.0015), (0.024, GZ1), (0.0, GZ1)], "silver", root, segs=240,
      disp=lambda a, z, r: silver_runes(GZ0 + 0.0015, GZ1 - 0.0015, 16, 4)(a, z, r) if r > 0.026
      else silver_hammered(seed=2)(a, z, r), oval=0.72)

# Virola de arriba (entre mango y guarda) y anillos labrados.
lathe("ferrule_top", [(0.0118, 0.041)] + [(0.0138, 0.042 + k * 0.007 / 10) for k in range(11)] + [(0.0125, 0.05)],
      "silver", root, segs=160, disp=silver_hammered(seed=3))
lathe("bead_top", [(0.0128, 0.0395 + k * 0.0025 / 6) for k in range(7)], "silver", root, segs=160, disp=rope())

# Mango: tiras de cuero enrolladas en espiral, con un hueco entre vuelta y vuelta.
def leather(a, z, r):
    # Cada vuelta de la tira monta sobre la anterior: sube en rampa y cae en un escalón.
    u = (a / (2 * math.pi) + z / 0.0115) % 1.0
    band = min(u / 0.85, 1.0) if u < 0.92 else 0.0
    grain = hammer(a * r, z, 0.0012, 13) * 0.1
    return 0.0005 * band - 0.0002, 0.45 + 0.55 * band - grain

lathe("grip", [(0.0112, -0.044 + k * 0.083 / 120) for k in range(121)], "leather", root, segs=72, disp=leather)
for zc in (-0.008, -0.0035):
    lathe("filigree_%d" % int(zc * 1e4), [(0.0123, zc + k * 0.0035 / 8) for k in range(9)], "silver", root,
          segs=160, disp=rope(freq=56, pitch=1400.0, amp=0.0004))

# Virola de abajo y pomo con runas.
lathe("bead_bottom", [(0.0128, -0.047 + k * 0.0025 / 6) for k in range(7)], "silver", root, segs=160, disp=rope())
lathe("ferrule_bottom", [(0.0125, -0.0475)] + [(0.0142, -0.049 - k * 0.006 / 10) for k in range(11)]
      + [(0.0135, -0.0555)], "silver", root, segs=160, disp=silver_hammered(seed=6))
PZ0, PZ1 = -0.078, -0.056
lathe("pommel", [(0.0136, PZ1)] + [(0.0158, PZ1 - 0.001 - k * 0.019 / 14) for k in range(15)]
      + [(0.0148, PZ0 + 0.001), (0.011, PZ0), (0.0, PZ0)], "silver", root, segs=200,
      disp=silver_runes(PZ0 + 0.001, PZ1 - 0.001, 12, 9))

# Racimo de cristales negros saliendo del pomo.
cr = random.Random(21)
for k in range(7):
    ang = cr.uniform(0, 2 * math.pi)
    off = cr.uniform(0.0, 0.007) if k else 0.0
    tilt = cr.uniform(0.15, 0.55) if k else 0.05
    axis = Vector((math.cos(ang) * math.sin(tilt), math.sin(ang) * math.sin(tilt), -math.cos(tilt)))
    base = Vector((math.cos(ang) * off, math.sin(ang) * off, PZ0 + 0.002))
    length = cr.uniform(0.012, 0.02) if k else 0.024
    rad = cr.uniform(0.0026, 0.0042)
    crystal_prism("black_crystal_%d" % k, base, axis, length, rad, rad * 0.9, length * 0.35, "black_crystal", root,
                  sides=6, jitter=0.2, seed=40 + k)

# ------------------------------------------------------------------ exportar y vista previa

# Aristas vivas donde la superficie quiebra (crestas entre lascas, facetas, runas).
for c in root.children:
    c.data.set_sharp_from_angle(angle=math.radians(14))
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
for c in root.children_recursive:
    c.select_set(True)
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_yup=True,
                          export_vertex_color="ACTIVE")
print("EXPORTADO", OUT)

if PREVIEW:
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = 1600, 900
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.85, 0.86, 0.88, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    sc.world = world
    root.rotation_euler = (0, math.radians(90), math.radians(-12))
    root.location = (0.06, 0, 0)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.35
    # Luces de estudio: una caja de luz grande arriba y dos de recorte, para que las facetas brillen.
    for name, loc, size, power in (("key", (0.15, -0.25, 0.6), 0.6, 60.0), ("rim", (0.4, 0.4, 0.25), 0.3, 25.0),
                                    ("fill", (-0.3, -0.5, 0.1), 0.5, 12.0)):
        light = bpy.data.objects.new(name, bpy.data.lights.new(name, "AREA"))
        light.data.size = size
        light.data.energy = power
        light.location = loc
        light.rotation_euler = (Vector((0.15, 0.0, 0.0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(light)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.lens = 85
    for name, at, frm in (("", (0.165, 0.0, 0.0), (0.165, -1.05, 0.55)), ("_hoja", (0.27, 0.0, 0.0), (0.24, -0.34, 0.2))):
        cam.location = frm
        look = Vector(at) - cam.location
        cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.abspath(PREVIEW).replace(".png", name + ".png")
        bpy.ops.render.render(write_still=True)
    print("VISTA", PREVIEW)
