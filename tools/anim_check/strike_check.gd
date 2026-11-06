extends SceneTree
## En el cuadro del impacto de cada golpe: dónde está lo que pega, en metros del cuerpo (adelante, arriba, al costado).
const DT := 1.0 / 60.0
func _init() -> void:
	Art.player_model = "vin"
	var w := Node3D.new(); root.add_child(w); current_scene = w
	for spec in [["puños", 0, false, 4], ["dagas", 1, false, 4], ["espada", 2, false, 5], ["escudo", 2, true, 3]]:
		var rig: ModelRig = Art.player_rig({})
		rig.use_real_time = true
		w.add_child(rig); rig.set_process(false)
		for i in 5: await process_frame
		rig.shield_owned = spec[2]
		rig.set_equipment(true, false, false, true)
		rig.weapon = spec[1]; rig.set_weapon(spec[1])
		rig.on_floor = true
		rig.brace = 1.0
		for i in 20: rig.set_process(false); rig._process(DT); await process_frame
		var line := "%-7s" % spec[0]
		for step in spec[3]:
			var d := rig.play_attack(1, 0.5, step)
			if step == 0: line += " [dura %.2f imp %.2f]" % [d, rig.impact_delay()]
			var left := rig.impact_delay()
			while left > 0.0:
				rig.set_process(false); rig._process(DT); await process_frame
				left -= DT
			line += " | %d:" % step
			for p in rig.strike_points():
				var l: Vector3 = rig.global_transform.affine_inverse() * p
				line += " (x%+.2f y%.2f z%+.2f)" % [l.x, l.y, l.z]
			if rig.strike_points().is_empty(): line += " [nada: attack=%.2f st=%s]" % [rig._attack, rig._state]
			for i in 30: rig.set_process(false); rig._process(DT); await process_frame
		print(line)
		rig.queue_free()
		await process_frame
	quit()
