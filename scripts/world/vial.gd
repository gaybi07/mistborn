class_name Vial
extends Area3D
## Frasco de metales: flota, gira y brilla. Al tocarlo rellena reservas.
## kind: &"mix" rellena acero/hierro/peltre/estaño; &"atium" rellena atium.

var kind: StringName = &"mix"

var _visual: Node3D
var _t := randf() * TAU


func _ready() -> void:
	collision_layer = 0
	collision_mask = Props.LAYER_PLAYER
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.6
	col.shape = shape
	add_child(col)

	var color := Color(1.0, 0.93, 0.7) if kind == &"atium" else Color(0.45, 0.72, 1.0)
	_visual = Node3D.new()
	add_child(_visual)

	var liquid_mat := Props.material(color, 0.0, 0.2)
	liquid_mat.emission_enabled = true
	liquid_mat.emission = color
	liquid_mat.emission_energy_multiplier = 2.5
	_mesh(CylinderMesh.new(), Vector3(0.05, 0.14, 0.05), Vector3(0, -0.03, 0), liquid_mat)

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.8, 0.9, 1.0, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	glass.rim_enabled = true
	glass.rim = 0.6
	_mesh(CylinderMesh.new(), Vector3(0.065, 0.24, 0.065), Vector3.ZERO, glass)
	_mesh(CylinderMesh.new(), Vector3(0.035, 0.05, 0.035), Vector3(0, 0.14, 0), Props.material(Color(0.45, 0.3, 0.18)))

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.8
	light.omni_range = 2.5
	_visual.add_child(light)

	body_entered.connect(_on_body_entered)


func _mesh(mesh: CylinderMesh, size: Vector3, pos: Vector3, mat: Material) -> void:
	mesh.top_radius = size.x
	mesh.bottom_radius = size.z
	mesh.height = size.y
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	_visual.add_child(mi)


func _process(delta: float) -> void:
	_t += delta
	_visual.position.y = sin(_t * 2.0) * 0.08
	_visual.rotation.y += delta * 1.2
	_visual.rotation.z = sin(_t * 1.3) * 0.15


func _on_body_entered(body: Node3D) -> void:
	var p := body as Player
	if p == null:
		return
	p.rig.play_pickup()
	if kind == &"atium":
		p.allomancy.refill(&"atium", 15.0)
	else:
		for m in [&"steel", &"iron", &"pewter", &"tin"]:
			p.allomancy.refill(m, 50.0)
		if p.vial_charges < p.max_vials():
			p.vial_charges += 1  # te guardas uno en el cinturón
			p.equipment_changed.emit()
	Fx.sparks(get_tree().current_scene, global_position, Color(1.0, 0.9, 0.6) if kind == &"atium" else Color(0.4, 0.7, 1.0))
	queue_free()
