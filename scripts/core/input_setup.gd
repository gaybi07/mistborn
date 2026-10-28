extends Node
## Registra las acciones de entrada por código (así no hace falta tocar el Mapa de Entrada)
## y cambia de escenario: F1 ciudad, F2 arena.
## Las teclas de metales (1-4 y Z X C V B) se leen directamente en player.gd.


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var scene := ""
	if event.keycode == KEY_F1:
		scene = "res://scenes/main.tscn"
	elif event.keycode == KEY_F2:
		scene = "res://scenes/arena.tscn"
	if scene != "" and get_tree().current_scene.scene_file_path != scene:
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file(scene)


func _enter_tree() -> void:
	_key(&"move_forward", KEY_W)
	_key(&"move_back", KEY_S)
	_key(&"move_left", KEY_A)
	_key(&"move_right", KEY_D)
	_key(&"jump", KEY_SPACE)
	_key(&"throw_coin", KEY_Q)
	_key(&"drop_coin", KEY_G)
	_key(&"stop_burning", KEY_N)
	_key(&"anchor", KEY_R)
	_key(&"drop_bag", KEY_F)
	_wheel(&"weapon_cycle")
	_key(&"attack", KEY_E)
	_key(&"roll", KEY_SHIFT)
	_key(&"hood", KEY_H)
	_key(&"inventory", KEY_I)
	_key(&"drink", KEY_T)
	_key(&"metal_wheel", KEY_TAB)
	# Con acero y hierro encendidos: clic izquierdo tira, clic derecho empuja.
	# Con uno solo, cualquiera de los dos clics lo usa (ver SteelIron).
	_mouse(&"pull", MOUSE_BUTTON_LEFT)
	_mouse(&"push", MOUSE_BUTTON_RIGHT)


func _ensure(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


func _key(action: StringName, key: Key) -> void:
	_ensure(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _wheel(action: StringName) -> void:
	_mouse(action, MOUSE_BUTTON_WHEEL_UP)
	_mouse(action, MOUSE_BUTTON_WHEEL_DOWN)


func _mouse(action: StringName, button: MouseButton) -> void:
	_ensure(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
