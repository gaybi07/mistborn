extends SceneTree
## Verificación del IK de pies (ModelRig._update_foot_ik) en escenarios con suelo real.
## Uso (desde la carpeta del proyecto, con ventana: el esqueleto se actualiza al dibujar):
##   godot --path . -s tools/anim_check/ik_check.gd -- [skaa|mistborn]
##
## Mide la pose FINAL (después del TwoBoneIK3D, en Skeleton3D.skeleton_updated):
## - apoyo: distancia del tobillo a su altura correcta sobre el suelo que tiene debajo (pie apoyado).
## - hundido: cuánto queda el tobillo por debajo de esa altura (pie dentro del suelo).
## - rodilla: cuadros con la rodilla doblada hacia atrás respecto de la cadera.
## - estira: cambio del largo de muslo y pantorrilla (el IK no debería estirar huesos).
## - salto: lo más que se mueve un tobillo de un cuadro al siguiente (tirones).
## - cadera: lo más que cambia el descenso del cuerpo entre cuadros (temblor).
## - desliza: centímetros que recorre en total un pie mientras está apoyado (patinar).

const FPS := 60.0

var who := "skaa"
var world: Node3D
var rig: ModelRig
var _samples := []  # una entrada por cuadro con las medidas de la pose final
var _ankle_rest := 0.0
var _lengths := []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		who = args[0]
	await process_frame
	var results := []
	results.append(await _static_case("plano", [_box(Vector3(20, 1, 20), Vector3(0, -0.5, 0))], 1.0))
	results.append(await _static_case("escalón 15 cm (pie der.)", _step_floor(0.15, 1), 1.0))
	results.append(await _static_case("pozo 15 cm (pie izq.)", _step_floor(-0.15, -1), 1.0))
	for deg in [15.0, 25.0, 35.0]:
		results.append(await _static_case("pendiente %d° de frente" % deg, [_slope(deg, Vector3.RIGHT)], 1.0))
		results.append(await _static_case("pendiente %d° de costado" % deg, [_slope(deg, Vector3.BACK)], 1.0))
	results.append(await _stairs_walk(true))
	results.append(await _stairs_walk(false))
	results.append(await _jump_land(true))
	results.append(await _jump_land(false))
	for anim in ["attack_fist_2", "dodge_left", "hit_front", "push_heavy", "dig", "put_down"]:
		results.append(await _in_place(anim, true))
		results.append(await _in_place(anim, false))
	_print(results)
	await _cost()
	quit()


# ---------------------------------------------------------------- escenarios

func _make_world(shapes: Array) -> void:
	if world:
		world.free()
	world = Node3D.new()
	root.add_child(world)
	for s in shapes:
		world.add_child(s)
	rig = Art.player_rig({}) if who == "mistborn" else Art.skaa_rig()
	rig.use_real_time = true
	world.add_child(rig)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0, 1.2, 3.0)
	cam.make_current()
	_samples.clear()
	_lengths.clear()
	var skel := rig._skel
	var b: Dictionary = rig._bones
	_ankle_rest = rig._ankle
	for side in ["_l", "_r"]:
		_lengths.append([b["thigh" + side], b["calf" + side], _rest_dist(b["thigh" + side], b["calf" + side])])
		_lengths.append([b["calf" + side], b["foot" + side], _rest_dist(b["calf" + side], b["foot" + side])])
	skel.skeleton_updated.connect(_on_pose)


func _rest_dist(a: int, c: int) -> float:
	var skel := rig._skel
	var s := skel.global_basis.get_scale().x
	return skel.get_bone_global_rest(a).origin.distance_to(skel.get_bone_global_rest(c).origin) * s


func _box(size: Vector3, pos: Vector3, rot := Basis()) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Props.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	body.transform = Transform3D(rot, pos)
	return body


## Suelo a 0 con un escalón (h > 0) o un pozo (h < 0) bajo el pie de ese lado (side: 1 der., -1 izq.;
## el personaje mira hacia -Z, así que su derecha es +X).
func _step_floor(h: float, side: int) -> Array:
	var other := _box(Vector3(10, 1, 10), Vector3(-side * 5.0, -0.5, 0))
	var under := _box(Vector3(10, 1, 10), Vector3(side * 5.0, -0.5 + h, 0))
	return [other, under]


