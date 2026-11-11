extends Node
## Uso: Godot --path . res://tools/anim_check/aim_pitch_check.tscn -- <carpeta para las fotos> [nivel de la Ráfaga, 1-5]
## (es una escena y no un -s porque la sala de poderes lleva el HUD, que necesita los autoloads).
## En la sala de poderes, con Vin, en el aire, revisa el humo de cada poder apuntado:
## - lanza y ráfaga, en varias inclinaciones: el humo sale del pecho y el rayo del medio termina sobre la línea de la mira;
## - embestida: sale de los pies hacia donde mira la cámara, por el piso;
## - golpe al piso, tirón y campo: el aro va alrededor de los pies.
## Los niveles van solo en memoria (no se guarda). La sala pone todo al máximo; el nivel de la Ráfaga se puede bajar
## (su abanico crece con el nivel, desde L2).
func _ready() -> void:
	Art.player_model = "vin"
	var room: TrainingRoom = load("res://scenes/skill_room.tscn").instantiate()
	room.set(&"open_menu", false)  # la sala no abre su menú: la prueba usa al jugador ya
	add_child(room)
	var tree := get_tree()
	for i in 30: await tree.physics_frame
	var player := room.player
	var args := OS.get_cmdline_user_args()
	var level := int(args[1]) if args.size() > 1 else SkillTree.max_level(&"steel_coin_burst")
	Progression.skill_levels[&"steel_coin_burst"] = level
	var cases := []
	for skill in [&"steel_spear", &"steel_coin_burst"]:
		for pitch_deg in [0.0, -25.0, -50.0, -85.0, 40.0]:
			cases.append([skill, pitch_deg])
	for skill in [&"pewter_charge", &"pewter_slam", &"iron_mass_yank", &"steel_magnetic_field"]:
		cases.append([skill, -25.0])
	var failed := false
	var k := 0
	for c in cases:
		var skill: StringName = c[0]
		player.global_position = Vector3(0, 7, 0)
		player.velocity = Vector3.ZERO  # si no, la caída acumulada se mide como error (el humo va un cuadro atrás)
		player.pitch_pivot.rotation.x = deg_to_rad(c[1])
		player._skill_press(skill)
		for i in 6: await tree.process_frame
		var zone: Telegraph = player._aim_preview
		if zone == null:
			print("%-20s no se pudo apuntar (¿bloqueado?)  MAL" % skill)
			failed = true
			continue
		var want: Vector3 = player.aim_direction().normalized()
		var feet: Vector3 = player.global_position + Vector3.UP * player.AIM_GROUND_SMOKE
		var error: float
		var what: String
		if skill in player.AIM_3D:
			# Distancia del final del rayo del medio a la línea de la mira, y del comienzo al pecho.
			var to_end: Vector3 = zone.path_end() - player.camera.global_position
			var off_line := (to_end - want * to_end.dot(want)).length()
			var off_chest: float = zone.global_position.distance_to(player.chest_position())
			error = maxf(off_line, off_chest)
			what = "final a %.3f m de la mira, comienzo a %.3f m del pecho" % [off_line, off_chest]
		elif skill == &"pewter_charge":
			var flat := Vector3(want.x, 0.0, want.z).normalized()
			var off_dir := rad_to_deg(flat.angle_to(-zone.global_basis.z))
			error = maxf(zone.global_position.distance_to(feet), off_dir / 10.0)
			what = "comienzo a %.3f m de los pies, desvío %.2f°" % [zone.global_position.distance_to(feet), off_dir]
		elif skill == &"pewter_slam":
			error = zone.global_position.distance_to(feet)
			what = "centro del aro a %.3f m de los pies" % error
		else:
			# El mismo centro desde el que el poder mide la distancia.
			var at: Vector3 = player.chest_position() if skill == &"steel_magnetic_field" else player.global_position
			error = zone.global_position.distance_to(at)
			what = "centro de la esfera a %.3f m de donde mide el poder" % error
		var ok := error < 0.2
		if not ok:
			failed = true
		print("%-20s mira %+4.0f°  %s  %s" % [skill, c[1], what, "OK" if ok else "MAL"])
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/aim3d_%d.png" % [args[0], k])
		k += 1
		player._end_aim()  # sin lanzar: el poder ensuciaría la foto siguiente
		for i in 20: await tree.physics_frame
	print("RESULTADO: ", "FALLÓ" if failed else "todo bien")
	tree.quit()
