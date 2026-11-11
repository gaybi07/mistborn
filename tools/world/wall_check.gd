extends SceneTree
## Prueba de la muralla (G29): hay 12 puertas, ninguna sobre el río ni metida en el foso, el campamento koloss o la
## aldea del sur, y por cada portón se pasa caminando (un rayo a la altura del pecho cruza de afuera hacia adentro
## sin chocar). Con ventana y una carpeta, saca fotos de algunas puertas.
## Godot --path . -s tools/world/wall_check.gd [-- <carpeta>]
var _fails := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var gates := CityPlan.gates()
	_ok(gates.size() == 12, "12 puertas (hay %d)" % gates.size())
	for g: Array in gates:
		var p: Vector2 = g[1]
		_ok(CityPlan.dist_to_river(p) > CityPlan.RIVER_WIDTH / 2.0 + 8.0, "%s fuera del agua" % g[0])  # la Puerta Este siempre estuvo a 25 m del río
		_ok(not AshPit.covers(p, 40.0) and not KolossCamp.covers(p, 40.0) and not SouthVillage.covers(p, 40.0), "%s lejos del foso, el campamento y la aldea" % g[0])
	var prog := FileAccess.get_file_as_bytes("user://progression.cfg")
	Art.player_model = "vin"
	SaveSlots.current = 9
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(6.0).timeout
	var p := get_first_node_in_group(&"player") as Player
	for g: Array in gates:
		var at: Vector2 = g[1]
		var out: Vector2 = g[2]
		var inner := at - out * 20.0  # adentro, a pie: que se armen los cuerpos de esa zona sin caer de lo alto
		p.global_position = Vector3(inner.x, CityPlan.ground(inner) + 1.0, inner.y)
		p.velocity = Vector3.ZERO
		await create_timer(0.6).timeout
		var from := at + out * 9.0
		var to := at - out * 9.0
		var q := PhysicsRayQueryParameters3D.create(Vector3(from.x, CityPlan.ground(from) + 1.4, from.y), Vector3(to.x, CityPlan.ground(to) + 1.4, to.y))
		q.collision_mask = Props.LAYER_WORLD
		var hit := root.get_world_3d().direct_space_state.intersect_ray(q)
		_ok(hit.is_empty(), "%s: se pasa caminando%s" % [g[0], "" if hit.is_empty() else " (choca en %s)" % hit["position"]])
	if args.size() > 0:
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.far = 2000
		cam.current = true
		for n in root.find_children("*", "FogVolume", true, false):
			(n as Node3D).visible = false
		for n in root.find_children("*", "WorldEnvironment", true, false):
			(n as WorldEnvironment).environment.fog_enabled = false
			(n as WorldEnvironment).environment.volumetric_fog_enabled = false
		for k: int in [0, 2, 5, 6]:
			var g: Array = gates[k]
			var at: Vector2 = g[1]
			var out: Vector2 = g[2]
			var along: Vector2 = g[3]
			var eye := at + out * 55.0 + along * 30.0
			var inner := at - out * 20.0
			p.global_position = Vector3(inner.x, CityPlan.ground(inner) + 1.0, inner.y)
			p.velocity = Vector3.ZERO
			cam.global_position = Vector3(eye.x, CityPlan.ground(eye) + 12.0, eye.y)
			cam.look_at(Vector3(at.x, CityPlan.ground(at) + 9.0, at.y))
			await create_timer(1.5).timeout
			root.get_viewport().get_texture().get_image().save_png("%s/puerta_%d.png" % [args[0], k])
		var c := Vector2(260, -330)
		cam.global_position = Vector3(c.x + 140, 70, c.y - 60)
		cam.look_at(Vector3(c.x - 60, 10, c.y + 80))
		await create_timer(1.5).timeout
		root.get_viewport().get_texture().get_image().save_png("%s/muralla_lejos.png" % args[0])
	if not prog.is_empty():
		FileAccess.open("user://progression.cfg", FileAccess.WRITE).store_buffer(prog)
	print("FALLAS ", _fails)
	quit(1 if _fails > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FALLA ") + what)
	if not cond:
		_fails += 1
