class_name CoinCharge
extends Control
## Medidor de la fuerza al lanzar una moneda: mientras mantienes la tecla, un arco alrededor de la mira
## se va llenando hasta el tope. La marca indica desde dónde la moneda sale lanzada en vez de caer a tus pies.

const RADIUS := 26.0

var player: Player


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)


func _process(_delta: float) -> void:
	visible = player.coin_charge > 0.0
	if visible:
		queue_redraw()


func _draw() -> void:
	var p := player.coin_charge
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, Color(0, 0, 0, 0.35), 5.0, true)
	var col := Color(0.95, 0.8, 0.4).lerp(Color(1.0, 0.45, 0.2), p)
	draw_arc(Vector2.ZERO, RADIUS, -PI / 2.0, -PI / 2.0 + TAU * p, maxi(int(40 * p), 3), col, 3.5, true)
	var a := -PI / 2.0 + TAU * Player.COIN_DROP_POWER
	draw_line(Vector2(cos(a), sin(a)) * (RADIUS - 5.0), Vector2(cos(a), sin(a)) * (RADIUS + 5.0), Color(1, 1, 1, 0.7), 1.5, true)
