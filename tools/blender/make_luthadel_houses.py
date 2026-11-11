"""Genera las casas modulares de Luthadel (G28): 24 para los barrios buenos (CasaB01..24) y 24 para los barrios skaa
(CasaS01..24). Cada casa sale de combinar módulos: cuerpo (frente, fondo, pisos), material de la planta baja y de los
pisos altos, techo, puertas, ventanas y uno o dos rasgos (torrecilla, torre lateral, mirador, balcón, frontón
escalonado, arcada o tienda, ala; en las skaa: escalera exterior, cobertizo, ropa tendida, tienda tapiada, piso
torcido, pescante). Se parecen entre sí pero ninguna es igual. Usa las piezas y texturas de make_luthadel_kit.py.

Uso (desde la carpeta del proyecto, con las texturas ya generadas en assets/luthadel/tex):
  blender -b --factory-startup -P tools/blender/make_luthadel_houses.py -- assets/luthadel [carpeta para las fotos]

Deja assets/luthadel/casas/Casa*.gltf (1 unidad = 1 m, el frente hacia -Y de Blender = +Z del juego).
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_luthadel_kit as kit  # noqa: E402

COUNT = 24


class Piece(kit.Piece):
    """Como la de las piezas sueltas, pero cada caja crece distinto sin engordar las partes finas (rejas, tablas)."""

    def box(self, size, center, m, rz=0.0, rx=0.0, ry=0.0):
        verts = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        self._n += 1
        g = min(0.004 + 0.0026 * ((self._n * 7) % 23), 0.5 * min(size) + 0.004)
        size = (size[0] + g, size[1] + g, size[2] + g)
        mat = Matrix.Translation(center) @ Euler((rx, ry, rz)).to_matrix().to_4x4() @ Matrix.Diagonal((*size, 1.0))
        bmesh.ops.transform(self.bm, matrix=mat, verts=verts)
        self._paint(verts, m)

    # Puerta y ventanas propias: como las de kit, pero sin dos partes con la misma medida (herrajes más angostos
    # que la hoja, parteluces más cortos que el vidrio) y con las bases escalonadas bajo el piso, para que ninguna
    # cara quede a ras de otra cuando el crecimiento de dos partes coincide.
    def door(self, x, y, w=1.1, h=2.1, arch=False, depth=-1.0):
        self.box((w + 0.36, 0.22, h + 0.3), (x, y + depth * 0.04, h / 2.0 + 0.05), "piedra_clara")
        self.box((w, 0.2, h + 0.2), (x, y + depth * 0.1, h / 2.0 - 0.1), "madera")
        for k in range(3):
            self.box((w - 0.1, 0.04, 0.05), (x, y + depth * 0.215, 0.35 + k * 0.7), "hierro")
        self.box((0.09, 0.07, 0.09), (x + w * 0.32, y + depth * 0.255, h * 0.5), "hierro")
        if arch:
            self.arch(x, y, h + 0.12, w + 0.3, depth=depth)
        self.box((w + 0.9, 0.7, 0.46), (x, y + depth * 0.35, -0.07), "piedra_clara")  # umbral

    def window(self, x, z, y, w=0.8, h=1.2, lit=True, shutters=True, depth=-1.0):
        self.box((w + 0.22, 0.12, h + 0.22), (x, y + depth * 0.03, z), "madera")
        self.box((w, 0.12, h), (x, y + depth * 0.07, z), "luz" if lit else "hueco")
        self.box((0.06, 0.04, h - 0.06), (x, y + depth * 0.15, z), "madera")
        self.box((w - 0.06, 0.04, 0.06), (x, y + depth * 0.165, z + h * 0.12), "madera")
        self.box((w + 0.4, 0.24, 0.1), (x, y + depth * 0.105, z - h / 2.0 - 0.14), "piedra_clara")
        self.box((w + 0.3, 0.2, 0.05), (x, y + depth * 0.1, z - h / 2.0 - 0.062), "ceniza")
        if shutters:
            for s in (-1, 1):
                self.box((0.34, 0.05, h + 0.1), (x + s * (w / 2.0 + 0.3), y + depth * 0.115, z), "madera_clara")

    def gothic_window(self, x, z, y, w=0.7, h=2.0, lit=True, depth=-1.0):
        self.box((w + 0.26, 0.14, h + 0.2), (x, y + depth * 0.03, z), "piedra_clara")
        self.box((w, 0.13, h), (x, y + depth * 0.075, z), "luz" if lit else "hueco")
        self.box((0.06, 0.05, h - 0.06), (x, y + depth * 0.16, z), "hierro")
        self.box((w - 0.06, 0.05, 0.06), (x, y + depth * 0.172, z + h * 0.2), "hierro")
        self.arch(x, y + depth * 0.02, z + h / 2.0, w + 0.3, depth=depth)
        self.box((w + 0.44, 0.3, 0.1), (x, y + depth * 0.11, z - h / 2.0 - 0.13), "piedra_clara")
        self.box((w + 0.34, 0.24, 0.05), (x, y + depth * 0.115, z - h / 2.0 - 0.06), "ceniza")

    def simple_window(self, x, z, y, w=0.8, h=1.2, lit=False, depth=-1.0, boarded=False):
        """Ventana barata: marco, hoja y alféizar (para costados, fondos y casas pobres)."""
        self.box((w + 0.2, 0.1, h + 0.2), (x, y + depth * 0.03, z), "madera")
        self.box((w, 0.1, h), (x, y + depth * 0.06, z), "luz" if lit else "hueco")
        self.box((w + 0.3, 0.2, 0.08), (x, y + depth * 0.12, z - h / 2.0 - 0.12), "piedra_clara")
        if boarded:
            for k in (-1, 1):
                self.box((w + 0.3, 0.05, 0.16), (x, y + depth * 0.13, z + k * h * 0.2), "madera_clara", ry=0.12 * k)

    def side_window(self, x, y, z, w=0.7, h=1.1, lit=False):
        """Ventana en una pared de costado (x = cara de la pared)."""
        s = 1.0 if x > 0 else -1.0
        self.box((0.1, w + 0.2, h + 0.2), (x + s * 0.03, y, z), "madera")
        self.box((0.1, w, h), (x + s * 0.06, y, z), "luz" if lit else "hueco")


def spread(n, w, margin=1.3):
    """n posiciones repartidas a lo ancho."""
    if n == 1:
        return [0.0]
    span = w - 2.0 * margin
    return [-span / 2.0 + span * k / (n - 1) for k in range(n)]


def gable_wall(p, w, y, z, h, m):
    """El hastial: la pared triangular bajo un techo cuya cumbrera va hacia el fondo."""
    p.gable(w - 0.1, 0.3, h * 0.97, (0, y, z + 0.012 + 0.004 * (y > 0)), m, over=0.0)  # no a ras de la base del techo


def roof(p, w, d, cy, top, kind, mat, wall, dormers, r):
    """Techo a dos aguas: 'front' (el hastial da a la calle) o 'side' (la cumbrera va paralela a la calle)."""
    if kind == "front":
        h = max(w * 0.56, 2.6)
        p.gable(w, d, h, (0, cy, top), mat, over=0.35)
        gable_wall(p, w, cy - d / 2.0 + 0.1, top, h, wall)
        gable_wall(p, w, cy + d / 2.0 - 0.1, top, h, wall)
        kit.ash_ridge(p, d, top + h, over=0.35)
        return h, "y"
    h = max(d * 0.6, 2.6)
    p.gable(w, d, h, (0, cy, top), mat, over=0.3, along="x")
    kit.ash_ridge(p, w, top + h, along="x", over=0.3)
    for x in spread(dormers, w, 2.2) if dormers else []:
        fy = cy - d / 2.0
        p.box((1.3, 1.5, 1.25), (x, fy + 1.0, top + 0.72), wall)
        p.simple_window(x, top + 0.8, fy + 0.25, w=0.6, h=0.7, lit=r.random() < 0.4)
        p.gable(1.3, 1.5, 0.75, (x, fy + 1.0, top + 1.34), mat, over=0.15)
    return h, "x"


# ---------------------------------------------------------------- Rasgos de los barrios buenos

def turret(p, x, y, z0, top):
    """Torrecilla en la esquina: ménsula, fuste de piedra, chapitel de pizarra y una saetera con luz."""
    p.cyl(1.05, 0.5, 1.1, (x, y, z0 - 1.1), "piedra_oscura", segs=8)
    p.cyl(1.05, 1.05, top + 1.6 - z0, (x, y, z0), "piedra_oscura", segs=8)
    p.cyl(1.25, 1.25, 0.28, (x, y, top + 1.6), "piedra_clara", segs=8)
    p.cyl(1.3, 0.0, 3.8, (x, y, top + 1.88), "pizarra", segs=8)
    p.cyl(0.07, 0.0, 1.3, (x, y, top + 5.4), "hierro", segs=4)
    p.box((0.3, 0.16, 0.9), (x, y - 1.0, (z0 + top) / 2.0 + 0.8), "luz")


def side_tower(p, x, y, top, wall, r):
    """Torre lateral cuadrada, más alta que la casa, con techo en punta."""
    h = top + 4.0
    p.box((3.4, 3.4, h + 0.06), (x, y, h / 2.0 - 0.03), wall)
    p.box((3.7, 3.7, 0.5), (x, y, 0.25), "piedra_oscura")
    for z in (top, h):
        p.box((3.65, 3.65, 0.24), (x, y, z), "piedra_clara")
    p.cyl(2.7, 0.0, 4.6, (x, y, h + 0.12), "pizarra", segs=4, rz=math.pi / 4.0)
    p.cyl(0.08, 0.0, 1.4, (x, y, h + 4.4), "hierro", segs=4)
    for k, z in enumerate((2.2, top - 1.6, top + 2.0)):
        p.gothic_window(x, z, y - 1.7, w=0.55, h=1.6, lit=k != 1 or r.random() < 0.5)


def oriel(p, x, y, z, r):
    """Mirador: un cuerpo de madera y vidrio que sale del primer piso, sobre canes, con su tejadillo."""
    p.box((2.4, 1.0, 2.4), (x, y - 0.5, z), "madera")
    for dx in (-0.6, 0.6):
        p.box((0.8, 0.1, 1.5), (dx + x, y - 1.02, z + 0.1), "luz" if r.random() < 0.7 else "hueco")
    p.box((0.08, 0.14, 1.5), (x, y - 1.04, z + 0.1), "madera_clara")
    for dx in (-0.9, 0.9):
        p.box((0.22, 0.8, 0.5), (x + dx, y - 0.45, z - 1.4), "madera", rx=0.5)
    p.box((2.7, 1.3, 0.12), (x, y - 0.6, z + 1.32), "pizarra", rx=0.25)
    p.box((2.6, 0.3, 0.05), (x, y - 1.05, z + 1.22), "ceniza", rx=0.25)


def balcony(p, x, y, z, w=3.6):
    """Balcón de piedra con reja de hierro y una puerta ventana."""
    p.box((w, 1.2, 0.2), (x, y - 0.55, z), "piedra_clara")
    for dx in (-w / 2.0 + 0.4, w / 2.0 - 0.4):
        p.box((0.36, 0.8, 0.46), (x + dx, y - 0.35, z - 0.34), "piedra_oscura", rx=0.5)
    p.box((w, 0.06, 0.07), (x, y - 1.1, z + 1.05), "hierro")
    n = int(w / 0.45)
    for k in range(n + 1):
        p.box((0.05, 0.03, 0.95), (x - w / 2.0 + w * k / n, y - 1.1, z + 0.57), "hierro")
    for s in (-1, 1):
        p.box((0.06, 1.0, 0.07), (x + s * w / 2.0, y - 0.54, z + 1.05), "hierro")
    p.box((1.1, 0.12, 2.1), (x, y + 0.02, z + 1.15), "hueco")
    p.box((1.3, 0.12, 0.14), (x, y - 0.02, z + 2.26), "piedra_clara")


def stepped_gable(p, w, y, top, h):
    """Frontón escalonado de piedra por delante del techo, con remate de hierro."""
    steps = 4
    for k in range(steps):
        sw = w - k * (w / (steps + 0.6))
        sh = (h + 0.8) / steps
        p.box((sw, 0.5, sh), (0, y + 0.2, top + sh / 2.0 + k * sh), "piedra")
        p.box((sw + 0.16, 0.6, 0.09), (0, y + 0.2, top + (k + 1) * sh), "ceniza")
    p.cyl(0.14, 0.0, 1.5, (0, y + 0.2, top + h + 0.8), "hierro", segs=4)


def arcade(p, w, y, gh, r):
    """Planta baja con arcos apuntados entre pilares: uno es la entrada, los otros dan luz."""
    n = 2 if w < 9.0 else 3
    xs = spread(n, w, 1.9)
    door = r.randrange(n)
    for k, x in enumerate(xs):
        p.box((1.9, 0.5, gh - 0.9), (x, y + 0.14, (gh - 0.9) / 2.0 + 0.06), "hueco")
        p.arch(x, y - 0.08, gh - 0.9, 2.2)
        if k == door:
            p.box((1.4, 0.12, gh - 1.3), (x, y + 0.32, (gh - 1.3) / 2.0 + 0.08), "madera")
        else:
            p.box((1.2, 0.1, 1.3), (x, y + 0.32, 1.8), "luz" if r.random() < 0.6 else "hueco")
    for x in spread(n + 1, w, 0.45):
        p.box((0.7, 0.7, gh - 0.1), (x, y - 0.18, (gh - 0.1) / 2.0 + 0.06), "piedra_oscura")


def shop(p, x, y, gh, r):
    """Tienda: vidriera con mostrador y toldo de lona."""
    p.box((3.0, 0.2, 1.7), (x, y - 0.02, 1.95), "hueco")
    p.box((2.6, 0.12, 1.3), (x, y - 0.07, 2.0), "luz")
    p.box((3.3, 0.6, 0.14), (x, y - 0.3, 1.08), "madera_clara")
    p.box((3.3, 0.2, 0.9), (x, y - 0.1, 0.6), "madera")
    mat = "lona" if r.random() < 0.4 else "lona_gris"
    p.box((3.5, 1.8, 0.06), (x, y - 0.95, gh - 0.25), mat, rx=0.3)
    for dx in (-1.65, 1.65):
        p.box((0.09, 0.09, gh - 0.75), (x + dx, y - 1.7, (gh - 0.75) / 2.0 + 0.04), "madera")
    p.box((0.06, 0.8, 0.06), (x + 2.0, y - 0.4, gh - 0.3), "hierro")
    p.box((0.05, 0.6, 0.5), (x + 2.0, y - 0.55, gh - 0.66), "madera_clara")


def wing(p, x, d, gh, wall, mat, r):
    """Ala lateral más baja, con su propio techo y una puerta de servicio."""
    ww, wd, wh = 3.6, d * 0.62, gh + 1.4
    y = d / 2.0 - wd / 2.0
    p.box((ww, wd, wh + 0.06), (x, y, wh / 2.0 - 0.03), wall)
    p.box((ww + 0.2, wd + 0.2, 0.4), (x, y, 0.2), "piedra_oscura")
    s = 1.0 if x > 0 else -1.0
    hw, hd = ww / 2.0 + 0.2, wd / 2.0 + 0.25  # techo a un agua hacia afuera
    p.box((ww + 0.5, wd + 0.5, 0.14), (x, y, wh + 0.75), mat, ry=s * 0.36)
    p.box((0.2, wd, 1.3), (x - s * (ww / 2.0 - 0.1), y, wh + 0.6), wall)
    p.simple_window(x, 1.7, y - wd / 2.0, lit=r.random() < 0.5)
    p.side_window(x + s * ww / 2.0, y, gh + 0.4, lit=r.random() < 0.4)
    return hw, hd


def lantern(p, x, y, z):
    p.box((0.07, 0.5, 0.07), (x, y - 0.28, z + 0.3), "hierro")
    p.box((0.26, 0.26, 0.36), (x, y - 0.5, z), "luz")
    p.box((0.34, 0.34, 0.06), (x, y - 0.5, z + 0.22), "hierro")
    p.box((0.34, 0.34, 0.06), (x, y - 0.5, z - 0.2), "hierro")


# ---------------------------------------------------------------- Rasgos de las casas skaa

def outside_stairs(p, w, d, gh, r):
    """Escalera de madera por el costado hasta una galería en el primer piso."""
    s = 1.0 if r.random() < 0.5 else -1.0
    x = s * (w / 2.0 + 0.6)
    n = 8
    for k in range(n):
        p.box((1.0, 0.36, 0.1), (x, -d / 2.0 + 0.6 + k * 0.42, 0.25 + k * (gh - 0.2) / n), "madera_clara")
    p.box((0.1, n * 0.44, 0.14), (x + s * 0.5, -d / 2.0 + 0.5 + n * 0.21, gh / 2.0 + 0.2), "madera", rx=-math.atan2(gh - 0.2, n * 0.42))
    p.box((1.3, d * 0.45, 0.12), (x + s * 0.1, d * 0.2, gh + 0.05), "madera_clara")  # galería
    for y in (d * 0.0, d * 0.2, d * 0.4):
        p.box((0.1, 0.1, gh + 1.0), (x + s * 0.65, y, (gh + 1.0) / 2.0 + 0.02), "madera")
    p.box((0.08, d * 0.45, 0.08), (x + s * 0.65, d * 0.2, gh + 1.0), "madera")
    p.box((0.12, 0.9, 1.9), (s * (w / 2.0 + 0.04), d * 0.2, gh + 1.05), "hueco")


def lean_to(p, w, d, r):
    """Cobertizo de tablas contra el costado, con un barril y leña."""
    s = 1.0 if r.random() < 0.5 else -1.0
    x = s * (w / 2.0 + 1.1)
    p.box((2.2, d * 0.5, 2.0), (x, d * 0.15, 1.0), "madera")
    p.box((2.6, d * 0.5 + 0.4, 0.1), (x, d * 0.15, 2.25), "madera_clara", ry=s * 0.28)
    p.box((0.12, 0.9, 1.6), (x, d * 0.15 - d * 0.25 - 0.02, 0.85), "hueco", rz=math.pi / 2.0)
    p.cyl(0.3, 0.3, 0.8, (x + s * 0.4, -d * 0.2, 0.0), "madera", segs=8)
    for k in range(3):
        p.box((0.9, 0.16, 0.16), (x - s * 0.3, -d * 0.25, 0.1 + k * 0.17), "madera_clara", rz=0.1 * k)


def laundry(p, w, y, z, r):
    """Ropa tendida de la fachada a un poste en la calle."""
    x = r.choice((-1, 1)) * (w / 2.0 - 0.6)
    p.box((0.12, 0.12, z + 0.2), (x, y - 3.4, (z + 0.2) / 2.0), "madera")
    p.box((0.03, 3.4, 0.03), (x, y - 1.7, z), "cuerda")
    for k in range(4):
        p.box((0.05, 0.55, 0.6 + 0.2 * (k % 2)), (x, y - 0.6 - k * 0.72, z - 0.36 - 0.1 * (k % 2)), "lona_gris" if k != 2 else "lona")


def boarded_shop(p, x, y, gh):
    """Tienda tapiada: el hueco con tablas cruzadas y un resto de toldo."""
    p.box((2.4, 0.16, 1.6), (x, y - 0.02, 1.7), "hueco")
    for k in range(4):
        p.box((2.6, 0.05, 0.26), (x, y - 0.12, 1.1 + k * 0.4), "madera_clara" if k % 2 else "madera", ry=0.05 * (k - 1.5))
    p.box((2.7, 0.07, 0.2), (x, y - 0.16, 1.75), "madera", ry=0.55)
    p.box((2.0, 0.9, 0.05), (x - 0.3, y - 0.45, gh - 0.3), "lona_gris", rx=0.45)


def hoist(p, y, z):
    """Pescante: una viga que sale bajo el hastial, con soga y un bulto colgando."""
    p.box((0.16, 1.8, 0.16), (0, y - 0.8, z), "madera")
    p.box((0.04, 0.04, 1.7), (0, y - 1.5, z - 0.85), "cuerda")
    p.box((0.6, 0.5, 0.5), (0, y - 1.5, z - 1.9), "lona_gris", rz=0.3)


def roof_patches(p, w, cy, top, h, axis, d, r):
    """Remiendos de tabla en el techo."""
    for k in range(3):
        s = 1.0 if k % 2 == 0 else -1.0
        t = r.uniform(0.3, 0.7)
        if axis == "y":
            half = w / 2.0 + 0.35
            a = math.atan2(h, half)
            p.box((1.3, 1.1, 0.06), (s * half * (1 - t), cy + r.uniform(-d * 0.3, d * 0.3), top + h * t + 0.07 + 0.03 * k), "madera_clara", ry=s * a)
        else:
            half = d / 2.0 + 0.3
            a = math.atan2(h, half)
            p.box((1.1, 1.3, 0.06), (r.uniform(-w * 0.3, w * 0.3), cy + s * half * (1 - t), top + h * t + 0.07 + 0.03 * k), "madera_clara", rx=-s * a)


# ---------------------------------------------------------------- Las casas

def casa_buena(i):
    """Barrios buenos: piedra, ladrillo o entramado prolijo, ventanas con luz y un rasgo que la distingue."""
    r = random.Random(4100 + i)
    p = Piece("CasaB%02d" % (i + 1))
    w = (7.6, 8.6, 9.6, 11.2)[i % 4]
    d = (7.6, 8.6, 9.4)[(i // 2) % 3]
    floors = 2 + (1 if i % 3 else 0) + (1 if i % 8 == 5 else 0)
    gh, fh = 3.5, 3.2
    ground = ("piedra", "ladrillo", "piedra_oscura")[i % 3]
    upper = ("timber", "piedra", "ladrillo", "timber", "piedra")[i % 5]
    wall = {"timber": "revoque", "piedra": "piedra", "ladrillo": "ladrillo"}[upper]
    feature = i % 6
    extra = (i // 6) % 4
    kind = "front" if feature == 4 or i % 3 == 0 else "side"
    mat = "teja" if i % 4 == 1 else "pizarra"
    jet = 0.3 if upper == "timber" else 0.0
    top = gh + (floors - 1) * fh
    fy = -d / 2.0
    fu = fy - jet
    # Cuerpo.
    p.box((w, d, gh + 0.06), (0, 0, gh / 2.0 - 0.03), ground)
    p.box((w + 0.24, d + 0.24, 0.5), (0, 0, 0.25), "piedra_oscura")
    p.box((w + jet, d + jet, top - gh), (0, -jet / 2.0, (gh + top) / 2.0), wall)
    if upper == "timber":
        kit.timber_front(p, w + jet, fu, gh, top, floors - 1)
    else:
        for k in range(floors):
            p.box((w + 0.22, d + 0.22, 0.2), (0, 0, gh + k * fh), "piedra_clara")
    # Ventanas de los pisos altos.
    cols = 2 if w < 8.0 else (3 if w < 10.5 else 4)
    xs = spread(cols, w, 1.5)
    skip = 0.0 if feature in (2, 3) and cols % 2 == 1 else None  # el mirador o el balcón van al medio
    for f in range(1, floors):
        z = gh + (f - 0.5) * fh + 0.1
        for x in xs:
            if f == 1 and (skip == x or (feature in (2, 3) and cols % 2 == 0 and abs(x) < 2.0)):
                continue
            lit = r.random() < 0.45
            if upper == "piedra":
                p.gothic_window(x, z, fu, lit=lit, h=1.8)
            else:
                p.window(x, z, fu, lit=lit, shutters=upper == "timber")
        for sx in (-1, 1):
            p.side_window(sx * (w + jet) / 2.0, r.uniform(-1.5, 1.5), z, lit=r.random() < 0.25)
    # Planta baja.
    if feature == 5 and i % 2 == 0:
        arcade(p, w, fy, gh, r)
    else:
        dx = xs[0] if cols > 2 else -w / 4.0
        p.door(dx, fy, w=1.25, h=2.4, arch=upper != "timber")
        if feature == 5:
            shop(p, w / 4.0, fy, gh, r)
        else:
            for x in xs[1:] if cols > 2 else [w / 4.0]:
                p.window(x, 1.9, fy, lit=r.random() < 0.5, shutters=False, w=0.9)
        if extra == 2:
            lantern(p, dx + 1.1, fy, 2.7)
            p.box((2.4, 1.1, 0.3), (dx, fy - 0.85, 0.12), "piedra_clara")  # escalón, más alto que el umbral
    # Techo.
    cy = -jet / 2.0
    h, axis = roof(p, w + jet, d + jet, cy, top, kind, mat, wall, (0 if feature == 0 else 1 + i % 3), r)
    kit.chimney(p, r.choice((-1, 1)) * w * 0.28, d * 0.2, top + h * 0.35, h * 0.75 + 1.0)
    if extra == 1:
        kit.chimney(p, 0.0, -d * 0.1, top + h * 0.5, h * 0.6 + 1.0)
    # Rasgos.
    if feature == 0:
        turret(p, r.choice((-1, 1)) * (w + jet) / 2.0, fu + 0.15, gh + 0.4, top)
    elif feature == 1:
        side_tower(p, r.choice((-1, 1)) * (w / 2.0 + 1.3), d / 2.0 - 1.9, top, ground, r)
    elif feature == 2:
        oriel(p, 0.0, fu, gh + fh * 0.5 + 0.1, r)
    elif feature == 3:
        balcony(p, 0.0, fu, gh + 0.12)
    elif feature == 4:
        stepped_gable(p, w + jet, fu, top, h)
    if extra == 3:
        wing(p, r.choice((-1, 1)) * (w / 2.0 + 1.7), d, gh, ground, mat, r)
    return p.finish()


def casa_skaa(i):
    """Barrios skaa: angostas, altas y remendadas; casi sin luz, con algo colgado o agregado."""
    r = random.Random(7300 + i)
    p = Piece("CasaS%02d" % (i + 1))
    w = (4.6, 5.2, 5.8, 6.6)[i % 4]
    d = (6.2, 7.0, 7.8)[(i // 2) % 3]
    floors = 2 + i % 3
    gh, fh = 2.9, 2.7
    ground = ("ladrillo", "piedra_oscura", "ladrillo", "madera")[i % 4]
    upper = ("timber", "ladrillo", "tablas")[i % 3]
    wall = {"timber": "revoque", "ladrillo": "ladrillo", "tablas": "madera"}[upper]
    feature = i % 6
    kind = "front" if i % 2 == 0 or feature == 5 else "side"
    mat = "pizarra" if i % 5 else "teja"
    jet = 0.35 if upper != "ladrillo" else 0.0
    top = gh + (floors - 1) * fh
    fy = -d / 2.0
    fu = fy - jet
    lean = 0.22 if feature == 4 else 0.0  # piso torcido: los de arriba, corridos de costado
    p.box((w, d, gh + 0.06), (0, 0, gh / 2.0 - 0.03), ground)
    p.box((w + 0.16, d + 0.16, 0.3), (0, 0, 0.15), "piedra_oscura")
    p.box((w + jet, d + jet, top - gh), (lean, -jet / 2.0, (gh + top) / 2.0), wall)
    if lean > 0.0:  # un puntal sostiene lo que vuela
        p.box((0.16, 0.16, gh * 0.75), (w / 2.0 + 0.3, 0.0, gh * 0.62), "madera", ry=-0.3)
    if upper == "timber":
        kit.timber_front(p, w + jet, fu, gh, top, floors - 1)
    if jet > 0.0:
        for x in spread(3, w, 0.5):  # canes
            p.box((0.18, 0.5, 0.26), (x, fy - 0.2, gh - 0.16), "madera")
    cols = 1 if w < 5.0 else 2
    for f in range(1, floors):
        z = gh + (f - 0.5) * fh
        for x in spread(cols, w, 1.25):
            p.simple_window(x, z, fu, w=0.75, h=1.0, lit=r.random() < 0.2, boarded=r.random() < 0.25)
        sx = r.choice((-1, 1))
        p.side_window(sx * (w + jet) / 2.0 + lean, r.uniform(-1.5, 1.5), z, w=0.6, h=0.9)
    dx = -w / 4.0 if cols == 2 else -w / 5.0
    p.door(dx, fy, w=1.0, h=2.0)
    if feature == 3:
        boarded_shop(p, w / 4.0 + 0.2, fy, gh)
    else:
        p.simple_window(w / 4.0, 1.6, fy, w=0.8, h=0.9, lit=r.random() < 0.25, boarded=r.random() < 0.3)
    cy = -jet / 2.0
    h, axis = roof(p, w + jet, d + jet, cy, top, kind, mat, wall, 0, r)
    roof_patches(p, w + jet, cy, top, h, axis, d + jet, r)
    kit.chimney(p, r.choice((-1, 1)) * w * 0.25, d * 0.2, top + h * 0.3, h * 0.8 + 0.9)
    if feature == 4:
        kit.chimney(p, 0.0, -d * 0.15, top + h * 0.45, h * 0.6 + 0.9)
    if feature == 0:
        outside_stairs(p, w, d, gh, r)
    elif feature == 1:
        lean_to(p, w, d, r)
    elif feature == 2:
        laundry(p, w, fu, gh + fh * 0.6, r)
    elif feature == 5:
        hoist(p, fu, top + h * 0.45)
    return p.finish()


def export(ob, out_dir):
    for o in bpy.context.scene.objects:
        o.select_set(o == ob)
    bpy.context.view_layer.objects.active = ob
    path = os.path.join(out_dir, ob.name + ".gltf")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLTF_SEPARATE", use_selection=True, export_apply=True,
                              export_keep_originals=True, export_tangents=True)
    tris = sum(len(f.vertices) - 2 for f in ob.data.polygons)
    print("CASA %s tris=%d dim=(%.1f, %.1f, %.1f)" % (ob.name, tris, *ob.dimensions))


def sheet(objs, path, cols=8, gap=16.0):
    """Foto de muestra: las casas en filas."""
    sc = bpy.context.scene
    rows = math.ceil(len(objs) / cols)
    for k, ob in enumerate(objs):
        ob.location = ((k % cols - (cols - 1) / 2.0) * gap, (k // cols - (rows - 1) / 2.0) * -gap * 1.25, 0)
        ob.hide_render = False
    for ob in sc.objects:
        if ob.type == "MESH" and ob not in objs and ob.name != "Piso":
            ob.hide_render = True
    cam = sc.camera
    pos, look = Vector((gap * 2.6, -gap * 5.2, gap * 4.4)), Vector((0, 0, 4.0))
    cam.location = pos
    cam.rotation_euler = (look - pos).to_track_quat("-Z", "Y").to_euler()
    cam.data.ortho_scale = cols * gap * 1.08
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    base = os.path.abspath(args[0])
    kit.TEX_DIR = os.path.join(base, "tex")
    out_dir = os.path.join(base, "casas")
    os.makedirs(out_dir, exist_ok=True)
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    good = [casa_buena(i) for i in range(COUNT)]
    skaa = [casa_skaa(i) for i in range(COUNT)]
    for ob in good + skaa:
        export(ob, out_dir)
    if len(args) > 1:
        os.makedirs(args[1], exist_ok=True)
        kit.stage()
        sheet(good, os.path.join(args[1], "casas_buenas.png"))
        sheet(skaa, os.path.join(args[1], "casas_skaa.png"), gap=12.0)


if __name__ == "__main__":
    main()
