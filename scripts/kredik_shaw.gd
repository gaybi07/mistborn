class_name KredikShaw
extends Node3D
## Interior de Kredik Shaw: un nivel por vez (ver KredikPlan y KredikLevel). Las escaleras y los
## pozos son puertas que vuelven a cargar esta escena con otro nivel; la Gran Entrada y las salidas
## de los subniveles llevan a la ciudad.
## Del más profundo al más alto: Subnivel 3 (cimientos antiguos), 2 (archivos restringidos),
## 1 (arsenal), planta baja (Salón del Trono), niveles 2 a 5 y la Torre del Inquisidor.

## Donde aparece el jugador al entrar desde la ciudad (por la Gran Entrada).
static func entrance() -> Vector3:
	return KredikLevel.spawn("ground", "Entrada Imperial", "out")


## Donde aparece el jugador al salir a la ciudad: delante de la Gran Entrada.
static func city_exit() -> Vector3:
	return KredikCitadel.city_exit()


func _ready() -> void:
	var level := Portal.take_level("ground")
	var m := KredikLevel.materials()
	WorldKit.add_environment(self, 0.35, Vector3(220, 40, 130))
	var weather := get_tree().get_first_node_in_group(&"weather") as Weather
	if weather:
		weather.indoor = true
		weather.sheltered = true  # bajo techo casi no hay bruma (ni el filtro de visibilidad)
	var built := KredikLevel.new()
	built.level = level
	add_child(built)
	add_child(WorldFx.new())
	_scatter(level, m)

	var player := Player.new()
	player.name = "Player"
	player.position = Portal.take_arrival(entrance() if level == "ground" else KredikLevel.spawn(level, "", "below"))
	add_child(player)
	var hud := Hud.new()
	hud.player = player
	add_child(hud)


## Monedas y frascos por los niveles; buen equipo (casi todo de metal) en el Salón del Trono.
func _scatter(level: String, _m: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level) + 7
	var spots: Array[Vector3] = []
	for spec: Array in KredikPlan.spaces(level):
		if spec[1] in ["hall", "corridor", "room", "court"] and spec[2].size() == 4:
			var r := KredikPlan.rect(spec[2]).grow(-2.0)
			if r.size.x > 2.0 and r.size.y > 2.0:
				spots.append(Vector3(rng.randf_range(r.position.x, r.end.x), 0.3, rng.randf_range(r.position.y, r.end.y)))
	spots.shuffle()
	for k in mini(spots.size(), 14):
		if k % 3 == 0:
			var v := Vial.new()
			v.position = spots[k] + Vector3(0, 0.7, 0)
			add_child(v)
		else:
			for c in 4:
				var coin := Props.coin()
				coin.position = spots[k] + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
				add_child(coin)
	if level == "ground":
		var throne := KredikPlan.rect([612, 28, 798, 160])
		var c := throne.get_center()
		var loot := {"steel_sword": Vector3(c.x - 5, 1.2, throne.position.y + 9), "chainmail": Vector3(c.x + 5, 1.2, throne.position.y + 9),
				"large_vials": Vector3(c.x - 8, 0, c.y + 4), "steel_daggers": Vector3(c.x + 8, 0, c.y + 4), "nailed_boots": Vector3(c.x, 0, c.y + 8)}
		for id in loot:
			var pickup := ItemPickup.new()
			pickup.item_id = id
			pickup.position = loot[id]
			add_child(pickup)
