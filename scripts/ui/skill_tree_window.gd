class_name SkillTreeWindow
extends CanvasLayer
## Árbol de habilidades (tecla K): una columna por metal con sus habilidades (cada una con "−  n/5  +"), un panel con el detalle de
## la que elijas (qué hace, cómo mejora, ponerla en una ranura o cambiarle la tecla) y la lista de los demás metales. Arriba
## van el nivel, la experiencia y los puntos libres de alomancia; abajo, las ranuras. Los puntos se pueden reasignar en
## cualquier momento. Mientras está abierto el juego sigue, pero el ratón es para la ventana.

const DIM := Color(0.6, 0.62, 0.68)
const GOOD := Color(0.5, 0.9, 0.55)
const GOLD := Color(0.78, 0.66, 1.0)  # elegido, teclas y realces: el violeta de los menús (HudKit.PICK, más claro)
const GOLD_SOFT := Color(0.78, 0.93, 1.0)  # títulos: acero claro (HudKit.ACCENT_LIGHT)
const LOCKED := Color(1.0, 0.65, 0.35)
const ACTIVE_COLOR := Color(0.36, 0.55, 0.78)
const PASSIVE_COLOR := Color(0.85, 0.45, 0.8)  # magenta: se distingue del celeste de las activas sin el marrón de antes
const BG := Color(0.035, 0.04, 0.055, 0.98)
## Ancho del panel de detalle (px): el de partida y lo que se puede estirar arrastrando la barra.
const DETAIL_WIDTH := 350.0
const DETAIL_MIN := 260.0
const DETAIL_MAX := 640.0
## Tamaño (px) para el que está pensada la ventana: en pantallas más chicas se reduce entera para que quepa.
const DESIGN_SIZE := Vector2(1480.0, 840.0)
const MAX_SCALE := 1.15
## Lo que hace cada metal, bajo su nombre.
const METAL_TAGLINE := {
	&"steel": "Empuja objetos metálicos",
	&"iron": "Atrae objetos metálicos",
	&"pewter": "Refuerza el cuerpo",
}

var player: Player

var _root: Control
var _margin: MarginContainer  # todo el contenido: su tamaño mínimo dice si la ventana entra en la pantalla
var _level_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _points_label: Label
var _columns: HBoxContainer
var _detail: VBoxContainer
var _others: VBoxContainer
var _slots_row: HBoxContainer
var _side_col: VBoxContainer
var _detail_width := DETAIL_WIDTH
var _body: HBoxContainer
var _canvas: SkillTreeCanvas
## Ctrl apretado: se resaltan las habilidades que se pueden poner en una ranura y se apagan las demás.
var _assign_mode := false
## Vista de árbol (true) o de lista (false).
## shortcut: arranca en la lista porque los puntos por poder todavía solo se ponen ahí; vuelve a true con L4 (pips en el árbol).
var _tree_mode := false
var _selected: StringName = &"steel_light_push"
## Habilidad bajo el ratón: Ctrl + tecla pone esa; si no hay ninguna, la elegida.
var _hovered: StringName = &""
## Mensaje corto sobre la última asignación con Ctrl + tecla (qué pasó y por qué).
var _toast: Label
## Ranura cuya tecla se está cambiando (la próxima tecla que pulses), o -1.
var _rebinding := -1


