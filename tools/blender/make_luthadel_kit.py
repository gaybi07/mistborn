"""Genera las piezas propias de Luthadel (G27): casas, edificios góticos y el mobiliario de las plazas, con formas
simples pero texturadas (sillar, ladrillo, pizarra, revoque, madera, lona: ver make_luthadel_textures.py) y los tonos
del libro: piedra tiznada, ceniza, hierro y luz cálida en las ventanas.

Uso (desde la carpeta del proyecto, después de generar las texturas en <salida>/tex):
  blender -b --factory-startup -P tools/blender/make_luthadel_kit.py -- <carpeta de salida> [carpeta para las fotos]

Deja un .gltf (+ .bin) por pieza, que usa las texturas compartidas de <salida>/tex. 1 unidad = 1 m, apoyada en z = 0,
el frente hacia -Y de Blender = +Z del juego. Si se pasa la segunda carpeta, saca fotos de muestra.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

# color (r, g, b) como se ve en pantalla, rugosidad, emisión
PAL = {
    "piedra": ((0.25, 0.23, 0.22), 0.95, 0.0),
    "piedra_clara": ((0.37, 0.34, 0.32), 0.95, 0.0),
    "piedra_oscura": ((0.15, 0.14, 0.14), 0.95, 0.0),
    "revoque": ((0.44, 0.38, 0.31), 1.0, 0.0),
    "madera": ((0.17, 0.11, 0.075), 0.9, 0.0),
    "madera_clara": ((0.3, 0.2, 0.13), 0.9, 0.0),
    "pizarra": ((0.12, 0.13, 0.15), 0.8, 0.0),
    "teja": ((0.27, 0.11, 0.09), 0.9, 0.0),
    "ceniza": ((0.5, 0.48, 0.46), 1.0, 0.0),
    "hierro": ((0.07, 0.07, 0.08), 0.5, 0.0),
    "hueco": ((0.03, 0.025, 0.02), 1.0, 0.0),
    "luz": ((1.0, 0.78, 0.5), 0.6, 1.6),
    "agua": ((0.07, 0.09, 0.11), 0.15, 0.0),
    "lona": ((0.3, 0.07, 0.06), 1.0, 0.0),
    "lona_gris": ((0.33, 0.31, 0.29), 1.0, 0.0),
    "papel": ((0.72, 0.66, 0.54), 1.0, 0.0),
    "cuerda": ((0.42, 0.34, 0.22), 1.0, 0.0),
    "ladrillo": ((0.3, 0.2, 0.17), 0.95, 0.0),
    "adoquin": ((0.25, 0.24, 0.24), 0.95, 0.0),
}

# Material -> [textura (en <salida>/tex), metros que cubre una repetición]. Los demás van de color liso.
TEX = {
    "piedra": ["sillar", 3.0], "piedra_clara": ["sillar_claro", 3.0], "piedra_oscura": ["sillar_oscuro", 3.5],
    "ladrillo": ["ladrillo", 2.2], "revoque": ["revoque", 3.0], "madera": ["madera", 1.6],
    "madera_clara": ["madera_clara", 1.6], "pizarra": ["pizarra", 2.4], "teja": ["teja", 2.4],
    "lona": ["lona_roja", 2.0], "lona_gris": ["lona", 2.0], "adoquin": ["adoquin", 2.5],
}
TEX_DIR = ""


def material(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    color, rough, emit = PAL[name]
    color = tuple(c ** 2.2 for c in color)  # PAL está como se ve en pantalla (sRGB); Blender y glTF quieren lineal
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = 0.9 if name == "hierro" else 0.0
    if emit > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit
    if name in TEX:
        base = os.path.join(TEX_DIR, TEX[name][0])
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(base + ".png", check_existing=True)
        m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        ntex = m.node_tree.nodes.new("ShaderNodeTexImage")
        ntex.image = bpy.data.images.load(base + "_n.png", check_existing=True)
        ntex.image.colorspace_settings.name = "Non-Color"
        nmap = m.node_tree.nodes.new("ShaderNodeNormalMap")
        m.node_tree.links.new(ntex.outputs["Color"], nmap.inputs["Color"])
        m.node_tree.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return m


class Piece:
    """Una pieza: se arma con cajas, cilindros y techos, y termina en un solo objeto con sus materiales."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []
        self._n = 0

    def _grow(self):
        """Unos milímetros distintos por parte: las que se apoyan encastran y ninguna cara queda a ras de otra
        (sin esto, dos caras en el mismo plano parpadean: z-fighting)."""
        self._n += 1
        return 0.004 + 0.0026 * (self._n % 13)  # 1,3 mm por cara entre una parte y la siguiente

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def _paint(self, verts, m):
        i = self._mi(m)
        for f in {f for v in verts for f in v.link_faces}:
            f.material_index = i

    def box(self, size, center, m, rz=0.0, rx=0.0, ry=0.0):
        verts = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        g = self._grow()
        size = (size[0] + g, size[1] + g, size[2] + g)
        mat = Matrix.Translation(center) @ Euler((rx, ry, rz)).to_matrix().to_4x4() @ Matrix.Diagonal((*size, 1.0))
        bmesh.ops.transform(self.bm, matrix=mat, verts=verts)
        self._paint(verts, m)

    def cyl(self, r1, r2, h, base, m, segs=8, rz=0.0, axis="z"):
        """Cilindro o cono (r2 arriba) parado en `base`. axis "x" o "y": acostado, centrado en `base` (ruedas, ejes)."""
        g = self._grow()
        verts = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=True, segments=segs, radius1=r1 + g, radius2=max(r2, 0.001), depth=h + g)["verts"]
        if axis != "z":
            turn = Matrix.Rotation(math.pi / 2.0, 4, "Y" if axis == "x" else "X")
            bmesh.ops.transform(self.bm, matrix=Matrix.Translation(base) @ turn, verts=verts)
            self._paint(verts, m)
            return
        mat = Matrix.Translation(Vector(base) + Vector((0, 0, h / 2.0))) @ Matrix.Rotation(rz, 4, "Z")
        bmesh.ops.transform(self.bm, matrix=mat, verts=verts)
        self._paint(verts, m)

    def ring(self, r_out, r_in, z0, z1, m, segs=8, rz=0.0):
        """Anillo macizo (el borde de una pila)."""
        verts = []
        for z in (z0, z1):
            for r in (r_out, r_in):
                verts.append([self.bm.verts.new((r * math.cos(rz + math.tau * i / segs), r * math.sin(rz + math.tau * i / segs), z)) for i in range(segs)])
        ob, ib, ot, it = verts
        faces = []
        for i in range(segs):
            j = (i + 1) % segs
            faces.append(self.bm.faces.new((ob[i], ob[j], ot[j], ot[i])))  # afuera
            faces.append(self.bm.faces.new((ib[j], ib[i], it[i], it[j])))  # adentro
            faces.append(self.bm.faces.new((ot[i], ot[j], it[j], it[i])))  # arriba
            faces.append(self.bm.faces.new((ob[j], ob[i], ib[i], ib[j])))  # abajo
        i = self._mi(m)
        for f in faces:
            f.material_index = i

    def gable(self, w, d, h, base, m, over=0.35, along="y"):
        """Techo a dos aguas con la cumbrera a lo largo de `along`, apoyado en `base` (centro, a la altura del alero)."""
        hw, hd = w / 2.0 + over, d / 2.0 + over
        pts = [(-hw, -hd, 0), (hw, -hd, 0), (hw, hd, 0), (-hw, hd, 0), (0, -hd, h), (0, hd, h)]
        if along == "x":
            hw, hd = d / 2.0 + over, w / 2.0 + over
            pts = [(-hd, -hw, 0), (hd, -hw, 0), (hd, hw, 0), (-hd, hw, 0), (-hd, 0, h), (hd, 0, h)]
            order = [(0, 1, 5, 4), (2, 3, 4, 5), (1, 2, 5), (3, 0, 4), (3, 2, 1, 0)]
        else:
            order = [(1, 2, 5, 4), (3, 0, 4, 5), (0, 1, 4), (2, 3, 5), (3, 2, 1, 0)]
        vs = [self.bm.verts.new(Vector(p) + Vector(base)) for p in pts]
        i = self._mi(m)
        for o in order:
            self.bm.faces.new([vs[k] for k in o]).material_index = i

    def window(self, x, z, y, w=0.8, h=1.2, lit=True, shutters=True, depth=-1.0):
        """Ventana en la pared de frente (y = cara de la pared; depth -1 mira a -Y, +1 a +Y)."""
        self.box((w + 0.22, 0.12, h + 0.22), (x, y + depth * 0.03, z), "madera")
        self.box((w, 0.12, h), (x, y + depth * 0.07, z), "luz" if lit else "hueco")
        self.box((0.07, 0.14, h), (x, y + depth * 0.1, z), "madera")
        self.box((w, 0.14, 0.07), (x, y + depth * 0.1, z + h * 0.12), "madera")
        self.box((w + 0.4, 0.24, 0.1), (x, y + depth * 0.105, z - h / 2.0 - 0.14), "piedra_clara")
        self.box((w + 0.3, 0.22, 0.05), (x, y + depth * 0.1, z - h / 2.0 - 0.065), "ceniza")
        if shutters:
            for s in (-1, 1):
                self.box((0.34, 0.06, h + 0.1), (x + s * (w / 2.0 + 0.27), y + depth * 0.06, z), "madera_clara")

    def arch(self, x, y, z, w, m="piedra_clara", depth=-1.0):
        """Arco apuntado: dos losas inclinadas que se juntan arriba, con la clave en z + w * 0.55."""
        for s in (-1, 1):
            self.box((w * 0.82, 0.26, 0.2), (x + s * w * 0.3, y + depth * 0.05, z + w * 0.3), m, ry=s * 0.75)

    def gothic_window(self, x, z, y, w=0.7, h=2.0, lit=True, depth=-1.0):
        """Ventana alta y angosta con arco apuntado y un parteluz."""
        self.box((w + 0.26, 0.14, h + 0.2), (x, y + depth * 0.03, z), "piedra_clara")
        self.box((w, 0.13, h), (x, y + depth * 0.075, z), "luz" if lit else "hueco")
        self.box((0.07, 0.15, h), (x, y + depth * 0.1, z), "hierro")
        self.box((w, 0.16, 0.06), (x, y + depth * 0.105, z + h * 0.2), "hierro")
        self.arch(x, y + depth * 0.02, z + h / 2.0, w + 0.3, depth=depth)
        self.box((w + 0.44, 0.3, 0.1), (x, y + depth * 0.11, z - h / 2.0 - 0.13), "piedra_clara")
        self.box((w + 0.34, 0.24, 0.05), (x, y + depth * 0.115, z - h / 2.0 - 0.06), "ceniza")

    def door(self, x, y, w=1.1, h=2.1, arch=False, depth=-1.0):
        self.box((w + 0.36, 0.22, h + 0.2), (x, y + depth * 0.04, h / 2.0 + 0.1), "piedra_clara")
        self.box((w, 0.2, h), (x, y + depth * 0.1, h / 2.0), "madera")
        for k in range(3):
            self.box((w, 0.22, 0.05), (x, y + depth * 0.11, 0.35 + k * 0.7), "hierro")
        self.box((0.09, 0.26, 0.09), (x + w * 0.32, y + depth * 0.14, h * 0.5), "hierro")
        if arch:  # arco apuntado: dos losas inclinadas sobre el dintel
            for s in (-1, 1):
                self.box((w * 0.8, 0.24, 0.22), (x + s * w * 0.3, y + depth * 0.05, h + 0.5), "piedra_clara", ry=s * 0.75)
        self.box((w + 0.9, 0.7, 0.16), (x, y + depth * 0.35, 0.08), "piedra_clara")  # umbral

    def _unwrap(self):
        """UV por proyección, a escala real: u a lo largo de la cara (horizontal), v hacia arriba (o cuesta arriba en
        los techos, así las hiladas quedan horizontales). La madera va con la veta a lo largo de la pieza."""
        uv = self.bm.loops.layers.uv.new("UVMap")
        self.bm.normal_update()
        for f in self.bm.faces:
            name = self.mats[f.material_index]
            scale = TEX[name][1] if name in TEX else 1.0
            n = f.normal
            if abs(n.z) > 0.92:
                t, b = Vector((1, 0, 0)), Vector((0, 1, 0))
            else:
                t = Vector((-n.y, n.x, 0)).normalized()
                b = n.cross(t)
            us = [l.vert.co.dot(t) for l in f.loops]
            vs = [l.vert.co.dot(b) for l in f.loops]
            turn = name.startswith("madera") and (max(vs) - min(vs)) > (max(us) - min(us)) * 1.3
            for l, u, v in zip(f.loops, us, vs):
                l[uv].uv = (v / scale, u / scale) if turn else (u / scale, v / scale)

    def finish(self):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.0001)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        self._unwrap()
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for m in self.mats:
            mesh.materials.append(material(m))
        ob = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def chimney(p, x, y, z, h=2.2):
    p.box((0.7, 0.7, h), (x, y, z + h / 2.0), "piedra")
    p.box((0.86, 0.86, 0.16), (x, y, z + h), "piedra_clara")
    p.box((0.5, 0.5, 0.12), (x, y, z + h + 0.12), "hueco")


