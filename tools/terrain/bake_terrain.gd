extends SceneTree
## Genera el terreno de Luthadel para Terrain3D (se corre una vez, o cuando cambia el plano):
##   Godot --headless --path . -s tools/terrain/bake_terrain.gd
## Escribe en res://terrain/: data/ (regiones con alturas y texturas pintadas), assets.res
## (texturas: empedrado, tierra con ceniza, roca). El material lo arma CityGround.
## Alturas: el cauce del río (CityPlan.river_bed), llano en el resto. Huecos: bajo la meseta de
## Kredik Shaw (tiene su propia malla) y los sótanos del taller de Clubs y la mansión Venture.
## Texturas: dentro de la muralla, empedrado; fuera, automático (tierra en lo llano, roca en
## las pendientes).

const DIR := "res://terrain/"
const SPACING := 2.0
const HALF := 1024.0  ## cubre ±HALF (4 regiones de 512 vértices)
const TEX := 512
enum { COBBLE, DIRT, ROCK }


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR + "data"))
	var assets := Terrain3DAssets.new()
	assets.set_texture(COBBLE, _asset("Losas", _polyhaven("large_floor_tiles_02", Color(0.72, 0.7, 0.68)), 1.0 / 3.0))
	assets.set_texture(DIRT, _asset("Tierra", _dirt(), 1.0 / 6.0))
	assets.set_texture(ROCK, _asset("Roca", _polyhaven("rock_face_03", Color(0.5, 0.47, 0.47)), 1.0 / 7.0))
	ResourceSaver.save(assets, DIR + "assets.res")

	var terrain := Terrain3D.new()
	terrain.region_size = 512
	terrain.vertex_spacing = SPACING
	terrain.assets = assets
	root.add_child(terrain)
	await process_frame
	var n := int(HALF * 2.0 / SPACING)
	var height := Image.create_empty(n, n, false, Image.FORMAT_RF)
	var control := Image.create_empty(n, n, false, Image.FORMAT_RF)
	var city := Terrain3DUtil.as_float(Terrain3DUtil.enc_base(COBBLE))
	var land := Terrain3DUtil.as_float(Terrain3DUtil.enc_base(DIRT) | Terrain3DUtil.enc_auto(true))
	var hole := Terrain3DUtil.as_float(Terrain3DUtil.enc_hole(true))
	for iz in n:
		for ix in n:
			var p := Vector2(-HALF + ix * SPACING, -HALF + iz * SPACING)
			height.set_pixel(ix, iz, Color(CityPlan.ground(p) + CityPlan.river_bed(p), 0, 0))
			var c := land
			if KredikCitadel.ground(p - CityPlan.HILL) > 0.0 or Workshop.GROUND_HOLE.has_point(p) or VentureManor.GROUND_HOLE.has_point(p):
				c = hole
			elif CityPlan.inside(p):
				c = city
			control.set_pixel(ix, iz, Color(c, 0, 0))
	terrain.data.import_images([height, control, null], Vector3(-HALF, 0, -HALF), 0.0, 1.0)
	terrain.data.save_directory(DIR + "data")
	print("terreno: %d regiones guardadas en %sdata" % [terrain.data.get_region_count(), DIR])
	quit()


func _asset(name: String, maps: Array, uv_scale: float) -> Terrain3DTextureAsset:
	var ta := Terrain3DTextureAsset.new()
	ta.name = name
	ta.albedo_texture = ImageTexture.create_from_image(maps[0])
	ta.normal_texture = ImageTexture.create_from_image(maps[1])
	ta.uv_scale = uv_scale
	ta.detiling_rotation = 0.1
	return ta


static func _hash(x: int, y: int, k: int) -> float:
	var h := (x * 374761393 + y * 668265263 + k * 2246822519) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 10007) / 10007.0


static func _noise(seed_value: int, freq: float) -> FastNoiseLite:
	var nz := FastNoiseLite.new()
	nz.seed = seed_value
	nz.frequency = freq
	nz.fractal_octaves = 4
	return nz


## Sin costuras: ruido sobre un toro (dos círculos) para que la textura se repita sin cortes.
static func _tile_noise(nz: FastNoiseLite, u: float, v: float, r: float) -> float:
	var a := u * TAU
	var b := v * TAU
	return nz.get_noise_3d(cos(a) * r, sin(a) * r + cos(b) * r, sin(b) * r) * 0.5 + 0.5


