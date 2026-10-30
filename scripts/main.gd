extends Node3D
## Luthadel de noche, a escala real según el mapa de referencia (ver CityPlan):
## muralla con tres puertas, Kredik Shaw sobre su colina al norte, el Distrito Noble y el
## Mercantil, la Plaza Central, la Asamblea, el Ministerio del Acero, tres cuarteles, la forja y
## los corrales de carbón, el río con la dársena al este y miles de casas skaa orientadas a sus calles.
## Edificios, murallas y torres: modelos de Quaternius (Medieval Village y Modular Medieval),
## dibujados en lote con ModelBatcher.
## Las luces solo se encienden cerca del jugador (ver _lights_near_player) y las ventanas de las
## casas, igual: de lejos se ven apagadas.
## Metal de verdad (anclas para acero/hierro): farolas, veletas y faroles de puerta de las casas,
## estatua, rejas del río, remate de Kredik Shaw y del Ministerio, unas pocas cajas y las monedas.

const HOUSES := [Color(0.38, 0.08, 0.08), Color(0.1, 0.16, 0.36), Color(0.12, 0.26, 0.16), Color(0.3, 0.22, 0.32)]

## Muralla: alto de 16 m sobre piezas de 2,35 m.
const WALL_SCALE := 6.8
## Tonos: los colores del pack son alegres; en Luthadel todo está apagado por la ceniza.
const SKAA_TINT := Color(0.68, 0.64, 0.6)
const STONE_TINT := Color(0.46, 0.44, 0.43)
const NOBLE_TINT := Color(0.9, 0.84, 0.8)

var _rng := RandomNumberGenerator.new()
var _batch: ModelBatcher
## Huecos ocupados por edificios singulares: [centro XZ, radio] (las casas los evitan).
var _occupied: Array = []
var _poly := {}  # modelos de Poly Haven: nombre -> [Transform3D] (ver PolyProps)
var _iron := {}  # "iron"/"glass" -> Array[Transform3D] de los herrajes de las casas
## Azar propio de los herrajes, para no alterar el reparto de las casas.
var _iron_rng := RandomNumberGenerator.new()
var _m := {}
## Lo que generan las casas (modelos, anclas de metal, ventanas, herrajes y el estado del azar),
## guardado la primera vez: al volver a la ciudad por una puerta no hace falta generarlas otra vez.
static var _house_cache := {}
var _rec := {}  # mientras se generan las casas: lo que se va guardando en _house_cache


func _ready() -> void:
	_rng.seed = 1337
	_iron_rng.seed = 7
	_m = WorldKit.materials()
	WorldKit.add_environment(self)
	CityGround.build(self, _m)
	_batch = ModelBatcher.new()
	add_child(_batch)
	_build_wall()
	_build_kredik_shaw()
	_build_estates()
	_build_landmarks()
	_build_port_and_bridges()
	_build_houses()
	_build_street_lamps()
	_build_plaza()
	_build_plaza_details()
	_batch.finalize()
	_build_ironwork()
	PolyProps.spawn(self, _poly)
	add_child(Exterior.new())
	_spawn_people()
	add_child(AllomancerSpawner.new())
	add_child(WorldFx.new())
	var player := Player.new()
	player.name = "Player"
	player.position = Portal.take_arrival(Vector3(0, 1, 10))
	add_child(player)
	var hud := Hud.new()
	hud.player = player
	add_child(hud)
	var map := CityMap.new()
	map.player = player
	add_child(map)
	_place_loot()
	_lights_near_player()


## Objetos tirados por las calles para mejorar el equipo (el resto los sueltan los alománticos
## derrotados, y en Kredik Shaw hay más).
const CITY_LOOT := ["wooden_vials", "glass_daggers", "padded_boots", "wool_cloak", "leather_jerkin", "dueling_cane"]


func _place_loot() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var spots := CityPlan.street_points().filter(func(p: Vector2) -> bool:
		return p.length() > 15.0 and p.length() < 140.0)
	for id in CITY_LOOT:
		if spots.is_empty():
			return
		var p: Vector2 = spots.pop_at(r.randi() % spots.size())
		var pickup := ItemPickup.new()
		pickup.item_id = id
		pickup.position = Vector3(p.x, 0.05, p.y)
		add_child(pickup)


## Posición en el mundo de un punto dado en coordenadas locales de algo girado (yaw) en origin.
func _at(origin: Vector2, yaw: float, local: Vector3) -> Vector3:
	var r := Basis(Vector3.UP, yaw) * local
	return Vector3(origin.x + r.x, r.y, origin.y + r.z)


func _q(name: String) -> String:
	return ModelKit.path(name)


# ---------------------------------------------------------------- Muralla

