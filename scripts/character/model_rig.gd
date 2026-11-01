class_name ModelRig
extends HumanoidRig
## Personaje con modelo 3D importado y sus animaciones (KayKit, Quaternius...), con la misma
## interfaz que HumanoidRig: el Player y los Npc le pasan velocidad, suelo, ataques, voltereta, etc.
## y aquí se elige qué animación reproducir.
##
## - Las animaciones se buscan por "estado" con varias alternativas; se usa la primera que exista.
## - Si el modelo no la tiene pero hay un pack "donante" (retarget_from), se reproduce en un
##   esqueleto invisible de ese pack y se copia la pose (BoneTools.Retargeter).
## - Encima de la animación se aplican las poses de alomancia: brazo derecho empujando con acero,
##   izquierdo tirando con hierro, más intensas y temblorosas al avivar.

## Estado -> nombres posibles de animación, en orden de preferencia (Quaternius antes que KayKit
## cuando ambos tienen una equivalente, así cada pack usa las suyas).
const ANIMS := {
	"idle": ["idle", "Idle", "Unarmed_Idle"],
	"idle_armed": ["sword_idle", "idle", "Attacking_Idle", "Idle_Attacking", "2H_Melee_Idle", "Idle_Weapon", "Idle"],
	"walk": ["walk", "Walk", "Walking_A"],
	"run": ["sprint", "Run", "Running_A"],
	"sprint": ["sprint", "Run", "Running_A"],
	"flee": ["Run", "Running_B", "Running_A"],
	"air": ["jump", "Jump_Idle", "Idle_Attacking", "Idle"],
	"jump": ["jump_start", "Jump_Start", "Jump_Full_Short"],
	"land": ["jump_land", "Jump_Land", "Idle"],
	"roll": ["roll", "Roll", "Dodge_Forward"],
	"dash": ["sword_dash", "Dodge_Forward", "Roll"],
	# Colgado de un borde y subiendo. Si agregás animaciones propias (p. ej. de Mixamo), poné su
	# nombre primero; mientras tanto se usa la pose de salto con las manos llevadas al borde.
	"hang": ["Hanging_Idle", "Hang_Idle", "Jump_Idle"],
	"climb": ["Climbing", "Climb_Up", "Jump_Start", "jump_start"],
	# Saltar desde un borde hacia abajo (Mixamo "Jumping Down"): todavía no la usa ningún estado.
	"attack_air": ["2H_Melee_Attack_Spinning", "Dualwield_Melee_Attack_Slice", "Dagger_Attack2", "Punch", "sword_attack"],
	# Combos: golpe 1, 2... y remate (attack_X, attack_X_1, attack_X_2, attack_X_3).
	"attack_fist": ["Punch", "Unarmed_Melee_Attack_Punch_A", "sword_regular_a"],
	"attack_fist_1": ["Unarmed_Melee_Attack_Punch_A", "Punch", "sword_regular_b"],
	"attack_fist_2": ["Unarmed_Melee_Attack_Kick", "Punch", "sword_regular_c"],
	# Dagas: puñalada, tajo cruzado con las dos, revés y tajo doble descendente (remate).
	"attack_daggers": ["sword_regular_a", "Dagger_Attack", "Dualwield_Melee_Attack_Slice", "1H_Melee_Attack_Stab", "Dagger_Attack2", "Punch"],
	"attack_daggers_1": ["sword_regular_b", "Dualwield_Melee_Attack_Slice", "Dagger_Attack2", "Dagger_Attack"],
	"attack_daggers_2": ["sword_attack", "Dagger_Attack2", "Dualwield_Melee_Attack_Stab", "Dagger_Attack"],
	"attack_daggers_3": ["sword_regular_c", "Dualwield_Melee_Attack_Chop", "1H_Melee_Attack_Stab", "Dagger_Attack"],
	"attack_sword": ["sword_regular_a", "Sword_Attack", "1H_Melee_Attack_Slice_Diagonal", "Dagger_Attack", "Punch"],
	"attack_sword_1": ["sword_regular_b", "Sword_Attack2", "1H_Melee_Attack_Slice_Horizontal", "Sword_Attack", "Dagger_Attack"],
	"attack_sword_2": ["sword_regular_c", "1H_Melee_Attack_Chop", "2H_Melee_Attack_Chop", "Sword_Attack", "Dagger_Attack"],
	"throw": ["spell_simple_enter", "Throw", "Punch"],
	"pickup": ["pickup_table", "PickUp", "Interact"],
	"swim": ["swim_fwd"],
	"swim_idle": ["swim_idle", "swim_fwd"],
	"slide": ["slide", "Jump_Idle"],
	"allomancy": ["spell_simple_idle", "Attacking_Idle", "Idle_Attacking", "Spellcasting", "Idle"],
	"hit": ["hit_chest", "RecieveHit", "Hit_A"],
	"down": ["death01", "Death", "Death_A"],
	# Alomancia con monedas (Mixamo, ver extra_donors): onda de monedas hacia afuera y escudo.
	"coin_wave": ["coin_wave"],
	"coin_shield": ["coin_shield"],
	# Más de Mixamo (MixamoSpells.glb), todavía sin estado que las use: se llaman con play_spell().
	"steel_push": ["steel_push"],
	"iron_pull": ["iron_pull"],
	"coin_flick": ["coin_flick"],
	"burn_focus": ["burn_focus"],
	"pewter_flex": ["pewter_flex"],
	"block": ["block"],
	"dodge_left": ["dodge_left"],
	"dodge_right": ["dodge_right"],
	"hit_front": ["hit_front"],
	"hit_back": ["hit_back"],
	"hit_left": ["hit_left"],
	"hit_right": ["hit_right"],
	"get_up": ["get_up"],
	"crouch_idle": ["crouch_idle"],
	"crouch_walk": ["crouch_walk"],
	"climb_wall": ["climb_wall"],
	"vault": ["vault"],
	"fall_roll": ["fall_roll"],
	"freefall": ["freefall"],
	"drink": ["drink"],
	"open_door": ["open_door"],
	"sit": ["sit"],
	# Trabajo de los skaa (SkaaWorker): arrodillado arreglando algo y los de Mixamo.
	"kneel_work": ["fixing_kneeling"],
	"box_idle": ["box_idle"],
	"carry_walk": ["carry_walk"],
	"dig": ["dig"],
	"push_heavy": ["push_heavy"],
	"pull_heavy": ["pull_heavy"],
	"lift_heavy": ["lift_heavy"],
	"put_down": ["put_down"],
	"pick_up": ["pick_up"],
	"kneel_pull": ["kneel_pull"],
	"kneel_inspect": ["kneel_inspect"],
	"sad_idle": ["sad_idle"],
	"sad_walk": ["sad_walk"],
	"warm_hands": ["warm_hands"],
}
## Animaciones que se repiten (el resto se queda en su último fotograma al terminar).
const LOOPING := ["idle", "idle_armed", "walk", "run", "sprint", "flee", "air", "allomancy", "hang",
		"swim", "swim_idle", "slide", "burn_focus", "crouch_idle", "crouch_walk", "freefall", "sit", "box_idle",
		"carry_walk", "dig", "push_heavy", "pull_heavy", "kneel_inspect", "sad_idle", "sad_walk", "warm_hands"]
