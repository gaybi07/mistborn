class_name MetalBar
extends Control
## Barra central inferior: los metales (símbolo, reserva alrededor, nombre y tecla) y debajo un marco
## único con la vida y la resistencia a los lados de una brújula. F1 a F9: acero, hierro, peltre, atium,
## cinc, cobre, bronce, estaño y latón (o clic en el icono con Tab sostenido). Quemando: el metal brilla.
## Avivando: halo pulsante. Con un candado: todavía no se aprendió (ver el árbol de habilidades, K).
## El anillo de color es la reserva. La bolsa, los frascos y las monedas están en HudCorner.
## Todo se dibuja por código (degradados, brillos y aros metálicos) y se reduce con la ventana.

const W := 840.0
const H := 192.0
const SLOT := 60.0
const GAP := 10.0
const GROUP_GAP := 30.0
const PAD := 16.0
const HEAD_H := 22.0
const KEY_H := 22.0
## Los cuatro primeros (teclas numéricas) van separados del resto.
const FIRST_GROUP := 4

var player: Player

var _metals: Array = []
var _trail := 100.0  # vida "fantasma" que baja despacio tras un golpe
## Tab sostenido: el ratón está libre para clicar los iconos; _held_metal es el que se está pulsando.
var _free_mouse := false
var _held_metal: StringName = &""
var _metal_rect: Rect2
var _frame_rect := Rect2(20, 150, 800, 34)
var _compass_c := Vector2(420, 167)
var _health_rect := Rect2(104, 157, 272, 20)
var _stamina_rect := Rect2(464, 157, 272, 20)


func _ready() -> void:
	_metals = Allomancy.METALS.keys()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mw := _metals.size() * SLOT + (_metals.size() - 1) * GAP + (GROUP_GAP - GAP) + PAD * 2.0
	_metal_rect = Rect2((W - mw) / 2.0, 6, mw, PAD + HEAD_H + SLOT + KEY_H + 8.0)
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -W / 2.0
	offset_right = W / 2.0
	offset_top = -H - 8.0
	offset_bottom = -8.0
	pivot_offset = Vector2(W / 2.0, H)
	_trail = player.health


func _process(delta: float) -> void:
	var rd := delta / Engine.time_scale
	_trail = player.health if player.health > _trail else move_toward(_trail, player.health, rd * 25.0)
	var s := HudKit.ui_scale(self)
	scale = Vector2(s, s)
	queue_redraw()


## Mantener Tab libera el ratón para clicar los iconos de los metales (clic: encender o apagar; doble clic y
## mantener: avivar). Al soltar Tab el ratón vuelve a la cámara.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"metal_wheel") and not _free_mouse and not player.ui_open and not player.dead:
		_free_mouse = true
		player.ui_open = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_released(&"metal_wheel") and _free_mouse:
		_release_mouse()
	elif _free_mouse and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _metal_at(get_local_mouse_position())
		if event.pressed and hit != &"":
			_held_metal = hit
			player.click_metal(hit, true)
		elif not event.pressed and _held_metal != &"":
			player.click_metal(_held_metal, false)
			_held_metal = &""
		get_viewport().set_input_as_handled()


func _release_mouse() -> void:
	_free_mouse = false
	if _held_metal != &"":
		player.click_metal(_held_metal, false)
		_held_metal = &""
	player.ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## El metal cuyo icono está bajo `p` (en coordenadas de la barra), o &"" si ninguno.
func _metal_at(p: Vector2) -> StringName:
	for i in _metals.size():
		if p.distance_to(_slot_center(i)) <= SLOT * 0.5:
			return _metals[i]
	return &""


func _slot_center(i: int) -> Vector2:
	var x := _metal_rect.position.x + PAD + SLOT * 0.5 + i * (SLOT + GAP)
	if i >= FIRST_GROUP:
		x += GROUP_GAP - GAP
	return Vector2(x, _metal_rect.position.y + PAD + HEAD_H + SLOT * 0.5)


func _draw() -> void:
	var font := get_theme_default_font()
	var now := Time.get_ticks_msec() / 1000.0
	_draw_metals(font, now)
	_draw_bars(font, now)


# ---------------------------------------------------------------- Metales

