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
	"flee": ["Run", "Running_B", "Running_A", "sprint"],
	"air": ["jump", "Jump_Idle", "Idle_Attacking", "Idle"],
	"jump": ["jump_start", "Jump_Start", "Jump_Full_Short"],
	"land": ["jump_land", "Jump_Land", "Idle"],
	"roll": ["roll", "Roll", "Dodge_Forward"],
	"dash": ["sword_dash", "Dodge_Forward", "Roll"],
	# Colgado de un borde y subiendo. Si agregás animaciones propias (p. ej. de Mixamo), poné su
	# nombre primero; mientras tanto se usa la pose de salto con las manos llevadas al borde.
	"hang": ["Hanging_Idle", "Hang_Idle", "Jump_Idle"],
	"climb": ["climb_wall", "Climbing", "Climb_Up", "Jump_Start", "jump_start"],
	# Saltar desde un borde hacia abajo (Mixamo "Jumping Down"): todavía no la usa ningún estado.
	# El salto con tajo del 3er golpe de la espada; ModelRig le suma un giro rápido del cuerpo.
	"attack_air": ["sword_regular_c", "2H_Melee_Attack_Spinning", "Dualwield_Melee_Attack_Slice", "Dagger_Attack2", "Punch", "sword_attack"],
	# Combos: golpe 1, 2... y remate (attack_X, attack_X_1, attack_X_2, attack_X_3).
	# Los de Mixamo (MixamoCombat.glb) primero; los demás, para los personajes que no los tienen.
	"attack_fist": ["fist_jab", "Unarmed_Melee_Attack_Punch_A", "sword_regular_a"],
	"attack_fist_1": ["fist_cross", "Unarmed_Melee_Attack_Punch_B", "sword_regular_b"],
	"attack_fist_2": ["fist_uppercut", "Unarmed_Melee_Attack_Punch_A", "sword_regular_c"],
	"attack_fist_3": ["fist_roundhouse", "Unarmed_Melee_Attack_Kick", "sword_attack"],
	# Dagas: puñalada con una mano, con la otra, tajo cruzado y puñalada doble (remate).
	"attack_daggers": ["dagger_lead", "1H_Melee_Attack_Stab", "sword_regular_a"],
	"attack_daggers_1": ["dagger_rear", "Dualwield_Melee_Attack_Stab", "sword_regular_b"],
	"attack_daggers_2": ["fist_hook", "Dualwield_Melee_Attack_Slice", "sword_attack"],
	"attack_daggers_3": ["dagger_double", "Dualwield_Melee_Attack_Chop", "sword_regular_c"],
	"attack_sword": ["sword_regular_a", "Sword_Attack", "1H_Melee_Attack_Slice_Diagonal", "Dagger_Attack", "Punch"],
	"attack_sword_1": ["sword_regular_b", "Sword_Attack2", "1H_Melee_Attack_Slice_Horizontal", "Sword_Attack", "Dagger_Attack"],
	"attack_sword_2": ["sword_regular_c", "1H_Melee_Attack_Chop", "2H_Melee_Attack_Chop", "Sword_Attack", "Dagger_Attack"],
	# Espada y escudo: tajo cruzado, hachazo y remate con una patada que empuja lejos.
	"attack_shield": ["shield_cross", "1H_Melee_Attack_Slice_Horizontal", "sword_regular_a"],
	"attack_shield_1": ["shield_down", "1H_Melee_Attack_Chop", "sword_regular_b"],
	"attack_shield_2": ["shield_kick", "Block_Attack", "sword_regular_c"],
	"block_shield": ["Blocking", "Block", "block"],
	"block_shield_hit": ["Block_Hit", "block"],
	"throw": ["spell_simple_enter", "Throw", "Punch"],
	"pickup": ["pickup_table", "PickUp", "Interact"],
	# Golpes de Lord Legislador e Inquisidores (ver Champion): clips propios de Meshy.
	"Double_Combo_Attack": ["Double_Combo_Attack"],
	"Weapon_Combo": ["Weapon_Combo"],
	"Triple_Combo_Attack": ["Triple_Combo_Attack"],
	"Attack": ["Attack"],
	"Left_Slash": ["Left_Slash"],
	"Weapon_Combo_1": ["Weapon_Combo_1"],
	"swim": ["swim_fwd"],
	"swim_idle": ["swim_idle", "swim_fwd"],
	"slide": ["slide", "Jump_Idle"],
	"allomancy": ["spell_simple_idle", "Attacking_Idle", "Idle_Attacking", "Spellcasting", "Idle"],
	"hit": ["hit_chest", "RecieveHit", "Hit_A"],
	"hit_head": ["hit_head", "hit_chest", "RecieveHit", "Hit_A"],
	"hit_knockback": ["hit_knockback", "hit_front", "RecieveHit", "Hit_A"],
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
	"slam": ["slam"],
	"fly": ["fly"],
	"fly_rise": ["fly_rise"],
	"fly_glide": ["fly_glide"],
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
	# Koloss (KolossMoves.glb de Mixamo): golpes con espadón o hachas y sus poderes; se llaman con play_spell().
	"gs_slash_down": ["gs_slash_down"],
	"gs_slash_power": ["gs_slash_power"],
	"gs_slash_low": ["gs_slash_low"],
	"gs_combo": ["gs_combo"],
	"gs_kick": ["gs_kick"],
	"mt_swipe_l": ["mt_swipe_l"],
	"mt_swipe_r": ["mt_swipe_r"],
	"mt_punch": ["mt_punch"],
	"mt_roar": ["mt_roar"],
	"mt_flex": ["mt_flex"],
	"mt_jump_attack": ["mt_jump_attack"],
}
## Animaciones que se repiten (el resto se queda en su último fotograma al terminar).
const LOOPING := ["block_shield", "idle", "idle_armed", "walk", "run", "sprint", "flee", "air", "fly", "fly_rise", "allomancy", "hang",
		"swim", "swim_idle", "slide", "burn_focus", "crouch_idle", "crouch_walk", "freefall", "sit", "box_idle",
		"carry_walk", "dig", "push_heavy", "pull_heavy", "kneel_inspect", "sad_idle", "sad_walk", "warm_hands"]
## Velocidad (m/s) a la que cada animación de desplazamiento "pisa" bien.
const STRIDE_SPEED := {"walk": 1.6, "run": 5.0, "sprint": 5.0, "flee": 5.0, "swim": 2.0, "crouch_walk": 0.7}
## Lo mismo por nombre de animación, para las que se apartan del valor de su estado (ActionForge).
const ANIM_STRIDE := {"walk": 0.92, "sprint": 7.7, "sad_walk": 0.72, "carry_walk": 1.1, "crouch_walk": 0.7,
		"gs_walk": 1.17, "gs_run": 4.61, "mt_walk": 1.38, "mt_run": 2.51, "Walking": 1.47, "Running": 5.0, "RunFast": 7.0,
		# Medidas en Vin con el pie apoyado (tools: feet_check): si no, el pie patina.
		"Spear_Walk": 1.46, "Cautious_Crouch_Walk_Forward_inplace": 1.27, "Walk_Fight_Forward": 0.77}
## Por encima de esta velocidad (peltre) se esprinta.
const SPRINT_SPEED := 8.0
## Golpes con dagas o espada: a esta fracción de la velocidad a la que entrarían en su duración.
const WEAPON_ANIM_SPEED := 0.8
## En qué fracción de cada clip pega el golpe o sale el poder: cuándo la mano o el pie van más rápido (medido con un
## script sobre los .glb). Los koloss guardan el suyo en Koloss.SWORD_BLOWS.
const IMPACT := {"sword_regular_a": 0.58, "sword_regular_b": 0.53, "sword_regular_c": 0.33, "sword_attack": 0.27,
		"Unarmed_Melee_Attack_Punch_A": 0.36, "Unarmed_Melee_Attack_Punch_B": 0.3, "fist_jab": 0.55, "fist_cross": 0.57,
		"fist_uppercut": 0.37, "fist_hook": 0.47, "fist_roundhouse": 0.45, "dagger_lead": 0.4, "dagger_rear": 0.28,
		"dagger_double": 0.38, "shield_cross": 0.5, "shield_down": 0.4, "shield_kick": 0.5, "Unarmed_Melee_Attack_Kick": 0.34, "1H_Melee_Attack_Slice_Horizontal": 0.25,
		"1H_Melee_Attack_Chop": 0.55, "Block_Attack": 0.36, "1H_Melee_Attack_Stab": 0.25,
		"Dualwield_Melee_Attack_Slice": 0.5, "Dualwield_Melee_Attack_Stab": 0.25, "Dualwield_Melee_Attack_Chop": 0.45, "steel_push": 0.46, "coin_flick": 0.41, "coin_wave": 0.43, "drink": 0.3}
const DEFAULT_IMPACT := 0.4
## Clips de Mixamo: [desde, hasta], el tramo del golpe. Lo demás es volver a una guardia que el juego no usa.
const ATTACK_CUT := {"fist_jab": [0.33, 0.75], "fist_cross": [0.4, 0.72], "fist_uppercut": [0.1, 0.6], "fist_hook": [0.22, 0.7],
		"fist_roundhouse": [0.1, 0.72], "dagger_lead": [0.2, 0.62], "dagger_rear": [0.13, 0.5], "dagger_double": [0.2, 0.6],
		"shield_cross": [0.2, 0.75], "shield_down": [0.22, 0.62], "shield_kick": [0.17, 0.75]}