## Velocidad (m/s) a la que cada animación de desplazamiento "pisa" bien.
const STRIDE_SPEED := {"walk": 1.6, "run": 5.0, "sprint": 5.0, "flee": 5.0, "swim": 2.0}
## Lo mismo por nombre de animación, para las que se apartan del valor de su estado (ActionForge).
const ANIM_STRIDE := {"walk": 0.92, "sprint": 7.7, "sad_walk": 0.72, "carry_walk": 1.1, "crouch_walk": 1.57}
## Por encima de esta velocidad (peltre) se esprinta.
const SPRINT_SPEED := 8.0
## Partes de las mallas que son armas o accesorios (se ocultan salvo las que use el personaje).
const ITEM_WORDS := ["Knife", "Dagger", "Guard", "Sword", "Shield", "Crossbow", "Throwable", "Staff", "Wand",
		"Spellbook", "Bow", "Arrow", "Axe", "Mug"]
## Huesos para las poses de alomancia (nombres de Quaternius, KayKit y Mixamo).
const BONES := {
	"torso": ["Torso", "chest", "Spine2", "spine_03"],
	"upper_r": ["UpperArm.R", "upperarm.r", "RightArm", "upperarm_r"],
	"lower_r": ["LowerArm.R", "lowerarm.r", "RightForeArm", "lowerarm_r"],
	"upper_l": ["UpperArm.L", "upperarm.l", "LeftArm", "upperarm_l"],
	"lower_l": ["LowerArm.L", "lowerarm.l", "LeftForeArm", "lowerarm_l"],
	"head": ["Head", "head"],
	"neck": ["Neck", "neck_01", "head"],
	"hips": ["Hips", "hips", "pelvis"],
	"hand_r": ["hand_r", "RightHand", "hand.r", "Hand.R"],
	"hand_l": ["hand_l", "LeftHand", "hand.l", "Hand.L"],
	"thigh_r": ["UpperLeg.R", "upperleg.r", "RightUpLeg", "thigh_r"],
	"calf_r": ["LowerLeg.R", "lowerleg.r", "RightLeg", "calf_r"],
	"foot_r": ["Foot.R", "foot.r", "RightFoot", "foot_r"],
	"thigh_l": ["UpperLeg.L", "upperleg.l", "LeftUpLeg", "thigh_l"],
	"calf_l": ["LowerLeg.L", "lowerleg.l", "LeftLeg", "calf_l"],
	"foot_l": ["Foot.L", "foot.l", "LeftFoot", "foot_l"],
}
## Cápsulas del cuerpo contra las que choca la capa: [hueso, hueso, radio para 1,7 m de alto].
## Radios con margen por la ropa gruesa del modelo.
const CLOAK_COLLIDERS := [["hips", "torso", 0.17], ["torso", "neck", 0.15],
		["upper_r", "lower_r", 0.09], ["lower_r", "hand_r", 0.08],
		["upper_l", "lower_l", 0.09], ["lower_l", "hand_l", 0.08],
		["thigh_r", "calf_r", 0.13], ["calf_r", "foot_r", 0.11],
		["thigh_l", "calf_l", 0.13], ["calf_l", "foot_l", 0.11]]
## Tono del traje oscuro de nacido de la bruma (inventario).
const OUTFIT_TINT := Color(0.5, 0.52, 0.62)
## Traje de color (Art.SUITS): la textura del modelo es casi negra, así que en vez de multiplicarla
## se toma su brillo (pliegues, costuras, cuero) y se pinta con el color elegido.
const SUIT_SHADER := """
shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 suit : source_color;
uniform vec3 mul : source_color = vec3(1.0);
void fragment() {
	vec3 c = texture(tex, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	ALBEDO = suit * mul * clamp(0.42 + l * 3.0, 0.0, 1.15);
	ROUGHNESS = 0.78;
}
"""
static var _suit_shader: Shader
## IK de pies: estados sin los pies en el suelo (no se corrigen) y de desplazamiento (el pie apoyado
## no se clava: el personaje avanza y la animación va en el lugar).
const IK_OFF := ["air", "jump", "hang", "climb", "swim", "swim_idle", "slide", "down", "roll", "dash",
		"attack_air", "freefall", "fall_roll", "climb_wall", "vault"]
