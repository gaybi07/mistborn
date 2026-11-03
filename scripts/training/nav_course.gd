extends TrainingRoom
## Pista de navegación: pasar por los aros en orden, contra reloj. Saltos, subidas, caídas a plataformas chicas,
## pasillos y vigas angostas y un empuje de acero. Cada aro guarda el lugar: si caés, volvés al último.
##   Retroceso: volver a empezar.

## Por debajo de esta altura se cuenta como caída.
const FALL_Y := -8.0
const GOLD := Color(1.0, 0.8, 0.3)
const DIM := Color(0.35, 0.5, 0.75, 0.35)
## Mejor tiempo de esta partida (no se guarda al cerrar el juego).
static var best := INF

## [zona, posición, de cara a (null: aro acostado, hay que aterrizar en él)].
var _rings: Array[Dictionary] = []
var _next := 0
var _time := 0.0
var _falls := 0
var _running := false
var _checkpoint_pending := false
var _beam: MeshInstance3D
var _m: Dictionary


func _ready() -> void:
	_build_base(Vector3(300, 80, 300), Vector3(0, 1, 4))
	_m = WorldKit.materials()
	add_child(Props.static_box(Vector3(400, 2, 400), Vector3(60, -15, -40), _m["ground"]))
	_build_course()
	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.12
	cyl.height = 60.0
	cyl.material = _ring_material(Color(GOLD, 0.25))
	_beam.mesh = cyl
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_show_next()


# ---------------------------------------------------------------- Pista

## Plataforma con la cara de arriba en `top`.
func _pad(x: float, top: float, z: float, sx: float, sz: float, mat := "stone", metal := false) -> void:
	add_child(Props.static_box(Vector3(sx, 1.0, sz), Vector3(x, top - 0.5, z), _m[mat], metal))


func _wall(x: float, z: float, sx: float, sz: float) -> void:
	add_child(Props.static_box(Vector3(sx, 5.0, sz), Vector3(x, 2.5, z), _m["wall"]))


func _ring(zone: String, pos: Vector3, facing: Variant = Vector3.BACK, radius := 1.7) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.12
	torus.outer_radius = radius
	var mat := _ring_material(DIM)
	torus.material = mat
	var mesh := MeshInstance3D.new()
	mesh.mesh = torus
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	mesh.position = pos
	if facing != null:
		# El agujero del TorusMesh es su eje Y: va mirando hacia donde se cruza.
		var axis: Vector3 = facing
		mesh.basis = Basis(Quaternion(Vector3.UP, axis.normalized()))
	_rings.append({"zone": zone, "pos": pos, "land": facing == null, "radius": radius, "mesh": mesh, "mat": mat})


func _ring_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	return m


