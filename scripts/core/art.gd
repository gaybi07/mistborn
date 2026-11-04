class_name Art
## Estilo de los personajes. Cambia `style` para elegir:
##   "procedural" -> cuerpos hechos con primitivas (HumanoidRig)
##   "kaykit"     -> KayKit Adventurers (CC0): jugador = pícaro encapuchado verde
##   "quaternius" -> Quaternius RPG Characters (CC0): jugador = pícaro encapuchado rojo
## Todos los rigs tienen la misma interfaz, así que el juego funciona igual con cualquiera.

static var style := "quaternius"
## Personaje propio del jugador (de PLAYER_MODELS) o "" para usar el del estilo.
static var player_model := "encapuchado"
## "noche" (bruma) o "dia" (sol rojo de Luthadel). Se cambia en el juego con F3.
static var lighting := "noche"
## "despejado", "lluvia" o "ceniza". F4.
static var weather := "despejado"
## "ninguna", "poca" o "mucha". Ctrl+F5.
static var fog := "mucha"
## Bruma negra (nubes bajas y jirones a ras de suelo), ceniza que flota siempre en el aire y relámpagos con lluvia.
## Se apagan desde el menú (Esc, pestaña Mundo); la lluvia y la ceniza de tormenta se apagan con el clima.
static var mist := true
static var ash_fall := true
static var lightning := true
## Sube cada vez que cambia el ambiente (para que el estaño recalcule sus valores base).
static var env_version := 0

## Color del traje y la capucha del jugador, para distinguirse en las partidas con otros. "negro" es
## el del modelo; los demás lo tiñen (HumanoidRig.set_suit). Se elige al empezar por primera vez y
## con P en el juego (SuitPicker), y se guarda en SUIT_FILE.
const SUITS := {"negro": Color(0.17, 0.19, 0.24), "blanco": Color(0.9, 0.89, 0.86),
		"rojo": Color(0.62, 0.06, 0.05), "azul": Color(0.07, 0.2, 0.66)}
const SUIT_FILE := "user://jugador.cfg"
static var suit := "negro"
## false hasta que se elige personaje por primera vez (entonces se muestra SuitPicker al empezar).
static var suit_chosen := false


## Lee el color guardado (si nunca se eligió, queda el negro y suit_chosen en false).
static func load_suit() -> void:
	var cfg := ConfigFile.new()
	var loaded := cfg.load(SUIT_FILE) == OK
	var s: String = cfg.get_value("jugador", "traje", "negro") if loaded else "negro"
	suit = s if SUITS.has(s) else "negro"
	var who: String = cfg.get_value("jugador", "personaje", "") if loaded else ""
	suit_chosen = who in HEROES
	if suit_chosen:
		player_model = who


static func save_suit(s: String) -> void:
	suit = s
	_save_player()


static func save_character(who: String) -> void:
	player_model = who
	_save_player()


static func _save_player() -> void:
	suit_chosen = true
	var cfg := ConfigFile.new()
	cfg.set_value("jugador", "traje", suit)
	cfg.set_value("jugador", "personaje", player_model)
	cfg.save(SUIT_FILE)


## Más lejos que esto no se dibuja lo chico (casas, árboles, gente, muebles): por zonas, para que
## cada cuadro dibuje menos. La niebla tiene que tapar todo antes (ver fog_floor): nunca se ve dónde
## termina lo dibujado. Los montes, la muralla de Kredik Shaw y su silueta no se recortan.
const DRAW_FAR := 250.0
## Anillo de bruma alrededor de la cámara: más lejos no se ve nada, ni los montes ni Kredik Shaw
## (solo la lava de los volcanes). Los sombreadores de montes y de Kredik Shaw usan el mismo valor
## (mist_ring).
const MIST_RING := 600.0


## Densidad mínima de la niebla de distancia para que a DRAW_FAR ya no se vea nada (≈2 % de luz).
static func fog_floor() -> float:
	return 3.9 / DRAW_FAR


