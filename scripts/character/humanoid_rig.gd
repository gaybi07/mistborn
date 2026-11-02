class_name HumanoidRig
extends Node3D
## Humanoide hecho con primitivas y animado por código: reposo, caminar, correr, salto/caída,
## brazo que apunta al empujar/tirar, lanzar, pánico, tambaleo y guardia con lanza.
## El dueño (Player o Npc) rellena las variables de estado cada frame.
## Para cambiarlo por un modelo con esqueleto (Mixamo, etc.) basta con sustituir este nodo.

## Aspecto. Claves opcionales: skin, hair, hair_style ("short"/"long"/"bald"), shirt, pants, boots,
## coat (Color o null), hat ("none"/"cap"/"tophat"/"hood"/"helmet"), armor, cloak, cloak_color,
## spear, daggers, sword, vials (frascos en el cinturón), bracers (Color), height (escala), build (anchura).
var look: Dictionary = {}
## El jugador anima en tiempo real (inmune al atium); la gente, en tiempo del mundo.
var use_real_time := false

var move_speed := 0.0
var vertical_speed := 0.0
var on_floor := true
var body_velocity := Vector3.ZERO
## Vector3 global al que apunta el brazo derecho (o el izquierdo), o null.
var aim_target: Variant = null
var aim_target_left: Variant = null
var panic := 0.0
var slouch := 0.0
var stagger := 0.0
## Con la guardia arriba (ver Player: bloqueo y parry).
var blocking := false
## Congelado del golpe (hit stop, en tiempo real): mientras dure, la pose se queda quieta.
var hitstop := 0.0
var _flash_mat: StandardMaterial3D
var _flash_tween: Tween
var brace := 0.0
## Colgado de un borde (las manos van a aim_target y aim_target_left).
var hanging := false
## Nadando en el río / resbalando por una pendiente de más de 45° (solo los ModelRig los animan).
var swimming := false
var sliding := false

var hips: Node3D
var spine: Node3D
var chest: Node3D
var neck: Node3D
var arms: Array[Node3D] = []
var elbows: Array[Node3D] = []
var legs: Array[Node3D] = []
var knees: Array[Node3D] = []
var hands: Array[Node3D] = []
var cloak: Mistcloak

enum Weapon { NONE, DAGGERS, SWORD }

const HIPS_HEIGHT := 0.95
const ROLL_PIVOT := Vector3(0, 0.5, 0)

static var _materials := {}
static var _meshes := {}

var weapon := Weapon.NONE
## Si lleva las dagas encima (inventario). Sin ellas no se ven envainadas.
var daggers_owned := true

var _vial_parts: Array[Node3D] = []

var _phase := 0.0
var _t := 0.0
var _air := 0.0
var _throw := 0.0
var _attack := 0.0
var _attack_len := 0.35
var _attack_side := 1
var _roll := 0.0
var _roll_len := 0.5
var _scale := 1.0
## Weapon -> {"sheathed": [Node3D], "held": [Node3D]}
var _weapon_nodes := {}


func _ready() -> void:
	_build()


func play_throw() -> void:
	_throw = 0.3


## Gesto de alomancia con monedas ("coin_wave", "coin_shield"). El cuerpo procedural no lo anima.
func play_spell(_state: String, _duration: float) -> void:
	pass


## Abre los dos brazos hacia los costados durante `duration` s (ver ModelRig). El cuerpo procedural no lo hace.
func open_arms(_duration: float, _lift := 0.0, _bend := 0.0) -> void:
	pass


## Gesto de un poder (ver ModelRig): el cuerpo procedural hace el de lanzar. Devuelve cuánto dura.
func play_skill(_state: String, _duration: float) -> float:
	play_throw()
	return _throw


## Recoger algo del suelo (bolsa, objeto, frasco). El cuerpo procedural no lo anima.
func play_pickup() -> void:
	pass


## Tajo con el brazo derecho (side = 1) o izquierdo (side = 0). step: golpe del combo (0, 1, 2).
## Devuelve cuánto dura de verdad (la animación puede pedir más que `duration`).
func play_attack(side: int, duration: float, _step := 0) -> float:
	_attack_side = side
	_attack_len = duration
	_attack = duration
	return duration


func play_roll(duration := 0.5) -> void:
	_roll_len = duration
	_roll = duration


