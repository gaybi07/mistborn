extends SceneTree
## Prueba de G1 (conversación, misión, cuaderno, brújula, mapa y partidas) con la misión de prueba "prueba_plaza".
## Con ventana (saca fotos en la carpeta que se pasa): Godot --path . -s tools/story/quest_check.gd -- <carpeta>
## Usa la partida 9 (fuera de las 3 del menú) y la borra al final. Sale con código 1 si algo falla.
## Necesita un personaje elegido (user://jugador.cfg): si no, el selector tapa la conversación.

const SLOT := 9
var _fails := 0
var _dir := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else ""
	# --- Datos, sin escena
	QuestLog.reset()
	_ok(Dialogues.entry("dockson") == "inicio", "Dockson arranca en inicio")
	_ok(QuestLog.offers().size() == 1 and QuestLog.map_marks().size() == 1, "Dockson figura en el mapa antes de hablarle")
	Dialogues.run([["start", "prueba_plaza"]])
	_ok(QuestLog.active.has("prueba_plaza") and QuestLog.tracked == "prueba_plaza", "la misión empieza y se sigue")
	_ok(Dialogues.entry("dockson") == "esperando", "Dockson espera mientras no fuiste a la plaza")
	_ok(QuestLog.step_target("prueba_plaza") == QuestLog.SIGNS["cartel_plaza"][0], "el paso 1 apunta al cartel de la plaza")
	_ok(QuestLog.guide(Vector2(0, 200)).get("text", "") == "Leer el cartel de la Plaza Central", "la guía dice qué hacer")
	var saved := QuestLog.to_dict()
	QuestLog.from_dict(saved)
	_ok(QuestLog.to_dict() == saved, "guardar y cargar el estado da lo mismo")
	# --- En la ciudad
	Art.player_model = "vin"
	SaveSlots.current = SLOT
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(6.0).timeout
	var p := get_first_node_in_group(&"player") as Player
	_shot("1_brujula")
	var map := (main.get_children().filter(func(n: Node) -> bool: return n is CityMap) as Array)[0] as CityMap
	map._big.visible = true
	await create_timer(0.5).timeout
	_shot("0_mapa")
	map._big.visible = false
	p.global_position = Vector3(-20, CityPlan.ground(Vector2(-20, 30)) + 1.0, 30)  # el cartel queda adelante a la derecha
	await create_timer(1.5).timeout
	_shot("1b_marcador")
	var sign: Vector2 = QuestLog.SIGNS["cartel_plaza"][0]
	p.global_position = Vector3(sign.x + 1.0, CityPlan.ground(sign) + 1.0, sign.y + 2.0)
	await create_timer(1.0).timeout
	_ok(int(QuestLog.active.get("prueba_plaza", -1)) == 0, "llegar a la plaza no alcanza: hay que leer el cartel")
	var reads := root.find_children("*", "Interactable", true, false).filter(func(n: Node) -> bool: return (n as Interactable).prompt == "Leer el cartel")
	_ok(reads.size() == 1, "el cartel está en la plaza y se usa con E")
	DialogueBox.open(self, "cartel_plaza")
	await create_timer(0.3).timeout
	_shot("1c_cartel")
	var reader := get_first_node_in_group(&"dialogue_box") as DialogueBox
	reader._choose(Dialogues.LINES["cartel_plaza"]["nodes"]["leer"]["options"][0])
	_ok(int(QuestLog.active.get("prueba_plaza", -1)) == 1, "leer el cartel cumple el paso 1")
	var talk: Variant = QuestLog.step_target("prueba_plaza")
	_ok(talk is Vector2, "el paso 2 apunta a Dockson")
	if talk is Vector2:
		p.global_position = Vector3(talk.x, CityPlan.ground(talk) + 1.0, talk.y + 2.0)
	await create_timer(4.0).timeout
	DialogueBox.open(self, "dockson")
	await create_timer(0.3).timeout
	var box := get_first_node_in_group(&"dialogue_box") as DialogueBox
	_ok(box.visible, "se abre la conversación")
	_shot("2_conversacion")
	box._choose(Dialogues.LINES["dockson"]["nodes"]["vuelta"]["options"][0])
	await create_timer(0.3).timeout
	_shot("3_respuesta")
	box._close()
	_ok(QuestLog.done.has("prueba_plaza") and QuestLog.known.size() == 1, "terminar la misión la marca hecha y anota lo que sabés")
	_ok(SaveSlots.exists(SLOT), "terminar una misión guarda la partida")
	var journal: JournalWindow = null
	for n in (get_first_node_in_group(&"dialogue_box") as Node).get_parent().get_children():
		if n is JournalWindow:
			journal = n
	journal.toggle()
	await create_timer(0.3).timeout
	_shot("4_cuaderno")
	journal._tabs.current_tab = 2
	await create_timer(0.3).timeout
	_shot("5_cuaderno_paso")
	journal.toggle()
	# --- Segunda misión: Dockson te manda al foso
	_ok(Dialogues.entry("dockson") == "foso_inicio" and QuestLog.offers().size() == 1, "después del cartel, Dockson ofrece ir al foso")
	Dialogues.run([["start", "prueba_foso"]])
	p.global_position = Vector3(AshPit.CENTER.x + 40, CityPlan.ground(AshPit.CENTER + Vector2(40, 0)) + 1.0, AshPit.CENTER.y)
	await create_timer(1.0).timeout
	_ok(int(QuestLog.active.get("prueba_foso", -1)) == 1, "llegar al foso cumple el paso 1")
	_ok(Dialogues.entry("dockson") == "foso_vuelta", "Dockson pregunta por el foso")
	Dialogues.run(Dialogues.LINES["dockson"]["nodes"]["foso_vuelta"]["options"][0]["do"])
	_ok(QuestLog.done.has("prueba_foso") and Dialogues.entry("dockson") == "despues", "terminar la del foso")
	SaveSlots.erase(SLOT)
	print("FALLAS ", _fails)
	quit(1 if _fails > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FALLA ") + what)
	if not cond:
		_fails += 1


func _shot(name: String) -> void:
	if _dir != "":
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