func _ready() -> void:
	layer = 30
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_TOP_LEFT)  # el tamaño lo fija _fit_to_window (la capa se escala)
	get_viewport().size_changed.connect(_fit_to_window)
	_root.theme = HudKit.menu_theme()
	_root.visible = false
	add_child(_root)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = BG
	_root.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	_root.add_child(margin)
	_margin = margin
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	col.add_child(_build_header())
	col.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	col.add_child(body)
	_body = body
	_canvas = SkillTreeCanvas.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.skill_hovered.connect(func(id: StringName) -> void: _hovered = id)
	_canvas.skill_clicked.connect(func(id: StringName) -> void:
		_selected = id
		_refresh())
	_canvas.metal_clicked.connect(func(metal: StringName) -> void:
		if Progression.raise_metal(metal):
			_refresh())
	col.add_child(_canvas)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_columns = HBoxContainer.new()
	_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.add_theme_constant_override("separation", 14)
	scroll.add_child(_columns)

	# Barra para ensanchar o angostar el detalle arrastrando.
	var handle := ColResizeHandle.new()
	handle.dragged.connect(func(dx: float) -> void:
		_detail_width = clampf(_detail_width - dx, DETAIL_MIN, DETAIL_MAX)
		_side_col.custom_minimum_size.x = _detail_width)
	body.add_child(handle)
	var side_col := VBoxContainer.new()
	_side_col = side_col
	side_col.custom_minimum_size.x = _detail_width
	side_col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	side_col.add_theme_constant_override("separation", 12)
	body.add_child(side_col)
	var detail_panel := _panel(Color(0.06, 0.07, 0.09), Color(0.3, 0.3, 0.34), 16)
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_col.add_child(detail_panel)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 8)
	detail_panel.add_child(_detail)
	var others_panel := _panel(Color(0.06, 0.07, 0.09), Color(0.3, 0.3, 0.34), 14)
	side_col.add_child(others_panel)
	_others = VBoxContainer.new()
	_others.add_theme_constant_override("separation", 6)
	others_panel.add_child(_others)

	col.add_child(HSeparator.new())
	col.add_child(_build_footer())
	_set_mode(_tree_mode)
	_fit_to_window()


## La ventana se reduce entera en pantallas chicas (y crece un poco en las grandes) para que todo quepa sin cortarse.
func _fit_to_window() -> void:
	if _root == null:
		return
	var vp := _root.get_viewport_rect().size
	var s := clampf(minf(vp.x / DESIGN_SIZE.x, vp.y / DESIGN_SIZE.y), 0.5, MAX_SCALE)
	# Si lo que hay adentro (columnas, detalle, encabezado) pide más lugar del que queda a esa escala, se achica un poco
	# más: si no, en pantallas chicas se cortaba por la derecha.
	var need := _margin.get_combined_minimum_size()
	if need.x > 0.0 and need.y > 0.0:
		s = clampf(minf(s, minf(vp.x / need.x, vp.y / need.y)), 0.5, MAX_SCALE)
	scale = Vector2(s, s)
	_root.position = Vector2.ZERO
	_root.size = vp / s


func _set_mode(tree: bool) -> void:
	_tree_mode = tree
	_hovered = &""
	_body.visible = not tree
	_canvas.visible = tree
	if tree:
		_canvas.fit()


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 22)
	var title := Label.new()
	title.text = "Árbol de habilidades"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", GOLD_SOFT)
	header.add_child(title)
	var views := ButtonGroup.new()
	for tree_view: bool in [false, true]:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = views
		b.focus_mode = Control.FOCUS_NONE
		b.text = "Árbol" if tree_view else "Lista"
		b.button_pressed = tree_view == _tree_mode
		b.pressed.connect(func() -> void: _set_mode(tree_view))
		header.add_child(b)
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 22)
	header.add_child(_level_label)
	var xp_box := HBoxContainer.new()
	xp_box.add_theme_constant_override("separation", 10)
	var xp_title := Label.new()
	xp_title.text = "EXP"
	xp_title.modulate = DIM
	xp_box.add_child(xp_title)
	_xp_label = Label.new()
	xp_box.add_child(_xp_label)
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(240, 10)
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_box.add_child(_xp_bar)
	header.add_child(xp_box)
	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", 22)
	header.add_child(_points_label)
	var reset := Button.new()
	reset.text = "Devolver todos los puntos"
	reset.tooltip_text = "Vuelve al inicio recomendado: Empuje básico, Tirón básico y Moneda de combate."
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(func() -> void:
		Progression.respec()
		_refresh())
	header.add_child(reset)
	return header


