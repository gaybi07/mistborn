class_name SkaaCrews
extends Node
## Cuadrillas de skaa trabajando en las calles de los barrios obreros. Hay muchos puestos en la ciudad,
## pero cada skaa es un personaje animado: solo existen los de los puestos cerca del jugador.

const ACTIVE_RADIUS := 80.0
const FREE_RADIUS := 100.0
const SITE_STEP := 45.0  # uno cada tantos metros de calle
const SITE_GAP := 30.0
const MAX_SITES := 6  # activos a la vez
const SPAWN_EVERY := 0.1  # de a uno, para que aparecer no trabe el juego
const MEGAKIT := "res://assets/quaternius/megakit/%s.gltf"
const KIT_SCALE := 3.2  # los de ModelKit vienen chicos (ver Main)

## Barrio -> trabajos que hay en sus calles.
const WORK := {
	"Distrito Skaa": ["obra", "carga", "reparacion", "descanso"],
	"Distrito de Forja": ["taller", "carga", "descanso"],
	"Corrales de carbón": ["obra", "carga"],
	"Talleres y almacenes": ["taller", "carga", "reparacion"],
	"Dársena": ["carga", "carga", "descanso"],
	# Donde no se trabaja en la calle, gente que pasa.
	"Distrito Mercantil": ["paseo"],
	"Viviendas de mercaderes": ["paseo"],
	"Distrito Noble": ["paseo"],
	"Laderas de Kredik Shaw": ["paseo"],
}
## tasks: uno por skaa (ver SkaaWorker). carriers: acarrean cajas por la calle. props: lo que hay alrededor.
## walkers: los que andan por ahí (uno si no se dice).
const CREWS := {
	"obra": {"tasks": ["dig", "dig", "kneel_pull", "lift_heavy"], "carriers": 1,
		"props": ["Bucket_Wooden_1", "Crate_Wooden", "Bucket_Wooden_1"]},
	"carga": {"tasks": ["push_heavy", "pull_heavy", "lift_heavy"], "carriers": 2,
		"props": ["props/Cart", "Crate_Wooden", "Barrel", "FarmCrate_Empty"]},
	"reparacion": {"tasks": ["kneel_work", "kneel_inspect", "kneel_work"], "carriers": 0,
		"props": ["Crate_Wooden", "Bucket_Metal", "Barrel"]},
	"taller": {"tasks": ["kneel_work", "kneel_inspect", "pull_heavy"], "carriers": 1,
		"props": ["Workbench", "Anvil_Log", "Barrel", "Whetstone"]},
	"descanso": {"tasks": ["sad_idle", "warm_hands", "warm_hands"], "carriers": 0,
		"props": ["Bench", "Bucket_Wooden_1"]},
	"paseo": {"tasks": [], "carriers": 0, "props": [], "walkers": 4},
}

var _sites: Array[Dictionary] = []
var _queue: Array[Node3D] = []  # skaa por entrar a su cuadrilla
var _check_in := 0.0
var _spawn_in := 0.0
var _player: Node3D
var _keep: Array[Resource] = []  # sin nadie que los retenga, cada skaa nuevo los lee otra vez del disco


func _ready() -> void:
	_sites = find_sites()
	print("Luthadel: %d puestos de trabajo skaa" % _sites.size())
	var rig := Art.skaa_rig()
	var paths: Array = Art.SKAA_MODELS + [SkaaGirl.MODEL, rig.retarget_from, rig.extra_donors[0][0], ModelKit.path("props/Cart")]
	rig.free()
	for spec: Dictionary in CREWS.values():
		for prop: String in spec["props"]:
			if not prop.begins_with("props/"):
				paths.append(MEGAKIT % prop)
	for path: String in paths:
		_keep.append(load(path))


func _process(delta: float) -> void:
	_spawn_in -= delta
	if _spawn_in <= 0.0 and not _queue.is_empty():
		_spawn_in = SPAWN_EVERY
		var who: Node3D = _queue.pop_front()
		who.get_meta(&"crew").add_child(who)
	_check_in -= delta
	if _check_in > 0.0:
		return
	_check_in = 0.5
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
		if _player == null:
			return
	var at := Vector2(_player.global_position.x, _player.global_position.z)
	var active := 0
	var nearest: Dictionary = {}
	var best := ACTIVE_RADIUS
	for s in _sites:
		var d := at.distance_to(s["pos"])
		if s["node"] != null:
			if d > FREE_RADIUS:
				_drop(s["node"])
				s["node"] = null
			else:
				active += 1
		elif d < best:
			best = d
			nearest = s
	if active < MAX_SITES and not nearest.is_empty():
		if _blocked(nearest):
			_sites.erase(nearest)
		else:
			_start(nearest)


