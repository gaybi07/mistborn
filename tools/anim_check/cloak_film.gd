extends SceneTree
## Filma la capa de Vin moviéndose de verdad (el rig avanza por el mundo) a 30 fps, desde atrás a tres
## cuartos y de costado, e imprime por cuadro cuánto se mete la capa en las piernas (huesos de la capa
## dentro de las cápsulas de muslo y pantorrilla; negativo = adentro).
## Uso (con ventana y --fixed-fps 30): -- <carpeta> [tramo,...|all] [personaje] [giro en grados]   Salida: capa_<tramo>_<vista>_<cuadro>.png
const DT := 1.0 / 30.0
## tramo -> [segundos, arma]
const SEGS := {
	"quieto": [2.5, 0], "caminar": [2.6, 0], "correr": [3.2, 0], "saltar": [2.4, 0], "rodar": [2.0, 0],
	"agachar": [2.6, 0], "combo_punos": [2.8, 0], "combo_espada": [3.2, 2], "push": [2.2, 0],
}
const LEGS := [["thigh_r", "calf_r", 0.13], ["calf_r", "foot_r", 0.11], ["thigh_l", "calf_l", 0.13], ["calf_l", "foot_l", 0.11]]


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	Art.player_model = a[2] if a.size() > 2 else "vin"  # si no, el personaje guardado (el encapuchado)
	var S: String = a[0]
	var only: PackedStringArray = a[1].split(",") if a.size() > 1 and a[1] != "all" else PackedStringArray()
	var w := Node3D.new(); root.add_child(w); current_scene = w
	var e := WorldEnvironment.new(); e.environment = Environment.new(); e.environment.background_mode = Environment.BG_COLOR; e.environment.background_color = Color(0.62, 0.64, 0.67); e.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.environment.ambient_light_color = Color.WHITE; e.environment.ambient_light_energy = 1.1; w.add_child(e)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-35, 160, 0); l.light_energy = 2.2; w.add_child(l)
	var l2 := DirectionalLight3D.new(); l2.rotation_degrees = Vector3(-30, -20, 0); l2.light_energy = 1.2; w.add_child(l2)
	var floor_mi := MeshInstance3D.new(); floor_mi.mesh = PlaneMesh.new(); floor_mi.mesh.size = Vector2(80, 80); w.add_child(floor_mi)
	var cam := Camera3D.new(); w.add_child(cam); cam.make_current(); cam.fov = 40
	for sn in SEGS:
		if not only.is_empty() and not sn in only:
			continue
		var rig: ModelRig = Art.player_rig({})
		rig.use_real_time = true
		w.add_child(rig); rig.set_process(false)
		for i in 5: await process_frame
		rig.set_equipment(true, true, true, true)
		rig.weapon = SEGS[sn][1]
		rig.set_weapon(SEGS[sn][1])
		if SEGS[sn][1] == 0:
			rig.brace = 1.0
		var skel: Skeleton3D = rig._skel
		rig.rotation.y = deg_to_rad(float(a[3])) if a.size() > 3 else 0.0
		for i in 2: await process_frame
		# Hacia dónde mira de verdad: del talón a la punta del pie.
		var foot: Vector3 = skel.global_transform * skel.get_bone_global_pose(rig._bones["foot_l"]).origin
		var toe: Vector3 = skel.global_transform * skel.get_bone_global_pose(skel.find_bone("LeftToeBase")).origin
		var fwd := Vector3(toe.x - foot.x, 0, toe.z - foot.z).normalized()
		var cloak_bones := []
		for b in skel.get_bone_count():
			if skel.get_bone_name(b).begins_with("cloak_"):
				cloak_bones.append(b)
		var t := 0.0
		var k := 0
		var y := 0.0
		var vy := 0.0
		var log := PackedStringArray()
		var attacks := 0
		while t < SEGS[sn][0]:
			var speed := 0.0
			match sn:
				"caminar": speed = 1.5 if t > 0.3 else 0.0
				"correr": speed = 5.5 if t > 0.3 and t < 2.3 else 0.0
				"saltar":
					speed = 3.0 if t > 0.3 and not rig.on_floor else 0.0
					if absf(t - 0.3) < DT * 0.5:
						rig.play_jump(); rig.on_floor = false; vy = 4.5
				"rodar":
					if absf(t - 0.3) < DT * 0.5: rig.play_roll(0.5)
					speed = 6.0 if t > 0.3 and t < 0.8 else 0.0
				"agachar":
					rig.crouched = t > 0.3 and t < 2.2
					speed = 0.7 if t > 1.0 and t < 1.8 else 0.0
				"combo_punos", "combo_espada":
					if t > 0.3 + attacks * 0.55 and attacks < 4:
						rig.play_attack(attacks % 2, 0.5, attacks); attacks += 1
				"push":
					if absf(t - 0.3) < DT * 0.5: rig.play_skill("steel_push", 0.9, 0.3, 1.0)
			if not rig.on_floor:
				vy -= 9.8 * DT
				y += vy * DT
				if y <= 0.0:
					y = 0.0; vy = 0.0; rig.on_floor = true; rig.play_land(0.8)
			var vel := fwd * speed + Vector3(0, vy, 0)
			rig.move_speed = speed
			rig.vertical_speed = vy
			rig.body_velocity = vel
			rig.position += fwd * speed * DT
			rig.position.y = y
			rig.set_process(false)
			rig._process(DT)
			# Tres cuartos de atrás y de costado, alternando cuadro a cuadro (cada vista a 15 fps).
			var view := "atras" if k % 2 == 0 else "costado"
			var off := -fwd * 3.0 + fwd.cross(Vector3.UP) * 2.0 if view == "atras" else fwd.cross(Vector3.UP) * 3.6
			cam.global_position = rig.global_position + off + Vector3(0, 1.2, 0)
			cam.look_at(rig.global_position + Vector3(0, 0.8, 0))
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/capa_%s_%s_%s_%03d.png" % [S, Art.player_model, sn, view, k / 2])
			var worst := 1.0
			var worst_b := ""
			var low := 9.0
			for c in LEGS:
				var p0: Vector3 = skel.global_transform * skel.get_bone_global_pose(rig._bones[c[0]]).origin
				var p1: Vector3 = skel.global_transform * skel.get_bone_global_pose(rig._bones[c[1]]).origin
				for b in cloak_bones:
					var p: Vector3 = skel.global_transform * skel.get_bone_global_pose(b).origin
					var q := Geometry3D.get_closest_point_to_segment(p, p0, p1)
					if p.distance_to(q) - c[2] < worst:
						worst = p.distance_to(q) - c[2]
						worst_b = skel.get_bone_name(b) + "/" + c[0]
			for b in cloak_bones:
				low = minf(low, (skel.global_transform * skel.get_bone_global_pose(b).origin).y - rig.global_position.y)
			log.append("%s %03d %.2fs %-12s piernas=%+.3f borde=%.2f %s" % [sn, k, t, rig._state, worst, low, worst_b])
			t += DT
			k += 1
		for x in log: print(x)
		rig.queue_free()
		await process_frame
	quit()
