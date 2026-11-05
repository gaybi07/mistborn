extends SceneTree
## Prueba Story (nombres que existen, lugares bien ubicados, partidas al azar que siempre llegan al final) y genera
## docs/HISTORIA_FLUJO.md (diagrama y lo que falta) y docs/historia_mapa.html (la página interactiva).
##   godot --headless --path . -s tools/story/story_check.gd

const RUNS := 20000
const OUT_MD := "res://docs/HISTORIA_FLUJO.md"
const OUT_HTML := "res://docs/historia_mapa.html"
const TEMPLATE := "res://tools/story/mapa_plantilla.html"
const CHANNELS := ["npc", "banda", "rumor", "lugar"]
const KINDS := ["main", "side", "teacher", "guardian"]

var _errors: Array[String] = []


func _initialize() -> void:
	_check_names()
	_check_rules()
	_check_runs()
	for e in _errors:
		printerr("ERROR: ", e)
	if _errors.is_empty():
		_write(OUT_MD, _flow())
		_write(OUT_HTML, FileAccess.get_file_as_string(TEMPLATE).replace("/*DATOS*/null", JSON.stringify(_data(), "", false)))
		print("OK: %d misiones, %d partidas al azar, sin trabas" % [Story.QUESTS.size(), RUNS])
	quit(1 if not _errors.is_empty() else 0)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _check_names() -> void:
	var names := {}
	for id: String in Story.QUESTS:
		names[id] = true
		for e: Dictionary in _results(Story.QUESTS[id]):
			for flag: String in e.get("sets", []):
				names[flag] = true
				if not flag in Story.MARKS:
					_errors.append("%s deja la marca %s, y MARKS no dice qué cambia" % [id, flag])
	for id: String in Story.QUESTS:
		var q: Dictionary = Story.QUESTS[id]
		if q["giver"] != "" and not q["giver"] in Story.NPCS:
			_errors.append("%s: no existe el NPC %s" % [id, q["giver"]])
		if not q["place"] in Story.PLACES:
			_errors.append("%s: no existe el lugar %s" % [id, q["place"]])
		for foe: String in q["foes"]:
			if not foe in Story.FOES:
				_errors.append("%s: no existe el enemigo %s" % [id, foe])
		for n: String in q["needs"] + (q["any"][1] if q.has("any") else []):
			if not n in names:
				_errors.append("%s: pide %s, y nada lo da" % [id, n])
		for e: Dictionary in q["ends"].values():
			for other: String in e.get("locks", []):
				if not other in Story.QUESTS:
					_errors.append("%s: bloquea %s, que no existe" % [id, other])
	for flag: String in Story.MARKS:
		if not flag in names:
			_errors.append("MARKS: nada deja la marca %s" % flag)
	for foe: Dictionary in Story.FOES.values():
		if foe["kit"] != "" and not foe["kit"] in Champion.KITS:
			_errors.append("%s: no existe el kit %s" % [foe["name"], foe["kit"]])
	for npc: Dictionary in Story.NPCS.values():
		if npc["model"] != "" and not ResourceLoader.exists(Art.MESHY % npc["model"]):
			_errors.append("%s: no existe el modelo %s" % [npc["name"], npc["model"]])
	for p: Dictionary in Story.PLACES.values():
		if p.has("at") and CityPlan.inside(p["at"]) != p["city"]:
			_errors.append("%s: dice city=%s y queda del otro lado de la muralla" % [p["name"], p["city"]])
		if p.has("scene") and not ResourceLoader.exists(p["scene"]):
			_errors.append("%s: no existe la escena %s" % [p["name"], p["scene"]])
	var powers: Array = Champion.KITS["LordRuler"]["powers"].map(func(x: Dictionary) -> String: return x["name"])
	for flag: String in Story.FINALE:
		if not flag in names:
			_errors.append("FINALE: nada deja la marca %s" % flag)
		for off: String in Story.FINALE[flag]["off"]:
			if not off in powers:
				_errors.append("FINALE: el Lord Legislador no tiene el poder %s" % off)


