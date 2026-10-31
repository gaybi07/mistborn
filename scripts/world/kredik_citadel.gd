class_name KredikCitadel
extends Node3D
## Kredik Shaw por fuera (ver docs/kredik_shaw.md y KredikPlan): una fortaleza-palacio de piedra
## volcánica sobre una meseta de roca, por encima de toda Luthadel.
##  - Muralla exterior rectangular con torres cuadradas en las esquinas, puertas oeste y este, y la
##    Gran Entrada al sur entre dos torres redondas, con una rampa que baja a la ciudad.
##  - Muralla interior con cuatro enormes torres redondas almenadas y su puerta.
##  - El torreón: nave catedralicia con dos agujas en la fachada, rosetón, arbotantes y pináculos;
##    detrás, la galería y la nave del trono con la gran aguja del Lord Legislador.
##  - Un cordón de picos de roca rodea la meseta: escarpado, casi imposible de cruzar a pie; solo
##    la rampa de la Gran Entrada lo atraviesa por un desfiladero.
##  - Ministerio, cuarteles, complejo inquisitorial con su torre, almacenes y alas de servicio.
##  - Ventanas ojivales con marco, parteluz y arco apuntado (algunas encendidas de noche), impostas,
##    contrafuertes, almenas y matacanes.
## Adentro van los niveles apilados (KredikInterior): sus muros son la fachada. Por fuera solo se
## agrega la muralla exterior con sus puertas, la Gran Entrada y lo que asoma por encima de los
## tejados: las torres redondas de la muralla interior, la nave del torreón con las agujas de su
## fachada y la gran aguja del Lord Legislador. Al oeste, un tajo en el cordón de picos deja salir
## los túneles de los subniveles.
## Todo se genera como pocas mallas grandes (la sólida con colisión; ventanas y molduras aparte) y
## se guarda la primera vez.

const PLINTH := 8.0  ## altura de la meseta sobre la ciudad
const HALF := KredikPlan.HALF
const TOP_SOUTH := 58.0  ## la meseta llega hasta aquí al sur (delante de la Gran Entrada)
const RAMP_LEN := 34.0
const RAMP_HALF := 8.0
const RIDGE := 30.0  ## ancho medio del cordón de picos alrededor de la meseta (varía de 20 a 40)
## Tajo del oeste (franja en z) por donde salen los túneles de los subniveles (KredikLevel.tunnels).
const CUT_Z := Vector2(-3.5, 10.8)
const CUT_FILL := 6.5  ## hasta la boca, la roca no baja de aquí (cubre los túneles)

static var _cache := {}
static var _noise_gen: FastNoiseLite
static var _ridge_gen: FastNoiseLite
static var _crag_gen: FastNoiseLite
static var _width_gen: FastNoiseLite
static var _cut_x := NAN

var _b := MeshBuilder.new()  # con colisión
var _d := MeshBuilder.new()  # ventanas, molduras y telas: sin colisión
var _rng := RandomNumberGenerator.new()
var _anchors: Array[Vector3] = []
var _props := {}  # modelos de Poly Haven (ver PolyProps)
var _clouds: Node3D
var _bell_in := 20.0  # la campana de la aguja toca cada tanto


## Hacia dónde mira la Gran Entrada (hacia la ciudad), en el plano.
static func gate_dir() -> Vector2:
	return Vector2(0, 1)


## Altura del terreno en un punto relativo al centro de la fortaleza (0 en la ciudad).
## Arriba, la meseta llana (PLINTH); alrededor, un cordón de picos de roca con crestas afiladas
## que caen en pendientes imposibles; al sur, la rampa de la Gran Entrada cruza por un desfiladero;
## al oeste, el tajo de los túneles.
static func ground(p: Vector2) -> float:
	var h := _raw_ground(p)
	if p.x < -HALF.x:
		var edge := smoothstep(CUT_Z.x - 2.0, CUT_Z.x, p.y) * (1.0 - smoothstep(CUT_Z.y, CUT_Z.y + 2.0, p.y))
		if edge > 0.0:
			# El tajo empieza 2 m antes de la boca: la pared de roca no tapa el arco.
			h = lerpf(h, 0.0 if p.x < cut_x() + 2.0 else maxf(h, CUT_FILL), edge)
	return h if h > 0.02 else 0.0


## Dónde empieza el tajo del oeste (x): donde los picos ya no tapan los túneles, al menos a 32 m de
## la cuadrícula de los niveles (la rampa del Subnivel 3 tiene que llegar arriba antes).
static func cut_x() -> float:
	if is_nan(_cut_x):
		var x := -HALF.x - 7.0
		while x > -HALF.x - 80.0:
			var top := 0.0
			for k in 8:
				top = maxf(top, _raw_ground(Vector2(x, lerpf(CUT_Z.x, CUT_Z.y, k / 7.0))))
			if top < CUT_FILL:
				break
			x -= 0.5
		_cut_x = minf(x, KredikLevel.X0 - 32.0)
	return _cut_x