func _build_footer() -> Control:
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 6)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	var slots_title := Label.new()
	slots_title.text = "RANURAS  ·  Ctrl + tecla con el ratón sobre una habilidad: la pone ahí  ·  clic: ver  ·  clic derecho: vaciar  ·  doble clic: cambiar la tecla"
	slots_title.add_theme_font_size_override("font_size", 13)
	slots_title.modulate = DIM
	slots_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(slots_title)
	var defaults := Button.new()
	defaults.text = "Ranuras por defecto"
	defaults.focus_mode = Control.FOCUS_NONE
	defaults.pressed.connect(func() -> void:
		Progression.reset_slots()
		Progression.save()
		_refresh())
	top.add_child(defaults)
	top.add_child(_chip("Activa", ACTIVE_COLOR))
	top.add_child(_chip("Pasiva", PASSIVE_COLOR))
	var hint := Label.new()
	hint.text = "K · Esc  cerrar"
	hint.modulate = DIM
	top.add_child(hint)
	footer.add_child(top)
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 14)
	_toast.custom_minimum_size.y = 20
	footer.add_child(_toast)
	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", 8)
	footer.add_child(_slots_row)
	return footer


# ---------------------------------------------------------------- Refresco

func _refresh() -> void:
	var free := Progression.points_free()
	_level_label.text = "Nivel %d" % Progression.level
	var need := Progression.xp_for_next(Progression.level)
	_xp_bar.max_value = need
	_xp_bar.value = Progression.xp
	_xp_label.text = "%s / %s" % [HudKit.thousands(Progression.xp), HudKit.thousands(need)]
	_points_label.text = "Puntos libres: %d" % free
	_points_label.add_theme_color_override("font_color", GOLD if free > 0 else DIM)
	if SkillTree.find(_selected).is_empty():
		_selected = &"steel_light_push"
	_clear(_columns)
	_clear(_others)
	_others.add_child(_heading("Otros metales"))
	for metal: StringName in Allomancy.METALS:
		if SkillTree.skills_of(metal).is_empty():
			_others.add_child(_other_metal_row(metal))
		else:
			_columns.add_child(_column(metal))
	_refresh_detail()
	_refresh_slots()
	_canvas.queue_redraw()


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


## Ranuras de los poderes básicos (Q y E por defecto): van al final, junto a la moneda de combate, como en el HUD del juego.
const BASIC_SLOTS: Array[int] = [4, 5]


func _refresh_slots() -> void:
	_clear(_slots_row)
	var order: Array[int] = []
	for i in Progression.SLOT_COUNT:
		if not i in BASIC_SLOTS:
			order.append(i)
	order.append(-1)  # separación antes de las básicas y la moneda
	order.append_array(BASIC_SLOTS)
	for i in order:
		if i < 0:
			var gap := Control.new()
			gap.custom_minimum_size.x = 18
			_slots_row.add_child(gap)
			continue
		var skill := Progression.slot_skills[i]
		var cap := SlotKey.new()
		cap.key_text = Progression.key_name(Progression.slot_keys[i])
		cap.skill = skill
		cap.rebinding = _rebinding == i
		cap.highlighted = skill != &"" and skill == _selected
		cap.tooltip_text = String(SkillTree.find(skill)["name"]) if skill != &"" else "Ranura vacía"
		cap.picked.connect(func() -> void:
			if skill != &"":
				_selected = skill
				_refresh())
		cap.cleared.connect(func() -> void:
			Progression.clear_slot(i)
			_refresh())
		cap.rebind_requested.connect(func() -> void:
			_rebinding = i
			_refresh_slots())
		_slots_row.add_child(cap)
	# La moneda de combate tiene su propia tecla (por defecto el clic derecho), al final, después de las básicas.
	var coin_id := &"steel_combat_coin"
	var coin_cap := SlotKey.new()
	coin_cap.key_text = Progression.key_name(Progression.coin_key)
	coin_cap.skill = coin_id if SkillTree.is_unlocked(coin_id) else &""
	coin_cap.rebinding = _rebinding == Progression.SLOT_COUNT
	coin_cap.highlighted = _selected == coin_id
	coin_cap.tooltip_text = "Moneda de combate" if coin_cap.skill != &"" else "Moneda de combate (se desbloquea con el acero)"
	coin_cap.picked.connect(func() -> void:
		_selected = coin_id
		_refresh())
	coin_cap.rebind_requested.connect(func() -> void:
		_rebinding = Progression.SLOT_COUNT
		_refresh_slots())
	_slots_row.add_child(coin_cap)


# ---------------------------------------------------------------- Columnas de metal