## Distancia (m) a la que alguien ve a otra persona a simple vista, sin estaño.
## Es lo que usan los alománticos para detectarte; la niebla y el clima la recortan.
static func sight_range() -> float:
	var r := 16.0 if lighting == "noche" else 38.0
	match fog:
		"ninguna":
			r *= 2.2
		"poca":
			r *= 1.6
		_:
			r *= 0.65
	match weather:
		"lluvia":
			r *= 0.75
		"ceniza":
			r *= 0.7
	return r

const KAYKIT := "res://assets/kaykit/characters/%s.glb"
const QUATERNIUS := "res://assets/quaternius/characters/%s.glb"

## Por estilo: modelo del jugador, de los guardias y de la gente (skaa y nobles).
const SETS := {
	"kaykit": {
		"path": KAYKIT,
		"flip": true,  # los modelos miran hacia +Z
		"player": "Rogue_Hooded",
		"guard": "Knight",
		"guard_items": ["Sword", "Shield"],
		"citizens": ["Barbarian", "Rogue", "Mage"],
		"nobles": ["Mage", "Knight"],
		# tipo de alomántico -> [modelo, tono, accesorios visibles]
		"allomancers": {
			"thug": ["Barbarian", Color(0.85, 0.75, 0.7), ["Axe"]],
			"coinshot": ["Rogue", Color(0.75, 0.8, 0.9), []],
			"lurcher": ["Rogue", Color(0.7, 0.72, 0.8), []],
			"tineye": ["Mage", Color(0.75, 0.78, 0.7), []],
			"smoker": ["Mage", Color(0.8, 0.65, 0.55), []],
			"seeker": ["Knight", Color(0.75, 0.7, 0.6), []],
			"mistborn": ["Rogue_Hooded", Color(0.5, 0.55, 0.75), []],
			"mistborn_sword": ["Knight", Color(0.5, 0.55, 0.75), ["Sword"]],
			"soother": ["Mage", Color(0.7, 0.85, 0.75), []],
			"rioter": ["Barbarian", Color(0.95, 0.65, 0.6), []],
		},
	},
	"quaternius": {
		"path": QUATERNIUS,
		"flip": true,  # también miran hacia +Z (el exportador glTF de Blender convierte el eje)
		# Animaciones que no tiene (salto, lanzar, esquivas...) las toma de KayKit con retarget.
		"retarget_from": KAYKIT % "Rogue",
		"player": "Rogue",
		"guard": "Warrior",
		"guard_items": ["Sword"],
		"citizens": ["Monk", "Ranger", "Cleric"],
		"nobles": ["Wizard", "Cleric"],
		# tipo de alomántico -> [modelo, tono, accesorios visibles]
		"allomancers": {
			"thug": ["Warrior", Color(0.9, 0.72, 0.68), ["Sword"]],
			"coinshot": ["Ranger", Color(0.72, 0.78, 0.9), []],
			"lurcher": ["Ranger", Color(0.65, 0.65, 0.75), []],
			"tineye": ["Monk", Color(0.8, 0.82, 0.72), []],
			"smoker": ["Cleric", Color(0.85, 0.7, 0.6), []],
			"seeker": ["Wizard", Color(0.8, 0.72, 0.6), []],
			"mistborn": ["Rogue", Color(0.45, 0.5, 0.7), []],
			"mistborn_sword": ["Warrior", Color(0.5, 0.52, 0.65), ["Sword"]],
			"soother": ["Cleric", Color(0.7, 0.85, 0.75), []],
			"rioter": ["Monk", Color(0.95, 0.65, 0.6), []],
		},
	},
}

