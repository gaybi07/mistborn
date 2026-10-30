class_name Exterior
extends Node3D
## Lo que hay fuera de la muralla de Luthadel:
## - llanuras de ceniza con colinas,
## - caminos que salen de las cuatro puertas, con árboles muertos a los lados,
## - un bosque muerto al suroeste: en el Imperio Final casi nada crece, así que son troncos
##   pelados y retorcidos y arbustos secos,
## - los montes de ceniza al norte: volcanes altos (algunos activos, con lava y humo) que se ven
##   por encima de la muralla de día o con poca niebla,
## - bruma densa en todo el exterior (volúmenes de niebla; su densidad la fija Weather).
## Los árboles son MultiMesh (miles de instancias, pocas llamadas de dibujo) y tienen colisión.

const MOUNTAIN_LINE := -620.0  ## al norte de esta z empiezan las faldas de los montes
const WORLD := 1700.0  ## medio lado del suelo exterior
const FOREST_CENTER := Vector2(-620, 620)
const FOREST_RADIUS := 190.0
## Montes de ceniza: [posición XZ, radio, altura, ¿activo?]
const MOUNTAINS := [
	[Vector2(-60, -900), 270.0, 340.0, true],
	[Vector2(240, -840), 210.0, 250.0, true],
	[Vector2(-340, -800), 190.0, 210.0, false],
	[Vector2(470, -980), 270.0, 300.0, false],
	[Vector2(-580, -960), 250.0, 270.0, true],
	[Vector2(120, -1190), 320.0, 400.0, false],
	[Vector2(-300, -1220), 300.0, 360.0, false],
]

var _rng := RandomNumberGenerator.new()
var _segments: Array = []  # [Vector2 a, Vector2 b]
var _trees: Array = []  # [Vector2 posición, tipo (0 árbol muerto alto, 1 bajo y torcido, 2 arbusto seco), escala]


func _ready() -> void:
	_rng.seed = 4242
	var m := WorldKit.materials()
	# Suelo exterior alrededor del terreno de la ciudad (CityGround cubre el centro, con el río).
	var h := CityGround.HALF
	var span := WORLD - h
	for s in [-1.0, 1.0]:
		add_child(Props.static_box(Vector3(WORLD * 2.0, 2, span), Vector3(0, -1, s * (h + span / 2.0)), m["terrain"]))
		add_child(Props.static_box(Vector3(span, 2, h * 2.0), Vector3(s * (h + span / 2.0), -1, 0), m["terrain"]))
	_build_roads(m["road"])
	_plan_forest()
	_plan_road_trees()
	_plan_scattered_trees(180)
	_build_trees()
	_build_logs_and_rocks()
	_build_hills(m["terrain"])
	_build_mountains(m["mountain"], m["terrain"])
	_build_mist(m["exterior_fog"])


# ---------------------------------------------------------------- Caminos

## Caminos (polilíneas en XZ) que salen de cada puerta; el del sur tiene un desvío al bosque.
func _roads() -> Array:
	var out := []
	for g in CityPlan.gates():
		var p: Vector2 = g[1]
		var outward: Vector2 = g[2]
		var along: Vector2 = g[3]
		var road := [p + outward * 4.0]
		var cur: Vector2 = road[0]
		for k in 4:
			cur = cur + outward * 180.0 + along * _rng.randf_range(-40.0, 40.0)
			if cur.y < MOUNTAIN_LINE + 20.0:
				cur.y = MOUNTAIN_LINE + 20.0
				road.append(cur)
				break
			road.append(cur)
		out.append(road)
		if g[0] == "Puerta Sur":
			var start: Vector2 = road[1]
			out.append([start, start.lerp(FOREST_CENTER, 0.5) + Vector2(20, -10), FOREST_CENTER + Vector2(-120, 60)])
	return out


