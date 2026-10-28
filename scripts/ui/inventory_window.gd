class_name InventoryWindow
extends CanvasLayer
## Inventario de tipo RPG (tecla I). Izquierda: el equipo puesto, una ranura por tipo (capa, ropa,
## botas, dagas, espada, frascos). Centro: la mochila con lo que tienes guardado. Derecha: el
## detalle del objeto elegido, comparado con lo que llevas puesto, y el botón para equiparlo o
## quitarlo. Abajo, el resumen: armadura, velocidad, a qué distancia te ven y si llevas metal.
## Mientras está abierto el juego sigue, pero el ratón es para la ventana.

const ACCENT := Color(0.45, 0.72, 1.0)
const DIM := Color(0.6, 0.62, 0.68)
const GOOD := Color(0.5, 0.9, 0.55)
const BAD := Color(1.0, 0.5, 0.45)
const METAL := Color(1.0, 0.7, 0.35)
const BAG_TILES := 12

var player: Player

var _root: Control
var _slots_box: VBoxContainer
var _bag_grid: GridContainer
var _detail: VBoxContainer
var _summary: Label
var _selected := ""


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
	var title := Label.new()
	title.text = "Inventario"
	title.add_theme_font_size_override("font_size", 30)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var hint := Label.new()
	hint.text = "Clic: ver · doble clic: equipar / quitar · I para cerrar"
	hint.modulate = DIM
	header.add_child(hint)
	col.add_child(header)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	row.add_child(_column("Equipo", 290, func(box: VBoxContainer) -> void:
		_slots_box = VBoxContainer.new()
		_slots_box.add_theme_constant_override("separation", 6)
		box.add_child(_slots_box)
	))
	row.add_child(_column("Mochila", 330, func(box: VBoxContainer) -> void:
		_bag_grid = GridContainer.new()
		_bag_grid.columns = 3
		_bag_grid.add_theme_constant_override("h_separation", 8)
		_bag_grid.add_theme_constant_override("v_separation", 8)
		box.add_child(_bag_grid)
	))
	row.add_child(_column("Detalle", 300, func(box: VBoxContainer) -> void:
		_detail = VBoxContainer.new()
		_detail.add_theme_constant_override("separation", 8)
		box.add_child(_detail)
	))
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 14)
	col.add_child(_summary)

	player.equipment_changed.connect(_refresh)


func _column(title: String, width: float, fill: Callable) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(width, 430)
	card.add_theme_stylebox_override("panel", _box(Color(0.09, 0.1, 0.125), Color(0.2, 0.22, 0.27), 12))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var l := Label.new()
	l.text = title.to_upper()
	l.add_theme_font_size_override("font_size", 13)
	l.modulate = DIM
	box.add_child(l)
	fill.call(box)
	return card


# ---------------------------------------------------------------- Contenido

func _refresh() -> void:
	if _slots_box == null:
		return
	for c in _slots_box.get_children():
		c.queue_free()
	for c in _bag_grid.get_children():
		c.queue_free()
	for slot in Items.SLOTS:
		_slots_box.add_child(_slot_row(slot))
	var bag := player.owned.duplicate()
	bag.sort()
	for id in bag:
		_bag_grid.add_child(_tile(id))
	for i in range(bag.size(), maxi(BAG_TILES, bag.size())):
		_bag_grid.add_child(_tile(""))
	_show_detail()
	_update_summary()


func _slot_row(slot: String) -> Control:
	var id: String = player.equipment.get(slot, "")
	var b := _clickable(id, id != "" and id == _selected)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var icon := ItemIcon.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.empty_slot = slot
	icon.item_id = id
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var s := Label.new()
	s.text = Items.SLOT_NAMES[slot]
	s.add_theme_font_size_override("font_size", 12)
	s.modulate = DIM
	v.add_child(s)
	var n := Label.new()
	n.text = Items.get_item(id)["name"] if id != "" else "— vacío —"
	n.add_theme_font_size_override("font_size", 15)
	n.modulate = Color.WHITE if id != "" else DIM
	v.add_child(n)
	return b


func _tile(id: String) -> Control:
	var b := _clickable(id, id != "" and id == _selected)
	b.custom_minimum_size = Vector2(100, 100)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(v)
	if id == "":
		return b
	var icon := ItemIcon.new()
	icon.custom_minimum_size = Vector2(56, 56)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.item_id = id
	v.add_child(icon)
	var n := Label.new()
	n.text = Items.get_item(id)["name"]
	n.add_theme_font_size_override("font_size", 11)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size = Vector2(90, 0)
	v.add_child(n)
	return b


