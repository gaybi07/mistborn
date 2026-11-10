class_name QuestTracker
extends Node
## En la ciudad: cumple los pasos de misión que se cumplen llegando a un lugar, y les pone "[E] Hablar con …" a los NPC
## que tienen conversación (Dialogues.LINES), según su modelo en Story.NPCS. Revisa unas veces por segundo.

const CHECK_EVERY := 0.3
const TALK_ZONE := Vector3(3.0, 2.2, 3.0)
## A cuántos metros de un lugar cuenta como visto (y aparecen sus marcas fijas en el mapa).
const SEEN_RADIUS := 40.0
## A cuántos metros del lugar de una misión de guardián se te cruza (y empieza).
const GUARDIAN_NOTICE := 80.0
## Lo jugable de cada misión (G5): arranca al llegar a su lugar; las de START_NOW, apenas empieza la misión.
static var MISSIONS := {
	"tejados": TejadosMission,
	"foso": FosoMission,
	"corrales": CorralesMission,
	"contrabando": ContrabandoMission,
	"mensajero": MensajeroMission,
}
const START_NOW := ["foso"]  # te agarraron: despertás adentro del foso


func _start_mission(id: String) -> void:
	var m: Mission = (MISSIONS[id] as GDScript).new()
	m.quest_id = id
	m.player = player
	get_parent().add_child(m)

var player: Player
var _wait := 0.0
## modelo de Meshy -> id del NPC en Story.NPCS, solo los que tienen conversación.
var _talkers := {}


func _ready() -> void:
	for id: String in Dialogues.LINES:
		var model: String = Story.NPCS.get(id, {}).get("model", "")
		if model != "":
			_talkers[model] = id
	for id: String in QuestLog.SIGNS:
		_sign.call_deferred(id)


## Cartel de madera con avisos clavados, que se lee con E (Dialogues.LINES[id]).
func _sign(id: String) -> void:
	var at: Vector2 = QuestLog.SIGNS[id][0]
	var root := Node3D.new()
	root.position = Vector3(at.x, CityPlan.ground(at), at.y)
	root.rotation.y = QuestLog.SIGNS[id][1]
	get_parent().add_child(root)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.3, 0.2, 0.13)
	wood.roughness = 0.9
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.78, 0.72, 0.6)
	paper.roughness = 1.0
	for part: Array in [[Vector3(0.12, 2.3, 0.12), Vector3(-0.85, 1.15, 0), wood], [Vector3(0.12, 2.3, 0.12), Vector3(0.85, 1.15, 0), wood],
			[Vector3(1.9, 1.15, 0.07), Vector3(0, 1.65, 0), wood], [Vector3(2.1, 0.1, 0.25), Vector3(0, 2.3, 0.05), wood],
			[Vector3(0.62, 0.85, 0.01), Vector3(-0.3, 1.65, 0.04), paper], [Vector3(0.5, 0.6, 0.01), Vector3(0.45, 1.75, 0.04), paper]]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0]
		mi.mesh = box
		mi.position = part[1]
		mi.material_override = part[2]
		root.add_child(mi)
	root.add_child(Interactable.make(Vector3(2.6, 2.2, 2.6), Vector3(0, 1.1, 0.9), "Leer el cartel",
			func() -> void: DialogueBox.open(get_tree(), id)))


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0 or not is_instance_valid(player):
		return
	_wait = CHECK_EVERY
	var here := Vector2(player.global_position.x, player.global_position.z)
	for place: String in Story.PLACES:
		var at: Variant = Story.PLACES[place].get("at", null)
		if at != null and not QuestLog.seen_places.has(place) and here.distance_to(at) < SEEN_RADIUS:
			QuestLog.seen_places[place] = true
			QuestLog.revision += 1
	# Las que no da nadie: las principales arrancan solas; las de guardián, al acercarse a su lugar.
	for id: String in QuestLog.startable():
		var q: Dictionary = Story.QUESTS[id]
		if QuestLog.giver_of(id) != "":
			continue
		var at: Variant = Story.PLACES.get(q["place"], {}).get("at", null)
		if q["kind"] == "main" or (at != null and here.distance_to(at) < GUARDIAN_NOTICE):
			QuestLog.start(id)
	var busy := is_instance_valid(Mission.current)
	for id: String in QuestLog.active.keys():
		var step := QuestLog.current_step(id)
		if step.is_empty():  # llegó y nadie se la dio: la narración deja elegir cómo termina
			if Dialogues.LINES.has("narra_" + id) and not busy:
				DialogueBox.open(get_tree(), "narra_" + id)
			continue
		if step.has("spend"):  # el primer punto del árbol (K); sin puntos libres no hay nada que gastar
			if Progression.points_spent() > int(QuestLog.outcome.get(id + "_spent", 0)) or Progression.points_free() == 0:
				QuestLog.finish(id, (QuestLog.quest(id)["ends"] as Dictionary).keys()[0])
			continue
		if step.has("talk") or step.has("read") or step.has("scene"):
			continue
		var target: Variant = QuestLog.step_target(id)
		var arrived := target != null and here.distance_to(target) < float(step.get("r", 10.0))
		if MISSIONS.has(id) and int(QuestLog.active[id]) == 0:  # lo jugable: arranca al llegar (o enseguida)
			if not busy and (arrived or id in START_NOW):
				_start_mission(id)
				busy = true
			continue
		if arrived:
			QuestLog.note("%s: %s." % [QuestLog.title(id), step["text"]])
			QuestLog.advance(id)
	for n: Node in get_tree().get_nodes_in_group(&"npc"):
		var c := n as Citizen
		if c == null or c.has_meta(&"talk") or not _talkers.has(c.meshy_model):
			continue
		var npc_id: String = _talkers[c.meshy_model]
		var spot: Variant = QuestLog.npc_spot(npc_id)
		if spot != null and Vector2(c.home.x, c.home.z).distance_to(spot) > 15.0:
			continue  # otro con el mismo modelo (la otra nena skaa no es Tesa)
		c.set_meta(&"talk", true)
		c.add_child(Interactable.make(TALK_ZONE, Vector3(0, 1.0, 0), "Hablar con " + String(Story.NPCS[npc_id]["name"]),
				func() -> void: DialogueBox.open(get_tree(), npc_id)))
