extends Node
## Uso: Godot --headless --path . res://tools/anim_check/run_jump_check.tscn
## (con --headless: con ventana, si pierde el foco el juego se pausa y los números salen cualquier cosa).
## En la sala de poderes, con Vin y sin metales: corre con W y salta (Espacio, sin acero). Mide la velocidad horizontal
## real (por cuánto se mueve, no player.velocity) antes, en el aire y al caer, y cuánto avanza en 3 s comparado con
## correr sin saltar. Saltar corriendo no debería frenarte.


func _ready() -> void:
	Art.player_model = "vin"
	var room: TrainingRoom = load("res://scenes/skill_room.tscn").instantiate()
	add_child(room)
	var tree := get_tree()
	for i in 60: await tree.physics_frame
	var player: Player = room.player
	for m: StringName in Allomancy.METALS:
		player.allomancy.set_state(m, Allomancy.State.OFF)
	await _run(player, tree, false)  # la primera sale lenta (la sala recién cargada): no cuenta
	var plain := await _run(player, tree, false)
	var jumping := await _run(player, tree, true)
	print("corriendo sin saltar: %.2f m en 3 s" % plain)
	print("corriendo y saltando: %.2f m en 3 s (%+.2f m)" % [jumping, jumping - plain])
	print("RESULTADO: ", "bien" if jumping >= plain - 0.3 else "saltar te frena")
	tree.quit()


## Corre 3 s para tomar velocidad y después mide 3 s, saltando (o no) al principio de esos 3 s.
func _run(player: Player, tree: SceneTree, jump: bool) -> float:
	var hz := float(Engine.physics_ticks_per_second)
	player.global_position = Vector3(0, 1.0, 30.0)
	player.velocity = Vector3.ZERO
	for i in 20: await tree.physics_frame
	Input.action_press(&"move_forward")
	var last := player.global_position
	var before := 0.0
	for i in int(hz * 3.0):
		await tree.physics_frame
		if i >= int(hz * 2.5):  # el último medio segundo
			before += _flat(player.global_position - last) / 0.5
		last = player.global_position
	var start := player.global_position
	if jump:
		Input.action_press(&"jump")
		await tree.physics_frame
		await tree.physics_frame
		Input.action_release(&"jump")
	var t := 0.0
	var air_d := 0.0
	var air_t := 0.0
	var after_d := 0.0
	var after_t := 0.0
	var was_air := false
	last = player.global_position
	while t < 3.0:
		await tree.physics_frame
		t += 1.0 / hz
		var step := _flat(player.global_position - last)
		last = player.global_position
		if not player.is_on_floor():
			was_air = true
			air_d += step
			air_t += 1.0 / hz
		elif was_air and after_t < 0.5:
			after_d += step
			after_t += 1.0 / hz
	Input.action_release(&"move_forward")
	if jump:
		print("antes de saltar %.2f m/s; en el aire %.2f m/s (%.2f s); medio segundo después de caer %.2f m/s" % [
				before, air_d / maxf(air_t, 0.001), air_t, after_d / maxf(after_t, 0.001)])
	else:
		print("corriendo %.2f m/s" % before)
	return _flat(player.global_position - start)


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()
