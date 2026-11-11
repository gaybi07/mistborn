class_name SkillTreeCanvas
extends Control
## Vista de árbol del árbol de habilidades (K): cada metal es una rama que nace de su hexágono, con sus habilidades repartidas
## en ramificaciones, y debajo los metales todavía sin habilidades. Se mueve arrastrando con el clic izquierdo, se acerca con la
## rueda y los detalles de cada habilidad salen al pasar el ratón (tooltip). Clic en una habilidad le pone un punto y clic
## derecho se lo saca (cada una muestra sus puntos con pips); clic en un metal sin habilidades le sube un nivel.

signal skill_hovered(id: StringName)
signal skill_clicked(id: StringName)
## Clic (raise = true) o clic derecho (false) sobre una habilidad: poner o sacar un punto (lo hace SkillTreeWindow).
signal skill_point(id: StringName, raise: bool)
signal metal_clicked(metal: StringName)

const BG := Color(0.035, 0.04, 0.055)
const GOLD := Color(0.78, 0.66, 1.0)  # elegido, teclas y realces: el violeta de los menús (HudKit.PICK, más claro)
const GOLD_SOFT := Color(0.78, 0.93, 1.0)  # títulos: acero claro (HudKit.ACCENT_LIGHT)
const GRAY := Color(0.36, 0.38, 0.43)
const GOOD := Color(0.5, 0.9, 0.55)
const LOCKED := Color(1.0, 0.65, 0.35)
const DIM := Color(0.6, 0.62, 0.68)
## Con Ctrl apretado (asignar a una ranura): borde de las que se pueden poner; el resto se apaga.
const ASSIGN := Color(0.55, 0.85, 1.0)
## Tamaño (px, sin zoom) del lienzo donde se reparten los metales.
const MIN_DESIGN := Vector2(1900.0, 900.0)
const ROOT_Y := 330.0
const COLUMN_X := 150.0
const COLUMN_STEP := 600.0
const LOCKED_Y := 790.0
const ROOT_RADIUS := 38.0
const SKILL_RADIUS := 23.0
const LOCKED_RADIUS := 27.0
const ZOOM_MIN := 0.45
const ZOOM_MAX := 1.7

## Tamaño (px, sin zoom) del lienzo; crece con la cantidad de ramas.
var _design := MIN_DESIGN
var _nodes: Array[Dictionary] = []  ## id, metal, pos, from
var _roots: Array[Dictionary] = []  ## metal, pos, radius, has_skills
var _stars := PackedVector2Array()
var _star_links: Array[Vector2i] = []
var _offset := Vector2.ZERO
var _zoom := 1.0
var _fit_pending := true
var _pressing := false
var _dragging := false
var _press_pos := Vector2.ZERO
var _press_hit := {}
var _hover := {}
## Ctrl apretado: resalta las habilidades que se pueden asignar a una ranura (lo pone SkillTreeWindow).
var assign_mode := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_build()
	resized.connect(func() -> void: _fit_pending = true)


func _build() -> void:
	var column := 0
	var locked: Array[StringName] = []
	for metal: StringName in Allomancy.METALS:
		var skills := SkillTree.skills_of(metal, &"allomancy")
		if skills.is_empty():
			locked.append(metal)
			continue
		var root := Vector2(COLUMN_X + COLUMN_STEP * column, ROOT_Y)
		column += 1
		_roots.append({"metal": metal, "pos": root, "radius": ROOT_RADIUS, "has_skills": true})
		var positions := {&"root": root}
		for entry: Array in SkillTree.LAYOUTS[&"allomancy"].get(metal, []):
			var from: Array[Vector2] = []
			for parent: StringName in entry[2]:
				from.append(positions[parent])
			positions[entry[0]] = root + (entry[1] as Vector2)
			_nodes.append({"id": entry[0], "metal": metal, "pos": positions[entry[0]], "from": from, "parents": entry[2]})
		# Habilidades nuevas que todavía no tienen lugar en el diseño: cuelgan de la raíz, en una columna.
		var extra := 0
		for s: Dictionary in skills:
			if not positions.has(s["id"]):
				var spot := root + Vector2(110.0, 150.0 + 90.0 * extra)
				extra += 1
				positions[s["id"]] = spot
				var origin: Array[Vector2] = [root]
				_nodes.append({"id": s["id"], "metal": metal, "pos": spot, "from": origin, "parents": [&"root"]})
	_design.x = maxf(MIN_DESIGN.x, COLUMN_X + COLUMN_STEP * (column - 1) + 520.0)
	for i in locked.size():
		var x := COLUMN_X + i * (_design.x - 2.0 * COLUMN_X) / maxf(locked.size() - 1.0, 1.0)
		_roots.append({"metal": locked[i], "pos": Vector2(x, LOCKED_Y), "radius": LOCKED_RADIUS, "has_skills": false})
	# Fondo: puntos sueltos unidos con líneas muy tenues, como una constelación.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:
		_stars.append(Vector2(rng.randf() * _design.x, rng.randf() * _design.y))
	for i in _stars.size():
		for j in range(i + 1, _stars.size()):
			if _stars[i].distance_to(_stars[j]) < 150.0 and _star_links.size() < 140:
				_star_links.append(Vector2i(i, j))


