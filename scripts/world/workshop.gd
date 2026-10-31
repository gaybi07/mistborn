class_name Workshop
extends Building
## Taller de carpintería de Clubs (escenario 1), en el Distrito Skaa con la fachada a la calle. Casa skaa estrecha y larga: planta baja de piedra, piso alto de entramado de madera
## que vuela sobre la calle y tejado a dos aguas cubierto de ceniza.
## Planta baja (8 × 18 m): bancos de trabajo en los dos muros, mesa de montaje y hogar en el
## centro, herramientas, patas de silla colgadas y, al fondo, un armario pesado. Con E se abren
## las puertas, se empuja el armario y se abre la trampilla que tapaba; la escalera baja 2,75 m
## al sótano de la banda (8 × 9 m), donde caben cómodos diez: mesa larga de caballetes con diez
## sillas dispares, estufa de hierro, armero escondido y provisiones.
## Muebles: con USE_PACKS salen de los packs CC0 (Quaternius Fantasy Props MegaKit y el Medieval
## Furniture de Wovkulaka Games); sin él, todo es boceto hecho con cajas.
## Coordenadas locales: +Z mira a la calle (la puerta está en z = +L/2), el suelo está en y = 0.

const POS := Vector2(-60, 189.5)  ## en el Distrito Skaa, sobre la calle que sale de la avenida del sur
const YAW := PI  ## la fachada mira al norte, a la calle
## Celdas del suelo de la ciudad que se quitan (en el mundo); el taller pone su suelo y rellena el resto.
const GROUND_HOLE := Rect2(POS.x - 6, POS.y - 11.5, 12, 21)  ## hueco en el terreno (ver tools/terrain/bake_terrain.gd)

const W := 8.0  ## ancho exterior
const L := 18.0  ## largo exterior
const T := 0.35  ## grosor de los muros de piedra
const H := 3.2  ## altura del techo de la planta baja
const UP_H := 2.6  ## altura del piso alto
const DEPTH := 2.75  ## del suelo de la planta baja al del sótano
const BASEMENT_L := 9.0  ## el sótano va bajo la mitad del fondo (de z = -L/2 a z = -L/2 + BASEMENT_L)
const DOOR_HALF := 0.9
## Hueco de la escalera (x, z), pegado al muro derecho; el armario lo tapa.
const STAIR_X := Vector2(2.65, 3.65)
const STAIR_TOP := -8.15  ## z donde empieza a bajar (detrás hay un rellano)
const STAIR_RUN := 2.95  ## largo de la rampa (43°, menos que floor_max_angle)
const HOLE_END := -5.55  ## fin del hueco en el suelo (deja 2,25 m de cabeza al bajar)
const WARDROBE_Z := -7.1  ## el armario (3,1 m) va del muro del fondo al final del hueco
const USE_PACKS := true
## Modelos del pueblo que tienen equivalente más detallado en el MegaKit.
const MEGA_SWAP := {"props/Barrel": "Barrel", "props/Crate": "Crate_Wooden"}
const WARDROBE_SLIDE := 3.25  ## hasta dejar libre el hueco (si no, la cabeza da con él al bajar)

var _batch: ModelBatcher
var _doors: Array[Node3D] = []
var _doors_open := false
var _door_zone: Interactable
var _wardrobe: Node3D
var _trapdoor: Node3D
var _secret := 0  ## 0 armario en su sitio, 1 armario apartado, 2 trampilla abierta
var _secret_zone: Interactable
var _stove_light: OmniLight3D
var _hearth_light: OmniLight3D
var _t := 0.0


func _ready() -> void:
	_rng.seed = 147
	position = Vector3(POS.x, 0, POS.y)
	rotation.y = YAW
	_make_materials()
	_batch = ModelBatcher.new()
	add_child(_batch)
	_build_shell()
	_build_upper_floor()
	_build_roof()
	_build_front()
	_build_ground_floor()
	_build_secret()
	_build_basement()
	_build_ash()
	_clear_fog(Vector3(W - T * 2.0, H + DEPTH + 0.2, L - T * 2.0), Vector3(0, (H - DEPTH) / 2.0, 0))
	_indoor_zone(Vector3(W - T * 2.0, H + DEPTH + 0.2, L - T * 2.0), Vector3(0, (H - DEPTH) / 2.0, 0))
	_batch.finalize()


func _process(delta: float) -> void:
	_t += delta
	_stove_light.light_energy = 1.6 + sin(_t * 9.0) * 0.15 + sin(_t * 23.0) * 0.1
	_hearth_light.light_energy = 1.4 + sin(_t * 7.0 + 1.0) * 0.2 + sin(_t * 19.0) * 0.12


# ---------------------------------------------------------------- Piezas

## Modelo del pack de Quaternius escalado a una altura dada (los packs son de juguete).
func _prop(name: String, pos: Vector3, yaw: float, height: float, collide := false) -> void:
	if USE_PACKS and MEGA_SWAP.has(name):
		_mega(MEGA_SWAP[name], pos, yaw, height, collide)
		return
	var path := ModelKit.path(name)
	_batch.add(path, pos, yaw, height / ModelKit.aabb(path).size.y, Color(0.72, 0.68, 0.64), collide)


# ---------------------------------------------------------------- Muros, suelos y techos

