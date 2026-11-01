class_name Items
## Catálogo de objetos equipables (inventario de tipo RPG, tecla I).
## Cada objeto va en una ranura y modifica al jugador con sus "stats":
##   conceal_night / conceal_day: multiplica la distancia a la que te ven (menos = mejor)
##   armor: fracción del daño de los golpes que se evita (se suma)
##   speed: multiplica la velocidad al andar
##   impact: m/s más de impacto que aguantas sin daño (caídas y choques)
##   damage / knockback: multiplican el daño y el empuje del arma; reach: alcance extra (m)
##   charges / refill: frascos que llevas y cuánto metal recupera cada uno
## metal: true si es metal. Llevar algo de metal encima (o la bolsa de monedas) deja que los
## alománticos enemigos te empujen y tiren de ti.

const SLOTS := ["cloak", "body", "boots", "daggers", "sword", "vials"]
const SLOT_NAMES := {"cloak": "Capa", "body": "Ropa", "boots": "Botas", "daggers": "Dagas",
		"sword": "Espada", "vials": "Frascos"}

const DB := {
	# --- Capas
	"mistcloak": {"slot": "cloak", "name": "Capa de bruma", "color": Color(0.3, 0.32, 0.38),
		"desc": "Tiras de tela gris que se confunden con la bruma al moverte.",
		"stats": {"conceal_night": 0.75, "conceal_day": 0.92}},
	"wool_cloak": {"slot": "cloak", "name": "Capa de viaje de lana", "color": Color(0.38, 0.3, 0.22),
		"desc": "Gruesa y abrigada. Amortigua algo los golpes, pero no esconde tanto.",
		"stats": {"conceal_night": 0.9, "conceal_day": 0.97, "armor": 0.05}},
	# --- Ropa
	"mistborn_suit": {"slot": "body", "name": "Traje de nacido de la bruma", "color": Color(0.16, 0.17, 0.2),
		"desc": "Ropa oscura y ceñida, sin una sola pieza de metal.", "dark": true,
		"stats": {"conceal_night": 0.85, "conceal_day": 0.97}},
	"skaa_clothes": {"slot": "body", "name": "Ropa de skaa", "color": Color(0.42, 0.36, 0.3),
		"desc": "Tela basta manchada de ceniza. Nadie mira dos veces a un skaa.",
		"stats": {}},
	"leather_jerkin": {"slot": "body", "name": "Jubón de cuero endurecido", "color": Color(0.36, 0.24, 0.15),
		"desc": "Cuero hervido en capas. Para cuchilladas, pero pesa un poco.", "dark": true,
		"stats": {"armor": 0.15, "speed": 0.96, "conceal_night": 0.95}},
	"chainmail": {"slot": "body", "name": "Cota de malla", "color": Color(0.5, 0.52, 0.56), "metal": true,
		"desc": "Protege mucho... y es una enorme pieza de metal: un lanzamonedas te hará volar.",
		"stats": {"armor": 0.32, "speed": 0.88}},
	# --- Botas
	"soft_boots": {"slot": "boots", "name": "Botas de cuero blando", "color": Color(0.25, 0.18, 0.12),
		"desc": "Livianas y silenciosas.", "stats": {"speed": 1.05}},
	"padded_boots": {"slot": "boots", "name": "Botas acolchadas", "color": Color(0.32, 0.26, 0.2),
		"desc": "Suela gruesa de corcho: los aterrizajes duelen menos.", "stats": {"impact": 3.0, "speed": 0.98}},
	"nailed_boots": {"slot": "boots", "name": "Botas con clavos de hierro", "color": Color(0.3, 0.3, 0.33), "metal": true,
		"desc": "Agarre firme en los tejados y aterrizajes duros. Los clavos son metal.",
		"stats": {"impact": 5.0}},
	# --- Dagas
	"obsidian_daggers": {"slot": "daggers", "name": "Dagas de obsidiana", "color": Color(0.12, 0.1, 0.14),
		"desc": "Cristal volcánico, no metal: ningún alomántico puede empujarlas.", "stats": {}},
	"glass_daggers": {"slot": "daggers", "name": "Dagas de vidrio templado", "color": Color(0.55, 0.7, 0.75),
		"desc": "Más filo y algo más de alcance. Sin metal.", "stats": {"damage": 1.25, "reach": 0.15}},
	"steel_daggers": {"slot": "daggers", "name": "Dagas de acero", "color": Color(0.62, 0.65, 0.7), "metal": true,
		"desc": "Las que más cortan, pero son metal.", "stats": {"damage": 1.4}},
	# --- Espadas
	"obsidian_sword": {"slot": "sword", "name": "Espada corta de obsidiana", "color": Color(0.14, 0.12, 0.16),
		"desc": "Hoja de cristal volcánico engastada en madera. Sin metal.", "stats": {}},
	"dueling_cane": {"slot": "sword", "name": "Bastón de duelo", "color": Color(0.4, 0.28, 0.16),
		"desc": "La 'espada' de los nobles en sus duelos: madera dura. Pega menos pero tumba.",
		"stats": {"damage": 0.7, "knockback": 1.6}},
	"steel_sword": {"slot": "sword", "name": "Espada de acero", "color": Color(0.65, 0.68, 0.72), "metal": true,
		"desc": "Una buena espada de soldado. Metal.", "stats": {"damage": 1.3, "reach": 0.2}},
	# --- Frascos
	"glass_vials": {"slot": "vials", "name": "Frascos de vidrio", "color": Color(0.45, 0.7, 1.0), "metal": true,
		"desc": "Tapón y cierre de estaño: un alomántico puede tirar de tu cinturón.",
		"stats": {"charges": 3, "refill": 40.0}},
	"wooden_vials": {"slot": "vials", "name": "Frascos de madera", "color": Color(0.5, 0.36, 0.2),
		"desc": "Tallados y sellados con cera, sin nada de metal por fuera.",
		"stats": {"charges": 3, "refill": 35.0}},
	"large_vials": {"slot": "vials", "name": "Frascos grandes de cristal", "color": Color(0.6, 0.85, 1.0), "metal": true,
		"desc": "Más reserva por trago y uno más en el cinturón. Tapones de metal.",
		"stats": {"charges": 4, "refill": 55.0}},
}

