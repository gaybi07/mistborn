class_name QuestLog
## Estado de la historia en la partida: misiones hechas, en curso (con su paso), bloqueadas, la que sigue la brújula,
## lo que sabés y lo que pasó (el cuaderno, tecla J). Las misiones salen de Story.QUESTS, con pasos armados acá (quest).
## Se guarda dentro de la partida (ver SaveSlots). `revision` sube con cada cambio para que la UI se refresque.
##
## Pasos ("steps", en orden): "place" (Story.PLACES) o "at" (XZ) se cumple al llegar (radio "r"); "scene" al entrar a
## esa escena (las salas del sótano); "talk" hablando con ese NPC; "read" leyendo ese cartel (SIGNS, con E).
## Con quien la da: ir al lugar y volver a contarle (ahí se elige el final, en Dialogues). Sin nadie que la dé: ir al
## lugar, y ahí una narración (Dialogues "narra_<id>") deja elegir el final.
## shortcut: lo que pasa adentro de cada misión (peleas, persecuciones) es de G5; hoy alcanza con llegar. Solo el
## Acto 1 tiene conversaciones (ACT); los demás actos se suman con las suyas.
const ACT := 1

## Carteles que se leen con E (QuestTracker los pone; el texto está en Dialogues.LINES con la misma clave):
## id -> [posición XZ, hacia dónde mira el frente (rad, 0 = sur)].
const SIGNS := {"cartel_plaza": [Vector2(9, 12), 0.6]}

static var _built := {}

static var done: Dictionary = {}
static var locked: Dictionary = {}
## id -> paso actual (índice en "steps"; las misiones sin pasos quedan en 0).
static var active: Dictionary = {}
## La que marca la brújula ("" = ninguna).
static var tracked := ""
## Lo que sabés: rumores y datos sueltos, en orden.
static var known: Array[String] = []
## Lo que pasó: [fecha y hora del juego, texto].
static var history: Array = []
## Lugares de Story.PLACES por los que ya pasaste: desde ahí el mapa muestra sus marcas fijas (tienda, refugio).
static var seen_places: Dictionary = {}
static var revision := 0


static func reset() -> void:
	done.clear()
	locked.clear()
	active.clear()
	tracked = ""
	known.clear()
	history.clear()
	seen_places.clear()
	revision += 1


## La misión de Story.QUESTS con quién la da de verdad ("giver") y sus pasos ("steps").
static func quest(id: String) -> Dictionary:
	if not _built.has(id):
		var q: Dictionary = Story.QUESTS.get(id, {}).duplicate()
		if not q.is_empty():
			q["giver"] = giver_of(id)
			q["steps"] = _steps(q)
		_built[id] = q
	return _built[id]


## Quién da la misión. Si su NPC todavía no tiene modelo (Spook), la da Clubs.
static func giver_of(id: String) -> String:
	var g: String = Story.QUESTS.get(id, {}).get("giver", "")
	if g != "" and String(Story.NPCS.get(g, {}).get("model", "")) == "":
		return "clubs"
	return g


static func _steps(q: Dictionary) -> Array:
	var place: Dictionary = Story.PLACES.get(q["place"], {})
	var name := String(place.get("name", q["place"]))
	var first := {"text": "Ir a: " + name, "place": q["place"], "r": 25.0 if place.get("city", false) else 50.0}
	if place.has("scene"):
		first = {"text": "Bajar al %s (Esc → Ir a)" % name, "scene": place["scene"]}
	if q["giver"] == "":
		return [first]
	return [first, {"text": "Volver con " + String(Story.NPCS[q["giver"]]["name"]), "talk": q["giver"]}]


## Se pueden empezar ahora, son del acto que ya tiene conversaciones y no están en curso.
static func startable() -> Array[String]:
	var out: Array[String] = []
	for id: String in Story.available(done, locked):
		if int(Story.QUESTS[id].get("act", 0)) == ACT and not active.has(id):
			out.append(id)
	return out


## Entraste a una escena (las salas del sótano): cumple el paso de las misiones que la pedían.
static func entered_scene(path: String) -> void:
	for id: String in active.keys():
		if current_step(id).get("scene", "") == path:
			note("%s: %s." % [title(id), current_step(id)["text"]])
			advance(id)


static func title(id: String) -> String:
	return String(quest(id).get("title", id))


## Texto del paso en curso (o el objetivo, si la misión no tiene pasos).
static func step_text(id: String) -> String:
	var steps: Array = quest(id).get("steps", [])
	var i: int = active.get(id, 0)
	return String(steps[i]["text"]) if i < steps.size() else String(quest(id).get("goal", ""))


static func current_step(id: String) -> Dictionary:
	var steps: Array = quest(id).get("steps", [])
	var i: int = active.get(id, 0)
	return steps[i] if i < steps.size() else {}


## Dónde está el paso en curso (XZ), o null si no tiene lugar.
static func step_target(id: String) -> Variant:
	var s := current_step(id)
	if s.has("at"):
		return s["at"]
	if s.has("talk"):
		return npc_spot(s["talk"])
	if s.has("read"):
		return SIGNS[s["read"]][0]
	if s.has("scene"):
		return Story.PLACES["taller"]["at"]  # las salas del sótano están abajo del taller
	var place: String = s.get("place", quest(id).get("place", ""))
	var p: Dictionary = Story.PLACES.get(place, {})
	return p.get("at", null)