const IK_MOVING := ["walk", "run", "sprint", "flee", "carry_walk", "sad_walk", "crouch_walk"]
## Clips que se desplazan de verdad (esquives, golpes que te empujan; ver actionforge_to_glb.py): traen
## el avance en el hueso root. Se saca del esqueleto y se mueve al personaje lo mismo (ver
## _take_root_motion): en el lugar los pies patinarían más de un metro.
const ROOT_MOTION := ["dodge_left", "dodge_right", "hit_front", "hit_back", "hit_left", "hit_right"]
## Cuánto sube o baja como mucho un pie para buscar el suelo (m).
const FOOT_REACH := 0.4
## Del tobillo a la punta del pie (m), para buscar el suelo también ahí.
const FOOT_TOE := 0.12
## Si la animación deja los dos pies en el aire menos que esto (m), se los apoya (ver _update_foot_ik).
const GROUND_FLOAT := 0.15
## Lo más que se separa un pie clavado de donde lo pone la animación antes de soltarlo (m).
const FOOT_LOCK_SLACK := 0.25
## Lo más que se acelera un golpe o una voltereta para que quepa en su tiempo.
const MAX_ONESHOT_SPEED := 2.4

var model_path := ""
var target_height := 1.7
## Gira el modelo 180° (para los que miran hacia +Z; aquí "delante" es -Z).
var flip := true
## Palabras de ITEM_WORDS que se muestran siempre (p. ej. espada y escudo del guardia).
var always_items: Array = []
## Multiplica el color de todos los materiales (para encajar en la paleta apagada de la ciudad).
var tint := Color(1, 1, 1)
## Noqueado / muerto: reproduce la animación de caída y se queda en el suelo.
var down := false
## Modelo cuyo AnimationPlayer presta animaciones que este no tiene (o "").
var retarget_from := ""
var retarget_map: Array = []
## Otros packs que prestan animaciones (después de retarget_from): [ruta, mapeo de huesos].
var extra_donors: Array = []
## Estado -> candidatos que reemplazan a los de ANIMS para este personaje (p. ej. el skaa camina triste).
var anim_overrides := {}
## Fuerza de las poses de alomancia: 1 quemando, 2 avivando (las pone el Player).
var push_power := 1.0
var pull_power := 1.0

var _model: Node3D
var _skel: Skeleton3D
var _ap: AnimationPlayer
var _src_model: Node3D
var _src_ap: AnimationPlayer
var _retargeter: BoneTools.Retargeter
var _donor_specs: Array = []  # [ruta, mapeo]: retarget_from y extra_donors
var _donors := {}  # índice -> {"model", "ap", "rt"} (se arman la primera vez que hacen falta)
var _spell := 0.0
var _spell_state := ""
var _resolved := {}  # estado -> {"name": String, "borrowed": bool}
var _state := ""
var _borrowed := false
var _items := {}  # MeshInstance3D -> palabra de ITEM_WORDS
var _bones := {}  # clave de BONES -> índice
var _air_since := 0.0
var _push_blend := 0.0
var _pull_blend := 0.0
var _oneshot_speed := 1.0
var _jump := 0.0
var _land := 0.0
var _dash := 0.0
var _climb := 0.0
var _pickup := 0.0
## Animación más espaciada lejos de la cámara (salvo el jugador, use_real_time): el tiempo que no se
## anima se junta y se aplica en el siguiente cuadro que sí.
var _pending_dt := 0.0
var _frame := 0
const NEAR_ANIM := 20.0
const FAR_ANIM := 60.0
## Capa de bruma y frascos del inventario: siguen a los huesos del cuello y la cadera.
var _cloak_anchor: Node3D
var _vial_anchor: Node3D
var _suit := "negro"
var _outfit := false
## Pies apoyados en el suelo real (pendientes, escalones) sin hundirse ni patinar; ver _update_foot_ik.
var foot_ik := true
var _ik: TwoBoneIK3D
var _ik_targets: Array[Node3D] = []
var _ik_poles: Array[Node3D] = []
var _ik_lock: Array = [null, null]  # punto (Vector3) donde quedó clavado cada pie, o null
## Corrección de cada pie respecto de la animación, suavizada: al pasar un escalón o soltar un pie
## clavado entra y sale de a poco en vez de saltar de un cuadro al otro.
var _ik_corr: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _ik_unlocking: Array[bool] = [false, false]  # recién soltado: no se vuelve a clavar hasta llegar
var _float_by := 0.0  # cuánto flota la animación (suavizado: es parejo, no cambia de un cuadro al otro)
var _ankle := 0.0  # altura del tobillo en reposo, en metros del personaje
var _hips_drop := 0.0  # cuánto se baja el cuerpo para que llegue el pie que pisa más abajo
var _model_y := 0.0
var _near := true
var _root_bone := -1
var _root_prev: Variant = null  # dónde estaba el root del clip el cuadro anterior (Vector3), o null


func _build() -> void:
	_model = _instance(model_path)
	_ap = _first(_model, "AnimationPlayer")
	_skel = _first(_model, "Skeleton3D")
	_prepare_meshes()
	_fit_height(_model, true)
	if flip:
		_model.rotation.y = PI
	if _skel:
		for key in BONES:
			_bones[key] = BoneTools.find_bone(_skel, BONES[key])
		_root_bone = _skel.find_bone("root")
		if _items.is_empty():
			_attach_weapons()
	_resolve_animations()
	if not use_real_time:
		for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
			mi.visibility_range_end = Art.DRAW_FAR
	set_weapon(weapon)
	_setup_foot_ik()
	_play("idle", 0.0)