## Plano inclinado que pasa por el origen (axis: eje de giro; RIGHT sube hacia delante, BACK de costado).
func _slope(deg: float, axis: Vector3) -> StaticBody3D:
	var rot := Basis(axis, deg_to_rad(deg))
	return _box(Vector3(10, 1, 10), rot * Vector3(0, -0.5, 0), rot)


func _static_case(name: String, shapes: Array, seconds: float) -> Dictionary:
	_make_world(shapes)
	for i in 90:  # que se acomode (el cuerpo baja de a poco si la animación flota)
		await process_frame
	_samples.clear()
	for i in int(seconds * FPS):
		await process_frame
	return _summary(name, _samples, true)


## Caminando escaleras arriba (15 cm por escalón): el cuerpo sigue la altura del suelo como lo haría
## la cápsula del personaje.
func _stairs_walk(ik: bool) -> Dictionary:
	var shapes := []
	for i in 12:
		shapes.append(_box(Vector3(4, 1, 0.35), Vector3(0, -0.5 + i * 0.15, -i * 0.35)))
	shapes.append(_box(Vector3(4, 1, 4), Vector3(0, -0.5, 2.1)))
	_make_world(shapes)
	rig.foot_ik = ik
	rig.position.z = 1.0
	for i in 10:
		await process_frame
	_samples.clear()
	var space := rig.get_world_3d().direct_space_state
	for i in int(3.0 * FPS):
		rig.move_speed = 1.4
		rig.body_velocity = Vector3(0, 0, -1.4)
		rig.position.z -= 1.4 / FPS
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				Vector3(0, 5, rig.position.z), Vector3(0, -5, rig.position.z), Props.LAYER_WORLD))
		if hit:
			rig.position.y = hit["position"].y
		await process_frame
	return _summary("escalera (IK %s)" % ("sí" if ik else "no"), _samples, false)


func _jump_land(ik: bool) -> Dictionary:
	_make_world([_box(Vector3(20, 1, 20), Vector3(0, -0.5, 0))])
	rig.foot_ik = ik
	for i in 10:
		await process_frame
	_samples.clear()
	rig.play_jump()
	for i in int(1.4 * FPS):
		rig.on_floor = i > 45
		rig.position.y = 0.6 * sin(clampf(i / 45.0, 0.0, 1.0) * PI)
		if i == 46:
			rig.play_land()
		await process_frame
	return _summary("salto (IK %s)" % ("sí" if ik else "no"), _samples, false)


## Animación en el lugar (golpes, esquivas, trabajo): cuánto se hunde y se desliza el pie apoyado,
## con el IK prendido o apagado. Se mide desde que termina la mezcla con la anterior.
func _in_place(anim: String, ik: bool) -> Dictionary:
	_make_world([_box(Vector3(20, 1, 20), Vector3(0, -0.5, 0))])
	rig.foot_ik = ik
	for i in 30:
		await process_frame
	var length := 0.0
	rig.play_spell(anim, 60.0)
	length = rig._spell
	for i in 6:
		await process_frame
	_samples.clear()
	for i in int(minf(length, 4.0) * FPS):
		await process_frame
	return _summary("%s (IK %s)" % [anim, "sí" if ik else "no"], _samples, false)


func _cost() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var shapes := [_box(Vector3(60, 1, 60), Vector3(0, -0.5, 0))]
	var ms := []
	for ik in [false, true]:
		_make_world(shapes.map(func(s): return s.duplicate()))
		rig.queue_free()
		var rigs := []
		for i in 20:
			var r: ModelRig = Art.player_rig({}) if who == "mistborn" else Art.skaa_rig()
			r.use_real_time = true
			r.foot_ik = ik
			r.position = Vector3((i % 5) * 1.5 - 3.0, 0, -(i / 5) * 1.5)
			world.add_child(r)
			rigs.append(r)
		for i in 20:
			await process_frame
		var t0 := Time.get_ticks_usec()
		for i in 300:
			await process_frame
		ms.append((Time.get_ticks_usec() - t0) / 300.0 / 1000.0)
	print("\nCOSTO: 20 personajes, %.2f ms por cuadro sin IK, %.2f ms con IK (%.3f ms por personaje)" % [
			ms[0], ms[1], (ms[1] - ms[0]) / 20.0])


