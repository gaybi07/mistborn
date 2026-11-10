class_name WaypointMarker
extends Control
## Marcador en pantalla de adónde ir (QuestLog.guide): un rombo dorado flotando sobre el lugar, con la distancia. Si el
## lugar queda fuera de la vista (o atrás), el rombo se pega al borde de la pantalla del lado hacia donde hay que girar.
## Cerca (menos de 6 m) se esconde, para no tapar lo que hay que usar.

const MARGIN := 48.0
const HIDE_NEAR := 6.0

var player: Player


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(player) or player.ui_open:
		return
	var cam := get_viewport().get_camera_3d()
	var here := Vector2(player.global_position.x, player.global_position.z)
	var guide := QuestLog.guide(here)
	if cam == null or guide.is_empty():
		return
	var xz: Vector2 = guide["xz"]
	var dist := here.distance_to(xz)
	if dist < HIDE_NEAR:
		return
	var world := Vector3(xz.x, CityPlan.ground(xz) + 3.0, xz.y)
	var behind := cam.is_position_behind(world)
	var p := cam.unproject_position(world)
	var center := size / 2.0
	if behind:
		p = center - (p - center) * 1000.0  # atrás: del lado contrario
	var inner := Rect2(Vector2.ONE * MARGIN, size - Vector2.ONE * MARGIN * 2.0)
	var edge := behind or not inner.has_point(p)
	if edge:  # al borde, sobre la recta desde el centro
		var d := p - center
		var k := minf(absf(inner.size.x / 2.0 / d.x) if d.x != 0.0 else INF, absf(inner.size.y / 2.0 / d.y) if d.y != 0.0 else INF)
		p = center + d * k
	var gold := Color(0.95, 0.75, 0.25)
	HudKit.diamond(self, p, 11.0, gold)
	if edge:  # flechita hacia afuera
		var dir := (p - center).normalized()
		var tip := p + dir * 22.0
		var side := Vector2(-dir.y, dir.x) * 7.0
		draw_colored_polygon(PackedVector2Array([tip, p + dir * 13.0 + side, p + dir * 13.0 - side]), gold)
	var font := ThemeDB.fallback_font
	var label := "%d m" % roundi(dist)
	draw_string_outline(font, p + Vector2(-40, 30), label, HORIZONTAL_ALIGNMENT_CENTER, 80, 16, 4, Color(0, 0, 0, 0.7))
	draw_string(font, p + Vector2(-40, 30), label, HORIZONTAL_ALIGNMENT_CENTER, 80, 16, Color(1.0, 0.9, 0.6))