func _setup_foot_ik() -> void:
	if _skel == null:
		return
	for side in ["_l", "_r"]:
		# Pierna encadenada muslo -> pantorrilla -> pie (en algunos packs el pie cuelga de la raíz).
		var thigh: int = _bones.get("thigh" + side, -1)
		var calf: int = _bones.get("calf" + side, -1)
		var foot: int = _bones.get("foot" + side, -1)
		if thigh < 0 or calf < 0 or foot < 0 or _skel.get_bone_parent(calf) != thigh or _skel.get_bone_parent(foot) != calf:
			return
	_ik = TwoBoneIK3D.new()
	_skel.add_child(_ik)
	_ik.setting_count = 2
	for i in 2:
		var side: String = ["_l", "_r"][i]
		var target := Node3D.new()
		var pole := Node3D.new()
		add_child(target)
		add_child(pole)
		_ik_targets.append(target)
		_ik_poles.append(pole)
		_ik.set_root_bone(i, _bones["thigh" + side])
		_ik.set_middle_bone(i, _bones["calf" + side])
		_ik.set_end_bone(i, _bones["foot" + side])
		_ik.set_target_node(i, _ik.get_path_to(target))
		_ik.set_pole_node(i, _ik.get_path_to(pole))
	_ik.influence = 0.0
	_model_y = _model.position.y
	var to_rig := global_transform.affine_inverse() * _skel.global_transform
	_ankle = (to_rig * _skel.get_bone_global_rest(_bones["foot_l"]).origin).y


func _instance(path: String) -> Node3D:
	var node: Node3D = (load(path) as PackedScene).instantiate()
	add_child(node)
	var ap: AnimationPlayer = _first(node, "AnimationPlayer")
	if ap:
		# Las avanzamos a mano para aplicar después el retarget y las poses de alomancia.
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return node


func _first(node: Node, type: String) -> Node:
	var found := node.find_children("*", type, true, false)
	return found[0] if not found.is_empty() else null


func _resolve_animations() -> void:
	_donor_specs = []
	if retarget_from != "":
		_donor_specs.append([retarget_from, retarget_map])
	_donor_specs += extra_donors
	var lists := []  # qué animaciones tiene cada donante
	for spec: Array in _donor_specs:
		var root: Node = (load(spec[0]) as PackedScene).instantiate()
		var ap := _first(root, "AnimationPlayer") as AnimationPlayer
		lists.append(ap.get_animation_list() if ap else PackedStringArray())
		root.free()
	for state in ANIMS:
		_resolved[state] = {"name": "", "borrowed": false, "donor": -1}
		for candidate in anim_overrides.get(state, ANIMS[state]):
			if _ap and _ap.has_animation(candidate):
				_resolved[state] = {"name": candidate, "borrowed": false, "donor": -1}
				break
			var found := -1
			for i in lists.size():
				if candidate in lists[i]:
					found = i
					break
			if found >= 0:
				_resolved[state] = {"name": candidate, "borrowed": true, "donor": found}
				break


## Deja listo el donante i (esqueleto invisible que reproduce sus animaciones) como el activo.
func _ensure_donor(i := 0) -> void:
	if _skel == null or i < 0 or i >= _donor_specs.size():
		return
	if not _donors.has(i):
		var model := _instance(_donor_specs[i][0])
		model.visible = false
		_fit_height(model, false)
		model.rotation.y = _model.rotation.y
		_donors[i] = {"model": model, "ap": _first(model, "AnimationPlayer"),
				"rt": BoneTools.Retargeter.new(_first(model, "Skeleton3D"), _skel, _donor_specs[i][1])}
	_src_model = _donors[i]["model"]
	_src_ap = _donors[i]["ap"]
	_retargeter = _donors[i]["rt"]


func _prepare_meshes() -> void:
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		for word in ITEM_WORDS:
			if word in String(mi.name):
				_items[mi] = word
				break
		if tint != Color(1, 1, 1):
			for i in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(i) as BaseMaterial3D
				if mat:
					mat = mat.duplicate()
					mat.albedo_color = mat.albedo_color * tint
					mi.set_surface_override_material(i, mat)


