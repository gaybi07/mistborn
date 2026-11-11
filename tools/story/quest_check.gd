extends SceneTree
## Prueba de las misiones del Acto 1 (G1 y G4): las tres primeras arrancan solas y se cierran con su narración al
## llegar; Sazed ofrece el taller; después la banda ofrece las suyas, Tesa habla solo en los corrales, bajar al sótano
## cumple el paso de Ham, y guardar y cargar da lo mismo. También el cartel de la plaza.
## Con ventana (saca fotos en la carpeta que se pasa): Godot --path . -s tools/story/quest_check.gd -- <carpeta>
## Usa la partida 9 (fuera de las 3 del menú) y la borra al final. Sale con código 1 si algo falla.
## Necesita un personaje elegido (user://jugador.cfg): si no, el selector tapa la conversación.

const SLOT := 9
var _fails := 0
var _dir := ""
var _p: Player


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else ""
	# --- Datos, sin escena
	# El taller da experiencia y se guarda en la progresión real: se restaura al salir.
	var prog := FileAccess.get_file_as_bytes("user://progression.cfg")
	QuestLog.reset()
	_ok(QuestLog.startable() == ["tejados"] and QuestLog.offers().is_empty(), "al empezar solo está la de los tejados, y nadie ofrece nada")
	_ok(QuestLog.giver_of("t_volador") == "spook", "la pista la da Spook (G9)")
	# --- En la ciudad
	Art.player_model = "vin"
	SaveSlots.current = SLOT
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(6.0).timeout
	_p = get_first_node_in_group(&"player") as Player
	_ok(_prompts("Leer el cartel") == 1, "el cartel de la plaza se lee con E")
	_ok(QuestLog.active.has("tejados") and QuestLog.tracked == "tejados", "la de los tejados arranca sola y se sigue")
	_shot("1_tejados")
	# Tejados y foso se juegan (Mission, ver tramo_check.gd): acá se dan por hechos en el mismo cuadro, antes de que
	# arranque lo jugable. Afueras: llegar y elegir en la narración.
	QuestLog.finish("tejados", "ok")
	QuestLog.start("foso")
	QuestLog.finish("foso", "salvar")
	await create_timer(0.6).timeout
	_ok(QuestLog.active.has("afueras"), "afueras arranca sola")
	await _go(Story.PLACES["camino_oeste"]["at"])
	var narr := get_first_node_in_group(&"dialogue_box") as DialogueBox
	_ok(narr.visible and narr._npc == "narra_afueras", "al llegar, la narración de afueras")
	_shot("2_narracion_afueras")
	if narr.visible:
		narr._choose(Dialogues.LINES["narra_afueras"]["nodes"]["n"]["options"][0])
	await create_timer(0.4).timeout
	_ok(QuestLog.done.has("afueras"), "afueras terminada")
	# Sazed y el taller.
	_ok(QuestLog.offers().size() == 1 and QuestLog.offers()[0]["giver"] == "terrisano", "Sazed ofrece la del taller")
	await _go(QuestLog.npc_spot("terrisano") + Vector2(0, 2))
	_ok(_prompts("Hablar con Sazed") == 1, "a Sazed se le habla con E")
	DialogueBox.open(self, "terrisano")
	await create_timer(0.3).timeout
	_shot("3_sazed")
	var box := get_first_node_in_group(&"dialogue_box") as DialogueBox
	_ok(box.visible and Dialogues.entry("terrisano") == "ofrece", "Sazed te la ofrece")
	box._choose(Dialogues.LINES["terrisano"]["nodes"]["ofrece"]["options"][0])
	box._close()
	await _go(Story.PLACES["taller"]["at"])
	_ok(Dialogues.entry("terrisano") == "a_clubs" and Dialogues.entry("clubs") == "taller_explica", "en el taller, Sazed manda con Clubs")
	Dialogues.run(Dialogues.LINES["clubs"]["nodes"]["taller_explica"]["options"][0]["do"])
	QuestLog.outcome["el_taller_spent"] = -1  # como si hubiera gastado un punto (sin tocar la progresión guardada)
	await create_timer(0.6).timeout
	_ok(QuestLog.done.has("el_taller"), "la del taller terminada")
	# La banda.
	var givers := QuestLog.offers().map(func(o: Dictionary) -> String: return o["giver"])
	givers.sort()
	_ok(givers == ["breeze", "clubs", "dockson", "ham", "spook", "tesa", "tindwyl"], "la banda ofrece las suyas: %s" % [givers])
	for npc in ["clubs", "spook", "ham", "breeze", "tesa", "dockson", "tindwyl"]:
		var e := Dialogues.entry(npc)
		_ok(e.ends_with("ofrece"), "%s ofrece (%s)" % [npc, e])
	_shot("4_mapa_ofertas")
	# Tesa, en los corrales.
	await _go(QuestLog.npc_spot("tesa") + Vector2(0, 3))
	await create_timer(3.0).timeout
	_ok(_prompts("Hablar con Tesa") == 1, "solo la Tesa de los corrales habla")
	Dialogues.run([["start", "corrales"]])
	await create_timer(0.6).timeout
	Dialogues.run(Dialogues.LINES["capataz"]["nodes"]["hola"]["options"][2]["do"])  # no meterse (lo jugable: tramo_check)
	await create_timer(0.3).timeout
	_ok(Dialogues.entry("tesa") == "vuelta", "en los corrales, Tesa pregunta qué pasó")
	Dialogues.run(Dialogues.LINES["tesa"]["nodes"]["vuelta"]["options"][2]["do"])
	_ok(QuestLog.done.has("corrales") and QuestLog.done.has("dato_cuartel"), "el final elegido deja su marca")
	# Ham: bajar a la sala de combate.
	Dialogues.run([["start", "t_peleador"]])
	QuestLog.entered_scene("res://scenes/combat_room.tscn")
	_ok(int(QuestLog.active.get("t_peleador", -1)) == 1, "bajar a la sala cumple el paso de Ham")
	var saved := QuestLog.to_dict()
	QuestLog.from_dict(saved)
	_ok(QuestLog.to_dict() == saved, "guardar y cargar el estado da lo mismo")
	_ok(SaveSlots.exists(SLOT), "terminar una misión guarda la partida")
	SaveSlots.erase(SLOT)
	print("FALLAS ", _fails)
	if not prog.is_empty():
		FileAccess.open("user://progression.cfg", FileAccess.WRITE).store_buffer(prog)
	quit(1 if _fails > 0 else 0)


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
