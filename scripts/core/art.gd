class_name Art
## Estilo de los personajes. Cambia `style` para elegir:
##   "procedural" -> cuerpos hechos con primitivas (HumanoidRig)
##   "kaykit"     -> KayKit Adventurers (CC0): jugador = pícaro encapuchado verde
##   "quaternius" -> Quaternius RPG Characters (CC0): jugador = pícaro encapuchado rojo
## Todos los rigs tienen la misma interfaz, así que el juego funciona igual con cualquiera.

static var style := "quaternius"
## Personaje propio del jugador (de PLAYER_MODELS) o "" para usar el del estilo.
static var player_model := "mistborn"
## "noche" (bruma) o "dia" (sol rojo de Luthadel). Se cambia en el juego con F3.
static var lighting := "noche"
## "despejado", "lluvia" o "ceniza". F4.
static var weather := "despejado"
## "poca" o "mucha". F5.
static var fog := "mucha"
## Sube cada vez que cambia el ambiente (para que el estaño recalcule sus valores base).
static var env_version := 0

## Color del traje y la capucha del jugador, para distinguirse en las partidas con otros. "negro" es
## el del modelo; los demás lo tiñen (HumanoidRig.set_suit). Se elige al empezar por primera vez y
## con P en el juego (SuitPicker), y se guarda en SUIT_FILE.
const SUITS := {"negro": Color(0.17, 0.19, 0.24), "blanco": Color(0.9, 0.89, 0.86),
		"rojo": Color(0.62, 0.06, 0.05), "azul": Color(0.07, 0.2, 0.66)}
const SUIT_FILE := "user://jugador.cfg"
static var suit := "negro"
## false hasta que se elige por primera vez (entonces se muestra SuitPicker al empezar).
static var suit_chosen := false


## Lee el color guardado (si nunca se eligió, queda el negro y suit_chosen en false).
static func load_suit() -> void:
	var cfg := ConfigFile.new()
	suit_chosen = cfg.load(SUIT_FILE) == OK
	var s: String = cfg.get_value("jugador", "traje", "negro") if suit_chosen else "negro"
	suit = s if SUITS.has(s) else "negro"


static func save_suit(s: String) -> void:
	suit = s
	suit_chosen = true
	var cfg := ConfigFile.new()
	cfg.set_value("jugador", "traje", s)
	cfg.save(SUIT_FILE)


## Distancia (m) a la que alguien ve a otra persona a simple vista, sin estaño.
## Es lo que usan los alománticos para detectarte; la niebla y el clima la recortan.
static func sight_range() -> float:
	var r := 16.0 if lighting == "noche" else 38.0
	r *= 1.6 if fog == "poca" else 0.65
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

## Tonos para que los colores de los packs encajen con la ciudad apagada (y varíe la gente).
const CROWD_TINTS := [Color(0.82, 0.8, 0.78), Color(0.75, 0.75, 0.8), Color(0.85, 0.8, 0.74),
		Color(0.72, 0.74, 0.72), Color(0.8, 0.76, 0.8)]


static func player_rig(look: Dictionary) -> HumanoidRig:
	if PLAYER_MODELS.has(player_model):
		var rig := ModelRig.new()
		rig.model_path = PLAYER_MODELS[player_model][0]
		rig.flip = true
		rig.retarget_from = KAYKIT % "Rogue"
		rig.retarget_map = PLAYER_MODELS[player_model][1]
		return rig
	if not SETS.has(style):
		return _procedural(look)
	return _model(SETS[style]["player"], Color(1, 1, 1), [])


static func npc_rig(role: String, look: Dictionary) -> HumanoidRig:
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
