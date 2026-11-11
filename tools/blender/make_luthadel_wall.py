"""Genera las piezas de la muralla de Luthadel (G29): tramos de distinta altura (uno con almenas rotas, otro
remendado, otro con contrafuerte), torres redondas, cuadradas y una rota, y el portón (paso abovedado entre dos torres,
con rastrillo de hierro). Textura propia ("muralla", ver make_luthadel_textures.py).

Uso (desde la carpeta del proyecto):
  blender -b --factory-startup -P tools/blender/make_luthadel_wall.py -- assets/luthadel [carpeta para las fotos]

Deja assets/luthadel/muralla/*.gltf. Medidas: los tramos miden TRAMO m a lo largo de X y GROSOR de ancho; el frente
(Blender -Y = Godot +Z) es el lado de afuera de la ciudad, donde van los contrafuertes. El portón tiene el paso a lo
largo de Y (de afuera hacia adentro).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_luthadel_houses as houses  # noqa: E402
import make_luthadel_kit as kit  # noqa: E402

import bpy  # noqa: E402

TRAMO = 12.0
GROSOR = 4.0
Piece = houses.Piece


def merlons(p, y0, z, length, r, broken=0.0, m="muralla"):
    """Almenas en el borde de afuera (y0); `broken`: fracción que falta o está mordida."""
    n = int(length / 1.6)
    for k in range(n):
        x = -length / 2.0 + (k + 0.5) * length / n
        if r.random() < broken:
            if r.random() < 0.5:
                p.box((0.9, 0.7, 0.5), (x, y0, z + 0.25), m, rz=r.uniform(-0.2, 0.2))  # mordida
            continue
        p.box((0.95, 0.7, 1.3 + r.uniform(-0.15, 0.15)), (x, y0, z + 0.62), m)


def walk(p, z, length):
    """Camino de ronda: losas arriba y un pretil bajo del lado de adentro."""
    p.box((length, GROSOR - 0.2, 0.25), (0, 0, z - 0.1), "piedra_oscura")
    p.box((length, 0.45, 0.8), (0, GROSOR / 2.0 - 0.25, z + 0.35), "muralla")


def tramo(name, h, seed, broken=0.0, patch=False, buttress=False, lean=0.0):
    r = random.Random(seed)
    p = Piece(name)
    L = TRAMO + 0.4  # se pisan un poco con el de al lado
    # Base ataludada y lienzo.
    p.box((L, GROSOR + 1.4, 2.4), (0, -0.35, 1.2 - 0.05), "piedra_oscura")
    p.box((L, GROSOR + 0.6, 1.2), (0, -0.15, 2.9), "muralla", rx=0.0)
    p.box((L, GROSOR, h), (0, 0, h / 2.0), "muralla")
    p.box((L + 0.05, GROSOR + 0.3, 0.35), (0, -0.1, h - 0.05), "piedra_clara")  # cornisa
    walk(p, h + 0.1, L)
    merlons(p, -GROSOR / 2.0 + 0.3, h + 0.15, L, r, broken)
    # Hiladas de distinto tamaño y mechinales: que no parezca liso.
    for k in range(3):
        z = 4.0 + k * (h - 5.0) / 3.0 + r.uniform(-0.6, 0.6)
        p.box((L - 0.3, 0.2, 0.18), (0, -GROSOR / 2.0 - 0.06, z), "piedra_oscura")
    for k in range(r.randint(2, 4)):
        p.box((0.35, 0.47, 0.35), (r.uniform(-L / 2.0 + 1, L / 2.0 - 1), -GROSOR / 2.0 + 0.03, r.uniform(5.0, h - 2.0)), "hueco")
    for k in range(2):  # saeteras
        x = -L / 4.0 + k * L / 2.0 + r.uniform(-0.6, 0.6)
        p.box((0.22, 0.3, 1.4), (x, -GROSOR / 2.0 - 0.06, h - 2.4), "hueco")
    if patch:  # un remiendo de piedra más clara y más chica, con su borde desparejo
        cx, cz = r.uniform(-2.5, 2.5), r.uniform(4.0, h - 4.0)
        p.box((4.6, 0.6, 3.6), (cx, -GROSOR / 2.0 + 0.05, cz), "piedra_clara", ry=r.uniform(-0.05, 0.05))
        for k in range(5):
            p.box((r.uniform(0.6, 1.2), 0.8, r.uniform(0.4, 0.7)), (cx + r.uniform(-2.6, 2.6), -GROSOR / 2.0 + 0.12 + 0.03 * k, cz + r.choice((-1, 1)) * 1.9), "piedra")
    if buttress:  # contrafuertes de afuera, ataludados
        for x in (-L / 4.0, L / 4.0):
            p.box((1.6, 2.4, h * 0.7), (x, -GROSOR / 2.0 - 1.0, h * 0.35), "piedra_oscura")
            p.box((1.6, 1.8, 1.8), (x, -GROSOR / 2.0 - 0.7, h * 0.7 + 0.2), "piedra_oscura", rx=0.7)
    if lean:  # un tramo viejo que se vence: arriba, unas hiladas corridas
        p.box((L * 0.6, GROSOR, 2.2), (r.uniform(-2, 2), -lean, h - 1.4), "muralla")
    return p.finish()


def torre(name, kind, h, seed):
    r = random.Random(seed)
    p = Piece(name)
    if kind == "redonda":
        p.cyl(5.6, 5.6, 3.0, (0, 0, 0), "piedra_oscura", segs=12)
        p.cyl(5.0, 4.6, h, (0, 0, 0), "muralla", segs=12)
        p.cyl(5.3, 5.3, 0.4, (0, 0, h), "piedra_clara", segs=12)
        p.cyl(4.6, 5.4, 1.2, (0, 0, h - 1.2), "piedra_oscura", segs=12)  # matacán
        for k in range(12):
            a = math.tau * (k + 0.5) / 12.0
            if r.random() < 0.85:
                p.box((1.3, 0.7, 1.4), (5.0 * math.cos(a), 5.0 * math.sin(a), h + 1.1), "muralla", rz=a + math.pi / 2.0)
        if r.random() < 0.6:
            p.cyl(4.8, 0.0, 7.0, (0, 0, h + 0.4), "pizarra", segs=12)
            p.cyl(0.1, 0.0, 2.0, (0, 0, h + 7.2), "hierro", segs=4)
        else:
            p.cyl(4.7, 4.7, 0.2, (0, 0, h + 0.38), "piedra_oscura", segs=12)
        for z in (h * 0.4, h * 0.7):
            p.box((0.3, 0.5, 1.6), (0, -4.8, z), "hueco")
            p.box((0.3, 0.5, 1.6), (4.8, 0, z), "hueco", rz=math.pi / 2.0)
    elif kind == "cuadrada":
        p.box((9.0, 9.0, 2.6), (0, 0, 1.25), "piedra_oscura")
        p.box((8.2, 8.2, h), (0, 0, h / 2.0), "muralla")
        p.box((8.7, 8.7, 0.4), (0, 0, h), "piedra_clara")
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.box((1.2, 1.2, h - 1.0), (sx * 4.1, sy * 4.1, (h - 1.0) / 2.0), "piedra_oscura")
        for side in range(4):
            for k in range(5):
                x = -3.4 + k * 1.7
                xy = [(x, -4.0), (4.0, x), (x, 4.0), (-4.0, x)][side]
                if r.random() < 0.85:
                    p.box((0.95, 0.95, 1.3), (xy[0], xy[1], h + 0.85), "muralla")
        for z in (h * 0.45, h * 0.75):
            p.gothic_window(0, z + 0.3, -4.1, w=0.5, h=1.4, lit=r.random() < 0.4)
        if r.random() < 0.5:
            p.cyl(6.2, 0.0, 6.0, (0, 0, h + 0.27), "pizarra", segs=4, rz=math.pi / 4.0)
    else:  # rota: la mitad de arriba se cayó y quedan dientes y escombros
        p.cyl(5.6, 5.6, 3.0, (0, 0, 0), "piedra_oscura", segs=12)
        p.cyl(5.0, 4.8, h * 0.6, (0, 0, 0), "muralla", segs=12)
        for k in range(7):
            a = math.tau * k / 12.0 + 0.3
            p.box((2.3, 1.1, r.uniform(2.0, 6.0)), (4.4 * math.cos(a), 4.4 * math.sin(a), h * 0.6 + 1.0), "muralla", rz=a + math.pi / 2.0)
        for k in range(9):
            a = r.uniform(0, math.tau)
            p.box((r.uniform(0.8, 1.6),) * 3, (6.5 * math.cos(a) + r.uniform(-1, 1), 6.5 * math.sin(a), r.uniform(0.3, 0.55)), "muralla", rz=r.uniform(0, 3), rx=r.uniform(0, 0.5))
        p.box((3.0, 0.4, 3.0), (0, -4.9, h * 0.3), "madera", rx=0.05)  # una brecha tapiada con tablas
    return p.finish()


def porton(name, seed):
    """Portón: paso abovedado de 6 m de ancho entre dos torres, con rastrillo de hierro levantado, matacán y
    estandarte. El paso va a lo largo de Y; las torres a los costados (±X). Mide unos 24 m de punta a punta."""
    r = random.Random(seed)
    p = Piece(name)
    h, pw, ph = 17.0, 6.0, 8.0  # alto, ancho y alto del paso
    d = GROSOR + 4.0  # el portón es más grueso que la muralla
    side_w = 4.0
    for s in (-1, 1):  # macizos a los lados del paso
        x = s * (pw / 2.0 + side_w / 2.0)
        p.box((side_w, d, h), (x, 0, h / 2.0), "muralla")
    p.box((pw + 0.2, d, h - ph - 1.6), (0, 0, ph + 1.6 + (h - ph - 1.6) / 2.0), "muralla")  # sobre el arco
    for y in (-d / 2.0, d / 2.0):  # arcos apuntados de los dos lados
        dep = -1.0 if y < 0 else 1.0
        p.arch(0, y, ph - 0.1, pw + 0.6, m="piedra_clara", depth=dep)
        p.box((pw + 1.0, 0.4, 0.5), (0, y + dep * 0.1, ph + 2.2), "piedra_clara")
    p.box((pw, d - 0.2, 0.3), (0, 0, ph + 1.5), "piedra_oscura")  # bóveda
    p.box((pw - 0.4, 0.25, 3.2), (0, -d / 2.0 + 1.2, ph - 0.1), "hierro")  # rastrillo levantado
    for k in range(9):
        p.box((0.12, 0.3, 1.2), (-pw / 2.0 + 0.5 + k * (pw - 1.0) / 8.0, -d / 2.0 + 1.2, ph - 2.2), "hierro")
    p.box((pw + 1.2, d + 0.3, 0.4), (0, 0, h), "piedra_clara")
    walk(p, h + 0.3, pw + 2 * side_w)
    merlons(p, -d / 2.0 + 0.3, h + 0.25, pw + 2 * side_w, r, 0.1)
    p.box((pw + 2.0, 1.4, 1.2), (0, -d / 2.0 - 0.5, h - 1.0), "piedra_oscura")  # matacán sobre el paso
    for k in range(4):
        p.box((0.4, 1.2, 0.6), (-pw / 2.0 - 0.6 + k * (pw + 1.2) / 3.0, -d / 2.0 - 0.4, h - 1.9), "piedra_oscura", rx=0.6)
    for s in (-1, 1):  # torres del portón, redondas y más altas
        x = s * (pw / 2.0 + side_w + 2.4)
        p.cyl(4.6, 4.6, 2.6, (x, -1.0, 0), "piedra_oscura", segs=12)
        p.cyl(4.0, 3.7, h + 5.0, (x, -1.0, 0), "muralla", segs=12)
        p.cyl(4.3, 4.3, 0.4, (x, -1.0, h + 5.0), "piedra_clara", segs=12)
        for k in range(10):
            a = math.tau * (k + 0.5) / 10.0
            p.box((1.1, 0.6, 1.3), (x + 4.0 * math.cos(a), -1.0 + 4.0 * math.sin(a), h + 6.0), "muralla", rz=a + math.pi / 2.0)
        p.cyl(3.9, 0.0, 6.5, (x, -1.0, h + 5.4), "pizarra", segs=12)
        p.cyl(0.1, 0.0, 2.0, (x, -1.0, h + 11.8), "hierro", segs=4)
        for z in (5.0, 11.0, h + 2.0):
            p.box((0.3, 0.5, 1.6), (x, -1.0 - 3.85, z), "hueco")
        p.box((0.3, 0.14, 0.9), (x, -1.0 - 3.9, h - 3.0), "luz")
    p.box((2.4, 0.06, 5.5), (0, -d / 2.0 - 1.25, h - 4.8), "lona")  # estandarte sobre el paso
    p.box((0.8, 0.07, 0.8), (0, -d / 2.0 - 1.3, h - 3.6), "hierro", ry=math.pi / 4.0)
    for s in (-1, 1):  # faroles a los lados del paso
        houses.lantern(p, s * (pw / 2.0 + 0.6), -d / 2.0 - 0.1, 4.2)
    return p.finish()


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    base = os.path.abspath(args[0])
    kit.TEX_DIR = os.path.join(base, "tex")
    out_dir = os.path.join(base, "muralla")
    os.makedirs(out_dir, exist_ok=True)
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    obs = [
        tramo("TramoAlto", 15.0, 1, broken=0.1),
        tramo("TramoBajo", 11.5, 2, broken=0.2),
        tramo("TramoRoto", 13.0, 3, broken=0.55),
        tramo("TramoRemendado", 14.0, 4, broken=0.15, patch=True),
        tramo("TramoContrafuerte", 16.0, 5, broken=0.05, buttress=True),
        tramo("TramoViejo", 12.5, 6, broken=0.35, patch=True, lean=0.4),
        torre("TorreRedonda", "redonda", 20.0, 7),
        torre("TorreCuadrada", "cuadrada", 22.0, 8),
        torre("TorreRota", "rota", 18.0, 9),
        porton("Porton", 10),
    ]
    for ob in obs:
        houses.export(ob, out_dir)
    if len(args) > 1:
        os.makedirs(args[1], exist_ok=True)
        kit.stage()
        houses.sheet(obs[:6], os.path.join(args[1], "muralla_tramos.png"), cols=6, gap=14.0)
        houses.sheet(obs[6:], os.path.join(args[1], "muralla_torres.png"), cols=4, gap=26.0)


if __name__ == "__main__":
    main()
