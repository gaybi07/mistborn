class_name ItemPickup
extends Area3D
## Objeto tirado en el mundo (cofre escondido o botín de un alomántico derrotado).
## Pasar por encima lo guarda en el inventario. Brilla un poco y muestra su nombre de cerca.

var item_id := ""

var _visual: Node3D
var _label: Label3D
var _t := randf() * TAU
var _checked := false


## Un objeto que el jugador todavía no tiene (o "" si ya los tiene todos).
static func random_new_item(player: Player) -> String:
	var pool: Array = Items.DB.keys().filter(func(id: String) -> bool: return not player.has_item(id))
	return "" if pool.is_empty() else pool.pick_random()


func _ready() -> void:
	collision_layer = 0
	collision_mask = Props.LAYER_PLAYER
	monitorable = false
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.9
	col.shape = shape
	col.position.y = 0.5
	add_child(col)
	var it := Items.get_item(item_id)
	_visual = Node3D.new()
	add_child(_visual)
	# Un fardo de tela atado con el color del objeto.
	var bundle := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.25, 0.35)
	bundle.mesh = box
	bundle.material_override = Props.material(Color(0.3, 0.24, 0.17), 0.0, 0.9)
	_visual.add_child(bundle)
	var band := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.1, 0.27, 0.37)
	band.mesh = bb
	var mat := Props.material(it.get("color", Color.WHITE), 0.4 if it.get("metal", false) else 0.0, 0.5)
	mat.emission_enabled = true
	mat.emission = (it.get("color", Color.WHITE) as Color).lightened(0.3)
	mat.emission_energy_multiplier = 0.6
	band.material_override = mat
	_visual.add_child(band)
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.8, 1.0)
	light.light_energy = 0.6
	light.omni_range = 3.0
	light.position.y = 0.6
	add_child(light)
	_label = Label3D.new()
	_label.text = it.get("name", "")
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 36
	_label.pixel_size = 0.005
	_label.outline_size = 8
	_label.position.y = 1.0
	_label.visible = false
	add_child(_label)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if not _checked:
		# Si ya lo tienes (lo recogiste antes de cambiar de mapa), no aparece.
		_checked = true
		var p := get_tree().get_first_node_in_group(&"player") as Player
		if p and p.has_item(item_id):
			queue_free()
			return
	_t += delta
	_visual.position.y = 0.35 + sin(_t * 2.0) * 0.06
	_visual.rotation.y += delta * 0.8
	var cam := get_viewport().get_camera_3d()
	_label.visible = cam != null and cam.global_position.distance_to(global_position) < 12.0


func _on_body_entered(body: Node3D) -> void:
	var p := body as Player
	if p == null or item_id == "":
		return
	p.give_item(item_id)
	p.rig.play_pickup()
	Fx.sparks(get_tree().current_scene, global_position + Vector3(0, 0.4, 0), Color(0.7, 0.85, 1.0))
	queue_free()
