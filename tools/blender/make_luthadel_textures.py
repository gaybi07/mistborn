"""Genera las texturas de las piezas propias de Luthadel (G27): sillar, ladrillo, pizarra, revoque, madera y lona, todas
tiznadas y con ceniza, repetibles sin costura. De cada una sale el color y el relieve (mapa de normales).

Uso (Python del sistema, con numpy y Pillow):
  python tools/blender/make_luthadel_textures.py assets/luthadel/tex

Después, tools/blender/make_luthadel_kit.py las usa en los modelos.
"""
import os
import sys

import numpy as np
from PIL import Image

N = 512
rng = np.random.default_rng(1877)


def noise(beta=1.6, seed=None):
    """Ruido repetible sin costura (espectro 1/f^beta), en 0..1."""
    r = np.random.default_rng(seed) if seed is not None else rng
    f = np.fft.fftfreq(N)[:, None] ** 2 + np.fft.fftfreq(N)[None, :] ** 2
    f[0, 0] = 1.0
    spec = (r.normal(size=(N, N)) + 1j * r.normal(size=(N, N))) / f ** (beta / 2.0)
    spec[0, 0] = 0.0
    out = np.real(np.fft.ifft2(spec))
    return (out - out.min()) / (out.max() - out.min())


def grid():
    y, x = np.mgrid[0:N, 0:N]
    return x / N, y / N


def cells(rows, cols, offset=0.5, joint=0.035, jitter=0.0):
    """Hiladas de bloques: devuelve (borde 0..1: 0 en la junta, id de cada bloque)."""
    u, v = grid()
    row = np.floor(v * rows)
    uu = u * cols + (row % 2) * offset
    if jitter > 0.0:
        uu = uu + (np.sin(row * 12.9898) * 43758.5453 % 1.0) * jitter
    col = np.floor(uu)
    fu, fv = uu - col, v * rows - row
    ju, jv = joint * cols / max(rows, 1), joint
    edge = np.minimum(np.minimum(fu, 1 - fu) / max(ju, 1e-6), np.minimum(fv, 1 - fv) / max(jv, 1e-6))
    ident = (np.sin(row * 127.1 + (col % cols) * 311.7) * 43758.5453) % 1.0
    return np.clip(edge, 0.0, 1.0), ident