var _impact_delay := 0.0
var _attack_hit := 0.0
## Al cambiar de clip, la pose de antes se apaga en estos segundos (sirve también entre esqueletos distintos).
const FADE_ATTACK := 0.08
## Golpe tras golpe: el cuerpo pasa un poco más suave y las piernas (cadera incluida) mucho más, para que los pies no salten.
const COMBO_FADE := 0.15
const ATTACK_LEG_FADE := 0.32
var _fade_leg_t := 0.0
var _fade_leg_len := 1.0
var _leg_bone := PackedByteArray()
const FADE_ONESHOT := 0.12
## Entrar a una voltereta (desde la carrera o al caer): a 0,08 s las manos saltaban 0,5 m en un cuadro.
const ROLL_FADE := 0.16  # también el dash y el doble salto (voltereta en el aire)
const PICKUP_FADE := 0.25  # agacharse a juntar algo no apura: la cabeza bajaba de golpe
const FADE_LONG := 0.35
const FADE_EXIT := 0.32  # volver a reposo tras un golpe o un bloqueo: a 0,22 s el brazo volvía de un tirón
var _fade_pose: Array[Quaternion] = []
var _fade_hips := Vector3.ZERO
var _fade_t := 0.0
var _fade_len := 1.0
## Capa superior: los gestos de los poderes van en torso y brazos, sobre lo que hagan las piernas (correr, caer...).
## Un esqueleto invisible de MixamoSpells reproduce el clip y se copian solo estos huesos.
const UPPER_DONOR := "MixamoSpells.glb"
const UPPER_BONES := ["Spine2", "Head", "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand"]  # del donante
const UPPER_FADE := 0.12
## Al soltar un gesto vuelve a la guardia en este tiempo, quieto en su último cuadro: a 0,12 s el brazo volvía de un tirón.
const UPPER_EXIT_FADE := 0.3
## Gestos lentos (los que fijan su velocidad en HeroClips.SKILLS): entran y salen más suave y se frenan al final.
const SLOW_SKILL_FADE := 0.3
const SLOW_SKILL_HOLD := 0.35
var _upper_fade := UPPER_FADE
## Golpe flojo de costado o por la espalda: la primera sacudida del clip direccional, solo en torso y brazos (el primer
## pico cae entre 0,1 y 0,15 del clip), así no empuja el cuerpo ni frena las piernas.
const LIGHT_HIT_CUT := 0.2
const LIGHT_HIT_TIME := 0.4
var _hit_head_next := false
## Encender un metal: [clip, desde, hasta]. Son clips largos; solo se usa el tramo del gesto (visto en una hoja de poses).
const BURN_GESTURE := ["burn_focus", 0.05, 0.2]
const PEWTER_GESTURE := ["pewter_flex", 0.25, 0.68]
const BURN_GESTURE_TIME := 0.8
## jump_start ya bajó los pies pasada esta fracción y jump_land ya se paró: el resto se vería parado en el aire o quieto.
const JUMP_CUT := 0.55
const DOUBLE_JUMP_TIME := 0.8  # la voltereta entera, sin cortarla
const FLY_LAUNCH_TIME := 0.6
var _launch := 0.0
## Salto de acero con moneda: vuela (Vuelo_Moneda), a los COIN_GLIDE_AFTER s pasa a Fall2 y lo mantiene mientras sube;
## al empezar a bajar, la zambullida de la caída libre.
const COIN_GLIDE_AFTER := 2.0
const COIN_DESCEND_SPEED := -1.0
## Héroes volando: bajando más rápido que esto (m/s) pasan de los brazos abiertos a la caída libre.
const HERO_FREEFALL_SPEED := 6.0
var _coin_t := 0.0
## Mezclas lentas en el aire: va levantando los brazos al volar y se da vuelta de a poco al caer.
const AIR_BLENDS := {"fly": 0.8, "fly_rise": 0.5, "fly_glide": 0.8, "freefall": 0.5}
## Volando hacia arriba (más que de costado) a más de esto (m/s): pose de subida tipo Ironman (fly_rise). Al empezar a
## bajar, la de caída.
const RISE_SPEED := 2.0
const FLY_END_BLEND := 0.3
const LAND_CUT := 0.7
## Cayendo más rápido que esto (m/s) se pasa a la pose de caída libre.
const FREEFALL_SPEED := 12.0
## Aterrizando así de fuerte y a la carrera, rueda en vez de clavarse.
const LAND_ROLL_STRENGTH := 1.0
const LAND_ROLL_SPEED := 2.5
var _upper := {}
var _upper_bones: Array[int] = []
var _upper_t := 0.0
var _upper_w := 0.0
var _upper_stop := INF  # segundo del clip en el que se queda quieto (ver play_skill)
var _upper_impact_at := -1.0  # segundo del clip del tiro; antes va a _upper_windup_speed
var _upper_windup_speed := 0.0
var _left_lag := 0.0  # segundos de retraso del brazo izquierdo (0: sigue al clip)
var _lagged := {}  # hueso -> giro con retraso
var _upper_speed := 1.0
## Quieto, caminar, correr...: al pasar de una a otra se mezclan durante LOCO_BLEND segundos y la
## nueva arranca en el mismo punto del paso (fase) que la anterior, así no se cortan de golpe.
const LOCOMOTION := ["idle", "idle_armed", "walk", "run", "sprint", "flee", "crouch_idle", "crouch_walk", "allomancy"]
const LOCO_BLEND := 0.4
## Al empezar a empujar (p. ej. la moneda recién lanzada) el cuerpo baja a la postura sin caer de golpe.
const PUSH_STANCE_BLEND := 0.9
## Bloqueo: la animación "block" se queda quieta en este punto (guardia arriba); al recibir un golpe
## retrocede a BLOCK_KICK_FROM y vuelve a subir.
const BLOCK_HOLD := 0.5
const BLOCK_KICK_FROM := 0.36
var _block_kick := 0.0
var _shield_node: Node3D
const SHIELD_SCALE := 0.85
## Estados en los que el brazo izquierdo lleva el escudo (en el resto no: trepar, nadar, gestos...).
const SHIELD_ARM_STATES := ["idle_armed", "idle", "walk", "run", "sprint", "jump", "air", "land", "hit", "block_shield",
		"block_shield_hit", "attack_air"]
var _combat_arms := 0.0
## Golpe recibido: el torso se dobla hacia este lado (mundo) y vuelve solo, sobre cualquier animación.
var _flinch := Vector3.ZERO
const FLINCH_LIGHT := 0.22
const FLINCH_HEAVY := 0.45
const FLINCH_RETURN := 7.0
var _attack_full := 1.0
const FINGER_CURL := 1.25
var _fist_closed := {}
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
const IK_OFF := ["air", "fly", "fly_rise", "fly_glide", "fly_launch", "slam", "jump", "hang", "climb", "swim", "swim_idle", "slide", "down", "roll", "dash",
		"attack_air", "freefall", "fall_roll", "climb_wall", "vault", "mt_jump_attack"]
const IK_MOVING := ["walk", "run", "sprint", "flee", "carry_walk", "sad_walk", "crouch_walk", "stop"]  # stop: da pasos, no se clava
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
## Pie hundido menos que esto (m) se deja: es el tobillo doblado. Más, el cuerpo sube (clips de otro esqueleto,
## p. ej. el Crouch Idle de Mixamo, que bajaba la cadera 26 cm).
const SINK_OK := 0.04
## Estados en el suelo sin IK de pies que igual apoyan el cuerpo (ver _contact_drop), y cuánto va el hueso por dentro.
const GROUND_CONTACT := ["roll", "fall_roll", "slide", "down"]
const BODY_PAD := 0.07
## Andando, a qué velocidad (m/s) se olvida lo más bajo que pisó el pie (ver _move_low).
const MOVE_LOW_RISE := 0.15
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
## Armas de la mano derecha e izquierda (rutas .glb) en lugar de la espada de siempre (el koloss).
var held_weapons: Array = []
## La zancada crece con el cuerpo: ANIM_STRIDE vale para 1,8 m; un koloss de 3 m usa 3 / 1,8.
var stride_scale := 1.0
## false: el color de Art.SUITS pinta solo la capa, no la textura del cuerpo.
var suit_on_body := true
## Solo los clips de anim_overrides y mezclas entre ellos: sin poses hechas por código (ver HeroClips).
var clips_only := false
var state_cuts := {}  # estado -> [desde, hasta, golpe (opcional)], fracciones del clip
var clip_holds := {}  # estado -> fracción del clip en la que se queda quieto
var skill_clips := {}  # gesto de play_skill -> [clip, desde, hasta, golpe]
var upper_donor := UPPER_DONOR
## Más donantes para los gestos de la capa superior (se usa el primero que tenga el clip).
var upper_extra: Array = []
var _uppers := {}  # archivo -> {"ap", "rt", "bones"}
## No reacciona a los golpes flojos (no le cortan el suyo): solo a los fuertes y al aturdimiento.
var ignore_light_hits := false
## En pleno salto, rugido o furia: ningún golpe le corta la animación.
var armored := false
## Arma de dos manos (una sola en held_weapons): el brazo izquierdo busca el mango con IK, porque los
## brazos del koloss no miden lo que los del clip y la mano quedaba a medio metro.
const TWO_HAND_GRIP := 0.22  # m por debajo de la mano derecha, sobre el mango
var _arm_iks: Array[SkeletonModifier3D] = []
var _right_hand_turn := Basis.IDENTITY
var _arm_targets: Array[Node3D] = []
var _arm_poles: Array[Node3D] = []
var _arm_len := 0.0
var _arm_grip_point := Vector3.ZERO
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
var _stop := 0.0  # frenada desde la carrera (ver _start_stop)
var _recent_speed := 0.0  # la velocidad de hace un momento: al frenar se pasa unos cuadros por caminar
var _dash := 0.0
var _climb := 0.0
var _pickup := 0.0
var _arms_open := 0.0
var _arms_open_len := 0.0
var _arms_lift := 0.0
var _arms_bend := 0.0
## Giro del golpe aéreo: una vuelta entera del cuerpo en SPIN_TIME s.
const SPIN_TIME := 0.3
var _spin := 0.0
## Animación más espaciada lejos de la cámara (salvo el jugador, use_real_time): el tiempo que no se
## anima se junta y se aplica en el siguiente cuadro que sí.
var _pending_dt := 0.0
var _frame := 0
const NEAR_ANIM := 20.0
const FAR_ANIM := 60.0
## Capa de bruma y frascos del inventario: siguen a los huesos del cuello y la cadera.
var _cloak_anchor: Node3D
var _vial_anchor: Node3D
var _belt: VialBelt
var _vial_hand: Node3D
var _held_vial: Node3D
const VIAL_HAND := "hand_l"  # la que sube a la boca en Stand_and_Drink
const CLOAK_NECK := 1.39
const CLOAK_SHOULDERS := 0.35
const EMPTY_VIAL_LIFE := 8.0
## Lleva la capa de bruma puesta de por sí, sin depender del inventario.
var always_cloak := false
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
var _move_low := 0.0  # andando: lo más bajo que pisa el pie en la zancada (baja enseguida, sube despacio)
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
	_setup_two_hand()
	_play("idle", 0.0)


