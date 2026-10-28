class_name Brazier
extends StaticBody3D
## Brasero con fuego: llamas, brasas y una luz que parpadea.
## Por defecto es de piedra y madera pintada (sin líneas); con is_metal = true es de hierro y sirve de ancla.

var is_metal := false

var _light: OmniLight3D
var _t := randf() * 10.0


func _ready() -> void:
	collision_layer = Props.LAYER_WORLD
	collision_mask = 0
	if is_metal:
		add_to_group(&"metal")
		set_meta(&"center_offset", Vector3(0, 1.0, 0))
	var iron := HumanoidRig._mat(Color(0.12, 0.12, 0.13), 0.85, 0.45)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 1.2, 0.9)
	col.shape = shape
	col.position.y = 0.6
	add_child(col)
	for i in 3:
		var a := TAU * i / 3.0
		var leg := Props._part(self, Props._box_mesh(Vector3(0.06, 1.0, 0.06)), Vector3(cos(a) * 0.3, 0.5, sin(a) * 0.3), iron)
		leg.rotation = Vector3(sin(a) * 0.15, 0, -cos(a) * 0.15)
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.45
	bowl.bottom_radius = 0.25
	bowl.height = 0.3
	Props._part(self, bowl, Vector3(0, 1.0, 0), iron)
	var coals_mat := Props.material(Color(1.0, 0.4, 0.1), 0.0, 0.8)
	coals_mat.emission_enabled = true
	coals_mat.emission = Color(1.0, 0.35, 0.08)
	coals_mat.emission_energy_multiplier = 3.0
	var coals := CylinderMesh.new()
	coals.top_radius = 0.4
	coals.bottom_radius = 0.4
	coals.height = 0.04
	Props._part(self, coals, Vector3(0, 1.13, 0), coals_mat)

	_flames(24, 0.7, 0.4, Color(1.0, 0.45, 0.12, 0.6) * 2.0, 1.6)
	_flames(12, 1.6, 0.05, Color(1.0, 0.5, 0.15, 1.0) * 3.0, 2.5)

	_light = OmniLight3D.new()
	_light.position = Vector3(0, 1.7, 0)
	_light.light_color = Color(1.0, 0.55, 0.25)
	_light.omni_range = 8.0
	_light.light_volumetric_fog_energy = 2.0
	add_child(_light)


func _flames(amount: int, life: float, size: float, color: Color, rise: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.position = Vector3(0, 1.15, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25
	pm.direction = Vector3.UP
	pm.spread = 15.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0, rise, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.0
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.15
	pm.color_ramp = Fx.fade_ramp()
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = Fx.particle_material(color, true)
	p.draw_pass_1 = quad
	add_child(p)


func _process(delta: float) -> void:
	_t += delta
	_light.light_energy = 1.8 + sin(_t * 13.0) * 0.25 + sin(_t * 7.3) * 0.2