static func _raw_ground(p: Vector2) -> float:
	if _noise_gen == null:
		_noise_gen = FastNoiseLite.new()
		_noise_gen.seed = 77
		_noise_gen.frequency = 0.05
		_noise_gen.fractal_octaves = 3
		_ridge_gen = FastNoiseLite.new()
		_ridge_gen.seed = 31
		_ridge_gen.frequency = 0.022
		_ridge_gen.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		_ridge_gen.fractal_octaves = 3
		_crag_gen = FastNoiseLite.new()
		_crag_gen.seed = 5
		_crag_gen.frequency = 0.16
		_crag_gen.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		_crag_gen.fractal_octaves = 2
		_width_gen = FastNoiseLite.new()
		_width_gen.seed = 12
		_width_gen.frequency = 0.014
	var n := _noise_gen.get_noise_2dv(p)
	var lo := Vector2(-HALF.x - 7.0, -HALF.y - 9.0)
	var hi := Vector2(HALF.x + 7.0, TOP_SOUTH)
	var dx := maxf(maxf(lo.x - p.x, p.x - hi.x), 0.0)
	var dz := maxf(maxf(lo.y - p.y, p.y - hi.y), 0.0)
	# Dentro de la meseta el suelo es llano: el ruido del borde solo empieza al salir de ella (antes
	# levantaba lomas de roca en los patios).
	var out := Vector2(dx, dz).length()
	var d := out + n * 3.0 * smoothstep(0.0, 6.0, out)
	var h := PLINTH
	if d > 0.0:
		# El pie del cordón avanza y retrocede (estribaciones y valles), no sigue el rectángulo.
		d = maxf(d - 9.0 * _width_gen.get_noise_2dv(p * 1.8) - 4.0 * _ridge_gen.get_noise_2dv(p * 2.5), 0.01)
		# El ancho del cordón varía (estribaciones que avanzan sobre la ciudad y entrantes), así
		# el pie de los montes no sigue el rectángulo.
		var width := clampf(RIDGE * (1.0 + 0.45 * _width_gen.get_noise_2dv(p)) + 4.0 * n, 20.0, 36.0)
		var t := clampf(d / width, 0.0, 1.0)
		# Picos: la cresta (más alta donde el ruido de crestas lo dice) a un tercio del cordón;
		# sube desde la meseta y cae hacia la ciudad, con peñas afiladas por encima.
		var ridge := _ridge_gen.get_noise_2dv(p) * 0.5 + 0.5
		var peak := (12.0 + 38.0 * pow(ridge, 1.7)) * clampf(width / 30.0, 0.65, 1.25)
		var crest := 0.32 + 0.08 * n
		var rise := smoothstep(0.0, crest, t)
		var fall := clampf(1.0 - (t - crest) / (1.0 - crest), 0.0, 1.0)
		var crag := (_crag_gen.get_noise_2dv(p) * 0.5 + 0.5) * 6.0
		# Hacia afuera, faldas cada vez más tendidas (el pie del cordón se funde con la ciudad).
		h = (lerpf(PLINTH, PLINTH + peak, rise) + crag * rise) * pow(fall, 1.5)
	# La rampa de la Gran Entrada cruza el cordón por un desfiladero; llano desde el portón (el ruido
	# del borde levantaba lomas delante de la puerta).
	if absf(p.x) < RAMP_HALF + 4.0 and p.y > 46.0:
		var ramp := PLINTH * clampf(1.0 - (p.y - TOP_SOUTH) / RAMP_LEN, 0.0, 1.0)
		var edge := 1.0 - smoothstep(RAMP_HALF, RAMP_HALF + 4.0, absf(p.x))
		h = lerpf(h, ramp, edge)
	return h


func _ready() -> void:
	position = Vector3(CityPlan.HILL.x, 0, CityPlan.HILL.y)
	if _cache.is_empty():
		_generate()
	var m := WorldKit.materials()
	var mats := {
		"rock": m["citadel_rock"],
		"wall": m["citadel_wall"],
		"trim": m["citadel_trim"],
		"roof": m["citadel_roof"],
		"cap": m["citadel_cap"],
		"iron": m["iron"],
		"red": m["citadel_red"],
		"glass": m["citadel_glass"],
		"glass_lit": m["citadel_glass_lit"],
	}
	for key in ["rock", "citadel"]:
		var body := StaticBody3D.new()
		body.collision_layer = Props.LAYER_WORLD
		body.collision_mask = 0
		var col := CollisionShape3D.new()
		col.shape = _cache[key + "_shape"]
		body.add_child(col)
		body.add_child(_instance(_cache[key], mats))
		add_child(body)
	add_child(_instance(_cache["deco"], mats))
	PolyProps.spawn(self, _cache["props"])
	for a: Vector3 in _cache["anchors"]:
		var anchor := Node3D.new()
		anchor.position = a
		anchor.add_to_group(&"metal")
		add_child(anchor)
	# Bruma espesa alrededor de la meseta: la base se difumina y las agujas asoman por encima.
	var fog := FogVolume.new()
	fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	fog.size = Vector3(HALF.x * 2.0 + 90.0, 110.0, HALF.y * 2.0 + 90.0)
	fog.position.y = 12.0
	fog.material = m["citadel_fog"]
	add_child(fog)
	_add_clouds(m["citadel_cloud"])
	add_child(KredikInterior.new())


func _instance(mesh: ArrayMesh, mats: Dictionary) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	for s in mesh.get_surface_count():
		mi.set_surface_override_material(s, mats[mesh.surface_get_name(s)])
	return mi


## Bancos de bruma alrededor de la fortaleza: siempre envuelta, también de lejos (la niebla
## volumétrica solo llega a 120 m de la cámara). Giran despacio.
func _add_clouds(mat: Material) -> void:
	_clouds = Node3D.new()
	add_child(_clouds)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 44:
		var y := rng.randf_range(2.0, 70.0)
		var spread := 1.15 - 0.5 * y / 70.0
		var p := Vector2(rng.randf_range(-1.0, 1.0) * (HALF.x + 20.0), rng.randf_range(-1.0, 1.0) * (HALF.y + 20.0)) * spread
		var quad := QuadMesh.new()
		var size := rng.randf_range(45.0, 100.0)
		quad.size = Vector2(size * 1.8, size * 0.6)
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(p.x, y, p.y)
		_clouds.add_child(mi)


func _process(delta: float) -> void:
	_clouds.rotation.y += delta * 0.006
	_bell_in -= delta
	if _bell_in <= 0.0:
		_bell_in = randf_range(90.0, 180.0)
		Sfx.play("bell", to_global(Vector3(0, KredikPlan.FLOOR["l5"] + KredikPlan.LH + 20.0, -44.0)), 6.0, 900.0)


