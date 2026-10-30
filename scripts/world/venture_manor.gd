class_name VentureManor
extends Building
## Mansión de la Casa Venture, según los planos. Tres modos:
##  - en la ciudad (por defecto): terreno de CITY_LOT con muralla, verja, garita, guardias y jardín,
##    y la mansión a media escala (un hijo en modo facade) cuya puerta lleva al interior;
##  - facade: solo el edificio por fuera, sin salas (lo que se ve desde la ciudad);
##  - interior: la mansión entera a tamaño real, en su propia escena (VentureInterior), con todas
##    las salas; su puerta principal vuelve a la ciudad.
## La mansión entera: bloque de piedra oscura de 68 × 80 m alrededor
## de un patio con fuente, cuatro torres redondas en las esquinas con agujas de pizarra, todo
## sobre un zócalo de 2,4 m con escalinata. Terreno de 120 × 150 m con muralla, verja y garita,
## jardín delantero con fuente y paseo de farolas, y jardín trasero.
## Planta baja: gran salón (doble altura, escalera principal), galería de murales, cuarto de
## guardia, comedor noble, sala, biblioteca, estudio privado, cocina, salón de baile (doble altura,
## con balcón) y el claustro que rodea el patio.
## Primer piso: entreplanta del gran salón, pasillo alrededor del patio, balcón del salón de baile,
## cámara del señor Venture, vestidor, suite y dormitorio de huéspedes.
## Torre noreste: escalera hasta el mirador con el telescopio. Sótano: bodega de vinos y la cámara
## de seguridad (con E se abre su puerta). El segundo piso no se visita (solo se ve desde fuera).
## Coordenadas locales: origen en el centro del terreno, +Z al sur (la verja), +X al este.

const POS := Vector2(-195, -261)  ## centro del terreno en la ciudad
const LOT := Vector2(120, 150)  ## terreno de la mansión entera: ancho (x) y fondo (z)
const CITY_LOT := Vector2(70, 92)  ## terreno en la ciudad (ver CityPlan.VENTURE)
const CITY_SCALE := 0.5  ## escala de la mansión que se ve en la ciudad
const FACADE_Z := -6.0  ## dónde va el centro de esa mansión dentro del terreno de la ciudad
const INTERIOR_SCENE := "res://scenes/venture_manor.tscn"
## Donde aparece el jugador al entrar: en el gran salón, de cara a la escalera.
const ENTRANCE := Vector3(0, 2.6, 24)

const F := 2.4  ## suelo de la planta baja (encima del zócalo)
const Y1 := F + 8.0  ## suelo del primer piso
const Y2 := Y1 + 6.0  ## suelo del segundo piso
const EAVE := Y2 + 5.0  ## alero
const HX := 34.0  ## medio ancho del bloque
const ZN := -50.0  ## fachada norte
const ZS := 30.0  ## fachada sur (entrada)
const WT := 1.2  ## grosor de los muros exteriores
const IW := 0.6  ## grosor de los tabiques
const COURT := Rect2(-15, -24, 30, 26)  ## patio (x, z)
const BASE_Y := F - 4.0  ## suelo del sótano
const TOWER_R := 9.0
const TOWER_TOP := 34.0
const TOWERS := [Vector2(-38, -54), Vector2(38, -54), Vector2(-38, 34), Vector2(38, 34)]
const CLIMB_TOWER := 1  ## la del noreste se sube hasta el mirador
const TOWER_LEVELS := [F, Y1, Y2, Y2 + 6.0, Y2 + 12.0]
const SLOPE := 41.0  ## grados de las escaleras (menos que floor_max_angle)
const STAIR_DZ := [-1.4, 1.4]  ## bandas de los tramos de la torre (ida y vuelta), respecto al centro

var facade := false
var interior := false
var _stained: Array[Material] = []
## Texturas pintadas a mano (en código), compartidas: clave -> ImageTexture.
static var _textures := {}
var _vault: Node3D
var _vault_zone: Interactable
var _vault_open := false


## Donde aparece el jugador al salir a la ciudad: al pie de la escalinata de la mansión chica.
static func city_exit() -> Vector3:
	return Vector3(POS.x, 0.6, POS.y + FACADE_Z + (ZS + 11.0) * CITY_SCALE)


func _ready() -> void:
	_rng.seed = 1714
	_make_materials()
	_venture_materials()
	if not facade and not interior:
		_build_city_lot()
		return
	_build_podium()
	_build_shell()
	_build_roofs()
	for i in TOWERS.size():
		_tower(TOWERS[i], interior and i == CLIMB_TOWER)
	_build_entrance()
	if facade:
		_build_courtyard()
		return
	_build_lot(LOT, ZS + 8.0)
	_build_scene_ground()
	_build_ground_floor()
	_build_first_floor()
	_build_courtyard()
	_build_basement()
	_clear_fog(Vector3(HX * 2.0, EAVE - BASE_Y + 1.0, ZS - ZN), Vector3(0, (EAVE + BASE_Y) / 2.0, (ZS + ZN) / 2.0))
	var t: Vector2 = TOWERS[CLIMB_TOWER]
	_clear_fog(Vector3(16, TOWER_TOP, 16), Vector3(t.x, TOWER_TOP / 2.0, t.y))
	_indoor_zone(Vector3(HX * 2.0 - 2.0, EAVE - BASE_Y, ZS - ZN - 2.0), Vector3(0, (EAVE + BASE_Y) / 2.0, (ZS + ZN) / 2.0))
	_indoor_zone(Vector3(16, TOWER_LEVELS[4], 16), Vector3(t.x, TOWER_LEVELS[4] / 2.0, t.y))


# ---------------------------------------------------------------- Materiales

func _venture_materials() -> void:
	var dark: ShaderMaterial = (_m["wall"] as ShaderMaterial).duplicate()
	dark.set_shader_parameter(&"stone_color", Color(0.2, 0.19, 0.21))
	dark.set_shader_parameter(&"ash_amount", 0.35)
	_m["dark_stone"] = dark
	_m["slate"] = _noise_material(Color(0.07, 0.08, 0.1), Color(0.17, 0.18, 0.21), 0.5)
	_m["wall_in"] = _noise_material(Color(0.3, 0.22, 0.17), Color(0.48, 0.38, 0.3), 0.3)
	_m["mural"] = _noise_material(Color(0.25, 0.1, 0.06), Color(0.66, 0.5, 0.3), 0.15)
	_m["hedge"] = _noise_material(Color(0.07, 0.09, 0.05), Color(0.17, 0.19, 0.1), 0.8)
	_m["carpet"] = Props.material(Color(0.3, 0.035, 0.03), 0.0, 1.0)
	_m["gold"] = Props.material(Color(0.62, 0.46, 0.2), 0.8, 0.35)
	_m["oak"] = _planks(Color(0.2, 0.11, 0.07), 0.5)
	for k in 4:
		_stained.append(_tex_mat(_stained_tex(k), 0.45))
	# Mármol en damero: losas de 1,2 m.
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	for p in [Vector2i(0, 0), Vector2i(1, 1)]:
		img.set_pixelv(p, Color(0.42, 0.4, 0.38))
	for p in [Vector2i(1, 0), Vector2i(0, 1)]:
		img.set_pixelv(p, Color(0.09, 0.08, 0.09))
	var marble := StandardMaterial3D.new()
	marble.albedo_texture = ImageTexture.create_from_image(img)
	marble.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	marble.uv1_triplanar = true
	marble.uv1_world_triplanar = true
	marble.uv1_scale = Vector3.ONE / 2.4
	marble.roughness = 0.25
	_m["marble"] = marble


# ---------------------------------------------------------------- Piezas

## Muro recto (a y b en XZ, alineados con un eje) entre y0 e y1, con huecos de puerta:
## doors = [[posición a lo largo del eje, ancho, alto desde y0]].
## panel: arrimadero de roble de 1,3 m con moldura dorada a las dos caras (en las salas).
func _wall(a: Vector2, b: Vector2, y0: float, y1: float, thick: float, mat: Material, doors := [], panel := false) -> void:
	var along_x := is_equal_approx(a.y, b.y)
	var lo := minf(a.x, b.x) if along_x else minf(a.y, b.y)
	var hi := maxf(a.x, b.x) if along_x else maxf(a.y, b.y)
	var cross := a.y if along_x else a.x
	var parts := []  # [u0, u1, y0, y1]
	var cur := lo
	var sorted := doors.duplicate()
	sorted.sort_custom(func(p, q): return p[0] < q[0])
	for d in sorted:
		var g0: float = d[0] - d[1] / 2.0
		var g1: float = d[0] + d[1] / 2.0
		if g1 <= lo or g0 >= hi:
			continue
		parts.append([cur, g0, y0, y1])
		parts.append([g0, g1, minf(y0 + d[2], y1), y1])
		cur = g1
	parts.append([cur, hi, y0, y1])
	for p in parts:
		if p[1] - p[0] < 0.01 or p[3] - p[2] < 0.01:
			continue
		if along_x:
			_span(Vector3(p[0], p[2], cross - thick / 2.0), Vector3(p[1], p[3], cross + thick / 2.0), mat, true)
		else:
			_span(Vector3(cross - thick / 2.0, p[2], p[0]), Vector3(cross + thick / 2.0, p[3], p[1]), mat, true)
		if panel and is_equal_approx(p[2], y0):
			for band in [[0.0, 1.3, thick + 0.12, _m["oak"]], [1.3, 1.4, thick + 0.18, _m["gold"]]]:
				var t: float = band[2] / 2.0
				if along_x:
					_span(Vector3(p[0], y0 + band[0], cross - t), Vector3(p[1], y0 + band[1], cross + t), band[3])
				else:
					_span(Vector3(cross - t, y0 + band[0], p[0]), Vector3(cross + t, y0 + band[1], p[1]), band[3])


## Partes de un segmento recto que quedan fuera de las torres (para cortar los muros del bloque).
func _outside_towers(a: Vector2, b: Vector2) -> Array:
	var keep := [[0.0, 1.0]]
	var d := b - a
	for c: Vector2 in TOWERS:
		var r := TOWER_R - 0.5
		var f := a - c
		var qa := d.dot(d)
		var qb := 2.0 * f.dot(d)
		var disc := qb * qb - 4.0 * qa * (f.dot(f) - r * r)
		if disc <= 0.0:
			continue
		var t0 := (-qb - sqrt(disc)) / (2.0 * qa)
		var t1 := (-qb + sqrt(disc)) / (2.0 * qa)
		var next := []
		for k in keep:
			if t1 <= k[0] or t0 >= k[1]:
				next.append(k)
				continue
			if t0 > k[0]:
				next.append([k[0], t0])
			if t1 < k[1]:
				next.append([t1, k[1]])
		keep = next
	var out := []
	for k in keep:
		out.append([a + d * k[0], a + d * k[1]])
	return out


func _inside_tower(p: Vector2, margin := 0.0) -> bool:
	return TOWERS.any(func(c: Vector2) -> bool: return p.distance_to(c) < TOWER_R + margin)


## Ventana gótica: vitral a las dos caras del muro (normal: hacia fuera), alféizar, jambas,
## parteluz y arco apuntado. drapes: cortinas rojas con su barra por dentro.
func _win(center: Vector3, normal: Vector3, w: float, h: float, depth: float, drapes := false) -> void:
	var along := Vector3.UP.cross(normal)
	var basis := Basis(along, Vector3.UP, normal)
	var glass: Material = _stained[_rng.randi() % _stained.size()]
	_quad(Vector2(w, h), center + normal * (depth / 2.0 + 0.03), basis, glass)
	_quad(Vector2(w, h), center - normal * (depth / 2.0 + 0.03), Basis(-along, Vector3.UP, -normal), glass)
	if drapes:
		var inside := center - normal * (depth / 2.0 + 0.12)
		for s in [-1.0, 1.0]:
			_box(Vector3(w * 0.4, h + 0.9, 0.1), inside + along * s * (w / 2.0 + w * 0.12) + Vector3.UP * 0.25, _m["carpet"], false, basis)
		_box(Vector3(w * 1.9, 0.07, 0.07), inside + Vector3.UP * (h / 2.0 + 0.72) - normal * 0.05, _m["gold"], false, basis)
	var face := center + normal * (depth / 2.0 + 0.05)
	_box(Vector3(w + 0.4, 0.18, 0.3), face + Vector3.UP * -(h / 2.0 + 0.09), _m["trim"], false, basis)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.2, h, 0.2), face + along * s * (w / 2.0 + 0.1), _m["trim"], false, basis)
	_box(Vector3(0.1, h, 0.12), face, _m["iron"], false, basis)
	var arch := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(w + 0.6, w * 0.7, 0.3)
	arch.mesh = prism
	arch.material_override = _m["trim"]
	arch.transform = Transform3D(basis, face + Vector3.UP * (h / 2.0 + w * 0.35))
	add_child(arch)


