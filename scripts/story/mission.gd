class_name Mission
extends Node3D
## Lo que se juega adentro de una misión (G5): la arranca QuestTracker al llegar a su lugar (o enseguida, si START_NOW)
## y la cierra con win(final). Si el jugador cae, la misión se deshace y vuelve al paso de llegar (QuestLog.mission_failed).
## Mientras corre, la brújula y el marcador apuntan a target() con el texto goal (QuestLog.guide).
## Cada misión es un script en scripts/story/missions/, anotado en QuestTracker.MISSIONS.

## La que está corriendo (una a la vez).
static var current: Mission
const CALM_RADIUS := 150.0

var quest_id := ""
var player: Player
var goal := ""
var _foes: Array[Npc] = []
var _done := false


## Guardias de la ciudad cerca de la misión: mientras corre no se suman si le pegás a uno de la patrulla
## (Champion.take_hit provoca a los pasivos de alrededor).
var _calmed: Array[Node] = []


func _ready() -> void:
	current = self
	add_to_group(&"mission")
	player.died.connect(_on_died)
	for c in get_tree().get_nodes_in_group(&"passive_champion"):
		if (c as Node3D).global_position.distance_to(player.global_position) < CALM_RADIUS:
			c.remove_from_group(&"passive_champion")
			_calmed.append(c)
	_begin()


func _exit_tree() -> void:
	if current == self:
		current = null
	for c in _calmed:
		if is_instance_valid(c):
			c.add_to_group(&"passive_champion")


# --- Para sobrescribir ---
func _begin() -> void:
	pass


## Adónde guiar al jugador ahora (XZ), o null.
func target() -> Variant:
	return null


## Lo que manda la conversación con ["mission", nombre] (ver Dialogues.run).
func event(_name: String) -> void:
	pass
# -------------------------


## Un soldado de la patrulla. hostile: te busca desde ya; si no, solo si lo provocás (provoke).
func soldier(xz: Vector2, health := 60.0, hostile := true) -> Champion:
	var s := Champion.new()
	s.kit = "Soldado"
	s.home = Vector3(xz.x, CityPlan.ground(xz), xz.y)
	s.position = s.home + Vector3.UP * 0.1
	s.stay_in_plaza = false
	s.roam_radius = 4.0
	add_child(s)
	s.max_health = health
	s.health = health
	if hostile:
		provoke(s)
	_foes.append(s)
	return s


func provoke(s: Champion) -> void:
	s._provoked_until = 1e9


## Los de la misión que siguen en pie.
func foes_left() -> int:
	return _foes.filter(func(f: Npc) -> bool: return is_instance_valid(f) and not f.down).size()


func win(ending: String) -> void:
	if _done:
		return
	_done = true
	QuestLog.mission_done(quest_id, ending)
	queue_free()


func _on_died() -> void:
	if _done:
		return
	_done = true
	QuestLog.mission_failed(quest_id)
	queue_free()


## Un skaa que no pelea: el preso herido del foso, el mensajero del bosque. Si `follow` tiene a alguien, lo sigue
## despacio (rengo). `talk`: lo que dice el "[E]" de arriba y qué hace.
class Survivor extends Npc:
	var follow: Node3D
	var speed := 1.8

	func _role() -> String:
		return "skaa:"

	func _setup() -> void:
		stay_in_plaza = false
		team = 0  # de tu lado: los tuyos no le pegan
		knockout_time = 4.0

	func _think(_delta: float) -> void:  # sin plan_velocity: se replanea cada cuadro y el plan nunca llegaría
		_switch_at = INF
		if follow == null or not is_instance_valid(follow):
			_desired = Vector3.ZERO
			return
		var to := follow.global_position - global_position
		to.y = 0.0
		face_point = follow.global_position
		_desired = to.normalized() * speed if to.length() > 2.5 else Vector3.ZERO