## Impulso al saltar, aterrizaje (strength 0..1 según la caída), dash en el aire y golpe aéreo.
## El cuerpo procedural no tiene animaciones para ellos (salvo el golpe); ModelRig sí.
func play_jump() -> void:
	pass


func play_land(_strength := 1.0) -> void:
	pass


func play_dash(_duration := 0.45) -> void:
	pass


func play_air_attack(duration: float) -> float:
	return play_attack(1, duration)


## Subir a un borde desde colgado (ver `hanging`).
## Devuelve cuánto dura la subida (la animación puede pedir más tiempo que `duration`).
func play_climb(duration := 0.65) -> float:
	return duration


## Reacción a un golpe que viene de `from` (punto del mundo). heavy: golpe fuerte; stun: aturdido
## (parry, crítico). El cuerpo procedural solo se tambalea.
func play_hit(_from: Vector3, _heavy: bool, _stun := false) -> void:
	stagger = 1.0


## Un golpe choca contra la guardia.
func block_impact() -> void:
	pass


func is_rolling() -> bool:
	return _roll > 0.0


## Desenvaina el arma elegida (o envaina todo con Weapon.NONE).
func set_weapon(w: Weapon) -> void:
	weapon = w
	for key in _weapon_nodes:
		for n in _weapon_nodes[key]["held"]:
			n.visible = key == w
		for n in _weapon_nodes[key]["sheathed"]:
			n.visible = key != w and (key != Weapon.DAGGERS or daggers_owned)


## Equipo visible del inventario. outfit: traje oscuro de nacido de la bruma.
## Color del traje y la capucha (ver Art.SUITS). El cuerpo hecho de primitivas no lo usa.
func set_suit(_suit: String) -> void:
	pass


func set_equipment(_outfit: bool, cloak_on: bool, vials_on: bool, daggers_on: bool) -> void:
	if cloak:
		cloak.visible = cloak_on
	for v in _vial_parts:
		v.visible = vials_on
	daggers_owned = daggers_on
	set_weapon(weapon)


