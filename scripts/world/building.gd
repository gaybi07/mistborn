class_name Building
extends Node3D
## Base de los edificios hechos a mano (taller de Clubs, mansión Venture): materiales comunes,
## piezas (cajas, cilindros con o sin colisión), modelos de los packs a tamaño real, faroles y el
## hueco en la bruma del interior.

const MEGA := "res://assets/quaternius/megakit/"
const RAD := "res://assets/radchenko/furniture.glb"

var _m := {}
var _rng := RandomNumberGenerator.new()
static var _scenes := {}
## Zonas de interior en las que está el jugador (pueden solaparse al pasar de una a otra).
static var _indoor_count := 0


# ---------------------------------------------------------------- Materiales

func _make_materials() -> void:
	_m = WorldKit.materials().duplicate()
	_m["floor"] = _planks(Color(0.3, 0.21, 0.14), 0.22, 0.35)
	_m["boards"] = _planks(Color(0.27, 0.19, 0.12), 0.16, 0.5)
	_m["bench"] = _planks(Color(0.36, 0.26, 0.17), 0.3, 0.6, true)
	_m["beam"] = _planks(Color(0.12, 0.085, 0.06), 6.0, 0.6)
	_m["pale_wood"] = _planks(Color(0.5, 0.38, 0.25), 0.12)
	_m["red_wood"] = _planks(Color(0.32, 0.15, 0.1), 0.2)
	var roof: ShaderMaterial = (_m["wall"] as ShaderMaterial).duplicate()
	roof.set_shader_parameter(&"tint", Color(0.6, 0.58, 0.6))
	roof.set_shader_parameter(&"ash_amount", 0.75)
	_m["roof_ash"] = roof
	_m["plaster"] = _noise_material(Color(0.33, 0.31, 0.28), Color(0.56, 0.53, 0.48), 0.4)
	_m["ash"] = _noise_material(Color(0.27, 0.26, 0.25), Color(0.4, 0.39, 0.38), 1.5)
	_m["paper"] = Props.material(Color(0.62, 0.56, 0.44), 0.0, 1.0)
	var lit := Props.material(Color(0.3, 0.2, 0.1), 0.0, 0.2)
	lit.emission_enabled = true
	lit.emission = Color(1.0, 0.6, 0.3)
	lit.emission_energy_multiplier = 1.2
	_m["window_lit"] = lit
	_m["window_dark"] = Props.material(Color(0.04, 0.04, 0.05), 0.0, 0.2)
	var night := Props.material(Color(0.06, 0.07, 0.09), 0.0, 0.2)  # de noche, la calle se ve azulada desde dentro
	night.emission_enabled = true
	night.emission = Color(0.3, 0.38, 0.5)
	night.emission_energy_multiplier = 0.25
	_m["window_night"] = night
	var fire := Props.material(Color(0.2, 0.06, 0.02), 0.0, 1.0)
	fire.emission_enabled = true
	fire.emission = Color(1.0, 0.4, 0.1)
	fire.emission_energy_multiplier = 3.0
	_m["fire"] = fire


func _planks(color: Color, width: float, ash := 0.0, along_x := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/planks.gdshader")
	m.set_shader_parameter(&"wood_color", color)
	m.set_shader_parameter(&"plank_width", width)
	m.set_shader_parameter(&"ash_amount", ash)
	m.set_shader_parameter(&"along_x", 1.0 if along_x else 0.0)
	return m


## Revoque o ceniza: ruido en coordenadas de mundo entre dos tonos.
static func _noise_material(dark: Color, light: Color, scale: float) -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.03
	noise.fractal_octaves = 5
	var ramp := Gradient.new()
	ramp.set_color(0, dark)
	ramp.set_color(1, light)
	var tex := NoiseTexture2D.new()
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = ramp
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	return m


# ---------------------------------------------------------------- Piezas

## Caja (centro, tamaño). Con solid lleva colisión; basis la gira.
func _box(size: Vector3, pos: Vector3, mat: Material, solid := false, basis := Basis(), parent: Node = self) -> Node3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	if not solid:
		mi.transform = Transform3D(basis, pos)
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = Props.LAYER_WORLD
	body.collision_mask = 0
	body.transform = Transform3D(basis, pos)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.add_child(mi)
	parent.add_child(body)
	return body


## Solo colisión (para muebles hechos de muchas piezas).
func _solid(size: Vector3, pos: Vector3, parent: Node = self) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Props.LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)


## Caja dada por sus esquinas (min, max).
func _span(a: Vector3, b: Vector3, mat: Material, solid := false, parent: Node = self) -> Node3D:
	return _box(b - a, (a + b) / 2.0, mat, solid, Basis(), parent)


func _cyl(radius: float, height: float, pos: Vector3, mat: Material, basis := Basis(), parent: Node = self, top_radius := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 10
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(basis, pos)
	parent.add_child(mi)
	return mi


## Modelo de un pack a tamaño real. node_name elige una pieza de un .glb con varias (Wovkulaka).
## scale es local al modelo; la colisión es la caja que lo envuelve.
func _model(path: String, pos: Vector3, yaw: float, scale := Vector3.ONE, collide := false, node_name := "", parent: Node = self) -> Node3D:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	var inst: Node3D = (_scenes[path] as PackedScene).instantiate()
	if node_name != "":
		for mi: Node in inst.find_children("*", "MeshInstance3D", true, false):
			if mi.name != node_name:
				mi.free()
	inst.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(scale), pos)
	parent.add_child(inst)
	if path.begins_with(MEGA):
		_ash_tint(inst)
	if collide:
		var box := _bounds(inst)
		var body := StaticBody3D.new()
		body.collision_layer = Props.LAYER_WORLD
		body.collision_mask = 0
		body.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size * scale
		col.shape = shape
		col.position = box.get_center() * scale
		body.add_child(col)
		parent.add_child(body)
	return inst


