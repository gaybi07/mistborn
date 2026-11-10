class_name SouthVillage
extends Node3D
## Aldeas del Camino Sur (Story.PLACES "camino_sur"): una aldea skaa a ambos lados del camino que sale de la Puerta Sur,
## a unos 300 m de la muralla. Chozas mirando al camino, una plaza con pozo y fogata, un molino, campos cercados con
## heno, corrales, y una torre de guardia del Ministerio en la entrada norte. La gente: cuadrillas skaa en los campos
## (SkaaCrews, ver crew_sites). Acá pasa la misión "aldea" del Acto 2 (koloss que bajan; evacuar o emboscar).
## shortcut: todo con piezas de Quaternius (no hay cultivos: los campos son heno y bolsas); modelos propios, si hacen
## falta, en un ticket aparte.

const CENTER := Vector2(-20, 715)
const RADIUS := 95.0  ## hasta dónde llega la aldea (ahí no van árboles ni lomas)
const KIT := 3.2
## El camino sur, como lo traza Exterior (semilla 4242): x del camino según z, entre estos puntos.
const ROAD := [Vector2(-9.79, 613.34), Vector2(-4.27, 793.88), Vector2(-21.12, 973.24)]
const ROAD_CLEAR := 9.0  ## nada a menos de esto del medio del camino
const PLAZA := Vector2(-42, 712)
const HOUSES := 22
const HOUSE_GAP := 12.0  ## separación mínima entre chozas
## Campos: [centro, medio tamaño].
const FIELDS := [[Vector2(-78, 660), Vector2(14, 10)], [Vector2(-80, 765), Vector2(16, 11)],
	[Vector2(42, 670), Vector2(15, 10)], [Vector2(46, 770), Vector2(13, 12)]]


## x del camino sur a esa altura (z).
static func road_x(z: float) -> float:
	for i in ROAD.size() - 1:
		var a: Vector2 = ROAD[i]
		var b: Vector2 = ROAD[i + 1]
		if z <= b.y or i == ROAD.size() - 2:
			return lerpf(a.x, b.x, clampf((z - a.y) / (b.y - a.y), 0.0, 1.0))
	return ROAD[0].x


static func covers(p: Vector2, margin := 0.0) -> bool:
	return p.distance_to(CENTER) < RADIUS + margin


## Puestos de cuadrillas skaa (SkaaCrews): trabajan en los campos y acarrean en la plaza.
static func crew_sites() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in FIELDS.size():
		var f: Array = FIELDS[i]
		for k in 2:
			var p: Vector2 = f[0] + Vector2((k * 2 - 1) * f[1].x * 0.4, 0)
			out.append({"pos": p, "dir": Vector2.RIGHT, "side": 1.0, "kind": "obra", "node": null})
	out.append({"pos": PLAZA + Vector2(6, 4), "dir": Vector2.UP, "side": 1.0, "kind": "carga", "node": null})
	return out