## Cada tramo entre dos vértices: piezas de muralla, torre en el vértice, torres intermedias,
## puertas y los huecos por donde pasa el río (con rejas de hierro).
func _build_wall() -> void:
	var gates := CityPlan.gates()
	var n := CityPlan.WALL.size()
	var piece_w := ModelKit.aabb(_q("castle/TallWall")).size.x * WALL_SCALE
	for i in n:
		var a: Vector2 = CityPlan.WALL[i]
		var b: Vector2 = CityPlan.WALL[(i + 1) % n]
		var length := a.distance_to(b)
		var dir := (b - a) / length
		var yaw := atan2(-dir.y, dir.x)  # el X del modelo a lo largo del tramo
		# Huecos: [centro (m desde a), medio ancho, tipo]
		var gaps := []
		for gi in CityPlan.GATE_SPECS.size():
			if CityPlan.GATE_SPECS[gi][1] == i:
				gaps.append([CityPlan.GATE_SPECS[gi][2] * length, piece_w / 2.0, "gate", gi])
		for ri in CityPlan.RIVER.size() - 1:
			var hit: Variant = Geometry2D.segment_intersects_segment(a, b, CityPlan.RIVER[ri], CityPlan.RIVER[ri + 1])
			if hit != null:
				gaps.append([a.distance_to(hit), CityPlan.RIVER_WIDTH / 2.0 + 3.0, "river", -1])
		# Piezas de muralla repartidas a lo largo del tramo (se solapan un poco).
		var count := ceili(length / piece_w)
		for k in count:
			var x := (k + 0.5) * length / count
			var blocked := false
			for g in gaps:
				if absf(x - g[0]) < g[1] + piece_w * 0.45:
					blocked = true
			if not blocked:
				var p := a + dir * x
				_batch.add(_q("castle/TallWall"), Vector3(p.x, 0, p.y), yaw, WALL_SCALE, STONE_TINT)
		# Torre grande en el vértice.
		_batch.add(_q("castle/LargeTower"), Vector3(a.x, 0, a.y), yaw, 7.0, STONE_TINT)
		# Torres intermedias cada ~50 m, lejos de los huecos.
		var towers := int(length / 50.0)
		for k in range(1, towers + 1):
			var x := length * k / (towers + 1)
			var near_gap := gaps.any(func(g): return absf(x - g[0]) < g[1] + 12.0)
			if not near_gap:
				var p := a + dir * x
				_batch.add(_q("castle/Tower"), Vector3(p.x, 0, p.y), yaw, 6.0, STONE_TINT)
		for g in gaps:
			var c: Vector2 = a + dir * g[0]
			if g[2] == "gate":
				_gate(c, dir, yaw, g[3])
			else:
				_water_gate(c, dir, yaw, g[1] * 2.0)


func _gate(c: Vector2, dir: Vector2, yaw: float, house: int) -> void:
	var w := ModelKit.aabb(_q("castle/TallWallEntrance")).size.x * WALL_SCALE
	_batch.add(_q("castle/TallWallEntrance"), Vector3(c.x, 0, c.y), yaw, WALL_SCALE, STONE_TINT)
	for side in [-1.0, 1.0]:
		var p: Vector2 = c + dir * side * (w / 2.0 + 4.0)
		_batch.add(_q("castle/LargeSquareTower"), Vector3(p.x, 0, p.y), yaw, 6.2, STONE_TINT)
		var inward := Vector2(dir.y, -dir.x) if Vector2(dir.y, -dir.x).dot(-c) > 0.0 else Vector2(-dir.y, dir.x)
		var bp: Vector2 = p + inward * 4.6
		var banner := Props.static_box(Vector3(2.0, 7.0, 0.08), Vector3(bp.x, 14.0, bp.y), Props.material(HOUSES[house], 0.0, 1.0))
		banner.rotation.y = yaw
		add_child(banner)


## Paso del río bajo la muralla: arco de piedra y rejas de hierro (metal de verdad, un ancla).
func _water_gate(c: Vector2, dir: Vector2, yaw: float, width: float) -> void:
	var lintel := Props.static_box(Vector3(width, 8.0, 4.0), Vector3(c.x, 12.0, c.y), _m["wall"])
	lintel.rotation.y = yaw
	add_child(lintel)
	for side in [-1.0, 1.0]:
		var p: Vector2 = c + dir * side * (width / 2.0 + 2.0)
		_batch.add(_q("castle/SmallSquareTower"), Vector3(p.x, 0, p.y), yaw, 8.0, STONE_TINT)
	var grate := StaticBody3D.new()
	grate.collision_layer = Props.LAYER_WORLD
	grate.position = Vector3(c.x, 2.5, c.y)
	grate.rotation.y = yaw
	grate.add_to_group(&"metal")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 7.0, 0.3)
	col.shape = shape
	grate.add_child(col)
	var bars: Array[Transform3D] = []
	var count := int(width / 0.6)
	for i in count + 1:
		bars.append(Transform3D(Basis(), Vector3(-width / 2.0 + width * i / count, 0, 0)))
	grate.add_child(Props.repeated_boxes(bars, Vector3(0.14, 7.0, 0.14), _m["iron"]))
	var rails: Array[Transform3D] = []
	for y in [-2.5, 0.0, 2.5]:
		rails.append(Transform3D(Basis(), Vector3(0, y, 0)))
	grate.add_child(Props.repeated_boxes(rails, Vector3(width, 0.14, 0.16), _m["iron"]))
	add_child(grate)


# ---------------------------------------------------------------- Kredik Shaw

## La colina de las mil agujas (ver KredikCitadel): peñasco, muralla, portón y agujas.
func _build_kredik_shaw() -> void:
	add_child(KredikCitadel.new())
	for x in [-90.0, -45.0, 0.0, 45.0, 90.0]:
		_occupied.append([CityPlan.HILL + Vector2(x, 2.0), 110.0])
	_occupied.append([CityPlan.HILL + Vector2(0, 80.0), 18.0])


# ---------------------------------------------------------------- Casas nobles

