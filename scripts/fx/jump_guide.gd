class_name JumpGuide
extends MeshInstance3D
## Ayuda del salto con G: dibuja la parábola que seguirías si soltaras ahora (solo la gravedad)
## y un anillo donde caerías. Se ve a través de las paredes.

const STEP := 0.05
const MAX_TIME := 4.0
const COLOR := Color(0.45, 0.75, 1.0, 0.75)

var _mesh := ImmediateMesh.new()
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	top_level = true
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	material_override = mat


## Con `on` falso se borra. `exclude`: cuerpos que el trazo ignora (el propio jugador).
func show_path(on: bool, from: Vector3, velocity: Vector3, exclude: Array[RID]) -> void:
	_mesh.clear_surfaces()
	if not on:
		return
	global_transform = Transform3D.IDENTITY
	var space := get_world_3d().direct_space_state
	var p := from
	var v := velocity
	var points: Array[Vector3] = [p]
	var landing: Variant = null
	var t := 0.0
	while t < MAX_TIME:
		var next := p + v * STEP
		v.y -= _gravity * STEP
		var q := PhysicsRayQueryParameters3D.create(p, next, Props.LAYER_WORLD | Props.LAYER_PROPS, exclude)
		var hit := space.intersect_ray(q)
		if hit:
			points.append(hit["position"])
			landing = hit
			break
		points.append(next)
		p = next
		t += STEP
	# Trazo discontinuo que se desvanece al alejarse.
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in points.size() - 1:
		if i % 2 == 1:
			continue
		var fade := 1.0 - float(i) / points.size() * 0.6
		_mesh.surface_set_color(Color(COLOR, COLOR.a * fade))
		_mesh.surface_add_vertex(points[i])
		_mesh.surface_add_vertex(points[i + 1])
	if landing != null:
		var c: Vector3 = landing["position"]
		var n: Vector3 = landing["normal"]
		var a := n.cross(Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var b := n.cross(a)
		for ring in [0.6, 0.25]:
			for k in 24:
				var a0 := TAU * k / 24.0
				var a1 := TAU * (k + 1) / 24.0
				_mesh.surface_set_color(COLOR)
				_mesh.surface_add_vertex(c + n * 0.05 + (a * cos(a0) + b * sin(a0)) * ring)
				_mesh.surface_add_vertex(c + n * 0.05 + (a * cos(a1) + b * sin(a1)) * ring)
	_mesh.surface_end()
