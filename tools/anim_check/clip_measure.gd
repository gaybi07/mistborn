extends SceneTree
## Mide clips sobre un personaje (por defecto el Lord Legislador): largo, cuándo la mano (o el pie, o la cadera) va
## más rápido (el golpe/tiro) y cuándo empieza y termina el movimiento. Para elegir cortes e impactos.
## Uso: -- clip1,clip2,... [kit]
const FPS := 30.0
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var kit: String = a[1] if a.size() > 1 else "LordRuler"
	var w := Node3D.new(); root.add_child(w); current_scene = w
	var rig: ModelRig = Art.champion_rig(kit)
	for c in a[0].split(","):
		rig.anim_overrides[c] = [c]
	w.add_child(rig); rig.set_process(false)
	for i in 5: await process_frame
	var skel: Skeleton3D = rig._skel
	for c in a[0].split(","):
		rig._play(c, 0.0, true)
		var ap: AnimationPlayer = rig._src_ap if rig._borrowed else rig._ap
		if ap == null or ap.current_animation != c:
			print("%-36s no está" % c)
			continue
		ap.get_animation(c).loop_mode = Animation.LOOP_NONE
		var length := ap.get_animation(c).length
		var parts := {"mano_i": rig._bones["hand_l"], "mano_d": rig._bones["hand_r"], "pie_i": rig._bones["foot_l"], "pie_d": rig._bones["foot_r"], "cadera": rig._bones["hips"]}
		var prev := {}
		var rows := []  # [frac, {parte: velocidad}]
		var n := int(length * FPS)
		for f in n + 1:
			ap.seek(f / FPS, true)
			if rig._borrowed: rig._retargeter.apply()
			var sp := {}
			for k in parts:
				var pos: Vector3 = skel.get_bone_global_pose(parts[k]).origin * rig.scale.y
				if prev.has(k):
					sp[k] = pos.distance_to(prev[k]) * FPS
				prev[k] = pos
			if f > 0:
				rows.append([f / float(n), sp])
		# El golpe: el pico más alto de una mano; el movimiento: donde alguna parte pasa de 1 m/s.
		var best := ["", 0.0, 0.0]
		var first := -1.0
		var last := 0.0
		for r in rows:
			for k in r[1]:
				if r[1][k] > best[2] and k.begins_with("mano"):
					best = [k, r[0], r[1][k]]
				if r[1][k] > 1.0:
					last = r[0]
					if first < 0.0:
						first = r[0]
		var peaks := ""
		for k in ["mano_i", "mano_d", "pie_i", "pie_d", "cadera"]:
			var top := [0.0, 0.0]
			for r in rows:
				if r[1].get(k, 0.0) > top[1]:
					top = [r[0], r[1][k]]
			peaks += " %s %.2f@%.2f" % [k, top[1], top[0]]
		print("%-36s %.2fs  mueve %.2f-%.2f  golpe %s %.2f (%.1f m/s) |%s" % [c, length, first, last, best[0], best[1], best[2], peaks])
	quit()