## Con qué empieza el jugador (equipado) y qué más lleva en la mochila. La capa de bruma va en la
## mochila: se la pone desde el inventario.
const START_EQUIPPED := {"cloak": "", "body": "mistborn_suit", "boots": "soft_boots",
		"daggers": "obsidian_daggers", "sword": "obsidian_sword", "vials": "glass_vials"}
const START_BAG := ["skaa_clothes", "mistcloak"]

## Nombre de cada stat y si "más" es mejor (para las comparaciones del inventario).
const STAT_INFO := {
	"armor": ["Armadura", true, "%+d %%", 100.0],
	"speed": ["Velocidad", true, "×%.2f", 1.0],
	"impact": ["Aguante de impactos", true, "%+.0f m/s", 1.0],
	"damage": ["Daño", true, "×%.2f", 1.0],
	"knockback": ["Empuje", true, "×%.2f", 1.0],
	"reach": ["Alcance", true, "%+.2f m", 1.0],
	"conceal_night": ["Te ven de noche a", false, "×%.2f", 1.0],
	"conceal_day": ["Te ven de día a", false, "×%.2f", 1.0],
	"charges": ["Frascos", true, "%d", 1.0],
	"refill": ["Metal por frasco", true, "%.0f", 1.0],
}


static func get_item(id: String) -> Dictionary:
	return DB.get(id, {})


static func stat(id: String, key: String, default: float) -> float:
	var it := get_item(id)
	if it.is_empty():
		return default
	return float(it["stats"].get(key, default))


## Texto de cada stat del objeto, p. ej. "Armadura +15 %".
static func describe(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	var stats: Dictionary = get_item(id).get("stats", {})
	for key in stats:
		var info: Array = STAT_INFO.get(key, [key, true, "%s", 1.0])
		out.append("%s %s" % [info[0], info[2] % (stats[key] * info[3])])
	return out
