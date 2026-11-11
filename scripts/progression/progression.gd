class_name Progression
## Progreso del jugador: nivel, experiencia y puntos en cada poder (ver docs/PLAN_PROGRESION.md). Lo único que se
## guarda es el nivel de cada poder; el nivel de un metal es la suma de los puntos en sus poderes. Hay
## maxi(nivel, START_POINTS) puntos: 3 en los niveles 1-3 y uno más por nivel hasta 100. Se reasigna gratis.
## Se guarda en user://progression.cfg.

## var y no const: progression_check la apunta a otro archivo para no pisar la partida.
static var save_path := "user://progression.cfg"
const MAX_LEVEL := 100
const START_POINTS := 3
## Inicio recomendado (los 3 puntos del comienzo): Empuje y Tirón básicos y la Moneda de combate.
const START_SKILLS := {&"steel_light_push": 1, &"iron_pull": 1, &"steel_combat_coin": 1}
## shortcut: tope y costo de los metales que se suben directo (sin poderes todavía) y de la validación de red;
## se van con L12 (direct_levels) y L19 (red).
const MAX_METAL_LEVEL := 20
const MAX_ATIUM_LEVEL := 10
const FREE_METALS: Array[StringName] = [&"steel", &"iron"]

## Ranuras de habilidades activas: cada una tiene una tecla (reasignable) y la habilidad que el jugador puso.
const SLOT_COUNT := 12
## Ranuras (por defecto con las teclas Q y E) de Empuje básico y Tirón básico: vienen puestos desde el inicio.
const BASIC_PUSH_SLOT := 4
const BASIC_PULL_SLOT := 5
const DEFAULT_SLOT_KEYS: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_Q, KEY_E, KEY_5, KEY_F, KEY_Z, KEY_X, KEY_C, KEY_V]

## Tecla de la moneda de combate: un código de teclado o, en negativo, un botón del ratón (-2 = clic derecho, por defecto).
const DEFAULT_COIN_KEY := -2

static var level := 1
static var xp := 0
static var coin_key := DEFAULT_COIN_KEY
## Habilidad de cada ranura (&"" = vacía) y su tecla.
static var slot_skills: Array[StringName] = []
static var slot_keys: Array[int] = []
## Nivel de cada poder (id -> 0..SkillTree.max_level). Falta = 0.
static var skill_levels: Dictionary = {}
## shortcut: niveles de los metales sin poderes (atium, cinc, cobre, bronce, latón), subidos directo como antes;
## se borra con L12, cuando todos tengan poderes.
static var direct_levels: Dictionary = {}
static var _loaded := false
## Sube cada vez que el progreso cambia (los clientes lo usan para reenviarlo al servidor).
static var revision := 0


static func _static_init() -> void:
	reset()


## Vuelve al inicio: jugador 1 con el inicio recomendado.
static func reset() -> void:
	level = 1
	xp = 0
	_start_skills()
	reset_slots()


static func _start_skills() -> void:
	skill_levels = START_SKILLS.duplicate()
	direct_levels.clear()


## Ranuras y teclas por defecto: Empuje básico en Q, Tirón básico en E y la moneda de combate en el clic derecho.
static func reset_slots() -> void:
	slot_skills.clear()
	slot_keys.clear()
	for i in SLOT_COUNT:
		slot_skills.append(&"")
		slot_keys.append(DEFAULT_SLOT_KEYS[i])
	slot_skills[BASIC_PUSH_SLOT] = &"steel_light_push"  # Q
	slot_skills[BASIC_PULL_SLOT] = &"iron_pull"  # E
	coin_key = DEFAULT_COIN_KEY
	apply_coin_binding()


## Nombre corto de una tecla de ranura (o del botón del ratón de la moneda de combate).
static func key_name(code: int) -> String:
	if code >= 0:
		return OS.get_keycode_string(code as Key)
	match -code:
		MOUSE_BUTTON_RIGHT:
			return "RMB"
		MOUSE_BUTTON_MIDDLE:
			return "MMB"
		MOUSE_BUTTON_XBUTTON1:
			return "Ratón 4"
		MOUSE_BUTTON_XBUTTON2:
			return "Ratón 5"
	return "Ratón %d" % -code


## Pone en la acción de entrada de la moneda de combate la tecla o el botón elegidos.
static func apply_coin_binding() -> void:
	if not InputMap.has_action(&"coin_shot"):
		return
	InputMap.action_erase_events(&"coin_shot")
	if coin_key < 0:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = (-coin_key) as MouseButton
		InputMap.action_add_event(&"coin_shot", mouse)
	else:
		var key := InputEventKey.new()
		key.physical_keycode = coin_key as Key
		InputMap.action_add_event(&"coin_shot", key)