## Mansión con patio: muralla baja, torreones en las esquinas, puerta hacia la calle,
## casa señorial al fondo, una torre del homenaje y estandartes de la casa.
## Los cuarteles son igual pero de piedra gris, con barracones en filas y estandartes rojos.
func _build_estates() -> void:
	for e in CityPlan.ESTATES + CityPlan.BARRACKS:
		var c: Vector2 = e[0]
		var w: float = e[1]
		var d: float = e[2]
		var yaw: float = e[3]
		var barracks: bool = e.size() < 5
		var tint := STONE_TINT if barracks else NOBLE_TINT
		# La puerta da a la calle más cercana.
		var to_street := CityPlan.nearest_street_point(c) - c
		var local_to := to_street.rotated(-yaw)
		var front_sign := 1.0 if local_to.y >= 0.0 else -1.0
		var wall := _q("castle/Wall")
		var wall_scale := 4.0
		var piece := ModelKit.aabb(wall).size.x * wall_scale
		for side_z in [-1.0, 1.0]:
			var count := ceili(w / piece)
			for k in count:
				var x := -w / 2.0 + (k + 0.5) * w / count
				var is_gate: bool = side_z == front_sign and absf(x) < piece * 0.6
				var model := _q("castle/WallEntrance") if is_gate else wall
				_batch.add(model, _at(c, yaw, Vector3(x, 0, side_z * d / 2.0)), yaw, wall_scale, tint)
		for side_x in [-1.0, 1.0]:
			var count := ceili(d / piece)
			for k in count:
				var z := -d / 2.0 + (k + 0.5) * d / count
				_batch.add(wall, _at(c, yaw, Vector3(side_x * w / 2.0, 0, z)), yaw + PI / 2, wall_scale, tint)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_batch.add(_q("castle/SmallSquareTower"), _at(c, yaw, Vector3(sx * w / 2.0, 0, sz * d / 2.0)), yaw, 5.0, tint)
		var facing := yaw + (0.0 if front_sign > 0 else PI)
		if barracks:
			# Barracones en filas en la mitad del fondo, torre de vigía y pertrechos en el patio de armas.
			var stable := _q("buildings/Stable")
			var sw := ModelKit.aabb(stable).size.x * 3.0 + 2.0
			var sd := ModelKit.aabb(stable).size.z * 3.0 + 5.0
			var cols := int((w - 16.0) / sw)
			for row in maxi(int((d * 0.5 - 6.0) / sd), 1):
				for k in cols:
					var x := -(cols - 1) * sw / 2.0 + k * sw
					_batch.add(stable, _at(c, yaw, Vector3(x, 0, -front_sign * (d / 2.0 - 6.0 - sd * (row + 0.5)))), facing, 3.0, STONE_TINT)
			_batch.add(_q("castle/LargeTower"), _at(c, yaw, Vector3(w * 0.38, 0, front_sign * d * 0.1)), yaw, 6.0, STONE_TINT)
			for k in 6:
				_add_prop(["props/Crate", "props/Barrel"][k % 2], _at(c, yaw, Vector3(-w * 0.35 + k * 1.6, 0, front_sign * d * 0.3)), _rng.randf() * TAU, 4.0)
		else:
			var grand := clampf(w / 34.0, 1.0, 1.5)
			_batch.add(_q("buildings/Inn"), _at(c, yaw, Vector3(0, 0, -front_sign * d * 0.18)), facing, 3.4 * grand, NOBLE_TINT)
			_batch.add(_q("castle/LargeTower"), _at(c, yaw, Vector3(w * 0.3, 0, -front_sign * d * 0.32)), yaw, 5.0, NOBLE_TINT)
			_batch.add(_q("props/Gazebo"), _at(c, yaw, Vector3(-w * 0.25, 0, front_sign * d * 0.22)), yaw, 3.0, NOBLE_TINT)
		var cloth := Props.material(Color(0.42, 0.06, 0.05) if barracks else HOUSES[e[4]], 0.0, 1.0)
		for sx in [-1.0, 1.0]:
			var banner := Props.static_box(Vector3(1.6, 4.5, 0.08), _at(c, yaw, Vector3(sx * piece * 0.75, 6.0, front_sign * (d / 2.0 + 1.6))), cloth)
			banner.rotation.y = yaw
			add_child(banner)


# ---------------------------------------------------------------- Plazas y edificios singulares

func _build_landmarks() -> void:
	# Plaza de la Asamblea: gran salón al norte de la plaza y un campanario.
	var asm := CityPlan.ASSEMBLY
	_batch.add(_q("buildings/Inn"), Vector3(asm.x, 0, asm.y - 14.0), 0.0, 6.0, STONE_TINT)
	_batch.add(_q("buildings/Bell_Tower"), Vector3(asm.x + 17.0, 0, asm.y - 10.0), 0.0, 4.5, STONE_TINT)
	_add_prop("props/Well", Vector3(asm.x, 0, asm.y + 4.0), 0.0, 3.5)
	_occupied.append([asm + Vector2(0, -14), 14.0])

	# Ministerio del Acero: torre de ladrillo oscuro con remate de metal.
	var mi := CityPlan.MINISTRY
	var tower := _q("castle/LargeSquareTowerBricks")
	_batch.add(tower, Vector3(mi.x, 0, mi.y), 0.4, 7.5, Color(0.42, 0.4, 0.44))
	var spire := Props.spire(Vector3(mi.x, ModelKit.aabb(tower).size.y * 7.5 - 0.5, mi.y), 0.4, 9.0, _m["metal"], true)
	add_child(spire)

	# Plaza del Mercado Central: puestos en corro, pozo, hoguera y mercancías.
	var mk := CityPlan.MARKET
	for i in 9:
		var a := TAU * i / 9.0
		var p := mk + Vector2(cos(a), sin(a)) * 11.0
		var model := "props/MarketStand_1" if i % 2 == 0 else "props/MarketStand_2"
		_batch.add(_q(model), Vector3(p.x, 0, p.y), atan2(-cos(a), -sin(a)), 3.2, SKAA_TINT)
	_add_prop("props/Well", Vector3(mk.x, 0, mk.y), 0.0, 3.5)
	var fire := Brazier.new()
	fire.position = Vector3(mk.x + 4.0, 0, mk.y - 3.0)
	add_child(fire)
	for i in 14:
		var a := _rng.randf() * TAU
		var p := mk + Vector2(cos(a), sin(a)) * _rng.randf_range(5.0, 15.0)
		var item: String = ["props/Barrel", "props/Crate", "props/Hay", "props/Bags", "props/Package_1"][i % 5]
		_add_prop(item, Vector3(p.x, 0, p.y), _rng.randf() * TAU, 4.0)

	# Molino junto al río y aserradero entre los talleres.
	_batch.add(_q("buildings/Mill"), Vector3(130, 0, 40), 0.6, 4.0, SKAA_TINT)
	_occupied.append([Vector2(130, 40), 10.0])
	_batch.add(_q("buildings/Sawmill"), Vector3(200, 0, 280), PI, 3.4, SKAA_TINT)
	_occupied.append([Vector2(200, 280), 10.0])
	_log_pile(Vector2(212, 276), PI)
	_log_pile(Vector2(212, 286), PI)
	_build_coal_and_forges()

	# Taller de carpintería de Clubs, al sur de la plaza (con sótano: ver Workshop).
	add_child(Workshop.new())
	_occupied.append([Workshop.POS, 10.5])
	# Casa Venture en el Distrito Noble (su terreno lo reserva CityPlan.VENTURE); por dentro es otra escena.
	add_child(VentureManor.new())


