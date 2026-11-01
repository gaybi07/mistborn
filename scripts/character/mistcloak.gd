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

## Capa de los personajes con esqueleto: arriba el manto modelado (Meshy: hombros y capucha), cortado
## a media espalda, y desde su borde cuelgan tiras de tela finas y sueltas. Cada tira es una cadena
## de huesos que mueve un SpringBoneSimulator3D (inercia, gravedad, viento y aire de la carrera) y
## choca con cápsulas del cuerpo.
const MODEL_PATH := "res://assets/meshy/mistcloak/mistcloak.fbx"
const MODEL_TEX := "res://assets/meshy/mistcloak/mistcloak_%s.png"
## Punto del cuello en la malla tal como se importa (mira hacia +Z, en metros).
const MODEL_NECK := Vector3(0, 1.68, -0.12)
## Escala de la malla para el cuerpo de los personajes (ancho, alto, fondo).
const MODEL_SCALE := Vector3(0.99, 0.86, 0.99)
## Altura del borde del manto (desde el cuello, en la malla): de ahí cuelgan las tiras.
const HEM_Y := -0.4
## Tiras alrededor del cuerpo (0 = centro de la espalda) hasta ±STRIP_SPREAD rad.
const STRIPS := 34
const STRIP_SPREAD := 2.6
const STRIP_BONES := 4
const STRIP_ROWS := 16
## Viento del mundo (m/s); lo puede cambiar el clima.
static var wind := Vector3(0.8, 0.0, 0.3)
## Cuánto empuja el aire relativo (viento menos velocidad del cuerpo) a las tiras.
const AIR_PUSH := 0.3
static var _model_mesh: ArrayMesh
static var _strip_joints := []  # [tira] -> {"joints": [Vector3 de cada hueso en la malla], "tail": largo del último}
var _model_mat: ShaderMaterial
var _strip_mat: ShaderMaterial
var _model_mi: MeshInstance3D
var _sim: SpringBoneSimulator3D


## Manto (superficie 0, pegado al torso: hueso 0 del Skin) y tiras (superficie 1, cada una con sus
## huesos 1 + tira * STRIP_BONES + k), con el origen en el cuello y mirando hacia -Z.
static func _baked_model() -> ArrayMesh:
	if _model_mesh:
		return _model_mesh
	var src: Node = load(MODEL_PATH).instantiate()
	var mi: MeshInstance3D = src.find_children("*", "MeshInstance3D", true, false)[0]
	var xf := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * Transform3D(Basis(), -MODEL_NECK) * mi.transform
	var rot := xf.basis.orthonormalized()
	var arrays := mi.mesh.surface_get_arrays(0)
	src.free()
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
	# Manto: solo los triángulos por encima del borde (un poco más abajo, para que tape el comienzo
	# de las tiras).
	var index: PackedInt32Array
	if arrays[Mesh.ARRAY_INDEX] != null:
		index = arrays[Mesh.ARRAY_INDEX]
	else:
		index = PackedInt32Array(range(verts.size()))
	var kept := PackedInt32Array()
	var cut := HEM_Y - 0.07
	for i in range(0, index.size(), 3):
		if verts[index[i]].y > cut and verts[index[i + 1]].y > cut and verts[index[i + 2]].y > cut:
			kept.append_array([index[i], index[i + 1], index[i + 2]])
	arrays[Mesh.ARRAY_INDEX] = kept
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(verts.size() * 4)
	weights.resize(verts.size() * 4)
	for i in verts.size():
		weights[i * 4] = 1.0
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	_model_mesh = ArrayMesh.new()
	_model_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_model_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _strip_arrays(_hem_radii(verts)))
	return _model_mesh


## Radio del manto a la altura del borde, por sectores de ángulo (0 = centro de la espalda, +Z).
static func _hem_radii(verts: PackedVector3Array) -> PackedFloat32Array:
	var radii := PackedFloat32Array()
	radii.resize(72)
	for v in verts:
		if absf(v.y - HEM_Y) < 0.05:
			var k := posmod(int(round((atan2(v.x, v.z) + PI) / TAU * 72.0)), 72)
			radii[k] = maxf(radii[k], Vector2(v.x, v.z).length())
	return radii