## Escala el modelo para que mida target_height y apoya los pies en y = 0.
## Se mide relativo al propio modelo (no al mundo): si no, la altura a la que aparece el
## personaje se restaba y quedaba hundido en el suelo.
func _fit_height(node: Node3D, skip_items: bool) -> void:
	var to_local := node.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if skip_items and _items.has(mi):
			continue
		var b: AABB = (to_local * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first or box.size.y <= 0.0:
		return
	var s := target_height / box.size.y
	node.scale = Vector3.ONE * s
	node.position.y = -box.position.y * s


## Modelos sin armas en la malla (p. ej. ActionForge): las dagas de obsidiana y la espada de
## HumanoidRig, enganchadas a las manos.
func _attach_weapons() -> void:
	var r := _grip(_bones["hand_r"])
	var l := _grip(_bones["hand_l"])
	if r == null or l == null:
		return
	var sword := _sword()
	r.add_child(sword)
	var daggers: Array[Node3D] = [_dagger(), _dagger()]
	r.add_child(daggers[0])
	l.add_child(daggers[1])
	_weapon_nodes[Weapon.DAGGERS] = {"held": daggers, "sheathed": []}
	_weapon_nodes[Weapon.SWORD] = {"held": [sword], "sheathed": []}


## Punto de agarre en la palma, con +Y (la hoja) hacia delante del cuerpo en la pose de reposo
## (pose T: del lado del pulgar).
func _grip(bone: int) -> Node3D:
	if bone < 0:
		return null
	var attach := BoneAttachment3D.new()
	_skel.add_child(attach)
	attach.bone_idx = bone
	var rest_inv := _skel.get_bone_global_rest(bone).basis.orthonormalized().inverse()
	var blade := (rest_inv * Vector3.BACK).normalized()  # +Z del modelo = delante
	var palm := (rest_inv * Vector3.DOWN).normalized()
	var grip := Node3D.new()
	attach.add_child(grip)
	var side := blade.cross(palm).normalized()
	grip.basis = Basis(side, blade, side.cross(blade))
	grip.position = Vector3.UP * 0.08 + palm * 0.03  # hacia los dedos y hacia la palma
	return grip


func set_weapon(w: Weapon) -> void:
	super(w)
	for mi in _items:
		var word: String = _items[mi]
		var shown := word in always_items
		if w == Weapon.DAGGERS and word in ["Knife", "Dagger", "Guard"]:
			shown = true
		elif w == Weapon.SWORD and word in ["Sword", "Knife", "Dagger", "Guard"]:
			shown = true  # si el modelo no trae espada, usa su daga
		mi.visible = shown


func set_suit(s: String) -> void:
	if s == _suit or not Art.SUITS.has(s):
		return
	_suit = s
	_apply_tint(OUTFIT_TINT if _outfit else tint)
	if cloak and _skel:
		cloak.set_suit_color(_cloak_suit())
	elif _cloak_anchor:
		# Las tiras se arman con su color: se rehacen con el nuevo.
		var shown := _cloak_anchor.visible
		_cloak_anchor.queue_free()
		_cloak_anchor = null
		cloak = null
		_add_cloak()
		_cloak_anchor.visible = shown
		_update_anchors()


func set_equipment(outfit: bool, cloak_on: bool, vials_on: bool, daggers_on: bool) -> void:
	_outfit = outfit
	_apply_tint(OUTFIT_TINT if outfit else tint)
	if cloak_on and _cloak_anchor == null:
		_add_cloak()
	if _cloak_anchor:
		_cloak_anchor.visible = cloak_on
	if vials_on and _vial_anchor == null:
		_vial_anchor = _make_vials()
	if _vial_anchor:
		_vial_anchor.visible = vials_on
	daggers_owned = daggers_on
	set_weapon(weapon)
	_update_anchors()


## Capa de bruma de tela desgarrada con huesos y física, que choca con el cuerpo. Sin esqueleto,
## las tiras de siempre.
func _add_cloak() -> void:
	_cloak_anchor = Node3D.new()
	add_child(_cloak_anchor)
	cloak = Mistcloak.new()
	_cloak_anchor.add_child(cloak)
	if _skel == null or _bones["torso"] < 0 or _bones["neck"] < 0:
		var c: Color = Art.SUITS[_suit]
		cloak.build(c if _suit == "negro" else c.darkened(0.2), 1.15, null, true)
		return
	var s := clampf(_skel.get_bone_global_rest(_bones["neck"]).origin.y / 1.45, 0.4, 1.2)
	var colliders := []
	for c in CLOAK_COLLIDERS:
		if _bones[c[0]] >= 0 and _bones[c[1]] >= 0:
			colliders.append([_bones[c[0]], _bones[c[1]], c[2] * s])
	cloak.build_model(_cloak_suit(), _skel, _bones["torso"], _bones["neck"], colliders)


## Con trajes de color la capa se tiñe como el traje; con el negro queda con su textura.
func _cloak_suit() -> Variant:
	return null if _suit == "negro" else Art.SUITS[_suit].darkened(0.2)


## Recolorea la ropa del modelo (no las armas) multiplicando su color original, o con el color
## del traje si no es el negro del modelo.
func _apply_tint(c: Color) -> void:
	if _suit_shader == null:
		_suit_shader = Shader.new()
		_suit_shader.code = SUIT_SHADER
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if _items.has(mi):
			continue
		for i in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if base == null:
				continue
			if _suit != "negro" and base.albedo_texture:
				var sm := ShaderMaterial.new()
				sm.shader = _suit_shader
				sm.set_shader_parameter("tex", base.albedo_texture)
				sm.set_shader_parameter("suit", Art.SUITS[_suit])
				sm.set_shader_parameter("mul", tint)  # sin oscurecer con el traje del inventario: que se te reconozca
				mi.set_surface_override_material(i, sm)
			else:
				var m: BaseMaterial3D = base.duplicate()
				m.albedo_color = base.albedo_color * c
				mi.set_surface_override_material(i, m)


func _make_vials() -> Node3D:
	var anchor := Node3D.new()
	add_child(anchor)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.5, 0.75, 1.0)
	glass.emission_enabled = true
	glass.emission = Color(0.4, 0.65, 1.0)
	glass.emission_energy_multiplier = 1.2
	glass.roughness = 0.1
	var cork := HumanoidRig._mat(Color(0.35, 0.25, 0.15))
	for x in [-0.13, -0.07, 0.11]:
		_part(anchor, HumanoidRig._cylinder(0.022, 0.022, 0.09), Vector3(x, 0.0, 0.0), glass)
		_part(anchor, HumanoidRig._cylinder(0.015, 0.015, 0.02), Vector3(x, 0.055, 0.0), cork)
	_part(anchor, HumanoidRig._cylinder(0.17, 0.17, 0.04), Vector3(0, 0.05, 0.12), HumanoidRig._mat(Color(0.2, 0.15, 0.1)))  # cinturón
	return anchor


## Coloca la capa en los hombros y los frascos delante de la cadera, según la pose actual.
func _update_anchors() -> void:
	if _skel == null:
		return
	var to_rig := global_transform.affine_inverse()
	var neck := to_rig * BoneTools.bone_world_pos(_skel, _bones["neck"])
	var s := clampf(neck.y / 1.45, 0.4, 1.2)
	if _cloak_anchor:
		# La capa se diseñó para un pecho cuyo cuello queda 0,4 m más arriba.
		_cloak_anchor.scale = Vector3.ONE * s
		_cloak_anchor.position = neck + Vector3(0, -0.4 * s, 0.06 * s)
	if _vial_anchor:
		var hips := to_rig * BoneTools.bone_world_pos(_skel, _bones["hips"])
		_vial_anchor.scale = Vector3.ONE * s
		_vial_anchor.position = hips + Vector3(0, 0.02, -0.2 * s)


