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

## Capa de los personajes con esqueleto: una sola tela del cuello a las pantorrillas, abierta adelante, con
## cuello alzado y broche, sin capucha (tools/blender/make_mistcloak.py la cuelga con simulación de tela sobre Vin y la
## riguea). Cadenas de huesos alrededor de la espalda, con pesos mezclados entre vecinas para que se mueva
## entera; las mueve un SpringBoneSimulator3D (inercia, gravedad, viento y aire de la carrera) y chocan con
## cápsulas del cuerpo. Los bordes rotos y los agujeros los corta el shader.
const CLOTH_PATH := "res://assets/models/mistcloak/mistcloak_vin.glb"
## _cloak_fit() del ModelRig de Vin, sobre la que se colgó la tela: los demás cuerpos la escalan a su medida.
const VIN_FIT := Vector3(0.7125, 0.902, 0.7125)
## Viento del mundo (m/s); lo puede cambiar el clima.
static var wind := Vector3(0.8, 0.0, 0.3)
## Cuánto empuja el aire relativo (viento menos velocidad del cuerpo) a la tela.
const AIR_PUSH := 0.12  # lana gruesa: con más, al correr queda horizontal como una bandera
## Malla (huesos renumerados por el orden de `names`), y de cada hueso su posición y su padre ("" = torso).
static var _cloth_mesh: ArrayMesh
static var _cloth_bones := {}  # nombre -> {"at": Vector3, "parent": String}
static var _cloth_names: PackedStringArray
var _model_mat: ShaderMaterial
var _model_mi: MeshInstance3D
var _sim: SpringBoneSimulator3D
var _chains := 0


## Lee el .glb una vez: la malla en el espacio del cuello (mirando a +Z) y dónde va cada hueso.
static func _load_cloth() -> void:
	if _cloth_mesh:
		return
	var src: Node = load(CLOTH_PATH).instantiate()
	var sk: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = src.find_children("*", "MeshInstance3D", true, false)[0]
	for b in sk.get_bone_count():
		var parent := sk.get_bone_parent(b)
		_cloth_bones[sk.get_bone_name(b)] = {"at": sk.get_bone_global_rest(b).origin,
				"parent": "" if parent < 0 or sk.get_bone_name(parent) == "cloak_root" else sk.get_bone_name(parent)}
	var skin: Skin = mi.skin
	_cloth_names = PackedStringArray()
	for i in skin.get_bind_count():
		var bn := skin.get_bind_name(i)
		_cloth_names.append(bn if bn != "" else sk.get_bone_name(skin.get_bind_bone(i)))
	_cloth_mesh = ArrayMesh.new()
	for surf in mi.mesh.get_surface_count():
		_cloth_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mi.mesh.surface_get_arrays(surf))
	src.free()


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


