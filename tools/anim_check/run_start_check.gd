extends Node
## Uso: Godot --headless --path . res://tools/anim_check/run_start_check.tscn
## En la sala de poderes, con Vin y sin metales: aprieta W desde quieta y anota la velocidad real (por cuánto se mueve)
## cada 0,1 s, y cuándo llega a correr. Con --headless: con ventana, si pierde el foco el juego se pausa.


func _ready() -> void:
	Art.player_model = "vin"
	var room: TrainingRoom = load("res://scenes/skill_room.tscn").instantiate()
	add_child(room)
	var tree := get_tree()
	for i in 60: await tree.physics_frame
	var player: Player = room.player
	for m: StringName in Allomancy.METALS:
		player.allomancy.set_state(m, Allomancy.State.OFF)
	var hz := float(Engine.physics_ticks_per_second)
	for attempt in 2:  # la primera sale lenta (la sala recién cargada): cuenta la segunda
		player.global_position = Vector3(0, 1.0, 30.0)
		player.velocity = Vector3.ZERO
		for i in int(hz): await tree.physics_frame  # 1 s quieta: vuelve a empezar caminando
		Input.action_press(&"move_forward")
		var last := player.global_position
		var line := ""
		var top := 0.0
		var full_t := -1.0
		var window := []
		for i in int(hz * 4.0):
			await tree.physics_frame
			var p := player.global_position
			window.append(Vector2(p.x - last.x, p.z - last.z).length() * hz)
			last = p
			if window.size() > int(hz * 0.1):
				window.pop_front()
			var v: float = window.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / window.size()
			top = maxf(top, v)
			if (i + 1) % int(hz * 0.1) == 0:
				line += "%.1f " % v
			if full_t < 0.0 and v >= 7.4:
				full_t = (i + 1) / hz
		Input.action_release(&"move_forward")
		if attempt == 1:
			print("velocidad cada 0,1 s (m/s): ", line)
			print("llega a correr (7,4 m/s) a los %s; máxima %.2f m/s" % ["%.2f s" % full_t if full_t >= 0.0 else "nunca", top])
	tree.quit()
