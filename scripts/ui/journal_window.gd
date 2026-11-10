class_name JournalWindow
extends Control
## Cuaderno (tecla J): Pendiente (misiones en curso, con su paso; la que elijas va a la brújula), Lo que sé (rumores y
## datos) y Lo que pasó (lo que fue pasando, lo último arriba). Lee QuestLog y se rehace cuando cambia.

var player: Player
var _tabs: TabContainer
var _pending: VBoxContainer
var _known: VBoxContainer
var _past: VBoxContainer
var _seen := -1


func _ready() -> void:
	theme = HudKit.menu_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(760, 520)
	add_child(panel)
	var col := VBoxContainer.new()
	panel.add_child(col)
	var head := Label.new()
	head.text = "Cuaderno"
	head.add_theme_font_size_override("font_size", 26)
	head.add_theme_color_override("font_color", HudKit.GOLD_LIGHT)
	col.add_child(head)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_tabs)
	_pending = _page("Pendiente")
	_known = _page("Lo que sé")
	_past = _page("Lo que pasó")
	var hint := Label.new()
	hint.text = "J o Esc: cerrar"
	hint.modulate.a = 0.6
	col.add_child(hint)


func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	return box


func _process(_delta: float) -> void:
	if visible and _seen != QuestLog.revision:
		_refresh()


func _refresh() -> void:
	_seen = QuestLog.revision
	for box in [_pending, _known, _past]:
		for c in box.get_children():
			c.queue_free()
	var offers := QuestLog.offers()
	if QuestLog.active.is_empty() and offers.is_empty():
		_pending.add_child(_line("Nada pendiente por ahora.", 0.6))
	for o: Dictionary in offers:
		var place: String = CityPlan.district(o["xz"])["name"] if CityPlan.inside(o["xz"]) else "fuera de la muralla"
		_pending.add_child(_line("%s (%s) tiene algo para vos. Está marcado en el mapa." % [Story.NPCS[o["giver"]]["name"], place], 0.85))
	for id: String in QuestLog.active:
		var row := HBoxContainer.new()
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := _line(("★ " if id == QuestLog.tracked else "") + QuestLog.title(id), 1.0)
		t.add_theme_color_override("font_color", HudKit.GOLD_LIGHT)
		text.add_child(t)
		text.add_child(_line(QuestLog.step_text(id), 0.85))
		row.add_child(text)
		var follow := Button.new()
		follow.text = "Siguiendo" if id == QuestLog.tracked else "Seguir"
		follow.disabled = id == QuestLog.tracked
		follow.pressed.connect(func() -> void:
			QuestLog.tracked = id
			QuestLog.revision += 1)
		row.add_child(follow)
		_pending.add_child(row)
	if QuestLog.known.is_empty():
		_known.add_child(_line("Todavía no sabés nada que valga la pena anotar.", 0.6))
	for k: String in QuestLog.known:
		_known.add_child(_line("· " + k, 1.0))
	if QuestLog.history.is_empty():
		_past.add_child(_line("Todavía no pasó nada.", 0.6))
	for i in range(QuestLog.history.size() - 1, -1, -1):
		var h: Array = QuestLog.history[i]
		_past.add_child(_line("%s  ·  %s" % [String(h[0]).substr(0, 16), h[1]], 1.0))


func _line(text: String, alpha: float) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate.a = alpha
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"journal") or (visible and event is InputEventKey and event.pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if not visible and player.ui_open:
		return  # hay otra ventana abierta
	visible = not visible
	player.ui_open = visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED
	if visible:
		_refresh()