## Corrales de carbón (montañas negras entre los cobertizos) y humo de las chimeneas del
## Distrito de Forja.
func _build_coal_and_forges() -> void:
	var coal := Props.material(Color(0.05, 0.05, 0.055), 0.0, 0.95)
	var placed := 0
	var tries := 0
	while placed < 14 and tries < 200:
		tries += 1
		var p := Vector2(-280, 250) + Vector2.from_angle(_rng.randf() * TAU) * sqrt(_rng.randf()) * 70.0
		var r := _rng.randf_range(5.0, 9.0)
		if not CityPlan.inside(p, r + 12.0):
			continue
		if _occupied.any(func(o: Array) -> bool: return p.distance_to(o[0]) < o[1] + r):
			continue
		var mesh := TerrainGen.mound(r, _rng.randf_range(2.5, 5.0), _rng.randi(), 0.0, 1.2, 10, 20)
		add_child(TerrainGen.body(mesh, Vector3(p.x, 0, p.y), coal))
		# Peñascos alrededor del montón.
		for k in _rng.randi_range(3, 5):
			var q := p + Vector2.from_angle(_rng.randf() * TAU) * (r + _rng.randf_range(0.2, 1.5))
			PolyProps.add(_poly, "boulder_01", PolyProps.at("boulder_01", Vector3(q.x, -0.2, q.y), _rng.randf() * TAU, _rng.randf_range(0.8, 1.8)))
		_occupied.append([p, r + 1.0])
		placed += 1
	for c in [Vector2(-300, 20), Vector2(-250, 70), Vector2(-215, 120), Vector2(-310, 210), Vector2(-240, 300)]:
		_smoke(Vector3(c.x, 14.0, c.y))


## Pila de troncos (dead_tree_trunk_02) de un aserradero: 3 abajo, 2 encima y 1 arriba, con
## alguna caja al lado. Solo si el sitio está libre.
func _log_pile(c: Vector2, yaw: float) -> void:
	if _occ.is_empty():
		_occupied.append([c, 4.0])  # antes de las casas: que no se construya encima
	elif not _rect_free(c, yaw, Rect2(-2.6, -1.8, 5.2, 3.6)):
		return
	else:
		_stamp_rect(c, yaw, Rect2(-2.6, -1.8, 5.2, 3.6))
	var rows := [[-1.05, 0.0, 1.05], [-0.52, 0.52], [0.0]]
	for i in rows.size():
		for z: float in rows[i]:
			var pos := _at(c, yaw, Vector3(_rng.randf_range(-0.3, 0.3), 0, z))
			pos.y = i * 0.88
			PolyProps.add(_poly, "dead_tree_trunk_02", PolyProps.at("dead_tree_trunk_02", pos, yaw + _rng.randf_range(-0.06, 0.06)))
	var crate := _at(c, yaw, Vector3(3.4, 0, 0.6))
	PolyProps.add(_poly, "wooden_crate_01", PolyProps.at("wooden_crate_01", crate, yaw, 1.6))