## Las reglas que decidimos: principales que no se pierden y con respaldo, y toda misión con forma de enterarse.
func _check_rules() -> void:
	var spines := {}
	for id: String in Story.QUESTS:
		var q: Dictionary = Story.QUESTS[id]
		if not q["kind"] in KINDS:
			_errors.append("%s: tipo desconocido %s" % [id, q["kind"]])
		if q["heard"] == "" or q["learn"].is_empty():
			_errors.append("%s: no dice cómo se entera el jugador" % id)
		for how: String in q["learn"]:
			if not how in CHANNELS:
				_errors.append("%s: forma de enterarse desconocida %s" % [id, how])
		if q["kind"] == "main":
			spines[q["spine"]] = true
			if q.has("late"):
				_errors.append("%s: es principal y se puede perder" % id)
			if q["giver"] != "" and not q.has("backup"):
				_errors.append("%s: es principal y nadie la da si muere %s" % [id, q["giver"]])
			if q.get("backup", "") == q["giver"] and q["giver"] != "":
				_errors.append("%s: su respaldo es el mismo NPC" % id)
			# Solo los cuatro caminos finales se excluyen entre sí.
			if not id.begins_with("f_"):
				for other: String in Story.QUESTS:
					for e: Dictionary in Story.QUESTS[other]["ends"].values():
						if id in e.get("locks", []):
							_errors.append("%s: es principal y la bloquea %s" % [id, other])
	if spines.size() != 12:
		_errors.append("La columna tiene %d números, no 12" % spines.size())


## Juega al azar: nunca puede quedarse sin misiones antes del final, y toda misión y todo final tienen que poder pasar.
func _check_runs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var seen := {}
	for run in RUNS:
		var done := {}
		var locked := {}
		# Una de cada dos partidas va derecho a terminar, salteando todo lo que puede: ahí pasan las consecuencias.
		var rush := run % 2 == 0
		var turns := 0
		while not Story.LAST in done:
			turns += 1
			var open := Story.available(done, locked)
			if open.is_empty() or turns > 500:
				_errors.append("Partida trabada. Hecho: %s" % ", ".join(done.keys()))
				return
			var id: String = open[rng.randi() % open.size()]
			if rush:
				var mains := open.filter(func(q: String) -> bool: return Story.QUESTS[q]["kind"] == "main")
				if not mains.is_empty():
					id = mains[rng.randi() % mains.size()]
			var ends: Array = Story.QUESTS[id]["ends"].keys()
			var ending: String = ends[rng.randi() % ends.size()]
			seen[id + "/" + ending] = true
			Story.finish(id, ending, done, locked)
	for id: String in Story.QUESTS:
		for ending: String in Story.QUESTS[id]["ends"]:
			if not (id + "/" + ending) in seen:
				_errors.append("Nunca se pudo jugar %s con el final %s" % [id, ending])


func _results(q: Dictionary) -> Array:
	return q["ends"].values() + q.get("late", [])


## Lo que necesita la página. Los Vector2 no pasan a JSON solos.
func _data() -> Dictionary:
	var places := {}
	for id: String in Story.PLACES:
		var p: Dictionary = Story.PLACES[id].duplicate()
		if p.has("at"):
			p["at"] = [p["at"].x, p["at"].y]
		places[id] = p
	var gates := []
	for g in CityPlan.gates():
		gates.append({"name": g[0], "at": [g[1].x, g[1].y]})
	return {
		"acts": Story.ACTS, "places": places, "npcs": Story.NPCS, "foes": Story.FOES, "finale": Story.FINALE, "marks": Story.MARKS,
		"quests": Story.QUESTS, "hosts": Story.KANDRA_HOSTS, "gates": gates,
		"wall": Array(CityPlan.WALL).map(func(v: Vector2) -> Array: return [v.x, v.y]),
		"river": Array(CityPlan.RIVER).map(func(v: Vector2) -> Array: return [v.x, v.y]),
	}


