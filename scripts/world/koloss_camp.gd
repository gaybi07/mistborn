class_name KolossCamp
extends Node3D
## Campamento koloss (Story.PLACES "campamento"): un claro al norte del camino de la Puerta Este, a unos 300 m de la
## muralla. Grande y desordenado: empalizada de barricadas de hueso rota a tramos, refugios de cuero y hueso en corros
## alrededor de fogatas, una hoguera enorme en el centro con el trono de huesos, tambores de guerra, jaulas de presos y
## tótems, espadones clavados, y la carga que llega por la entrada (lo que descubre la misión "rastros" del Acto 2:
## alguien está trayendo koloss). Los koloss que andan por ahí los pone GateForces (PEOPLE con kit de koloss).
## No van árboles ni lomas adentro (Exterior, covers). Los modelos son de Meshy (G24, assets/koloss/campamento:
## tools/blender/meshy_props_to_glb.py); los huesos sueltos siguen siendo rocas tintadas.

const CENTER := Vector2(640, -330)
const RADIUS := 115.0  ## el claro
const STAKES_R := 95.0  ## la empalizada
const KIT := 3.2
const BONE := Color(0.82, 0.78, 0.66)
const GEAR := "res://assets/koloss/campamento/%s.glb"
## La entrada: del camino al centro, por el sur.
const GATE_ANGLE := PI / 2.0
## El camino de la Puerta Este, como lo traza Exterior (semilla 4242).
const ROAD := [Vector2(340.08, -137.2), Vector2(503.86, -216.86), Vector2(684.2, -242.96), Vector2(851.71, -310.54)]
## Corros de refugios: [ángulo, distancia al centro, refugios].
const CLUSTERS := [[0.2, 60.0, 5], [1.1, 55.0, 4], [2.0, 62.0, 5], [2.9, 58.0, 5], [3.8, 64.0, 4], [4.6, 52.0, 5],
	[5.5, 60.0, 4], [0.0, 30.0, 3], [3.1, 34.0, 3]]


static func covers(p: Vector2, margin := 0.0) -> bool:
	return p.distance_to(CENTER) < RADIUS + margin


static func _polar(angle: float, r: float) -> Vector2:
	return CENTER + Vector2.from_angle(angle) * r


var _batch: ModelBatcher
var _r := RandomNumberGenerator.new()


func _ready() -> void:
	_r.seed = 640
	_batch = ModelBatcher.new()
	_batch.on_ground = true
	_batch.draw_chunk = 64.0
	_batch.draw_far = Art.DRAW_FAR
	add_child(_batch)
	_stakes()
	_center()
	for c: Array in CLUSTERS:
		var mid := _polar(c[0], c[1])
		_fire(mid, 1.3, 14.0)
		# Refugios alrededor de la fogata, con la entrada hacia ella.
		for i in int(c[2]):
			var a: float = TAU * i / c[2] + _r.randf_range(-0.2, 0.2)
			var p := mid + Vector2.from_angle(a) * _r.randf_range(8.5, 10.5)
			_gear("KolossRefugio", p, _face(p, mid), _r.randf_range(0.85, 1.1))
		# Junto a cada fogata: huesos, un barril o un cajón, y a veces un espadón tirado.
		for i in 2:
			var p := mid + Vector2.from_angle(_r.randf() * TAU) * _r.randf_range(3.0, 5.0)
			_batch.add(ModelKit.path(["props/Rock_1", "props/Rock_2"][i]), Vector3(p.x, 0, p.y), _r.randf() * TAU, KIT * _r.randf_range(1.0, 1.6), BONE)
		var side := mid + Vector2.from_angle(c[0] + PI) * 4.5
		_gear("KolossBarril" if _r.randf() < 0.5 else "KolossCajon", side, _r.randf() * TAU)
		if _r.randf() < 0.6:
			var b := mid + Vector2.from_angle(c[0] + PI / 2.0) * 4.0
			_gear("KolossEspada%d" % (_r.randi() % 3 + 1), b, _r.randf() * TAU, 1.0, false)
	# Montañas de huesos sueltas.
	for i in 12:
		var p := _polar(_r.randf() * TAU, _r.randf_range(20.0, 88.0))
		_batch.add(ModelKit.path(["props/Rock_1", "props/Rock_2", "props/Rock_3"][i % 3]), Vector3(p.x, 0, p.y), _r.randf() * TAU, KIT * _r.randf_range(2.0, 3.5), BONE)
	# Lo que traen de afuera: pilas de cajones y barriles a lo largo de la entrada, del camino al centro, y jaulas
	# vacías esperando carga.
	for i in 8:
		var p := _polar(GATE_ANGLE, 100.0 - i * 9.0) + Vector2(6.5 if i % 2 == 0 else -6.5, 0)
		for k in 3:
			var q := p + Vector2(k * 1.8, 0).rotated(_r.randf_range(-0.2, 0.2))
			_gear("KolossCajon" if (i + k) % 3 else "KolossBarril", q, _r.randf_range(-0.3, 0.3))
		if i % 3 == 1:
			_gear("KolossJaula", p + Vector2(-4.0 if i % 2 == 0 else 4.0, 0), _r.randf() * TAU)
	# Efigies de hueso en la entrada y en el borde: avisan de quién es esto.
	for a: float in [GATE_ANGLE - 0.13, GATE_ANGLE + 0.13, 0.9, 2.6, 4.0, 5.3]:
		var p := _polar(a, STAKES_R - 5.0)
		_gear("KolossEfigies", p, _face(p, CENTER))
	# Torres de vigía en el borde.
	for a: float in [0.7, 2.5, 4.2, 5.8]:
		var p := _polar(a, STAKES_R - 8.0)
		_gear("KolossTorre", p, _face(p, CENTER))
	_batch.finalize()