## Paso entre el brazo derecho y el izquierdo: lo que el izquierdo necesita saber ya está resuelto.
class TwoHandStep extends SkeletonModifier3D:
	var rig: ModelRig

	func _process_modification_with_delta(_delta: float) -> void:
		rig._two_hand_step()


func _setup_two_hand() -> void:
	if _skel == null or held_weapons.size() != 1:
		return
	var step := TwoHandStep.new()
	step.rig = self
	_arm_iks = [TwoBoneIK3D.new(), step, TwoBoneIK3D.new()]
	for i in 3:
		_skel.add_child(_arm_iks[i])
	for i in [0, 2]:
		var side: String = "_r" if i == 0 else "_l"
		var ik: TwoBoneIK3D = _arm_iks[i]
		var target := Node3D.new()
		var pole := Node3D.new()
		add_child(target)
		add_child(pole)
		_arm_targets.append(target)
		_arm_poles.append(pole)
		ik.setting_count = 1
		ik.set_root_bone(0, _bones["upper" + side])
		ik.set_middle_bone(0, _bones["lower" + side])
		ik.set_end_bone(0, _bones["hand" + side])
		ik.set_target_node(0, ik.get_path_to(target))
		ik.set_pole_node(0, ik.get_path_to(pole))
		ik.influence = 0.0
	step.influence = 0.0
	var shoulder := _skel.get_bone_global_rest(_bones["upper_l"]).origin
	var elbow := _skel.get_bone_global_rest(_bones["lower_l"]).origin
	_arm_len = shoulder.distance_to(elbow) + elbow.distance_to(_skel.get_bone_global_rest(_bones["hand_l"]).origin)


## Con los clips de espadón, la mano izquierda va al mango; si no llega, la derecha acerca el arma lo
## justo, sin girarla (ver _two_hand_step).
func _update_two_hand(dt: float, state: String) -> void:
	if _arm_iks.is_empty():
		return
	var clip: String = _resolved.get(state, {}).get("name", "")
	var want := _near and weapon == Weapon.SWORD and clip.begins_with("gs_")
	var power := move_toward(_arm_iks[0].influence, 1.0 if want else 0.0, dt * 8.0)
	for ik: SkeletonModifier3D in _arm_iks:
		ik.influence = power
	if power <= 0.0:
		return
	var to_world := _skel.global_transform
	var size := _skel.global_basis.get_scale().x
	var pose := _skel.get_bone_global_pose(_bones["hand_r"])
	_right_hand_turn = pose.basis
	var hand := to_world * pose
	var grip := hand * _arm_grip_point
	var left := to_world * _skel.get_bone_global_pose(_bones["upper_l"]).origin
	var right := to_world * _skel.get_bone_global_pose(_bones["upper_r"]).origin
	var short := maxf(left.distance_to(grip) - _arm_len * size * 0.95, 0.0)
	var shift := (left - grip).normalized() * short
	_arm_targets[0].global_position = hand.origin + shift
	# Los codos hacia afuera y abajo.
	var out := (left - right).normalized()
	_arm_poles[0].global_position = (right + hand.origin + shift) * 0.5 + (Vector3.DOWN - out) * 0.5 * size
	_arm_poles[1].global_position = (left + grip + shift) * 0.5 + (out + Vector3.DOWN) * 0.5 * size


## Resuelto el brazo derecho: la mano vuelve al giro del clip (el IK la giró con el antebrazo) y recién
## ahí se sabe dónde queda el mango para la izquierda.
func _two_hand_step() -> void:
	var bone: int = _bones["hand_r"]
	var pose := Transform3D(_right_hand_turn, _skel.get_bone_global_pose(bone).origin)
	_skel.set_bone_global_pose(bone, pose)
	_arm_targets[1].global_position = _skel.global_transform * (pose * _arm_grip_point)


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
		ap.process_mode = Node.PROCESS_MODE_ALWAYS  # en pausa los que usan sus propios clips quedaban en pose T
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
	for state in ANIMS.keys() + anim_overrides.keys():
		_resolved[state] = {"name": "", "borrowed": false, "donor": -1}
		for candidate in anim_overrides.get(state, [] if clips_only else ANIMS.get(state, [])):
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
	var swords: Array[Node3D] = []
	for i in held_weapons.size():
		swords.append((load(held_weapons[i]) as PackedScene).instantiate())
		(r if i == 0 else l).add_child(swords[i])
	if held_weapons.size() == 1:
		_arm_grip_point = r.position + r.basis * Vector3.DOWN * TWO_HAND_GRIP
	if swords.is_empty():
		swords.append(_sword())
		r.add_child(swords[0])
	var daggers: Array[Node3D] = [_dagger(), _dagger()]
	r.add_child(daggers[0])
	l.add_child(daggers[1])
	_weapon_nodes[Weapon.DAGGERS] = {"held": daggers, "sheathed": []}
	_weapon_nodes[Weapon.SWORD] = {"held": swords, "sheathed": []}
	_shield_node = (load("res://assets/weapons/shield.glb") as PackedScene).instantiate()
	_shield_node.visible = false
	l.add_child(_shield_node)


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
	if _shield_node:
		_shield_node.visible = shield_up()
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
	cloak_on = cloak_on or always_cloak
	if cloak_on and _cloak_anchor == null:
		_add_cloak()
	if _cloak_anchor:
		_cloak_anchor.visible = cloak_on
	if vials_on and _vial_anchor == null:
		_make_belt()
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
	cloak.build_model(_cloak_suit(), _skel, _bones["torso"], _bones["neck"], colliders, _cloak_fit())


## Tamaño de la capa según el cuerpo: alto por el cuello, ancho por los hombros (medidas del encapuchado, para el que se armó).
func _cloak_fit() -> Vector3:
	var neck: float = _skel.get_bone_global_rest(_bones["neck"]).origin.y
	var wide: float = _skel.get_bone_global_rest(_bones["upper_r"]).origin.distance_to(_skel.get_bone_global_rest(_bones["upper_l"]).origin)
	return Vector3(wide / CLOAK_SHOULDERS, neck / CLOAK_NECK, wide / CLOAK_SHOULDERS)


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
		if _items.has(mi) or (_belt and _belt.is_ancestor_of(mi)):
			continue
		for i in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if base == null:
				continue
			if suit_on_body and _suit != "negro" and base.albedo_texture:
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


func _make_belt() -> void:
	if _skel == null or _bones["hips"] < 0:
		return
	var attach := BoneAttachment3D.new()
	_skel.add_child(attach)
	attach.bone_idx = _bones["hips"]
	_belt = VialBelt.new()
	attach.add_child(_belt)
	_belt.build(_model, _skel, _bones["hips"])
	_vial_anchor = attach


## kind: id del objeto de frascos. Lo llama el jugador en cada cuadro; solo cambia algo si cambió la cantidad.
func set_vials(kind: String, capacity: int, count: int) -> void:
	if _belt:
		_belt.set_vials(kind, capacity)
		_belt.show_count(count)


## Saca un frasco del cinturón y lo lleva a la mano; lo que haya en esa mano se guarda mientras toma.
func take_vial() -> void:
	if _belt == null or _vial_hand == null and _make_vial_hand() == null:
		return
	var i := _belt.take()
	if i < 0:
		return
	_clear_held_vial()
	_held_vial = _belt.make_vial(i)
	_vial_hand.add_child(_held_vial)
	_show_held_weapon(false)


