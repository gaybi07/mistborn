class_name CityPlan
## Plano de Luthadel (datos y consultas geométricas), a escala real según el mapa de referencia
## (800 × 1000 m): muralla ovalada con las puertas Oeste, Este y Sur; Kredik Shaw sobre su colina
## al norte con el Distrito Noble al noroeste y el Mercantil al noreste; la avenida principal de
## oeste a este; la Plaza Central; tres cuarteles; el Distrito de Forja y los corrales de carbón
## al oeste; el Distrito Skaa al sur; y el río por el este con la dársena, talleres y almacenes.
## Coordenadas en el plano XZ (Vector2(x, z)) con el origen en la Plaza Central; el norte es -z.

## Vértices de la muralla, en orden.
const WALL := [
	Vector2(-4, -473), Vector2(107, -454), Vector2(193, -406), Vector2(257, -335), Vector2(301, -250),
	Vector2(344, -111), Vector2(351, 32), Vector2(351, 160), Vector2(353, 267), Vector2(328, 346),
	Vector2(221, 397), Vector2(103, 435), Vector2(-164, 421), Vector2(-264, 349), Vector2(-329, 253),
	Vector2(-360, 146), Vector2(-369, 46), Vector2(-367, -168), Vector2(-337, -264), Vector2(-275, -357),
	Vector2(-185, -421), Vector2(-93, -460),
]
## Rectángulo que abarca la muralla (para recorrer la ciudad).
const BOUNDS := Rect2(-370, -474, 724, 910)
## Puertas: [nombre, índice del tramo de muralla, posición a lo largo del tramo (0..1)]
const GATE_SPECS := [["Puerta Este", 4, 0.82], ["Puerta Sur", 11, 0.5], ["Puerta Oeste", 16, 0.5]]
const GATE_WIDTH := 10.0

## Río (polilínea) y su anchura: baja por el este, entra en la ciudad junto a la Puerta Este y
## sale por el sureste.
const RIVER := [
	Vector2(178, -538), Vector2(225, -417), Vector2(292, -335), Vector2(339, -246), Vector2(364, -146),
	Vector2(353, -82), Vector2(292, -39), Vector2(225, 11), Vector2(182, 71), Vector2(171, 128),
	Vector2(203, 178), Vector2(260, 225), Vector2(314, 275), Vector2(371, 324), Vector2(428, 431),
	Vector2(485, 602),
]
const RIVER_WIDTH := 30.0
const RIVER_DEPTH := 3.0
const WATER_LEVEL := -1.0

## Kredik Shaw: centro de la fortaleza y medio tamaño de su meseta (con la rampa al sur).
const HILL := Vector2(-4, -328)
const HILL_HALF := Vector2(152, 104)  ## con el cordón de picos que la rodea
const HILL_SOUTH := 104.0  ## hasta donde llega la rampa

## Plazas: [centro, radio]. La Central es cuadrada (ver PLAZA_HALF).
const PLAZA_HALF := 40.0
const MARKET := Vector2(70, -165)  ## en el corazón del Distrito Mercantil
const MARKET_RADIUS := 19.0
const ASSEMBLY := Vector2(-110, -85)
const ASSEMBLY_RADIUS := 18.0
const MINISTRY := Vector2(166, -208)

## Mansiones nobles genéricas: [centro, ancho, fondo, ángulo, casa]
const ESTATES := [
	[Vector2(-292, -252), 46.0, 40.0, -0.15, 1],  # Casa Hastings
	[Vector2(-60, -175), 45.0, 35.0, 0.3, 2],  # Casa Lorch
]
## Terreno de la Casa Venture (ver VentureManor: POS y CITY_LOT): [centro, ancho, fondo, ángulo]
const VENTURE := [Vector2(-195, -261), 70.0, 92.0, 0.0]
## Cuarteles imperiales: [centro, ancho, fondo, ángulo]
const BARRACKS := [
	[Vector2(-267, -150), 120.0, 90.0, 0.0],
	[Vector2(205, -295), 80.0, 80.0, 0.1],
	[Vector2(90, 335), 110.0, 85.0, 0.0],
]
## Dársena: muelles a lo largo de la orilla oeste del río, entre estos dos puntos.
const PORT_A := Vector2(279, -56)
const PORT_B := Vector2(212, -6)
const PORT_DEPTH := 16.0  ## franja de almacenes tierra adentro