## Tramo de escalera recto: rampa invisible para andar (SLOPE grados) y peldaños para verla.
## Con solid los peldaños bajan hasta base_y (escalera maciza); si no, son una losa colgada.
func _flight(bottom: Vector3, top: Vector3, width: float, base_y: float, mat: Material, carpet := false, solid := false) -> void:
	var flat := Vector3(top.x - bottom.x, 0, top.z - bottom.z)
	var run := flat.length()
	var dir := flat / run
	var rise := top.y - bottom.y
	var slope := atan2(rise, run)
	var basis := Basis(Vector3.UP, atan2(dir.x, dir.z)) * Basis(Vector3.RIGHT, -slope)
	var ramp := StaticBody3D.new()
	ramp.collision_layer = Props.LAYER_WORLD
	ramp.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.1, sqrt(run * run + rise * rise) + 0.2)
	col.shape = shape
	col.transform = Transform3D(basis, (bottom + top) / 2.0 - basis.y * 0.05)
	ramp.add_child(col)
	add_child(ramp)
	var n := ceili(rise / 0.2)
	var yaw_basis := Basis(Vector3.UP, atan2(dir.x, dir.z))
	for i in n:
		var y := bottom.y + rise * (i + 1) / n
		var c := bottom + dir * run * (i + 0.5) / n
		var y0 := base_y if solid else maxf(base_y, y - 0.45)
		_box(Vector3(width, y - y0, run / n + 0.02), Vector3(c.x, (y + y0) / 2.0, c.z), mat, false, yaw_basis)
		if carpet:
			_box(Vector3(width * 0.6, 0.03, run / n + 0.03), Vector3(c.x, y + 0.015, c.z), _m["carpet"], false, yaw_basis)


## Suelo redondo (de tiras) con un hueco rectangular para la escalera que llega desde abajo.
func _round_floor(c: Vector2, y: float, r: float, mat: Material, hole := Rect2()) -> void:
	var bands := [[-r, r]]
	if hole.size != Vector2.ZERO:
		bands = [[-r, hole.position.y - c.y], [hole.position.y - c.y, hole.end.y - c.y], [hole.end.y - c.y, r]]
	for bi in bands.size():
		var z0: float = bands[bi][0]
		var z1: float = bands[bi][1]
		var n := maxi(ceili((z1 - z0) / 0.8), 1)
		for k in n:
			var a := z0 + (z1 - z0) * k / n
			var b := z0 + (z1 - z0) * (k + 1) / n
			var edge := maxf(absf(a), absf(b)) if signf(a) == signf(b) else 0.0
			var half := sqrt(maxf(r * r - edge * edge, 0.0))
			if half < 0.2:
				continue
			if bi == 1:
				var hx0 := hole.position.x - c.x
				var hx1 := hole.end.x - c.x
				if hx0 > -half:
					_span(Vector3(c.x - half, y - 0.4, c.y + a), Vector3(c.x + hx0, y, c.y + b), mat, true)
				if hx1 < half:
					_span(Vector3(c.x + hx1, y - 0.4, c.y + a), Vector3(c.x + half, y, c.y + b), mat, true)
			else:
				_span(Vector3(c.x - half, y - 0.4, c.y + a), Vector3(c.x + half, y, c.y + b), mat, true)


## Disco macizo (cilindro con colisión).
func _disc(c: Vector2, y0: float, y1: float, r: float, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Props.LAYER_WORLD
	body.collision_mask = 0
	body.position = Vector3(c.x, (y0 + y1) / 2.0, c.y)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = y1 - y0
	col.shape = shape
	body.add_child(col)
	add_child(body)
	var mi := _cyl(r, y1 - y0, Vector3.ZERO, mat, Basis(), body)
	(mi.mesh as CylinderMesh).radial_segments = 32


## Barandilla de piedra entre a y b (puede subir con una escalera).
func _railing(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var flat := Vector2(d.x, d.z).length()
	var basis := Basis(Vector3.UP, atan2(d.x, d.z)) * Basis(Vector3.RIGHT, -atan2(d.y, flat))
	_box(Vector3(0.3, 1.1, d.length()), (a + b) / 2.0 + Vector3.UP * 0.55, _m["trim"], true, basis)
	_box(Vector3(0.45, 0.12, d.length()), (a + b) / 2.0 + Vector3.UP * 1.12, _m["trim"], false, basis)


## Araña de velas del MegaKit con su luz.
func _chandelier(pos: Vector3, size: float, energy: float, reach: float) -> void:
	_mega("Chandelier", pos - Vector3.UP * size, _rng.randf() * TAU, size)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.42)
	light.light_energy = energy
	light.omni_range = reach
	light.position = pos - Vector3.UP * (size * 0.8)
	add_child(light)


func _light(pos: Vector3, energy: float, reach: float, color := Color(1.0, 0.68, 0.38)) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.position = pos
	add_child(light)
	return light


## Chimenea de piedra con fuego contra un muro (normal: hacia la sala).
func _fireplace(pos: Vector3, normal: Vector3) -> void:
	var along := Vector3.UP.cross(normal)
	var basis := Basis(along, Vector3.UP, normal)
	_box(Vector3(3.2, 2.6, 0.9), pos + Vector3.UP * 1.3, _m["dark_stone"], true, basis)
	_box(Vector3(3.6, 0.25, 1.2), pos + Vector3.UP * 2.7 + normal * 0.1, _m["trim"], false, basis)
	_box(Vector3(1.8, 1.3, 0.2), pos + Vector3.UP * 0.75 + normal * 0.4, _m["iron"], false, basis)
	_box(Vector3(1.4, 0.5, 0.3), pos + Vector3.UP * 0.35 + normal * 0.55, _m["fire"], false, basis)
	_light(pos + Vector3.UP * 0.8 + normal * 1.5, 1.6, 7.0, Color(1.0, 0.45, 0.18))


## Estandarte rojo con la V dorada de los Venture, colgado de un muro (normal: hacia fuera del muro).
func _banner(pos: Vector3, normal: Vector3, h: float) -> void:
	var along := Vector3.UP.cross(normal)
	var basis := Basis(along, Vector3.UP, normal)
	_box(Vector3(1.6, h, 0.05), pos + normal * 0.05, _m["carpet"], false, basis)
	_box(Vector3(1.9, 0.1, 0.1), pos + Vector3.UP * (h / 2.0 + 0.05) + normal * 0.08, _m["gold"], false, basis)
	var v := Label3D.new()
	v.text = "V"
	v.font_size = 160
	v.pixel_size = 0.006
	v.outline_size = 0
	v.modulate = Color(0.85, 0.65, 0.28)
	v.transform = Transform3D(basis, pos + Vector3.UP * (h * 0.15) + normal * 0.09)
	add_child(v)


## Árbol muerto: tronco y ramas peladas.
func _dead_tree(p: Vector3, h: float) -> void:
	_cyl(0.18 * h / 5.0, h, p + Vector3.UP * h / 2.0, _m["beam"], Basis(), self, 0.06)
	for i in 4:
		var a := _rng.randf() * TAU
		var tilt := _rng.randf_range(0.5, 0.9)
		var length := h * _rng.randf_range(0.3, 0.45)
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.BACK, tilt)
		_cyl(0.06, length, p + Vector3.UP * h * _rng.randf_range(0.55, 0.85) + basis.y * length / 2.0, _m["beam"], basis, self, 0.02)


func _fountain(c: Vector3, r: float) -> void:
	_disc(Vector2(c.x, c.z), c.y, c.y + 0.7, r, _m["trim"])
	var water := _cyl(r - 0.3, 0.05, c + Vector3.UP * 0.66, _m["water"])
	(water.mesh as CylinderMesh).radial_segments = 32
	_cyl(0.35, 2.4, c + Vector3.UP * 1.9, _m["trim"])
	_cyl(r * 0.35, 0.3, c + Vector3.UP * 3.0, _m["trim"], Basis(), self, r * 0.45)
	_cyl(0.18, 1.0, c + Vector3.UP * 3.6, _m["bronze"])


# ---------------------------------------------------------------- Terreno

## En la ciudad: el terreno chico, la mansión a media escala y los guardias de la verja.
func _build_city_lot() -> void:
	position = Vector3(POS.x, 0, POS.y)
	_build_lot(CITY_LOT, FACADE_Z + (ZS + 8.0) * CITY_SCALE)
	var house := VentureManor.new()
	house.facade = true
	house.position = Vector3(0, 0, FACADE_Z)
	house.scale = Vector3.ONE * CITY_SCALE
	add_child(house)
	for s in [-1.0, 1.0]:
		var guard := Guard.new()
		var p := Vector3(POS.x + s * 8.0, 0, POS.y + CITY_LOT.y / 2.0 + 3.0)
		guard.home = p
		guard.roam_radius = 2.5
		guard.stay_in_plaza = false
		guard.position = p + Vector3(0, 0.1, 0)
		get_parent().add_child.call_deferred(guard)


## Suelo de la escena interior (en la ciudad lo pone CityGround), sin tapar el sótano.
func _build_scene_ground() -> void:
	var cellar := Rect2(9, -48, 24, 21)
	var big := 400.0
	for r in [Rect2(-big, -big, big * 2.0, cellar.position.y + big), Rect2(-big, cellar.end.y, big * 2.0, big - cellar.end.y),
			Rect2(-big, cellar.position.y, cellar.position.x + big, cellar.size.y), Rect2(cellar.end.x, cellar.position.y, big - cellar.end.x, cellar.size.y)]:
		_span(Vector3(r.position.x, -0.5, r.position.y), Vector3(r.end.x, 0, r.end.y), _m["ground"], true)


## Muralla del terreno (lot: ancho y fondo), verja, garita y jardines; front: z del pie de la escalinata.
func _build_lot(lot: Vector2, front: float) -> void:
	var hx := lot.x / 2.0
	var hz := lot.y / 2.0
	var stone: Material = _m["dark_stone"]
	# Muralla del terreno con pilares; la verja en el centro del lado sur.
	var gate := 5.0
	for seg in [[Vector2(-hx, -hz), Vector2(hx, -hz)], [Vector2(-hx, -hz), Vector2(-hx, hz)], [Vector2(hx, -hz), Vector2(hx, hz)],
			[Vector2(-hx, hz), Vector2(-gate, hz)], [Vector2(gate, hz), Vector2(hx, hz)]]:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		_wall(a, b, 0.0, 3.6, 0.8, stone)
		var n := ceili(a.distance_to(b) / 8.0)
		for k in n + 1:
			var p := a.lerp(b, float(k) / n)
			_box(Vector3(1.3, 4.4, 1.3), Vector3(p.x, 2.2, p.y), stone, true)
			_box(Vector3(1.5, 0.25, 1.5), Vector3(p.x, 4.5, p.y), _m["trim"])
	# Pilares de la verja con remate y las hojas de hierro abiertas (hierro de verdad: anclas).
	for s in [-1.0, 1.0]:
		_box(Vector3(2.4, 7.0, 2.4), Vector3(s * (gate + 1.2), 3.5, hz), stone, true)
		_cyl(0.9, 2.6, Vector3(s * (gate + 1.2), 8.3, hz), _m["slate"], Basis(), self, 0.0)
		var leaf := _box(Vector3(gate - 0.2, 5.0, 0.12), Vector3(0, 2.6, 0), _m["iron"], true)
		leaf.position = Vector3(s * gate * 0.55, 2.6, hz - gate * 0.45)
		leaf.rotation.y = s * deg_to_rad(80.0)
		leaf.add_to_group(&"metal")
		_light(Vector3(s * (gate + 1.2), 6.0, hz + 1.6), 1.6, 9.0)
	_box(Vector3(gate * 2.0 + 4.8, 1.0, 1.0), Vector3(0, 7.5, hz), _m["iron"])
	_banner(Vector3(0, 5.6, hz + 0.6), Vector3.BACK, 2.6)
	# Garita junto a la verja.
	var g := Vector3(-gate - 7.0, 0, hz - 5.0)
	_wall(Vector2(g.x - 3, g.z - 2.5), Vector2(g.x + 3, g.z - 2.5), 0, 3.6, 0.4, stone)
	_wall(Vector2(g.x - 3, g.z + 2.5), Vector2(g.x + 3, g.z + 2.5), 0, 3.6, 0.4, stone)
	_wall(Vector2(g.x - 3, g.z - 2.5), Vector2(g.x - 3, g.z + 2.5), 0, 3.6, 0.4, stone)
	_wall(Vector2(g.x + 3, g.z - 2.5), Vector2(g.x + 3, g.z + 2.5), 0, 3.6, 0.4, stone, [[g.z, 1.4, 2.4]])
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(7.0, 2.2, 6.0)
	roof.mesh = prism
	roof.material_override = _m["slate"]
	roof.position = g + Vector3(0, 4.7, 0)
	add_child(roof)
	_span(Vector3(g.x - 3.2, 3.5, g.z - 2.7), Vector3(g.x + 3.2, 3.6, g.z + 2.7), _m["oak"], true)
	_win(g + Vector3(0, 2.0, 2.5), Vector3.BACK, 0.9, 1.1, 0.4)
	_mega("Table_Large", g + Vector3(-1.0, 0, 0), PI / 2, 0.8)
	_mega("Chair_1", g + Vector3(0.2, 0, 0.6), -PI / 2)
	_mega("WeaponStand", g + Vector3(-2.3, 0, -1.6), PI / 2, 0, true)
	_light(g + Vector3(0, 3.0, 0), 1.2, 6.0)
	_build_gardens(hx, hz, front)