## Tomado: el frasco vacío se suelta y cae al piso.
func drop_vial() -> void:
	if _held_vial == null:
		return
	var at := _held_vial.global_transform
	_clear_held_vial()
	_belt.put_back()
	_show_held_weapon(true)
	var scene := get_tree().current_scene
	if scene == null:
		return
	var body := RigidBody3D.new()
	body.collision_layer = 0
	body.collision_mask = Props.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.03
	shape.shape = ball
	body.add_child(shape)
	var empty: Node3D = (load(VialBelt.VIAL_MODEL) as PackedScene).instantiate()
	for mi: MeshInstance3D in empty.find_children("vial_liquid", "MeshInstance3D", true, false):
		mi.visible = false
	empty.scale = Vector3.ONE * VialBelt.VIAL_SCALE
	body.add_child(empty)
	scene.add_child(body)
	body.global_position = at.origin
	body.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	get_tree().create_timer(EMPTY_VIAL_LIFE).timeout.connect(body.queue_free)


func _make_vial_hand() -> Node3D:
	_vial_hand = _grip(_bones[VIAL_HAND])
	return _vial_hand


func _clear_held_vial() -> void:
	if _held_vial:
		_held_vial.queue_free()
		_held_vial = null


func _show_held_weapon(on: bool) -> void:
	if weapon == Weapon.DAGGERS:
		(_weapon_nodes[weapon]["held"][1] as Node3D).visible = on
	elif on:
		set_weapon(weapon)  # el escudo vuelve si le corresponde
	if not on and _shield_node:
		_shield_node.visible = false


## Coloca la capa en los hombros, según la pose actual.
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


func play_attack(side: int, duration: float, step := 0) -> float:
	super(side, duration, step)
	var state := "attack_fist"
	if weapon == Weapon.DAGGERS:
		state = "attack_daggers"
	elif weapon == Weapon.SWORD:
		state = "attack_shield" if shield_up() else "attack_sword"
	if step > 0 and _resolved.get("%s_%d" % [state, step], {"name": ""})["name"] != "":
		state = "%s_%d" % [state, step]
	_upper_t = 0.0
	_spell = 0.0
	_attack = _play_once(state, duration, COMBO_FADE if _attack > 0.0 else FADE_ATTACK)
	if _fade_t > 0.0:
		_fade_leg_t = ATTACK_LEG_FADE
		_fade_leg_len = ATTACK_LEG_FADE
	if weapon != Weapon.NONE:
		_slow_attack()
	_attack_full = _attack
	_attack_hit = _impact_delay
	return _attack


func play_roll(duration := 0.5, slide := false) -> void:
	super(duration)
	_variant["roll"] = "_slide" if slide else ""
	_roll = _play_once("roll", duration, ROLL_FADE)


func play_throw() -> void:
	super()
	_throw = _play_once("throw", 0.55)


## Gesto de alomancia con monedas (coin_wave, coin_shield) de unos `duration` segundos.
func play_spell(state: String, duration: float) -> void:
	_spell_state = state
	# Los de duración larga son trabajos en bucle (skaa): cambian despacio.
	_spell = _play_once(state, duration, FADE_LONG if duration > 5.0 else FADE_ONESHOT)


## Brazos abiertos hacia los costados (escudo de monedas, golpe giratorio con las armas por fuera).
## lift: cuánto suben (0 = horizontales; negativo, más abajo). bend: codos doblados hacia delante.
func open_arms(duration: float, lift := 0.0, bend := 0.0) -> void:
	_arms_open = duration
	_arms_open_len = duration
	_arms_lift = lift
	_arms_bend = bend


## Gesto de un poder (empujar, tirar, lanzar monedas...) en la capa superior: las piernas siguen en lo suyo.
## from, to: tramo del clip que se usa (se salta la preparación, o el resto de un clip largo). Devuelve cuánto dura.
func play_skill(state: String, duration: float, from := 0.0, to := 1.0) -> float:
	var impact: float = IMPACT.get(state, DEFAULT_IMPACT)
	var fixed_speed := 0.0
	var blend_out := 0.0
	var windup_speed := 0.0
	_left_lag = 0.0
	_lagged.clear()
	if skill_clips.has(state):
		var skill: Array = skill_clips[state]
		state = skill[0]
		from = skill[1]
		to = skill[2]
		impact = skill[3]
		fixed_speed = skill[4] if skill.size() > 4 else 0.0
		blend_out = skill[5] if skill.size() > 5 else 0.0
		windup_speed = skill[6] if skill.size() > 6 else 0.0
		_left_lag = skill[7] if skill.size() > 7 else 0.0
	if not _ensure_upper(state) or not _upper["ap"].has_animation(state):
		play_throw()
		_impact_delay = 0.0
		return _throw
	var ap: AnimationPlayer = _upper["ap"]
	var length := ap.get_animation(state).length
	ap.get_animation(state).loop_mode = Animation.LOOP_NONE
	ap.play(state, 0.0)
	ap.seek(length * from, true)  # ya en la pose del tramo: si no, al entrar se ve la pose en T
	_upper_speed = clampf(length * (to - from) / duration, 1.0, MAX_ONESHOT_SPEED)
	_upper_fade = UPPER_FADE
	if fixed_speed > 0.0:
		_upper_speed = fixed_speed
		_upper_fade = SLOW_SKILL_FADE
	_upper_t = length * (to - from) / _upper_speed
	_impact_delay = maxf(impact - from, 0.0) * length / _upper_speed
	_upper_impact_at = -1.0
	_upper_windup_speed = 0.0
	if windup_speed > 0.0 and impact > from:
		# Hasta el tiro, a su propia velocidad (más rápido); de ahí en adelante, a la del resto.
		_upper_impact_at = length * impact
		_upper_windup_speed = windup_speed
		_impact_delay = (impact - from) * length / windup_speed
		_upper_t = _impact_delay + maxf(to - impact, 0.0) * length / _upper_speed
	_upper_stop = INF
	if blend_out > 0.0:
		# Se queda en el último cuadro del tramo y desde ahí se funde con lo que hace el cuerpo (el empuje).
		_upper_stop = length * to
		_upper_fade = blend_out
		_upper_t += blend_out
	elif fixed_speed > 0.0:
		_upper_t += SLOW_SKILL_HOLD  # se queda un momento en la pose final antes de soltar
	return _upper_t


## Gesto al encender un metal, solo si el cuerpo no está en otra cosa: no corta nada.
func burn_gesture(pewter: bool) -> void:
	if _upper_t > 0.0 or _attack > 0.0 or _roll > 0.0 or _spell > 0.0 or _dash > 0.0 or _climb > 0.0 or hanging or swimming or down:
		return
	var g: Array = PEWTER_GESTURE if pewter else BURN_GESTURE
	play_skill(g[0], BURN_GESTURE_TIME, g[1], g[2])


func impact_delay() -> float:
	return _impact_delay


## Hasta dónde llega el arma más allá de la mano (m).
const KICK_CLIPS := ["Step_in_High_Kick", "Rising_Flying_Kick", "Double_kick_forward", "Flying_Fist_Kick"]
const STRIKE_REACH := {Weapon.NONE: 0.05, Weapon.DAGGERS: 0.3, Weapon.SWORD: 0.85}
## Lo que barrió el golpe en este tiempo antes del impacto también pega: en un tajo ancho, en el pico de velocidad
## la hoja ya pasó por delante y está al costado.
const STRIKE_WINDOW := 0.15
var _strike_pts: Array[Vector3] = []
var _strike_hist: Array = []  # [tiempo, puntos]


## Mientras pega: dónde están lo que golpea (las manos con su arma, o los pies en las patadas).
func _track_strike(_dt: float) -> void:
	_strike_pts.clear()
	if _attack <= 0.0 or _skel == null:
		_strike_hist.clear()
		return
	# Los pies solo en las patadas: en los demás golpes el pie que da el paso no pega.
	var kick: bool = _resolved.get(_state, {}).get("name", "") in KICK_CLIPS
	for key in (["foot_l", "foot_r"] if kick else ["hand_l", "hand_r"]):
		if _bones.get(key, -1) < 0:
			continue
		var p := BoneTools.bone_world_pos(_skel, _bones[key])
		if not kick:
			var elbow := BoneTools.bone_world_pos(_skel, _bones["lower" + key.substr(4)])
			p += (p - elbow).normalized() * float(STRIKE_REACH.get(weapon, 0.05)) * scale.y
		_strike_pts.append(p)
	_strike_hist.append([_t, _strike_pts.duplicate()])
	while _strike_hist.size() > 1 and _t - float(_strike_hist[0][0]) > STRIKE_WINDOW:
		_strike_hist.pop_front()


## Por dónde pasó lo que golpea en los últimos STRIKE_WINDOW s (vacío si no está pegando o no se sabe).
func strike_points() -> Array[Vector3]:
	var all: Array[Vector3] = []
	for h: Array in _strike_hist:
		all.append_array(h[1])
	return all


func cancel_action() -> void:
	super()
	if _held_vial:  # cortó el trago: el frasco vuelve al cinturón
		_clear_held_vial()
		_belt.put_back()
		_show_held_weapon(true)
	_spell = 0.0
	_upper_t = 0.0
	_land = 0.0


## anim: el clip que se va a usar; elige el donante que lo tenga. Sin anim, el principal.
func _ensure_upper(anim := "") -> bool:
	if _skel == null:
		return false
	if not _upper.is_empty() and (anim == "" or (_upper["ap"] as AnimationPlayer).has_animation(anim)):
		return true
	for spec: Array in _donor_specs:
		var file := String(spec[0]).get_file()
		if file != upper_donor and not file in upper_extra:
			continue
		if not _uppers.has(file):
			var map: Array = (spec[1] as Array).filter(func(m: Array) -> bool: return m[1] in UPPER_BONES)
			var model := _instance(spec[0])
			model.visible = false
			_fit_height(model, false)
			model.rotation.y = _model.rotation.y
			var bones: Array[int] = []
			for m: Array in map:
				if _skel.find_bone(m[0]) >= 0:
					bones.append(_skel.find_bone(m[0]))
			_uppers[file] = {"ap": _first(model, "AnimationPlayer"), "rt": BoneTools.Retargeter.new(_first(model, "Skeleton3D"), _skel, map), "bones": bones}
		var e: Dictionary = _uppers[file]
		if e["ap"] != null and (anim == "" or (e["ap"] as AnimationPlayer).has_animation(anim)):
			_upper = e
			_upper_bones = e["bones"]
			return true
	return false


