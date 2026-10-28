class_name Mistcloak
extends Node3D
## Capa de bruma: tiras de tela de tres segmentos (cada vez más finas y claras hacia la punta)
## que ondean según la velocidad del cuerpo. Cada segmento es un resorte amortiguado que va con
## retraso respecto al anterior. Al moverse rápido o caer, las puntas dejan un rastro de bruma.
## Incluye capucha (bajada o subida). Se cuelga del pecho del HumanoidRig.

@export var strips := 15
@export var segment_length := 0.42

const SEGMENTS := 3
const WIDTHS := [0.1, 0.085, 0.065]

var hood_up := false

var _segs := []  # [segmento][tira] -> Node3D
var _ang := []  # [segmento][tira] -> Vector2
var _vel := []
var _t := 0.0
var _trail: GPUParticles3D
var _hood_down: MeshInstance3D
var _hood_up: MeshInstance3D


## neck: nodo del cuello del rig (para la capucha subida).
func build(color: Color, width := 1.0, neck: Node3D = null) -> void:
	var mantle := MeshInstance3D.new()
	mantle.mesh = HumanoidRig._cylinder(0.17, 0.28, 0.22)
	mantle.material_override = HumanoidRig._mat(color, 0.0, 0.95)
	mantle.position = Vector3(0, 0.36, 0.01)
	mantle.scale = Vector3(width * 1.05, 1, 0.85)
	add_child(mantle)

	# Capucha bajada (bulto detrás del cuello) y subida (cubre la cabeza).
	_hood_down = MeshInstance3D.new()
	_hood_down.mesh = HumanoidRig._sphere(0.13)
	_hood_down.material_override = mantle.material_override
	_hood_down.position = Vector3(0, 0.44, 0.12)
	_hood_down.scale = Vector3(1.2, 0.7, 0.8)
	add_child(_hood_down)
	if neck:
		_hood_up = MeshInstance3D.new()
		_hood_up.mesh = HumanoidRig._sphere(0.14)
		_hood_up.material_override = mantle.material_override
		_hood_up.position = Vector3(0, 0.17, 0.045)
		_hood_up.scale = Vector3(1.05, 1.08, 1.02)
		_hood_up.visible = false
		neck.add_child(_hood_up)

	# Cada segmento un poco más claro: la capa "se deshace" en bruma hacia las puntas.
	var mats := []
	for s in SEGMENTS:
		var c := color.lerp(Color(0.42, 0.45, 0.52), s * 0.22)
		mats.append([HumanoidRig._mat(c, 0.0, 0.95), HumanoidRig._mat(c.darkened(0.15), 0.0, 0.95)])
	for s in SEGMENTS:
		_segs.append([])
		_ang.append([])
		_vel.append([])
	for i in strips:
		var a := lerpf(-1.65, 1.65, float(i) / (strips - 1))  # alrededor de la espalda (0 = centro)
		var parent: Node3D = self
		for s in SEGMENTS:
			var p := Node3D.new()
			p.position = Vector3(sin(a) * 0.25 * width, 0.33, cos(a) * 0.17 + 0.03) if s == 0 else Vector3(0, -segment_length, 0)
			parent.add_child(p)
			var mi := MeshInstance3D.new()
			mi.mesh = HumanoidRig._box(Vector3(WIDTHS[s], segment_length, 0.012))
			mi.material_override = mats[s][i % 2]
			mi.position = Vector3(0, -segment_length / 2.0, 0)
			mi.rotation.y = a
			p.add_child(mi)
			_segs[s].append(p)
			_ang[s].append(Vector2(-0.12, 0) if s == 0 else Vector2.ZERO)
			_vel[s].append(Vector2.ZERO)
			parent = p

	_trail = GPUParticles3D.new()
	_trail.amount = 40
	_trail.lifetime = 1.4
	_trail.local_coords = false
	_trail.position = Vector3(0, -0.6, 0.3)
	_trail.visibility_aabb = AABB(Vector3(-6, -4, -6), Vector3(12, 8, 12))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.3, 0.45, 0.15)
	pm.gravity = Vector3(0, 0.2, 0)
	pm.initial_velocity_max = 0.2
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.color_ramp = Fx.fade_ramp(0.25)
	_trail.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 0.8)
	quad.material = Fx.particle_material(Color(0.72, 0.77, 0.88, 0.1), false, 0.4)
	_trail.draw_pass_1 = quad
	_trail.emitting = false
	add_child(_trail)


func set_hood(up: bool) -> void:
	hood_up = up
	_hood_down.visible = not up
	if _hood_up:
		_hood_up.visible = up


## vel: velocidad global del cuerpo.
func drive(dt: float, vel: Vector3) -> void:
	if _segs.is_empty() or dt <= 0.0:
		return
	dt = minf(dt, 1.0 / 30.0)
	_t += dt
	var local := global_basis.inverse() * vel
	var forward := -local.z
	var flare := clampf(forward * 0.13, 0.0, 1.3)
	var fall := clampf(-local.y * 0.1, 0.0, 1.9)  # al caer, las tiras suben
	var base := Vector2(-0.12 - flare - fall, clampf(-local.x * 0.1, -0.7, 0.7))
	var speed := vel.length()
	var mid := (strips - 1) / 2.0
	for i in strips:
		var flutter := sin(_t * (7.0 + i * 0.7) + i * 1.3) * (0.03 + speed * 0.012)
		var spread := (i - mid) / mid * fall * 0.25
		var target: Vector2 = base + Vector2(flutter, flutter * 0.5 + spread)
		for s in SEGMENTS:
			var stiffness := 60.0 - s * 15.0
			var damping := 9.0 - s * 2.0
			if s > 0:
				# Los segmentos siguientes se retrasan respecto al anterior y ondean más.
				target = (target - _ang[s - 1][i]) * 0.8 + Vector2(flutter * (1.0 + s), 0)
			_vel[s][i] += ((target - _ang[s][i]) * stiffness - _vel[s][i] * damping) * dt
			_ang[s][i] += _vel[s][i] * dt
			if s == 0:
				_ang[s][i].x = clampf(_ang[s][i].x, -2.8, 0.15)
			_segs[s][i].rotation = Vector3(_ang[s][i].x, 0, _ang[s][i].y)
	_trail.emitting = speed > 4.5
	_trail.amount_ratio = clampf((speed - 4.5) / 10.0, 0.2, 1.0)
