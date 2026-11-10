class_name CompassBar
extends Control
## Brújula arriba de la pantalla: N, E, S, O según hacia dónde mira la cámara, y la misión que seguís (QuestLog.tracked)
## con su distancia. Si queda fuera de la tira, la marca se queda pegada al borde del lado hacia donde hay que girar.

const WIDTH := 560.0
const HEIGHT := 34.0
const SPAN := PI * 0.75  # lo que abarca la tira, de punta a punta
const CARDINALS := [["N", 0.0], ["E", -PI * 0.5], ["S", PI], ["O", PI * 0.5]]

var player: Player


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -WIDTH / 2.0
	offset_right = WIDTH / 2.0
	offset_top = 10
	offset_bottom = 10 + HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


## Ángulo (rad) de una dirección del mundo con la misma convención que la cámara: 0 = -Z (norte), sube hacia la izquierda.
static func bearing(v: Vector2) -> float:
	return atan2(-v.x, -v.y)


func _draw() -> void:
	if not is_instance_valid(player):
		return
	var font := get_theme_default_font()
	var yaw := player.yaw_pivot.global_rotation.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.03, 0.55))
	draw_line(Vector2(0, size.y), Vector2(size.x, size.y), HudKit.GOLD, 1.0)
	draw_line(Vector2(size.x / 2.0, size.y - 6), Vector2(size.x / 2.0, size.y), HudKit.GOLD_LIGHT, 2.0)
	for c: Array in CARDINALS:
		var x := _x(c[1], yaw)
		if x >= 0.0:
			draw_string(font, Vector2(x - 6, 22), c[0], HORIZONTAL_ALIGNMENT_CENTER, -1, 18, HudKit.GOLD_LIGHT)
	var id := QuestLog.tracked
	var target: Variant = QuestLog.step_target(id) if id != "" else null
	if target == null:
		return
	var here := Vector2(player.global_position.x, player.global_position.z)
	var to: Vector2 = (target as Vector2) - here
	var rel := wrapf(bearing(to) - yaw, -PI, PI)
	var x := clampf(size.x / 2.0 - rel / (SPAN / 2.0) * size.x / 2.0, 8.0, size.x - 8.0)
	HudKit.diamond(self, Vector2(x, size.y / 2.0), 7.0, Color(0.95, 0.75, 0.25))
	draw_string(font, Vector2(x - 30, size.y + 16), "%d m" % roundi(to.length()), HORIZONTAL_ALIGNMENT_CENTER, 60, 14, HudKit.GOLD_LIGHT)


## Posición en la tira de un rumbo, o -1 si queda afuera.
func _x(angle: float, yaw: float) -> float:
	var rel := wrapf(angle - yaw, -PI, PI)
	if absf(rel) > SPAN / 2.0:
		return -1.0
	return size.x / 2.0 - rel / (SPAN / 2.0) * size.x / 2.0