const STREET_HALF := 4.0
const ALLEY_HALF := 2.2
## Callejones: red de nudos cada ALLEY_STEP m, movidos al azar para que salga un laberinto.
const ALLEY_STEP := 34.0
const HILL_RING := 6.0  ## separación entre la meseta y la calle que la rodea

## Avenidas (con farolas): la principal de oeste a este y las que van de la plaza al norte y al sur.
const AVENUES := [
	[Vector2(-369, -61), Vector2(150, -61), Vector2(336, -136)],
	[Vector2(0, -40), Vector2(-3, -228)],
	[Vector2(0, 40), Vector2(-21, 232), Vector2(-30, 428)],
]
## Otras calles principales (polilíneas).
const STREETS := [
	[Vector2(-195, -61), Vector2(-195, -203), Vector2(-110, -205), Vector2(-75, -258)],  # al Distrito Noble y la verja de Venture
	[Vector2(-195, -203), Vector2(-195, -216)],  # hasta la verja de la Casa Venture
	[Vector2(150, -61), Vector2(195, -240)],  # al cuartel del noreste
	[Vector2(-2, -120), Vector2(-200, -120)],  # a la Asamblea y el cuartel del noroeste
	[Vector2(40, -10), Vector2(200, -22)],  # a la dársena
	[Vector2(-40, 10), Vector2(-180, 40), Vector2(-300, 90)],  # Distrito de Forja
	[Vector2(-180, 40), Vector2(-250, 180), Vector2(-280, 290)],  # corrales de carbón
	[Vector2(-21, 172), Vector2(-150, 172), Vector2(-280, 150)],  # Distrito Skaa
	[Vector2(-26, 300), Vector2(-150, 330), Vector2(-220, 330)],
	[Vector2(40, 40), Vector2(130, 140), Vector2(170, 250), Vector2(160, 380)],  # talleres y almacenes
	[Vector2(170, 250), Vector2(330, 200)],  # cruza el río a la orilla este
	[Vector2(-25, 300), Vector2(35, 335)],  # al cuartel del sur
]

