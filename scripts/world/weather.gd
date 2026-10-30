class_name Weather
extends Node3D
## Hora, clima y niebla, aplicados en vivo (ciudad y arena).
##   F3 hora: noche / día        F4 clima: despejado / lluvia / ceniza        F5 niebla: poca / mucha
## Además de lo visual cambia la jugabilidad: Art.sight_range() (a qué distancia te ven los
## alománticos) depende de los tres, y de día aparecen menos alománticos.

## Cae un relámpago (el estaño avivado encandila).
signal lightning

const WEATHERS := ["despejado", "lluvia", "ceniza"]
const WEATHER_NAMES := {"despejado": "Despejado", "lluvia": "Lluvia", "ceniza": "Lluvia de ceniza"}

var env: Environment
var moon: DirectionalLight3D
var sky_mat: ShaderMaterial  ## shaders/sky.gdshader
## Multiplica la niebla (la arena es más clara que la ciudad).
var fog_scale := 1.0
## Bajo techo (interiores): no cae lluvia ni ceniza.
var indoor := false
## Dentro de un edificio de la ciudad (Building): además, casi sin bruma (ver Building._indoor_zone).
var sheltered := false

var _rain: GPUParticles3D
var _ash: GPUParticles3D
var _label: Label
var _label_time := 0.0
var _moon_energy := 0.5
var _next_lightning := 10.0
var _flash := 0.0


func _ready() -> void:
	add_to_group(&"weather")
	_rain = _particles(5000, 1.0, Vector3(28, 1, 28), _rain_material(), Vector2(0.025, 0.7))
	var rain_pm := _rain.process_material as ParticleProcessMaterial
	rain_pm.direction = Vector3(0.08, -1, 0.04)
	rain_pm.spread = 3.0
	rain_pm.initial_velocity_min = 22.0
	rain_pm.initial_velocity_max = 28.0
	rain_pm.gravity = Vector3(0, -10, 0)
	rain_pm.particle_flag_align_y = true

	var ash_mat := Fx.particle_material(Color(0.22, 0.21, 0.2, 1.0), false)
	_ash = _particles(5000, 16.0, Vector3(24, 5, 24), ash_mat, Vector2(0.15, 0.15))
	var ash_pm := _ash.process_material as ParticleProcessMaterial
	ash_pm.direction = Vector3(0.6, -1, 0.2)
	ash_pm.spread = 30.0
	ash_pm.initial_velocity_min = 0.3
	ash_pm.initial_velocity_max = 0.8
	ash_pm.gravity = Vector3(0, -0.7, 0)
	ash_pm.scale_min = 0.5
	ash_pm.scale_max = 1.6
	ash_pm.turbulence_enabled = true
	ash_pm.turbulence_noise_strength = 1.5
	ash_pm.turbulence_noise_scale = 5.0
	ash_pm.turbulence_influence_min = 0.05
	ash_pm.turbulence_influence_max = 0.12
	ash_pm.color_ramp = Fx.fade_ramp(0.1)

	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.offset_top = 70
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_label)
	apply.call_deferred()  # cuando ya existan WorldFx y el resto del escenario


func _particles(amount: int, life: float, extents: Vector3, mat: Material, size: Vector2) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = mat
	p.draw_pass_1 = quad
	add_child(p)
	return p


func _rain_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Fx.soft_texture()
	m.albedo_color = Color(0.72, 0.77, 0.88, 0.32)
	return m


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F3:
			Art.lighting = "dia" if Art.lighting == "noche" else "noche"
		KEY_F4:
			Art.weather = WEATHERS[(WEATHERS.find(Art.weather) + 1) % WEATHERS.size()]
		KEY_F5:
			Art.fog = "poca" if Art.fog == "mucha" else "mucha"
		_:
			return
	apply()
	get_viewport().set_input_as_handled()


