class_name SouthVillage
extends Node3D
## Aldeas del Camino Sur (Story.PLACES "camino_sur"): un pueblo grande (300 casas) sobre el camino que sale de la Puerta
## Sur, a unos 300 m de la muralla de Luthadel. Amurallado (piedra, torres, entradas donde pasan los caminos), con
## calles en cuadrícula, plaza de mercado con campanario, la mansión amurallada de un noble, arrabales afuera a lo largo
## de los caminos, y granjas alrededor: campos, corrales para el ganado con establos, molinos y un aserradero.
## La gente: cuadrillas skaa (SkaaCrews, ver crew_sites) y guardias en las puertas (GateForces.PEOPLE).
## Acá pasa la misión "aldea" del Acto 2 (koloss que bajan; evacuar o emboscar).
## Tamaños de pueblos (pedido de Gabi, 10/11): chico 50 casas, mediano 100, grande 300.
## shortcut: todo con piezas de Quaternius y sin animales (no hay modelos); los propios, en G23.

const CENTER := Vector2(-20, 715)
const WALL_R := 120.0  ## radio medio de la muralla (wall_r lo deforma)
const RADIUS := 215.0  ## hasta dónde llegan las granjas (ahí no van árboles ni lomas)
const HOUSES := 300
const KIT := 3.2
const STONE := Color(0.46, 0.44, 0.43)
const NOBLE := Color(0.9, 0.84, 0.8)
## El camino sur y su desvío al bosque, como los traza Exterior (semilla 4242).
const ROAD := [Vector2(-9.79, 613.34), Vector2(-4.27, 793.88), Vector2(-21.12, 973.24)]
const ROAD_IN := Vector2(-30.71, 431.99)  ## donde arranca, en la Puerta Sur
const BRANCH := [Vector2(-9.79, 613.34), Vector2(-294.9, 606.67)]
const PLAZA := Vector2(-40, 715)
const PLAZA_R := 20.0
const MANOR := Vector2(52, 668)  ## la mansión del noble
const MANOR_SIZE := Vector2(54, 46)
const SETBACK := 8.5  ## del medio de la calle al frente de la casa
const STEP := 9.0  ## entre casa y casa a lo largo de la calle
const BACK_ROW := 11.5  ## la fila de atrás, detrás del frente
const GAP := 8.0  ## separación mínima entre casas
## Calles de la cuadrícula, respecto del centro: x de las que van de norte a sur, z de las que van de este a oeste.
const STREETS_X := [-88.0, -62.0, 38.0, 82.0]
const STREETS_Z := [-80.0, -40.0, 0.0, 42.0, 84.0]
const OUTSIDE := 60  ## casas que quedan para los arrabales, afuera de la muralla


## Radio de la muralla en ese ángulo: no es un círculo perfecto.
static func wall_r(angle: float) -> float:
	return WALL_R * (1.0 + 0.06 * sin(2.0 * angle + 0.5) + 0.04 * sin(3.0 * angle + 1.7))


static func inside_wall(p: Vector2, margin := 0.0) -> bool:
	var l := p - CENTER
	return l.length() < wall_r(l.angle()) - margin


static func covers(p: Vector2, margin := 0.0) -> bool:
	return p.distance_to(CENTER) < RADIUS + margin


## x del camino sur a esa altura (z).
static func road_x(z: float) -> float:
	for i in ROAD.size() - 1:
		var a: Vector2 = ROAD[i]
		var b: Vector2 = ROAD[i + 1]
		if z <= b.y or i == ROAD.size() - 2:
			return lerpf(a.x, b.x, clampf((z - a.y) / (b.y - a.y), 0.0, 1.0))
	return ROAD[0].x


