extends Node
## Registra las acciones de entrada por código (así no hace falta tocar el Mapa de Entrada)
## y cambia de escenario: Ctrl+F1 ciudad, Ctrl+F2 arena.
## Las teclas de metales (F1 a F9) se leen directamente en player.gd.


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var scene := ""
	if not event.ctrl_pressed:
		return  # F1-F9 son los metales (ver Allomancy)
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
	_key(&"stop_burning", KEY_N)
	_key(&"anchor", KEY_Y)
	_key(&"drop_bag", KEY_B)
	_wheel(&"weapon_cycle")
	_mouse(&"attack", MOUSE_BUTTON_LEFT)
	_mouse(&"coin_shot", MOUSE_BUTTON_RIGHT)
	_key(&"roll", KEY_SHIFT)
	_key(&"block", KEY_CTRL)  # mantener: bloquear; pulsar justo antes del golpe: parry
	_key(&"hood", KEY_H)
	_key(&"inventory", KEY_I)
	_key(&"skill_tree", KEY_K)
	_key(&"drink", KEY_T)
	_key(&"metal_wheel", KEY_TAB)
	_key(&"map", KEY_M)
	_key(&"interact", KEY_E)  # puertas y armarios; donde hay algo que usar, la ranura en E no se activa


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