func _apply_upper(dt: float) -> void:
	_upper_t -= dt
	var rising := _upper_t > _upper_fade and not hanging
	# Con armado rápido, entra rápido: si no, el armado pasaría a medio fundir.
	var fade := UPPER_FADE if rising and _upper_windup_speed > 0.0 else _upper_fade
	if not rising and not hanging:
		fade = maxf(fade, UPPER_EXIT_FADE)
	_upper_w = move_toward(_upper_w, 1.0 if rising else 0.0, dt / fade)
	if _upper_w <= 0.0:
		_apply_left_lag(dt)  # el brazo izquierdo termina de llegar con su retraso: si no, salta al soltar
		return
	var ap := _upper["ap"] as AnimationPlayer
	var speed := _upper_windup_speed if ap.current_animation_position < _upper_impact_at else _upper_speed
	if _upper_t > 0.0:  # terminado el tramo, se funde quieto (si no, sigue el resto del clip)
		ap.advance(minf(dt * speed, maxf(_upper_stop - ap.current_animation_position, 0.0)))
	var before: Array[Quaternion] = []
	for b in _upper_bones:
		before.append(_skel.get_bone_pose_rotation(b))
	_upper["rt"].apply(true)
	var w := smoothstep(0.0, 1.0, _upper_w)
	for i in _upper_bones.size():
		_skel.set_bone_pose_rotation(_upper_bones[i], before[i].slerp(_skel.get_bone_pose_rotation(_upper_bones[i]), w))
	_apply_left_lag(dt)


## El brazo izquierdo sigue al clip con retraso: su balanceo queda más lento y suave. Ya soltado el gesto, se apaga
## cuando alcanza la pose del cuerpo.
func _apply_left_lag(dt: float) -> void:
	if _left_lag <= 0.0:
		return
	var k := 1.0 - exp(-dt / _left_lag)
	var behind := false
	for key in ["upper_l", "lower_l", "hand_l"]:
		var b: int = _bones[key]
		if b < 0:
			continue
		var now := _skel.get_bone_pose_rotation(b)
		_lagged[b] = (_lagged[b] as Quaternion).slerp(now, k) if _lagged.has(b) else now
		behind = behind or (_lagged[b] as Quaternion).angle_to(now) > 0.01
		_skel.set_bone_pose_rotation(b, _lagged[b])
	if _upper_w <= 0.0 and not behind:
		_left_lag = 0.0
		_lagged.clear()


## Solo parado o caminando: a la carrera la animación entera se vería deslizándose.
func play_pickup() -> void:
	if move_speed < 3.0 and _attack <= 0.0 and _roll <= 0.0:
		_pickup = _play_once("pickup", 0.9, PICKUP_FADE)


## air_flip: segundo salto en el aire, con su propio clip.
func play_jump(air_flip := false) -> void:
	if _attack > 0.0 or _roll > 0.0:
		return
	_land = 0.0
	_variant["jump"] = ""
	if air_flip or next_jump != "":
		_variant["jump"] = "_double" if air_flip else next_jump
	next_jump = ""
	_jump = _play_once("jump", DOUBLE_JUMP_TIME, ROLL_FADE) if air_flip else _play_once("jump", 0.35, FADE_ATTACK) * JUMP_CUT


func play_fly_launch() -> void:
	if _resolved.get("fly_launch", {"name": ""})["name"] != "" and _attack <= 0.0:
		_jump = 0.0
		_launch = _play_once("fly_launch", FLY_LAUNCH_TIME, FADE_ONESHOT)


## Frenada desde la carrera (Sprint_and_Sudden_Stop): el clip corre en el lugar, frena con el pie izquierdo
## (25 %), da un paso más con el derecho y queda parado con los pies juntos (STOP_END). Se entra en el punto de su
## carrera que coincide con el paso que trae (izquierdo apoyado: 6,5 % del clip = 30 % del ciclo de Running;
## derecho: 16,5 % = 80 %): sigue con el pie que toca y no patina. Medido en Vin con tools/anim_check.
const STOP_LEFT_AT := 0.065
const STOP_RIGHT_AT := 0.165
const STOP_END := 0.62
const STOP_SPEED := 1.2
const STOP_FADE := 0.15
const STOP_FROM := 3.5  # m/s: más lento que esto se para sin frenada


func _start_stop() -> bool:
	if _resolved.get("stop", {"name": ""})["name"] == "" or not on_floor or crouched or _attack > 0.0 or _roll > 0.0:
		return false
	var phase := _cycle_phase()  # de la carrera que viene
	if phase < 0.0:
		return false
	var entry := STOP_LEFT_AT + fposmod(phase - 0.3, 1.0) * 2.0 * (STOP_RIGHT_AT - STOP_LEFT_AT)
	_play("stop", STOP_FADE, true)
	var length := _current_length()
	(_src_ap if _borrowed else _ap).seek(length * entry, true)
	_oneshot_speed = STOP_SPEED
	_stop = (STOP_END - entry) * length / STOP_SPEED
	return true


## Aterrizaje: si vienes corriendo se corta solo (ver _choose_state).
const LAND_FADE := 0.22  # del ovillo del aire a la pose de caída: más corto, los brazos se abren de un salto
func play_land(strength := 1.0) -> void:
	if _attack > 0.0 or _roll > 0.0 or _dash > 0.0:
		return
	_jump = 0.0
	if strength >= LAND_ROLL_STRENGTH and move_speed > LAND_ROLL_SPEED and _resolved.get("fall_roll", {"name": ""})["name"] != "":
		_spell_state = "fall_roll"
		_spell = _play_once("fall_roll", 1.0, ROLL_FADE)
		return
	_land = _play_once("land", lerpf(0.52, 0.9, strength), LAND_FADE) * LAND_CUT


func play_dash(duration := 0.45) -> void:
	_jump = 0.0
	_dash = minf(_play_once("dash", duration, ROLL_FADE), duration)  # el final del clip es pararse: en el aire no va


func play_climb(duration := 0.65) -> float:
	_jump = 0.0
	_land = 0.0
	_climb = _play_once("climb", duration)
	return _climb


func play_air_attack(duration: float) -> float:
	_attack_len = duration
	_jump = 0.0
	_dash = 0.0
	_upper_t = 0.0
	_spell = 0.0
	_attack = _play_once("attack_air", duration, FADE_ATTACK)
	_attack_full = _attack
	_attack_hit = _impact_delay
	_spin = 0.0 if clips_only else SPIN_TIME
	return _attack


func _slow_attack() -> void:
	_oneshot_speed *= WEAPON_ANIM_SPEED
	_attack /= WEAPON_ANIM_SPEED
	_impact_delay /= WEAPON_ANIM_SPEED


## Reproduce entera una animación de una vez (golpe, voltereta...), acelerada para que quepa en
## `duration` (sin pasar de MAX_ONESHOT_SPEED). Devuelve cuánto dura así, para no cortarla.
func _play_once(state: String, duration: float, fade := FADE_ONESHOT) -> float:
	_play(state, fade, true)
	var length := _current_length()
	if length <= 0.0:
		_oneshot_speed = 1.0
		_impact_delay = duration * DEFAULT_IMPACT
		return duration
	var clip: String = _resolved.get(state, {}).get("name", "")
	var cut: Array = state_cuts.get(state + _suffix(state), state_cuts.get(state, ATTACK_CUT.get(clip, [0.0, 1.0])))
	if cut[0] > 0.0:
		(_src_ap if _borrowed else _ap).seek(length * cut[0], true)
	var used: float = length * (cut[1] - cut[0])
	_oneshot_speed = clampf(used / duration, 1.0, MAX_ONESHOT_SPEED)
	var impact: float = cut[2] if cut.size() > 2 else IMPACT.get(clip, DEFAULT_IMPACT)
	_impact_delay = maxf(impact - cut[0], 0.0) * length / _oneshot_speed
	return used / _oneshot_speed


## Por dónde va el ciclo de la animación actual (0..1).
func _cycle_phase() -> float:
	var length := _current_length()
	var player := _src_ap if _borrowed else _ap
	return fposmod(player.current_animation_position / length, 1.0) if length > 0.0 else -1.0


func _seek_time(t: float) -> void:
	(_src_ap if _borrowed else _ap).seek(t, false)


func block_impact() -> void:
	if _state in ["block_shield", "block_shield_hit"]:
		_play("block_shield_hit", 0.05, true)
		_block_kick = _current_length()
	elif _state == "block":
		_seek_time(BLOCK_KICK_FROM)
		_block_kick = BLOCK_HOLD - BLOCK_KICK_FROM