## El MegaKit tiene colores alegres: se apagan (como los edificios del pueblo) para el Imperio Final.
static var _tinted := {}  # material original -> apagado


func _ash_tint(inst: Node3D) -> void:
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if m == null:
				continue
			if not _tinted.has(m):
				var d: BaseMaterial3D = m.duplicate()
				d.albedo_color = Color(0.62, 0.58, 0.55)
				_tinted[m] = d
			mi.set_surface_override_material(i, _tinted[m])


## Pieza del MegaKit a una altura dada (todo el pack está a escala real; esto ajusta un poco).
func _mega(name: String, pos: Vector3, yaw: float, height := 0.0, collide := false, parent: Node = self) -> Node3D:
	var path := MEGA + name + ".gltf"
	if height <= 0.0:
		return _model(path, pos, yaw, Vector3.ONE, collide, "", parent)
	var inst := _model(path, pos, yaw, Vector3.ONE, false, "", parent)
	var k := height / maxf(_bounds(inst).size.y, 0.01)
	inst.free()
	return _model(path, pos, yaw, Vector3.ONE * k, collide, "", parent)


## Caja que envuelve las mallas de un modelo, en sus coordenadas (sin la escala de inst).
func _bounds(inst: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var n: Node = mi
		while n != inst:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b: AABB = xf * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _lantern(pos: Vector3, energy: float, reach: float, shadows := false) -> void:
	_box(Vector3(0.02, 0.5, 0.02), pos + Vector3(0, 0.45, 0), _m["iron"])
	_box(Vector3(0.2, 0.06, 0.2), pos + Vector3(0, 0.17, 0), _m["iron"])
	_box(Vector3(0.16, 0.24, 0.16), pos, _m["lamp_glass"])
	_box(Vector3(0.22, 0.04, 0.22), pos + Vector3(0, -0.14, 0), _m["iron"])
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.68, 0.38)
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = shadows
	light.position = pos + Vector3(0, -0.2, 0)
	add_child(light)


## Junta en una malla por material las piezas sueltas (cajas, cilindros, prismas) que cuelgan
## directamente del edificio o de sus cuerpos de colisión: miles de nodos pasan a unas decenas de
## llamadas de dibujo. Las que se mueven o están en un grupo (anclas de metal) se dejan.
func _merge_static(root: Node3D = null) -> void:
	if root == null:
		root = self
	var tools := {}  # material -> SurfaceTool
	for child in root.get_children():
		var pieces := []  # [MeshInstance3D, transformación respecto al edificio]
		if child is MeshInstance3D:
			pieces.append([child, (child as Node3D).transform])
		elif child is StaticBody3D:
			for c in child.get_children():
				if c is MeshInstance3D:
					pieces.append([c, (child as Node3D).transform * (c as Node3D).transform])
		for p: Array in pieces:
			var mi: MeshInstance3D = p[0]
			if mi.material_override == null or mi.get_child_count() > 0 or not mi.get_groups().is_empty():
				continue
			if not (mi.mesh is PrimitiveMesh) or not mi.get_parent().get_groups().is_empty():
				continue
			var mat := mi.material_override
			if not tools.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[mat] = st
			(tools[mat] as SurfaceTool).append_from(mi.mesh, 0, p[1])
			mi.get_parent().remove_child(mi)
			mi.queue_free()
	for mat: Material in tools:
		var out := MeshInstance3D.new()
		out.mesh = (tools[mat] as SurfaceTool).commit()
		out.material_override = mat
		root.add_child(out)


## Las luces se apagan solas de lejos (con decenas en un edificio, la ciudad no las paga todas).
func _fade_lights(begin := 40.0) -> void:
	for l: OmniLight3D in find_children("*", "OmniLight3D", true, false):
		l.distance_fade_enabled = true
		l.distance_fade_begin = begin
		l.distance_fade_length = 15.0


## La bruma de la noche no entra en casa: volumen de niebla negativo (caja centrada en pos).
func _clear_fog(size: Vector3, pos: Vector3) -> void:
	var mat := FogMaterial.new()
	mat.density = -1.0
	var fv := FogVolume.new()
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fv.size = size
	fv.position = pos
	fv.material = mat
	add_child(fv)


## Zona de interior (caja centrada en pos): mientras el jugador está dentro, Weather.sheltered
## quita casi toda la bruma (la de profundidad no se puede recortar con volúmenes) y la lluvia.
func _indoor_zone(size: Vector3, pos: Vector3) -> void:
	var zone := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask = Props.LAYER_PLAYER
	zone.monitorable = false
	zone.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	zone.add_child(col)
	zone.body_entered.connect(func(b: Node3D) -> void:
		if b is Player:
			zone.set_meta(&"inside", true)
			_set_indoor(1))
	zone.body_exited.connect(func(b: Node3D) -> void:
		if b is Player and zone.get_meta(&"inside", false):
			zone.set_meta(&"inside", false)
			_set_indoor(-1))
	# Al cambiar de mapa desde dentro (una puerta-portal) no llega body_exited: se descuenta aquí.
	zone.tree_exiting.connect(func() -> void:
		if zone.get_meta(&"inside", false):
			_indoor_count = maxi(_indoor_count - 1, 0))
	add_child(zone)


func _set_indoor(delta: int) -> void:
	_indoor_count = maxi(_indoor_count + delta, 0)
	var weather := get_tree().get_first_node_in_group(&"weather") as Weather
	if weather and weather.sheltered != (_indoor_count > 0):
		weather.sheltered = _indoor_count > 0
		weather.apply(false)
