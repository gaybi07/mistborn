class_name MetalBar
extends Control
## Barra inferior al estilo de los MOBA: los metales arriba (símbolo, reserva alrededor y tecla)
## y la vida debajo. 1-4 acero, hierro, peltre y atium; Z X C V B cinc, cobre, bronce, estaño y latón.
## Quemando: el metal se ilumina con su color. Avivando: halo pulsante. El anillo es la reserva.

const SLOT := 54.0
const GAP := 8.0
const GROUP_GAP := 28.0
const PAD := 14.0
const INFO_H := 20.0
const KEY_H := 18.0
const HEALTH_H := 18.0
## Los cuatro primeros (teclas numéricas) van separados del resto.
const FIRST_GROUP := 4

var player: Player

var _metals: Array = []
var _trail := 100.0  # vida "fantasma" que baja despacio tras un golpe
var _panel := StyleBoxFlat.new()


func _ready() -> void:
	_metals = Allomancy.METALS.keys()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := _metals.size() * SLOT + (_metals.size() - 2) * GAP + GROUP_GAP + PAD * 2.0
	var h := PAD * 2.0 + INFO_H + SLOT + KEY_H + 8.0 + HEALTH_H
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -w / 2.0
	offset_right = w / 2.0
	offset_top = -h - 10.0
	offset_bottom = -10.0
	_panel.bg_color = Color(0.045, 0.05, 0.065, 0.84)
	_panel.border_color = Color(0.4, 0.42, 0.48, 0.55)
	_panel.set_border_width_all(1)
	_panel.set_corner_radius_all(10)
	_panel.shadow_color = Color(0, 0, 0, 0.35)
	_panel.shadow_size = 6
	_trail = player.health


func _process(delta: float) -> void:
	var rd := delta / Engine.time_scale
	_trail = player.health if player.health > _trail else move_toward(_trail, player.health, rd * 25.0)
	queue_redraw()


func _slot_center(i: int) -> Vector2:
	var x := PAD + SLOT * 0.5 + i * (SLOT + GAP)
	if i >= FIRST_GROUP:
		x += GROUP_GAP - GAP
	return Vector2(x, PAD + INFO_H + SLOT * 0.5)


