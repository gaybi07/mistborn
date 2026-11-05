class_name AirFx
## Efectos de los poderes: ondas que deforman el aire y bruma que se deshace. Nada de chispas ni sprites.
## Todo se arma con dos shaders (shaders/air_wave.gdshader y shaders/air_mist.gdshader), con pocos quads por efecto.

const WAVE_SHADER := preload("res://shaders/air_wave.gdshader")
const MIST_SHADER := preload("res://shaders/air_mist.gdshader")

## Colores de cada metal, apagados para que encajen con la ceniza. El alfa es la densidad de la bruma: casi transparente,
## la onda es la que se tiene que notar.
const STEEL := Color(0.5, 0.68, 0.95, 0.2)
const IRON := Color(0.62, 0.78, 0.9, 0.2)
const PEWTER := Color(0.85, 0.36, 0.2, 0.22)
const TIN := Color(0.9, 0.84, 0.66, 0.16)
const ASH := Color(0.42, 0.38, 0.35, 0.34)
const GOLD := Color(0.95, 0.82, 0.5, 0.2)


## Una onda sola. facing: null = de frente a la cámara, si no, hacia dónde mira el frente (Vector3.UP = en el piso).
## inward: se cierra hacia el centro en vez de abrirse.
static func wave(parent: Node, pos: Vector3, radius: float, color: Color, time := 0.5, strength := 0.03,
		facing: Variant = null, inward := false) -> void:
	var q := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(radius, radius) * 2.0
	q.mesh = quad
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = WAVE_SHADER
	m.set_shader_parameter(&"tint", color)
	m.set_shader_parameter(&"strength", strength)
	m.set_shader_parameter(&"seed", randf() * 50.0)
	q.material_override = m
	parent.add_child(q)
	q.global_position = pos
	_face(q, pos, facing)
	var from := 0.85 if inward else 0.05
	var tw := q.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter(&"progress", v), from, 0.85 - from + 0.05, time) \
			.set_trans(Tween.TRANS_QUART if not inward else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if not inward else Tween.EASE_IN)
	tw.parallel().tween_method(func(v: float) -> void: m.set_shader_parameter(&"fade", v), 1.0, 0.0, time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(q.queue_free)


## Un jirón de bruma que crece, se corre con drift (m/s) y se deshace.
static func mist(parent: Node, pos: Vector3, size: float, color: Color, time := 1.2, drift := Vector3.ZERO) -> void:
	var q := _mist_quad(color)
	parent.add_child(q)
	q.global_position = pos
	q.scale = Vector3.ONE * size * 0.55
	var m := q.material_override as ShaderMaterial
	var tw := q.create_tween()
	tw.tween_property(q, "scale", Vector3.ONE * size, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(q, "global_position", pos + drift * time, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(v: float) -> void: m.set_shader_parameter(&"dissolve", v), 0.0, 1.0, time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(q.queue_free)


## Varios jirones alrededor de un punto, saliendo hacia afuera.
static func cloud(parent: Node, pos: Vector3, size: float, color: Color, time := 1.2, count := 4, speed := 1.0) -> void:
	for i in count:
		var out := Vector3(randf_range(-1, 1), randf_range(-0.3, 0.6), randf_range(-1, 1)).normalized()
		mist(parent, pos + out * size * 0.2, size * randf_range(0.7, 1.1), color, time * randf_range(0.75, 1.1), out * speed)


## Empuje: el aire sale disparado hacia dir en frentes sucesivos, arrastrando bruma. power escala todo.
static func push(parent: Node, from: Vector3, dir: Vector3, color: Color, power := 1.0) -> void:
	for i in 3:
		var at := from + dir * (0.5 + i * 0.9) * power
		_later(parent, i * 0.05, wave.bind(parent, at, (0.9 + i * 0.5) * power, color, 0.4, 0.035 * power, dir))
	for i in 2:
		var side := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.25 * power
		mist(parent, from + dir * (1.0 + i * 1.2) * power + side, 0.9 * power, Color(color, color.a * 0.55), 0.8, dir * 3.5 * power)


## Tirón: el aire se cierra sobre `at` y la bruma corre hacia `to`.
static func pull(parent: Node, at: Vector3, to: Vector3, color: Color, power := 1.0) -> void:
	wave(parent, at, 1.5 * power, color, 0.45, 0.035 * power, null, true)
	var dir := (to - at).normalized()
	for i in 3:
		mist(parent, at + dir * i * 0.7, 0.8 * power, Color(color, color.a * 0.6), 0.7, dir * 4.0)


## Onda por el piso: el aire se deforma y un anillo de ceniza corre hasta `radius`.
static func ground(parent: Node, pos: Vector3, radius: float, color: Color, time := 0.7, inward := false) -> void:
	var at := pos + Vector3(0, 0.25, 0)
	wave(parent, at, radius, color, time, 0.035, Vector3.UP, inward)
	var count := clampi(int(radius * 1.5), 4, 9)
	for i in count:
		var a := TAU * i / count + randf() * 0.4
		var out := Vector3(cos(a), 0.05, sin(a))
		var start := at + out * (radius * 0.75 if inward else radius * 0.15)
		mist(parent, start, minf(radius * 0.25 + 0.5, 1.8), color, time * 1.5, -out * radius * 0.55 if inward else out * radius * 0.8)


## Golpe: una onda chiquita y un poco de bruma donde pegó.
static func impact(parent: Node, pos: Vector3, color: Color, size := 1.0) -> void:
	wave(parent, pos, 1.1 * size, color, 0.3, 0.03)
	cloud(parent, pos, 0.8 * size, color, 0.7, 2, 0.7)


## Bruma alrededor de `holder` mientras alive sea verdadero. ring: además, una onda quieta a ese radio (0 = sin onda).
static func shell(holder: Node3D, color: Color, radius: float, alive: Callable, height := 1.0, count := 5, ring := 0.0) -> void:
	var s := _Shell.new()
	s.holder = holder
	s.alive = alive
	s.height = height
	s.radius = radius
	holder.get_tree().current_scene.add_child(s)
	s.build(color, count, ring)


## Estela de bruma detrás de `holder` mientras alive sea verdadero. Sin alive, hasta que holder desaparezca.
static func trail(holder: Node3D, color: Color, size: float, alive := Callable(), height := 1.0) -> void:
	var t := _Trail.new()
	t.holder = holder
	t.alive = alive
	t.color = color
	t.size = size
	t.height = height
	holder.get_tree().current_scene.add_child(t)


## Material de bruma para partículas (ver MistSwirl y PewterAura): la curva de vida del sistema le da el alfa.
static func mist_material(color: Color, dissolve := 0.2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = MIST_SHADER
	m.set_shader_parameter(&"tint", color)
	m.set_shader_parameter(&"dissolve", dissolve)
	m.set_shader_parameter(&"seed", randf() * 50.0)
	return m


static func _mist_quad(color: Color) -> MeshInstance3D:
	var q := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	q.mesh = quad
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.material_override = mist_material(color, 0.0)
	return q


static func _face(q: Node3D, pos: Vector3, facing: Variant) -> void:
	var normal: Vector3
	if facing == null:
		var cam := q.get_viewport().get_camera_3d()
		normal = (cam.global_position - pos).normalized() if cam else Vector3.BACK
	else:
		normal = facing
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	q.global_basis = Basis.looking_at(-normal, up)


static func _later(parent: Node, delay: float, call_it: Callable) -> void:
	if delay <= 0.0:
		call_it.call()
	else:
		parent.get_tree().create_timer(delay).timeout.connect(call_it)


class _Shell extends Node3D:
	var holder: Node3D
	var alive: Callable
	var height := 1.0
	var radius := 1.0
	var _spin := 0.0
	var _puffs: Array[MeshInstance3D] = []
	var _ring: MeshInstance3D
	var _level := 0.0
	var _ending := false

	func build(color: Color, count: int, ring: float) -> void:
		for i in count:
			var q := AirFx._mist_quad(color)
			q.scale = Vector3.ONE * radius * randf_range(0.6, 0.85)
			add_child(q)
			_puffs.append(q)
		if ring > 0.0:
			_ring = MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(ring, ring) * 2.0
			_ring.mesh = quad
			_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var m := ShaderMaterial.new()
			m.shader = AirFx.WAVE_SHADER
			m.set_shader_parameter(&"tint", Color(color, color.a * 0.35))
			m.set_shader_parameter(&"strength", 0.018)
			m.set_shader_parameter(&"progress", 0.8)
			m.set_shader_parameter(&"band", 0.1)
			_ring.material_override = m
			add_child(_ring)
		_process(0.0)

	func _process(delta: float) -> void:
		if not is_instance_valid(holder):
			queue_free()
			return
		_ending = _ending or not alive.call()
		_level = move_toward(_level, 0.0 if _ending else 1.0, delta * (1.2 if _ending else 2.5))
		if _ending and _level <= 0.0:
			queue_free()
			return
		global_position = holder.global_position + Vector3(0, height, 0)
		_spin += delta * 0.7
		for i in _puffs.size():
			var a := _spin + TAU * i / _puffs.size()
			var lift := sin(_spin * 1.3 + i * 2.1) * radius * 0.45
			_puffs[i].position = Vector3(cos(a) * radius, lift, sin(a) * radius)  # alrededor: el cuerpo se sigue viendo
			(_puffs[i].material_override as ShaderMaterial).set_shader_parameter(&"dissolve", 1.0 - _level * 0.8)
		if _ring:
			var cam := get_viewport().get_camera_3d()
			if cam:
				AirFx._face(_ring, global_position, null)
			(_ring.material_override as ShaderMaterial).set_shader_parameter(&"fade", _level * (0.75 + 0.25 * sin(_spin * 4.0)))


class _Trail extends Node:
	const EVERY := 0.07
	var holder: Node3D
	var alive: Callable
	var color: Color
	var size := 1.0
	var height := 1.0
	var _wait := 0.0

	func _process(delta: float) -> void:
		if not is_instance_valid(holder) or (alive.is_valid() and not alive.call()):
			queue_free()
			return
		_wait -= delta
		if _wait <= 0.0:
			_wait = EVERY
			AirFx.mist(get_parent(), holder.global_position + Vector3(0, height, 0), size, color, 0.9)