## Ligero: un respingo (cabeza o pecho). Fuerte: la de su lado (de frente, de espaldas, izquierda,
## derecha), que además empuja el cuerpo (root motion). Aturdido: la que lo tira hacia atrás.
func play_hit(from: Vector3, heavy: bool, stun := false) -> void:
	recoil(from, FLINCH_HEAVY if heavy or stun else FLINCH_LIGHT)
	if armored or (ignore_light_hits and (_spell > 0.0 or (not heavy and not stun))):
		return  # su golpe o poder sigue: cortar el clip dejaría el daño sin movimiento
	stagger = 1.0
	if _attack > 0.0 and not heavy and not stun:
		return  # un golpe flojo no corta el tuyo: alcanza con el retroceso del torso
	if down or _roll > 0.0 or _climb > 0.0 or _skel == null:
		return
	var side := _hit_side(from)
	if not heavy and not stun and side != "hit_front" and _upper_t <= 0.0 and _ensure_upper() and _upper["ap"].has_animation(side):
		play_skill(side, LIGHT_HIT_TIME, 0.0, LIGHT_HIT_CUT)
		return
	_hit_head_next = not _hit_head_next
	var state := "hit_head" if _hit_head_next else "hit"
	var duration := 0.35
	if stun:
		state = "hit_knockback"
		duration = 0.8
	elif heavy:
		state = side
		duration = 0.75
	if _resolved.get(state, {"name": ""})["name"] == "":
		return
	if heavy or stun:
		_attack = 0.0  # un golpe fuerte corta el tuyo
	play_spell(state, duration)


## De qué lado del cuerpo viene un golpe: el clip hit_* que le corresponde.
func _hit_side(from: Vector3) -> String:
	# Hacia dónde mira el personaje (-Z), no la línea de los hombros: con el torso girado por otro golpe, uno de
	# frente salía de costado.
	var b := global_basis.orthonormalized()
	var up := b.y
	var forward := -b.z
	var right := forward.cross(up)
	var to := from - global_position
	to = (to - up * to.dot(up)).normalized()
	if absf(to.dot(forward)) >= absf(to.dot(right)):
		return "hit_front" if to.dot(forward) > 0.0 else "hit_back"
	return "hit_right" if to.dot(right) > 0.0 else "hit_left"


func recoil(from: Vector3, amount := FLINCH_LIGHT) -> void:
	var away := global_position - from
	away.y = 0.0
	_flinch = (_flinch + away.normalized() * amount).limit_length(0.7)


func _seek_phase(phase: float) -> void:
	var length := _current_length()
	if length > 0.0:
		(_src_ap if _borrowed else _ap).seek(phase * length, false)


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
	_launch -= dt
	_coin_t = _coin_t + dt if coin_flight and not on_floor else 0.0
	_land -= dt
	_stop -= dt
	_recent_speed = maxf(move_speed, _recent_speed - dt * 10.0)
	_dash -= dt
	_climb -= dt
	_pickup -= dt
	_spell -= dt
	_arms_open -= dt
	_block_kick -= dt
	if _spin > 0.0:
		_spin -= dt
		# Arranca de golpe y frena al final de la vuelta.
		var k := 1.0 - maxf(_spin, 0.0) / SPIN_TIME
		rotation.y = TAU * (1.0 - pow(1.0 - k, 3.0)) if _spin > 0.0 else 0.0
	if _ap == null and retarget_from == "":
		return
	var state := _choose_state()
	if state in ["idle", "idle_armed"] and _state in ["run", "sprint", "walk"] and _recent_speed > STOP_FROM and _start_stop():
		state = "stop"
	if stance_suffix() != _stance and state in STANCE_STATES:
		_stance = stance_suffix()  # cambió de arma sin cambiar de estado: el clip sí cambia
		_play(state, LOCO_BLEND)
	var was_crouched := _state.begins_with("crouch")
	if state != _state:
		if was_crouched and not state.begins_with("crouch"):
			_play(state, STAND_UP_BLEND)
		elif state.begins_with("crouch") and not was_crouched:
			_play(state, CROUCH_BLEND)
		elif state == "block":
			_play(state, 0.16)
			_seek_time(BLOCK_HOLD)
		elif state in LOCOMOTION and _state in LOCOMOTION:
			var phase := _cycle_phase() if STRIDE_SPEED.has(_state) and STRIDE_SPEED.has(state) else -1.0
			_play(state, PUSH_STANCE_BLEND if state == "allomancy" else LOCO_BLEND)
			if phase >= 0.0:
				_seek_phase(phase)
		else:
			# Entrar y salir del aire con una mezcla más larga: el salto se ve más suave.
			var normal: float = 0.25 if state in ["air", "land"] or _state in ["air", "jump", "dash"] else FADE_EXIT
			_play(state, AIR_BLENDS.get(state, FLY_END_BLEND if _state == "fly" else normal))
		if clip_holds.has(state + _suffix(state)):
			var enters: bool = state == "crouch_idle" and not was_crouched
			_settling = enters
			if not enters:
				# Mismo clip que el estado anterior (salto -> aire, los dos de Regular_Jump): _play no mezcló y
				# el salto al cuadro fijo se vería de golpe.
				_begin_fade(AIR_BLENDS.get(state, 0.25))
			# Aplicando la pose ya: quieto (velocidad 0) no avanza y se quedaba en la pose en T del reposo.
			(_src_ap if _borrowed else _ap).seek(0.0 if enters else _current_length() * clip_holds[state + _suffix(state)], true)
	var speed := 1.0
	if clip_holds.has(state + _suffix(state)):
		_settling = _settling and _current_time() < _current_length() * clip_holds[state + _suffix(state)]
		speed = CROUCH_ENTER_SPEED if _settling else 0.0
	elif STRIDE_SPEED.has(state):
		var stride: float = ANIM_STRIDE.get(_resolved.get(state + _suffix(state), _resolved[state])["name"], STRIDE_SPEED[state])  # el clip que suena (con arma: Spear_Walk...)
		speed = clampf(move_speed / (stride * stride_scale), 0.6, 2.2)
	elif state == "block":
		speed = 1.0 if _block_kick > 0.0 else 0.0
	elif state in ["roll", "throw", "jump", "fly_launch", "land", "dash", "climb", "pickup", "stop"] or state.begins_with("attack") 			or (_spell > 0.0 and state == _spell_state):
		speed = _oneshot_speed
	if _borrowed and _src_ap:
		_src_ap.advance(dt * speed)
		_take_root_motion()  # antes de copiar la pose: si no, el avance del donante también mueve el cuerpo
		_retargeter.apply()
	elif _ap:
		_ap.advance(dt * speed)
		_take_root_motion()
	if state == "fly_launch" and _bones["hips"] >= 0:
		# El impulso del clip sube el cuerpo; acá lo sube el metal: la cadera no pasa de su altura de reposo.
		var hp := _skel.get_bone_pose_position(_bones["hips"])
		hp.y = minf(hp.y, _skel.get_bone_rest(_bones["hips"]).origin.y)
		_skel.set_bone_pose_position(_bones["hips"], hp)
	_apply_fade(dt)
	if not _upper.is_empty():
		_apply_upper(dt)
	_apply_fist_hands(state)
	if not clips_only:
		_apply_flinch(dt)
		_apply_allomancy_pose(dt)
		_apply_open_arms()
		_apply_combat_arms(state, dt)
	_orient_shield()
	if not clips_only:
		_close_fists(state)
	_update_two_hand(dt, state)
	_update_foot_ik(dt, state)
	_track_strike(dt)
	_update_anchors()
	if cloak and _cloak_anchor.visible:
		cloak.drive(dt, body_velocity)


const STAND_UP_BLEND := 0.35
const CROUCH_BLEND := 0.45  # de parado a agachado se mezcla, no salta
const CROUCH_ENTER_SPEED := 0.8
var _settling := false  # bajando hasta el cuadro en el que se queda
## Sufijo del próximo salto: sale agachado (ver Player).
var next_jump := ""


func _current_time() -> float:
	var p := _src_ap if _borrowed else _ap
	return p.current_animation_position if p else 0.0


const STANCE_STATES := ["idle", "idle_armed", "walk", "run", "sprint"]
const TOP_RUN_SPEED := 10.0
var _stance := ""
var _variant := {}
## Clip con el puño cerrado: de ahí sale la mano sin arma al caminar, correr y saltar. "" = no toca las manos.
var fist_clip := ""
var _fist_pose: Array = []  # [hueso, giro]
const FIST_STATES := ["idle", "walk", "run", "sprint", "jump", "air", "land", "freefall", "roll", "dash"]
const FIST_WEIGHT := 0.8  # no del todo cerrada: una flexión natural


## Qué lleva en las manos, como sufijo del estado: "walk_daggers" reemplaza a "walk" si existe.
func stance_suffix() -> String:
	if move_speed > TOP_RUN_SPEED:
		return "_top"
	if relaxed:
		return ""
	match weapon:
		Weapon.DAGGERS:
			return "_daggers"
		Weapon.SWORD:
			return "_shield" if shield_up() else "_sword"
	return "_fist" if brace > 0.5 else ""


## El sufijo del clip de este estado: según el arma, o el que salió sorteado.
func _suffix(state: String) -> String:
	if state == "fly" and coin_flight:
		return "_coin"
	if state == "attack_air":
		if weapon == Weapon.NONE:
			return "_fist"
		return "" if weapon == Weapon.DAGGERS else ("_shield" if shield_up() else "_sword")
	return stance_suffix() if state in STANCE_STATES else String(_variant.get(state, ""))