func play_attack(side: int, duration: float, step := 0) -> void:
	super(side, duration, step)
	var state := "attack_fist"
	if weapon == Weapon.DAGGERS:
		state = "attack_daggers"
	elif weapon == Weapon.SWORD:
		state = "attack_sword"
	if step > 0 and _resolved.get("%s_%d" % [state, step], {"name": ""})["name"] != "":
		state = "%s_%d" % [state, step]
	_attack = _play_once(state, duration)


func play_roll(duration := 0.5) -> void:
	super(duration)
	_roll = _play_once("roll", duration)


func play_throw() -> void:
	super()
	_throw = _play_once("throw", 0.55)


## Gesto de alomancia con monedas (coin_wave, coin_shield) de unos `duration` segundos.
func play_spell(state: String, duration: float) -> void:
	_spell_state = state
	_spell = _play_once(state, duration)


## Solo parado o caminando: a la carrera la animación entera se vería deslizándose.
func play_pickup() -> void:
	if move_speed < 3.0 and _attack <= 0.0 and _roll <= 0.0:
		_pickup = _play_once("pickup", 0.9)


func play_jump() -> void:
	if _attack > 0.0 or _roll > 0.0:
		return
	_land = 0.0
	_jump = _play_once("jump", 0.35)


## Aterrizaje: si vienes corriendo se corta solo (ver _choose_state).
func play_land(strength := 1.0) -> void:
	if _attack > 0.0 or _roll > 0.0 or _dash > 0.0:
		return
	_jump = 0.0
	_land = _play_once("land", lerpf(0.28, 0.5, strength))


func play_dash(duration := 0.45) -> void:
	_jump = 0.0
	_dash = _play_once("dash", duration)


func play_climb(duration := 0.65) -> float:
	_jump = 0.0
	_land = 0.0
	_climb = _play_once("climb", duration)
	return _climb


func play_air_attack(duration: float) -> void:
	_attack_len = duration
	_jump = 0.0
	_dash = 0.0
	_attack = _play_once("attack_air", duration)


## Reproduce entera una animación de una vez (golpe, voltereta...), acelerada para que quepa en
## `duration` (sin pasar de MAX_ONESHOT_SPEED). Devuelve cuánto dura así, para no cortarla.
func _play_once(state: String, duration: float) -> float:
	_play(state, 0.05, true)
	var length := _current_length()
	if length <= 0.0:
		_oneshot_speed = 1.0
		return duration
	_oneshot_speed = clampf(length / duration, 1.0, MAX_ONESHOT_SPEED)
	return length / _oneshot_speed


func _current_length() -> float:
	var player := _src_ap if _borrowed else _ap
	if player == null or player.current_animation == "":
		return 0.0
	return player.get_animation(player.current_animation).length


func _process(delta: float) -> void:
	if hitstop > 0.0:
		hitstop -= delta / Engine.time_scale
		return
	_near = true
	if not use_real_time:
		var cam := get_viewport().get_camera_3d()
		var every := 1
		if cam:
			var d := cam.global_position.distance_to(global_position)
			every = 1 if d < NEAR_ANIM else (3 if d < FAR_ANIM else 8)
		_near = every == 1
		_frame += 1
		if _frame % every != 0:
			_pending_dt += delta
			return
		delta += _pending_dt
		_pending_dt = 0.0
	var dt := minf(delta / Engine.time_scale if use_real_time else delta, 0.25 if not use_real_time else 0.05)
	_t += dt
	_attack -= dt
	_roll -= dt
	_throw -= dt
	_jump -= dt
	_land -= dt
	_dash -= dt
	_climb -= dt
	_pickup -= dt
	_spell -= dt
	if _ap == null and retarget_from == "":
		return
	var state := _choose_state()
	if state != _state:
		# Entrar y salir del aire con una mezcla más larga: el salto se ve más suave.
		_play(state, 0.25 if state in ["air", "land"] or _state in ["air", "jump", "dash"] else 0.15)
	var speed := 1.0
	if STRIDE_SPEED.has(state):
		var stride: float = ANIM_STRIDE.get(_resolved[state]["name"], STRIDE_SPEED[state])
		speed = clampf(move_speed / stride, 0.6, 2.2)
	elif state in ["roll", "throw", "jump", "land", "dash", "climb", "pickup"] or state.begins_with("attack"):
		speed = _oneshot_speed
	if _borrowed and _src_ap:
		_src_ap.advance(dt * speed)
		_retargeter.apply()
	elif _ap:
		_ap.advance(dt * speed)
	_take_root_motion()
	_apply_allomancy_pose(dt)
	_update_foot_ik(dt, state)
	_update_anchors()
	if cloak and _cloak_anchor.visible:
		cloak.drive(dt, body_velocity)


func _choose_state() -> String:
	if down:
		return "down"
	if hanging:
		return "hang"
	if swimming:
		return "swim" if move_speed > 0.6 else "swim_idle"
	if sliding:
		return "slide"
	if _climb > 0.0:
		return "climb"
	if _roll > 0.0:
		return "roll"
	if _dash > 0.0:
		return "dash"
	if _spell > 0.0:
		return _spell_state
	if _attack > 0.0:
		return _state if _state.begins_with("attack") else "attack_fist"
	if _throw > 0.0:
		return "throw"
	if _pickup > 0.0:
		return "pickup"
	if stagger > 0.6:
		return "hit"
	if _jump > 0.0:
		return "jump"
	if not on_floor and _air_time() > 0.15:
		return "air"
	if _land > 0.0 and on_floor and move_speed < 3.0 and aim_target == null and aim_target_left == null:
		return "land"
	if aim_target != null or aim_target_left != null:
		return "allomancy" if move_speed < 3.0 else "run"
	if panic > 0.5 and move_speed > 0.5:
		return "flee"
	if move_speed > SPRINT_SPEED:
		return "sprint"
	if move_speed > 3.2:
		return "run"
	if move_speed > 0.3:
		return "walk"
	return "idle_armed" if weapon != Weapon.NONE or brace > 0.5 else "idle"


