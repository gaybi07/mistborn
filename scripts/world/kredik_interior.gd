class_name KredikInterior
extends Node3D
## Los niveles de Kredik Shaw apilados dentro de la fortaleza (ver KredikLevel y KredikPlan): del
## Subnivel 3, en la roca bajo la ciudad, al Nivel 5, y la Torre del Inquisidor que sube desde el
## Nivel 3. Se entra caminando por la Gran Entrada, por los túneles de los subniveles (al oeste) o
## volando a los patios y terrazas; las escaleras son de verdad.
## Arriba a la izquierda, el nivel y la sala donde está el jugador; bajo techo casi no hay bruma.
## Por los niveles hay monedas y frascos, y buen equipo (casi todo de metal) en el Salón del Trono.
## De lejos solo se dibuja una cáscara con la misma silueta (_proxy): los volúmenes de cada nivel y la
## torre. Al acercarse al recinto (NEAR m) aparece todo. La colisión está siempre.

## Orden en que se arman: cada nivel de arriba se apoya en el de abajo (KredikLevel._prune).
const ORDER := ["ground", "l2", "l3", "l4", "l5", "sub1", "sub2", "sub3"]
const LIFT := 0.05  # el suelo de la planta baja, apenas sobre la roca de la meseta

static var _parapets: Array = []  # [malla, forma] del pretil de los tejados (se arma una vez)
static var _proxy_mesh: ArrayMesh
## Distancia (m) de la cámara al borde del recinto a partir de la cual se ve solo la cáscara.
const NEAR := 40.0

var _detail: Array[Node3D] = []  # lo que se oculta de lejos
var _proxy: MeshInstance3D
var _near := true

var _label: Label
var _sheltered := false


func _ready() -> void:
	for lvl: String in ORDER:
		var node := KredikLevel.new()
		node.level = lvl
		node.position.y = KredikPlan.FLOOR[lvl] + LIFT
		add_child(node)
		_detail.append(node)
	var t := KredikPlan.m(KredikPlan.TOWER_PX)
	var tower := KredikLevel.new()
	tower.level = "tower"
	tower.position = Vector3(t.x, KredikPlan.FLOOR["l3"] + LIFT, t.y)
	add_child(tower)
	_detail.append(tower)
	_add_parapets()
	var loot := Node3D.new()
	add_child(loot)
	_detail.append(loot)
	_scatter(loot)
	_proxy = MeshInstance3D.new()
	_proxy.mesh = _build_proxy()
	var mats := KredikLevel.materials()
	for i in _proxy.mesh.get_surface_count():
		_proxy.set_surface_override_material(i, mats[_proxy.mesh.surface_get_name(i)])
	_fade_at_ring(_proxy)
	add_child(_proxy)
	_set_near(false)
	var layer := CanvasLayer.new()
	layer.layer = 11
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 40)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_constant_override("outline_size", 5)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.modulate = Color(0.85, 0.82, 0.75)
	layer.add_child(_label)


## Pretil almenado en los bordes de los tejados: donde lo más alto de una celda (techo de una
## sala o muro macizo, en cualquier nivel) queda más de 1 m por encima del de al lado.
func _add_parapets() -> void:
	if _parapets.is_empty():
		var top := PackedFloat32Array()
		top.resize(KredikLevel.NX * KredikLevel.NZ)
		var roofed := PackedByteArray()
		roofed.resize(top.size())
		for lvl: String in ["ground", "l2", "l3", "l4", "l5"]:
			var c := KredikLevel.cached(lvl)
			var grid: PackedInt32Array = c["grid"]
			var y0: float = KredikPlan.FLOOR[lvl] + LIFT
			for idx in grid.size():
				var id := grid[idx]
				var y := -1.0
				if id >= 0:
					var room: Dictionary = c["rooms"][id]
					var bare: bool = room["open"] or room["kind"] == "tower"  # la torre sigue hacia arriba
					y = y0 if bare else y0 + room["h"] + 0.7
				elif id == KredikLevel.SOLID:
					y = y0 + KredikPlan.LH
				if y > top[idx]:
					top[idx] = y
					roofed[idx] = 1 if id == KredikLevel.SOLID or (id >= 0 and y > y0) else 0
		var mb := MeshBuilder.new()
		var nx := KredikLevel.NX
		for j in KredikLevel.NZ:
			for i in nx:
				var t := top[j * nx + i]
				if not roofed[j * nx + i]:
					continue
				var c := Vector3(KredikLevel.X0 + i + 0.5, t, KredikLevel.Z0 + j + 0.5)
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n := Vector2i(i, j) + d
					var low := n.x < 0 or n.y < 0 or n.x >= nx or n.y >= KredikLevel.NZ or top[n.y * nx + n.x] < t - 1.0
					if not low:
						continue
					var along := Vector3(absf(d.y), 0, absf(d.x))
					var p := c + Vector3(d.x, 0, d.y) * 0.25
					var size := along * 1.0 + Vector3(absf(d.x), 0, absf(d.y)) * 0.5
					mb.abox("ks_wall", p + Vector3(0, 0.5, 0), size + Vector3(0, 1.0, 0))
					if (i + j) % 2 == 0:
						mb.abox("ks_wall", p + Vector3(0, 1.4, 0), size * Vector3(0.6, 0, 0.6).max(Vector3(0.5, 0, 0.5)) + Vector3(0, 0.8, 0))
		var mesh := mb.commit()
		_parapets = [mesh, mesh.create_trimesh_shape()]
	var body := StaticBody3D.new()
	body.collision_layer = Props.LAYER_WORLD
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	col.shape = _parapets[1]
	body.add_child(col)
	var mi := MeshInstance3D.new()
	mi.mesh = _parapets[0]
	var mats := KredikLevel.materials()
	for s in mi.mesh.get_surface_count():
		mi.set_surface_override_material(s, mats[mi.mesh.surface_get_name(s)])
	_fade_at_ring(mi)
	body.add_child(mi)
	add_child(body)


