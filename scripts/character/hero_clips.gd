class_name HeroClips
## Qué clip de Meshy (MistbornHood.glb, y si no Vin.glb) usa cada acción de los personajes elegibles. Ningún otro movimiento:
## un estado que no está acá se queda en la guardia (ver ModelRig.clips_only).
## Falta un clip de subir un borde: "climb" sigue siendo un tramo de salto.

## Postura y caminata según lo que tenga en las manos (ver ModelRig.stance_suffix). Los puños van en guardia solo peleando.
const STANCES := {
	"idle_armed_sword": ["Alert"], "walk_sword": ["Spear_Walk"],  # Combat_Stance es de puños: la espada colgaba hacia atrás
	"idle_armed_shield": ["Alert"], "walk_shield": ["Spear_Walk"],  # Walk_Fight_Forward pisa 0,64 m: a 1,6 m/s pedía 2,5× y el pie patinaba
	"idle_armed_daggers": ["Lower_Weapon_Look_Raise"],
  # con dagas camina normal (walk)
}
const FISTS := {"idle_armed_fist": ["punch_cross"], "walk_fist": ["Walking"]}
## A toda velocidad (peltre avivado), con cualquier arma. Ver ModelRig.stance_suffix.
const TOP_SPEED := {"sprint_top": ["RunFast"]}  # Lean_Forward_Sprint va a 2,5 m/s: a 11 m/s el pie patinaba 5 m/s
## Clip del que sale la mano cerrada para caminar y correr sin arma (ver ModelRig.fist_clip).
const FIST_HAND := "Punch_Pose"


## Recibir un golpe: sirven para cualquier personaje de Meshy, también NPC y enemigos.
const HITS := {
	"hit": ["Hit_Reaction"], "hit_head": ["Hit_Reaction_to_Waist"], "hit_knockback": ["Step_Back"],
	"hit_front": ["Step_Back"], "hit_back": ["Slap_Reaction"], "hit_left": ["Slap_Reaction"], "hit_right": ["Slap_Reaction"],
	"get_up": ["Arise"],
}
const HIT_CUTS := {
	"hit": [0.0, 0.7], "hit_head": [0.0, 0.7],
	"hit_back": [0.1, 0.5], "hit_left": [0.1, 0.5], "hit_right": [0.1, 0.5],
}

