class_name Portal
extends Area3D
## Puerta a otro mapa: al cruzarla el jugador, fundido a negro y cambio de escena.
## En la escena de destino el jugador aparece en `arrival` (la escena lo pide con take_arrival()).
## Se ve como un umbral de bruma oscura con un cartel.

@export_file("*.tscn") var target_scene := ""
@export var arrival := Vector3.ZERO
## Ancho y alto del umbral.
@export var door_size := Vector2(3.0, 4.2)
@export var label := ""
## Para escenas con varios niveles (Kredik Shaw): qué nivel cargar al llegar.
@export var target_level := ""

## Posición de llegada pendiente tras cruzar una puerta (null: ninguna).
static var _pending: Variant = null
static var _pending_level := ""

var _used := false


## La posición donde debe aparecer el jugador en la escena nueva (o `fallback` si no vino por una puerta).
static func take_arrival(fallback: Vector3) -> Vector3:
	var p: Variant = _pending
	_pending = null
	return p if p != null else fallback


## El nivel pedido por la puerta que se cruzó (o `fallback`).
static func take_level(fallback: String) -> String:
	var l := _pending_level
	_pending_level = ""
	return l if l != "" else fallback


func _ready() -> void:
	collision_layer = 0
	collision_mask = Props.LAYER_PLAYER
	monitorable = false
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(door_size.x, door_size.y, 0.8)
	col.shape = shape
	col.position.y = door_size.y / 2.0
	add_child(col)

	# Umbral: un velo de bruma que respira.
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = Fx.soft_texture()
	mat.albedo_color = Color(0.55, 0.62, 0.8, 0.55)
	var quad := QuadMesh.new()
	quad.size = Vector2(door_size.x * 1.3, door_size.y * 1.3)
	var veil := MeshInstance3D.new()
	veil.mesh = quad
	veil.material_override = mat
	veil.position.y = door_size.y / 2.0
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(veil)
	var tween := create_tween().set_loops()
	tween.tween_property(mat, "albedo_color:a", 0.3, 1.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mat, "albedo_color:a", 0.6, 1.6).set_trans(Tween.TRANS_SINE)
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.68, 0.9)
	light.light_energy = 1.2
	light.omni_range = 6.0
	light.position = Vector3(0, door_size.y * 0.5, 0.8)
	add_child(light)
	if label != "":
		var l := Label3D.new()
		l.text = label
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 48
		l.pixel_size = 0.006
		l.outline_size = 10
		l.modulate = Color(0.85, 0.88, 0.95, 0.85)
		l.position.y = door_size.y + 0.6
		add_child(l)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _used or not body is Player or target_scene == "":
		return
	_used = true
	_pending = arrival
	_pending_level = target_level
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(fade)
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(fade, "color:a", 1.0, 0.5)
	tween.tween_callback(func() -> void:
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file(target_scene)
	)
