class_name GateForces
extends Node
## Lo que espera afuera de cada puerta: koloss al este, el Lord Legislador al oeste, inquisidores al sur. Solo existen con
## el jugador cerca: el terreno no tiene colisión lejos de él, y se caerían.

const ACTIVE_RADIUS := 130.0
const FREE_RADIUS := 170.0
const GATE_POST := 35.0  # m afuera: lejos de los guardias de adentro
const SPACING := 4.0
const SPAWN_EVERY := 0.1  # de a uno, para que aparecer no trabe el juego

var _posts: Array[Dictionary] = []
var _queue: Array[Npc] = []
var _check_in := 0.0
var _spawn_in := 0.0
var _player: Node3D
var _keep: Array[Resource] = []  # los modelos quedan cargados: volver a la puerta no los lee del disco


func _ready() -> void:
	for gate in CityPlan.gates():
		var out := GATE_POST
		while CityPlan.dist_to_river(gate[1] + gate[2] * out) < CityPlan.RIVER_WIDTH + 20.0:
			out += 5.0  # el río pasa pegado a la Puerta Este
		_posts.append({"gate": gate, "node": null, "at": gate[1] + gate[2] * out})
	for model in ["KolossJoven", "KolossAdulto", "LordRuler", "MistbornHood"]:
		_keep.append(load(Art.MESHY % model))
	_keep.append(load("res://assets/koloss/KolossMoves.glb"))
	_keep.append(load(Art.KOLOSS_ANIMS))


func _process(delta: float) -> void:
	_spawn_in -= delta
	if _spawn_in <= 0.0 and not _queue.is_empty():
		_spawn_in = SPAWN_EVERY
		var foe: Npc = _queue.pop_front()
		foe.get_meta(&"post").add_child(foe)
	_check_in -= delta
	if _check_in > 0.0:
		return
	_check_in = 0.5
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
		if _player == null:
			return
	var at := Vector2(_player.global_position.x, _player.global_position.z)
	for post in _posts:
		var d := at.distance_to(post["at"])
		if post["node"] == null and d < ACTIVE_RADIUS:
			_start(post)
		elif post["node"] != null and d > FREE_RADIUS:
			_drop(post["node"])
			post["node"] = null


func _start(post: Dictionary) -> void:
	var gate: Array = post["gate"]
	var foes := _foes_of(gate[0])
	var node := Node3D.new()  # en el origen del mundo: lo de adentro se ubica en coordenadas globales
	add_child(node)
	post["node"] = node
	for i in foes.size():
		var foe := foes[i]
		var p: Vector2 = post["at"] + gate[3] * (i - (foes.size() - 1) / 2.0) * SPACING
		foe.home = Vector3(p.x, CityPlan.ground(p), p.y)
		foe.position = foe.home + Vector3.UP * 0.1
		foe.rotation.y = atan2(gate[2].x, gate[2].y)  # mirando a la ciudad
		foe.stay_in_plaza = false
		foe.set_meta(&"post", node)
		_queue.append(foe)


static func _foes_of(gate_name: String) -> Array[Npc]:
	var foes: Array[Npc] = []
	match gate_name:
		"Puerta Este":
			for i in 7:
				foes.append(Koloss.new())
		"Puerta Oeste":
			var ruler := Champion.new()
			ruler.kit = "LordRuler"
			foes.append(ruler)
		"Puerta Sur":
			for i in 3:
				foes.append(Champion.new())
	return foes


## Los que seguían en la cola todavía no están en el árbol: hay que liberarlos a mano.
func _drop(node: Node3D) -> void:
	for foe in _queue.filter(func(f: Npc) -> bool: return f.get_meta(&"post") == node):
		_queue.erase(foe)
		foe.free()
	node.queue_free()


func _exit_tree() -> void:
	for foe in _queue:
		foe.free()
	_queue.clear()
