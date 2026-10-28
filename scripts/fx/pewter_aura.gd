class_name PewterAura
extends Node3D
## Peltre: neblina rojiza que sale del cuerpo, brasas que suben y un leve resplandor rojo.
## Quemando es sutil; avivando, intenso. Con cobre quemando no se ve nada.

## Quien quema el peltre: cualquier nodo con una propiedad `allomancy` (jugador o PNJ).
var holder: Node3D

var _haze: GPUParticles3D
var _embers: GPUParticles3D
var _light: OmniLight3D
var _level := 0.0


func _ready() -> void:
	position = Vector3(0, 0.9, 0)

	_haze = _particles(40, 1.6, Vector3(0.3, 0.75, 0.3), 0.9,
			Fx.particle_material(Color(1.0, 0.18, 0.1, 0.12), true, 0.5))
	var haze_pm := _haze.process_material as ParticleProcessMaterial
	haze_pm.gravity = Vector3(0, 0.6, 0)
	haze_pm.initial_velocity_min = 0.1
	haze_pm.initial_velocity_max = 0.35
	haze_pm.scale_min = 0.6
	haze_pm.scale_max = 1.3
	haze_pm.angle_min = -180.0
	haze_pm.angle_max = 180.0
	haze_pm.color_ramp = Fx.fade_ramp(0.3)

	_embers = _particles(30, 1.0, Vector3(0.28, 0.7, 0.28), 0.045,
			Fx.particle_material(Color(1.0, 0.35, 0.12, 1.0) * 2.5, true))
	var ember_pm := _embers.process_material as ParticleProcessMaterial
	ember_pm.gravity = Vector3(0, 2.5, 0)
	ember_pm.initial_velocity_min = 0.4
	ember_pm.initial_velocity_max = 1.2
	ember_pm.damping_min = 1.0
	ember_pm.damping_max = 2.0
	ember_pm.turbulence_enabled = true
	ember_pm.turbulence_noise_strength = 1.5
	ember_pm.turbulence_influence_min = 0.1
	ember_pm.turbulence_influence_max = 0.2
	ember_pm.color_ramp = Fx.fade_ramp()

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.25, 0.15)
	_light.omni_range = 3.0
	_light.light_energy = 0.0
	add_child(_light)


func _particles(amount: int, life: float, extents: Vector3, size: float, mat: Material) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false  # se quedan atrás al moverte: "sale" del cuerpo
	p.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 8, 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.direction = Vector3.UP
	pm.spread = 25.0
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	p.draw_pass_1 = quad
	p.emitting = false
	add_child(p)
	return p


func _process(delta: float) -> void:
	var rd := delta / Engine.time_scale
	var a: Allomancy = holder.allomancy
	if a == null:
		return
	var target := 0.0 if a.is_burning(&"copper") else a.strength(&"pewter")
	_level = move_toward(_level, target, rd * 4.0)
	var on := _level > 0.05
	_haze.emitting = on
	_embers.emitting = on
	# Quemando (1): neblina a medias y pocas brasas. Avivando (2): todo al máximo.
	var k := _level / Allomancy.FLARE_STRENGTH
	_haze.amount_ratio = clampf(k, 0.1, 1.0)
	_embers.amount_ratio = clampf(k * k, 0.05, 1.0)
	_light.light_energy = k * 1.2