func _build() -> void:
	var skin: Color = look.get("skin", Color(0.86, 0.7, 0.58))
	var hair: Color = look.get("hair", Color(0.12, 0.09, 0.07))
	var shirt: Color = look.get("shirt", Color(0.3, 0.28, 0.25))
	var pants: Color = look.get("pants", Color(0.2, 0.19, 0.18))
	var boots: Color = look.get("boots", Color(0.12, 0.09, 0.07))
	var coat: Variant = look.get("coat")
	var armor: bool = look.get("armor", false)
	var w: float = look.get("build", 1.0)
	_scale = float(look.get("height", 0.95))
	scale = Vector3.ONE * _scale
	var top: Color = coat if coat != null else shirt
	var metal := _mat(Color(0.5, 0.52, 0.56), 0.9, 0.35)
	var dark := _mat(Color(0.07, 0.06, 0.05))

	hips = _pivot(self, Vector3(0, HIPS_HEIGHT, 0))
	_part(hips, _sphere(0.17), Vector3(0, 0.02, 0), _mat(pants), Vector3(1.1 * w, 0.75, 0.8))
	_part(hips, _cylinder(0.165, 0.165, 0.06), Vector3(0, 0.08, 0), dark, Vector3(w, 1, 0.8))
	if coat != null:
		_part(hips, _cylinder(0.19, 0.29, 0.62), Vector3(0, -0.24, 0), _mat(coat), Vector3(w, 1, 0.85))

	spine = _pivot(hips, Vector3(0, 0.06, 0))
	_part(spine, _capsule(0.15, 0.36), Vector3(0, 0.14, 0), _mat(top), Vector3(w * 1.05, 1, 0.78))
	chest = _pivot(spine, Vector3(0, 0.24, 0))
	_part(chest, _capsule(0.19, 0.46), Vector3(0, 0.16, 0), _mat(top), Vector3(w * 1.12, 1, 0.74))
	if armor:
		_part(chest, _capsule(0.2, 0.44), Vector3(0, 0.17, -0.01), metal, Vector3(w * 1.2, 1, 0.82))

	neck = _pivot(chest, Vector3(0, 0.4, 0))
	_part(neck, _cylinder(0.05, 0.055, 0.12), Vector3(0, 0.04, 0), _mat(skin))
	var head := Vector3(0, 0.15, 0)
	_part(neck, _sphere(0.115), head, _mat(skin), Vector3(0.9, 1.08, 1.0))
	for s in [-1.0, 1.0]:
		_part(neck, _sphere(0.016), head + Vector3(s * 0.04, 0.015, -0.098), dark)
	_part(neck, _box(Vector3(0.025, 0.04, 0.04)), head + Vector3(0, -0.01, -0.112), _mat(skin))
	_build_hair_and_hat(head, hair, shirt, coat, metal)

	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var sh := _pivot(chest, Vector3(side * 0.22 * w, 0.33, 0))
		_part(sh, _capsule(0.058, 0.34), Vector3(0, -0.14, 0), _mat(top))
		if armor:
			_part(sh, _sphere(0.085), Vector3(side * 0.01, 0, 0), metal, Vector3(1.1, 0.75, 1.1))
		var el := _pivot(sh, Vector3(0, -0.29, 0))
		_part(el, _capsule(0.05, 0.31), Vector3(0, -0.13, 0), _mat(top))
		_part(el, _sphere(0.05), Vector3(0, -0.29, 0), _mat(skin), Vector3(0.8, 1.15, 0.6))
		if look.has("bracers"):
			_part(el, _cylinder(0.058, 0.054, 0.13), Vector3(0, -0.2, 0), _mat(look["bracers"], 0.0, 0.6))
		# Mano: las armas sujetas son perpendiculares al antebrazo (apuntan hacia delante con el codo doblado).
		var hand := _pivot(el, Vector3(0, -0.3, 0))
		hand.rotation.x = -PI / 2
		hands.append(hand)
		if i == 1 and look.get("spear", false):
			# La lanza es perpendicular al antebrazo: vertical con el codo doblado, horizontal con el brazo recto.
			var grip := _pivot(el, Vector3(0, -0.29, 0))
			grip.rotation.x = -PI / 2
			_part(grip, _cylinder(0.018, 0.018, 2.0), Vector3(0, 0.4, 0), _mat(Color(0.3, 0.2, 0.12)))
			_part(grip, _cylinder(0.0, 0.035, 0.22), Vector3(0, 1.51, 0), metal)
		arms.append(sh)
		elbows.append(el)

	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var hp := _pivot(hips, Vector3(side * 0.095 * w, -0.03, 0))
		_part(hp, _capsule(0.078, 0.5), Vector3(0, -0.2, 0), _mat(pants))
		var kn := _pivot(hp, Vector3(0, -0.44, 0))
		_part(kn, _capsule(0.062, 0.36), Vector3(0, -0.14, 0), _mat(pants))
		_part(kn, _capsule(0.068, 0.24), Vector3(0, -0.33, 0), _mat(boots))
		_part(kn, _box(Vector3(0.1, 0.07, 0.23)), Vector3(0, -0.445, -0.05), _mat(boots))
		legs.append(hp)
		knees.append(kn)

	if look.get("vials", false):
		_build_vial_belt(w)
	_build_weapons(w)

	if look.get("cloak", false):
		cloak = Mistcloak.new()
		chest.add_child(cloak)
		cloak.build(look.get("cloak_color", Color(0.2, 0.21, 0.24)), w, neck)


## Frascos de metales colgando del cinturón (brillan un poco).
func _build_vial_belt(w: float) -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.5, 0.75, 1.0)
	glass.emission_enabled = true
	glass.emission = Color(0.4, 0.65, 1.0)
	glass.emission_energy_multiplier = 1.2
	glass.roughness = 0.1
	for x in [-0.14, -0.09, 0.12]:
		_vial_parts.append(_part(hips, _cylinder(0.018, 0.018, 0.07), Vector3(x * w, 0.02, -0.13), glass))
		_vial_parts.append(_part(hips, _cylinder(0.012, 0.012, 0.015), Vector3(x * w, 0.065, -0.13), _mat(Color(0.35, 0.25, 0.15))))
	_part(hips, _box(Vector3(0.09, 0.08, 0.05)), Vector3(0.16 * w, -0.02, 0.06), _mat(Color(0.2, 0.15, 0.1)))  # bolsa de monedas


