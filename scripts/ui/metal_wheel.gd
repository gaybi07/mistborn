class_name MetalWheel
extends Control
## Rueda de metales: mantén Tab, mueve el ratón hacia un metal y suelta Tab para encenderlo o
## apagarlo. Clic izquierdo mientras está abierta:
## avivar / dejar de avivar el elegido. Mientras está abierta el ratón no mueve la cámara.

const RADIUS := 150.0
const INNER := 45.0

var player: Player

var _open := false
var _aim := Vector2.ZERO
var _selected := -1
var _metals: Array = []


func _ready() -> void:
	_metals = Allomancy.METALS.keys()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"metal_wheel") and not player.ui_open and not player.dead:
		_open = true
		_aim = Vector2.ZERO
		_selected = -1
		player.ui_open = true
		visible = true
	elif event.is_action_released(&"metal_wheel") and _open:
		_open = false
		player.ui_open = false
		visible = false
		if _selected >= 0 and not (_metals[_selected] == &"pewter" and player.pewter_drag() > 0.0):
			player.allomancy.toggle_burn(_metals[_selected])
	elif _open and event is InputEventMouseMotion:
		_aim = (_aim + (event as InputEventMouseMotion).relative).limit_length(RADIUS)
		if _aim.length() > INNER * 0.6:
			var step := TAU / _metals.size()
			_selected = int(round(fposmod(_aim.angle() + PI / 2, TAU) / step)) % _metals.size()
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif _open and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _selected >= 0:
			var m: StringName = _metals[_selected]
			player.allomancy.set_state(m, Allomancy.State.BURN if player.allomancy.is_flaring(m) else Allomancy.State.FLARE)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _open:
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var font := get_theme_default_font()
	draw_circle(c, RADIUS + 40.0, Color(0, 0, 0, 0.45))
	var step := TAU / _metals.size()
	for i in _metals.size():
		var m: StringName = _metals[i]
		var info: Dictionary = Allomancy.METALS[m]
		var dir := Vector2.from_angle(i * step - PI / 2)
		var p := c + dir * RADIUS
		var a := player.allomancy
		var col: Color = info["color"]
		var r := 26.0 if i == _selected else 20.0
		draw_circle(p, r, col.darkened(0.45) if a.is_burning(m) else col.darkened(0.8))
		MetalGlyph.draw(self, m, p, r * 0.75, col.lightened(0.4) if a.is_burning(m) else col.darkened(0.2), 2.0)
		if a.is_flaring(m):
			draw_arc(p, r + 5.0, 0.0, TAU, 32, Color(1.0, 0.6, 0.3), 3.0)
		if i == _selected:
			draw_arc(p, r + 9.0, 0.0, TAU, 32, Color.WHITE, 2.0)
		var label: String = info["label"]
		var reserve := "%d%%" % int(100.0 * a.reserve[m] / info["max"])
		draw_string(font, p + Vector2(-60, r + 18), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 15)
		draw_string(font, p + Vector2(-60, r + 34), reserve, HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(1, 1, 1, 0.6))
	draw_string(font, c + Vector2(-90, -2), "Soltá Tab: encender/apagar", HORIZONTAL_ALIGNMENT_CENTER, 180, 13)
	draw_string(font, c + Vector2(-90, 16), "Clic: avivar", HORIZONTAL_ALIGNMENT_CENTER, 180, 13)
	if _aim.length() > 1.0:
		draw_line(c, c + _aim * 0.5, Color(1, 1, 1, 0.5), 2.0)
