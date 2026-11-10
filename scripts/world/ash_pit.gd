class_name AshPit
extends Node3D
## Foso de ceniza (Story.PLACES "foso"): un pozo de trabajo forzado al oeste de Luthadel, grande para moverse con
## alomancia. Cinco paredes de 8 m (40 m de hondo, 200 m de ancho) con terrazas entre ellas y una rampa por pared que
## baja en espiral. El pozo está en el terreno (CityPlan.ground resta depth); este nodo pone lo de arriba: empalizada,
## torres de guardia, barracas, fogatas, montañas de ceniza, carros y cajones (Quaternius). La gente: cuadrillas skaa
## (SkaaCrews, ver crew_sites) y soldados de guardia (GateForces.PEOPLE).
## shortcut: todo con piezas de Quaternius; los modelos propios (andamios, poleas, jaulas) están pedidos en G20.

const CENTER := Vector2(-580, 330)
const RIM := 100.0  ## radio del borde
const DROP := 8.0  ## alto de cada pared
const WALL := 8.0  ## ancho (en planta) de cada pared
const BENCH := 10.0  ## ancho de cada terraza
const WALLS := 5
const RAMP_LEN := 48.0  ## largo de cada rampa (pendiente de 8 m en 48: suave)
const RAMP_GAP := 0.35  ## giro (rad) entre el final de una rampa y el principio de la siguiente
const PALISADE := 112.0  ## radio de la empalizada
const CAMP := 165.0  ## hasta dónde llega el campamento (sin árboles)
const GATE_HALF := 0.1  ## mitad del hueco de la entrada, al este (hacia la ciudad), en radianes
const KIT := 3.2  ## los modelos de Quaternius vienen chicos (como en Main)
const ASH := Color(0.32, 0.31, 0.3)

static var _ramps: Array = []  # [inicio, ancho] en radianes de cada pared


## Cuánto baja el suelo en p por el pozo (0 afuera).
static func depth(p: Vector2) -> float:
	var l := p - CENTER
	var r := l.length()
	if r >= RIM:
		return 0.0
	var band := RIM - r
	var k := int(band / (WALL + BENCH))
	if k >= WALLS:
		return DROP * WALLS
	var s := band - k * (WALL + BENCH)
	if s >= WALL:
		return DROP * (k + 1)  # terraza
	var t := ramp_t(k, atan2(l.y, l.x))
	if t >= 0.0:
		return DROP * (k + t)  # rampa: baja con el ángulo
	return DROP * k + DROP * smoothstep(0.0, WALL, s)


## Dónde está una rampa: 0 al principio (arriba) y 1 al final (abajo), o -1 si ese ángulo no cae en la rampa de esa pared.
static func ramp_t(wall: int, angle: float) -> float:
	if _ramps.is_empty():
		var a := 0.6
		for k in WALLS:
			var mid := RIM - k * (WALL + BENCH) - WALL / 2.0
			var width := RAMP_LEN / mid
			_ramps.append([a, width])
			a += width + RAMP_GAP
	var start: float = _ramps[wall][0]
	var width: float = _ramps[wall][1]
	var t := fposmod(angle - start, TAU) / width
	return t if t <= 1.0 else -1.0


## Si p queda en el pozo o su campamento (ahí no van árboles ni rocas sueltas).
static func covers(p: Vector2, margin := 0.0) -> bool:
	return p.distance_to(CENTER) < CAMP + margin


## Punto en la terraza (o el fondo) de esa pared, en ese ángulo.
static func on_bench(wall: int, angle: float) -> Vector2:
	var r := RIM - wall * (WALL + BENCH) - WALL - BENCH / 2.0 if wall < WALLS - 1 else 10.0
	return CENTER + Vector2(cos(angle), sin(angle)) * r


