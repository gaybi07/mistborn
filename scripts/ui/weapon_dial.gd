class_name WeaponDial
extends Control
## El arma elegida en un círculo, en la esquina inferior derecha de la pantalla: su icono en el centro, el aro dorado y el
## nombre debajo. Se ilumina un momento al cambiarla (rueda del ratón). Se reduce con la ventana (ver HudKit.ui_scale).

const SIZE := Vector2(180, 192)
const RADIUS := 69.0
const MARGIN := 14.0

var player: Player

var _last_weapon := -1
## Destello (1 a 0) del aro justo después de cambiar de arma.
var _flash := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -MARGIN - SIZE.x
	offset_right = -MARGIN
	offset_top = -MARGIN - SIZE.y
	offset_bottom = -MARGIN
	pivot_offset = SIZE  # se reduce hacia la esquina


func _process(delta: float) -> void:
	if player.weapon != _last_weapon:
		_flash = 1.0 if _last_weapon >= 0 else 0.0
		_last_weapon = player.weapon
	_flash = move_toward(_flash, 0.0, delta / Engine.time_scale * 0.8)
	var s := HudKit.ui_scale(self)
	scale = Vector2(s, s)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var c := Vector2(SIZE.x * 0.5, RADIUS + 9.0)
	HudKit.disc(self, c, RADIUS, Color(0.1, 0.1, 0.12), Color(0.02, 0.022, 0.03))
	HudKit.ring(self, c, RADIUS, 6.0, HudKit.GOLD)
	draw_arc(c, RADIUS - 10.0, 0.0, TAU, 48, Color(1, 1, 1, 0.1), 1.5, true)
	for k in 4:
		var a := TAU * k / 4.0 - PI / 2.0
		HudKit.diamond(self, c + Vector2(cos(a), sin(a)) * RADIUS, 6.0, Color(HudKit.GOLD_LIGHT, 0.95))
	if _flash > 0.0:
		draw_arc(c, RADIUS + 7.0, 0.0, TAU, 48, Color(HudKit.GOLD_LIGHT, 0.7 * _flash), 4.5, true)
	HudKit.weapon_icon(self, c, 1.9, player.weapon)
	var weapon_name: String = player.weapon_stats(player.weapon)["name"]
	draw_string(font, Vector2(0.0, SIZE.y - 8.0), weapon_name, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 19,
			Color(1, 1, 1, 0.55 + 0.4 * maxf(_flash, 0.7)))
