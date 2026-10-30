class_name WorldKit
## Piezas comunes de los escenarios (ciudad y arena): materiales y ambiente (cielo, bruma, luz).
## El ambiente sigue Art.lighting: "noche" (bruma) o "dia" (sol rojo de Luthadel).

static var _materials := {}


## Materiales compartidos: stone, wall, ground, trim, roof, metal, rusty, iron, painted, wood,
## bronze, lamp_glass y los del exterior: terrain, road, mountain, exterior_fog.
## La misma lejanía que el sombreador de los montes, añadida al final de otro sombreador (que
## tenga `wpos`): sin la niebla del motor, oscurece hacia el color de la bruma con la distancia
## pero nunca del todo (haze_max), y deja pasar parte del brillo de las ventanas.
static func _hazed(path: String) -> Shader:
	var code := (load(path) as Shader).code
	code = code.replace("shader_type spatial;", """shader_type spatial;
render_mode fog_disabled;
uniform float haze_density = 0.005;
uniform float haze_max = 0.85;
uniform vec3 haze_color : source_color = vec3(0.4, 0.42, 0.5);
uniform float haze_brightness = 0.12;
uniform float haze_height = 40.0;""")
	var end := code.rfind("}")
	# Más bruma cerca del suelo (la base se pierde y las agujas asoman); sin lejanía en la vista
	# ortogonal del mapa (PROJECTION_MATRIX[3][3] = 1).
	code = code.substr(0, end) + """	float hz = clamp(1.0 - exp(-distance(wpos, CAMERA_POSITION_WORLD) * haze_density), 0.0, haze_max);
	hz = max(hz, haze_max * 0.75 * (1.0 - smoothstep(0.0, haze_height, wpos.y)) * smoothstep(40.0, 160.0, distance(wpos, CAMERA_POSITION_WORLD)));
	// Jirones que suben y se mueven despacio: la bruma envuelve, no es un velo parejo.
	float wisp = 0.5 + 0.5 * sin(wpos.y * 0.09 + 2.0 * sin(wpos.x * 0.045 + TIME * 0.12) + wpos.z * 0.035 - TIME * 0.2);
	hz = max(hz, haze_max * wisp * (1.0 - smoothstep(haze_height * 0.6, haze_height * 1.5, wpos.y)) * smoothstep(30.0, 120.0, distance(wpos, CAMERA_POSITION_WORLD)));
	hz *= 1.0 - PROJECTION_MATRIX[3][3];
	ALBEDO = mix(ALBEDO, vec3(0.0), hz);
	EMISSION = EMISSION * (1.0 - hz * 0.5) + haze_color * hz * haze_brightness;
""" + code.substr(end)
	var shader := Shader.new()
	shader.code = code
	return shader