func _build_weapons(w: float) -> void:
	var leather := _mat(Color(0.12, 0.09, 0.07), 0.0, 0.7)
	if look.get("daggers", false):
		var held: Array[Node3D] = []
		var sheathed: Array[Node3D] = []
		for i in 2:
			var d := _dagger()
			hands[i].add_child(d)
			held.append(d)
			# Envainadas cruzadas en la parte baja de la espalda.
			var sheath := _pivot(hips, Vector3((0.07 if i == 0 else -0.07) * w, 0.02, 0.17))
			sheath.rotation.z = -1.99 if i == 0 else 1.99
			sheath.add_child(_dagger())
			_part(sheath, _box(Vector3(0.045, 0.2, 0.022)), Vector3(0, 0.12, 0), leather)
			sheathed.append(sheath)
		_weapon_nodes[Weapon.DAGGERS] = {"held": held, "sheathed": sheathed}
	if look.get("sword", false):
		var held_sword := _sword()
		hands[1].add_child(held_sword)
		# Envainada en la cadera izquierda, con la punta hacia atrás.
		var sheath := _pivot(hips, Vector3(-0.2 * w, 0.0, 0.05))
		sheath.rotation.x = PI - 0.3
		sheath.add_child(_sword())
		_part(sheath, _box(Vector3(0.065, 0.86, 0.035)), Vector3(0, 0.53, 0), leather)
		_weapon_nodes[Weapon.SWORD] = {"held": [held_sword], "sheathed": [sheath]}
	set_weapon(Weapon.NONE)


## Daga de obsidiana: no es metal, así que ningún alomántico puede empujarla.
## Dagas y espada modeladas en Blender (tools/blender/make_weapons.py): agarre en el origen, hoja hacia +Y.
func _dagger() -> Node3D:
	return (load("res://assets/weapons/dagger_crystal.glb") as PackedScene).instantiate()


func _sword() -> Node3D:
	return (load("res://assets/weapons/sword_steel.glb") as PackedScene).instantiate()


func _build_hair_and_hat(head: Vector3, hair: Color, shirt: Color, coat: Variant, metal: Material) -> void:
	var style: String = look.get("hair_style", "short")
	var hat: String = look.get("hat", "none")
	if style != "bald" and hat != "helmet":
		_part(neck, _sphere(0.122), head + Vector3(0, 0.035, 0.035), _mat(hair), Vector3(0.95, 0.85, 1.0))
		if style == "long":
			_part(neck, _capsule(0.09, 0.3), head + Vector3(0, -0.08, 0.08), _mat(hair), Vector3(1.2, 1, 0.6))
	match hat:
		"cap":
			var c := _mat(shirt.darkened(0.35))
			_part(neck, _cylinder(0.125, 0.125, 0.07), head + Vector3(0, 0.1, 0.01), c)
			_part(neck, _cylinder(0.15, 0.15, 0.015), head + Vector3(0, 0.075, -0.03), c)
		"tophat":
			var c := _mat(Color(0.05, 0.05, 0.06), 0.0, 0.5)
			_part(neck, _cylinder(0.1, 0.1, 0.22), head + Vector3(0, 0.2, 0.01), c)
			_part(neck, _cylinder(0.16, 0.16, 0.015), head + Vector3(0, 0.095, 0.01), c)
		"hood":
			var hood_color: Color = coat if coat != null else shirt.darkened(0.2)
			_part(neck, _sphere(0.135), head + Vector3(0, 0.02, 0.04), _mat(hood_color), Vector3(1.02, 1.05, 1.0))
		"helmet":
			_part(neck, _hemisphere(0.13), head + Vector3(0, 0.02, 0.005), metal)
			_part(neck, _cylinder(0.14, 0.14, 0.02), head + Vector3(0, 0.025, 0.005), metal)


## Congela un instante a los que chocan en un golpe: 50 ms, hasta 120 ms con mucho daño.
static func hit_stop(rigs: Array, damage: float) -> void:
	var t := clampf(0.05 + damage / 400.0, 0.05, 0.12)
	for r in rigs:
		if r is HumanoidRig:
			r.hitstop = maxf(r.hitstop, t)