func _column(metal: StringName) -> Control:
	var color: Color = Allomancy.METALS[metal]["color"]
	var lvl := Progression.metal_level(metal)
	var panel := _panel(Color(0.055, 0.065, 0.085), Color(color, 0.4), 14)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var icon := SkillHex.new(24.0, 56.0)
	icon.metal = metal
	icon.locked = lvl <= 0
	head.add_child(icon)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_l := Label.new()
	name_l.text = String(Allomancy.METALS[metal]["label"]).to_upper()
	name_l.add_theme_font_size_override("font_size", 24)
	name_l.add_theme_color_override("font_color", GOLD_SOFT)
	names.add_child(name_l)
	var tag := Label.new()
	tag.text = METAL_TAGLINE.get(metal, "")
	tag.modulate = DIM
	names.add_child(tag)
	head.add_child(names)
	box.add_child(head)

	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 10)
	var level_l := Label.new()
	level_l.text = ("Nivel del metal: %d" % lvl) if lvl > 0 else "Sin aprender"
	level_l.tooltip_text = "Suma de los puntos en sus poderes. Con más nivel, el metal gasta menos y dura más."
	level_l.mouse_filter = Control.MOUSE_FILTER_PASS
	level_l.add_theme_color_override("font_color", color.lightened(0.3) if lvl > 0 else DIM)
	level_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_row.add_child(level_l)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	pad.add_child(level_row)
	box.add_child(pad)
	box.add_child(HSeparator.new())

	var skills := SkillTree.skills_of(metal)
	for i in skills.size():
		box.add_child(_skill_row(skills[i] as Dictionary, lvl, color, i > 0, i < skills.size() - 1))
	return panel


## Por qué no se puede poner un punto en el poder ("" = se puede).
func _raise_reason(id: StringName) -> String:
	if Progression.skill_level(id) >= SkillTree.max_level(id):
		return "Nivel máximo"
	var missing := PackedStringArray()
	for p in SkillTree.parents(id):
		if Progression.skill_level(p) < 1:
			missing.append(String(SkillTree.find(p)["name"]))
	if not missing.is_empty():
		return "Necesita: %s" % ", ".join(missing)
	if Progression.points_free() < SkillTree.skill_cost(id):
		return "Sin puntos libres: se gana uno por nivel"
	return "" if Progression.can_raise_skill(id) else "No se puede subir"


## Por qué no se puede sacar un punto del poder ("" = se puede).
func _lower_reason(id: StringName) -> String:
	if Progression.skill_level(id) <= 0:
		return "No tiene puntos"
	var blocker := Progression.lower_blocker(id)
	if blocker != &"":
		return "%s depende de este: bajalo primero" % SkillTree.find(blocker)["name"]
	return "" if Progression.can_lower_skill(id) else "No se puede bajar"


## "−  2/5  +" de un poder: cada botón, apagado con el motivo en el tooltip.
func _skill_buttons(id: StringName) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lvl := Progression.skill_level(id)
	for raise: bool in [false, true]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = "+" if raise else "−"
		b.custom_minimum_size = Vector2(28, 28)
		var why := _raise_reason(id) if raise else _lower_reason(id)
		b.disabled = why != ""
		b.tooltip_text = why if why != "" else ("Poner un punto" if raise else "Devolver un punto")
		b.pressed.connect(func() -> void:
			_selected = id
			var changed := Progression.raise_skill(id) if raise else Progression.lower_skill(id)
			if changed:
				_refresh())
		if raise:
			var count := Label.new()
			count.text = "%d/%d" % [lvl, SkillTree.max_level(id)]
			count.add_theme_color_override("font_color", GOLD if lvl > 0 else DIM)
			count.custom_minimum_size.x = 30
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(count)
		box.add_child(b)
	return box


## shortcut: "+" de los metales sin poderes (Otros metales); se va con L12.
func _raise_button(metal: StringName) -> Button:
	var lvl := Progression.metal_level(metal)
	var cost := Progression.point_cost(metal)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	if lvl >= Progression.metal_cap(metal):
		b.text = "Nivel máximo"
	else:
		b.text = "%s  (%d pt%s)" % ["Aprender" if lvl == 0 else "Subir nivel", cost, "" if cost == 1 else "s"]
	b.disabled = not Progression.can_raise(metal)
	b.pressed.connect(func() -> void:
		if Progression.raise_metal(metal):
			_refresh())
	return b