## Casillero clicable: clic lo elige, doble clic lo equipa o lo quita.
func _clickable(id: String, selected: bool) -> PanelContainer:
	var b := PanelContainer.new()
	var border := ACCENT if selected else Color(0.2, 0.22, 0.27)
	b.add_theme_stylebox_override("panel", _box(Color(0.12, 0.13, 0.16) if id != "" else Color(0.07, 0.075, 0.09), border, 6))
	if id != "":
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_selected = id
				if ev.double_click:
					_toggle_equip(id)
				else:
					_refresh()
		)
	return b


func _is_equipped(id: String) -> bool:
	return id in player.equipment.values()


func _toggle_equip(id: String) -> void:
	if _is_equipped(id):
		player.unequip(Items.get_item(id)["slot"])
	else:
		player.equip(id)


func _show_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	if _selected == "" or not player.has_item(_selected):
		_selected = ""
		var l := _text("Elegí un objeto para ver qué hace.", DIM)
		_detail.add_child(l)
		return
	var it := Items.get_item(_selected)
	var equipped := _is_equipped(_selected)
	var icon := ItemIcon.new()
	icon.custom_minimum_size = Vector2(84, 84)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	icon.item_id = _selected
	_detail.add_child(icon)
	var name_l := Label.new()
	name_l.text = it["name"]
	name_l.add_theme_font_size_override("font_size", 20)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(name_l)
	_detail.add_child(_text("%s · %s" % [Items.SLOT_NAMES[it["slot"]], "equipado" if equipped else "en la mochila"],
			ACCENT if equipped else DIM))
	_detail.add_child(_text(it["desc"], Color(0.85, 0.87, 0.9)))
	# Stats, comparados con lo que llevas en esa ranura.
	var current: String = player.equipment.get(it["slot"], "")
	for key in _stat_keys(_selected, current):
		var info: Array = Items.STAT_INFO[key]
		var neutral := 0.0 if key in ["armor", "impact", "reach", "charges", "refill"] else 1.0
		var v := Items.stat(_selected, key, neutral)
		var line := "%s  %s" % [info[0], info[2] % (v * info[3])]
		var color := Color(0.85, 0.87, 0.9)
		if not equipped and current != "":
			var cur := Items.stat(current, key, neutral)
			if not is_equal_approx(v, cur):
				var better: bool = (v > cur) == info[1]
				color = GOOD if better else BAD
				line += "   (%s)" % ("mejor" if better else "peor")
		_detail.add_child(_text(line, color))
	if it.get("metal", false):
		_detail.add_child(_text("METAL: con esto puesto te pueden empujar y tirar de vos.", METAL))
	else:
		_detail.add_child(_text("Sin metal.", GOOD))
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.text = "Quitar" if equipped else "Equipar"
	button.pressed.connect(_toggle_equip.bind(_selected))
	_detail.add_child(button)


## Stats que tienen el objeto elegido o el equipado en su ranura (para mostrar lo que cambia).
func _stat_keys(a: String, b: String) -> Array:
	var keys := []
	for id in [a, b]:
		if id == "":
			continue
		for k in Items.get_item(id)["stats"]:
			if not k in keys:
				keys.append(k)
	return keys


func _update_summary() -> void:
	var metal := PackedStringArray()
	if player.has_bag():
		metal.append("bolsa de monedas")
	for id: String in player.equipment.values():
		if id != "" and Items.get_item(id).get("metal", false):
			metal.append(Items.get_item(id)["name"].to_lower())
	var night := player.gear_stat("conceal_night")
	_summary.text = "Armadura %d %%   ·   Velocidad ×%.2f   ·   Aguante de impactos %+.0f m/s   ·   Te ven de noche a ×%.2f   ·   Frascos %d/%d\n%s" % [
		int(player.gear_stat("armor", true) * 100.0), player.gear_stat("speed"), player.gear_stat("impact", true),
		night, player.vial_charges, player.max_vials(),
		("Metal encima: " + ", ".join(metal) + "  (te pueden empujar y tirar de vos)") if not metal.is_empty()
				else "Sin metal encima: ningún alomántico puede empujarte ni tirar de vos."]
	_summary.modulate = Color.WHITE
	_summary.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9) if not metal.is_empty() else GOOD)


func _text(t: String, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(270, 0)
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"inventory") or (_root.visible and event is InputEventKey \
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
