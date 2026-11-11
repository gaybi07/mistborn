extends SceneTree
## Cuentas de la progresión por poderes (docs/PLAN_PROGRESION.md), sin escena:
##   Godot --headless --path . -s tools/anim_check/progression_check.gd
## Sale con código 1 si falla alguna. Guarda en un archivo aparte: no toca la partida.

const TEST_PATH := "user://progression_check.cfg"
var _fails := 0


func _init() -> void:
	Progression.save_path = TEST_PATH
	_check_points()
	_check_requirements()
	_check_lower()
	_check_save()
	_check_bad_files()
	_check_formulas()
	_check_fill_all()
	_check_feruchemy()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("progression_check: %s" % ("OK" if _fails == 0 else "%d fallas" % _fails))
	quit(1 if _fails > 0 else 0)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		printerr("FALLA: ", what)


func _check_points() -> void:
	Progression.reset()
	_expect(Progression.points_total() == 3, "nivel 1 da 3 puntos (da %d)" % Progression.points_total())
	_expect(Progression.points_free() == 0, "nivel 1 con el inicio: 0 libres (da %d)" % Progression.points_free())
	_expect(Progression.metal_level(&"steel") == 2, "acero = Empuje + Moneda = 2 (da %d)" % Progression.metal_level(&"steel"))
	_expect(Progression.metal_level(&"iron") == 1, "hierro = Tirón = 1")
	_expect(Progression.metal_level(&"pewter") == 0, "peltre sin aprender")
	_expect(SkillTree.is_unlocked(&"steel_combat_coin"), "la Moneda de combate viene lista")
	Progression.level = 4
	_expect(Progression.points_free() == 1, "nivel 4: 1 libre (da %d)" % Progression.points_free())
	Progression.level = 100
	_expect(Progression.points_total() == 100, "nivel 100 da 100 puntos")
	_expect(Progression.raise_skill(&"steel_coin_burst"), "Ráfaga con la Moneda puesta")
	_expect(Progression.metal_level(&"steel") == 3, "el acero suma la Ráfaga")
	for i in 10:
		Progression.raise_skill(&"steel_coin_burst")
	_expect(Progression.skill_level(&"steel_coin_burst") == SkillTree.max_level(&"steel_coin_burst"), "la Ráfaga topa en su máximo")
	Progression.level = 1
	_expect(not Progression.can_raise_skill(&"pewter_endurance"), "sin puntos libres no se sube nada")
	Progression.reset()
	Progression.level = 10
	_expect(Progression.raise_skill(&"atium_shadows") and Progression.points_free() == 5, "cada nivel de atium cuesta 2")
	_expect(Progression.metal_level(&"atium") == 1, "el atium suma su nivel")


func _check_requirements() -> void:
	Progression.reset()
	Progression.level = 20
	_expect(Progression.lower_skill(&"steel_combat_coin"), "bajar la Moneda (sin hijos con puntos)")
	_expect(not Progression.can_raise_skill(&"steel_coin_burst"), "Ráfaga sin Moneda de combate falla")
	_expect(Progression.can_raise_skill(&"steel_coin_shield"), "Escudo nace de la raíz")
	Progression.raise_skill(&"pewter_strike")
	Progression.raise_skill(&"pewter_charge")
	_expect(not Progression.can_raise_skill(&"pewter_fury"), "Furia pide los dos padres")
	Progression.raise_skill(&"pewter_slam")
	_expect(Progression.can_raise_skill(&"pewter_fury"), "Furia con Embestida y Martillazo")
	_expect(SkillTree.parents(&"pewter_fury").size() == 2 and SkillTree.parents(&"steel_light_push").is_empty(), "padres desde LAYOUTS")
	_expect(&"steel_coin_burst" in SkillTree.children(&"steel_combat_coin"), "hijos desde LAYOUTS")


func _check_lower() -> void:
	Progression.reset()
	Progression.level = 20
	Progression.raise_skill(&"steel_coin_burst")
	_expect(Progression.lower_blocker(&"steel_combat_coin") == &"steel_coin_burst", "la Ráfaga bloquea bajar la Moneda")
	_expect(not Progression.lower_skill(&"steel_combat_coin"), "bajar un padre con hijo falla")
	Progression.raise_skill(&"steel_combat_coin")
	_expect(Progression.lower_skill(&"steel_combat_coin"), "de 2 a 1 se puede: el hijo sigue con su requisito")
	Progression.slot_skills[0] = &"steel_coin_burst"
	_expect(Progression.lower_skill(&"steel_coin_burst") and Progression.slot_skills[0] == &"", "al quedar en 0 sale de la ranura")
	Progression.raise_skill(&"pewter_endurance")
	Progression.respec()
	_expect(Progression.skill_levels == Progression.START_SKILLS, "Devolver todos deja el inicio recomendado")


func _check_save() -> void:
	Progression.reset()
	Progression.level = 12
	Progression.raise_skill(&"steel_coin_burst")
	Progression.raise_skill(&"steel_coin_burst")
	Progression.raise_skill(&"tin_senses")
	Progression.raise_skill(&"zinc_fury")
	Progression.save()
	var skills := Progression.skill_levels.duplicate()
	Progression.reset()
	Progression._loaded = false
	Progression.load_progress()
	_expect(Progression.level == 12, "guardar y cargar: nivel")
	_expect(Progression.skill_levels == skills, "guardar y cargar: poderes (%s vs %s)" % [Progression.skill_levels, skills])


