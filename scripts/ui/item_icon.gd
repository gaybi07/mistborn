class_name ItemIcon
extends Control
## Ícono de un objeto del inventario, dibujado con formas según su ranura y en su color.
## Los objetos de metal llevan un punto azul en la esquina (te pueden empujar).

var item_id := "":
	set(v):
		item_id = v
		queue_redraw()
## Ranura a dibujar en gris si no hay objeto (casillero vacío del equipo).
var empty_slot := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	draw_rect(Rect2(o, Vector2(s, s)), Color(0.05, 0.055, 0.07))
	var it := Items.get_item(item_id)
	var slot: String = it.get("slot", empty_slot)
	var col: Color = it.get("color", Color(0.3, 0.31, 0.34))
	if it.is_empty():
		col.a = 0.35
	var lit := col.lightened(0.25)
	var c := o + Vector2(s, s) * 0.5
	var u := s / 100.0
	match slot:
		"cloak":
			draw_colored_polygon(_pts(c, u, [[-14, -32], [14, -32], [36, 38], [-36, 38]]), col)
			draw_circle(c + Vector2(0, -30) * u, 13 * u, lit)
			draw_line(c + Vector2(-8, -16) * u, c + Vector2(-20, 36) * u, col.darkened(0.4), 2.0 * u)
			draw_line(c + Vector2(8, -16) * u, c + Vector2(20, 36) * u, col.darkened(0.4), 2.0 * u)
		"body":
			draw_colored_polygon(_pts(c, u, [[-16, -34], [16, -34], [38, -20], [32, 2], [22, -4], [22, 36],
					[-22, 36], [-22, -4], [-32, 2], [-38, -20]]), col)
			draw_line(c + Vector2(0, -34) * u, c + Vector2(0, 30) * u, lit, 2.0 * u)
		"boots":
			draw_colored_polygon(_pts(c, u, [[-14, -36], [10, -36], [10, 14], [34, 22], [34, 36], [-14, 36]]), col)
			draw_line(c + Vector2(-14, 26) * u, c + Vector2(34, 26) * u, lit, 3.0 * u)
		"daggers":
			for sgn in [-1.0, 1.0]:
				var a := c + Vector2(sgn * -26, 30) * u
				var b := c + Vector2(sgn * 22, -32) * u
				draw_line(a, b, lit, 6.0 * u)
				var mid := a.lerp(b, 0.28)
				var perp := (b - a).normalized().orthogonal() * 10.0 * u
				draw_line(mid - perp, mid + perp, col.darkened(0.3), 4.0 * u)
		"sword":
			var a := c + Vector2(-30, 32) * u
			var b := c + Vector2(30, -34) * u
			draw_line(a, b, lit, 8.0 * u)
			var mid := a.lerp(b, 0.22)
			var perp := (b - a).normalized().orthogonal() * 16.0 * u
			draw_line(mid - perp, mid + perp, col.darkened(0.3), 6.0 * u)
		"vials":
			for k in 3:
				var x := (k - 1) * 22.0
				draw_rect(Rect2(c + Vector2(x - 8, -10) * u, Vector2(16, 40) * u), Color(0.8, 0.85, 0.9, 0.25 if not it.is_empty() else 0.1))
				draw_rect(Rect2(c + Vector2(x - 8, 6) * u, Vector2(16, 24) * u), col)
				draw_rect(Rect2(c + Vector2(x - 4, -20) * u, Vector2(8, 10) * u), Color(0.45, 0.32, 0.2, col.a))
	if it.get("metal", false):
		var p := o + Vector2(s - 12 * u, 12 * u)
		draw_circle(p, 7 * u, Color(0.25, 0.5, 1.0))
		draw_arc(p, 9 * u, 0, TAU, 16, Color(0.6, 0.8, 1.0), 1.5)


func _pts(c: Vector2, u: float, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + Vector2(p[0], p[1]) * u)
	return out
