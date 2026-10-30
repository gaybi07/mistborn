class_name CityMap
extends CanvasLayer
## Mapa de Luthadel. Al cargar la ciudad se saca una foto cenital de la ciudad entera (cámara
## ortogonal, sin bruma y con luz para que se lea) y con ella:
##  - minimapa en la esquina superior derecha, siempre visible: la zona alrededor del jugador,
##    con el norte arriba, una flecha que mira hacia donde mira el jugador y el nombre del barrio;
##  - mapa grande con la tecla M: la ciudad entera con los nombres de distritos, casas, cuarteles
##    y puertas, y dónde estás. Rueda del ratón: zoom hacia el cursor; arrastrar: mover. Los
##    carteles no se pisan: si dos chocan queda el más importante, y al acercarte aparecen los demás.
##    Se cierra con M o Esc; el juego sigue mientras tanto.

const MAP_CENTER := Vector2(-8, -19)  ## centro de la foto (XZ)
const MAP_SIZE := 1000.0  ## lado de la foto en metros
const MAP_PX := 2048
const MINI_SIZE := 220.0  ## lado del minimapa en píxeles de pantalla
const MINI_METERS := 180.0  ## metros que abarca el minimapa
const MAX_ZOOM := 6.0
const INK := Color(0.16, 0.11, 0.07)
const PAPER := Color(0.86, 0.79, 0.64)

## Pergamino: tono sepia, contraste suave y bordes oscurecidos (como el plano de referencia).
const PARCHMENT_SHADER := """
shader_type canvas_item;
uniform float vignette = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 sepia = vec3(g) * vec3(1.18, 1.0, 0.78);
	vec3 col = mix(c.rgb, sepia, 0.45) * 1.25 + vec3(0.04, 0.03, 0.01);
	float d = length(UV - 0.5);
	col *= mix(1.0, smoothstep(0.75, 0.35, d), 0.55 * vignette);
	COLOR = vec4(col, c.a);
}
"""

var player: Player

var _tex: Texture2D
var _mini: Panel
var _mini_map: TextureRect
var _mini_label: Label
var _big: Control
var _big_map: TextureRect
var _big_marker: Control
var _mini_marker: Control
var _view: Control  ## recorta el mapa grande al marco
var _tags: Array[Label] = []  ## en orden de importancia
var _tag_pos: Array[Vector2] = []
var _side := 0.0
var _zoom := 1.0
var _dragging := false
## La foto de la ciudad se saca una sola vez (al volver por una puerta se reusa).
static var _cached_tex: Texture2D


func _ready() -> void:
	layer = 9
	if _cached_tex == null:
		_cached_tex = await _capture()
	_tex = _cached_tex
	_build_minimap()
	_build_big_map()


## Foto cenital de la ciudad: una SubViewport con cámara ortogonal sobre el mismo mundo 3D, con su
## propio Environment (sin bruma, luz ambiente cálida). Se hace una vez y se libera.
func _capture() -> Texture2D:
	for i in 3:
		await get_tree().process_frame
	var sub := SubViewport.new()
	sub.size = Vector2i(MAP_PX, MAP_PX)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = MAP_SIZE
	cam.far = 2000.0
	cam.position = Vector3(MAP_CENTER.x, 900.0, MAP_CENTER.y)
	cam.rotation_degrees = Vector3(-90, 0, 0)  # mirando abajo, con el norte (-Z) arriba
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.09, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.84, 0.74)
	env.ambient_light_energy = 1.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	cam.environment = env
	sub.add_child(cam)
	add_child(sub)
	cam.make_current()
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := sub.get_texture().get_image()
	sub.queue_free()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Posición en la foto (0..1) de un punto del mundo (XZ).
func _uv(p: Vector2) -> Vector2:
	return (p - MAP_CENTER) / MAP_SIZE + Vector2(0.5, 0.5)


func _player_xz() -> Vector2:
	return Vector2(player.global_position.x, player.global_position.z)


func _parchment() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = PARCHMENT_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat


func _frame_style(border: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.07, 0.06)
	s.border_color = Color(0.55, 0.42, 0.22)
	s.set_border_width_all(border)
	s.set_corner_radius_all(4)
	return s


# ---------------------------------------------------------------- Minimapa