## Destello de color sobre todo el cuerpo al recibir un golpe (se va en 0,2 s).
func flash(color := Color(1.0, 0.3, 0.25)) -> void:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if _flash_tween:
		_flash_tween.kill()
	var meshes := find_children("*", "MeshInstance3D", true, false)
	for mi: MeshInstance3D in meshes:
		mi.material_overlay = _flash_mat
	_flash_mat.albedo_color = Color(color, 0.8)
	_flash_tween = create_tween().set_ignore_time_scale(true)
	_flash_tween.tween_property(_flash_mat, "albedo_color:a", 0.0, 0.2).set_ease(Tween.EASE_OUT)
	# Sin el overlay puesto no cuesta una pasada más de dibujo.
	_flash_tween.tween_callback(func() -> void:
		for mi: MeshInstance3D in meshes:
			if is_instance_valid(mi):
				mi.material_overlay = null)


func _process(delta: float) -> void:
	if hitstop > 0.0:
		hitstop -= delta / Engine.time_scale
		return
	var dt := minf(delta / Engine.time_scale if use_real_time else delta, 0.05)
	_t += dt
	_throw -= dt
	_attack -= dt
	_roll -= dt
	var rolling := _roll > 0.0
	# Voltereta: postura recogida (se mezcla con todo lo demás).
	var tuck := sin(PI * clampf(1.0 - _roll / _roll_len, 0.0, 1.0)) if rolling else 0.0
	var k := 1.0 - exp(-dt * 18.0)

	var speed := move_speed
	var stride := clampf(speed / 2.5, 0.0, 1.0)
	var run := clampf((speed - 2.5) / 5.0, 0.0, 1.0)
	if stride > 0.02:
		_phase = fmod(_phase + dt * (2.5 + 2.4 * sqrt(speed)), TAU)
	_air = move_toward(_air, 0.0 if on_floor else 1.0, dt * 5.0)
	var falling := clampf(-vertical_speed / 10.0, 0.0, 1.0)
	var sw := sin(_phase)
	var cw := cos(_phase)

	var leg_amp := 0.55 * stride + 0.35 * run
	var knee_amp := 0.5 * stride + 0.9 * run
	var arm_amp := 0.25 * stride + 0.55 * run
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var ph := sw * side
		# Piernas: la rodilla se dobla mientras la pierna avanza.
		var thigh := ph * leg_amp
		var knee := -(maxf(0.0, cw * side) * knee_amp + 0.05)
		thigh = lerpf(thigh, (0.9 if i == 0 else 0.15) - falling * 0.5, _air)
		knee = lerpf(knee, (-1.4 if i == 0 else -0.6) + falling * 0.6, _air)
		thigh = lerpf(thigh, 1.8, tuck)
		knee = lerpf(knee, -2.3, tuck)
		_rot(legs[i], Vector3(thigh, 0, side * 0.04 * (1.0 + _air)), k)
		_rot(knees[i], Vector3(knee, 0, 0), k)

		# Brazos: balanceo opuesto a las piernas; abiertos en el aire; arriba con pánico.
		var arm_x := -ph * arm_amp
		var arm_z := side * (0.08 + 0.05 * run)
		var elbow := 0.2 + 1.0 * run * stride
		arm_x = lerpf(arm_x, -0.2 + falling * 0.5, _air)
		arm_z = lerpf(arm_z, side * (0.9 + falling * 0.6), _air)
		elbow = lerpf(elbow, 0.4, _air)
		arm_x = lerpf(arm_x, 2.4 + sin(_t * 14.0 + i) * 0.2, panic)
		arm_z = lerpf(arm_z, side * 0.3, panic)
		elbow = lerpf(elbow, 1.1, panic)
		arm_z += side * stagger * 0.8
		arm_x -= stagger * 0.5
		if i == 1 and look.get("spear", false):
			arm_x = lerpf(arm_x * 0.3, 0.35, brace)
			elbow = lerpf(1.4, 0.05, brace)
		if i == 1 and _throw > 0.0:
			arm_x = 1.6
			elbow = 0.1
		# Arma desenvainada: guardia con el codo doblado (la hoja apunta hacia delante y arriba).
		if weapon == Weapon.SWORD and i == 1 or weapon == Weapon.DAGGERS:
			arm_x = arm_x * 0.4 + 0.3
			elbow = maxf(elbow, 1.0)
		arm_x = lerpf(arm_x, 1.0, tuck)
		elbow = lerpf(elbow, 1.6, tuck)
		var target := Quaternion.from_euler(Vector3(arm_x, 0, arm_z))
		var aim: Variant = aim_target if i == 1 else aim_target_left
		if aim != null:
			target = _aim_quat(arms[i], aim)
			elbow = 0.05
		if _attack > 0.0 and i == _attack_side:
			# Tajo: preparación arriba y fuera, barrido cruzando por delante del cuerpo.
			var swing := smoothstep(0.2, 0.65, 1.0 - _attack / _attack_len)
			target = Quaternion.from_euler(Vector3(lerpf(2.3, 0.5, swing), 0, side * lerpf(0.9, -0.6, swing)))
			elbow = lerpf(1.3, 0.15, swing)
		arms[i].quaternion = arms[i].quaternion.slerp(target, k)
		_rot(elbows[i], Vector3(elbow, 0, 0), k)

	var lean := -(0.06 * stride + 0.22 * run) - slouch * 0.35
	lean = lerpf(lean, -0.15 + falling * 0.25, _air) + stagger * 0.5
	lean = lerpf(lean, -0.7, tuck)
	var twist := sw * 0.1 * stride
	if _attack > 0.0:
		var side_sign := 1.0 if _attack_side == 1 else -1.0
		twist += side_sign * lerpf(-0.35, 0.45, smoothstep(0.2, 0.65, 1.0 - _attack / _attack_len))
	_rot(spine, Vector3(lean, twist, 0), k)
	_rot(neck, Vector3(-lean * 0.6 + slouch * 0.15, -sw * 0.08 * stride, 0), k)
	hips.position.y = HIPS_HEIGHT + (absf(cw) - 0.5) * 0.05 * stride - 0.04 * run
	chest.scale = Vector3.ONE * (1.0 + sin(_t * 1.8) * 0.012)

	# Giro completo de la voltereta alrededor de la cintura.
	if rolling:
		var spin := Basis(Vector3.RIGHT, -TAU * smoothstep(0.0, 1.0, 1.0 - _roll / _roll_len)).scaled(Vector3.ONE * _scale)
		transform = Transform3D(spin, ROLL_PIVOT * _scale - spin * ROLL_PIVOT)
	elif _roll > -0.2:  # recién terminada: deja el cuerpo derecho
		transform = Transform3D(Basis.from_scale(Vector3.ONE * _scale), Vector3.ZERO)

	if cloak:
		cloak.drive(dt, body_velocity)