def ash_ridge(p, d, z, along="y", over=0.35):
    """Ceniza juntada en la cumbrera."""
    size = (0.36, d + over * 2.0 + 0.04, 0.12) if along == "y" else (d + over * 2.0 + 0.04, 0.36, 0.12)
    p.box(size, (0, 0, z - 0.02), "ceniza")


def timber_front(p, w, y, z0, z1, floors):
    """Entramado de madera en la fachada (y): postes, soleras por piso y cruces."""
    for x in (-w / 2.0, 0.0, w / 2.0):
        p.box((0.2, 0.14, z1 - z0), (x, y - 0.04, (z0 + z1) / 2.0), "madera")
    for k in range(floors + 1):
        p.box((w + 0.2, 0.16, 0.2), (0, y - 0.05, z0 + (z1 - z0) * k / floors), "madera")
    for k in range(floors):
        zc = z0 + (z1 - z0) * (k + 0.5) / floors
        for s in (-1, 1):
            p.box((0.13, 0.12, (z1 - z0) / floors * 0.85), (s * (w / 2.0 - 0.42), y - 0.03, zc), "madera", ry=s * 0.32)


def casa_conventillo():
    """Conventillo skaa: angosto y alto. Planta baja de piedra, dos pisos de entramado que vuelan sobre la calle."""
    p = Piece("CasaConventillo")
    w, d = 5.6, 7.2
    p.box((w, d, 3.0), (0, 0, 1.5), "ladrillo")
    p.box((w + 0.16, d + 0.16, 0.35), (0, 0, 0.175), "piedra_oscura")  # zócalo
    p.box((w + 0.5, d + 0.4, 5.4), (0, -0.15, 5.7), "revoque")  # los pisos de arriba vuelan 40 cm
    fy = -d / 2.0 - 0.35
    timber_front(p, w + 0.5, fy, 3.0, 8.4, 2)
    for k in range(4):  # canes que sostienen el vuelo
        p.box((0.2, 0.55, 0.28), (-w / 2.0 + 0.4 + k * (w - 0.8) / 3.0, -d / 2.0 - 0.2, 2.83), "madera")
    p.door(-1.3, -d / 2.0)
    p.window(1.3, 1.6, -d / 2.0, lit=False, w=1.0)
    for z, lit in ((4.4, (True, False)), (7.0, (False, True))):
        for x, on in zip((-1.45, 1.45), lit):
            p.window(x, z, fy, lit=on)
    for z in (4.4, 7.0):  # ventanas del costado
        p.box((0.12, 0.8, 1.1), (w / 2.0 + 0.27, 0.8, z), "hueco")
        p.box((0.14, 1.0, 0.1), (w / 2.0 + 0.29, 0.8, z - 0.62), "madera")
    p.gable(w + 0.5, d + 0.4, 3.4, (0, -0.15, 8.4), "pizarra")
    p.box((w + 0.3, 0.14, 0.14), (0, fy + 0.02, 8.42), "madera")
    ash_ridge(p, d + 0.4, 11.8)
    for s in (-1, 1):  # ceniza en los aleros
        p.box((0.5, d + 1.0, 0.07), (s * (w / 2.0 + 0.42), -0.15, 8.47), "ceniza", ry=s * 0.86)
    chimney(p, 1.5, 1.6, 9.6, 2.6)
    p.box((1.0, 0.08, 0.5), (1.3, -d / 2.0 - 0.5, 2.5), "lona_gris", rx=-0.5)  # trapo colgado
    return p.finish()


