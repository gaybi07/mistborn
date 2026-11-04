class_name SuitPicker
extends CanvasLayer
## Ventana para elegir personaje (ver HeroChooser). Sale sola la primera vez que se juega y con P en cualquier momento (pausa
## el juego). Teclas 1 a 4 para el personaje, 5 a 8 para el color, Enter o Jugar para seguir; Esc cierra.

var player: Player

var _root: Control
var _chooser: HeroChooser
## La primera vez no se cierra con Esc: hay que tocar Jugar.
var _must_choose := false


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.065, 0.085, 0.96)
	style.border_color = Color(0.4, 0.42, 0.5, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Elegí tu personaje"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Lo podés cambiar cuando quieras con P o en el menú de Esc."
	box.add_child(hint)

	_chooser = HeroChooser.new()
	_chooser.player = player
	_chooser.show_keys = true
	box.add_child(_chooser)

	var play := Button.new()
	play.text = "Jugar"
	play.custom_minimum_size = Vector2(0, 44)
	play.pressed.connect(close)
	box.add_child(play)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not _root.visible:
		if event.keycode == KEY_P and not player.ui_open:
			open()
			get_viewport().set_input_as_handled()
		return
	var hero_keys := [KEY_1, KEY_2, KEY_3, KEY_4]
	var suit_keys := [KEY_5, KEY_6, KEY_7, KEY_8]
	if hero_keys.find(event.keycode) in range(Art.HEROES.size()):
		_chooser.choose_hero(Art.HEROES.keys()[hero_keys.find(event.keycode)])
	elif event.keycode in suit_keys:
		_chooser.choose_suit(Art.SUITS.keys()[suit_keys.find(event.keycode)])
	elif event.keycode == KEY_ENTER or (event.keycode == KEY_ESCAPE and not _must_choose):
		close()
	get_viewport().set_input_as_handled()


func open(first := false) -> void:
	_must_choose = first
	_root.visible = true
	player.ui_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if _must_choose:
		Art.save_character(Art.player_model)  # aunque se quede con el de siempre, ya no vuelve a preguntar
	_root.visible = false
	player.ui_open = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
