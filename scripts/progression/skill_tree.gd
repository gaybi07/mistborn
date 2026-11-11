class_name SkillTree
## Catálogo del árbol de habilidades (ver docs/arbol-de-habilidades.md). Cada metal da una habilidad nueva
## en ciertos niveles y mejora números en el resto. Por ahora están acero, hierro y peltre.

enum Kind { PASSIVE, ACTIVE }

## Niveles de metal en los que se desbloquea una habilidad nueva (atium, con tope 10, tiene menos).
const UNLOCK_LEVELS := [1, 4, 8, 12, 16, 20]
const ATIUM_UNLOCK_LEVELS := [1, 5, 10]
## Niveles que deben tener ambos metales para cada escalón de una habilidad combinada.
const COMBO_TIERS := [5, 10, 15]
## Peso del personaje (kg) y cuánto crece su poder de empuje y de tirón por nivel de metal (ver power_mass).
const BODY_MASS := 70.0
const POWER_PER_LEVEL := 0.15

## Niveles de cada poder si su entrada no dice "max".
const DEFAULT_MAX := 5
## Tope de la escala vieja de nivel de metal (ver equiv_level).
const MAX_EQUIV := 20

## Cómo mejora el metal en sí con cada punto en sus poderes (nivel del metal): "burn", cambio del consumo por punto, y
## "max", cambio de la reserva por punto. Provisorio (D7): igual para todos hasta balancear; un metal sin entrada
## usa DEFAULT_METAL_SCALING. El consumo nunca baja de MIN_BURN_SCALE.
const DEFAULT_METAL_SCALING := {"burn": -0.02, "max": 0.03}
const METAL_SCALING := {}
const MIN_BURN_SCALE := 0.4


## Multiplicador del consumo (quemar y avivar) con ese nivel de metal.
static func burn_scale(metal: StringName, metal_level: int) -> float:
	return maxf(1.0 + float(METAL_SCALING.get(metal, DEFAULT_METAL_SCALING)["burn"]) * metal_level, MIN_BURN_SCALE)


## Multiplicador de la reserva máxima con ese nivel de metal.
static func reserve_scale(metal: StringName, metal_level: int) -> float:
	return 1.0 + float(METAL_SCALING.get(metal, DEFAULT_METAL_SCALING)["max"]) * metal_level