## Todas las calles, en tramos [a, b]: los caminos que cruzan el pueblo y la cuadrícula de adentro de la muralla.
static func streets() -> Array:
	var out := [[ROAD_IN, ROAD[0]], [ROAD[0], ROAD[1]], [ROAD[1], ROAD[2]], [BRANCH[0], BRANCH[1]]]
	var r := WALL_R * 0.9
	# Cada calle un poco corrida y torcida (siempre igual), para que la cuadrícula no quede perfecta.
	var i := 0
	for dx: float in STREETS_X:
		var h := sqrt(maxf(r * r - dx * dx, 0.0))
		var tilt := Vector2(0.06 * sin(i * 2.3), 0.0) * h
		var off := Vector2(4.0 * sin(i * 1.7), 0.0)
		out.append([CENTER + Vector2(dx, -h) + off - tilt, CENTER + Vector2(dx, h) + off + tilt])
		i += 1
	for dz: float in STREETS_Z:
		var h := sqrt(maxf(r * r - dz * dz, 0.0))
		var tilt := Vector2(0.0, 0.06 * sin(i * 2.3)) * h
		var off := Vector2(0.0, 4.0 * sin(i * 1.7))
		out.append([CENTER + Vector2(-h, dz) + off - tilt, CENTER + Vector2(h, dz) + off + tilt])
		i += 1
	return out


static func dist_to_streets(p: Vector2, list: Array) -> float:
	var best := INF
	for s: Array in list:
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, s[0], s[1]).distance_to(p))
	return best


static func _polar(angle: float, r: float) -> Vector2:
	return CENTER + Vector2.from_angle(angle) * r


## Granjas, afuera de la muralla: [centro, medio tamaño, giro]. Lejos de los caminos (al norte, al sur y al oeste).
static func fields() -> Array:
	return [[_polar(0.05, 165.0), Vector2(18, 12), 0.05], [_polar(0.55, 172.0), Vector2(16, 11), 0.55],
		[_polar(-0.5, 168.0), Vector2(17, 12), -0.5], [_polar(2.15, 170.0), Vector2(18, 11), 2.15],
		[_polar(2.75, 165.0), Vector2(15, 12), 2.75], [_polar(3.6, 185.0), Vector2(16, 10), 3.6]]


static func pens() -> Array:
	return [[_polar(0.95, 160.0), Vector2(10, 8), 0.95], [_polar(-0.95, 158.0), Vector2(10, 8), -0.95],
		[_polar(1.75, 165.0), Vector2(9, 8), 1.75], [_polar(3.15, 160.0), Vector2(10, 7), 3.15]]


## Puestos de cuadrillas skaa (SkaaCrews): en los campos, en los corrales y en el mercado.
static func crew_sites() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f: Array in fields():
		out.append({"pos": f[0] + Vector2.from_angle(f[2]) * f[1].x * 0.4, "dir": Vector2.from_angle(f[2]), "side": 1.0, "kind": "obra", "node": null})
	for p: Array in pens():
		out.append({"pos": p[0], "dir": Vector2.from_angle(p[2]), "side": 1.0, "kind": "carga", "node": null})
	out.append({"pos": PLAZA + Vector2(8, 6), "dir": Vector2.UP, "side": 1.0, "kind": "carga", "node": null})
	return out


var _batch: ModelBatcher
var _r := RandomNumberGenerator.new()
var _houses: Array[Vector2] = []


func _ready() -> void:
	_r.seed = 715
	_batch = ModelBatcher.new()
	_batch.on_ground = true
	_batch.draw_chunk = 64.0
	_batch.draw_far = Art.DRAW_FAR
	add_child(_batch)
	var list := streets()
	_paths(list)
	_wall()
	_manor()
	_plaza()
	# Casas a los dos lados de cada calle de adentro, mirando a la calle; después, los arrabales sobre los caminos.
	for s: Array in list.slice(4):
		_line_of_houses(s[0], s[1], list, true)
	for s: Array in list.slice(0, 4):
		_line_of_houses(s[0], s[1], list, true)
	_fill_blocks(list)
	for s: Array in list.slice(0, 4):
		_line_of_houses(s[0], s[1], list, false)
	_farms()
	_batch.finalize()


func _line_of_houses(a: Vector2, b: Vector2, list: Array, inside: bool) -> void:
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x)
	var d := STEP * 0.5
	while d < a.distance_to(b) and _houses.size() < HOUSES:
		for side: float in [1.0, -1.0]:
			var p := a + dir * d + n * side * (SETBACK + _r.randf_range(-0.8, 1.5))
			if _house_ok(p, list, inside):
				_house(p, a + dir * d)
			# Segunda fila, detrás: casas de callejón (mirando a la misma calle, corridas medio paso).
			var back := p + n * side * BACK_ROW + dir * STEP * 0.5
			if _house_ok(back, list, inside):
				_house(back, back - n * side * BACK_ROW)
		d += STEP + _r.randf_range(-1.5, 2.0)