## Columna de humo de chimenea: partículas grises que suben y se lleva el viento.
func _smoke(pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.visibility_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 90, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.5
	pm.direction = Vector3.UP
	pm.spread = 10.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 3.5
	pm.gravity = Vector3(0.6, 0.2, 0.2)
	pm.scale_min = 1.0
	pm.scale_max = 2.5
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.color_ramp = Fx.fade_ramp(0.1)
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(9, 9)
	quad.material = Fx.particle_material(Color(0.2, 0.19, 0.19, 0.55), false)
	p.draw_pass_1 = quad
	p.position = pos
	add_child(p)


## Objeto pequeño decorativo (sin colisión salvo los grandes).
func _add_prop(name: String, pos: Vector3, yaw: float, scale: float) -> void:
	var big := ModelKit.footprint(_q(name), scale) > 1.0
	_house_model(_q(name), pos, yaw, scale, SKAA_TINT, big)


## Modelo al lote; mientras se generan las casas, además queda guardado para la próxima vez.
func _house_model(path: String, pos: Vector3, yaw: float, scale: float, tint: Color, collide := true) -> void:
	_batch.add(path, pos, yaw, scale, tint, collide)
	if not _rec.is_empty():
		_rec["models"].append([path, pos, yaw, scale, tint, collide])


## Luces de farolas, faroles, braseros, interiores...: solo se ven (y cuestan) cerca de la cámara;
## más allá se apagan poco a poco. La luna no.
func _lights_near_player() -> void:
	for l: Light3D in find_children("*", "Light3D", true, false):
		if l is DirectionalLight3D:
			continue
		l.distance_fade_enabled = true
		l.distance_fade_begin = 70.0
		l.distance_fade_length = 30.0


# ---------------------------------------------------------------- Puerto y puentes

func _build_port_and_bridges() -> void:
	var wood: Material = _m["wood"]
	# Dársena: muelles de madera que entran en el río, barcas amarradas y almacenes en la orilla.
	var along := (CityPlan.PORT_B - CityPlan.PORT_A).normalized()
	var to_river := Vector2(-along.y, along.x)
	var mid := (CityPlan.PORT_A + CityPlan.PORT_B) / 2.0
	if CityPlan.dist_to_river(mid + to_river * 5.0) > CityPlan.dist_to_river(mid):
		to_river = -to_river
	var port_len := CityPlan.PORT_A.distance_to(CityPlan.PORT_B)
	var pier_yaw := atan2(to_river.x, to_river.y)
	for i in 4:
		var base := CityPlan.PORT_A + along * port_len * (i + 0.5) / 4.0
		var length := 16.0
		var c := base + to_river * (length / 2.0 - 2.0)
		var deck := Props.static_box(Vector3(3.5, 0.3, length), Vector3(c.x, -0.15, c.y), wood)
		deck.rotation.y = pier_yaw
		add_child(deck)
		for k in 4:
			add_child(Props.static_box(Vector3(0.3, 2.4, 0.3), _at(base, pier_yaw, Vector3(1.5 if k % 2 == 0 else -1.5, -1.5, 1.0 + k * 3.5)), wood))
		if i < 3:
			var bp := base + to_river * 8.0 + along * 4.5
			_boat(Vector3(bp.x, CityPlan.WATER_LEVEL, bp.y), pier_yaw + _rng.randf_range(-0.2, 0.2))
	for i in 3:
		var p := CityPlan.PORT_A + along * port_len * (i + 0.5) / 3.0 - to_river * 10.0
		_batch.add(_q("buildings/Stable"), Vector3(p.x, 0, p.y), pier_yaw, 3.2, SKAA_TINT)
	for i in 16:
		var p := CityPlan.PORT_A + along * _rng.randf() * port_len + to_river * _rng.randf_range(-3.0, 0.0)
		_add_prop(["props/Crate", "props/Barrel", "props/Bags", "props/Package_2"][i % 4], Vector3(p.x, 0, p.y), _rng.randf() * TAU, 4.0)

	# Puentes donde las avenidas cruzan el río.
	for br in CityPlan.bridges():
		var c: Vector2 = br[0]
		var dir: Vector2 = br[1]
		var yaw := atan2(-dir.y, dir.x)
		var length := CityPlan.RIVER_WIDTH + 12.0
		var deck := Props.static_box(Vector3(length, 0.5, 8.0), Vector3(c.x, -0.25, c.y), _m["trim"])
		deck.rotation.y = yaw
		add_child(deck)
		for side in [-1.0, 1.0]:
			var rail := Props.static_box(Vector3(length, 1.0, 0.4), _at(c, yaw, Vector3(0, 0.5, side * 3.8)), _m["trim"])
			rail.rotation.y = yaw
			add_child(rail)
		_occupied.append([c, 10.0])


func _boat(pos: Vector3, yaw: float) -> void:
	var wood: Material = _m["wood"]
	var boat := Node3D.new()
	boat.position = pos
	boat.rotation.y = yaw
	add_child(boat)
	boat.add_child(Props.static_box(Vector3(2.6, 0.9, 7.0), Vector3(0, 0.2, 0), wood))
	boat.add_child(Props.static_box(Vector3(0.15, 5.0, 0.15), Vector3(0, 2.8, 0.5), wood))
	boat.add_child(Props.static_box(Vector3(2.4, 2.4, 0.04), Vector3(0, 3.6, 0.6), Props.material(Color(0.5, 0.46, 0.4), 0.0, 1.0)))


# ---------------------------------------------------------------- Barrios skaa

## Barrios por zonas (CityPlan.DISTRICTS). Tres pasadas sobre un mapa de ocupación de 1 m:
##  1. se marcan las calles, callejones y edificios singulares (no se puede construir encima),
##  2. casas en hilera pegadas a ambos lados de las calles (todas en los barrios densos; solo
##     las calles principales en los de densidad media),
##  3. relleno del interior de las manzanas, más o menos apretado según el barrio.
func _build_houses() -> void:
	if not _house_cache.is_empty():
		_replay_houses()
		return
	_rec = {"models": [], "anchors": []}
	_occ_init()
	for s in CityPlan.street_segments():
		_stamp_line(s[0], s[1], s[2])
	for o in _occupied:
		_stamp_disc(o[0], o[1])
	for e in CityPlan.ESTATES + CityPlan.BARRACKS + [CityPlan.VENTURE]:
		_stamp_rect(e[0], e[3], Rect2(-e[1] / 2.0 - 2.0, -e[2] / 2.0 - 2.0, e[1] + 4.0, e[2] + 4.0))

	var count := 0
	# Casas en hilera a lo largo de las calles.
	for s in CityPlan.street_segments():
		count += _row(s[0], s[1], s[2], s[2] == CityPlan.STREET_HALF)
	# Relleno de las manzanas: dos pasadas (la segunda desplazada medio paso). En cada hueco se
	# prueba la casa elegida, luego la más pequeña del barrio, mirando a la calle o girada 90°.
	for pass_offset: float in [0.0, 1.5]:
		var candidates: Array[Vector2] = []
		var bounds := CityPlan.BOUNDS
		var x := bounds.position.x + pass_offset
		while x <= bounds.end.x:
			var z := bounds.position.y + pass_offset
			while z <= bounds.end.y:
				candidates.append(Vector2(x, z) + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)))
				z += 3.0
			x += 3.0
		candidates.shuffle()
		for p in candidates:
			var i := _occ_index(p)
			if i < 0 or _occ[i] != 0 or not CityPlan.inside(p, 10.0):
				continue
			var d := CityPlan.district(p)
			var keep: float = {"dense": 1.0, "medium": 0.9, "sparse": 0.4}[d["density"]]
			if _rng.randf() > keep:
				continue
			var to := CityPlan.nearest_street_point(p) - p
			var yaw := atan2(to.x, to.y)
			for attempt in [[_pick(d), yaw], [_smallest(d), yaw], [_smallest(d), yaw + PI / 2]]:
				if _try_house(p, attempt[1], d, attempt[0]):
					count += 1
					break
	print("Luthadel: %d casas skaa" % count)
	_house_cache = {"models": _rec["models"], "anchors": _rec["anchors"], "poly": _poly.duplicate(true),
			"iron": _iron.duplicate(true), "rng": _rng.state, "iron_rng": _iron_rng.state}
	_rec = {}


## Las mismas casas que la primera vez, sin volver a buscarles sitio.
func _replay_houses() -> void:
	for m in _house_cache["models"]:
		_batch.add(m[0], m[1], m[2], m[3], m[4], m[5])
	for a: Vector3 in _house_cache["anchors"]:
		_metal_anchor(a)
	_iron = _house_cache["iron"].duplicate(true)
	_poly = _house_cache["poly"].duplicate(true)
	_rng.state = _house_cache["rng"]
	_iron_rng.state = _house_cache["iron_rng"]