## Barrios: el de cada punto es el del centro más cercano.
## density: "dense" (casas en hilera en todas las calles y relleno apretado), "medium", "sparse".
## houses: [modelo, escala mínima, escala máxima, peso]
const DISTRICTS := [
	{"name": "Distrito Noble", "centers": [Vector2(-200, -300), Vector2(-110, -240)], "density": "sparse",
		"tint": Color(0.82, 0.78, 0.74),
		"houses": [["buildings/Inn", 3.4, 3.8, 2], ["buildings/House_2", 3.6, 4.0, 2], ["buildings/Bell_Tower", 3.4, 3.8, 1]]},
	{"name": "Laderas de Kredik Shaw", "centers": [Vector2(-80, -420), Vector2(110, -360)], "density": "medium",
		"tint": Color(0.62, 0.6, 0.58),
		"houses": [["buildings/House_1", 2.7, 3.0, 3], ["buildings/House_3", 3.0, 3.3, 2], ["buildings/House_2", 2.7, 3.0, 2]]},
	{"name": "Distrito Mercantil", "centers": [Vector2(70, -165), Vector2(170, -140), Vector2(250, -200)], "density": "medium",
		"tint": Color(0.64, 0.6, 0.56),
		"houses": [["buildings/Inn", 2.6, 2.9, 2], ["buildings/House_2", 2.8, 3.1, 3], ["buildings/Blacksmith", 2.7, 3.0, 1], ["buildings/Bell_Tower", 3.0, 3.3, 1]]},
	{"name": "Viviendas de mercaderes", "centers": [Vector2(-150, -40), Vector2(-60, -170), Vector2(110, -30)], "density": "medium",
		"tint": Color(0.7, 0.66, 0.62),
		"houses": [["buildings/House_2", 2.8, 3.1, 3], ["buildings/House_1", 2.8, 3.1, 3], ["buildings/Inn", 2.7, 3.0, 1]]},
	{"name": "Plaza Central", "centers": [Vector2(0, 0)], "density": "medium",
		"tint": Color(0.62, 0.6, 0.58),
		"houses": [["buildings/Inn", 3.4, 3.8, 3], ["buildings/Bell_Tower", 3.4, 3.8, 1], ["buildings/House_2", 3.4, 3.8, 2]]},
	{"name": "Distrito de Forja", "centers": [Vector2(-270, 40), Vector2(-200, 90)], "density": "dense",
		"tint": Color(0.5, 0.47, 0.45),
		"houses": [["buildings/Blacksmith", 2.7, 3.0, 4], ["buildings/Sawmill", 2.4, 2.6, 1], ["buildings/House_3", 2.5, 2.9, 2]]},
	{"name": "Corrales de carbón", "centers": [Vector2(-280, 250)], "density": "medium",
		"tint": Color(0.42, 0.4, 0.39),
		"houses": [["buildings/Stable", 2.5, 2.8, 3], ["buildings/Blacksmith", 2.6, 2.9, 1]]},
	{"name": "Distrito Skaa", "centers": [Vector2(-100, 190), Vector2(-150, 330), Vector2(30, 230), Vector2(-90, 80), Vector2(-40, 380)],
		"density": "dense", "tint": Color(0.56, 0.53, 0.5),
		"houses": [["buildings/House_3", 2.5, 2.9, 5], ["buildings/House_1", 2.3, 2.7, 4], ["buildings/House_2", 2.3, 2.7, 2], ["buildings/Stable", 2.2, 2.5, 1]]},
	{"name": "Talleres y almacenes", "centers": [Vector2(190, 200), Vector2(220, 330), Vector2(90, 120)], "density": "dense",
		"tint": Color(0.6, 0.56, 0.52),
		"houses": [["buildings/Blacksmith", 2.7, 3.0, 3], ["buildings/Stable", 2.5, 2.8, 3], ["buildings/Sawmill", 2.4, 2.6, 1], ["buildings/House_3", 2.6, 3.0, 2]]},
	{"name": "Dársena", "centers": [Vector2(270, -90), Vector2(310, 100), Vector2(300, 220)], "density": "medium",
		"tint": Color(0.6, 0.57, 0.54),
		"houses": [["buildings/Stable", 2.6, 2.9, 3], ["buildings/House_2", 2.5, 2.8, 2], ["buildings/Sawmill", 2.4, 2.6, 1]]},
]

static var _segments: Array = []
static var _gates: Array = []
static var _wall_poly := PackedVector2Array(WALL)
static var _hash := {}  # Vector2i -> índices de _segments que pasan a menos de HASH_CELL m
const HASH_CELL := 40.0


static func district(p: Vector2) -> Dictionary:
	var best := INF
	var out: Dictionary = DISTRICTS[0]
	for d in DISTRICTS:
		for c: Vector2 in d["centers"]:
			var dist := p.distance_squared_to(c)
			if dist < best:
				best = dist
				out = d
	return out


## Calle que rodea la meseta de Kredik Shaw (un rectángulo de esquinas redondeadas), como
## polilínea cerrada.
static func hill_ring() -> Array:
	var out := []
	var a := HILL_HALF.x + HILL_RING
	var b := HILL_HALF.y + HILL_RING
	for i in 41:
		var t := TAU * i / 40.0
		var c := cos(t)
		var s := sin(t)
		out.append(HILL + Vector2(a * signf(c) * pow(absf(c), 0.4), b * signf(s) * pow(absf(s), 0.4)))
	return out


## ¿Cae p sobre la meseta de Kredik Shaw (o a menos de `margin` de ella)?
static func near_hill(p: Vector2, margin := 0.0) -> bool:
	var l := p - HILL
	if absf(l.x) < 14.0 + margin and l.y > 0.0 and l.y < HILL_SOUTH + margin:
		return true  # la rampa
	return absf(l.x) < HILL_HALF.x + margin and absf(l.y) < HILL_HALF.y + margin