func _ready() -> void:
	var batch := ModelBatcher.new()
	batch.on_ground = true
	batch.draw_chunk = 64.0
	batch.draw_far = Art.DRAW_FAR
	add_child(batch)
	var r := RandomNumberGenerator.new()
	r.seed = 715
	# Chozas desparramadas: casi todas bajas (House_4, una planta), algunas de dos (House_3) y pocas grandes. Cada una a
	# su distancia del camino, separadas entre sí, mirando al camino o a la plaza (lo que tengan más cerca), torcidas.
	var placed: Array[Vector2] = []
	var tries := 0
	while placed.size() < HOUSES and tries < 2000:
		tries += 1
		var p := CENTER + Vector2(r.randf_range(-RADIUS, RADIUS), r.randf_range(-RADIUS, RADIUS)) * 0.9
		var off_road := absf(p.x - road_x(p.y))
		if p.distance_to(CENTER) > RADIUS * 0.9 or off_road < 13.0 or off_road > 60.0 or p.distance_to(PLAZA) < 14.0 or _in_field(p, 7.0):
			continue
		if placed.any(func(q: Vector2) -> bool: return q.distance_to(p) < HOUSE_GAP):
			continue
		placed.append(p)
		var road := Vector2(road_x(p.y), p.y)
		var look := PLAZA if p.distance_to(PLAZA) < off_road else road
		var to := look - p
		var roll := r.randf()
		var model := "buildings/House_4" if roll < 0.6 else ("buildings/House_3" if roll < 0.9 else "buildings/House_1")
		batch.add(ModelKit.path(model), Vector3(p.x, 0, p.y), atan2(to.x, to.y) + r.randf_range(-0.4, 0.4), KIT * r.randf_range(0.9, 1.05))
	# Plaza: pozo, fogata, caldero, bancos y un puesto.
	batch.add(ModelKit.path("props/Well"), Vector3(PLAZA.x, 0.8, PLAZA.y), 0.0, KIT)  # el pozo tiene el origen bajo el brocal
	_fire(batch, PLAZA + Vector2(7, -5))
	batch.add(ModelKit.path("props/Cauldron"), Vector3(PLAZA.x + 8.5, 0, PLAZA.y - 3.0), 0.0, KIT)
	for k in 3:
		var a := 0.6 + k * 1.9
		var b := PLAZA + Vector2.from_angle(a) * 6.5
		batch.add(ModelKit.path("props/Bench_1"), Vector3(b.x, 0, b.y), -a + PI / 2.0, KIT)
	batch.add(ModelKit.path("props/MarketStand_1"), Vector3(PLAZA.x - 9, 0, PLAZA.y + 6), 0.4, KIT)
	# Molino y establo con su corral, del lado este; herrería junto a la plaza.
	batch.add(ModelKit.path("buildings/Mill"), Vector3(70, 0, 735), -1.2, KIT)
	batch.add(ModelKit.path("buildings/Stable"), Vector3(-66, 0, 718), PI / 2.0, KIT)
	batch.add(ModelKit.path("buildings/Blacksmith"), Vector3(-50, 0, 690), 0.3, KIT)
	# Campos cercados con heno y bolsas.
	var fence := ModelKit.path("props/Fence")
	var flen := ModelKit.aabb(fence).size.x * KIT
	for f: Array in FIELDS:
		var c: Vector2 = f[0]
		var h: Vector2 = f[1]
		for edge: Array in [[Vector2(-h.x, -h.y), Vector2(h.x, -h.y)], [Vector2(h.x, -h.y), Vector2(h.x, h.y)],
				[Vector2(h.x, h.y), Vector2(-h.x, h.y)], [Vector2(-h.x, h.y), Vector2(-h.x, -h.y)]]:
			var a: Vector2 = c + edge[0]
			var b: Vector2 = c + edge[1]
			var n := maxi(1, roundi(a.distance_to(b) / flen))
			for i in n:
				if edge == [Vector2(-h.x, h.y), Vector2(-h.x, -h.y)] and i == n / 2:
					continue  # la tranquera
				var m := a.lerp(b, (i + 0.5) / n)
				batch.add(fence, Vector3(m.x, 0, m.y), -(b - a).angle(), KIT)
		for i in 6:
			var p := c + Vector2(r.randf_range(-h.x, h.x), r.randf_range(-h.y, h.y)) * 0.75
			batch.add(ModelKit.path("props/Hay" if i % 3 != 2 else "props/Bags"), Vector3(p.x, 0, p.y), r.randf() * TAU, KIT)
	# Carros y barriles por el camino; torre de guardia del Ministerio en la entrada norte.
	for i in 6:
		var zz := CENTER.y - 60.0 + i * 24.0
		var p := Vector2(road_x(zz) + (ROAD_CLEAR + 2.0) * (1.0 if i % 2 == 0 else -1.0), zz)
		batch.add(ModelKit.path(["props/Cart", "props/Barrel", "props/Crate"][i % 3]), Vector3(p.x, 0, p.y), r.randf() * TAU, KIT)
	var gate := Vector2(road_x(CENTER.y - 85.0) + 12.0, CENTER.y - 85.0)
	batch.add(ModelKit.path("castle/WatchTowerWRoof"), Vector3(gate.x, 0, gate.y), 0.0, KIT)
	_fire(batch, Vector2(road_x(CENTER.y + 40.0) - 14.0, CENTER.y + 40.0))
	batch.finalize()


func _in_field(p: Vector2, margin: float) -> bool:
	for f: Array in FIELDS:
		var d: Vector2 = (p - f[0]).abs() - f[1]
		if d.x < margin and d.y < margin:
			return true
	return false


func _fire(batch: ModelBatcher, p: Vector2) -> void:
	batch.add(ModelKit.path("props/Bonfire_Lit"), Vector3(p.x, 0, p.y), 0.0, KIT, Color.WHITE, false)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.omni_range = 14.0
	light.light_energy = 2.0
	light.position = Vector3(p.x, CityPlan.ground(p) + 1.5, p.y)
	light.distance_fade_enabled = true
	light.distance_fade_begin = Art.DRAW_FAR
	add_child(light)