func _build_roads(mat: Material) -> void:
	for road in _roads():
		for i in road.size() - 1:
			var a: Vector2 = road[i]
			var b: Vector2 = road[i + 1]
			_segments.append([a, b])
			var mid := (a + b) / 2.0
			var mi := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(7.0, 0.06, a.distance_to(b) + 7.0)  # +7: los tramos se solapan en las curvas
			mi.mesh = mesh
			mi.material_override = mat
			mi.position = Vector3(mid.x, 0.0, mid.y)
			mi.rotation.y = atan2(b.x - a.x, b.y - a.y)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)


func _dist_to_roads(p: Vector2) -> float:
	var best := INF
	for s in _segments:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


func _in_city(p: Vector2, margin := 10.0) -> bool:
	return CityPlan.inside(p) or CityPlan.dist_to_wall(p) < margin or CityPlan.dist_to_river(p) < CityPlan.RIVER_WIDTH


# ---------------------------------------------------------------- Árboles

func _plan_forest() -> void:
	var tries := 0
	var placed := 0
	while placed < 900 and tries < 8000:
		tries += 1
		var r := sqrt(_rng.randf()) * FOREST_RADIUS
		var a := _rng.randf() * TAU
		var p := FOREST_CENTER + Vector2(cos(a), sin(a)) * r
		# Más denso en el centro; claros donde pasa el camino.
		if _rng.randf() > 1.0 - pow(r / FOREST_RADIUS, 2.0) * 0.6:
			continue
		if _dist_to_roads(p) < 7.0 or _in_city(p):
			continue
		var roll := _rng.randf()
		_trees.append([p, 0 if roll < 0.7 else (1 if roll < 0.9 else 2), _rng.randf_range(0.8, 1.6)])
		placed += 1


func _plan_road_trees() -> void:
	for s in _segments:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var d := 0.0
		while d < a.distance_to(b):
			for sgn: float in [-1.0, 1.0]:
				var p := a + dir * d + side * sgn * _rng.randf_range(7.0, 10.0)
				if _rng.randf() < 0.55 and not _in_city(p, 20.0) and p.y > MOUNTAIN_LINE:
					_trees.append([p, 1 if _rng.randf() < 0.6 else 2, _rng.randf_range(0.8, 1.3)])
			d += 16.0


func _plan_scattered_trees(count: int) -> void:
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 20:
		tries += 1
		var p := Vector2(_rng.randf_range(-900, 900), _rng.randf_range(MOUNTAIN_LINE, 900))
		if _in_city(p, 30.0) or _dist_to_roads(p) < 8.0:
			continue
		_trees.append([p, _rng.randi_range(0, 2), _rng.randf_range(0.7, 1.4)])
		placed += 1


## Fuera de la muralla: troncos caídos junto a los árboles muertos y peñascos sueltos (modelos de
## Poly Haven, en lote).
func _build_logs_and_rocks() -> void:
	var props := {}
	for t: Array in _trees:
		if _rng.randf() < 0.15:
			var p: Vector2 = t[0] + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(2.0, 4.0)
			PolyProps.add(props, "dead_tree_trunk_02", PolyProps.at("dead_tree_trunk_02", Vector3(p.x, -0.1, p.y), _rng.randf() * TAU, _rng.randf_range(0.8, 1.3)))
	var placed := 0
	var tries := 0
	while placed < 80 and tries < 3000:
		tries += 1
		var p := Vector2(_rng.randf_range(-900, 900), _rng.randf_range(MOUNTAIN_LINE, 900))
		if _in_city(p, 25.0) or _dist_to_roads(p) < 6.0:
			continue
		PolyProps.add(props, "boulder_01", PolyProps.at("boulder_01", Vector3(p.x, -0.3, p.y), _rng.randf() * TAU, _rng.randf_range(1.0, 3.5)))
		placed += 1
	PolyProps.spawn(self, props)


const TREE_VARIANTS := 4
const BUSH_VARIANTS := 3


