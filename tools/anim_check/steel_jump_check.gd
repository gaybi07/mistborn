extends Node
## Uso: Godot --path . res://tools/anim_check/steel_jump_check.tscn -- [segundos con Espacio apretado]
## En la sala de poderes, con Vin y el acero encendido: W + Espacio (salto de acero). Anota la trayectoria cada 0,1 s
## (avance, altura), y dice altura máxima, distancia al caer y si es una parábola (cuánto se aparta de la que hace la
## gravedad con la velocidad de salida). Después prueba un segundo salto enseguida (para ver la recarga).


func _ready() -> void:
	Art.player_model = "vin"
	var room: TrainingRoom = load("res://scenes/skill_room.tscn").instantiate()
	add_child(room)
	var tree := get_tree()
	for i in 60: await tree.physics_frame
	var player: Player = room.player
	var hold := float(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 0.6
	player.allomancy.set_state(&"steel", Allomancy.State.BURN)
	for attempt in 2:
		var start := player.global_position
		var fwd := -player.yaw_pivot.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		Input.action_press(&"move_forward")
		Input.action_press(&"jump")
		var t := 0.0
		var pts: Array[Vector2] = []
		var left_floor := false
		var v0 := Vector3.ZERO
		while t < 6.0:
			await tree.physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
			if t >= hold:
				Input.action_release(&"jump")
			var off := player.global_position - start
			pts.append(Vector2(off.dot(fwd), off.y))
			if not player.is_on_floor() and not left_floor:
				left_floor = true
				v0 = player.velocity
			if left_floor and player.is_on_floor() and t > 0.3:
				break
		Input.action_release(&"move_forward")
		Input.action_release(&"jump")
		var top := 0.0
		for p in pts:
			top = maxf(top, p.y)
		var line := ""
		for i in range(0, pts.size(), 6):
			line += "(%.1f, %.1f) " % [pts[i].x, pts[i].y]
		print("salto %d: %s en el aire %.2f s, altura máx %.2f m, avance %.2f m" % [attempt + 1, "despegó" if left_floor else "NO despegó", t, top, pts[-1].x])
		print("   trayectoria (avance, altura) cada 0,1 s: ", line)
		# Parábola de referencia: la que haría solo la gravedad desde la velocidad de despegue.
		if left_floor:
			var g: float = player._gravity
			var vh := Vector2(v0.x, v0.z).length()
			var worst := 0.0
			var i0 := -1
			for i in pts.size():
				if pts[i].y > 0.05:
					i0 = i
					break
			if i0 >= 0:
				for i in range(i0, pts.size()):
					var dt := float(i - i0) / Engine.physics_ticks_per_second
					var want := pts[i0].y + v0.y * dt - 0.5 * g * dt * dt
					worst = maxf(worst, absf(pts[i].y - want))
			print("   despegue: %.1f m/s hacia arriba, %.1f m/s adelante; se aparta de la parábola hasta %.2f m" % [v0.y, vh, worst])
		for i in 10: await tree.physics_frame
	tree.quit()
