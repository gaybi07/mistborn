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

## id, metal, nivel de metal, tipo y nombre.
const SKILLS := [
	{"id": &"steel_light_push", "metal": &"steel", "level": 1, "kind": Kind.ACTIVE, "name": "Empuje básico"},
	{"id": &"steel_combat_coin", "metal": &"steel", "level": 2, "kind": Kind.ACTIVE, "name": "Moneda de combate"},
	{"id": &"steel_coin_burst", "metal": &"steel", "level": 3, "kind": Kind.ACTIVE, "name": "Ráfaga de monedas"},
	{"id": &"steel_coin_shield", "metal": &"steel", "level": 8, "kind": Kind.ACTIVE, "name": "Escudo de monedas"},
	{"id": &"steel_magnetic_field", "metal": &"steel", "level": 12, "kind": Kind.ACTIVE, "name": "Campo magnético"},
	{"id": &"steel_spear", "metal": &"steel", "level": 20, "kind": Kind.ACTIVE, "name": "Lanza de acero"},
	{"id": &"iron_pull", "metal": &"iron", "level": 1, "kind": Kind.ACTIVE, "name": "Tirón básico"},
	{"id": &"iron_light_pull", "metal": &"iron", "level": 4, "kind": Kind.PASSIVE, "name": "Tirón ligero"},
	{"id": &"iron_coin_magnet", "metal": &"iron", "level": 2, "kind": Kind.ACTIVE, "name": "Imán de monedas"},
	{"id": &"iron_coin_anchor", "metal": &"iron", "level": 8, "kind": Kind.ACTIVE, "name": "Anclaje de monedas"},
	{"id": &"iron_weapon_pull", "metal": &"iron", "level": 12, "kind": Kind.ACTIVE, "name": "Tirón de armas"},
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
const PENDING: Array[StringName] = [&"iron_coin_anchor", &"iron_weapon_pull", &"iron_swing", &"pewter_fury"]
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


## Siempre impar, para que haya una moneda justo en el centro (donde apunta el ratón): 3 en el nivel 2 y dos más (una a
## cada lado) cada 2 niveles; 21 en el 20.
static func fan_count(metal_level: int, min_level := FAN_MIN_LEVEL) -> int:
	return 3 + 2 * maxi((metal_level - min_level) / 2, 0)


## Ángulo total (rad) del abanico; TAU = radial.
static func fan_angle(metal_level: int, min_level := FAN_MIN_LEVEL) -> float:
	if metal_level >= FAN_RADIAL_LEVEL:
		return TAU
	return lerpf(FAN_MIN_ANGLE, FAN_MAX_ANGLE, clampf(float(metal_level - min_level) / float(FAN_RADIAL_LEVEL - 1 - min_level), 0.0, 1.0))


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


## Poder de empuje y de tirón: hasta qué masa (kg) mueves lo que empujas o tiras en vez de que te mueva a ti. Es tu
## peso en el nivel 1 y sube un 15 % por nivel de acero o hierro (con 70 kg: 70 en el 1, 143 en el 8, 270 en el 20).
static func power_mass(metal_level: int, body_mass := BODY_MASS) -> float:
	return body_mass * (1.0 + POWER_PER_LEVEL * maxi(metal_level - 1, 0))


## Monedas que giran a tu alrededor con el Escudo de monedas: 8 en el nivel 8 y una más por nivel (20 en el 20).
## Cada una bloquea un golpe.
static func shield_count(metal_level: int) -> int:
	return 0 if metal_level < 8 else metal_level


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
	&"steel_combat_coin": "Clic derecho: lanza una moneda hacia donde apuntas. Si apuntas a algo fijo (suelo, pared, farola) a menos de 25 m, la moneda queda clavada al instante y el empuje empieza ya: sirve para frenar una caída, saltar o desplazarte. Mantén el clic para seguir empujando; si te interpones con algo, el lazo se corta.\nSi apuntas a un enemigo, un objeto suelto o algo más lejos, sale como proyectil rápido (60 m/s) que hiere al chocar.\nTe empuja solo cuando la moneda está clavada en algo fijo o más pesado que tu poder. Entre impulsos hay 1 s de recarga.\nCayendo, la moneda sale siempre hacia abajo (al menos 55° bajo la horizontal). En el aire, un aro suave en la mira te avisa cuando lo que apuntas está a distancia para impulsarte con la moneda.\nMejora: el empuje gana un 3 % de fuerza por nivel de acero.",
	&"steel_light_push": "Mantén la tecla apuntando a un metal dentro del círculo de la mira: lo empuja lejos de ti. Lo fijo (farolas, rejas, anclas) o más pesado que tu poder no se mueve: te empuja a ti en sentido contrario. Lo más liviano sale despedido y casi no te mueve.\nTu poder de empuje es tu peso en el nivel 1 y sube un 15 % por nivel: con más niveles mueves cosas cada vez más pesadas que tú.\nLa fuerza también sube un 3 % por nivel.",
	&"iron_pull": "Mantén la tecla apuntando a un metal dentro del círculo de la mira: lo trae hacia ti. Lo más liviano que tu poder viene curvando si te mueves; una moneda se guarda al tocarte y otro objeto puede golpearte. Lo fijo o más pesado que tu poder (farolas, rejas, techos) no se mueve: te acerca a él, así puedes subir a un techo.\nAl soltar la tecla, lo que traías cae con la física normal. Al terminar un agarre pasa solo al siguiente metal dentro del círculo.\nTu poder de tirón es tu peso en el nivel 1 y sube un 15 % por nivel; la fuerza sube un 3 % por nivel.",
	&"iron_light_pull": "Pasiva (hito del nivel 4): el tirón de hierro gana un 10 % de fuerza extra. Se suma al 3 % por nivel y a tu poder de tirón.",
	&"iron_mass_pull": "Pasiva (hito del nivel 20): el tirón de hierro gana un 25 % de fuerza extra. Se suma al 3 % por nivel y a tu poder de tirón, que en el nivel 20 llega a casi cuatro veces tu peso.",
	&"iron_swing": "Próximamente: columpiarte de un ancla con más control en el aire.",
	&"iron_coin_anchor": "Próximamente: clava monedas en paredes y suelo como anclas temporales para columpiarte con hierro.",
	&"iron_weapon_pull": "Próximamente: arranca el arma metálica de un enemigo y te la trae.",
	&"pewter_endurance": "Pasiva: mientras quemas peltre aguantas más: gastas menos aguante, lo recuperas antes y recibes menos daño y menos empujón.\nQuemando: ~40 % menos daño; avivando: ~55 % menos.",
	&"pewter_jump": "Pasiva: con peltre quemando saltas más alto (+30 %) y el doble salto (Espacio, Espacio en el aire) es mucho más fuerte. Con acero también da un impulso extra al salto recto hacia arriba.",
	&"pewter_strike": "Pasiva: con peltre pegas más fuerte y más rápido: +75 % de daño y más empuje cuerpo a cuerpo; avivando, más aún.",
	&"pewter_landing": "Pasiva: con peltre soportas caídas e impactos: el umbral de daño sube 8 m/s quemando y el daño que sí recibes se reduce.",
	&"pewter_second_wind": "Pasiva: con peltre quemando recuperas vida mucho más rápido cuando llevas un rato sin recibir daño (triple de velocidad quemando).",
	&"pewter_fury": "Próximamente: ráfaga de velocidad y daño con peltre.",
}


