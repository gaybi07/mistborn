class_name HeroChooser
extends VBoxContainer
## Elegir personaje (Art.HEROES) y el color de su capa (Art.SUITS). Lo usan SuitPicker (P) y el menú de Esc.

const NAMES := {"negro": "Negro", "blanco": "Blanco", "rojo": "Rojo", "azul": "Azul"}

var player: Player
var show_keys := false  # numera los botones (las teclas de SuitPicker)

var _hero_buttons := {}


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var heroes := HBoxContainer.new()
	heroes.alignment = BoxContainer.ALIGNMENT_CENTER
	heroes.add_theme_constant_override("separation", 12)
	add_child(heroes)
	var k := 0
	for who: String in Art.HEROES:
		k += 1
		var b := Button.new()
		b.toggle_mode = true
		b.theme_type_variation = &"CardButton"  # recta: la foto tiene fondo
		b.custom_minimum_size = Vector2(210, 260)
		b.text = _label(k, Art.HEROES[who]["name"])
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon = true
		b.icon = load(Art.HEROES[who]["portrait"])
		b.pressed.connect(choose_hero.bind(who))
		heroes.add_child(b)
		_hero_buttons[who] = b

	var cape := Label.new()
	cape.text = "Color de la capa"
	add_child(cape)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	for s: String in Art.SUITS:
		k += 1
		var b := Button.new()
		b.theme_type_variation = &"CardButton"
		b.custom_minimum_size = Vector2(120, 110)
		b.text = _label(k, NAMES[s])
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.icon = _swatch(Art.SUITS[s])
		b.pressed.connect(choose_suit.bind(s))
		row.add_child(b)
	# El otro menú puede haber cambiado de personaje mientras este estaba oculto.
	visibility_changed.connect(_mark_hero)
	_mark_hero()


func _label(k: int, text: String) -> String:
	return "%d · %s" % [k, text] if show_keys else text


func _swatch(c: Color) -> Texture2D:
	var img := Image.create(60, 60, false, Image.FORMAT_RGB8)
	img.fill(c)
	return ImageTexture.create_from_image(img)


func choose_hero(who: String) -> void:
	if who != Art.player_model:
		player.change_character(who)
	_mark_hero()


func _mark_hero() -> void:
	for who: String in _hero_buttons:
		_hero_buttons[who].set_pressed_no_signal(who == Art.player_model)


func choose_suit(s: String) -> void:
	Art.save_suit(s)
	player.rig.set_suit(s)