## Toma la mano cerrada de un clip real, pasada al reposo de este esqueleto.
func _build_fist_pose() -> void:
	if fist_clip == "" or not _fist_pose.is_empty() or not _ensure_upper() or not _upper["ap"].has_animation(fist_clip):
		return
	var anim: Animation = _upper["ap"].get_animation(fist_clip)
	var src: Skeleton3D = _upper["rt"].src
	for t in anim.get_track_count():
		var name := String(anim.track_get_path(t).get_subname(0))
		if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D or not "Hand" in name or name.ends_with("Hand"):
			continue
		var d := _skel.find_bone(name)
		var s := src.find_bone(name)
		if d >= 0 and s >= 0:
			var q := anim.rotation_track_interpolate(t, anim.length * 0.5)
			_fist_pose.append([d, _skel.get_bone_rest(d).basis.get_rotation_quaternion() * (src.get_bone_rest(s).basis.get_rotation_quaternion().inverse() * q)])


func _apply_fist_hands(state: String) -> void:
	var hands_in: bool = state.begins_with("crouch") or (weapon == Weapon.NONE and state in FIST_STATES)
	if fist_clip == "" or not hands_in or _skel == null:
		return
	_build_fist_pose()
	for f: Array in _fist_pose:
		_skel.set_bone_pose_rotation(f[0], _skel.get_bone_pose_rotation(f[0]).slerp(f[1], FIST_WEIGHT))


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
	# Ya pegó y te movés: la recuperación se corta, si no los pies patinarían.
	if _attack > 0.0 and on_floor and move_speed > 1.5 and _attack < _attack_full - _attack_hit:
		_attack = 0.0
	if _attack > 0.0:
		return _state if _state.begins_with("attack") else "attack_fist"
	# La pose de guardia es para estar quieto; moviéndote camina con los brazos en guardia (_apply_combat_arms).
	if blocking and shield_up() and (_block_kick > 0.0 or move_speed < 0.3):
		return "block_shield_hit" if _block_kick > 0.0 else "block_shield"
	if blocking and move_speed < 0.3 and _resolved.get("block", {"name": ""})["name"] != "":
		return "block"
	if _throw > 0.0:
		return "throw"
	if _pickup > 0.0:
		return "pickup"
	if stagger > 0.6:
		return "hit"
	# Ya subiendo, sigue en la pose hasta el punto más alto (si no, cerca de la cima pasaría un rato a volar de frente).
	var rising: bool = body_velocity.y > (0.0 if _state == "fly_rise" else RISE_SPEED) and body_velocity.y >= Vector2(body_velocity.x, body_velocity.z).length() * 0.6 			and _resolved.get("fly_rise", {"name": ""})["name"] != ""
	# Héroes: subiendo, Ironman; arriba o bajando despacio, brazos abiertos; cayendo rápido, caída libre. Sin la pose
	# de "volando" ni la de despegue.
	var hero_flight: bool = _resolved.get("fly_rise", {"name": ""})["name"] != "" and _resolved.get("fly_glide", {"name": ""})["name"] != ""
	if hero_flight and (flying or coin_flight) and not on_floor and not near_ground:
		if rising:
			return "fly_rise"
		if body_velocity.y > -HERO_FREEFALL_SPEED or _resolved.get("freefall", {"name": ""})["name"] == "":
			return "fly_glide"
		return "freefall"
	if coin_flight and not on_floor and not near_ground:
		if rising:
			return "fly_rise"
		if body_velocity.y < COIN_DESCEND_SPEED:
			return "freefall"
		return "fly_glide" if _coin_t > COIN_GLIDE_AFTER else "fly"
	if flying and not on_floor and not near_ground and _resolved.get("fly", {"name": ""})["name"] != "":
		if rising:
			return "fly_rise"
		if body_velocity.y >= 0.0:
			return "fly_launch" if _launch > 0.0 else "fly"  # un metal corta el salto: vuela enseguida
		# bajando: la pose de caída (abajo)
	if _jump > 0.0:
		return "jump"
	if not on_floor and _air_time() > 0.15:
		return "freefall" if body_velocity.y < -FREEFALL_SPEED and not near_ground and _resolved.get("freefall", {"name": ""})["name"] != "" else "air"
	if _land > 0.0 and on_floor and move_speed < 3.0 and aim_target == null and aim_target_left == null:
		return "land"
	if _stop > 0.0 and on_floor and move_speed < 1.0 and not crouched and aim_target == null and aim_target_left == null:
		return "stop"
	if aim_target != null or aim_target_left != null:
		return "allomancy" if move_speed < 3.0 or pushed_on_floor else "run"
	if panic > 0.5 and move_speed > 0.5:
		return "flee"
	if crouched and on_floor:
		return "crouch_walk" if move_speed > 0.3 else "crouch_idle"
	if move_speed > SPRINT_SPEED:
		return "sprint"
	if move_speed > 3.2:
		return "run"
	if move_speed > 0.3:
		return "walk"
	return "idle_armed" if (weapon != Weapon.NONE and not relaxed) or brace > 0.5 else "idle"


func _air_time() -> float:
	if on_floor:
		_air_since = _t
	return _t - _air_since


func _play(state: String, blend: float, restart := false) -> void:
	# Agacharse o pararse cambia toda la pose: siempre se mezcla la pose, no el reproductor.
	var both_loco: bool = state in LOCOMOTION and _state in LOCOMOTION and state.begins_with("crouch") == _state.begins_with("crouch")
	_state = state
	# Sin animaciones propias (modelo recién rigueado) todo sale del donante.
	if _ap == null and retarget_from == "":
		return
	var info: Dictionary = _resolved.get(state, {"name": "", "borrowed": false})
	info = _resolved.get(state + _suffix(state), info)
	if info["name"] == "":
		info = _resolved.get("idle", info)
	if info["name"] == "":
		return
	var before := _src_ap if _borrowed else _ap
	_borrowed = info["borrowed"]
	var player := _ap
	if _borrowed:
		_ensure_donor(info.get("donor", 0))
		player = _src_ap
		if player == null:
			_borrowed = false
			return
	var anim: String = info["name"]
	# El vuelo con moneda trae su despegue al principio: se pasa una vez y se queda en la pose final.
	var looping: bool = state in LOOPING and not (state == "fly" and coin_flight)
	player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	# Volver a un clip de otro reproductor (p. ej. el reposo del donante, que quedó cargado) también se mezcla.
	if restart or player.current_animation != anim or player != before:
		# Misma fase del paso: mezcla el reproductor. Si el clip viene de otro donante, ese reproductor no tiene
		# de dónde mezclar y la pose saltaría: se mezcla la pose.
		if both_loco and not restart and player.current_animation != "" and player == before:
			player.play(anim, blend)
		else:
			_begin_fade(blend)
			player.play(anim, 0.0)
		if restart:
			player.seek(0.0, true)
		_root_prev = null


func _begin_fade(time: float) -> void:
	if _skel == null or not _near or time <= 0.0:
		return
	_fade_pose.resize(_skel.get_bone_count())
	for b in _fade_pose.size():
		_fade_pose[b] = _skel.get_bone_pose_rotation(b)
	if _bones["hips"] >= 0:
		_fade_hips = _skel.get_bone_pose_position(_bones["hips"])
	_fade_t = time
	_fade_len = time
	_fade_leg_t = time
	_fade_leg_len = time
	if _leg_bone.size() != _fade_pose.size():
		_leg_bone.resize(_fade_pose.size())
		for b in _leg_bone.size():
			var n := _skel.get_bone_name(b)
			_leg_bone[b] = 1 if b == _bones["hips"] or "Leg" in n or "Foot" in n or "Toe" in n else 0


func _apply_fade(dt: float) -> void:
	if (_fade_t <= 0.0 and _fade_leg_t <= 0.0) or _skel == null:
		return
	_fade_t -= dt
	_fade_leg_t -= dt
	var w := smoothstep(0.0, 1.0, clampf(_fade_t / _fade_len, 0.0, 1.0))
	var wl := smoothstep(0.0, 1.0, clampf(_fade_leg_t / _fade_leg_len, 0.0, 1.0))
	for b in _fade_pose.size():
		_skel.set_bone_pose_rotation(b, _skel.get_bone_pose_rotation(b).slerp(_fade_pose[b], wl if _leg_bone[b] == 1 else w))
	if _bones["hips"] >= 0:
		_skel.set_bone_pose_position(_bones["hips"], _skel.get_bone_pose_position(_bones["hips"]).lerp(_fade_hips, wl))