def soot(height_bias=0.5):
    """Chorreado de hollín: manchas verticales, más arriba que abajo de cada repetición."""
    streak = noise(1.2)
    streak = np.repeat(streak[:8, :], N // 8, axis=0)  # estirado en vertical
    return np.clip(0.55 * noise(2.2) + 0.45 * streak, 0, 1) ** (1.0 + height_bias)


def save(name, color, height, out_dir, strength=2.0):
    """color: (N, N, 3) en 0..1; height: (N, N) en 0..1."""
    Image.fromarray((np.clip(color, 0, 1) * 255).astype(np.uint8)).save(os.path.join(out_dir, name + ".png"))
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
    nz = 1.0 / np.sqrt(dx * dx + dy * dy + 1.0)
    normal = np.stack([-dx * nz * 0.5 + 0.5, dy * nz * 0.5 + 0.5, nz * 0.5 + 0.5], axis=-1)
    Image.fromarray((normal * 255).astype(np.uint8)).save(os.path.join(out_dir, name + "_n.png"))
    print("TEXTURA", name)


def shade(base, value):
    """base: color (3,), value: (N, N) multiplicador."""
    return np.asarray(base)[None, None, :] * value[..., None]


def stone(name, out_dir, base, rows=6, cols=3):
    edge, ident = cells(rows, cols, joint=0.06, jitter=0.35)
    grain = noise(1.4)
    body = 0.78 + 0.3 * (ident - 0.5) + 0.22 * (grain - 0.5)
    color = shade(base, body)
    color *= (0.45 + 0.55 * edge ** 0.6)[..., None]  # juntas oscuras
    color *= (1.0 - 0.45 * soot())[..., None]
    ash = (noise(1.0) > 0.72) * (edge > 0.9) * 0.1  # motas de ceniza
    color += ash[..., None]
    save(name, color, edge * 0.7 + grain * 0.3, out_dir, 3.0)


def brick(name, out_dir, base):
    edge, ident = cells(16, 4, joint=0.09)
    grain = noise(1.0)
    hue = np.stack([1.0 + 0.25 * (ident - 0.5), 1.0 + 0.1 * (ident - 0.5), np.ones_like(ident)], axis=-1)
    color = shade(base, 0.75 + 0.35 * (ident - 0.5) + 0.25 * (grain - 0.5)) * hue
    mortar = np.asarray((0.2, 0.19, 0.18))[None, None, :]
    k = (edge ** 0.5)[..., None]
    color = color * k + mortar * (1 - k)
    color *= (1.0 - 0.55 * soot())[..., None]
    save(name, color, edge * 0.8 + grain * 0.2, out_dir, 3.5)


def slate(name, out_dir, base):
    """Pizarras o tejas en hiladas solapadas: cada una se oscurece hacia arriba (queda bajo la de arriba)."""
    u, v = grid()
    rows, cols = 10, 8
    row = np.floor(v * rows)
    uu = u * cols + (row % 2) * 0.5
    col = np.floor(uu)
    fu, fv = uu - col, v * rows - row
    ident = (np.sin(row * 127.1 + (col % cols) * 311.7) * 43758.5453) % 1.0
    gap = np.clip(np.minimum(fu, 1 - fu) / 0.05, 0, 1)
    lap = 0.55 + 0.45 * fv  # fv = 1 en el borde de abajo de la pizarra (el que se ve)
    color = shade(base, (0.8 + 0.3 * (ident - 0.5) + 0.2 * (noise(1.0) - 0.5)) * lap * (0.5 + 0.5 * gap))
    ash = np.clip((noise(2.0) - 0.45) * 2.5, 0, 1) * np.clip((fv - 0.6) * 3.0, 0, 1)  # ceniza en el borde
    color = color * (1 - 0.55 * ash[..., None]) + np.asarray((0.46, 0.45, 0.44))[None, None, :] * 0.55 * ash[..., None]
    save(name, color, fv * 0.8 + gap * 0.2, out_dir, 3.0)


def plaster(name, out_dir, base):
    grain = noise(1.8)
    cracks = np.clip(1.0 - np.abs(noise(2.6) - 0.5) * 40.0, 0, 1)
    color = shade(base, 0.8 + 0.3 * (grain - 0.5))
    color *= (1.0 - 0.6 * soot(1.0))[..., None]
    color *= (1.0 - 0.5 * cracks)[..., None]
    save(name, color, grain * 0.6 - cracks * 0.4 + 0.4, out_dir, 1.5)


def wood(name, out_dir, base):
    u, v = grid()
    fibre = np.repeat(noise(1.0)[:, :16], N // 16, axis=1)  # vetas a lo largo de u
    planks = np.clip(np.minimum((v * 6) % 1.0, 1 - (v * 6) % 1.0) / 0.06, 0, 1)
    ident = (np.sin(np.floor(v * 6) * 91.7) * 43758.5453) % 1.0
    color = shade(base, (0.75 + 0.4 * (fibre - 0.5) + 0.25 * (ident - 0.5)) * (0.4 + 0.6 * planks))
    color *= (1.0 - 0.3 * soot())[..., None]
    save(name, color, fibre * 0.5 + planks * 0.5, out_dir, 2.5)


def canvas(name, out_dir, base):
    u, v = grid()
    weave = 0.5 + 0.25 * np.sin(u * N * 0.8) * np.sin(v * N * 0.8)
    folds = noise(2.4)
    stains = np.clip((noise(1.8) - 0.5) * 3.0, 0, 1)
    color = shade(base, 0.7 + 0.25 * (weave - 0.5) + 0.45 * (folds - 0.5))
    color *= (1.0 - 0.45 * stains)[..., None]
    ash = np.clip((noise(1.3) - 0.62) * 6.0, 0, 1)
    color = color * (1 - 0.4 * ash[..., None]) + np.asarray((0.5, 0.49, 0.48))[None, None, :] * 0.4 * ash[..., None]
    save(name, color, folds * 0.8 + weave * 0.2, out_dir, 2.0)


def cobble(name, out_dir, base):
    edge, ident = cells(9, 7, joint=0.16, jitter=0.5)
    dome = np.clip(edge, 0, 1) ** 0.5
    color = shade(base, (0.7 + 0.5 * (ident - 0.5) + 0.2 * (noise(1.0) - 0.5)) * (0.35 + 0.65 * dome))
    ash = np.clip(1.0 - edge * 2.0, 0, 1) * 0.18  # ceniza en las juntas
    color += ash[..., None]
    save(name, color, dome, out_dir, 4.0)


def main():
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    stone("sillar", out_dir, (0.3, 0.29, 0.29))
    stone("sillar_claro", out_dir, (0.4, 0.39, 0.38), rows=8, cols=4)
    stone("sillar_oscuro", out_dir, (0.19, 0.18, 0.19), rows=5, cols=2)
    brick("ladrillo", out_dir, (0.3, 0.2, 0.17))
    slate("pizarra", out_dir, (0.17, 0.18, 0.21))
    slate("teja", out_dir, (0.27, 0.15, 0.13))
    plaster("revoque", out_dir, (0.42, 0.39, 0.35))
    wood("madera", out_dir, (0.17, 0.12, 0.09))
    wood("madera_clara", out_dir, (0.3, 0.22, 0.16))
    canvas("lona", out_dir, (0.33, 0.32, 0.31))
    canvas("lona_roja", out_dir, (0.3, 0.08, 0.07))
    cobble("adoquin", out_dir, (0.25, 0.24, 0.24))


main()