func _generate() -> void:
	_rng.seed = 1337
	var rock := MeshBuilder.new()
	_plateau(rock)
	_outer_wall()
	_precinct_wall()
	_crowns()
	var rock_mesh := rock.commit()
	var mesh := _b.commit()
	_cache = {"rock": rock_mesh, "rock_shape": rock_mesh.create_trimesh_shape(),
			"citadel": mesh, "citadel_shape": ModelKit.solid_trimesh(mesh), "deco": _d.commit(), "anchors": _anchors, "props": _props}


# ------------------------------------------------------------------ Meseta

func _plateau(b: MeshBuilder) -> void:
	var step := 1.5
	# Un margen de sobra alrededor del cordón: el terreno de la ciudad se agujerea por celdas de 2 m
	# donde hay roca, y la malla tiene que tapar todo ese agujero.
	var x0 := -HALF.x - 7.0 - 56.0
	var z0 := -HALF.y - 9.0 - 56.0
	var nx := int(-x0 * 2.0 / step)
	var nz := int((TOP_SOUTH + RAMP_LEN + 16.0 - z0) / step)
	var pts := []
	for j in nz + 1:
		var row := []
		for i in nx + 1:
			var p := Vector2(x0 + i * step, z0 + j * step)
			var h := ground(p)
			row.append(Vector3(p.x, h if h > 0.0 else -0.4, p.y))
		pts.append(row)
	# Sin roca encima de la escalera que sube del Subnivel 1 a la planta baja, ni en las bocas de
	# los túneles (la pared del tajo los cruzaría; ahí va el portal de piedra de KredikLevel._tunnel).
	var holes: Array[Rect2] = []
	for f: Array in KredikPlan.flights():
		if f[1] == "ground":
			holes.append((KredikLevel.stair_frame(KredikPlan.rect(f[2]))["hole"] as Rect2).grow(0.2))
	for t: Array in KredikLevel.tunnels():
		holes.append(Rect2(cut_x() + 1.0, t[1] - 2.5, 2.5, t[2] - t[1] + 5.0))
	for j in nz:
		for i in nx:
			var quad := Rect2(Vector2(pts[j][i].x, pts[j][i].z), Vector2(step, step))
			var open := false
			for hole in holes:
				open = open or hole.intersects(quad)
			if not open:
				# Cara hacia arriba: se orienta con un punto justo debajo (con uno fijo bajo el centro, las
				# laderas casi verticales que miran a la meseta quedaban al revés: invisibles y sin suelo).
				var under: Vector3 = (pts[j][i] + pts[j + 1][i + 1]) / 2.0 - Vector3(0, 50, 0)
				b.quad("rock", pts[j][i], pts[j][i + 1], pts[j + 1][i + 1], pts[j + 1][i], under)
	# Agujas de roca por el cordón (como en la ilustración).
	for k in 260:
		var side := _rng.randi() % 4
		var p := Vector2.ZERO
		var out := _rng.randf_range(2.0, 36.0)
		match side:
			0: p = Vector2(_rng.randf_range(-HALF.x - 30.0, HALF.x + 30.0), -HALF.y - 9.0 - out)
			1: p = Vector2(_rng.randf_range(-HALF.x - 30.0, HALF.x + 30.0), TOP_SOUTH + out)
			2: p = Vector2(-HALF.x - 7.0 - out, _rng.randf_range(-HALF.y - 30.0, TOP_SOUTH + 20.0))
			3: p = Vector2(HALF.x + 7.0 + out, _rng.randf_range(-HALF.y - 30.0, TOP_SOUTH + 20.0))
		if absf(p.x) < RAMP_HALF + 7.0 and p.y > TOP_SOUTH - 4.0:
			continue
		if p.x < -HALF.x and p.y > CUT_Z.x - 6.0 and p.y < CUT_Z.y + 6.0:
			continue
		if ground(p) <= 0.0:
			continue
		if _rng.randf() < 0.35:
			# Aguja de roca: un prisma torcido y afilado.
			var hh := _rng.randf_range(8.0, 22.0)
			b.frustum("rock", Vector3(p.x, ground(p) - 2.0, p.y), _rng.randf_range(2.0, 4.0), _rng.randf_range(0.2, 0.8), hh, 5, _rng.randf() * TAU)
			continue
	# Peñascos (boulder_01) al pie del cordón y por el desfiladero.
	var placed := 0
	while placed < 90:
		var p := Vector2(_rng.randf_range(-HALF.x - 50.0, HALF.x + 50.0), _rng.randf_range(-HALF.y - 55.0, TOP_SOUTH + RAMP_LEN + 6.0))
		var g := ground(p)
		var in_ramp := absf(p.x) < RAMP_HALF and p.y > TOP_SOUTH
		if g <= 0.0 or g > 12.0 or in_ramp or (absf(p.x) < HALF.x + 7.0 and p.y > -HALF.y - 9.0 and p.y < TOP_SOUTH):
			continue
		PolyProps.add(_props, "boulder_01", PolyProps.at("boulder_01", Vector3(p.x, g - 0.4, p.y), _rng.randf() * TAU, _rng.randf_range(1.5, 4.5)))
		placed += 1
	# Pretiles de la rampa.
	for sgn: float in [-1.0, 1.0]:
		var a := Vector3(sgn * (RAMP_HALF + 0.4), PLINTH, TOP_SOUTH)
		var c := Vector3(sgn * (RAMP_HALF + 0.4), 0.0, TOP_SOUTH + RAMP_LEN)
		var mid := (a + c) / 2.0
		var along := (c - a).normalized()
		var x := Vector3(1, 0, 0)
		var up := along.cross(x).normalized()
		if up.y < 0.0:
			up = -up
		_b.cube("wall", Transform3D(Basis(x, up, along), mid + up * 0.7), Vector3(1.0, 1.4, a.distance_to(c)))


# ------------------------------------------------------------------ Piezas en un plano de fachada

