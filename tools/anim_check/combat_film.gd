extends SceneTree
## Filma a Vin con cada arma: combo completo, golpe aéreo, bloqueo y cada poder, a 30 fps.
## Uso: -- <carpeta> [arma,...] [tramo,...]   Salida: cb_<arma>_<tramo>_<cuadro>.png y una línea por cuadro con velocidades.
const DT := 1.0 / 30.0
const WEAPONS := {"fist": 0, "daggers": 1, "sword": 2, "shield": 2}
const COMBOS := {
	"fist": [0.45, 0.5, 0.55, 0.7], "daggers": [0.42, 0.46, 0.5, 0.78],
	"sword": [0.55, 0.6, 0.6, 0.7, 0.85], "shield": [0.5, 0.55, 0.8],
}
## tramo -> [llamada, args..., segundos que se filma]
const SEGS := {
	"combo": [], "aire": [], "bloqueo": [], "quieto": ["burn", false, 0.9], "caminar": [], "agachar": [],
	"push": ["skill", "steel_push", 0.9, 0.3, 1.0, 1.6],
	"pull": ["skill", "pull_heavy", 0.9, 0.0, 1.0, 1.6],
	"flick": ["skill", "coin_flick", 0.7, 0.35, 1.0, 1.9],
	"wave": ["skill", "coin_wave", 0.9, 0.25, 1.0, 2.6],
	"cshield": ["skill", "coin_shield", 0.9, 0.0, 1.0, 1.8],
	"spear": ["skill", "spear", 1.5, 0.0, 1.0, 2.2],
	"field": ["skill", "field", 1.0, 0.0, 1.0, 1.9],
	"magnet": ["skill", "coin_magnet", 0.9, 0.0, 1.0, 1.8],
	"drink": ["skill", "drink", 1.2, 0.2, 0.42, 2.0],
	"burn": ["burn", false, 1.5], "pewter": ["burn", true, 1.5],
	"throw": ["throw", 1.4], "slam": ["spell", "slam", 1.3, 2.0],
	"dodge": ["spell", "dodge_left", 0.55, 1.3], "roll": ["roll", 1.4],
}
func _init() -> void:
	Art.player_model = "vin"  # si no, el personaje guardado (el encapuchado)
	var a := OS.get_cmdline_user_args()
	var S: String = a[0]
	var wonly: PackedStringArray = a[1].split(",") if a.size() > 1 and a[1] != "all" else PackedStringArray()
	var sonly: PackedStringArray = a[2].split(",") if a.size() > 2 else PackedStringArray()
	var w := Node3D.new(); root.add_child(w); current_scene = w
	var e := WorldEnvironment.new(); e.environment = Environment.new(); e.environment.background_mode = Environment.BG_COLOR; e.environment.background_color = Color(0.45, 0.47, 0.5); e.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.environment.ambient_light_color = Color.WHITE; e.environment.ambient_light_energy = 1.3; w.add_child(e)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-50, 30, 0); w.add_child(l)
	var cam := Camera3D.new(); w.add_child(cam); cam.make_current(); cam.fov = 40
	for wn in WEAPONS:
		if not wonly.is_empty() and not wn in wonly:
			continue
		for sn in SEGS:
			if not sonly.is_empty() and not sn in sonly:
				continue
			var rig: ModelRig = Art.player_rig({})
			for ov in (a[3].split(";") if a.size() > 3 else PackedStringArray()):
				rig.anim_overrides[ov.split("=")[0]] = [ov.split("=")[1]]
			rig.use_real_time = true
			w.add_child(rig); rig.set_process(false)
			rig.shield_owned = wn == "shield"
			for i in 5: await process_frame
			rig.set_equipment(true, true, true, true)
			rig.weapon = WEAPONS[wn]
			rig.set_weapon(WEAPONS[wn])
			if rig._cloak_anchor: rig._cloak_anchor.visible = false  # tapa el cuerpo
			for i in 3: await process_frame
			var skel: Skeleton3D = rig._skel
			var parts := {}
			for p in ["Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot", "Hips"]:
				for b in skel.get_bone_count():
					if skel.get_bone_name(b).ends_with(p):
						parts[p] = b
						break
			cam.global_position = rig.global_position + Vector3(2.4, 1.3, -2.8)
			cam.look_at(rig.global_position + Vector3(0, 0.9, 0))
			# Programa: [tiempo, Callable]
			var prog := []
			var end_t := 0.0
			var seg: Array = SEGS[sn]
			if wn == "fist":
				rig.brace = 1.0
			match sn:
				"combo":
					var t := 0.4
					var side: int = 1
					for i in COMBOS[wn].size():
						var d: float = COMBOS[wn][i]
						var step: int = i
						var sd: int = side
						prog.append([t, func() -> float: return rig.play_attack(sd, d, step)])
						# el jugador encadena en cuanto puede: max(impacto + 0,1, 60 % de lo que dura)
						t += 0.0  # se ajusta al vuelo, ver abajo
						if wn == "daggers": side = 1 - side
					end_t = 0.0
				"aire":
					prog.append([0.3, func() -> float: rig.on_floor = false; return 0.0])
					prog.append([0.5, func() -> float: return rig.play_air_attack(0.55)])
					prog.append([1.3, func() -> float: rig.on_floor = true; rig.play_land(0.6); return 0.0])
					end_t = 2.4
				"caminar":
					prog.append([0.3, func() -> float: rig.move_speed = 1.5; return 0.0])
					prog.append([1.5, func() -> float: rig.move_speed = 5.0; return 0.0])
					prog.append([2.5, func() -> float: rig.move_speed = 0.0; return 0.0])
					end_t = 3.4
				"agachar":
					prog.append([0.3, func() -> float: rig.crouched = true; return 0.0])
					prog.append([1.6, func() -> float: rig.move_speed = 0.7; return 0.0])
					prog.append([2.6, func() -> float: rig.move_speed = 0.0; return 0.0])
					prog.append([3.4, func() -> float: rig.crouched = false; return 0.0])
					end_t = 4.3
				"bloqueo":
					prog.append([0.4, func() -> float: rig.blocking = true; return 0.0])
					prog.append([1.0, func() -> float: rig.block_impact(); return 0.0])
					prog.append([1.6, func() -> float: rig.blocking = false; return 0.0])
					end_t = 2.6
				_:
					var f: Callable
					match seg[0]:
						"skill": f = func() -> float: return rig.play_skill(seg[1], seg[2], seg[3], seg[4])
						"burn": f = (func() -> float: return 0.0) if sn == "quieto" else (func() -> float: rig.burn_gesture(seg[1]); return 0.0)
						"throw": f = func() -> float: rig.play_throw(); return 0.0
						"spell": f = func() -> float: rig.play_spell(seg[1], seg[2]); return 0.0
						"roll": f = func() -> float: rig.play_roll(0.5); return 0.0
					prog.append([0.3, f])
					end_t = 0.3 + float(seg[-1])
			var t := 0.0
			var k := 0
			var prev := {}
			var log := PackedStringArray()
			var next_attack := 0
			var next_at := 0.4
			while true:
				if sn == "combo":
					if next_attack < prog.size() and t >= next_at - DT * 0.5:
						var dur: float = prog[next_attack][1].call()
						next_at = t + maxf(rig.impact_delay() + 0.1, dur * 0.6)
						next_attack += 1
						if next_attack == prog.size():
							end_t = t + dur + 1.2
					if end_t > 0.0 and t >= end_t:
						break
				else:
					if t >= end_t:
						break
					for s in prog:
						if absf(s[0] - t) < DT * 0.5:
							s[1].call()
				Engine.time_scale = 1.0
				rig.set_process(false)
				rig._process(DT)
				await process_frame
				await RenderingServer.frame_post_draw
				if k % 2 == 0: root.get_texture().get_image().save_png("%s/cb_%s_%s_%03d.png" % [S, wn, sn, k])
				var line := "%s_%s %03d %.2fs %-16s" % [wn, sn, k, t, rig._state]
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