## Casas en hilera a ambos lados de un tramo de calle, con la fachada pegada a la calle.
func _row(a: Vector2, b: Vector2, half: float, main_street: bool) -> int:
	var length := a.distance_to(b)
	if length < 1.0:
		return 0
	var dir := (b - a) / length
	var normal := Vector2(-dir.y, dir.x)
	var placed := 0
	for side: float in [-1.0, 1.0]:
		var t := _rng.randf_range(0.0, 3.0)
		while t < length:
			var at := a + dir * t
			var d := CityPlan.district(at)
			if d["density"] == "sparse" or (d["density"] == "medium" and not main_street and _rng.randf() < 0.4):
				t += 6.0
				continue
			var spec := _pick(d)
			var model: String = spec[0]
			var scale: float = spec[1]
			var box := ModelKit.aabb(model)
			var width := box.size.x * scale
			var out := normal * side  # de la calle hacia la casa
			var yaw := atan2(-out.x, -out.y)  # la fachada (+Z del modelo) mira a la calle
			# El origen del modelo, de modo que su fachada quede en el borde de la calle.
			var p := at + dir * (width / 2.0) + out * (half + 1.0 + box.end.z * scale)
			if _try_house(p, yaw, d, spec):
				t += width + 0.15
				placed += 1
			else:
				t += 2.0
	return placed


## Elige modelo y escala del barrio (por peso).
func _pick(d: Dictionary) -> Array:
	var houses: Array = d["houses"]
	var total := 0
	for h in houses:
		total += h[3]
	var roll := _rng.randi() % total
	for h in houses:
		roll -= h[3]
		if roll < 0:
			# Escalas de a 0,05: cada escala distinta es otra forma de colisión que construir.
			return [_q(h[0]), snappedf(_rng.randf_range(h[1], h[2]), 0.05)]
	return [_q(houses[0][0]), houses[0][1]]


## La casa más pequeña del barrio (para encajar en huecos).
func _smallest(d: Dictionary) -> Array:
	var best: Array = []
	var best_area := INF
	for h in d["houses"]:
		var box := ModelKit.aabb(_q(h[0]))
		var area: float = box.size.x * box.size.z * h[1] * h[1]
		if area < best_area:
			best_area = area
			best = [_q(h[0]), h[1]]
	return best


## Coloca una casa si su huella está libre; añade ventanas, objetos y algún letrero.
func _try_house(p: Vector2, yaw: float, d: Dictionary, spec: Array = []) -> bool:
	if spec.is_empty():
		spec = _pick(d)
	var model: String = spec[0]
	var scale: float = spec[1]
	var box := ModelKit.aabb(model)
	var rect := Rect2(box.position.x * scale, box.position.z * scale, box.size.x * scale, box.size.z * scale)
	if not CityPlan.free_for_house(p, minf(rect.size.x, rect.size.y) * 0.35):
		return false
	if not _rect_free(p, yaw, rect.grow(-0.6)):
		return false
	_stamp_rect(p, yaw, rect)
	var tint: Color = d["tint"] * _rng.randf_range(0.88, 1.08)
	tint.a = 1.0
	_house_model(model, Vector3(p.x, 0, p.y), yaw, scale, tint)
	# Aserraderos: pila de troncos al costado.
	if "Sawmill" in model:
		var side := _at(p, yaw, Vector3(box.end.x * scale + 3.2, 0, 0))
		_log_pile(Vector2(side.x, side.z), yaw)
	# Herrajes de hierro (anclas para acero/hierro): veleta en el tejado o farol en la puerta.
	var iron_roll := _iron_rng.randf()
	if iron_roll < 0.3:
		var c := box.get_center() * scale
		_iron_vane(_at(p, yaw, Vector3(c.x, box.end.y * scale - 0.4, c.z)), yaw)
	elif iron_roll < 0.55:
		var local := Vector3(_iron_rng.randf_range(-0.35, 0.35) * box.size.x * scale, 2.6, box.end.z * scale)
		_iron_door_lamp(_at(p, yaw, local), yaw)
	if _rng.randf() < 0.12:
		var corner := _at(p, yaw, Vector3(box.end.x * scale + 0.6, 0, box.end.z * scale + 0.8))
		var item: String = ["props/Barrel", "props/Crate", "props/Hay"][_rng.randi() % 3]
		_add_prop(item, corner, _rng.randf() * TAU, 4.0)
	return true


# ---------------------------------------------------------------- Mapa de ocupación (1 m)

const OCC_HALF := 500
var _occ := PackedByteArray()


func _occ_init() -> void:
	_occ.resize((OCC_HALF * 2) * (OCC_HALF * 2))
	_occ.fill(0)


func _occ_index(p: Vector2) -> int:
	var ix := int(floor(p.x)) + OCC_HALF
	var iz := int(floor(p.y)) + OCC_HALF
	if ix < 0 or iz < 0 or ix >= OCC_HALF * 2 or iz >= OCC_HALF * 2:
		return -1
	return iz * OCC_HALF * 2 + ix


func _stamp_disc(c: Vector2, r: float) -> void:
	var x := -r
	while x <= r:
		var z := -r
		while z <= r:
			if x * x + z * z <= r * r:
				var i := _occ_index(c + Vector2(x, z))
				if i >= 0:
					_occ[i] = 1
			z += 0.8
		x += 0.8


func _stamp_line(a: Vector2, b: Vector2, half: float) -> void:
	var length := a.distance_to(b)
	var t := 0.0
	while t <= length:
		_stamp_disc(a.lerp(b, t / length), half)
		t += maxf(half, 0.8)