## El centro de las manzanas: donde entre una casa más, mirando a la calle más cercana, hasta dejar OUTSIDE afuera.
func _fill_blocks(list: Array) -> void:
	for x in range(-int(WALL_R), int(WALL_R), 9):
		for z in range(-int(WALL_R), int(WALL_R), 9):
			if _houses.size() >= HOUSES - OUTSIDE:
				return
			var p := CENTER + Vector2(x, z) + Vector2(_r.randf_range(-2, 2), _r.randf_range(-2, 2))
			if not _house_ok(p, list, true):
				continue
			var near := p
			var best := INF
			for s: Array in list:
				var q := Geometry2D.get_closest_point_to_segment(p, s[0], s[1])
				if q.distance_to(p) < best:
					best = q.distance_to(p)
					near = q
			_house(p, near)


func _house_ok(p: Vector2, list: Array, inside: bool) -> bool:
	if _houses.size() >= HOUSES or inside != inside_wall(p, 9.0) or (not inside and (inside_wall(p, -10.0) or not covers(p, -5.0))):
		return false
	if p.distance_to(PLAZA) < PLAZA_R + 6.0 or _in_rect(p, MANOR, MANOR_SIZE / 2.0 + Vector2(6, 6), 0.0):
		return false
	if dist_to_streets(p, list) < SETBACK - 2.0 or CityPlan.dist_to_river(p) < CityPlan.RIVER_WIDTH + 6.0:
		return false
	return not _houses.any(func(q: Vector2) -> bool: return q.distance_to(p) < GAP)


func _house(p: Vector2, street: Vector2) -> void:
	_houses.append(p)
	var to := street - p
	var roll := _r.randf()
	var model := "buildings/House_1"
	if roll < 0.3:
		model = "buildings/House_2"
	elif roll < 0.5:
		model = "buildings/House_3"
	elif roll < 0.6:
		model = "buildings/House_4"
	elif roll < 0.64:
		model = "buildings/Blacksmith"
	elif roll < 0.67:
		model = "buildings/Inn"
	_batch.add(ModelKit.path(model), Vector3(p.x, 0, p.y), atan2(to.x, to.y) + _r.randf_range(-0.08, 0.08), KIT * _r.randf_range(0.92, 1.05))


## Muralla de piedra con torres; donde pasa un camino, una entrada flanqueada por dos torres.
func _wall() -> void:
	var wall := ModelKit.path("castle/Wall")
	var gate := ModelKit.path("castle/WallEntrance")
	var tower := ModelKit.path("castle/Tower")
	var s := 4.5
	var length := ModelKit.aabb(wall).size.x * s
	var roads := [[ROAD_IN, ROAD[0]], [ROAD[0], ROAD[1]], [ROAD[1], ROAD[2]], [BRANCH[0], BRANCH[1]]]
	var a := 0.0
	var k := 0
	while a < TAU:
		var r0 := wall_r(a)
		var step := length * 0.98 / r0
		var p0 := _polar(a, wall_r(a))
		var p1 := _polar(a + step, wall_r(a + step))
		var mid := (p0 + p1) / 2.0
		var yaw := -(p1 - p0).angle()
		var at_road := dist_to_streets(mid, roads) < length * 0.6
		_batch.add(gate if at_road else wall, Vector3(mid.x, 0, mid.y), yaw, s, STONE)
		if at_road:
			for q in [p0, p1]:
				_batch.add(tower, Vector3(q.x, 0, q.y), yaw, 3.5, STONE)
		elif k % 7 == 0:
			_batch.add(tower, Vector3(p0.x, 0, p0.y), yaw, 3.5, STONE)
		a += step
		k += 1