## Clip de ROOT_MOTION: el avance del root en este cuadro pasa del esqueleto al personaje (el
## CharacterBody3D de arriba, que choca con las paredes; si no hay, el rig mismo).
func _take_root_motion() -> void:
	var skel := _retargeter.src if _borrowed else _skel
	var root_bone := skel.find_bone("root") if _borrowed else _root_bone
	# Donante: solo los del esqueleto de ActionForge (en KayKit el root es otra cosa).
	if root_bone < 0 or (_borrowed and skel.find_bone("pelvis") < 0):
		return
	var now := skel.get_bone_pose_position(root_bone)
	# Siempre en reposo: al mezclar el final de un esquive con la siguiente, el root trae su avance.
	skel.set_bone_pose_position(root_bone, skel.get_bone_rest(root_bone).origin)
	if not _resolved.get(_state, {}).get("name", "") in ROOT_MOTION:
		_root_prev = null
		return
	if _root_prev != null:
		var step: Vector3 = skel.global_basis * (now - _root_prev)
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
		_hips_drop = move_toward(_hips_drop, _contact_drop(state), dt * (3.0 if state in GROUND_CONTACT else 1.0))
		_model.position.y = _model_y + _hips_drop / maxf(scale.y, 1e-4)
		return
	var space := get_world_3d().direct_space_state
	var ground := global_position.y  # el suelo de la animación
	var fwd := -global_basis.z.normalized()
	var drop := INF  # cuánto se mueve el cuerpo: baja para que llegue el pie más bajo, sube si los dos se hunden
	var goals: Array[Vector3] = []
	var anim_feet: Array[Vector3] = []
	for side in ["_l", "_r"]:
		anim_feet.append(BoneTools.bone_world_pos(_skel, _bones["foot" + side]) - Vector3(0, _hips_drop, 0))
	# Animaciones que dejan al personaje flotando (los dos pies arriba, p. ej. el reposo del Mistborn
	# a 10 cm): se apoya el pie más bajo. Más de GROUND_FLOAT ya es un salto a propósito.
	var float_target := 0.0
	var low := minf(anim_feet[0].y, anim_feet[1].y) - ground - _ankle
	if not state in IK_MOVING:
		if low > 0.04 and low < GROUND_FLOAT:
			float_target = low
	else:
		# Andando siempre hay un pie arriba (y corriendo, ratos con los dos): manda lo más bajo que pisa en la zancada.
		_move_low = low if low < _move_low else _move_low + dt * MOVE_LOW_RISE
		float_target = clampf(_move_low, 0.0, GROUND_FLOAT)
	_float_by = lerpf(_float_by, float_target, minf(dt * (8.0 if state in IK_MOVING else 3.0), 1.0))
	var float_by := _float_by
	for i in 2:
		var side: String = ["_l", "_r"][i]
		var foot := anim_feet[i]
		var rel := foot.y - ground - _ankle - float_by
		# Nunca por debajo del suelo; hundido apenas (el tobillo se dobla) se deja como está.
		var lift := rel if rel < 0.0 and rel > -SINK_OK else maxf(rel, 0.0)
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
	_hips_drop = lerpf(_hips_drop, clampf(drop, -FOOT_REACH, FOOT_REACH), minf(dt * 12.0, 1.0))
	_model.position.y = _model_y + _hips_drop / maxf(scale.y, 1e-4)
	for i in 2:
		_ik_targets[i].global_position = goals[i]


## Rodando, deslizando o tirado en el suelo (sin IK de pies): cuánto mover el cuerpo para que su punto más bajo
## apoye en el suelo de la animación. Los clips de otros esqueletos dejaban el cuerpo flotando o metido en el piso.
func _contact_drop(state: String) -> float:
	if not state in GROUND_CONTACT or not on_floor:
		return 0.0
	var low := INF
	for key in ["hips", "torso", "head", "hand_l", "hand_r", "calf_l", "calf_r", "foot_l", "foot_r", "upper_l", "upper_r"]:
		if _bones.get(key, -1) >= 0:
			low = minf(low, BoneTools.bone_world_pos(_skel, _bones[key]).y - _hips_drop)
	# El hueso va por dentro: la superficie del cuerpo queda unos cm más abajo.
	return clampf(global_position.y + BODY_PAD - low, -FOOT_REACH, FOOT_REACH) if low < INF else 0.0


func _floor_hit(space: PhysicsDirectSpaceState3D, at: Vector3, ground: float) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, ground + FOOT_REACH, at.z),
			Vector3(at.x, ground - FOOT_REACH, at.z), Props.LAYER_WORLD))


# ---------------------------------------------------------------- Poses de alomancia

func _apply_flinch(dt: float) -> void:
	if _skel == null or _bones["torso"] < 0 or _flinch.length_squared() < 1e-4:
		return
	_flinch = _flinch.lerp(Vector3.ZERO, 1.0 - exp(-dt * FLINCH_RETURN))
	var torso: int = _bones["torso"]
	var now := _skel.global_basis.orthonormalized() * (_skel.get_bone_global_pose(torso).basis.orthonormalized() * Vector3.UP)
	BoneTools.aim(_skel, torso, now + _flinch)


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


## Los dos brazos abiertos hacia su costado, algo adelantados y con los codos doblados hacia delante;
## entran y salen suave (en un 30 % de la duración cada uno).
func _apply_open_arms() -> void:
	if _arms_open <= 0.0 or _skel == null:
		return
	var edge := _arms_open_len * 0.3
	var w := smoothstep(0.0, 1.0, clampf(minf(_arms_open_len - _arms_open, _arms_open) / edge, 0.0, 1.0))
	var torso: int = _bones["torso"]
	var center := BoneTools.bone_world_pos(_skel, torso) if torso >= 0 else global_position
	var up := global_basis.orthonormalized() * Vector3.UP
	var right := BoneTools.bone_world_pos(_skel, _bones["upper_r"]) - center
	var forward := up.cross(right - up * right.dot(up)).normalized()
	for side in ["l", "r"]:
		var upper: int = _bones["upper_" + side]
		var lower: int = _bones["lower_" + side]
		if upper < 0 or lower < 0:
			continue
		var out := BoneTools.bone_world_pos(_skel, upper) - center
		out = (out - up * out.dot(up)).normalized()
		var arm := (out + up * _arms_lift + forward * 0.3).normalized()
		BoneTools.aim(_skel, upper, arm, w)
		BoneTools.aim(_skel, lower, arm.slerp(forward + up * _arms_lift, _arms_bend).normalized(), w)


## Brazos de combate hechos a mano: los clips de KayKit copiados a este esqueleto abren los brazos hacia los
## costados. Caminando en guardia: las dos manos arriba. Escudo: el brazo izquierdo lo lleva delante y lo sube al bloquear.
func _apply_combat_arms(state: String, dt: float) -> void:
	var shielded := shield_up() and state in SHIELD_ARM_STATES
	var guard_walk := blocking and state in ["walk", "run"]
	_combat_arms = move_toward(_combat_arms, 1.0 if shielded or guard_walk else 0.0, dt * 9.0)
	if _combat_arms <= 0.0 or _skel == null or _bones["torso"] < 0:
		return
	var center := BoneTools.bone_world_pos(_skel, _bones["torso"])
	var up := global_basis.orthonormalized() * Vector3.UP
	var right := BoneTools.bone_world_pos(_skel, _bones["upper_r"]) - center
	var fwd := up.cross(right - up * right.dot(up)).normalized()
	right = fwd.cross(up).normalized()
	for side in ["l", "r"]:
		var out := right if side == "r" else -right
		var upper: Vector3
		var lower: Vector3
		if guard_walk and not shielded:
			upper = fwd * 0.45 - up * 0.8 + out * 0.3
			lower = fwd * 0.55 + up * 0.8 - out * 0.3
		elif side == "l":
			if state.begins_with("block") or guard_walk:
				upper = fwd * 0.7 - up * 0.45 + out * 0.3
				lower = fwd * 0.25 + up * 0.5 - out * 0.8
			else:
				upper = fwd * 0.35 - up * 0.85 + out * 0.3
				lower = fwd * 0.9 + up * 0.15 - out * 0.3
		else:
			continue
		BoneTools.aim(_skel, _bones["upper_" + side], upper.normalized(), _combat_arms)
		BoneTools.aim(_skel, _bones["lower_" + side], lower.normalized(), _combat_arms)


## El escudo sigue a la mano pero no a su giro: siempre de pie y de cara hacia delante-izquierda (el reborde y
## la cara de afuera se ven igual en cualquier animación, ninguna fue hecha para llevarlo).
func _orient_shield() -> void:
	if _shield_node == null or not _shield_node.visible:
		return
	var b := global_basis.orthonormalized()
	var face := (-b.z * 0.8 - b.x * 0.6).normalized()
	if _skel and _bones["lower_l"] >= 0 and _bones["hand_l"] >= 0:
		# Atado al antebrazo: va con el brazo (colgando, levantado para bloquear) y mira hacia afuera del cuerpo.
		var elbow := BoneTools.bone_world_pos(_skel, _bones["lower_l"])
		var hand := BoneTools.bone_world_pos(_skel, _bones["hand_l"])
		var along := (hand - elbow).normalized()
		var out := (face - along * face.dot(along)).normalized()
		if out.length_squared() > 0.5:
			_shield_node.global_basis = Basis(along.cross(out).normalized(), along, out).scaled(Vector3.ONE * SHIELD_SCALE)
			_shield_node.global_position = elbow.lerp(hand, 0.6) + out * 0.08
			return
	_shield_node.global_basis = Basis(b.y.cross(face).normalized(), b.y, face).scaled(Vector3.ONE * SHIELD_SCALE)
	_shield_node.global_position = _shield_node.get_parent().global_position + face * 0.14  # la mano queda detrás


## Cierra las manos al pegar con los puños y la izquierda al llevar escudo (los clips de KayKit no mueven los dedos).
func _close_fists(state: String) -> void:
	if _skel == null:
		return
	var punching := state.begins_with("attack_fist")
	for side in ["l", "r"]:
		var closed: bool = punching or (side == "l" and _shield_node != null and _shield_node.visible)
		if not closed and not _fist_closed.get(side, false):
			continue
		_fist_closed[side] = closed
		for finger in ["index", "middle", "ring", "pinky", "thumb"]:
			for joint in 3:
				var bone := _skel.find_bone("%s_0%d_%s" % [finger, joint + 1, side])
				if bone < 0:
					continue
				var rest := _skel.get_bone_rest(bone).basis.get_rotation_quaternion()
				var curl := FINGER_CURL * (0.4 if finger == "thumb" else 1.0)
				_skel.set_bone_pose_rotation(bone, rest * Quaternion(Vector3(0, 0, 1), curl) if closed else rest)


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
