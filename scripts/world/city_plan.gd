class_name CityPlan
## Plano de Luthadel (datos y consultas geométricas), según el mapa de referencia:
## muralla irregular más ancha de este a oeste, cuatro puertas (la entrada principal al oeste),
## Kredik Shaw sobre una colina al noreste, el río Kredres por el sur con un puerto, tres plazas
## y mansiones nobles repartidas entre los barrios skaa.
## Coordenadas en el plano XZ (Vector2(x, z)); el norte es -z.

## Vértices de la muralla, en orden.
const WALL := [
	Vector2(-150, -72), Vector2(-96, -122), Vector2(-12, -134), Vector2(92, -128), Vector2(160, -80),
	Vector2(182, 8), Vector2(162, 88), Vector2(92, 128), Vector2(-18, 138), Vector2(-112, 118),
	Vector2(-166, 52), Vector2(-178, -12),
]
## Puertas: [nombre, índice del tramo de muralla, posición a lo largo del tramo (0..1)]
const GATE_SPECS := [["Puerta del Norte", 1, 0.6], ["Puerta del Este", 5, 0.1],
		["Puerta del Sur", 7, 0.55], ["Entrada principal (oeste)", 10, 0.55]]
const GATE_WIDTH := 10.0

## Río Kredres (polilínea) y su anchura.
const RIVER := [
	Vector2(-360, 30), Vector2(-220, 62), Vector2(-150, 92), Vector2(-80, 108), Vector2(-10, 112),
	Vector2(55, 109), Vector2(100, 112), Vector2(150, 135), Vector2(230, 170), Vector2(380, 205),
]
const RIVER_WIDTH := 18.0
const RIVER_DEPTH := 3.0
const WATER_LEVEL := -1.0

## Colina de Kredik Shaw.
const HILL := Vector2(80, -82)
const HILL_RADIUS := 56.0
const HILL_HEIGHT := 30.0
const HILL_TOP := 20.0  ## altura de la meseta donde se alza el palacio

## Plazas: [centro, radio]. La del centro es cuadrada (ver PLAZA_HALF).
const PLAZA_HALF := 40.0
const MARKET := Vector2(80, 26)
const MARKET_RADIUS := 19.0
const ASSEMBLY := Vector2(-60, -40)
const ASSEMBLY_RADIUS := 18.0
const MINISTRY := Vector2(32, -46)

## Mansiones nobles: [centro, ancho, fondo, ángulo, casa]
const ESTATES := [
	[Vector2(-110, -76), 34.0, 26.0, 0.35, 0],
	[Vector2(-66, -100), 26.0, 20.0, 0.12, 1],
	[Vector2(150, -30), 24.0, 30.0, -0.2, 2],
	[Vector2(-122, 42), 30.0, 22.0, -0.1, 3],
	[Vector2(118, 62), 26.0, 22.0, 0.3, 0],
]
## Puerto: rectángulo en la orilla norte del río (min, max).
const PORT_MIN := Vector2(-38, 82)
const PORT_MAX := Vector2(48, 100)

## Calles en anillo alrededor del centro (radios).
const RINGS := [58.0, 102.0]
const STREET_HALF := 4.0
## Callejones: anillos estrechos y radios cada 18° (salvo donde ya hay avenida).
const ALLEY_RINGS := [80.0, 128.0]
const ALLEY_HALF := 2.2
const SPOKE_STEP_DEG := 18.0