## id, metal, "legacy_level" (el nivel de metal en que se desbloqueaba antes: de ahí arranca equiv_level), tipo y nombre.
## Opcionales: "max" (niveles del poder, DEFAULT_MAX), "tree" (&"allomancy" o &"feruchemy"; falta = alomancia) y
## "requires" (requisitos extra, ver _requirement_ok).
const SKILLS := [
	{"id": &"steel_light_push", "metal": &"steel", "legacy_level": 1, "kind": Kind.ACTIVE, "name": "Empuje básico"},
	{"id": &"steel_combat_coin", "metal": &"steel", "legacy_level": 2, "kind": Kind.ACTIVE, "name": "Moneda de combate"},
	{"id": &"steel_coin_burst", "metal": &"steel", "legacy_level": 3, "kind": Kind.ACTIVE, "name": "Ráfaga de monedas"},
	{"id": &"steel_coin_shield", "metal": &"steel", "legacy_level": 8, "kind": Kind.ACTIVE, "name": "Escudo de monedas"},
	{"id": &"steel_magnetic_field", "metal": &"steel", "legacy_level": 12, "kind": Kind.ACTIVE, "name": "Campo magnético"},
	{"id": &"steel_spear", "metal": &"steel", "legacy_level": 20, "kind": Kind.ACTIVE, "name": "Lanza de acero"},
	{"id": &"iron_pull", "metal": &"iron", "legacy_level": 1, "kind": Kind.ACTIVE, "name": "Tirón básico"},
	{"id": &"iron_drag", "metal": &"iron", "legacy_level": 4, "kind": Kind.ACTIVE, "name": "Arrastre"},
	{"id": &"iron_coin_magnet", "metal": &"iron", "legacy_level": 2, "kind": Kind.ACTIVE, "name": "Imán de monedas"},
	{"id": &"iron_hook", "metal": &"iron", "legacy_level": 8, "kind": Kind.ACTIVE, "name": "Gancho"},
	{"id": &"iron_disarm", "metal": &"iron", "legacy_level": 12, "kind": Kind.ACTIVE, "name": "Desarme"},
	{"id": &"iron_mass_yank", "metal": &"iron", "legacy_level": 20, "kind": Kind.ACTIVE, "name": "Atracción masiva"},
	{"id": &"pewter_endurance", "metal": &"pewter", "legacy_level": 1, "kind": Kind.PASSIVE, "name": "Resistencia"},
	{"id": &"pewter_charge", "metal": &"pewter", "legacy_level": 4, "kind": Kind.ACTIVE, "name": "Embestida"},
	{"id": &"pewter_strike", "metal": &"pewter", "legacy_level": 8, "kind": Kind.PASSIVE, "name": "Golpe reforzado"},
	{"id": &"pewter_slam", "metal": &"pewter", "legacy_level": 12, "kind": Kind.ACTIVE, "name": "Martillazo"},
	{"id": &"pewter_last_stand", "metal": &"pewter", "legacy_level": 16, "kind": Kind.PASSIVE, "name": "Último aliento"},
	{"id": &"pewter_fury", "metal": &"pewter", "legacy_level": 20, "kind": Kind.ACTIVE, "name": "Furia"},
	{"id": &"tin_senses", "metal": &"tin", "legacy_level": 1, "kind": Kind.PASSIVE, "name": "Sentidos agudos"},
	{"id": &"tin_focus", "metal": &"tin", "legacy_level": 4, "kind": Kind.ACTIVE, "name": "Foco"},
	{"id": &"tin_ear", "metal": &"tin", "legacy_level": 8, "kind": Kind.PASSIVE, "name": "Oído agudo"},
	{"id": &"tin_mark", "metal": &"tin", "legacy_level": 12, "kind": Kind.ACTIVE, "name": "Marca del cazador"},
	{"id": &"tin_clear_mind", "metal": &"tin", "legacy_level": 16, "kind": Kind.ACTIVE, "name": "Mente despejada"},
	{"id": &"tin_extreme", "metal": &"tin", "legacy_level": 20, "kind": Kind.ACTIVE, "name": "Sentidos extremos"},
	# Cinc (L7): cada poder enciende una emoción en los NPC (ver ZincPowers y los estados de Npc).
	{"id": &"zinc_fury", "metal": &"zinc", "legacy_level": 1, "kind": Kind.ACTIVE, "name": "Furia"},
	{"id": &"zinc_panic", "metal": &"zinc", "legacy_level": 4, "kind": Kind.ACTIVE, "name": "Pánico"},
	{"id": &"zinc_greed", "metal": &"zinc", "legacy_level": 8, "kind": Kind.ACTIVE, "name": "Avaricia"},
	{"id": &"zinc_tame", "metal": &"zinc", "legacy_level": 12, "kind": Kind.ACTIVE, "name": "Domar"},
	{"id": &"zinc_contagion", "metal": &"zinc", "legacy_level": 16, "kind": Kind.PASSIVE, "name": "Contagio emocional"},
	{"id": &"zinc_storm", "metal": &"zinc", "legacy_level": 20, "kind": Kind.ACTIVE, "name": "Tormenta de emociones"},
]


## Rama de cada metal, por árbol: [habilidad, posición respecto a la raíz, de quién(es) nace]. Cada rama agrupa lo
## que va junto (ataque con ataque, defensa con defensa) y cada metal tiene su propia forma. Los padres van antes que
## los hijos. Es dato del árbol y no de la vista: de acá salen los requisitos (todos los padres con 1 punto o más).
const LAYOUTS := {
	&"allomancy": {
		# Acero: un brazo de ataque a distancia con monedas (arriba) y otro de defensa (abajo).
		&"steel": [
			[&"steel_light_push", Vector2(75, -60), [&"root"]],
			[&"steel_combat_coin", Vector2(140, -175), [&"steel_light_push"]],
			[&"steel_coin_burst", Vector2(290, -235), [&"steel_combat_coin"]],
			[&"steel_spear", Vector2(345, -95), [&"steel_coin_burst"]],
			[&"steel_coin_shield", Vector2(75, 145), [&"root"]],
			[&"steel_magnetic_field", Vector2(255, 220), [&"steel_coin_shield"]],
		],
		# Hierro: tirar de lo que sea. Arriba, sobre los enemigos; en medio, sobre las monedas; abajo, para moverte tú.
		&"iron": [
			[&"iron_pull", Vector2(75, -65), [&"root"]],
			[&"iron_drag", Vector2(170, -185), [&"iron_pull"]],
			[&"iron_disarm", Vector2(335, -240), [&"iron_drag"]],
			[&"iron_mass_yank", Vector2(350, -115), [&"iron_drag"]],
			[&"iron_coin_magnet", Vector2(255, 10), [&"iron_pull"]],
			[&"iron_hook", Vector2(80, 150), [&"root"]],
		],
		# Estaño: el oído (arriba) llega a los sentidos extremos; el foco lleva a marcar; y abajo, mantener la cabeza fría.
		&"tin": [
			[&"tin_senses", Vector2(75, -65), [&"root"]],
			[&"tin_ear", Vector2(185, -190), [&"tin_senses"]],
			[&"tin_extreme", Vector2(340, -240), [&"tin_ear"]],
			[&"tin_focus", Vector2(255, -10), [&"tin_senses"]],
			[&"tin_mark", Vector2(345, 105), [&"tin_focus"]],
			[&"tin_clear_mind", Vector2(80, 150), [&"root"]],
		],
		# Peltre: la defensa arriba (aguantar y sobrevivir) y la ofensa abajo, que acaba en Furia.
		&"pewter": [
			[&"pewter_endurance", Vector2(75, -100), [&"root"]],
			[&"pewter_last_stand", Vector2(250, -195), [&"pewter_endurance"]],
			[&"pewter_strike", Vector2(110, 95), [&"root"]],
			[&"pewter_charge", Vector2(190, 215), [&"pewter_strike"]],
			[&"pewter_slam", Vector2(345, 130), [&"pewter_strike"]],
			[&"pewter_fury", Vector2(355, 255), [&"pewter_charge", &"pewter_slam"]],
		],
		# Cinc: arriba la ira (Furia y su contagio); abajo, llevar a la gente (miedo, codicia y lealtad). Las dos
		# ramas se juntan en la Tormenta.
		&"zinc": [
			[&"zinc_fury", Vector2(75, -65), [&"root"]],
			[&"zinc_contagion", Vector2(190, -190), [&"zinc_fury"]],
			[&"zinc_panic", Vector2(80, 150), [&"root"]],
			[&"zinc_greed", Vector2(200, 220), [&"zinc_panic"]],
			[&"zinc_tame", Vector2(345, 130), [&"zinc_greed"]],
			[&"zinc_storm", Vector2(355, -60), [&"zinc_contagion", &"zinc_tame"]],
		],
	},
	&"feruchemy": {},
}