def casa_tienda():
    """Casa con tienda: ancha y baja. Piedra abajo con el mostrador y el toldo, entramado arriba, techo de teja."""
    p = Piece("CasaTienda")
    w, d = 8.4, 6.4
    p.box((w, d, 3.1), (0, 0, 1.55), "piedra")
    p.box((w + 0.16, d + 0.16, 0.35), (0, 0, 0.175), "piedra_oscura")
    p.box((w + 0.4, d + 0.3, 2.7), (0, -0.1, 4.45), "revoque")
    fy = -d / 2.0 - 0.25
    timber_front(p, w + 0.4, fy, 3.1, 5.8, 1)
    # La tienda: hueco con mostrador, postigos levantados y toldo.
    p.box((3.4, 0.2, 1.7), (1.9, -d / 2.0 - 0.02, 1.95), "hueco")
    p.box((3.0, 0.14, 1.3), (1.9, -d / 2.0 - 0.06, 2.0), "luz")
    p.box((3.7, 0.6, 0.14), (1.9, -d / 2.0 - 0.3, 1.08), "madera_clara")
    p.box((3.7, 0.2, 0.9), (1.9, -d / 2.0 - 0.1, 0.6), "madera")
    for k in range(5):
        p.box((0.78, 1.9, 0.07), (0.3 + k * 0.8, -d / 2.0 - 0.95, 3.0 - (0.06 if k % 2 else 0.0)), "lona_gris", rx=0.32)
    for x in (0.1, 3.7):
        p.box((0.1, 0.1, 2.5), (x, -d / 2.0 - 1.75, 1.25), "madera")
    p.box((3.8, 0.1, 0.1), (1.9, -d / 2.0 - 1.75, 2.5), "madera")
    p.door(-2.6, -d / 2.0)
    p.box((0.08, 0.9, 0.08), (-1.5, -d / 2.0 - 0.45, 3.0), "hierro")  # el brazo del cartel
    p.box((0.06, 0.7, 0.55), (-1.5, -d / 2.0 - 0.6, 2.62), "madera_clara")
    for x, on in ((-2.6, True), (0.0, False), (2.6, True)):
        p.window(x, 4.5, fy, lit=on, h=1.1)
    p.gable(w + 0.4, d + 0.3, 2.9, (0, -0.1, 5.8), "teja", along="x")
    ash_ridge(p, w + 0.4, 8.7, along="x")
    for s in (-1, 1):
        p.box((w + 1.1, 0.5, 0.07), (0, -0.1 + s * (d / 2.0 + 0.33), 5.87), "ceniza", rx=s * -0.74)
    for x in (-2.2, 2.2):  # buhardillas
        p.box((1.3, 1.5, 1.2), (x, -d / 2.0 + 0.9, 6.5), "revoque")
        p.window(x, 6.55, -d / 2.0 + 0.15, w=0.7, h=0.7, lit=x < 0, shutters=False)
        p.gable(1.3, 1.5, 0.7, (x, -d / 2.0 + 0.9, 7.1), "teja", over=0.15)
    chimney(p, -3.0, 1.4, 6.6, 2.6)
    for k, (x, y) in enumerate(((4.6, -3.7), (5.3, -3.6), (4.9, -4.4))):  # cajones y un barril afuera
        p.box((0.7, 0.7, 0.7), (x, y, 0.35 + (0.0 if k < 2 else 0.0)), "madera_clara", rz=k * 0.4)
    p.cyl(0.38, 0.38, 0.95, (-4.7, -3.7, 0.0), "madera", segs=10)
    p.cyl(0.4, 0.4, 0.06, (-4.7, -3.7, 0.3), "hierro", segs=10)
    return p.finish()