func _build_shell() -> void:
	var stone: Material = _m["wall"]
	var hx := W / 2.0
	var hz := L / 2.0
	var ix := hx - T  # interior
	var iz := hz - T
	# Muros de piedra de la planta baja (de -0.15 a H + 0.25), con el hueco de la puerta delante.
	var y0 := -0.15
	var y1 := H + 0.25
	for s in [-1.0, 1.0]:
		_span(Vector3(s * hx - (T if s > 0 else 0.0), y0, -hz), Vector3(s * hx + (0.0 if s > 0 else T), y1, hz), stone, true)
		_span(Vector3(s * DOOR_HALF if s > 0 else -ix, y0, iz), Vector3(ix if s > 0 else -DOOR_HALF, y1, hz), stone, true)
	_span(Vector3(-ix, y0, -hz), Vector3(ix, y1, -iz), stone, true)
	_span(Vector3(-DOOR_HALF, 2.4, iz), Vector3(DOOR_HALF, y1, hz), stone, true)
	# Suelo de tablones (con el hueco de la escalera tras el rellano del fondo).
	var floor_mat: Material = _m["floor"]
	_span(Vector3(-ix, -0.15, HOLE_END), Vector3(ix, 0, hz), floor_mat, true)
	_span(Vector3(-ix, -0.15, -iz), Vector3(STAIR_X.x, 0, HOLE_END), floor_mat, true)
	_span(Vector3(STAIR_X.x, -0.15, -iz), Vector3(ix, 0, STAIR_TOP), floor_mat, true)
	# Techo: forjado del piso alto (vuela 15 cm sobre los muros) con vigas debajo.
	_span(Vector3(-hx - 0.15, H, -hz - 0.15), Vector3(hx + 0.15, H + 0.27, hz + 0.15), _m["beam"], true)
	var z := -iz + 0.6
	while z < iz:
		_box(Vector3(ix * 2.0, 0.24, 0.2), Vector3(0, H - 0.12, z), _m["beam"])
		z += 1.6
	# Relleno del suelo de la ciudad alrededor: el terreno quita una celda de 2 m más allá del hueco,
	# así que el relleno sobra GAP por cada lado (apenas por debajo del terreno, para no pisarse).
	var ground: Material = _m["ground"]
	var gap := 2.5
	var gx := GROUND_HOLE.size.x / 2.0 + gap  # el hueco está centrado en x; con YAW = PI, z local = POS.y - z
	var gz0 := POS.y - GROUND_HOLE.end.y - gap
	var gz1 := POS.y - GROUND_HOLE.position.y + gap
	for s in [-1.0, 1.0]:
		_span(Vector3(minf(s * hx, s * gx), -0.5, gz0), Vector3(maxf(s * hx, s * gx), -0.03, gz1), ground, true)
	_span(Vector3(-hx, -0.5, hz), Vector3(hx, -0.03, gz1), ground, true)
	_span(Vector3(-hx, -0.5, gz0), Vector3(hx, -0.03, -hz), ground, true)


func _build_upper_floor() -> void:
	var y0 := H + 0.27
	var ox := W / 2.0 + 0.15
	var oz := L / 2.0 + 0.15
	var pl: Material = _m["plaster"]
	for s in [-1.0, 1.0]:
		_span(Vector3(s * ox - (0.25 if s > 0 else 0.0), y0, -oz), Vector3(s * ox + (0.0 if s > 0 else 0.25), y0 + UP_H, oz), pl, true)
		_span(Vector3(-ox + 0.25, y0, s * oz - (0.25 if s > 0 else 0.0)), Vector3(ox - 0.25, y0 + UP_H, s * oz + (0.0 if s > 0 else 0.25)), pl, true)
	# Entramado de vigas oscuras en las cuatro caras, con ventanas con postigos.
	var faces := [[Vector3(0, 0, oz), Vector3.BACK, ox * 2.0, [1, 4]], [Vector3(0, 0, -oz), Vector3.FORWARD, ox * 2.0, [2, 3]],
			[Vector3(ox, 0, 0), Vector3.RIGHT, oz * 2.0, [2, 5, 8, 11]], [Vector3(-ox, 0, 0), Vector3.LEFT, oz * 2.0, [3, 6, 9]]]
	var lit_count := 0
	for f in faces:
		var center: Vector3 = f[0]
		var normal: Vector3 = f[1]
		var length: float = f[2]
		var along := Vector3.UP.cross(normal)
		var n := maxi(int(round(length / 1.4)), 2)
		_timber_face(center, normal, length, y0, n)
		for k: int in f[3]:
			var t := -length / 2.0 + length * (k + 0.5) / n
			_window(center + along * t + Vector3.UP * (y0 + 1.8) - normal * 0.125, normal, 0.6, 0.7, 0.25, "window_lit" if lit_count % 2 == 0 else "window_dark")
			lit_count += 1


func _timber_face(center: Vector3, normal: Vector3, length: float, y0: float, n: int) -> void:
	var along := Vector3.UP.cross(normal)
	var basis := Basis(along, Vector3.UP, normal)
	var beam: Material = _m["beam"]
	for i in n + 1:
		var t := -length / 2.0 + length * i / n
		_box(Vector3(0.18, UP_H, 0.08), center + along * t + normal * 0.04 + Vector3.UP * (y0 + UP_H / 2.0), beam, false, basis)
	for y in [y0 + 0.09, y0 + 1.2, y0 + UP_H - 0.09]:
		_box(Vector3(length + 0.1, 0.16, 0.08), center + normal * 0.05 + Vector3.UP * y, beam, false, basis)
	# Riostras en cruz de San Andrés en los paños de los extremos (mitad de abajo).
	var pw := length / n
	for k in [0, n - 1]:
		var a: float = -length / 2.0 + pw * k
		for flip in [false, true]:
			var p0 := Vector2(a + (pw if flip else 0.0), y0 + 0.12)
			var p1 := Vector2(a + (0.0 if flip else pw), y0 + 1.15)
			var d := p1 - p0
			var mid := (p0 + p1) / 2.0
			_box(Vector3(d.length(), 0.13, 0.07), center + along * mid.x + normal * 0.045 + Vector3.UP * mid.y, beam, false,
					basis * Basis(Vector3.BACK, atan2(d.y, d.x)))


## Ventana: vidrio que atraviesa el muro (se ve desde los dos lados), marco y postigos abiertos.
func _window(center: Vector3, normal: Vector3, w: float, h: float, depth: float, glass: String, bars := false) -> void:
	var along := Vector3.UP.cross(normal)
	var basis := Basis(along, Vector3.UP, normal)
	_box(Vector3(w, h, depth + 0.04), center, _m[glass], false, basis)
	var face := center + normal * (depth / 2.0 + 0.04)
	_box(Vector3(w + 0.14, 0.08, 0.1), face + Vector3.UP * (h / 2.0 + 0.04), _m["beam"], false, basis)
	_box(Vector3(w + 0.2, 0.08, 0.16), face + Vector3.UP * -(h / 2.0 + 0.04), _m["beam"], false, basis)
	for s in [-1.0, 1.0]:
		_box(Vector3(w / 2.0 + 0.02, h + 0.04, 0.04), face + along * s * (w * 0.75 + 0.1), _m["boards"], false,
				basis * Basis(Vector3.UP, s * 0.35))
	if bars:
		for i in 3:
			_box(Vector3(0.025, h, 0.025), face + along * (i - 1) * w / 4.0, _m["iron"], false, basis)