## Cambia la tecla de la moneda de combate (teclado o ratón, menos el clic izquierdo, que ataca). Si una ranura tenía esa
## tecla, intercambian. Devuelve false si no se pudo.
static func rebind_coin(code: int) -> bool:
	if code == -MOUSE_BUTTON_LEFT:
		return false
	var other := slot_keys.find(code)
	if other >= 0:
		if coin_key < 0:
			return false  # la ranura no puede quedarse con un botón del ratón
		slot_keys[other] = coin_key
	coin_key = code
	apply_coin_binding()
	save()
	return true


static func skill_level(id: StringName) -> int:
	return int(skill_levels.get(id, 0))


## Suma de los puntos en los poderes de ese metal (de los dos árboles) más su nivel directo. 0 = no aprendido.
static func metal_level(metal: StringName) -> int:
	return metal_level_of(skill_levels, direct_levels, metal)


## Lo mismo para cualquier juego de niveles (sirve también para lo que manda un cliente en red).
static func metal_level_of(levels: Dictionary, direct: Dictionary, metal: StringName) -> int:
	var total := int(direct.get(metal, 0))
	for s: Dictionary in SkillTree.skills_of(metal):
		total += int(levels.get(s["id"], 0))
	return total


## Metal que todavía no tiene poderes: se sube directo con "+".
static func is_direct_metal(metal: StringName) -> bool:
	return Allomancy.METALS.has(metal) and SkillTree.skills_of(metal).is_empty()


static func metal_cap(metal: StringName) -> int:
	return MAX_ATIUM_LEVEL if metal == &"atium" else MAX_METAL_LEVEL


## Puntos que cuesta cada nivel directo de ese metal.
static func point_cost(metal: StringName) -> int:
	return 2 if metal == &"atium" else 1


## 3 puntos en los niveles 1-3, después uno por nivel (100 en el 100).
static func points_total() -> int:
	return maxi(level, START_POINTS)


static func points_spent() -> int:
	var spent := 0
	for id: StringName in skill_levels:
		spent += skill_level(id) * SkillTree.skill_cost(id)
	for m: StringName in direct_levels:
		spent += int(direct_levels[m]) * point_cost(m)
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


static func can_raise_skill(id: StringName) -> bool:
	return not SkillTree.find(id).is_empty() and skill_level(id) < SkillTree.max_level(id) \
			and points_free() >= SkillTree.skill_cost(id) and SkillTree.requirements_met(id)


static func raise_skill(id: StringName) -> bool:
	if not can_raise_skill(id):
		return false
	skill_levels[id] = skill_level(id) + 1
	save()
	return true


## Costo de devolver un punto. Hoy es gratis; es la única costura para cobrar más adelante.
static func refund_cost() -> int:
	return 0


## Poder que quedaría sin su requisito si se baja un punto de `id` (&"" = ninguno, se puede bajar).
static func lower_blocker(id: StringName) -> StringName:
	if skill_level(id) <= 0:
		return &""
	skill_levels[id] = skill_level(id) - 1
	var blocker := &""
	for other: StringName in skill_levels:
		if skill_level(other) > 0 and not SkillTree.requirements_met(other):
			blocker = other
			break
	skill_levels[id] = skill_level(id) + 1
	return blocker


static func can_lower_skill(id: StringName) -> bool:
	return skill_level(id) > 0 and lower_blocker(id) == &"" and points_free() + SkillTree.skill_cost(id) >= refund_cost()


static func lower_skill(id: StringName) -> bool:
	if not can_lower_skill(id):
		return false
	skill_levels[id] = skill_level(id) - 1
	if skill_level(id) == 0:
		skill_levels.erase(id)
	prune_slots()
	save()
	return true


## shortcut: "+" de los metales sin poderes (ver direct_levels).
static func can_raise(metal: StringName) -> bool:
	return is_direct_metal(metal) and metal_level(metal) < metal_cap(metal) and points_free() >= point_cost(metal)


static func raise_metal(metal: StringName) -> bool:
	if not can_raise(metal):
		return false
	direct_levels[metal] = int(direct_levels.get(metal, 0)) + 1
	save()
	return true


## Devuelve todos los puntos y deja el inicio recomendado; las ranuras con habilidades perdidas se vacían.
static func respec() -> void:
	_start_skills()
	prune_slots()
	save()


## Si los niveles cargados son posibles: cada poder con sus requisitos y sin gastar más puntos de los que hay.
static func is_valid() -> bool:
	if points_free() < 0:
		return false
	for id: StringName in skill_levels:
		if skill_level(id) > 0 and not SkillTree.requirements_met(id):
			return false
	return true


## Vacía las ranuras cuya habilidad ya no está desbloqueada.
static func prune_slots() -> void:
	for i in SLOT_COUNT:
		if slot_skills[i] != &"" and not SkillTree.is_unlocked(slot_skills[i]):
			slot_skills[i] = &""


## Ranura (o -1) que tiene esa habilidad.
static func slot_of(skill: StringName) -> int:
	return slot_skills.find(skill)


## Ranura (o -1) cuya tecla es `key` y tiene una habilidad puesta.
static func slot_for_key(key: int) -> int:
	for i in SLOT_COUNT:
		if slot_keys[i] == key and slot_skills[i] != &"":
			return i
	return -1