## Material con texturas de Poly Haven (assets/textures/polyhaven/<nombre>/), proyectadas en
## coordenadas de mundo (shaders/pbr_world.gdshader). hazed: con la lejanía propia de Kredik Shaw.
static func pbr(name: String, tint: Color, scale: float, hazed := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _hazed("res://shaders/pbr_world.gdshader") if hazed else load("res://shaders/pbr_world.gdshader")
	var dir := "res://assets/textures/polyhaven/%s/" % name
	m.set_shader_parameter(&"albedo_tex", load(dir + "diff.jpg"))
	m.set_shader_parameter(&"normal_tex", load(dir + "nor.jpg"))
	m.set_shader_parameter(&"arm_tex", load(dir + "arm.jpg"))
	m.set_shader_parameter(&"tint", tint)
	m.set_shader_parameter(&"scale", scale)
	return m


static func materials() -> Dictionary:
	if not _materials.is_empty():
		return _materials
	var stone := ShaderMaterial.new()
	stone.shader = load("res://shaders/building.gdshader")
	# Muros y suelos con las texturas de Poly Haven (las mismas que Kredik Shaw).
	var wall := pbr("castle_brick_07", Color(0.8, 0.77, 0.74), 3.0)
	var ground := pbr("large_floor_tiles_02", Color(0.72, 0.7, 0.68), 3.0)
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
	# Kredik Shaw: roca con los adoquines de la calle (también en los acantilados), sillares negros
	# con alguna ventana encendida, muralla sin ventanas, pizarra y su bruma propia.
	# Como los montes, no usan la niebla del motor sino su propia lejanía: así se ven siempre,
	# difuminados, y las ventanas brillan a través de la bruma.
	var citadel_rock := pbr("rock_face_03", Color(0.5, 0.47, 0.47), 7.0, true)
	var citadel_stone := ShaderMaterial.new()
	citadel_stone.shader = _hazed("res://shaders/building.gdshader")
	citadel_stone.set_shader_parameter(&"stone_color", Color(0.15, 0.145, 0.16))
	citadel_stone.set_shader_parameter(&"lit_ratio", 0.07)
	citadel_stone.set_shader_parameter(&"window_glow", 6.0)
	var citadel_wall := pbr("castle_brick_07", Color(0.36, 0.34, 0.37), 3.0, true)
	var citadel_roof: ShaderMaterial = citadel_stone.duplicate()
	citadel_roof.set_shader_parameter(&"windows", 0.0)
	citadel_roof.set_shader_parameter(&"stone_color", Color(0.08, 0.08, 0.095))
	var citadel_trim := pbr("castle_brick_07", Color(0.22, 0.21, 0.23), 3.0, true)
	citadel_trim.set_shader_parameter(&"normal_strength", 0.4)
	var citadel_glass := ShaderMaterial.new()
	citadel_glass.shader = _hazed("res://shaders/glass.gdshader")
	var citadel_glass_lit: ShaderMaterial = citadel_glass.duplicate()
	citadel_glass_lit.set_shader_parameter(&"glow_energy", 4.0)
	var citadel_red := ShaderMaterial.new()
	citadel_red.shader = citadel_glass.shader
	citadel_red.set_shader_parameter(&"albedo", Color(0.32, 0.04, 0.03))
	citadel_red.set_shader_parameter(&"roughness", 0.9)
	var citadel_fog: FogMaterial = exterior_fog.duplicate()
	citadel_fog.height_falloff = 0.06
	citadel_fog.edge_fade = 0.6
	# Bruma de nubes negras (la Profundidad): la mueve y le da densidad Weather.
	var noise := FastNoiseLite.new()
	noise.frequency = 0.05
	noise.fractal_octaves = 3
	var noise_tex := NoiseTexture3D.new()
	noise_tex.width = 64
	noise_tex.height = 64
	noise_tex.depth = 64
	noise_tex.seamless = true
	noise_tex.noise = noise
	var dark_mist := ShaderMaterial.new()
	dark_mist.shader = load("res://shaders/dark_mist.gdshader")
	dark_mist.set_shader_parameter(&"noise", noise_tex)
	# Bancos de bruma de Kredik Shaw (KredikCitadel): Weather les pone el color.
	var citadel_cloud := Fx.particle_material(Color(0.3, 0.32, 0.38, 0.55), false, 5.0)
	citadel_cloud.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	citadel_cloud.vertex_color_use_as_albedo = false
	citadel_cloud.disable_fog = true
	# Las puntas de metal brillan un poco y atraviesan la bruma, como en las referencias (de noche).
	var citadel_cap := Props.material(Color(0.6, 0.48, 0.28), 1.0, 0.35)
	citadel_cap.disable_fog = true
	citadel_cap.emission_enabled = true
	citadel_cap.emission = Color(0.55, 0.4, 0.2)
	_materials = {
		"citadel_cap": citadel_cap,
		"citadel_trim": citadel_trim,
		"citadel_glass": citadel_glass,
		"citadel_glass_lit": citadel_glass_lit,
		"citadel_red": citadel_red,
		"citadel_cloud": citadel_cloud,
		"dark_mist": dark_mist,
		"citadel_rock": citadel_rock,
		"citadel_stone": citadel_stone,
		"citadel_wall": citadel_wall,
		"citadel_roof": citadel_roof,
		"citadel_fog": citadel_fog,
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