## Partes del tooltip de una habilidad (ver SkillTooltip): "body" (qué hace y cómo mejora, con párrafos separados
## por salto de línea), "now" (los números con el nivel actual del metal) y "unlock" (cuándo se desbloquea).
static func tooltip_parts(id: StringName, metal_level: int) -> Dictionary:
	var s := find(id)
	if s.is_empty():
		return {}
	var body: String = DESCRIPTIONS.get(id, "")
	var now := ""
	match id:
		&"steel_coin_burst":
			body = "Lanza monedas en abanico hacia donde apunta el ratón. Gasta una moneda del monedero por cada una.\nSiempre sale una cantidad impar, con una moneda justo en el centro, donde apuntas.\nNivel 3: 3 monedas en un cono de 30°. Cada 2 niveles suma 2 monedas (una a cada lado) y el cono se abre; desde el nivel 15 es una ráfaga ancha alrededor de donde apuntas."
			now = _fan_now("monedas", metal_level, BURST_MIN_LEVEL)
		&"iron_coin_magnet":
			body = "Atrae las monedas sueltas cercanas hacia donde apunta el ratón; vuelan hacia ti y se guardan al tocarte, sin hacerte daño.\nNivel 2: hasta 3 monedas en un cono de 30°. Cada 2 niveles suma 2 monedas y el cono se abre; en el nivel 15 atrae todas las de alrededor."
			now = _fan_now("monedas atraídas", metal_level, FAN_MIN_LEVEL)
		&"steel_light_push", &"iron_pull":
			now = "Ahora (nivel %d): mueves objetos de hasta %d kg; lo más pesado o fijo te mueve a ti." % [metal_level, roundi(power_mass(metal_level))]
		&"steel_coin_shield":
			body = "Pulsa la tecla: monedas del monedero giran a tu alrededor en órbitas inclinadas que se cruzan, como el escudo de maná de un mago. Cada golpe cuerpo a cuerpo que te den tiene una probabilidad de ser desviado: sin daño ni empuje. No frena proyectiles (para eso está el Campo magnético).\nDura 5,5 s y se retira solo (o pulsando de nuevo): las monedas no se gastan, vuelven al monedero.\n8 monedas en el nivel 8 y una más por nivel (20 en el 20). Con más monedas, más probabilidad: 40 % con 8 y 3 % más por moneda (76 % con 20)."
			if metal_level >= 8:
				now = "Ahora (nivel %d): %d monedas, %d %% de probabilidad de desviar un golpe." % [metal_level, shield_count(metal_level), roundi(shield_block_chance(shield_count(metal_level)) * 100.0)]
		&"steel_magnetic_field":
			body = "Durante %d segundos un campo magnético te rodea (hasta %d m): las monedas y proyectiles metálicos enemigos que se acercan se desvían y vuelven hacia quien los lanzó, con su misma velocidad y daño. Es la defensa contra ataques a distancia.\nRecarga: %d s." % [int(FIELD_DURATION), int(FIELD_RADIUS), int(FIELD_COOLDOWN)]
		&"steel_spear":
			body = "Gasta %d monedas en un solo proyectil muy veloz y pesado que sale hacia donde apuntas, atraviesa hasta 4 enemigos y pega muy fuerte, lanzándolos lejos.\nRecarga: %d s." % [SPEAR_COST, int(SPEAR_COOLDOWN)]
	var unlock := ""
	if int(s["level"]) > metal_level:
		unlock = "Se desbloquea en el nivel %d." % int(s["level"])
	return {"body": body, "now": now, "unlock": unlock}


static func _fan_now(noun: String, metal_level: int, min_level: int) -> String:
	if metal_level < min_level:
		return ""
	var n := fan_count(metal_level, min_level)
	if fan_angle(metal_level, min_level) >= TAU:
		return "Ahora (nivel %d): %d %s, en círculo completo." % [metal_level, n, noun]
	return "Ahora (nivel %d): %d %s, cono de %d°." % [metal_level, n, noun, roundi(rad_to_deg(fan_angle(metal_level, min_level)))]
