class_name MetalList
extends Control
## Lista vertical de metales a la izquierda de la pantalla: un icono circular por metal con su reserva alrededor y su tecla
## (F1 a F9). Discreta: los metales apagados se ven tenues y los que queman se iluminan. Un candado marca los que todavía
## no se aprendieron (ver el árbol de habilidades, K). Mantener Tab libera el ratón para clicar los iconos (clic: encender
## o apagar; doble clic y mantener: avivar); al soltar Tab el ratón vuelve a la cámara.

const SLOT := 38.0  # diámetro del icono
const GAP := 9.0
const W := 76.0
const MARGIN := 12.0

var player: Player

var _metals: Array = []
## Tab sostenido: el ratón está libre para clicar los iconos; _held_metal es el que se está pulsando.
var _free_mouse := false
var _held_metal: StringName = &""


func _ready() -> void:
	_metals = Allomancy.METALS.keys()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := _metals.size() * (SLOT + GAP) - GAP
	set_anchors_preset(Control.PRESET_CENTER_LEFT)
	offset_left = MARGIN
	offset_right = MARGIN + W
	offset_top = -h * 0.5
	offset_bottom = h * 0.5
	pivot_offset = Vector2(0.0, h * 0.5)


func _process(_delta: float) -> void:
	var s := HudKit.ui_scale(self) * 0.95
	scale = Vector2(s, s)
	queue_redraw()


func _slot_center(i: int) -> Vector2:
	return Vector2(SLOT * 0.5 + 2.0, SLOT * 0.5 + i * (SLOT + GAP))


## El metal cuyo icono está bajo `p` (en coordenadas de la lista), o &"" si ninguno.
func _metal_at(p: Vector2) -> StringName:
	for i in _metals.size():
		if p.distance_to(_slot_center(i)) <= SLOT * 0.5 + 3.0:
			return _metals[i]
	return &""


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


func _draw() -> void:
	var font := get_theme_default_font()
	var now := Time.get_ticks_msec() / 1000.0
	var a := player.allomancy
	for i in _metals.size():
		var m: StringName = _metals[i]
		var info: Dictionary = Allomancy.METALS[m]
		var c := _slot_center(i)
		var r := SLOT * 0.5 - 1.0
		var col: Color = info["color"]
		var frac: float = a.reserve[m] / info["max"]
		var burning := a.is_burning(m)
		var flaring := a.is_flaring(m)
		var learned := a.is_learned(m)
		var empty := frac <= 0.0 or not learned
		var blocked := m == &"pewter" and player.pewter_drag() > 0.0
		var tint := Color(0.5, 0.5, 0.52) if empty else col
		var alpha := 1.0 if (burning or _free_mouse) else 0.62
		# Resplandor suave: apenas si está apagado, más fuerte quemando, pulsante avivando.
		var glow := 0.0 if empty else (0.2 if burning else 0.0)
		if flaring:
			glow = 0.3 + 0.18 * sin(now * 9.0)
		for k in 4:
			draw_circle(c, r + 2.0 + k * 2.5, Color(tint.lightened(0.2), glow * (1.0 - k / 4.0) * 0.5))
		draw_circle(c, r, Color(0.03, 0.035, 0.05, 0.82 * alpha))
		HudKit.disc(self, c, r - 1.0, Color(tint.darkened(0.55 if burning else 0.8), alpha), Color(tint.darkened(0.9), alpha))
		# Reserva: anillo de color sobre una pista oscura.
		draw_arc(c, r - 2.5, 0.0, TAU, 40, Color(0, 0, 0, 0.55 * alpha), 4.0, true)
		if frac > 0.0:
			draw_arc(c, r - 2.5, -PI / 2, -PI / 2 + TAU * frac, maxi(int(40 * frac), 3),
					Color(tint.lightened(0.15 if burning else 0.0), alpha), 3.0, true)
		HudKit.ring(self, c, r, 1.8, Color(HudKit.STEEL if not burning else tint.lightened(0.2), alpha))
		var glyph := tint.lightened(0.3) if burning else tint.lightened(0.12)
		if flaring:
			glyph = Color(1, 1, 1)
		MetalGlyph.draw(self, m, c, r * 0.72, Color(glyph, alpha), 2.0 if burning else 1.7)
		if blocked:
			draw_line(c + Vector2(-r, -r) * 0.6, c + Vector2(r, r) * 0.6, Color(0.9, 0.2, 0.15), 2.5, true)
		if not learned:
			_lock(c + Vector2(r * 0.6, r * 0.6))
		# Tecla pequeña a la derecha del icono.
		draw_string(font, c + Vector2(r + 7.0, 4.0), OS.get_keycode_string(info["key"]), HORIZONTAL_ALIGNMENT_LEFT, 40, 11,
				Color(1, 1, 1, 0.8 if burning else 0.4))


## Candado chico en la esquina del icono de un metal que todavía no se aprendió.
func _lock(c: Vector2) -> void:
	draw_circle(c, 7.0, Color(0, 0, 0, 0.78))
	draw_arc(c + Vector2(0, -2.0), 2.6, PI, TAU, 10, Color(0.9, 0.85, 0.7), 1.4, true)
	draw_rect(Rect2(c + Vector2(-3.0, -1.2), Vector2(6, 4.6)), Color(0.9, 0.85, 0.7))
