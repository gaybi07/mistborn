class_name KredikLevel
extends Node3D
## Un nivel interior de Kredik Shaw armado a partir de los planos (KredikPlan).
## La planta se pinta en una cuadrícula de 1 m (cada celda: un espacio, muro macizo, roca o nada).
## De ahí sale todo:
##  - Muros donde cambian los espacios, con puertas (arco apuntado) entre salas y pasillos y
##    ventanas ojivales hacia los patios y el exterior; zócalo, cornisa y, en los salones, pilastras
##    y estandartes.
##  - Suelos de losas, techos con nervaduras, muros macizos, torres redondas y roca.
##  - Mobiliario según el uso de cada sala (escritorios, archivos, literas, armerías, el trono...),
##    lámparas de hierro (anclas para acero/hierro) y luz cálida de antorchas.
##  - Escaleras de ida y vuelta al nivel de arriba (KredikPlan.flights) y túneles de salida a la
##    ciudad en los subniveles.
## Los niveles se apilan en la ciudad (KredikInterior): los de arriba solo conservan lo que se apoya
## en un techo del de abajo (los patios quedan a cielo abierto) y encima de las salas de doble altura
## de la planta baja queda un hueco (HOLE).
## Todo va a dos mallas (sólida con colisión y decorativa sin ella) que se guardan la primera vez.

const X0 := -106.0
const Z0 := -59.0
const NX := 212
const NZ := 118
const VOID := -1
const SOLID := -2
const ROCK := -3
const ROUND := -4  ## torre o bastión redondo (se dibuja como cilindro)
const HOLE := -5  ## encima de una sala de doble altura: sin suelo ni muros (los pone la sala)
const ROOM_H := KredikPlan.LH - 0.8  ## alto máximo de una sala (cabe la losa del nivel de arriba)
## Escaleras: rellano de abajo y de media vuelta (m) y ancho máximo de los dos tramos juntos.
const STAIR_LAND := 1.8
const STAIR_MID := 2.0
const STAIR_BAND := 4.4
## Túneles de salida (subniveles): alto libre y pendiente de la rampa del Subnivel 3.
const TUNNEL_H := 4.5
const TUNNEL_SLOPE := 30.0

const SOLID_KEYS := ["ks_wall", "ks_trim", "ks_floor", "ks_court", "ks_ceil", "ks_marble", "wood", "iron",
		"gold", "rock", "red", "cloth", "paper"]

static var _cache := {}

var level := "ground"

var _rooms: Array = []
var _grid := PackedInt32Array()
var _rounds: Array = []  # [centro (m), radio]
var _runs: Array = []
var _mb := MeshBuilder.new()  # con colisión
var _deco := MeshBuilder.new()  # sin colisión: cristal, fuego, agua, plantas, telas colgadas
var _rng := RandomNumberGenerator.new()
var _lights: Array = []  # [pos, color, range, energy]
var _anchors: Array = []
var _braziers: Array = []
var _props := {}  # modelos de Poly Haven: nombre -> [Transform3D] (ver PolyProps)
var _solid_h := KredikPlan.LH
var _skip_ceil: Array[Rect2] = []  # sin techo (la escalera sube por ahí)
var _skip_floor: Array[Rect2] = []  # sin suelo (el hueco de la escalera de abajo)
## Colisión de las rampas (escaleras, túneles): cajas simples [Transform3D, tamaño], como las de la
## mansión Venture; con la malla, el jugador se traba en las aristas donde empalman con el suelo.
var _ramps: Array = []


# ------------------------------------------------------------------ Escaleras

## Escalera de ida y vuelta en un rectángulo: a lo largo del lado largo, rellano de abajo en el
## extremo norte/oeste (start), dos tramos en una franja central (band) con pasillos a los lados y
## el rellano de media vuelta al otro extremo. hole: el hueco en el suelo del nivel de arriba.
static func stair_frame(r: Rect2) -> Dictionary:
	var along_x := r.size.x >= r.size.y
	var axis := Vector2(1, 0) if along_x else Vector2(0, 1)
	var side := Vector2(0, 1) if along_x else Vector2(1, 0)
	var length := r.size.x if along_x else r.size.y
	var width := r.size.y if along_x else r.size.x
	var start := r.position + side * width / 2.0
	var band := minf(width - 2.4, STAIR_BAND)
	var a := start + axis * STAIR_LAND - side * band / 2.0
	var b := start + axis * length + side * band / 2.0
	return {"start": start, "axis": axis, "side": side, "len": length, "band": band,
			"hole": Rect2(a.min(b), (b - a).abs())}


## Celda de la cuadrícula en un punto (en metros, relativo al centro de la fortaleza).
static func cell_at(grid: PackedInt32Array, p: Vector2) -> int:
	var i := int(floorf(p.x - X0))
	var j := int(floorf(p.y - Z0))
	if grid.is_empty() or i < 0 or j < 0 or i >= NX or j >= NZ:
		return VOID
	return grid[j * NX + i]


## Dónde sale cada túnel de los subniveles: [nivel, z0, z1, x del borde de la cuadrícula,
## x de la boca]. La boca está donde el tajo del cordón de picos (KredikCitadel.ground) baja a la
## ciudad; el túnel del Subnivel 3 sube en rampa hasta la altura de la ciudad.
static func tunnels() -> Array:
	var out := []
	for spec: Array in [["sub1", "Salida de emergencia"], ["sub3", "Salida de la cueva"]]:
		for s: Array in KredikPlan.spaces(spec[0]):
			if s[0] == spec[1]:
				var r := KredikPlan.rect(s[2])
				out.append([spec[0], r.position.y, r.end.y, X0, KredikCitadel.cut_x()])
	return out


# ------------------------------------------------------------------ Escena

func _ready() -> void:
	if not _cache.has(level):
		if level == "tower":
			_build_tower()
		else:
			_build()
		var solid := _mb.commit(SOLID_KEYS)
		_cache[level] = {"mesh": solid, "shape": ModelKit.solid_trimesh(solid), "deco": _deco.commit(),
				"lights": _lights, "anchors": _anchors, "braziers": _braziers,
				"rooms": _rooms, "grid": _grid, "props": _props, "ramps": _ramps}
	var c: Dictionary = _cache[level]
	_rooms = c["rooms"]
	_grid = c["grid"]
	var mats := materials()
	var body := StaticBody3D.new()
	body.collision_layer = Props.LAYER_WORLD
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	col.shape = c["shape"]
	body.add_child(col)
	for r: Array in c["ramps"]:
		var ramp := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = r[1]
		ramp.shape = box
		ramp.transform = r[0]
		body.add_child(ramp)
	var dark := level.begins_with("sub")
	var solid := _instance(c["mesh"], mats)
	# Bajo tierra no hay sol que proyecte sombras; las molduras y telas tampoco hacen falta.
	if dark:
		solid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(solid)
	add_child(body)
	var deco := _instance(c["deco"], mats)
	deco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	deco.visibility_range_end = Art.DRAW_FAR  # molduras, telas y vidrios
	add_child(deco)
	for l: Array in c["lights"]:
		var light := OmniLight3D.new()
		light.position = l[0]
		light.light_color = l[1]
		light.omni_range = l[2] * 1.25  # más luz que antes: las salas se veían muy oscuras
		light.light_energy = l[3] * 1.5
		light.light_volumetric_fog_energy = 0.6 if dark else 1.2
		light.distance_fade_enabled = true
		light.distance_fade_begin = 38.0
		light.distance_fade_length = 14.0
		add_child(light)
	for a: Vector3 in c["anchors"]:
		var anchor := Node3D.new()
		anchor.position = a
		anchor.add_to_group(&"metal")
		add_child(anchor)
	PolyProps.spawn(self, c["props"], 32.0, Art.DRAW_FAR)
	for p: Vector3 in c["braziers"]:
		var b := Brazier.new()
		b.position = p
		add_child(b)


## Lo que se guardó de un nivel ya armado (grid, rooms...) o {} si todavía no se armó.
static func cached(lvl: String) -> Dictionary:
	return _cache.get(lvl, {})


func _instance(mesh: ArrayMesh, mats: Dictionary) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	for s in mesh.get_surface_count():
		mi.set_surface_override_material(s, mats[mesh.surface_get_name(s)])
	return mi


## Materiales del interior: piedra volcánica oscura, losas pulidas, mármol negro, hierro y oro.
static func materials() -> Dictionary:
	var m := WorldKit.materials()
	if m.has("ks_wall"):
		return m
	m["ks_wall"] = WorldKit.pbr("castle_brick_07", Color(0.75, 0.72, 0.76), 3.0)
	var floor_mat := WorldKit.pbr("large_floor_tiles_02", Color(0.55, 0.53, 0.56), 4.0)
	# Relieve por parallax de cerca: juntas de los ladrillos y de las losas.
	(m["ks_wall"] as ShaderMaterial).set_shader_parameter(&"parallax_depth", 0.08)
	floor_mat.set_shader_parameter(&"parallax_depth", 0.04)
	m["ks_floor"] = floor_mat
	var court: ShaderMaterial = (m["ground"] as ShaderMaterial).duplicate()
	m["ks_court"] = court
	m["ks_trim"] = Props.material(Color(0.12, 0.115, 0.13), 0.05, 0.6)
	m["ks_ceil"] = Props.material(Color(0.07, 0.068, 0.078), 0.0, 0.9)
	m["ks_marble"] = Props.material(Color(0.045, 0.043, 0.052), 0.15, 0.2)
	m["gold"] = Props.material(Color(0.78, 0.56, 0.24), 1.0, 0.3)
	m["red"] = Props.material(Color(0.36, 0.05, 0.04), 0.0, 0.95)
	m["cloth"] = Props.material(Color(0.16, 0.12, 0.1), 0.0, 1.0)
	m["paper"] = Props.material(Color(0.62, 0.56, 0.44), 0.0, 1.0)
	m["plant"] = Props.material(Color(0.07, 0.1, 0.06), 0.0, 1.0)
	m["rock"] = m["citadel_rock"]
	var glass := Props.material(Color(0.1, 0.13, 0.2), 0.0, 0.08)
	glass.emission_enabled = true
	glass.emission = Color(0.32, 0.42, 0.7)
	glass.emission_energy_multiplier = 0.7
	m["ks_glass"] = glass
	var fire := Props.material(Color(0.3, 0.12, 0.03), 0.0, 1.0)
	fire.emission_enabled = true
	fire.emission = Color(1.0, 0.55, 0.2)
	fire.emission_energy_multiplier = 5.0
	m["fire"] = fire
	return m


# ------------------------------------------------------------------ Planta

func _build() -> void:
	_rng.seed = hash(level)
	_grid.resize(NX * NZ)
	_grid.fill(VOID)
	for spec: Array in KredikPlan.spaces(level):
		_paint(spec)
	if KredikPlan.BELOW.has(level):
		_prune(KredikLevel.cached(KredikPlan.BELOW[level]))
	for f: Array in KredikPlan.flights():
		var rect := KredikPlan.rect(f[2])
		if f[0] == level:
			_skip_ceil.append(rect.grow(0.5))
		elif f[1] == level:
			_skip_floor.append(rect)
	_measure_rooms()
	_collect_runs()
	_place_doors()
	_place_windows()
	_floors_and_ceilings()
	_masses()
	for run: Dictionary in _runs:
		_wall(run)
	for i in _rooms.size():
		var r: Dictionary = _rooms[i]
		if r["cells"] == 0:
			continue
		if r["circle"]:
			_ring(i)
		_furnish(i)
		_light(i)
	_flights()
	for t: Array in tunnels():
		if t[0] == level:
			_tunnel(t[1], t[2], t[3], t[4], KredikPlan.FLOOR["sub1"] - KredikPlan.FLOOR[level])
	if level == "sub3":
		var cave := KredikPlan.rect([110, 330, 205, 420])  # sin tapar la salida
		for k in 14:
			var q := Vector2(_rng.randf_range(cave.position.x, cave.end.x), cave.position.y + (_rng.randf_range(0.0, 3.0) if k % 2 == 0 else cave.size.y - _rng.randf_range(0.0, 3.0)))
			_poly("boulder_01", Vector3(q.x, -0.3, q.y), _rng.randf() * TAU, _rng.randf_range(1.5, 3.0))


