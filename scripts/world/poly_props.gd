class_name PolyProps
## Modelos de Poly Haven (assets/models/polyhaven/<nombre>/<nombre>.gltf) dibujados en lote: por
## cada malla del modelo, un MultiMesh con todas sus copias (una llamada de dibujo por malla,
## aunque haya cientos). Los que estorban llevan colisión de caja (su AABB).

const DIR := "res://assets/models/polyhaven/%s/%s.gltf"
## Los que no se atraviesan.
const SOLID := ["wooden_crate_01", "WoodenTable_02", "GothicCabinet_01", "treasure_chest", "gothic_statue",
		"large_castle_door", "boulder_01", "dead_tree_trunk_02", "GothicBed_01", "GothicCommode_01", "ClassicConsole_01",
		"Sofa_01", "ArmChair_01", "Ottoman_01", "gothic_coffee_table", "painted_wooden_bench", "ClassicNightstand_01"]

## Tono que se les aplica (roca volcánica y madera gastada por la ceniza).
const TINT := {"boulder_01": Color(0.32, 0.3, 0.3), "dead_tree_trunk_02": Color(0.5, 0.45, 0.4)}

## Tope de triángulos por modelo: los de Poly Haven traen mucho detalle (hasta 100 mil) y aquí van
## cientos de copias. Se usa el nivel de detalle (LOD) que generó el importador que entra en el tope.
const BUDGET := {"boulder_01": 2500, "dead_tree_trunk_02": 3000, "treasure_chest": 5000, "Lantern_01": 1500,
		"brass_candleholders": 5000, "gothic_statue": 9000, "marble_bust_01": 3000, "WoodenChair_01": 3000,
		"GothicCabinet_01": 5000, "large_castle_door": 5000, "wooden_crate_01": 2500, "kite_shield": 2500,
		"lantern_chandelier_01": 6000, "Chandelier_01": 3600, "Chandelier_03": 5000, "GothicBed_01": 4700,
		"ArmChair_01": 3000, "dining_chair_02": 2500, "gothic_coffee_table": 3000, "chess_set": 2500,
		"brass_goblets": 1500, "antique_ceramic_vase_01": 2000, "ornate_mirror_01": 2000, "mantel_clock_01": 1200, "Ottoman_01": 2500}
## Sin sombra (chicos: la sombra duplica el costo y casi no se nota).
const NO_SHADOW := ["Lantern_01", "brass_candleholders", "marble_bust_01", "wooden_crate_01", "kite_shield", "boulder_01",
		"brass_goblets", "chess_set", "mantel_clock_01", "ornate_mirror_01", "ClassicNightstand_01"]

static var _parts := {}  # nombre -> [[Mesh, Transform3D local], ...]
static var _boxes := {}  # nombre -> AABB del modelo


## [[malla, transformación dentro del modelo], ...] y su caja (se leen una vez).
static func parts(name: String) -> Array:
	if not _parts.has(name):
		var inst := (load(DIR % [name, name]) as PackedScene).instantiate() as Node3D
		var out := []
		var box := AABB()
		var first := true
		for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
			var xf := _local(mi, inst)
			out.append([_reduced(mi.mesh, BUDGET.get(name, 6000) / maxi(1, inst.find_children("*", "MeshInstance3D", true, false).size())), xf])
			var b := xf * mi.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		inst.free()
		_parts[name] = out
		_boxes[name] = box
	return _parts[name]


static func box(name: String) -> AABB:
	parts(name)
	return _boxes[name]


## La misma malla con el LOD más detallado que no pasa de `max_tris` triángulos por superficie.
static func _reduced(mesh: Mesh, max_tris: int) -> Mesh:
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.size() / 3 > max_tris:
			var surf := RenderingServer.mesh_get_surface(mesh.get_rid(), s)
			var wide: bool = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 65535
			for lod: Dictionary in surf.get("lods", []):
				var data: PackedByteArray = lod["index_data"]
				var lod_idx := data.to_int32_array() if wide else _u16(data)
				idx = lod_idx
				if lod_idx.size() / 3 <= max_tris:
					break
			arrays[Mesh.ARRAY_INDEX] = idx
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(s, mesh.surface_get_material(s))
	return out


static func _u16(data: PackedByteArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(data.size() / 2)
	for i in out.size():
		out[i] = data.decode_u16(i * 2)
	return out


static func _local(n: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur := n
	while cur != root and cur != null:
		xf = cur.transform * xf
		cur = cur.get_parent() as Node3D
	return xf


## Transformación que apoya el modelo en el suelo en `pos` (su base en pos.y), girado `yaw`.
static func at(name: String, pos: Vector3, yaw := 0.0, scale := 1.0) -> Transform3D:
	var b := box(name)
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
	var foot := Vector3(b.get_center().x, b.position.y, b.get_center().z) * scale
	return Transform3D(basis, pos - Basis(Vector3.UP, yaw) * foot)


## Dibuja (y da colisión a) todas las copias: props = {nombre: [Transform3D, ...]}.
## Con `tile` > 0 las copias se agrupan por parcelas de ese lado (en el plano) y cada parcela deja
## de dibujarse a `far` m de la cámara: para interiores grandes llenos de muebles (Kredik Shaw).
static func spawn(parent: Node, props: Dictionary, tile := 0.0, far := 0.0) -> void:
	for name: String in props:
		var xfs: Array = props[name]
		if xfs.is_empty():
			continue
		var groups := {}
		for xf: Transform3D in xfs:
			var key := Vector2i(floori(xf.origin.x / tile), floori(xf.origin.z / tile)) if tile > 0.0 else Vector2i.ZERO
			if not groups.has(key):
				groups[key] = []
			groups[key].append(xf)
		for part: Array in parts(name):
			for group: Array in groups.values():
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = part[0]
				mm.instance_count = group.size()
				for i in group.size():
					mm.set_instance_transform(i, (group[i] as Transform3D) * (part[1] as Transform3D))
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				if far > 0.0:
					mmi.visibility_range_end = far
					mmi.visibility_range_end_margin = 8.0
					mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				if name in NO_SHADOW:
					mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if TINT.has(name):
					var mat := (part[0] as Mesh).surface_get_material(0).duplicate() as BaseMaterial3D
					mat.albedo_color = mat.albedo_color * TINT[name]
					mmi.material_override = mat
				parent.add_child(mmi)
		if name in SOLID:
			var body := StaticBody3D.new()
			body.collision_layer = Props.LAYER_WORLD
			body.collision_mask = 0
			var b := box(name)
			for xf: Transform3D in xfs:
				var col := CollisionShape3D.new()
				var shape := BoxShape3D.new()
				shape.size = b.size * xf.basis.get_scale()
				col.shape = shape
				col.transform = Transform3D(xf.basis.orthonormalized(), xf * b.get_center())
				body.add_child(col)
			parent.add_child(body)


## Agrega una copia a la lista de `name`.
static func add(props: Dictionary, name: String, xf: Transform3D) -> void:
	if not props.has(name):
		props[name] = []
	props[name].append(xf)
