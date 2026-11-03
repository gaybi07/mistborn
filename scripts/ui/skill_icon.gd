class_name SkillIcon
extends RefCounted
## Icono de una habilidad: el símbolo de su metal y una marca que la distingue de las demás de ese metal. Lo usan el HUD y
## el árbol de habilidades (K).


static func draw(ci: CanvasItem, c: Vector2, half: float, skill: StringName, col: Color) -> void:
	var light := col.lightened(0.3)
	var r := half * 0.6
	MetalGlyph.draw(ci, SkillTree.find(skill)["metal"], c, r, light, 2.2)
	match skill:
		&"steel_combat_coin":
			ci.draw_circle(c + Vector2(half * 0.45, half * 0.45), half * 0.2, Color(0.82, 0.58, 0.32))
			ci.draw_arc(c + Vector2(half * 0.45, half * 0.45), half * 0.2, 0.0, TAU, 14, Color(0.4, 0.26, 0.14), 1.2, true)
		&"steel_coin_burst":
			for k in 3:
				var ang := -PI / 2 + (k - 1) * 0.55
				ci.draw_circle(c + Vector2(cos(ang), sin(ang)) * half * 0.78, half * 0.1, Color(0.82, 0.58, 0.32))
		&"steel_coin_shield":
			ci.draw_arc(c, half * 0.82, 0.0, TAU, 28, Color(0.82, 0.58, 0.32, 0.9), 1.6, true)
			for k in 5:
				var ang := TAU * k / 5.0
				ci.draw_circle(c + Vector2(cos(ang), sin(ang)) * half * 0.82, half * 0.09, Color(0.95, 0.75, 0.45))
		&"steel_magnetic_field":
			for k in 6:
				var a0 := TAU * k / 6.0
				ci.draw_arc(c, half * 0.85, a0, a0 + 0.55, 6, light, 1.6, true)
		&"steel_spear":
			ci.draw_line(c + Vector2(-half * 0.7, half * 0.7), c + Vector2(half * 0.7, -half * 0.7), Color(0.95, 0.9, 0.8), 2.6, true)
		&"iron_coin_magnet":
			ci.draw_arc(c + Vector2(0, half * 0.1), half * 0.55, 0.0, PI, 14, Color(0.9, 0.35, 0.3), 3.0, true)
		&"iron_drag":
			# Flechas hacia el centro: algo es arrastrado hacia ti.
			for k in 2:
				var side := -1.0 if k == 0 else 1.0
				ci.draw_line(c + Vector2(side * half * 0.85, half * 0.55), c + Vector2(side * half * 0.4, half * 0.55), Color(0.9, 0.35, 0.3), 2.0, true)
				ci.draw_line(c + Vector2(side * half * 0.4, half * 0.55), c + Vector2(side * half * 0.55, half * 0.42), Color(0.9, 0.35, 0.3), 2.0, true)
		&"iron_hook":
			ci.draw_arc(c + Vector2(half * 0.45, half * 0.4), half * 0.28, -PI * 0.2, PI * 1.3, 12, Color(0.9, 0.35, 0.3), 2.4, true)
		&"iron_disarm":
			ci.draw_line(c + Vector2(-half * 0.85, half * 0.8), c + Vector2(-half * 0.3, half * 0.5), Color(0.95, 0.9, 0.8), 2.4, true)
			ci.draw_line(c + Vector2(-half * 0.55, half * 0.38), c + Vector2(-half * 0.55, half * 0.8), Color(0.95, 0.9, 0.8), 1.6, true)
		&"pewter_charge":
			for k in 3:
				var x := -half * 0.2 + k * half * 0.38
				ci.draw_line(c + Vector2(x, -half * 0.35), c + Vector2(x + half * 0.22, 0.0), Color(0.95, 0.55, 0.3), 2.0, true)
				ci.draw_line(c + Vector2(x + half * 0.22, 0.0), c + Vector2(x, half * 0.35), Color(0.95, 0.55, 0.3), 2.0, true)
		&"pewter_slam":
			ci.draw_arc(c + Vector2(0, half * 0.55), half * 0.55, PI, TAU, 14, Color(0.95, 0.55, 0.3), 2.4, true)
			ci.draw_arc(c + Vector2(0, half * 0.55), half * 0.85, PI * 1.1, PI * 1.9, 14, Color(0.95, 0.55, 0.3, 0.7), 1.6, true)
		&"pewter_fury":
			for k in 8:
				var ang := TAU * k / 8.0
				ci.draw_line(c + Vector2(cos(ang), sin(ang)) * half * 0.7, c + Vector2(cos(ang), sin(ang)) * half * 0.95, Color(0.95, 0.5, 0.2), 2.0, true)
		&"iron_mass_yank":
			ci.draw_arc(c, half * 0.85, 0.0, TAU, 24, Color(0.9, 0.35, 0.3, 0.9), 1.6, true)
			for k in 4:
				var ang := TAU * k / 4.0 + PI / 4.0
				ci.draw_circle(c + Vector2(cos(ang), sin(ang)) * half * 0.85, half * 0.1, Color(0.9, 0.35, 0.3))
		&"tin_senses":
			ci.draw_arc(c, half * 0.9, 0.0, TAU, 20, Color(0.82, 0.86, 0.7, 0.8), 1.4, true)
		&"tin_focus":
			ci.draw_arc(c, half * 0.85, 0.0, TAU, 24, Color(0.82, 0.86, 0.7), 1.6, true)
			for k in 4:
				var ang := TAU * k / 4.0
				ci.draw_line(c + Vector2(cos(ang), sin(ang)) * half * 0.62, c + Vector2(cos(ang), sin(ang)) * half * 1.0, Color(0.82, 0.86, 0.7), 1.6, true)
		&"tin_ear":
			for k in 2:
				ci.draw_arc(c + Vector2(half * 0.2, 0.0), half * (0.75 + 0.25 * k), -0.9, 0.9, 10, Color(0.82, 0.86, 0.7, 0.8), 1.5, true)
		&"tin_mark":
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var corner := c + Vector2(sx, sy) * half * 0.9
					ci.draw_line(corner, corner - Vector2(sx, 0.0) * half * 0.35, Color(0.95, 0.9, 0.7), 1.8, true)
					ci.draw_line(corner, corner - Vector2(0.0, sy) * half * 0.35, Color(0.95, 0.9, 0.7), 1.8, true)
		&"tin_clear_mind":
			ci.draw_arc(c, half * 0.9, 0.0, TAU, 24, Color(0.6, 0.85, 1.0, 0.8), 1.5, true)
			ci.draw_arc(c, half * 0.55, 0.0, TAU, 20, Color(0.6, 0.85, 1.0, 0.5), 1.2, true)
		&"tin_extreme":
			for k in 3:
				ci.draw_arc(c, half * (0.55 + 0.22 * k), -0.7, 0.7, 8, Color(0.82, 0.86, 0.7, 0.9 - 0.2 * k), 1.5, true)
				ci.draw_arc(c, half * (0.55 + 0.22 * k), PI - 0.7, PI + 0.7, 8, Color(0.82, 0.86, 0.7, 0.9 - 0.2 * k), 1.5, true)