## Personajes propios del jugador: [modelo, mapeo de huesos desde KayKit]. Usan sus propias
## animaciones y las que les faltan las toman de KayKit con retarget.
const PLAYER_MODELS := {
	# Mixamo, armado con tools/blender/mixamo_to_glb.py.
	"ninja": ["res://assets/mixamo/Ninja.glb", BoneTools.KAYKIT_TO_MIXAMO],
	# Hunyuan3D + ActionForge, armado con tools/blender/actionforge_to_glb.py.
	"mistborn": ["res://assets/mixamo/Mistborn.glb", BoneTools.KAYKIT_TO_UE],
}
## Los que se eligen en SuitPicker. Se mueven solo con el paquete de Meshy (ver hero_rig). shortcut: el terrisano sin ferruquimia todavía.
const HEROES := {
	"encapuchado": {"name": "Mistborn", "height": 1.8, "model": MESHY_HOOD, "portrait": "res://assets/meshy/retrato_encapuchado.png"},
	"terrisano": {"name": "Terrisano", "height": 2.0, "model": "res://assets/meshy/Terrisano.glb", "portrait": "res://assets/meshy/retrato_terrisano.png"},
}
## shortcut: todavía sin clips propios, no se pueden elegir; cuando los tengan, pasarlos a HEROES.
const HEROES_LATER := {
	"kelsier": {"name": "Kelsier", "height": 1.8, "model": "res://assets/meshy/Kelsier.glb", "portrait": "res://assets/meshy/retrato_kelsier.png"},
	"vin": {"name": "Vin", "height": 1.55, "model": "res://assets/meshy/Vin.glb", "portrait": "res://assets/meshy/retrato_vin.png"},
}

## Tonos para que los colores de los packs encajen con la ciudad apagada (y varíe la gente).
const CROWD_TINTS := [Color(0.82, 0.8, 0.78), Color(0.75, 0.75, 0.8), Color(0.85, 0.8, 0.74),
		Color(0.72, 0.74, 0.72), Color(0.8, 0.76, 0.8)]


## Kelsier y Vin tienen el esqueleto del Mistborn; los demás, el de Mixamo, igual que el paquete.
static func hero_rig() -> ModelRig:
	var hero: Dictionary = HEROES[player_model]
	var rig := ModelRig.new()
	rig.model_path = hero["model"]
	rig.flip = true
	rig.target_height = hero["height"]
	rig.stride_scale = rig.target_height / 1.8
	rig.suit_on_body = false  # se les ve la cara: el color queda para la capa
	rig.retarget_from = MESHY_HOOD
	rig.retarget_map = BoneTools.MIXAMO_TO_UE if player_model in ["kelsier", "vin"] else _mixamo_same()
	rig.clips_only = true
	rig.anim_overrides = HeroClips.STATES
	rig.state_cuts = HeroClips.CUTS
	rig.clip_holds = HeroClips.HOLDS
	rig.skill_clips = HeroClips.SKILLS
	rig.upper_donor = MESHY_HOOD.get_file()
	return rig


static func player_rig(look: Dictionary) -> HumanoidRig:
	if HEROES.has(player_model):
		return hero_rig()
	if PLAYER_MODELS.has(player_model):
		var rig := ModelRig.new()
		rig.model_path = PLAYER_MODELS[player_model][0]
		rig.flip = true
		rig.retarget_from = KAYKIT % "Rogue"
		rig.retarget_map = PLAYER_MODELS[player_model][1]
		# Gestos con monedas bajados de Mixamo (tools/blender/mixamo_to_glb.py).
		# MixamoCombat: golpes de puños, dagas y espada con escudo.
		rig.extra_donors = [["res://assets/mixamo/MixamoSpells.glb", BoneTools.MIXAMO_TO_UE],
				["res://assets/mixamo/MixamoCombat.glb", BoneTools.MIXAMO_TO_UE]]
		return rig
	if not SETS.has(style):
		return _procedural(look)
	return _model(SETS[style]["player"], Color(1, 1, 1), [])


## Todos los NPC usan el modelo del koloss (ver tools/koloss/make_koloss_glb.js). Su esqueleto copia el del
## Mistborn, así que repite las animaciones del personaje principal (ver BoneTools.UE_TO_UE).
const KOLOSS := "res://assets/koloss/Koloss.glb"
const KOLOSS_ANIMS := "res://assets/mixamo/Mistborn.glb"
## Alto (m) de los NPC: de este mínimo al máximo, con pocos gigantes (la curva favorece a los bajos).
const NPC_MIN_HEIGHT := 1.5
const NPC_MAX_HEIGHT := 3.0
static var npc_use_koloss := true


