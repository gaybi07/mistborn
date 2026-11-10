class_name AshPit
extends Node3D
## Foso de ceniza (Story.PLACES "foso"): un pozo de trabajo forzado al oeste de Luthadel, grande para moverse con
## alomancia. Cuatro paredes de 10 m (40 m de hondo, unos 200 m de ancho) con terrazas entre ellas y una rampa por pared
## que baja en espiral. No es redondo: el borde tiene lóbulos (rim_at), cada terraza ondula a su manera (ruido), hay
## espolones que cortan algunas terrazas (SPURS, como un laberinto) y picos de roca que salen del fondo (PEAKS). Afuera,
## más allá del campamento, unas lomas (HILLS). Todo eso está en el terreno (CityPlan.ground resta depth); este nodo pone
## lo de arriba: empalizada, torres de guardia, barracas, fogatas, montañas de ceniza, carros y cajones (Quaternius).
## La gente: cuadrillas skaa (SkaaCrews, ver crew_sites) y soldados de guardia (GateForces.PEOPLE).
## shortcut: todo con piezas de Quaternius; los modelos propios (andamios, poleas, jaulas) están pedidos en G20.

const CENTER := Vector2(-580, 330)
const RIM := 100.0  ## radio medio del borde (rim_at lo deforma entre ~85 y ~115)
const DROP := 10.0  ## alto de cada pared
const WALL := 8.0  ## ancho (en planta) de cada pared
const BENCH := 9.0  ## ancho de cada terraza
const WALLS := 4
const RAMP_LEN := 52.0  ## largo de cada rampa (10 m en 52: suave)
const RAMP_GAP := 0.35  ## giro (rad) entre el final de una rampa y el principio de la siguiente
const WOBBLE := 6.0  ## cuánto ondula cada terraza (m)
const FENCE_OUT := 14.0  ## la empalizada, a cuánto del borde
const CAMP := 165.0  ## hasta dónde llega el campamento (sin árboles)
const GATE_HALF := 0.1  ## mitad del hueco de la entrada, al este (hacia la ciudad), en radianes
const KIT := 3.2  ## los modelos de Quaternius vienen chicos (como en Main)
const ASH := Color(0.32, 0.31, 0.3)
## Espolones: [terraza (0 = la de arriba), ángulo, ancho en m]. Cortan la vuelta por esa terraza, nunca el camino de una
## rampa a la siguiente (ver _check_spurs).
const SPURS := [[0, 2.6, 7.0], [0, 4.7, 6.0], [1, 0.4, 7.0], [1, 5.6, 6.0], [2, 5.2, 8.0]]
## Picos de roca: [desplazamiento desde CENTER, radio, alto desde el fondo]. El primero asoma sobre el borde.
const PEAKS := [[Vector2(-12, 10), 13.0, 52.0], [Vector2(15, -12), 9.0, 30.0], [Vector2(-38, -45), 8.0, 24.0]]
## Lomas de afuera: [ángulo, distancia al centro, radio, alto]. Del lado de la ciudad (este), ninguna.
const HILLS := [[1.4, 215.0, 45.0, 16.0], [2.1, 235.0, 55.0, 22.0], [2.9, 210.0, 40.0, 12.0], [3.6, 240.0, 60.0, 26.0],
	[4.3, 220.0, 42.0, 14.0], [5.0, 230.0, 50.0, 18.0]]

static var _ramps: Array = []  # [inicio, ancho] en radianes de cada pared
static var _noise: FastNoiseLite


## Radio del borde en ese ángulo: lóbulos suaves para que no sea un círculo.
static func rim_at(angle: float) -> float:
	return RIM * (1.0 + 0.07 * sin(2.0 * angle + 1.0) + 0.05 * sin(3.0 * angle + 2.3) + 0.03 * sin(5.0 * angle + 0.7))


static func _n(p: Vector2) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 4242
		_noise.frequency = 0.035
	return _noise.get_noise_2dv(p)


## Cuánto baja el suelo en p por el pozo (0 lejos; negativo en las lomas de afuera, que suben).
static func depth(p: Vector2) -> float:
	var l := p - CENTER
	var r := l.length()
	if r > 320.0:
		return 0.0
	var a := atan2(l.y, l.x)
	var band := rim_at(a) - r + _n(p) * WOBBLE
	if band <= 0.0:
		return -_hill_height(p)
	var k := int(band / (WALL + BENCH))
	var d: float
	if k >= WALLS:
		d = DROP * WALLS
	else:
		var s := band - k * (WALL + BENCH)
		if s >= WALL:
			d = DROP * (k + 1)  # terraza
			for spur: Array in SPURS:  # espolón: la terraza sube al nivel de arriba
				if spur[0] == k and absf(angle_difference(a, spur[1])) * r < spur[2] * 0.5 * (1.0 + 0.4 * _n(p * 3.0)):
					d = DROP * k
		else:
			var t := ramp_t(k, a)
			d = DROP * (k + t) if t >= 0.0 else DROP * k + DROP * smoothstep(0.0, WALL, s)
	for peak: Array in PEAKS:  # picos: roca que sube desde el fondo, con aristas
		var q: float = p.distance_to(CENTER + peak[0]) / peak[1]
		if q < 1.0:
			var top: float = peak[2] * pow(1.0 - q, 1.4) * (0.85 + 0.15 * _n(p * 4.0))
			d = minf(d, DROP * WALLS - top)
	return d


## Lomas de afuera (alto en p).
static func _hill_height(p: Vector2) -> float:
	var h := 0.0
	for hill: Array in HILLS:
		var c: Vector2 = CENTER + Vector2.from_angle(hill[0]) * hill[1]
		var q: float = p.distance_to(c) / (hill[2] * (1.0 + 0.2 * _n(p * 0.5)))
		if q < 1.0:
			h = maxf(h, hill[3] * smoothstep(1.0, 0.0, q))
	return h


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


