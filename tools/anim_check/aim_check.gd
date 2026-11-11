extends SceneTree
## Uso: -- <carpeta para las fotos>. Pone 2 puntos en cada poder de acero, hierro y peltre, solo en memoria (no se guarda).
## Vin apunta cada poder con zona (mantener la tecla) y lo suelta: foto de la zona azul y si salió.
func _init() -> void:
	var w := Node3D.new(); root.add_child(w); current_scene = w
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-60, 30, 0); w.add_child(l)
	var e := WorldEnvironment.new(); e.environment = Environment.new(); e.environment.background_mode = Environment.BG_COLOR; e.environment.background_color = Color(0.3, 0.31, 0.33); e.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.environment.ambient_light_color = Color.WHITE; w.add_child(e)
	var floor := StaticBody3D.new(); floor.collision_layer = Props.LAYER_WORLD
	var cs := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(80, 1, 80); cs.shape = box
	floor.add_child(cs); floor.position.y = -0.5; w.add_child(floor)
	var fm := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(80, 80); fm.mesh = pm; w.add_child(fm)
	var stone := StandardMaterial3D.new(); stone.albedo_color = Color(0.36, 0.35, 0.33); fm.material_override = stone
	var player := Player.new()
	w.add_child(player)
	for i in 30: await physics_frame
	for s in SkillTree.SKILLS:  # solo en memoria: no se guarda
		if s["metal"] in [&"steel", &"iron", &"pewter"]: Progression.skill_levels[s["id"]] = 2
	var k := 0
	for skill in Player.AIMED:
		player._skill_press(skill)
		var ok: bool = player._aim_skill == skill and is_instance_valid(player._aim_preview)
		for i in 20: await process_frame
		player.yaw_pivot.rotate_y(0.6)  # gira la mira: la zona tiene que seguirla
		for i in 10: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/aim_%d.png" % [OS.get_cmdline_user_args()[0], k])
		player._skill_release(skill)
		print("%-22s apuntando %s, al soltar la zona se fue: %s" % [skill, ok, not is_instance_valid(player._aim_preview)])
		k += 1
		for i in 40: await physics_frame
	quit()