const SKAA_MODELS := ["res://assets/skaa/Skaa.glb", "res://assets/skaa/SkaaObrero.glb"]


## Skaa de Meshy con el esqueleto y las animaciones del Mistborn; lo que le falte, de KayKit y Mixamo.
## Sin model, uno al azar.
static func skaa_rig(model := "") -> ModelRig:
	var rig := ModelRig.new()
	rig.model_path = model if model != "" else SKAA_MODELS.pick_random()
	rig.flip = true
	rig.retarget_from = KAYKIT % "Rogue"
	rig.retarget_map = BoneTools.KAYKIT_TO_UE
	rig.extra_donors = [["res://assets/mixamo/MixamoSpells.glb", BoneTools.MIXAMO_TO_UE]]
	# Tranquilo camina encorvado; huyendo corre como el Mistborn (no con el clip chibi de KayKit).
	rig.anim_overrides = {"idle": ["sad_idle", "idle"], "walk": ["sad_walk", "walk"], "flee": ["sprint"]}
	return rig


## Nena skaa: modelo de Meshy ya riggeado (huesos de Mixamo), con sus propios clips.
static func skaa_girl_rig() -> ModelRig:
	var rig := ModelRig.new()
	rig.model_path = "res://assets/skaa/SkaaPilgrim.glb"
	rig.anim_overrides = {"walk": ["Walking_Woman"], "idle": ["Alert"], "get_up": ["Arise"]}
	return rig


const MESHY := "res://assets/meshy/%s.glb"
const MESHY_HOOD := "res://assets/meshy/MistbornHood.glb"
## Los que no pelean: alto y clips, todos de su propio paquete.
const CIVILIANS := {
	"Terrisano": {"height": 2.0, "states": {"idle": ["Combat_Stance"], "idle_armed": ["Combat_Stance"], "walk": ["Walking"], "run": ["Running"],
			"sprint": ["Running"], "flee": ["Running"], "down": ["falling_down"]}},
	"GordoNoble": {"height": 1.7, "states": {"idle": ["Scheming_Hand_Rub"], "idle_armed": ["Scheming_Hand_Rub"], "walk": ["Walking"], "run": ["Running"],
			"sprint": ["Running"], "flee": ["Running"], "down": ["falling_down"]}},
}


## Mismo esqueleto de Mixamo en origen y destino: el clip se copia tal cual.
static func _mixamo_same() -> Array:
	return BoneTools.MIXAMO_TO_UE.map(func(m: Array) -> Array: return [m[1], m[1], m[2], m[3]])


## Personaje de Meshy que se mueve solo con los clips de su paquete.
static func _pack_rig(model: String, height: float, states: Dictionary) -> ModelRig:
	var rig := ModelRig.new()
	rig.model_path = MESHY % model
	rig.flip = true
	rig.target_height = height
	rig.stride_scale = height / 1.8
	rig.clips_only = true
	rig.anim_overrides = states
	return rig


static func meshy_rig(model: String) -> ModelRig:
	return _pack_rig(model, CIVILIANS[model]["height"], CIVILIANS[model]["states"])


static func champion_rig(kit: String) -> ModelRig:
	var spec: Dictionary = Champion.KITS[kit]
	var states: Dictionary = spec["states"].duplicate()
	for clip: String in Champion.clips_of(kit):
		states[clip] = [clip]
	var rig := _pack_rig(kit, spec["height"], states)
	rig.ignore_light_hits = true
	rig.held_weapons = spec["weapons"]
	rig.state_cuts = spec.get("cuts", {})
	rig.clip_holds = spec.get("holds", {})
	return rig