func _air_time() -> float:
	if on_floor:
		_air_since = _t
	return _t - _air_since


func _play(state: String, blend: float, restart := false) -> void:
	_state = state
	# Sin animaciones propias (modelo recién rigueado) todo sale del donante.
	if _ap == null and retarget_from == "":
		return
	var info: Dictionary = _resolved.get(state, {"name": "", "borrowed": false})
	if info["name"] == "":
		info = _resolved.get("idle", info)
	if info["name"] == "":
		return
	_borrowed = info["borrowed"]
	var player := _ap
	if _borrowed:
		_ensure_donor(info.get("donor", 0))
		player = _src_ap
		if player == null:
			_borrowed = false
			return
	var anim: String = info["name"]
	var looping: bool = state in LOOPING
	player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	if restart or player.current_animation != anim:
		player.play(anim, blend)
		if restart:
			player.seek(0.0, true)
		_root_prev = null


## Clip de ROOT_MOTION: el avance del root en este cuadro pasa del esqueleto al personaje (el
## CharacterBody3D de arriba, que choca con las paredes; si no hay, el rig mismo).
func _take_root_motion() -> void:
	if _root_bone < 0 or _borrowed:
		return
	var now := _skel.get_bone_pose_position(_root_bone)
	# Siempre en reposo: al mezclar el final de un esquive con la siguiente, el root trae su avance.
	_skel.set_bone_pose_position(_root_bone, _skel.get_bone_rest(_root_bone).origin)
	if not _resolved.get(_state, {}).get("name", "") in ROOT_MOTION:
		_root_prev = null
		return
	if _root_prev != null:
		var step: Vector3 = _skel.global_basis * (now - _root_prev)
		step.y = 0.0
		var body := get_parent()
		while body and not body is CharacterBody3D:
			body = body.get_parent()
		if body:
			(body as CharacterBody3D).move_and_collide(step)
		else:
			global_position += step
	_root_prev = now


# ---------------------------------------------------------------- IK de pies

## Las animaciones suponen suelo plano a la altura del personaje. Cada pie busca el suelo real debajo
## (rayo contra el mundo) y se apoya ahí conservando lo que la animación lo levanta; el cuerpo baja lo
## que haga falta para que llegue el pie que pisa más abajo. Parado, trabajando o peleando, el pie
## apoyado se queda clavado donde pisó (no patina). El TwoBoneIK3D dobla la pierna después de la
## animación, en la actualización del esqueleto.
func _update_foot_ik(dt: float, state: String) -> void:
	if _ik == null:
		return
	var want := foot_ik and _near and on_floor and not state in IK_OFF and is_inside_tree()
	_ik.influence = move_toward(_ik.influence, 1.0 if want else 0.0, dt * 6.0)
	if _ik.influence <= 0.0:
		_ik_lock = [null, null]
		_ik_corr = [Vector3.ZERO, Vector3.ZERO]
		_ik_unlocking = [false, false]
		_float_by = 0.0
		_hips_drop = move_toward(_hips_drop, 0.0, dt)
		_model.position.y = _model_y + _hips_drop / maxf(scale.y, 1e-4)
		return
	var space := get_world_3d().direct_space_state
	var ground := global_position.y  # el suelo de la animación
	var fwd := -global_basis.z.normalized()
	var drop := 0.0
	var goals: Array[Vector3] = []
	var anim_feet: Array[Vector3] = []
	for side in ["_l", "_r"]:
		anim_feet.append(BoneTools.bone_world_pos(_skel, _bones["foot" + side]) - Vector3(0, _hips_drop, 0))
	# Animaciones que dejan al personaje flotando (los dos pies arriba, p. ej. el reposo del Mistborn
	# a 10 cm): se apoya el pie más bajo. Más de GROUND_FLOAT ya es un salto a propósito.
	var float_target := 0.0
	if not state in IK_MOVING:
		var low := minf(anim_feet[0].y, anim_feet[1].y) - ground - _ankle
		if low > 0.04 and low < GROUND_FLOAT:
			float_target = low
	_float_by = lerpf(_float_by, float_target, minf(dt * (8.0 if state in IK_MOVING else 3.0), 1.0))
	var float_by := _float_by
	for i in 2:
		var side: String = ["_l", "_r"][i]
		var foot := anim_feet[i]
		var lift := maxf(foot.y - ground - _ankle - float_by, 0.0)  # nunca por debajo del suelo
		# Suelo bajo el talón y bajo la punta: en el borde de un escalón manda el más alto (si no, la
		# punta se mete en el escalón).
		# Cuenta como escalón si la punta está más alta de lo que da la pendiente bajo el talón.
		var floor_y := ground
		var heel := _floor_hit(space, foot, ground)
		if heel:
			floor_y = heel["position"].y
			var n: Vector3 = heel["normal"]
			var d := fwd * FOOT_TOE
			var slope_rise := -(n.x * d.x + n.z * d.z) / maxf(n.y, 0.2)
			var toe := _floor_hit(space, foot + d, ground)
			if toe and toe["position"].y > floor_y + slope_rise + 0.03:
				floor_y = toe["position"].y
		var goal := Vector3(foot.x, floor_y + _ankle + lift, foot.z)
		var shown := foot + _ik_corr[i]  # donde se ve el pie ahora
		if not state in IK_MOVING and lift < 0.03 and not _ik_unlocking[i]:
			if _ik_lock[i] == null:
				_ik_lock[i] = shown  # se clava donde está, sin saltar
			elif Vector2(_ik_lock[i].x - goal.x, _ik_lock[i].z - goal.z).length() > FOOT_LOCK_SLACK:
				# La animación se alejó demasiado: se suelta y el pie vuelve de a poco a donde va.
				_ik_lock[i] = null
				_ik_unlocking[i] = true
			if _ik_lock[i] != null:
				goal = Vector3(_ik_lock[i].x, goal.y, _ik_lock[i].z)
		else:
			_ik_lock[i] = null
		if _ik_unlocking[i] and Vector2(_ik_corr[i].x, _ik_corr[i].z).length() < 0.02:
			_ik_unlocking[i] = false
		# La corrección se acomoda en ~0,1 s (al soltar un pie clavado o bajar de un escalón), salvo
		# subir el pie, que es inmediato (si no, se metería en el escalón), y el pie clavado, que
		# queda fijo.
		var need := goal - foot
		var c: Vector3 = _ik_corr[i].lerp(need, minf(dt * 14.0, 1.0))
		if _ik_lock[i] != null:
			c.x = need.x
			c.z = need.z
		c.y = maxf(c.y, need.y)
		_ik_corr[i] = c
		goal = foot + c
		drop = minf(drop, goal.y - foot.y)
		goals.append(goal)
		var knee := BoneTools.bone_world_pos(_skel, _bones["calf" + side])
		_ik_poles[i].global_position = knee + fwd * 0.5
	_hips_drop = lerpf(_hips_drop, maxf(drop, -FOOT_REACH), minf(dt * 12.0, 1.0))
	_model.position.y = _model_y + _hips_drop / maxf(scale.y, 1e-4)
	for i in 2:
		_ik_targets[i].global_position = goals[i]