## El centro: la hoguera grande, el trono de huesos mirándola, tambores, tótems con fuego y las jaulas de los presos.
func _center() -> void:
	_fire(CENTER, 3.0, 26.0)
	var throne := _polar(-PI / 2.0, 12.0)  # al norte, de cara a la hoguera y a la entrada
	_gear("KolossTrono", throne, _face(throne, CENTER), 1.1)
	for s: float in [-1.0, 1.0]:
		var d := throne + Vector2(s * 4.2, 1.0)
		_gear("KolossTambor", d, _face(d, CENTER))
		_gear("KolossEspada%d" % (2 if s < 0 else 3), throne + Vector2(s * 2.2, -1.6), PI / 2.0 + s * 0.3, 1.0, false)
	for k in 4:  # tótems con brasas, alrededor de la hoguera
		var p := _polar(PI / 4.0 + k * PI / 2.0, 9.0)
		_gear("KolossTotem", p, _face(p, CENTER))
		_batch.add(ModelKit.path("props/Bonfire_Lit"), Vector3(p.x, 3.75, p.y), 0.0, KIT * 0.8, Color.WHITE, false)  # brasas en la canasta
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.5, 0.2)
		glow.omni_range = 7.0
		glow.light_energy = 1.4
		glow.position = Vector3(p.x, CityPlan.ground(p) + 4.4, p.y)
		glow.distance_fade_enabled = true
		glow.distance_fade_begin = Art.DRAW_FAR
		add_child(glow)
	for k in 3:  # jaulas de presos, al este del trono
		var p := _polar(-PI / 2.0 + 0.7 + k * 0.32, 18.0)
		_gear("KolossJaula", p, _face(p, CENTER))


## Empalizada de barricadas de hueso con tramos caídos, y la entrada hacia el camino.
func _stakes() -> void:
	var piece := 3.6  # lo que ocupa cada barricada a lo largo
	var a := 0.0
	while a < TAU:
		var step := piece / STAKES_R
		var gap := absf(angle_difference(a, GATE_ANGLE)) < 0.12 or _on_road(_polar(a, STAKES_R))
		var broken := sin(a * 7.0) > 0.85  # tramos caídos
		if not gap and not broken:
			var p0 := _polar(a, STAKES_R + _r.randf_range(-1.2, 1.2))
			var p1 := _polar(a + step, STAKES_R)
			_gear("KolossBarricada", (p0 + p1) / 2.0, -(p1 - p0).angle() + _r.randf_range(-0.08, 0.08), _r.randf_range(0.9, 1.1))
		elif broken and _r.randf() < 0.3:  # una barricada volteada en el hueco
			_gear("KolossBarricada", _polar(a, STAKES_R + 2.0), _r.randf() * TAU, 0.8)
		a += step


## Una pieza del campamento (G24) en p, girada yaw; `collide`: si se choca (las espadas tiradas, no).
func _gear(name: String, p: Vector2, yaw: float, scale := 1.0, collide := true) -> void:
	_batch.add(GEAR % name, Vector3(p.x, 0, p.y), yaw, scale, Color.WHITE, collide)


## Giro para que el frente de un modelo (+Z) mire hacia `to`.
static func _face(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(d.x, d.y)


## Si p cae sobre el camino de la Puerta Este (ahí la empalizada no sigue).
static func _on_road(p: Vector2) -> bool:
	for i in ROAD.size() - 1:
		if Geometry2D.get_closest_point_to_segment(p, ROAD[i], ROAD[i + 1]).distance_to(p) < 8.0:
			return true
	return false


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