## [nivel, sala, bajo techo] donde está un punto (relativo a la fortaleza); nivel "" si está afuera.
static func where(p: Vector3) -> Array:
	var tp := Vector2(p.x, p.z) - KredikPlan.m(KredikPlan.TOWER_PX)
	var ty := p.y - KredikPlan.FLOOR["l3"]
	var floors := KredikLevel.TOWER_NAMES.size()
	if tp.length() < KredikLevel.TOWER_R and ty > KredikLevel.TOWER_FLOOR - 0.5 and ty < KredikLevel.TOWER_FLOOR * floors:
		var f := clampi(int((ty + 0.5) / KredikLevel.TOWER_FLOOR), 0, floors - 1)
		return ["tower", KredikLevel.TOWER_NAMES[f], f < floors - 1]
	for lvl: String in ORDER:
		var y0: float = KredikPlan.FLOOR[lvl]
		if p.y < y0 - 0.5 or p.y >= y0 + KredikPlan.LH - 0.5:
			continue
		var c := KredikLevel.cached(lvl)
		if c.is_empty():
			return ["", "", false]
		var at := lvl
		var id := KredikLevel.cell_at(c["grid"], Vector2(p.x, p.z))
		if id == KredikLevel.HOLE:
			# Dentro de una sala de doble altura de la planta baja.
			at = "ground"
			c = KredikLevel.cached(at)
			id = KredikLevel.cell_at(c["grid"], Vector2(p.x, p.z))
		if id < 0:
			return ["", "", false]
		var room: Dictionary = c["rooms"][id]
		return [at, room["name"], not room["open"]]
	return ["", "", false]


## La cáscara de lejos: por nivel, los rectángulos de celdas techadas (salas, muros, el hueco de las
## de doble altura) como cajas de piso a techo, el suelo de las terrazas y la torre como un cilindro.
static func _build_proxy() -> ArrayMesh:
	if _proxy_mesh:
		return _proxy_mesh
	var mb := MeshBuilder.new()
	for lvl: String in ["ground", "l2", "l3", "l4", "l5"]:
		var c := KredikLevel.cached(lvl)
		var grid: PackedInt32Array = c["grid"]
		var rooms: Array = c["rooms"]
		var y0: float = KredikPlan.FLOOR[lvl] + LIFT
		var solid := func(id: int) -> bool:
			return id == KredikLevel.SOLID or id == KredikLevel.ROUND or id == KredikLevel.HOLE or (id >= 0 and not rooms[id]["open"])
		var open := func(id: int) -> bool:
			return id >= 0 and rooms[id]["open"]
		for rc: Rect2 in _greedy(grid, solid):
			mb.abox("ks_wall", Vector3(rc.get_center().x, y0 + KredikPlan.LH / 2.0 - 0.1, rc.get_center().y), Vector3(rc.size.x, KredikPlan.LH - 0.1, rc.size.y))
		for rc: Rect2 in _greedy(grid, open):
			mb.abox("ks_court", Vector3(rc.get_center().x, y0 - 0.5, rc.get_center().y), Vector3(rc.size.x, 1.0, rc.size.y))
	var t := KredikPlan.m(KredikPlan.TOWER_PX)
	var floors := KredikLevel.TOWER_NAMES.size()
	mb.frustum("ks_wall", Vector3(t.x, KredikPlan.FLOOR["l3"], t.y), KredikLevel.TOWER_R + 1.2, KredikLevel.TOWER_R + 1.2, KredikLevel.TOWER_FLOOR * (floors - 1) + 2.6, 24)
	_proxy_mesh = mb.commit()
	return _proxy_mesh