## Recorre las calles principales de los barrios obreros y deja un puesto cada SITE_STEP metros.
static func find_sites() -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7  # siempre los mismos puestos
	var out: Array[Dictionary] = []
	for seg in CityPlan.street_segments():
		if seg[2] != CityPlan.STREET_HALF:
			continue
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		for k in int(a.distance_to(b) / SITE_STEP):
			var p := a.lerp(b, (k + 0.5) * SITE_STEP / a.distance_to(b))
			var kinds: Array = WORK.get(CityPlan.district(p)["name"], [])
			if kinds.is_empty() or not CityPlan.inside(p, 12.0) or CityPlan.dist_to_river(p) < CityPlan.RIVER_WIDTH + 8.0:
				continue
			if p.distance_to(Workshop.POS) < 16.0 or out.any(func(s: Dictionary) -> bool: return p.distance_to(s["pos"]) < SITE_GAP):
				continue
			out.append({"pos": p, "dir": (b - a).normalized(), "side": 1.0 if rng.randf() < 0.5 else -1.0,
					"kind": kinds[rng.randi() % kinds.size()], "node": null})
	return out


## Los montones de carbón se ubican al azar y pueden caer sobre la calle: ese puesto no se usa.
func _blocked(site: Dictionary) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	query.shape = sphere
	var d: Vector2 = site["dir"]
	var n: Vector2 = Vector2(-d.y, d.x) * site["side"]
	for spot: Vector2 in [Vector2(2.4, -4.2), Vector2(2.4, 0.0), Vector2(2.4, 4.2), Vector2(-3.2, -5.0), Vector2(-3.2, 5.0)]:
		var at: Vector2 = site["pos"] + n * spot.x + d * spot.y
		query.transform = Transform3D(Basis.IDENTITY, _on_ground(at) + Vector3.UP)
		for hit in _player.get_world_3d().direct_space_state.intersect_shape(query, 4):
			if hit["collider"] is StaticBody3D:
				return true
	return false


func _start(site: Dictionary) -> void:
	var crew := Node3D.new()  # en el origen del mundo: lo de adentro se ubica en coordenadas globales
	add_child(crew)
	site["node"] = crew
	var spec: Dictionary = CREWS[site["kind"]]
	var d: Vector2 = site["dir"]
	var n: Vector2 = Vector2(-d.y, d.x) * site["side"]
	var base: Vector2 = site["pos"] + n * 2.4  # a un lado: la otra mano de la calle queda libre
	var tasks: Array = spec["tasks"]
	for i in tasks.size():
		var p: Vector2 = base + d * (i - (tasks.size() - 1) / 2.0) * 2.8 + n * randf_range(-0.3, 0.3)
		var w := SkaaWorker.new()
		w.task = tasks[i]
		w.position = _on_ground(p)
		w.rotation.y = _yaw_towards(n if tasks[i] not in ["sad_idle", "warm_hands"] else -n) + randf_range(-0.4, 0.4)
		_enqueue(w, crew)
	var props: Array = spec["props"]
	for i in props.size():
		var p: Vector2 = base + n * 1.0 + d * (i - (props.size() - 1) / 2.0) * 2.4
		var prop := _prop(props[i])
		prop.position = _on_ground(p)
		prop.rotation.y = _yaw_towards(d) + randf_range(-0.2, 0.2)
		crew.add_child(prop)
	var reach := tasks.size() * 1.4 + 1.0
	for i in spec["carriers"]:
		var from: Vector2 = base - n * 1.2 * (i + 1) - d * reach
		var to: Vector2 = from + d * reach * 2.0
		var c := SkaaWorker.new()
		c.position = _on_ground(from)
		c.route = _on_ground(to) - c.position
		_enqueue(c, crew)
	if site["kind"] == "descanso":
		_add_girl(crew, site["pos"] - n * 3.2, d, _yaw_towards(n))
	for i in spec.get("walkers", 1):
		var walker := Citizen.new()
		walker.skaa = true
		walker.stay_in_plaza = false
		walker.home = _on_ground(site["pos"] + d * randf_range(-12.0, 12.0))
		walker.roam_radius = 14.0
		walker.position = walker.home + Vector3.UP * 0.1
		_enqueue(walker, crew)


## La nena va y viene por la vereda de enfrente.
func _add_girl(crew: Node3D, center: Vector2, d: Vector2, yaw: float) -> void:
	var girl := SkaaGirl.new()
	girl.facing = yaw
	for side in [-5.0, 5.0]:
		girl.spots.append(_on_ground(center + d * side))
	_enqueue(girl, crew)


static func _prop(prop_name: String) -> Node3D:
	if prop_name.begins_with("props/"):
		var kit := (load(ModelKit.path(prop_name)) as PackedScene).instantiate() as Node3D
		kit.scale = Vector3.ONE * KIT_SCALE
		return kit
	return (load(MEGAKIT % prop_name) as PackedScene).instantiate() as Node3D


func _enqueue(who: Node3D, crew: Node3D) -> void:
	who.set_meta(&"crew", crew)
	_queue.append(who)


## Los que seguían en la cola todavía no están en el árbol: hay que liberarlos a mano.
func _drop(crew: Node3D) -> void:
	for who in _queue.filter(func(w: Node3D) -> bool: return w.get_meta(&"crew") == crew):
		_queue.erase(who)
		who.free()
	crew.queue_free()


func _exit_tree() -> void:
	for who in _queue:
		who.free()
	_queue.clear()


static func _on_ground(p: Vector2) -> Vector3:
	return Vector3(p.x, CityPlan.ground(p), p.y)


static func _yaw_towards(dir: Vector2) -> float:
	return atan2(-dir.x, -dir.y)  # -Z es el frente
