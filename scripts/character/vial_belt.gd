class_name VialBelt
extends Node3D
## Cinturón de cuero con los frascos del inventario. Sigue el contorno real de la cintura de cada modelo.
## Los frascos usan los colores y el orden de la barra del HUD: el último que queda es el primero en salir.

const VIAL_MODEL := "res://assets/weapons/vial.glb"
const WAIST_UP := 0.07  # m sobre el hueso de la cadera
const STRAP_HEIGHT := 0.045
const SECTORS := 48
const WAIST_BONES := ["Hips", "Spine", "Spine1", "LeftUpLeg", "RightUpLeg"]
## Lugar de cada frasco alrededor del cuerpo, en grados desde el frente.
const SLOT_ANGLES := [-62.0, -36.0, 40.0, 66.0]
const VIAL_SCALE := 1.0
const LARGE_SCALE := 1.2
const WOOD := Color(0.3, 0.19, 0.1)

static var _leather_mat: StandardMaterial3D
static var _brass_mat: StandardMaterial3D

var _slots: Array[Node3D] = []
var _loops: Array[Node3D] = []
var _radii := PackedFloat32Array()
var _center := Vector3.ZERO
var _kind := ""
var _count := 0
var _held_slot := -1


## model: lo que contiene las mallas del cuerpo. La cintura se mide en la pose de reposo del esqueleto.
func build(model: Node3D, skel: Skeleton3D, hips: int) -> void:
	_center = skel.get_bone_global_rest(hips).origin + Vector3.UP * WAIST_UP
	_radii = _measure_waist(model, skel)
	transform = skel.get_bone_global_rest(hips).affine_inverse()
	var strap := MeshInstance3D.new()
	strap.mesh = _strap_mesh()
	strap.material_override = _leather()
	add_child(strap)
	_part(BoxMesh.new(), Vector3(0.05, 0.05, 0.008), _on_waist(0.0, 0.004), 0.0, _brass())
	_part(BoxMesh.new(), Vector3(0.034, 0.03, 0.01), _on_waist(0.0, 0.006), 0.0, _leather())


## kind: id del objeto de frascos. count: cuántos quedan. Con otro tipo de frasco se arman de nuevo.
func set_vials(kind: String, capacity: int) -> void:
	if kind == _kind and _slots.size() == capacity:
		return
	_kind = kind
	for old: Node3D in _slots + _loops:
		old.queue_free()
	_slots.clear()
	_loops.clear()
	for i in mini(capacity, SLOT_ANGLES.size()):
		var a: float = SLOT_ANGLES[i]
		var loop_pos := _on_waist(a, 0.01)
		_loops.append(_part(BoxMesh.new(), Vector3(0.042, 0.03, 0.012), loop_pos, a, _leather()))
		var slot := make_vial(i)
		slot.position = _on_waist(a, 0.026) + Vector3.DOWN * 0.05
		add_child(slot)
		_slots.append(slot)
	_refresh()


func show_count(count: int) -> void:
	if count != _count:
		_count = count
		_refresh()


## Saca del cinturón el último frasco. Devuelve cuál era, o -1 si no queda ninguno.
func take() -> int:
	_held_slot = mini(_count, _slots.size()) - 1
	_refresh()
	return _held_slot


func put_back() -> void:
	_held_slot = -1
	_refresh()


func make_vial(i: int) -> Node3D:
	var vial: Node3D = (load(VIAL_MODEL) as PackedScene).instantiate()
	vial.scale = Vector3.ONE * (LARGE_SCALE if _kind == "large_vials" else VIAL_SCALE)
	var color: Color = HudKit.VIAL_COLORS[i % HudKit.VIAL_COLORS.size()]
	for mi: MeshInstance3D in vial.find_children("*", "MeshInstance3D", true, false):
		if mi.name == "vial_liquid":
			var m := mi.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
			m.albedo_color = Color(color, 0.92)
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = 0.15
			mi.material_override = m
		elif mi.name == "vial_glass" and _kind == "wooden_vials":
			var wood := StandardMaterial3D.new()
			wood.albedo_color = WOOD
			wood.roughness = 0.8
			mi.material_override = wood
	return vial


func _refresh() -> void:
	for i in _slots.size():
		_slots[i].visible = i < _count and i != _held_slot


func _part(mesh: BoxMesh, size: Vector3, at: Vector3, angle: float, mat: Material) -> MeshInstance3D:
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation.y = deg_to_rad(angle)
	add_child(mi)
	return mi


func _on_waist(angle_deg: float, out: float) -> Vector3:
	var a := deg_to_rad(angle_deg)
	var f := fposmod(a / TAU, 1.0) * SECTORS
	var k := int(f)
	var r := lerpf(_radii[k % SECTORS], _radii[(k + 1) % SECTORS], f - k) + out
	return _center + Vector3(sin(a) * r, 0.0, cos(a) * r)


