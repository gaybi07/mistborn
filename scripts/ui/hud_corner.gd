class_name HudCorner
extends Control
## Paneles chicos a los costados de la barra central, de menor importancia que ella:
## a la izquierda, la bolsa de metales (y el arma); a la derecha, los frascos de recarga y las monedas.
## Van pegados a los costados de la barra central y se reducen con la ventana igual que ella (ver HudKit.ui_scale).

## Separación (px) entre la barra central y estos paneles, y de la base de la pantalla.
const GAP := 10.0
const BOTTOM := 8.0
const LEFT_SIZE := Vector2(150, 78)
const RIGHT_SIZE := Vector2(310, 66)

var player: Player
## true: a la izquierda de la barra (bolsa); false: a la derecha (frascos y monedas).
var left := true


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


func _process(_delta: float) -> void:
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
	# Arma actual encima, discreta; debajo la píldora con la bolsa y su tecla.
	draw_string(font, Vector2(4, 12), player.weapon_stats(player.weapon)["name"], HORIZONTAL_ALIGNMENT_LEFT, 140, 13, HudKit.DIM)
	var rect := Rect2(0, 24, LEFT_SIZE.x, 50)
	HudKit.panel(self, rect, 9.0)
	HudKit.bag(self, rect.position + Vector2(38, 25), 0.5, has)
	HudKit.key_box(self, font, rect.position + Vector2(rect.size.x - 28, 25), "F", 0.9 if has else 0.4)
	var text := "" if has and player.carries_metal() else ("SIN BOLSA" if not has else "sin metal")
	if text != "":
		draw_string(font, rect.position + Vector2(62, 16), text, HORIZONTAL_ALIGNMENT_LEFT, 60, 10, Color(1.0, 0.7, 0.4, 0.9))


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
