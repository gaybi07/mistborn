extends SceneTree
## Prueba de la misión del taller con la progresión nueva (G22), sin ventana y sin tocar la del jugador: una partida
## nueva arranca con los 3 puntos ya puestos y la moneda de combate lista; al llegar al paso "gastar un punto", Clubs
## te deja uno libre, y el paso no se da por hecho hasta que lo gastás.
## Godot --headless --path . -s tools/story/taller_check.gd
var _fails := 0


func _initialize() -> void:
	Progression.save_path = "user://taller_check.cfg"
	Progression.reset()
	QuestLog.reset()
	_ok(Progression.points_free() == 0, "partida nueva: los 3 puntos del inicio ya están puestos")
	_ok(SkillTree.is_unlocked(&"steel_combat_coin"), "partida nueva: la moneda de combate está lista")
	QuestLog.active["el_taller"] = 1  # habló con Sazed y llegó al taller
	QuestLog.advance("el_taller")  # Clubs explica: pasa al paso de gastar un punto
	_ok(QuestLog.current_step("el_taller").get("spend", false), "el paso es gastar un punto")
	_ok(Progression.points_free() >= 1, "Clubs te deja un punto libre (nivel %d)" % Progression.level)
	var spent := Progression.points_spent()
	_ok(spent == int(QuestLog.outcome["el_taller_spent"]), "todavía no gastaste nada")
	var raised := false
	for s: Dictionary in SkillTree.SKILLS:
		if Progression.raise_skill(s["id"]):
			raised = true
			break
	_ok(raised and Progression.points_spent() > spent, "gastar el punto en la K")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://taller_check.cfg"))
	print("FALLAS ", _fails)
	quit(1 if _fails > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FALLA ") + what)
	if not cond:
		_fails += 1
