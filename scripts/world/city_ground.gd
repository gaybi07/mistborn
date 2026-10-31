class_name CityGround
## Suelo de la ciudad y sus alrededores (±HALF): un Terrain3D con el cauce del río excavado,
## empedrado dentro de la muralla y, fuera, tierra con roca en las pendientes. Los datos (alturas,
## texturas pintadas, huecos bajo Kredik Shaw y el sótano del taller) se generan una vez con
## tools/terrain/bake_terrain.gd y se cargan de res://terrain/. Además, la superficie del agua.

const HALF := 1024.0
const DATA := "res://terrain/data"
const ASSETS := "res://terrain/assets.res"
const DIRT := 1
const ROCK := 2


static func build(parent: Node, mats: Dictionary) -> void:
	var terrain := Terrain3D.new()
	terrain.name = "Terrain3D"
	terrain.vertex_spacing = 2.0
	terrain.collision_layer = Props.LAYER_WORLD
	terrain.collision_mask = 0
	terrain.collision_mode = Terrain3DCollision.FULL_GAME  # se puede volar lejos: colisión en todo
	var material := Terrain3DMaterial.new()
	material.world_background = Terrain3DMaterial.NONE
	material.auto_shader = true
	material.set_shader_param("auto_base_texture", DIRT)
	material.set_shader_param("auto_overlay_texture", ROCK)
	material.set_shader_param("auto_slope", 4.0)
	material.set_shader_param("blend_sharpness", 0.9)
	terrain.material = material
	terrain.assets = load(ASSETS)
	terrain.data_directory = DATA
	parent.add_child(terrain)
	parent.add_child(_water(mats["water"]))
	parent.add_child(_quays(mats))


## Cinta de agua a lo largo del río (UV.x = metros recorridos, para que el agua fluya).
static func _water(mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = CityPlan.RIVER
	var half := CityPlan.RIVER_WIDTH / 2.0 + 1.5
	var along := 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var side_a := _side(pts, i) * half
		var side_b := _side(pts, i + 1) * half
		var next := along + a.distance_to(b)
		var ya := CityPlan.water_level(a)  # el agua baja con el río (CityPlan.ground)
		var yb := CityPlan.water_level(b)
		var q := [Vector3(a.x - side_a.x, ya, a.y - side_a.y), Vector3(a.x + side_a.x, ya, a.y + side_a.y),
				Vector3(b.x - side_b.x, yb, b.y - side_b.y), Vector3(b.x + side_b.x, yb, b.y + side_b.y)]
		var uv := [Vector2(along, 0), Vector2(along, 1), Vector2(next, 0), Vector2(next, 1)]
		for k in [0, 2, 1, 1, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[k])
			st.add_vertex(q[k])
		along = next
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group(&"water")  # el Player solo nada si el escenario tiene río
	# El ruido del río: un bucle cada 60 m a lo largo del cauce (se oye a menos de 45 m).
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := maxi(1, int(a.distance_to(b) / 60.0))
		for k in n:
			var c := a.lerp(b, (k + 0.5) / n)
			var p := Sfx.loop(mi, "river_loop", 45.0, -4.0)
			p.position = Vector3(c.x, CityPlan.water_level(c), c.y)
	return mi


## Malecones de piedra a las dos orillas dentro de la muralla: muro desde el fondo del cauce hasta
## un poco por encima de la calle, con un remate de piedra clara. Tapan la orilla en pendiente del
## terreno (y el borde del agua). Ya va a la altura del suelo (on_ground: main.gd no lo mueve).
static func _quays(mats: Dictionary) -> StaticBody3D:
	var mb := MeshBuilder.new()
	var pts: Array = CityPlan.RIVER
	var half := CityPlan.RIVER_WIDTH / 2.0
	var step := 3.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var length := a.distance_to(b)
		var dir := (b - a) / length
		var side := Vector2(-dir.y, dir.x)
		var basis := Basis(Vector3(dir.x, 0, dir.y), Vector3.UP, Vector3(side.x, 0, side.y))
		var n := maxi(1, int(length / step))
		for k in n:
			var c := a + dir * length * (k + 0.5) / n
			if not CityPlan.inside(c, 8.0):
				continue
			for sgn: float in [-1.0, 1.0]:
				var q := c + side * sgn * (half + 1.6)
				var top := CityPlan.ground(q) + 0.3
				var bottom := CityPlan.ground(q) - CityPlan.RIVER_DEPTH - 1.0
				var pos := Vector3(q.x, (top + bottom) / 2.0, q.y)
				mb.cube("stone", Transform3D(basis, pos), Vector3(length / n + 0.4, top - bottom, 3.4))
				mb.cube("trim", Transform3D(basis, Vector3(q.x, top + 0.12, q.y) - Vector3(side.x, 0, side.y) * sgn * 1.45), Vector3(length / n + 0.4, 0.25, 0.7))
	var mesh := mb.commit()
	var body := StaticBody3D.new()
	body.collision_layer = Props.LAYER_WORLD
	body.collision_mask = 0
	body.set_meta(&"on_ground", true)
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(col)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	for i in mesh.get_surface_count():
		mi.set_surface_override_material(i, mats[mesh.surface_get_name(i)])
	body.add_child(mi)
	return body


static func _side(pts: Array, i: int) -> Vector2:
	var prev: Vector2 = pts[maxi(i - 1, 0)]
	var next: Vector2 = pts[mini(i + 1, pts.size() - 1)]
	var d := (next - prev).normalized()
	return Vector2(-d.y, d.x)