func _build_gardens(hx: float, hz: float, front: float) -> void:
	# Paseo central de losas hasta la escalinata, con farolas de hierro a los lados.
	_span(Vector3(-4, 0, front), Vector3(4, 0.06, hz), _m["trim"], true)
	var z := front + 4.0
	while z < hz - 3.0:
		for s in [-1.0, 1.0]:
			var lamp := Props.lamp_post(Vector3(s * 5.0, 0, z), _m["iron"], _m["lamp_glass"], true)
			lamp.rotation.y = -s * PI / 2.0
			add_child(lamp)
		z += 10.0
	_fountain(Vector3(0, 0, (front + hz) / 2.0), clampf((hz - front) / 7.0, 3.0, 5.5))
	# Parterres de setos a los dos lados del paseo y árboles muertos.
	for s in [-1.0, 1.0]:
		var row := 0
		while front + 14.0 + row * 10.0 < hz - 1.0:
			var z0 := front + 6.0 + row * 10.0
			row += 1
			var x0: float = s * 9.0
			var x1: float = s * (hx - 8.0)
			_span(Vector3(minf(x0, x1), 0, z0), Vector3(maxf(x0, x1), 0.04, z0 + 8.0), _m["terrain"])
			for edge in [z0, z0 + 8.0]:
				_span(Vector3(minf(x0, x1), 0, edge - 0.4), Vector3(maxf(x0, x1), 1.0, edge + 0.4), _m["hedge"], true)
			_dead_tree(Vector3((x0 + x1) / 2.0 + _rng.randf_range(-8, 8), 0, z0 + 4.0), _rng.randf_range(4.0, 6.5))
	# Jardín trasero: una fila de setos con árboles, pegada a la muralla.
	var gx := -hx + 12.0
	while gx < hx - 6.0:
		_span(Vector3(gx - 6, 0, -hz + 3.6), Vector3(gx + 6, 1.1, -hz + 4.4), _m["hedge"], true)
		_dead_tree(Vector3(gx + 4, 0, -hz + 2.0), _rng.randf_range(4.0, 6.0))
		gx += 16.0
	# Árboles a los lados de la casa.
	for s in [-1.0, 1.0]:
		var gz := -hz + 12.0
		while gz < front:
			_dead_tree(Vector3(s * (hx - 6.0), 0, gz), _rng.randf_range(4.5, 7.0))
			gz += 12.0


# ---------------------------------------------------------------- Zócalo, muros y techos

func _build_podium() -> void:
	var stone: Material = _m["dark_stone"]
	# Zócalo macizo bajo el bloque, salvo el sótano (x 9..33, z -48..-27).
	for r in [Rect2(-HX, ZN, 43, ZS - ZN), Rect2(9, ZN, HX - 9, 2), Rect2(9, -27, HX - 9, ZS + 27), Rect2(33, -48, 1, 21)]:
		_span(Vector3(r.position.x, -0.2, r.position.y), Vector3(r.end.x, F, r.end.y), stone, true)
	# Losa sobre el sótano con el hueco de la escalera (x 29..31.6, z -35..-30).
	_span(Vector3(9, F - 0.4, -48), Vector3(29, F, -27), stone, true)
	_span(Vector3(31.6, F - 0.4, -48), Vector3(33, F, -27), stone, true)
	_span(Vector3(29, F - 0.4, -48), Vector3(31.6, F, -35.2), stone, true)
	_span(Vector3(29, F - 0.4, -29.8), Vector3(31.6, F, -27), stone, true)
	# Moldura del zócalo alrededor del bloque.
	for s in [-1.0, 1.0]:
		_span(Vector3(-HX - 0.3, F - 0.3, ZN - 0.3 if s < 0 else ZS), Vector3(HX + 0.3, F, ZN if s < 0 else ZS + 0.3), _m["trim"])
		_span(Vector3(s * HX - (0.0 if s > 0 else 0.3), F - 0.3, ZN), Vector3(s * HX + (0.3 if s > 0 else 0.0), F, ZS), _m["trim"])


func _build_shell() -> void:
	var stone: Material = _m["dark_stone"]
	var ix := HX - WT
	# Muros exteriores: zócalo macizo y, encima, los tres pisos (con la puerta principal al sur).
	var sides := [[Vector2(-HX, ZS - WT / 2.0), Vector2(HX, ZS - WT / 2.0), Vector3.BACK],
			[Vector2(-HX, ZN + WT / 2.0), Vector2(HX, ZN + WT / 2.0), Vector3.FORWARD],
			[Vector2(-HX + WT / 2.0, ZN), Vector2(-HX + WT / 2.0, ZS), Vector3.LEFT],
			[Vector2(HX - WT / 2.0, ZN), Vector2(HX - WT / 2.0, ZS), Vector3.RIGHT]]
	for side in sides:
		var normal: Vector3 = side[2]
		for piece in _outside_towers(side[0], side[1]):
			var doors := [[0.0, 5.0, 6.0]] if normal == Vector3.BACK else []
			_wall(piece[0], piece[1], -0.2, F, WT, stone)
			_wall(piece[0], piece[1], F, EAVE, WT, stone, doors)
		# Ventanas: alta en la planta baja, media en el primer piso, pequeña en el segundo.
		var along_x := normal.z != 0.0
		var line: Vector2 = side[0]
		var spots: Array = [-28.0, -22.0, -16.0, -10.0, -4.0, 4.0, 10.0, 16.0, 22.0, 28.0] if along_x 				else [-42.0, -35.0, -22.0, -14.0, 0.0, 12.0, 19.0, 24.0]
		for u: float in spots:
			var p := Vector2(u, line.y) if along_x else Vector2(line.x, u)
			if _inside_tower(p, 1.0):
				continue
			for lv in [[F + 3.6, 1.8, 4.2], [Y1 + 2.8, 1.5, 3.0], [Y2 + 2.4, 1.2, 2.4]]:
				if lv[0] < Y2 and absf(u) < 6.0 and (normal == Vector3.BACK or normal == Vector3.FORWARD):
					continue  # la portada al sur y el rosetón del salón de baile al norte
				_win(Vector3(p.x, lv[0], p.y), normal, lv[1], lv[2], WT, interior and lv[0] < Y2)
		if interior and normal != Vector3.BACK:
			_panel_strips(side[0], side[1], -normal * (WT / 2.0 + 0.04))
		# Contrafuertes entre las ventanas, rematados con un pináculo.
		for i in spots.size() - 1:
			var u: float = (spots[i] + spots[i + 1]) / 2.0
			var p := Vector2(u, line.y) if along_x else Vector2(line.x, u)
			if _inside_tower(p, 1.5) or (normal == Vector3.BACK and absf(u) < 6.0):
				continue
			var c := Vector3(p.x, EAVE / 2.0 - 1.0, p.y) + normal * (WT / 2.0 + 0.35)
			_box(Vector3(0.7, EAVE - 2.0, 0.7), c, stone, true)
			_cyl(0.3, 2.2, Vector3(c.x, EAVE + 0.6, c.z), _m["slate"], Basis(), self, 0.0)
	# Fachada del patio (desde el primer piso; abajo está el claustro con arcos).
	var cx0 := COURT.position.x
	var cx1 := COURT.end.x
	var cz0 := COURT.position.y
	var cz1 := COURT.end.y
	var inner := [[Vector2(cx0, cz0 - 0.3), Vector2(cx1, cz0 - 0.3), Vector3.BACK], [Vector2(cx0, cz1 + 0.3), Vector2(cx1, cz1 + 0.3), Vector3.FORWARD],
			[Vector2(cx0 - 0.3, cz0), Vector2(cx0 - 0.3, cz1), Vector3.RIGHT], [Vector2(cx1 + 0.3, cz0), Vector2(cx1 + 0.3, cz1), Vector3.LEFT]]
	for side in inner:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		var normal: Vector3 = side[2]
		var grow := Vector2(0.6, 0) if a.y == b.y else Vector2(0, 0.6)
		_wall(a - grow, b + grow, Y1 - 0.5, EAVE, IW, stone)
		var n := int(a.distance_to(b) / 5.0)
		for k in n:
			var p := a.lerp(b, (k + 0.5) / n)
			for lv in [[Y1 + 2.8, 1.4, 2.8], [Y2 + 2.4, 1.2, 2.2]]:
				_win(Vector3(p.x, lv[0], p.y), normal, lv[1], lv[2], IW, interior and lv[0] < Y2)
		# Arcos del claustro en la planta baja.
		var m := int(a.distance_to(b) / 3.4)
		for k in m + 1:
			var p := a.lerp(b, float(k) / m)
			_column(p, F, Y1 - 1.6, 0.6)
		_span(Vector3(minf(a.x, b.x) - 0.3, Y1 - 1.6, minf(a.y, b.y) - 0.3), Vector3(maxf(a.x, b.x) + 0.3, Y1 - 0.5, maxf(a.y, b.y) + 0.3), stone)
	# Losas: primer piso (con los huecos de doble altura), segundo piso y cubierta.
	var oak: Material = _m["oak"]
	for r in [Rect2(-ix, -48.8, ix - 22, 17.8), Rect2(22, -48.8, ix - 22, 17.8), Rect2(-ix, -31, ix * 2, 7),
			Rect2(-ix, cz0, ix + cx0, cz1 - cz0), Rect2(cx1, cz0, ix - cx1, cz1 - cz0), Rect2(-ix, cz1, ix * 2, 15.8 - cz1),
			Rect2(-ix, 15.8, ix - 12, 28.8 - 15.8), Rect2(12, 15.8, ix - 12, 28.8 - 15.8)]:
		_span(Vector3(r.position.x, Y1 - 0.5, r.position.y), Vector3(r.end.x, Y1, r.end.y), oak, true)
	for y in [Y2, EAVE + 0.4]:
		for r in [Rect2(-ix, -48.8, ix * 2, cz0 + 48.8), Rect2(-ix, cz0, ix + cx0, cz1 - cz0), Rect2(cx1, cz0, ix - cx1, cz1 - cz0),
				Rect2(-ix, cz1, ix * 2, 28.8 - cz1)]:
			_span(Vector3(r.position.x, y - 0.5, r.position.y), Vector3(r.end.x, y, r.end.y), oak if y == Y2 else stone, true)
			if y == Y2 and interior:
				_beams(r, Y2 - 0.5)
	_rose_window(Vector3(0, Y1 + 2.0, ZN + WT / 2.0), Vector3.FORWARD, 4.2)
	if interior:
		for r in [Rect2(-ix, -31, ix * 2, 7), Rect2(-ix, cz0, ix + cx0, cz1 - cz0), Rect2(cx1, cz0, ix - cx1, cz1 - cz0),
				Rect2(-ix, cz1, ix * 2, 15.8 - cz1), Rect2(-ix, 15.8, ix - 12, 13), Rect2(12, 15.8, ix - 12, 13),
				Rect2(-ix, -48.8, ix - 22, 17.8), Rect2(22, -48.8, ix - 22, 17.8)]:
			_beams(r, Y1 - 0.5)