## Dónde anda ese NPC de Story.NPCS (su "at", o el primero de GateForces.PEOPLE con su modelo), o null.
static func npc_spot(npc: String) -> Variant:
	if Story.NPCS.get(npc, {}).has("at"):
		return Story.NPCS[npc]["at"]
	var model: String = Story.NPCS.get(npc, {}).get("model", "")
	for spec: Array in GateForces.PEOPLE:
		if spec[0] == model:
			return spec[1]
	return null


## Misiones que alguien tiene para darte y todavía no empezaste: [{"id", "giver", "xz"}].
static func offers() -> Array:
	var out := []
	for id: String in startable():
		var giver := giver_of(id)
		if giver == "":
			continue
		var at: Variant = npc_spot(giver)
		if at != null:
			out.append({"id": id, "giver": giver, "xz": at})
	return out


## Adónde guiar al jugador (brújula y marcador en pantalla): el paso de la misión que sigue o, sin ninguna, quien
## tenga una para darle, el más cercano. {"xz", "text"} o {} si no hay nada.
static func guide(here: Vector2) -> Dictionary:
	if tracked != "":
		var at: Variant = step_target(tracked)
		if at != null:
			return {"xz": at, "text": step_text(tracked)}
	var best := {}
	for o: Dictionary in offers():
		if best.is_empty() or here.distance_to(o["xz"]) < here.distance_to(best["xz"]):
			best = {"xz": o["xz"], "text": "Hablar con " + String(Story.NPCS[o["giver"]]["name"])}
	return best


## Leíste ese cartel: cumple el paso de las misiones que lo pedían.
static func read(sign: String) -> void:
	for id: String in active.keys():
		if current_step(id).get("read", "") == sign:
			note("%s: %s." % [title(id), current_step(id)["text"]])
			advance(id)


static func start(id: String) -> void:
	if active.has(id) or done.has(id) or locked.has(id) or quest(id).is_empty():
		return
	active[id] = 0
	if tracked == "":
		tracked = id
	note("Nueva misión: %s." % title(id))


## Pasa al paso siguiente de la misión.
static func advance(id: String) -> void:
	if not active.has(id):
		return
	active[id] = int(active[id]) + 1
	revision += 1


## Termina la misión con ese final: marcas, bloqueos y consecuencias (Story.finish), y guarda la partida.
static func finish(id: String, ending: String) -> void:
	var q := quest(id)
	if not active.has(id) or not (q["ends"] as Dictionary).has(ending):
		return
	active.erase(id)
	Story.finish(id, ending, done, locked)
	if tracked == id:
		tracked = "" if active.is_empty() else String(active.keys()[0])
	note("%s: %s." % [title(id), q["ends"][ending]["text"]])
	SaveSlots.autosave()


static func learn(text: String) -> void:
	if text in known:
		return
	known.append(text)
	revision += 1


static func note(text: String) -> void:
	history.append([Time.get_datetime_string_from_system(false, true), text])
	revision += 1


static func to_dict() -> Dictionary:
	return {"done": done.keys(), "locked": locked.keys(), "active": active.duplicate(), "tracked": tracked, "known": known.duplicate(),
			"history": history.duplicate(true), "seen": seen_places.keys()}


static func from_dict(d: Dictionary) -> void:
	reset()
	for id: String in d.get("done", []):
		done[id] = true
	for id: String in d.get("locked", []):
		locked[id] = true
	for id: String in (d.get("active", {}) as Dictionary):
		if not quest(id).is_empty():
			active[id] = int(d["active"][id])
	tracked = String(d.get("tracked", ""))
	if not active.has(tracked):
		tracked = ""
	known.assign(d.get("known", []))
	history.assign(d.get("history", []))
	for place: String in d.get("seen", []):
		seen_places[place] = true
	revision += 1


const MARK_OF_KIND := {"main": "principal", "side": "secundaria", "teacher": "maestro", "guardian": "guardian"}


## Marcas para el mapa: [{"xz", "kind", "label", "tracked"}]. Las misiones en curso marcan su paso; los lugares que ya
## viste, sus marcas fijas. "kind": principal, secundaria, maestro, guardian, tienda o refugio.
## shortcut: todavía no hay marcas de rumor ("?" en una zona); llegan con las misiones de G5, que traen los rumores.
static func map_marks() -> Array:
	var out := []
	for id: String in active:
		var at: Variant = step_target(id)
		if at != null:
			out.append({"xz": at, "kind": MARK_OF_KIND.get(quest(id).get("kind", "side"), "secundaria"), "label": title(id), "tracked": id == tracked})
	for o: Dictionary in offers():
		out.append({"xz": o["xz"], "kind": MARK_OF_KIND.get(quest(o["id"]).get("kind", "side"), "secundaria"),
				"label": "Hablar con " + String(Story.NPCS[o["giver"]]["name"]), "tracked": false})
	for place: String in seen_places:
		var p: Dictionary = Story.PLACES.get(place, {})
		for kind: String in p.get("marks", []):
			out.append({"xz": p["at"], "kind": kind, "label": p["name"], "tracked": false})
	return out