## Caja en el plano de una fachada: o (esquina, a ras de la meseta), u (a lo largo), n (hacia afuera).
func _pbox(b: MeshBuilder, key: String, o: Vector3, u: Vector3, n: Vector3, s: float, y: float, out: float, along: float, height: float, thick: float, angle := 0.0) -> void:
	var x := u * cos(angle) + Vector3.UP * sin(angle)
	var yv := -u * sin(angle) + Vector3.UP * cos(angle)
	b.cube(key, Transform3D(Basis(x, yv, n), o + u * s + Vector3.UP * y + n * out), Vector3(along, height, thick))


## Ventana ojival: cristal, jambas, alféizar, parteluz y arco apuntado (dos piezas inclinadas).
func _lancet(o: Vector3, u: Vector3, n: Vector3, s: float, y0: float, w: float, h: float, lit_chance: float) -> void:
	var glass := "glass_lit" if _rng.randf() < lit_chance else "glass"
	_pbox(_d, glass, o, u, n, s, y0 + h / 2.0, 0.04, w, h, 0.08)
	for k: float in [-1.0, 1.0]:
		_pbox(_d, "trim", o, u, n, s + k * (w / 2.0 + 0.12), y0 + h / 2.0, 0.12, 0.24, h, 0.25)
	_pbox(_d, "trim", o, u, n, s, y0 - 0.1, 0.18, w + 0.6, 0.2, 0.36)
	if w >= 1.0:
		_pbox(_d, "trim", o, u, n, s, y0 + h / 2.0, 0.1, 0.1, h, 0.16)
	var spring := y0 + h - w * 0.55
	for k: float in [-1.0, 1.0]:
		var p0 := Vector2(s + k * w / 2.0, spring)
		var p1 := Vector2(s, y0 + h + 0.05)
		var d := p1 - p0
		var angle := atan2(d.y, d.x) if k < 0.0 else atan2(-d.y, -d.x)
		var up := Vector2(-d.y, d.x).normalized()
		if up.y < 0.0:
			up = -up
		var hb := w * 0.4
		var c := (p0 + p1) / 2.0 + up * hb / 2.0
		_pbox(_d, "trim", o, u, n, c.x, c.y, 0.08, d.length(), hb, 0.18, angle)
	# Una gota de piedra encima del arco.
	_pbox(_d, "trim", o, u, n, s, y0 + h + 0.35, 0.1, 0.5, 0.5, 0.2, PI / 4.0)


## Fachadas de un bloque: contrafuertes entre crujías, una ventana ojival por crujía y piso,
## impostas en cada piso y cornisa arriba.
func _facades(r: Rect2, y0: float, h: float, windows: bool, lit := 0.1, floor_h := 6.5, bay := 4.6) -> void:
	var corners := [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]
	var center := r.get_center()
	var floors := maxi(1, int((h - 1.0) / floor_h))
	for k in 4:
		var a: Vector2 = corners[k]
		var c: Vector2 = corners[(k + 1) % 4]
		var length := a.distance_to(c)
		var u2 := (c - a) / length
		var u := Vector3(u2.x, 0, u2.y)
		var n := Vector3(-u2.y, 0, u2.x)
		var mid := (a + c) / 2.0
		if n.dot(Vector3(mid.x - center.x, 0, mid.y - center.y)) < 0.0:
			n = -n
		var o := Vector3(a.x, y0, a.y)
		var bays := maxi(1, int(length / bay))
		for f in range(1, floors + 1):
			_pbox(_d, "trim", o, u, n, length / 2.0, f * floor_h - 0.2, 0.15, length, 0.35, 0.4)
		for i in bays + 1:
			var s := length * i / bays
			_pbox(_d, "trim", o, u, n, s, h / 2.0, 0.3, 0.9, h, 0.7)
			_pbox(_d, "trim", o, u, n, s, 1.2, 0.45, 1.3, 2.4, 1.0)
		if windows:
			for i in bays:
				var s := length * (i + 0.5) / bays
				for f in floors:
					var wh := minf(floor_h * 0.58, 4.2)
					_lancet(o, u, n, s, f * floor_h + floor_h * 0.25, 1.3, wh, lit)
	_b.abox("trim", Vector3(center.x, y0 + h - 0.3, center.y), Vector3(r.size.x + 1.0, 0.6, r.size.y + 1.0))
	_b.abox("trim", Vector3(center.x, y0 + 0.6, center.y), Vector3(r.size.x + 0.8, 1.2, r.size.y + 0.8))


## Almenas a lo largo de un borde.
func _merlons(a: Vector3, c: Vector3, thick: float) -> void:
	var length := a.distance_to(c)
	var u := (c - a) / length
	var n := int(length / 2.2)
	for i in n:
		var p := a + u * ((i + 0.5) * length / n)
		_b.cube("wall", Transform3D(Basis(u, Vector3.UP, u.cross(Vector3.UP)), p + Vector3(0, 0.8, 0)), Vector3(1.2, 1.6, thick))


# ------------------------------------------------------------------ Torres