func _skill_row(s: Dictionary, lvl: int, color: Color, up: bool, down: bool) -> Control:
	var id: StringName = s["id"]
	var unlocked := SkillTree.is_unlocked(s["id"])
	var is_active: bool = s["kind"] == SkillTree.Kind.ACTIVE
	var row := PanelContainer.new()
	var selected := id == _selected
	row.add_theme_stylebox_override("panel", _box(Color(color, 0.14) if selected else Color(0, 0, 0, 0),
			Color(GOLD, 0.8) if selected else Color(0, 0, 0, 0), 1, 6, 4))
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if _assign_mode:
		if unlocked and SkillTree.is_assignable(id):
			row.add_theme_stylebox_override("panel", _box(Color(SkillTreeCanvas.ASSIGN, 0.05), Color(SkillTreeCanvas.ASSIGN, 0.35), 1, 6, 4))
		else:
			row.modulate = Color(1, 1, 1, 0.25)  # pasiva o bloqueada: no va en una ranura
	elif not unlocked:
		row.modulate = Color(0.62, 0.62, 0.66, 0.6)  # bloqueada por nivel o por puntos: se ve apagada
	row.mouse_entered.connect(func() -> void: _hovered = id)
	row.mouse_exited.connect(func() -> void:
		if _hovered == id:
			_hovered = &"")
	row.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_selected = id
			_refresh())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	var hex := SkillHex.new(26.0, 80.0)
	hex.metal = s["metal"]
	hex.skill = id
	hex.locked = not unlocked
	hex.selected = selected
	hex.line_up = up
	hex.line_down = down
	h.add_child(hex)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 1)
	var top := HBoxContainer.new()
	var level_l := Label.new()
	# El requisito que falta; si no falta nada, si ya tiene puntos.
	var need := String(SkillTree.tooltip_parts(id, 0).get("unlock", "")).trim_suffix(".")
	level_l.text = need if need != "" else ("Aprendida" if unlocked else "Sin puntos")
	level_l.add_theme_font_size_override("font_size", 12)
	level_l.add_theme_color_override("font_color", LOCKED if need != "" else (GOOD if unlocked else DIM))
	level_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(level_l)
	top.add_child(_chip("Activa" if is_active else "Pasiva", ACTIVE_COLOR if is_active else PASSIVE_COLOR))
	text.add_child(top)
	var name_l := Label.new()
	name_l.text = String(s["name"])
	name_l.add_theme_font_size_override("font_size", 17)
	name_l.add_theme_color_override("font_color", Color.WHITE if unlocked else Color(0.7, 0.72, 0.78))
	text.add_child(name_l)
	var desc := Label.new()
	desc.text = String(SkillTree.tooltip_parts(id, Progression.skill_level(id)).get("body", "")).split("\n")[0]
	desc.add_theme_font_size_override("font_size", 12)
	desc.modulate = DIM
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.max_lines_visible = 2
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc.custom_minimum_size.x = 120
	text.add_child(desc)
	h.add_child(text)
	_ignore_mouse(h)
	h.add_child(_skill_buttons(id))  # después de _ignore_mouse: los botones sí reciben el clic
	return row


## Los hijos de una fila no se quedan los clics: los recibe la fila entera.
func _ignore_mouse(node: Node) -> void:
	for c in node.get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(c)


# ---------------------------------------------------------------- Detalle y otros metales