func _build_minimap() -> void:
	_mini = Panel.new()
	_mini.add_theme_stylebox_override("panel", _frame_style(3))
	_mini.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mini.offset_left = -MINI_SIZE - 16
	_mini.offset_right = -16
	_mini.offset_top = 16
	_mini.offset_bottom = 16 + MINI_SIZE
	_mini.clip_contents = true
	_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mini)
	_mini_map = TextureRect.new()
	_mini_map.texture = _tex
	var flat := _parchment()
	flat.set_shader_parameter(&"vignette", 0.0)
	_mini_map.material = flat
	_mini_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mini_map.stretch_mode = TextureRect.STRETCH_SCALE
	_mini_map.size = Vector2.ONE * MINI_SIZE * MAP_SIZE / MINI_METERS
	_mini_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini.add_child(_mini_map)
	_mini_marker = _marker(13.0)
	_mini_marker.position = Vector2.ONE * MINI_SIZE / 2.0
	_mini.add_child(_mini_marker)
	var north := _text("N", 14, PAPER)
	north.position = Vector2(MINI_SIZE / 2.0 - 5, 4)
	_mini.add_child(north)
	_mini_label = _text("", 13, PAPER)
	_mini_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mini_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mini_label.offset_left = -MINI_SIZE - 16
	_mini_label.offset_right = -16
	_mini_label.offset_top = MINI_SIZE + 20
	_mini_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_mini_label.add_theme_constant_override("outline_size", 5)
	add_child(_mini_label)


## Flecha del jugador (apunta hacia arriba sin girar).
func _marker(size: float) -> Control:
	var m := Control.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.draw.connect(func() -> void:
		var pts := PackedVector2Array([Vector2(0, -size), Vector2(size * 0.62, size * 0.7), Vector2(0, size * 0.3), Vector2(-size * 0.62, size * 0.7)])
		m.draw_colored_polygon(pts, Color(0.85, 0.12, 0.08))
		m.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 0.93, 0.8), 2.0, true))
	return m


func _text(t: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _process(_delta: float) -> void:
	if _mini == null or not is_instance_valid(player):
		return
	var p := _player_xz()
	var yaw := player.yaw_pivot.global_rotation.y
	_mini_map.position = Vector2.ONE * MINI_SIZE / 2.0 - _uv(p) * _mini_map.size
	_mini_marker.rotation = -yaw
	_mini_label.text = CityPlan.district(p)["name"] if CityPlan.inside(p) else "Fuera de la muralla"
	if _big.visible:
		_big_marker.position = _big_map.position + _uv(p) * _big_map.size
		_big_marker.rotation = -yaw


# ---------------------------------------------------------------- Mapa grande (M)

func _build_big_map() -> void:
	var top := CanvasLayer.new()
	top.layer = 30  # por encima de la barra de metales y vida
	add_child(top)
	_big = Control.new()
	_big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_big.visible = false
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_big)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.add_child(dim)
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", _frame_style(6))
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.add_child(frame)
	# Tamaño: un cuadrado que entre en la pantalla.
	var screen := get_viewport().get_visible_rect().size
	_side = minf(screen.y - 40.0, screen.x - 40.0)
	frame.offset_left = -_side / 2.0 - 6
	frame.offset_right = _side / 2.0 + 6
	frame.offset_top = -_side / 2.0 - 6
	frame.offset_bottom = _side / 2.0 + 6
	_view = Control.new()
	_view.position = Vector2(6, 6)
	_view.size = Vector2(_side, _side)
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.gui_input.connect(_on_map_input)
	frame.add_child(_view)
	_big_map = TextureRect.new()
	_big_map.texture = _tex
	_big_map.material = _parchment()
	_big_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_big_map.stretch_mode = TextureRect.STRETCH_SCALE
	_big_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(_big_map)
	for l in _place_names():
		_tag(l[0], l[1], l[2])
	_big_marker = _marker(14.0)
	_view.add_child(_big_marker)
	# Título, norte y ayuda quedan fijos sobre el marco.
	var title := _text("LUTHADEL", 30, PAPER)
	title.position = Vector2(_side / 2.0 - 70, 10)
	var north := _text("N ↑", 22, PAPER)
	north.position = Vector2(18, 12)
	var hint := _text("Rueda: zoom · Arrastrar: mover · M o Esc: cerrar", 14, PAPER)
	hint.position = Vector2(_side - 360, _side - 26)
	for t: Label in [title, north, hint]:
		t.add_theme_color_override("font_outline_color", INK)
		t.add_theme_constant_override("outline_size", 6)
		_view.add_child(t)
	_set_view(1.0, Vector2.ZERO)