## Tejados de pizarra a dos aguas sobre las cuatro alas, buhardillas y chimeneas.
func _build_roofs() -> void:
	var rise := 9.0
	var y := EAVE + 0.4
	var cx0 := COURT.position.x
	var cx1 := COURT.end.x
	var cz0 := COURT.position.y
	var cz1 := COURT.end.y
	# [centro x, centro z, largo, ancho, ¿cumbrera a lo largo de x?]
	var wings := [[0.0, (ZS + cz1) / 2.0, HX * 2.0, ZS - cz1, true], [0.0, (ZN + cz0) / 2.0, HX * 2.0, cz0 - ZN, true],
			[(-HX + cx0) / 2.0, (cz0 + cz1) / 2.0, cz1 - cz0, cx0 + HX, false], [(HX + cx1) / 2.0, (cz0 + cz1) / 2.0, cz1 - cz0, HX - cx1, false]]
	for w in wings:
		var roof := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(w[3] + 1.6, rise, w[2] + (1.6 if w[4] else 0.0))
		roof.mesh = prism
		roof.material_override = _m["slate"]
		roof.position = Vector3(w[0], y + rise / 2.0, w[1])
		roof.rotation.y = PI / 2.0 if w[4] else 0.0
		add_child(roof)
		# Cresta de hierro en la cumbrera.
		_box(Vector3(w[2] if w[4] else 0.15, 0.6, 0.15 if w[4] else w[2]), Vector3(w[0], y + rise + 0.3, w[1]), _m["iron"])
	# Buhardillas en las fachadas largas.
	for s in [-1.0, 1.0]:
		for x in [-20.0, -8.0, 8.0, 20.0]:
			var z: float = (ZS - 3.0) if s > 0 else (ZN + 3.0)
			_span(Vector3(x - 1.6, y, z - 1.6), Vector3(x + 1.6, y + 3.4, z + 1.6), _m["dark_stone"])
			_win(Vector3(x, y + 1.8, z + s * 1.6), Vector3(0, 0, s), 1.0, 1.6, 0.2)
			var cap := MeshInstance3D.new()
			var pr := PrismMesh.new()
			pr.size = Vector3(4.0, 2.2, 4.0)
			cap.mesh = pr
			cap.material_override = _m["slate"]
			cap.position = Vector3(x, y + 4.5, z)
			add_child(cap)
	# Chimeneas.
	for p in [Vector2(-26, -40), Vector2(26, -12), Vector2(-26, 0), Vector2(18, 20)]:
		_span(Vector3(p.x - 1.0, y, p.y - 1.4), Vector3(p.x + 1.0, y + rise + 3.0, p.y + 1.4), _m["dark_stone"])
		_span(Vector3(p.x - 1.2, y + rise + 3.0, p.y - 1.6), Vector3(p.x + 1.2, y + rise + 3.3, p.y + 1.6), _m["trim"])


## Torre redonda: anillo de muro (abierto a la sala en la planta baja donde se mete en el bloque),
## ventanas estrechas, aguja de pizarra con remate dorado. La que se sube tiene pisos con escalera
## y, arriba, el mirador abierto con el telescopio.
func _tower(c: Vector2, climb: bool) -> void:
	var stone: Material = _m["dark_stone"]
	var segs := 24
	var top: float = TOWER_LEVELS[4] if climb else TOWER_TOP
	_disc(c, -0.2, F, TOWER_R - 0.2, stone)
	for i in segs:
		var a := TAU * (i + 0.5) / segs
		var dir := Vector2(cos(a), sin(a))
		var mid := c + dir * (TOWER_R - 0.5)
		var in_block := absf(mid.x) < HX and mid.y > ZN and mid.y < ZS
		var y0 := Y1 - 0.5 if in_block else -0.2
		var basis := Basis(Vector3.UP, atan2(dir.x, dir.y))
		var w := 2.0 * TOWER_R * sin(PI / segs) + 0.2
		_box(Vector3(w, top - y0, 1.0), Vector3(mid.x, (top + y0) / 2.0, mid.y), stone, true, basis)
		if not in_block and i % 3 == 0:
			for wy in [F + 3.0, Y1 + 2.8, Y2 + 2.8, Y2 + 8.4]:
				if wy < top - 1.0:
					_win(Vector3(mid.x, wy, mid.y), Vector3(dir.x, 0, dir.y), 0.8, 2.2, 1.0)
	_cyl(TOWER_R + 0.4, 0.5, Vector3(c.x, F - 0.05, c.y), _m["trim"])
	var roof_y := TOWER_TOP
	if climb:
		# Mirador: parapeto y columnas hasta TOWER_TOP, sin muro (se ve la ciudad entera).
		for i in segs:
			var a := TAU * (i + 0.5) / segs
			var dir := Vector2(cos(a), sin(a))
			var mid := c + dir * (TOWER_R - 0.5)
			var basis := Basis(Vector3.UP, atan2(dir.x, dir.y))
			var w := 2.0 * TOWER_R * sin(PI / segs) + 0.2
			_box(Vector3(w, 1.1, 0.8), Vector3(mid.x, top + 0.55, mid.y), _m["trim"], true, basis)
			if i % 2 == 0:
				_box(Vector3(0.6, TOWER_TOP - top, 0.6), Vector3(mid.x, (top + TOWER_TOP) / 2.0, mid.y), _m["trim"], true)
		_cyl(TOWER_R + 0.2, 1.0, Vector3(c.x, TOWER_TOP + 0.5, c.y), stone)
		roof_y = TOWER_TOP + 1.0
		_build_tower_stairs(c)
	else:
		_round_floor(c, Y1, TOWER_R - 0.6, _m["oak"])
	var cone := _cyl(TOWER_R + 0.8, 15.0, Vector3(c.x, roof_y + 7.5, c.y), _m["slate"], Basis(), self, 0.0)
	(cone.mesh as CylinderMesh).radial_segments = 24
	_cyl(0.12, 4.0, Vector3(c.x, roof_y + 17.0, c.y), _m["gold"])
	_cyl(0.3, 0.6, Vector3(c.x, roof_y + 15.3, c.y), _m["gold"])


## Escalera de ida y vuelta de la torre noreste: un tramo por piso, alternando de banda.
func _build_tower_stairs(c: Vector2) -> void:
	var tan_s := tan(deg_to_rad(SLOPE))
	for k in TOWER_LEVELS.size() - 1:
		var y0: float = TOWER_LEVELS[k]
		var y1: float = TOWER_LEVELS[k + 1]
		var run := (y1 - y0) / tan_s
		var z: float = c.y + STAIR_DZ[k % 2]
		var s := 1.0 if k % 2 == 0 else -1.0
		var bottom := Vector3(c.x - s * run / 2.0, y0, z)
		var top := Vector3(c.x + s * run / 2.0, y1, z)
		_flight(bottom, top, 1.6, y0, _m["trim"])
		# El piso de arriba tiene el hueco justo sobre este tramo.
		var hole := Rect2(c.x - run / 2.0, z - 1.1, run, 2.2)
		_round_floor(c, y1, TOWER_R - 0.6, _m["oak"], hole)
		_light(Vector3(c.x, y1 - 1.2, c.y + 4.0), 1.2, 9.0)
	# Telescopio de bronce en el mirador.
	var m := Vector3(c.x + 3.0, TOWER_LEVELS[4], c.y - 3.0)
	for i in 3:
		var a := TAU * i / 3.0
		_cyl(0.04, 1.4, m + Vector3(cos(a) * 0.3, 0.65, sin(a) * 0.3), _m["oak"], Basis(Vector3(-sin(a), 0, cos(a)), 0.25))
	_cyl(0.12, 2.2, m + Vector3(0, 1.7, 0), _m["bronze"], Basis(Vector3.BACK, -1.1) * Basis(Vector3.UP, 0.0), self, 0.07)
	_mega("Chair_1", m + Vector3(-1.4, 0, 0.6), PI * 0.6)


# ---------------------------------------------------------------- Entrada

func _build_entrance() -> void:
	# Escalinata de 12 m de ancho del suelo al zócalo.
	_flight(Vector3(0, 0, ZS + 8.0), Vector3(0, F, ZS), 12.0, 0.0, _m["trim"], true, true)
	for s in [-1.0, 1.0]:
		_span(Vector3(s * 6.0 - 0.5, 0, ZS), Vector3(s * 6.0 + 0.5, F + 1.0, ZS + 8.4), _m["dark_stone"], true)
		# Estatuas sobre pedestales.
		_box(Vector3(1.4, 1.8, 1.4), Vector3(s * 9.0, 0.9, ZS + 6.0), _m["trim"], true)
		_mega("Vase_4", Vector3(s * 9.0, 1.8, ZS + 6.0), 0.0, 1.8)
	# Portada: arco apuntado con columnas, la V de la casa y faroles.
	for s in [-1.0, 1.0]:
		_box(Vector3(0.9, 8.0, 0.9), Vector3(s * 3.4, F + 4.0, ZS + 0.4), _m["trim"], true)
		_banner(Vector3(s * 7.5, F + 10.0, ZS + 0.05), Vector3.BACK, 6.0)
		_lantern(Vector3(s * 4.6, F + 4.2, ZS + 0.6), 3.6, 13.0)
	var arch := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(7.8, 3.2, 1.0)
	arch.mesh = prism
	arch.material_override = _m["trim"]
	arch.position = Vector3(0, F + 9.6, ZS + 0.4)
	add_child(arch)
	_box(Vector3(7.8, 1.6, 1.0), Vector3(0, F + 7.2, ZS + 0.4), _m["trim"])
	var v := Label3D.new()
	v.text = "V"
	v.font_size = 220
	v.pixel_size = 0.008
	v.outline_size = 0
	v.modulate = Color(0.85, 0.65, 0.28)
	v.position = Vector3(0, F + 9.3, ZS + 0.95)
	add_child(v)
	# Puertas de roble con herrajes, cerradas: el paso es la bruma del umbral (cambia de mapa).
	for s in [-1.0, 1.0]:
		var leaf := _box(Vector3(2.45, 6.0, 0.18), Vector3(s * 1.25, F + 3.0, ZS - WT / 2.0), _m["oak"], true)
		for y in [1.0, 3.0, 5.0]:
			_box(Vector3(2.3, 0.1, 0.22), Vector3(0, y - 3.0, 0), _m["iron"], false, Basis(), leaf)
		_cyl(0.12, 0.05, Vector3(-s * 0.9, 0, 0.14), _m["gold"], Basis(Vector3.RIGHT, PI / 2), leaf)
	var portal := Portal.new()
	portal.door_size = Vector2(5.0, 6.0)
	if facade:
		portal.target_scene = INTERIOR_SCENE
		portal.arrival = ENTRANCE
		portal.label = "Casa Venture"
		portal.position = Vector3(0, F, ZS + 0.5)
	else:
		portal.target_scene = "res://scenes/main.tscn"
		portal.arrival = city_exit()
		portal.label = "Salir a Luthadel"
		portal.position = Vector3(0, F, ZS - WT - 0.5)
	add_child(portal)


# ---------------------------------------------------------------- Planta baja

func _build_ground_floor() -> void:
	var ix := HX - WT
	var w_in: Material = _m["wall_in"]
	var h := Y1 - 0.5
	# Suelos: mármol en el gran salón y el salón de baile, roble en las salas, losas en el claustro.
	for r in [Rect2(-ix, -28, ix - 19, 34), Rect2(19, -28, ix - 19, 34), Rect2(-ix, 6, ix - 12, 22.8), Rect2(12, 6, ix - 12, 22.8)]:
		_span(Vector3(r.position.x, F, r.position.y), Vector3(r.end.x, F + 0.04, r.end.y), _m["oak"])
	_span(Vector3(-ix, F, -48.8), Vector3(-22, F + 0.04, -28), _m["trim"])
	_span(Vector3(-12, F, 6), Vector3(12, F + 0.04, 28.8), _m["marble"])
	_span(Vector3(-22, F, -48.8), Vector3(22, F + 0.04, -28), _m["marble"])
	# Tabiques (doble altura en el salón de baile y el gran salón).
	_wall(Vector2(-ix, -28), Vector2(ix, -28), F, h, IW, w_in, [[-27, 2.0, 3.0], [-8, 3.0, 4.5], [0, 3.0, 4.5], [8, 3.0, 4.5], [27, 2.0, 3.0]], true)
	for s in [-1.0, 1.0]:
		_wall(Vector2(s * 22, -48.8), Vector2(s * 22, -28), F, Y2 - 0.5, IW, w_in, [[-38, 2.5, 3.2]], true)
		_wall(Vector2(s * 19, -28), Vector2(s * 19, 6), F, h, IW, w_in, [[-17, 3.0, 4.0], [0, 2.0, 3.2]], true)
		_wall(Vector2(s * 12, 6), Vector2(s * 12, 28.8), F, Y1, IW, w_in, [[18, 3.0, 4.5]], true)
	_wall(Vector2(-ix, -6), Vector2(-19, -6), F, h, IW, w_in, [[-26, 2.0, 3.2]], true)
	_wall(Vector2(19, -4), Vector2(ix, -4), F, h, IW, w_in, [[26, 2.0, 3.2]], true)
	_wall(Vector2(-ix, 6), Vector2(ix, 6), F, h, IW, w_in, [[-26, 2.0, 3.2], [-15.5, 2.0, 3.2], [0, 4.0, 5.0], [15.5, 2.0, 3.2], [26, 2.0, 3.2]], true)
	# Faroles del claustro.
	for p in [Vector2(-17, -26), Vector2(17, -26), Vector2(-17, 4), Vector2(17, 4), Vector2(-17, -11), Vector2(17, -11)]:
		_lantern(Vector3(p.x, h - 1.0, p.y), 2.5, 11.7)
	_great_hall()
	_mural_gallery()
	_guard_room()
	_dining_room()
	_sitting_room()
	_library()
	_study()
	_kitchen()
	_ballroom()
	_cellar_stair_room()