## Habilidades que todavía no hacen nada (se ven en el árbol como "próximamente").
const PENDING: Array[StringName] = []
## Activas con tecla propia fuera de las ranuras (la moneda de combate es el clic derecho).
const FIXED_KEY: Array[StringName] = [&"steel_combat_coin"]


## Si se puede poner en una ranura: activa, ya funciona y no tiene una tecla fija.
static func is_assignable(id: StringName) -> bool:
	var s := find(id)
	return not s.is_empty() and s["kind"] == Kind.ACTIVE and not id in PENDING and not id in FIXED_KEY


## Ráfaga de monedas (acero) e Imán de monedas (hierro): desde el nivel 2 salen o se atraen nivel + 1 monedas en un
## abanico hacia adelante que se abre con cada nivel; desde FAN_RADIAL_LEVEL es un círculo completo.
const FAN_MIN_LEVEL := 2  # el imán de hierro
const BURST_MIN_LEVEL := 3  # la ráfaga de monedas de acero
const FAN_RADIAL_LEVEL := 15
const FAN_MIN_ANGLE := 0.5236  # 30°
const FAN_MAX_ANGLE := 5.7596  # 330°


## Ráfaga de monedas: con cuántas se cierra el círculo (las que tiene en el nivel FAN_RADIAL_LEVEL; una cada 24°).
const BURST_CIRCLE := 15


## Hacia dónde sale cada moneda de la Ráfaga: (giro a la derecha, elevación) en radianes, respecto a la mira. Las
## primeras BURST_CIRCLE van en el plano de la mira, en un abanico que se abre con el nivel hasta cerrar el círculo
## (también hacia atrás); las que sobran salen de a pares hacia arriba y hacia abajo: con un par, recto arriba y abajo;
## con dos, además a 45°.
static func burst_dirs(metal_level: int, count: int) -> Array[Vector2]:
	var flat := mini(count, BURST_CIRCLE)
	var angle := fan_angle(metal_level, BURST_MIN_LEVEL)
	var out: Array[Vector2] = []
	for i in flat:
		if angle >= TAU:
			out.append(Vector2(wrapf(TAU * float(i) / float(flat), -PI, PI), 0.0))
		else:
			out.append(Vector2(0.0 if flat == 1 else -angle * 0.5 + angle * float(i) / float(flat - 1), 0.0))
	var pairs := (count - flat) / 2
	for k in pairs:
		var up := PI * 0.5 * float(k + 1) / float(pairs)
		out.append(Vector2(0.0, up))
		out.append(Vector2(0.0, -up))
	return out


## Siempre impar, para que haya una moneda justo en el centro (donde apunta el ratón): 3 en el nivel 2 y dos más (una a
## cada lado) cada 2 niveles; 21 en el 20.
static func fan_count(metal_level: int, min_level := FAN_MIN_LEVEL) -> int:
	return 3 + 2 * maxi((metal_level - min_level) / 2, 0)