func _build_roof() -> void:
	var y0 := H + 0.27 + UP_H
	var ox := W / 2.0 + 0.15
	var oz := L / 2.0 + 0.15
	var rise := 3.4
	var eave := 0.4
	# Hastiales de revoque (se ven en los extremos, bajo el vuelo del tejado).
	var gable := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(ox * 2.0, rise, oz * 2.0)
	gable.mesh = prism
	gable.material_override = _m["plaster"]
	gable.position = Vector3(0, y0 + rise / 2.0, 0)
	add_child(gable)
	var slope := atan2(rise, ox)
	var run := ox + eave
	var length := run / cos(slope)
	for s in [-1.0, 1.0]:
		var normal := Vector3(s * sin(slope), cos(slope), 0)
		var mid := Vector3(s * run / 2.0, y0 + rise - (run / 2.0) * tan(slope), 0)
		_box(Vector3(length + 0.15, 0.18, oz * 2.0 + 0.8), mid + normal * 0.09, _m["roof_ash"], true, Basis(Vector3.BACK, -s * slope))
	_box(Vector3(0.22, 0.22, oz * 2.0 + 0.9), Vector3(0, y0 + rise + 0.12, 0), _m["beam"])
	# Chimenea de la estufa del sótano, de piedra, por el muro izquierdo.
	_span(Vector3(-ox - 0.7, 0, -1.25), Vector3(-ox, y0 + rise + 0.8, -0.45), _m["wall"], true)
	_span(Vector3(-ox - 0.78, y0 + rise + 0.8, -1.33), Vector3(-ox + 0.08, y0 + rise + 0.95, -0.37), _m["trim"])


# ---------------------------------------------------------------- Fachada y puertas

func _build_front() -> void:
	var hz := L / 2.0
	var beam: Material = _m["beam"]
	# Marco de la puerta doble.
	for s in [-1.0, 1.0]:
		_box(Vector3(0.16, 2.5, 0.12), Vector3(s * (DOOR_HALF + 0.08), 1.25, hz + 0.04), beam)
	_box(Vector3(DOOR_HALF * 2.0 + 0.5, 0.22, 0.14), Vector3(0, 2.5, hz + 0.05), beam)
	# Hojas: tablones con dos flejes de hierro y una argolla; giran hacia dentro.
	for s in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(s * DOOR_HALF, 0, hz - T / 2.0)
		add_child(hinge)
		var leaf := _box(Vector3(DOOR_HALF - 0.02, 2.38, 0.07), Vector3(-s * DOOR_HALF / 2.0, 1.2, 0), _m["boards"], true, Basis(), hinge)
		for y in [0.45, 1.95]:
			_box(Vector3(DOOR_HALF - 0.1, 0.07, 0.09), Vector3(0, y - 1.2, 0), _m["iron"], false, Basis(), leaf)
		_cyl(0.06, 0.02, Vector3(s * (DOOR_HALF / 2.0 - 0.12), 1.05 - 1.2, 0.06), _m["iron"], Basis(Vector3.RIGHT, PI / 2), leaf)
		_doors.append(hinge)
	_door_zone = Interactable.make(Vector3(2.6, 2.0, 2.4), Vector3(0, 1.0, hz - T / 2.0), "Abrir las puertas", _toggle_doors)
	add_child(_door_zone)
	# Letrero colgado sobre la puerta y un farol de pared.
	_box(Vector3(0.05, 0.05, 0.75), Vector3(0, 3.05, hz + 0.37), _m["iron"])
	_box(Vector3(1.5, 0.42, 0.06), Vector3(0, 2.72, hz + 0.68), _m["beam"])
	for s in [-1.0, 1.0]:
		_box(Vector3(0.015, 0.3, 0.015), Vector3(s * 0.6, 2.95, hz + 0.68), _m["iron"])
		var sign := Label3D.new()
		sign.text = "CARPINTERÍA"
		sign.font_size = 64
		sign.pixel_size = 0.0035
		sign.outline_size = 0
		sign.modulate = Color(0.78, 0.7, 0.55)
		sign.position = Vector3(0, 2.72, hz + 0.68 + s * 0.035)
		sign.rotation.y = 0.0 if s > 0 else PI
		add_child(sign)
	_lantern(Vector3(-DOOR_HALF - 0.55, 2.35, hz + 0.25), 1.2, 6.0)
	# Ventanas de la planta baja: pequeñas, con barrotes, en la fachada y en el muro izquierdo.
	for x in [-2.6, 2.6]:
		_window(Vector3(x, 1.7, hz - T / 2.0), Vector3.BACK, 0.7, 0.6, T, "window_night", true)
	for z in [-6.3, -3.0, 3.0, 6.3]:
		_window(Vector3(-W / 2.0 + T / 2.0, 1.85, z), Vector3.LEFT, 0.55, 0.55, T, "window_night", true)


func _toggle_doors() -> void:
	_doors_open = not _doors_open
	for i in _doors.size():
		var s := -1.0 if i == 0 else 1.0
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(_doors[i], "rotation:y", (-s * deg_to_rad(100.0)) if _doors_open else 0.0, 0.7)
	_door_zone.set_prompt("Cerrar las puertas" if _doors_open else "Abrir las puertas")


# ---------------------------------------------------------------- Planta baja