## Gran salón: doble altura, escalera principal al primer piso, columnas, estandartes y arañas.
func _great_hall() -> void:
	var y := F + 0.04
	_span(Vector3(-2.5, y, 15.8), Vector3(2.5, y + 0.02, 28.8), _m["carpet"])
	_flight(Vector3(0, F, 25.0), Vector3(0, Y1, 15.8), 6.0, F, _m["trim"], true, true)
	for s in [-1.0, 1.0]:
		_railing(Vector3(s * 3.2, F, 25.0), Vector3(s * 3.2, Y1, 15.8))
		for z in [9.0, 13.0, 19.0, 23.0, 27.0]:
			_column(Vector2(s * 10.6, z), F, Y2 - 0.5, 1.0)
		_banner(Vector3(s * 11.65, F + 9.0, 21.0), Vector3(-s, 0, 0), 7.0)
		# Estatuas de bronce al pie de la escalera, retratos, aparadores y apliques.
		_box(Vector3(1.6, 1.0, 1.6), Vector3(s * 6.0, F + 0.5, 26.5), _m["trim"], true)
		Props.bronze_statue(self, Vector3(s * 6.0, F + 1.0, 26.5), {"height": 2.0, "build": 1.1, "coat": Color.WHITE,
				"cloak": s > 0, "hair_style": "short"}, _m["bronze"], PI)
		for z in [11.0, 25.0]:
			_painting(Vector3(s * 11.67, F + 4.0, z), Vector3(-s, 0, 0), 2.2, 3.0, "portrait")
		_model(RAD, Vector3(s * 11.2, F, 16.0), -s * PI / 2.0, Vector3.ONE, true, "commode")
		_mega("CandleStick_Triple", Vector3(s * 11.2, F + 0.95, 16.0), 0.0)
		_mega("Vase_2", Vector3(s * 11.2, F + 0.95, 15.3), 0.0)
		for z in [7.5, 17.5, 29.0 - 1.5]:
			_sconce(Vector3(s * 11.68, F + 3.4, z), Vector3(-s, 0, 0))
	_painting(Vector3(0, Y1 + 3.2, 6.32), Vector3.BACK, 3.0, 2.0, "landscape")
	# Entreplanta (encima de la escalera) con barandilla hacia el vacío.
	_railing(Vector3(-11.7, Y1, 15.8), Vector3(-3.2, Y1, 15.8))
	_railing(Vector3(3.2, Y1, 15.8), Vector3(11.7, Y1, 15.8))
	for z in [11.0, 22.0]:
		_chandelier(Vector3(0, Y2 - 0.5, z), 2.6, 6.0, 22.5)


func _mural_gallery() -> void:
	# Murales en tres muros, con marcos dorados; bancos en el centro.
	var y0 := F + 1.4
	var k := 0
	for m in [[Vector3(-32.62, 0, 17.4), Vector3.RIGHT, 18.0], [Vector3(-22.4, 0, 28.62), Vector3.FORWARD, 16.0], [Vector3(-20.75, 0, 6.38), Vector3.BACK, 6.0]]:
		var c: Vector3 = m[0]
		var n: Vector3 = m[1]
		_painting(c + Vector3.UP * (y0 + 2.6), n, m[2], 4.6, "mural", k)
		k += 1
	for z in [12.0, 18.0, 24.0]:
		_mega("Bench", Vector3(-22, F, z), PI / 2, 0.0, true)
	_box(Vector3(1.4, 1.0, 1.4), Vector3(-15, F + 0.5, 23), _m["trim"], true)
	Props.bronze_statue(self, Vector3(-15, F + 1.0, 23), {"height": 1.9, "build": 0.95, "coat": Color.WHITE, "hair_style": "long"}, _m["bronze"], -PI / 2)
	for z in [9.0, 26.0]:
		_pedestal_vase(Vector3(-14.5, F, z))
	_rug(Rect2(-25, 10, 6, 15), F)
	_chandelier(Vector3(-22, Y1 - 0.5, 17.4), 1.6, 4.8, 17.5)


func _guard_room() -> void:
	var y := F
	_mega("WeaponStand", Vector3(31.5, y, 10), -PI / 2, 0.0, true)
	_mega("WeaponStand", Vector3(31.5, y, 13), -PI / 2, 0.0, true)
	_mega("Shield_Wooden", Vector3(32.6, y + 2.0, 17), -PI / 2)
	_mega("Shield_Wooden", Vector3(32.6, y + 2.0, 19), -PI / 2)
	for z in [22.0, 26.0]:
		_mega("Bed_Twin1", Vector3(30.5, y, z), -PI / 2, 0.0, true)
	_mega("Table_Large", Vector3(20, y, 18), 0.0, 0.0, true)
	for s in [-1.0, 1.0]:
		_mega("Stool", Vector3(20 + s * 1.3, y, 17), 0.0)
	_mega("Peg_Rack", Vector3(13, y + 1.8, 27.6), PI)
	_mega("Chest_Wood", Vector3(14, y, 8), 0.0, 0.0, true)
	_mega("Dummy", Vector3(26, y, 9), PI, 0.0, true)
	_mega("Sword_Bronze", Vector3(20.2, y + 0.9, 18.2), 0.3)
	_mega("Mug", Vector3(19.6, y + 0.9, 17.7), 0.0)
	_painting(Vector3(22, F + 3.2, 28.62), Vector3.FORWARD, 2.6, 1.8, "landscape")
	_lantern(Vector3(22, Y1 - 2.0, 17), 2.9, 15.6)


func _dining_room() -> void:
	# Mesa principal de 14 m (tres mesas largas seguidas) con dieciséis sillas.
	var y := F
	var x := -26.0
	for z in [-23.5, -17.0, -10.5]:
		_mega("Table_Large", Vector3(x, y, z), PI / 2, 0.0, true)
		_span(Vector3(x - 0.9, y + 0.86, z - 3.2), Vector3(x + 0.9, y + 0.88, z + 3.2), _m["carpet"])
	for k in 7:
		var z := -26.0 + k * 2.0 + 1.0
		for s in [-1.0, 1.0]:
			_mega("Chair_1", Vector3(x + s * 1.5, y, z), -s * PI / 2.0)
		_mega("Table_Plate", Vector3(x - 0.5, y + 0.88, z), 0.0)
		_mega("Table_Plate", Vector3(x + 0.5, y + 0.88, z), 0.0)
		if k % 2 == 0:
			_mega("CandleStick_Triple", Vector3(x, y + 0.88, z), 0.0)
		else:
			_mega("Chalice", Vector3(x, y + 0.88, z), 0.0)
	_mega("Chair_1", Vector3(x, y, -27.0), 0.0)
	_fireplace(Vector3(-32.6, y, -17), Vector3.RIGHT)
	_mega("Cabinet", Vector3(-20.0, y, -24), -PI / 2, 0.0, true)
	_rug(Rect2(-29, -27, 6, 19), y)
	_model(RAD, Vector3(-19.9, y, -10.5), -PI / 2, Vector3.ONE, true, "commode")
	for z in [-11.0, -10.0]:
		_mega("Table_Plate", Vector3(-19.9, y + 0.95, z), 0.0)
	_mega("Bottle_1", Vector3(-19.9, y + 0.95, -9.4), 0.0)
	for z in [-24.0, -11.0]:
		_painting(Vector3(-19.33, F + 3.6, z), Vector3.LEFT, 2.8, 2.0, "landscape")
	_painting(Vector3(-26, F + 3.8, -27.68), Vector3.BACK, 2.0, 2.8, "portrait")
	for z in [-26.0, -8.0]:
		_sconce(Vector3(-32.68, F + 3.4, z), Vector3.RIGHT)
	_banner(Vector3(-32.65, F + 5.0, -24), Vector3.RIGHT, 3.5)
	_banner(Vector3(-32.65, F + 5.0, -10), Vector3.RIGHT, 3.5)
	_chandelier(Vector3(x, Y1 - 0.5, -21), 1.8, 5.2, 17.5)
	_chandelier(Vector3(x, Y1 - 0.5, -12), 1.8, 5.2, 17.5)


func _sitting_room() -> void:
	var y := F
	_rug(Rect2(-30, -3, 8, 7), y)
	_painting(Vector3(-26, F + 3.5, -5.68), Vector3.BACK, 2.4, 1.7, "landscape")
	_model(RAD, Vector3(-20.0, y, 3.0), -PI / 2, Vector3.ONE, true, "bookshelf")
	_pedestal_vase(Vector3(-20.5, y, -4.5))
	for p in [Vector3(-28, y, -1), Vector3(-24, y, -1), Vector3(-28, y, 2.5), Vector3(-24, y, 2.5)]:
		_model(RAD, p, PI if p.z > 0 else 0.0, Vector3.ONE * 1.1, false, "chair")
	_model(RAD, Vector3(-26, y, 0.8), 0.0, Vector3.ONE, true, "table")
	_mega("CandleStick", Vector3(-26, y + 0.8, 0.8), 0.0)
	_fireplace(Vector3(-32.6, y, 1), Vector3.RIGHT)
	_lantern(Vector3(-26, Y1 - 2.0, 0), 2.5, 11.7)


## Biblioteca: estanterías de suelo a techo en los muros y en filas, mesas de lectura con velas.
func _library() -> void:
	var y := F
	for z in range(-27, -5, 2):
		_mega("Bookcase_2", Vector3(32.4, y, z + 0.5), -PI / 2, 4.0, true)
	for x in range(21, 32, 2):
		_mega("Bookcase_2", Vector3(x + 0.5, y, -27.4), 0.0, 4.0, true)
	for row in [-20.0, -14.0]:
		for x in [22.5, 24.5, 26.5]:
			_mega("Bookcase_2", Vector3(x, y, row), PI, 3.0, true)
	for z in [-24.0, -10.0]:
		_mega("Table_Large", Vector3(26, y, z), 0.0, 0.0, true)
		_mega("CandleStick_Triple", Vector3(26, y + 0.88, z), 0.0)
		_mega("Book_Stack_1", Vector3(25, y + 0.88, z + 0.3), 0.4)
		for s in [-1.0, 1.0]:
			_mega("Chair_1", Vector3(26 + s * 1.2, y, z + s * 0.9), PI if s > 0 else 0.0)
	_mega("BookStand", Vector3(21, y, -8), PI / 2)
	_rug(Rect2(23, -26, 6, 18), y)
	for z in [-24.0, -10.0]:
		_mega("BookGroup_Medium_1", Vector3(26.6, y + 0.88, z - 0.2), 0.3)
		_mega("Book_7", Vector3(25.4, y + 0.88, z + 0.2), 1.2)
	_painting(Vector3(19.33, F + 4.0, -23), Vector3.RIGHT, 2.0, 2.8, "portrait")
	_cyl(0.6, 0.05, Vector3(30.5, y + 1.2, -8), _m["bronze"], Basis(Vector3.RIGHT, PI / 2))
	var globe := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	globe.mesh = sphere
	globe.material_override = _m["mural"]
	globe.position = Vector3(30.5, y + 1.2, -8)
	add_child(globe)
	_box(Vector3(0.6, 0.6, 0.6), Vector3(30.5, y + 0.3, -8), _m["oak"], true)
	_chandelier(Vector3(26, Y1 - 0.5, -17), 1.8, 5.2, 20.0)


