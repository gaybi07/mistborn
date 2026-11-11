class_name TejadosMission
extends Mission
## Sobre los tejados (Story "tejados"): una patrulla de tres te persigue por el barrio skaa. Hay que seguir la ruta de
## techo en techo (columnas de luz, de a una) hasta la última; ahí te acorralan (la narración lo cuenta).
## La ruta sale de los techos que hay de verdad: rayos hacia abajo buscan superficies altas y planas.

const CHECKPOINTS := 6
const REACH := 3.5
const HOP := Vector2(8.0, 18.0)  ## distancia entre un techo y el siguiente
const MAX_RISE := 4.0  ## cuánto más alto puede estar el techo siguiente
const FIRST_RISE := 9.0  ## el primero, desde la calle

var _route: Array[Vector3] = []
var _i := 0
var _beacon: Node3D


func _begin() -> void:
	goal = "Escapar por los tejados"
	var here := Vector2(player.global_position.x, player.global_position.z)
	_route = route_from(here, Story.PLACES["barrio_skaa"]["at"], get_world_3d().direct_space_state)
	_beacon = beacon()
	add_child(_beacon)
	_beacon.global_position = _route[0]
	var back := (here - Vector2(_route[0].x, _route[0].z)).normalized()
	for i in 3:
		soldier(here + back * 14.0 + back.orthogonal() * (i - 1) * 2.5, 50.0)


func target() -> Variant:
	return Vector2(_route[_i].x, _route[_i].z)


func _physics_process(_delta: float) -> void:
	if _done or player.global_position.distance_to(_route[_i]) > REACH:
		return
	_i += 1
	if _i >= _route.size():
		win("ok")
		return
	_beacon.global_position = _route[_i]


## Ruta de techo en techo desde `from`, cruzando el barrio por su centro. Si no hay techos, por la calle.
static func route_from(from: Vector2, center: Vector2, space: PhysicsDirectSpaceState3D) -> Array[Vector3]:
	var roofs: Array[Vector3] = []
	for x in range(-70, 71, 3):
		for z in range(-70, 71, 3):
			var p := center + Vector2(x, z)
			var g := CityPlan.ground(p)
			var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, g + 40.0, p.y), Vector3(p.x, g - 1.0, p.y))
			q.collision_mask = Props.LAYER_WORLD
			var hit := space.intersect_ray(q)
			if not hit.is_empty() and hit["position"].y > g + 3.5 and (hit["normal"] as Vector3).y > 0.55:  # techos de hasta ~56°: los de G28 son empinados
				roofs.append(hit["position"])
	# Hacia el otro lado del barrio; si se llega justo por el centro, hacia el este.
	var away := center - from
	var goal_xz := center + (away.normalized() if away.length() > 1.0 else Vector2.RIGHT) * 70.0
	var out: Array[Vector3] = []
	var cur := Vector3(from.x, CityPlan.ground(from), from.y)
	for k in CHECKPOINTS:
		var best := Vector3.INF
		var best_d := INF
		for r in roofs:
			var d := Vector2(r.x - cur.x, r.z - cur.z).length()
			# El primer techo puede estar más alto (se sube con un empuje); después, de techo en techo.
			if d < HOP.x or d > HOP.y or r.y - cur.y > (FIRST_RISE if k == 0 else MAX_RISE) or r in out:
				continue
			var left := Vector2(r.x, r.z).distance_to(goal_xz)
			if left < best_d:
				best_d = left
				best = r
		if best == Vector3.INF:  # sin techo a mano: por la calle, hacia la meta
			var step := Vector2(cur.x, cur.z).move_toward(goal_xz, HOP.y)
			best = Vector3(step.x, CityPlan.ground(step), step.y)
		out.append(best + Vector3.UP * 0.2)
		cur = best
	return out


## Columna de luz dorada donde hay que llegar.
static func beacon() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.75, 0.3, 0.18)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.2
	cyl.bottom_radius = 1.2
	cyl.height = 9.0
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = mat
	mi.position.y = 4.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.35)
	light.omni_range = 8.0
	light.light_energy = 1.5
	light.position.y = 1.5
	root.add_child(light)
	return root