## Callejones: red de nudos desplazados al azar (siempre la misma), solo donde hay casas skaa.
static func alleys() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var nx := int(BOUNDS.size.x / ALLEY_STEP) + 2
	var nz := int(BOUNDS.size.y / ALLEY_STEP) + 2
	var nodes := []
	for iz in nz:
		for ix in nx:
			var jitter := Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
			nodes.append(BOUNDS.position + Vector2(ix, iz) * ALLEY_STEP + jitter)
	var out := []
	for iz in nz:
		for ix in nx:
			var a: Vector2 = nodes[iz * nx + ix]
			for next in [[ix + 1, iz], [ix, iz + 1]]:
				if next[0] >= nx or next[1] >= nz:
					continue
				var b: Vector2 = nodes[next[1] * nx + next[0]]
				var keep := rng.randf()
				if _alley_ok(a) and _alley_ok(b) and _alley_ok((a + b) / 2.0):
					var density: String = district((a + b) / 2.0)["density"]
					if density == "dense" or (density == "medium" and keep < 0.6):
						out.append([a, b])
	return out


static func _alley_ok(p: Vector2) -> bool:
	if not inside(p, 10.0) or near_hill(p, 14.0):
		return false
	if absf(p.x) < PLAZA_HALF + 6.0 and absf(p.y) < PLAZA_HALF + 6.0:
		return false
	if dist_to_river(p) < RIVER_WIDTH / 2.0 + 5.0 or in_estate(p, 4.0) or in_port(p, 2.0):
		return false
	return p.distance_to(MARKET) > 48.0 and p.distance_to(ASSEMBLY) > ASSEMBLY_RADIUS + 16.0


## Polilíneas de calles principales (avenidas, calles y el anillo de la colina).
static func main_streets() -> Array:
	return AVENUES + STREETS + [hill_ring()]


## Todas las calles como segmentos [a, b, medio ancho] (se calculan una vez).
static func street_segments() -> Array:
	if _segments.is_empty():
		for line in main_streets():
			for i in line.size() - 1:
				_segments.append([line[i], line[i + 1], STREET_HALF])
		for s in alleys():
			_segments.append([s[0], s[1], ALLEY_HALF])
		for i in _segments.size():
			var a: Vector2 = _segments[i][0]
			var b: Vector2 = _segments[i][1]
			var lo := Vector2i(((a.min(b) - Vector2.ONE * HASH_CELL) / HASH_CELL).floor())
			var hi := Vector2i(((a.max(b) + Vector2.ONE * HASH_CELL) / HASH_CELL).floor())
			for cz in range(lo.y, hi.y + 1):
				for cx in range(lo.x, hi.x + 1):
					var key := Vector2i(cx, cz)
					if not _hash.has(key):
						_hash[key] = []
					_hash[key].append(i)
	return _segments


static func gates() -> Array:
	## [nombre, posición, dirección hacia fuera (normalizada), dirección a lo largo de la muralla]
	if not _gates.is_empty():
		return _gates
	var out := _gates
	for g in GATE_SPECS:
		var a: Vector2 = WALL[g[1]]
		var b: Vector2 = WALL[(g[1] + 1) % WALL.size()]
		var along := (b - a).normalized()
		var normal := Vector2(along.y, -along.x)
		if not inside(a.lerp(b, g[2]) - normal * 5.0):
			normal = -normal  # que apunte hacia fuera
		out.append([g[0], a.lerp(b, g[2]), normal, along])
	return out


## Tramos de las avenidas, para las farolas: [a, b].
static func avenues() -> Array:
	var out := []
	for line in AVENUES:
		for i in line.size() - 1:
			out.append([line[i], line[i + 1]])
	return out


static func inside(p: Vector2, margin := 0.0) -> bool:
	if not Geometry2D.is_point_in_polygon(p, _wall_poly):
		return false
	return margin <= 0.0 or dist_to_wall(p) >= margin


static func dist_to_wall(p: Vector2) -> float:
	var best := INF
	for i in WALL.size():
		best = minf(best, _dist_segment(p, WALL[i], WALL[(i + 1) % WALL.size()]))
	return best


