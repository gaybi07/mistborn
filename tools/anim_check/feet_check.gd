extends SceneTree
## Pies de Vin sobre un piso de verdad: por caso, altura de la suela del pie más bajo (flota o se hunde) y, andando,
## cuánto patina el pie apoyado (su velocidad contra la del cuerpo: el personaje no avanza, el pie apoyado debería ir
## hacia atrás a la misma velocidad).  Uso: -- [caso,...]
const DT := 1.0 / 60.0
const CASES := {
	"quieto": {}, "guardia": {"brace": 1.0}, "espada": {"weapon": 2}, "dagas": {"weapon": 1},
	"caminar": {"move_speed": 1.6}, "caminar_lento": {"move_speed": 1.0}, "correr": {"move_speed": 5.0},
	"esprint": {"move_speed": 7.5}, "esprint_top": {"move_speed": 11.0},
	"agachado": {"crouched": true}, "agachado_mov": {"crouched": true, "move_speed": 0.7},
	"caminar_espada": {"weapon": 2, "move_speed": 1.6}, "caminar_dagas": {"weapon": 1, "move_speed": 1.6},
	"correr_espada": {"weapon": 2, "move_speed": 5.0}, "caminar_escudo": {"weapon": 2, "shield": true, "move_speed": 1.6},
	"caminar_puños": {"brace": 1.0, "move_speed": 1.6},
	"rodar": {"roll": true}, "aterrizar": {"land": true},
}
func _init() -> void:
	Art.player_model = "vin"
	var only: PackedStringArray = OS.get_cmdline_user_args()[0].split(",") if OS.get_cmdline_user_args().size() > 0 else PackedStringArray()
	var w := Node3D.new(); root.add_child(w); current_scene = w
	var floor := StaticBody3D.new(); floor.collision_layer = Props.LAYER_WORLD
	var cs := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(200, 1, 200); cs.shape = box
	floor.add_child(cs); floor.position.y = -0.5; w.add_child(floor)
	for name in CASES:
		if not only.is_empty() and not name in only:
			continue
		var c: Dictionary = CASES[name]
		var rig: ModelRig = Art.player_rig({})
		rig.use_real_time = true
		w.add_child(rig); rig.set_process(false)
		for i in 5: await process_frame
		rig.set_equipment(true, false, false, true)
		rig.on_floor = true
		rig.shield_owned = c.has("shield")
		if c.has("weapon"):
			rig.weapon = c["weapon"]; rig.set_weapon(c["weapon"])
		for k in c:
			if k in ["move_speed", "crouched", "brace"]:
				rig.set(k, c[k])
		var skel: Skeleton3D = rig._skel
		var feet := [rig._bones["foot_l"], rig._bones["foot_r"]]
		var ankle: float = rig._ankle * rig.scale.y
		var t := 0.0
		var prev := [null, null]
		var lows := []
		var slides := []
		var hips := []
		var rows := []
		var fspd := []
		var lowest := []
		var spd: float = c.get("move_speed", 0.0)
		while t < 3.0:
			if t >= 1.0 and t - DT < 1.0:
				if c.has("roll"): rig.play_roll(0.5)
				if c.has("land"): rig.play_land(0.8)
			rig.set_process(false)
			rig._process(DT)
			await process_frame
			var p := []
			for i in 2:
				p.append(skel.global_transform * skel.get_bone_global_pose(feet[i]).origin)
			var low := 0 if p[0].y < p[1].y else 1
			var h: float = p[low].y - ankle
			if t > 1.0:
				lows.append(h)
				hips.append((skel.global_transform * skel.get_bone_global_pose(rig._bones["hips"]).origin))
				if prev[low] != null and h < 0.04 and spd > 0.0:
					var v: Vector3 = (p[low] - prev[low]) / DT
					v.y = 0.0
					slides.append(absf(v.length() - spd))
					fspd.append(v.length())
				var lb := 9.0
				for b in skel.get_bone_count():
					if skel.get_bone_name(b).contains("Foot") or skel.get_bone_name(b).contains("Toe"): continue
					lb = minf(lb, (skel.global_transform * skel.get_bone_global_pose(b).origin).y)
				lowest.append(lb)
				rows.append("%.2f %s h=%.3f cuerpo=%.3f ik=%.2f caida=%.3f" % [t, rig._state, h, lb, rig._ik.influence if rig._ik else -1.0, rig._hips_drop])
			prev = p
			t += DT
		lows.sort()
		var hx: Array = hips.map(func(v: Vector3) -> float: return Vector2(v.x, v.z).length())
		var line := "%-15s estado=%-14s suela: min %+.3f  mediana %+.3f  max %+.3f" % [name, rig._state, lows[0], lows[lows.size() / 2], lows[-1]]
		if spd > 0.0:
			slides.sort()
			fspd.sort()
			line += " | patina: mediana %.2f m/s  p90 %.2f (cuerpo %.1f, pie %.2f, clip %s)" % [slides[slides.size() / 2], slides[int(slides.size() * 0.9)], spd, fspd[fspd.size() / 2], rig._resolved.get(rig._state + rig._suffix(rig._state), rig._resolved.get(rig._state, {})).get("name", "?")]
		line += " | cuerpo más bajo %.3f" % lowest.min()
		print(line)
		if name in ["rodar", "aterrizar", "agachado"]:
			for r in rows.slice(0, 50, 3): print("   ", r)
		rig.queue_free()
		await process_frame
	quit()
