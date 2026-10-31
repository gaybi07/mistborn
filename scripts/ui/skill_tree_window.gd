class_name SkillTreeWindow
extends CanvasLayer
## Árbol de habilidades (tecla K): una tarjeta por metal con su nivel, el botón para subirlo con puntos de
## alomancia y sus habilidades (las ya desbloqueadas y en qué nivel llega la siguiente). Los puntos se pueden
## reasignar en cualquier momento. Mientras está abierto el juego sigue, pero el ratón es para la ventana.

const DIM := Color(0.6, 0.62, 0.68)
const GOOD := Color(0.5, 0.9, 0.55)
const GOLD := Color(0.95, 0.8, 0.35)

var player: Player

var _root: Control
var _title: Label
var _grid: GridContainer
var _slots_row: GridContainer
## Ranura cuya tecla se está cambiando (la próxima tecla que pulses), o -1.
var _rebinding := -1


func _ready() -> void:
	layer = 30
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", _box(Color(0.06, 0.065, 0.085, 0.97), Color(0.3, 0.32, 0.4), 20))
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	var title := Label.new()
	title.text = "Habilidades"
	title.add_theme_font_size_override("font_size", 30)
	header.add_child(title)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	header.add_child(_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var reset := Button.new()
	reset.text = "Reasignar puntos"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(func() -> void:
		Progression.respec()
		_refresh())
	header.add_child(reset)
	var hint := Label.new()
	hint.text = "K para cerrar"
	hint.modulate = DIM
	header.add_child(hint)
	col.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(980, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)

	var slots_title := Label.new()
	slots_title.text = "RANURAS  ·  clic en la tecla para cambiarla, clic en la habilidad para vaciarla"
	slots_title.add_theme_font_size_override("font_size", 13)
	slots_title.modulate = DIM
	col.add_child(slots_title)
	_slots_row = GridContainer.new()
	_slots_row.columns = Progression.SLOT_COUNT
	_slots_row.add_theme_constant_override("h_separation", 6)
	col.add_child(_slots_row)


func _refresh() -> void:
	var free := Progression.points_free()
	_title.text = "Nivel %d  ·  %d punto%s libre%s  ·  XP %d/%d" % [Progression.level, free, "" if free == 1 else "s",
			"" if free == 1 else "s", Progression.xp, Progression.xp_for_next(Progression.level)]
	_title.add_theme_color_override("font_color", GOLD if free > 0 else Color.WHITE)
	for c in _grid.get_children():
		c.queue_free()
	for metal: StringName in Allomancy.METALS:
		_grid.add_child(_card(metal))
	_refresh_slots()


func _refresh_slots() -> void:
	for c in _slots_row.get_children():
		c.queue_free()
	for i in Progression.SLOT_COUNT:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(76, 0)
		var key_button := Button.new()
		key_button.focus_mode = Control.FOCUS_NONE
		key_button.text = "…" if _rebinding == i else OS.get_keycode_string(Progression.slot_keys[i] as Key)
		key_button.pressed.connect(func() -> void:
			_rebinding = i
			_refresh_slots())
		cell.add_child(key_button)
		var skill := Progression.slot_skills[i]
		var skill_button := Button.new()
		skill_button.focus_mode = Control.FOCUS_NONE
		skill_button.clip_text = true
		skill_button.disabled = skill == &""
		skill_button.text = String(SkillTree.find(skill)["name"]) if skill != &"" else "—"
		skill_button.pressed.connect(func() -> void:
			Progression.clear_slot(i)
			_refresh())
		cell.add_child(skill_button)
		_slots_row.add_child(cell)


func _card(metal: StringName) -> Control:
	var color: Color = Allomancy.METALS[metal]["color"]
	var lvl := Progression.metal_level(metal)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(310, 0)
	card.add_theme_stylebox_override("panel", _box(Color(0.09, 0.1, 0.125), color.darkened(0.35) if lvl > 0 else Color(0.2, 0.22, 0.27), 12))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var head := HBoxContainer.new()
	var name_l := Label.new()
	name_l.text = Allomancy.METALS[metal]["label"]
	name_l.add_theme_font_size_override("font_size", 20)
	name_l.add_theme_color_override("font_color", color)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	var lvl_l := Label.new()
	lvl_l.text = ("Nivel %d / %d" % [lvl, Progression.metal_cap(metal)]) if lvl > 0 else "Sin aprender"
	lvl_l.modulate = Color.WHITE if lvl > 0 else DIM
	head.add_child(lvl_l)
	box.add_child(head)

	var cost := Progression.point_cost(metal)
	var raise := Button.new()
	raise.focus_mode = Control.FOCUS_NONE
	if lvl >= Progression.metal_cap(metal):
		raise.text = "Nivel máximo"
	else:
		raise.text = "%s  (%d punto%s)" % ["Aprender" if lvl == 0 else "Subir nivel", cost, "" if cost == 1 else "s"]
	raise.disabled = not Progression.can_raise(metal)
	raise.pressed.connect(func() -> void:
		if Progression.raise_metal(metal):
			_refresh())
	box.add_child(raise)

	var skills := SkillTree.skills_of(metal)
	if skills.is_empty():
		box.add_child(_line("Habilidades: próximamente.", DIM))
		return card
	for s: Dictionary in skills:
		var id: StringName = s["id"]
		var unlocked := lvl >= int(s["level"])
		var tag := "  (activa)" if s["kind"] == SkillTree.Kind.ACTIVE else "  (pasiva)"
		if id in SkillTree.FIXED_KEY:
			tag = "  (clic derecho)"
		var text := ("✓ " if unlocked else "· ") + String(s["name"]) + tag
		if not unlocked:
			text += "  — nivel %d" % int(s["level"])
		elif id in SkillTree.PENDING:
			text += "  — próximamente"
		var row := HBoxContainer.new()
		var label := _line(text, GOOD if unlocked and not id in SkillTree.PENDING else DIM)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		if unlocked and SkillTree.is_assignable(id):
			var slot := Progression.slot_of(id)
			var assign := Button.new()
			assign.focus_mode = Control.FOCUS_NONE
			assign.text = "Quitar" if slot >= 0 else "Poner en ranura"
			assign.disabled = slot < 0 and not Progression.slot_skills.has(&"")
			assign.pressed.connect(func() -> void:
				if slot >= 0:
					Progression.clear_slot(slot)
				else:
					Progression.assign_skill(id)
				_refresh())
			row.add_child(assign)
		box.add_child(row)
	return card


func _line(t: String, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 14)
	l.modulate = color
	return l


func _box(bg: Color, border: Color, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(margin)
	return s


## Cambiando la tecla de una ranura: la próxima tecla que pulses (Esc cancela).
func _input(event: InputEvent) -> void:
	if _rebinding < 0 or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_ESCAPE:
		Progression.rebind_slot(_rebinding, event.physical_keycode)
	_rebinding = -1
	_refresh_slots()
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"skill_tree") or (_root.visible and event is InputEventKey \
			and event.pressed and event.keycode == KEY_ESCAPE):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if not _root.visible and player.ui_open:
		return  # hay otra ventana abierta
	_root.visible = not _root.visible
	player.ui_open = _root.visible
	_refresh()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _root.visible else Input.MOUSE_MODE_CAPTURED
