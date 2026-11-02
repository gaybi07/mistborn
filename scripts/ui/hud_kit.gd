class_name HudKit
## Piezas de dibujo compartidas por la barra inferior (AbilityHud) y la lista de metales (MetalList) y los paneles de las esquinas (HudCorner):
## colores, aros metálicos, paneles con borde dorado, íconos de frascos y monedas.
## Todas son funciones estáticas que dibujan sobre el CanvasItem `ci` (se llaman desde su _draw).

const GOLD := Color(0.72, 0.62, 0.45)
const GOLD_LIGHT := Color(0.95, 0.86, 0.66)
const STEEL := Color(0.52, 0.54, 0.6)
const PANEL_TOP := Color(0.085, 0.09, 0.11, 0.94)
const PANEL_BOTTOM := Color(0.03, 0.033, 0.045, 0.94)
const DIM := Color(0.82, 0.84, 0.9, 0.8)
const VIAL_COLORS: Array[Color] = [Color(0.9, 0.22, 0.22), Color(0.95, 0.78, 0.25), Color(0.3, 0.6, 1.0)]
## Tamaño de ventana (px) de referencia, en el que el HUD se ve a tamaño natural (escala 1).
const FULL_SIZE_WIDTH := 1650.0
const FULL_SIZE_HEIGHT := 880.0


## Escala del HUD según la ventana (1 = tamaño completo, nunca menos de la mitad), por el ajuste
## "Tamaño del HUD" de las opciones (que sí permite agrandarlo).
## Un entero con separador de miles (por defecto el punto: 1.250), para las monedas.
static func thousands(n: int, separator := ".") -> String:
	var digits := str(absi(n))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += separator
		out += digits[i]
	return ("-" if n < 0 else "") + out


static func ui_scale(ci: CanvasItem) -> float:
	var vp := ci.get_viewport_rect().size
	return clampf(minf(vp.x / FULL_SIZE_WIDTH, vp.y / FULL_SIZE_HEIGHT), 0.5, 1.0) * GameSettings.hud_scale


## Disco con degradado radial (centro -> borde).
static func disc(ci: CanvasItem, c: Vector2, r: float, inner: Color, outer: Color, steps := 8) -> void:
	for i in steps:
		var t := float(i) / float(steps - 1)
		ci.draw_circle(c, r * (1.0 - t * 0.9), outer.lerp(inner, t))


## Aro metálico: base, brillo arriba a la izquierda y sombra abajo a la derecha.
static func ring(ci: CanvasItem, c: Vector2, r: float, w: float, base: Color) -> void:
	ci.draw_arc(c, r, 0.0, TAU, 56, base.darkened(0.35), w, true)
	ci.draw_arc(c, r, PI * 0.95, PI * 1.85, 28, base.lightened(0.4), w * 0.55, true)
	ci.draw_arc(c, r, 0.0, PI * 0.8, 20, base.darkened(0.55), w * 0.5, true)


## Rombo pequeño (adorno).
static func diamond(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.7, 0), c + Vector2(0, s), c + Vector2(-s * 0.7, 0)]), col)


## Panel de esquinas cortadas con degradado vertical, doble borde dorado y adornos en las esquinas.
static func panel(ci: CanvasItem, rect: Rect2, cut := 10.0) -> void:
	var p := rect.position
	var e := rect.end
	var pts := PackedVector2Array([Vector2(p.x + cut, p.y), Vector2(e.x - cut, p.y), Vector2(e.x, p.y + cut),
			Vector2(e.x, e.y - cut), Vector2(e.x - cut, e.y), Vector2(p.x + cut, e.y), Vector2(p.x, e.y - cut),
			Vector2(p.x, p.y + cut)])
	var cols := PackedColorArray([PANEL_TOP, PANEL_TOP, PANEL_TOP.lerp(PANEL_BOTTOM, 0.3), PANEL_BOTTOM, PANEL_BOTTOM,
			PANEL_BOTTOM, PANEL_BOTTOM, PANEL_TOP.lerp(PANEL_BOTTOM, 0.3)])
	ci.draw_polygon(pts, cols)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, Color(GOLD, 0.95), 2.0, true)
	ci.draw_rect(rect.grow(-5.0), Color(GOLD, 0.16), false, 1.0)
	for corner: Vector2 in [Vector2(p.x + cut * 0.55, p.y + cut * 0.55), Vector2(e.x - cut * 0.55, p.y + cut * 0.55),
			Vector2(e.x - cut * 0.55, e.y - cut * 0.55), Vector2(p.x + cut * 0.55, e.y - cut * 0.55)]:
		diamond(ci, corner, 3.2, Color(GOLD_LIGHT, 0.9))


