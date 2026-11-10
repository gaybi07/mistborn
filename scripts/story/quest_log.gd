class_name QuestLog
## Estado de la historia en la partida: misiones hechas, en curso (con su paso), bloqueadas, la que sigue la brújula,
## lo que sabés y lo que pasó (el cuaderno, tecla J). Las misiones salen de Story.QUESTS; las de prueba, de TEST.
## Se guarda dentro de la partida (ver SaveSlots). `revision` sube con cada cambio para que la UI se refresque.

## Misiones fuera de la historia, para probar el sistema. "steps": pasos en orden; "at" (XZ) o "place" (Story.PLACES)
## dice dónde se cumple el paso al llegar (radio "r", 10 m si falta); "talk" = se cumple hablando con ese NPC.
const TEST := {
	"prueba_plaza": {"kind": "side", "title": "Un cartel en la plaza", "giver": "dockson",
		"goal": "Dockson quiere saber qué dice el cartel nuevo de la Plaza Central.",
		"steps": [
			{"text": "Leer el cartel de la Plaza Central", "place": "plaza", "r": 12.0},
			{"text": "Contarle a Dockson lo que dice", "talk": "dockson"},
		],
		"ends": {"verdad": {"text": "Le contaste lo que decía"}, "mentira": {"text": "Le dijiste que no decía nada"}}},
}

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


static func quest(id: String) -> Dictionary:
	return TEST.get(id, Story.QUESTS.get(id, {}))


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
	if s.has("talk"):  # donde anda ese NPC (GateForces.PEOPLE)
		var model: String = Story.NPCS.get(s["talk"], {}).get("model", "")
		for spec: Array in GateForces.PEOPLE:
			if spec[0] == model:
				return spec[1]
	var place: String = s.get("place", quest(id).get("place", ""))
	var p: Dictionary = Story.PLACES.get(place, {})
	return p.get("at", null)


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
	if TEST.has(id):
		done[id] = true
	else:
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
	for place: String in seen_places:
		var p: Dictionary = Story.PLACES.get(place, {})
		for kind: String in p.get("marks", []):
			out.append({"xz": p["at"], "kind": kind, "label": p["name"], "tracked": false})
	return out