## Ángulo total (rad) del abanico; TAU = radial.
static func fan_angle(metal_level: int, min_level := FAN_MIN_LEVEL) -> float:
	if metal_level >= FAN_RADIAL_LEVEL:
		return TAU
	return lerpf(FAN_MIN_ANGLE, FAN_MAX_ANGLE, clampf(float(metal_level - min_level) / float(FAN_RADIAL_LEVEL - 1 - min_level), 0.0, 1.0))


## Poderes de prueba que agrega progression_check (por ejemplo, uno de feruquimia antes de que existan los de verdad).
## En el juego queda vacía: los poderes van en SKILLS.
static var test_skills: Array = []


static func all_skills() -> Array:
	return SKILLS + test_skills


## Poderes de un metal; con `tree`, solo los de ese árbol (&"allomancy" o &"feruchemy"). Sin `tree`, los de los dos
## (así el nivel del metal suma alomancia y feruquimia).
static func skills_of(metal: StringName, tree := &"") -> Array:
	return all_skills().filter(func(s): return s["metal"] == metal and (tree == &"" or s.get("tree", &"allomancy") == tree))


static func find(id: StringName) -> Dictionary:
	for s in all_skills():
		if s["id"] == id:
			return s
	return {}


## Si el jugador tiene al menos un punto en la habilidad.
static func is_unlocked(id: StringName) -> bool:
	return Progression.skill_level(id) >= 1


static func max_level(id: StringName) -> int:
	return int(find(id).get("max", DEFAULT_MAX))


## Nivel del poder (1..max) traducido a la escala vieja de nivel de metal (1-20), la que reciben fan_count,
## shield_count, power_mass y compañía: va de su desbloqueo viejo (nivel 1) a 20 (nivel máximo). 0 = sin puntos.
## Ráfaga (desbloqueo 3): 3, 7, 12, 16, 20. El balance se ajusta acá, no en las fórmulas.
static func equiv_level(id: StringName, lvl: int) -> int:
	var s := find(id)
	if s.is_empty() or lvl <= 0:
		return 0
	var top := max_level(id)
	var legacy := int(s["legacy_level"])
	if top <= 1:
		return MAX_EQUIV
	return roundi(lerpf(legacy, MAX_EQUIV, float(mini(lvl, top) - 1) / float(top - 1)))


## Puntos por nivel de un poder (D5: todos 1).
static func skill_cost(_id: StringName) -> int:
	return 1


static func tree_of(id: StringName) -> StringName:
	return find(id).get("tree", &"allomancy")


## Padres del poder en su rama (sin &"root"). Vacío = nace de la raíz.
static func parents(id: StringName) -> Array[StringName]:
	var s := find(id)
	var out: Array[StringName] = []
	if s.is_empty():
		return out
	for entry: Array in LAYOUTS.get(tree_of(id), {}).get(s["metal"], []):
		if entry[0] == id:
			for p: StringName in entry[2]:
				if p != &"root":
					out.append(p)
	return out


