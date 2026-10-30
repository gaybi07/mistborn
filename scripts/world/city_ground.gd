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
		var y := CityPlan.WATER_LEVEL
		var q := [Vector3(a.x - side_a.x, y, a.y - side_a.y), Vector3(a.x + side_a.x, y, a.y + side_a.y),
				Vector3(b.x - side_b.x, y, b.y - side_b.y), Vector3(b.x + side_b.x, y, b.y + side_b.y)]
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
	return mi


static func _side(pts: Array, i: int) -> Vector2:
	var prev: Vector2 = pts[maxi(i - 1, 0)]
	var next: Vector2 = pts[mini(i + 1, pts.size() - 1)]
	var d := (next - prev).normalized()
	return Vector2(-d.y, d.x)