func _write(text: String) -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	Progression.reset()
	Progression._loaded = false
	Progression.load_progress()


func _check_bad_files() -> void:
	_write("[jugador]\nnivel=1\n[poderes]\nsteel_light_push=5\niron_pull=5\n[ranuras]\nversion=5\n")
	_expect(Progression.skill_levels == Progression.START_SKILLS, "puntos de más: vuelve al inicio")
	_write("[jugador]\nnivel=30\n[poderes]\nsteel_light_push=1\niron_pull=1\nsteel_spear=2\n[ranuras]\nversion=5\n")
	_expect(Progression.skill_levels == Progression.START_SKILLS, "Lanza sin sus padres: vuelve al inicio")
	_write("[jugador]\nnivel=30\n[poderes]\nsteel_light_push=9\nno_existe=3\n[ranuras]\nversion=5\n")
	_expect(Progression.skill_level(&"steel_light_push") == 5 and not Progression.skill_levels.has(&"no_existe"), "acota al máximo y descarta ids desconocidos")
	_write("[jugador]\nnivel=30\n[metales]\nsteel=12\npewter=8\n[ranuras]\nversion=4\n")
	_expect(Progression.level == 30 and Progression.skill_levels == Progression.START_SKILLS, "archivo viejo: nivel sí, metales no")
	for m in Allomancy.METALS:
		_expect(not SkillTree.skills_of(m).is_empty(), "%s tiene poderes (ya no hay metales directos)" % m)


func _check_formulas() -> void:
	var burst: Array[int] = []
	var shield: Array[int] = []
	for lvl in range(1, 6):
		burst.append(SkillTree.fan_count(SkillTree.equiv_level(&"steel_coin_burst", lvl), SkillTree.BURST_MIN_LEVEL))
		shield.append(SkillTree.shield_count(SkillTree.equiv_level(&"steel_coin_shield", lvl)))
	_expect(burst == [3, 7, 11, 15, 19], "Ráfaga 1-5 da 3, 7, 11, 15, 19 monedas (da %s)" % [burst])
	_expect(shield == [8, 11, 14, 17, 20], "Escudo 1-5 da 8, 11, 14, 17, 20 monedas (da %s)" % [shield])
	_expect(SkillTree.equiv_level(&"steel_coin_burst", 0) == 0, "sin puntos, nivel equivalente 0")
	var steel := Allomancy.new()
	var levels := {&"steel": 0}
	steel.metal_level = func(m: StringName) -> int: return int(levels.get(m, 0))
	var base := steel.max_reserve(&"steel")
	levels[&"steel"] = 10
	_expect(steel.max_reserve(&"steel") > base, "acero con 10 puntos: más reserva")
	var seconds_0: float = base / Allomancy.METALS[&"steel"]["burn"]
	var seconds_10: float = steel.max_reserve(&"steel") / (Allomancy.METALS[&"steel"]["burn"] * SkillTree.burn_scale(&"steel", 10))
	_expect(seconds_10 > seconds_0 * 1.4, "acero con 10 puntos dura más (%.0f s contra %.0f s)" % [seconds_10, seconds_0])
	_expect(SkillTree.burn_scale(&"steel", 100) == SkillTree.MIN_BURN_SCALE, "el consumo no baja del mínimo")
	steel.free()


func _check_fill_all() -> void:
	Progression.reset()
	Progression.fill_all()
	_expect(Progression.level == Progression.MAX_LEVEL and Progression.points_free() == 0, "todo al máximo: nivel 100 sin puntos libres")
	_expect(Progression.skill_level(&"steel_spear") == 5 and Progression.skill_level(&"tin_extreme") == 5, "todo al máximo: acero y estaño llenos")
	_expect(Progression.is_valid(), "todo al máximo: queda válido (se puede guardar y cargar)")


## Un poder de feruquimia de prueba en hierro (solo acá): comparte puntos y suma al nivel del hierro.
func _check_feruchemy() -> void:
	SkillTree.test_skills = [{"id": &"test_iron_mind", "metal": &"iron", "legacy_level": 1, "kind": SkillTree.Kind.PASSIVE,
			"name": "Mente de hierro (prueba)", "tree": &"feruchemy"}]
	Progression.reset()
	Progression.level = 5
	var free := Progression.points_free()
	var iron := Progression.metal_level(&"iron")
	_expect(Progression.raise_skill(&"test_iron_mind"), "un punto en feruquimia de hierro")
	_expect(Progression.metal_level(&"iron") == iron + 1, "la feruquimia sube el nivel del hierro")
	_expect(Progression.points_free() == free - 1, "y gasta de los mismos puntos libres")
	_expect(SkillTree.skills_of(&"iron", &"allomancy").size() == 6 and SkillTree.skills_of(&"iron", &"feruchemy").size() == 1, "skills_of filtra por árbol")
	Progression.save()
	Progression.reset()
	Progression._loaded = false
	Progression.load_progress()
	_expect(Progression.skill_level(&"test_iron_mind") == 1, "la feruquimia se guarda y se carga")
	SkillTree.test_skills = []