## Ícono simple del arma (0 puños, 1 dagas, 2 espada) centrado en `c`; `u` es la escala (1 = ~40 px).
static func weapon_icon(ci: CanvasItem, c: Vector2, u: float, weapon: int) -> void:
	match weapon:
		1:
			for sgn in [-1.0, 1.0]:
				var a := c + Vector2(sgn * -14, 16) * u
				var b := c + Vector2(sgn * 12, -16) * u
				ci.draw_line(a, b, GOLD_LIGHT, 4.0 * u, true)
				var perp := (b - a).normalized().orthogonal() * 6.0 * u
				var mid := a.lerp(b, 0.3)
				ci.draw_line(mid - perp, mid + perp, GOLD, 3.0 * u, true)
		2:
			var a := c + Vector2(-15, 17) * u
			var b := c + Vector2(15, -17) * u
			ci.draw_line(a, b, GOLD_LIGHT, 5.0 * u, true)
			var perp := (b - a).normalized().orthogonal() * 9.0 * u
			var mid := a.lerp(b, 0.25)
			ci.draw_line(mid - perp, mid + perp, GOLD, 4.0 * u, true)
		_:
			ci.draw_circle(c + Vector2(0, 3) * u, 11.0 * u, GOLD_LIGHT)
			for i in 4:
				ci.draw_circle(c + Vector2(-9 + i * 6.0, -7) * u, 4.0 * u, GOLD)


static func key_box(ci: CanvasItem, font: Font, c: Vector2, text: String, bright: float) -> void:
	var r := Rect2(c - Vector2(11, 9), Vector2(22, 18))
	ci.draw_rect(r, Color(0.0, 0.0, 0.0, 0.45))
	ci.draw_rect(r, Color(1, 1, 1, 0.18 * bright + 0.05), false, 1.0)
	ci.draw_string(font, c + Vector2(-11, 5), text, HORIZONTAL_ALIGNMENT_CENTER, 22, 12, Color(1, 1, 1, 0.55 + 0.4 * bright))


static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	ci.draw_colored_polygon(pts, col)


