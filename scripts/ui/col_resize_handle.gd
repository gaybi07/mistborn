class_name ColResizeHandle
extends Control
## Barra vertical fina entre dos columnas para cambiar su ancho arrastrándola con el ratón (cursor de redimensionado horizontal,
## el «col-resize» de la web). Avisa con `dragged` cuánto se movió (px, hacia la derecha es positivo).

signal dragged(delta_x: float)

const GOLD := Color(0.78, 0.66, 1.0)  # elegido, teclas y realces: el violeta de los menús (HudKit.PICK, más claro)

var _dragging := false
var _hover := false


func _init() -> void:
	custom_minimum_size = Vector2(12.0, 0.0)
	mouse_default_cursor_shape = Control.CURSOR_HSIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		queue_redraw()
	elif event is InputEventMouseMotion and _dragging:
		dragged.emit(event.relative.x)


func _draw() -> void:
	var x := size.x * 0.5
	var active := _hover or _dragging
	draw_line(Vector2(x, 4.0), Vector2(x, size.y - 4.0), Color(GOLD, 0.7 if active else 0.18), 2.0, true)
	if active:
		for k in 3:
			draw_circle(Vector2(x, size.y * 0.5 + (k - 1) * 9.0), 2.0, Color(GOLD, 0.9))
