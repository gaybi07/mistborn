class_name CityGround
## Suelo de la zona de la ciudad: una malla en cuadrícula con el cauce del río excavado.
## Las celdas dentro de la muralla llevan empedrado y las de fuera, tierra. Además, la superficie
## del agua del río. Cubre un cuadrado de ±HALF; más allá está el suelo del exterior (Exterior).

const HALF := 330.0
const CELL := 3.0


static func build(parent: Node, mats: Dictionary) -> void:
	var n := int(HALF * 2.0 / CELL)
	var heights := PackedFloat32Array()
	heights.resize((n + 1) * (n + 1))
	for iz in n + 1:
		for ix in n + 1:
			var p := Vector2(-HALF + ix * CELL, -HALF + iz * CELL)
			heights[iz * (n + 1) + ix] = CityPlan.river_bed(p)
	var city := SurfaceTool.new()
	var land := SurfaceTool.new()
	city.begin(Mesh.PRIMITIVE_TRIANGLES)
	land.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in n:
		for ix in n:
			var c := Vector2(-HALF + (ix + 0.5) * CELL, -HALF + (iz + 0.5) * CELL)
			var st := city if CityPlan.inside(c) else land
			var v := [_v(heights, n, ix, iz), _v(heights, n, ix + 1, iz), _v(heights, n, ix, iz + 1), _v(heights, n, ix + 1, iz + 1)]
			st.add_vertex(v[0])
			st.add_vertex(v[1])
			st.add_vertex(v[2])
			st.add_vertex(v[1])
			st.add_vertex(v[3])
			st.add_vertex(v[2])
	city.generate_normals()
	land.generate_normals()
	var mesh := city.commit()
	land.commit(mesh)
	mesh.surface_set_material(0, mats["ground"])
	mesh.surface_set_material(1, mats["terrain"])

	var body := StaticBody3D.new()
	body.collision_layer = Props.LAYER_WORLD
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(col)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	parent.add_child(body)
	parent.add_child(_water(mats["water"]))


static func _v(heights: PackedFloat32Array, n: int, ix: int, iz: int) -> Vector3:
	return Vector3(-HALF + ix * CELL, heights[iz * (n + 1) + ix], -HALF + iz * CELL)


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
	return mi


static func _side(pts: Array, i: int) -> Vector2:
	var prev: Vector2 = pts[maxi(i - 1, 0)]
	var next: Vector2 = pts[mini(i + 1, pts.size() - 1)]
	var d := (next - prev).normalized()
	return Vector2(-d.y, d.x)