func _build_ground_floor() -> void:
	var ix := W / 2.0 - T
	var iz := L / 2.0 - T
	# Banco largo en el muro izquierdo y otro más corto en el derecho (deja sitio al armario).
	_workbench(Vector3(-ix + 0.4, 0, 0.0), 12.0, 0.8)
	_workbench(Vector3(ix - 0.4, 0, 3.6), 6.0, 0.8)
	# Tablero de herramientas en el muro izquierdo, entre las ventanas del medio.
	var wall_x := -ix + 0.03
	_span(Vector3(wall_x, 1.05, -2.0), Vector3(wall_x + 0.04, 2.25, 2.0), _m["beam"])
	for i in 12:
		var z := -1.76 + i * 0.32
		var kind := i % 3
		if kind == 0:  # sierra
			_box(Vector3(0.02, 0.5, 0.18), Vector3(wall_x + 0.06, 1.6, z), _m["metal"])
			_box(Vector3(0.04, 0.14, 0.12), Vector3(wall_x + 0.07, 1.9, z), _m["pale_wood"])
		elif kind == 1:  # mazo / martillo
			_box(Vector3(0.03, 0.4, 0.03), Vector3(wall_x + 0.07, 1.65, z), _m["pale_wood"])
			_box(Vector3(0.06, 0.08, 0.16), Vector3(wall_x + 0.08, 1.88, z), _m["iron"])
		else:  # gubias y formones
			for k in 3:
				_box(Vector3(0.02, 0.28, 0.02), Vector3(wall_x + 0.06, 1.55 + k * 0.05, z - 0.08 + k * 0.08), _m["metal"])
		_cyl(0.008, 0.08, Vector3(wall_x + 0.06, 2.08, z), _m["iron"], Basis(Vector3.BACK, PI / 2))
	# Cosas sobre los bancos: tornillo de banco, garlopa, sillas a medio hacer.
	var top := 0.94
	_box(Vector3(0.22, 0.14, 0.12), Vector3(-ix + 0.72, top + 0.07, 4.2), _m["iron"])
	_box(Vector3(0.1, 0.1, 0.3), Vector3(-ix + 0.45, top + 0.05, 2.6), _m["pale_wood"])
	_box(Vector3(0.6, 0.04, 0.12), Vector3(-ix + 0.45, top + 0.02, 1.4), _m["bench"])
	_chair(Vector3(-ix + 0.4, top, -3.6), PI / 2, 0.45, 0.0, _m["pale_wood"], false)
	_chair(Vector3(ix - 0.4, top, 2.0), -PI / 2, 0.42, 0.4, _m["pale_wood"], false)
	# Mesa de montaje en el centro con una silla grande a medio armar, y el hogar detrás.
	_assembly_table(Vector3(0, 0, 3.4))
	_hearth(Vector3(0, 0, -2.2))
	# Caballetes con un tablón a medio serrar.
	for z in [-5.6, -4.2]:
		_sawhorse(Vector3(-1.6, 0, z))
	_box(Vector3(0.3, 0.05, 2.6), Vector3(-1.6, 0.75, -4.9), _m["pale_wood"])
	_box(Vector3(0.02, 0.3, 0.5), Vector3(-1.6, 0.9, -4.4), _m["metal"], false, Basis(Vector3.RIGHT, 0.4))
	for i in 30:
		var p := Vector3(_rng.randf_range(-2.8, 2.0), 0.004, _rng.randf_range(-6.5, 7.0))
		_box(Vector3(0.08, 0.008, 0.03), p, _m["pale_wood"], false, Basis(Vector3.UP, _rng.randf() * TAU))
	# Patas de silla torneadas colgando de ganchos sobre el banco derecho.
	_box(Vector3(0.05, 0.05, 5.8), Vector3(ix - 0.12, 2.45, 3.6), _m["beam"])
	for i in 20:
		var z := 0.9 + i * 0.28
		_cyl(0.006, 0.08, Vector3(ix - 0.12, 2.39, z), _m["iron"])
		_cyl(0.028, 0.48, Vector3(ix - 0.12, 2.1, z), _m["pale_wood"], Basis(), self, 0.018)
	# Madera apoyada al fondo a la izquierda, barriles, cajas y sacos.
	for i in 14:
		var x := -ix + 0.12 + i * 0.14
		_box(Vector3(0.12, 2.6, 0.035), Vector3(x, 1.25, -iz + 0.28), _m["pale_wood" if i % 2 == 0 else "bench"], false,
				Basis(Vector3.RIGHT, -0.12 - _rng.randf() * 0.06))
	_prop("props/Barrel", Vector3(-ix + 0.4, 0, iz - 0.6), 0.3, 0.95, true)
	_prop("props/Barrel", Vector3(-ix + 1.3, 0, iz - 0.5), 1.1, 0.95, true)
	_prop("props/Bags", Vector3(ix - 0.5, 0, iz - 0.6), 1.2, 0.6)
	_prop("props/Crate", Vector3(ix - 1.4, 0, iz - 0.45), 0.3, 0.65, true)
	_prop("props/Crate", Vector3(0.2, 0, -iz + 0.4), 0.1, 0.6, true)
	_prop("props/Package_1", Vector3(0.9, 0, -iz + 0.35), 0.5, 0.45)
	if USE_PACKS:
		_mega("Shelf_Simple", Vector3(ix - 0.16, 1.7, 7.4), -PI / 2.0)
		_mega("Shelf_Simple", Vector3(ix - 0.16, 1.2, 7.4), -PI / 2.0)
		_mega("Rope_1", Vector3(ix - 0.5, 0, 7.6), 0.5)
		_mega("Bucket_Wooden_1", Vector3(-1.0, 0, -2.4), 1.0)
		_mega("Cabinet", Vector3(-1.6, 0, -iz + 0.25), 0.0, 0.0, true)
	_lantern(Vector3(0, 2.55, 6.2), 1.8, 8.0, true)
	_lantern(Vector3(-1.8, 2.55, 0.6), 1.5, 7.5)
	_lantern(Vector3(0.8, 2.55, -5.6), 1.4, 7.0)


## Mesa de montaje grande con una silla a medio armar encima y piezas sueltas.
func _assembly_table(pos: Vector3) -> void:
	if USE_PACKS:
		_model(RAD, pos, PI / 2.0, Vector3(1.6, 1.15, 1.25), true, "table")
		var t := 0.85
		_chair(pos + Vector3(0, t, -0.7), 0.4, 0.5, 0.65, _m["red_wood"], false)
		_mega("Workbench_Drawers", pos + Vector3(0.3, t, 0.9), 0.3)
		for k in 5:
			_box(Vector3(0.04, 0.04, 0.5), pos + Vector3(-0.3 + k * 0.12, t + 0.02, 0.4), _m["pale_wood"], false,
					Basis(Vector3.UP, _rng.randf_range(-0.3, 0.3)))
		_mega("Bucket_Wooden_1", pos + Vector3(0.9, 0, 1.6), 0.5)
		return
	var top := 0.88
	_box(Vector3(1.2, 0.09, 3.0), pos + Vector3(0, top - 0.045, 0), _m["bench"])
	_solid(Vector3(1.2, top, 3.0), pos + Vector3(0, top / 2.0, 0))
	for x in [-0.5, 0.5]:
		for z in [-1.35, 1.35]:
			_box(Vector3(0.12, top - 0.09, 0.12), pos + Vector3(x, (top - 0.09) / 2.0, z), _m["beam"])
	_box(Vector3(1.0, 0.06, 2.7), pos + Vector3(0, 0.18, 0), _m["boards"])
	_chair(pos + Vector3(0, top, -0.6), 0.4, 0.5, 0.65, _m["red_wood"], false)
	for k in 5:
		_box(Vector3(0.04, 0.04, 0.5), pos + Vector3(-0.3 + k * 0.12, top + 0.02, 0.7), _m["pale_wood"], false,
				Basis(Vector3.UP, _rng.randf_range(-0.3, 0.3)))
	_box(Vector3(0.12, 0.1, 0.3), pos + Vector3(0.35, top + 0.05, 1.1), _m["pale_wood"])
	_cyl(0.05, 0.06, pos + Vector3(-0.35, top + 0.03, 1.2), _m["rusty"])


