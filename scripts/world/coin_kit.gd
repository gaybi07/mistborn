class_name CoinKit
## La moneda del juego (Props.coin, el escudo de monedas...): una malla 3D con canto biselado y borde elevado, y un
## material de bronce apagado con textura generada por código (color, desgaste y relieve con mapa de normales).
## Todo se crea una sola vez y lo comparten todas las monedas.

const RADIUS := 0.09
const SEGMENTS := 40
const TEX_SIZE := 256
## Perfil de la moneda de adentro hacia afuera en la cara de arriba y de vuelta por la de abajo: [radio (fracción), alto].
## Centro hundido, borde elevado y canto con bisel (la moneda mide unos 2 cm de grueso).
const PROFILE := [
	[0.00, 0.0072], [0.66, 0.0072], [0.72, 0.0098], [0.93, 0.0098], [0.98, 0.0085], [1.00, 0.0060],
	[1.00, -0.0060], [0.98, -0.0085], [0.93, -0.0098], [0.72, -0.0098], [0.66, -0.0072], [0.00, -0.0072],
]

static var _mesh: ArrayMesh
static var _material: StandardMaterial3D


static func mesh() -> ArrayMesh:
	if _mesh == null:
		_mesh = _build_mesh()
	return _mesh


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = _build_material()
	return _material


# ---------------------------------------------------------------- Malla

## Gira el perfil alrededor del eje Y. Las dos caras usan la misma textura, proyectada desde arriba.
static func _build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in PROFILE.size() - 1:
		for s in SEGMENTS:
			var a := _point(i, s)
			var b := _point(i + 1, s)
			var c := _point(i, s + 1)
			var d := _point(i + 1, s + 1)
			for p: Vector3 in [a, b, c, c, b, d]:
				st.set_uv(Vector2(0.5 + p.x / (2.0 * RADIUS), 0.5 + p.z / (2.0 * RADIUS)))
				st.add_vertex(p)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func _point(i: int, s: int) -> Vector3:
	var angle := TAU * s / SEGMENTS
	var r: float = PROFILE[i][0] * RADIUS
	return Vector3(cos(angle) * r, PROFILE[i][1], sin(angle) * r)


# ---------------------------------------------------------------- Material

static func _build_material() -> StandardMaterial3D:
	var maps := _maps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = maps[0]
	m.normal_enabled = true
	m.normal_texture = maps[1]
	m.normal_scale = 1.3
	m.metallic = 0.8
	m.roughness = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Altura (0-1) del relieve en un punto de la cara, con u y v entre -1 y 1: centro hundido con una estrella de ocho
## puntas en relieve, borde elevado con una ranura y una hilera de perlitas.
static func _height(u: float, v: float) -> float:
	var r := sqrt(u * u + v * v)
	if r > 1.0:
		return 0.0
	var theta := atan2(v, u)
	var h := 0.18  # campo hundido
	if r >= 0.72:
		h = 0.62  # borde elevado
		h -= 0.22 * (1.0 - smoothstep(0.0, 0.025, absf(r - 0.73)))  # ranura junto al borde
		var beads := maxf(cos(theta * 28.0), 0.0) * (1.0 - smoothstep(0.0, 0.06, absf(r - 0.85)))
		h += 0.16 * beads
		h -= 0.12 * smoothstep(0.96, 1.0, r)  # bisel
	else:
		var star := 0.52 * (0.6 + 0.4 * absf(cos(theta * 4.0)))
		h += 0.38 * (1.0 - smoothstep(star - 0.03, star + 0.03, r))
		h += 0.1 * (1.0 - smoothstep(0.08, 0.13, r))  # botón central
	return h


## Textura de color y mapa de normales de la moneda (ver _height).
static func _maps() -> Array:
	var wear := FastNoiseLite.new()
	wear.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wear.frequency = 0.045
	wear.seed = 7
	var grain := FastNoiseLite.new()
	grain.noise_type = FastNoiseLite.TYPE_SIMPLEX
	grain.frequency = 0.35
	grain.seed = 13
	var heights := PackedFloat32Array()
	heights.resize(TEX_SIZE * TEX_SIZE)
	var color := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	var bronze := Color(0.5, 0.34, 0.2)  # bronce apagado
	var bright := Color(0.68, 0.48, 0.28)  # relieve gastado por el roce
	var dark := Color(0.27, 0.18, 0.12)  # suciedad de las partes hundidas
	var patina := Color(0.28, 0.31, 0.25)  # algo de pátina verdosa
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var u := (x + 0.5) / TEX_SIZE * 2.0 - 1.0
			var v := (y + 0.5) / TEX_SIZE * 2.0 - 1.0
			var n := wear.get_noise_2d(x, y)
			var g := grain.get_noise_2d(x, y)
			var h := _height(u, v) + 0.03 * n + 0.012 * g
			heights[y * TEX_SIZE + x] = h
			var c := bronze.lerp(bright, smoothstep(0.35, 0.7, h))
			c = c.lerp(dark, smoothstep(0.3, 0.12, h) * 0.7)
			c = c.lerp(patina, clampf(n * 1.6 - 0.1, 0.0, 1.0) * smoothstep(0.4, 0.15, h) * 0.45)
			c = c.lightened(0.1 * smoothstep(0.96, 0.995, sqrt(u * u + v * v)))  # el canto, más pulido
			var speck := 1.0 + 0.1 * g + 0.05 * n
			color.set_pixel(x, y, Color(c.r * speck, c.g * speck, c.b * speck))
	var normal := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var hl := heights[y * TEX_SIZE + clampi(x - 1, 0, TEX_SIZE - 1)]
			var hr := heights[y * TEX_SIZE + clampi(x + 1, 0, TEX_SIZE - 1)]
			var hu := heights[clampi(y - 1, 0, TEX_SIZE - 1) * TEX_SIZE + x]
			var hd := heights[clampi(y + 1, 0, TEX_SIZE - 1) * TEX_SIZE + x]
			var nv := Vector3((hl - hr) * 3.0, (hd - hu) * 3.0, 1.0).normalized()
			normal.set_pixel(x, y, Color(nv.x * 0.5 + 0.5, nv.y * 0.5 + 0.5, nv.z * 0.5 + 0.5))
	color.generate_mipmaps()
	normal.generate_mipmaps()
	return [ImageTexture.create_from_image(color), ImageTexture.create_from_image(normal)]