## La mansión del noble: muralla baja, torreones en las esquinas, puerta hacia el camino, casa señorial, torre del
## homenaje, glorieta y estandartes (como las mansiones de Luthadel, en main.gd).
func _manor() -> void:
	var c := MANOR
	var h := MANOR_SIZE / 2.0
	var wall := ModelKit.path("castle/Wall")
	var s := 3.5
	var piece := ModelKit.aabb(wall).size.x * s
	for side: float in [-1.0, 1.0]:
		var count := ceili(MANOR_SIZE.y / piece)
		for i in count:
			var z := -h.y + (i + 0.5) * MANOR_SIZE.y / count
			var is_gate: bool = side < 0.0 and absf(z) < piece * 0.6  # la puerta, hacia el oeste (el camino)
			_batch.add(ModelKit.path("castle/WallEntrance") if is_gate else wall, Vector3(c.x + side * h.x, 0, c.y + z), PI / 2.0, s, NOBLE)
		count = ceili(MANOR_SIZE.x / piece)
		for i in count:
			var x := -h.x + (i + 0.5) * MANOR_SIZE.x / count
			_batch.add(wall, Vector3(c.x + x, 0, c.y + side * h.y), 0.0, s, NOBLE)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_batch.add(ModelKit.path("castle/SmallSquareTower"), Vector3(c.x + sx * h.x, 0, c.y + sz * h.y), 0.0, 5.0, NOBLE)
	_batch.add(ModelKit.path("buildings/Inn"), Vector3(c.x + 8, 0, c.y), -PI / 2.0, 4.6, NOBLE)
	_batch.add(ModelKit.path("castle/LargeTower"), Vector3(c.x + 18, 0, c.y - 14), 0.0, 5.0, NOBLE)
	_batch.add(ModelKit.path("props/Gazebo"), Vector3(c.x - 12, 0, c.y + 12), 0.0, 3.0, NOBLE)
	for i in 4:
		_batch.add(ModelKit.path("props/Bench_2"), Vector3(c.x - 16 + i * 3.0, 0, c.y - 14), 0.0, KIT)
	var cloth := Props.material(Color(0.1, 0.16, 0.36), 0.0, 1.0)
	for sz: float in [-1.0, 1.0]:
		var banner := Props.static_box(Vector3(0.08, 4.5, 1.6), Vector3(c.x - h.x - 1.4, CityPlan.ground(c) + 6.0, c.y + sz * piece * 0.75), cloth)
		add_child(banner)


## Plaza de mercado: pozo, campanario, puestos en corro, fogata, caldero y bancos.
func _plaza() -> void:
	var p := PLAZA
	_batch.add(ModelKit.path("props/Well"), Vector3(p.x, 0.8, p.y), 0.0, KIT)  # el pozo tiene el origen bajo el brocal
	_batch.add(ModelKit.path("buildings/Bell_Tower"), Vector3(p.x - 14, 0, p.y - 12), 0.6, 3.6, STONE)
	for i in 9:
		var a := TAU * i / 9.0
		var q := p + Vector2.from_angle(a) * 13.0
		_batch.add(ModelKit.path("props/MarketStand_1" if i % 2 == 0 else "props/MarketStand_2"), Vector3(q.x, 0, q.y), -a - PI / 2.0, KIT)
	_fire(p + Vector2(6, 4))
	_batch.add(ModelKit.path("props/Cauldron"), Vector3(p.x + 7.5, 0, p.y + 6.5), 0.0, KIT)
	for i in 4:
		var q := p + Vector2.from_angle(0.4 + i * 1.5) * 6.5
		_batch.add(ModelKit.path("props/Bench_1"), Vector3(q.x, 0, q.y), -(0.4 + i * 1.5) + PI / 2.0, KIT)