## Hogar bajo de piedra con brasas y una luz que parpadea.
func _hearth(pos: Vector3) -> void:
	var stone: Material = _m["trim"]
	for s in [-1.0, 1.0]:
		_box(Vector3(1.3, 0.35, 0.18), pos + Vector3(0, 0.175, s * 0.56), stone, true)
		_box(Vector3(0.18, 0.35, 0.94), pos + Vector3(s * 0.56, 0.175, 0), stone, true)
	_box(Vector3(0.94, 0.1, 0.94), pos + Vector3(0, 0.05, 0), _m["iron"])
	for i in 6:
		_box(Vector3(0.5, 0.08, 0.09), pos + Vector3(_rng.randf_range(-0.15, 0.15), 0.14, _rng.randf_range(-0.25, 0.25)), _m["beam"], false,
				Basis(Vector3.UP, _rng.randf() * TAU))
	_box(Vector3(0.6, 0.04, 0.6), pos + Vector3(0, 0.12, 0), _m["fire"])
	_hearth_light = OmniLight3D.new()
	_hearth_light.light_color = Color(1.0, 0.42, 0.15)
	_hearth_light.omni_range = 5.0
	_hearth_light.position = pos + Vector3(0, 0.6, 0)
	add_child(_hearth_light)


## Caballete de carpintero (A con travesaño).
func _sawhorse(pos: Vector3) -> void:
	_box(Vector3(0.9, 0.08, 0.1), pos + Vector3(0, 0.68, 0), _m["bench"])
	for s in [-1.0, 1.0]:
		for t in [-1.0, 1.0]:
			_box(Vector3(0.06, 0.72, 0.06), pos + Vector3(s * 0.36, 0.33, t * 0.12), _m["beam"], false, Basis(Vector3.RIGHT, t * 0.25))
	_solid(Vector3(0.9, 0.7, 0.4), pos + Vector3(0, 0.35, 0))


## Banco de trabajo: tablero grueso, patas, travesaño y balda abajo con tablas. pos = centro en el suelo.
func _workbench(pos: Vector3, length: float, depth: float) -> void:
	if USE_PACKS:  # bancos del MegaKit (2 × 1 m) en fila, de lado contra el muro
		var n := maxi(int(round(length / 2.05)), 1)
		var side := signf(pos.x)
		for i in n:
			var z := pos.z - length / 2.0 + length * (i + 0.5) / n
			_mega("Workbench", Vector3(pos.x - side * (0.51 - depth / 2.0), 0, z), side * PI / 2.0, 0.0, true)
		return
	var top := 0.94
	_box(Vector3(depth, 0.08, length), pos + Vector3(0, top - 0.04, 0), _m["bench"])
	_solid(Vector3(depth, top, length), pos + Vector3(0, top / 2.0, 0))
	var n := maxi(int(length / 1.6), 1)
	for i in n + 1:
		var z := -length / 2.0 + 0.08 + (length - 0.16) * i / n
		for s in [-1.0, 1.0]:
			_box(Vector3(0.09, top - 0.08, 0.09), pos + Vector3(s * (depth / 2.0 - 0.07), (top - 0.08) / 2.0, z), _m["beam"])
	_box(Vector3(depth - 0.1, 0.04, length - 0.1), pos + Vector3(0, 0.22, 0), _m["boards"])
	for k in 4:
		_box(Vector3(0.18, 0.03, length * _rng.randf_range(0.4, 0.8)), pos + Vector3(-0.2 + k * 0.13, 0.25 + 0.03 * (k % 2), _rng.randf_range(-0.5, 0.5)), _m["pale_wood"])


## Silla sencilla de carpintero. back = alto del respaldo (0 = taburete). pos = centro en el suelo.
func _chair(pos: Vector3, yaw: float, seat: float, back: float, mat: Material, solid := true) -> void:
	var node := Node3D.new()
	node.position = pos
	node.rotation.y = yaw
	add_child(node)
	_box(Vector3(0.42, 0.04, 0.4), Vector3(0, seat, 0), mat, false, Basis(), node)
	for x in [-0.18, 0.18]:
		for z in [-0.17, 0.17]:
			var h := seat + (back if z < 0 else 0.0)
			_box(Vector3(0.035, h, 0.035), Vector3(x, h / 2.0, z), mat, false, Basis(), node)
	if back > 0.0:
		for k in 2:
			_box(Vector3(0.38, 0.05, 0.025), Vector3(0, seat + back * (0.5 + k * 0.4), -0.17), mat, false, Basis(), node)
	if solid:
		_solid(Vector3(0.42, seat + 0.04, 0.4), Vector3(0, (seat + 0.04) / 2.0, 0), node)


# ---------------------------------------------------------------- Armario y trampilla