## Árboles muertos (varias formas generadas) y arbustos secos, en MultiMesh. Solo los troncos
## tienen colisión. Alrededor de muchos árboles crecen matas secas.
func _build_trees() -> void:
	var wood := StandardMaterial3D.new()
	wood.vertex_color_use_as_albedo = true
	wood.albedo_color = Color(0.2, 0.17, 0.14)
	wood.roughness = 1.0
	var brush := StandardMaterial3D.new()
	brush.vertex_color_use_as_albedo = true
	brush.albedo_color = Color(0.36, 0.29, 0.2)
	brush.roughness = 1.0
	brush.cull_mode = BaseMaterial3D.CULL_DISABLED

	var trees: Array = []
	for i in TREE_VARIANTS:
		trees.append(_dead_tree_mesh(1000 + i))
	var bushes: Array = []
	for i in BUSH_VARIANTS:
		bushes.append(_dry_bush_mesh(2000 + i))
	var tree_items := []  # variante -> [[Transform3D, Color]]
	var bush_items := []
	for i in TREE_VARIANTS:
		tree_items.append([])
	for i in BUSH_VARIANTS:
		bush_items.append([])

	var bodies := StaticBody3D.new()
	bodies.collision_layer = Props.LAYER_WORLD
	bodies.collision_mask = 0
	add_child(bodies)
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.35
	trunk_shape.height = 5.0
	for t in _trees:
		var p: Vector2 = t[0]
		var kind: int = t[1]
		var s: float = t[2]
		var base := Vector3(p.x, -0.05, p.y)
		# Madera gris parda, más o menos descolorida.
		var tone := Color(1, 1, 1) * _rng.randf_range(0.75, 1.2)
		if kind == 2:
			_add_bush(bush_items, base, s)
			continue
		var size := s * (1.0 if kind == 0 else 0.72)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * size)
		tree_items[_rng.randi() % TREE_VARIANTS].append([Transform3D(basis, base), tone])
		var col_shape := CollisionShape3D.new()
		col_shape.shape = trunk_shape
		col_shape.position = base + Vector3(0, 2.5, 0)
		bodies.add_child(col_shape)
		# Matas secas al pie.
		for k in _rng.randi_range(0, 3):
			var off := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(1.5, 5.0)
			_add_bush(bush_items, base + Vector3(off.x, 0, off.y), _rng.randf_range(0.6, 1.2))

	for i in TREE_VARIANTS:
		add_child(_multimesh(trees[i], wood, tree_items[i], true))
	for i in BUSH_VARIANTS:
		add_child(_multimesh(bushes[i], brush, bush_items[i], true))


func _add_bush(items: Array, pos: Vector3, s: float) -> void:
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.2), s))
	var tone := Color(1, 1, 1) * _rng.randf_range(0.7, 1.15)
	items[_rng.randi() % items.size()].append([Transform3D(basis, pos), tone])


