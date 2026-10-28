class_name ModelBatcher
extends Node3D
## Junta todas las instancias de cada modelo en MultiMesh (una llamada de dibujo por parte de
## modelo en lugar de una por casa) y crea su colisión en un único cuerpo estático.
## Uso: add(...) para cada pieza y, al final, finalize().

var _items := {}  # ruta -> Array[[Transform3D, Color]]
var _body: StaticBody3D


func _ready() -> void:
	_body = StaticBody3D.new()
	_body.collision_layer = Props.LAYER_WORLD
	_body.collision_mask = 0
	add_child(_body)


## yaw: giro sobre el eje vertical (el +Z del modelo mira hacia (sin yaw, cos yaw) en XZ).
func add(model_path: String, pos: Vector3, yaw: float, scale: float, color := Color.WHITE, collide := true) -> void:
	if not _items.has(model_path):
		_items[model_path] = []
	var rot := Basis(Vector3.UP, yaw)
	_items[model_path].append([Transform3D(rot.scaled(Vector3.ONE * scale), pos), color])
	if collide:
		var col := CollisionShape3D.new()
		col.shape = ModelKit.shape(model_path, scale)
		col.transform = Transform3D(rot, pos)
		_body.add_child(col)


func finalize() -> void:
	for model_path in _items:
		var items: Array = _items[model_path]
		for part in ModelKit.parts(model_path):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = part[0]
			mm.instance_count = items.size()
			for i in items.size():
				mm.set_instance_transform(i, items[i][0] * part[1])
				mm.set_instance_color(i, items[i][1])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			add_child(mmi)
	_items.clear()