## Niveles de arriba: lo que no se apoya en un techo del nivel de abajo (patios, terrazas, vacío)
## desaparece; encima de las salas de doble altura queda HOLE; los muros macizos sin salas al lado
## y los restos de salas recortadas también se van.
func _prune(below: Dictionary) -> void:
	var bg: PackedInt32Array = below["grid"]
	var brooms: Array = below["rooms"]
	for idx in _grid.size():
		var b := bg[idx]
		if b >= 0 and brooms[b].get("double", false):
			_grid[idx] = HOLE
			continue
		var held: bool = b == SOLID or b == ROUND or b == HOLE or (b >= 0 and not brooms[b]["open"])
		if not held:
			_grid[idx] = VOID
	var kept: Array = []
	for t: Array in _rounds:
		if cell_at(bg, t[0]) == ROUND:
			kept.append(t)
	_rounds = kept
	var walls := []
	for j in NZ:
		for i in NX:
			var id := _grid[j * NX + i]
			if id != SOLID and id != ROUND:
				continue
			var near := false
			for dj in range(-2, 3):
				for di in range(-2, 3):
					var ii := i + di
					var jj := j + dj
					if ii >= 0 and jj >= 0 and ii < NX and jj < NZ and (_grid[jj * NX + ii] >= 0 or _grid[jj * NX + ii] == HOLE):
						near = true
			if not near:
				walls.append(j * NX + i)
	for idx: int in walls:
		_grid[idx] = VOID
	var counts := {}
	for id in _grid:
		if id >= 0:
			counts[id] = counts.get(id, 0) + 1
	for idx in _grid.size():
		var id := _grid[idx]
		if id >= 0 and counts[id] < 12:
			_grid[idx] = VOID


func _paint(spec: Array) -> void:
	var kind: String = spec[1]
	var geo: Array = spec[2]
	var circle := geo.size() == 3
	var c := KredikPlan.m(Vector2(geo[0], geo[1])) if circle else Vector2.ZERO
	var radius: float = geo[2] * KredikPlan.PX if circle else 0.0
	var r := Rect2(c - Vector2(radius, radius), Vector2(radius, radius) * 2.0) if circle else KredikPlan.rect(geo)
	var ids: Array = []
	if kind == "solid":
		if circle:
			_rounds.append([c, radius])
		ids = [ROUND if circle else SOLID]
	elif kind == "rock":
		ids = [ROCK]
	elif kind == "void":
		ids = [VOID]
	elif kind == "cells_x" or kind == "cells_y":
		var along_x := kind == "cells_x"
		var length := r.size.x if along_x else r.size.y
		var n := maxi(1, roundi(length / 4.5))
		for k in n:
			var sub := Rect2(r.position + (Vector2(length / n * k, 0) if along_x else Vector2(0, length / n * k)),
					Vector2(length / n, r.size.y) if along_x else Vector2(r.size.x, length / n))
			ids.append(_add_room("%s %d" % [spec[0], k + 1], "room", spec[3], KredikPlan.KIND_H[kind], sub, false, Vector2.ZERO, 0.0))
		for k in n:
			var room: Dictionary = _rooms[ids[k]]
			_paint_area(room["rect"], false, Vector2.ZERO, 0.0, ids[k])
		return
	else:
		var h: float = spec[4] if spec[4] > 0.0 else KredikPlan.KIND_H[kind]
		ids = [_add_room(spec[0], kind, spec[3], h, r, circle, c, radius)]
	_paint_area(r, circle, c, radius, ids[0])


func _add_room(name: String, kind: String, props: String, h: float, r: Rect2, circle: bool, c: Vector2, radius: float) -> int:
	# Las salas altas de la planta baja ocupan dos niveles; el resto cabe en uno.
	var double := level == "ground" and h >= KredikPlan.DOUBLE_H
	h = minf(h, ROOM_H + KredikPlan.LH if double else ROOM_H)
	_rooms.append({"name": name, "kind": kind, "props": props, "h": h, "rect": r, "circle": circle, "double": double,
			"c": c, "r": radius, "open": kind in KredikPlan.OPEN_KINDS, "circ": kind in KredikPlan.CIRCULATION,
			"cells": 0, "doors": [], "lo": Vector2i(NX, NZ), "hi": Vector2i(-1, -1)})
	return _rooms.size() - 1


func _paint_area(r: Rect2, circle: bool, c: Vector2, radius: float, id: int) -> void:
	var i0 := clampi(int(floorf(r.position.x - X0)), 0, NX - 1)
	var i1 := clampi(int(ceilf(r.end.x - X0)), 0, NX - 1)
	var j0 := clampi(int(floorf(r.position.y - Z0)), 0, NZ - 1)
	var j1 := clampi(int(ceilf(r.end.y - Z0)), 0, NZ - 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var p := Vector2(X0 + i + 0.5, Z0 + j + 0.5)
			var inside := p.distance_to(c) < radius if circle else r.has_point(p)
			if inside:
				_grid[j * NX + i] = id


func _measure_rooms() -> void:
	for j in NZ:
		for i in NX:
			var id := _grid[j * NX + i]
			if id < 0:
				continue
			var r: Dictionary = _rooms[id]
			r["cells"] += 1
			r["lo"] = Vector2i(mini(r["lo"].x, i), mini(r["lo"].y, j))
			r["hi"] = Vector2i(maxi(r["hi"].x, i), maxi(r["hi"].y, j))
	for r: Dictionary in _rooms:
		if r["cells"] > 0:
			# Lo que quedó de la sala (otras pueden taparla en parte).
			r["box"] = Rect2(X0 + r["lo"].x, Z0 + r["lo"].y, r["hi"].x - r["lo"].x + 1, r["hi"].y - r["lo"].y + 1)


func _h(id: int) -> float:
	return _rooms[id]["h"] if id >= 0 else 0.0


func _is_open(id: int) -> bool:
	return id >= 0 and _rooms[id]["open"]


# ------------------------------------------------------------------ Muros, puertas y ventanas

func _collect_runs() -> void:
	var edges := {}
	for j in NZ:
		for i in NX:
			var a := _grid[j * NX + i]
			if i + 1 < NX:
				_edge(edges, 0, X0 + i + 1, Z0 + j, a, _grid[j * NX + i + 1])
			if j + 1 < NZ:
				_edge(edges, 1, Z0 + j + 1, X0 + i, a, _grid[(j + 1) * NX + i])
	for key: Array in edges:
		var ss: Array = edges[key]
		ss.sort()
		var s0: float = ss[0]
		var prev: float = ss[0]
		for k in range(1, ss.size() + 1):
			if k < ss.size() and is_equal_approx(ss[k], prev + 1.0):
				prev = ss[k]
				continue
			_runs.append({"o": key[0], "line": key[1], "a": key[2], "b": key[3], "s0": s0, "s1": prev + 1.0, "open": []})
			if k < ss.size():
				s0 = ss[k]
				prev = ss[k]


func _edge(edges: Dictionary, o: int, line: float, s: float, a: int, b: int) -> void:
	if a == b:
		return
	for id in [a, b]:
		if id == SOLID or id == ROCK or id == ROUND or id == HOLE or (id >= 0 and _rooms[id]["circle"]):
			return
	if _is_open(a) and _is_open(b):
		return
	var key := [o, line, a, b]
	if not edges.has(key):
		edges[key] = []
	edges[key].append(s)


## Medidas del muro de un tramo: [alto, grosor].
func _wall_size(run: Dictionary) -> Vector2:
	var a: int = run["a"]
	var b: int = run["b"]
	var h := maxf(_h(a), _h(b))
	var t := 1.2 if a == VOID or b == VOID else 0.5
	if h <= 0.0:
		h = 1.2  # pretil entre una terraza y el vacío
	return Vector2(h, t)


func _length(run: Dictionary) -> float:
	return run["s1"] - run["s0"]


## Puertas: entre dos espacios de paso, un vano ancho; entre una sala y un espacio de paso, una
## puerta; las salas que siguen sin salida se abren a su vecina con más muro en común.
func _place_doors() -> void:
	var pairs := {}
	for k in _runs.size():
		var run: Dictionary = _runs[k]
		var key := Vector2i(mini(run["a"], run["b"]), maxi(run["a"], run["b"]))
		if not pairs.has(key):
			pairs[key] = []
		pairs[key].append(k)
	# Las salas redondas no tienen tramos (su muro es un anillo): sus vecinos salen de la cuadrícula.
	_circle_pairs(pairs)
	var deferred := []
	for key: Vector2i in pairs:
		var a := key.x
		var b := key.y
		var runs: Array = pairs[key]
		runs.sort_custom(func(x: int, y: int) -> bool: return _length(_runs[x]) > _length(_runs[y]))
		if a == VOID:
			if b >= 0 and _rooms[b]["kind"] == "exit":
				_door(runs[0], 6.0, b)
			continue
		var ca: bool = _rooms[a]["circ"]
		var cb: bool = _rooms[b]["circ"]
		var grand := false
		for id in [a, b]:
			if _rooms[id]["kind"] in ["hall", "throne", "court", "terrace", "garden", "exit"]:
				grand = true
		if ca and cb:
			for k: int in runs:
				var length := _length(_runs[k])
				if length < 3.0:
					continue
				var n := maxi(1, int(length / 16.0))
				for d in n:
					var s: float = _runs[k]["s0"] + length * (d + 0.5) / n
					_door(k, minf(length - 1.0, 5.0 if grand else 3.4), -1, s)
				if not grand:
					break
		elif ca or cb:
			var room := b if ca else a
			if _length(_runs[runs[0]]) >= 2.4:
				_door(runs[0], 3.6 if _rooms[room]["h"] >= 7.0 else 2.2, room)
		else:
			deferred.append(key)
	for i in _rooms.size():
		var r: Dictionary = _rooms[i]
		if r["cells"] == 0 or r["circ"] or not r["doors"].is_empty():
			continue
		var best := -1
		var best_len := 0.0
		for key: Vector2i in deferred:
			if key.x != i and key.y != i:
				continue
			var k: int = pairs[key][0]
			if _length(_runs[k]) > best_len and _length(_runs[k]) >= 2.4:
				best_len = _length(_runs[k])
				best = k
		if best < 0 and not level.begins_with("sub"):
			# Sin vecinos (arriba, sobre un patio): una puerta al vacío, para entrar volando.
			for k in _runs.size():
				var run: Dictionary = _runs[k]
				if (run["a"] == i and run["b"] == VOID or run["b"] == i and run["a"] == VOID) and _length(run) > best_len:
					best_len = _length(run)
					best = k
		if best >= 0:
			_door(best, 2.2, i)


## Una puerta en el tramo k (por defecto en el medio). room: la sala que la recibe (para contarla).
func _door(k: int, w: float, room: int, s := NAN) -> void:
	var run: Dictionary = _runs[k]
	var length := _length(run)
	w = minf(w, length - 0.6)
	if w < 1.2:
		return
	var mid: float = (run["s0"] + run["s1"]) / 2.0 if is_nan(s) else s
	mid = clampf(mid, run["s0"] + w / 2.0 + 0.3, run["s1"] - w / 2.0 - 0.3)
	var size := _wall_size(run)
	var top := minf(size.x - 0.9, 5.6 if w >= 3.4 else 3.3)
	if top < 2.2:
		return
	run["open"].append({"s": mid, "w": w, "y0": 0.0, "y1": top, "door": true})
	for id in [run["a"], run["b"]]:
		if id >= 0:
			_rooms[id]["doors"].append(_run_point(run, mid))


## Vecinos de las salas redondas: los tramos de cuadrícula se buscan aparte (no se dibujan).
func _circle_pairs(pairs: Dictionary) -> void:
	for i in _rooms.size():
		var r: Dictionary = _rooms[i]
		if not r["circle"] or r["cells"] == 0:
			continue
		var best := {}
		for j in range(r["lo"].y - 1, r["hi"].y + 2):
			for ii in range(r["lo"].x - 1, r["hi"].x + 2):
				if ii < 0 or j < 0 or ii >= NX or j >= NZ or _grid[j * NX + ii] != i:
					continue
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n := Vector2i(ii, j) + d
					if n.x < 0 or n.y < 0 or n.x >= NX or n.y >= NZ:
						continue
					var other := _grid[n.y * NX + n.x]
					if other == i or other < 0:
						continue
					if not best.has(other):
						best[other] = []
					best[other].append(Vector2(X0 + ii + 0.5 + d.x * 0.5, Z0 + j + 0.5 + d.y * 0.5))
		for other: int in best:
			var pts: Array = best[other]
			if r["open"] and _rooms[other]["open"]:
				continue
			if not (r["circ"] or _rooms[other]["circ"]) and not r["doors"].is_empty():
				continue
			# La puerta del anillo: el punto de contacto más cercano al centro del contacto.
			var avg := Vector2.ZERO
			for p: Vector2 in pts:
				avg += p
			avg /= pts.size()
			var ang: float = (avg - r["c"]).angle()
			r["doors"].append(r["c"] + Vector2.from_angle(ang) * r["r"])
			r["ring_doors"] = r.get("ring_doors", []) + [[ang, 3.6 if r["h"] >= 7.0 or _rooms[other]["kind"] == "hall" else 2.4]]
			_rooms[other]["doors"].append(avg)


func _run_point(run: Dictionary, s: float) -> Vector2:
	return Vector2(run["line"], s) if run["o"] == 0 else Vector2(s, run["line"])


## Ventanas ojivales en los muros de las salas que dan a un patio o al exterior.
func _place_windows() -> void:
	for run: Dictionary in _runs:
		var a: int = run["a"]
		var b: int = run["b"]
		var room := -1
		if a >= 0 and not _rooms[a]["open"] and (b == VOID or _is_open(b)):
			room = a
		elif b >= 0 and not _rooms[b]["open"] and (a == VOID or _is_open(a)):
			room = b
		if room < 0 or _rooms[room]["kind"] in ["vault", "maze"] or level.begins_with("sub"):
			continue
		var h: float = _wall_size(run).x
		if h < 4.0 or _length(run) < 3.0:
			continue
		var top := minf(h - 1.3, 8.0)
		var n := int(_length(run) / 4.5)
		for k in n:
			var s: float = run["s0"] + _length(run) * (k + 0.5) / n
			var clear := true
			for o: Dictionary in run["open"]:
				if absf(o["s"] - s) < o["w"] / 2.0 + 1.6:
					clear = false
			if clear:
				run["open"].append({"s": s, "w": 1.3, "y0": 1.5, "y1": top, "door": false})


## Caja en el plano de un tramo de muro: s a lo largo, y en altura, n hacia el lado b.
func _wbox(b: MeshBuilder, key: String, run: Dictionary, s: float, y: float, along: float, height: float, thick: float, angle := 0.0, n := 0.0) -> void:
	var ax := Vector3(0, 0, 1) if run["o"] == 0 else Vector3(1, 0, 0)
	var nrm := Vector3(1, 0, 0) if run["o"] == 0 else Vector3(0, 0, 1)
	var x := ax * cos(angle) + Vector3.UP * sin(angle)
	var yv := -ax * sin(angle) + Vector3.UP * cos(angle)
	var p := Vector3(run["line"], y, s) if run["o"] == 0 else Vector3(s, y, run["line"])
	b.cube(key, Transform3D(Basis(x, yv, nrm), p + nrm * n), Vector3(along, height, thick))


func _wall(run: Dictionary) -> void:
	var size := _wall_size(run)
	var h := size.x
	var t := size.y
	var ext := t / 2.0 if run["o"] == 0 else 0.0  # los tramos norte-sur tapan las esquinas
	var s0: float = run["s0"] - ext
	var s1: float = run["s1"] + ext
	var ops: Array = run["open"]
	ops.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["s"] < y["s"])
	var cur := s0
	for o: Dictionary in ops:
		var l: float = o["s"] - o["w"] / 2.0
		var r: float = o["s"] + o["w"] / 2.0
		if l > cur + 0.01:
			_piece(run, cur, l, 0.0, h, t, true)
		if o["y0"] > 0.0:
			_piece(run, l, r, 0.0, o["y0"], t, true)
		_piece(run, l, r, o["y1"], h, t, false)
		_frame(run, o, t)
		cur = r
	if s1 > cur + 0.01:
		_piece(run, cur, s1, 0.0, h, t, true)
	if h >= 3.0:
		_wbox(_mb, "ks_trim", run, (s0 + s1) / 2.0, h - 0.25, s1 - s0, 0.5, t + 0.3)
	_pilasters(run, h, t)