## Puestos de cuadrillas skaa (SkaaCrews): cavan en las terrazas y el fondo, y acarrean en el borde.
static func crew_sites() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var spots := [[0, 2.4], [1, 3.6], [1, 5.2], [2, 1.2], [2, 4.4], [3, 2.8], [4, 0.0], [4, 3.0]]
	for i in spots.size():
		var p := on_bench(spots[i][0], spots[i][1])
		var tangent := Vector2(-sin(spots[i][1]), cos(spots[i][1]))
		out.append({"pos": p, "dir": tangent, "side": 1.0, "kind": "obra" if i % 3 != 2 else "carga", "node": null})
	return out


func _ready() -> void:
	var batch := ModelBatcher.new()
	batch.on_ground = true
	batch.draw_chunk = 64.0
	batch.draw_far = Art.DRAW_FAR
	add_child(batch)
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	_palisade(batch)
	for a: float in [0.35, -0.35, 1.6, -1.6, PI]:  # torres de guardia
		batch.add(ModelKit.path("castle/WatchTowerWRoof"), _at(a, PALISADE + 6.0), -a + PI / 2.0, KIT)
	for i in 6:  # barracas de los presos y la casa del capataz, del lado de la entrada
		var a := -0.75 + i * 0.3
		var model := "buildings/House_1" if i == 2 else ("buildings/Stable" if i % 2 == 0 else "buildings/Sawmill")
		batch.add(ModelKit.path(model), _at(a, 140.0), -a - PI / 2.0, KIT)
	# Montañas de ceniza: en el fondo, en las terrazas y afuera, junto a la empalizada.
	var rocks := ["props/Rock_1", "props/Rock_2", "props/Rock_3"]
	for i in 26:
		var wall := r.randi_range(1, WALLS - 1)
		var p := on_bench(wall, r.randf() * TAU) if i < 16 else CENTER + Vector2.from_angle(r.randf() * TAU) * r.randf_range(118.0, 158.0)
		if i >= 16 and absf(angle_difference(0.0, (p - CENTER).angle())) < 0.5:
			continue  # frente a la entrada, no
		batch.add(ModelKit.path(rocks[i % 3]), Vector3(p.x, 0, p.y), r.randf() * TAU, KIT * r.randf_range(2.0, 4.0), ASH)
	# Carros, cajones, barriles y bolsas en las terrazas; fogatas para ver de noche.
	var things := ["props/Cart", "props/Crate", "props/Barrel", "props/Bags", "props/Hay"]
	for i in 30:
		var p := on_bench(r.randi_range(0, WALLS - 1), r.randf() * TAU) + Vector2(r.randf_range(-3, 3), r.randf_range(-3, 3))
		batch.add(ModelKit.path(things[i % things.size()]), Vector3(p.x, 0, p.y), r.randf() * TAU, KIT)
	for i in 10:
		var p := on_bench(i % WALLS, i * 1.3) if i < 7 else CENTER + Vector2.from_angle(-0.4 + (i - 7) * 0.4) * 128.0
		batch.add(ModelKit.path("props/Bonfire_Lit"), Vector3(p.x, 0, p.y), 0.0, KIT, Color.WHITE, false)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.6, 0.3)
		light.omni_range = 14.0
		light.light_energy = 2.0
		light.position = Vector3(p.x, CityPlan.ground(p) + 1.5, p.y)
		light.distance_fade_enabled = true
		light.distance_fade_begin = Art.DRAW_FAR
		add_child(light)
	batch.finalize()


## Empalizada: cercas de madera alrededor del pozo, con la entrada hacia la ciudad.
func _palisade(batch: ModelBatcher) -> void:
	var fence := ModelKit.path("props/Fence")
	var s := KIT * 2.2  # la cerca de Quaternius es de jardín (1 m): al doble, empalizada de 2 m
	var length := ModelKit.aabb(fence).size.x * s
	var step := length * 0.97 / PALISADE  # que se pisen un poco: sin huecos
	var a := GATE_HALF
	while a < TAU - GATE_HALF:
		batch.add(fence, _at(a, PALISADE), -a + PI / 2.0, s)
		a += step


func _at(angle: float, radius: float) -> Vector3:
	var p := CENTER + Vector2(cos(angle), sin(angle)) * radius
	return Vector3(p.x, 0, p.y)
