class_name HudKit
## Piezas de dibujo compartidas por la barra central (MetalBar) y los paneles de las esquinas (HudCorner):
## colores, aros metálicos, paneles con borde dorado, íconos de bolsa, frascos y monedas.
## Todas son funciones estáticas que dibujan sobre el CanvasItem `ci` (se llaman desde su _draw).

const GOLD := Color(0.72, 0.62, 0.45)
const GOLD_LIGHT := Color(0.95, 0.86, 0.66)
const STEEL := Color(0.52, 0.54, 0.6)
const PANEL_TOP := Color(0.085, 0.09, 0.11, 0.94)
const PANEL_BOTTOM := Color(0.03, 0.033, 0.045, 0.94)
const DIM := Color(0.82, 0.84, 0.9, 0.8)
const VIAL_COLORS: Array[Color] = [Color(0.9, 0.22, 0.22), Color(0.95, 0.78, 0.25), Color(0.3, 0.6, 1.0)]
## Ancho de pantalla (px) a partir del cual el HUD se ve a tamaño completo; en ventanas más chicas se reduce.
const FULL_SIZE_WIDTH := 1650.0
const FULL_SIZE_HEIGHT := 880.0


## Escala del HUD según la ventana (1 = tamaño completo, nunca menos de la mitad).
static func ui_scale(ci: CanvasItem) -> float:
	var vp := ci.get_viewport_rect().size
	return clampf(minf(vp.x / FULL_SIZE_WIDTH, vp.y / FULL_SIZE_HEIGHT), 0.5, 1.0)


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


## Medallón de la bolsa de cuero (radio 44 × `s`); gris y tachado si no la llevas.
static func bag(ci: CanvasItem, c: Vector2, s: float, has: bool) -> void:
	ci.draw_set_transform(c, 0.0, Vector2(s, s))
	disc(ci, Vector2.ZERO, 44.0, Color(0.1, 0.1, 0.12), Color(0.02, 0.022, 0.03))
	ring(ci, Vector2.ZERO, 44.0, 4.0, GOLD)
	ci.draw_arc(Vector2.ZERO, 37.0, 0.0, TAU, 48, Color(1, 1, 1, 0.1), 1.0, true)
	for k in 4:
		var a := TAU * k / 4.0 - PI / 2.0
		diamond(ci, Vector2(cos(a), sin(a)) * 44.0, 4.5, Color(GOLD_LIGHT, 0.95) if has else Color(0.5, 0.5, 0.52))
	var base := Color(0.72, 0.47, 0.24) if has else Color(0.36, 0.36, 0.38)
	disc(ci, Vector2(0, 8), 20.0, base.lightened(0.25), base.darkened(0.45))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-8, -12), Vector2(8, -12), Vector2(14, 2), Vector2(-14, 2)]), base.darkened(0.1))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-10, -17), Vector2(-5, -11), Vector2(5, -11), Vector2(10, -17), Vector2(0, -14)]), base.darkened(0.25))
	ci.draw_line(Vector2(-10, -4), Vector2(10, -4), base.lightened(0.55), 2.5, true)
	ci.draw_line(Vector2(-9, -1), Vector2(9, -1), base.darkened(0.55), 1.5, true)
	ci.draw_arc(Vector2(0, 8), 16.0, PI * 0.1, PI * 0.65, 12, Color(1, 1, 1, 0.22), 2.5, true)
	ci.draw_circle(Vector2(0, 10), 3.0, base.lightened(0.5) if has else base)
	if not has:
		ci.draw_line(Vector2(-26, -26), Vector2(26, 26), Color(0.9, 0.2, 0.15), 3.5, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