## Poderes que nacen de este en su rama.
static func children(id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for s: Dictionary in all_skills():
		if id in parents(s["id"]):
			out.append(s["id"])
	return out


## Se puede tener un punto en el poder: todos sus padres con nivel 1 o más y cada requisito extra cumplido.
static func requirements_met(id: StringName) -> bool:
	for p in parents(id):
		if Progression.skill_level(p) < 1:
			return false
	for r: Dictionary in find(id).get("requires", []):
		if not _requirement_ok(r):
			return false
	return true


## Un requisito extra de SKILLS[i]["requires"]. Agregar un tipo es una línea.
static func _requirement_ok(r: Dictionary) -> bool:
	if r.has("skill"):
		return Progression.skill_level(r["skill"]) >= int(r.get("level", 1))
	if r.has("player_level"):
		return Progression.level >= int(r["player_level"])
	if r.has("metal"):
		return Progression.metal_level(r["metal"]) >= int(r.get("level", 1))
	push_warning("SkillTree: requisito desconocido %s" % r)
	return false


## Escalón (0 = ninguno, 1-3) de una habilidad combinada de dos metales: se cuenta por el menor nivel.
static func combo_tier(a: StringName, b: StringName) -> int:
	var lowest := mini(Progression.metal_level(a), Progression.metal_level(b))
	var tier := 0
	for need: int in COMBO_TIERS:
		if lowest >= need:
			tier += 1
	return tier


## Poder de empuje y de tirón: hasta qué masa (kg) mueves lo que empujas o tiras en vez de que te mueva a ti. Es tu
## peso en el nivel 1 y sube un 15 % por nivel de acero o hierro (con 70 kg: 70 en el 1, 143 en el 8, 270 en el 20).
static func power_mass(metal_level: int, body_mass := BODY_MASS) -> float:
	return body_mass * (1.0 + POWER_PER_LEVEL * maxi(metal_level - 1, 0))


## Monedas que giran a tu alrededor con el Escudo de monedas: 8 en el nivel 8 y una más por nivel (20 en el 20).
## Cada una bloquea un golpe.
static func shield_count(metal_level: int) -> int:
	return 0 if metal_level < 8 else metal_level


## Hierro: recargas (s) del Arrastre, el Gancho, el Desarme y la Atracción masiva; alcance del Gancho y radio de la Atracción (m).
const DRAG_COOLDOWN := 6.0
const HOOK_COOLDOWN := 3.0
const HOOK_RANGE := 25.0
const DISARM_COOLDOWN := 8.0
const DISARM_SECONDS := 8.0
const YANK_COOLDOWN := 20.0
const YANK_RADIUS := 12.0

## Peltre: recargas (s) de la Embestida, el Martillazo, la Furia y el Último aliento; radio del Martillazo (m); duración de la Furia
## y del Último aliento (s).
const CHARGE_COOLDOWN := 8.0
## Estaño: duración y recarga (s) de Foco, Marca del cazador, Mente despejada y Sentidos extremos.
const FOCUS_TIME := 5.0
const FOCUS_COOLDOWN := 20.0
const MARK_TIME := 15.0
const MARK_COOLDOWN := 25.0
const CLEAR_TIME := 12.0
const CLEAR_COOLDOWN := 30.0
const EXTREME_TIME := 12.0
const EXTREME_COOLDOWN := 35.0
## Cinc: duración (s), recarga (s) y radios (m) con el poder en nivel 1; cada nivel más dura un ZINC_PER_LEVEL más
## (ver ZincPowers.scale). Alcance de la mira para los que apuntan a un NPC.
const ZINC_RANGE := 25.0
const ZINC_PER_LEVEL := 0.15
const ZINC_FURY_TIME := 10.0
const ZINC_FURY_COOLDOWN := 12.0
const ZINC_FURY_XP := 0.5
const ZINC_PANIC_TIME := 8.0
const ZINC_PANIC_COOLDOWN := 20.0
const ZINC_PANIC_SEEN := 8.0  # los que están a esta distancia y lo ven huir se asustan con la mitad
const ZINC_GREED_TIME := 6.0
const ZINC_GREED_COOLDOWN := 18.0
const ZINC_GREED_RADIUS := 12.0
const ZINC_TAME_TIME := 45.0
const ZINC_TAME_COOLDOWN := 40.0
const ZINC_TAME_STRONG := 0.45  # los fuertes (más de 100 de vida) duran esta fracción
const ZINC_CONTAGION_RADIUS := 6.0
const ZINC_STORM_TIME := 20.0
const ZINC_STORM_COOLDOWN := 60.0
const ZINC_STORM_RADIUS := 15.0
const SLAM_COOLDOWN := 12.0
const SLAM_RADIUS := 6.0
const FURY_TIME := 8.0
const FURY_COOLDOWN := 45.0
const LAST_STAND_TIME := 3.0
const LAST_STAND_COOLDOWN := 60.0

## Escudo de monedas: cuánto dura (s) antes de retirarse solo.
const SHIELD_DURATION := 5.5

## Campo magnético: radio (m), duración y recarga (s). Lanza de acero: monedas que gasta, velocidad (m/s) y recarga (s).
const FIELD_RADIUS := 3.5
const FIELD_DURATION := 5.0
const FIELD_COOLDOWN := 12.0
const SPEAR_COST := 5
const SPEAR_SPEED := 60.0
const SPEAR_COOLDOWN := 4.0


## Probabilidad de que el escudo de monedas desvíe un golpe cuerpo a cuerpo: 40 % con 8 monedas y +3 % por moneda
## (76 % con 20).
static func shield_block_chance(coins: int) -> float:
	return clampf(0.4 + 0.03 * (coins - 8), 0.0, 0.8)

## Qué hace cada habilidad y cómo mejora con los niveles (se muestra al pasar el ratón por encima en el árbol).
const DESCRIPTIONS := {
	&"steel_combat_coin": "Clic derecho: lanza una moneda hacia donde apuntas. Si apuntas a algo fijo (suelo, pared, farola) a menos de 25 m, la moneda queda clavada al instante y el empuje empieza ya: sirve para frenar una caída, saltar o desplazarte. Mantén el clic para seguir empujando; si te interpones con algo, el lazo se corta.\nSi apuntas a un enemigo, un objeto suelto o algo más lejos, sale como proyectil rápido (60 m/s) que hiere al chocar.\nTe empuja solo cuando la moneda está clavada en algo fijo o más pesado que tu poder. Entre impulsos hay 1 s de recarga.\nCayendo, la moneda sale siempre hacia abajo (al menos 55° bajo la horizontal). En el aire, un aro suave en la mira te avisa cuando lo que apuntas está a distancia para impulsarte con la moneda.\nMejora: el empuje gana fuerza con cada nivel de la Moneda.",
	&"steel_light_push": "Mantén la tecla apuntando a un metal dentro del círculo de la mira: lo empuja lejos de ti. Lo fijo (farolas, rejas, anclas) o más pesado que tu poder no se mueve: te empuja a ti en sentido contrario. Lo más liviano sale despedido y casi no te mueve.\nTu poder de empuje es tu peso en el nivel 1 y sube con cada nivel de este poder: mueves cosas cada vez más pesadas que tú, y con más fuerza.",
	&"iron_pull": "Mantén la tecla apuntando a un metal dentro del círculo de la mira: lo trae hacia ti. Lo más liviano que tu poder viene curvando si te mueves; una moneda se guarda al tocarte y otro objeto puede golpearte. Lo fijo o más pesado que tu poder (farolas, rejas, techos) no se mueve: te acerca a él, así puedes subir a un techo.\nAl soltar la tecla, lo que traías cae con la física normal. Al terminar un agarre pasa solo al siguiente metal dentro del círculo.\nTu poder de tirón es tu peso en el nivel 1 y sube con cada nivel de este poder, igual que la fuerza.",
	&"iron_drag": "Un toque apuntando a un enemigo que lleve metal: lo arrastra hacia ti durante 1,5 s a 16 m/s y, al llegar a unos 2 m, queda aturdido 1 s. Necesita línea de visión.\nSolo arrastra a quien pese hasta tu poder de tirón (sube con los niveles del Tirón básico).\nRecarga: 6 s.",
	&"iron_hook": "Un toque apuntando a cualquier superficie fija a menos de 25 m (el mismo alcance que la moneda del clic derecho): clava una moneda ahí (gasta 1) y una soga te tira hacia ella hasta unos 28 m/s. Frenas al llegar y, durante un momento, los golpes casi no te lastiman. Sirve para trepar y cruzar entre techos sin depender de farolas.\nRecarga: 3 s.",
	&"iron_disarm": "Un toque apuntando a un enemigo con arma metálica: el arma sale despedida y cae al piso a mitad de camino entre él y tú; durante 8 s ese enemigo pega un 70 % menos. Con hierro puedes tirar del arma que cayó.\nRecarga: 8 s.",
	&"iron_mass_yank": "Un toque: tira de todos los enemigos con metal en 12 m a la vez y los junta en un anillo a tu alrededor; quedan aturdidos 1,2 s. Solo a los que pesan hasta tu poder de tirón (sube con los niveles del Tirón básico).\nRecarga: 20 s.",
	&"pewter_endurance": "Pasiva: mientras quemas peltre aguantas más: gastas menos aguante, lo recuperas antes y recibes menos daño y menos empujón.\nQuemando: ~40 % menos daño; avivando: ~55 % menos.",
	&"pewter_charge": "Un toque: te lanzas hacia donde miras unos 0,4 s a gran velocidad; a quien toques en el camino lo golpeas, lo empujas y lo dejas aturdido 1,5 s. Más fuerte con el peltre encendido.\nRecarga: 8 s.",
	&"pewter_strike": "Pasiva: con peltre pegas más fuerte y más rápido: +75 % de daño y más empuje cuerpo a cuerpo; avivando, más aún.",
	&"pewter_slam": "Un toque en el suelo: golpeas la tierra con una onda de choque de 6 m que daña, empuja y aturde 1,2 s a todos los que te rodean.\nRecarga: 12 s.",
	&"pewter_last_stand": "Pasiva: cuando un golpe te dejaría por debajo del 20 % de vida, sobrevives (con 1 de vida como mínimo), eres intocable 3 s y te curas un 40 % de tu vida en ese tiempo. Se activa sola.\nRecarga: 60 s.",
	&"pewter_fury": "Un toque: durante 8 s el peltre arde avivado sin gastar metal, y pegas un 30 % más fuerte. Al terminar quedas sin aliento un momento.\nRecarga: 45 s.",
	&"tin_senses": "Pasiva: con estaño quemando ves más lejos y mejor en la bruma y la noche, y te recuperas antes de un golpe (más aún avivando). Es lo que hace el estaño desde el principio.",
	&"tin_focus": "Un toque: durante 5 s la cámara hace zoom (el campo de visión baja un 40 %) y tienes un 25 % más de probabilidad de crítico.\nRecarga: 20 s.",
	&"tin_ear": "Pasiva: con estaño quemando «oyes» a la gente cercana (hasta 22 m, más si avivas). Si la ves de frente, solo se remarca su silueta con un borde tenue. Si una pared te la tapa, ves una estela de humo sin forma definida que sale de donde estaba hace 0,5 s.",
	&"tin_mark": "Un toque apuntando a un enemigo: lo marcas 15 s y recibe un 25 % más de daño tuyo. Si lo ves de frente, su silueta se remarca con fuerza. Si hay una pared, ves un humo más denso y concentrado de donde estaba hace solo 0,2 s.\nEl estaño arde mientras dura.\nRecarga: 25 s.",
	&"tin_clear_mind": "Un toque: durante 12 s casi nada te descontrola. Los relámpagos no te encandilan, no te aplacan ni te enardecen, los golpes apenas te empujan ni te hacen perder el equilibrio y tu guardia no se rompe. Además se te quita al instante lo que tengas encima.\nRecarga: 30 s.",
	&"zinc_fury": "Un toque apuntando a un NPC: lo enardecés 10 s. Ataca más seguido, no retrocede y recibe un 25 % más de daño. Si mientras dura mata a otro NPC, te llevás el 50 % de la experiencia de esa muerte.\nQuien quema cobre lo resiste.\nRecarga: 12 s.",
	&"zinc_panic": "Un toque apuntando a un NPC: suelta la guardia y huye de vos 8 s. Si es un guardia, abandona su puesto. Los que están cerca y lo ven huir se asustan con la mitad.\nRecarga: 20 s.",
	&"zinc_greed": "Un toque: lanzás una moneda adonde apuntás y los NPC a 12 m de ella van a buscarla, sin hacerte caso, durante 6 s. Los guardias dejan su puesto. Sirve de señuelo y combina con el acero.\nCuesta una moneda. Recarga: 18 s.",
	&"zinc_tame": "Un toque apuntando a un NPC común: te sigue y pelea por vos 45 s. Los fuertes duran menos y los jefes no se dejan. Mientras está domado, toda la experiencia de lo que mate es tuya.\nSolo uno a la vez: domar a otro suelta al anterior.\nRecarga: 40 s.",
	&"zinc_contagion": "Pasiva: la Furia y el Pánico que pongas en un NPC se pasan a los que están a 6 m, con la mitad de duración. La ira pelea en cadena y el miedo se vuelve una huida en masa.",
	&"zinc_storm": "Un toque: a cada NPC a 15 m le das la emoción que mejor le encaja durante 20 s. Ira a los guardias, koloss y alománticos, que se atacan entre ellos (y te llevás el 50 % de la experiencia de esas muertes); pánico a los ciudadanos; y lealtad al más débil que pelee, que pasa a pelear por vos.\nRecarga: 60 s.",
	&"tin_extreme": "Un toque: durante 12 s ves a todos los que estén hasta 45 m. De frente, se remarca su silueta; detrás de paredes, un humo más marcado que con Oído agudo, en tiempo real.\nEl estaño arde mientras dura.\nRecarga: 35 s.",
}


## Partes del tooltip de una habilidad (ver SkillTooltip): "body" (qué hace y cómo mejora, con párrafos separados
## por salto de línea), "now" (los números con el nivel actual del poder y con el siguiente) y "unlock" (qué falta
## para poder ponerle un punto).
static func tooltip_parts(id: StringName, skill_level: int) -> Dictionary:
	var s := find(id)
	if s.is_empty():
		return {}
	var body: String = DESCRIPTIONS.get(id, "")
	match id:
		&"steel_coin_burst":
			body = "Lanza monedas en abanico hacia donde apunta el ratón. Gasta una moneda del monedero por cada una.\nSiempre sale una cantidad impar, con una moneda justo en el centro, donde apuntas.\nCon cada nivel salen más monedas y el cono se abre hasta cerrar un círculo completo a tu alrededor; las que sobran salen hacia arriba y hacia abajo.\nMonedas por nivel: %s." % _per_level(id, func(eq: int) -> String: return str(fan_count(eq, BURST_MIN_LEVEL)))
		&"iron_coin_magnet":
			body = "Atrae las monedas sueltas cercanas hacia donde apunta el ratón; vuelan hacia ti y se guardan al tocarte, sin hacerte daño.\nCon cada nivel atrae más monedas y el cono se abre, hasta atraer todas las de alrededor.\nMonedas por nivel: %s." % _per_level(id, func(eq: int) -> String: return str(fan_count(eq)))
		&"steel_coin_shield":
			body = "Pulsa la tecla: monedas del monedero giran a tu alrededor en órbitas inclinadas que se cruzan, como el escudo de maná de un mago. Cada golpe cuerpo a cuerpo que te den tiene una probabilidad de ser desviado: sin daño ni empuje. No frena proyectiles (para eso está el Campo magnético).\nDura 5,5 s y se retira solo (o pulsando de nuevo): las monedas no se gastan, vuelven al monedero.\nCon más monedas, más probabilidad. Monedas por nivel: %s.\nCombinación: la Ráfaga de monedas o el Campo magnético con el escudo puesto lo hacen reventar: sus monedas y muchas más del monedero salen volando, con una onda magnética." % _per_level(id, func(eq: int) -> String: return str(shield_count(eq)))
		&"steel_magnetic_field":
			body = "Durante %d segundos un campo magnético te rodea (hasta %d m): las monedas y proyectiles metálicos enemigos que se acercan se desvían y vuelven hacia quien los lanzó, con su misma velocidad y daño. Es la defensa contra ataques a distancia.\nCombinación: el Imán de monedas con el campo puesto trae todas las monedas cercanas, rebotan hacia afuera y el campo se rompe en una onda de choque. Encenderlo con el Escudo de monedas puesto hace reventar el escudo.\nRecarga: %d s." % [int(FIELD_DURATION), int(FIELD_RADIUS), int(FIELD_COOLDOWN)]
		&"steel_spear":
			body = "Gasta %d monedas en un solo proyectil muy veloz y pesado que sale hacia donde apuntas, atraviesa hasta 4 enemigos y pega muy fuerte, lanzándolos lejos.\nRecarga: %d s." % [SPEAR_COST, int(SPEAR_COOLDOWN)]
	var lines := PackedStringArray()
	var top := max_level(id)
	if skill_level >= 1 and _numbers(id, equiv_level(id, skill_level)) != "":
		lines.append("Ahora (nivel %d/%d): %s" % [skill_level, top, _numbers(id, equiv_level(id, skill_level))])
	if skill_level < top and _numbers(id, equiv_level(id, skill_level + 1)) != "":
		lines.append("Nivel %d: %s" % [skill_level + 1, _numbers(id, equiv_level(id, skill_level + 1))])
	var unlock := ""
	var missing := PackedStringArray()
	for p in parents(id):
		if Progression.skill_level(p) < 1:
			missing.append(String(find(p)["name"]))
	if not missing.is_empty():
		unlock = "Necesita: %s." % ", ".join(missing)
	return {"body": body, "now": "\n".join(lines), "unlock": unlock}


## Los números de un poder en un nivel equivalente (escala vieja 1-20; ver equiv_level). "" = sin números.
static func _numbers(id: StringName, eq: int) -> String:
	match id:
		&"steel_coin_burst":
			var up := fan_count(eq, BURST_MIN_LEVEL) - BURST_CIRCLE
			if up > 0:
				return "%d monedas en círculo y %d hacia arriba y abajo." % [BURST_CIRCLE, up]
			return _fan_text("monedas", eq, BURST_MIN_LEVEL)
		&"iron_coin_magnet":
			return _fan_text("monedas atraídas", eq, FAN_MIN_LEVEL)
		&"iron_drag", &"iron_mass_yank":
			return "arrastras a quien pese hasta %d kg (según tu Tirón básico)." % roundi(power_mass(equiv_level(&"iron_pull", Progression.skill_level(&"iron_pull"))))
		&"steel_light_push", &"iron_pull":
			return "mueves objetos de hasta %d kg, con %d %% más de fuerza; lo más pesado o fijo te mueve a ti." % [roundi(power_mass(eq)), roundi(3.0 * maxi(eq - 1, 0))]
		&"steel_combat_coin":
			return "el empuje de la moneda tiene %d %% más de fuerza." % roundi(3.0 * maxi(eq - 1, 0))
		&"steel_coin_shield":
			return "%d monedas, %d %% de probabilidad de desviar un golpe." % [shield_count(eq), roundi(shield_block_chance(shield_count(eq)) * 100.0)]
	return ""


static func _fan_text(noun: String, eq: int, min_level: int) -> String:
	var n := fan_count(eq, min_level)
	if fan_angle(eq, min_level) >= TAU:
		return "%d %s, en círculo completo." % [n, noun]
	return "%d %s, cono de %d°." % [n, noun, roundi(rad_to_deg(fan_angle(eq, min_level)))]


## "3, 7, 11, 15 y 19": el número de cada nivel del poder.
static func _per_level(id: StringName, text: Callable) -> String:
	var out := PackedStringArray()
	for lvl in range(1, max_level(id) + 1):
		out.append(text.call(equiv_level(id, lvl)))
	return ", ".join(out.slice(0, -1)) + " y " + out[-1] if out.size() > 1 else out[0]