## Torre redonda: zócalo en talud, ventanas por pisos, matacán y corona almenada; con tejado
## cónico si se pide.
func _round_tower(c2: Vector2, r: float, h: float, cone := 0.0, lit := 0.08, y0 := PLINTH - 2.0) -> void:
	var base := Vector3(c2.x, y0, c2.y)
	var sides := 24
	_b.frustum("wall", base, r * 1.12, r, 6.0, sides)
	_b.frustum("wall", base + Vector3(0, 6.0, 0), r, r, h - 4.0, sides)
	var y := 10.0
	var tier := 0
	while y < h - 6.0:
		_d.frustum("trim", base + Vector3(0, y + 2.0, 0), r + 0.2, r + 0.2, 0.4, sides)
		var n := 6 if r > 5.0 else 4
		for k in n:
			var a := TAU * (k + 0.5 * (tier % 2)) / n
			var d := Vector3(cos(a), 0, sin(a))
			var o := base + d * (r - 0.02) + Vector3(0, y + 2.4, 0)
			_lancet(o, Vector3(-d.z, 0, d.x), d, 0.0, 0.6, 1.0 if r > 5.0 else 0.6, 3.0 if r > 5.0 else 2.2, lit)
		y += 7.0
		tier += 1
	# Matacán: modillones bajo una corona que sobresale.
	var top := base + Vector3(0, h + 2.0, 0)
	var corb := 28 if r > 5.0 else 16
	for k in corb:
		var a := TAU * k / corb
		var d := Vector3(cos(a), 0, sin(a))
		_b.cube("trim", Transform3D(Basis(Vector3(-d.z, 0, d.x), Vector3.UP, d), top + d * (r + 0.45) + Vector3(0, -1.6, 0)), Vector3(0.5, 1.4, 0.9))
	_b.frustum("wall", top + Vector3(0, -1.0, 0), r + 1.0, r + 1.0, 2.2, sides)
	var merl := 20 if r > 5.0 else 12
	for k in merl:
		var a := TAU * k / merl
		var d := Vector3(cos(a), 0, sin(a))
		_b.cube("wall", Transform3D(Basis(Vector3(-d.z, 0, d.x), Vector3.UP, d), top + d * (r + 0.7) + Vector3(0, 2.0, 0)), Vector3(1.3, 1.6, 0.6))
	if cone > 0.0:
		_b.frustum("wall", top + Vector3(0, 1.2, 0), r * 0.7, r * 0.7, 3.0, sides)
		_b.frustum("roof", top + Vector3(0, 4.2, 0), r * 0.85, 0.0, cone, sides)
		_b.frustum("cap", top + Vector3(0, 4.2 + cone * 0.85, 0), 0.4, 0.0, cone * 0.2 + 1.5, 8)
		_anchors.append(top + Vector3(0, 4.2 + cone + 1.5, 0))


## Torre cuadrada con almenas y garitas en las esquinas.
func _square_tower(c2: Vector2, half: float, h: float, spire := 0.0, lit := 0.08, y0 := PLINTH - 2.0) -> void:
	var r := Rect2(c2 - Vector2(half, half), Vector2(half, half) * 2.0)
	_b.abox("wall", Vector3(c2.x, y0 + h / 2.0, c2.y), Vector3(half * 2.0, h, half * 2.0), false)
	_facades(r, y0, h, true, lit, 7.0, half)
	var top := y0 + h
	_b.abox("trim", Vector3(c2.x, top + 0.3, c2.y), Vector3(half * 2.0 + 1.4, 0.8, half * 2.0 + 1.4))
	var cs := [Vector3(r.position.x - 0.5, top + 0.7, r.position.y - 0.5), Vector3(r.end.x + 0.5, top + 0.7, r.position.y - 0.5),
			Vector3(r.end.x + 0.5, top + 0.7, r.end.y + 0.5), Vector3(r.position.x - 0.5, top + 0.7, r.end.y + 0.5)]
	for k in 4:
		_merlons(cs[k], cs[(k + 1) % 4], 0.6)
		_b.frustum("wall", cs[k], 1.0, 1.0, 3.0, 8)
		_b.frustum("roof", cs[k] + Vector3(0, 3.0, 0), 1.2, 0.0, 3.5, 8)
	if spire > 0.0:
		_anchors.append(_spire(Vector3(c2.x, top + 0.7, c2.y), half * 0.85, 4.0, spire, 8))


## Aguja gótica: fuste, pináculos y gabletes alrededor, cono de pizarra con anillos y punta de
## metal. Devuelve la punta.
func _spire(base: Vector3, radius: float, shaft: float, needle: float, sides := 8) -> Vector3:
	var rot := PI / sides
	_b.frustum("wall", base, radius, radius * 0.94, shaft, sides, rot)
	var y := base.y + shaft
	if radius >= 1.4:
		_b.frustum("trim", Vector3(base.x, y, base.z), radius * 1.12, radius * 1.12, 0.8, sides, rot)
		for k in sides:
			var a := rot + TAU * (k + 0.5) / sides
			var pp := Vector3(base.x + cos(a) * radius * 0.95, y + 0.8, base.z + sin(a) * radius * 0.95)
			_b.frustum("wall", pp, radius * 0.13, radius * 0.13, 1.5, 4, a)
			_b.frustum("roof", pp + Vector3(0, 1.5, 0), radius * 0.17, 0.0, needle * 0.22, 4, a)
		for k in sides:
			var a := rot + TAU * k / sides + PI / sides
			var d := Vector3(cos(a), 0, sin(a))
			var gp := Vector3(base.x, y + 0.8, base.z) + d * radius * 0.82
			_b.gable("roof", Transform3D(Basis(Vector3(-d.z, 0, d.x), Vector3.UP, d), gp), radius * 0.55, 0.5, needle * 0.12)
	_b.frustum("roof", Vector3(base.x, y + 0.8, base.z), radius, 0.0, needle, sides, rot)
	if radius >= 1.4:
		for t: float in [0.3, 0.55, 0.75]:
			_d.frustum("trim", Vector3(base.x, y + 0.8 + needle * t, base.z), radius * (1.0 - t) + 0.15, radius * (1.0 - t) + 0.05, 0.35, sides, rot)
	var tip := Vector3(base.x, y + 0.8 + needle * 0.86, base.z)
	_b.frustum("cap", tip, radius * 0.16 + 0.1, 0.0, needle * 0.14 + 1.5, sides, rot)
	return tip + Vector3(0, needle * 0.14 + 1.5, 0)


# ------------------------------------------------------------------ Murallas