## Pone la habilidad en la primera ranura libre. Devuelve false si ya estaba o no hay lugar.
static func assign_skill(skill: StringName) -> bool:
	if slot_of(skill) >= 0:
		return false
	var free := slot_skills.find(&"")
	if free < 0:
		return false
	slot_skills[free] = skill
	save()
	return true


## Pone la habilidad en esa ranura. Si ya estaba en otra, las dos intercambian lugar; lo que hubiera en la ranura y no tenga
## adónde ir queda sin ranura.
static func assign_to_slot(skill: StringName, index: int) -> void:
	var old := slot_skills.find(skill)
	if old == index:
		return
	var displaced := slot_skills[index]
	slot_skills[index] = skill
	if old >= 0:
		slot_skills[old] = displaced
	save()


static func clear_slot(index: int) -> void:
	slot_skills[index] = &""
	save()


## Cambia la tecla de una ranura; si otra ranura la tenía, intercambian teclas.
static func rebind_slot(index: int, key: int) -> void:
	var old := slot_keys[index]
	var other := slot_keys.find(key)
	if other >= 0 and other != index:
		slot_keys[other] = old
	elif key == coin_key:
		coin_key = old
		apply_coin_binding()
	slot_keys[index] = key
	save()


static func load_progress() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	level = clampi(int(cfg.get_value("jugador", "nivel", level)), 1, MAX_LEVEL)
	xp = maxi(int(cfg.get_value("jugador", "xp", xp)), 0)
	# Antes de la versión 5 los puntos iban en metales ([metales]): se ignoran y queda el inicio recomendado.
	if int(cfg.get_value("ranuras", "version", 1)) >= 5:
		skill_levels.clear()
		direct_levels.clear()
		for key: String in (cfg.get_section_keys("poderes") if cfg.has_section("poderes") else PackedStringArray()):
			var id := StringName(key)
			var lvl := clampi(int(cfg.get_value("poderes", key)), 0, SkillTree.max_level(id))
			if not SkillTree.find(id).is_empty() and lvl > 0:
				skill_levels[id] = lvl
		for key: String in (cfg.get_section_keys("metales_directos") if cfg.has_section("metales_directos") else PackedStringArray()):
			var m := StringName(key)
			var lvl := clampi(int(cfg.get_value("metales_directos", key)), 0, metal_cap(m))
			if is_direct_metal(m) and lvl > 0:
				direct_levels[m] = lvl
	for i in SLOT_COUNT:
		slot_skills[i] = StringName(cfg.get_value("ranuras", "habilidad_%d" % i, ""))
		slot_keys[i] = int(cfg.get_value("ranuras", "tecla_%d" % i, DEFAULT_SLOT_KEYS[i]))
	coin_key = int(cfg.get_value("ranuras", "tecla_moneda", DEFAULT_COIN_KEY))
	# Un archivo editado a mano no puede dar más de lo que pagan los puntos ni saltear requisitos.
	if not is_valid():
		_start_skills()
	prune_slots()
	# Guardados anteriores: Empuje básico y Tirón básico pasan a venir puestos en Q y E (se mueve lo que hubiera ahí).
	# La ranura que tenía la R ahora es la 5 (si no la cambiaste).
	if int(cfg.get_value("ranuras", "version", 1)) < 4 and slot_keys[6] == KEY_R:
		slot_keys[6] = KEY_5
	if int(cfg.get_value("ranuras", "version", 1)) < 3:
		_put_in_slot(&"steel_light_push", BASIC_PUSH_SLOT)
		_put_in_slot(&"iron_pull", BASIC_PULL_SLOT)


## Pone la habilidad en esa ranura: si estaba en otra la saca de ahí, y lo que hubiera en la ranura va a la primera libre.
static func _put_in_slot(skill: StringName, index: int) -> void:
	var old := slot_skills.find(skill)
	if old >= 0:
		slot_skills[old] = &""
	var displaced := slot_skills[index]
	slot_skills[index] = skill
	if displaced != &"" and displaced != skill:
		var free := slot_skills.find(&"")
		if free >= 0:
			slot_skills[free] = displaced


static func save() -> void:
	revision += 1
	var cfg := ConfigFile.new()
	cfg.set_value("jugador", "nivel", level)
	cfg.set_value("jugador", "xp", xp)
	for id: StringName in skill_levels:
		cfg.set_value("poderes", String(id), skill_level(id))
	for m: StringName in direct_levels:
		cfg.set_value("metales_directos", String(m), int(direct_levels[m]))
	for i in SLOT_COUNT:
		cfg.set_value("ranuras", "habilidad_%d" % i, String(slot_skills[i]))
		cfg.set_value("ranuras", "tecla_%d" % i, slot_keys[i])
	cfg.set_value("ranuras", "tecla_moneda", coin_key)
	cfg.set_value("ranuras", "version", 5)
	cfg.save(save_path)