const STATES := {
	"idle": ["Idle_11"], "idle_armed": ["Combat_Stance"],
	"walk": ["Walking"], "run": ["Running"], "sprint": ["RunFast"], "flee": ["Running"],
	"crouch_idle": ["crouch_idle_mx"],  # agachado quieto: "Crouch Idle" de Mixamo (AFClips); el de Meshy tenía los brazos como con arco
	 "crouch_walk": ["Cautious_Crouch_Walk_Forward_inplace"],
	"jump": ["Regular_Jump"], "air": ["Regular_Jump"], "land": ["Regular_Jump"], "hang": ["Bar_Hang_Idle"], "climb": ["Regular_Jump"],
	"freefall": ["Dive_Down_and_Land"], "fly": ["Vuelo_B"], "fly_rise": ["idle_loop_adjusted"], "fly_coin": ["Vuelo_Moneda"], "fly_glide": ["Fall2"], "fly_launch": ["Vuelo_A"], "slam": ["Charged_Ground_Slam"], "fall_roll": ["Roll_Dodge_1"],
	"roll": ["Roll_Dodge"], "dodge_left": ["Stand_Dodge"], "dodge_right": ["Stand_Dodge"],
	"slide": ["slide_light"], "swim": ["Swim_Forward"], "swim_idle": ["Swim_Idle"], "down": ["Dead"],
	"block": ["Block5"], "block_shield": ["Block3"], "block_shield_hit": ["Block3"],  # Block5 dejaba el escudo al costado
	"attack_fist": ["Punch_Combo"], "attack_fist_1": ["Punch_Combo"], "attack_fist_2": ["Punch_Combo_2"],
	"attack_fist_3": ["Step_in_High_Kick"],
	"attack_sword": ["Weapon_Combo"], "attack_sword_1": ["Weapon_Combo"], "attack_sword_2": ["Weapon_Combo_2"], "attack_sword_3": ["Charged_Slash"], "attack_sword_4": ["Weapon_Combo"],
	"attack_shield": ["Weapon_Combo_1"], "attack_shield_1": ["Weapon_Combo_1"], "attack_shield_2": ["Shield_Push_Left"],
	"attack_daggers": ["Right_Hand_Sword_Slash"], "attack_daggers_1": ["Triple_Combo_Attack"], "attack_daggers_2": ["Triple_Combo_Attack"],
	"attack_daggers_3": ["Double_Blade_Spin"],
	"attack_air": ["Double_Blade_Spin"], "attack_air_fist": ["Rising_Flying_Kick"], "attack_air_sword": ["Charged_Upward_Slash"], "attack_air_shield": ["Sword_Judgment"],
	"throw": ["mage_soell_cast_4"], "allomancy": ["mage_soell_cast_3"],
	"coin_wave": ["mage_soell_cast_2"], "coin_shield": ["Charged_Spell_Cast"],
	"pickup": ["Collect_Object"],
	"jump_crouch": ["Jump_and_Grab_Wall"], "jump_double": ["Parkour_Vault_3"],
	
	"roll_slide": ["slide_light"], "dash": ["Roll_Dodge"],
	"stop": ["Sprint_and_Sudden_Stop"],  # frenar desde la carrera con el pie que toca (ver ModelRig._start_stop)
}

## fly_rise (subiendo): Idle Loop de ActionForge retocado (brazos -48° afuera y -18° atrás, cabeza +25°, postura -8°),
## pose tipo Ironman: derecho, brazos abajo y un poco abiertos. Piernas juntas y estiradas con una capa de rotaciones
## en el cuadro 1 (ejes globales): thigh_l (10, 0, 12), thigh_r (-19, -25, -15), foot_l X 30, foot_r X 42 (puntas abajo).

## Tramo de un clip que usa cada estado: [desde, hasta, golpe]. "golpe" es el pico de velocidad de la mano, medido en el clip;
## en los tajos anchos de espada, cuando la hoja cruza por delante (medido en Vin con tools/anim_check).
## Los combos se reparten entre los pasos del combo.
const CUTS := {
	"jump": [0.12, 0.6], "land": [0.62, 1.0], "climb": [0.2, 0.5],
	"attack_fist": [0.1, 0.38, 0.27], "attack_fist_1": [0.38, 0.7, 0.51], "attack_fist_2": [0.28, 0.55, 0.42], "attack_fist_3": [0.0, 0.8, 0.4],
	"attack_sword": [0.05, 0.27, 0.18], "attack_sword_1": [0.27, 0.47, 0.35], "attack_sword_2": [0.12, 0.38, 0.245], "attack_sword_3": [0.2, 0.8, 0.55], "attack_sword_4": [0.47, 0.9, 0.61],
	"attack_shield": [0.08, 0.35, 0.23], "attack_shield_1": [0.35, 0.58, 0.48], "attack_shield_2": [0.1, 0.6, 0.3],
	"attack_daggers": [0.05, 0.7, 0.35], "attack_daggers_1": [0.27, 0.44, 0.35], "attack_daggers_2": [0.44, 0.75, 0.52],
	"attack_daggers_3": [0.05, 0.32, 0.27],  # después del 32 % el giro se queda quieto agachado
	"attack_air": [0.05, 0.32, 0.27], "attack_air_fist": [0.0, 0.8, 0.35], "attack_air_sword": [0.1, 0.6, 0.32], "attack_air_shield": [0.1, 0.4, 0.23],
	"throw": [0.1, 0.7, 0.24], "coin_wave": [0.0, 0.7, 0.41], "coin_shield": [0.1, 0.8, 0.65],
	"pickup": [0.2, 0.7],
	"jump_crouch": [0.12, 0.55], "jump_double": [0.12, 0.8], "fly_launch": [0.1, 0.45], "slam": [0.1, 0.95, 0.55],
	"roll_slide": [0.05, 0.85], "dash": [0.25, 0.8],
}