## Recorre la huella (rectángulo en coordenadas del modelo, girado yaw) cada 0,7 m.
func _rect_points(p: Vector2, yaw: float, rect: Rect2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var u := rect.position.x
	while u <= rect.end.x:
		var v := rect.position.y
		while v <= rect.end.y:
			var w := Basis(Vector3.UP, yaw) * Vector3(u, 0, v)
			out.append(p + Vector2(w.x, w.z))
			v += 0.7
		u += 0.7
	return out


## Igual que recorrer _rect_points, pero sin crear el array y cortando en el primer punto ocupado
## (es lo que más se llama al generar miles de casas).
func _rect_free(p: Vector2, yaw: float, rect: Rect2) -> bool:
	var ax := Vector2(cos(yaw), -sin(yaw))  # Basis(UP, yaw) * X
	var az := Vector2(sin(yaw), cos(yaw))  # Basis(UP, yaw) * Z
	var u := rect.position.x
	while u <= rect.end.x:
		var v := rect.position.y
		while v <= rect.end.y:
			var i := _occ_index(p + ax * u + az * v)
			if i < 0 or _occ[i] != 0:
				return false
			v += 0.7
		u += 0.7
	return true


func _stamp_rect(p: Vector2, yaw: float, rect: Rect2) -> void:
	for q in _rect_points(p, yaw, rect):
		var i := _occ_index(q)
		if i >= 0:
			_occ[i] = 1


## Ancla invisible de metal: las líneas apuntan a ella y no se mueve (no tiene masa movible).
func _metal_anchor(pos: Vector3) -> void:
	if not _rec.is_empty():
		_rec["anchors"].append(pos)
	var anchor := Node3D.new()
	anchor.position = pos
	anchor.add_to_group(&"metal")
	add_child(anchor)


## Pieza de hierro para el lote: caja unitaria escalada a size, girada yaw.
func _iron_piece(key: String, pos: Vector3, yaw: float, size: Vector3) -> void:
	if not _iron.has(key):
		var list: Array[Transform3D] = []
		_iron[key] = list
	_iron[key].append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), pos))


## Veleta: mástil, cruz de rumbos y flecha, sobre el tejado.
func _iron_vane(top: Vector3, yaw: float) -> void:
	var turn := _iron_rng.randf() * TAU
	_iron_piece("iron", top + Vector3(0, 0.9, 0), 0.0, Vector3(0.07, 2.2, 0.07))
	_iron_piece("iron", top + Vector3(0, 1.4, 0), yaw, Vector3(0.6, 0.04, 0.04))
	_iron_piece("iron", top + Vector3(0, 1.4, 0), yaw + PI / 2, Vector3(0.6, 0.04, 0.04))
	_iron_piece("iron", top + Vector3(0, 1.8, 0), turn, Vector3(1.0, 0.05, 0.05))
	_iron_piece("iron", top + Vector3(0, 1.8, 0) + Basis(Vector3.UP, turn) * Vector3(-0.45, 0, 0), turn, Vector3(0.25, 0.3, 0.03))
	_metal_anchor(top + Vector3(0, 1.4, 0))


## Farol de hierro colgado junto a la puerta: brazo, jaula y cristal encendido.
func _iron_door_lamp(wall: Vector3, yaw: float) -> void:
	var out := Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
	_iron_piece("iron", wall + out * 0.3, yaw, Vector3(0.05, 0.05, 0.6))
	_iron_piece("iron", wall + out * 0.55 + Vector3(0, -0.12, 0), yaw, Vector3(0.05, 0.25, 0.05))
	_iron_piece("iron", wall + out * 0.55 + Vector3(0, -0.28, 0), yaw, Vector3(0.3, 0.06, 0.3))
	_iron_piece("glass", wall + out * 0.55 + Vector3(0, -0.5, 0), yaw, Vector3(0.22, 0.36, 0.22))
	_iron_piece("iron", wall + out * 0.55 + Vector3(0, -0.7, 0), yaw, Vector3(0.28, 0.05, 0.28))
	_metal_anchor(wall + out * 0.55 + Vector3(0, -0.45, 0))


## Todos los herrajes de las casas en dos MultiMesh (hierro y cristal): dos llamadas de dibujo.
func _build_ironwork() -> void:
	var mats := {"iron": _m["iron"], "glass": _m["lamp_glass"]}
	for key: String in _iron:
		var mmi := Props.repeated_boxes(_iron[key], Vector3.ONE, mats[key])
		if key == "glass":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


## Farolas de hierro a lo largo de las avenidas: anclas para saltar de una a otra.
func _build_street_lamps() -> void:
	for av in CityPlan.avenues():
		var a: Vector2 = av[0]
		var b: Vector2 = av[1]
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var d := 48.0
		var k := 0
		while d < a.distance_to(b) - 18.0:
			var s := 1.0 if k % 2 == 0 else -1.0
			var p := a + dir * d + side * s * 5.5
			if CityPlan.dist_to_river(p) > CityPlan.RIVER_WIDTH and not CityPlan.near_hill(p):
				var lamp := Props.lamp_post(Vector3(p.x, 0, p.y), _m["iron"], _m["lamp_glass"], true)
				lamp.rotation.y = atan2(side.x * s, side.y * s)
				add_child(lamp)
			d += 24.0
			k += 1


# ---------------------------------------------------------------- Plaza del Centro

