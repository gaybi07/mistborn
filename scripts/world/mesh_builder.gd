class_name MeshBuilder
extends RefCounted
## Junta muchas piezas (cajas, prismas, agujas, tejados) en una sola malla con una superficie por
## material: pocas llamadas de dibujo para edificios enteros (Kredik Shaw por fuera y por dentro).
## Las caras se orientan solas: hacia afuera de un punto interior que se pasa en cada pieza.

var _st := {}  # material -> SurfaceTool
## Se suma a todas las piezas (para armar lo mismo a otra altura).
var offset := Vector3.ZERO


func _tool(key: String) -> SurfaceTool:
	if not _st.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[key] = st
	return _st[key]


## Triángulo con la cara hacia afuera de `inside` (normal plana: aristas marcadas).
func tri(key: String, a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
	a += offset
	b += offset
	c += offset
	inside += offset
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	var st := _tool(key)
	st.set_normal(n.normalized())
	# Godot dibuja de frente los triángulos en sentido horario.
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)


func quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3) -> void:
	tri(key, a, b, c, inside)
	tri(key, a, c, d, inside)


## Caja en el espacio de xf (centro en el origen de xf). bottom = false: sin la cara de abajo.
func cube(key: String, xf: Transform3D, size: Vector3, bottom := true) -> void:
	var e := size / 2.0
	var p := func(x: float, y: float, z: float) -> Vector3: return xf * Vector3(x * e.x, y * e.y, z * e.z)
	var o := xf.origin
	quad(key, p.call(-1, 1, -1), p.call(1, 1, -1), p.call(1, 1, 1), p.call(-1, 1, 1), o)
	if bottom:
		quad(key, p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, -1, 1), p.call(-1, -1, 1), o)
	for s in [-1.0, 1.0]:
		quad(key, p.call(s, -1, -1), p.call(s, 1, -1), p.call(s, 1, 1), p.call(s, -1, 1), o)
		quad(key, p.call(-1, -1, s), p.call(1, -1, s), p.call(1, 1, s), p.call(-1, 1, s), o)


## Caja alineada con los ejes del mundo.
func abox(key: String, center: Vector3, size: Vector3, bottom := true) -> void:
	cube(key, Transform3D(Basis(), center), size, bottom)


## Tronco de pirámide/prisma de `sides` lados (r1 = 0: aguja) con su tapa.
func frustum(key: String, base: Vector3, r0: float, r1: float, h: float, sides: int, rot := 0.0, bottom := false) -> void:
	var inside := base + Vector3(0, h * 0.3, 0)
	var top := base + Vector3(0, h, 0)
	for i in sides:
		var a0 := rot + TAU * i / sides
		var a1 := rot + TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		if r1 <= 0.0:
			tri(key, base + d0 * r0, base + d1 * r0, top, inside)
		else:
			quad(key, base + d0 * r0, base + d1 * r0, top + d1 * r1, top + d0 * r1, inside)
			tri(key, top, top + d0 * r1, top + d1 * r1, inside)
		if bottom:
			tri(key, base, base + d0 * r0, base + d1 * r0, inside)


## Anillo (muro curvo) entre los ángulos a0 y a1: radio r, grosor t, de y0 a y1.
func arc_wall(key: String, c: Vector3, r: float, t: float, y0: float, y1: float, a0: float, a1: float, steps: int) -> void:
	for i in steps:
		var b0 := lerpf(a0, a1, float(i) / steps)
		var b1 := lerpf(a0, a1, float(i + 1) / steps)
		var mid := (b0 + b1) / 2.0
		var d := Vector3(cos(mid), 0, sin(mid))
		var length := 2.0 * (r + t / 2.0) * sin((b1 - b0) / 2.0) + 0.05
		var x := Vector3(-d.z, 0, d.x)
		cube(key, Transform3D(Basis(x, Vector3.UP, d), c + d * r + Vector3(0, (y0 + y1) / 2.0, 0)), Vector3(length, y1 - y0, t))


## Tejado a dos aguas (cumbrera a lo largo del eje x local) sobre la base de xf.
func gable(key: String, xf: Transform3D, w: float, d: float, h: float) -> void:
	var p := func(x: float, y: float, z: float) -> Vector3: return xf * Vector3(x, y, z)
	var o: Vector3 = p.call(0, h * 0.3, 0)
	var r0: Vector3 = p.call(-w / 2.0, h, 0)
	var r1: Vector3 = p.call(w / 2.0, h, 0)
	for s in [-1.0, 1.0]:
		quad(key, p.call(-w / 2.0, 0, s * d / 2.0), p.call(w / 2.0, 0, s * d / 2.0), r1, r0, o)
		var x: float = s * w / 2.0
		tri(key, p.call(x, 0, -d / 2.0), p.call(x, 0, d / 2.0), p.call(x, h, 0), o)


func has(key: String) -> bool:
	return _st.has(key)


## Una malla con una superficie por material, cada una con el nombre de su material.
func commit(keys: Array = []) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for key: String in (keys if not keys.is_empty() else _st.keys()):
		if not _st.has(key):
			continue
		_st[key].commit(mesh)
		mesh.surface_set_name(mesh.get_surface_count() - 1, key)
	return mesh