## Granjas: campos con heno, corrales con establo, bebedero y heno, molinos y un aserradero junto al desvío.
func _farms() -> void:
	for f: Array in fields():
		_fenced(f[0], f[1], f[2], true)
		# Caserío de la granja: unas casas al lado del campo, hasta completar las del pueblo.
		for k in 4:
			var q: Vector2 = f[0] + Vector2(f[1].x + 10.0 + (k / 2) * 10.0, (k % 2 * 2 - 1) * 7.0).rotated(f[2])
			if _houses.size() < HOUSES and _house_ok(q, streets(), false):
				_house(q, f[0])
		for i in 8:
			var q: Vector2 = f[0] + Vector2(_r.randf_range(-f[1].x, f[1].x), _r.randf_range(-f[1].y, f[1].y)).rotated(f[2]) * 0.75
			_batch.add(ModelKit.path("props/Hay" if i % 4 != 3 else "props/Bags"), Vector3(q.x, 0, q.y), _r.randf() * TAU, KIT)
	for p: Array in pens():
		_fenced(p[0], p[1], p[2], true)
		var back: Vector2 = p[0] + Vector2.from_angle(p[2]) * (p[1].x + 9.0)
		_batch.add(ModelKit.path("buildings/Stable"), Vector3(back.x, 0, back.y), -p[2] + PI / 2.0, KIT)
		for i in 3:
			var q: Vector2 = p[0] + Vector2(_r.randf_range(-0.6, 0.6) * p[1].x, _r.randf_range(-0.6, 0.6) * p[1].y).rotated(p[2])
			_batch.add(ModelKit.path(["props/Hay", "props/Barrel", "props/Cauldron"][i]), Vector3(q.x, 0, q.y), _r.randf() * TAU, KIT)
		_house(p[0] - Vector2.from_angle(p[2]) * (p[1].x + 10.0), p[0])  # la casa del que cuida el ganado
	for a: float in [0.28, 2.5, -0.25]:
		var m := _polar(a, 200.0)
		_batch.add(ModelKit.path("buildings/Mill"), Vector3(m.x, 0, m.y), -a, KIT * 1.2)
	var saw: Vector2 = BRANCH[0].lerp(BRANCH[1], 0.45) + Vector2(0, -14)
	_batch.add(ModelKit.path("buildings/Sawmill"), Vector3(saw.x, 0, saw.y), 0.0, KIT)
	for i in 6:
		_batch.add(ModelKit.path("props/Cart" if i % 2 == 0 else "props/Crate"), Vector3(saw.x + 8 + i * 2.0, 0, saw.y + 3), _r.randf() * TAU, KIT)


func _fenced(c: Vector2, h: Vector2, yaw: float, with_gate: bool) -> void:
	var fence := ModelKit.path("props/Fence")
	var flen := ModelKit.aabb(fence).size.x * KIT
	var corners := [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]
	for e in 4:
		var a: Vector2 = c + (corners[e] as Vector2).rotated(yaw)
		var b: Vector2 = c + (corners[(e + 1) % 4] as Vector2).rotated(yaw)
		var n := maxi(1, roundi(a.distance_to(b) / flen))
		for i in n:
			if with_gate and e == 3 and i == n / 2:
				continue  # la tranquera
			var m := a.lerp(b, (i + 0.5) / n)
			_batch.add(fence, Vector3(m.x, 0, m.y), -(b - a).angle(), KIT)


static func _in_rect(p: Vector2, c: Vector2, h: Vector2, yaw: float) -> bool:
	var l := (p - c).rotated(-yaw)
	return absf(l.x) < h.x and absf(l.y) < h.y


## Calles de tierra: una tira que sigue el suelo por cada calle de adentro (los caminos ya los dibuja Exterior).
func _paths(list: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s: Array in list.slice(4):
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var dir := (b - a).normalized()
		var n := Vector2(-dir.y, dir.x) * 3.0
		var count := ceili(a.distance_to(b) / 4.0)
		for i in count:
			var p := a.lerp(b, float(i) / count)
			var q := a.lerp(b, float(i + 1) / count)
			var v := [p + n, p - n, q - n, q + n].map(func(x: Vector2) -> Vector3: return Vector3(x.x, CityPlan.ground(x) + 0.06, x.y))
			for idx in [0, 1, 2, 0, 2, 3, 2, 1, 0, 3, 2, 0]:  # de las dos caras
				st.set_normal(Vector3.UP)
				st.add_vertex(v[idx])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = WorldKit.materials()["road"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _fire(p: Vector2) -> void:
	_batch.add(ModelKit.path("props/Bonfire_Lit"), Vector3(p.x, 0, p.y), 0.0, KIT, Color.WHITE, false)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.omni_range = 14.0
	light.light_energy = 2.0
	light.position = Vector3(p.x, CityPlan.ground(p) + 1.5, p.y)
	light.distance_fade_enabled = true
	light.distance_fade_begin = Art.DRAW_FAR
	add_child(light)