## Zoom (1 = la ciudad entera) y desplazamiento del mapa dentro del marco (sin dejar huecos).
func _set_view(zoom: float, offset: Vector2) -> void:
	_zoom = clampf(zoom, 1.0, MAX_ZOOM)
	_big_map.size = Vector2.ONE * _side * _zoom
	_big_map.position = offset.clamp(Vector2.ONE * (_side - _big_map.size.x), Vector2.ZERO)
	_layout_tags()


## Coloca los carteles y oculta los que pisarían a uno más importante (o se salen del marco).
func _layout_tags() -> void:
	var placed: Array[Rect2] = []
	for i in _tags.size():
		var l := _tags[i]
		l.position = _big_map.position + _uv(_tag_pos[i]) * _big_map.size - l.size / 2.0
		var rect := Rect2(l.position, l.size).grow(3.0)
		var fits := Rect2(Vector2.ZERO, Vector2.ONE * _side).encloses(rect)
		for other in placed:
			if other.intersects(rect):
				fits = false
				break
		l.visible = fits
		if fits:
			placed.append(rect)


func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var k := 1.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.25
		var zoom := clampf(_zoom * k, 1.0, MAX_ZOOM)
		# El punto bajo el cursor queda quieto.
		var cursor: Vector2 = event.position
		var uv := (cursor - _big_map.position) / _big_map.size
		_set_view(zoom, cursor - uv * _side * zoom)
		_view.accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_view.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_view(_zoom, _big_map.position + event.relative)
		_view.accept_event()


## [texto, posición XZ, grande (distrito) o chico (lugar)], de más a menos importante.
func _place_names() -> Array:
	var out := [
		["KREDIK SHAW", CityPlan.HILL, true],
		["DISTRITO NOBLE", Vector2(-275, -330), true],
		["Casa Venture", CityPlan.VENTURE[0], false],
		["Casa Hastings", (CityPlan.ESTATES[0][0] as Vector2) + Vector2(-10, 30), false],
		["Casa Lorch", CityPlan.ESTATES[1][0], false],
		["DISTRITO MERCANTIL", CityPlan.MARKET + Vector2(60, -45), true],
		["Ministerio del Acero", CityPlan.MINISTRY, false],
		["Asamblea", CityPlan.ASSEMBLY, false],
		["PLAZA CENTRAL", Vector2.ZERO, true],
		["Avenida principal", Vector2(-130, -61), false],
		["DISTRITO DE FORJA", Vector2(-255, 45), true],
		["CORRALES DE CARBÓN", Vector2(-270, 250), true],
		["DISTRITO SKAA", Vector2(-60, 300), true],
		["Taller de Clubs", Workshop.POS + Vector2(0, 16), false],
		["TALLERES Y ALMACENES", Vector2(215, 190), true],
		["DÁRSENA", Vector2(290, -10), true],
	]
	for b in CityPlan.BARRACKS:
		out.append(["Cuartel general", b[0], false])
	for g in CityPlan.gates():
		out.append([g[0], (g[1] as Vector2) - (g[2] as Vector2) * 28.0, false])
	# Primero los distritos (grandes), después los lugares.
	var big := out.filter(func(l: Array) -> bool: return l[2])
	return big + out.filter(func(l: Array) -> bool: return not l[2])


## Cartel de nombre como en el plano: letras oscuras sobre una tira de pergamino.
func _tag(text: String, p: Vector2, big: bool) -> void:
	var l := _text(text, 15 if big else 12, INK)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(PAPER, 0.88)
	s.border_color = INK
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.set_content_margin_all(3)
	s.content_margin_left = 6
	s.content_margin_right = 6
	l.add_theme_stylebox_override("normal", s)
	_view.add_child(l)
	l.reset_size()
	_tags.append(l)
	_tag_pos.append(p)


func _unhandled_input(event: InputEvent) -> void:
	if _big == null:
		return
	if event.is_action_pressed(&"map") or (_big.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if not _big.visible and player.ui_open:
		return  # hay otra ventana abierta
	_big.visible = not _big.visible
	_mini.visible = not _big.visible
	_mini_label.visible = not _big.visible
	player.ui_open = _big.visible
	_dragging = false
	if _big.visible:
		_set_view(1.0, Vector2.ZERO)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _big.visible else Input.MOUSE_MODE_CAPTURED