## Vuelve a encuadrar todo el árbol en la ventana (al abrirla o cambiar de tamaño).
func fit() -> void:
	_fit_pending = true
	queue_redraw()


func _apply_fit() -> void:
	_fit_pending = false
	_zoom = clampf(minf(size.x / _design.x, size.y / _design.y), ZOOM_MIN, 1.2)
	_offset = (size - _design * _zoom) * 0.5


func _to_screen(p: Vector2) -> Vector2:
	return _offset + p * _zoom


func _clamp_offset() -> void:
	_offset.x = clampf(_offset.x, size.x * 0.2 - _design.x * _zoom, size.x * 0.8)
	_offset.y = clampf(_offset.y, size.y * 0.2 - _design.y * _zoom, size.y * 0.8)


# ---------------------------------------------------------------- Entrada

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_pressing = true
					_dragging = false
					_press_pos = event.position
					_press_hit = _hit_at(event.position)
				else:
					if _pressing and not _dragging and not _press_hit.is_empty():
						_click(_press_hit)
					_pressing = false
					_dragging = false
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					var hit := _hit_at(event.position)
					if hit.get("kind") == "skill":
						skill_point.emit(hit["id"], false)
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom_at(event.position, 1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_at(event.position, 1.0 / 1.1)
	elif event is InputEventMouseMotion:
		if _pressing:
			if not _dragging and event.position.distance_to(_press_pos) > 6.0:
				_dragging = true
			if _dragging:
				_offset += event.relative
				_clamp_offset()
				queue_redraw()
		_set_hover(_hit_at(event.position) if not _dragging else {})


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_pressing = false
		_dragging = false
		_set_hover({})


func _zoom_at(pos: Vector2, factor: float) -> void:
	var new_zoom := clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	_offset = pos - (pos - _offset) * (new_zoom / _zoom)
	_zoom = new_zoom
	_clamp_offset()
	queue_redraw()


## La habilidad que hay ahora mismo bajo el puntero (&"" si ninguna).
func skill_under_mouse() -> StringName:
	if not visible:
		return &""
	var hit := _hit_at(get_local_mouse_position())
	return hit["id"] if hit.get("kind") == "skill" else &""


func _set_hover(hit: Dictionary) -> void:
	if hit == _hover:
		return
	_hover = hit
	skill_hovered.emit(hit["id"] if hit.get("kind") == "skill" else &"")
	queue_redraw()


func _click(hit: Dictionary) -> void:
	if hit["kind"] == "skill":
		skill_clicked.emit(hit["id"])
		skill_point.emit(hit["id"], true)
	else:
		metal_clicked.emit(hit["id"])


## Lo que hay bajo el ratón: una habilidad o un metal ({} si nada).
func _hit_at(pos: Vector2) -> Dictionary:
	for n in _nodes:
		if _to_screen(n["pos"]).distance_to(pos) <= SKILL_RADIUS * _zoom * 1.15:
			return {"kind": "skill", "id": n["id"]}
	for r in _roots:
		if _to_screen(r["pos"]).distance_to(pos) <= float(r["radius"]) * _zoom * 1.1:
			return {"kind": "metal", "id": r["metal"]}
	return {}


# ---------------------------------------------------------------- Tooltip

func _get_tooltip(at_position: Vector2) -> String:
	var hit := _hit_at(at_position)
	return "" if hit.is_empty() else "%s:%s" % [hit["kind"], hit["id"]]


func _make_custom_tooltip(for_text: String) -> Object:
	var parts := for_text.split(":")
	if parts.size() != 2:
		return null
	if parts[0] == "skill":
		var s := SkillTree.find(StringName(parts[1]))
		if s.is_empty():
			return null
		var card := SkillRowLabel.new()
		card.skill_id = StringName(parts[1])
		card.skill_level = Progression.skill_level(s["id"])
		var panel: Object = card._make_custom_tooltip("")
		card.free()
		return panel
	return _metal_card(StringName(parts[1]))


func _metal_card(metal: StringName) -> Control:
	var lvl := Progression.metal_level(metal)
	var cap := Progression.metal_cap(metal)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.05, 0.07, 0.98)
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(_card_label(String(Allomancy.METALS[metal]["label"]), 20, GOLD))
	if not Progression.is_direct_metal(metal):
		box.add_child(_card_label(("Nivel %d" % lvl) if lvl > 0 else "Sin aprender", 14, DIM))
		box.add_child(_card_label("Suma de los puntos en sus poderes: con más nivel, gasta menos y dura más.", 14, GOOD))
		return panel
	box.add_child(_card_label(("Nivel %d / %d" % [lvl, cap]) if lvl > 0 else "Sin aprender", 14, DIM))
	var cost := Progression.point_cost(metal)
	var hint := ""
	if lvl >= cap:
		hint = "Nivel máximo"
	elif Progression.can_raise(metal):
		hint = "Clic: %s (%d punto%s)" % ["subir nivel" if lvl > 0 else "aprender", cost, "" if cost == 1 else "s"]
	else:
		hint = "Te faltan puntos de alomancia (%d)" % cost
	box.add_child(_card_label(hint, 14, GOOD if Progression.can_raise(metal) else LOCKED))
	return panel