## Aplica Art.lighting, Art.weather y Art.fog al cielo, la luz, la niebla, el suelo y las partículas.
## show_label: avisa en pantalla del cambio (no hace falta al entrar o salir de un edificio).
func apply(show_label := true) -> void:
	var day := Art.lighting == "dia"
	var rain := Art.weather == "lluvia"
	var ash := Art.weather == "ceniza"
	var fog_mult := (0.45 if Art.fog == "poca" else 1.5) * fog_scale * (0.12 if sheltered else 1.0)

	# --- Hora
	# Cielo: [arriba, horizonte, suelo, nubes, borde de nubes, cobertura, estrellas, disco, tamaño del disco]
	var sky: Array
	if day:
		# Sol rojo de Luthadel tras nubes de ceniza pardas.
		sky = [Color(0.36, 0.27, 0.25), Color(0.78, 0.5, 0.38), Color(0.2, 0.17, 0.16), Color(0.33, 0.25, 0.22),
				Color(0.95, 0.6, 0.42), 0.62, 0.0, Color(1.0, 0.42, 0.25), 0.045]
		env.ambient_light_energy = 1.0
		env.fog_light_color = Color(0.75, 0.55, 0.45)
		env.fog_density = 0.01 * fog_mult
		env.volumetric_fog_density = 0.01 * fog_mult
		env.volumetric_fog_albedo = Color(0.9, 0.75, 0.65)
		moon.rotation_degrees = Vector3(-35, -40, 0)
		moon.light_color = Color(1.0, 0.68, 0.5)
		_moon_energy = 1.8
	else:
		# Noche de bruma: luna velada, nubes oscuras con el borde plateado y alguna estrella.
		sky = [Color(0.02, 0.025, 0.045), Color(0.15, 0.14, 0.16), Color(0.02, 0.02, 0.03), Color(0.045, 0.045, 0.055),
				Color(0.32, 0.37, 0.5), 0.55, 0.55, Color(0.82, 0.88, 1.0), 0.028]
		env.ambient_light_energy = 0.5
		env.fog_light_color = Color(0.48, 0.52, 0.62)
		env.fog_density = 0.025 * fog_mult
		env.volumetric_fog_density = 0.035 * fog_mult
		env.volumetric_fog_albedo = Color(0.8, 0.84, 0.9)
		moon.rotation_degrees = Vector3(-40, 30, 0)
		moon.light_color = Color(0.62, 0.7, 0.92)
		_moon_energy = 0.55
	env.tonemap_exposure = 1.0

	# --- Clima
	if rain:
		# Nubes de tormenta: menos luz, cielo plomizo y cerrado, algo más de niebla.
		var dark := 0.35 if day else 0.0
		sky[0] = (sky[0] as Color).lerp(Color(0.12, 0.13, 0.15) * (1.0 + dark), 0.6)
		sky[1] = (sky[1] as Color).lerp(Color(0.25, 0.27, 0.3), 0.6)
		sky[3] = (sky[3] as Color).lerp(Color(0.08, 0.085, 0.1) * (1.0 + 2.0 * dark), 0.7)
		sky[5] = 0.95
		sky[6] = 0.0
		env.ambient_light_energy *= 0.75
		env.fog_light_color = env.fog_light_color.lerp(Color(0.45, 0.5, 0.58), 0.5)
		env.fog_density *= 1.3
		env.volumetric_fog_density *= 1.3
		_moon_energy *= 0.45
	elif ash:
		# Cielo pardo y luz apagada; la ceniza flota en el aire.
		sky[0] = (sky[0] as Color).lerp(Color(0.2, 0.17, 0.15), 0.5)
		sky[1] = (sky[1] as Color).lerp(Color(0.38, 0.32, 0.28), 0.5)
		sky[3] = (sky[3] as Color).lerp(Color(0.22, 0.19, 0.17), 0.5 if day else 0.25)
		sky[5] = 0.85
		sky[6] = 0.1
		env.fog_light_color = env.fog_light_color.lerp(Color(0.5, 0.45, 0.4), 0.6)
		env.volumetric_fog_albedo = env.volumetric_fog_albedo.lerp(Color(0.6, 0.55, 0.5), 0.6)
		env.fog_density *= 1.35
		env.volumetric_fog_density *= 1.35
		_moon_energy *= 0.7
	moon.light_energy = _moon_energy
	moon.light_volumetric_fog_energy = 1.0 if day else 0.5
	var params := [&"top_color", &"horizon_color", &"ground_color", &"cloud_color", &"cloud_light",
			&"cloud_cover", &"stars", &"disc_color", &"disc_size"]
	for i in params.size():
		sky_mat.set_shader_parameter(params[i], sky[i])
	sky_mat.set_shader_parameter(&"haze", clampf((0.35 if Art.fog == "poca" else 0.7) + (0.15 if rain or ash else 0.0), 0.0, 1.0))

	# --- Suelo y paredes
	var mats := WorldKit.materials()
	for key in ["ground", "stone", "wall", "terrain", "road", "water"]:
		var m: ShaderMaterial = mats[key]
		m.set_shader_parameter(&"wetness", 1.0 if rain else 0.0)
		m.set_shader_parameter(&"ash_amount", 1.0 if ash else 0.0)

	# --- Exterior: bruma densa fuera de la muralla y lejanía de los montes de ceniza.
	var thick := Art.fog == "mucha"
	var bad_weather := rain or ash
	var ext_fog: FogMaterial = mats["exterior_fog"]
	ext_fog.density = (0.012 if day else 0.045) * (1.5 if thick else 0.6) * (1.2 if bad_weather else 1.0)
	ext_fog.albedo = env.fog_light_color.lerp(Color(0.85, 0.88, 0.94), 0.5)
	var haze := (0.28 if day else 0.72) + (0.2 if thick else 0.0) + (0.12 if rain else 0.0) + (0.15 if ash else 0.0)
	var mountain: ShaderMaterial = mats["mountain"]
	mountain.set_shader_parameter(&"haze", clampf(haze, 0.0, 0.97))
	mountain.set_shader_parameter(&"haze_color", env.fog_light_color)
	mountain.set_shader_parameter(&"haze_brightness", 0.9 if day else 0.12)  # de noche, siluetas oscuras

	# --- Partículas
	_rain.emitting = rain and not (indoor or sheltered)
	_ash.emitting = ash and not (indoor or sheltered)
	var world_fx := get_tree().get_first_node_in_group(&"world_fx") as WorldFx
	if world_fx:
		var mist := 0.07 * (0.5 if Art.fog == "poca" else 1.4)
		if day:
			mist *= 0.3  # la bruma es cosa de la noche
		world_fx.set_base_alpha(mist)

	Art.env_version += 1
	_label.text = "%s · %s · %s niebla\nVisibilidad: %d m" % ["Día" if day else "Noche", WEATHER_NAMES[Art.weather],
			"Poca" if Art.fog == "poca" else "Mucha", int(Art.sight_range())]
	if show_label:
		_label_time = 3.0


