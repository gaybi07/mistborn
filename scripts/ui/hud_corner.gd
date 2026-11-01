class_name HudCorner
extends Control
## Inventario de consumibles y oro, a la derecha de la barra inferior (ver AbilityHud). Se reduce con la ventana igual
## que ella (ver HudKit.ui_scale). El arma está aparte, en el círculo de la esquina inferior derecha (ver WeaponDial).

## Separación (px) entre la barra inferior y este panel, y de la base de la pantalla.
const GAP := 10.0
const BOTTOM := 8.0
const RIGHT_SIZE := Vector2(176, 164)
## Casillas del inventario de consumibles (3 por 2) y su separación.
const ITEM_SLOT := 46.0
const ITEM_GAP := 5.0
## Franja del oro debajo de las casillas.
const GOLD_RECT := Rect2(14.0, 132.0, 148.0, 24.0)

var player: Player


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_top = -BOTTOM - RIGHT_SIZE.y
	offset_bottom = -BOTTOM
	# Se reduce hacia el borde que da a la barra, así queda siempre pegado a ella.
	pivot_offset = Vector2(0.0, RIGHT_SIZE.y)
	_place(1.0)


## Junto a la barra inferior (a su derecha), con la misma base.
func _place(s: float) -> void:
	var edge := AbilityHud.W * 0.5 * s + GAP
	offset_left = edge
	offset_right = edge + RIGHT_SIZE.x


func _process(_delta: float) -> void:
	var s := HudKit.ui_scale(self)
	scale = Vector2(s, s)
	_place(s)
	queue_redraw()


func _draw() -> void:
	_draw_items(get_theme_default_font())


## Inventario de consumibles (seis casillas, como los objetos del LoL): cada frasco ocupa una, llena o vacía; la T bebe
## uno. Debajo, en su propia franja, el oro (las monedas del monedero).
func _draw_items(font: Font) -> void:
	var rect := Rect2(0, 0, RIGHT_SIZE.x, RIGHT_SIZE.y)
	HudKit.panel(self, rect, 9.0)
	var vials := maxi(player.max_vials(), 0)
	for i in 6:
		var cell := Rect2(14.0 + (i % 3) * (ITEM_SLOT + ITEM_GAP), 16.0 + (i / 3) * (ITEM_SLOT + ITEM_GAP), ITEM_SLOT, ITEM_SLOT)
		draw_rect(cell, Color(0.03, 0.035, 0.05, 0.95))
		draw_rect(cell, Color(HudKit.GOLD, 0.45), false, 1.2)
		# Solo se dibujan los frascos que quedan: la casilla de uno gastado queda vacía, sin silueta.
		if i < vials and i < player.vial_charges:
			HudKit.vial(self, cell.get_center() + Vector2(0, -1), 0.8, HudKit.VIAL_COLORS[i % HudKit.VIAL_COLORS.size()], true)
			if i == 0:
				var tag := Rect2(cell.end - Vector2(17, 14), Vector2(14, 12))
				draw_rect(tag, Color(0.02, 0.022, 0.03, 0.9))
				draw_string(font, tag.position + Vector2(0, 9), "T", HORIZONTAL_ALIGNMENT_CENTER, 14, 10, Color(1, 1, 1, 0.8))
	# Oro: una franja propia debajo de las casillas, con la pila de monedas a la izquierda y la cantidad a la derecha.
	# En naranja cuando se acaban.
	var count := player.coins_held
	draw_rect(GOLD_RECT, Color(0.03, 0.035, 0.05, 0.95))
	draw_rect(GOLD_RECT, Color(HudKit.GOLD, 0.45), false, 1.2)
	HudKit.coin_stack(self, GOLD_RECT.position + Vector2(17.0, 12.0), 0.34, count > 0)
	draw_string(font, GOLD_RECT.position + Vector2(34.0, 17.5), HudKit.thousands(count), HORIZONTAL_ALIGNMENT_RIGHT, GOLD_RECT.size.x - 42.0, 17,
		Color(0.98, 0.84, 0.4) if count > 0 else Color(1.0, 0.7, 0.4))
