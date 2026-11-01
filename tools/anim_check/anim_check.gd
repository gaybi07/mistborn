extends SceneTree
## Revisor de animaciones: reproduce cada estado de ModelRig.ANIMS en un personaje y mide, cuadro a
## cuadro, lo que a ojo se escapa. Uso (desde la carpeta del proyecto):
##   godot --headless --path . -s tools/anim_check/anim_check.gd -- <skaa|mistborn> [estado ...]
##
## Por animación informa (en el espacio del personaje, suelo en y = 0, delante = -Z):
## - hundido: cuánto baja el tobillo por debajo de su altura de reposo (pie metido en el suelo).
## - patina: velocidad media del pie apoyado. En las de desplazamiento (en el lugar) el pie apoyado
##   va hacia atrás a la velocidad de la caminata: eso es "paso", no un error.
## - rodilla/codo al revés: cuadros con la articulación doblada para el lado que no es.
## - estira: cuánto cambia el largo de un hueso respecto del reposo (el retarget no debería).
## - mano en cuerpo: cuadros con una mano metida en el torso.
## - flota: en las que no son de desplazamiento ni en el aire, lo más alto que queda un pie durante
##   TODA la animación (un pie que nunca apoya: está en el aire).

const FPS := 30.0
const PLANTED_HEIGHT := 0.04  # m sobre el reposo para contar el pie como apoyado
const PLANTED_VSPEED := 0.15  # m/s de velocidad vertical máxima del pie apoyado
const LOCOMOTION := ["walk", "run", "sprint", "flee", "carry_walk", "sad_walk", "crouch_walk"]
## Sin los pies en el suelo a propósito: no se mide hundido ni patina.
const OFF_GROUND := ["air", "jump", "hang", "climb", "swim", "swim_idle", "slide", "down", "roll", "dash",
		"attack_air", "freefall", "fall_roll", "climb_wall", "vault"]
const LIMBS := [["thigh_l", "calf_l", "foot_l"], ["thigh_r", "calf_r", "foot_r"],
		["upper_l", "lower_l", "hand_l"], ["upper_r", "lower_r", "hand_r"]]

var rig: ModelRig


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var who: String = args[0] if args.size() > 0 else "skaa"
	var only := args.slice(1)
	if who == "mistborn":
		Art.player_model = "mistborn"
		rig = Art.player_rig({})
	else:
		rig = Art.skaa_rig()
	root.add_child(rig)
	for i in 5:
		await process_frame
	rig.set_process(false)
	rig.use_real_time = true

	var seen := {}
	var rows := []
	for state: String in ModelRig.ANIMS:
		if only.size() and not state in only:
			continue
		var info: Dictionary = rig._resolved.get(state, {})
		if info.get("name", "") == "":
			continue
		var key := "%s/%d" % [info["name"], info.get("donor", -1)]
		if seen.has(key):
			continue
		seen[key] = true
		rows.append(_measure(state, info))
	_print(who, rows)
	quit()