def casa_piedra():
    """Casa de piedra: de mercader o de funcionario. Frontón escalonado, puerta de arco apuntado, contrafuertes."""
    p = Piece("CasaPiedra")
    w, d = 6.6, 8.0
    p.box((w, d, 6.4), (0, 0, 3.2), "piedra")
    p.box((w + 0.2, d + 0.2, 0.45), (0, 0, 0.225), "piedra_oscura")
    p.box((w + 0.12, d + 0.12, 0.18), (0, 0, 3.3), "piedra_clara")  # cornisa entre pisos
    fy = -d / 2.0
    for s in (-1, 1):  # contrafuertes
        p.box((0.7, 0.9, 4.6), (s * (w / 2.0 - 0.1), fy - 0.25, 2.3), "piedra_oscura")
        p.box((0.7, 0.9, 0.5), (s * (w / 2.0 - 0.1), fy - 0.12, 4.75), "piedra_oscura", rx=0.5)
    # Frontón escalonado, más alto que el techo.
    for k in range(4):
        p.box((w - k * 1.5, 0.5, 0.95), (0, fy + 0.25, 6.4 + 0.475 + k * 0.95), "piedra")
        p.box((w - k * 1.5 + 0.16, 0.6, 0.1), (0, fy + 0.25, 6.4 + (k + 1) * 0.95), "ceniza")
    p.box((0.3, 0.3, 1.5), (0, fy + 0.25, 10.9), "hierro")  # púa del remate
    p.cyl(0.16, 0.0, 1.0, (0, fy + 0.25, 11.6), "hierro", segs=4)
    p.door(0.0, fy, w=1.3, h=2.4, arch=True)
    for s in (-1, 1):  # ventanas altas y angostas
        p.window(s * 2.0, 1.9, fy, w=0.55, h=1.7, lit=s > 0, shutters=False)
        p.window(s * 1.9, 4.9, fy, w=0.6, h=1.8, lit=s < 0, shutters=False)
    p.window(0.0, 5.0, fy, w=0.6, h=2.0, lit=True, shutters=False)
    p.box((0.5, 0.1, 0.5), (0, fy - 0.03, 8.0), "luz")  # óculo
    p.box((0.74, 0.12, 0.74), (0, fy + 0.0, 8.0), "madera")
    for z in (1.9, 4.9):
        p.box((0.12, 0.6, 1.5), (w / 2.0 + 0.02, 1.0, z), "hueco")
        p.box((0.12, 0.6, 1.5), (-w / 2.0 - 0.02, -1.0, z), "hueco")
    p.gable(w, d, 3.6, (0, 0.0, 6.4), "pizarra", over=0.25)
    ash_ridge(p, d, 10.0, over=0.25)
    chimney(p, -2.0, 2.2, 7.8, 3.0)
    # Farol de hierro junto a la puerta.
    p.box((0.07, 0.5, 0.07), (1.25, fy - 0.3, 2.9), "hierro")
    p.box((0.26, 0.26, 0.36), (1.25, fy - 0.5, 2.62), "luz")
    p.box((0.34, 0.34, 0.06), (1.25, fy - 0.5, 2.84), "hierro")
    p.box((0.34, 0.34, 0.06), (1.25, fy - 0.5, 2.42), "hierro")
    return p.finish()


def fuente_plaza():
    """Fuente de la Plaza Central: grada de tres escalones, pila octogonal y el pedestal de la estatua con púas."""
    p = Piece("PlazaFuente")
    rz = math.pi / 8.0
    for k, r in enumerate((9.0, 8.2, 7.4)):
        p.cyl(r, r, 0.2, (0, 0, k * 0.2), "piedra_clara" if k % 2 == 0 else "piedra", segs=8, rz=rz)
    z = 0.6
    p.ring(6.0, 5.2, z, z + 0.95, "piedra", rz=rz)
    p.ring(6.15, 5.05, z + 0.95, z + 1.1, "piedra_clara", rz=rz)
    p.cyl(5.25, 5.25, 0.55, (0, 0, z), "agua", segs=8, rz=rz)
    for i in range(8):  # ceniza flotando en los bordes
        a = rz + math.tau * (i + 0.5) / 8.0
        p.box((1.1, 0.4, 0.03), (4.3 * math.cos(a), 4.3 * math.sin(a), z + 0.56), "ceniza", rz=a + math.pi / 2.0)
    # Pedestal: zócalo, fuste que se afina y losa de arriba (la estatua de bronce va encima, la pone el juego).
    p.cyl(2.1, 2.1, 1.3, (0, 0, z), "piedra_oscura", segs=8, rz=rz)
    p.cyl(2.3, 2.3, 0.18, (0, 0, z + 1.3), "piedra_clara", segs=8, rz=rz)
    p.cyl(1.45, 1.15, 2.3, (0, 0, z + 1.48), "piedra", segs=8, rz=rz)
    p.cyl(1.55, 1.55, 0.24, (0, 0, z + 3.78), "piedra_clara", segs=8, rz=rz)
    for i in range(8):  # púas de hierro, como las de Kredik Shaw
        a = rz + math.tau * i / 8.0
        p.cyl(0.13, 0.0, 2.6, (1.85 * math.cos(a), 1.85 * math.sin(a), z + 1.48), "hierro", segs=4, rz=a)
    for i in range(4):  # caños
        a = math.tau * i / 4.0
        p.box((0.9, 0.2, 0.2), (1.7 * math.cos(a), 1.7 * math.sin(a), z + 0.95), "hierro", rz=a)
    return p.finish()


