class_name StartScreen
extends Control
## Pantalla de inicio: las tres partidas (SaveSlots) con personaje, misión, nivel y fecha. Continuar, empezar una nueva o
## borrarla. Sale al abrir el juego (la ciudad sigue atrás, con el jugador quieto) y desde Esc → Partidas.

var player: Player
var _list: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = HudKit.menu_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.03, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.custom_minimum_size.x = 620
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	var title := Label.new()
	title.text = "MISTBORN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", HudKit.GOLD_LIGHT)
	col.add_child(title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	col.add_child(_list)
	if SaveSlots.current == 0:
		open.call_deferred()


func open() -> void:
	visible = true
	if player:
		player.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func _close() -> void:
	visible = false
	if player:
		player.ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	for slot in range(1, SaveSlots.COUNT + 1):
		var panel := PanelContainer.new()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		panel.add_child(row)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var s := SaveSlots.summary(slot)
		var here := " (en juego)" if slot == SaveSlots.current else ""
		if s.is_empty():
			info.text = "Partida %d%s\nVacía" % [slot, here]
		else:
			info.text = "Partida %d%s · %s, nivel %d\n%s · %s" % [slot, here, s.get("hero", "?"), int(s.get("level", 1)),
					s.get("quest", "") if s.get("quest", "") != "" else "Sin misión elegida", String(s.get("date", "")).substr(0, 16)]
		row.add_child(info)
		var play := Button.new()
		play.text = "Nueva" if s.is_empty() else ("Seguir" if slot == SaveSlots.current else "Cargar")
		play.pressed.connect(func() -> void:
			if slot == SaveSlots.current:
				_close()
			else:
				SaveSlots.play(slot))
		row.add_child(play)
		if not s.is_empty():
			var erase := Button.new()
			erase.text = "Borrar"
			erase.pressed.connect(func() -> void:
				if erase.text == "Borrar":
					erase.text = "¿Seguro?"
					return
				SaveSlots.erase(slot)
				if SaveSlots.current == 0:
					open()
				_refresh())
			row.add_child(erase)
		_list.add_child(panel)
	if SaveSlots.current != 0:
		var back := Button.new()
		back.text = "Volver al juego"
		back.pressed.connect(_close)
		_list.add_child(back)
	else:
		var hint := Label.new()
		hint.text = "Elegí una partida para empezar. Se guarda sola al terminar cada misión y al salir."
		hint.modulate.a = 0.6
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if visible and SaveSlots.current != 0 and event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