func _study() -> void:
	var y := F
	_model(RAD, Vector3(26, y, 1.5), PI / 2, Vector3.ONE * 1.1, true, "table")
	_model(RAD, Vector3(27.6, y, 1.5), -PI / 2, Vector3.ONE, false, "chair")
	_model(RAD, Vector3(32.2, y, -1.8), -PI / 2, Vector3.ONE, true, "bookshelf")
	_mega("CandleStick", Vector3(25.6, y + 0.85, 1.0), 0.0)
	_mega("Scroll_1", Vector3(26.2, y + 0.85, 1.8), 0.6)
	_mega("Chest_Wood", Vector3(21, y, 4.6), PI, 0.0, true)
	_rug(Rect2(23, -2, 6, 6), y)
	_painting(Vector3(26, F + 3.6, 5.68), Vector3.FORWARD, 2.2, 1.6, "landscape")
	_painting(Vector3(19.33, F + 3.6, -1), Vector3.RIGHT, 1.4, 2.0, "portrait")
	_pedestal_vase(Vector3(31.5, y, 5))
	_fireplace(Vector3(32.6, y, 3.5), Vector3.LEFT)
	_lantern(Vector3(26, Y1 - 2.5, 1), 2.2, 10.4)


func _kitchen() -> void:
	var y := F
	for z in [-46.0, -42.0]:
		_mega("Workbench", Vector3(-31.5, y, z), PI / 2, 0.0, true)
	_mega("Workbench_Drawers", Vector3(-27, y, -38), 0.0, 0.0, true)
	_mega("Table_Large", Vector3(-27, y, -33), 0.0, 0.0, true)
	_mega("Cauldron", Vector3(-24, y, -47.5), 0.0, 0.0, true)
	_box(Vector3(5.0, 3.0, 1.2), Vector3(-28, y + 1.5, -48.2), _m["dark_stone"], true)
	_box(Vector3(3.0, 0.6, 0.4), Vector3(-28, y + 0.6, -47.5), _m["fire"])
	_light(Vector3(-28, y + 1.2, -46), 2.0, 8.0, Color(1.0, 0.45, 0.18))
	for x in [-30.0, -28.5, -27.0, -25.5]:
		_mega("Pot_1", Vector3(x, y + 3.2, -36), 0.0)
		_cyl(0.01, 1.2, Vector3(x, y + 4.2, -36), _m["iron"])
	_box(Vector3(5.0, 0.1, 0.1), Vector3(-27.75, y + 4.8, -36), _m["iron"])
	for p in [Vector3(-31.5, y, -30), Vector3(-30.3, y, -29.6)]:
		_mega("Barrel", p, _rng.randf() * TAU, 0.0, true)
	_mega("Shelf_Small_Bottles", Vector3(-22.6, y + 1.6, -34), -PI / 2)
	_mega("FarmCrate_Carrot", Vector3(-31, y, -38), 0.3)
	_mega("Pot_1_Lid", Vector3(-27.5, y + 0.95, -38), 0.0)
	_mega("Bucket_Wooden_1", Vector3(-23, y, -46), 0.0)
	_mega("Table_Knife", Vector3(-26.6, y + 0.88, -33), 0.5)
	_mega("Barrel_Apples", Vector3(-31.2, y, -35.5), 0.0, 0.0, true)
	_lantern(Vector3(-27, Y1 - 2.0, -40), 2.9, 15.6)


## Salón de baile: doble altura, suelo de damero, columnas, tres arañas grandes y el balcón.
func _ballroom() -> void:
	for x in range(-18, 19, 6):
		if absf(x) > 5:  # en el centro, el rosetón
			_column(Vector2(x, -47.8), F, Y2 - 0.5, 1.0)
	for s in [-1.0, 1.0]:
		_banner(Vector3(s * 21.65, F + 8.0, -42), Vector3(-s, 0, 0), 7.0)
		_banner(Vector3(s * 21.65, F + 8.0, -34), Vector3(-s, 0, 0), 7.0)
		_painting(Vector3(s * 21.67, F + 5.5, -38), Vector3(-s, 0, 0), 3.4, 5.0, "tapestry", 2 if s > 0 else 3)
		for z in [-46.0, -30.0]:
			_sconce(Vector3(s * 21.68, F + 3.6, z), Vector3(-s, 0, 0))
		for z in [-42.0, -34.0]:
			_mega("Table_Large", Vector3(s * 19.4, F, z), PI / 2, 0.6, true)
			_mega("Chalice", Vector3(s * 19.4, F + 0.6, z - 0.3), 0.0)
			_mega("CandleStick", Vector3(s * 19.4, F + 0.6, z + 0.3), 0.0)
	for x in [-12.0, 0.0, 12.0]:
		_chandelier(Vector3(x, Y2 - 0.5, -40), 3.2, 6.4, 25.0)
	# Tarima de los músicos al norte, con sillas.
	_span(Vector3(-8, F, -48.6), Vector3(8, F + 0.6, -45.5), _m["oak"], true)
	for x in [-5.0, -2.5, 0.0, 2.5, 5.0]:
		_mega("Chair_1", Vector3(x, F + 0.6, -47.0), 0.0)
	# Balcón del salón (en el primer piso, sobre la entrada del sur).
	_railing(Vector3(-21.7, Y1, -31.0), Vector3(21.7, Y1, -31.0))
	# Sillas a lo largo de las paredes laterales.
	for s in [-1.0, 1.0]:
		for z in [-44.0, -40.0, -36.0, -32.0]:
			_model(RAD, Vector3(s * 20.6, F, z), -s * PI / 2.0, Vector3.ONE, false, "chair")


## Cuarto de la escalera al sótano (noreste), que también da a la torre de la familia.
func _cellar_stair_room() -> void:
	_flight(Vector3(30.3, BASE_Y, -35.0), Vector3(30.3, F, -30.0), 2.4, BASE_Y, _m["trim"])
	_railing(Vector3(28.9, F, -35.2), Vector3(28.9, F, -30.0))
	_mega("Chest_Wood", Vector3(24, F, -46), 0.0, 0.0, true)
	_mega("Crate_Wooden", Vector3(25.6, F, -46.3), 0.4, 0.0, true)
	_lantern(Vector3(27, Y1 - 2.0, -38), 2.5, 13.0)


# ---------------------------------------------------------------- Primer piso

func _build_first_floor() -> void:
	var ix := HX - WT
	var w_in: Material = _m["wall_in"]
	var y0 := Y1
	var y1 := Y2 - 0.5
	_wall(Vector2(-ix, -28), Vector2(ix, -28), y0, y1, IW, w_in, [[-8, 2.5, 3.2], [8, 2.5, 3.2]], true)
	for s in [-1.0, 1.0]:
		_wall(Vector2(s * 19, -28), Vector2(s * 19, 6), y0, y1, IW, w_in, [[-11, 2.0, 3.0]], true)
		_wall(Vector2(s * 12, 6), Vector2(s * 12, 28.8), y0, y1, IW, w_in, [[10, 2.0, 3.0]], true)
	_wall(Vector2(-ix, -6), Vector2(-19, -6), y0, y1, IW, w_in, [[-26, 2.0, 3.0]], true)
	_wall(Vector2(19, -4), Vector2(ix, -4), y0, y1, IW, w_in, [[26, 2.0, 3.0]], true)
	_wall(Vector2(-ix, 6), Vector2(ix, 6), y0, y1, IW, w_in, [[0, 3.0, 4.0]], true)
	# Pasillo alrededor del patio: alfombra y faroles.
	for r in [Rect2(-18, -27.2, 36, 2.4), Rect2(-18, 2.8, 36, 2.4), Rect2(-18, -24, 2.4, 26), Rect2(15.6, -24, 2.4, 26)]:
		_span(Vector3(r.position.x, y0, r.position.y), Vector3(r.end.x, y0 + 0.03, r.end.y), _m["carpet"])
	for p in [Vector2(-17, -26), Vector2(17, -26), Vector2(-17, 4), Vector2(17, 4)]:
		_lantern(Vector3(p.x, y1 - 0.8, p.y), 2.2, 11.7)
		_pedestal_vase(Vector3(p.x + signf(p.x) * 1.2, y0, p.y + (-1.2 if p.y < 0 else 1.2)))
	for z in [-18.0, -4.0]:
		for s in [-1.0, 1.0]:
			_painting(Vector3(s * 18.67, y0 + 2.6, z), Vector3(-s, 0, 0), 2.0, 1.5, "landscape" if z < -10 else "portrait")
			_mega("Bench", Vector3(s * 17.9, y0, z + 6.0), -s * PI / 2.0, 0.0, true)
	_lord_chamber()
	_guest_suite()
	_guest_room()
	_upper_sitting_room()


## Cámara del señor Venture: cama grande, armarios, escritorio, chimenea.
func _lord_chamber() -> void:
	var y := Y1
	_rug(Rect2(-31, -24, 10, 14), y)
	_model(RAD, Vector3(-30.5, y, -17), PI / 2, Vector3(1.4, 1.3, 1.4), true, "bed")
	_canopy(Vector3(-30.6, y, -17), Vector2(3.2, 3.0))
	_painting(Vector3(-19.33, y + 3.0, -17), Vector3.LEFT, 2.0, 2.8, "portrait")
	_painting(Vector3(-26, y + 3.0, -6.32), Vector3.FORWARD, 2.6, 1.8, "landscape")
	_pedestal_vase(Vector3(-20.5, y, -26.5))
	_model(RAD, Vector3(-32.0, y, -24), PI / 2, Vector3(1.0, 1.2, 1.3), true, "closet")
	_model(RAD, Vector3(-32.0, y, -10.5), PI / 2, Vector3.ONE, true, "commode")
	_model(RAD, Vector3(-22, y, -14), -PI / 2, Vector3.ONE, true, "table")
	_model(RAD, Vector3(-23.2, y, -14), PI / 2, Vector3.ONE, false, "chair")
	_mega("CandleStick", Vector3(-22, y + 0.8, -14.4), 0.0)
	_fireplace(Vector3(-26, y, -27.6), Vector3.BACK)
	_banner(Vector3(-32.65, y + 3.0, -17), Vector3.RIGHT, 2.6)
	_lantern(Vector3(-26, Y2 - 2.0, -17), 2.5, 13.0)
	# Vestidor.
	for z in [-4.0, -1.0, 2.0]:
		_model(RAD, Vector3(-32.0, y, z), PI / 2, Vector3(1.0, 1.2, 1.3), true, "closet")
	_mega("Chest_Wood", Vector3(-22, y, 3), -PI / 2, 0.0, true)
	_lantern(Vector3(-26, Y2 - 2.0, 0), 1.8, 9.1)


func _guest_suite() -> void:
	var y := Y1
	_rug(Rect2(21, -24, 10, 12), y)
	_canopy(Vector3(30.6, y, -18), Vector2(2.8, 2.6))
	_painting(Vector3(19.33, y + 3.0, -20), Vector3.RIGHT, 2.4, 1.7, "landscape")
	_model(RAD, Vector3(30.5, y, -18), -PI / 2, Vector3(1.2, 1.2, 1.2), true, "bed")
	_mega("Nightstand_Shelf", Vector3(31.8, y, -21.5), -PI / 2, 0.0, true)
	_model(RAD, Vector3(32.0, y, -26), -PI / 2, Vector3.ONE, true, "commode")
	_model(RAD, Vector3(22, y, -8), PI / 2, Vector3.ONE, true, "bookshelf")
	_mega("CandleStick", Vector3(31.8, y + 0.6, -21.5), 0.0)
	_lantern(Vector3(26, Y2 - 2.0, -16), 2.3, 13.0)
	# Sala de la suite.
	for p in [Vector3(24, y, 1), Vector3(28, y, 1)]:
		_model(RAD, p, PI, Vector3.ONE, false, "chair")
	_model(RAD, Vector3(26, y, -0.5), 0.0, Vector3.ONE, true, "table")
	_lantern(Vector3(26, Y2 - 2.0, 1), 1.8, 9.1)


func _guest_room() -> void:
	var y := Y1
	_model(RAD, Vector3(-30.5, y, 20), PI / 2, Vector3(1.2, 1.2, 1.2), true, "bed")
	_rug(Rect2(-29, 15, 8, 9), y)
	_painting(Vector3(-12.33, y + 3.0, 20), Vector3.RIGHT, 1.6, 2.2, "portrait")
	_model(RAD, Vector3(-32.0, y, 13), PI / 2, Vector3(1.0, 1.2, 1.3), true, "closet")
	_mega("Nightstand_Shelf", Vector3(-31.8, y, 23.5), PI / 2, 0.0, true)
	_model(RAD, Vector3(-18, y, 24), 0.0, Vector3.ONE, true, "table")
	_model(RAD, Vector3(-18, y, 22.8), PI, Vector3.ONE, false, "chair")
	_fireplace(Vector3(-22, y, 28.4), Vector3.FORWARD)
	_lantern(Vector3(-22, Y2 - 2.0, 18), 2.3, 14.3)