# ---------------------------------------------------------------- medición

func _on_pose() -> void:
	var skel := rig._skel
	var b: Dictionary = rig._bones
	var space := rig.get_world_3d().direct_space_state
	var s := {"feet": [], "err": [], "knee_bad": 0, "stretch": 0.0, "drop": rig._hips_drop}
	var hips_turn := (skel.global_basis.orthonormalized() * skel.get_bone_global_pose(b["hips"]).basis.orthonormalized()
			* skel.get_bone_global_rest(b["hips"]).basis.orthonormalized().inverse())
	var fwd := hips_turn * (skel.global_basis.orthonormalized().inverse() * (-rig.global_basis.z))
	for side in ["_l", "_r"]:
		var hip := BoneTools.bone_world_pos(skel, b["thigh" + side])
		var knee := BoneTools.bone_world_pos(skel, b["calf" + side])
		var ankle := BoneTools.bone_world_pos(skel, b["foot" + side])
		s["feet"].append(ankle)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(ankle + Vector3.UP * 0.6,
				ankle - Vector3.UP * 1.0, Props.LAYER_WORLD))
		s["err"].append(ankle.y - (hit["position"].y + _ankle_rest) if hit else 0.0)
		var off := knee - (hip + ankle) * 0.5
		var bent := (knee - hip).normalized().dot((ankle - knee).normalized()) < 0.97
		if bent and off.dot(fwd) < -0.03:
			s["knee_bad"] += 1
	for l in _lengths:
		var now := BoneTools.bone_world_pos(skel, l[0]).distance_to(BoneTools.bone_world_pos(skel, l[1]))
		s["stretch"] = maxf(s["stretch"], absf(now / l[2] - 1.0))
	_samples.append(s)


## static: los dos pies tienen que estar apoyados todo el tiempo (error = distancia al suelo).
func _summary(name: String, samples: Array, static_case: bool) -> Dictionary:
	var r := {"name": name, "frames": samples.size(), "contact": 0.0, "sink": 0.0, "knee": 0,
			"stretch": 0.0, "pop": 0.0, "hip_jitter": 0.0, "slide": 0.0}
	for i in samples.size():
		var s: Dictionary = samples[i]
		for k in 2:
			var e: float = s["err"][k]
			if static_case:
				r["contact"] = maxf(r["contact"], absf(e))
			r["sink"] = maxf(r["sink"], -e)
			if i > 0:
				var d: Vector3 = s["feet"][k] - samples[i - 1]["feet"][k]
				r["pop"] = maxf(r["pop"], d.length())
				if e < 0.03 and samples[i - 1]["err"][k] < 0.03:  # apoyado: no debería deslizarse
					r["slide"] += Vector2(d.x, d.z).length()
		r["knee"] += s["knee_bad"]
		r["stretch"] = maxf(r["stretch"], s["stretch"])
		if i > 0:
			r["hip_jitter"] = maxf(r["hip_jitter"], absf(s["drop"] - samples[i - 1]["drop"]))
	return r


func _print(results: Array) -> void:
	print("\nVERIFICACIÓN IK DE PIES (%s)" % who)
	print("%-28s %6s %8s %8s %7s %7s %8s %8s %8s" % ["escenario", "cuadros", "apoyo", "hundido", "rodilla",
			"estira", "salto", "cadera", "desliza"])
	for r in results:
		print("%-28s %6d %7.1fcm %7.1fcm %7d %6.1f%% %7.1fcm %7.1fcm %6.1fcm" % [r["name"], r["frames"],
				r["contact"] * 100.0, maxf(r["sink"], 0.0) * 100.0, r["knee"], r["stretch"] * 100.0,
				r["pop"] * 100.0, r["hip_jitter"] * 100.0, r["slide"] * 100.0])
