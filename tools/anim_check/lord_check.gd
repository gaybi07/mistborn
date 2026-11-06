extends SceneTree
## El Lord Legislador tira cada poder de LordPowers contra Vin (el Player de verdad, quieta a `dist` m). Por poder:
## cuánta vida te sacó y una foto de arriba cada 0,25 s (avisos y efectos).
## Uso: -- <carpeta|-> [poder,...|all] [dist] [esquivar]   (carpeta "-": no saca fotos)
const DT := 1.0 / 60.0
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var S: String = a[0] if a.size() > 0 and a[0] != "-" else ""
	var only: PackedStringArray = a[1].split(",") if a.size() > 1 and a[1] != "all" else PackedStringArray()
	var dist: float = float(a[2]) if a.size() > 2 else 7.0
	var dodge := a.size() > 3 and a[3] == "esquivar"  # se corre 8 m al costado justo antes del golpe
	var w := Node3D.new(); root.add_child(w); current_scene = w
	var e := WorldEnvironment.new(); e.environment = Environment.new(); e.environment.background_mode = Environment.BG_COLOR; e.environment.background_color = Color(0.3, 0.31, 0.33); e.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.environment.ambient_light_color = Color.WHITE; e.environment.ambient_light_energy = 1.0; w.add_child(e)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-60, 30, 0); w.add_child(l)
	var floor := StaticBody3D.new(); floor.collision_layer = Props.LAYER_WORLD
	var cs := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(80, 1, 80); cs.shape = box
	floor.add_child(cs); floor.position.y = -0.5; w.add_child(floor)
	var fm := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(80, 80); fm.mesh = pm; w.add_child(fm)
	var stone := StandardMaterial3D.new(); stone.albedo_color = Color(0.36, 0.35, 0.33); fm.material_override = stone  # como el empedrado
	var player := Player.new()
	w.add_child(player)
	for i in 20: await physics_frame
	Art.player_model = "vin"  # sin guardar la elección
	player.rig.queue_free(); player._add_rig(); player._apply_equipment()
	var lord := Champion.new()
	lord.kit = "LordRuler"
	w.add_child(lord)
	lord.global_position = Vector3(0, 0, -dist)
	for i in 60: await physics_frame
	var cam := Camera3D.new(); w.add_child(cam)
	cam.global_position = Vector3(6.5, 7.5, 5.0); cam.look_at(Vector3(0, 0.5, -dist * 0.45)); cam.make_current(); cam.fov = 60
	if OS.has_environment("LORD_CLOSE"):  # cerca del Lord, de costado: para ver sus animaciones
		cam.global_position = Vector3(4.5, 1.8, -dist + 1.0); cam.look_at(Vector3(0, 1.1, -dist)); cam.fov = 50
	for p: Dictionary in LordPowers.POWERS:
		if not only.is_empty() and not p["name"] in only:
			continue
		player.health = player.max_health; player.dead = false; player.stamina = 100.0
		player.global_position = Vector3.ZERO; player.velocity = Vector3.ZERO
		lord.global_position = Vector3(0, 0, -dist); lord.velocity = Vector3.ZERO; lord.health = lord.max_health * (0.9 if p["phase"] == 1 else (0.5 if p["phase"] == 2 else 0.25)) if p["name"] != "Mente de oro" else lord.max_health * 0.5
		lord.lord_powers.buffs.clear()
		lord._foe = player; lord._player = player
		var hp0: float = player.health
		lord.lord_powers.cast(p)
		var k := 0
		var t := 0.0
		var skel: Skeleton3D = lord.rig._skel
		var bones := {}
		for part in ["Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot", "Hips"]:
			for b in skel.get_bone_count():
				if skel.get_bone_name(b).ends_with(part):
					bones[part] = b
					break
		var prev := {}
		while t < 4.5:
			lord._foe = player
			lord._next_blow = INF  # solo el poder: sin golpes comunes ni otros poderes
			lord._next_power = INF
			if dodge and absf(t - (float(p["warn"]) - 0.12)) < DT * 0.5:
				player.global_position += Vector3(8, 0, 0)
			await physics_frame
			t += DT
			# Saltos de pose del Lord (ver saltos.py): velocidad de cabeza, manos, pies y cadera, sin el desplazamiento del cuerpo.
			var line := "%s %03d %.2fs %-16s" % [p["name"].replace(" ", "_"), int(t * 60.0), t, lord.rig._state]
			var worst := 0.0
			for part in bones:
				var pos: Vector3 = lord.rig.global_transform.affine_inverse() * (skel.global_transform * skel.get_bone_global_pose(bones[part]).origin)
				if prev.has(part):
					var v: float = pos.distance_to(prev[part]) / DT
					line += " %s=%.2f" % [part.substr(0, 5), v]
					worst = maxf(worst, v)
				prev[part] = pos
			if OS.has_environment("LORD_LOG"): print(line + " | max=%.2f" % worst)
			if S != "" and int(t * 60.0) % 8 == 0:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("%s/lord_%s_%02d.png" % [S, p["name"].replace(" ", "_"), k])
				k += 1
		print("%-20s fase %d  vida %.0f -> %.0f  (lord %.0f)" % [p["name"], p["phase"], hp0, player.health, lord.health])
		lord._busy_until = 0.0
		for i in 30: await physics_frame
	quit()
