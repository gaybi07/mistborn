class_name Props
## Fábrica de objetos del escenario. Todo lo que esté en el grupo "metal" se puede empujar/tirar;
## lo que esté en "atium_visible" proyecta sombra de atium. El meta "center_offset" indica
## a qué punto apuntan las líneas de acero/hierro (por defecto, el origen del nodo).

const LAYER_WORLD := 1
const LAYER_PROPS := 2
const LAYER_PLAYER := 4


static func material(color: Color, metallic := 0.0, roughness := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m


static func static_box(size: Vector3, pos: Vector3, mat: Material, metal := false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	_add_box(body, size, mat)
	if metal:
		body.add_to_group(&"metal")
	return body


## Tejado a dos aguas. `base` es el centro de la base del tejado.
static func prism_roof(size: Vector3, base: Vector3, mat: Material, turned := false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.position = base + Vector3(0, size.y / 2.0, 0)
	if turned:
		body.rotation.y = PI / 2
		size = Vector3(size.z, size.y, size.x)
	var mesh := PrismMesh.new()
	mesh.size = size
	_add_mesh(body, mesh, mat)
	return body


## Cono/aguja decorativa con colisión.
static func spire(base: Vector3, radius: float, height: float, mat: Material, metal := false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.position = base + Vector3(0, height / 2.0, 0)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	_add_mesh(body, mesh, mat)
	if metal:
		body.add_to_group(&"metal")
	return body


## Farola: base, poste, brazo y farol con luz cálida que ilumina la bruma.
## metal = false: poste de madera pintado como hierro (no da líneas alománticas).
static func lamp_post(base: Vector3, iron: Material, glass: Material, metal := true, height := 5.0) -> StaticBody3D:
	var post := StaticBody3D.new()
	post.collision_layer = LAYER_WORLD
	post.collision_mask = 0
	post.position = base
	if metal:
		post.add_to_group(&"metal")
		post.set_meta(&"center_offset", Vector3(0, height * 0.6, 0))
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.25, height, 0.25)
	col.shape = shape
	col.position.y = height / 2.0
	post.add_child(col)
	_part(post, _box_mesh(Vector3(0.4, 0.4, 0.4)), Vector3(0, 0.2, 0), iron)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.09
	pole.height = height
	_part(post, pole, Vector3(0, height / 2.0, 0), iron)
	_part(post, _box_mesh(Vector3(0.06, 0.06, 0.6)), Vector3(0, height - 0.1, -0.28), iron)
	_part(post, _box_mesh(Vector3(0.28, 0.4, 0.28)), Vector3(0, height - 0.4, -0.55), glass)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.02
	cap.bottom_radius = 0.24
	cap.height = 0.18
	_part(post, cap, Vector3(0, height - 0.12, -0.55), iron)
	var light := OmniLight3D.new()
	light.position = Vector3(0, height - 0.45, -0.55)
	light.light_color = Color(1.0, 0.68, 0.38)
	light.light_energy = 2.2
	light.omni_range = 10.0
	light.light_volumetric_fog_energy = 3.0
	post.add_child(light)
	return post


## Puesto de mercado: mesa, postes y toldo de tela.
static func market_stall(pos: Vector3, angle: float, wood: Material, cloth: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = angle
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.6, 0.9, 1.2)
	col.shape = shape
	col.position.y = 0.45
	body.add_child(col)
	_part(body, _box_mesh(Vector3(2.6, 0.1, 1.2)), Vector3(0, 0.85, 0), wood)
	_part(body, _box_mesh(Vector3(2.4, 0.75, 1.0)), Vector3(0, 0.4, 0), wood)
	for x in [-1.25, 1.25]:
		for z in [-0.55, 0.55]:
			_part(body, _box_mesh(Vector3(0.08, 2.3, 0.08)), Vector3(x, 1.15, z), wood)
	var awning := _part(body, _box_mesh(Vector3(2.9, 0.04, 1.6)), Vector3(0, 2.3, 0.05), cloth)
	awning.rotation.x = 0.18
	return body


## Almenas (o cualquier caja repetida) con un MultiMesh: muchas piezas, una sola llamada de dibujo.
static func repeated_boxes(transforms: Array[Transform3D], size: Vector3, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _box_mesh(size)
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	return mmi


## Transformaciones de almenas a lo largo de una línea (coordenadas locales del padre).
static func merlons_line(a: Vector3, b: Vector3, step := 2.0) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var length := a.distance_to(b)
	var angle := atan2(-(b - a).z, (b - a).x)
	var count := int(length / step)
	for i in count + 1:
		out.append(Transform3D(Basis(Vector3.UP, angle), a.lerp(b, float(i) / maxf(count, 1))))
	return out


## Almenas alrededor de un rectángulo (centro y tamaño en XZ, a la altura y).
static func merlons_rect(center: Vector3, size_x: float, size_z: float, step := 1.8) -> Array[Transform3D]:
	var hx := size_x / 2.0
	var hz := size_z / 2.0
	var out: Array[Transform3D] = []
	out.append_array(merlons_line(center + Vector3(-hx, 0, -hz), center + Vector3(hx, 0, -hz), step))
	out.append_array(merlons_line(center + Vector3(-hx, 0, hz), center + Vector3(hx, 0, hz), step))
	out.append_array(merlons_line(center + Vector3(-hx, 0, -hz), center + Vector3(-hx, 0, hz), step))
	out.append_array(merlons_line(center + Vector3(hx, 0, -hz), center + Vector3(hx, 0, hz), step))
	return out


## Torre redonda con corona almenada y tejado cónico. Con metal_finial, el remate es de metal
## (ancla para subir con hierro); si no, es madera pintada.
static func round_tower(base: Vector3, radius: float, height: float, wall: Material, trim: Material,
		roof: Material, metal: Material, metal_finial := false, with_roof := true) -> Node3D:
	var root := Node3D.new()
	root.position = base
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	root.add_child(body)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius + 0.4
	shape.height = height + 1.0
	col.shape = shape
	col.position.y = (height + 1.0) / 2.0
	body.add_child(col)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.08
	mesh.height = height
	mesh.radial_segments = 24
	_part(body, mesh, Vector3(0, height / 2.0, 0), wall)
	var crown := CylinderMesh.new()
	crown.top_radius = radius + 0.4
	crown.bottom_radius = radius + 0.4
	crown.height = 1.0
	crown.radial_segments = 24
	_part(body, crown, Vector3(0, height + 0.5, 0), trim)
	var ring: Array[Transform3D] = []
	var count := int(TAU * radius / 1.6)
	for i in count:
		var a := TAU * i / count
		ring.append(Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * (radius + 0.2), height + 1.5, sin(a) * (radius + 0.2))))
	root.add_child(repeated_boxes(ring, Vector3(0.5, 1.0, 0.9), trim))
	if with_roof:
		var roof_h := radius * 2.4
		root.add_child(spire(Vector3(0, height + 1.0, 0), radius + 0.7, roof_h, roof))
		root.add_child(spire(Vector3(0, height + 1.0 + roof_h - 0.5, 0), 0.15, 3.5, metal, metal_finial))
	return root


## Verja entre dos puntos. Por defecto es madera pintada imitando hierro (sin líneas alománticas);
## con metal = true es hierro de verdad y sirve de ancla.
static func iron_fence(a: Vector3, b: Vector3, iron: Material, metal := false, height := 1.4) -> StaticBody3D:
	var length := a.distance_to(b)
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.position = (a + b) / 2.0
	body.rotation.y = atan2(-(b - a).z, (b - a).x)
	if metal:
		body.add_to_group(&"metal")
		body.set_meta(&"center_offset", Vector3(0, height * 0.6, 0))
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, height, 0.15)
	col.shape = shape
	col.position.y = height / 2.0
	body.add_child(col)
	var bars: Array[Transform3D] = []
	var count := int(length / 0.18)
	for i in count + 1:
		bars.append(Transform3D(Basis(), Vector3(-length / 2.0 + length * i / count, height / 2.0, 0)))
	body.add_child(repeated_boxes(bars, Vector3(0.03, height, 0.03), iron))
	for y in [0.15, height - 0.15]:
		_part(body, _box_mesh(Vector3(length, 0.05, 0.05)), Vector3(0, y, 0), iron)
	for x in [-length / 2.0, length / 2.0]:
		_part(body, _box_mesh(Vector3(0.12, height + 0.2, 0.12)), Vector3(x, (height + 0.2) / 2.0, 0), iron)
	return body


static func barrel(pos: Vector3, wood: Material, iron: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.36
	shape.height = 0.9
	col.shape = shape
	col.position.y = 0.45
	body.add_child(col)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.32
	mesh.bottom_radius = 0.32
	mesh.height = 0.9
	_part(body, mesh, Vector3(0, 0.45, 0), wood)
	var band := CylinderMesh.new()
	band.top_radius = 0.345
	band.bottom_radius = 0.345
	band.height = 0.05
	for y in [0.15, 0.75]:
		_part(body, band, Vector3(0, y, 0), iron)
	return body


static func cart(pos: Vector3, angle: float, wood: Material, iron: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = angle
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 1.2, 1.4)
	col.shape = shape
	col.position.y = 0.6
	body.add_child(col)
	_part(body, _box_mesh(Vector3(2.4, 0.12, 1.3)), Vector3(0, 0.75, 0), wood)
	for z in [-0.62, 0.62]:
		_part(body, _box_mesh(Vector3(2.4, 0.4, 0.06)), Vector3(0, 0.97, z), wood)
	_part(body, _box_mesh(Vector3(0.06, 0.4, 1.3)), Vector3(-1.17, 0.97, 0), wood)
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.48
	wheel.bottom_radius = 0.48
	wheel.height = 0.08
	for z in [-0.75, 0.75]:
		var w := _part(body, wheel, Vector3(0.2, 0.48, z), iron)
		w.rotation.x = PI / 2
	for z in [-0.4, 0.4]:
		var shaft := _part(body, _box_mesh(Vector3(1.8, 0.07, 0.07)), Vector3(2.0, 0.55, z), wood)
		shaft.rotation.z = 0.25
	return body


static func bench(pos: Vector3, angle: float, wood: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = angle
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 0.5, 0.5)
	col.shape = shape
	col.position.y = 0.25
	body.add_child(col)
	_part(body, _box_mesh(Vector3(2.0, 0.08, 0.45)), Vector3(0, 0.46, 0), wood)
	_part(body, _box_mesh(Vector3(2.0, 0.4, 0.06)), Vector3(0, 0.75, 0.2), wood)
	for x in [-0.85, 0.85]:
		_part(body, _box_mesh(Vector3(0.08, 0.45, 0.4)), Vector3(x, 0.22, 0), wood)
	return body


static func well(pos: Vector3, stone: Material, wood: Material, roof: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.1
	shape.height = 0.9
	col.shape = shape
	col.position.y = 0.45
	body.add_child(col)
	var ring := CylinderMesh.new()
	ring.top_radius = 1.05
	ring.bottom_radius = 1.1
	ring.height = 0.9
	_part(body, ring, Vector3(0, 0.45, 0), stone)
	var water := CylinderMesh.new()
	water.top_radius = 0.85
	water.bottom_radius = 0.85
	water.height = 0.02
	_part(body, water, Vector3(0, 0.88, 0), material(Color(0.02, 0.03, 0.04), 0.0, 0.05))
	for x in [-0.95, 0.95]:
		_part(body, _box_mesh(Vector3(0.12, 2.2, 0.12)), Vector3(x, 1.1, 0), wood)
	_part(body, _box_mesh(Vector3(2.0, 0.08, 0.08)), Vector3(0, 1.8, 0), wood)
	var top := PrismMesh.new()
	top.size = Vector3(2.6, 0.8, 1.6)
	var roof_mi := _part(body, top, Vector3(0, 2.6, 0), roof)
	roof_mi.rotation.y = PI / 2
	return body


## Estandarte colgando de un mástil.
static func banner_pole(pos: Vector3, cloth_color: Color, wood: Material, height := 6.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, height, 0.2)
	col.shape = shape
	col.position.y = height / 2.0
	body.add_child(col)
	_part(body, _box_mesh(Vector3(0.12, height, 0.12)), Vector3(0, height / 2.0, 0), wood)
	_part(body, _box_mesh(Vector3(1.4, 0.07, 0.07)), Vector3(0, height - 0.3, 0), wood)
	_part(body, _box_mesh(Vector3(1.2, 2.6, 0.03)), Vector3(0, height - 1.65, 0.05), material(cloth_color, 0.0, 1.0))
	return body


static func metal_crate(size: Vector3, pos: Vector3, mass: float, mat: Material, band: Material) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.position = pos
	body.mass = mass
	body.collision_layer = LAYER_PROPS
	body.collision_mask = LAYER_WORLD | LAYER_PROPS | LAYER_PLAYER
	_add_box(body, size, mat)
	for y in [-0.3, 0.3]:
		_part(body, _box_mesh(Vector3(size.x * 1.03, size.y * 0.08, size.z * 1.03)), Vector3(0, size.y * y, 0), band)
	body.add_to_group(&"metal")
	body.add_to_group(&"atium_visible")
	return body


static var _coin_mesh: CylinderMesh
static var _coin_mat: StandardMaterial3D


static func coin() -> Coin:
	var body := Coin.new()
	body.mass = 0.05
	body.continuous_cd = true
	body.collision_layer = LAYER_PROPS
	body.collision_mask = LAYER_WORLD | LAYER_PROPS | LAYER_PLAYER
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.bounce = 0.1
	body.physics_material_override = pm
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.07
	col.shape = shape
	body.add_child(col)
	if _coin_mesh == null:
		_coin_mesh = CylinderMesh.new()
		_coin_mesh.top_radius = 0.09
		_coin_mesh.bottom_radius = 0.09
		_coin_mesh.height = 0.02
		_coin_mat = material(Color(0.85, 0.6, 0.3), 1.0, 0.25)
	_part(body, _coin_mesh, Vector3.ZERO, _coin_mat)
	body.add_to_group(&"metal")
	body.add_to_group(&"atium_visible")
	body.add_to_group(&"coin")
	return body


static func _add_box(body: Node3D, size: Vector3, mat: Material) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	_part(body, _box_mesh(size), Vector3.ZERO, mat)


static func _add_mesh(body: Node3D, mesh: Mesh, mat: Material) -> void:
	var col := CollisionShape3D.new()
	col.shape = mesh.create_convex_shape()
	body.add_child(col)
	_part(body, mesh, Vector3.ZERO, mat)


static func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


## Estatua de bronce (metal de verdad): construye un humanoide con ese aspecto, copia sus mallas
## en bronce y descarta el rig. look: el de HumanoidRig (altura 2,1 ≈ 3,8 m de estatua).
static func bronze_statue(parent: Node, pos: Vector3, look: Dictionary, bronze: Material, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.position = pos
	body.rotation.y = yaw
	body.add_to_group(&"metal")
	body.set_meta(&"center_offset", Vector3(0, 2.0, 0))
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 3.8, 1.2)
	col.shape = shape
	col.position.y = 1.9
	body.add_child(col)
	parent.add_child(body)
	var rig := HumanoidRig.new()
	rig.look = look
	body.add_child(rig)
	Afterimage.copy_meshes(rig, body, bronze)
	rig.queue_free()
	return body