## Árbol muerto: tronco algo torcido que se abre en ramas peladas que vuelven a dividirse.
func _dead_tree_mesh(seed_value: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height := r.randf_range(4.5, 6.5)
	var lean := Vector3(r.randf_range(-0.6, 0.6), 0, r.randf_range(-0.6, 0.6))
	var mid := Vector3(lean.x * 0.4, height * 0.5, lean.z * 0.4)
	var top := Vector3(lean.x, height, lean.z)
	_limb(st, Vector3.ZERO, mid, 0.34, 0.24, 7)
	_limb(st, mid, top, 0.24, 0.07, 7)
	# Raíces que asoman.
	for i in 4:
		var a := TAU * i / 4.0 + r.randf_range(-0.4, 0.4)
		_limb(st, Vector3(0, 0.35, 0), Vector3(cos(a) * 0.9, -0.15, sin(a) * 0.9), 0.16, 0.04, 5)
	# Ramas desde la mitad de arriba.
	for i in r.randi_range(4, 6):
		var t := r.randf_range(0.45, 0.9)
		var from := mid.lerp(top, (t - 0.5) * 2.0) if t > 0.5 else Vector3.ZERO.lerp(mid, t * 2.0)
		var a := r.randf() * TAU
		var dir := Vector3(cos(a), r.randf_range(0.5, 1.3), sin(a)).normalized()
		var length := r.randf_range(1.4, 2.8) * (1.2 - t * 0.5)
		var rad := 0.16 * (1.1 - t)
		_branch(st, r, from, dir, length, rad, 2)
	st.generate_normals()
	return st.commit()


## Rama que se divide en `depth` niveles más, girando un poco y apuntando hacia arriba.
func _branch(st: SurfaceTool, r: RandomNumberGenerator, from: Vector3, dir: Vector3, length: float, rad: float, depth: int) -> void:
	var bend := Vector3(r.randf_range(-0.4, 0.4), r.randf_range(-0.25, 0.15), r.randf_range(-0.4, 0.4))
	var to := from + (dir + bend).normalized() * length
	_limb(st, from, to, rad, rad * 0.55, 5)
	if depth <= 0:
		return
	for i in r.randi_range(1, 3):
		var a := r.randf() * TAU
		var nd := (dir + Vector3(cos(a), 0.35, sin(a)) * 0.8).normalized()
		_branch(st, r, from.lerp(to, r.randf_range(0.6, 1.0)), nd, length * r.randf_range(0.45, 0.7), rad * 0.55, depth - 1)


## Arbusto seco: un manojo de varas finas que salen del suelo hacia fuera.
func _dry_bush_mesh(seed_value: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in r.randi_range(12, 18):
		var a := r.randf() * TAU
		var dir := Vector3(cos(a) * r.randf_range(0.3, 0.9), 1.0, sin(a) * r.randf_range(0.3, 0.9)).normalized()
		var from := Vector3(r.randf_range(-0.15, 0.15), 0, r.randf_range(-0.15, 0.15))
		var length := r.randf_range(0.6, 1.3)
		var mid := from + dir * length * 0.55
		_limb(st, from, mid, 0.03, 0.02, 4)
		_limb(st, mid, mid + (dir + Vector3(r.randf_range(-0.4, 0.4), -0.1, r.randf_range(-0.4, 0.4))).normalized() * length * 0.5,
				0.02, 0.006, 4)
		if r.randf() < 0.6:
			var b := Vector3(cos(a + 1.0), 0.6, sin(a + 1.0)).normalized()
			_limb(st, mid, mid + b * length * 0.35, 0.015, 0.004, 3)
	st.generate_normals()
	return st.commit()


## Cilindro estrechado entre dos puntos (con color de vértice más oscuro en la base).
func _limb(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, sides: int) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT).normalized()
	var up := axis.cross(side)
	var dark := Color(0.8, 0.78, 0.76)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var o0 := side * cos(a0) + up * sin(a0)
		var o1 := side * cos(a1) + up * sin(a1)
		var p0 := a + o0 * ra
		var p1 := a + o1 * ra
		var q0 := b + o0 * rb
		var q1 := b + o1 * rb
		for v in [[p0, dark], [q0, Color.WHITE], [p1, dark], [p1, dark], [q0, Color.WHITE], [q1, Color.WHITE]]:
			st.set_color(v[1])
			st.add_vertex(v[0])


func _multimesh(mesh: Mesh, mat: Material, items: Array, colors: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		if colors:
			mm.set_instance_color(i, items[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	return mmi


# ---------------------------------------------------------------- Relieve

func _build_hills(mat: Material) -> void:
	var placed := 0
	var tries := 0
	while placed < 32 and tries < 400:
		tries += 1
		var a := _rng.randf() * TAU
		var p := Vector2(cos(a), sin(a)) * _rng.randf_range(450.0, 1100.0)
		var radius := _rng.randf_range(40.0, 110.0)
		if p.y < MOUNTAIN_LINE + 40.0 or _dist_to_roads(p) < radius * 0.8 + 6.0:
			continue
		if CityPlan.dist_to_wall(p) < radius + 30.0 or CityPlan.dist_to_river(p) < radius + 10.0 or CityPlan.inside(p):
			continue
		if p.distance_to(FOREST_CENTER) < FOREST_RADIUS * 0.7:
			continue  # dentro del bosque el suelo es llano
		var mesh := TerrainGen.mound(radius, _rng.randf_range(6.0, 24.0), _rng.randi(), 0.0, 1.3, 16, 32)
		add_child(TerrainGen.body(mesh, Vector3(p.x, 0, p.y), mat))
		placed += 1


func _build_mountains(mountain_mat: Material, terrain_mat: Material) -> void:
	# Faldas: colinas altas entre la llanura y los volcanes.
	for i in 12:
		var p := Vector2(_rng.randf_range(-700, 700), _rng.randf_range(-740, -650))
		var mesh := TerrainGen.mound(_rng.randf_range(70.0, 130.0), _rng.randf_range(25.0, 60.0), _rng.randi(), 0.0, 1.3, 18, 36)
		add_child(TerrainGen.body(mesh, Vector3(p.x, 0, p.y), terrain_mat))
	for spec in MOUNTAINS:
		var p: Vector2 = spec[0]
		var radius: float = spec[1]
		var height: float = spec[2]
		var active: bool = spec[3]
		var mesh := TerrainGen.mound(radius, height, _rng.randi(), radius * 0.1, 1.9, 36, 72)
		var b := TerrainGen.body(mesh, Vector3(p.x, 0, p.y), mountain_mat)
		add_child(b)
		var mi: MeshInstance3D = b.get_child(1)
		mi.set_instance_shader_parameter(&"lava_level", height * 0.72 if active else 10000.0)
		if active:
			_volcano_smoke(Vector3(p.x, height * 0.93, p.y))


## Columna de humo y ceniza saliendo del cráter, y un resplandor rojo.
func _volcano_smoke(top: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 45
	p.lifetime = 32.0
	p.preprocess = 32.0
	p.visibility_aabb = AABB(Vector3(-400, -60, -400), Vector3(800, 600, 800))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 25.0
	pm.direction = Vector3.UP
	pm.spread = 15.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 6.0
	pm.gravity = Vector3(0.8, 0.3, 0.2)  # el viento la tumba un poco
	pm.scale_min = 1.0
	pm.scale_max = 2.6
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.color_ramp = Fx.fade_ramp(0.15)
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(70, 70)
	quad.material = Fx.particle_material(Color(0.17, 0.16, 0.16, 0.5), false)
	p.draw_pass_1 = quad
	p.position = top
	add_child(p)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.35, 0.1)
	glow.light_energy = 8.0
	glow.omni_range = 140.0
	glow.position = top + Vector3(0, -10, 0)
	add_child(glow)


# ---------------------------------------------------------------- Bruma

## Volúmenes de niebla densa fuera de la muralla (más espesa a ras de suelo), alrededor del
## rectángulo que ocupa la ciudad.
func _build_mist(mat: FogMaterial) -> void:
	var outer := 1400.0
	var x_half := 380.0
	var z_north := 480.0
	var z_south := 440.0
	_fog_box(Vector3(0, 12, -(z_north + (outer - z_north) / 2.0)), Vector3(outer * 2.0, 44, outer - z_north), mat)
	_fog_box(Vector3(0, 12, z_south + (outer - z_south) / 2.0), Vector3(outer * 2.0, 44, outer - z_south), mat)
	for x_sign in [-1.0, 1.0]:
		_fog_box(Vector3(x_sign * (x_half + (outer - x_half) / 2.0), 12, (z_south - z_north) / 2.0),
				Vector3(outer - x_half, 44, z_north + z_south), mat)


func _fog_box(pos: Vector3, size: Vector3, mat: FogMaterial) -> void:
	var fv := FogVolume.new()
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fv.size = size
	fv.material = mat
	fv.position = pos
	add_child(fv)
