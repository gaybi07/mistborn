class_name HudCorner
extends Control
## Paneles chicos a los costados de la barra central, de menor importancia que ella:
## a la izquierda, la bolsa de metales (y el arma); a la derecha, los frascos de recarga y las monedas.
## Van pegados a los costados de la barra central y se reducen con la ventana igual que ella (ver HudKit.ui_scale).

## Separación (px) entre la barra central y estos paneles, y de la base de la pantalla.
const GAP := 10.0
const BOTTOM := 8.0
const LEFT_SIZE := Vector2(190, 112)
const RIGHT_SIZE := Vector2(310, 66)
## Alto del panel del arma (arriba) y de la píldora de la bolsa (abajo) en el lado izquierdo.
const WEAPON_H := 52.0
const BAG_H := 50.0

var player: Player
## true: a la izquierda de la barra (arma y bolsa); false: a la derecha (frascos y monedas).
var left := true
var _last_weapon := -1
## Destello (1 a 0) del panel del arma justo después de cambiarla.
var _weapon_flash := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := LEFT_SIZE if left else RIGHT_SIZE
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_top = -BOTTOM - s.y
	offset_bottom = -BOTTOM
	# Se reduce hacia el borde que da a la barra central, así queda siempre pegada a ella.
	pivot_offset = Vector2(s.x if left else 0.0, s.y)
	_place(1.0)


## Junto a la barra central (a su izquierda o a su derecha), con la misma base.
func _place(s: float) -> void:
	var size_px := LEFT_SIZE if left else RIGHT_SIZE
	var edge := MetalBar.W * 0.5 * s + GAP
	if left:
		offset_right = -edge
		offset_left = -edge - size_px.x
	else:
		offset_left = edge
		offset_right = edge + size_px.x


func _process(delta: float) -> void:
	if player.weapon != _last_weapon:
		_weapon_flash = 1.0 if _last_weapon >= 0 else 0.0
		_last_weapon = player.weapon
	_weapon_flash = move_toward(_weapon_flash, 0.0, delta / Engine.time_scale * 0.8)
	var s := HudKit.ui_scale(self)
	scale = Vector2(s, s)
	_place(s)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	if left:
		_draw_bag(font)
	else:
		_draw_vials(font)
		_draw_coins(font)


func _draw_bag(font: Font) -> void:
	var has := player.has_bag()
	_draw_weapon(font)
	var rect := Rect2(0, LEFT_SIZE.y - BAG_H, LEFT_SIZE.x, BAG_H)
	HudKit.panel(self, rect, 9.0)
	HudKit.bag(self, rect.position + Vector2(38, 25), 0.5, has)
	HudKit.key_box(self, font, rect.position + Vector2(rect.size.x - 28, 25), "F", 0.9 if has else 0.4)
	var text := "" if has and player.carries_metal() else ("SIN BOLSA" if not has else "sin metal")
	if text != "":
		draw_string(font, rect.position + Vector2(62, 16), text, HORIZONTAL_ALIGNMENT_LEFT, 60, 10, Color(1.0, 0.7, 0.4, 0.9))


## Panel del arma elegida (ícono, nombre y la rueda del ratón para cambiarla). Se ilumina al cambiarla.
func _draw_weapon(font: Font) -> void:
	var rect := Rect2(0, 0, LEFT_SIZE.x, WEAPON_H)
	HudKit.panel(self, rect, 9.0)
	if _weapon_flash > 0.0:
		draw_rect(rect.grow(-2.0), Color(HudKit.GOLD_LIGHT, 0.55 * _weapon_flash), false, 2.0)
	HudKit.weapon_icon(self, Vector2(32, WEAPON_H * 0.5), 0.8, player.weapon)
	draw_string(font, Vector2(60, 20), "ARMA · rueda", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 66, 10, Color(1, 1, 1, 0.45))
	draw_string(font, Vector2(60, 39), player.weapon_stats(player.weapon)["name"], HORIZONTAL_ALIGNMENT_LEFT,
			rect.size.x - 66, 13, Color(1, 1, 1, 0.5 + 0.45 * maxf(_weapon_flash, 0.7)))


func _draw_vials(font: Font) -> void:
	var rect := Rect2(0, 0, 178, RIGHT_SIZE.y)
	HudKit.panel(self, rect, 9.0)
	var n := maxi(player.max_vials(), 1)
	var step := minf(38.0, (rect.size.x - 44.0) / n)
	var x0 := rect.position.x + 62.0 + (rect.size.x - 62.0 - 12.0) * 0.5 - step * (n - 1) * 0.5
	for i in n:
		HudKit.vial(self, Vector2(x0 + i * step, 28), 0.85, HudKit.VIAL_COLORS[i % HudKit.VIAL_COLORS.size()], i < player.vial_charges)
	draw_string(font, Vector2(12, 28), "T", HORIZONTAL_ALIGNMENT_LEFT, 20, 12, Color(1, 1, 1, 0.45))
	draw_string(font, Vector2(12, 46), "Frascos", HORIZONTAL_ALIGNMENT_LEFT, 56, 11, HudKit.DIM)
	draw_string(font, Vector2(62, rect.size.y - 7), "%d / %d" % [player.vial_charges, player.max_vials()],
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 74, 12, Color(1, 1, 1, 0.92))


func _draw_coins(font: Font) -> void:
	var has := player.has_bag()
	var rect := Rect2(188, 0, 122, RIGHT_SIZE.y)
	HudKit.panel(self, rect, 9.0)
	HudKit.coin_stack(self, rect.position + Vector2(34, 31), 0.85, has)
	# Las monedas que llevas (sin la bolsa, ninguna). En naranja cuando se acaban.
	var count := player.coins_held if has else 0
	draw_string(font, rect.position + Vector2(58, 40), str(count), HORIZONTAL_ALIGNMENT_CENTER, 56, 22,
			Color(1, 1, 1, 0.92) if count > 0 else Color(1.0, 0.7, 0.4))