## Texturas de Poly Haven (assets/textures/polyhaven/<nombre>) en el formato de Terrain3D: color
## con altura (luminancia) en alfa, normal con rugosidad en alfa; a TEX px como las demás.
func _polyhaven(name: String, tint: Color) -> Array:
	var dir := ProjectSettings.globalize_path("res://assets/textures/polyhaven/%s/" % name)
	var diff := Image.load_from_file(dir + "diff.jpg")
	var nor := Image.load_from_file(dir + "nor.jpg")
	var arm := Image.load_from_file(dir + "arm.jpg")
	for img in [diff, nor, arm]:
		img.convert(Image.FORMAT_RGBA8)
		img.resize(TEX, TEX, Image.INTERPOLATE_LANCZOS)
	for y in TEX:
		for x in TEX:
			var c := diff.get_pixel(x, y)
			var a := Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.get_luminance())
			diff.set_pixel(x, y, a)
			var n := nor.get_pixel(x, y)
			n.a = arm.get_pixel(x, y).g
			nor.set_pixel(x, y, n)
	return [_mip(diff), _mip(nor)]


## Adoquines (celdas de Voronoi, como el sombreador de la calle): `cells` piedras por lado, juntas
## oscuras y ceniza en las juntas. Devuelve [albedo con altura en alfa, normal con rugosidad].
func _cobble(cells: int, a: Color, b: Color, ash_amount: float) -> Array:
	var albedo := Image.create_empty(TEX, TEX, false, Image.FORMAT_RGBA8)
	var heights := PackedFloat32Array()
	heights.resize(TEX * TEX)
	var nz := _noise(11, 0.9)
	var ash := Color(0.34, 0.33, 0.32)
	for y in TEX:
		for x in TEX:
			var px := float(x) / TEX * cells
			var py := float(y) / TEX * cells
			var ix := floori(px)
			var iy := floori(py)
			var d1 := 8.0
			var d2 := 8.0
			var cid := Vector2i.ZERO
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var gx := ix + ox
					var gy := iy + oy
					var wx := posmod(gx, cells)
					var wy := posmod(gy, cells)
					var o := Vector2(_hash(wx, wy, 1), _hash(wx, wy, 2)) * 0.8 + Vector2(0.1, 0.1)
					var d := Vector2(gx + o.x - px, gy + o.y - py).length()
					if d < d1:
						d2 = d1
						d1 = d
						cid = Vector2i(wx, wy)
					elif d < d2:
						d2 = d
			var gap := 1.0 - smoothstep(0.03, 0.12, d2 - d1)
			var n := _tile_noise(nz, float(x) / TEX, float(y) / TEX, 1.5)
			var col := a.lerp(b, _hash(cid.x, cid.y, 3)) * (0.85 + 0.3 * n)
			col = col.lerp(ash, smoothstep(0.55, 0.9, n) * ash_amount)
			col = col * (1.0 - gap * 0.7)
			col.a = 1.0
			var h := clampf((1.0 - gap) * (0.55 + 0.45 * (1.0 - d1)) + n * 0.1, 0.0, 1.0)
			heights[y * TEX + x] = h
			col.a = h
			albedo.set_pixel(x, y, col)
	return [_mip(albedo), _normal(heights, 3.0, 0.85)]


## Tierra cubierta de ceniza con manchas de hierba parda (como el sombreador del exterior).
func _dirt() -> Array:
	var albedo := Image.create_empty(TEX, TEX, false, Image.FORMAT_RGBA8)
	var heights := PackedFloat32Array()
	heights.resize(TEX * TEX)
	var big := _noise(21, 0.6)
	var fine := _noise(22, 3.0)
	var dirt := Color(0.2, 0.17, 0.14)
	var grass := Color(0.26, 0.22, 0.12)
	var ash := Color(0.33, 0.32, 0.31)
	for y in TEX:
		for x in TEX:
			var u := float(x) / TEX
			var v := float(y) / TEX
			var n1 := _tile_noise(big, u, v, 1.0)
			var n2 := _tile_noise(fine, u, v, 1.0)
			var col := dirt.lerp(grass, smoothstep(0.5, 0.75, n1)) * (0.8 + 0.35 * n2)
			col = col.lerp(ash, smoothstep(0.45, 0.85, n1 * 0.5 + n2 * 0.5) * 0.6)
			var h := n2 * 0.7 + n1 * 0.3
			heights[y * TEX + x] = h
			col.a = h
			albedo.set_pixel(x, y, col)
	return [_mip(albedo), _normal(heights, 2.0, 0.95)]


## Normal (RGB) a partir de las alturas, con la rugosidad en alfa.
func _normal(heights: PackedFloat32Array, strength: float, rough: float) -> Image:
	var img := Image.create_empty(TEX, TEX, false, Image.FORMAT_RGBA8)
	for y in TEX:
		for x in TEX:
			var dx := heights[y * TEX + (x + 1) % TEX] - heights[y * TEX + (x - 1 + TEX) % TEX]
			var dy := heights[((y + 1) % TEX) * TEX + x] - heights[((y - 1 + TEX) % TEX) * TEX + x]
			var nrm := Vector3(-dx * strength, -dy * strength, 1.0).normalized()
			img.set_pixel(x, y, Color(nrm.x * 0.5 + 0.5, nrm.y * 0.5 + 0.5, nrm.z * 0.5 + 0.5, rough))
	return _mip(img)


func _mip(img: Image) -> Image:
	img.generate_mipmaps()
	return img