## Lienzo de muralla de a a c: cuerpo con talud, contrafuertes hacia afuera, troneras, matacán y
## almenas a los dos lados del adarve. out: el lado de afuera. gaps: huecos [desde, hasta] (m).
func _curtain(a: Vector2, c: Vector2, h: float, t: float, out: Vector2, gaps := [], base := PLINTH) -> void:
	var length := a.distance_to(c)
	var u2 := (c - a) / length
	var u := Vector3(u2.x, 0, u2.y)
	var n := Vector3(out.x, 0, out.y)
	var basis := Basis(u, Vector3.UP, n)
	var cuts := [0.0]
	for g: Vector2 in gaps:
		cuts.append(g.x)
		cuts.append(g.y)
	cuts.append(length)
	for i in range(0, cuts.size(), 2):
		var s0: float = cuts[i]
		var s1: float = cuts[i + 1]
		if s1 - s0 < 0.5:
			continue
		var seg := s1 - s0
		var pc := Vector3(a.x, 0, a.y) + u * (s0 + s1) / 2.0
		_b.cube("wall", Transform3D(basis, pc + Vector3(0, base + h / 2.0 - 1.0, 0)), Vector3(seg, h + 2.0, t), false)
		_b.cube("wall", Transform3D(basis, pc + Vector3(0, base + 1.0, 0) + n * 0.6), Vector3(seg, 4.0, t + 1.2), false)
		var y := Vector3(0, base + h, 0)
		for sgn: float in [1.0, -1.0]:
			var off := n * sgn * (t / 2.0 - 0.3)
			_merlons(pc - u * seg / 2.0 + y + off, pc + u * seg / 2.0 + y + off, 0.6)
		var o := Vector3(a.x, base, a.y) + u * s0 + n * (t / 2.0)
		# Matacán corrido bajo el parapeto.
		_pbox(_d, "trim", o, u, n, seg / 2.0, h - 0.6, 0.35, seg, 0.7, 0.8)
		var nc := int(seg / 1.3)
		for k in nc:
			_pbox(_d, "trim", o, u, n, (k + 0.5) * seg / nc, h - 1.6, 0.25, 0.45, 1.2, 0.6)
		# Contrafuertes, troneras e imposta.
		var nb := maxi(1, int(seg / 9.0))
		for k in nb + 1:
			_pbox(_b, "wall", o, u, n, seg * k / nb, h * 0.4, 0.6, 1.6, h * 0.8, 1.4)
		for k in nb:
			var s := seg * (k + 0.5) / nb
			_pbox(_d, "glass", o, u, n, s, h * 0.55, 0.03, 0.35, 2.2, 0.06)
			_pbox(_d, "trim", o, u, n, s, h * 0.55, 0.06, 0.8, 2.8, 0.12)
		_pbox(_d, "trim", o, u, n, seg / 2.0, h * 0.35, 0.1, seg, 0.35, 0.3)


func _outer_wall() -> void:
	var a := KredikPlan.m(Vector2(45, 70))
	var c := KredikPlan.m(Vector2(1365, 705))
	var nw := Vector2(a.x, a.y)
	var ne := Vector2(c.x, a.y)
	var se := Vector2(c.x, c.y)
	var sw := Vector2(a.x, c.y)
	var wall_h := 15.0
	# Norte (en el medio lo tapa la nave del trono), este y oeste (con su puerta), sur (Gran Entrada).
	var throne_l := KredikPlan.m(Vector2(500, 0)).x
	var throne_r := KredikPlan.m(Vector2(915, 0)).x
	_curtain(nw, ne, wall_h, 3.0, Vector2(0, -1), [Vector2(throne_l - nw.x, throne_r - nw.x)])
	_curtain(ne, se, wall_h, 3.0, Vector2(1, 0), [Vector2(-ne.y - 4.0, -ne.y + 4.0)])
	_curtain(nw, sw, wall_h, 3.0, Vector2(-1, 0), [Vector2(-nw.y - 4.0, -nw.y + 4.0)])
	_curtain(sw, se, wall_h, 3.0, Vector2(0, 1), [Vector2(-sw.x - 9.0, -sw.x + 9.0)])
	for p: Vector2 in [nw, ne, se, sw]:
		_square_tower(p, 4.5, wall_h + 9.0, 0.0, 0.04)
	# Puertas oeste y este: torres cuadradas gemelas y el arco cerrado por un rastrillo.
	for sgn: float in [-1.0, 1.0]:
		var x := sgn * (HALF.x + 0.5)
		for z: float in [-6.5, 6.5]:
			_square_tower(Vector2(x, z), 3.2, wall_h + 6.0, 0.0, 0.05)
		_b.abox("wall", Vector3(x, PLINTH + wall_h - 1.0, 0), Vector3(5.0, 6.0, 10.0))
		for k in 6:
			_b.abox("iron", Vector3(x + sgn * 1.6, PLINTH + 4.5, -3.2 + k * 1.3), Vector3(0.18, 9.0, 0.18))
		_anchors.append(Vector3(x + sgn * 1.6, PLINTH + 5.0, 0))
	_great_gate()


