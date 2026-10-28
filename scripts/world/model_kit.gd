class_name ModelKit
## Acceso a los modelos de los packs (Quaternius Medieval Village y Modular Medieval):
## sus mallas con la transformación de cada parte, su tamaño y su colisión exacta (trimesh)
## a una escala dada. Todo se cachea: cada modelo se carga una sola vez.
## Los materiales se copian con vertex_color_use_as_albedo para poder teñir cada instancia.

const ROOT := "res://assets/quaternius/"

static var _parts := {}  # ruta -> Array[[Mesh, Transform3D]]
static var _aabbs := {}  # ruta -> AABB
static var _shapes := {}  # "ruta|escala" -> ConcavePolygonShape3D


static func path(name: String) -> String:
	return ROOT + name + ".glb"


static func parts(model_path: String) -> Array:
	if _parts.has(model_path):
		return _parts[model_path]
	var scene: Node = (load(model_path) as PackedScene).instantiate()
	var out := []
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var xf := mi.transform
		var p := mi.get_parent()
		while p and p != scene:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		out.append([_tintable(mi.mesh), xf])
		var b: AABB = xf * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	scene.free()
	_parts[model_path] = out
	_aabbs[model_path] = box
	return out


static func aabb(model_path: String) -> AABB:
	parts(model_path)
	return _aabbs[model_path]


## Radio de la huella en planta a una escala dada.
static func footprint(model_path: String, scale: float) -> float:
	var s := aabb(model_path).size
	return maxf(s.x, s.z) * scale / 2.0


static func shape(model_path: String, scale: float) -> ConcavePolygonShape3D:
	var key := "%s|%s" % [model_path, scale]
	if _shapes.has(key):
		return _shapes[key]
	var faces := PackedVector3Array()
	var s := Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO)
	for part in parts(model_path):
		var xf: Transform3D = s * part[1]
		for v in (part[0] as Mesh).get_faces():
			faces.append(xf * v)
	var shp := ConcavePolygonShape3D.new()
	shp.set_faces(faces)
	_shapes[key] = shp
	return shp


static func _tintable(mesh: Mesh) -> Mesh:
	var copy: Mesh = mesh.duplicate()
	for i in copy.get_surface_count():
		var m := copy.surface_get_material(i) as BaseMaterial3D
		if m:
			m = m.duplicate()
			m.vertex_color_use_as_albedo = true
			copy.surface_set_material(i, m)
	return copy