func _upper_sitting_room() -> void:
	var y := Y1
	_rug(Rect2(17, 13, 12, 11), y)
	_painting(Vector3(12.33, y + 3.0, 20), Vector3.LEFT, 2.6, 1.8, "landscape")
	_painting(Vector3(23, y + 3.0, 28.62), Vector3.FORWARD, 1.6, 2.2, "portrait")
	for p in [Vector3(20, y, 16), Vector3(26, y, 16), Vector3(20, y, 21), Vector3(26, y, 21)]:
		_model(RAD, p, PI if p.z > 18 else 0.0, Vector3.ONE * 1.1, false, "chair")
	_mega("Table_Large", Vector3(23, y, 18.5), 0.0, 0.0, true)
	_mega("Chalice", Vector3(22.6, y + 0.88, 18.3), 0.0)
	_mega("Bottle_1", Vector3(23.4, y + 0.88, 18.7), 0.0)
	_model(RAD, Vector3(32.0, y, 10), -PI / 2, Vector3.ONE, true, "bookshelf")
	_fireplace(Vector3(32.6, y, 18.5), Vector3.LEFT)
	_lantern(Vector3(23, Y2 - 2.0, 18), 2.3, 14.3)


# ---------------------------------------------------------------- Patio

func _build_courtyard() -> void:
	var c := Vector3(COURT.get_center().x, F, COURT.get_center().y)
	_span(Vector3(COURT.position.x, F, COURT.position.y), Vector3(COURT.end.x, F + 0.05, COURT.end.y), _m["trim"])
	_fountain(c, 3.4)
	# Cuatro parterres con setos bajos, un árbol y bancos mirando a la fuente.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := c + Vector3(sx * 8.5, 0, sz * 7.0)
			_span(p + Vector3(-4.5, 0.05, -3.5), p + Vector3(4.5, 0.09, 3.5), _m["terrain"])
			for e in [-3.5, 3.5]:
				_span(p + Vector3(-4.5, 0.05, e - 0.3), p + Vector3(4.5, 0.9, e + 0.3), _m["hedge"], true)
			_dead_tree(p + Vector3(0, 0.05, 0), _rng.randf_range(4.0, 5.5))
			_mega("Bench", c + Vector3(sx * 5.5, 0, sz * 4.5), atan2(-sx, -sz), 0.0, true)
	for p in [Vector3(-13, 0, -22), Vector3(13, 0, -22), Vector3(-13, 0, 0), Vector3(13, 0, 0)]:
		var lamp := Props.lamp_post(Vector3(p.x, F, p.z), _m["iron"], _m["lamp_glass"], true, 3.5)
		add_child(lamp)


# ---------------------------------------------------------------- Sótano

## Bodega de vinos bajo el ala noreste y la cámara de seguridad con su puerta redonda de acero.
func _build_basement() -> void:
	var stone: Material = _m["dark_stone"]
	var x0 := 9.0
	var x1 := 33.0
	var z0 := -48.0
	var z1 := -27.0
	_span(Vector3(x0, BASE_Y - 0.4, z0), Vector3(x1, BASE_Y, z1), stone, true)
	_wall(Vector2(x0 + 0.3, z0), Vector2(x0 + 0.3, z1), BASE_Y, F - 0.4, 0.6, stone)
	_wall(Vector2(x1 - 0.3, z0), Vector2(x1 - 0.3, z1), BASE_Y, F - 0.4, 0.6, stone)
	_wall(Vector2(x0, z0 + 0.3), Vector2(x1, z0 + 0.3), BASE_Y, F - 0.4, 0.6, stone)
	_wall(Vector2(x0, z1 - 0.3), Vector2(x1, z1 - 0.3), BASE_Y, F - 0.4, 0.6, stone)
	# Bóvedas: arcos de piedra cada 4 m.
	for x in range(13, 33, 4):
		_span(Vector3(x - 0.3, F - 1.2, z0), Vector3(x + 0.3, F - 0.4, z1), _m["trim"])
	var y := BASE_Y
	# Barricas en sus soportes a lo largo del muro norte y del oeste.
	for x in range(19, 28, 2):  # más allá está el pie de la torre noreste
		_mega("Barrel_Holder", Vector3(x, y, -46.8), 0.0, 0.0, true)
		_mega("Barrel", Vector3(x, y + 0.45, -46.8), PI / 2)
	for z in range(-38, -28, 2):
		_mega("Shelf_Small_Bottles", Vector3(9.9, y + 1.0, z), PI / 2)
		_mega("Shelf_Small_Bottles", Vector3(9.9, y + 2.0, z), PI / 2)
	_mega("Table_Large", Vector3(21, y, -36), 0.0, 0.0, true)
	for s in [-1.0, 1.0]:
		_mega("Stool", Vector3(21 + s * 1.2, y, -35), 0.0)
	_mega("Bottle_1", Vector3(20.6, y + 0.88, -36), 0.0)
	_mega("Mug", Vector3(21.4, y + 0.88, -35.8), 0.0)
	_mega("CandleStick", Vector3(21, y + 0.88, -36.3), 0.0)
	for p in [Vector3(16, y, -29), Vector3(17.2, y, -28.6), Vector3(16.5, y + 0.9, -28.8)]:
		_mega("Barrel", p, _rng.randf() * TAU, 0.0, true)
	_lantern(Vector3(21, F - 1.4, -36), 2.5, 15.6)
	_lantern(Vector3(27, F - 1.4, -42), 2.2, 13.0)
	# Cámara de seguridad (x 9.6..17, z -47.4..-40): muros gruesos y puerta redonda de acero.
	_wall(Vector2(17.3, z0), Vector2(17.3, -39.7), y, F - 0.4, 0.6, stone)
	_wall(Vector2(x0, -39.7), Vector2(17.6, -39.7), y, F - 0.4, 0.6, stone, [[13.3, 2.2, 2.4]])
	var hinge := Node3D.new()
	hinge.position = Vector3(12.2, y + 1.2, -39.3)
	add_child(hinge)
	_vault = hinge
	var door := _cyl(1.15, 0.35, Vector3(1.1, 0, 0), _m["iron"], Basis(Vector3.RIGHT, PI / 2), hinge)
	door.add_to_group(&"metal")
	_solid(Vector3(2.3, 2.3, 0.35), Vector3(1.1, 0, 0), hinge)
	for k in 6:
		var a := TAU * k / 6.0
		_cyl(0.06, 0.6, Vector3(1.1 + cos(a) * 0.45, sin(a) * 0.45, 0.25), _m["gold"], Basis(Vector3.RIGHT, PI / 2), hinge)
	_vault_zone = Interactable.make(Vector3(3.0, 2.4, 2.0), Vector3(13.3, y + 1.2, -38.6), "Abrir la cámara", _toggle_vault)
	add_child(_vault_zone)
	# Dentro: cofres, monedas, la llave de oro y estanterías.
	_mega("Chest_Wood", Vector3(11, y, -46.5), 0.0, 0.0, true)
	_mega("Chest_Wood", Vector3(13.5, y, -46.5), 0.0, 0.0, true)
	for p in [Vector3(15.5, y, -45), Vector3(11.5, y, -43), Vector3(15.8, y, -42)]:
		_mega("Coin_Pile_2", p, _rng.randf() * TAU)
	_mega("Key_Gold", Vector3(13.5, y + 0.75, -46.4), 0.3)
	_mega("Shelf_Simple", Vector3(10.0, y + 1.5, -44), PI / 2)
	_mega("Pouch_Large", Vector3(10.1, y + 1.55, -44.3), 0.0)
	_light(Vector3(13, F - 1.2, -44), 0.8, 6.0, Color(1.0, 0.8, 0.5))


func _toggle_vault() -> void:
	_vault_open = not _vault_open
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_vault, "rotation:y", deg_to_rad(100.0) if _vault_open else 0.0, 1.6)
	_vault_zone.set_prompt("Cerrar la cámara" if _vault_open else "Abrir la cámara")


# ---------------------------------------------------------------- Adornos