static func npc_rig(role: String, look: Dictionary) -> HumanoidRig:
	if role.begins_with("meshy:"):
		return meshy_rig(role.trim_prefix("meshy:"))
	if role == "noble":
		return meshy_rig("GordoNoble")
	if role.begins_with("champion:"):
		return champion_rig(role.trim_prefix("champion:"))
	if role.begins_with("skaa"):
		return skaa_rig(role.trim_prefix("skaa").trim_prefix(":"))
	if role.begins_with("koloss"):
		return koloss_fighter_rig(role == "koloss_axes")
	if npc_use_koloss:
		return koloss_rig()
	if not SETS.has(style):
		return _procedural(look)
	var set: Dictionary = SETS[style]
	if role.begins_with("allomancer:"):
		var spec: Array = set["allomancers"][role.trim_prefix("allomancer:")]
		return _model(spec[0], spec[1], spec[2])
	match role:
		"guard":
			return _model(set["guard"], Color(0.8, 0.78, 0.8), set["guard_items"])
		"noble":
			return _model(set["nobles"].pick_random(), Color(0.9, 0.88, 0.9), [])
	return _model(set["citizens"].pick_random(), CROWD_TINTS.pick_random(), [])


static func koloss_rig() -> ModelRig:
	var rig := ModelRig.new()
	rig.model_path = KOLOSS
	rig.flip = true  # mira hacia +Z como los demás glTF
	rig.retarget_from = KOLOSS_ANIMS
	rig.retarget_map = BoneTools.UE_TO_UE
	rig.target_height = NPC_MIN_HEIGHT + (NPC_MAX_HEIGHT - NPC_MIN_HEIGHT) * pow(randf(), 1.4)
	rig.stride_scale = rig.target_height / 1.8
	rig.tint = Color.WHITE.darkened(randf_range(0.0, 0.25))
	return rig


## El koloss que pelea (ver Koloss): con espadón a dos manos o con un hacha en cada mano.
static func koloss_fighter_rig(axes: bool) -> ModelRig:
	var rig := ModelRig.new()
	rig.target_height = randf_range(1.6, 3.2)
	rig.model_path = MESHY % ("KolossJoven" if rig.target_height < 2.2 else "KolossAdulto")
	rig.flip = true
	# KolossMoves primero: esquives y golpes del mismo donante, así se mezclan sin cortes.
	rig.retarget_from = "res://assets/koloss/KolossMoves.glb"
	rig.retarget_map = _mixamo_same()
	rig.extra_donors = [[KOLOSS_ANIMS, BoneTools.UE_TO_MIXAMO]]
	rig.stride_scale = rig.target_height / 1.8
	rig.ignore_light_hits = true
	rig.tint = Color.WHITE.darkened(randf_range(0.0, 0.2))
	rig.held_weapons = ["res://assets/weapons/koloss_axe.glb", "res://assets/weapons/koloss_axe.glb"] if axes 			else ["res://assets/weapons/koloss_greatsword.glb"]
	var style := "mt" if axes else "gs"
	var idle := ["%s_idle" % style]
	var run := ["%s_run" % style]
	rig.anim_overrides = {"idle": idle, "idle_armed": idle, "walk": ["%s_walk" % style], "run": run, "sprint": run,
			"flee": run, "hit": ["gs_hit"], "hit_head": ["gs_hit"], "hit_knockback": ["hit_front"], "down": ["mt_die"],
			"block": ["gs_block"]}
	return rig


static func _procedural(look: Dictionary) -> HumanoidRig:
	var rig := HumanoidRig.new()
	rig.look = look
	return rig


static func _model(name: String, tint: Color, items: Array) -> ModelRig:
	var rig := ModelRig.new()
	rig.model_path = SETS[style]["path"] % name
	rig.flip = SETS[style]["flip"]
	if SETS[style].has("retarget_from"):
		rig.retarget_from = SETS[style]["retarget_from"]
		rig.retarget_map = BoneTools.KAYKIT_TO_QUATERNIUS
	rig.tint = tint
	rig.always_items = items
	return rig