## Frasco de vidrio con corcho y líquido brillante (centrado en `c`, escala `s`); vacío: solo el vidrio.
static func vial(ci: CanvasItem, c: Vector2, s: float, col: Color, filled: bool) -> void:
	ci.draw_set_transform(c, 0.0, Vector2(s, s))
	var glass := Color(0.75, 0.85, 0.95, 0.75 if filled else 0.35)
	if filled:
		for k in 4:
			ci.draw_circle(Vector2(0, 6), 14.0 + k * 3.0, Color(col, 0.08 * (4 - k)))
	var body := Vector2(0, 8)
	disc(ci, body, 13.0, col.lightened(0.35) if filled else Color(0.05, 0.06, 0.08, 0.8), col.darkened(0.35) if filled else Color(0.02, 0.025, 0.035, 0.8))
	ci.draw_rect(Rect2(Vector2(-4.5, -13), Vector2(9, 12)), col.darkened(0.2) if filled else Color(0.04, 0.05, 0.07, 0.8))
	ci.draw_arc(body, 13.0, 0.0, TAU, 28, glass, 1.8, true)
	ci.draw_rect(Rect2(Vector2(-4.5, -13), Vector2(9, 12)), glass, false, 1.5)
	ci.draw_rect(Rect2(Vector2(-6, -17), Vector2(12, 4)), Color(0.55, 0.38, 0.2, 0.95 if filled else 0.45))
	ci.draw_arc(body, 9.0, PI * 1.05, PI * 1.45, 8, Color(1, 1, 1, 0.5 if filled else 0.2), 2.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Pila de monedas plateadas con canto estriado (centrada en `c`, escala `s`).
static func coin_stack(ci: CanvasItem, c: Vector2, s: float, has: bool) -> void:
	ci.draw_set_transform(c, 0.0, Vector2(s, s))
	var coin := Color(0.88, 0.88, 0.9) if has else Color(0.36, 0.36, 0.38)
	for k in 4:
		var y := 12.0 - k * 7.5
		ellipse(ci, Vector2(0, y + 4.0), 16.0, 6.0, coin.darkened(0.55))
		ci.draw_rect(Rect2(-16.0, y - 1.0, 32.0, 5.0), coin.darkened(0.35))
		for j in 7:
			ci.draw_line(Vector2(-14.0 + j * 4.7, y), Vector2(-14.0 + j * 4.7, y + 4.0), coin.darkened(0.6), 1.0)
		ellipse(ci, Vector2(0, y), 16.0, 6.0, coin)
		ellipse(ci, Vector2(0, y), 11.0, 4.0, coin.lightened(0.2))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- Tema de los menús

static var _theme: Theme = null


## Tema común de los menús (pausa, red, arena): paneles oscuros con borde dorado, botones, pestañas,
## deslizadores y cuadros de texto del mismo estilo que el HUD. Se asigna a la raíz de cada menú.
static func menu_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 15
	var panel := _box(Color(0.05, 0.055, 0.075, 0.97), Color(GOLD, 0.9), 2, 8, 20.0, 18.0)
	panel.shadow_color = Color(0, 0, 0, 0.5)
	panel.shadow_size = 12
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	# Botones
	t.set_stylebox("normal", "Button", _box(Color(0.1, 0.11, 0.14), Color(GOLD, 0.55), 1, 5, 16.0, 8.0))
	t.set_stylebox("hover", "Button", _box(Color(0.15, 0.16, 0.2), Color(GOLD_LIGHT, 0.9), 1, 5, 16.0, 8.0))
	t.set_stylebox("pressed", "Button", _box(Color(0.2, 0.17, 0.11), GOLD_LIGHT, 1, 5, 16.0, 8.0))
	t.set_stylebox("disabled", "Button", _box(Color(0.07, 0.075, 0.09), Color(GOLD, 0.2), 1, 5, 16.0, 8.0))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Color(GOLD_LIGHT, 0.5), 1, 5, 16.0, 8.0))
	t.set_color("font_color", "Button", Color(0.92, 0.92, 0.96))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD_LIGHT)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.55))
	# Texto
	t.set_color("font_color", "Label", Color(0.92, 0.92, 0.96))
	t.set_color("default_color", "RichTextLabel", Color(0.9, 0.9, 0.95))
	t.set_color("font_color", "CheckButton", Color(0.92, 0.92, 0.96))
	# Pestañas
	t.set_stylebox("tab_selected", "TabContainer", _box(Color(0.12, 0.11, 0.1), GOLD, 1, 5, 16.0, 8.0))
	t.set_stylebox("tab_unselected", "TabContainer", _box(Color(0.07, 0.075, 0.095), Color(GOLD, 0.25), 1, 5, 16.0, 8.0))
	t.set_stylebox("tab_hovered", "TabContainer", _box(Color(0.11, 0.115, 0.14), Color(GOLD, 0.6), 1, 5, 16.0, 8.0))
	t.set_stylebox("panel", "TabContainer", _box(Color(0.035, 0.04, 0.055, 0.9), Color(GOLD, 0.35), 1, 6, 14.0, 12.0))
	t.set_color("font_selected_color", "TabContainer", GOLD_LIGHT)
	t.set_color("font_unselected_color", "TabContainer", Color(0.75, 0.77, 0.83))
	t.set_color("font_hovered_color", "TabContainer", Color.WHITE)
	# Cuadros de texto y deslizadores
	t.set_stylebox("normal", "LineEdit", _box(Color(0.03, 0.035, 0.05), Color(GOLD, 0.45), 1, 4, 10.0, 6.0))
	t.set_stylebox("focus", "LineEdit", _box(Color(0.03, 0.035, 0.05), GOLD_LIGHT, 1, 4, 10.0, 6.0))
	t.set_color("font_color", "LineEdit", Color(0.95, 0.95, 1.0))
	t.set_stylebox("slider", "HSlider", _box(Color(0.03, 0.035, 0.05), Color(GOLD, 0.35), 1, 3, 0.0, 3.0))
	t.set_stylebox("grabber_area", "HSlider", _box(Color(GOLD, 0.85), Color(GOLD_LIGHT, 0.0), 0, 3, 0.0, 3.0))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(Color(GOLD_LIGHT, 0.95), Color(GOLD_LIGHT, 0.0), 0, 3, 0.0, 3.0))
	_theme = t
	return t


static func _box(bg: Color, border: Color, border_width: int, radius: int, margin_h: float, margin_v: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = margin_v
	s.content_margin_bottom = margin_v
	s.anti_aliasing = true
	return s


## Título de sección (dorado) para los menús.
static func section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", GOLD_LIGHT)
	l.add_theme_font_size_override("font_size", 17)
	return l