func _piece(run: Dictionary, a: float, b: float, y0: float, y1: float, t: float, plinth: bool) -> void:
	if y1 - y0 < 0.01 or b - a < 0.01:
		return
	_wbox(_mb, "ks_wall", run, (a + b) / 2.0, (y0 + y1) / 2.0, b - a, y1 - y0, t)
	if plinth and y0 == 0.0 and y1 > 1.0:
		_wbox(_mb, "ks_trim", run, (a + b) / 2.0, 0.22, b - a, 0.45, t + 0.16)


## Marco de puerta o ventana: jambas, arco apuntado y, en las ventanas, cristal con parteluz.
func _frame(run: Dictionary, o: Dictionary, t: float) -> void:
	var s: float = o["s"]
	var w: float = o["w"]
	var y0: float = o["y0"]
	var y1: float = o["y1"]
	var key := "ks_trim"
	for k: float in [-1.0, 1.0]:
		_wbox(_mb, key, run, s + k * (w / 2.0 + 0.16), (y0 + y1) / 2.0, 0.32, y1 - y0, t + 0.22)
	# Arco apuntado: las esquinas de arriba del vano se cierran con muro (dos triángulos por cara)
	# y una moldura fina sigue la curva del arco.
	var spring := y1 - w * 0.55
	if spring > y0 + 1.0:
		for k: float in [-1.0, 1.0]:
			var p0 := Vector2(s + k * w / 2.0, spring)
			var p1 := Vector2(s, y1)
			var corner := Vector2(s + k * w / 2.0, y1)
			for side: float in [-1.0, 1.0]:
				_wtri(run, p0, p1, corner, side * t / 2.0)
			var d := p1 - p0
			var angle := atan2(d.y, d.x) if k < 0.0 else atan2(-d.y, -d.x)
			var up := Vector2(-d.y, d.x).normalized()
			if up.y < 0.0:
				up = -up
			var c := (p0 + p1) / 2.0 + up * 0.15
			_wbox(_mb, key, run, c.x, c.y, d.length() + 0.1, 0.3, t + 0.12, angle)
	if not o["door"]:
		_wbox(_deco, "ks_glass", run, s, (y0 + y1) / 2.0, w, y1 - y0, 0.08)
		_wbox(_mb, "iron", run, s, (y0 + y1) / 2.0, 0.08, y1 - y0, 0.14)
		_wbox(_mb, "iron", run, s, lerpf(y0, y1, 0.55), w, 0.08, 0.14)
		_wbox(_mb, key, run, s, y0 - 0.1, w + 0.5, 0.2, t + 0.3)


## Triángulo de muro en el plano de un tramo (puntos en s, y), en la cara desplazada n.
func _wtri(run: Dictionary, a: Vector2, b: Vector2, c: Vector2, n: float) -> void:
	var to3 := func(p: Vector2, off: float) -> Vector3:
		return Vector3(run["line"] + off, p.y, p.x) if run["o"] == 0 else Vector3(p.x, p.y, run["line"] + off)
	_mb.tri("ks_wall", to3.call(a, n), to3.call(b, n), to3.call(c, n), to3.call((a + b + c) / 3.0, 0.0))


## Pilastras (y estandartes) en los muros de los salones.
func _pilasters(run: Dictionary, h: float, t: float) -> void:
	if h < 7.0:
		return
	for side: float in [-1.0, 1.0]:
		var id: int = run["a"] if side < 0.0 else run["b"]
		if id < 0 or not _rooms[id]["kind"] in ["hall", "throne"]:
			continue
		var banners: bool = "banners" in _rooms[id]["props"]
		var s: float = run["s0"] + 2.5
		var k := 0
		while s < run["s1"] - 1.5:
			var clear := true
			for o: Dictionary in run["open"]:
				if absf(o["s"] - s) < o["w"] / 2.0 + 1.0:
					clear = false
			if clear:
				_wbox(_mb, "ks_trim", run, s, (h - 0.5) / 2.0, 0.9, h - 0.5, 0.4, 0.0, side * (t / 2.0 + 0.2))
				_wbox(_mb, "ks_trim", run, s, 0.4, 1.3, 0.8, 0.6, 0.0, side * (t / 2.0 + 0.3))
				if banners and k % 2 == 1 and s + 2.5 < run["s1"]:
					var bs := s - 2.5
					var free := true
					for o: Dictionary in run["open"]:
						if absf(o["s"] - bs) < o["w"] / 2.0 + 1.2:
							free = false
					if free:
						var bh := minf(h * 0.45, 7.0)
						_wbox(_deco, "red", run, bs, h - 1.6 - bh / 2.0, 1.5, bh, 0.06, 0.0, side * (t / 2.0 + 0.06))
						_wbox(_mb, "gold", run, bs, h - 1.5, 1.9, 0.12, 0.14, 0.0, side * (t / 2.0 + 0.1))
			s += 5.0
			k += 1


## Muro curvo de las salas redondas (con sus puertas) o bordillo de los jardines redondos.
func _ring(i: int) -> void:
	var r: Dictionary = _rooms[i]
	var c := Vector3(r["c"].x, 0, r["c"].y)
	var radius: float = r["r"]
	var steps := 48
	if r["open"]:
		for k in 4:
			var a := k * PI / 2.0 + 0.2
			_mb.arc_wall("ks_trim", c, radius, 0.6, 0.0, 0.6, a, a + PI / 2.0 - 0.4, 8)
		return
	var h: float = r["h"]
	var doors: Array = r.get("ring_doors", [])
	for k in steps:
		var a0 := TAU * k / steps
		var a1 := TAU * (k + 1) / steps
		var mid := (a0 + a1) / 2.0
		var gap := 0.0
		for d: Array in doors:
			var half := asin(clampf(d[1] / 2.0 / radius, 0.0, 1.0))
			if absf(angle_difference(mid, d[0])) < half + 0.02:
				gap = d[1]
		if gap > 0.0:
			_mb.arc_wall("ks_wall", c, radius, 0.6, minf(h - 0.9, 5.6 if gap >= 3.4 else 3.3), h, a0, a1, 1)
		else:
			_mb.arc_wall("ks_wall", c, radius, 0.6, 0.0, h, a0, a1, 1)
	_mb.arc_wall("ks_trim", c, radius, 0.9, h - 0.5, h, 0.0, TAU, steps)
	_mb.arc_wall("ks_trim", c, radius - 0.08, 0.75, 0.0, 0.45, 0.0, TAU, steps)


# ------------------------------------------------------------------ Suelos, techos y macizos

