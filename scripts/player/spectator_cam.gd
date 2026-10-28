class_name SpectatorCam
extends Camera3D
## Cámara del modo espectador de la arena.
##   Libre: WASD para moverte, Q/E bajar/subir, Shift rápido, mantén clic derecho para mirar.
##   Tab: sigue al siguiente luchador (gira alrededor con el ratón). Retroceso: vuelve a la libre.

@export var speed := 10.0
@export var sensitivity := 0.003

var _yaw := 0.0
var _pitch := -0.35
var _follow: Node3D = null
var _follow_index := -1
var _orbit_dist := 7.0


func _ready() -> void:
	current = true
	far = 2500.0
	rotation = Vector3(_pitch, _yaw, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= event.relative.x * sensitivity
		_pitch = clampf(_pitch - event.relative.y * sensitivity, -1.4, 1.2)
	elif event is InputEventMouseButton and event.pressed and _follow:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_orbit_dist = maxf(_orbit_dist - 0.7, 2.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_orbit_dist = minf(_orbit_dist + 0.7, 25.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_next_fighter()
		elif event.keycode == KEY_BACKSPACE:
			_follow = null


func _next_fighter() -> void:
	var fighters := get_tree().get_nodes_in_group(&"allomancer").filter(func(n): return not n.down)
	if fighters.is_empty():
		_follow = null
		return
	_follow_index = (_follow_index + 1) % fighters.size()
	_follow = fighters[_follow_index]


func _process(delta: float) -> void:
	var rd := delta / Engine.time_scale
	rotation = Vector3(_pitch, _yaw, 0)
	if _follow and is_instance_valid(_follow):
		var focus := _follow.global_position + Vector3(0, 1.2, 0)
		var back := Basis.from_euler(Vector3(_pitch, _yaw, 0)) * Vector3(0, 0, _orbit_dist)
		global_position = global_position.lerp(focus + back, minf(rd * 6.0, 1.0))
		return
	var input := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input.z -= 1
	if Input.is_key_pressed(KEY_S):
		input.z += 1
	if Input.is_key_pressed(KEY_A):
		input.x -= 1
	if Input.is_key_pressed(KEY_D):
		input.x += 1
	if Input.is_key_pressed(KEY_E):
		input.y += 1
	if Input.is_key_pressed(KEY_Q):
		input.y -= 1
	var fast := 3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	global_position += global_basis * input.normalized() * speed * fast * rd