func _measure(state: String, info: Dictionary) -> Dictionary:
	rig.play_spell(state, 600.0)  # muy larga: a su velocidad natural
	var length := rig._spell
	var frames := int(ceil(length * FPS))
	var b: Dictionary = rig._bones
	var rest := _rest_lengths()
	var rest_ankle := minf(_rest_pos(b["foot_l"]).y, _rest_pos(b["foot_r"]).y)
	var r := {"state": state, "anim": info["name"], "len": length, "sink": 0.0, "slide": 0.0,
			"stride": 0.0, "bad_knee": 0, "bad_elbow": 0, "stretch": 0.0, "hand_in_body": 0, "frames": frames,
			"float": 0.0}
	var lowest := [INF, INF]  # altura mínima de cada tobillo sobre el reposo en toda la animación
	var prev := {}
	var planted_speed := []
	for f in frames:
		rig._process(1.0 / FPS)
		if f < 3:  # mezcla con la anterior
			prev = _feet()
			continue
		var feet := _feet()
		for side in ([] if state in OFF_GROUND else ["foot_l", "foot_r"]):
			var p: Vector3 = feet[side]
			var k := 0 if side == "foot_l" else 1
			lowest[k] = minf(lowest[k], p.y - rest_ankle)
			r["sink"] = maxf(r["sink"], rest_ankle - p.y)
			var v: Vector3 = (p - prev[side]) * FPS
			if p.y < rest_ankle + PLANTED_HEIGHT and absf(v.y) < PLANTED_VSPEED:
				planted_speed.append(Vector2(v.x, v.z).length())
		prev = feet
		# Delante y arriba del cuerpo según la cadera (en una voltereta el cuerpo gira entero).
		var hips_turn := _turn(b["hips"])
		var fwd := hips_turn * Vector3.FORWARD
		var up := hips_turn * Vector3.UP
		for limb in LIMBS:
			var a := _pos(b[limb[0]])
			var m := _pos(b[limb[1]])
			var e := _pos(b[limb[2]])
			var off := m - (a + e) * 0.5
			var bent := (m - a).normalized().dot((e - m).normalized()) < 0.97
			if limb[0].begins_with("thigh"):
				# La rodilla se dobla hacia delante del cuerpo: hacia atrás es al revés.
				if bent and off.dot(fwd) < -0.03:
					r["bad_knee"] += 1
			elif bent and off.dot(fwd) > 0.06 and off.dot(up) > 0.0:
				# El codo apunta hacia atrás o abajo; adelante y arriba a la vez es doblarlo al revés.
				r["bad_elbow"] += 1
		for pair in rest:
			var now := _pos(pair[0]).distance_to(_pos(pair[1]))
			r["stretch"] = maxf(r["stretch"], absf(now / pair[2] - 1.0))
		var hips := _pos(b["hips"])
		var neck := _pos(b["neck"])
		for hand in ["hand_l", "hand_r"]:
			var h := _pos(b[hand])
			if Geometry3D.get_closest_point_to_segment(h, hips, neck).distance_to(h) < 0.07:
				r["hand_in_body"] += 1
	if not state in OFF_GROUND and not state in LOCOMOTION and lowest[0] < INF:
		r["float"] = maxf(lowest[0], lowest[1])
	if planted_speed.size():
		planted_speed.sort()
		var median: float = planted_speed[planted_speed.size() / 2]
		if state in LOCOMOTION:
			r["stride"] = median
		else:
			r["slide"] = median
	return r


## Posición de un hueso en el espacio del personaje.
func _pos(bone: int) -> Vector3:
	var skel := rig._skel
	return rig.global_transform.affine_inverse() * skel.global_transform * skel.get_bone_global_pose(bone).origin


## Giro del hueso respecto de su reposo, en el espacio del personaje.
func _turn(bone: int) -> Basis:
	var skel := rig._skel
	var to_rig := (rig.global_transform.affine_inverse() * skel.global_transform).basis.orthonormalized()
	var now := skel.get_bone_global_pose(bone).basis.orthonormalized()
	var rest := skel.get_bone_global_rest(bone).basis.orthonormalized()
	return to_rig * now * rest.inverse() * to_rig.inverse()


func _rest_pos(bone: int) -> Vector3:
	var skel := rig._skel
	return rig.global_transform.affine_inverse() * skel.global_transform * skel.get_bone_global_rest(bone).origin


func _feet() -> Dictionary:
	return {"foot_l": _pos(rig._bones["foot_l"]), "foot_r": _pos(rig._bones["foot_r"])}


## [hueso, hijo, largo en reposo] de los huesos de brazos y piernas.
func _rest_lengths() -> Array:
	var out := []
	for limb in LIMBS:
		for i in 2:
			var a: int = rig._bones[limb[i]]
			var c: int = rig._bones[limb[i + 1]]
			out.append([a, c, _rest_pos(a).distance_to(_rest_pos(c))])
	return out


func _print(who: String, rows: Array) -> void:
	print("\nREVISIÓN %s (%d animaciones)" % [who, rows.size()])
	print("%-16s %-22s %5s %7s %7s %6s %7s %6s %6s %7s %6s  %s" % ["estado", "animación", "seg", "hundido", "patina",
			"flota", "paso", "rodilla", "codo", "estira", "mano", "veredicto"])
	for r in rows:
		var bad := []
		if r["sink"] > 0.05:
			bad.append("pie bajo el suelo")
		if r["float"] > 0.05:
			bad.append("pie en el aire")
		if r["slide"] > 0.25:
			bad.append("patina")
		if r["bad_knee"] > r["frames"] * 0.1:
			bad.append("rodilla al revés")
		if r["bad_elbow"] > r["frames"] * 0.1:
			bad.append("codo al revés")
		if r["stretch"] > 0.05:
			bad.append("huesos estirados")
		if r["hand_in_body"] > r["frames"] * 0.15:
			bad.append("mano en el cuerpo")
		print("%-16s %-22s %5.1f %7.2f %7.2f %6.2f %7.2f %6d %6d %6.0f%% %6d  %s" % [r["state"], r["anim"].left(22), r["len"],
				r["sink"], r["slide"], r["float"], r["stride"], r["bad_knee"], r["bad_elbow"], r["stretch"] * 100.0,
				r["hand_in_body"], "OK" if bad.is_empty() else ", ".join(bad)])