func _build_secret() -> void:
	var ix := W / 2.0 - T
	var depth := 0.95
	var length := 3.1
	var h := 2.3
	_wardrobe = Node3D.new()
	_wardrobe.position = Vector3(ix - depth / 2.0, 0, WARDROBE_Z)
	add_child(_wardrobe)
	if USE_PACKS:  # tres roperos tallados juntos, del pack de Wovkulaka (1 m de ancho cada uno)
		var body := StaticBody3D.new()
		body.collision_layer = Props.LAYER_WORLD
		body.collision_mask = 0
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(depth, 2.3, length)
		col.shape = shape
		col.position.y = 1.15
		body.add_child(col)
		_wardrobe.add_child(body)
		for i in 3:
			_model(RAD, Vector3(0.04, 0, -length / 3.0 + i * length / 3.0), -PI / 2.0, Vector3(1.03, 1.1, 1.5), false, "closet", _wardrobe)
		_build_trapdoor()
		return
	_box(Vector3(depth, h, length), Vector3(0, h / 2.0, 0), _m["boards"], true, Basis(), _wardrobe)
	_box(Vector3(depth + 0.08, 0.12, length + 0.08), Vector3(0, h + 0.06, 0), _m["beam"], false, Basis(), _wardrobe)
	_box(Vector3(depth + 0.04, 0.1, length + 0.04), Vector3(0, 0.05, 0), _m["beam"], false, Basis(), _wardrobe)
	for z in [-length / 4.0, length / 4.0]:  # dos cuerpos con dos puertas cada uno
		for s in [-1.0, 1.0]:
			_box(Vector3(0.03, h - 0.4, length / 4.0 - 0.06), Vector3(-depth / 2.0 - 0.01, h / 2.0, z + s * length / 8.0), _m["red_wood"], false, Basis(), _wardrobe)
			_box(Vector3(0.04, 0.12, 0.03), Vector3(-depth / 2.0 - 0.04, h / 2.0, z + s * 0.06), _m["iron"], false, Basis(), _wardrobe)
	_build_trapdoor()


## Trampilla: tablones con fleje y argolla; gira sobre el muro derecho.
func _build_trapdoor() -> void:
	var ix := W / 2.0 - T
	_trapdoor = Node3D.new()
	_trapdoor.position = Vector3(STAIR_X.y, 0, (STAIR_TOP + HOLE_END) / 2.0)
	add_child(_trapdoor)
	var hole_len := HOLE_END - STAIR_TOP
	var w := STAIR_X.y - STAIR_X.x
	var leaf := _box(Vector3(w, 0.07, hole_len), Vector3(-w / 2.0, -0.035, 0), _m["boards"], true, Basis(), _trapdoor)
	for z in [-hole_len / 3.0, hole_len / 3.0]:
		_box(Vector3(w - 0.06, 0.02, 0.07), Vector3(0, 0.04, z), _m["iron"], false, Basis(), leaf)
	_cyl(0.07, 0.015, Vector3(-w / 2.0 + 0.25, 0.04, 0), _m["iron"], Basis(), leaf)
	_secret_zone = Interactable.make(Vector3(2.6, 2.2, 3.4), Vector3(ix - 1.35, 1.1, WARDROBE_Z + 0.3), "Empujar el armario", _use_secret)
	add_child(_secret_zone)


func _use_secret() -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	match _secret:
		0:
			tw.tween_property(_wardrobe, "position:z", WARDROBE_Z + WARDROBE_SLIDE, 1.6)
			_secret = 1
		1:
			tw.tween_property(_trapdoor, "rotation:z", -deg_to_rad(88.0), 0.8)
			_secret = 2
		2:
			tw.tween_property(_trapdoor, "rotation:z", 0.0, 0.6)
			_secret = 1
	_secret_zone.set_prompt(["", "Abrir la trampilla", "Cerrar la trampilla"][_secret])


# ---------------------------------------------------------------- Sótano

func _build_basement() -> void:
	var hx := W / 2.0
	var ix := hx - T
	var back := -L / 2.0
	var front := back + BASEMENT_L
	var fy := -DEPTH
	var stone: Material = _m["wall"]
	_span(Vector3(-hx, fy - 0.2, back), Vector3(hx, fy, front), _m["ground"], true)
	for s in [-1.0, 1.0]:
		_span(Vector3(minf(s * hx, s * ix), fy - 0.2, back), Vector3(maxf(s * hx, s * ix), -0.15, front), stone, true)
	_span(Vector3(-ix, fy - 0.2, back), Vector3(ix, -0.15, back + T), stone, true)
	_span(Vector3(-ix, fy - 0.2, front - T), Vector3(ix, -0.15, front), stone, true)
	var z := front - T - 0.9
	while z > back + T:
		var x1 := ix if z > HOLE_END else STAIR_X.x
		_span(Vector3(-ix, -0.38, z - 0.1), Vector3(x1, -0.15, z + 0.1), _m["beam"])
		z -= 1.5
	# Viga maestra con dos pies derechos (la sala es ancha).
	_span(Vector3(1.8, -0.62, back + T), Vector3(2.0, -0.38, front - T), _m["beam"])
	for pz in [front - 2.4, back + 2.6]:
		_span(Vector3(1.8, fy, pz - 0.1), Vector3(2.0, -0.62, pz + 0.1), _m["beam"], true)

	# Escalera tosca: rampa invisible para andar (43°) y peldaños de tablón para verla.
	var drop := DEPTH
	var slope := atan2(drop, STAIR_RUN)
	var ramp := StaticBody3D.new()
	ramp.collision_layer = Props.LAYER_WORLD
	ramp.collision_mask = 0
	var rcol := CollisionShape3D.new()
	var rshape := BoxShape3D.new()
	rshape.size = Vector3(STAIR_X.y - STAIR_X.x, 0.1, sqrt(drop * drop + STAIR_RUN * STAIR_RUN) + 0.1)
	rcol.shape = rshape
	var up_normal := Vector3(0, cos(slope), sin(slope))
	rcol.transform = Transform3D(Basis(Vector3.RIGHT, slope),
			Vector3((STAIR_X.x + STAIR_X.y) / 2.0, -drop / 2.0, STAIR_TOP + STAIR_RUN / 2.0) - up_normal * 0.05)
	ramp.add_child(rcol)
	add_child(ramp)
	var steps := 11
	for i in steps - 1:
		var top := -drop * (i + 1) / steps
		var z0 := STAIR_TOP + STAIR_RUN * i / steps
		_span(Vector3(STAIR_X.x, fy, z0), Vector3(STAIR_X.y, top, z0 + STAIR_RUN / steps + 0.02), _m["boards"])
		_box(Vector3(STAIR_X.y - STAIR_X.x, 0.04, 0.06), Vector3((STAIR_X.x + STAIR_X.y) / 2.0, top - 0.02, z0 + STAIR_RUN / steps), _m["beam"])

	# Mesa larga de caballetes para diez: cuatro sillas por lado y una en cada cabecera, ninguna igual.
	var tx := -0.6
	var tz := (back + front) / 2.0
	var tl := 3.6
	if USE_PACKS:  # mesa grande del MegaKit estirada a 3,6 m
		_mega("Table_Large", Vector3(tx, fy, tz), PI / 2.0, 0.0, false).scale = Vector3(tl / 2.85, 1.0, 1.0)
		_solid(Vector3(1.1, 0.8, tl), Vector3(tx, fy + 0.4, tz))
	else:
		_table_trestles(tx, tz, tl, fy)
	_seat_ten(tx, tz, tl, fy)
	_table_things(tx, tz, fy)
	_basement_rest(ix, back, front, fy, tx, tz)