func _build_plaza() -> void:
	# Estatua de bronce del Lord Legislador: ancla de metal en el centro.
	add_child(Props.static_box(Vector3(5, 1.0, 5), Vector3(0, 0.5, -2), _m["trim"]))
	add_child(Props.static_box(Vector3(2.4, 1.6, 2.4), Vector3(0, 1.8, -2), _m["stone"]))
	Props.bronze_statue(self, Vector3(0, 2.6, -2), {"height": 2.1, "build": 1.15, "coat": Color.WHITE, "cloak": true, "hair_style": "short"}, _m["bronze"])

	# Farolas de la plaza: hierro de verdad.
	for i in 12:
		var ang := TAU * i / 12.0
		var lamp := Props.lamp_post(Vector3(cos(ang) * 17.0, 0, sin(ang) * 17.0), _m["iron"], _m["lamp_glass"])
		lamp.rotation.y = -ang + PI / 2  # el farol mira hacia el centro
		add_child(lamp)

	for i in 10:
		var ang := TAU * (i + 0.5) / 10.0
		var model := "props/MarketStand_1" if i % 2 == 0 else "props/MarketStand_2"
		_batch.add(_q(model), Vector3(cos(ang) * 27.0, 0, sin(ang) * 27.0), atan2(-cos(ang), -sin(ang)), 3.2, SKAA_TINT)

	for p in [Vector3(5, 0.05, 2), Vector3(-10, 0.05, -8)]:
		add_child(Props.static_box(Vector3(1.2, 0.1, 1.2), p, _m["rusty"], true))

	for i in 5:
		var s := _rng.randf_range(0.5, 1.2)
		var pos := Vector3(_rng.randf_range(-12, 12), s / 2.0 + 0.1, _rng.randf_range(-12, 14))
		if pos.distance_to(Vector3(0, pos.y, -2)) < 4.0:
			pos.x += 6.0
		add_child(Props.metal_crate(Vector3.ONE * s, pos, 60.0 * s * s * s, _m["rusty"], _m["iron"]))

	for i in 15:
		var coin := Props.coin()
		coin.position = Vector3(_rng.randf_range(-18, 18), 0.2, _rng.randf_range(-18, 18))
		add_child(coin)

	for p in [Vector3(3, 1, 4), Vector3(-8, 1, -8), Vector3(10, 1, 5), Vector3(-4, 1, 13), Vector3(0, 1, -22), Vector3(14, 1, -14)]:
		_vial(p, &"mix")
	for p in [Vector3(-3, 1, 2), Vector3(6, 1, -6)]:
		_vial(p, &"atium")


## Detalles de los bordes de la plaza. Casi todo es madera (o madera pintada): poco metal.
func _build_plaza_details() -> void:
	# Verjas pintadas a lo largo de los bordes, con huecos donde entran las calles.
	for s in [-1.0, 1.0]:
		for span in [Vector2(-30, -17), Vector2(17, 30)]:
			add_child(Props.iron_fence(Vector3(span.x, 0, s * 35), Vector3(span.y, 0, s * 35), _m["painted"]))
			add_child(Props.iron_fence(Vector3(s * 35, 0, span.x), Vector3(s * 35, 0, span.y), _m["painted"]))

	# Braseros en las esquinas; solo uno es de hierro.
	var corners := [Vector3(31, 0, 31), Vector3(-31, 0, 31), Vector3(31, 0, -31), Vector3(-31, 0, -31)]
	for i in corners.size():
		var b := Brazier.new()
		b.is_metal = i == 2
		b.position = corners[i]
		add_child(b)

	_add_prop("props/Well", Vector3(-24, 0, 24), 0.0, 3.5)

	# Bancos alrededor de la estatua, mirando hacia ella.
	for i in 4:
		var a := TAU * (i + 0.5) / 4.0
		var off := Vector3(sin(a), 0, cos(a)) * 7.5
		_batch.add(_q("props/Bench_1"), Vector3(0, 0, -2) + off, a + PI, 3.2, SKAA_TINT)

	for p in [Vector3(31.5, 0, 6), Vector3(32.3, 0, 6.7), Vector3(31.6, 0, 7.5), Vector3(-31.5, 0, -6),
			Vector3(-32.2, 0, -6.8), Vector3(6, 0, -31.5), Vector3(6.8, 0, -32.2), Vector3(-20, 0, 31.5)]:
		_add_prop("props/Barrel", p, _rng.randf() * TAU, 4.0)
	_batch.add(_q("props/Cart"), Vector3(28, 0, -14), 0.3, 3.2, SKAA_TINT)
	_batch.add(_q("props/Cart"), Vector3(-28, 0, 14), PI - 0.25, 3.2, SKAA_TINT)
	for p in [Vector3(-32, 0, 8), Vector3(-32, 0, 9.4), Vector3(24, 0, 32), Vector3(25.4, 0, 32.2)]:
		_add_prop("props/Crate", p, _rng.randf() * TAU, 6.0)

	# Estandartes de las casas nobles en las entradas de la plaza.
	var i := 0
	for p in [Vector3(-15, 0, -33), Vector3(15, 0, -33), Vector3(-15, 0, 33), Vector3(15, 0, 33),
			Vector3(33, 0, -15), Vector3(33, 0, 15), Vector3(-33, 0, -15), Vector3(-33, 0, 15)]:
		add_child(Props.banner_pole(p, HOUSES[i % HOUSES.size()], _m["wood"]))
		i += 1


func _vial(pos: Vector3, kind: StringName) -> void:
	var v := Vial.new()
	v.kind = kind
	v.position = pos
	add_child(v)


func _spawn_people() -> void:
	for i in 22:
		var c := Citizen.new()
		var home := Vector3(_rng.randf_range(-30, 30), 0, _rng.randf_range(-30, 30))
		if home.distance_to(Vector3(0, 0, -2)) < 9.0:
			home.x += 12.0
		c.home = home
		c.roam_radius = 18.0
		c.position = home + Vector3(0, 0.1, 0)
		add_child(c)
	for i in 6:
		var g := Guard.new()
		var ang := TAU * i / 6.0
		g.home = Vector3(cos(ang) * 22.0, 0, sin(ang) * 22.0)
		g.roam_radius = 10.0
		g.position = g.home + Vector3(0, 0.1, 0)
		add_child(g)
	# Dos guardias en cada puerta, por dentro.
	for gate in CityPlan.gates():
		for side in [-1.0, 1.0]:
			var p: Vector2 = gate[1] - gate[2] * 12.0 + gate[3] * side * 4.0
			var g := Guard.new()
			g.home = Vector3(p.x, 0, p.y)
			g.roam_radius = 3.0
			g.stay_in_plaza = false
			g.position = g.home + Vector3(0, 0.1, 0)
			add_child(g)
