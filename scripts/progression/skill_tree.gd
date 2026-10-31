class_name SkillTree
## Catálogo del árbol de habilidades (ver docs/arbol-de-habilidades.md). Cada metal da una habilidad nueva
## en ciertos niveles y mejora números en el resto. Por ahora están acero, hierro y peltre.

enum Kind { PASSIVE, ACTIVE }

## Niveles de metal en los que se desbloquea una habilidad nueva (atium, con tope 10, tiene menos).
const UNLOCK_LEVELS := [1, 4, 8, 12, 16, 20]
const ATIUM_UNLOCK_LEVELS := [1, 5, 10]
## Niveles que deben tener ambos metales para cada escalón de una habilidad combinada.
const COMBO_TIERS := [5, 10, 15]
## Masa máxima (kg) que se puede empujar o tirar con acero/hierro, por nivel de metal. 0 = ninguna;
## el último escalón es "tu propio cuerpo" (sin tope por masa).
const PUSH_MASS_BY_LEVEL := [[20, INF], [16, 100.0], [12, 25.0], [8, 5.0], [4, 1.0], [1, 0.2]]

## id, metal, nivel de metal, tipo y nombre.
const SKILLS := [
	{"id": &"steel_combat_coin", "metal": &"steel", "level": 1, "kind": Kind.ACTIVE, "name": "Moneda de combate"},
	{"id": &"steel_light_push", "metal": &"steel", "level": 4, "kind": Kind.ACTIVE, "name": "Empuje ligero"},
	{"id": &"steel_coin_ring", "metal": &"steel", "level": 8, "kind": Kind.ACTIVE, "name": "Anillo de monedas"},
	{"id": &"steel_shield", "metal": &"steel", "level": 12, "kind": Kind.ACTIVE, "name": "Escudo metálico"},
	{"id": &"steel_heavy_push", "metal": &"steel", "level": 16, "kind": Kind.PASSIVE, "name": "Empuje pesado"},
	{"id": &"steel_wave", "metal": &"steel", "level": 20, "kind": Kind.PASSIVE, "name": "Onda de acero"},
	{"id": &"iron_pull", "metal": &"iron", "level": 1, "kind": Kind.ACTIVE, "name": "Tirón básico"},
	{"id": &"iron_light_pull", "metal": &"iron", "level": 4, "kind": Kind.PASSIVE, "name": "Tirón ligero"},
	{"id": &"iron_coin_magnet", "metal": &"iron", "level": 8, "kind": Kind.ACTIVE, "name": "Imán de monedas"},
	{"id": &"iron_disarm", "metal": &"iron", "level": 12, "kind": Kind.ACTIVE, "name": "Desarme"},
	{"id": &"iron_swing", "metal": &"iron", "level": 16, "kind": Kind.PASSIVE, "name": "Balanceo"},
	{"id": &"iron_mass_pull", "metal": &"iron", "level": 20, "kind": Kind.PASSIVE, "name": "Tirón de masa"},
	{"id": &"pewter_endurance", "metal": &"pewter", "level": 1, "kind": Kind.PASSIVE, "name": "Resistencia"},
	{"id": &"pewter_jump", "metal": &"pewter", "level": 4, "kind": Kind.PASSIVE, "name": "Salto reforzado"},
	{"id": &"pewter_strike", "metal": &"pewter", "level": 8, "kind": Kind.PASSIVE, "name": "Golpe reforzado"},
	{"id": &"pewter_landing", "metal": &"pewter", "level": 12, "kind": Kind.PASSIVE, "name": "Aterrizaje seguro"},
	{"id": &"pewter_second_wind", "metal": &"pewter", "level": 16, "kind": Kind.PASSIVE, "name": "Segundo aliento"},
	{"id": &"pewter_fury", "metal": &"pewter", "level": 20, "kind": Kind.ACTIVE, "name": "Furia"},
]


## Habilidades que todavía no hacen nada (se ven en el árbol como "próximamente").
const PENDING: Array[StringName] = [&"steel_shield", &"steel_wave", &"iron_disarm", &"pewter_fury"]
## Activas con tecla propia fuera de las ranuras (la moneda de combate es el clic derecho).
const FIXED_KEY: Array[StringName] = [&"steel_combat_coin"]


## Si se puede poner en una ranura: activa, ya funciona y no tiene una tecla fija.
static func is_assignable(id: StringName) -> bool:
	var s := find(id)
	return not s.is_empty() and s["kind"] == Kind.ACTIVE and not id in PENDING and not id in FIXED_KEY


static func skills_of(metal: StringName) -> Array:
	return SKILLS.filter(func(s): return s["metal"] == metal)


static func find(id: StringName) -> Dictionary:
	for s in SKILLS:
		if s["id"] == id:
			return s
	return {}


## Si la habilidad está desbloqueada con los niveles de metal actuales.
static func is_unlocked(id: StringName) -> bool:
	var s := find(id)
	return not s.is_empty() and Progression.metal_level(s["metal"]) >= int(s["level"])


## Escalón (0 = ninguno, 1-3) de una habilidad combinada de dos metales: se cuenta por el menor nivel.
static func combo_tier(a: StringName, b: StringName) -> int:
	var lowest := mini(Progression.metal_level(a), Progression.metal_level(b))
	var tier := 0
	for need: int in COMBO_TIERS:
		if lowest >= need:
			tier += 1
	return tier


## Masa máxima (kg) que se puede empujar o tirar con el nivel de acero/hierro dado (0 si ninguna).
static func push_mass_limit(metal_level: int) -> float:
	for row: Array in PUSH_MASS_BY_LEVEL:
		if metal_level >= int(row[0]):
			return float(row[1])
	return 0.0