## Cara plana con un material (las texturas pintadas en código van en quads).
func _quad(size: Vector2, pos: Vector3, basis: Basis, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = mat
	mi.transform = Transform3D(basis, pos)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _tex_mat(tex: Texture2D, glow := 0.0, cutout := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.8
	if glow > 0.0:
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission = Color.WHITE
		m.emission_energy_multiplier = glow
	if cutout:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	return m


## Cuadro con marco dorado colgado de un muro (normal: hacia la sala). kind: portrait,
## landscape, mural o tapestry (tapiz, sin marco); variant elige la pintura.
func _painting(pos: Vector3, normal: Vector3, w: float, h: float, kind: String, variant := -1) -> void:
	var along := Vector3.UP.cross(normal)
	var basis := Basis(along, Vector3.UP, normal)
	if variant < 0:
		variant = _rng.randi() % 4
	var tex: Texture2D
	match kind:
		"portrait":
			tex = _portrait_tex(variant)
		"tapestry":
			tex = _rug_tex(variant)
		_:
			tex = _mural_tex(variant)
	_quad(Vector2(w, h), pos + normal * 0.04, basis, _tex_mat(tex))
	if kind == "tapestry":
		_box(Vector3(w + 0.4, 0.08, 0.08), pos + Vector3.UP * (h / 2.0 + 0.05) + normal * 0.06, _m["gold"], false, basis)
		return
	var f := 0.12 if w < 4.0 else 0.22
	for s in [-1.0, 1.0]:
		_box(Vector3(w + f * 2.0, f, 0.1), pos + Vector3.UP * s * (h / 2.0 + f / 2.0) + normal * 0.05, _m["gold"], false, basis)
		_box(Vector3(f, h, 0.1), pos + along * s * (w / 2.0 + f / 2.0) + normal * 0.05, _m["gold"], false, basis)


## Alfombra con cenefa y medallón, tendida en el suelo.
func _rug(r: Rect2, y: float) -> void:
	var c := r.get_center()
	var tex := _rug_tex(_rng.randi() % 4)
	_quad(r.size, Vector3(c.x, y + 0.06, c.y), Basis(Vector3.RIGHT, -PI / 2.0), _tex_mat(tex))


## Columna de piedra con basa, fuste, collarín dorado y capitel (p en XZ).
func _column(p: Vector2, y0: float, y1: float, w: float) -> void:
	_box(Vector3(w, y1 - y0, w), Vector3(p.x, (y0 + y1) / 2.0, p.y), _m["trim"], true)
	_box(Vector3(w * 1.45, 0.5, w * 1.45), Vector3(p.x, y0 + 0.25, p.y), _m["dark_stone"])
	_box(Vector3(w * 1.15, 0.12, w * 1.15), Vector3(p.x, y1 - 0.75, p.y), _m["gold"])
	_box(Vector3(w * 1.5, 0.6, w * 1.5), Vector3(p.x, y1 - 0.3, p.y), _m["dark_stone"])


## Vigas de roble bajo un techo (rect en XZ), cada 3 m a lo largo de x.
func _beams(r: Rect2, y: float) -> void:
	var z := r.position.y + 1.5
	while z < r.end.y - 0.5:
		_box(Vector3(r.size.x, 0.45, 0.35), Vector3(r.get_center().x, y - 0.22, z), _m["beam"])
		z += 3.0


## Aplique de pared: placa y brazo de hierro con una vela encendida (sin luz propia: solo brilla).
func _sconce(pos: Vector3, normal: Vector3) -> void:
	var basis := Basis(Vector3.UP.cross(normal), Vector3.UP, normal)
	_box(Vector3(0.18, 0.4, 0.04), pos, _m["iron"], false, basis)
	_box(Vector3(0.05, 0.05, 0.35), pos + normal * 0.18 - Vector3.UP * 0.1, _m["gold"], false, basis)
	_cyl(0.05, 0.22, pos + normal * 0.34 + Vector3.UP * 0.03, _m["paper"])
	_box(Vector3(0.04, 0.08, 0.04), pos + normal * 0.34 + Vector3.UP * 0.18, _m["fire"])


func _pedestal_vase(p: Vector3) -> void:
	_box(Vector3(0.8, 1.1, 0.8), p + Vector3.UP * 0.55, _m["trim"], true)
	_box(Vector3(0.95, 0.1, 0.95), p + Vector3.UP * 1.15, _m["gold"])
	_mega("Vase_4" if _rng.randf() < 0.5 else "Vase_2", p + Vector3.UP * 1.2, _rng.randf() * TAU, 0.9)


## Dosel de cama: cuatro postes, marco y cielo de tela roja con cortinas recogidas.
func _canopy(c: Vector3, size: Vector2) -> void:
	var h := 3.2
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := c + Vector3(sx * size.x / 2.0, 0, sz * size.y / 2.0)
			_cyl(0.08, h, p + Vector3.UP * h / 2.0, _m["oak"])
			_box(Vector3(0.35, h - 0.6, 0.35), p + Vector3(-sx * 0.15, h / 2.0 + 0.2, -sz * 0.15), _m["carpet"])
	_span(c + Vector3(-size.x / 2.0 - 0.1, h, -size.y / 2.0 - 0.1), c + Vector3(size.x / 2.0 + 0.1, h + 0.25, size.y / 2.0 + 0.1), _m["oak"])
	_span(c + Vector3(-size.x / 2.0, h - 0.4, -size.y / 2.0), c + Vector3(size.x / 2.0, h, size.y / 2.0), _m["carpet"])


## Arrimadero de roble por dentro de un muro exterior (a-b en XZ), en la planta baja y el primer piso.
func _panel_strips(a: Vector2, b: Vector2, inward: Vector3) -> void:
	for piece in _outside_towers(a, b):
		var p0: Vector2 = piece[0]
		var p1: Vector2 = piece[1]
		for y in [F, Y1]:
			var spans := [[p0, p1]]
			if y == Y1 and p0.y == p1.y and p0.y < 0.0:
				# Al norte, el salón de baile es de doble altura: en el primer piso no hay sala.
				spans = [[p0, Vector2(-22, p0.y)], [Vector2(22, p0.y), p1]]
			for sp in spans:
				var q0: Vector2 = sp[0]
				var q1: Vector2 = sp[1]
				if q0.distance_to(q1) < 0.5 or (q1 - q0).dot(p1 - p0) < 0.0:
					continue
				var lo := Vector3(minf(q0.x, q1.x), y, minf(q0.y, q1.y)) + inward
				var hi := Vector3(maxf(q0.x, q1.x), y + 1.3, maxf(q0.y, q1.y)) + inward
				var t := Vector3(0.04 if q0.x == q1.x else 0.0, 0, 0.04 if q0.y == q1.y else 0.0)
				_span(lo - t, hi + t, _m["oak"])
				_span(lo - t * 1.6 + Vector3.UP * 1.3, hi + t * 1.6 + Vector3.UP * 0.1, _m["gold"])


## Rosetón: vitral redondo a las dos caras del muro (normal: hacia fuera) con aro de piedra.
func _rose_window(center: Vector3, normal: Vector3, r: float) -> void:
	var along := Vector3.UP.cross(normal)
	var mat := _tex_mat(_rose_tex(), 0.5, true)
	_quad(Vector2(r, r) * 2.0, center + normal * (WT / 2.0 + 0.03), Basis(along, Vector3.UP, normal), mat)
	_quad(Vector2(r, r) * 2.0, center - normal * (WT / 2.0 + 0.03), Basis(-along, Vector3.UP, -normal), mat)
	for k in 24:
		var a := TAU * k / 24.0
		var p := center + (along * cos(a) + Vector3.UP * sin(a)) * (r + 0.15)
		for side in [1.0, -1.0]:
			_box(Vector3(1.2, 0.35, 0.3), p + normal * side * (WT / 2.0 + 0.1), _m["trim"], false,
					Basis(along, Vector3.UP, normal) * Basis(Vector3.BACK, a + PI / 2.0))


# ---------------------------------------------------------------- Texturas pintadas en código

static func _tex(key: String, img: Image) -> ImageTexture:
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex


const GLASS := [Color(0.62, 0.06, 0.05), Color(0.08, 0.16, 0.62), Color(0.85, 0.6, 0.12), Color(0.08, 0.42, 0.18), Color(0.4, 0.1, 0.48)]


## Vitral: rombos de colores entre plomos, cenefa dorada y un medallón con la V.
static func _stained_tex(variant: int) -> Texture2D:
	var key := "stained%d" % variant
	if _textures.has(key):
		return _textures[key]
	var w := 48
	var h := 96
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var lead := Color(0.03, 0.03, 0.03)
	for y in h:
		for x in w:
			var c: Color
			var u := (x + y * 0.5) / 9.0
			var v := (x - y * 0.5) / 9.0
			if x < 2 or y < 2 or x >= w - 2 or y >= h - 2:
				c = lead
			elif x < 5 or y < 5 or x >= w - 5 or y >= h - 5:
				c = Color(0.9, 0.7, 0.25) if (x + y) % 6 > 1 else lead
			else:
				var d := Vector2(x - w / 2.0, y - 36.0).length()
				if absf(d - 13.0) < 1.0 or absf(fposmod(u, 1.0)) < 0.13 or absf(fposmod(v, 1.0)) < 0.13:
					c = lead if d > 14.0 or absf(d - 13.0) < 1.0 else GLASS[(variant + 2) % 5]
				elif d < 13.0:
					c = GLASS[(variant + int(d / 4.5)) % 5]
					# La V de la casa en el medallón.
					var lx := absf(x - w / 2.0)
					if y > 28 and y < 44 and absf(lx - (44 - y) * 0.45) < 1.3:
						c = Color(0.95, 0.75, 0.3)
				else:
					c = GLASS[absi(int(floor(u)) * 7 + int(floor(v)) * 3 + variant) % 5]
				c = c * (0.85 + 0.3 * fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5, 1.0))
			img.set_pixel(x, y, c)
	return _tex(key, img)


## Rosetón: anillos y pétalos de colores entre plomos, fuera del círculo transparente.
static func _rose_tex() -> Texture2D:
	if _textures.has("rose"):
		return _textures["rose"]
	var n := 192
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var lead := Color(0.03, 0.03, 0.03)
	for y in n:
		for x in n:
			var p := Vector2(x - n / 2.0, y - n / 2.0) / (n / 2.0)
			var r := p.length()
			if r > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var ring := int(r * 5.0)
			var sectors := 6 + ring * 6
			var a := fposmod(p.angle(), TAU) / TAU * sectors
			var c: Color
			if r > 0.96 or fposmod(r * 5.0, 1.0) < 0.07 or (ring > 0 and fposmod(a, 1.0) < 0.06 * (1.0 + ring * 0.5)):
				c = lead
			elif ring == 0:
				c = Color(0.9, 0.68, 0.2)
			else:
				c = GLASS[(ring * 2 + int(a)) % 5]
			img.set_pixel(x, y, c)
	return _tex("rose", img)


## Pintura de paisaje o mural: cielo de ceniza, sol rojo, montes, las agujas de Kredik Shaw y,
## abajo, una procesión de figuras (algunas con capa roja de la casa).
static func _mural_tex(variant: int) -> Texture2D:
	var key := "mural%d" % variant
	if _textures.has(key):
		return _textures[key]
	var w := 320
	var h := 144
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + variant
	var noise := FastNoiseLite.new()
	noise.seed = variant
	noise.frequency = 0.02
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var sun := Vector2(rng.randf_range(50, 270), rng.randf_range(28, 50))
	var spires := []
	for i in 7:
		spires.append(Vector3(rng.randf_range(120, 200), rng.randf_range(40, 75), rng.randf_range(2.5, 5.0)))
	for y in h:
		for x in w:
			var t := float(y) / h
			var c := Color(0.22, 0.07, 0.05).lerp(Color(0.78, 0.45, 0.22), clampf(t * 1.6, 0.0, 1.0))
			if Vector2(x, y).distance_to(sun) < 14.0:
				c = Color(0.95, 0.4, 0.15)
			for s: Vector3 in spires:
				if y > s.y and absf(x - s.x) < s.z * (y - s.y) / 30.0 + 0.6 and y < 100:
					c = Color(0.12, 0.09, 0.1)
			if y > 82.0 + noise.get_noise_1d(x) * 22.0:
				c = Color(0.24, 0.14, 0.1)
			if y > 100.0 + noise.get_noise_1d(x + 500) * 10.0:
				c = Color(0.13, 0.08, 0.07)
			img.set_pixel(x, y, c * (0.9 + 0.2 * noise.get_noise_2d(x * 4, y * 4)))
	# Procesión de figuras.
	for i in 18:
		var fx := rng.randi_range(8, w - 8)
		var base := rng.randi_range(128, 140)
		var cloak: Color = [Color(0.06, 0.05, 0.05), Color(0.45, 0.05, 0.04), Color(0.7, 0.55, 0.25)][rng.randi() % 3]
		img.fill_rect(Rect2i(fx - 3, base - 22, 7, 22), cloak)
		img.fill_rect(Rect2i(fx - 2, base - 28, 5, 6), Color(0.5, 0.36, 0.28))
	return _tex(key, img)


## Retrato al óleo: fondo oscuro, busto con casaca y cuello, cara y pelo.
static func _portrait_tex(variant: int) -> Texture2D:
	var key := "portrait%d" % variant
	if _textures.has(key):
		return _textures[key]
	var w := 64
	var h := 96
	var bgs := [Color(0.1, 0.14, 0.09), Color(0.2, 0.06, 0.05), Color(0.08, 0.08, 0.14), Color(0.14, 0.1, 0.06)]
	var coats := [Color(0.05, 0.05, 0.06), Color(0.42, 0.05, 0.04), Color(0.1, 0.12, 0.3), Color(0.2, 0.18, 0.16)]
	var skins := [Color(0.78, 0.6, 0.5), Color(0.6, 0.44, 0.34), Color(0.85, 0.7, 0.6), Color(0.5, 0.36, 0.28)]
	var hairs := [Color(0.08, 0.05, 0.04), Color(0.45, 0.4, 0.38), Color(0.3, 0.18, 0.08), Color(0.6, 0.5, 0.3)]
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var c: Color = (bgs[variant % 4] as Color) * (1.3 - Vector2(x - 32, y - 40).length() / 70.0)
			var half := 15.0 + (y - 60) * 0.35
			if y > 60 and absf(x - 32) < half:
				c = coats[variant % 4]
				if y < 70 and absf(x - 32) < 5:
					c = Color(0.85, 0.82, 0.75)
			var head := Vector2((x - 32) / 10.0, (y - 40) / 13.0).length()
			if head < 1.0:
				c = skins[variant % 4]
				if y < 33 or (head > 0.85 and y < 44):
					c = hairs[variant % 4]
				if y > 37 and y < 40 and absf(absf(x - 32) - 4) < 1.2:
					c = Color(0.1, 0.06, 0.05)
			if y > 56 and y < 60 and absf(x - 32) < 3:
				c = skins[variant % 4] * 0.85
			img.set_pixel(x, y, c)
	return _tex(key, img)


## Alfombra (o tapiz): campo de color, cenefas, puntos y un medallón romboidal.
static func _rug_tex(variant: int) -> Texture2D:
	var key := "rug%d" % variant
	if _textures.has(key):
		return _textures[key]
	var w := 96
	var h := 144
	var fields := [Color(0.36, 0.05, 0.04), Color(0.08, 0.1, 0.26), Color(0.3, 0.06, 0.04), Color(0.1, 0.2, 0.12)]
	var field: Color = fields[variant % 4]
	var gold := Color(0.62, 0.45, 0.16)
	var dark := Color(0.06, 0.06, 0.12)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var e := mini(mini(x, w - 1 - x), mini(y, h - 1 - y))
			var c := field
			if e < 3:
				c = dark
			elif e < 10:
				c = gold if (x + y) % 8 < 4 else gold * 0.75
			elif e < 15:
				c = dark if (x / 3 + y / 3) % 3 != 0 else gold
			else:
				var d := absf(x - w / 2.0) / 30.0 + absf(y - h / 2.0) / 50.0
				if d < 0.45:
					c = field * 1.5
				elif d < 1.0:
					c = gold if d > 0.9 or d < 0.52 else dark
				elif (x / 6 + y / 6) % 2 == 0 and (x % 6 == 3 and y % 6 == 3):
					c = gold
			img.set_pixel(x, y, c * (0.92 + 0.16 * fposmod(sin(x * 3.7 + y * 9.1) * 437.5, 1.0)))
	return _tex(key, img)