def cadalso():
    """Cadalso: tarima de madera con escalera, tajo y horca. Las ejecuciones del Ministerio son acá."""
    p = Piece("PlazaCadalso")
    w, d, h = 5.6, 4.4, 1.7
    p.box((w, d, 0.16), (0, 0, h), "madera_clara")
    for k in range(7):
        p.box((0.06, d + 0.04, 0.17), (-w / 2.0 + 0.4 + k * 0.8, 0, h), "madera")
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((0.26, 0.26, h), (sx * (w / 2.0 - 0.2), sy * (d / 2.0 - 0.2), h / 2.0), "madera")
        p.box((0.12, d - 0.5, 0.16), (sx * (w / 2.0 - 0.2), 0, 0.7), "madera")
        p.box((0.1, d * 1.02, 0.14), (sx * (w / 2.0 - 0.2), 0, h / 2.0 + 0.1), "madera", rx=sx * 0.36)
    for k in range(6):  # escalera, por el frente
        p.box((1.5, 0.34, 0.12), (-1.6, -d / 2.0 - 0.2 - (5 - k) * 0.3, 0.2 + k * 0.28), "madera_clara")
    for s in (-1, 1):
        p.box((0.1, 2.1, 0.16), (-1.6 + s * 0.75, -d / 2.0 - 0.95, 0.9), "madera", rx=0.75)
    # Tajo y hacha.
    p.cyl(0.42, 0.46, 0.55, (-1.4, 0.3, h + 0.08), "madera", segs=8)
    p.box((0.08, 0.08, 1.0), (-0.95, 0.5, h + 0.55), "madera_clara", ry=0.25)
    p.box((0.36, 0.05, 0.3), (-0.82, 0.5, h + 0.98), "hierro")
    # Horca: dos postes, travesaño, tornapuntas y dos sogas.
    for s in (-1, 1):
        p.box((0.24, 0.24, 3.4), (1.2 + s * 1.2, 0.9, h + 1.7), "madera")
        p.box((0.14, 0.14, 1.1), (1.2 + s * 0.8, 0.9, h + 3.0), "madera", ry=s * 0.8)
        p.box((0.05, 0.05, 1.1), (1.2 + s * 0.5, 0.9, h + 2.7), "cuerda")
        p.box((0.3, 0.07, 0.36), (1.2 + s * 0.5, 0.9, h + 2.0), "cuerda")
        p.box((0.2, 0.09, 0.24), (1.2 + s * 0.5, 0.9, h + 2.0), "hueco")
    p.box((3.1, 0.24, 0.24), (1.2, 0.9, h + 3.4), "madera")
    p.box((w * 0.8, 0.05, 0.9), (0, -d / 2.0 - 0.03, h - 0.5), "lona")  # paño del Ministerio al frente
    return p.finish()


def tablon():
    """Tablón de avisos del Ministerio: dos postes, tablero con papeles y un tejadillo."""
    p = Piece("PlazaTablon")
    for s in (-1, 1):
        p.box((0.16, 0.16, 2.7), (s * 1.05, 0, 1.35), "madera")
        p.box((0.3, 0.3, 0.2), (s * 1.05, 0, 0.1), "piedra")
    p.box((2.0, 0.1, 1.35), (0, 0, 1.65), "madera_clara")
    p.box((2.2, 0.14, 0.1), (0, 0, 2.36), "madera")
    p.box((2.2, 0.14, 0.1), (0, 0, 0.94), "madera")
    for x, z, w, h, rz in ((-0.55, 1.75, 0.6, 0.8, 0.04), (0.3, 1.85, 0.5, 0.6, -0.06), (0.42, 1.3, 0.4, 0.35, 0.08), (-0.1, 1.25, 0.3, 0.3, -0.03)):
        p.box((w, 0.02, h), (x, -0.062, z), "papel", ry=rz)
    p.box((0.34, 0.03, 0.24), (-0.55, -0.075, 2.06), "lona")  # el sello
    p.gable(2.3, 0.5, 0.42, (0, 0, 2.62), "pizarra", over=0.12, along="x")
    p.box((2.5, 0.16, 0.06), (0, 0, 3.05), "ceniza")
    return p.finish()


def banco():
    """Banco de piedra, con ceniza encima."""
    p = Piece("PlazaBanco")
    p.box((2.4, 0.7, 0.16), (0, 0, 0.5), "piedra_clara")
    for s in (-1, 1):
        p.box((0.3, 0.6, 0.42), (s * 0.85, 0, 0.21), "piedra")
        p.box((0.36, 0.66, 0.08), (s * 0.85, 0, 0.04), "piedra_oscura")
    p.box((1.5, 0.5, 0.03), (0.3, 0.05, 0.595), "ceniza")
    return p.finish()


def _goods(p, x0, x1, y, z):
    """Mercadería sobre un mostrador: cajones, bolsas y un farol."""
    n = 4
    for k in range(n):
        x = x0 + (x1 - x0) * (k + 0.5) / n
        size = 0.26 + 0.1 * ((k * 7) % 3)
        p.box((size * 1.3, size, size * 0.7), (x, y, z + size * 0.35), "madera_clara" if k % 2 else "lona_gris", rz=0.2 * k)
    p.box((0.2, 0.2, 0.3), (x1 - 0.1, y - 0.25, z + 0.15), "luz")
    p.box((0.26, 0.26, 0.05), (x1 - 0.1, y - 0.25, z + 0.32), "hierro")