## Malla de las tiras: cintas que se angostan hacia la punta, en dos capas alternadas (las de
## adentro un poco más largas), con una leve curva a lo ancho. Guarda dónde va cada hueso.
static func _strip_arrays(radii: PackedFloat32Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var index := PackedInt32Array()
	_strip_joints.clear()
	for s in STRIPS:
		var th := lerpf(-STRIP_SPREAD, STRIP_SPREAD, (s + rng.randf_range(-0.3, 0.3)) / (STRIPS - 1))
		var k := posmod(int(round((th + PI) / TAU * 72.0)), 72)
		var r: float = radii[k] if radii[k] > 0.05 else 0.22
		var inner := s % 2 == 1
		if inner:
			r -= 0.012
		var out := Vector3(sin(th), 0.0, cos(th))
		# Cada tira un poco girada (no todas paralelas, como una cortina) y arrancando debajo del
		# borde del manto, que la tapa.
		var side := Vector3(cos(th), 0.0, -sin(th)).rotated(Vector3.UP, rng.randf_range(-0.35, 0.35))
		var normal := side.cross(Vector3.DOWN).normalized()
		if normal.dot(out) < 0.0:
			normal = -normal
		var top := Vector3(out.x * (r - 0.015), HEM_Y + rng.randf_range(0.07, 0.13), out.z * (r - 0.015))
		# Más cortas hacia los costados de adelante; las de adentro, un poco más largas.
		var length := rng.randf_range(0.95, 1.25) * (1.0 - 0.25 * absf(th) / STRIP_SPREAD) * (1.08 if inner else 1.0)
		var width := rng.randf_range(0.11, 0.16)
		var flare := rng.randf_range(0.06, 0.14)
		var seed := rng.randf()
		# Curva de reposo: un poco abombada hacia afuera y desviada de costado, distinta en cada tira.
		var bulge := rng.randf_range(0.015, 0.045)
		var sway := rng.randf_range(-0.04, 0.04)
		var base := verts.size()
		for row in STRIP_ROWS + 1:
			var t := float(row) / STRIP_ROWS
			var center := top + Vector3(0, -length * t, 0) + out * flare * t * length 					+ normal * bulge * sin(PI * t) + side * sway * t * t
			var w := width * (1.0 - 0.35 * t) * 0.5
			# Peso entre los dos huesos de la cadena entre los que está.
			var f := minf(t * STRIP_BONES, STRIP_BONES - 1.0)
			var b0 := mini(floori(f), STRIP_BONES - 1)
			var b1 := mini(b0 + 1, STRIP_BONES - 1)
			var fb := f - b0 if b1 != b0 else 0.0
			for col in 3:
				verts.append(center + side * float(col - 1) * w + normal * (0.006 if col == 1 else 0.0))
				normals.append(normal)
				uvs.append(Vector2(col * 0.5, t))
				uv2s.append(Vector2(seed, 0))
				bones.append_array([1 + s * STRIP_BONES + b0, 1 + s * STRIP_BONES + b1, 0, 0])
				weights.append_array([1.0 - fb, fb, 0.0, 0.0])
		for row in STRIP_ROWS:
			for col in 2:
				var a := base + row * 3 + col
				index.append_array([a, a + 3, a + 1, a + 1, a + 3, a + 4])
		var joints := []
		for b in STRIP_BONES:
			var t := float(b) / STRIP_BONES
			joints.append(top + Vector3(0, -length * t, 0) + out * flare * t * length
					+ normal * bulge * sin(PI * t) + side * sway * t * t)
		_strip_joints.append({"joints": joints, "tail": length / STRIP_BONES})
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = index
	return arrays


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


## Capa con manto y tiras sueltas para modelos con esqueleto. suit: color del traje, o null para
## dejar la tela con su color original. Agrega sus huesos a `skel` colgando de `torso`, con el
## cuello de la capa en el hueso `neck`. colliders: [[hueso, hueso, radio], ...] del cuerpo.
func build_model(suit: Variant, skel: Skeleton3D, torso: int, neck: int, colliders: Array) -> void:
	var mesh := _baked_model()
	_model_mat = ShaderMaterial.new()
	_model_mat.shader = preload("res://shaders/mistcloak.gdshader")
	_model_mat.set_shader_parameter("albedo_tex", load(MODEL_TEX % "diffuse"))
	_model_mat.set_shader_parameter("normal_tex", load(MODEL_TEX % "normal"))
	_model_mat.set_shader_parameter("rough_tex", load(MODEL_TEX % "roughness"))
	_strip_mat = ShaderMaterial.new()
	_strip_mat.shader = preload("res://shaders/mistcloak_strips.gdshader")
	set_suit_color(suit)

	# De la malla al espacio del esqueleto (los modelos miran hacia +Z dentro de su esqueleto).
	var fit := Transform3D(Basis(Vector3.UP, PI) * Basis.from_scale(MODEL_SCALE), skel.get_bone_global_rest(neck).origin)
	var skin := Skin.new()
	skin.add_bind(torso, skel.get_bone_global_rest(torso).affine_inverse() * fit)
	var chains := []
	for s in STRIPS:
		var parent := torso
		var chain := []
		for k in STRIP_BONES:
			var bone_name := "cloak_%d_%d" % [s, k]
			var b := skel.find_bone(bone_name)
			if b < 0:  # los huesos quedan en el esqueleto si la capa se vuelve a armar
				skel.add_bone(bone_name)
				b = skel.find_bone(bone_name)
				skel.set_bone_parent(b, parent)
			var global := Transform3D(Basis(), fit * (_strip_joints[s]["joints"][k] as Vector3))
			skel.set_bone_rest(b, skel.get_bone_global_rest(parent).affine_inverse() * global)
			skel.reset_bone_pose(b)
			skin.add_bind(b, global.affine_inverse() * fit)
			chain.append(b)
			parent = b
		chains.append(chain)

	_model_mi = MeshInstance3D.new()
	_model_mi.mesh = mesh
	_model_mi.skin = skin
	_model_mi.set_surface_override_material(0, _model_mat)
	_model_mi.set_surface_override_material(1, _strip_mat)
	_model_mi.extra_cull_margin = 1.5
	skel.add_child(_model_mi)
	_model_mi.skeleton = _model_mi.get_path_to(skel)

	_sim = SpringBoneSimulator3D.new()
	skel.add_child(_sim)
	_sim.set_setting_count(STRIPS)
	for s in STRIPS:
		_sim.set_root_bone(s, chains[s][0])
		_sim.set_end_bone(s, chains[s][-1])
		_sim.set_extend_end_bone(s, true)
		_sim.set_end_bone_length(s, _strip_joints[s]["tail"] * MODEL_SCALE.y)
		_sim.set_radius(s, 0.025)
		_sim.set_stiffness(s, 0.45)
		_sim.set_drag(s, 0.3)
		_sim.set_gravity(s, 1.4)
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
	_strip_mat.set_shader_parameter("base_color", (suit as Color).darkened(0.55) if suit != null else Color(0.1, 0.105, 0.12))


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
	if _sim:
		# Las tiras las mueve el SpringBoneSimulator3D: el aire (viento con ráfagas menos la
		# velocidad del cuerpo) las empuja, y cada una aletea con su propio ritmo.
		var gust := 0.7 + 0.3 * sin(_t * 1.3) * sin(_t * 0.37 + 1.0)
		var air := wind * gust - vel
		_sim.external_force = air * AIR_PUSH
		var amp := 0.06 + air.length() * 0.035
		for s in STRIPS:
			var f := sin(_t * (5.0 + s * 0.53) + s * 2.1) * amp
			_sim.set_gravity_direction(s, Vector3(f, -1.0, f * 0.6).normalized())
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
