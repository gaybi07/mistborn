class_name Telegraph
extends MeshInstance3D
## Aviso en el piso de dónde va a pegar un poder: se llena en `time` segundos y destella al pegar. La forma es la misma
## que usa el daño (ver LordPowers): lo que se ve es lo que pega.
## follow: el aviso sigue a ese nodo hasta LOCK segundos antes del golpe (ahí se fija y se puede esquivar).
## alive: si devuelve falso (al que lo tira lo aturdieron), se apaga sin destello.

const RED := Color(1.0, 0.16, 0.1, 1.0)
const BLUE := Color(0.45, 0.65, 1.0, 0.9)
const CYAN := Color(0.55, 0.85, 1.0, 0.9)
const VIOLET := Color(0.7, 0.4, 1.0, 0.9)
const GREY := Color(0.6, 0.6, 0.62, 0.7)
const LOCK := 0.35
const FLASH := 0.12
const FADE_OUT := 0.3
const SHADER := preload("res://shaders/telegraph.gdshader")

var time := 1.0
var follow: Node3D
var line_to: Node3D  # línea: de `follow` a este nodo
var alive := Callable()
var _t := 0.0
var _mat: ShaderMaterial
var _done := false
var _end := 0.0
var _width := 0.0
var _solid := false
var _length := 0.0  # franja: su largo (para retarget)


static func _make(parent: Node, shape: int, size: Vector2, time: float, color: Color) -> Telegraph:
	var t := Telegraph.new()
	var plane := PlaneMesh.new()
	plane.size = size
	t.mesh = plane
	t._mat = ShaderMaterial.new()
	t._mat.shader = SHADER
	t._mat.set_shader_parameter("shape", shape)
	t._mat.set_shader_parameter("color", color)
	t._mat.render_priority = 1
	t.material_override = t._mat
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.time = maxf(time, 0.05)
	parent.add_child(t)
	return t


## Círculo de `radius` m en `pos` (o siguiendo a `follow`).
static func disc(parent: Node, pos: Vector3, radius: float, time: float, color := RED, follow_node: Node3D = null) -> Telegraph:
	var t := _make(parent, 0, Vector2.ONE * radius * 2.0, time, color)
	t._mat.set_shader_parameter("edge", clampf(0.12 / radius, 0.01, 0.2))
	t.follow = follow_node
	t._place(pos)
	return t


## Anillo: dentro de `outer` pero fuera de `inner`.
static func ring(parent: Node, pos: Vector3, inner_r: float, outer_r: float, time: float, color := RED) -> Telegraph:
	var t := _make(parent, 1, Vector2.ONE * outer_r * 2.0, time, color)
	t._mat.set_shader_parameter("inner", inner_r / outer_r)
	t._mat.set_shader_parameter("edge", clampf(0.12 / outer_r, 0.01, 0.2))
	t._place(pos)
	return t


## Cono desde `pos` hacia `dir`, de `reach` m y `half` radianes para cada lado.
static func cone(parent: Node, pos: Vector3, dir: Vector3, reach: float, half: float, time: float, color := RED) -> Telegraph:
	var t := _make(parent, 2, Vector2.ONE * reach * 2.0, time, color)
	t._mat.set_shader_parameter("half_angle", half)
	t._mat.set_shader_parameter("edge", clampf(0.12 / reach, 0.01, 0.2))
	t._place(pos)
	t._aim(dir)
	return t


## Franja recta desde `from` hacia `dir`: `length` de largo y `width` de ancho.
static func strip(parent: Node, from: Vector3, dir: Vector3, length: float, width: float, time: float, color := RED) -> Telegraph:
	var t := _make(parent, 3, Vector2(width, length), time, color)
	t._mat.set_shader_parameter("edge", clampf(0.1 / length, 0.005, 0.1))
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	t._length = length
	t._place(from + flat * length * 0.5)
	t._aim(flat)
	return t


## Línea fina de `from_node` a `to_node` que los sigue hasta fijarse: te está apuntando.
static func line(parent: Node, from_node: Node3D, to_node: Node3D, time: float, color := RED, width := 0.35) -> Telegraph:
	var t := _make(parent, 3, Vector2(width, 1.0), time, color)
	t._mat.set_shader_parameter("edge", 0.02)
	t.follow = from_node
	t.line_to = to_node
	t._width = width
	t._update_line()
	return t


## Mueve un cono o una franja a otro origen y dirección (la zona de apuntado del jugador).
func retarget(from: Vector3, dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	_place(from + flat * _length * 0.5 if _length > 0.0 else from)
	_aim(flat)


## Solo el borde, sin relleno: zonas que no dañan (el campo magnético, la nube de cobre).
func outline_only() -> Telegraph:
	_mat.set_shader_parameter("fill", false)
	return self


## Relleno completo desde ya: la ola de calor, que se mueve sola (set_ring).
func solid() -> Telegraph:
	_solid = true
	_mat.set_shader_parameter("progress", 1.0)
	return self


## Anillo entre `inner_r` y `outer_r` m (lo mueve quien lo creó).
func set_ring(inner_r: float, outer_r: float) -> void:
	(mesh as PlaneMesh).size = Vector2.ONE * outer_r * 2.0
	_mat.set_shader_parameter("inner", inner_r / outer_r)
	_mat.set_shader_parameter("edge", clampf(0.1 / outer_r, 0.01, 0.2))


## Dónde estaba fijado al pegar (para el daño).
func center() -> Vector3:
	return global_position


func _place(pos: Vector3) -> void:
	var at := pos
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space:
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 1.5, pos + Vector3.DOWN * 4.0, Props.LAYER_WORLD)
		var hit := space.intersect_ray(q)
		if hit:
			at.y = hit["position"].y
	global_position = at + Vector3.UP * 0.04


func _aim(dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() > 1e-4:
		global_basis = Basis.looking_at(flat.normalized(), Vector3.UP)


func _update_line() -> void:
	if not is_instance_valid(follow) or not is_instance_valid(line_to):
		return
	var a := follow.global_position
	var b := line_to.global_position
	var span := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := maxf(span.length(), 0.5)
	(mesh as PlaneMesh).size = Vector2(_width, length)
	_place(a + span * 0.5)
	_aim(span)


func _process(delta: float) -> void:
	_t += delta
	if _done:
		_end += delta
		var k := _end / FADE_OUT
		_mat.set_shader_parameter("flash", maxf(1.0 - _end / FLASH, 0.0) if _mat.get_shader_parameter("flash") > 0.0 else 0.0)
		_mat.set_shader_parameter("fade", 1.0 - k)
		if k >= 1.0:
			queue_free()
		return
	if alive.is_valid() and not alive.call():
		_finish(false)
		return
	var left := time - _t
	if left > LOCK:
		if line_to != null:
			_update_line()
		elif is_instance_valid(follow):
			_place(follow.global_position)
	var k := clampf(_t / time, 0.0, 1.0)
	if not _solid:
		_mat.set_shader_parameter("progress", k * k * (3.0 - 2.0 * k))  # empieza y termina despacio
	if _t >= time:
		_finish(true)


func _finish(hit: bool) -> void:
	_done = true
	_end = 0.0
	_mat.set_shader_parameter("progress", 1.0 if hit else _mat.get_shader_parameter("progress"))
	_mat.set_shader_parameter("flash", 1.0 if hit else 0.0)
