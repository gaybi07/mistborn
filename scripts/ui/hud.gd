class_name Hud
extends CanvasLayer
## Barra inferior (metales y vida, ver MetalBar), mira, estados, avisos y barras de los PNJ.
## Esc abre el menú con todas las habilidades y controles (PauseMenu).

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float amount = 0.0;
void fragment() {
	float d = length(UV - 0.5);
	COLOR = vec4(0.55, 0.0, 0.0, smoothstep(0.2, 0.75, d) * amount);
}
"""

var player: Player

var _target_label: Label
var _select_ring: Panel
var _enemy_bars: Array[ProgressBar] = []
## Estados que te afectan (arrastre de peltre, aplacado, enardecido, encandilado...).
var _status_label: Label
## "enardecido" / "aplacado" sobre los PNJ afectados por cinc o latón.
var _emotion_tags: Array[Label] = []
var _vignette_mat: ShaderMaterial
var _death_screen: ColorRect
var _impact_label: Label
var _flash := 0.0
var _impact_time := 0.0


func _ready() -> void:
	layer = 10
	_build_damage_overlay()
	var inventory := InventoryWindow.new()
	inventory.player = player
	add_child(inventory)
	var wheel := MetalWheel.new()
	wheel.player = player
	add_child(wheel)
	var bar := MetalBar.new()
	bar.player = player
	add_child(bar)
	for is_left in [true, false]:
		var corner := HudCorner.new()
		corner.player = player
		corner.left = is_left
		add_child(corner)
	var menu := PauseMenu.new()
	menu.player = player
	add_child(menu)
	_status_label = _label("")
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_status_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.offset_top = 150
	add_child(_status_label)

	var cross := ColorRect.new()
	cross.color = Color(1, 1, 1, 0.8)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.offset_left = -2
	cross.offset_top = -2
	cross.offset_right = 2
	cross.offset_bottom = 2
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cross)

	# Zona de selección de acero/hierro alrededor de la mira
	var ring_style := StyleBoxFlat.new()
	ring_style.draw_center = false
	ring_style.set_border_width_all(1)
	ring_style.border_color = Color(0.5, 0.75, 1.0, 0.25)
	ring_style.set_corner_radius_all(1000)
	ring_style.anti_aliasing = true
	_select_ring = Panel.new()
	_select_ring.add_theme_stylebox_override("panel", ring_style)
	_select_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_select_ring.visible = false
	add_child(_select_ring)

	_target_label = _label("")
	_target_label.set_anchors_preset(Control.PRESET_CENTER)
	_target_label.offset_left = 12
	_target_label.offset_top = 8
	add_child(_target_label)

	var hint := _label("Esc: habilidades y controles")
	hint.add_theme_font_size_override("font_size", 13)
	hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hint.position = Vector2(16, 12)
	hint.modulate.a = 0.55
	add_child(hint)


func _build_damage_overlay() -> void:
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = shader
	vignette.material = _vignette_mat
	add_child(vignette)

	_death_screen = ColorRect.new()
	_death_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_screen.color = Color(0.05, 0.0, 0.0, 0.0)
	var death_label := _label("Has caído")
	death_label.add_theme_font_size_override("font_size", 48)
	death_label.set_anchors_preset(Control.PRESET_CENTER)
	death_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	death_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_death_screen.add_child(death_label)
	add_child(_death_screen)

	_impact_label = _label("")
	_impact_label.add_theme_font_size_override("font_size", 22)
	_impact_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_impact_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_impact_label.offset_top = -210
	add_child(_impact_label)

	player.damaged.connect(_on_damaged)
	player.dodged.connect(_notice.bind("Esquivado (atium)", 1.5))
	player.notice.connect(_notice.bind(2.0))


func _notice(text: String, time: float) -> void:
	_impact_label.text = text
	_impact_time = time


func _on_damaged(amount: float, impact_speed: float) -> void:
	_flash = clampf(amount / 40.0, 0.35, 1.0)
	_impact_time = 2.5
	if impact_speed > 0.0:
		_impact_label.text = "Impacto %.1f m/s  ·  -%d salud" % [impact_speed, int(round(amount))]
	else:
		_impact_label.text = "-%d salud" % int(round(amount))


func _process(delta: float) -> void:
	var rd := delta / Engine.time_scale
	_update_enemy_bars()
	_update_status()
	_flash = move_toward(_flash, 0.0, rd * 1.5)
	var low := 1.0 - player.health / player.max_health
	var pulse := maxf(low - 0.5, 0.0) * (0.6 + 0.4 * sin(Time.get_ticks_msec() / 1000.0 * 4.0))
	_vignette_mat.set_shader_parameter(&"amount", maxf(_flash, pulse))
	_death_screen.color.a = move_toward(_death_screen.color.a, 0.75 if player.dead else 0.0, rd * 1.5)
	_death_screen.visible = _death_screen.color.a > 0.01
	_impact_time -= rd
	_impact_label.modulate.a = clampf(_impact_time, 0.0, 1.0)

	var a := player.allomancy
	_select_ring.visible = a.is_burning(&"steel") or a.is_burning(&"iron")
	if _select_ring.visible:
		var view := get_viewport().get_visible_rect().size
		var d := 2.0 * player.steel_iron.select_radius * view.y
		_select_ring.size = Vector2(d, d)
		_select_ring.position = view * 0.5 - _select_ring.size * 0.5

	var lines := PackedStringArray()
	var t := player.steel_iron.target
	if is_instance_valid(t):
		var mass := player.steel_iron.movable_mass(t)
		lines.append(("%.2f kg" % mass) if mass > 0.0 else "fijo")
	for g in player.steel_iron.grips():
		if g.active:
			lines.append(("Empujando" if g.dir_sign > 0.0 else "Tirando") + ("  [ANCLADO]" if g.latched else ""))
	_target_label.text = "\n".join(lines)


## Barra de vida flotando sobre cada PNJ que está peleando (rojo: alománticos y guardias
## enemigos; ámbar: el resto).
func _update_enemy_bars() -> void:
	var cam := player.camera
	var used := 0
	for n in get_tree().get_nodes_in_group(&"npc"):
		var npc := n as Npc
		if npc == null or npc.down or not npc.in_combat():
			continue
		var head := npc.global_position + Vector3(0, 2.15, 0)
		if cam.is_position_behind(head) or head.distance_to(cam.global_position) > 50.0:
			continue
		if used == _enemy_bars.size():
			var b := _bar(1.0, Color.WHITE)
			b.custom_minimum_size = Vector2(70, 7)
			add_child(b)
			_enemy_bars.append(b)
		var bar := _enemy_bars[used]
		used += 1
		var hostile := npc.team >= 0 and npc.team != player.team
		(bar.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color = Color(0.8, 0.12, 0.1) if hostile else Color(0.85, 0.6, 0.2)
		bar.max_value = npc.max_health
		bar.value = npc.health
		bar.size = bar.custom_minimum_size
		bar.position = cam.unproject_position(head) - bar.size * 0.5
		bar.visible = true
	for i in range(used, _enemy_bars.size()):
		_enemy_bars[i].visible = false
	_update_emotion_tags()


func _update_emotion_tags() -> void:
	var cam := player.camera
	var used := 0
	for n in get_tree().get_nodes_in_group(&"npc"):
		var npc := n as Npc
		if npc == null or npc.down:
			continue
		var text := ""
		var color := Color.WHITE
		if npc.surrendered:
			text = "rendido"
			color = Color(0.7, 0.9, 0.75)
		elif npc.is_frenzied():
			text = "frenesí"
			color = Color(1.0, 0.35, 0.3)
		elif npc.is_rioted():
			text = "enardecido"
			color = Color(1.0, 0.5, 0.4)
		elif npc.is_soothed():
			text = "aplacado"
			color = Color(0.6, 0.9, 0.7)
		if text == "":
			continue
		var head := npc.global_position + Vector3(0, 2.45, 0)
		if cam.is_position_behind(head) or head.distance_to(cam.global_position) > 40.0:
			continue
		if used == _emotion_tags.size():
			var l := _label("")
			l.add_theme_font_size_override("font_size", 14)
			add_child(l)
			_emotion_tags.append(l)
		var tag := _emotion_tags[used]
		used += 1
		tag.text = text
		tag.add_theme_color_override("font_color", color)
		tag.reset_size()
		tag.position = cam.unproject_position(head) - tag.size * 0.5
		tag.visible = true
	for i in range(used, _emotion_tags.size()):
		_emotion_tags[i].visible = false


func _update_status() -> void:
	var lines := PackedStringArray()
	if player.pewter_drag() > 0.0:
		lines.append("ARRASTRE DE PELTRE  %d s  (lento y débil)" % ceili(player.pewter_drag()))
	if player.is_soothed():
		lines.append("Aplacado: no podés avivar  (el cobre te protege)")
	if player.is_rioted():
		lines.append("Enardecido: pegás más pero recibís más  (el cobre te protege)")
	if player.senses.blinded > 0.0:
		lines.append("¡Encandilado!")
	if player.atium.contested:
		lines.append("Atium contra atium: se anulan")
	_status_label.text = "\n".join(lines)


func _bar(max_value: float, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(160, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = max_value
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bar.add_theme_stylebox_override("background", bg)
	return bar


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