## Rectángulos que cubren las celdas que cumplen `pred` (fusión voraz).
func _greedy(pred: Callable, lo := Vector2i(0, 0), hi := Vector2i(NX - 1, NZ - 1)) -> Array:
	var used := PackedByteArray()
	used.resize(NX * NZ)
	var out := []
	for j in range(lo.y, hi.y + 1):
		for i in range(lo.x, hi.x + 1):
			if used[j * NX + i] or not pred.call(i, j):
				continue
			var w := 1
			while i + w <= hi.x and not used[j * NX + i + w] and pred.call(i + w, j):
				w += 1
			var d := 1
			var grow := true
			while grow and j + d <= hi.y:
				for k in w:
					if used[(j + d) * NX + i + k] or not pred.call(i + k, j + d):
						grow = false
						break
				if grow:
					d += 1
			for dz in d:
				for k in w:
					used[(j + dz) * NX + i + k] = 1
			out.append(Rect2(X0 + i, Z0 + j, w, d))
	return out


func _floors_and_ceilings() -> void:
	var g := _grid
	var pool := func(id: int) -> bool: return id >= 0 and _rooms[id]["kind"] == "pool"
	var skip := func(i: int, j: int, rects: Array[Rect2]) -> bool:
		for rc: Rect2 in rects:
			if rc.has_point(Vector2(X0 + i + 0.5, Z0 + j + 0.5)):
				return true
		return false
	for rc: Rect2 in _greedy(func(i: int, j: int) -> bool:
			var id := g[j * NX + i]
			return id >= 0 and not _rooms[id]["open"] and not pool.call(id) and not skip.call(i, j, _skip_floor)):
		_mb.abox("ks_floor", Vector3(rc.get_center().x, -0.5, rc.get_center().y), Vector3(rc.size.x, 1.0, rc.size.y))
	for rc: Rect2 in _greedy(func(i: int, j: int) -> bool:
			var id := g[j * NX + i]
			return id >= 0 and _rooms[id]["open"]):
		_mb.abox("ks_court", Vector3(rc.get_center().x, -0.5, rc.get_center().y), Vector3(rc.size.x, 1.0, rc.size.y))
	for i in _rooms.size():
		var r: Dictionary = _rooms[i]
		if r["cells"] == 0 or r["open"] or r["kind"] == "tower":
			continue
		var h: float = r["h"]
		for rc: Rect2 in _greedy(func(ii: int, j: int) -> bool: return g[j * NX + ii] == i and not skip.call(ii, j, _skip_ceil), r["lo"], r["hi"]):
			_mb.abox("ks_ceil", Vector3(rc.get_center().x, h + 0.35, rc.get_center().y), Vector3(rc.size.x, 0.7, rc.size.y))
		if r["kind"] == "pool":
			_pool(r)
		# Nervaduras del techo en los salones.
		if h >= 7.0 and not r["circle"] and r["kind"] != "stair":
			var box: Rect2 = r["box"]
			var along_x := box.size.x >= box.size.y
			var length := box.size.x if along_x else box.size.y
			var n := int(length / 4.5)
			for k in range(1, n):
				var t := float(k) / n
				if along_x:
					_mb.abox("ks_trim", Vector3(box.position.x + box.size.x * t, h - 0.3, box.get_center().y), Vector3(0.5, 0.6, box.size.y))
				else:
					_mb.abox("ks_trim", Vector3(box.get_center().x, h - 0.3, box.position.y + box.size.y * t), Vector3(box.size.x, 0.6, 0.5))


## Cisterna: anden alrededor, pozo con agua oscura y un pretil.
func _pool(r: Dictionary) -> void:
	var box: Rect2 = r["box"]
	if r["circle"]:
		var c := Vector3(r["c"].x, 0, r["c"].y)
		var radius: float = r["r"]
		var inner := radius - 3.0
		_mb.arc_wall("ks_floor", c, (radius + inner) / 2.0, radius - inner, -1.0, 0.0, 0.0, TAU, 40)
		_mb.arc_wall("ks_wall", c, inner, 0.6, -4.0, 0.0, 0.0, TAU, 40)
		_mb.arc_wall("ks_trim", c, inner, 0.7, 0.0, 0.7, 0.0, TAU, 40)
		_mb.frustum("ks_floor", c + Vector3(0, -5.0, 0), inner, inner, 1.0, 40)
		_deco.frustum("water", c + Vector3(0, -1.6, 0), inner, inner, 0.05, 40)
		return
	var inner := box.grow(-2.0)
	for side in 4:
		var rc := Rect2()
		match side:
			0: rc = Rect2(box.position, Vector2(box.size.x, 2.0))
			1: rc = Rect2(Vector2(box.position.x, inner.end.y), Vector2(box.size.x, 2.0))
			2: rc = Rect2(Vector2(box.position.x, inner.position.y), Vector2(2.0, inner.size.y))
			3: rc = Rect2(Vector2(inner.end.x, inner.position.y), Vector2(2.0, inner.size.y))
		_mb.abox("ks_floor", Vector3(rc.get_center().x, -0.5, rc.get_center().y), Vector3(rc.size.x, 1.0, rc.size.y))
	_mb.abox("ks_floor", Vector3(inner.get_center().x, -4.5, inner.get_center().y), Vector3(inner.size.x, 1.0, inner.size.y))
	_deco.abox("water", Vector3(inner.get_center().x, -1.6, inner.get_center().y), Vector3(inner.size.x, 0.05, inner.size.y))
	for side: float in [-1.0, 1.0]:
		_mb.abox("ks_trim", Vector3(inner.get_center().x, 0.35, inner.get_center().y + side * inner.size.y / 2.0), Vector3(inner.size.x, 0.7, 0.4))
		_mb.abox("ks_trim", Vector3(inner.get_center().x + side * inner.size.x / 2.0, 0.35, inner.get_center().y), Vector3(0.4, 0.7, inner.size.y))


## Muros macizos, roca y torres redondas.
func _masses() -> void:
	var g := _grid
	var sh := _solid_h
	for rc: Rect2 in _greedy(func(i: int, j: int) -> bool: return g[j * NX + i] == SOLID):
		_mb.abox("ks_wall", Vector3(rc.get_center().x, sh / 2.0 - 0.5, rc.get_center().y), Vector3(rc.size.x, sh + 1.0, rc.size.y))
		if not level.begins_with("sub"):
			_mb.abox("ks_trim", Vector3(rc.get_center().x, sh - 0.1, rc.get_center().y), Vector3(rc.size.x + 0.4, 0.4, rc.size.y + 0.4))
	for rc: Rect2 in _greedy(func(i: int, j: int) -> bool: return g[j * NX + i] == ROCK):
		_mb.abox("rock", Vector3(rc.get_center().x, sh / 2.0 - 1.0, rc.get_center().y), Vector3(rc.size.x, sh + 2.0, rc.size.y))
	for t: Array in _rounds:
		var c := Vector3(t[0].x, -1.0, t[0].y)
		_mb.frustum("ks_wall", c, t[1], t[1], sh + 1.0, 24)
		_mb.frustum("ks_trim", c + Vector3(0, 1.0, 0), t[1] + 0.2, t[1] + 0.2, 0.5, 24)
		if not level.begins_with("sub"):
			_mb.frustum("ks_trim", c + Vector3(0, sh + 0.6, 0), t[1] + 0.4, t[1] + 0.4, 0.5, 24)


# ------------------------------------------------------------------ Escaleras y salidas

func _flights() -> void:
	for f: Array in KredikPlan.flights():
		var s := stair_frame(KredikPlan.rect(f[2]))
		if f[0] == level:
			_stair(s)
		elif f[1] == level:
			# Arriba: barandilla alrededor del hueco (menos el lado del rellano, por donde se llega).
			var own := false
			for g: Array in KredikPlan.flights():
				if g[0] == level and g[2] == f[2]:
					own = true
			var axis: Vector2 = s["axis"]
			var side: Vector2 = s["side"]
			var start: Vector2 = s["start"]
			var band: float = s["band"]
			var length: float = s["len"]
			var far := start + axis * length
			# Suelo a medida (la cuadrícula de 1 m no cae justo en el hueco): rellano y pasillos.
			var rect := KredikPlan.rect(f[2])
			var hole: Rect2 = s["hole"]
			var land := Rect2(rect.position, (axis * STAIR_LAND + side * (rect.size.x if axis.x == 0.0 else rect.size.y)).abs())
			var strips: Array[Rect2] = [land]
			if axis.x == 0.0:
				strips.append(Rect2(rect.position.x, hole.position.y, hole.position.x - rect.position.x, hole.size.y))
				strips.append(Rect2(hole.end.x, hole.position.y, rect.end.x - hole.end.x, hole.size.y))
			else:
				strips.append(Rect2(hole.position.x, rect.position.y, hole.size.x, hole.position.y - rect.position.y))
				strips.append(Rect2(hole.position.x, hole.end.y, hole.size.x, rect.end.y - hole.end.y))
			for rc: Rect2 in strips:
				_mb.abox("ks_floor", Vector3(rc.get_center().x, -0.5, rc.get_center().y), Vector3(rc.size.x, 1.0, rc.size.y))
			for sgn: float in [-1.0, 1.0]:
				_rail(start + axis * STAIR_LAND + side * sgn * band / 2.0, far + side * sgn * band / 2.0)
			_rail(far - side * band / 2.0, far + side * band / 2.0)
			if not own:
				# Sin tramo propio que siga subiendo: se cierra la mitad por donde no se llega.
				var a := start + axis * STAIR_LAND
				_rail(a - side * band / 2.0, a)
				_rail(a, far)


## Dos tramos de ida y vuelta hasta el suelo del nivel de arriba, con el rellano de media vuelta,
## un murete entre los tramos y barandillas por fuera; una lámpara encima del rellano.
func _stair(s: Dictionary) -> void:
	var lh := KredikPlan.LH
	var axis: Vector2 = s["axis"]
	var side: Vector2 = s["side"]
	var start: Vector2 = s["start"]
	var band: float = s["band"]
	var length: float = s["len"]
	var a := start + axis * STAIR_LAND
	var b := start + axis * (length - STAIR_MID)
	var w := band / 2.0 - 0.15
	var off := side * band / 4.0
	_ramp(a - off, b - off, 0.0, lh / 2.0, w)
	_ramp(b + off, a + off, lh / 2.0, lh, w)
	for sgn: float in [-1.0, 1.0]:
		var o := side * sgn * (band / 2.0 - 0.05)
		var y0 := 0.0 if sgn < 0.0 else lh
		var y1 := lh / 2.0
		_rail3(Vector3(a.x + o.x, y0 + 1.0, a.y + o.y), Vector3(b.x + o.x, y1 + 1.0, b.y + o.y))
	# Rellano de media vuelta (macizo) y murete central hasta el suelo de arriba.
	var m := start + axis * (length - STAIR_MID / 2.0)
	var land := Vector2(STAIR_MID, band) if axis.x != 0.0 else Vector2(band, STAIR_MID)
	_mb.abox("ks_marble", Vector3(m.x, lh / 4.0 - 0.1, m.y), Vector3(land.x, lh / 2.0 + 0.2, land.y))
	var core := (a + b) / 2.0
	var core_len := a.distance_to(b)
	_mb.abox("ks_wall", Vector3(core.x, lh / 2.0, core.y), Vector3(core_len if axis.x != 0.0 else 0.3, lh, 0.3 if axis.x != 0.0 else core_len))
	_lights.append([Vector3(m.x, lh / 2.0 + 3.0, m.y), Color(1.0, 0.62, 0.32), 10.0, 1.3])
	_mb.abox("iron", Vector3(m.x, lh / 2.0 + 3.4, m.y), Vector3(0.5, 0.6, 0.5))
	_deco.abox("fire", Vector3(m.x, lh / 2.0 + 3.35, m.y), Vector3(0.28, 0.35, 0.28))
	_anchors.append(Vector3(m.x, lh / 2.0 + 3.4, m.y))


