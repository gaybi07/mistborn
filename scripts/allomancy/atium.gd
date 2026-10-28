class_name Atium
extends Node3D
## Atium.
## Quemando: muestra la "sombra" de cada cosa del grupo "atium_visible" donde estará en unos instantes,
## y esquivas los golpes de quien no queme atium (ver Metals.atium_edge).
## Avivando: efecto Sandevistan — el mundo se ralentiza, tú no, dejas estelas de colores
## y la pantalla se tiñe con aberración cromática.
## Contra otro que quema atium se anulan: no hay cámara lenta y su sombra se divide en futuros
## que saltan de un lado a otro (su futuro depende de lo que tú hagas, y al revés).

@export var slow_time_scale := 0.15
@export var shadow_lookahead := 0.6  ## segundos de futuro que se ven
@export var shadow_range := 45.0
@export var afterimage_interval := 0.045
@export var afterimage_life := 0.5

var player: Player
## 0..1, cuánto está activo el Sandevistan (lo usan la cámara y el shader).
var intensity := 0.0
## Quemas atium y un enemigo cercano también: se anulan.
var contested := false

var _ghosts := {}  # Node3D -> {"node": sombra, "pairs": [[malla, copia]...], "animated": bool}
var _ghost_mat := Afterimage.ghost_material(Color(0.85, 0.9, 1.0), 0.55)
var _overlay: ColorRect
var _overlay_mat: ShaderMaterial
var _afterimage_timer := 0.0
var _hue := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = load("res://shaders/sandevistan.gdshader")
	_overlay.material = _overlay_mat
	_overlay.visible = false
	layer.add_child(_overlay)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	var rd := delta / Engine.time_scale
	var burning := player.allomancy.is_burning(&"atium")
	contested = burning and _rival_burning()
	var flaring := player.allomancy.is_flaring(&"atium") and not contested

	Engine.time_scale = move_toward(Engine.time_scale, slow_time_scale if flaring else 1.0, rd * 4.0)
	intensity = move_toward(intensity, 1.0 if flaring else 0.0, rd * 5.0)
	_hue = fmod(_hue + rd * 0.9, 1.0)
	_overlay.visible = intensity > 0.001
	_overlay_mat.set_shader_parameter(&"intensity", intensity)
	_overlay_mat.set_shader_parameter(&"hue", _hue)

	if flaring:
		_afterimage_timer -= rd
		if _afterimage_timer <= 0.0:
			_afterimage_timer = afterimage_interval
			var ghost := Afterimage.new()
			get_tree().current_scene.add_child(ghost)
			ghost.setup(player.visual, Color.from_hsv(_hue, 0.85, 1.0), afterimage_life)

	_update_shadows(burning)


func _update_shadows(on: bool) -> void:
	var seen := {}
	if on:
		var origin := player.global_position
		for n in get_tree().get_nodes_in_group(&"atium_visible"):
			var body := n as Node3D
			if body == null or body.global_position.distance_to(origin) > shadow_range:
				continue
			var entry: Dictionary = _ghosts.get(body, {})
			if entry.is_empty():
				var node := Node3D.new()
				node.top_level = true
				add_child(node)
				entry = {"node": node, "pairs": Afterimage.copy_meshes(body, node, _ghost_mat), "animated": body is Npc}
				_ghosts[body] = entry
			if entry["animated"]:
				# La sombra copia la pose actual (camina, corre, huye...). Las mallas con esqueleto
				# se vuelven a congelar unas pocas veces por segundo (es más caro).
				var inv := body.global_transform.affine_inverse()
				var rebake := Time.get_ticks_msec() / 1000.0 >= float(entry.get("next_bake", 0.0))
				if rebake:
					entry["next_bake"] = Time.get_ticks_msec() / 1000.0 + 0.15
				for pair in entry["pairs"]:
					var src := pair[0] as MeshInstance3D
					var copy := pair[1] as MeshInstance3D
					copy.transform = inv * src.global_transform
					if rebake and src.skin:
						copy.mesh = src.bake_mesh_from_current_skeleton_pose(copy.mesh as ArrayMesh)
			var ghost: Node3D = entry["node"]
			var xf := body.global_transform
			xf.origin = _predict(body, shadow_lookahead)
			if Metals.burns_atium(body):
				# Él también quema atium: su sombra salta entre futuros posibles.
				var now := Time.get_ticks_msec() / 1000.0
				if now >= float(entry.get("next_jump", 0.0)):
					entry["next_jump"] = now + randf_range(0.05, 0.12)
					entry["jump"] = Vector3(randf_range(-1.8, 1.8), 0, randf_range(-1.8, 1.8))
				xf.origin += entry["jump"] as Vector3
			ghost.global_transform = xf
			ghost.visible = true
			seen[body] = true
	for body in _ghosts.keys():
		if seen.has(body):
			continue
		var ghost: Node3D = _ghosts[body]["node"]
		if not is_instance_valid(body):
			ghost.queue_free()
			_ghosts.erase(body)
		else:
			ghost.visible = false


func _rival_burning() -> bool:
	for n in get_tree().get_nodes_in_group(&"allomancer_body"):
		if n != player and n.get(&"team") != player.team and Metals.burns_atium(n) \
				and (n as Node3D).global_position.distance_to(player.global_position) < shadow_range:
			return true
	return false


func _predict(body: Node3D, t: float) -> Vector3:
	if body.has_method(&"predict_position"):
		return body.predict_position(t)
	var rb := body as RigidBody3D
	if rb == null or rb.freeze or rb.linear_velocity.length() < 0.2:
		return body.global_position
	var g := Vector3.DOWN * _gravity * rb.gravity_scale
	var p := rb.global_position + rb.linear_velocity * t + 0.5 * g * t * t
	# Que la sombra no atraviese el suelo/paredes
	var query := PhysicsRayQueryParameters3D.create(rb.global_position, p, Props.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if hit else p
