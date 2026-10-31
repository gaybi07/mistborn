class_name SkillRowLabel
extends Label
## Nombre de una habilidad en el árbol (K). Al pasar el ratón muestra una tarjeta con su nombre, tipo, qué hace,
## los números con el nivel actual de su metal y, si falta, en qué nivel se desbloquea.

const GOLD := Color(0.95, 0.8, 0.35)
const TEXT := Color(0.86, 0.88, 0.92)
const DIM := Color(0.6, 0.62, 0.68)
const GOOD := Color(0.5, 0.9, 0.55)
const LOCKED := Color(1.0, 0.65, 0.35)
const WIDTH := 380.0

var skill_id: StringName = &""
var metal_level := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_HELP
	tooltip_text = String(skill_id)  # el texto en sí no se ve: solo hace falta que no esté vacío


func _make_custom_tooltip(_for_text: String) -> Object:
	var s := SkillTree.find(skill_id)
	if s.is_empty():
		return null
	var parts := SkillTree.tooltip_parts(skill_id, metal_level)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.05, 0.07, 0.98)
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 14.0
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = WIDTH
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var metal: StringName = s["metal"]
	var kind := "Activa" if s["kind"] == SkillTree.Kind.ACTIVE else "Pasiva"
	if skill_id in SkillTree.FIXED_KEY:
		kind = "Clic derecho"
	box.add_child(_label(String(s["name"]), 20, GOLD))
	box.add_child(_label("%s  ·  %s  ·  desde el nivel %d" % [kind, Allomancy.METALS[metal]["label"], int(s["level"])], 13, DIM))
	box.add_child(HSeparator.new())

	var body := String(parts.get("body", ""))
	for paragraph in body.split("\n"):
		if paragraph != "":
			box.add_child(_label(paragraph, 15, TEXT, true))
	var now := String(parts.get("now", ""))
	if now != "":
		box.add_child(_label(now, 15, GOOD, true))
	var unlock := String(parts.get("unlock", ""))
	if unlock != "":
		box.add_child(_label(unlock, 15, LOCKED, true))
	return panel


func _label(text: String, size: int, color: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = WIDTH
	return l
