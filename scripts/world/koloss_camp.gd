class_name KolossCamp
extends Node3D
## Campamento koloss (Story.PLACES "campamento"): un claro al norte del camino de la Puerta Este, a unos 300 m de la
## muralla. Grande y desordenado: empalizada de estacas rota a tramos, tiendas de cuero en corros alrededor de fogatas,
## una hoguera enorme en el centro, pilas de huesos, estantes de carne, y la fila de carros que trae los koloss (lo que
## descubre la misión "rastros" del Acto 2: alguien los está trayendo). Los koloss que andan por ahí los pone
## GateForces (PEOPLE con kit de koloss, junto a las fogatas). No van árboles ni lomas adentro (Exterior, covers).
## shortcut: las tiendas son conos hechos acá (Quaternius no tiene) y los huesos son rocas tintadas; los modelos
## propios, en G24.

const CENTER := Vector2(640, -330)
const RADIUS := 115.0  ## el claro
const STAKES_R := 95.0  ## la empalizada
const KIT := 3.2
const HIDE := Color(0.32, 0.22, 0.15)
const BONE := Color(0.82, 0.78, 0.66)
## La entrada: del camino al centro, por el sur.
const GATE_ANGLE := PI / 2.0
## El camino de la Puerta Este, como lo traza Exterior (semilla 4242).
const ROAD := [Vector2(340.08, -137.2), Vector2(503.86, -216.86), Vector2(684.2, -242.96), Vector2(851.71, -310.54)]
## Corros de tiendas: [ángulo, distancia al centro, tiendas].
const CLUSTERS := [[0.2, 60.0, 7], [1.1, 55.0, 6], [2.0, 62.0, 8], [2.9, 58.0, 7], [3.8, 64.0, 6], [4.6, 52.0, 7],
	[5.5, 60.0, 6], [0.0, 25.0, 5], [3.1, 30.0, 5]]


static func covers(p: Vector2, margin := 0.0) -> bool:
	return p.distance_to(CENTER) < RADIUS + margin


static func _polar(angle: float, r: float) -> Vector2:
	return CENTER + Vector2.from_angle(angle) * r


var _batch: ModelBatcher
var _r := RandomNumberGenerator.new()
var _tents: Array = []  # [posición, radio, alto]


func _ready() -> void:
	_r.seed = 640
	_batch = ModelBatcher.new()
	_batch.on_ground = true
	_batch.draw_chunk = 64.0
	_batch.draw_far = Art.DRAW_FAR
	add_child(_batch)
	_stakes()
	# La hoguera del centro, grande, y fogatas en cada corro de tiendas.
	_fire(CENTER, 3.0, 26.0)
	for c: Array in CLUSTERS:
		var mid := _polar(c[0], c[1])
		_fire(mid, 1.3, 14.0)
		for i in int(c[2]):
			var a: float = TAU * i / c[2] + _r.randf_range(-0.25, 0.25)
			var p := mid + Vector2.from_angle(a) * _r.randf_range(7.0, 11.0)
			_tents.append([p, _r.randf_range(2.2, 3.6), _r.randf_range(3.0, 5.0)])
		# Huesos y carne junto a cada fogata.
		for i in 3:
			var p := mid + Vector2.from_angle(_r.randf() * TAU) * _r.randf_range(3.0, 5.5)
			_batch.add(ModelKit.path(["props/Rock_1", "props/Rock_2", "props/Rock_3"][i]), Vector3(p.x, 0, p.y), _r.randf() * TAU, KIT * _r.randf_range(1.0, 1.8), BONE)
		var rack := mid + Vector2.from_angle(c[0] + PI) * 5.0
		_batch.add(ModelKit.path("props/Fence"), Vector3(rack.x, 0.0, rack.y), c[0], KIT * 1.4, HIDE)
		_batch.add(ModelKit.path("props/Bags"), Vector3(rack.x + 1.0, 0, rack.y), _r.randf() * TAU, KIT, HIDE)
	_build_tents()
	# Montañas de huesos sueltas.
	for i in 14:
		var p := _polar(_r.randf() * TAU, _r.randf_range(20.0, 88.0))
		_batch.add(ModelKit.path(["props/Rock_1", "props/Rock_2", "props/Rock_3"][i % 3]), Vector3(p.x, 0, p.y), _r.randf() * TAU, KIT * _r.randf_range(2.0, 3.5), BONE)
	# Lo que traen de afuera: pilas de cajones, bolsas y barriles a lo largo de la entrada, del camino al centro.
	# shortcut: el "Cart" de Quaternius es un carrito de mercado con toldo; los carros de verdad, en G24.
	var crate := ModelKit.path("props/Crate")
	var crate_h := ModelKit.aabb(crate).size.y * KIT * 2.2
	for i in 9:
		var p := _polar(GATE_ANGLE, 105.0 - i * 9.0) + Vector2(7.0 if i % 2 == 0 else -7.0, 0)
		for k in 3:
			var q := p + Vector2(k * 2.6, 0).rotated(_r.randf_range(-0.2, 0.2))
			_batch.add(crate, Vector3(q.x, 0, q.y), _r.randf() * 0.3, KIT * 2.2)
			if (i + k) % 2 == 0:
				_batch.add(crate, Vector3(q.x, crate_h, q.y), _r.randf() * 0.5, KIT * 2.2)  # uno encima
		_batch.add(ModelKit.path("props/Bags" if i % 2 == 0 else "props/Barrel"), Vector3(p.x - 2.5, 0, p.y + 1.5), _r.randf() * TAU, KIT * 1.2)
	# Torres de vigía improvisadas en el borde.
	for a: float in [0.7, 2.5, 4.2, 5.8]:
		var p := _polar(a, STAKES_R - 6.0)
		_batch.add(ModelKit.path("castle/Watchtower"), Vector3(p.x, 0, p.y), -a, KIT, HIDE)
	_batch.finalize()


