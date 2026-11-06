extends SceneTree
## Filma transiciones del rig de Vin cuadro por cuadro (30 fps) y mide saltos de pose.
## Uso: -- <carpeta> [escenario,...]   Por escenario: tr_<e>_<cuadro>.png (vista 3/4) y una línea por cuadro con la
## velocidad de cabeza, manos, pies y cadera (m/s). Un salto marca un corte en la mezcla.
const DT := 1.0 / 30.0
const SCEN := {
	"agacharse": [[0.0, {}], [0.5, {"crouched": true}], [2.0, {"crouched": false}], [3.2, null]],
	"guardia": [[0.0, {}], [0.5, {"brace": 1.0}], [1.5, {"attack": 1}], [2.7, {"brace": 0.0}], [3.7, null]],
	"caminar": [[0.0, {}], [0.3, {"move_speed": 1.5}], [1.5, {"move_speed": 5.0}], [2.7, {"move_speed": 0.0}], [3.9, null]],
	"agachado_mov": [[0.0, {"crouched": true}], [1.0, {"move_speed": 0.7}], [2.2, {"move_speed": 0.0}], [3.2, null]],
	"bloqueo": [[0.0, {}], [0.5, {"blocking": true}], [1.5, {"blocking": false}], [2.5, null]],
	"camina_agacha": [[0.0, {"move_speed": 1.5}], [1.0, {"crouched": true, "move_speed": 0.7}], [2.2, {"crouched": false, "move_speed": 1.5}], [3.4, null]],
	"golpe_quieto": [[0.0, {}], [0.5, {"attack": 1}], [1.8, null]],
	"aterrizar": [[0.0, {"on_floor": false}], [0.8, {"on_floor": true, "land": 1}], [2.0, null]],
	"salto": [[0.0, {}], [0.4, {"jump": 1, "on_floor": false, "body_velocity": Vector3(0, 5, 0)}], [0.8, {"body_velocity": Vector3(0, -4, 0)}], [1.2, {"on_floor": true, "land": 0.5, "body_velocity": Vector3.ZERO}], [2.4, null]],
	"salto_corriendo": [[0.0, {"move_speed": 5.0}], [0.6, {"jump": 1, "on_floor": false, "body_velocity": Vector3(0, 5, -5)}], [1.0, {"body_velocity": Vector3(0, -5, -5)}], [1.4, {"on_floor": true, "land": 0.5, "body_velocity": Vector3.ZERO}], [2.6, null]],
	"caida_alta": [[0.0, {}], [0.3, {"on_floor": false, "body_velocity": Vector3(0, -6, 0)}], [0.8, {"body_velocity": Vector3(0, -15, 0)}], [1.8, {"near_ground": true}], [2.0, {"on_floor": true, "near_ground": false, "land": 1.0, "body_velocity": Vector3.ZERO}], [3.4, null]],
	"caida_rodar": [[0.0, {"move_speed": 5.0}], [0.3, {"on_floor": false, "body_velocity": Vector3(0, -8, -5)}], [1.2, {"on_floor": true, "land": 1.0, "body_velocity": Vector3.ZERO}], [2.6, {"move_speed": 0.0}], [3.4, null]],
	"rodar": [[0.0, {"move_speed": 4.0}], [0.5, {"roll": 1}], [1.4, {"move_speed": 0.0}], [2.4, null]],
	"frenar": [[0.0, {"move_speed": 5.0}], [1.0, {"move_speed": 2.0}], [1.05, {"move_speed": 0.0}], [2.6, null]],
	"frenar2": [[0.0, {"move_speed": 5.0}], [1.17, {"move_speed": 2.0}], [1.22, {"move_speed": 0.0}], [2.8, null]],
	"relajar": [[0.0, {"weapon": 2}], [1.2, {"relaxed": true}], [2.6, {"move_speed": 1.6}], [3.6, {"relaxed": false}], [4.6, {"move_speed": 0.0}], [5.6, null]],
	"vuelo_piso": [[0.0, {}], [0.3, {"on_floor": false, "flying": true, "body_velocity": Vector3(0, 10, 0)}], [1.6, {"body_velocity": Vector3(0, 0.5, -4)}], [2.8, {"body_velocity": Vector3(0, -11, -3)}], [3.6, {"near_ground": true}], [3.8, {"flying": false, "near_ground": false, "on_floor": true, "land": 0.8, "body_velocity": Vector3.ZERO}], [4.8, null]],
	"vuelo_salto": [[0.0, {}], [0.3, {"jump": 1, "on_floor": false, "body_velocity": Vector3(0, 5, 0)}], [0.6, {"flying": true, "body_velocity": Vector3(0, 9, -2)}], [1.8, {"body_velocity": Vector3(0, -2, -5)}], [3.0, {"body_velocity": Vector3(0, -10, -2)}], [3.8, {"flying": false, "on_floor": true, "land": 0.8, "body_velocity": Vector3.ZERO}], [4.8, null]],
	"golpeado": [[0.0, {}], [0.4, {"hit_light": 1}], [1.4, {"hit_heavy": 1}], [3.0, null]],
	"morir": [[0.0, {}], [0.4, {"down": true}], [2.6, {"down": false}], [3.6, null]],
	"nadar": [[0.0, {"swimming": true}], [1.0, {"move_speed": 2.0}], [2.4, {"move_speed": 0.0}], [3.4, {"swimming": false}], [4.2, null]],
	"colgar": [[0.0, {"on_floor": false}], [0.3, {"hanging": true}], [1.6, {"hanging": false, "climb": 1}], [2.6, {"on_floor": true}], [3.4, null]],
	"deslizar": [[0.0, {"move_speed": 6.0}], [0.4, {"sliding": true}], [1.4, {"sliding": false, "move_speed": 3.0}], [2.0, {"move_speed": 0.0}], [2.8, null]],
	"dash": [[0.0, {"on_floor": false}], [0.4, {"dash": 1}], [1.2, {"on_floor": true, "land": 0.4}], [2.2, null]],
	"juntar": [[0.0, {}], [0.4, {"pickup": 1}], [1.8, null]],
	"doble_salto": [[0.0, {}], [0.3, {"jump": 1, "on_floor": false, "body_velocity": Vector3(0, 5, 0)}], [0.7, {"jump2": 1}], [1.6, {"on_floor": true, "land": 0.6, "body_velocity": Vector3.ZERO}], [2.6, null]],
	"salto_agachado": [[0.0, {"crouched": true}], [0.5, {"next_jump": "_crouch", "crouched": false}], [0.52, {"jump": 1, "on_floor": false, "body_velocity": Vector3(0, 6, 0)}], [1.3, {"on_floor": true, "land": 0.6, "body_velocity": Vector3.ZERO}], [2.3, null]],
	"volar": [[0.0, {"on_floor": false}], [0.3, {"flying": true, "body_velocity": Vector3(0, 2, -8)}], [1.5, {"body_velocity": Vector3(0, 9, 0)}], [2.7, {"body_velocity": Vector3(0, -4, -6)}], [3.6, {"flying": false, "on_floor": true, "land": 0.5, "body_velocity": Vector3.ZERO}], [4.6, null]],
}
func _init() -> void:
	Art.player_model = "vin"  # si no, el personaje guardado (el encapuchado)
	var S: String = OS.get_cmdline_user_args()[0]
	var only: PackedStringArray = OS.get_cmdline_user_args()[1].split(",") if OS.get_cmdline_user_args().size() > 1 else PackedStringArray()
	root.size = Vector2i(360, 480)
	var w := Node3D.new(); root.add_child(w); current_scene = w
	var e := WorldEnvironment.new(); e.environment = Environment.new(); e.environment.background_mode = Environment.BG_COLOR; e.environment.background_color = Color(0.45, 0.47, 0.5); e.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.environment.ambient_light_color = Color.WHITE; e.environment.ambient_light_energy = 1.3; w.add_child(e)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-50, 30, 0); w.add_child(l)
	var cam := Camera3D.new(); w.add_child(cam); cam.make_current(); cam.fov = 40
	for name in SCEN:
		if not only.is_empty() and not name in only:
			continue
		var rig: ModelRig = Art.player_rig({})
		rig.use_real_time = true
		w.add_child(rig); rig.set_process(false)
		for i in 5: await process_frame
		var skel: Skeleton3D = rig._skel
		var parts := {}
		for p in ["Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot", "Hips"]:
			for b in skel.get_bone_count():
				if skel.get_bone_name(b).ends_with(p):
					parts[p] = b
					break
		cam.global_position = rig.global_position + Vector3(2.6, 1.2, -2.6)
		cam.look_at(rig.global_position + Vector3(0, 0.85, 0))
		var steps: Array = SCEN[name]
		var t := 0.0
		var k := 0
		var prev := {}
		var log := PackedStringArray()
		var end_t: float = steps[-1][0]
		while t < end_t:
			for s in steps:
				if s[1] != null and absf(s[0] - t) < DT * 0.5:
					for key in s[1]:
						match key:
							"attack": rig.play_attack(1, 0.55, 0)
							"land": rig.play_land(float(s[1][key]))
							"jump": rig.play_jump()
							"roll": rig.play_roll(0.5)
							"weapon": rig.weapon = s[1][key]; rig.set_weapon(s[1][key])
							"jump2": rig.play_jump(true)
							"hit_light": rig.play_hit(rig.global_position + Vector3(0, 1, -2), false)
							"hit_heavy": rig.play_hit(rig.global_position + Vector3(0, 1, -2), true)
							"climb": rig.play_climb()
							"dash": rig.play_dash()
							"pickup": rig.play_pickup()
							_: rig.set(key, s[1][key])
			Engine.time_scale = 1.0
			rig.set_process(false)
			rig._process(DT)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/tr_%s_%03d.png" % [S, name, k])
			var line := "%s %03d %.2fs %-16s" % [name, k, t, rig._state]
			var worst := 0.0
			for p in parts:
				var pos: Vector3 = skel.global_transform * skel.get_bone_global_pose(parts[p]).origin
				if prev.has(p):
					var v: float = pos.distance_to(prev[p]) / DT
					line += " %s=%.2f" % [p.substr(0, 5), v]
					worst = maxf(worst, v)
				prev[p] = pos
			log.append(line + " | max=%.2f" % worst)
			t += DT
			k += 1
		for x in log: print(x)
		rig.queue_free()
		await process_frame
	quit()
