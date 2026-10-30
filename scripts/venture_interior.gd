class_name VentureInterior
extends Node3D
## La mansión Venture por dentro, a tamaño real (en la ciudad se ve a media escala). Se entra por
## la puerta de la mansión de la ciudad y se vuelve a salir por la puerta principal.


func _ready() -> void:
	WorldKit.add_environment(self, 0.4, Vector3(80, 30, 90))
	var weather := get_tree().get_first_node_in_group(&"weather") as Weather
	if weather:
		weather.indoor = true
	var manor := VentureManor.new()
	manor.interior = true
	add_child(manor)
	add_child(WorldFx.new())
	var player := Player.new()
	player.name = "Player"
	player.position = Portal.take_arrival(VentureManor.ENTRANCE)
	add_child(player)
	var hud := Hud.new()
	hud.player = player
	add_child(hud)
