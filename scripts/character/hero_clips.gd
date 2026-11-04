class_name HeroClips
## Qué clip del paquete de Meshy (MistbornHood.glb) usa cada acción de Kelsier, Vin y el terrisano. Ningún otro movimiento:
## un estado que no está acá se queda en la guardia (ver ModelRig.clips_only).
## Faltan en el paquete: recibir un golpe, colgarse, agacharse, agarrar cosas, beber y abrir puertas.

const STATES := {
	"idle": ["Combat_Stance"], "idle_armed": ["Combat_Stance"],
	"walk": ["Walking"], "run": ["Running"], "sprint": ["RunFast"], "flee": ["Running"],
	"crouch_idle": ["Combat_Stance"], "crouch_walk": ["Walking"],
	"jump": ["Regular_Jump"], "air": ["Regular_Jump"], "land": ["Regular_Jump"], "hang": ["Regular_Jump"], "climb": ["Regular_Jump"],
	"freefall": ["Jump_with_Arms_Open"], "fall_roll": ["Roll_Dodge_1"],
	"roll": ["Roll_Dodge"], "dash": ["Stand_Dodge"], "dodge_left": ["Stand_Dodge"], "dodge_right": ["Stand_Dodge"],
	"slide": ["slide_light"], "swim": ["Swim_Forward"], "swim_idle": ["Swim_Idle"], "down": ["Dead"],
	"block": ["Block5"], "block_shield": ["Block5"], "block_shield_hit": ["Block5"],
	"attack_fist": ["Punch_Combo"], "attack_fist_1": ["Punch_Combo"], "attack_fist_2": ["Punch_Forward_with_Both_Fists"],
	"attack_fist_3": ["Axe_Spin_Attack"],
	"attack_sword": ["Weapon_Combo"], "attack_sword_1": ["Weapon_Combo"], "attack_sword_2": ["Weapon_Combo"],
	"attack_shield": ["Weapon_Combo_1"], "attack_shield_1": ["Weapon_Combo_1"], "attack_shield_2": ["Weapon_Combo_1"],
	"attack_daggers": ["Triple_Combo_Attack"], "attack_daggers_1": ["Triple_Combo_Attack"], "attack_daggers_2": ["Triple_Combo_Attack"],
	"attack_daggers_3": ["Double_Blade_Spin"],
	"attack_air": ["Sword_Judgment"],
	"throw": ["mage_soell_cast_4"], "allomancy": ["mage_soell_cast_3"],
	"coin_wave": ["mage_soell_cast_2"], "coin_shield": ["Charged_Spell_Cast"],
}

## Tramo de un clip que usa cada estado: [desde, hasta, golpe]. "golpe" es el pico de velocidad de la mano, medido en el clip.
## Los combos se reparten entre los pasos del combo.
const CUTS := {
	"jump": [0.12, 0.6], "land": [0.62, 1.0], "climb": [0.2, 0.5],
	"attack_fist": [0.1, 0.38, 0.27], "attack_fist_1": [0.38, 0.7, 0.51], "attack_fist_2": [0.1, 0.6, 0.4], "attack_fist_3": [0.0, 0.55, 0.37],
	"attack_sword": [0.05, 0.27, 0.18], "attack_sword_1": [0.27, 0.47, 0.35], "attack_sword_2": [0.47, 0.9, 0.61],
	"attack_shield": [0.08, 0.35, 0.23], "attack_shield_1": [0.35, 0.58, 0.48], "attack_shield_2": [0.58, 1.0, 0.7],
	"attack_daggers": [0.05, 0.27, 0.18], "attack_daggers_1": [0.27, 0.44, 0.35], "attack_daggers_2": [0.44, 0.75, 0.52],
	"attack_daggers_3": [0.05, 0.4, 0.27],
	"attack_air": [0.1, 0.4, 0.23],
	"throw": [0.1, 0.7, 0.24], "coin_wave": [0.0, 0.7, 0.41], "coin_shield": [0.1, 0.8, 0.65],
}

## Estados que se quedan quietos en un cuadro del clip: el aire no tiene un clip que se repita. Fracción del clip.
const HOLDS := {"air": 0.45, "hang": 0.45, "freefall": 0.55, "slide": 0.25, "allomancy": 0.5}

## Gestos de poderes en la mitad de arriba del cuerpo: nombre en el juego -> [clip, desde, hasta, golpe].
const SKILLS := {
	"steel_push": ["Charged_Spell_Cast_1", 0.1, 0.45, 0.25],
	"iron_pull": ["mage_soell_cast_3", 0.1, 0.6, 0.27],
	"pull_heavy": ["mage_soell_cast_3", 0.1, 0.6, 0.27],
	"coin_flick": ["mage_soell_cast", 0.15, 0.7, 0.56],
	"coin_wave": ["mage_soell_cast_2", 0.1, 0.7, 0.41],
	"burn_focus": ["mage_soell_cast_6", 0.1, 0.45, 0.35],
	"pewter_flex": ["Charged_Spell_Cast", 0.1, 0.45, 0.23],
}