## Barrios por sector (ángulo en grados con 0 = este, 90 = sur, 180 = oeste, 270 = norte).
## density: "dense" (casas en hilera en todas las calles y relleno apretado), "medium", "sparse".
## houses: [modelo, escala mínima, escala máxima, peso]
const DISTRICTS := [
	{"name": "Edificios gubernamentales y templos", "from": 330.0, "to": 30.0, "density": "sparse",
		"tint": Color(0.62, 0.6, 0.58),
		"houses": [["buildings/Inn", 4.2, 4.8, 3], ["buildings/Bell_Tower", 3.8, 4.4, 2], ["buildings/House_2", 3.8, 4.2, 1]]},
	{"name": "Barrio de los Tejedores", "from": 30.0, "to": 75.0, "density": "dense",
		"tint": Color(0.64, 0.6, 0.56),
		"houses": [["buildings/House_1", 2.4, 2.8, 3], ["buildings/House_2", 2.3, 2.7, 3], ["buildings/House_3", 2.7, 3.1, 2], ["buildings/Sawmill", 2.4, 2.6, 1]]},
	{"name": "Mercados y Talleres", "from": 75.0, "to": 110.0, "density": "medium",
		"tint": Color(0.62, 0.58, 0.54),
		"houses": [["buildings/Blacksmith", 2.7, 3.0, 3], ["buildings/Stable", 2.5, 2.8, 2], ["buildings/Inn", 2.5, 2.8, 1], ["buildings/House_2", 2.6, 2.9, 2]]},
	{"name": "Barrio Dormaroe", "from": 110.0, "to": 150.0, "density": "dense",
		"tint": Color(0.5, 0.48, 0.46),
		"houses": [["buildings/House_3", 2.5, 2.9, 5], ["buildings/House_1", 2.3, 2.6, 2], ["buildings/Stable", 2.2, 2.5, 1]]},
	{"name": "Barrio del Pozo", "from": 150.0, "to": 205.0, "density": "dense",
		"tint": Color(0.58, 0.55, 0.52),
		"houses": [["buildings/House_1", 2.4, 2.8, 4], ["buildings/House_3", 2.7, 3.1, 3], ["buildings/House_2", 2.4, 2.7, 2]]},
	{"name": "Casas nobles", "from": 205.0, "to": 250.0, "density": "sparse",
		"tint": Color(0.82, 0.78, 0.74),
		"houses": [["buildings/Inn", 3.4, 3.8, 2], ["buildings/House_2", 3.6, 4.0, 2], ["buildings/Bell_Tower", 3.4, 3.8, 1]]},
	{"name": "Barrio Alto", "from": 250.0, "to": 290.0, "density": "medium",
		"tint": Color(0.7, 0.66, 0.62),
		"houses": [["buildings/House_2", 2.8, 3.1, 3], ["buildings/House_1", 2.8, 3.1, 3], ["buildings/Inn", 2.7, 3.0, 1]]},
	{"name": "Ladera de Kredik", "from": 290.0, "to": 330.0, "density": "medium",
		"tint": Color(0.62, 0.6, 0.58),
		"houses": [["buildings/House_1", 2.7, 3.0, 3], ["buildings/House_3", 3.0, 3.3, 2], ["buildings/House_2", 2.7, 3.0, 2]]},
]


static func district(p: Vector2) -> Dictionary:
	var deg := fposmod(rad_to_deg(atan2(p.y, p.x)), 360.0)
	for d in DISTRICTS:
		var from: float = d["from"]
		var to: float = d["to"]
		if (from < to and deg >= from and deg < to) or (from > to and (deg >= from or deg < to)):
			return d
	return DISTRICTS[0]


## Callejones radiales: [inicio, fin] desde el primer anillo hasta más allá de la muralla.
static func spokes() -> Array:
	var avenue_angles := []
	for g in gates():
		avenue_angles.append(rad_to_deg((g[1] as Vector2).angle()))
	var out := []
	var deg := SPOKE_STEP_DEG / 2.0
	while deg < 360.0:
		var near_avenue := avenue_angles.any(func(a): return absf(angle_difference(deg_to_rad(deg), deg_to_rad(a))) < deg_to_rad(8.0))
		if not near_avenue:
			var dir := Vector2.from_angle(deg_to_rad(deg))
			out.append([dir * RINGS[0], dir * 240.0])
		deg += SPOKE_STEP_DEG
	return out


## Todas las calles para trazarlas: segmentos [a, b, medio ancho] y anillos [radio, medio ancho].
static func street_segments() -> Array:
	var out := []
	for av in avenues():
		out.append([av[0], av[1], STREET_HALF])
	for s in spokes():
		out.append([s[0], s[1], ALLEY_HALF])
	return out


static func street_rings() -> Array:
	var out := []
	for r in RINGS:
		out.append([r, STREET_HALF])
	for r in ALLEY_RINGS:
		out.append([r, ALLEY_HALF])
	return out


static func gates() -> Array:
	## [nombre, posición, dirección hacia fuera (normalizada), dirección a lo largo de la muralla]
	var out := []
	for g in GATE_SPECS:
		var a: Vector2 = WALL[g[1]]
		var b: Vector2 = WALL[(g[1] + 1) % WALL.size()]
		var along := (b - a).normalized()
		var normal := Vector2(along.y, -along.x)
		if normal.dot(a.lerp(b, g[2])) < 0.0:
			normal = -normal  # que apunte hacia fuera (lejos del centro)
		out.append([g[0], a.lerp(b, g[2]), normal, along])
	return out


