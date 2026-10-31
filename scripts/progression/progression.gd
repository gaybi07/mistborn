class_name Progression
## Progreso del jugador: nivel, experiencia y nivel de cada metal. Cada nivel de jugador da un punto de
## alomancia; subir un nivel de metal cuesta puntos (atium, el doble y con tope más bajo). Se puede reasignar
## todo fuera de combate. Se guarda en user://progression.cfg (ver docs/arbol-de-habilidades.md).

const PATH := "user://progression.cfg"
const MAX_LEVEL := 100
const MAX_METAL_LEVEL := 20
const MAX_ATIUM_LEVEL := 10
## Metales que se tienen en nivel 1 sin gastar puntos.
const FREE_METALS: Array[StringName] = [&"steel", &"iron"]

static var level := 1
static var xp := 0
## Nivel de cada metal (0 = todavía no aprendido).
static var metal_levels: Dictionary = {}
static var _loaded := false


static func _static_init() -> void:
	reset()


## Vuelve al inicio: jugador 1 con acero y hierro en nivel 1.
static func reset() -> void:
	level = 1
	xp = 0
	metal_levels.clear()
	for m: StringName in Allomancy.METALS:
		metal_levels[m] = 1 if m in FREE_METALS else 0


static func metal_level(metal: StringName) -> int:
	return int(metal_levels.get(metal, 0))


static func metal_cap(metal: StringName) -> int:
	return MAX_ATIUM_LEVEL if metal == &"atium" else MAX_METAL_LEVEL


## Puntos que cuesta cada nivel de ese metal.
static func point_cost(metal: StringName) -> int:
	return 2 if metal == &"atium" else 1


## Un punto por cada nivel de jugador por encima del 1.
static func points_total() -> int:
	return level - 1


static func points_spent() -> int:
	var spent := 0
	for m: StringName in metal_levels:
		var free := 1 if m in FREE_METALS else 0
		spent += maxi(metal_level(m) - free, 0) * point_cost(m)
	return spent


static func points_free() -> int:
	return points_total() - points_spent()


## Experiencia necesaria para pasar del nivel `lvl` al siguiente (curva de prueba, a ajustar).
static func xp_for_next(lvl: int) -> int:
	return 60 + 25 * lvl + lvl * lvl / 2


## Suma experiencia; devuelve cuántos niveles de jugador se subieron.
static func add_xp(amount: int) -> int:
	if amount <= 0 or level >= MAX_LEVEL:
		return 0
	xp += amount
	var gained := 0
	while level < MAX_LEVEL and xp >= xp_for_next(level):
		xp -= xp_for_next(level)
		level += 1
		gained += 1
	if level >= MAX_LEVEL:
		xp = 0
	if gained > 0:
		save()
	return gained


static func can_raise(metal: StringName) -> bool:
	return metal_levels.has(metal) and metal_level(metal) < metal_cap(metal) and points_free() >= point_cost(metal)


static func raise_metal(metal: StringName) -> bool:
	if not can_raise(metal):
		return false
	metal_levels[metal] = metal_level(metal) + 1
	save()
	return true


## Devuelve todos los puntos (no se llama en combate: lo decide el menú). Acero y hierro quedan en 1.
static func respec() -> void:
	for m: StringName in metal_levels:
		metal_levels[m] = 1 if m in FREE_METALS else 0
	save()


static func load_progress() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	level = clampi(int(cfg.get_value("jugador", "nivel", level)), 1, MAX_LEVEL)
	xp = maxi(int(cfg.get_value("jugador", "xp", xp)), 0)
	for m: StringName in metal_levels:
		var saved := clampi(int(cfg.get_value("metales", String(m), metal_levels[m])), 0, metal_cap(m))
		metal_levels[m] = maxi(saved, 1 if m in FREE_METALS else 0)
	# Un archivo editado a mano no puede dar más niveles de los que pagan los puntos.
	if points_free() < 0:
		respec()


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("jugador", "nivel", level)
	cfg.set_value("jugador", "xp", xp)
	for m: StringName in metal_levels:
		cfg.set_value("metales", String(m), metal_levels[m])
	cfg.save(PATH)