func _draw_metals(font: Font, now: float) -> void:
	HudKit.panel(self, _metal_rect, 14.0)
	_wings(_metal_rect)
	var a := player.allomancy
	var sep_x := (_slot_center(FIRST_GROUP - 1).x + _slot_center(FIRST_GROUP).x) * 0.5
	var sy := _metal_rect.position.y + PAD + HEAD_H
	draw_line(Vector2(sep_x, sy + 4), Vector2(sep_x, sy + SLOT - 4), Color(HudKit.GOLD, 0.3), 1.0)
	for i in _metals.size():
		var m: StringName = _metals[i]
		var info: Dictionary = Allomancy.METALS[m]
		var c := _slot_center(i)
		var r := SLOT * 0.5 - 2.0
		var col: Color = info["color"]
		var frac: float = a.reserve[m] / info["max"]
		var burning := a.is_burning(m)
		var flaring := a.is_flaring(m)
		var learned := a.is_learned(m)
		var empty := frac <= 0.0 or not learned
		var blocked := m == &"pewter" and player.pewter_drag() > 0.0
		var tint := Color(0.5, 0.5, 0.52) if empty else col
		draw_string(font, Vector2(c.x - SLOT * 0.5 - GAP * 0.5, _metal_rect.position.y + PAD + 13), info["label"],
				HORIZONTAL_ALIGNMENT_CENTER, SLOT + GAP, 13, Color(1, 1, 1, 0.88).lerp(col.lightened(0.45), 0.8 if burning else 0.0))
		# Resplandor: leve siempre, fuerte quemando, pulsante avivando.
		var glow := 0.0 if empty else (0.22 if burning else 0.07)
		if flaring:
			glow = 0.3 + 0.2 * sin(now * 9.0)
		for k in 5:
			draw_circle(c, r + 2.0 + k * 3.0, Color(tint.lightened(0.2), glow * (1.0 - k / 5.0) * 0.55))
		# Fondo: oscuro y teñido del color del metal.
		HudKit.disc(self, c, r, tint.darkened(0.55) if burning else tint.darkened(0.8), tint.darkened(0.9))
		# Reserva: anillo de color sobre una pista oscura, dentro del aro metálico.
		draw_arc(c, r - 3.5, 0.0, TAU, 48, Color(0, 0, 0, 0.55), 5.0, true)
		if frac > 0.0:
			draw_arc(c, r - 3.5, -PI / 2, -PI / 2 + TAU * frac, maxi(int(48 * frac), 3),
					Color(tint.lightened(0.15 if burning else 0.0), 1.0), 4.0, true)
		HudKit.ring(self, c, r, 2.6, HudKit.STEEL if not burning else tint.lightened(0.2))
		var glyph := tint.lightened(0.3) if burning else tint.lightened(0.12)
		if flaring:
			glyph = Color(1, 1, 1)
		MetalGlyph.draw(self, m, c, r * 0.76, glyph, 2.5 if burning else 2.0)
		if blocked:
			draw_line(c + Vector2(-r, -r) * 0.6, c + Vector2(r, r) * 0.6, Color(0.9, 0.2, 0.15), 3.0, true)
		if not learned:
			_lock(c + Vector2(r * 0.55, r * 0.55))
		HudKit.key_box(self, font, Vector2(c.x, c.y + SLOT * 0.5 + KEY_H * 0.5 + 2.0), OS.get_keycode_string(info["key"]),
				1.0 if burning else 0.4)


## Candado chico en la esquina del icono de un metal que todavía no se aprendió.
func _lock(c: Vector2) -> void:
	draw_circle(c, 8.0, Color(0, 0, 0, 0.75))
	draw_arc(c + Vector2(0, -2.5), 3.0, PI, TAU, 10, Color(0.9, 0.85, 0.7), 1.6, true)
	draw_rect(Rect2(c + Vector2(-3.5, -1.5), Vector2(7, 5.5)), Color(0.9, 0.85, 0.7))


## Adornos del panel: puntas a los lados y rombo arriba al centro.
func _wings(rect: Rect2) -> void:
	var mid := rect.position.y + rect.size.y * 0.5
	for s in [-1.0, 1.0]:
		var x: float = rect.position.x if s < 0.0 else rect.end.x
		draw_colored_polygon(PackedVector2Array([Vector2(x + s * 16, mid), Vector2(x - s * 4, mid - 9), Vector2(x - s * 4, mid + 9)]), Color(HudKit.GOLD, 0.95))
		draw_line(Vector2(x - s * 4, mid - 12), Vector2(x - s * 20, mid - 20), Color(HudKit.GOLD, 0.6), 1.5, true)
		draw_line(Vector2(x - s * 4, mid + 12), Vector2(x - s * 20, mid + 20), Color(HudKit.GOLD, 0.6), 1.5, true)
	HudKit.diamond(self, Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y), 6.0, Color(HudKit.GOLD_LIGHT, 0.95))