func _table_trestles(tx: float, tz: float, tl: float, fy: float) -> void:
	_box(Vector3(1.0, 0.08, tl), Vector3(tx, fy + 0.76, tz), _m["bench"], true)
	for dz in [-1.4, 0.0, 1.4]:
		for s in [-1.0, 1.0]:
			_box(Vector3(0.07, 0.82, 0.07), Vector3(tx + s * 0.26, fy + 0.37, tz + dz), _m["beam"], false, Basis(Vector3.BACK, s * 0.32))
		_box(Vector3(0.82, 0.06, 0.06), Vector3(tx, fy + 0.62, tz + dz), _m["beam"])
	_box(Vector3(0.06, 0.06, tl - 0.6), Vector3(tx, fy + 0.2, tz), _m["beam"])


## Diez asientos: cuatro por lado y uno en cada cabecera, ninguno igual al de al lado.
func _seat_ten(tx: float, tz: float, tl: float, fy: float) -> void:
	var chair_mats := ["pale_wood", "red_wood", "bench", "boards", "beam"]
	var seats := []  # [posición, yaw]: la silla mira hacia su +z
	for side in [-1.0, 1.0]:
		for i in 4:
			seats.append([Vector3(tx + side * 0.82, fy, tz - 1.275 + i * 0.85), -side * PI / 2.0])
	seats.append([Vector3(tx, fy, tz - tl / 2.0 - 0.45), 0.0])
	seats.append([Vector3(tx, fy, tz + tl / 2.0 + 0.45), PI])
	for k in seats.size():
		var seat := 0.42 + _rng.randf_range(-0.04, 0.05)
		var back_h: float = [0.0, 0.45, 0.6, 0.5][k % 4]
		var pos: Vector3 = seats[k][0]
		var yaw: float = seats[k][1]
		var at := pos + Vector3(_rng.randf_range(-0.05, 0.05), 0, _rng.randf_range(-0.08, 0.08))
		yaw += _rng.randf_range(-0.25, 0.25)
		if USE_PACKS:
			match k % 3:
				0: _model(RAD, at, yaw, Vector3.ONE, true, "chair")
				1: _mega("Chair_1", at, yaw + PI, 0.0, true)
				2: _mega("Stool", at, yaw, 0.0, true)
			continue
		_chair(at, yaw, seat, back_h, _m[chair_mats[k % chair_mats.size()]])


func _table_things(tx: float, tz: float, fy: float) -> void:
	# Sobre la mesa: planos de Luthadel, jarras y velas.
	_box(Vector3(0.6, 0.005, 0.8), Vector3(tx, fy + 0.805, tz - 0.3), _m["paper"], false, Basis(Vector3.UP, 0.15))
	_box(Vector3(0.4, 0.005, 0.5), Vector3(tx + 0.15, fy + 0.806, tz + 0.7), _m["paper"], false, Basis(Vector3.UP, -0.3))
	var top := fy + (0.81 if USE_PACKS else 0.8)
	for i in 8:
		var p := Vector3(_rng.randf_range(-0.38, 0.38), 0, _rng.randf_range(-1.6, 1.6))
		if USE_PACKS:
			_mega("Mug", Vector3(tx + p.x, top, tz + p.z), _rng.randf() * TAU)
		else:
			_cyl(0.045, 0.13, Vector3(tx + p.x, fy + 0.865, tz + p.z), _m["rusty"])
	if USE_PACKS:
		for dz in [-1.2, 1.2]:
			_mega("CandleStick_Triple", Vector3(tx + 0.15, top, tz + dz), 0.4)
		_mega("Scroll_1", Vector3(tx - 0.25, top, tz + 0.3), 0.8)
		_mega("Table_Plate", Vector3(tx + 0.25, top, tz - 0.6), 0.0)
		_mega("Coin_Pile", Vector3(tx - 0.2, top, tz - 1.0), 0.0)
		return
	for dz in [-1.0, 1.1]:
		_cyl(0.03, 0.14, Vector3(tx + 0.1, fy + 0.87, tz + dz), _m["paper"])
		_box(Vector3(0.02, 0.03, 0.02), Vector3(tx + 0.1, fy + 0.955, tz + dz), _m["fire"])


