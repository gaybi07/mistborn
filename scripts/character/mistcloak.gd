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

## Textura de tela compartida por todas las capas: grano de cuero curtido y su relieve.
static var _grain: NoiseTexture2D
static var _grain_normal: NoiseTexture2D

## Capa modelada (Meshy, tela desgarrada) para los personajes con esqueleto: la tela va pegada
## (skinning) a cadenas de huesos que bajan por la espalda y los costados, y un
## SpringBoneSimulator3D las mueve con inercia y gravedad, chocando con cápsulas del cuerpo.
const MODEL_PATH := "res://assets/meshy/mistcloak/mistcloak.fbx"
const MODEL_TEX := "res://assets/meshy/mistcloak/mistcloak_%s.png"
## Punto del cuello en la malla tal como se importa (mira hacia +Z, en metros).
const MODEL_NECK := Vector3(0, 1.68, -0.12)
## Cadenas repartidas alrededor del cuerpo (0 = centro de la espalda), hasta ±CHAIN_SPREAD rad.
const CHAINS := 12
const CHAIN_SPREAD := 2.7
## Altura de las articulaciones de cada cadena en la malla (del hombro al borde).
const LEVELS := [-0.1, -0.48, -0.86, -1.24, -1.62]
const LEVEL_STEP := 0.38
## Escala de la malla para el cuerpo de los personajes (ancho, alto, fondo).
const MODEL_SCALE := Vector3(0.99, 0.86, 0.99)
static var _model_mesh: ArrayMesh
static var _joints := []  # [cadena][nivel] -> Vector3 en la malla
var _model_mat: ShaderMaterial
var _model_mi: MeshInstance3D
var _sim: SpringBoneSimulator3D


## La malla con el origen en el cuello, mirando hacia -Z, con los pesos de cada vértice hacia el
## torso (índice 0 del Skin) y las articulaciones de las cadenas (1 + cadena * niveles + nivel).
static func _baked_model() -> ArrayMesh:
	if _model_mesh:
		return _model_mesh
	var src: Node = load(MODEL_PATH).instantiate()
	var mi: MeshInstance3D = src.find_children("*", "MeshInstance3D", true, false)[0]
	var xf := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * Transform3D(Basis(), -MODEL_NECK) * mi.transform
	var rot := xf.basis.orthonormalized()
	var arrays := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in verts.size():
		verts[i] = xf * verts[i]
		normals[i] = rot * normals[i]
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var tangents = arrays[Mesh.ARRAY_TANGENT]
	if tangents != null:
		for i in range(0, tangents.size(), 4):
			var t := rot * Vector3(tangents[i], tangents[i + 1], tangents[i + 2])
			tangents[i] = t.x
			tangents[i + 1] = t.y
			tangents[i + 2] = t.z
		arrays[Mesh.ARRAY_TANGENT] = tangents
	src.free()

	# Articulaciones: el centro de los vértices de cada cadena a la altura de cada nivel.
	var step := CHAIN_SPREAD * 2.0 / (CHAINS - 1)
	var sums := []
	for c in CHAINS:
		sums.append([])
		for k in LEVELS.size():
			sums[c].append([Vector3.ZERO, 0])
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(verts.size() * 4)
	weights.resize(verts.size() * 4)
	for i in verts.size():
		var v := verts[i]
		var cf := clampf((atan2(v.x, v.z) + CHAIN_SPREAD) / step, 0.0, CHAINS - 1.0)
		var lf: float = (LEVELS[0] - v.y) / LEVEL_STEP
		var near_level := roundi(lf)
		if near_level >= 0 and near_level < LEVELS.size() and absf(lf - near_level) * LEVEL_STEP < 0.06:
			var acc: Array = sums[roundi(cf)][near_level]
			acc[0] += v
			acc[1] += 1
		# Cada vértice sigue a las dos cadenas más cercanas y, en cada una, a las dos
		# articulaciones entre las que está (por encima del hombro, al torso).
		var c0 := mini(floori(cf), CHAINS - 2)
		var fc := cf - c0
		var u := clampf(lf - 0.5, -1.0, LEVELS.size() - 1.0)
		var k0 := mini(floori(u), LEVELS.size() - 2)
		var fk := u - k0
		var slots := [[c0, k0, (1.0 - fc) * (1.0 - fk)], [c0, k0 + 1, (1.0 - fc) * fk],
				[c0 + 1, k0, fc * (1.0 - fk)], [c0 + 1, k0 + 1, fc * fk]]
		for j in 4:
			var k: int = slots[j][1]
			bones[i * 4 + j] = 0 if k < 0 else 1 + slots[j][0] * LEVELS.size() + k
			weights[i * 4 + j] = slots[j][2]
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	_joints.clear()
	for c in CHAINS:
		var th := -CHAIN_SPREAD + c * step
		var chain := []
		for k in LEVELS.size():
			var acc: Array = sums[c][k]
			chain.append(acc[0] / acc[1] if acc[1] > 0 else Vector3(sin(th) * 0.3, LEVELS[k], cos(th) * 0.2))
		_joints.append(chain)
	_model_mesh = ArrayMesh.new()
	_model_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _model_mesh


