class_name ModelBatcher
extends Node3D
## Junta las instancias de cada modelo en MultiMesh por zonas de draw_chunk m (una llamada de
## dibujo por parte de modelo y zona en lugar de una por casa, y las zonas fuera de cámara no se
## dibujan) y crea su colisión en cuerpos estáticos por zonas de CHUNK m (con Jolt, un cuerpo
## con miles de formas tarda muchísimo en armarse).
## Uso: add(...) para cada pieza y, al final, finalize().

var _items := {}  # [ruta, zona] -> Array[[Transform3D, Color]]
var _bodies := {}  # Vector2i -> StaticBody3D, fuera del árbol hasta finalize()
## Apoya cada pieza en el suelo de la ciudad (CityPlan.ground), un poco hundida para que no flote
## en la pendiente.
var on_ground := false
const CHUNK := 64.0
## Lado de las zonas de dibujo y distancia a la que una zona deja de dibujarse (0: siempre).
var draw_chunk := 128.0
var draw_far := 0.0


## yaw: giro sobre el eje vertical (el +Z del modelo mira hacia (sin yaw, cos yaw) en XZ).
func add(model_path: String, pos: Vector3, yaw: float, scale: float, color := Color.WHITE, collide := true) -> void:
	if on_ground:
		pos.y += CityPlan.ground(Vector2(pos.x, pos.z)) - 0.15
	var zone := [model_path, Vector2i(floori(pos.x / draw_chunk), floori(pos.z / draw_chunk))]
	if not _items.has(zone):
		_items[zone] = []
	var rot := Basis(Vector3.UP, yaw)
	_items[zone].append([Transform3D(rot.scaled(Vector3.ONE * scale), pos), color])
	if collide:
		var key := Vector2i(floori(pos.x / CHUNK), floori(pos.z / CHUNK))
		if not _bodies.has(key):
			var body := StaticBody3D.new()
			body.collision_layer = Props.LAYER_WORLD
			body.collision_mask = 0
			_bodies[key] = body
		for shp: Shape3D in ModelKit.shapes(model_path, scale):
			var col := CollisionShape3D.new()
			col.shape = shp
			col.transform = Transform3D(rot, pos)
			_bodies[key].add_child(col)


func finalize() -> void:
	for key in _bodies:
		add_child(_bodies[key])
	_bodies.clear()
	for zone: Array in _items:
		var items: Array = _items[zone]
		for part in ModelKit.parts(zone[0]):
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
			if draw_far > 0.0:
				mmi.visibility_range_end = draw_far
				mmi.visibility_range_end_margin = 20.0
			add_child(mmi)
	_items.clear()