## Radio del cuerpo por sectores (0 = frente, +Z), solo con lo que pesa en la cadera y el vientre: sin brazos ni mangas.
func _measure_waist(model: Node3D, skel: Skeleton3D) -> PackedFloat32Array:
	var radii := PackedFloat32Array()
	radii.resize(SECTORS)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null:
			continue
		var allowed := {}
		for b in mi.skin.get_bind_count():
			var bone := mi.skin.get_bind_bone(b)
			var bone_name := String(mi.skin.get_bind_name(b)) if bone < 0 else skel.get_bone_name(bone)
			if bone_name in WAIST_BONES:
				allowed[b] = true
		var to_skel := skel.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var per := bones.size() / maxi(verts.size(), 1)
			for i in verts.size():
				var p := to_skel * verts[i]
				if absf(p.y - _center.y) > STRAP_HEIGHT or not allowed.has(_main_bone(bones, weights, i, per)):
					continue
				var d := Vector2(p.x - _center.x, p.z - _center.z)
				var k := posmod(int(round(atan2(d.x, d.y) / TAU * SECTORS)), SECTORS)
				radii[k] = maxf(radii[k], d.length())
	return _smooth(radii)


static func _main_bone(bones: PackedInt32Array, weights: PackedFloat32Array, i: int, per: int) -> int:
	var best := 0
	for j in per:
		if weights[i * per + j] > weights[i * per + best]:
			best = j
	return bones[i * per + best]


## Rellena los sectores sin vértices y saca los picos de un pliegue suelto.
static func _smooth(radii: PackedFloat32Array) -> PackedFloat32Array:
	var known := PackedFloat32Array()
	for r in radii:
		if r > 0.0:
			known.append(r)
	var fallback: float = known[known.size() / 2] if not known.is_empty() else 0.15
	for k in SECTORS:
		if radii[k] <= 0.0:
			var a := radii[(k + SECTORS - 1) % SECTORS]
			radii[k] = a if a > 0.0 else fallback
	for pass_i in 3:
		var next := radii.duplicate()
		for k in SECTORS:
			next[k] = (radii[(k + SECTORS - 1) % SECTORS] + radii[k] * 2.0 + radii[(k + 1) % SECTORS]) / 4.0
		radii = next
	return radii


## Una tira cerrada: cara de afuera y dos filos de la misma textura.
func _strap_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := 0.0
	var rows := [[-0.5, 0.0], [0.5, 0.0]]
	for k in SECTORS + 1:
		var a := float(k) / SECTORS * 360.0
		var p := _on_waist(a, 0.008)
		var out := Vector3(p.x - _center.x, 0.0, p.z - _center.z).normalized()
		if k > 0:
			length += p.distance_to(_on_waist(float(k - 1) / SECTORS * 360.0, 0.008))
		for row: Array in rows:
			st.set_normal(out)
			st.set_uv(Vector2(length / 0.36, row[0] + 0.5))
			st.add_vertex(p + Vector3.UP * row[0] * STRAP_HEIGHT)
	for k in SECTORS:
		var a := k * 2
		for i in [a, a + 2, a + 1, a + 1, a + 2, a + 3]:
			st.add_index(i)
	st.generate_tangents()
	return st.commit()


static func _brass() -> StandardMaterial3D:
	if _brass_mat == null:
		_brass_mat = StandardMaterial3D.new()
		_brass_mat.albedo_color = Color(0.72, 0.55, 0.28)
		_brass_mat.metallic = 0.9
		_brass_mat.roughness = 0.35
	return _brass_mat


## Cuero marrón gastado con costuras en los dos bordes: color y relieve salen del mismo mapa de alturas.
static func _leather() -> StandardMaterial3D:
	if _leather_mat != null:
		return _leather_mat
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.09
	noise.fractal_octaves = 3
	var grain := noise.get_seamless_image(512, 64)
	grain.convert(Image.FORMAT_RGBA8)
	var albedo := Image.create(512, 64, false, Image.FORMAT_RGBA8)
	var height := Image.create(512, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		var edge := minf(y, 63 - y) / 8.0
		for x in 512:
			var g := grain.get_pixel(x, y).r
			var stitch: bool = (y in [6, 7, 56, 57]) and x % 14 < 9
			var wear := clampf(edge, 0.55, 1.0)
			var c := Color(0.27, 0.16, 0.09).lerp(Color(0.4, 0.26, 0.15), g) * wear
			albedo.set_pixel(x, y, Color(0.62, 0.5, 0.33) if stitch else Color(c, 1.0))
			var h := 0.9 if stitch else g * 0.45 + 0.25 * clampf(edge, 0.0, 1.0)
			height.set_pixel(x, y, Color(h, h, h))
	height.bump_map_to_normal_map(2.5)
	albedo.generate_mipmaps()
	height.generate_mipmaps()
	_leather_mat = StandardMaterial3D.new()
	_leather_mat.albedo_texture = ImageTexture.create_from_image(albedo)
	_leather_mat.normal_enabled = true
	_leather_mat.normal_texture = ImageTexture.create_from_image(height)
	_leather_mat.roughness = 0.7
	_leather_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _leather_mat