## La Gran Entrada: dos torres redondas, el arco ojival con el rastrillo levantado, estandartes
## rojos y la rampa que baja a la ciudad.
func _great_gate() -> void:
	var z := 49.0
	for sgn: float in [-1.0, 1.0]:
		_round_tower(Vector2(sgn * 8.8, z), 4.6, 26.0, 9.0, 0.05)
		_banner(Vector3(sgn * 8.8, PLINTH, z + 4.75), Basis(), 22.0, 11.0)
	var o := Vector3(-4.5, PLINTH, z + 3.0)
	_b.abox("wall", Vector3(0, PLINTH + 15.5, z), Vector3(9.5, 9.0, 7.0))
	for sgn: float in [-1.0, 1.0]:
		_b.abox("wall", Vector3(sgn * 4.0, PLINTH + 5.5, z), Vector3(1.6, 11.0, 7.0))
	# Arco ojival: dovelas inclinadas sobre el vano y una arquivolta de moldura.
	for k: float in [-1.0, 1.0]:
		var p0 := Vector2(4.5 + k * 3.2, 9.0)
		var p1 := Vector2(4.5, 13.2)
		var d := p1 - p0
		var angle := atan2(d.y, d.x) if k < 0.0 else atan2(-d.y, -d.x)
		var up := Vector2(-d.y, d.x).normalized()
		if up.y < 0.0:
			up = -up
		var c := (p0 + p1) / 2.0 + up * 1.4
		_pbox(_b, "wall", o, Vector3(1, 0, 0), Vector3(0, 0, 1), c.x, c.y, -3.5, d.length() + 0.4, 2.8, 7.0, angle)
		_pbox(_d, "trim", o, Vector3(1, 0, 0), Vector3(0, 0, 1), c.x, c.y - 1.0, 0.6, d.length() + 0.4, 0.5, 0.5, angle)
	for k in 6:
		_b.abox("iron", Vector3(-2.6 + k * 1.04, PLINTH + 12.0, z + 1.5), Vector3(0.22, 2.6, 0.22))
	_b.abox("iron", Vector3(0, PLINTH + 10.8, z + 1.5), Vector3(6.2, 0.3, 0.3))
	_anchors.append(Vector3(0, PLINTH + 11.5, z + 1.5))
	for x: float in [-1.0, 1.0]:
		_merlons(Vector3(-4.75, PLINTH + 20.0, z + 3.3 * x), Vector3(4.75, PLINTH + 20.0, z + 3.3 * x), 0.6)
	# Escudo del Lord Legislador sobre el arco.
	_d.abox("red", Vector3(0, PLINTH + 16.8, z + 3.6), Vector3(2.6, 3.4, 0.2))
	_d.abox("cap", Vector3(0, PLINTH + 16.8, z + 3.72), Vector3(1.2, 1.6, 0.1))


func _banner(foot: Vector3, basis: Basis, top: float, length: float) -> void:
	_d.cube("red", Transform3D(basis, foot + Vector3(0, top - length / 2.0, 0)), Vector3(2.4, length, 0.15))
	_d.cube("cap", Transform3D(basis, foot + Vector3(0, top + 0.1, 0)), Vector3(3.0, 0.25, 0.3))


## Rosetón: vidriera (cuatro cuadrados girados), anillo de moldura y radios.
func _rose(c: Vector3, radius: float) -> void:
	var u := Vector3(1, 0, 0)
	var n := Vector3(0, 0, 1)
	var o := Vector3(c.x, 0, c.z)
	for k in 4:
		_pbox(_d, "glass_lit" if k == 0 else "glass", o, u, n, 0.0, c.y, -0.05, radius * 1.45, radius * 1.45, 0.06, PI / 8.0 * k)
	for k in 20:
		var a := TAU * k / 20.0
		_pbox(_d, "trim", o, u, n, cos(a) * radius, c.y + sin(a) * radius, 0.1, TAU * radius / 20.0 + 0.1, 0.6, 0.5, a + PI / 2.0)
	for k in 12:
		var a := TAU * k / 12.0
		_pbox(_d, "trim", o, u, n, cos(a) * radius * 0.5, c.y + sin(a) * radius * 0.5, 0.06, radius, 0.14, 0.2, a)
	_pbox(_d, "trim", o, u, n, 0.0, c.y, 0.1, 1.2, 1.2, 0.4, PI / 4.0)


## Muralla del recinto: rodea el pie del cordón de picos, a ras de la ciudad, y cierra la rampa con
## un portón de rastrillo bajado: no se llega a pie hasta la Gran Entrada. Se entra volando por
## encima (sus torres y el rastrillo son de metal para el acero) o por los túneles de los
## subniveles, que salen por un postigo abierto en el tajo del oeste.
const PRECINCT_H := 12.0
const PRECINCT_GATE := 7.0  ## medio ancho del portón


func _precinct_wall() -> void:
	var a := CityPlan.HILL_HALF.x
	var b := CityPlan.HILL_HALF.y
	var pts: Array[Vector2] = []
	for i in 40:
		var t := TAU * i / 40.0
		pts.append(Vector2(a * signf(cos(t)) * pow(absf(cos(t)), 0.4), b * signf(sin(t)) * pow(absf(sin(t)), 0.4)))
	var in_gap := func(q: Vector2) -> bool:
		return (q.y > 0.0 and absf(q.x) < PRECINCT_GATE) or (q.x < 0.0 and q.y > CUT_Z.x - 1.0 and q.y < CUT_Z.y + 1.0)
	for i in 40:
		var p0 := pts[i]
		var p1 := pts[(i + 1) % 40]
		var seg := p1 - p0
		var nrm := Vector2(seg.y, -seg.x).normalized()
		if nrm.dot((p0 + p1) / 2.0) < 0.0:
			nrm = -nrm
		# Huecos del portón y del postigo: tramos del segmento que caen dentro.
		var gaps := []
		var length := seg.length()
		var start := -1.0
		var s := 0.0
		while s <= length:
			var open: bool = in_gap.call(p0 + seg * (s / length))
			if open and start < 0.0:
				start = s
			elif not open and start >= 0.0:
				gaps.append(Vector2(start, s))
				start = -1.0
			s += 0.5
		if start >= 0.0:
			gaps.append(Vector2(start, length))
		_curtain(p0, p1, PRECINCT_H, 2.5, nrm, gaps, -1.0)
		if i % 4 == 2 and not in_gap.call(p0):
			_square_tower(p0, 3.0, PRECINCT_H + 6.0, 0.0, 0.04, -1.0)
	# Portón: dos torres, el dintel y el rastrillo de hierro bajado.
	for sgn: float in [-1.0, 1.0]:
		_square_tower(Vector2(sgn * (PRECINCT_GATE + 3.0), b), 3.0, PRECINCT_H + 8.0, 0.0, 0.05, -1.0)
	_b.abox("wall", Vector3(0, PRECINCT_H - 1.5, b), Vector3(PRECINCT_GATE * 2.0, 5.0, 3.0))
	for k in 12:
		_b.abox("iron", Vector3(-PRECINCT_GATE + (k + 0.5) * PRECINCT_GATE * 2.0 / 12.0, (PRECINCT_H - 4.0) / 2.0, b), Vector3(0.22, PRECINCT_H - 4.0, 0.22))
	for y: float in [1.5, 4.0, 6.5]:
		_b.abox("iron", Vector3(0, y, b), Vector3(PRECINCT_GATE * 2.0, 0.22, 0.26))
	_anchors.append(Vector3(0, 4.0, b))
	_banner(Vector3(-(PRECINCT_GATE + 3.0), -1.0, b + 3.1), Basis(), PRECINCT_H + 4.0, 9.0)
	_banner(Vector3(PRECINCT_GATE + 3.0, -1.0, b + 3.1), Basis(), PRECINCT_H + 4.0, 9.0)
	# Postigo del oeste: un arco sobre el tajo.
	_b.abox("wall", Vector3(-a, PRECINCT_H - 1.5, (CUT_Z.x + CUT_Z.y) / 2.0), Vector3(3.0, 5.0, CUT_Z.y - CUT_Z.x + 2.0))