## Capa de tela para modelos con esqueleto. suit: color del traje, o null para el gris oscuro de la tela.
## Agrega sus huesos a `skel` colgando de `torso`, con el cuello de la capa en el hueso `neck`.
## colliders: [[hueso, hueso, radio], ...] del cuerpo. body: medidas de este cuerpo (ModelRig._cloak_fit).
func build_model(suit: Variant, skel: Skeleton3D, torso: int, neck: int, colliders: Array, body := Vector3.ONE) -> void:
	_load_cloth()
	_model_mat = ShaderMaterial.new()
	_model_mat.shader = preload("res://shaders/mistcloak.gdshader")
	set_suit_color(suit)
	var clasp := StandardMaterial3D.new()
	clasp.albedo_color = Color(0.22, 0.2, 0.18)
	clasp.metallic = 0.85
	clasp.roughness = 0.45

	var fit := Transform3D(Basis.from_scale(body / VIN_FIT), skel.get_bone_global_rest(neck).origin)
	var skin := Skin.new()
	var ids := {}
	for bone_name in _cloth_names:
		if bone_name == "cloak_root":
			continue
		var b := skel.find_bone(bone_name)
		if b < 0:  # los huesos quedan en el esqueleto si la capa se vuelve a armar
			skel.add_bone(bone_name)
			b = skel.find_bone(bone_name)
		ids[bone_name] = b
	# Padres antes que hijos: las cadenas van de arriba (k = 0) a abajo.
	var names: Array = ids.keys()
	names.sort_custom(func(a: String, c: String) -> bool: return int(a.get_slice("_", 2)) < int(c.get_slice("_", 2)))
	for bone_name in names:
		var b: int = ids[bone_name]
		var parent_name: String = _cloth_bones[bone_name]["parent"]
		var parent: int = torso if parent_name == "" else ids[parent_name]
		skel.set_bone_parent(b, parent)
		var global := Transform3D(Basis(), fit * (_cloth_bones[bone_name]["at"] as Vector3))
		skel.set_bone_rest(b, skel.get_bone_global_rest(parent).affine_inverse() * global)
		skel.reset_bone_pose(b)
	# Los binds en el mismo orden que en el .glb: los índices de hueso de la malla apuntan a ellos.
	for bone_name in _cloth_names:
		var b: int = torso if bone_name == "cloak_root" else ids[bone_name]
		skin.add_bind(b, skel.get_bone_global_rest(b).affine_inverse() * fit)

	_model_mi = MeshInstance3D.new()
	_model_mi.mesh = _cloth_mesh
	_model_mi.skin = skin
	_model_mi.set_surface_override_material(0, _model_mat)
	_model_mi.set_surface_override_material(1, clasp)
	_model_mi.extra_cull_margin = 1.5
	skel.add_child(_model_mi)
	_model_mi.skeleton = _model_mi.get_path_to(skel)

	_sim = SpringBoneSimulator3D.new()
	skel.add_child(_sim)
	_chains = 0
	while ids.has("cloak_%d_0" % _chains):
		_chains += 1
	_sim.set_setting_count(_chains)
	for m in _chains:
		var k := 0
		while ids.has("cloak_%d_%d" % [m, k + 1]):
			k += 1
		_sim.set_root_bone(m, ids["cloak_%d_0" % m])
		_sim.set_end_bone(m, ids["cloak_%d_%d" % [m, k]])
		_sim.set_extend_end_bone(m, true)
		var last: Vector3 = _cloth_bones["cloak_%d_%d" % [m, k]]["at"] - _cloth_bones["cloak_%d_%d" % [m, k - 1]]["at"]
		_sim.set_end_bone_length(m, last.length() * body.y / VIN_FIT.y)
		_sim.set_radius(m, 0.03)
		_sim.set_stiffness(m, 0.5)
		_sim.set_drag(m, 0.35)
		_sim.set_gravity(m, 2.0)
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


## Color del traje para la capa, o null para el gris oscuro de la tela.
func set_suit_color(suit: Variant) -> void:
	_model_mat.set_shader_parameter("base_color", (suit as Color).darkened(0.55) if suit != null else Color(0.075, 0.072, 0.07))


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
	_trail.visible = Fx.ENABLED
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
	if _sim:
		# La tela la mueve el SpringBoneSimulator3D: el aire (viento con ráfagas menos la velocidad
		# del cuerpo) la empuja.
		var gust := 0.7 + 0.3 * sin(_t * 1.3) * sin(_t * 0.37 + 1.0)
		var air := wind * gust - vel
		_sim.external_force = air * AIR_PUSH
		# Una onda que recorre la capa de una cadena a la vecina (arriba la tela es entera: si cada una
		# aleteara por su lado, se estiraría entre ellas) y un poco de aleteo propio de cada tira.
		var amp := 0.04 + air.length() * 0.025
		for m in _chains:
			var f := sin(_t * 4.0 - m * 0.45) * amp + sin(_t * 1.7 + m * 0.2) * amp * 0.5 + sin(_t * 6.3 + m * 2.7) * amp * 0.4
			_sim.set_gravity_direction(m, Vector3(f, -1.0, f * 0.6).normalized())
		return
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