func _draw() -> void:
	var font := get_theme_default_font()
	draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	var a := player.allomancy
	var now := Time.get_ticks_msec() / 1000.0

	# Línea de información: arma a la izquierda; frascos y bolsa a la derecha.
	var dim := Color(0.8, 0.82, 0.88, 0.75)
	draw_string(font, Vector2(PAD, PAD + 13), player.weapon_stats(player.weapon)["name"], HORIZONTAL_ALIGNMENT_LEFT, 220, 13, dim)
	var right := "Frascos %d/%d   ·   %s" % [player.vial_charges, player.max_vials(),
			("Bolsa de monedas" if player.has_bag() else "SIN BOLSA (F)") + ("" if player.carries_metal() else "  ·  sin metal")]
	var right_col := dim if player.has_bag() else Color(1.0, 0.7, 0.4)
	draw_string(font, Vector2(size.x - PAD - 300, PAD + 13), right, HORIZONTAL_ALIGNMENT_RIGHT, 300, 13, right_col)

	# Separador entre los dos grupos.
	var sep_x := (_slot_center(FIRST_GROUP - 1).x + _slot_center(FIRST_GROUP).x) * 0.5
	var sy := PAD + INFO_H
	draw_line(Vector2(sep_x, sy + 6), Vector2(sep_x, sy + SLOT - 6), Color(1, 1, 1, 0.12), 1.0)

	for i in _metals.size():
		var m: StringName = _metals[i]
		var info: Dictionary = Allomancy.METALS[m]
		var c := _slot_center(i)
		var r := SLOT * 0.5 - 4.0
		var col: Color = info["color"]
		var frac: float = a.reserve[m] / info["max"]
		var burning := a.is_burning(m)
		var flaring := a.is_flaring(m)
		var blocked := m == &"pewter" and player.pewter_drag() > 0.0
		if flaring:
			var pulse := 0.5 + 0.5 * sin(now * 9.0)
			for k in 4:
				draw_arc(c, r + 3.0 + k * 2.0, 0.0, TAU, 40, Color(col.lightened(0.4), (0.45 - k * 0.1) * (0.6 + 0.4 * pulse)), 2.0, true)
		draw_circle(c, r, Color(0.03, 0.035, 0.045))
		if burning:
			draw_circle(c, r, Color(col.darkened(0.55), 0.95 if flaring else 0.75))
		# Reserva: anillo que se vacía en sentido horario desde arriba.
		draw_arc(c, r - 1.5, 0.0, TAU, 40, Color(1, 1, 1, 0.08), 3.0, true)
		if frac > 0.0:
			draw_arc(c, r - 1.5, -PI / 2, -PI / 2 + TAU * frac, maxi(int(40 * frac), 3),
					Color(col, 1.0 if burning else 0.55), 3.0, true)
		var glyph := col.lightened(0.35) if burning else Color(col.darkened(0.25), 0.55)
		if flaring:
			glyph = Color(1, 1, 1)
		if frac <= 0.0:
			glyph = Color(0.4, 0.4, 0.42, 0.5)
		MetalGlyph.draw(self, m, c, r * 0.78, glyph, 2.2 if burning else 1.7)
		if blocked:
			draw_line(c + Vector2(-r, -r) * 0.6, c + Vector2(r, r) * 0.6, Color(0.9, 0.2, 0.15), 3.0, true)
		# Tecla.
		var key := OS.get_keycode_string(info["key"])
		var kc := Vector2(c.x, c.y + SLOT * 0.5 + KEY_H * 0.5 + 1.0)
		draw_rect(Rect2(kc - Vector2(10, 8), Vector2(20, 16)), Color(1, 1, 1, 0.07))
		draw_string(font, kc + Vector2(-10, 5), key, HORIZONTAL_ALIGNMENT_CENTER, 20, 12,
				Color(1, 1, 1, 0.9 if burning else 0.5))

	# Vida.
	var hy := PAD + INFO_H + SLOT + KEY_H + 8.0
	var hr := Rect2(PAD, hy, size.x - PAD * 2.0, HEALTH_H)
	draw_rect(hr, Color(0.0, 0.0, 0.0, 0.6))
	var maxh := player.max_health
	var trail_r := Rect2(hr.position, Vector2(hr.size.x * clampf(_trail / maxh, 0.0, 1.0), hr.size.y))
	draw_rect(trail_r, Color(0.95, 0.85, 0.7, 0.55))
	var hp := clampf(player.health / maxh, 0.0, 1.0)
	var fill := Rect2(hr.position, Vector2(hr.size.x * hp, hr.size.y))
	var low := hp < 0.3
	var base := Color(0.62, 0.1, 0.09) if not low else Color(0.75, 0.08, 0.06).lerp(Color(1, 0.3, 0.2), 0.5 + 0.5 * sin(now * 8.0))
	draw_rect(fill, base)
	draw_rect(Rect2(fill.position, Vector2(fill.size.x, fill.size.y * 0.4)), Color(1, 1, 1, 0.12))
	# Marcas cada 10 de vida.
	var ticks := int(maxh / 10.0)
	for k in range(1, ticks):
		var x := hr.position.x + hr.size.x * k / ticks
		draw_line(Vector2(x, hy + HEALTH_H * 0.55), Vector2(x, hy + HEALTH_H), Color(0, 0, 0, 0.45), 1.0)
	draw_rect(hr, Color(1, 1, 1, 0.18), false, 1.0)
	var hp_text := "%d / %d" % [ceili(player.health), int(maxh)]
	var hp_pos := Vector2(hr.position.x, hy + 14)
	draw_string_outline(font, hp_pos, hp_text, HORIZONTAL_ALIGNMENT_CENTER, hr.size.x, 13, 3, Color(0, 0, 0, 0.8))
	draw_string(font, hp_pos, hp_text, HORIZONTAL_ALIGNMENT_CENTER, hr.size.x, 13, Color(1, 1, 1, 0.95))