static func dist_to_river(p: Vector2) -> float:
	var best := INF
	for i in RIVER.size() - 1:
		best = minf(best, _dist_segment(p, RIVER[i], RIVER[i + 1]))
	return best


## Punto más cercano de cualquier calle o callejón (para que las casas miren hacia ella).
static func nearest_street_point(p: Vector2) -> Vector2:
	var segs := street_segments()
	var near: Array = _hash.get(Vector2i((p / HASH_CELL).floor()), [])
	var best := INF
	var out := p
	for i in (near if not near.is_empty() else range(segs.size())):
		var a: Vector2 = segs[i][0]
		var ab: Vector2 = segs[i][1] - a
		var q: Vector2 = a + ab * clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if p.distance_to(q) < best:
			best = p.distance_to(q)
			out = q
	return out


## Hundimiento del terreno por el cauce del río (0 fuera, -RIVER_DEPTH en el centro).
static func river_bed(p: Vector2) -> float:
	var d := dist_to_river(p)
	var half := RIVER_WIDTH / 2.0
	if d >= half + 3.0:
		return 0.0
	if d <= half:
		return -RIVER_DEPTH
	return lerpf(-RIVER_DEPTH, 0.0, (d - half) / 3.0)  # orilla en pendiente


## Dentro de una mansión o un cuartel.
static func in_estate(p: Vector2, margin := 0.0) -> bool:
	for e in ESTATES + BARRACKS + [VENTURE]:
		var center: Vector2 = e[0]
		var local := (p - center).rotated(-float(e[3]))
		if absf(local.x) < e[1] / 2.0 + margin and absf(local.y) < e[2] / 2.0 + margin:
			return true
	return false


## Franja de la dársena: de la orilla a PORT_DEPTH m tierra adentro.
static func in_port(p: Vector2, margin := 0.0) -> bool:
	return _dist_segment(p, PORT_A, PORT_B) < PORT_DEPTH + margin


## ¿Hay sitio para una casa skaa aquí?
static func free_for_house(p: Vector2, radius: float) -> bool:
	if not inside(p, 8.0 + radius):
		return false
	if absf(p.x) < PLAZA_HALF + radius and absf(p.y) < PLAZA_HALF + radius:
		return false
	if p.distance_to(MARKET) < MARKET_RADIUS + radius or p.distance_to(ASSEMBLY) < ASSEMBLY_RADIUS + radius:
		return false
	if p.distance_to(MINISTRY) < 12.0 + radius or near_hill(p, radius):
		return false
	# Las calles las protege el mapa de ocupación de la ciudad; aquí solo el río.
	if dist_to_river(p) < RIVER_WIDTH / 2.0 + 4.0 + radius:
		return false
	if in_estate(p, radius + 2.0) or in_port(p, radius):
		return false
	for g in gates():
		if p.distance_to(g[1]) < 18.0 + radius:
			return false
	return true


## Puntos sobre las calles principales (para que aparezcan alománticos, por ejemplo).
static func street_points(step := 12.0) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for line in main_streets():
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var n := maxi(int(a.distance_to(b) / step), 1)
			for k in n:
				var p := a.lerp(b, float(k) / n)
				if inside(p, 10.0) and dist_to_river(p) > RIVER_WIDTH and not near_hill(p):
					out.append(p)
	return out


## Puentes donde una calle principal (o el camino que sale de una puerta) cruza el río:
## [centro, dirección de la calle].
static func bridges() -> Array:
	var lines := []
	for line in main_streets():
		for i in line.size() - 1:
			lines.append([line[i], line[i + 1]])
	for g in gates():
		lines.append([g[1], g[1] + g[2] * 120.0])
	var out := []
	for l in lines:
		var a: Vector2 = l[0]
		var b: Vector2 = l[1]
		for i in RIVER.size() - 1:
			var hit: Variant = Geometry2D.segment_intersects_segment(a, b, RIVER[i], RIVER[i + 1])
			if hit != null:
				out.append([hit, (b - a).normalized()])
	return out


static func _dist_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)