## Punto en la terraza (o el fondo) de esa pared, en ese ángulo: se busca bajando por el radio, porque las terrazas
## ondulan. Si en ese ángulo no hay terraza llana (un pico, un espolón), el punto más parecido.
static func on_bench(wall: int, angle: float) -> Vector2:
	var want := DROP * (wall + 1)
	var dir := Vector2.from_angle(angle)
	var best := CENTER
	var best_err := INF
	var run: Array = []
	var r := rim_at(angle) + WOBBLE
	while r > 2.0:
		var p := CENTER + dir * r
		var err := absf(depth(p) - want)
		if err < 0.05:
			run.append(p)
		elif not run.is_empty():
			break
		if err < best_err:
			best_err = err
			best = p
		r -= 0.5
	return run[int(run.size() / 2.0)] if not run.is_empty() else best


## Puestos de cuadrillas skaa (SkaaCrews): cavan en las terrazas y el fondo, y acarrean en el borde.
static func crew_sites() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var spots := [[0, 2.0], [1, 3.6], [1, 5.0], [2, 1.2], [2, 4.4], [3, 2.8], [3, 0.0], [3, 4.4]]
	for i in spots.size():
		var p := on_bench(spots[i][0], spots[i][1])
		var tangent := Vector2(-sin(spots[i][1]), cos(spots[i][1]))
		out.append({"pos": p, "dir": tangent, "side": 1.0, "kind": "obra" if i % 3 != 2 else "carga", "node": null})
	return out


## Que ningún espolón tape el paso del final de una rampa al principio de la siguiente (por esa terraza se baja).
static func _check_spurs() -> void:
	ramp_t(0, 0.0)
	for spur: Array in SPURS:
		var k: int = spur[0]
		if k + 1 >= WALLS:
			continue
		var from: float = _ramps[k][0] + _ramps[k][1] - 0.15
		var to: float = _ramps[k + 1][0] + 0.15
		assert(fposmod(spur[1] - from, TAU) > to - from, "el espolón %s tapa la bajada" % [spur])


func _ready() -> void:
	_check_spurs()
	var batch := ModelBatcher.new()
	batch.on_ground = true
	batch.draw_chunk = 64.0
	batch.draw_far = Art.DRAW_FAR
	add_child(batch)
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	_palisade(batch)
	for a: float in [0.35, -0.35, 1.6, -1.6, PI]:  # torres de guardia
		batch.add(ModelKit.path("castle/WatchTowerWRoof"), _at(a, FENCE_OUT + 6.0), -a + PI / 2.0, KIT)
	for i in 6:  # barracas de los presos y la casa del capataz, del lado de la entrada
		var a := -0.75 + i * 0.3
		var model := "buildings/House_1" if i == 2 else ("buildings/Stable" if i % 2 == 0 else "buildings/Sawmill")
		batch.add(ModelKit.path(model), _at(a, 38.0), -a - PI / 2.0, KIT)
	# Montañas de ceniza: en las terrazas y afuera, junto a la empalizada.
	var rocks := ["props/Rock_1", "props/Rock_2", "props/Rock_3"]
	for i in 26:
		var wall := r.randi_range(1, WALLS - 1)
		var ang := r.randf() * TAU
		var p := on_bench(wall, ang) if i < 16 else CENTER + Vector2.from_angle(ang) * (rim_at(ang) + r.randf_range(20.0, 50.0))
		if i >= 16 and absf(angle_difference(0.0, ang)) < 0.5:
			continue  # frente a la entrada, no
		batch.add(ModelKit.path(rocks[i % 3]), Vector3(p.x, 0, p.y), r.randf() * TAU, KIT * r.randf_range(2.0, 4.0), ASH)
	# Carros, cajones, barriles y bolsas en las terrazas; fogatas para ver de noche.
	var things := ["props/Cart", "props/Crate", "props/Barrel", "props/Bags", "props/Hay"]
	for i in 30:
		var p := on_bench(r.randi_range(0, WALLS - 1), r.randf() * TAU) + Vector2(r.randf_range(-2, 2), r.randf_range(-2, 2))
		batch.add(ModelKit.path(things[i % things.size()]), Vector3(p.x, 0, p.y), r.randf() * TAU, KIT)
	for i in 10:
		var out := _at(-0.4 + (i - 7) * 0.4, 26.0)
		var p := on_bench(i % WALLS, i * 1.3) if i < 7 else Vector2(out.x, out.z)
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


## Empalizada: cercas de madera siguiendo el borde, con la entrada hacia la ciudad.
func _palisade(batch: ModelBatcher) -> void:
	var fence := ModelKit.path("props/Fence")
	var s := KIT * 2.2  # la cerca de Quaternius es de jardín (1 m): al doble, empalizada de 2 m
	var length := ModelKit.aabb(fence).size.x * s
	var a := GATE_HALF
	while a < TAU - GATE_HALF:
		var radius := rim_at(a) + FENCE_OUT
		var step := length * 0.97 / radius  # que se pisen un poco: sin huecos
		var p0 := _at(a, FENCE_OUT)  # cada cerca va de punto a punto del contorno, que no es un círculo
		var p1 := _at(a + step, FENCE_OUT)
		batch.add(fence, (p0 + p1) / 2.0, -Vector2(p1.x - p0.x, p1.z - p0.z).angle(), s)
		a += step


## Punto a `out` metros afuera del borde, en ese ángulo.
func _at(angle: float, out: float) -> Vector3:
	var p := CENTER + Vector2(cos(angle), sin(angle)) * (rim_at(angle) + out)
	return Vector3(p.x, 0, p.y)
