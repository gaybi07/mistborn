class_name WorldFx
extends Node3D
## Ceniza que cae del cielo y jirones de bruma a ras de suelo. Siguen a la cámara.

var _ash: GPUParticles3D
var _mist: GPUParticles3D
var _mist_mat: StandardMaterial3D
var _mist_alpha := 0.07


func _ready() -> void:
	add_to_group(&"world_fx")

	_ash = _make_particles(1800, 14.0, Vector3(35, 1, 35), 0.05, Fx.particle_material(Color(0.36, 0.34, 0.33, 0.9), false))
	var ash_pm := _ash.process_material as ParticleProcessMaterial
	ash_pm.gravity = Vector3(0, -0.8, 0)
	ash_pm.direction = Vector3(1, 0, 0.3)
	ash_pm.spread = 40.0
	ash_pm.initial_velocity_min = 0.1
	ash_pm.initial_velocity_max = 0.5
	ash_pm.turbulence_enabled = true
	ash_pm.turbulence_noise_strength = 1.0
	ash_pm.turbulence_noise_scale = 4.0
	ash_pm.turbulence_influence_min = 0.03
	ash_pm.turbulence_influence_max = 0.08

	_mist_mat = Fx.particle_material(Color(0.1, 0.1, 0.13, _mist_alpha), false, 3.0)  # jirones de las nubes negras
	_mist_mat.disable_fog = true  # si no, la niebla los aclara y parecen humo blanco
	_mist = _make_particles(110, 18.0, Vector3(45, 2, 45), 7.0, _mist_mat)
	var mist_pm := _mist.process_material as ParticleProcessMaterial
	mist_pm.gravity = Vector3.ZERO
	mist_pm.direction = Vector3(1, 0, 0.3)
	mist_pm.spread = 60.0
	mist_pm.initial_velocity_min = 0.3
	mist_pm.initial_velocity_max = 0.9
	mist_pm.scale_min = 0.6
	mist_pm.scale_max = 1.5
	mist_pm.angle_min = -180.0
	mist_pm.angle_max = 180.0
	mist_pm.color_ramp = Fx.fade_ramp(0.3)
	_mist.position.y = 1.5


## Opacidad base de los jirones de bruma (la fija Weather según hora y niebla).
func set_base_alpha(alpha: float) -> void:
	_mist_alpha = alpha
	set_mist_strength(1.0)


func _make_particles(amount: int, life: float, extents: Vector3, size: float, mat: Material) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.visibility_aabb = AABB(Vector3(-60, -30, -60), Vector3(120, 60, 120))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	p.draw_pass_1 = quad
	add_child(p)
	return p


## La ceniza que flota siempre en el aire (se apaga desde el menú, ver Art.ash_fall).
func set_ash_enabled(on: bool) -> void:
	_ash.emitting = on


## 1 = bruma normal; el estaño la reduce.
func set_mist_strength(strength: float) -> void:
	var c := _mist_mat.albedo_color
	c.a = _mist_alpha * strength
	_mist_mat.albedo_color = c


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	global_position = Vector3(cam.global_position.x, 0, cam.global_position.z)
	_ash.position.y = cam.global_position.y + 14.0