func _flow() -> String:
	var s := "# Flujo de la historia\n\nGenerado por `tools/story/story_check.gd` desde `scripts/story/story.gd`: no editar a mano.\n"
	s += "Las reglas y el relato están en [HISTORIA.md](HISTORIA.md). La versión interactiva es `historia_mapa.html`.\n\n"
	s += "Flecha llena: hace falta. Punteada: alcanza con algunas (el número dice cuántas). Línea con X: bloquea. Con ★: principal.\n\n"
	s += "```mermaid\nflowchart TD\n"
	var flag_from := {}
	for id: String in Story.QUESTS:
		for e: Dictionary in _results(Story.QUESTS[id]):
			for flag: String in e.get("sets", []):
				flag_from.get_or_add(flag, {})[id] = true
	for act: int in Story.ACTS:
		s += "  subgraph a%d[\"Acto %d. %s\"]\n" % [act, act, Story.ACTS[act]]
		for id: String in Story.QUESTS:
			var q: Dictionary = Story.QUESTS[id]
			if q["act"] == act:
				s += "    %s[\"%s%s\"]\n" % [_node(id), "★%d " % q["spine"] if q["kind"] == "main" else "", q["title"]]
		s += "  end\n"
	for id: String in Story.QUESTS:
		var q: Dictionary = Story.QUESTS[id]
		for n: String in q["needs"]:
			s += _edge(n, id, "-->", "", flag_from)
		if q.has("any"):
			for n: String in q["any"][1]:
				s += _edge(n, id, "-.->", "|%d|" % q["any"][0], flag_from)
		if id.begins_with("f_"):
			continue  # los cuatro caminos finales se excluyen entre sí: dibujarlo no aclara nada
		for e: Dictionary in q["ends"].values():
			for other: String in e.get("locks", []):
				s += "  %s x--x %s\n" % [_node(id), _node(other)]
	s += "```\n\n## Misiones\n"
	for act: int in Story.ACTS:
		s += "\n### Acto %d. %s\n\n| Misión | Quién | Dónde | Cómo te enterás | Contra | Cómo se resuelve | Si no la hacés |\n|---|---|---|---|---|---|---|\n" % [act, Story.ACTS[act]]
		for id: String in Story.QUESTS:
			var q: Dictionary = Story.QUESTS[id]
			if q["act"] != act:
				continue
			var foes: Array[String] = []
			for foe: String in q["foes"]:
				foes.append("%d %s" % [q["foes"][foe], Story.FOES[foe]["name"]])
			var ends: Array[String] = []
			for e: Dictionary in q["ends"].values():
				ends.append(e["text"])
			var lates: Array[String] = []
			for l: Dictionary in q.get("late", []):
				lates.append("Tras %d principales: %s" % [l["after"], l["text"]])
			s += "| %s**%s**: %s | %s | %s | %s | %s | %s | %s |\n" % ["★%d " % q["spine"] if q["kind"] == "main" else "", q["title"], q["goal"],
					Story.NPCS[q["giver"]]["name"] if q["giver"] != "" else "", Story.PLACES[q["place"]]["name"], q["heard"], ", ".join(foes), " / ".join(ends), " ".join(lates)]
	s += "\n## Qué cambia cada marca\n\n"
	for flag: String in Story.MARKS:
		s += "- `%s`: %s\n" % [flag, Story.MARKS[flag]]
	s += "\n## Lo que falta construir\n\n"
	s += "**Lugares:** " + _list(Story.PLACES, func(p: Dictionary) -> bool: return not p["ready"]) + "\n\n"
	s += "**Personajes sin modelo:** " + _list(Story.NPCS, func(n: Dictionary) -> bool: return n["model"] == "") + "\n\n"
	s += "**Personajes con modelo y sin clips:** " + _list(Story.NPCS, func(n: Dictionary) -> bool: return n["model"] != "" and not n["clips"]) + "\n\n**Enemigos que todavía no pelean:**\n\n"
	for foe: Dictionary in Story.FOES.values():
		if foe["kit"] == "":
			s += "- %s: %s\n" % [foe["name"], foe["note"]]
	return s


func _list(table: Dictionary, wanted: Callable) -> String:
	var out: Array[String] = []
	for v: Dictionary in table.values():
		if wanted.call(v):
			out.append(v["name"])
	return ", ".join(out)


## Las marcas se dibujan desde la misión que las deja.
func _edge(need: String, id: String, arrow: String, label: String, flag_from: Dictionary) -> String:
	if need in Story.QUESTS:
		return "  %s %s%s %s\n" % [_node(need), arrow, label, _node(id)]
	var s := ""
	for from: String in flag_from.get(need, {}):
		s += "  %s %s%s %s\n" % [_node(from), arrow, label, _node(id)]
	return s


func _node(id: String) -> String:
	return "q_" + id