## Calles principales: del centro a cada puerta.
static func avenues() -> Array:
	var out := []
	for g in gates():
		out.append([Vector2.ZERO, g[1]])
	return out


static func inside(p: Vector2, margin := 0.0) -> bool:
	if not Geometry2D.is_point_in_polygon(p, PackedVector2Array(WALL)):
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


## Distancia a la calle más cercana (avenidas y anillos).
static func dist_to_streets(p: Vector2) -> float:
	var best := INF
	for av in avenues():
		best = minf(best, _dist_segment(p, av[0], av[1]))
	for r in RINGS:
		best = minf(best, absf(p.length() - r))
	return best


## Dirección de la calle más cercana (para orientar las casas hacia ella).
static func street_direction(p: Vector2) -> Vector2:
	var best := INF
	var dir := Vector2.RIGHT
	for av in avenues():
		var d := _dist_segment(p, av[0], av[1])
		if d < best:
			best = d
			dir = (av[1] - av[0]).normalized()
	for r in RINGS:
		var d := absf(p.length() - r)
		if d < best and p.length() > 0.1:
			best = d
			dir = Vector2(-p.y, p.x).normalized()  # tangente al anillo
	return dir


## Punto más cercano de cualquier calle o callejón (para que las casas miren hacia ella).
static func nearest_street_point(p: Vector2) -> Vector2:
	var best := INF
	var out := p
	for s in street_segments():
		var a: Vector2 = s[0]
		var ab: Vector2 = s[1] - a
		var q: Vector2 = a + ab * clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if p.distance_to(q) < best:
			best = p.distance_to(q)
			out = q
	for ring in street_rings():
		if p.length() > 0.1:
			var q: Vector2 = p.normalized() * float(ring[0])
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


static func in_estate(p: Vector2, margin := 0.0) -> bool:
	for e in ESTATES:
		var center: Vector2 = e[0]
		var local := (p - center).rotated(-float(e[3]))
		if absf(local.x) < e[1] / 2.0 + margin and absf(local.y) < e[2] / 2.0 + margin:
			return true
	return false


static func in_port(p: Vector2, margin := 0.0) -> bool:
	return p.x > PORT_MIN.x - margin and p.x < PORT_MAX.x + margin \
			and p.y > PORT_MIN.y - margin and p.y < PORT_MAX.y + margin


## ¿Hay sitio para una casa skaa aquí?
static func free_for_house(p: Vector2, radius: float) -> bool:
	if not inside(p, 8.0 + radius):
		return false
	if absf(p.x) < PLAZA_HALF + radius and absf(p.y) < PLAZA_HALF + radius:
		return false
	if p.distance_to(MARKET) < MARKET_RADIUS + radius or p.distance_to(ASSEMBLY) < ASSEMBLY_RADIUS + radius:
		return false
	if p.distance_to(MINISTRY) < 12.0 + radius or p.distance_to(HILL) < HILL_RADIUS + radius:
		return false
	# Las calles las protege el mapa de ocupación de la ciudad; aquí solo el río.
	if dist_to_river(p) < RIVER_WIDTH / 2.0 + 4.0 + radius:
		return false
	if in_estate(p, radius + 2.0) or in_port(p, radius):
		return false
	for g in gates():
		if p.distance_to(g[1]) < 16.0 + radius:
			return false
	return true


## Puntos sobre las calles (para que aparezcan alománticos, por ejemplo).
static func street_points(step := 12.0) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for av in avenues():
		var a: Vector2 = av[0]
		var b: Vector2 = av[1]
		var n := int(a.distance_to(b) / step)
		for i in n:
			out.append(a.lerp(b, float(i) / n))
	for r in RINGS:
		var n := int(TAU * r / step)
		for i in n:
			var p: Vector2 = Vector2(cos(TAU * i / n), sin(TAU * i / n)) * r
			if inside(p, 10.0) and dist_to_river(p) > RIVER_WIDTH and p.distance_to(HILL) > HILL_RADIUS:
				out.append(p)
	return out


## ¿Cruza una calle el río aquí? Devuelve los puntos de cruce de las avenidas con el río.
static func bridges() -> Array:
	var out := []  # [centro, dirección de la calle]
	for av in avenues():
		var a: Vector2 = av[0]
		var b: Vector2 = av[1]
		for i in RIVER.size() - 1:
			var hit: Variant = Geometry2D.segment_intersects_segment(a, b, RIVER[i], RIVER[i + 1])
			if hit != null:
				out.append([hit, (b - a).normalized()])
	return out


static func _dist_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)
