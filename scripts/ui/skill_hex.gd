class_name SkillHex
extends Control
## Hexágono de una habilidad (o de un metal, si no tiene `skill`) del árbol de habilidades: borde y símbolo con el color de
## su metal, apagado y con candado si todavía está bloqueado, y un tramo de línea arriba y abajo para unirlo con los vecinos.

const GOLD := Color(0.95, 0.8, 0.35)

var metal: StringName = &""
var skill: StringName = &""
var locked := false
var selected := false
var line_up := false
var line_down := false
## Radio del hexágono (px).
var radius := 28.0


func _init(hex_radius := 28.0, height := 78.0) -> void:
	radius = hex_radius
	custom_minimum_size = Vector2(hex_radius * 2.3, height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var color: Color = Allomancy.METALS[metal]["color"]
	var c := size * 0.5
	var tint := Color(0.36, 0.38, 0.43) if locked else color  # bloqueada: gris apagado en vez del color del metal
	var line := Color(tint, 0.4)
	if line_up:
		draw_line(Vector2(c.x, 0.0), Vector2(c.x, c.y - radius), line, 2.0, true)
	if line_down:
		draw_line(Vector2(c.x, c.y + radius), Vector2(c.x, size.y), line, 2.0, true)
	var points := PackedVector2Array()
	for k in 6:
		var ang := -PI / 2 + TAU * k / 6.0
		points.append(c + Vector2(cos(ang), sin(ang)) * radius)
	draw_colored_polygon(points, Color(0.07, 0.085, 0.11) if not selected else Color(tint, 0.22).blend(Color(0.07, 0.085, 0.11)))
	if skill != &"":
		SkillIcon.draw(self, c, radius * 0.9, skill, tint.lightened(0.15))
	else:
		MetalGlyph.draw(self, metal, c, radius * 0.55, tint.lightened(0.3), 2.4)
	if locked:
		draw_colored_polygon(points, Color(0.03, 0.035, 0.05, 0.6))  # velo encima del icono
	points.append(points[0])
	draw_polyline(points, GOLD if selected else tint, 3.0 if selected else 2.0, true)
	if locked:
		var p := c + Vector2(radius * 0.62, radius * 0.62)
		draw_arc(p + Vector2(0, -3.0), 4.5, PI, TAU, 10, Color(0.85, 0.8, 0.65, 0.9), 1.8, true)
		draw_rect(Rect2(p + Vector2(-6.0, -2.0), Vector2(12, 9)), Color(0.85, 0.8, 0.65, 0.9))