# ---------------------------------------------------------------- Vida y resistencia

func _draw_bars(font: Font, now: float) -> void:
	_draw_frame()
	var maxh := player.max_health
	var hp := clampf(player.health / maxh, 0.0, 1.0)
	var low := hp < 0.3
	var red := Color(0.72, 0.1, 0.09) if not low else Color(0.8, 0.08, 0.06).lerp(Color(1, 0.35, 0.25), 0.5 + 0.5 * sin(now * 8.0))
	_bar(font, _health_rect, hp, clampf(_trail / maxh, 0.0, 1.0), red,
			"%d / %d" % [ceili(player.health), int(maxh)], int(maxh / 10.0))
	var sp := clampf(player.stamina / player.max_stamina, 0.0, 1.0)
	var tired := player.is_exhausted()
	var blue := Color(0.17, 0.48, 0.92)
	if tired:
		blue = Color(0.45, 0.5, 0.6).lerp(Color(0.95, 0.55, 0.2), 0.5 + 0.5 * sin(now * 8.0))
	_bar(font, _stamina_rect, sp, sp, blue, "Sin aliento" if tired else "%d / %d" % [ceili(player.stamina), int(player.max_stamina)], 0)
	_heart(Vector2(_health_rect.position.x - 24, _frame_rect.position.y + _frame_rect.size.y * 0.5 - 1), 9.0, Color(0.95, 0.22, 0.22))
	_runner(Vector2(_stamina_rect.end.x + 26, _frame_rect.position.y + _frame_rect.size.y * 0.5), 10.0,
			Color(0.5, 0.8, 1.0) if not tired else Color(1.0, 0.6, 0.3))
	_compass(_compass_c)


## Marco único con las puntas hacia afuera, que abraza las dos barras y la brújula.
func _draw_frame() -> void:
	var p := _frame_rect.position
	var e := _frame_rect.end
	var mid := (p.y + e.y) * 0.5
	var tip := 38.0
	var pts := PackedVector2Array([Vector2(p.x, mid), Vector2(p.x + tip, p.y), Vector2(e.x - tip, p.y), Vector2(e.x, mid),
			Vector2(e.x - tip, e.y), Vector2(p.x + tip, e.y)])
	var cols := PackedColorArray([HudKit.PANEL_TOP, HudKit.PANEL_TOP, HudKit.PANEL_TOP, HudKit.PANEL_TOP, HudKit.PANEL_BOTTOM, HudKit.PANEL_BOTTOM])
	draw_polygon(pts, cols)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, Color(HudKit.GOLD, 0.95), 2.2, true)
	var inner := PackedVector2Array([Vector2(p.x + 10, mid), Vector2(p.x + tip + 2, p.y + 4), Vector2(e.x - tip - 2, p.y + 4),
			Vector2(e.x - 10, mid), Vector2(e.x - tip - 2, e.y - 4), Vector2(p.x + tip + 2, e.y - 4), Vector2(p.x + 10, mid)])
	draw_polyline(inner, Color(HudKit.GOLD, 0.2), 1.0, true)
	for s in [-1.0, 1.0]:
		var x: float = p.x if s < 0.0 else e.x
		draw_colored_polygon(PackedVector2Array([Vector2(x + s * 14, mid), Vector2(x - s * 6, mid - 8), Vector2(x - s * 6, mid + 8)]), Color(HudKit.GOLD, 0.95))
		draw_line(Vector2(x - s * 6, mid - 10), Vector2(x - s * 22, mid - 14), Color(HudKit.GOLD, 0.6), 1.5, true)
		draw_line(Vector2(x - s * 6, mid + 10), Vector2(x - s * 22, mid + 14), Color(HudKit.GOLD, 0.6), 1.5, true)