## Tramo de escalera: rampa de mármol con las aristas de los peldaños marcadas.
func _ramp(p0: Vector2, p1: Vector2, y0: float, y1: float, width: float) -> void:
	var run := p0.distance_to(p1)
	var dir := (p1 - p0) / run
	var rise := y1 - y0
	var slope := atan2(rise, run)
	var ax3 := Vector3(dir.x, 0, dir.y)
	var sd3 := ax3.cross(Vector3.UP)
	var basis := Basis(ax3 * cos(slope) + Vector3.UP * sin(slope), -ax3 * sin(slope) + Vector3.UP * cos(slope), sd3)
	var mid := (p0 + p1) / 2.0
	_deco.cube("ks_marble", Transform3D(basis, Vector3(mid.x, (y0 + y1) / 2.0 - 0.25 / cos(slope), mid.y)), Vector3(run / cos(slope) + 0.1, 0.5, width))
	_ramps.append([Transform3D(basis, Vector3(mid.x, (y0 + y1) / 2.0, mid.y) - basis.y * 0.05 - basis.x * 0.05), Vector3(run / cos(slope) + 0.1, 0.1, width)])
	var steps := int(absf(rise) / 0.25)
	for k in steps:
		var t := (k + 0.5) / steps
		var p := p0.lerp(p1, t)
		_deco.cube("ks_trim", Transform3D(basis, Vector3(p.x, lerpf(y0, y1, t) + 0.02, p.y)), Vector3(0.08, 0.06, width))


## Barandilla de hierro a 1 m del suelo, con postes.
func _rail(a: Vector2, b: Vector2) -> void:
	_rail3(Vector3(a.x, 1.0, a.y), Vector3(b.x, 1.0, b.y))


func _rail3(a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	if length < 0.1:
		return
	var u := (b - a) / length
	var flat := Vector3(u.x, 0, u.z).normalized()
	var side := flat.cross(Vector3.UP)
	_mb.cube("iron", Transform3D(Basis(u, side.cross(u), side), (a + b) / 2.0), Vector3(length, 0.08, 0.08))
	var posts := int(length / 1.6) + 1
	for k in posts + 1:
		var p := a.lerp(b, float(k) / posts)
		_mb.abox("iron", p - Vector3(0, 0.5, 0), Vector3(0.06, 1.0, 0.06))


## Túnel de salida de un subnivel: sale del borde de la cuadrícula hacia el oeste por la franja
## z0..z1 y llega a la boca (x1), en el tajo del cordón de picos. Si `rise` > 0 sube en rampa
## (TUNNEL_SLOPE) hasta esa altura y sigue llano. Suelo de losas, muros y bóveda de roca, antorchas.
func _tunnel(z0: float, z1: float, x0: float, x1: float, rise: float) -> void:
	var zc := (z0 + z1) / 2.0
	var width := z1 - z0
	var run := rise / tan(deg_to_rad(TUNNEL_SLOPE))
	var xr := x0 - run  # donde termina la rampa
	var pieces := []  # [x desde, x hasta, y desde, y hasta]
	if rise > 0.0:
		pieces.append([x0, xr, 0.0, rise])
	pieces.append([xr, x1, rise, rise])
	for p: Array in pieces:
		var a := Vector3(p[0], p[2], zc)
		var b := Vector3(p[1], p[3], zc)
		var length := Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y))
		var u := (b - a) / length
		var up := Vector3(0, 0, 1).cross(u).normalized()
		if up.y < 0.0:
			up = -up
		var basis := Basis(u, up, Vector3(0, 0, 1))
		var mid := (a + b) / 2.0
		if p[2] != p[3]:
			_deco.cube("ks_floor", Transform3D(basis, mid - up * 0.5), Vector3(length + 0.2, 1.0, width + 2.0))
			_ramps.append([Transform3D(basis, mid - up * 0.05 - u * 0.05), Vector3(length + 0.1, 0.1, width + 2.0)])
		else:
			_mb.cube("ks_floor", Transform3D(basis, mid - up * 0.5), Vector3(length, 1.0, width + 2.0))
		_mb.cube("rock", Transform3D(basis, mid + up * (TUNNEL_H + 0.5)), Vector3(length + 0.2, 1.0, width + 2.0))
		for sgn: float in [-1.0, 1.0]:
			_mb.cube("rock", Transform3D(basis, mid + up * TUNNEL_H / 2.0 + Vector3(0, 0, sgn * (width / 2.0 + 0.5))), Vector3(length + 0.2, TUNNEL_H + 2.0, 1.0))
		if p[2] != p[3]:
			var steps := int((p[3] - p[2]) / 0.3)
			for k in steps:
				var q := a.lerp(b, (k + 0.5) / steps)
				_deco.cube("ks_trim", Transform3D(basis, q + up * 0.02), Vector3(0.08, 0.06, width))
	# Portal de roca alrededor de la boca: tapa el hueco que deja la meseta (ver KredikCitadel._plateau).
	_mb.abox("rock", Vector3(x1 + 3.0, rise + TUNNEL_H + 1.75, zc), Vector3(5.0, 3.5, width + 9.0))
	for sgn: float in [-1.0, 1.0]:
		# Del lado del otro túnel (que corre al lado) no: ahí ya están los muros de los dos.
		var free := true
		for t: Array in tunnels():
			var oc: float = (t[1] + t[2]) / 2.0
			if not is_equal_approx(oc, zc) and signf(oc - zc) == sgn and absf(oc - zc) < width + 8.0:
				free = false
		if free:
			_mb.abox("rock", Vector3(x1 + 3.0, rise + (TUNNEL_H + 3.5) / 2.0, zc + sgn * (width / 2.0 + 2.75)), Vector3(5.0, TUNNEL_H + 3.5, 3.5))
	# Arco de la boca y un poco de suelo afuera (el hueco del terreno tiene celdas de 2 m).
	_mb.abox("ks_floor", Vector3(x1 - 1.5, rise - 0.5, zc), Vector3(3.0, 1.0, width + 2.0))
	for sgn: float in [-1.0, 1.0]:
		_mb.abox("ks_trim", Vector3(x1 + 0.3, rise + TUNNEL_H / 2.0, zc + sgn * (width / 2.0 + 0.3)), Vector3(0.8, TUNNEL_H + 0.4, 0.9))
	_mb.abox("ks_trim", Vector3(x1 + 0.3, rise + TUNNEL_H + 0.3, zc), Vector3(0.8, 0.8, width + 1.6))
	# Antorchas cada 12 m.
	var x := x0 - 6.0
	while x > x1 + 3.0:
		var y := rise if x < xr else (x0 - x) * tan(deg_to_rad(TUNNEL_SLOPE))
		var p := Vector3(x, y + 2.6, z0 + 0.25)
		_mb.abox("iron", p, Vector3(0.3, 0.5, 0.3))
		_deco.abox("fire", p + Vector3(0, 0.35, 0), Vector3(0.2, 0.3, 0.2))
		_lights.append([p + Vector3(0, 0.6, 1.0), Color(1.0, 0.58, 0.28), 9.0, 1.1])
		_anchors.append(p)
		x -= 12.0


# ------------------------------------------------------------------ Mobiliario y luz

func _furnish(i: int) -> void:
	var r: Dictionary = _rooms[i]
	var props: String = r["props"]
	var box: Rect2 = r["box"] if not r["circle"] else Rect2(r["c"] - Vector2(r["r"], r["r"]) * 0.7, Vector2(r["r"], r["r"]) * 1.4)
	var h: float = r["h"]
	var inner := box.grow(-1.6)
	if inner.size.x < 1.0 or inner.size.y < 1.0:
		inner = box.grow(-0.8)
	var along_x := inner.size.x >= inner.size.y
	if r["kind"] == "maze":
		_maze(r)
	if "columns" in props or r["kind"] == "throne":
		_columns(box, h)
	if r["kind"] in ["hall", "throne"] and not r["circle"]:
		_carpet(box, along_x)
	for p in props.split(" ", false):
		match p:
			"throne":
				_throne(box, h)
				# Estatuas a los lados del estrado y candelabros en los escalones.
				for sgn: float in [-1.0, 1.0]:
					_mb.abox("ks_marble", Vector3(box.get_center().x + sgn * 9.5, 0.6, box.position.y + 4.0), Vector3(4.0, 1.2, 4.0))
					_poly("gothic_statue", Vector3(box.get_center().x + sgn * 9.5, 1.2, box.position.y + 4.0), PI, 2.8)
					_poly("brass_candleholders", Vector3(box.get_center().x + sgn * 4.5, 0.6, box.position.y + 8.6), PI, 1.6)
			"benches":
				_rows(inner, along_x, 2.0, func(c: Vector3, ax: bool) -> void: _bench(c, ax))
			"desks":
				_rows(inner, along_x, 2.5, func(c: Vector3, ax: bool) -> void: _desk(c, ax))
			"shelves":
				_shelf_rows(inner, along_x, h)
				_cabinets(box, along_x)
			"library":
				_shelf_rows(inner, along_x, h)
				_cabinets(box, along_x)
				_table(inner.get_center(), along_x, 3.0)
			"bunks":
				_rows(inner, along_x, 2.2, func(c: Vector3, ax: bool) -> void: _bunk(c, ax))
			"crates":
				_crates(inner)
			"table":
				_table(inner.get_center(), along_x, minf(maxf(inner.size.x, inner.size.y) * 0.6, 8.0))
			"round_table":
				_round_table(inner.get_center(), minf(minf(inner.size.x, inner.size.y) * 0.3, 2.2), 8)
			"map_table":
				_map_table(inner.get_center(), along_x)
			"council":
				_council(r["c"], r["r"])
			"bed":
				_bed(inner, along_x)
				_cabinets(box, along_x)
			"bath":
				_bath(inner)
			"statue":
				_mb.abox("ks_marble", Vector3(inner.get_center().x, 0.5, inner.get_center().y), Vector3(4.2, 1.0, 4.2))
				_poly("gothic_statue", Vector3(inner.get_center().x, 1.0, inner.get_center().y), PI, 2.4)
			"statues":
				_statue_rows(inner, along_x)
			"fountain":
				_fountain(inner.get_center(), minf(minf(inner.size.x, inner.size.y) * 0.3, 4.5))
			"altar":
				_altar(inner, along_x)
				var c2 := inner.get_center()
				var far := Vector2(inner.end.x - 1.0, c2.y) if along_x else Vector2(c2.x, inner.position.y + 1.0)
				_poly("brass_candleholders", Vector3(far.x, 1.2, far.y), PI if not along_x else -PI / 2.0, 0.9)
			"weapons":
				_weapons(inner, along_x)
			"chests":
				_chests(inner, along_x)
			"cell":
				_cell(inner)
			"garden":
				_garden(inner, r)
				for k in 3:
					var gc: Vector2 = (r["c"] if r["circle"] else inner.get_center()) + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(1.0, 3.0)
					_poly("boulder_01", Vector3(gc.x, 0, gc.y), _rng.randf() * TAU, _rng.randf_range(0.8, 1.5))
			"vault_dome":
				_dome(r)
			"shaft":
				_shaft(inner)
	if r["open"] and r["cells"] > 60 and not level.begins_with("sub"):
		var c := inner.get_center()
		_braziers.append(Vector3(c.x + inner.size.x * 0.3, 0, c.y))
	# Algo que recoger: monedas y frascos por aquí y por allá; buen equipo en el Salón del Trono.
	if r["name"] == "Salón del Trono":
		_loot(box)


