extends SceneTree
## Prueba del espectro de la bruma (MistWraith), con ventana: aparece frente al jugador, se arrastra, se lanza y le
## pega en el pico del estirón (el jugador pierde vida), y al morir se derrite y desaparece. Saca fotos si se pasa una
## carpeta: Godot --path . -s tools/world/wraith_check.gd -- <carpeta>
var _fails := 0
var _dir := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else ""
	# Matar enemigos da experiencia y se guarda en la progresión real: se restaura al salir.
	var prog := FileAccess.get_file_as_bytes("user://progression.cfg")
	Art.player_model = "vin"
	SaveSlots.current = 9
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(5.0).timeout
	var p := get_first_node_in_group(&"player") as Player
	var at := Vector2(-470, 260)  # afuera, lejos de los espectros del mapa
	p.global_position = Vector3(at.x, CityPlan.ground(at) + 1.0, at.y)
	p.yaw_pivot.rotation.y = 0.0  # mirando al norte
	await create_timer(1.0).timeout
	var w := MistWraith.new()
	var spot := at + Vector2(0, -12)
	w.home = Vector3(spot.x, CityPlan.ground(spot), spot.y)
	w.position = w.home + Vector3.UP * 0.1
	main.add_child(w)
	var rig := w.rig as WraithRig
	_ok(rig != null and rig.get_child_count() >= 2, "el espectro tiene su cuerpo y su bruma")
	await create_timer(0.3).timeout
	_shot("1_quieto")
	var hp := p.health
	var crawled := false
	var lunged := false
	for i in 80:  # hasta 8 s: se acerca y se lanza
		await create_timer(0.1).timeout
		if rig._crawl > 0.5 and not crawled:
			crawled = true
			_shot("2_arrastrandose")
		if rig._lunge_t > WraithRig.PEAK * w.LUNGE_DUR * 0.9 and not lunged:
			lunged = true
			_shot("3_lanzandose")
		if p.health < hp:
			break
	_ok(crawled, "se arrastra hacia el jugador")
	_ok(lunged, "se lanza")
	_ok(p.health < hp, "el estirón le pega al jugador (%d -> %d)" % [hp, p.health])
	w.take_hit(Vector3.ZERO, 1000.0, p)
	await create_timer(1.2).timeout
	_shot("4_derritiendose")
	_ok(rig._melt > 0.2, "al morir se derrite")
	await create_timer(2.5).timeout
	_ok(not is_instance_valid(w), "después desaparece")
	print("FALLAS ", _fails)
	if not prog.is_empty():
		FileAccess.open("user://progression.cfg", FileAccess.WRITE).store_buffer(prog)
	quit(1 if _fails > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FALLA ") + what)
	if not cond:
		_fails += 1


func _shot(name: String) -> void:
	if _dir != "":
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
