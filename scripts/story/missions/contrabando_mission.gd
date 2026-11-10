class_name ContrabandoMission
extends Mission
## Cajas que no existen (Story "contrabando", de Dockson): tres cajas en la Dársena y tres soldados revisando. Se cargan
## con E; si un soldado te ve de cerca, te ataca (y los de al lado también). Con las tres, se vuelve con Dockson.

const CRATES := 3
const SEEN := 7.0  ## a cuánto te ve un soldado

var _crates: Array[Node3D] = []
var _got := 0


func _begin() -> void:
	var c: Vector2 = Story.PLACES["darsena"]["at"]
	var spots := land_spots(c, CRATES)
	for p in spots:
		var crate := (load(ModelKit.path("props/Crate")) as PackedScene).instantiate() as Node3D
		crate.scale = Vector3.ONE * 6.0
		var box := Node3D.new()
		box.add_child(crate)
		box.add_child(Interactable.make(Vector3(2.2, 2.0, 2.2), Vector3(0, 0.8, 0), "Cargar la caja", _take.bind(box)))
		add_child(box)
		box.global_position = Vector3(p.x, CityPlan.ground(p), p.y)
		_crates.append(box)
		soldier(p + Vector2(5, 3), 60.0, false).roam_radius = 8.0
	_goal_text()


## Puntos en tierra firme alrededor de c (la Dársena está sobre el río).
static func land_spots(c: Vector2, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var a := 0.0
	while out.size() < count and a < TAU * 3.0:
		var p := c + Vector2.from_angle(a) * (12.0 + out.size() * 5.0)
		if CityPlan.dist_to_river(p) > CityPlan.RIVER_WIDTH * 0.5 + 6.0:
			out.append(p)
			a += 2.1
		else:
			a += 0.3
	return out


func _take(box: Node3D) -> void:
	_crates.erase(box)
	box.queue_free()
	_got += 1
	_goal_text()
	if _got >= CRATES:
		win("ok")


func _goal_text() -> void:
	goal = "Cargar las cajas sin que te vean (%d/%d)" % [_got, CRATES]


func target() -> Variant:
	var here := Vector2(player.global_position.x, player.global_position.z)
	var best: Variant = null
	for b in _crates:
		var p := Vector2(b.global_position.x, b.global_position.z)
		if best == null or here.distance_to(p) < here.distance_to(best):
			best = p
	return best


func _physics_process(_delta: float) -> void:
	if _done:
		return
	for f in _foes:
		if is_instance_valid(f) and f.global_position.distance_to(player.global_position) < SEEN:
			provoke(f as Champion)