## Lámparas de hierro colgadas (anclas) con su luz; más oscuro cuanto más abajo.
func _light(i: int) -> void:
	var r: Dictionary = _rooms[i]
	if r["open"] or r["kind"] in ["stair", "tower"]:
		return
	var box: Rect2 = r["box"]
	var area: float = r["cells"]
	var n := clampi(int(area / 110.0), 1, 6)
	var color := Color(1.0, 0.62, 0.32)
	var energy := 1.5
	match level:
		"l5":
			color = Color(1.0, 0.72, 0.42)
			energy = 1.9
		"sub1":
			energy = 1.2
		"sub2":
			energy = 0.9
		"sub3":
			color = Color(0.55, 0.7, 0.95)
			energy = 0.55
			if _rng.randf() < 0.4:
				return
	var h: float = r["h"]
	var y := minf(h - 1.6, 6.5)
	var along_x := box.size.x >= box.size.y
	for k in n:
		var t := (k + 0.5) / n
		var p := Vector2(lerpf(box.position.x, box.end.x, t), box.get_center().y) if along_x \
				else Vector2(box.get_center().x, lerpf(box.position.y, box.end.y, t))
		if r["circle"]:
			p = r["c"]
		var big := h >= 9.0
		_mb.abox("iron", Vector3(p.x, (y + h) / 2.0 + 0.4, p.y), Vector3(0.06, h - y - 0.4, 0.06))
		if big:
			_poly("lantern_chandelier_01", Vector3(p.x, y - 2.0, p.y), 0.0, 2.8)
		else:
			_mb.abox("iron", Vector3(p.x, y, p.y), Vector3(0.5, 0.6, 0.5))
			_deco.abox("fire", Vector3(p.x, y - 0.05, p.y), Vector3(0.28, 0.35, 0.28))
		_anchors.append(Vector3(p.x, y, p.y))
		_lights.append([Vector3(p.x, y - 0.5, p.y), color, clampf(sqrt(area / n) * 1.1, 6.0, 16.0), energy * (1.4 if big else 1.0)])


# ------------------------------------------------------------------ Piezas de mobiliario

func _columns(box: Rect2, h: float) -> void:
	var along_x := box.size.x >= box.size.y
	var length := box.size.x if along_x else box.size.y
	var width := box.size.y if along_x else box.size.x
	if width < 9.0 or length < 10.0:
		return
	var n := int((length - 4.0) / 6.0)
	for row: float in [0.25, 0.75]:
		for k in n + 1:
			var t := 2.0 + (length - 4.0) * k / maxf(n, 1)
			var p := box.position + (Vector2(t, width * row) if along_x else Vector2(width * row, t))
			var c := Vector3(p.x, 0, p.y)
			_mb.abox("ks_trim", c + Vector3(0, 0.35, 0), Vector3(1.7, 0.7, 1.7))
			_mb.frustum("ks_marble", c + Vector3(0, 0.7, 0), 0.62, 0.55, h - 1.6, 12)
			_mb.abox("ks_trim", c + Vector3(0, h - 0.6, 0), Vector3(1.6, 0.6, 1.6))


func _carpet(box: Rect2, along_x: bool) -> void:
	var c := box.get_center()
	var size := Vector3(box.size.x - 3.0, 0.03, 2.4) if along_x else Vector3(2.4, 0.03, box.size.y - 3.0)
	_mb.abox("red", Vector3(c.x, 0.015, c.y), size)
	var edge := Vector3(size.x + (0.0 if along_x else 0.4), 0.025, size.z + (0.4 if along_x else 0.0))
	_mb.abox("gold", Vector3(c.x, 0.01, c.y), edge)


## Estrado con escalones y el trono de hierro de respaldo altísimo, al norte del salón.
func _throne(box: Rect2, h: float) -> void:
	var c := Vector2(box.get_center().x, box.position.y + 5.0)
	for k in 3:
		_mb.abox("ks_marble", Vector3(c.x, 0.3 + k * 0.6, c.y - k * 0.8), Vector3(14.0 - k * 3.0, 0.6, 7.0 - k * 1.6))
	var seat := Vector3(c.x, 1.8, c.y - 1.6)
	_mb.abox("iron", seat + Vector3(0, 0.5, 0), Vector3(2.0, 1.0, 1.6))
	_mb.abox("iron", seat + Vector3(0, 3.4, -0.7), Vector3(2.2, 5.8, 0.35))
	for k in 5:
		var x := (k - 2) * 0.5
		_mb.frustum("iron", seat + Vector3(x, 6.3, -0.7), 0.12, 0.0, 1.6 - absf(x) * 0.5, 4)
	for sgn: float in [-1.0, 1.0]:
		_mb.abox("iron", seat + Vector3(sgn * 1.0, 1.2, 0.0), Vector3(0.25, 0.4, 1.4))
		_braziers.append(Vector3(c.x + sgn * 6.0, 0, c.y + 2.0))
	_anchors.append(seat + Vector3(0, 2.0, 0))
	var bh := minf(h - 4.0, 12.0)
	for sgn: float in [-1.0, 1.0]:
		_deco.abox("red", Vector3(c.x + sgn * 5.0, h - 2.0 - bh / 2.0, box.position.y + 0.35), Vector3(3.0, bh, 0.08))


## Filas de muebles a los dos lados de un pasillo central.
func _rows(inner: Rect2, along_x: bool, step: float, put: Callable) -> void:
	var length := inner.size.x if along_x else inner.size.y
	var width := inner.size.y if along_x else inner.size.x
	var n := maxi(1, int(length / step))
	var lanes := [0.5] if width < 5.0 else [0.18, 0.82]
	for lane: float in lanes:
		for k in n:
			var t := (k + 0.5) * length / n
			var p := inner.position + (Vector2(t, width * lane) if along_x else Vector2(width * lane, t))
			put.call(Vector3(p.x, 0, p.y), along_x)


func _bench(c: Vector3, along_x: bool) -> void:
	var size := Vector3(0.5, 0.45, 2.6) if along_x else Vector3(2.6, 0.45, 0.5)
	_mb.abox("wood", c + Vector3(0, 0.45, 0), size)
	_mb.abox("wood", c + Vector3(0, 0.2, 0), size * Vector3(0.6, 0.9, 0.9) if along_x else size * Vector3(0.9, 0.9, 0.6))


func _desk(c: Vector3, along_x: bool) -> void:
	var top := Vector3(0.9, 0.08, 1.7) if along_x else Vector3(1.7, 0.08, 0.9)
	_mb.abox("wood", c + Vector3(0, 0.8, 0), top)
	_mb.abox("wood", c + Vector3(0, 0.38, 0), top * Vector3(0.8, 9.5, 0.8))
	var back := Vector3(-0.9, 0, 0) if along_x else Vector3(0, 0, 0.9)
	_mb.abox("wood", c + back + Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5))
	_mb.abox("wood", c + back * 1.25 + Vector3(0, 0.75, 0), Vector3(0.08, 1.0, 0.5) if along_x else Vector3(0.5, 1.0, 0.08))
	_mb.abox("paper", c + Vector3(0, 0.86, 0), Vector3(0.4, 0.04, 0.55))
	if _rng.randf() < 0.35:
		_poly("Lantern_01", c + Vector3(0.25, 0.84, -0.5), _rng.randf() * TAU, 1.6)
	if _rng.randf() < 0.5:
		_mb.abox("paper", c + Vector3(0.2, 0.95, 0.3), Vector3(0.35, 0.2, 0.3))


func _bunk(c: Vector3, along_x: bool) -> void:
	var size := Vector3(0.95, 0.1, 2.0) if along_x else Vector3(2.0, 0.1, 0.95)
	for y: float in [0.45, 1.5]:
		_mb.abox("wood", c + Vector3(0, y, 0), size)
		_mb.abox("cloth", c + Vector3(0, y + 0.12, 0), size * Vector3(0.9, 1.5, 0.95))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_mb.abox("wood", c + Vector3(sx * (size.x / 2.0 - 0.05), 1.0, sz * (size.z / 2.0 - 0.05)), Vector3(0.1, 2.0, 0.1))


func _shelf_rows(inner: Rect2, along_x: bool, h: float) -> void:
	# Estanterías perpendiculares al eje largo, con pasillo central.
	var length := inner.size.x if along_x else inner.size.y
	var width := inner.size.y if along_x else inner.size.x
	var n := maxi(1, int(length / 2.6))
	var sh := minf(h - 0.8, 3.6)
	var half := maxf((width - 2.4) / 2.0, 0.8)
	for k in n:
		var t := (k + 0.5) * length / n
		for lane: float in [-1.0, 1.0]:
			if width < 4.0 and lane > 0.0:
				continue
			var off := (half / 2.0 + 1.2) * lane if width >= 4.0 else 0.0
			var c2 := inner.position + (Vector2(t, width / 2.0 + off) if along_x else Vector2(width / 2.0 + off, t))
			var size := Vector3(0.6, sh, minf(half, width)) if along_x else Vector3(minf(half, width), sh, 0.6)
			var c := Vector3(c2.x, sh / 2.0, c2.y)
			_mb.abox("wood", c, size)
			for y in range(1, int(sh / 0.9) + 1):
				_mb.abox("red" if (k + y) % 3 == 0 else ("paper" if (k + y) % 3 == 1 else "cloth"),
						Vector3(c2.x, y * 0.9 - 0.4, c2.y), size * Vector3(1.08, 0.0, 0.92) + Vector3(0, 0.55, 0))


func _table(c2: Vector2, along_x: bool, length: float) -> void:
	var c := Vector3(c2.x, 0, c2.y)
	var top := Vector3(length, 0.1, 1.6) if along_x else Vector3(1.6, 0.1, length)
	_mb.abox("wood", c + Vector3(0, 0.85, 0), top)
	_mb.abox("wood", c + Vector3(0, 0.4, 0), top * Vector3(0.9, 8.0, 0.5) if along_x else top * Vector3(0.5, 8.0, 0.9))
	var n := int(length / 1.4)
	for k in n:
		var t := -length / 2.0 + (k + 0.5) * length / n
		for sgn: float in [-1.0, 1.0]:
			var p := c + (Vector3(t, 0, sgn * 1.25) if along_x else Vector3(sgn * 1.25, 0, t))
			_chair(p, c + (Vector3(t, 0, 0) if along_x else Vector3(0, 0, t)))
	_deco.abox("fire", c + Vector3(0, 1.1, 0), Vector3(0.1, 0.4, 0.1))


func _round_table(c2: Vector2, radius: float, chairs: int) -> void:
	var c := Vector3(c2.x, 0, c2.y)
	_mb.frustum("wood", c + Vector3(0, 0.78, 0), radius, radius, 0.1, 16)
	_mb.frustum("wood", c, radius * 0.3, radius * 0.2, 0.78, 8)
	for k in chairs:
		var d := Vector2.from_angle(TAU * k / chairs)
		_chair(c + Vector3(d.x, 0, d.y) * (radius + 0.65), c)


## Silla gótica (WoodenChair_01) mirando hacia `to`.
func _chair(p: Vector3, to: Vector3) -> void:
	var v := to - p
	PolyProps.add(_props, "WoodenChair_01", PolyProps.at("WoodenChair_01", p + _mb.offset, atan2(v.x, v.z)))


func _poly(name: String, p: Vector3, yaw := 0.0, scale := 1.0) -> void:
	PolyProps.add(_props, name, PolyProps.at(name, p + _mb.offset, yaw, scale))


func _map_table(c2: Vector2, along_x: bool) -> void:
	var c := Vector3(c2.x, 0, c2.y)
	var size := Vector3(6.0, 0.15, 3.4) if along_x else Vector3(3.4, 0.15, 6.0)
	_mb.abox("wood", c + Vector3(0, 0.95, 0), size)
	_mb.abox("paper", c + Vector3(0, 1.04, 0), size * Vector3(0.92, 0.2, 0.9))
	_mb.abox("wood", c + Vector3(0, 0.45, 0), size * Vector3(0.8, 6.0, 0.6))
	for sgn: float in [-1.0, 1.0]:
		var p := c + (Vector3(sgn * 3.4, 0, 0) if along_x else Vector3(0, 0, sgn * 3.4))
		_mb.frustum("iron", p, 0.25, 0.08, 2.0, 6)
		_deco.abox("fire", p + Vector3(0, 2.15, 0), Vector3(0.15, 0.3, 0.15))
		_anchors.append(p + Vector3(0, 1.5, 0))


