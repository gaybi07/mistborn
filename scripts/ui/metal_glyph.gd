class_name MetalGlyph
## Símbolos de los metales dibujados con líneas (se ven nítidos a cualquier tamaño).
## Los usa la barra del HUD.
##   Acero: flecha hacia fuera (empujar)       Hierro: flecha hacia dentro (tirar)
##   Peltre: escudo con el puño del guerrero    Atium: reloj de arena dentro de un anillo
##   Cinc: llama (enardecer)                   Cobre: nube que te oculta
##   Bronce: ondas que se sienten               Estaño: ojo (sentidos)
##   Latón: aguas en calma (aplacar)


## Dibuja el símbolo de `metal` centrado en `c` dentro de un círculo de radio `r`.
static func draw(ci: CanvasItem, metal: StringName, c: Vector2, r: float, color: Color, w := 2.0) -> void:
	match metal:
		&"steel":
			_arrow(ci, c + Vector2(0, r * 0.55), c + Vector2(0, -r * 0.6), r * 0.32, color, w)
			ci.draw_line(c + Vector2(-r * 0.4, r * 0.55), c + Vector2(r * 0.4, r * 0.55), color, w, true)
			for s in [-1.0, 1.0]:
				ci.draw_line(c + Vector2(s * r * 0.45, r * 0.1), c + Vector2(s * r * 0.62, -r * 0.2), color, w * 0.7, true)
		&"iron":
			_arrow(ci, c + Vector2(0, -r * 0.65), c + Vector2(0, r * 0.35), r * 0.32, color, w)
			ci.draw_arc(c + Vector2(0, r * 0.25), r * 0.42, 0.15 * PI, 0.85 * PI, 16, color, w, true)
		&"pewter":
			var shield := PackedVector2Array([c + Vector2(-r * 0.55, -r * 0.55), c + Vector2(r * 0.55, -r * 0.55),
					c + Vector2(r * 0.5, r * 0.1), c + Vector2(0, r * 0.65), c + Vector2(-r * 0.5, r * 0.1),
					c + Vector2(-r * 0.55, -r * 0.55)])
			ci.draw_polyline(shield, color, w, true)
			ci.draw_line(c + Vector2(0, -r * 0.4), c + Vector2(0, r * 0.4), color, w, true)
			ci.draw_line(c + Vector2(-r * 0.3, -r * 0.1), c + Vector2(r * 0.3, -r * 0.1), color, w, true)
		&"atium":
			ci.draw_arc(c, r * 0.72, 0.0, TAU, 32, color, w * 0.7, true)
			var glass := PackedVector2Array([c + Vector2(-r * 0.38, -r * 0.5), c + Vector2(r * 0.38, -r * 0.5),
					c, c + Vector2(r * 0.38, r * 0.5), c + Vector2(-r * 0.38, r * 0.5), c, c + Vector2(-r * 0.38, -r * 0.5)])
			ci.draw_polyline(glass, color, w, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.22, r * 0.5), c + Vector2(r * 0.22, r * 0.5),
					c + Vector2(0, r * 0.22)]), color)
		&"zinc":
			var flame := PackedVector2Array()
			for i in 25:
				var t := float(i) / 24.0 * TAU
				# Gota invertida con la punta ondulada hacia arriba.
				var rad := r * (0.42 + 0.18 * sin(t * 0.5))
				var p := Vector2(sin(t) * rad * 0.8, -cos(t) * rad)
				p.y -= r * 0.25 * pow(maxf(cos(t), 0.0), 3.0)
				flame.append(c + p + Vector2(0, r * 0.12))
			ci.draw_polyline(flame, color, w, true)
			ci.draw_arc(c + Vector2(0, r * 0.3), r * 0.18, PI, TAU, 10, color, w * 0.8, true)
		&"copper":
			ci.draw_arc(c + Vector2(-r * 0.3, r * 0.05), r * 0.28, PI * 0.5, PI * 1.6, 14, color, w, true)
			ci.draw_arc(c + Vector2(0.0, -r * 0.12), r * 0.36, PI * 1.05, PI * 1.95, 16, color, w, true)
			ci.draw_arc(c + Vector2(r * 0.33, r * 0.05), r * 0.28, PI * 1.4, PI * 2.5, 14, color, w, true)
			ci.draw_line(c + Vector2(-r * 0.3, r * 0.33), c + Vector2(r * 0.33, r * 0.33), color, w, true)
			ci.draw_line(c + Vector2(-r * 0.45, r * 0.55), c + Vector2(r * 0.45, r * 0.55), color, w * 0.6, true)
		&"bronze":
			ci.draw_circle(c, r * 0.12, color)
			for k in 3:
				var rr := r * (0.3 + 0.18 * k)
				for s in [0.0, PI]:
					ci.draw_arc(c, rr, s - 0.6, s + 0.6, 10, Color(color, color.a * (1.0 - 0.25 * k)), w, true)
		&"tin":
			ci.draw_arc(c + Vector2(0, r * 0.45), r * 0.75, -PI * 0.78, -PI * 0.22, 16, color, w, true)
			ci.draw_arc(c + Vector2(0, -r * 0.45), r * 0.75, PI * 0.22, PI * 0.78, 16, color, w, true)
			ci.draw_arc(c, r * 0.2, 0.0, TAU, 16, color, w, true)
			ci.draw_circle(c, r * 0.08, color)
		&"brass":
			for k in 3:
				var y := (k - 1) * r * 0.32
				var line := PackedVector2Array()
				for i in 13:
					var x := -r * 0.6 + r * 1.2 * i / 12.0
					line.append(c + Vector2(x, y + sin(x / r * 5.0) * r * 0.08 * (1.0 - 0.3 * k)))
				ci.draw_polyline(line, color, w, true)
		_:
			ci.draw_circle(c, r * 0.3, color)


static func _arrow(ci: CanvasItem, from: Vector2, to: Vector2, head: float, color: Color, w: float) -> void:
	ci.draw_line(from, to, color, w, true)
	var d := (to - from).normalized()
	var side := Vector2(-d.y, d.x)
	ci.draw_line(to, to - d * head + side * head * 0.7, color, w, true)
	ci.draw_line(to, to - d * head - side * head * 0.7, color, w, true)