## Empalizada de estacas (cercas tintadas, altas) con tramos caídos, y la entrada hacia el camino.
func _stakes() -> void:
	var fence := ModelKit.path("props/Fence")
	var s := KIT * 2.4
	var length := ModelKit.aabb(fence).size.x * s
	var a := 0.0
	while a < TAU:
		var step := length * 0.97 / STAKES_R
		var gap := absf(angle_difference(a, GATE_ANGLE)) < 0.12 or _on_road(_polar(a, STAKES_R))
		var broken := sin(a * 7.0) > 0.85  # tramos caídos
		if not gap and not broken:
			var p0 := _polar(a, STAKES_R + _r.randf_range(-1.5, 1.5))
			var p1 := _polar(a + step, STAKES_R)
			_batch.add(fence, Vector3((p0.x + p1.x) / 2.0, 0, (p0.y + p1.y) / 2.0), -(p1 - p0).angle(), s, HIDE)
		a += step


## Si p cae sobre el camino de la Puerta Este (ahí la empalizada no sigue).
static func _on_road(p: Vector2) -> bool:
	for i in ROAD.size() - 1:
		if Geometry2D.get_closest_point_to_segment(p, ROAD[i], ROAD[i + 1]).distance_to(p) < 8.0:
			return true
	return false


## Tiendas de cuero: conos (todos en un MultiMesh) con su cuerpo para chocar.
func _build_tents() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.06
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 7
	cone.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = HIDE
	mat.roughness = 1.0
	cone.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	mm.instance_count = _tents.size()
	var body := StaticBody3D.new()
	body.collision_layer = Props.LAYER_WORLD
	body.collision_mask = 0
	for i in _tents.size():
		var p: Vector2 = _tents[i][0]
		var r: float = _tents[i][1]
		var h: float = _tents[i][2]
		var y := CityPlan.ground(p) - 0.1
		var basis := Basis(Vector3.UP, _r.randf() * TAU).scaled(Vector3(r, h, r))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(p.x, y + h / 2.0, p.y)))
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = r * 0.7
		shape.height = h
		col.shape = shape
		col.position = Vector3(p.x, y + h / 2.0, p.y)
		body.add_child(col)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = Art.DRAW_FAR
	add_child(mmi)
	add_child(body)


func _fire(p: Vector2, size: float, reach: float) -> void:
	_batch.add(ModelKit.path("props/Bonfire_Lit"), Vector3(p.x, 0, p.y), 0.0, KIT * size, Color.WHITE, false)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.25)
	light.omni_range = reach
	light.light_energy = 2.5
	light.position = Vector3(p.x, CityPlan.ground(p) + 1.5 * size, p.y)
	light.distance_fade_enabled = true
	light.distance_fade_begin = Art.DRAW_FAR
	add_child(light)