func _floor_hit(space: PhysicsDirectSpaceState3D, at: Vector3, ground: float) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, ground + FOOT_REACH, at.z),
			Vector3(at.x, ground - FOOT_REACH, at.z), Props.LAYER_WORLD))


# ---------------------------------------------------------------- Poses de alomancia

## Acero: brazo derecho recto hacia el metal y el cuerpo afirmado hacia atrás.
## Hierro: brazo izquierdo hacia el metal, tirando a tirones con el codo, inclinado hacia atrás.
## Avivar (power 2): más inclinación, tirones más rápidos y temblor.
func _apply_allomancy_pose(dt: float) -> void:
	if _skel == null:
		return
	if hanging and (aim_target == null or aim_target_left == null):
		return
	_push_blend = move_toward(_push_blend, 1.0 if aim_target != null else 0.0, dt * 8.0)
	_pull_blend = move_toward(_pull_blend, 1.0 if aim_target_left != null else 0.0, dt * 8.0)
	if _push_blend <= 0.0 and _pull_blend <= 0.0:
		return
	var body_basis := global_basis.orthonormalized()
	var push := _push_blend * push_power
	var pull := _pull_blend * pull_power
	var tug := 0.5 + 0.5 * sin(_t * (6.0 + 6.0 * (pull_power - 1.0)))
	# Inclinación del torso hacia atrás (afirmarse contra la fuerza).
	var lean := 0.12 * push + (0.15 + 0.12 * tug) * pull
	if hanging:
		# Colgado: los dos brazos estirados al borde, sin tirones ni inclinación.
		_aim_arm("r", aim_target, 1.0, 0.1)
		_aim_arm("l", aim_target_left, 1.0, 0.1)
		return
	var torso: int = _bones["torso"]
	if torso >= 0:
		var lean_dir := body_basis * (Basis(Vector3.RIGHT, lean) * Vector3.UP)
		BoneTools.aim(_skel, torso, lean_dir, 0.8)
	if aim_target != null:
		_aim_arm("r", aim_target, push, 0.0)
	if aim_target_left != null:
		_aim_arm("l", aim_target_left, pull, tug * (0.35 + 0.15 * pull_power))
	var head: int = _bones["head"]
	var look: Variant = aim_target if aim_target != null else aim_target_left
	if head >= 0 and look != null:
		var to: Vector3 = (look as Vector3) - BoneTools.bone_world_pos(_skel, head)
		BoneTools.aim(_skel, head, (body_basis * Vector3.UP).slerp(to.normalized(), 0.25), 0.6)


## bend: cuánto se dobla el codo hacia el pecho (0 = brazo recto).
func _aim_arm(side: String, target: Vector3, power: float, bend: float) -> void:
	var upper: int = _bones["upper_" + side]
	var lower: int = _bones["lower_" + side]
	if upper < 0 or lower < 0:
		return
	var shoulder := BoneTools.bone_world_pos(_skel, upper)
	var dir := (target - shoulder).normalized()
	if power > 1.2:
		# Temblor del esfuerzo al avivar.
		var n := Vector3(sin(_t * 41.0), sin(_t * 37.0 + 1.3), sin(_t * 43.0 + 2.1)) * 0.035 * (power - 1.0)
		dir = (dir + n).normalized()
	var weight := clampf(power, 0.0, 1.0)
	BoneTools.aim(_skel, upper, dir, weight)
	var elbow := BoneTools.bone_world_pos(_skel, lower)
	var chest := global_position + global_basis.orthonormalized() * Vector3(0, target_height * 0.65, 0)
	var forearm := dir.slerp((chest - elbow).normalized(), clampf(bend, 0.0, 0.9))
	BoneTools.aim(_skel, lower, forearm, weight)