## Estados que se quedan quietos en un cuadro del clip: el aire no tiene un clip que se repita. Fracción del clip.
const HOLDS := {"idle_armed_fist": 0.0, "fly_glide": 0.95, "air": 0.55, "freefall": 0.8, "slide": 0.25, "allomancy": 0.5}

## Cuánto puede girar el pecho siguiendo al clip en cada poder (grados; si no está, ModelRig.CHEST_TWIST_MAX).
## Encender metal: el clip gira el cuerpo de -43° a +44° y Vin quedaba de espaldas en un gesto de concentración.
const CHEST_TWIST := {"burn_focus": 20.0}

## Gestos de poderes en la mitad de arriba del cuerpo: nombre en el juego -> [clip, desde, hasta, golpe].
const SKILLS := {
	# Empuje: los dos brazos derecho adelante a la altura del hombro (el de antes bajaba los brazos a los costados).
	"steel_push": ["Punch_Forward_with_Both_Fists", 0.3, 0.6, 0.45],
	"iron_pull": ["mage_soell_cast_3", 0.1, 0.6, 0.27],
	"pull_heavy": ["mage_soell_cast_3", 0.1, 0.6, 0.27],
	# ActionForge: Overhandthrow con el pecho y la cabeza enderezados (Adjust: pecho -20°, cabeza +20°), desde lo alto
	# del armado hasta que termina el tirón (después se encorva mucho), a menos de la mitad de velocidad: entero va demasiado rápido.
	# Suelta en el cuadro 12 (29 %). Al terminar se funde en 0,5 s con la pose de empujar la moneda.
	# Armado más rápido (séptimo valor: velocidad hasta el tiro) y brazo izquierdo con 0,18 s de retraso (octavo).
	"coin_flick": ["overhandthrow_adjusted", 0.12, 0.36, 0.29, 0.47, 0.5, 0.81, 0.18],
	## Ráfaga: gesto lento que se frena al final (quinto valor: velocidad fija del clip; sexto, si está: se queda en el
	## último cuadro y se funde en esos segundos, sin la pausa de SLOW_SKILL_HOLD).
	# Ráfaga: lanzamiento de revés tipo kunai: "Frisbee Throw" de Mixamo (HeroMixamoXBot). La mano derecha va al lado
	# izquierdo del pecho (codo ~105°, 30-37 %) y barre paralela al piso hacia afuera estirando el codo hasta ~166°;
	# las monedas salen al 44 %. A su velocidad. Termina al 47 %: hasta el 50 % el brazo quedaba estirado y colgando.
	# El clip gira todo el cuerpo; el pecho lo acompaña con ModelRig._twist_chest (si no, la mano pasaba por la espalda).
	"coin_wave": ["frisbee_throw_mx", 0.27, 0.47, 0.44, 1.0, 0.25],
	"field": ["mage_soell_cast_1", 0.2, 0.65, 0.5],
	"coin_shield": ["mage_soell_cast_6", 0.1, 0.7, 0.4],
	"coin_magnet": ["mage_soell_cast_7", 0.3, 0.9, 0.55],
	"spear": ["mage_soell_cast_3", 0.1, 0.6, 0.27],
	"burn_focus": ["mage_soell_cast_6", 0.1, 0.45, 0.35],
	"pewter_flex": ["Charged_Spell_Cast", 0.1, 0.45, 0.23],
	"drink": ["Stand_and_Drink", 0.2, 0.6, 0.55],  # hasta que la mano llega a la boca (57 %)
}
