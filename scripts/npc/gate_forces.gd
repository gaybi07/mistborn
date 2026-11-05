class_name GateForces
extends Node
## Lo que espera afuera de cada puerta: koloss al este, el Lord Legislador al oeste, inquisidores al sur. También los mataneblinos
## del Bosque Muerto y la gente de la ciudad, plaza incluida (PEOPLE). Solo existen con
## el jugador cerca: el terreno no tiene colisión lejos de él, y se caerían.

const ACTIVE_RADIUS := 130.0
const FREE_RADIUS := 170.0
const GATE_POST := 35.0  # m afuera: lejos de los guardias de adentro
const SPACING := 4.0
const SPAWN_EVERY := 0.1  # de a uno, para que aparecer no trabe el juego
const FOES := {"Puerta Este": 7, "Puerta Oeste": 1, "Puerta Sur": 3, HAZEKILLERS: 4}
const HAZEKILLERS := "Bosque Muerto"
const HAZEKILLER_POST := Vector2(-620, 620)
## [modelo, XZ, radio por el que pasea]. Los lugares salen de Story.PLACES. "Soldado" y "Obligador" son de la guardia imperial.
const PEOPLE := [
	["GordoNoble", Vector2(-18, 10), 18.0], ["GordoNoble", Vector2(-29, 30), 18.0], ["GordoNoble", Vector2(25, 14), 18.0],
	["GordoNoble", Vector2(16, 2), 18.0], ["GordoNoble", Vector2(-29, 14), 18.0], ["GordoNoble", Vector2(-5, 14), 18.0],
	["Obligador", Vector2(14, 0), 0.0], ["Obligador", Vector2(4.3, 13.3), 0.0], ["Obligador", Vector2(-11.3, 8.2), 0.0],
	["Obligador", Vector2(-11.3, -8.2), 0.0], ["Obligador", Vector2(4.3, -13.3), 0.0],
	["Terrisano", Vector2(-57, 176), 5.0], ["Clubs", Vector2(-63, 177), 3.0], ["Ham", Vector2(-53, 173), 5.0],
	["Breeze", Vector2(-60, 172), 4.0], ["Dockson", Vector2(-67, 174), 4.0], ["Tindwyl", Vector2(-50, 177), 4.0],
	["Elend", Vector2(-217, -238), 6.0], ["Straff", Vector2(-205, -241), 4.0],
	["Cett", Vector2(-110, -70), 0.0], ["Jastes", Vector2(290, -10), 6.0],
	["NinoSkaa", Vector2(-100, 330), 22.0], ["NinaSkaa", Vector2(-92, 324), 22.0],
	["NinaSkaa", Vector2(-280, 250), 6.0],  # Tesa, en los corrales
	["Soldado", Vector2(95, 325), 0.0], ["Soldado", Vector2(90, 331), 0.0], ["Soldado", Vector2(86, 330), 0.0],
	["Soldado", Vector2(166, -190), 0.0], ["Soldado", Vector2(174, -190), 0.0],
]

static var _instance: GateForces
var _posts: Array[Dictionary] = []
var _queue: Array[Npc] = []
var _check_in := 0.0
var _spawn_in := 0.0
var _player: Node3D
var _keep: Array[Resource] = []  # los modelos quedan cargados: volver a la puerta no los lee del disco


## Para el mapa: los que todavía no aparecieron, [posición XZ, es el Lord Legislador]. Se saben de antemano dónde están.
static func far_foes() -> Array:
	var out := []
	if not is_instance_valid(_instance):
		return out
	for post in _instance._posts:
		if post["node"] == null:
			var gate: Array = post["gate"]
			var count: int = FOES.get(gate[0], 0)
			for i in count:
				out.append([_spot(post, i, count), gate[0] == "Puerta Oeste"])
	return out


static func _spot(post: Dictionary, i: int, count: int) -> Vector2:
	return post["at"] + post["gate"][3] * (i - (count - 1) / 2.0) * SPACING


func _ready() -> void:
	_instance = self
	for gate in CityPlan.gates():
		var out := GATE_POST
		while CityPlan.dist_to_river(gate[1] + gate[2] * out) < CityPlan.RIVER_WIDTH + 20.0:
			out += 5.0  # el río pasa pegado a la Puerta Este
		_posts.append({"gate": gate, "node": null, "at": gate[1] + gate[2] * out})
	_posts.append({"gate": [HAZEKILLERS, HAZEKILLER_POST, Vector2.UP, Vector2.RIGHT], "node": null, "at": HAZEKILLER_POST})
	for i in PEOPLE.size():
		_posts.append({"gate": ["persona %d" % i, PEOPLE[i][1], Vector2.DOWN, Vector2.RIGHT], "node": null, "at": PEOPLE[i][1]})
	for model in ["KolossJoven", "KolossAdulto", "LordRuler", "MistbornHood", "Mataneblino", "Soldado", "GordoNoble", "Obligador"]:
		_keep.append(load(Art.MESHY % model))


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
		var p := _spot(post, i, foes.size())
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
			for i in FOES[gate_name]:
				var koloss := Champion.new()
				koloss.kit = "KolossAdulto" if i % 2 == 1 else "KolossJoven"
				foes.append(koloss)
		"Puerta Oeste":
			var ruler := Champion.new()
			ruler.kit = "LordRuler"
			foes.append(ruler)
		"Puerta Sur":
			for i in FOES[gate_name]:
				foes.append(Champion.new())
		HAZEKILLERS:
			for i in FOES[gate_name]:
				var hazekiller := Champion.new()
				hazekiller.kit = "Mataneblino"
				foes.append(hazekiller)
		_:
			foes.append(_person(PEOPLE[gate_name.trim_prefix("persona ").to_int()]))
	return foes


static func _person(spec: Array) -> Npc:
	if spec[0] in ["Soldado", "Obligador"]:
		var guard := Champion.new()
		guard.kit = spec[0]
		return guard
	var c := Citizen.new()
	c.meshy_model = spec[0]
	c.roam_radius = spec[2]
	if spec[0] == "Cett":
		c.add_child((load("res://assets/quaternius/props/Bench_1.glb") as PackedScene).instantiate())
	return c


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
