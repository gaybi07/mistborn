class_name WorldKit
## Piezas comunes de los escenarios (ciudad y arena): materiales y ambiente (cielo, bruma, luz).
## El ambiente sigue Art.lighting: "noche" (bruma) o "dia" (sol rojo de Luthadel).

static var _materials := {}


## Materiales compartidos: stone, wall, ground, trim, roof, metal, rusty, iron, painted, wood,
## bronze, lamp_glass y los del exterior: terrain, road, mountain, exterior_fog.
static func materials() -> Dictionary:
	if not _materials.is_empty():
		return _materials
	var stone := ShaderMaterial.new()
	stone.shader = load("res://shaders/building.gdshader")
	var wall: ShaderMaterial = stone.duplicate()
	wall.set_shader_parameter(&"windows", 0.0)
	wall.set_shader_parameter(&"stone_color", Color(0.3, 0.29, 0.28))
	var ground := ShaderMaterial.new()
	ground.shader = load("res://shaders/cobblestone.gdshader")
	var lamp_glass := Props.material(Color(1.0, 0.75, 0.45), 0.0, 0.2)
	lamp_glass.emission_enabled = true
	lamp_glass.emission = Color(1.0, 0.65, 0.35)
	lamp_glass.emission_energy_multiplier = 4.0
	var terrain := ShaderMaterial.new()
	terrain.shader = load("res://shaders/terrain.gdshader")
	var road: ShaderMaterial = terrain.duplicate()
	road.set_shader_parameter(&"road", 1.0)
	var mountain := ShaderMaterial.new()
	mountain.shader = load("res://shaders/mountain.gdshader")
	var exterior_fog := FogMaterial.new()
	exterior_fog.albedo = Color(0.82, 0.86, 0.92)
	exterior_fog.density = 0.05
	exterior_fog.height_falloff = 0.04
	exterior_fog.edge_fade = 0.4
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/water.gdshader")
	_materials = {
		"water": water,
		"noble_roof": Props.material(Color(0.36, 0.12, 0.09), 0.0, 0.75),
		"terrain": terrain,
		"road": road,
		"mountain": mountain,
		"exterior_fog": exterior_fog,
		"stone": stone,
		"wall": wall,
		"ground": ground,
		"trim": Props.material(Color(0.2, 0.19, 0.18), 0.0, 0.95),
		"roof": Props.material(Color(0.13, 0.13, 0.15), 0.1, 0.7),
		"metal": Props.material(Color(0.55, 0.57, 0.6), 0.9, 0.3),
		"rusty": Props.material(Color(0.42, 0.3, 0.24), 0.7, 0.6),
		"iron": Props.material(Color(0.12, 0.12, 0.13), 0.85, 0.45),
		"painted": Props.material(Color(0.13, 0.13, 0.14), 0.2, 0.55),  # madera pintada imitando hierro
		"wood": Props.material(Color(0.3, 0.21, 0.14), 0.0, 0.9),
		"bronze": Props.material(Color(0.55, 0.4, 0.25), 1.0, 0.35),
		"lamp_glass": lamp_glass,
	}
	return _materials


## Cielo, bruma, luna (o sol), clima (Weather) y sonda de reflejos. fog_scale < 1 aclara la bruma (arena).
static func add_environment(parent: Node, fog_scale := 1.0, probe_size := Vector3(90, 40, 90)) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	# Cielo con nubes (shaders/sky.gdshader); los colores los pone Weather.apply().
	# Las nubes se mueven (usa TIME): el mapa de reflejos se actualiza poco a poco y pequeño.
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	# Con los modelos animados importados (KayKit/Quaternius), el SSAO produce píxeles inválidos
	# que se extienden en bloques negros (visto en una Radeon RX 570). Solo se usa con el estilo procedural.
	env.ssao_enabled = Art.style == "procedural"
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.9
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 0.8  # mundo apagado: el color lo pone la alomancia
	env.fog_enabled = true
	env.fog_light_color = Color(0.48, 0.52, 0.62)
	env.fog_density = 0.025 * fog_scale
	env.fog_aerial_perspective = 0.4
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.035 * fog_scale
	env.volumetric_fog_albedo = Color(0.8, 0.84, 0.9)
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_length = 120.0  # que la bruma del exterior se vea desde lo alto de la muralla
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_env.add_to_group(&"world_env")
	parent.add_child(world_env)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-40, 30, 0)
	moon.light_color = Color(0.62, 0.7, 0.92)
	moon.light_energy = 0.55
	moon.light_volumetric_fog_energy = 0.5
	moon.shadow_enabled = true
	parent.add_child(moon)

	# Hora, clima y niebla (los aplica en vivo; F3/F4/F5 los cambian).
	var weather := Weather.new()
	weather.env = env
	weather.moon = moon
	weather.sky_mat = sky_mat
	weather.fog_scale = fog_scale
	parent.add_child(weather)

	var probe := ReflectionProbe.new()
	probe.size = probe_size
	probe.position = Vector3(0, probe_size.y / 4.0, 0)
	parent.add_child(probe)
