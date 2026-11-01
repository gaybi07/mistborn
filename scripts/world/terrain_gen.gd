class_name TerrainGen
## Mallas de relieve generadas por código: colinas y montañas (con cráter opcional).
## Anillos concéntricos con altura h(r) = height * (1 - r/R)^exp, deformada con ruido para que
## tengan crestas y barrancos. Se generan ya a tamaño real (sin escalar el nodo), así la
## colisión (trimesh) coincide con lo que se ve.


## crater: radio del cráter (0 = sin cráter); exponent > 1 da laderas cóncavas (volcán);
## plateau > 0 corta la cima a esa altura (meseta plana para construir encima).
static func mound(radius: float, height: float, seed: int, crater := 0.0, exponent := 1.6,
		rings := 28, segments := 56, plateau := 0.0) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 3.0 / radius
	noise.fractal_octaves = 4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid := []  # [anillo][segmento] -> Vector3
	for ri in rings + 1:
		var f := float(ri) / rings  # 0 = cumbre, 1 = base
		var ring := []
		for si in segments:
			var a := TAU * si / segments
			var r := f * radius
			var x := cos(a) * r
			var z := sin(a) * r
			var n := noise.get_noise_2d(x, z)
			var rr := clampf(r / radius + n * 0.08, 0.0, 1.0)
			var h := height * pow(1.0 - rr, exponent) * (1.0 + 0.25 * n)
			if plateau > 0.0:
				h = minf(h, plateau)
			if crater > 0.0 and r < crater:
				h -= (1.0 - r / crater) * height * 0.12  # hundimiento del cráter
			if ri == rings:
				h = -0.3  # borde apenas enterrado: tapa la costura sin dejar un escalón
			ring.append(Vector3(x, h, z))
		grid.append(ring)
	for ri in rings:
		for si in segments:
			var s2 := (si + 1) % segments
			var a: Vector3 = grid[ri][si]
			var b: Vector3 = grid[ri][s2]
			var c: Vector3 = grid[ri + 1][si]
			var d: Vector3 = grid[ri + 1][s2]
			# Orden horario visto desde fuera: la cara exterior es la de frente (render y colisión).
			st.add_vertex(a)
			st.add_vertex(c)
			st.add_vertex(b)
			st.add_vertex(b)
			st.add_vertex(c)
			st.add_vertex(d)
	st.generate_normals()
	return st.commit()


## Cuerpo estático con la malla y su colisión exacta.
static func body(mesh: ArrayMesh, pos: Vector3, mat: Material) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = Props.LAYER_WORLD
	b.collision_mask = 0
	b.position = pos
	var col := CollisionShape3D.new()
	col.shape = ModelKit.solid_trimesh(mesh)
	b.add_child(col)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	b.add_child(mi)
	return b