func _rot(node: Node3D, euler: Vector3, k: float) -> void:
	node.quaternion = node.quaternion.slerp(Quaternion.from_euler(euler), k)


## Rotación del hombro para que el brazo (que cuelga en -Y) apunte al punto global.
func _aim_quat(shoulder: Node3D, point: Vector3) -> Quaternion:
	var parent := shoulder.get_parent() as Node3D
	var d := point - shoulder.global_position
	if d.length() < 0.01:
		return shoulder.quaternion
	var local := (parent.global_basis.inverse() * d).normalized()
	if local.dot(Vector3.DOWN) < -0.999:
		local = (local + Vector3(0.02, 0, 0)).normalized()
	return Quaternion(Vector3.DOWN, local)


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


# Materiales y mallas compartidos entre todos los personajes (menos memoria, mejor batching).
static func _mat(color: Color, metallic := 0.0, rough := 0.85) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [color.to_html(), metallic, rough]
	if not _materials.has(key):
		_materials[key] = Props.material(color, metallic, rough)
	return _materials[key]


static func _capsule(r: float, h: float) -> Mesh:
	var key := "cap%s_%s" % [r, h]
	if not _meshes.has(key):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = maxf(h, 2.0 * r)
		m.radial_segments = 16
		m.rings = 6
		_meshes[key] = m
	return _meshes[key]


static func _sphere(r: float) -> Mesh:
	var key := "sph%s" % r
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = 2.0 * r
		m.radial_segments = 16
		m.rings = 8
		_meshes[key] = m
	return _meshes[key]


static func _hemisphere(r: float) -> Mesh:
	var key := "hem%s" % r
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r
		m.is_hemisphere = true
		m.radial_segments = 16
		m.rings = 6
		_meshes[key] = m
	return _meshes[key]


static func _cylinder(top: float, bottom: float, h: float) -> Mesh:
	var key := "cyl%s_%s_%s" % [top, bottom, h]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = 16
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


static func _box(size: Vector3) -> Mesh:
	var key := "box%s" % size
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]