func _refresh_detail() -> void:
	_clear(_detail)
	var s := SkillTree.find(_selected)
	var metal: StringName = s["metal"]
	var color: Color = Allomancy.METALS[metal]["color"]
	var lvl := Progression.metal_level(metal)
	var unlocked := SkillTree.is_unlocked(s["id"])
	var parts := SkillTree.tooltip_parts(_selected, Progression.skill_level(_selected))
	var kind := "Activa" if s["kind"] == SkillTree.Kind.ACTIVE else "Pasiva"
	var slot := Progression.slot_of(_selected)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var hex := SkillHex.new(30.0, 76.0)
	hex.metal = metal
	hex.skill = _selected
	hex.locked = not unlocked
	head.add_child(hex)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_l := Label.new()
	name_l.text = String(s["name"])
	name_l.add_theme_font_size_override("font_size", 26)
	name_l.add_theme_color_override("font_color", GOLD_SOFT)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size.x = 100
	names.add_child(name_l)
	var sub := Label.new()
	sub.text = "Nivel %d/%d · %s · %s" % [Progression.skill_level(_selected), SkillTree.max_level(_selected), kind, Allomancy.METALS[metal]["label"]]
	sub.modulate = color.lightened(0.3)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size.x = 100
	names.add_child(sub)
	head.add_child(names)
	if _selected in SkillTree.FIXED_KEY:
		head.add_child(_chip(Progression.key_name(Progression.coin_key), GOLD))
	elif slot >= 0:
		head.add_child(_chip(Progression.key_name(Progression.slot_keys[slot]), GOLD))
	_detail.add_child(head)
	_detail.add_child(HSeparator.new())

	# La descripción va en su propio scroll y ocupa solo lo que sobra: si no, una larga agranda la ventana y tapa las
	# ranuras de abajo. El encabezado y los botones quedan siempre a la vista.
	var text_scroll := ScrollContainer.new()
	text_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail.add_child(text_scroll)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 8)
	text_scroll.add_child(text)
	for paragraph in String(parts.get("body", "")).split("\n"):
		if paragraph != "":
			text.add_child(_wrapped(paragraph, 15, Color(0.86, 0.88, 0.92)))
	var now := String(parts.get("now", ""))
	if now != "":
		text.add_child(_wrapped(now, 15, GOOD))
	var unlock := String(parts.get("unlock", ""))
	if unlock != "":
		text.add_child(_wrapped(unlock, 15, LOCKED))
	if _selected in SkillTree.FIXED_KEY:
		_detail.add_child(_wrapped("Tiene su propia tecla (por defecto el clic derecho).", 14, DIM))
		if unlocked:
			var change := Button.new()
			change.focus_mode = Control.FOCUS_NONE
			change.text = "Cambiar tecla"
			change.pressed.connect(func() -> void:
				_rebinding = Progression.SLOT_COUNT
				_refresh_slots())
			_detail.add_child(change)
	elif unlocked and SkillTree.is_assignable(_selected):
		_detail.add_child(_wrapped("Ctrl + la tecla de una ranura, con el ratón sobre la habilidad: la pone ahí.", 14, GOLD_SOFT))
		if slot >= 0:
			var buttons := HBoxContainer.new()
			buttons.add_theme_constant_override("separation", 8)
			var remove := Button.new()
			remove.focus_mode = Control.FOCUS_NONE
			remove.text = "Quitar de la ranura"
			remove.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			remove.pressed.connect(func() -> void:
				Progression.clear_slot(slot)
				_refresh())
			buttons.add_child(remove)
			var rebind := Button.new()
			rebind.focus_mode = Control.FOCUS_NONE
			rebind.text = "Cambiar tecla"
			rebind.pressed.connect(func() -> void:
				_rebinding = slot
				_refresh_slots())
			buttons.add_child(rebind)
			_detail.add_child(buttons)


func _other_metal_row(metal: StringName) -> Control:
	var color: Color = Allomancy.METALS[metal]["color"]
	var lvl := Progression.metal_level(metal)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon := SkillHex.new(13.0, 30.0)
	icon.metal = metal
	icon.locked = lvl <= 0
	row.add_child(icon)
	var name_l := Label.new()
	name_l.text = Allomancy.METALS[metal]["label"]
	name_l.add_theme_color_override("font_color", color.lightened(0.2) if lvl > 0 else DIM)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_l)
	var lvl_l := Label.new()
	lvl_l.text = ("Nivel %d" % lvl) if lvl > 0 else "Bloqueado"
	lvl_l.modulate = DIM
	lvl_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lvl_l)
	var raise := _raise_button(metal)
	raise.text = "+" if lvl > 0 else "Aprender"
	raise.tooltip_text = "%d punto%s de alomancia" % [Progression.point_cost(metal), "" if Progression.point_cost(metal) == 1 else "s"]
	row.add_child(raise)
	return row


# ---------------------------------------------------------------- Piezas

func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", GOLD_SOFT)
	return l


