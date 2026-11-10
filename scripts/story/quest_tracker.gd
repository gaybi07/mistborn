class_name QuestTracker
extends Node
## En la ciudad: cumple los pasos de misión que se cumplen llegando a un lugar, y les pone "[E] Hablar con …" a los NPC
## que tienen conversación (Dialogues.LINES), según su modelo en Story.NPCS. Revisa unas veces por segundo.

const CHECK_EVERY := 0.3
const TALK_ZONE := Vector3(3.0, 2.2, 3.0)
## A cuántos metros de un lugar cuenta como visto (y aparecen sus marcas fijas en el mapa).
const SEEN_RADIUS := 40.0

var player: Player
var _wait := 0.0
## modelo de Meshy -> id del NPC en Story.NPCS, solo los que tienen conversación.
var _talkers := {}


func _ready() -> void:
	for id: String in Dialogues.LINES:
		var model: String = Story.NPCS.get(id, {}).get("model", "")
		if model != "":
			_talkers[model] = id


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
	for id: String in QuestLog.active.keys():
		var step := QuestLog.current_step(id)
		if step.has("talk") or step.is_empty():
			continue
		var target: Variant = QuestLog.step_target(id)
		if target != null and here.distance_to(target) < float(step.get("r", 10.0)):
			QuestLog.note("%s: %s." % [QuestLog.title(id), step["text"]])
			QuestLog.advance(id)
	for n: Node in get_tree().get_nodes_in_group(&"npc"):
		var c := n as Citizen
		if c == null or c.has_meta(&"talk") or not _talkers.has(c.meshy_model):
			continue
		var npc_id: String = _talkers[c.meshy_model]
		c.set_meta(&"talk", true)
		c.add_child(Interactable.make(TALK_ZONE, Vector3(0, 1.0, 0), "Hablar con " + String(Story.NPCS[npc_id]["name"]),
				func() -> void: DialogueBox.open(get_tree(), npc_id)))