## Lo que asoma por encima de los niveles (todos terminan en el techo del Nivel 5).
##  - Las cuatro torres redondas de la muralla interior: corona almenada y chapitel.
##  - El torreón: la nave alta con su tejado, pináculos y aguja, y la fachada sur con dos torres de
##    agujas altísimas, el piñón y el rosetón.
##  - Sobre el complejo del trono, la gran aguja del Lord Legislador, la más alta de Luthadel.
func _crowns() -> void:
	var roof: float = KredikPlan.FLOOR["l5"] + KredikPlan.LH
	for p: Vector2 in [Vector2(205, 195), Vector2(1200, 195), Vector2(205, 575), Vector2(1200, 575)]:
		_round_tower(KredikPlan.m(p), 26 * KredikPlan.PX, 14.0, 12.0, 0.1, roof - 0.5)
	# Nave alta.
	var r := KredikPlan.rect([565, 245, 870, 480])
	var c := r.get_center()
	var nave := Rect2(Vector2(c.x - 10.0, r.position.y + 2.0), Vector2(20.0, r.size.y - 4.0))
	var nave_h := 18.0
	var nc := nave.get_center()
	_b.abox("wall", Vector3(nc.x, roof + nave_h / 2.0, nc.y), Vector3(nave.size.x, nave_h, nave.size.y), false)
	_facades(nave, roof, nave_h, true, 0.15, 9.0, 4.4)
	_b.gable("roof", Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(nc.x, roof + nave_h, nc.y)), nave.size.y + 1.0, nave.size.x + 1.6, 15.0)
	for k in 7:
		var z := nave.position.y + nave.size.y * (k + 0.5) / 7.0
		for sgn: float in [-1.0, 1.0]:
			_spire(Vector3(nc.x + sgn * (nave.size.x / 2.0 + 0.2), roof + nave_h, z), 0.6, 2.0, 6.0, 4)
	_spire(Vector3(nc.x, roof + nave_h + 14.0, nc.y), 1.6, 4.0, 22.0, 8)
	# Fachada sur: dos torres con agujas, el piñón con el rosetón.
	var front := nave.end.y + 4.5
	for sgn: float in [-1.0, 1.0]:
		var tc := Vector2(nc.x + sgn * 14.5, front - 4.5)
		var tower_h := 30.0
		_b.abox("wall", Vector3(tc.x, roof + tower_h / 2.0, tc.y), Vector3(9.0, tower_h, 9.0), false)
		_facades(Rect2(tc - Vector2(4.5, 4.5), Vector2(9.0, 9.0)), roof, tower_h, true, 0.12, 8.0, 3.0)
		_b.abox("trim", Vector3(tc.x, roof + tower_h + 0.4, tc.y), Vector3(10.4, 0.8, 10.4))
		for cx: float in [-1.0, 1.0]:
			for cz: float in [-1.0, 1.0]:
				_spire(Vector3(tc.x + cx * 4.3, roof + tower_h + 0.8, tc.y + cz * 4.3), 0.8, 3.0, 9.0, 4)
		_anchors.append(_spire(Vector3(tc.x, roof + tower_h + 0.8, tc.y), 3.6, 6.0, 46.0, 8))
	var gable_z := nave.end.y + 1.0
	_b.abox("wall", Vector3(nc.x, roof + nave_h / 2.0, gable_z), Vector3(20.0, nave_h, 2.0), false)
	_b.gable("wall", Transform3D(Basis(), Vector3(nc.x, roof + nave_h, gable_z)), 20.0, 2.0, 11.0)
	_rose(Vector3(nc.x, roof + nave_h - 1.0, gable_z + 1.05), 5.0)
	# La gran aguja: torre cuadrada, linterna octogonal y una aguja de casi 130 m.
	var t := KredikPlan.rect([612, 28, 798, 160]).get_center()
	var tower_h := 22.0
	_b.abox("wall", Vector3(t.x, roof + tower_h / 2.0, t.y), Vector3(11.0, tower_h, 11.0), false)
	_facades(Rect2(t - Vector2(5.5, 5.5), Vector2(11.0, 11.0)), roof, tower_h, true, 0.2, 7.0, 3.6)
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			_spire(Vector3(t.x + cx * 5.2, roof + tower_h, t.y + cz * 5.2), 1.1, 6.0, 14.0, 6)
	_b.frustum("wall", Vector3(t.x, roof + tower_h, t.y), 4.8, 4.5, 10.0, 8, PI / 8.0)
	for k in 8:
		var a := PI / 8.0 + TAU * (k + 0.5) / 8.0
		var d := Vector3(cos(a), 0, sin(a))
		_lancet(Vector3(t.x, roof + tower_h, t.y) + d * 4.5, Vector3(-d.z, 0, d.x), d, 0.0, 2.5, 1.0, 5.0, 0.6)
	_anchors.append(_spire(Vector3(t.x, roof + tower_h + 10.0, t.y), 4.4, 2.0, 50.0, 8))