## Tela oscura con grano y relieve, teñida con `color` (a juego con el cuero del traje).
static func _cloth(color: Color) -> StandardMaterial3D:
	if _grain == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.frequency = 0.04
		noise.fractal_octaves = 3
		_grain = NoiseTexture2D.new()
		_grain.noise = noise
		_grain.seamless = true
		_grain.color_ramp = Gradient.new()
		_grain.color_ramp.set_color(0, Color(0.7, 0.7, 0.7))
		_grain.color_ramp.set_color(1, Color(1, 1, 1))
		_grain_normal = NoiseTexture2D.new()
		_grain_normal.noise = noise
		_grain_normal.seamless = true
		_grain_normal.as_normal_map = true
		_grain_normal.bump_strength = 6.0
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = _grain
	m.normal_enabled = true
	m.normal_texture = _grain_normal
	m.normal_scale = 0.8
	m.roughness = 0.75
	m.uv1_scale = Vector3(3, 3, 3)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## neck: nodo del cuello del rig (para la capucha subida).
## strips_only: solo las tiras, para modelos que ya traen chaqueta y capucha.
func build(color: Color, width := 1.0, neck: Node3D = null, strips_only := false) -> void:
	if not strips_only:
		var mantle := MeshInstance3D.new()
		mantle.mesh = HumanoidRig._cylinder(0.17, 0.28, 0.22)
		mantle.material_override = _cloth(color)
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
		mats.append([_cloth(c), _cloth(c.darkened(0.15))])
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
	_add_trail()


