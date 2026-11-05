class_name HeroClips
## Qué clip de Meshy (MistbornHood.glb, y si no Vin.glb) usa cada acción de los personajes elegibles. Ningún otro movimiento:
## un estado que no está acá se queda en la guardia (ver ModelRig.clips_only).
## Falta un clip de subir un borde: "climb" sigue siendo un tramo de salto.

## Postura y caminata según lo que tenga en las manos (ver ModelRig.stance_suffix). Los puños van en guardia solo peleando.
const STANCES := {
	"idle_armed_sword": ["Combat_Stance"], "walk_sword": ["Spear_Walk"],
	"idle_armed_shield": ["Combat_Stance"], "walk_shield": ["Walk_Fight_Forward"],
	"idle_armed_daggers": ["Lower_Weapon_Look_Raise"], "walk_daggers": ["Sneaky_Walk"],
}
const FISTS := {"idle_armed_fist": ["Block1"], "walk_fist": ["Walking"]}
## A toda velocidad (peltre avivado), con cualquier arma. Ver ModelRig.stance_suffix.
const TOP_SPEED := {"sprint_top": ["Lean_Forward_Sprint"]}
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
	"crouch_idle": ["Block10"], "crouch_walk": ["Cautious_Crouch_Walk_Forward_inplace"],
	"jump": ["Regular_Jump"], "air": ["Regular_Jump"], "land": ["Regular_Jump"], "hang": ["Bar_Hang_Idle"], "climb": ["Regular_Jump"],
	"freefall": ["Dive_Down_and_Land"], "fly": ["Idle_8"], "fall_roll": ["Roll_Dodge_1"],
	"roll": ["Roll_Dodge"], "dodge_left": ["Stand_Dodge"], "dodge_right": ["Stand_Dodge"],
	"slide": ["slide_light"], "swim": ["Swim_Forward"], "swim_idle": ["Swim_Idle"], "down": ["Dead"],
	"block": ["Block5"], "block_shield": ["Block5"], "block_shield_hit": ["Block5"],
	"attack_fist": ["Punch_Combo"], "attack_fist_1": ["Punch_Combo"], "attack_fist_2": ["Punch_Combo_2"],
	"attack_fist_3": ["Step_in_High_Kick"],
	"attack_sword": ["Weapon_Combo"], "attack_sword_1": ["Weapon_Combo"], "attack_sword_2": ["Thrust_Slash"], "attack_sword_3": ["Charged_Slash"], "attack_sword_4": ["Weapon_Combo"],
	"attack_shield": ["Weapon_Combo_1"], "attack_shield_1": ["Weapon_Combo_1"], "attack_shield_2": ["Shield_Push_Left"],
	"attack_daggers": ["Right_Hand_Sword_Slash"], "attack_daggers_1": ["Triple_Combo_Attack"], "attack_daggers_2": ["Triple_Combo_Attack"],
	"attack_daggers_3": ["Double_Blade_Spin"],
	"attack_air": ["Double_Blade_Spin"], "attack_air_fist": ["Rising_Flying_Kick"], "attack_air_sword": ["Charged_Upward_Slash"], "attack_air_shield": ["Sword_Judgment"],
	"throw": ["mage_soell_cast_4"], "allomancy": ["mage_soell_cast_3"],
	"coin_wave": ["mage_soell_cast_2"], "coin_shield": ["Charged_Spell_Cast"],
	"pickup": ["Collect_Object"],
	"jump_crouch": ["Jump_and_Grab_Wall"], "jump_double": ["Parkour_Vault_3"],
	
	"roll_slide": ["slide_light"], "dash": ["Roll_Dodge"],
}

## Tramo de un clip que usa cada estado: [desde, hasta, golpe]. "golpe" es el pico de velocidad de la mano, medido en el clip.
## Los combos se reparten entre los pasos del combo.
const CUTS := {
	"jump": [0.12, 0.6], "land": [0.62, 1.0], "climb": [0.2, 0.5],
	"attack_fist": [0.1, 0.38, 0.27], "attack_fist_1": [0.38, 0.7, 0.51], "attack_fist_2": [0.28, 0.55, 0.42], "attack_fist_3": [0.0, 0.8, 0.4],
	"attack_sword": [0.05, 0.27, 0.18], "attack_sword_1": [0.27, 0.47, 0.35], "attack_sword_2": [0.1, 0.55, 0.3], "attack_sword_3": [0.2, 0.8, 0.52], "attack_sword_4": [0.47, 0.9, 0.61],
	"attack_shield": [0.08, 0.35, 0.23], "attack_shield_1": [0.35, 0.58, 0.48], "attack_shield_2": [0.1, 0.6, 0.3],
	"attack_daggers": [0.05, 0.7, 0.35], "attack_daggers_1": [0.27, 0.44, 0.35], "attack_daggers_2": [0.44, 0.75, 0.52],
	"attack_daggers_3": [0.05, 0.4, 0.27],
	"attack_air": [0.05, 0.4, 0.27], "attack_air_fist": [0.0, 0.8, 0.35], "attack_air_sword": [0.1, 0.6, 0.32], "attack_air_shield": [0.1, 0.4, 0.23],
	"throw": [0.1, 0.7, 0.24], "coin_wave": [0.0, 0.7, 0.41], "coin_shield": [0.1, 0.8, 0.65],
	"pickup": [0.2, 0.7],
	"jump_crouch": [0.12, 0.55], "jump_double": [0.12, 0.8],
	"roll_slide": [0.05, 0.85], "dash": [0.25, 0.8],
}

## Estados que se quedan quietos en un cuadro del clip: el aire no tiene un clip que se repita. Fracción del clip.
const HOLDS := {"crouch_idle": 0.9, "air": 0.45, "freefall": 0.8, "slide": 0.25, "allomancy": 0.5}

## Gestos de poderes en la mitad de arriba del cuerpo: nombre en el juego -> [clip, desde, hasta, golpe].
const SKILLS := {
	"steel_push": ["Charged_Spell_Cast_1", 0.1, 0.45, 0.25],
	"iron_pull": ["mage_soell_cast_3", 0.1, 0.6, 0.27],
	"pull_heavy": ["mage_soell_cast_3", 0.1, 0.6, 0.27],
	"coin_flick": ["mage_soell_cast", 0.15, 0.7, 0.56],
	"coin_wave": ["mage_soell_cast_2", 0.1, 0.7, 0.41],
	"burn_focus": ["mage_soell_cast_6", 0.1, 0.45, 0.35],
	"pewter_flex": ["Charged_Spell_Cast", 0.1, 0.45, 0.23],
	"drink": ["Stand_and_Drink", 0.2, 0.42, 0.3],
}
