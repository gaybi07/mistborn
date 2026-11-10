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
	QuestLog.reset()
	_ok(QuestLog.startable() == ["tejados"] and QuestLog.offers().is_empty(), "al empezar solo está la de los tejados, y nadie ofrece nada")
	_ok(QuestLog.giver_of("t_volador") == "clubs", "la de Spook (sin modelo) la da Clubs")
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
	# Las tres primeras: llegar y elegir en la narración.
	for q: Array in [["tejados", "barrio_skaa", 0], ["foso", "foso", 0], ["afueras", "camino_oeste", 0]]:
		_ok(QuestLog.active.has(q[0]), "%s arranca sola" % q[0])
		await _go(Story.PLACES[q[1]]["at"])
		var box := get_first_node_in_group(&"dialogue_box") as DialogueBox
		_ok(box.visible and box._npc == "narra_" + q[0], "al llegar, la narración de %s" % q[0])
		if q[0] == "foso":
			_shot("2_narracion_foso")
		if box.visible:
			box._choose(Dialogues.LINES["narra_" + q[0]]["nodes"]["n"]["options"][q[2]])
		await create_timer(0.4).timeout
		_ok(QuestLog.done.has(q[0]), "%s terminada" % q[0])
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
	_ok(Dialogues.entry("terrisano") == "vuelta", "ir al taller y volver con Sazed")
	Dialogues.run(Dialogues.LINES["terrisano"]["nodes"]["vuelta"]["options"][0]["do"])
	_ok(QuestLog.done.has("el_taller"), "la del taller terminada")
	# La banda.
	var givers := QuestLog.offers().map(func(o: Dictionary) -> String: return o["giver"])
	givers.sort()
	_ok(givers == ["breeze", "clubs", "clubs", "dockson", "ham", "tesa", "tindwyl"], "la banda ofrece las suyas: %s" % [givers])
	for npc in ["clubs", "ham", "breeze", "tesa", "dockson", "tindwyl"]:
		var e := Dialogues.entry(npc)
		_ok(e.ends_with("ofrece"), "%s ofrece (%s)" % [npc, e])
	_shot("4_mapa_ofertas")
	# Tesa, en los corrales.
	await _go(QuestLog.npc_spot("tesa") + Vector2(0, 3))
	await create_timer(3.0).timeout
	_ok(_prompts("Hablar con Tesa") == 1, "solo la Tesa de los corrales habla")
	Dialogues.run([["start", "corrales"]])
	await create_timer(0.6).timeout
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