func _build_course() -> void:
	# Calentamiento: correr. Se avanza hacia -Z.
	_pad(0, 0, -8, 6, 24)
	_ring("Calentamiento", Vector3(0, 1.3, -16))
	# Saltos: parado (1,8 m), corriendo (2,6 m) y doble salto (3,4 m).
	_pad(0, 0, -23.8, 4, 4)
	_pad(0, 0, -30.9, 4, 5)
	_ring("Saltos", Vector3(0, 2.0, -35.1))
	_pad(0, 0, -39.8, 5, 6)
	_ring("Saltos", Vector3(0, 1.3, -41))
	# Subida: escalones cada vez más altos y una pared para agarrarse del borde.
	_pad(0, 0.9, -44, 5, 2)
	_pad(0, 2.2, -46.5, 5, 3)
	_pad(0, 3.7, -49.5, 5, 3)
	_wall_step(0, 6.0, -53, 5, 4)
	_ring("Subida", Vector3(0, 7.3, -53))
	# Hacia +X, saltando y subiendo hasta lo alto de la torre.
	_pad(5.8, 7.0, -53, 3, 3)
	_pad(10.6, 8.0, -53, 3, 3)
	_wall_step(16.5, 9.5, -53, 6, 6)
	_ring("Subida", Vector3(16.5, 10.8, -53), Vector3.RIGHT)
	# Aterrizar: caer desde la torre y quedar parado dentro del aro acostado.
	_pad(26.0, 4.0, -53, 4, 4)
	_ring("Aterrizar", Vector3(26.0, 4.1, -53), null)
	_pad(33.5, 0.0, -53, 4, 4)
	_ring("Aterrizar", Vector3(33.5, 0.1, -53), null)
	# Estrecho: zigzag entre paredes con un hueco de 1,3 m, alternando de lado.
	_pad(51.5, 0.0, -53, 32, 10)
	for i in 5:
		var x := 41.0 + i * 5.0
		var gap_z := -53.0 + (3.0 if i % 2 == 0 else -3.0)
		# Dos tramos de pared, uno a cada lado del hueco.
		var lo := gap_z - 0.65
		var hi := gap_z + 0.65
		_wall(x, (-58.0 + lo) / 2.0, 0.6, lo + 58.0)
		_wall(x, (hi - 48.0) / 2.0, 0.6, -48.0 - hi)
	_ring("Estrecho", Vector3(65.0, 1.3, -53), Vector3.RIGHT)
	# Vigas angostas sobre el vacío, con un giro en el medio.
	_pad(73.5, 0.0, -53, 17, 0.6)
	_pad(82.3, 0.0, -53, 1.6, 1.6)
	_ring("Vigas", Vector3(82.3, 1.3, -53), Vector3.RIGHT)
	_pad(82.3, 0.0, -60.8, 0.5, 14)
	_pad(82.3, 0.0, -69.5, 5, 4)
	# Empuje de acero: una placa de hierro bajo el aro (quemá acero y empujá hacia abajo).
	_pad(82.3, 0.0, -76, 7, 9)
	_pad(82.3, 0.05, -76, 3, 3, "iron", true)
	_ring("Empuje de acero", Vector3(82.3, 11.0, -76), Vector3.UP, 2.2)
	# Llegada: bajar en un aro acostado.
	_pad(82.3, 0.0, -88, 8, 8)
	_ring("Llegada", Vector3(82.3, 0.1, -88), null, 3.0)


## Bloque macizo hasta el suelo de la pista: pared para agarrarse del borde, sin hueco por debajo.
func _wall_step(x: float, top: float, z: float, sx: float, sz: float) -> void:
	add_child(Props.static_box(Vector3(sx, top + 1.0, sz), Vector3(x, (top - 1.0) / 2.0, z), _m["stone"]))


# ---------------------------------------------------------------- Juego

func _process(delta: float) -> void:
	if _next >= _rings.size():
		return
	if _running:
		_time += delta
	# Se guarda el lugar al pisar: un aro en el aire no te hace reaparecer flotando.
	if _checkpoint_pending and player.is_on_floor():
		_checkpoint_pending = false
		player.spawn_point = player.global_position
	if player.global_position.y < FALL_Y:
		_falls += 1
		_back_to_checkpoint()
	var ring: Dictionary = _rings[_next]
	if _passed(ring):
		_pass_ring(ring)
	if _next < _rings.size():
		var to := player.chest_position().distance_to(_rings[_next]["pos"])
		_banner.text = "%s · aro %d/%d · a %d m\n%s · caídas %d" % [_rings[_next]["zone"], _next + 1, _rings.size(), roundi(to), _clock(_time), _falls]


func _passed(ring: Dictionary) -> bool:
	var pos: Vector3 = ring["pos"]
	if ring["land"]:
		var flat := Vector2(player.global_position.x - pos.x, player.global_position.z - pos.z)
		return player.is_on_floor() and flat.length() < ring["radius"] and absf(player.global_position.y - pos.y) < 0.6
	return player.chest_position().distance_to(pos) < ring["radius"] + 0.3


func _pass_ring(ring: Dictionary) -> void:
	_running = true
	Fx.sparks(self, ring["pos"], GOLD)
	Fx.shockwave(self, ring["pos"], ring["radius"] * 1.6, GOLD, 0.3)
	ring["mesh"].visible = false
	_checkpoint_pending = true
	_refill()
	_next += 1
	if _next >= _rings.size():
		_finish()
	else:
		_show_next()


func _show_next() -> void:
	var ring: Dictionary = _rings[_next]
	ring["mat"].albedo_color = GOLD
	_beam.position = ring["pos"]


func _finish() -> void:
	_beam.visible = false
	var record := _time < best
	if record:
		best = _time
	_banner.text = "¡Llegaste! %s · caídas %d%s\nRetroceso: otra vez" % [_clock(_time), _falls, " · mejor tiempo" if record else " · mejor: " + _clock(best)]


func _back_to_checkpoint() -> void:
	player.respawn()
	_refill()


func _clock(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_BACKSPACE:
		get_tree().reload_current_scene()
