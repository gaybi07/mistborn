class_name KredikShaw
extends Node3D
## Interior de Kredik Shaw (PROVISORIO: un salón del trono para probar la entrada; el castillo
## de verdad lo arma el autor del juego y puede reemplazar esta escena).
## Se llega por la puerta de la torre central (ver main.gd, _kredik_door) y se vuelve a la
## ciudad por la puerta del fondo. Columnas y lámparas de hierro para moverse con acero y hierro.

## Donde aparece el jugador al entrar.
const ENTRANCE := Vector3(0, 1, 24)
const HALL := Vector3(30, 18, 60)  ## ancho, alto, largo


## Donde aparece el jugador al salir a la ciudad: delante de la puerta, en la meseta.
static func city_exit() -> Vector3:
	var dir := (-CityPlan.HILL).normalized()
	var c := CityPlan.HILL + dir * 13.0
	return Vector3(c.x, CityPlan.HILL_TOP + 1.0, c.y)


func _ready() -> void:
	var m := WorldKit.materials()
	WorldKit.add_environment(self, 0.5, Vector3(HALL.x, HALL.y, HALL.z))
	var weather := get_tree().get_first_node_in_group(&"weather") as Weather
	if weather:
		weather.indoor = true
	_build_hall(m)
	add_child(WorldFx.new())

	var exit := Portal.new()
	exit.target_scene = "res://scenes/main.tscn"
	exit.arrival = city_exit()
	exit.label = "Salir a Luthadel"
	exit.position = Vector3(0, 0, HALL.z / 2.0 - 0.6)
	add_child(exit)

	var player := Player.new()
	player.name = "Player"
	player.position = Portal.take_arrival(ENTRANCE)
	player.rotation.y = 0.0
	add_child(player)
	var hud := Hud.new()
	hud.player = player
	add_child(hud)


func _build_hall(m: Dictionary) -> void:
	var w := HALL.x
	var h := HALL.y
	var l := HALL.z
	add_child(Props.static_box(Vector3(w, 1, l), Vector3(0, -0.5, 0), m["ground"]))
	add_child(Props.static_box(Vector3(w, 1, l), Vector3(0, h + 0.5, 0), m["wall"]))
	for s in [-1.0, 1.0]:
		add_child(Props.static_box(Vector3(1, h, l), Vector3(s * (w / 2.0 + 0.5), h / 2.0, 0), m["wall"]))
		add_child(Props.static_box(Vector3(w, h, 1), Vector3(0, h / 2.0, s * (l / 2.0 + 0.5)), m["wall"]))
	# Alfombra roja hasta el trono.
	add_child(Props.static_box(Vector3(4, 0.04, l - 12), Vector3(0, 0.02, 4), Props.material(Color(0.32, 0.06, 0.05), 0.0, 1.0)))
	# Columnas de hierro (anclas) a los lados de la nave.
	for s in [-1.0, 1.0]:
		for z in range(-20, 25, 10):
			add_child(Props.static_box(Vector3(1.2, h, 1.2), Vector3(s * 8.0, h / 2.0, z), m["iron"], true))
	# Lámparas de hierro colgadas del techo (anclas altas para volar entre ellas).
	for z in [-15.0, 0.0, 15.0]:
		add_child(Props.static_box(Vector3(0.08, 4.0, 0.08), Vector3(0, h - 2.0, z), m["iron"]))
		add_child(Props.static_box(Vector3(2.2, 0.3, 2.2), Vector3(0, h - 4.2, z), m["iron"], true))
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.7, 0.45)
		light.light_energy = 2.0
		light.omni_range = 16.0
		light.position = Vector3(0, h - 5.0, z)
		add_child(light)
	# Estrado y trono al fondo.
	add_child(Props.static_box(Vector3(14, 1.2, 8), Vector3(0, 0.6, -l / 2.0 + 4.0), m["stone"]))
	add_child(Props.static_box(Vector3(10, 0.6, 2), Vector3(0, 0.3, -l / 2.0 + 9.0), m["stone"]))
	add_child(Props.static_box(Vector3(2.4, 1.0, 1.8), Vector3(0, 1.7, -l / 2.0 + 3.0), m["iron"], true))
	add_child(Props.static_box(Vector3(2.4, 4.0, 0.4), Vector3(0, 3.2, -l / 2.0 + 2.1), m["iron"], true))
	for s in [-1.0, 1.0]:
		var banner := Props.static_box(Vector3(3.0, 9.0, 0.1), Vector3(s * 5.0, 9.0, -l / 2.0 + 0.1), Props.material(Color(0.36, 0.07, 0.06), 0.0, 1.0))
		add_child(banner)
	for p in [Vector3(-11, 0, -20), Vector3(11, 0, -20), Vector3(-11, 0, 20), Vector3(11, 0, 20)]:
		var b := Brazier.new()
		b.position = p
		add_child(b)
	for i in 20:
		var coin := Props.coin()
		coin.position = Vector3(randf_range(-12, 12), 0.2, randf_range(-25, 25))
		add_child(coin)
	for p in [Vector3(-12, 1, 0), Vector3(12, 1, 0)]:
		var v := Vial.new()
		v.position = p
		add_child(v)
	# La armería del Lord Legislador: buen equipo... casi todo de metal.
	var loot := {"steel_sword": Vector3(-6, 1.2, -l / 2.0 + 5.0), "chainmail": Vector3(6, 1.2, -l / 2.0 + 5.0),
			"large_vials": Vector3(-12, 0, -10), "steel_daggers": Vector3(12, 0, -10), "nailed_boots": Vector3(0, 0, 12)}
	for id in loot:
		var pickup := ItemPickup.new()
		pickup.item_id = id
		pickup.position = loot[id]
		add_child(pickup)