def puesto_lona():
    """Puesto con toldo de lona gris combada: cuatro postes, mostrador, fondo de tablas, mercadería y un farol."""
    p = Piece("PuestoLona")
    w, d = 4.2, 2.6
    for sx in (-1, 1):
        p.box((0.13, 0.13, 2.3), (sx * (w / 2.0 - 0.1), -d / 2.0 + 0.1, 1.15), "madera")
        p.box((0.13, 0.13, 3.1), (sx * (w / 2.0 - 0.1), d / 2.0 - 0.1, 1.55), "madera")
    p.box((w, 0.8, 0.1), (0, -d / 2.0 + 0.45, 1.0), "madera_clara")
    p.box((w, 0.08, 0.9), (0, -d / 2.0 + 0.1, 0.5), "madera")
    p.box((w, 0.08, 2.0), (0, d / 2.0 - 0.1, 1.3), "madera")
    # La lona, en tres paños: cae hacia el frente y se comba en el medio.
    for k, (x, sag) in enumerate(((-w / 3.0, 0.0), (0.0, 0.22), (w / 3.0, 0.05))):
        p.box((w / 3.0 + 0.3, d + 1.3, 0.05), (x, -0.25, 2.72 - sag), "lona_gris", rx=0.3, ry=0.06 * (k - 1))
    p.box((w + 0.5, 0.05, 0.45), (0, -d / 2.0 - 0.85, 2.2), "lona_gris", rx=-0.15)  # el faldón
    p.box((0.05, d + 0.6, 1.6), (-w / 2.0 - 0.08, -0.1, 1.9), "lona_gris", ry=0.08)  # un costado tapado
    _goods(p, -w / 2.0 + 0.3, w / 2.0 - 0.3, -d / 2.0 + 0.45, 1.05)
    p.cyl(0.32, 0.32, 0.8, (w / 2.0 + 0.5, -0.4, 0.0), "madera", segs=8)
    p.box((0.7, 0.55, 0.4), (-w / 2.0 - 0.6, -0.9, 0.2), "lona_gris", rz=0.3)
    p.box((0.6, 0.6, 0.6), (0.9, 0.5, 0.3), "madera_clara", rz=0.2)
    return p.finish()


def puesto_carpa():
    """Carpa de mercado: una lona gris a dos aguas sobre un palo, con una mesa adentro."""
    p = Piece("PuestoCarpa")
    w, d = 3.6, 3.2
    for sy in (-1, 1):
        p.box((0.12, 0.12, 2.9), (0, sy * (d / 2.0), 1.45), "madera")
    p.box((0.1, d + 0.4, 0.1), (0, 0, 2.9), "madera")
    p.gable(w, d, 1.5, (0, 0, 1.45), "lona_gris", over=0.15)
    for sx in (-1, 1):  # los paños siguen hasta casi el piso, abiertos adelante
        p.box((0.05, d + 0.3, 1.1), (sx * (w / 2.0 + 0.32), 0, 0.95), "lona_gris", ry=sx * -0.35)
        p.box((0.1, 0.1, 1.5), (sx * (w / 2.0 + 0.1), -d / 2.0, 0.75), "madera")
    p.box((2.4, 1.0, 0.1), (0, 0.2, 0.9), "madera_clara")
    for sx in (-1, 1):
        p.box((0.1, 0.9, 0.9), (sx * 1.0, 0.2, 0.45), "madera")
    _goods(p, -1.0, 1.0, 0.2, 0.95)
    p.box((0.7, 0.6, 0.45), (-1.0, -1.3, 0.22), "lona_gris", rz=0.4)
    p.cyl(0.3, 0.3, 0.75, (1.2, -1.2, 0.0), "madera", segs=8)
    return p.finish()


def fuente_mercado():
    """Fuente del mercado: dos escalones de adoquín, pila octogonal y tres platos con un remate encapuchado."""
    p = Piece("FuenteMercado")
    rz = math.pi / 8.0
    p.cyl(5.2, 5.2, 0.2, (0, 0, 0), "adoquin", segs=8, rz=rz)
    p.cyl(4.5, 4.5, 0.2, (0, 0, 0.2), "piedra", segs=8, rz=rz)
    z = 0.4
    p.ring(3.7, 3.1, z, z + 0.8, "piedra", rz=rz)
    p.ring(3.85, 2.95, z + 0.8, z + 0.95, "piedra_clara", rz=rz)
    p.cyl(3.15, 3.15, 0.5, (0, 0, z), "agua", segs=8, rz=rz)
    p.cyl(0.7, 0.55, 1.7, (0, 0, z), "piedra_oscura", segs=8)
    p.cyl(0.6, 1.9, 0.45, (0, 0, z + 1.7), "piedra", segs=8, rz=rz)  # plato grande
    p.cyl(1.75, 1.75, 0.06, (0, 0, z + 2.1), "agua", segs=8, rz=rz)
    p.cyl(0.42, 0.34, 1.2, (0, 0, z + 2.15), "piedra_oscura", segs=8)
    p.cyl(0.4, 1.15, 0.35, (0, 0, z + 3.35), "piedra", segs=8, rz=rz)  # plato chico
    p.cyl(1.02, 1.02, 0.05, (0, 0, z + 3.66), "agua", segs=8, rz=rz)
    p.cyl(0.4, 0.14, 1.1, (0, 0, z + 3.7), "piedra_oscura", segs=6)  # figura encapuchada
    p.box((0.26, 0.26, 0.3), (0, 0, z + 4.9), "piedra_oscura")
    for k in range(4):  # caños de hierro
        a = math.tau * k / 4.0
        p.box((0.7, 0.14, 0.14), (0.95 * math.cos(a), 0.95 * math.sin(a), z + 1.25), "hierro", rz=a)
    return p.finish()