## El Consejo: anillo de sitiales altos alrededor de una mesa redonda.
func _council(c2: Vector2, radius: float) -> void:
	var c := Vector3(c2.x, 0, c2.y)
	_mb.frustum("ks_marble", c, radius * 0.45, radius * 0.45, 0.4, 32)
	_mb.frustum("wood", c + Vector3(0, 0.4, 0), radius * 0.32, radius * 0.32, 0.6, 32)
	_mb.frustum("ks_floor", c + Vector3(0, 0.4, 0), radius * 0.18, radius * 0.18, 0.62, 24)
	for k in 12:
		var d := Vector2.from_angle(TAU * k / 12.0)
		var p := c + Vector3(d.x, 0, d.y) * radius * 0.62
		var basis := Basis(Vector3.UP, -d.angle() + PI / 2.0)
		_mb.cube("ks_marble", Transform3D(basis, p + Vector3(0, 0.3, 0)), Vector3(1.0, 0.6, 1.0))
		var back := p + Vector3(d.x, 0, d.y) * 0.5
		_mb.cube("ks_marble", Transform3D(basis, back + Vector3(0, 1.9, 0)), Vector3(1.0, 3.2, 0.25))
		_mb.cube("gold", Transform3D(basis, back + Vector3(0, 3.55, 0)), Vector3(1.1, 0.15, 0.3))


func _bed(inner: Rect2, along_x: bool) -> void:
	var c := Vector3(inner.get_center().x, 0, inner.get_center().y)
	var size := Vector3(3.2, 0.6, 2.4) if along_x else Vector3(2.4, 0.6, 3.2)
	_mb.abox("wood", c + Vector3(0, 0.3, 0), size)
	_mb.abox("red", c + Vector3(0, 0.7, 0), size * Vector3(0.95, 0.4, 0.95))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_mb.abox("wood", c + Vector3(sx * size.x / 2.0, 1.4, sz * size.z / 2.0), Vector3(0.15, 2.8, 0.15))
	_mb.abox("red", c + Vector3(0, 2.85, 0), size * Vector3(1.05, 0.15, 1.05))
	_mb.abox("red", c + Vector3(0, 0.01, 0), Vector3(size.x + 3.0, 0.02, size.z + 3.0))


func _bath(inner: Rect2) -> void:
	var c := Vector3(inner.get_center().x, 0, inner.get_center().y)
	var size := Vector3(minf(inner.size.x * 0.6, 5.0), 0.7, minf(inner.size.y * 0.6, 3.5))
	for sgn: float in [-1.0, 1.0]:
		_mb.abox("ks_marble", c + Vector3(0, 0.35, sgn * size.z / 2.0), Vector3(size.x, 0.7, 0.3))
		_mb.abox("ks_marble", c + Vector3(sgn * size.x / 2.0, 0.35, 0), Vector3(0.3, 0.7, size.z))
	_deco.abox("water", c + Vector3(0, 0.5, 0), Vector3(size.x - 0.3, 0.04, size.z - 0.3))


## Estatua del Lord Legislador sobre su pedestal.
func _statue(c2: Vector2, height: float) -> void:
	var c := Vector3(c2.x, 0, c2.y)
	_mb.abox("ks_marble", c + Vector3(0, 0.6, 0), Vector3(2.4, 1.2, 2.4))
	_mb.abox("ks_trim", c + Vector3(0, 1.3, 0), Vector3(2.0, 0.2, 2.0))
	_mb.frustum("ks_marble", c + Vector3(0, 1.4, 0), 0.75, 0.45, height * 0.55, 8)  # capa
	_mb.frustum("ks_marble", c + Vector3(0, 1.4 + height * 0.55, 0), 0.38, 0.3, height * 0.25, 8)
	_mb.frustum("ks_marble", c + Vector3(0, 1.4 + height * 0.8, 0), 0.24, 0.2, height * 0.18, 8)


func _statue_rows(inner: Rect2, along_x: bool) -> void:
	_rows(inner, along_x, 4.0, func(c: Vector3, _ax: bool) -> void:
		_mb.frustum("ks_marble", c, 0.5, 0.42, 1.3, 8)
		_poly("marble_bust_01", c + Vector3(0, 1.3, 0), _rng.randf_range(-0.4, 0.4) + PI, 2.0))


func _fountain(c2: Vector2, radius: float) -> void:
	var c := Vector3(c2.x, 0, c2.y)
	_mb.arc_wall("ks_marble", c, radius, 0.5, 0.0, 0.7, 0.0, TAU, 24)
	_mb.frustum("ks_floor", c, radius, radius, 0.15, 24)
	_deco.frustum("water", c + Vector3(0, 0.5, 0), radius - 0.2, radius - 0.2, 0.04, 24)
	_mb.frustum("ks_marble", c, 0.5, 0.35, 2.6, 8)
	_mb.frustum("ks_marble", c + Vector3(0, 2.6, 0), 1.3, 0.2, 0.5, 12)


func _altar(inner: Rect2, along_x: bool) -> void:
	var c2 := inner.get_center()
	var far := Vector2(inner.end.x - 1.0, c2.y) if along_x else Vector2(c2.x, inner.position.y + 1.0)
	var c := Vector3(far.x, 0, far.y)
	_mb.abox("ks_marble", c + Vector3(0, 0.15, 0), Vector3(4.0, 0.3, 4.0))
	_mb.abox("ks_marble", c + Vector3(0, 0.75, 0), Vector3(2.4, 0.9, 1.2) if not along_x else Vector3(1.2, 0.9, 2.4))
	_mb.abox("gold", c + Vector3(0, 1.22, 0), Vector3(0.6, 0.04, 0.6))
	for k in 6:
		var off := Vector3(_rng.randf_range(-1.2, 1.2), 0, _rng.randf_range(-1.2, 1.2))
		_mb.frustum("paper", c + off + Vector3(0, 0.3, 0), 0.06, 0.06, 0.35 + _rng.randf() * 0.3, 6)
		_deco.abox("fire", c + off + Vector3(0, 0.75 + _rng.randf() * 0.2, 0), Vector3(0.05, 0.1, 0.05))
	_lights.append([c + Vector3(0, 1.4, 0), Color(1.0, 0.7, 0.4), 6.0, 0.8])


func _weapons(inner: Rect2, along_x: bool) -> void:
	var length := inner.size.x if along_x else inner.size.y
	var n := maxi(1, int(length / 3.0))
	for k in n:
		var t := (k + 0.5) * length / n
		for lane: float in [0.0, 1.0]:
			var p2 := inner.position + (Vector2(t, inner.size.y * lane) if along_x else Vector2(inner.size.x * lane, t))
			var c := Vector3(p2.x, 0, p2.y)
			var bar := Vector3(2.0, 0.08, 0.08) if along_x else Vector3(0.08, 0.08, 2.0)
			_mb.abox("wood", c + Vector3(0, 1.4, 0), bar * Vector3(1, 1.5, 1.5))
			_mb.abox("wood", c + Vector3(0, 0.3, 0), bar * Vector3(1, 1.5, 1.5))
			for w in 5:
				var off := (w - 2) * 0.38
				_mb.abox("iron", c + (Vector3(off, 1.1, 0) if along_x else Vector3(0, 1.1, off)), Vector3(0.05, 2.0, 0.05))
			_anchors.append(c + Vector3(0, 1.2, 0))
			_poly("kite_shield", c + (Vector3(1.2, 0, 0.35) if along_x else Vector3(0.35, 0, 1.2)), (0.0 if along_x else PI / 2.0) + 0.15, 1.0)


func _chests(inner: Rect2, along_x: bool) -> void:
	_rows(inner, along_x, 2.0, func(c: Vector3, ax: bool) -> void: _chest(c, ax))


func _chest(c: Vector3, along_x: bool) -> void:
	_poly("treasure_chest", c, (PI / 2.0 if along_x else 0.0) + (PI if _rng.randf() < 0.5 else 0.0), 1.3)
	_anchors.append(c + Vector3(0, 0.5, 0))  # herrajes de metal
	if _rng.randf() < 0.35:
		_mb.frustum("gold", c + Vector3(0, 0.82, 0), 0.4, 0.1, 0.3, 8)


## Armarios góticos contra los dos extremos de la sala.
func _cabinets(box: Rect2, along_x: bool) -> void:
	if (box.size.x if along_x else box.size.y) < 6.0:
		return
	for sgn: float in [-1.0, 1.0]:
		var c := box.get_center()
		var p := Vector2(c.x + sgn * (box.size.x / 2.0 - 0.75), c.y) if along_x else Vector2(c.x, c.y + sgn * (box.size.y / 2.0 - 0.75))
		var yaw := (-sgn * PI / 2.0) if along_x else (PI if sgn > 0.0 else 0.0)
		_poly("GothicCabinet_01", Vector3(p.x, 0, p.y), yaw)


func _cell(inner: Rect2) -> void:
	var c := Vector3(inner.get_center().x, 0, inner.get_center().y)
	_mb.abox("ks_marble", c + Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 2.0))
	_mb.abox("iron", c + Vector3(0.6, 1.4, 0), Vector3(0.06, 0.06, 1.2))
	_anchors.append(c + Vector3(0.6, 1.4, 0))


## Terrazas del Lord Legislador: arriates de piedra con arbustos oscuros y árboles secos.
func _garden(inner: Rect2, r: Dictionary) -> void:
	var c2: Vector2 = r["c"] if r["circle"] else inner.get_center()
	var radius: float = r["r"] * 0.6 if r["circle"] else minf(inner.size.x, inner.size.y) * 0.3
	var n := 8 if r["circle"] else 12
	for k in n:
		var d := Vector2.from_angle(TAU * k / n)
		var p := Vector3(c2.x + d.x * radius, 0, c2.y + d.y * radius)
		_mb.abox("ks_marble", p + Vector3(0, 0.35, 0), Vector3(1.6, 0.7, 1.6))
		_deco.frustum("plant", p + Vector3(0, 0.7, 0), 0.7, 0.0, 1.4 + _rng.randf() * 0.8, 6)
		if k % 3 == 0:
			_mb.frustum("wood", p + Vector3(0, 0.7, 0), 0.15, 0.08, 2.6, 6)
			for b in 3:
				var bd := Vector2.from_angle(_rng.randf() * TAU)
				_mb.cube("wood", Transform3D(Basis(Vector3(bd.x, 0, bd.y).cross(Vector3.UP).normalized(), 0.8), p + Vector3(bd.x * 0.5, 3.0, bd.y * 0.5)), Vector3(0.08, 1.2, 0.08))


func _dome(r: Dictionary) -> void:
	var c := Vector3(r["c"].x, 0, r["c"].y)
	_mb.frustum("ks_marble", c, 1.4, 1.1, r["h"], 12)
	for k in 8:
		var d := Vector2.from_angle(TAU * k / 8.0)
		var length: float = r["r"] - 1.2
		var p := c + Vector3(d.x, 0, d.y) * (length / 2.0 + 1.1)
		_mb.cube("ks_trim", Transform3D(Basis(Vector3.UP, -d.angle()), p + Vector3(0, r["h"] - 0.4, 0)), Vector3(length, 0.6, 0.6))


