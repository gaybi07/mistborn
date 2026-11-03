class_name TrainingRoom
extends Node3D
## Lo común de las salas de práctica: ambiente, jugador, cartel de arriba y recargar lo gastado.
## Practicar no da experiencia ni botín (ver CombatRoom).

const COINS := 200

var player: Player

var _banner: Label


func _build_base(env_size: Vector3, spawn: Vector3, yaw := 0.0) -> void:
	WorldKit.add_environment(self, 0.45, env_size)
	add_child(WorldFx.new())
	player = Player.new()
	player.name = "Player"
	player.position = spawn
	add_child(player)
	player.yaw_pivot.rotation.y = yaw
	var hud := Hud.new()
	hud.player = player
	add_child(hud)
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 24
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 26)
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	var layer := CanvasLayer.new()
	layer.layer = 15
	layer.add_child(_banner)
	add_child(layer)
	_refill()


## Vida, resistencia, frascos, metales y monedas al máximo.
func _refill() -> void:
	player.health = player.max_health
	player.stamina = player.max_stamina
	player.vial_charges = player.max_vials()
	player.coins_held = maxi(player.coins_held, COINS)
	for metal in Allomancy.METALS:
		player.allomancy.refill(metal, 1000.0)