func _wrapped(t: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 100
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Etiqueta pequeña con borde (Activa, Pasiva, la tecla de la ranura).
func _chip(text: String, color: Color) -> Control:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", _box(Color(color, 0.22), color, 1, 4, 0, 6, 2))
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", color.lightened(0.45))
	chip.add_child(l)
	return chip


func _panel(bg: Color, border: Color, margin: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(bg, border, 1, 8, margin))
	return p


func _box(bg: Color, border: Color, border_width: int, radius: int, margin: int, margin_h := -1, margin_v := -1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin if margin_h < 0 else margin_h
	s.content_margin_right = margin if margin_h < 0 else margin_h
	s.content_margin_top = margin if margin_v < 0 else margin_v
	s.content_margin_bottom = margin if margin_v < 0 else margin_v
	return s


# ---------------------------------------------------------------- Entrada

func _process(_delta: float) -> void:
	var held := _root != null and _root.visible and Input.is_key_pressed(KEY_CTRL)
	if held == _assign_mode:
		return
	_assign_mode = held
	_canvas.assign_mode = held
	_canvas.queue_redraw()
	if not _tree_mode:
		_refresh()


## Cambiando la tecla de una ranura: la próxima tecla que pulses (Esc cancela).
func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	var coin_slot := _rebinding == Progression.SLOT_COUNT
	# Cambiando la tecla de la moneda de combate también vale un botón del ratón (menos el izquierdo).
	if coin_slot and event is InputEventMouseButton and event.pressed and event.button_index != MOUSE_BUTTON_LEFT \
			and event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
		Progression.rebind_coin(-event.button_index)
		_rebinding = -1
		_refresh()
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _rebinding < 0:
		# Ctrl + la tecla de una ranura: pone ahí la habilidad bajo el ratón (o, si no hay, la elegida).
		if event.ctrl_pressed and event.keycode != KEY_CTRL:
			_assign_with_key(event.physical_keycode)
			get_viewport().set_input_as_handled()
		return
	if event.keycode != KEY_ESCAPE:
		if coin_slot:
			Progression.rebind_coin(event.physical_keycode)
		else:
			Progression.rebind_slot(_rebinding, event.physical_keycode)
	_rebinding = -1
	_refresh()
	get_viewport().set_input_as_handled()


## Ctrl + tecla: pone en la ranura de esa tecla la habilidad bajo el ratón (en la vista de árbol se mira justo donde está el
## puntero) o, si no hay ninguna, la que tengas elegida. Dice en pantalla qué pasó.
func _assign_with_key(code: int) -> void:
	var slot := Progression.slot_keys.find(code)
	if slot < 0:
		_say("%s no es la tecla de ninguna ranura" % Progression.key_name(code), LOCKED)
		return
	var skill := _canvas.skill_under_mouse() if _tree_mode else _hovered
	if skill == &"":
		skill = _selected
	var info := SkillTree.find(skill)
	if info.is_empty():
		_say("Pasa el ratón por una habilidad y pulsa Ctrl + tecla", LOCKED)
		return
	var skill_name := String(info["name"])
	if skill in SkillTree.FIXED_KEY:
		_say("%s tiene su propia tecla: doble clic en la tecla RMB de abajo" % skill_name, LOCKED)
	elif not SkillTree.is_unlocked(skill):
		_say("%s todavía no tiene puntos: subila con +" % skill_name, LOCKED)
	elif not SkillTree.is_assignable(skill):
		_say("%s es pasiva: funciona sola y no va en una ranura" % skill_name, LOCKED)
	else:
		Progression.assign_to_slot(skill, slot)
		_selected = skill
		_refresh()
		_say("%s → ranura %s" % [skill_name, Progression.key_name(code)], GOOD)


func _say(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	get_tree().create_timer(3.0, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(_toast) and _toast.text == text:
			_toast.text = "")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"skill_tree") or (_root.visible and event is InputEventKey \
			and event.pressed and event.keycode == KEY_ESCAPE):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if not _root.visible and player.ui_open:
		return  # hay otra ventana abierta
	_fit_to_window()
	_root.visible = not _root.visible
	player.ui_open = _root.visible
	_refresh()
	_fit_to_window.call_deferred()  # con el contenido ya armado se sabe cuánto lugar pide
	if _root.visible and _tree_mode:
		_canvas.fit()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _root.visible else Input.MOUSE_MODE_CAPTURED