func _card_label(text: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	return l


# ---------------------------------------------------------------- Dibujo

func _draw() -> void:
	if _fit_pending and size.x > 0.0 and size.y > 0.0:
		_apply_fit()
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	for link in _star_links:
		draw_line(_to_screen(_stars[link.x]), _to_screen(_stars[link.y]), Color(0.5, 0.55, 0.7, 0.07), 1.0, true)
	for p in _stars:
		draw_circle(_to_screen(p), 1.6 * _zoom, Color(0.6, 0.65, 0.8, 0.18))
	for n in _nodes:
		_draw_link(n)
	for r in _roots:
		_draw_root(font, r)
	for n in _nodes:
		_draw_skill(font, n)
	if assign_mode:
		draw_string(font, Vector2(14.0, size.y - 12.0), "Ctrl: las resaltadas se pueden poner en una ranura (las pasivas no)  ·  ratón sobre una + tecla de la ranura",
				HORIZONTAL_ALIGNMENT_LEFT, size.x - 28.0, 13, ASSIGN)
	else:
		draw_string(font, Vector2(14.0, size.y - 12.0), "Clic: poner un punto  ·  Clic derecho: sacarlo  ·  Arrastrar: mover  ·  Rueda: zoom  ·  Ctrl + tecla de una ranura: ponerla ahí",
				HORIZONTAL_ALIGNMENT_LEFT, size.x - 28.0, 13, Color(0.6, 0.62, 0.68, 0.8))


func _unlocked(n: Dictionary) -> bool:
	return SkillTree.is_unlocked(n["id"])


## Cada línea se enciende cuando su padre tiene al menos un punto (o nace de la raíz), y brilla del todo cuando el hijo
## también lo tiene.
func _draw_link(n: Dictionary) -> void:
	var color: Color = Allomancy.METALS[n["metal"]]["color"]
	var b := _to_screen(n["pos"])
	var froms: Array = n["from"]
	for i in froms.size():
		var a := _to_screen(froms[i])
		var parent: StringName = n["parents"][i]
		var open := parent == &"root" or Progression.skill_level(parent) >= 1
		if _unlocked(n):
			draw_line(a, b, Color(color, 0.14), 7.0 * _zoom, true)
			draw_line(a, b, Color(color, 0.75), 2.0 * _zoom, true)
		elif open:
			draw_line(a, b, Color(color, 0.4), 1.5 * _zoom, true)
		else:
			draw_line(a, b, Color(GRAY, 0.4), 1.5 * _zoom, true)
		for t in [0.33, 0.66]:
			draw_circle(a.lerp(b, t), 3.0 * _zoom, Color(color, 0.8) if open else Color(GRAY, 0.5))


func _hex_points(c: Vector2, r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in 6:
		var ang := -PI / 2 + TAU * k / 6.0
		points.append(c + Vector2(cos(ang), sin(ang)) * r)
	return points


func _draw_hex(c: Vector2, r: float, fill: Color, border: Color, width: float) -> void:
	var points := _hex_points(c, r)
	draw_colored_polygon(points, fill)
	if width > 0.0:
		points.append(points[0])
		draw_polyline(points, border, width, true)


func _padlock(c: Vector2, scale_px: float) -> void:
	draw_arc(c + Vector2(0, -3.0 * scale_px), 4.5 * scale_px, PI, TAU, 10, Color(0.85, 0.8, 0.65, 0.9), 1.8, true)
	draw_rect(Rect2(c + Vector2(-6.0, -2.0) * scale_px, Vector2(12, 9) * scale_px), Color(0.85, 0.8, 0.65, 0.9))


func _draw_root(font: Font, r: Dictionary) -> void:
	var metal: StringName = r["metal"]
	var color: Color = Allomancy.METALS[metal]["color"]
	var lvl := Progression.metal_level(metal)
	var learned := lvl > 0
	var rad: float = float(r["radius"]) * _zoom
	var c := _to_screen(r["pos"])
	var hovered: bool = _hover.get("kind") == "metal" and _hover.get("id") == metal
	var tint := color if learned else GRAY
	if learned and bool(r["has_skills"]):
		_draw_hex(c, rad * 1.35, Color(color, 0.06), Color(color, 0.0), 0.0)
	_draw_hex(c, rad, Color(0.07, 0.085, 0.11).lerp(tint, 0.14), GOLD if hovered else tint, (3.2 if hovered else 2.6) * _zoom)
	MetalGlyph.draw(self, metal, c, rad * 0.55, tint.lightened(0.3), 2.6)
	if not learned:
		draw_colored_polygon(_hex_points(c, rad), Color(0.03, 0.035, 0.05, 0.55))
		_padlock(c + Vector2(rad * 0.62, rad * 0.62), 0.9 * _zoom)
	# Placa con el nombre.
	var size_px := clampi(roundi((22.0 if bool(r["has_skills"]) else 16.0) * _zoom), 11, 40)
	var label := String(Allomancy.METALS[metal]["label"]).to_upper()
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	var plate := Rect2(c + Vector2(-text_size.x * 0.5 - 14.0 * _zoom, rad + 10.0 * _zoom), text_size + Vector2(28.0, 10.0) * _zoom)
	draw_rect(plate, Color(0.06, 0.07, 0.09, 0.95))
	draw_rect(plate, Color(tint, 0.7 if learned else 0.35), false, 1.5)
	draw_string(font, plate.position + Vector2(14.0 * _zoom, text_size.y * 0.85 + 4.0 * _zoom), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px,
			GOLD_SOFT if learned else Color(0.55, 0.57, 0.62))
	if learned and bool(r["has_skills"]):
		var small := clampi(roundi(13.0 * _zoom), 9, 24)
		draw_string(font, Vector2(plate.position.x, plate.end.y + 16.0 * _zoom), "Nivel %d" % lvl,
				HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, small, Color(tint.lightened(0.3), 0.9))


func _draw_skill(font: Font, n: Dictionary) -> void:
	var id: StringName = n["id"]
	var s := SkillTree.find(id)
	var metal: StringName = n["metal"]
	var color: Color = Allomancy.METALS[metal]["color"]
	var unlocked := _unlocked(n)
	var tint := color if unlocked else GRAY
	var rad := SKILL_RADIUS * _zoom
	var c := _to_screen(n["pos"])
	var hovered: bool = _hover.get("kind") == "skill" and _hover.get("id") == id
	var assignable := unlocked and SkillTree.is_assignable(id)
	if assign_mode and assignable:
		_draw_hex(c, rad * 1.3, Color(ASSIGN, 0.07), Color(ASSIGN, 0.35), 1.0 * _zoom)  # sutil: halo apenas marcado
	if hovered:
		_draw_hex(c, rad * 1.3, Color(tint, 0.1), Color(GOLD, 0.35), 1.5)
	_draw_hex(c, rad, Color(0.07, 0.085, 0.11).lerp(tint, 0.12), GOLD if hovered else tint, (3.0 if hovered else 2.0) * _zoom)
	SkillIcon.draw(self, c, rad * 0.9, id, tint.lightened(0.15))
	if unlocked:
		var b := c + Vector2(rad * 0.75, rad * 0.75)
		draw_circle(b, 7.0 * _zoom, Color(0.04, 0.05, 0.07))
		draw_arc(b, 7.0 * _zoom, 0.0, TAU, 12, Color(GOOD, 0.9), 1.4, true)
		draw_line(b + Vector2(-3.0, 0.0) * _zoom, b + Vector2(-1.0, 2.5) * _zoom, Color(GOOD, 0.95), 1.6, true)
		draw_line(b + Vector2(-1.0, 2.5) * _zoom, b + Vector2(3.5, -2.5) * _zoom, Color(GOOD, 0.95), 1.6, true)
	else:
		draw_colored_polygon(_hex_points(c, rad), Color(0.03, 0.035, 0.05, 0.6))
		if not SkillTree.requirements_met(id):
			_padlock(c + Vector2(rad * 0.7, rad * 0.7), 0.7 * _zoom)  # falta el poder previo; sin candado, solo faltan puntos
	# Pips: un punto por nivel, llenos los que tiene.
	var top := SkillTree.max_level(id)
	var lvl := Progression.skill_level(id)
	var step := 9.0 * _zoom
	for k in top:
		var p := c + Vector2((k - (top - 1) * 0.5) * step, rad + 8.0 * _zoom)
		if k < lvl:
			draw_circle(p, 3.0 * _zoom, color.lightened(0.25))
		else:
			draw_arc(p, 3.0 * _zoom, 0.0, TAU, 10, Color(GRAY, 0.8), 1.0, true)
	var dimmed := assign_mode and not assignable
	if dimmed:
		draw_colored_polygon(_hex_points(c, rad * 1.05), Color(BG, 0.72))  # pasiva o bloqueada: no va en una ranura
	var size_px := clampi(roundi(15.0 * _zoom), 11, 26)
	var text_color := Color(0.88, 0.9, 0.95) if unlocked else Color(0.5, 0.52, 0.58)
	if dimmed:
		text_color = Color(text_color, 0.3)
	elif assign_mode:
		text_color = ASSIGN.lightened(0.4)
	font.draw_multiline_string(get_canvas_item(), c + Vector2(rad + 12.0 * _zoom, -2.0 * _zoom), String(s["name"]), HORIZONTAL_ALIGNMENT_LEFT,
			125.0 * _zoom, size_px, 2, text_color)
	var slot := Progression.slot_of(id)
	if slot >= 0:
		draw_string(font, c + Vector2(rad + 12.0 * _zoom, 30.0 * _zoom), "[%s]" % Progression.key_name(Progression.slot_keys[slot]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, clampi(roundi(12.0 * _zoom), 8, 22), GOLD)
	elif id in SkillTree.FIXED_KEY and unlocked:
		draw_string(font, c + Vector2(rad + 12.0 * _zoom, 30.0 * _zoom), "[%s]" % Progression.key_name(Progression.coin_key),
				HORIZONTAL_ALIGNMENT_LEFT, -1, clampi(roundi(12.0 * _zoom), 8, 22), GOLD)
