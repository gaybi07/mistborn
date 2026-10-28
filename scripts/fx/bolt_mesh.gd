class_name BoltMesh
extends MeshInstance3D
## Dibuja los hilos de bruma azul de acero/hierro: cintas orientadas a cámara que serpentean
## como un rayo y siempre conectan los dos extremos. Lo usan el jugador (SteelIron) y los PNJ.
## Uso por frame: begin(), add(...) por cada línea, end().

const LINE_SHADER := preload("res://shaders/metal_line.gdshader")

var _mesh := ImmediateMesh.new()
var _mist_mat := ShaderMaterial.new()
var _core_mat := ShaderMaterial.new()
var _bolts := []  # [puntos, ancho, color, flujo, semilla, núcleo]


func _ready() -> void:
	_mist_mat.shader = LINE_SHADER
	_core_mat.shader = LINE_SHADER
	_core_mat.set_shader_parameter(&"core", 1.0)
	mesh = _mesh
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	global_transform = Transform3D.IDENTITY


func begin() -> void:
	_bolts.clear()


## amp: cuánto serpentea (fracción de la longitud); energetic: saltos más rápidos;
## core: añade el núcleo fino y brillante (líneas en uso).
func add(a: Vector3, b: Vector3, width_per_meter: float, col: Color, flow: float, seed: float,
		amp: float, energetic := false, core := false) -> PackedVector3Array:
	var pts := bolt_path(a, b, seed, amp, Time.get_ticks_msec() / 1000.0, energetic)
	_bolts.append([pts, width_per_meter, col, flow, seed, core])
	return pts


func end() -> void:
	_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if _bolts.is_empty() or cam == null:
		return
	var eye := cam.global_position
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mist_mat)
	for b in _bolts:
		_ribbon(b[0], b[1], b[2], eye, b[3], b[4])
	_mesh.surface_end()
	var cores := _bolts.filter(func(b): return b[5])
	if not cores.is_empty():
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _core_mat)
		for b in cores:
			var col: Color = b[2]
			_ribbon(b[0], 0.007, Color(col.r * 0.8, col.g * 0.9, col.b, 0.85), eye, b[3], b[4])
		_mesh.surface_end()


## Recorrido tipo rayo: serpentea de forma suave y además da pequeños saltos aleatorios
## (cambian ~14 veces por segundo). El desvío es cero en los extremos: siempre conecta.
static func bolt_path(a: Vector3, b: Vector3, seed: float, amp: float, t: float, energetic: bool) -> PackedVector3Array:
	var seg := b - a
	var length := seg.length()
	if amp <= 0.0 or length < 0.5:
		return PackedVector3Array([a, b])
	var dir := seg / length
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.1:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(dir)
	var n := clampi(int(length / 1.5), 3, 12)
	var size := minf(length * amp, 1.2)
	var jump := floorf(t * (20.0 if energetic else 14.0))
	var pts := PackedVector3Array([a])
	for i in range(1, n):
		var f := float(i) / n
		var x := f * length
		var envelope := sin(PI * f)
		var ws := sin(x * 0.9 + t * 2.3 + seed) * 0.6 + sin(x * 2.1 - t * 3.7 + seed * 1.9) * 0.4
		var wu := sin(x * 1.1 - t * 2.9 + seed * 0.7) * 0.6 + sin(x * 2.6 + t * 4.1 + seed * 2.3) * 0.4
		var cs := _hash(seed + i * 13.1 + jump) - 0.5
		var cu := _hash(seed * 1.3 + i * 7.7 + jump) - 0.5
		pts.append(a + seg * f + (side * (ws + cs * 0.9) + up * (wu + cu * 0.9)) * size * envelope)
	pts.append(b)
	return pts


static func _hash(x: float) -> float:
	return fposmod(sin(x * 12.9898) * 43758.5453, 1.0)


## Cinta orientada a cámara a lo largo de una polilínea, con grosor proporcional a la distancia
## a la cámara (≈ grosor constante en pantalla).
func _ribbon(pts: PackedVector3Array, width_per_meter: float, col: Color, cam: Vector3, flow: float, seed: float) -> void:
	var along := 0.0
	for i in pts.size() - 1:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var s0 := _side(pts, i, cam) * width_per_meter * cam.distance_to(p0)
		var s1 := _side(pts, i + 1, cam) * width_per_meter * cam.distance_to(p1)
		var next := along + p0.distance_to(p1)
		_vertex(p0 - s0, Vector2(along, 0), col, flow, seed)
		_vertex(p0 + s0, Vector2(along, 1), col, flow, seed)
		_vertex(p1 + s1, Vector2(next, 1), col, flow, seed)
		_vertex(p0 - s0, Vector2(along, 0), col, flow, seed)
		_vertex(p1 + s1, Vector2(next, 1), col, flow, seed)
		_vertex(p1 - s1, Vector2(next, 0), col, flow, seed)
		along = next


func _side(pts: PackedVector3Array, i: int, cam: Vector3) -> Vector3:
	var tangent := pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]
	return tangent.cross(cam - pts[i]).normalized()


func _vertex(pos: Vector3, uv: Vector2, col: Color, flow: float, seed: float) -> void:
	_mesh.surface_set_color(col)
	_mesh.surface_set_uv(uv)
	_mesh.surface_set_uv2(Vector2(flow, seed))
	_mesh.surface_add_vertex(pos)
