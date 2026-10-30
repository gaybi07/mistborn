class_name MistSwirl
extends GPUParticles3D
## La bruma se arremolina alrededor del alomántico mientras quema metales.

## Quien quema metales: cualquier nodo con una propiedad `allomancy` (jugador o PNJ).
var holder: Node3D


func _ready() -> void:
	amount = 70
	lifetime = 3.0
	local_coords = false
	visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 10, 16))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 2.2
	pm.gravity = Vector3(0, 0.05, 0)
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.radial_accel_min = -1.4
	pm.radial_accel_max = -0.6
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.0
	pm.turbulence_influence_min = 0.1
	pm.turbulence_influence_max = 0.25
	pm.scale_min = 1.0
	pm.scale_max = 2.2
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.color_ramp = Fx.fade_ramp(0.3)
	process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mat := Fx.particle_material(Color(0.08, 0.08, 0.11, 0.12), false, 0.8)  # la bruma negra
	mat.disable_fog = true  # si no, la niebla la aclara y parece humo blanco
	quad.material = mat
	draw_pass_1 = quad
	emitting = false


func _process(_delta: float) -> void:
	global_position = holder.global_position + Vector3(0, 1.0, 0)
	var a: Allomancy = holder.allomancy
	if a == null:
		return
	# El cobre oculta las señales de la alomancia.
	emitting = not a.burning_metals().is_empty() and not a.is_burning(&"copper")