## Barra rellena con degradado, brillo y marcas; la estela clara es la vida recién perdida.
func _bar(font: Font, rect: Rect2, frac: float, trail: float, fill: Color, text: String, ticks: int) -> void:
	draw_rect(rect, Color(0, 0, 0, 0.7))
	if trail > frac:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * trail, rect.size.y)), Color(0.98, 0.9, 0.75, 0.6))
	if frac > 0.0:
		var f := Rect2(rect.position, Vector2(rect.size.x * frac, rect.size.y))
		draw_rect(f, fill.darkened(0.25))
		draw_rect(Rect2(f.position, Vector2(f.size.x, f.size.y * 0.6)), fill)
		draw_rect(Rect2(f.position, Vector2(f.size.x, f.size.y * 0.28)), Color(fill.lightened(0.45), 0.55))
		draw_line(f.position + Vector2(f.size.x, 0), f.position + Vector2(f.size.x, f.size.y), Color(1, 1, 1, 0.4), 1.5)
	for k in range(1, ticks):
		var x := rect.position.x + rect.size.x * k / ticks
		draw_line(Vector2(x, rect.end.y - rect.size.y * 0.4), Vector2(x, rect.end.y), Color(0, 0, 0, 0.45), 1.0)
	draw_rect(rect, Color(HudKit.GOLD, 0.5), false, 1.2)
	var tp := Vector2(rect.position.x, rect.position.y + 15)
	draw_string_outline(font, tp, text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 13, 4, Color(0, 0, 0, 0.85))
	draw_string(font, tp, text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 13, Color(1, 1, 1, 0.97))


## Rosa de los vientos: aro dorado, ocho puntas y centro oscuro.
func _compass(c: Vector2) -> void:
	for k in 4:
		draw_circle(c, 33.0 + k * 3.0, Color(0, 0, 0, 0.12 * (4 - k)))
	HudKit.disc(self, c, 30.0, Color(0.11, 0.11, 0.14), Color(0.02, 0.022, 0.03))
	HudKit.ring(self, c, 30.0, 4.5, HudKit.GOLD)
	draw_arc(c, 24.0, 0.0, TAU, 40, Color(HudKit.GOLD, 0.35), 1.0, true)
	for i in 8:
		var ang := TAU * i / 8.0 - PI / 2.0
		var len := 27.0 if i % 2 == 0 else 15.0
		var dir := Vector2(cos(ang), sin(ang))
		var side := Vector2(-dir.y, dir.x) * (4.2 if i % 2 == 0 else 3.0)
		var tone := HudKit.GOLD_LIGHT if i % 2 == 0 else HudKit.GOLD
		# Cada punta con una mitad clara y otra oscura, para dar relieve.
		draw_colored_polygon(PackedVector2Array([c + dir * len, c + side, c]), tone)
		draw_colored_polygon(PackedVector2Array([c + dir * len, c - side, c]), tone.darkened(0.4))
	draw_circle(c, 5.0, Color(0.04, 0.045, 0.06))
	draw_arc(c, 5.0, 0.0, TAU, 16, HudKit.GOLD_LIGHT, 1.5, true)
	HudKit.diamond(self, c, 2.5, HudKit.GOLD_LIGHT)


func _heart(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c + Vector2(-s * 0.48, -s * 0.15), s * 0.56, col)
	draw_circle(c + Vector2(s * 0.48, -s * 0.15), s * 0.56, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 1.0, 0.1 * s), c + Vector2(s * 1.0, 0.1 * s), c + Vector2(0, s * 1.05)]), col)
	draw_circle(c + Vector2(-s * 0.5, -s * 0.3), s * 0.2, Color(1, 1, 1, 0.45))


## Figura corriendo: cabeza, torso, brazos y piernas.
func _runner(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c + Vector2(s * 0.25, -s * 0.8), s * 0.27, col)
	draw_line(c + Vector2(s * 0.1, -s * 0.45), c + Vector2(-s * 0.1, s * 0.15), col, 2.6, true)
	draw_polyline(PackedVector2Array([c + Vector2(s * 0.5, -s * 0.2), c + Vector2(s * 0.05, -s * 0.35), c + Vector2(-s * 0.4, -s * 0.1)]), col, 2.4, true)
	draw_polyline(PackedVector2Array([c + Vector2(-s * 0.1, s * 0.15), c + Vector2(s * 0.35, s * 0.35), c + Vector2(s * 0.15, s * 0.9)]), col, 2.6, true)
	draw_polyline(PackedVector2Array([c + Vector2(-s * 0.1, s * 0.15), c + Vector2(-s * 0.5, s * 0.55), c + Vector2(-s * 0.85, s * 0.4)]), col, 2.6, true)
