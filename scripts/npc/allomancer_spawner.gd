class_name AllomancerSpawner
extends Node
## Hace aparecer alománticos por la ciudad de vez en cuando: sueltos o en banda (un Violento,
## un Lanzamonedas y un Humeador que los cubre, a veces con un Aplacador o un Encendedor). Aparecen en calles a cierta distancia del
## jugador, fuera de su vista. Unos son agresivos; otros solo pelean si los provocas.
## Los que quedan fuera de combate se retiran pasado un rato.

@export var max_alive := 5
@export var first_spawn := 12.0
@export var interval := Vector2(35.0, 70.0)

## Tipo y probabilidad de aparecer suelto.
const WEIGHTS := {
	AllomancerNpc.Kind.THUG: 25, AllomancerNpc.Kind.COINSHOT: 20, AllomancerNpc.Kind.LURCHER: 15,
	AllomancerNpc.Kind.TINEYE: 10, AllomancerNpc.Kind.SMOKER: 8, AllomancerNpc.Kind.SEEKER: 12,
	AllomancerNpc.Kind.MISTBORN: 10, AllomancerNpc.Kind.SOOTHER: 8, AllomancerNpc.Kind.RIOTER: 8,
}

var _next := 0.0


func _ready() -> void:
	_next = first_spawn


func _process(delta: float) -> void:
	# De día los alománticos se esconden: salen la mitad de a menudo.
	_next -= delta * (0.5 if Art.lighting == "dia" else 1.0)
	_retire_fallen()
	if _next > 0.0:
		return
	_next = randf_range(interval.x, interval.y)
	if get_tree().get_nodes_in_group(&"allomancer").size() < max_alive:
		spawn_group()


func spawn_group() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var center := _spawn_point(player.global_position if player else Vector3.ZERO)
	var aggressive := randf() < 0.6
	var kinds: Array = []
	if randf() < 0.3:
		kinds = [AllomancerNpc.Kind.THUG, AllomancerNpc.Kind.COINSHOT, AllomancerNpc.Kind.SMOKER]
		if randf() < 0.5:
			kinds.append([AllomancerNpc.Kind.SOOTHER, AllomancerNpc.Kind.RIOTER].pick_random())
	else:
		kinds = [_weighted_kind()]
	for i in kinds.size():
		var a := AllomancerNpc.new()
		a.kind = kinds[i]
		a.team = 1
		a.aggressive = aggressive
		a.stay_in_plaza = false
		a.knockout_time = 30.0
		a.home = center
		a.roam_radius = 10.0
		a.position = center + Vector3(i * 1.5, 0.1, i * 0.8)
		get_tree().current_scene.add_child(a)


func _weighted_kind() -> int:
	var total := 0
	for k in WEIGHTS:
		total += WEIGHTS[k]
	var roll := randi() % total
	for k in WEIGHTS:
		roll -= WEIGHTS[k]
		if roll < 0:
			return k
	return AllomancerNpc.Kind.THUG


## Un punto de alguna calle entre 25 y 45 m del jugador.
func _spawn_point(near: Vector3) -> Vector3:
	var options: Array[Vector3] = []
	for s in CityPlan.street_points():
		var p := Vector3(s.x, CityPlan.ground(s), s.y)
		var d := s.distance_to(Vector2(near.x, near.z))
		if d > 25.0 and d < 45.0:
			options.append(p)
	return options.pick_random() if not options.is_empty() else Vector3(0, CityPlan.ground(Vector2(0, 45)), 45)


func _retire_fallen() -> void:
	for n in get_tree().get_nodes_in_group(&"allomancer"):
		var a := n as AllomancerNpc
		if a == null:
			continue
		if not a.down:
			if a.has_meta(&"down_since"):
				a.remove_meta(&"down_since")
			continue
		if not a.has_meta(&"down_since"):
			a.set_meta(&"down_since", Time.get_ticks_msec())
		elif Time.get_ticks_msec() - int(a.get_meta(&"down_since")) > 20000:
			a.queue_free()
