class_name SlotKey
extends Control
## Ranura del árbol de habilidades dibujada como una tecla de teclado: la letra de la tecla arriba a la izquierda y, en el
## centro, el icono de la habilidad que tiene puesta. Clic: elegirla en el detalle. Clic derecho: vaciarla. Doble clic: cambiar
## su tecla.

signal picked
signal cleared
signal rebind_requested

const GOLD := Color(0.95, 0.8, 0.35)
const KEY_SIZE := Vector2(60.0, 60.0)
const DEPTH := 5.0

var key_text := ""
var skill: StringName = &""
var highlighted := false
var rebinding := false

var _top := StyleBoxFlat.new()
var _base := StyleBoxFlat.new()


func _init() -> void:
	custom_minimum_size = KEY_SIZE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style: StyleBoxFlat in [_top, _base]:
		style.set_corner_radius_all(8)
		style.set_border_width_all(1)
	_base.bg_color = Color(0.03, 0.035, 0.05)
	_base.border_color = Color(0.2, 0.21, 0.26)
	gui_input.connect(_on_gui_input)


func _on_gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed):
		return
	if e.button_index == MOUSE_BUTTON_RIGHT:
		cleared.emit()
	elif e.button_index == MOUSE_BUTTON_LEFT:
		if e.double_click:
			rebind_requested.emit()
		else:
			picked.emit()


func _draw() -> void:
	var filled := skill != &""
	_top.bg_color = Color(0.13, 0.14, 0.19) if filled else Color(0.08, 0.085, 0.11)
	_top.border_color = GOLD if highlighted else (Color(0.42, 0.45, 0.55) if filled else Color(0.22, 0.23, 0.28))
	var face := Rect2(Vector2.ZERO, Vector2(size.x, size.y - DEPTH))
	draw_style_box(_base, Rect2(Vector2(0.0, DEPTH), Vector2(size.x, size.y - DEPTH)))
	draw_style_box(_top, face)
	var font := get_theme_default_font()
	var legend := "…" if rebinding else key_text
	draw_string(font, Vector2(8.0, 17.0), legend, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12.0, 13, GOLD if rebinding or highlighted else Color(0.78, 0.8, 0.86))
	if filled:
		var metal: StringName = SkillTree.find(skill)["metal"]
		var tint: Color = Allomancy.METALS[metal]["color"]
		SkillIcon.draw(self, face.get_center() + Vector2(3.0, 5.0), 20.0, skill, tint)