## Capa modelada de tela desgarrada, en lugar de las tiras. suit: color del traje, o null para
## dejar la tela con su color original. Agrega sus huesos a `skel` colgando de `torso`, con el
## cuello de la capa en el hueso `neck`. colliders: [[hueso, hueso, radio], ...] del cuerpo.
func build_model(suit: Variant, skel: Skeleton3D, torso: int, neck: int, colliders: Array) -> void:
	var mesh := _baked_model()
	_model_mat = ShaderMaterial.new()
	_model_mat.shader = preload("res://shaders/mistcloak.gdshader")
	_model_mat.set_shader_parameter("albedo_tex", load(MODEL_TEX % "diffuse"))
	_model_mat.set_shader_parameter("normal_tex", load(MODEL_TEX % "normal"))
	_model_mat.set_shader_parameter("rough_tex", load(MODEL_TEX % "roughness"))
	set_suit_color(suit)

	# De la malla al espacio del esqueleto (los modelos miran hacia +Z dentro de su esqueleto).
	var fit := Transform3D(Basis(Vector3.UP, PI) * Basis.from_scale(MODEL_SCALE), skel.get_bone_global_rest(neck).origin)
	var skin := Skin.new()
	skin.add_bind(torso, skel.get_bone_global_rest(torso).affine_inverse() * fit)
	var chain_bones := []
	for c in CHAINS:
		var parent := torso
		var chain := []
		for k in LEVELS.size():
			var bone_name := "cloak_%d_%d" % [c, k]
			var b := skel.find_bone(bone_name)
			if b < 0:  # los huesos quedan en el esqueleto si la capa se vuelve a armar
				skel.add_bone(bone_name)
				b = skel.find_bone(bone_name)
				skel.set_bone_parent(b, parent)
			var global := Transform3D(Basis(), fit * (_joints[c][k] as Vector3))
			skel.set_bone_rest(b, skel.get_bone_global_rest(parent).affine_inverse() * global)
			skel.reset_bone_pose(b)
			skin.add_bind(b, global.affine_inverse() * fit)
			chain.append(b)
			parent = b
		chain_bones.append(chain)

	_model_mi = MeshInstance3D.new()
	_model_mi.mesh = mesh
	_model_mi.skin = skin
	_model_mi.material_override = _model_mat
	_model_mi.extra_cull_margin = 1.0
	skel.add_child(_model_mi)
	_model_mi.skeleton = _model_mi.get_path_to(skel)

	_sim = SpringBoneSimulator3D.new()
	skel.add_child(_sim)
	_sim.set_setting_count(CHAINS)
	for c in CHAINS:
		_sim.set_root_bone(c, chain_bones[c][0])
		_sim.set_end_bone(c, chain_bones[c][-1])
		_sim.set_extend_end_bone(c, true)
		_sim.set_end_bone_length(c, LEVEL_STEP * MODEL_SCALE.y)
		_sim.set_radius(c, 0.03)
		_sim.set_stiffness(c, 1.2)
		_sim.set_drag(c, 0.5)
		_sim.set_gravity(c, 2.0)
	for col in colliders:
		var a: int = col[0]
		var r: float = col[2]
		var to_b := skel.get_bone_global_rest(a).affine_inverse() * skel.get_bone_global_rest(col[1]).origin
		var cap := SpringBoneCollisionCapsule3D.new()
		_sim.add_child(cap)
		cap.set_bone(a)
		cap.set_position_offset(to_b / 2.0)
		cap.set_rotation_offset(Quaternion(Vector3.UP, to_b.normalized()))
		cap.set_radius(r)
		cap.set_height(to_b.length() + r * 2.0)
	_add_trail()


## Color del traje para la capa modelada, o null para su color original.
func set_suit_color(suit: Variant) -> void:
	_model_mat.set_shader_parameter("suit", suit if suit != null else Color.WHITE)
	_model_mat.set_shader_parameter("recolor", 0.0 if suit == null else 1.0)


func _notification(what: int) -> void:
	# La tela y el simulador cuelgan del esqueleto, no de este nodo: se ocultan y se borran con él.
	if _model_mi == null or not is_instance_valid(_model_mi):
		return
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		var shown := is_visible_in_tree()
		_model_mi.visible = shown
		_sim.active = shown
		if shown:
			_sim.reset()
	elif what == NOTIFICATION_PREDELETE:
		_model_mi.queue_free()
		_sim.queue_free()


func _add_trail() -> void:
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
	if _hood_down:
		_hood_down.visible = not up
	if _hood_up:
		_hood_up.visible = up


## vel: velocidad global del cuerpo.
func drive(dt: float, vel: Vector3) -> void:
	if (_segs.is_empty() and _model_mi == null) or dt <= 0.0:
		return
	dt = minf(dt, 1.0 / 30.0)
	_t += dt
	var local := global_basis.inverse() * vel
	var forward := -local.z
	var flare := clampf(forward * 0.13, 0.0, 1.3)
	var fall := clampf(-local.y * 0.1, 0.0, 1.9)  # al caer, las tiras suben
	var base := Vector2(-0.12 - flare - fall, clampf(-local.x * 0.1, -0.7, 0.7))
	var speed := vel.length()
	_trail.emitting = speed > 4.5
	_trail.amount_ratio = clampf((speed - 4.5) / 10.0, 0.2, 1.0)
	if _model_mi:
		return  # la capa modelada la mueve el SpringBoneSimulator3D
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