def carreta():
    """Carreta de carga, sin caballo: caja de tablas, dos ruedas grandes, varas, bolsas, un barril y media lona."""
    p = Piece("Carreta")
    p.box((1.7, 3.4, 0.14), (0, 0, 1.0), "madera_clara")
    for sx in (-1, 1):
        p.box((0.08, 3.4, 0.6), (sx * 0.85, 0, 1.35), "madera")
        p.cyl(0.72, 0.72, 0.12, (sx * 1.0, 0.3, 0.72), "madera", segs=10, axis="x")
        p.cyl(0.16, 0.16, 0.2, (sx * 1.0, 0.3, 0.72), "hierro", segs=6, axis="x")
        p.box((0.1, 2.6, 0.1), (sx * 0.6, -2.9, 0.86), "madera", rx=0.1)  # varas, hacia el frente
    p.box((1.7, 0.08, 0.6), (0, 1.7, 1.35), "madera")
    p.box((1.9, 0.12, 0.12), (0, 0.3, 0.72), "hierro")  # el eje
    p.box((0.12, 0.12, 0.9), (0, -1.5, 0.5), "madera")  # la pata de apoyo
    for k, (x, y) in enumerate(((-0.4, 1.1), (0.35, 1.0), (-0.1, 0.4), (0.4, 0.2))):
        p.box((0.65, 0.5, 0.36), (x, y, 1.26 + 0.2 * (k // 2)), "lona_gris", rz=0.5 * k)
    p.cyl(0.33, 0.33, 0.8, (0.3, -0.9, 1.07), "madera", segs=8)
    p.box((0.6, 0.6, 0.55), (-0.4, -0.8, 1.35), "madera_clara", rz=0.2)
    p.box((1.9, 1.6, 0.05), (0, 0.9, 1.78), "lona_gris", rx=0.12)  # media lona encima
    return p.finish()


def casa_gotica():
    """Caserón gótico de piedra: arcada abajo, tres pisos de ventanas apuntadas, balcón de hierro, torrecillas en las
    esquinas del frente y techo empinado de pizarra con buhardillas. Para los frentes de las plazas."""
    p = Piece("CasaGotica")
    w, d, top = 13.0, 9.0, 13.6
    fy = -d / 2.0
    p.box((w, d, top), (0, 0, top / 2.0), "piedra")
    p.box((w + 0.3, d + 0.3, 0.6), (0, 0, 0.3), "piedra_oscura")
    for z in (4.2, 7.4, 10.6, top):  # cornisas con ceniza
        p.box((w + 0.3, d + 0.3, 0.22), (0, 0, z), "piedra_clara")
        p.box((w + 0.36, 0.34, 0.05), (0, fy - 0.02, z + 0.13), "ceniza")
    for k in range(4):  # arcada: cuatro vanos apuntados entre pilares
        x = -4.5 + k * 3.0
        p.box((2.0, 0.5, 2.9), (x, fy + 0.12, 1.56), "hueco")
        p.arch(x, fy - 0.1, 3.0, 2.3)
        if k in (1, 2):
            p.box((1.5, 0.12, 2.3), (x, fy + 0.3, 1.2), "madera")
        else:
            p.box((1.3, 0.1, 1.5), (x, fy + 0.3, 1.9), "luz")
    for k in range(5):
        p.box((0.75, 0.75, 4.0), (-6.0 + k * 3.0, fy - 0.2, 2.1), "piedra_oscura")
    for fl, z in enumerate((5.8, 9.0, 12.1)):
        for k in range(4):
            x = -4.5 + k * 3.0
            p.gothic_window(x, z, fy, lit=(k + fl) % 3 == 0)
    # Balcón del primer piso, al medio.
    p.box((6.4, 1.3, 0.2), (0, fy - 0.6, 4.55), "piedra_clara")
    for k in range(3):
        p.box((0.4, 0.9, 0.5), (-2.6 + k * 2.6, fy - 0.4, 4.2), "piedra_oscura", rx=0.5)
    p.box((6.4, 0.06, 0.07), (0, fy - 1.2, 5.6), "hierro")
    for k in range(13):
        p.box((0.05, 0.05, 0.95), (-3.1 + k * 0.52, fy - 1.2, 5.12), "hierro")
    for sy in (-1, 1):
        p.box((0.06, 1.2, 0.07), (sy * 3.17, fy - 0.6, 5.6), "hierro")
    for z in (5.8, 9.0, 12.1):  # costados
        for y in (-2.0, 2.0):
            p.box((0.14, 0.7, 1.9), (w / 2.0 + 0.02, y, z), "hueco")
            p.box((0.14, 0.7, 1.9), (-w / 2.0 - 0.02, y, z), "hueco")
    p.gable(w, d, 5.2, (0, 0, top), "pizarra", over=0.3, along="x")
    ash_ridge(p, w, top + 5.2, along="x", over=0.3)
    for x in (-4.0, 0.0, 4.0):
        p.box((1.5, 1.8, 1.6), (x, fy + 1.3, top + 0.9), "piedra")
        p.gothic_window(x, top + 1.0, fy + 0.4, w=0.6, h=1.0, lit=x == 0.0)
        p.gable(1.5, 1.8, 1.1, (x, fy + 1.3, top + 1.7), "pizarra", over=0.15)
    for sx in (-1, 1):  # torrecillas de las esquinas, con chapitel
        x = sx * (w / 2.0 - 0.1)
        p.cyl(1.0, 1.0, 5.5, (x, fy + 0.1, 10.0), "piedra_oscura", segs=8)
        p.cyl(1.2, 1.2, 0.3, (x, fy + 0.1, 15.5), "piedra_clara", segs=8)
        p.cyl(1.25, 0.0, 4.2, (x, fy + 0.1, 15.8), "pizarra", segs=8)
        p.cyl(0.07, 0.0, 1.4, (x, fy + 0.1, 19.6), "hierro", segs=4)
        p.cyl(1.1, 0.6, 1.2, (x, fy + 0.1, 8.8), "piedra_oscura", segs=8)  # ménsula
        p.box((0.3, 0.14, 0.9), (x, fy - 0.9, 13.0), "luz")
    chimney(p, -4.5, 2.5, top + 1.5, 4.6)
    chimney(p, 4.0, 2.2, top + 2.0, 4.4)
    for x in (-3.0, 3.0):  # faroles colgados en la arcada
        p.box((0.06, 0.06, 0.5), (x, fy - 0.45, 3.85), "hierro")
        p.box((0.28, 0.28, 0.4), (x, fy - 0.45, 3.45), "luz")
        p.box((0.36, 0.36, 0.06), (x, fy - 0.45, 3.68), "hierro")
    return p.finish()


def torre_gotica():
    """Torre octogonal de piedra con matacán y chapitel de pizarra, y un estandarte rojo colgado al frente."""
    p = Piece("TorreGotica")
    rz = math.pi / 8.0
    p.cyl(4.0, 4.0, 1.4, (0, 0, 0), "piedra_oscura", segs=8, rz=rz)
    p.cyl(3.5, 3.4, 16.0, (0, 0, 0), "piedra", segs=8, rz=rz)
    for z in (6.0, 11.0):
        p.cyl(3.62, 3.62, 0.3, (0, 0, z), "piedra_clara", segs=8, rz=rz)
    p.cyl(3.5, 4.0, 1.0, (0, 0, 16.0), "piedra_oscura", segs=8, rz=rz)  # matacán
    p.cyl(4.0, 4.0, 0.9, (0, 0, 17.0), "piedra", segs=8, rz=rz)
    for k in range(8):  # almenas
        a = rz + math.tau * (k + 0.5) / 8.0
        p.box((1.1, 0.5, 0.8), (3.6 * math.cos(a), 3.6 * math.sin(a), 18.3), "piedra", rz=a + math.pi / 2.0)
    p.cyl(3.3, 0.0, 8.5, (0, 0, 17.9), "pizarra", segs=8, rz=rz)
    p.cyl(0.12, 0.0, 2.6, (0, 0, 26.0), "hierro", segs=4)
    face = 3.5 * math.cos(math.pi / 8.0)  # la cara plana que da al frente
    p.door(0.0, -face + 0.12, w=1.3, h=2.5, arch=True)
    for z, lit in ((5.0, True), (9.0, False), (13.5, True)):
        p.gothic_window(0.0, z, -face + 0.08, w=0.55, h=1.7, lit=lit)
        p.box((0.2, 0.5, 1.5), (face - 0.05, 0, z), "hueco")
        p.box((0.2, 0.5, 1.5), (-face + 0.05, 0, z), "hueco")
    p.box((0.08, 0.9, 0.08), (1.9, -face - 0.3, 12.2), "hierro")  # el brazo del estandarte
    p.box((1.3, 0.05, 4.4), (1.9, -face - 0.6, 9.95), "lona")
    p.box((0.5, 0.06, 0.5), (1.9, -face - 0.64, 10.6), "hierro", ry=math.pi / 4.0)  # el emblema
    return p.finish()


def obelisco():
    """Obelisco con púa de hierro, para las entradas de la plaza: el gusto del Lord Legislador."""
    p = Piece("PlazaObelisco")
    p.box((1.8, 1.8, 0.3), (0, 0, 0.15), "piedra_oscura")
    p.box((1.4, 1.4, 0.3), (0, 0, 0.45), "piedra_clara")
    p.cyl(0.78, 0.5, 4.2, (0, 0, 0.6), "piedra", segs=4, rz=math.pi / 4.0)
    p.box((1.0, 1.0, 0.16), (0, 0, 4.86), "piedra_clara")
    p.cyl(0.3, 0.0, 3.4, (0, 0, 4.94), "hierro", segs=4, rz=math.pi / 4.0)
    for z in (1.6, 3.0):
        p.box((1.16 - z * 0.12, 1.16 - z * 0.12, 0.1), (0, 0, z), "hierro")
    p.box((1.3, 1.3, 0.04), (0, 0, 0.62), "ceniza")
    return p.finish()


def export(ob, out_dir):
    for o in bpy.context.scene.objects:
        o.select_set(o == ob)
    bpy.context.view_layer.objects.active = ob
    path = os.path.join(out_dir, ob.name + ".gltf")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLTF_SEPARATE", use_selection=True, export_apply=True,
                              export_keep_originals=True, export_tangents=True)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    print("PIEZA %s tris=%d dim=(%.1f, %.1f, %.1f) %s" % (ob.name, tris, *ob.dimensions, path))


def photo(objs, spacing, cam_pos, look, path, ortho):
    """Foto de muestra: las piezas en fila sobre un piso de ceniza, con la luz rojiza del juego."""
    sc = bpy.context.scene
    x = -sum(spacing) / 2.0
    for ob, gap in zip(objs, spacing):
        x += gap / 2.0
        ob.location = (x, 0, 0)
        ob.hide_render = False
        x += gap / 2.0
    for ob in sc.objects:
        if ob.type == "MESH" and ob not in objs and ob.name != "Piso":
            ob.hide_render = True
    cam = sc.camera
    cam.location = cam_pos
    cam.rotation_euler = (Vector(look) - Vector(cam_pos)).to_track_quat("-Z", "Y").to_euler()
    cam.data.ortho_scale = ortho
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def stage():
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_EEVEE"
    except TypeError:
        pass
    sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
    world = bpy.data.worlds.new("Ceniza")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.42, 0.26, 0.19, 1.0)
    bg.inputs["Strength"].default_value = 0.7
    sc.world = world
    sun = bpy.data.objects.new("Sol", bpy.data.lights.new("Sol", "SUN"))
    sun.data.energy = 3.2
    sun.data.color = (1.0, 0.72, 0.55)
    sun.rotation_euler = (math.radians(58), 0, math.radians(-38))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("Camara", bpy.data.cameras.new("Camara"))
    cam.data.type = "ORTHO"
    sc.collection.objects.link(cam)
    sc.camera = cam
    floor = Piece("Piso")
    floor.box((120, 120, 0.2), (0, 0, -0.1), "piedra_oscura")
    floor.finish()


def main():
    global TEX_DIR
    args = sys.argv[sys.argv.index("--") + 1:]
    out_dir = os.path.abspath(args[0])
    TEX_DIR = os.path.join(out_dir, "tex")
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    houses = [casa_conventillo(), casa_tienda(), casa_piedra()]
    gothic = [casa_gotica(), torre_gotica()]
    plaza = [fuente_plaza(), fuente_mercado(), cadalso(), puesto_lona(), puesto_carpa(), carreta(), tablon(), banco(), obelisco()]
    for ob in houses + gothic + plaza:
        export(ob, out_dir)
    if len(args) > 1:
        os.makedirs(args[1], exist_ok=True)
        stage()
        photo(houses, [11, 13, 11], (16, -34, 17), (0, 0, 5.0), os.path.join(args[1], "casas.png"), 40)
        photo(gothic, [18, 13], (18, -40, 24), (0, 0, 9.0), os.path.join(args[1], "gotico.png"), 46)
        photo(plaza, [20, 12, 9, 7, 6, 5, 4.5, 4.5, 4.5], (24, -48, 26), (0, 0, 2.0), os.path.join(args[1], "plaza.png"), 70)


if __name__ == "__main__":
    main()
