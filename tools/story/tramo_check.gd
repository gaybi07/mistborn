extends SceneTree
## Prueba del primer tramo jugable (G5): tejados (ruta por los techos con la patrulla), foso (fuga con el herido),
## afueras, el taller (Clubs y el primer punto) y las tres secundarias jugadas: corrales (pelea con el capataz),
## contrabando (las cajas) y mensajero (los espectros). Caer en una misión la reinicia.
## Con ventana: Godot --path . -s tools/story/tramo_check.gd -- <carpeta para fotos>
## Usa la partida 9 y la borra al final; no toca la progresión guardada. Sale con código 1 si algo falla.

const SLOT := 9
var _fails := 0
var _dir := ""
var _p: Player


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else ""
	# Matar enemigos da experiencia y se guarda en la progresión real: se restaura al salir.
	var prog := FileAccess.get_file_as_bytes("user://progression.cfg")
	QuestLog.reset()
	Art.player_model = "vin"
	SaveSlots.current = SLOT
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(6.0).timeout
	_p = get_first_node_in_group(&"player") as Player
	# --- Tejados: llegar al barrio arranca la persecución.
	await _go(Story.PLACES["barrio_skaa"]["at"])
	var m := Mission.current
	_ok(m is TejadosMission, "en el barrio skaa arranca la persecución")
	if m is TejadosMission:
		var t := m as TejadosMission
		var roofs := t._route.filter(func(r: Vector3) -> bool: return r.y > CityPlan.ground(Vector2(r.x, r.z)) + 3.0).size()
		var spread := Vector2(t._route[0].x - t._route[-1].x, t._route[0].z - t._route[-1].z).length()
		_ok(t._route.size() == TejadosMission.CHECKPOINTS and spread > 25.0, "ruta de %d puntos (%d sobre techos) que cruza %d m" % [t._route.size(), roofs, spread])
		_ok(t.foes_left() == 3, "tres de la patrulla detrás")
		_shot("1_tejados")
		# Caer la reinicia.
		t._on_died()
		await create_timer(0.8).timeout
		_ok(int(QuestLog.active.get("tejados", -1)) == 0 and Mission.current is TejadosMission and Mission.current != t, "caer reinicia la misión")
		t = Mission.current as TejadosMission
		for r in t._route:
			_p.global_position = r + Vector3.UP * 0.5
			_p.velocity = Vector3.ZERO
			await create_timer(0.25).timeout
	await _narration("tejados", 0)
	# --- Foso: despertás adentro, con el herido.
	await create_timer(0.8).timeout
	m = Mission.current
	_ok(m is FosoMission and _p.global_position.y < CityPlan.ground(AshPit.CENTER + Vector2(AshPit.RIM + 20, 0)) - 20.0, "despertás en el fondo del foso")
	if m is FosoMission:
		var f := m as FosoMission
		_ok(_prompts("Hablar con el preso herido") == 1 and f._foes.size() == 4, "el herido y la patrulla de cuatro")
		_shot("2_foso")
		Dialogues.run([["mission", "seguir"]])
		_ok(f._herido.follow == _p, "el herido te sigue")
		f._herido.global_position = Vector3(f._exit.x - 4, CityPlan.ground(f._exit) + 0.5, f._exit.y)
		await _go(f._exit)
	_ok(QuestLog.outcome.get("foso", "") == "salvar", "llegar con el herido a la entrada es salvarlo")
	await _narration("foso", 0)
	# --- Afueras: la narración de siempre.
	await _go(Story.PLACES["camino_oeste"]["at"])
	await _narration("afueras", 0)
	# --- El taller: Sazed, Clubs y el primer punto.
	Dialogues.run([["start", "el_taller"]])
	await _go(Story.PLACES["taller"]["at"])
	_ok(Dialogues.entry("clubs") == "taller_explica", "en el taller, Clubs explica")
	Dialogues.run(Dialogues.LINES["clubs"]["nodes"]["taller_explica"]["options"][0]["do"])
	_ok(Progression.points_free() >= 1, "Clubs te deja un punto libre para gastar (hay %d)" % Progression.points_free())
	_ok(QuestLog.step_text("el_taller") == "Gastar un punto en el árbol (K)", "después, gastar un punto")
	QuestLog.outcome["el_taller_spent"] = -1  # como si hubiera gastado uno (sin tocar la progresión guardada)
	await create_timer(0.6).timeout
	_ok(QuestLog.done.has("el_taller"), "con el punto gastado, el taller termina")
	_ok(Dialogues.check({"coins": 50}) and not Dialogues.check({"coins": 1000000}), "las opciones que piden monedas")
	# --- Corrales: pelear con el capataz.
	Dialogues.run([["start", "corrales"]])
	await _go(Story.PLACES["corrales"]["at"])
	await create_timer(0.5).timeout
	m = Mission.current
	_ok(m is CorralesMission and _prompts("Hablar con el capataz") == 1, "en los corrales, el capataz y sus guardias")
	DialogueBox.open(self, "capataz")
	await create_timer(0.3).timeout
	_shot("3_capataz")
	var box := get_first_node_in_group(&"dialogue_box") as DialogueBox
	box._close()
	Dialogues.run([["mission", "pelea"]])
	for foe in m._foes:
		foe.take_hit(Vector3.ZERO, 1000.0, _p)
	await create_timer(0.6).timeout
	_ok(QuestLog.outcome.get("corrales", "") == "pelear" and int(QuestLog.active.get("corrales", -1)) == 1, "tumbarlos a todos es echarlo a golpes")
	DialogueBox.open(self, "tesa")
	await create_timer(0.3).timeout
	var opts := box._options.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())
	_ok(opts.size() == 1, "Tesa solo deja contar lo que pasó de verdad")
	box._close()
	Dialogues.run(Dialogues.LINES["tesa"]["nodes"]["vuelta"]["options"][0]["do"])
	_ok(QuestLog.done.has("corrales") and QuestLog.done.has("skaa_corrales"), "corrales terminada, con su marca")
	# --- Contrabando: las tres cajas.
	Dialogues.run([["start", "contrabando"]])
	await _go(Story.PLACES["darsena"]["at"])
	m = Mission.current
	_ok(m is ContrabandoMission and (m as ContrabandoMission)._crates.size() == 3, "en la Dársena, tres cajas")
	if m is ContrabandoMission:
		var c := m as ContrabandoMission
		_ok(c._crates.all(func(b: Node3D) -> bool: return CityPlan.dist_to_river(Vector2(b.global_position.x, b.global_position.z)) > CityPlan.RIVER_WIDTH * 0.5), "las cajas en tierra")
		for b in c._crates.duplicate():
			c._take(b)
	await create_timer(0.4).timeout
	Dialogues.run(Dialogues.LINES["dockson"]["nodes"]["vuelta"]["options"][0]["do"])
	_ok(QuestLog.done.has("contrabando"), "contrabando terminada")
	# --- Mensajero: los espectros.
	Dialogues.run([["start", "mensajero"]])
	await _go(Story.PLACES["bosque"]["at"])
	await create_timer(1.0).timeout
	m = Mission.current
	_ok(m is MensajeroMission and m.foes_left() == 6, "en el bosque, el mensajero rodeado de seis espectros")
	_shot("4_mensajero")
	_ok(Dialogues.entry("mensajero_terris") == "rodeado", "con espectros cerca no se puede hablar con él")
	if m is MensajeroMission:
		for w in m._foes:
			w.take_hit(Vector3.ZERO, 1000.0, _p)
	await create_timer(0.3).timeout
	_ok(Dialogues.entry("mensajero_terris") == "salvado", "sin espectros, el mensajero habla")
	Dialogues.run(Dialogues.LINES["mensajero_terris"]["nodes"]["salvado"]["options"][0]["do"])
	await create_timer(0.3).timeout
	Dialogues.run(Dialogues.LINES["tindwyl"]["nodes"]["vuelta"]["options"][0]["do"])
	_ok(QuestLog.done.has("mensajero") and QuestLog.done.has("amigo_terris"), "mensajero terminada, con su marca")
	SaveSlots.erase(SLOT)
	print("FALLAS ", _fails)
	if not prog.is_empty():
		FileAccess.open("user://progression.cfg", FileAccess.WRITE).store_buffer(prog)
	quit(1 if _fails > 0 else 0)


## La narración de esa misión se abre sola al terminar lo jugable; elige la opción `pick`.
func _narration(id: String, pick: int) -> void:
	await create_timer(0.8).timeout
	var box := get_first_node_in_group(&"dialogue_box") as DialogueBox
	_ok(box.visible and box._npc == "narra_" + id, "la narración de %s" % id)
	if box.visible:
		var buttons := box._options.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())
		(buttons[pick] as Button).pressed.emit()
	await create_timer(0.4).timeout
	_ok(QuestLog.done.has(id), "%s terminada" % id)


func _go(xz: Vector2) -> void:
	_p.global_position = Vector3(xz.x, CityPlan.ground(xz) + 1.0, xz.y)
	_p.velocity = Vector3.ZERO
	await create_timer(1.0).timeout


func _prompts(text: String) -> int:
	return root.find_children("*", "Interactable", true, false).filter(func(n: Node) -> bool: return (n as Interactable).prompt == text).size()


func _ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FALLA ") + what)
	if not cond:
		_fails += 1


func _shot(name: String) -> void:
	if _dir != "":
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
