class_name DialogueBox
extends Control
## Caja de conversación abajo de la pantalla: nombre, texto y opciones (clic o teclas 1-4). Las conversaciones están en
## Dialogues.LINES. Mientras está abierta, el jugador no se mueve ni ataca (Player.ui_open) y el cursor queda libre.

var player: Player
var _npc := ""
var _name: Label
var _text: Label
var _options: VBoxContainer


## Abre la conversación con ese NPC (clave de Story.NPCS), si tiene algo que decir.
static func open(tree: SceneTree, npc: String) -> void:
	var box := tree.get_first_node_in_group(&"dialogue_box") as DialogueBox
	if box and not box.player.ui_open:
		box._start(npc)


func _ready() -> void:
	add_to_group(&"dialogue_box")
	theme = HudKit.menu_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size.x = 760
	panel.offset_bottom = -170  # arriba de la barra de habilidades
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	_name = Label.new()
	_name.add_theme_color_override("font_color", HudKit.GOLD_LIGHT)
	_name.add_theme_font_size_override("font_size", 22)
	col.add_child(_name)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 720
	_text.add_theme_font_size_override("font_size", 19)
	col.add_child(_text)
	_options = VBoxContainer.new()
	col.add_child(_options)


func _start(npc: String) -> void:
	var node := Dialogues.entry(npc)
	if node == "":
		return
	_npc = npc
	_name.text = String(Story.NPCS.get(npc, Dialogues.LINES[npc]).get("name", npc))
	visible = true
	player.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show(node)


func _show(node: String) -> void:
	var data: Dictionary = Dialogues.LINES[_npc]["nodes"].get(node, {})
	if data.is_empty():
		_close()
		return
	_text.text = data["text"]
	for c in _options.get_children():
		c.queue_free()
	var opts: Array = (data.get("options", []) as Array).filter(func(o: Dictionary) -> bool: return Dialogues.check(o.get("if", {})))
	if opts.is_empty():
		opts = [{"text": "(Seguir)"}]
	for i in opts.size():
		var o: Dictionary = opts[i]
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, o["text"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_choose.bind(o))
		_options.add_child(b)


func _choose(o: Dictionary) -> void:
	Dialogues.run(o.get("do", []))
	if String(o.get("to", "")) == "":
		_close()
	else:
		_show(o["to"])


func _close() -> void:
	visible = false
	player.ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = (event as InputEventKey).keycode
	if k == KEY_ESCAPE:
		_close()
	elif k >= KEY_1 and k <= KEY_9:
		var i := k - KEY_1
		var buttons := _options.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())
		if i < buttons.size():
			(buttons[i] as Button).pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()