## Rectángulos que cubren las celdas que cumplen `pred` (fusión voraz, como KredikLevel._greedy).
static func _greedy(grid: PackedInt32Array, pred: Callable) -> Array[Rect2]:
	var nx := KredikLevel.NX
	var nz := KredikLevel.NZ
	var used := PackedByteArray()
	used.resize(nx * nz)
	var out: Array[Rect2] = []
	for j in nz:
		for i in nx:
			if used[j * nx + i] or not pred.call(grid[j * nx + i]):
				continue
			var w := 1
			while i + w < nx and not used[j * nx + i + w] and pred.call(grid[j * nx + i + w]):
				w += 1
			var d := 1
			var grow := true
			while grow and j + d < nz:
				for k in w:
					if used[(j + d) * nx + i + k] or not pred.call(grid[(j + d) * nx + i + k]):
						grow = false
						break
				if grow:
					d += 1
			for dz in d:
				for k in w:
					used[(j + dz) * nx + i + k] = 1
			out.append(Rect2(KredikLevel.X0 + i, KredikLevel.Z0 + j, w, d))
	return out


## Más allá del anillo de bruma (Art.MIST_RING) no se dibuja: desaparece como el resto de Kredik Shaw.
static func _fade_at_ring(g: GeometryInstance3D) -> void:
	g.visibility_range_end = Art.MIST_RING
	g.visibility_range_end_margin = 150.0
	g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _set_near(near: bool) -> void:
	_near = near
	for n in _detail:
		n.visible = near
	_proxy.visible = not near


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var l := to_local(cam.global_position)
		var half := CityPlan.HILL_HALF + Vector2(NEAR, NEAR)
		var near := absf(l.x) < half.x and absf(l.z) < half.y
		if near != _near:
			_set_near(near)
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return
	var w := where(to_local(player.global_position))
	_label.text = KredikPlan.LEVEL_NAMES[w[0]] + "\n" + w[1] if w[0] != "" else ""
	if w[2] != _sheltered:
		_sheltered = w[2]
		var weather := get_tree().get_first_node_in_group(&"weather") as Weather
		if weather:
			weather.sheltered = _sheltered
			weather.apply(false)


func _scatter(parent: Node3D) -> void:
	for lvl: String in ORDER:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(lvl) + 7
		var grid: PackedInt32Array = KredikLevel.cached(lvl)["grid"]
		var y: float = KredikPlan.FLOOR[lvl] + LIFT
		var spots: Array[Vector3] = []
		for spec: Array in KredikPlan.spaces(lvl):
			if spec[1] in ["hall", "corridor", "room", "court"] and spec[2].size() == 4:
				var r := KredikPlan.rect(spec[2]).grow(-2.0)
				if r.size.x > 2.0 and r.size.y > 2.0:
					var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
					if KredikLevel.cell_at(grid, p) >= 0:
						spots.append(Vector3(p.x, y + 0.3, p.y))
		spots.shuffle()
		for k in mini(spots.size(), 14):
			if k % 3 == 0:
				var v := Vial.new()
				v.position = spots[k] + Vector3(0, 0.7, 0)
				parent.add_child(v)
			else:
				for c in 4:
					var coin := Props.coin()
					coin.position = spots[k] + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
					parent.add_child(coin)
	var throne := KredikPlan.rect([612, 28, 798, 160])
	var c := throne.get_center()
	var y0: float = KredikPlan.FLOOR["ground"] + LIFT
	var loot := {"steel_sword": Vector3(c.x - 5, y0 + 1.2, throne.position.y + 9), "chainmail": Vector3(c.x + 5, y0 + 1.2, throne.position.y + 9),
			"large_vials": Vector3(c.x - 8, y0, c.y + 4), "steel_daggers": Vector3(c.x + 8, y0, c.y + 4), "nailed_boots": Vector3(c.x, y0, c.y + 8)}
	for id: String in loot:
		var pickup := ItemPickup.new()
		pickup.item_id = id
		pickup.position = loot[id]
		parent.add_child(pickup)