func _basement_rest(ix: float, back: float, front: float, fy: float, tx: float, tz: float) -> void:

	# Estufa de hierro en la esquina noreste, con el tubo hacia la chimenea del muro.
	var st := Vector3(-ix + 0.38, fy, -0.8)
	_box(Vector3(0.6, 0.7, 0.6), st + Vector3(0, 0.5, 0), _m["iron"], true)
	_box(Vector3(0.66, 0.06, 0.66), st + Vector3(0, 0.88, 0), _m["iron"])
	_box(Vector3(0.04, 0.22, 0.32), st + Vector3(0.31, 0.45, 0), _m["fire"])
	for s in [-1.0, 1.0]:
		for t in [-1.0, 1.0]:
			_box(Vector3(0.05, 0.15, 0.05), st + Vector3(s * 0.25, 0.075, t * 0.25), _m["iron"])
	_cyl(0.07, 1.4, st + Vector3(0, 1.6, 0), _m["iron"])
	_cyl(0.07, 0.4, st + Vector3(-0.2, 2.25, 0), _m["iron"], Basis(Vector3.BACK, PI / 2))
	_stove_light = OmniLight3D.new()
	_stove_light.light_color = Color(1.0, 0.45, 0.15)
	_stove_light.omni_range = 4.5
	_stove_light.position = st + Vector3(0.6, 0.5, 0)
	add_child(_stove_light)
	# Banco corrido junto a la estufa, para los que esperan.
	if USE_PACKS:
		_mega("Bench", Vector3(-ix + 0.3, fy, -2.6), PI / 2.0, 0.0, true)
	else:
		_box(Vector3(0.4, 0.06, 2.4), Vector3(-ix + 0.25, fy + 0.45, -2.6), _m["bench"], true)
		for dz in [-1.0, 1.0]:
			_box(Vector3(0.3, 0.42, 0.06), Vector3(-ix + 0.25, fy + 0.21, -2.6 + dz), _m["beam"])
	if USE_PACKS:
		_basement_pack_extras(ix, back, front, fy)

	# Armero escondido en el muro izquierdo: lanzas, bastones de duelo y escudos.
	var rack_x := -ix + 0.08
	_span(Vector3(rack_x - 0.05, fy + 0.3, back + 1.2), Vector3(rack_x + 0.05, fy + 0.4, back + 3.6), _m["beam"])
	_span(Vector3(rack_x - 0.05, fy + 1.6, back + 1.2), Vector3(rack_x + 0.05, fy + 1.7, back + 3.6), _m["beam"])
	for i in 8:
		var rz := back + 1.4 + i * 0.28
		var spear := i % 3 != 2
		_cyl(0.018, 2.1 if spear else 1.0, Vector3(rack_x + 0.1, fy + (1.1 if spear else 0.55), rz), _m["pale_wood" if spear else "beam"],
				Basis(Vector3.BACK, 0.08))
		if spear:
			_cyl(0.03, 0.22, Vector3(rack_x + 0.18, fy + 2.25, rz), _m["metal"], Basis(Vector3.BACK, 0.08), self, 0.0)
	for rz in [back + 4.1, back + 4.8]:
		_cyl(0.32, 0.05, Vector3(rack_x + 0.06, fy + 1.3, rz), _m["red_wood"], Basis(Vector3.BACK, PI / 2))
		_cyl(0.06, 0.07, Vector3(rack_x + 0.09, fy + 1.3, rz), _m["iron"], Basis(Vector3.BACK, PI / 2))

	# Provisiones contra los cimientos y barriles junto a la escalera.
	_prop("props/Crate", Vector3(-1.2, fy, back + T + 0.35), 0.2, 0.65, true)
	_prop("props/Crate", Vector3(-1.2, fy + 0.65, back + T + 0.35), -0.3, 0.5)
	_prop("props/Crate", Vector3(-0.45, fy, back + T + 0.3), 0.05, 0.55, true)
	_prop("props/Bags", Vector3(0.4, fy, back + T + 0.35), 0.4, 0.55)
	_prop("props/Bags", Vector3(1.1, fy, back + T + 0.3), -0.6, 0.5)
	for bz in [front - T - 0.45, front - T - 1.35]:
		_prop("props/Barrel", Vector3(ix - 0.45, fy, bz), _rng.randf() * TAU, 0.9, true)
	_prop("props/Package_1", Vector3(1.2, fy, front - T - 0.4), 0.6, 0.4)
	_lantern(Vector3(tx, fy + 2.05, tz - 0.9), 1.6, 7.0, true)
	_lantern(Vector3(tx, fy + 2.05, tz + 0.9), 1.3, 6.0)


## Lo que solo hay con los packs: armero y escudos, librería, cómoda, cofre, araña de velas, estantes.
func _basement_pack_extras(ix: float, back: float, front: float, fy: float) -> void:
	_mega("WeaponStand", Vector3(-ix + 0.55, fy, back + 5.6), PI / 2.0, 0.0, true)
	_mega("Shield_Wooden", Vector3(-ix + 0.12, fy + 1.0, back + 4.4), PI / 2.0)
	_mega("Sword_Bronze", Vector3(-ix + 0.6, fy + 0.85, back + 5.6), 0.3)
	_model(RAD, Vector3(-0.9, fy, back + T + 0.25), 0.0, Vector3.ONE * 1.1, true, "bookshelf")
	_mega("BookGroup_Medium_1", Vector3(-1.2, fy + 1.05, back + T + 0.25), 0.0)
	_mega("Book_Stack_1", Vector3(-0.5, fy + 0.55, back + T + 0.25), 0.4)
	_model(RAD, Vector3(1.0, fy, back + T + 0.3), 0.0, Vector3.ONE, true, "commode")
	_mega("CandleStick", Vector3(1.2, fy + 0.48, back + T + 0.3), 0.0)
	_mega("Chest_Wood", Vector3(ix - 0.5, fy, front - T - 2.4), -PI / 2.0, 0.0, true)
	_mega("Peg_Rack", Vector3(ix - 0.06, fy + 1.6, front - T - 2.4), -PI / 2.0)
	_mega("Shelf_Small_Bottles", Vector3(-ix + 0.16, fy + 1.4, -1.6), PI / 2.0)
	var ch := _mega("Chandelier", Vector3(-0.6, -1.65, (back + front) / 2.0), 0.0)
	ch.scale *= 0.8


# ---------------------------------------------------------------- Ceniza

## Montones de ceniza: en el umbral (nivel 3), al pie de los muros y algo colada dentro.
func _build_ash() -> void:
	var hz := L / 2.0
	var drifts := [[Vector3(0, 0, hz + 0.7), Vector3(2.6, 0.22, 1.1)], [Vector3(-1.2, 0, hz + 0.35), Vector3(1.2, 0.3, 0.8)],
			[Vector3(1.4, 0, hz + 0.9), Vector3(1.3, 0.18, 1.0)], [Vector3(0.2, 0, hz - 0.6), Vector3(1.4, 0.08, 0.7)],
			[Vector3(-0.4, 0, hz - 1.3), Vector3(0.8, 0.04, 0.5)], [Vector3(-3.0, 0, hz + 0.5), Vector3(1.8, 0.2, 0.9)],
			[Vector3(3.1, 0, hz + 0.6), Vector3(1.6, 0.25, 1.0)]]
	for z in range(-8, 9, 2):
		for s in [-1.0, 1.0]:
			drifts.append([Vector3(s * (W / 2.0 + 0.25), 0, z + _rng.randf_range(-0.6, 0.6)), Vector3(0.6, 0.2, _rng.randf_range(1.2, 2.0))])
	for d in drifts:
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 16
		sphere.rings = 6
		mi.mesh = sphere
		mi.material_override = _m["ash"]
		mi.scale = d[1]
		mi.position = d[0]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