## El pozo que baja más allá del Subnivel 3: un agujero sin fondo con una escala de hierro.
func _shaft(inner: Rect2) -> void:
	var c := Vector3(inner.get_center().x, 0, inner.get_center().y)
	_mb.arc_wall("ks_trim", c, 1.6, 0.4, 0.0, 1.0, 0.0, TAU, 16)
	_deco.frustum("ks_ceil", c + Vector3(0, 0.03, 0), 1.4, 1.4, 0.02, 16)
	for k in 4:
		_mb.abox("iron", c + Vector3(0.9, 0.2 + k * 0.4, 0), Vector3(0.05, 0.05, 0.6))
	_anchors.append(c + Vector3(0.9, 0.8, 0))


func _crates(inner: Rect2) -> void:
	var n := int(inner.get_area() / 9.0)
	for k in clampi(n, 2, 30):
		var p := Vector2(_rng.randf_range(inner.position.x, inner.end.x), _rng.randf_range(inner.position.y, inner.end.y))
		if absf(p.x - inner.get_center().x) < 1.2 or absf(p.y - inner.get_center().y) < 1.2:
			continue
		var c := Vector3(p.x, 0, p.y)
		if _rng.randf() < 0.6:
			# Pila de cajas (wooden_crate_01).
			var yaw := _rng.randf() * 0.4
			for k2 in _rng.randi_range(1, 3):
				_poly("wooden_crate_01", c + Vector3(0, k2 * 0.56, 0), yaw + _rng.randf_range(-0.15, 0.15), 1.6)
		else:
			_mb.frustum("wood", c, 0.4, 0.4, 1.0, 10)
			_mb.frustum("iron", c + Vector3(0, 0.2, 0), 0.42, 0.42, 0.06, 10)
			_mb.frustum("iron", c + Vector3(0, 0.75, 0), 0.42, 0.42, 0.06, 10)


func _maze(r: Dictionary) -> void:
	var box: Rect2 = r["box"].grow(-2.0)
	var cell := 3.0
	var nx := int(box.size.x / cell)
	var nz := int(box.size.y / cell)
	if nx < 2 or nz < 2:
		return
	var origin := box.position + (box.size - Vector2(nx, nz) * cell) / 2.0
	var shelves: bool = "shelves" in r["props"]
	var key := "wood" if shelves else "ks_wall"
	var h: float = minf(r["h"] - 0.5, 3.4) if shelves else r["h"]
	# Laberinto perfecto (backtracking) con salidas en el medio de cada lado.
	var visited := PackedByteArray()
	visited.resize(nx * nz)
	var open_e := PackedByteArray()
	open_e.resize(nx * nz)
	var open_s := PackedByteArray()
	open_s.resize(nx * nz)
	var stack := [Vector2i(0, 0)]
	visited[0] = 1
	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var options := []
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.y >= 0 and n.x < nx and n.y < nz and not visited[n.y * nx + n.x]:
				options.append(d)
		if options.is_empty():
			stack.pop_back()
			continue
		var d: Vector2i = options[_rng.randi() % options.size()]
		var n2 := cur + d
		if d == Vector2i(1, 0):
			open_e[cur.y * nx + cur.x] = 1
		elif d == Vector2i(-1, 0):
			open_e[n2.y * nx + n2.x] = 1
		elif d == Vector2i(0, 1):
			open_s[cur.y * nx + cur.x] = 1
		else:
			open_s[n2.y * nx + n2.x] = 1
		visited[n2.y * nx + n2.x] = 1
		stack.append(n2)
	for j in nz:
		for i in nx:
			var p := origin + Vector2(i, j) * cell
			if i < nx - 1 and not open_e[j * nx + i]:
				_mb.abox(key, Vector3(p.x + cell, h / 2.0, p.y + cell / 2.0), Vector3(0.5, h, cell + 0.5))
			if j < nz - 1 and not open_s[j * nx + i]:
				_mb.abox(key, Vector3(p.x + cell / 2.0, h / 2.0, p.y + cell), Vector3(cell + 0.5, h, 0.5))
			# Borde con salidas en el medio de cada lado.
			if j == 0 and i != nx / 2:
				_mb.abox(key, Vector3(p.x + cell / 2.0, h / 2.0, p.y), Vector3(cell + 0.5, h, 0.5))
			if j == nz - 1 and i != nx / 2:
				_mb.abox(key, Vector3(p.x + cell / 2.0, h / 2.0, p.y + cell), Vector3(cell + 0.5, h, 0.5))
			if i == 0 and j != nz / 2:
				_mb.abox(key, Vector3(p.x, h / 2.0, p.y + cell / 2.0), Vector3(0.5, h, cell + 0.5))
			if i == nx - 1 and j != nz / 2:
				_mb.abox(key, Vector3(p.x + cell, h / 2.0, p.y + cell / 2.0), Vector3(0.5, h, cell + 0.5))
	if "chests" in r["props"]:
		for k in 4:
			var p := origin + Vector2(_rng.randi() % nx + 0.5, _rng.randi() % nz + 0.5) * cell
			_mb.abox("wood", Vector3(p.x, 0.35, p.y), Vector3(1.2, 0.7, 0.8))
			_mb.frustum("gold", Vector3(p.x, 0.7, p.y), 0.45, 0.1, 0.35, 8)


func _loot(box: Rect2) -> void:
	_anchors.append(Vector3(box.get_center().x, 1.0, box.get_center().y))


# ------------------------------------------------------------------ Torre del Inquisidor

## La torre: ocho pisos redondos unidos por rampas que suben pegadas al muro, troneras y la
## azotea almenada arriba. La planta de abajo es la sala redonda del Nivel 3 (KredikPlan.TOWER_PX).
const TOWER_R := 9.0
const TOWER_FLOOR := 7.0
const TOWER_NAMES := ["Base de la torre", "Sala de guardia", "Archivo del Inquisidor", "Celdas",
		"Sala de interrogatorio", "Mensajería", "Observatorio", "Cima de la torre"]


func _build_tower() -> void:
	_rng.seed = 99
	var c := Vector3.ZERO
	var floors := TOWER_NAMES.size()
	for f in floors:
		var y := f * TOWER_FLOOR
		_rooms.append({"name": TOWER_NAMES[f]})
		# Suelo: disco central y anillo, con el hueco por donde llega la rampa de abajo.
		# (La planta de abajo es la sala del Nivel 3: suelo y muro con puertas los pone ese nivel.)
		if f > 0:
			_mb.frustum("ks_floor", c + Vector3(0, y - 0.5, 0), TOWER_R * 0.55, TOWER_R * 0.55, 0.5, 24)
		var below := 0.0 if (f - 1) % 2 == 0 else PI
		for k in (16 if f > 0 else 0):
			var a0 := TAU * k / 16.0
			var a1 := TAU * (k + 1) / 16.0
			var mid := (a0 + a1) / 2.0
			if f > 0 and angle_difference(below + 1.6, mid) >= 0.0 and angle_difference(mid, below + 2.7) >= 0.0:
				continue
			_mb.arc_wall("ks_floor", c + Vector3(0, y - 0.5, 0), TOWER_R * 0.775, TOWER_R * 0.45 + 1.2, 0.0, 0.5, a0, a1, 1)
		# Muro con troneras.
		var top := TOWER_FLOOR if f < floors - 1 else 1.4
		for k in (24 if f > 0 else 0):
			var a0 := TAU * k / 24.0
			var a1 := TAU * (k + 1) / 24.0
			if f < floors - 1 and k % 3 == 1:
				_mb.arc_wall("ks_wall", c, TOWER_R + 0.6, 1.2, y, y + 2.0, a0, a1, 1)
				_mb.arc_wall("ks_wall", c, TOWER_R + 0.6, 1.2, y + 4.2, y + top, a0, a1, 1)
				_mb.arc_wall("ks_wall", c, TOWER_R + 0.6, 1.2, y + 2.0, y + 4.2, a0, a0 + 0.1, 1)
				_mb.arc_wall("ks_wall", c, TOWER_R + 0.6, 1.2, y + 2.0, y + 4.2, a1 - 0.1, a1, 1)
				_deco.arc_wall("ks_glass", c, TOWER_R + 0.6, 0.1, y + 2.0, y + 4.2, a0 + 0.1, a1 - 0.1, 1)
			else:
				_mb.arc_wall("ks_wall", c, TOWER_R + 0.6, 1.2, y, y + top, a0, a1, 1)
		if f > 0:
			_mb.arc_wall("ks_trim", c, TOWER_R + 0.5, 1.5, y - 0.2, y + 0.3, 0.0, TAU, 32)
		# Rampa al piso siguiente, pegada al muro (tramos inclinados).
		if f < floors - 1:
			var a := 0.0 if f % 2 == 0 else PI
			var steps := 16
			var span := 2.6
			var rr := TOWER_R - 1.4
			for k in steps:
				var b0 := a + span * k / steps
				var b1 := a + span * (k + 1) / steps
				var h0 := y + TOWER_FLOOR * k / steps
				var h1 := y + TOWER_FLOOR * (k + 1) / steps
				var p0 := Vector3(cos(b0) * rr, h0, sin(b0) * rr)
				var p1 := Vector3(cos(b1) * rr, h1, sin(b1) * rr)
				var along := (p1 - p0).normalized()
				var out := Vector3(cos((b0 + b1) / 2.0), 0, sin((b0 + b1) / 2.0))
				var upv := out.cross(along).normalized()
				if upv.y < 0.0:
					upv = -upv
				var xf := Transform3D(Basis(along, upv, out), (p0 + p1) / 2.0)
				_deco.cube("ks_marble", xf.translated(-upv * 0.25), Vector3(p0.distance_to(p1) + 0.05, 0.5, 2.6))
				_ramps.append([xf.translated(-upv * 0.05), Vector3(p0.distance_to(p1) + 0.05, 0.1, 2.6)])
			var end := a + span
			var tangent := Vector3(-sin(end), 0, cos(end))
			_ramps.append([Transform3D(Basis(tangent, Vector3.UP, tangent.cross(Vector3.UP)), Vector3(cos(end) * rr, y + TOWER_FLOOR - 0.05, sin(end) * rr) + tangent * 0.75), Vector3(1.5, 0.1, 2.6)])
		# Mobiliario de cada piso (desplazado a su altura) y su lámpara.
		var first := _anchors.size()
		_mb.offset = Vector3(0, y, 0)
		var mid2 := Vector2(-2.5, 0.0)
		match f:
			1:
				_weapons(Rect2(mid2 - Vector2(2, 1.5), Vector2(4, 3)), true)
			2:
				_shelf_rows(Rect2(mid2 - Vector2(2.5, 2), Vector2(5, 4)), true, 4.0)
			3:
				_cell(Rect2(mid2 - Vector2(1, 1), Vector2(2, 2)))
			4:
				_table(mid2, true, 3.0)
			5:
				_desk(Vector3(mid2.x, 0, mid2.y), true)
			6:
				_map_table(mid2, true)
		_mb.offset = Vector3.ZERO
		for k in range(first, _anchors.size()):
			_anchors[k] += Vector3(0, y, 0)
		if f < floors - 1:
			_lights.append([c + Vector3(0, y + 4.5, 0), Color(1.0, 0.6, 0.3), 12.0, 1.4])
			_mb.abox("iron", c + Vector3(0, y + 5.2, 0), Vector3(0.6, 0.6, 0.6))
			_deco.abox("fire", c + Vector3(0, y + 5.15, 0), Vector3(0.35, 0.4, 0.35))
			_anchors.append(c + Vector3(0, y + 5.2, 0))
	# Almenas de la azotea.
	var y_top := (floors - 1) * TOWER_FLOOR
	for k in 16:
		if k % 2 == 0:
			var a0 := TAU * k / 16.0
			_mb.arc_wall("ks_wall", c, TOWER_R + 0.6, 1.2, y_top + 1.4, y_top + 2.6, a0, a0 + TAU / 16.0, 1)