func _process(delta: float) -> void:
	var rd := delta / Engine.time_scale
	var cam := get_viewport().get_camera_3d()
	if cam:
		var c := cam.global_position
		_rain.global_position = c + Vector3(0, 14, 0)
		_ash.global_position = c + Vector3(0, 6, 0)
	_label_time -= rd
	_label.modulate.a = clampf(_label_time, 0.0, 1.0)
	_update_lightning(rd)


## Relámpagos durante la lluvia: dos destellos seguidos de la luz principal.
func _update_lightning(rd: float) -> void:
	if Art.weather != "lluvia":
		return
	_next_lightning -= rd
	if _next_lightning <= 0.0:
		_next_lightning = randf_range(12.0, 30.0)
		_flash = 0.45
		lightning.emit()
	if _flash > 0.0:
		_flash -= rd
		var on := fmod(_flash, 0.22) > 0.12
		moon.light_energy = (_moon_energy + 5.0) if on else _moon_energy
		moon.light_color = Color(0.85, 0.9, 1.0) if on else moon.light_color
		if _flash <= 0.0:
			apply_light_only()


func apply_light_only() -> void:
	moon.light_energy = _moon_energy
	moon.light_color = Color(1.0, 0.68, 0.5) if Art.lighting == "dia" else Color(0.62, 0.7, 0.92)
