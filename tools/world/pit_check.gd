extends SceneTree
## Prueba del foso de ceniza (AshPit), sin ventana: desde la entrada se llega caminando al fondo (escalones de menos de
## 1 m por metro, como una rampa de 45°) y los puestos de guardia caen donde deben.
## Godot --headless --path . -s tools/world/pit_check.gd
func _initialize() -> void:
	var fails := 0
	var c := AshPit.CENTER
	var start := c + Vector2(AshPit.rim_at(0.0) + 10.0, 0.0)  # la entrada, al este
	var seen := {Vector2i(start.round()): true}
	var todo: Array[Vector2i] = [Vector2i(start.round())]
	var deepest := 0.0
	while not todo.is_empty():
		var cell: Vector2i = todo.pop_back()
		var h := CityPlan.ground(Vector2(cell))
		deepest = maxf(deepest, AshPit.depth(Vector2(cell)))
		for dlt: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := cell + dlt
			if seen.has(n) or Vector2(n).distance_to(c) > AshPit.rim_at(0.0) + 20.0:
				continue
			if absf(CityPlan.ground(Vector2(n)) - h) < 1.0:
				seen[n] = true
				todo.append(n)
	print("hondo alcanzado caminando: ", deepest, " de ", AshPit.DROP * AshPit.WALLS)
	if deepest < AshPit.DROP * AshPit.WALLS - 0.5:
		print("FALLA no se llega al fondo caminando")
		fails += 1
	for spec: Array in GateForces.PEOPLE:
		var p: Vector2 = spec[1]
		if p.distance_to(c) < AshPit.CAMP:
			print("guardia en ", p, " hondo ", snappedf(AshPit.depth(p), 0.1), " dist ", snappedf(p.distance_to(c), 0.1), " borde ", snappedf(AshPit.rim_at((p - c).angle()), 0.1))
	for s: Dictionary in AshPit.crew_sites():
		print("cuadrilla ", s["pos"], " hondo ", snappedf(AshPit.depth(s["pos"]), 0.1))
	AshPit._check_spurs()
	print("FALLAS ", fails)
	quit(1 if fails > 0 else 0)
