class_name AbilityHud
extends Control
## Barra inferior al estilo de League of Legends: el retrato del personaje (en vivo, de cerca) con la experiencia como un
## arco dorado alrededor y el nivel en un círculo; las habilidades en fila con su icono y su tecla (las ranuras 1 a 5; a la
## derecha, en el lugar de los hechizos, el Empuje básico (Q), el Tirón básico (E) y la moneda de combate (clic derecho);
## y debajo de 1 a 5, las ranuras F Z X C V, siempre visibles); y debajo de todo la vida (verde) y la resistencia (azul).
## Los metales están aparte, en la lista de la izquierda (ver MetalList). Se reduce con la ventana (ver HudKit.ui_scale).

const W := 622.0
const H := 164.0
const PORTRAIT_C := Vector2(86, 82)
const PORTRAIT_R := 69.0  # igual que el círculo del arma (ver WeaponDial)
## Arco de experiencia, como en el LoL: un tramo del 30 % de la circunferencia, entre arriba a la derecha y el círculo del nivel.
const XP_START := -1.4  # rad (unos -80°)
const XP_SPAN := 1.885  # rad (el 30 % de la vuelta)
const BOX := 44.0  # 1 a 5 y F Z X C V: todas del mismo tamaño
const BOX_GAP := 10.0
const ROW_X := 178.0
const ROW_Y := 10.0
const BASIC := 38.0  # Q, E y el clic derecho, más chicas
const LOW_Y := 66.0  # segunda fila (F Z X C V), debajo de 1 a 5
## Ranuras de la fila de arriba (teclas 1 2 3 4 5) y de la de abajo (F Z X C V), de izquierda a derecha.
const MAIN_SLOTS: Array[int] = [0, 1, 2, 3, 6]
const LOW_SLOTS: Array[int] = [7, 8, 9, 10, 11]
const BAR_X := 178.0
const BAR_W := 436.0
const EFFECT := 25.0  # lado de los iconos de buffs y debuffs sobre la barra
const GREEN := Color(0.2, 0.72, 0.28)
const BLUE := Color(0.2, 0.46, 0.9)

var player: Player

var _portrait: SubViewport
var _trail := 100.0  # vida "fantasma" que baja despacio tras un golpe
var _trail_hold := 0.0
var _last_health := 100.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -W / 2.0
	offset_right = W / 2.0
	offset_top = -H - 8.0
	offset_bottom = -8.0
	pivot_offset = Vector2(W / 2.0, H)
	_trail = player.health
	_last_health = player.health
	_make_portrait()


## Retrato en vivo: el personaje de cerca en un mundo propio (para no recibir la luz ni la niebla del juego).
func _make_portrait() -> void:
	_portrait = SubViewport.new()
	_portrait.size = Vector2i(160, 160)
	_portrait.own_world_3d = true
	_portrait.transparent_bg = true
	_portrait.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_portrait)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.68)
	env.ambient_light_energy = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_portrait.add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25.0, 180.0, 0.0)  # alumbra desde delante del personaje (que mira hacia -Z)
	light.light_energy = 1.1
	_portrait.add_child(light)
	var rig := Art.player_rig({})
	_portrait.add_child(rig)
	var cam := Camera3D.new()
	cam.fov = 24.0
	cam.position = Vector3(0.0, 1.57, -1.0)
	_portrait.add_child(cam)
	cam.look_at(Vector3(0.0, 1.55, 0.0))
	cam.current = true


func _process(delta: float) -> void:
	var rd := delta / Engine.time_scale
	if player.health < _last_health:
		_trail_hold = 0.45
	_last_health = player.health
	_trail_hold -= rd
	if player.health > _trail:
		_trail = player.health
	elif _trail_hold <= 0.0:
		_trail = move_toward(_trail, player.health, rd * maxf(25.0, (_trail - player.health) * 6.0))
	var s := HudKit.ui_scale(self)
	scale = Vector2(s, s)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	# Placa tenue detrás de las habilidades y las barras.
	draw_rect(Rect2(ROW_X - 8.0, 2.0, W - ROW_X + 8.0, H - 2.0), Color(0.03, 0.035, 0.05, 0.55))
	draw_rect(Rect2(ROW_X - 8.0, 2.0, W - ROW_X + 8.0, H - 2.0), Color(HudKit.GOLD, 0.35), false, 1.0)
	_draw_portrait(font)
	_draw_skills(font)
	_draw_bars(font)
	_draw_effects(font)


# ---------------------------------------------------------------- Retrato, experiencia y nivel

func _draw_portrait(font: Font) -> void:
	var c := PORTRAIT_C
	draw_circle(c, PORTRAIT_R + 2.0, Color(0.02, 0.022, 0.03, 0.95))
	if _portrait != null:
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for k in 48:
			var ang := TAU * k / 48.0
			var dir := Vector2(cos(ang), sin(ang))
			pts.append(c + dir * PORTRAIT_R)
			uvs.append(Vector2(0.5, 0.5) + dir * 0.5)
		draw_colored_polygon(pts, Color.WHITE, uvs, _portrait.get_texture())
	HudKit.ring(self, c, PORTRAIT_R + 1.0, 5.0, HudKit.GOLD)
	# Experiencia: un tramo corto de arco (el 30 % de la circunferencia) sobre el círculo del nivel, que se llena en el
	# sentido del reloj como en el LoL.
	var need := maxi(Progression.xp_for_next(Progression.level), 1)
	var frac := 1.0 if Progression.level >= Progression.MAX_LEVEL else clampf(float(Progression.xp) / float(need), 0.0, 1.0)
	var xp_r := PORTRAIT_R + 9.0
	draw_arc(c, xp_r, XP_START - 0.04, XP_START + XP_SPAN + 0.04, 32, Color(HudKit.GOLD, 0.8), 8.0, true)
	draw_arc(c, xp_r, XP_START, XP_START + XP_SPAN, 32, Color(0.03, 0.03, 0.045, 0.95), 5.5, true)
	if frac > 0.0:
		draw_arc(c, xp_r, XP_START, XP_START + XP_SPAN * frac, maxi(int(32 * frac), 2), Color(0.95, 0.8, 0.35), 4.0, true)
	# Nivel: el círculo de abajo a la derecha.
	var lv := c + Vector2(51, 53)
	draw_circle(lv, 18.0, Color(0.05, 0.05, 0.07, 0.95))
	HudKit.ring(self, lv, 18.0, 3.0, HudKit.GOLD)
	draw_string(font, lv + Vector2(-18.0, 6.0), str(Progression.level), HORIZONTAL_ALIGNMENT_CENTER, 36, 17, Color(1, 1, 1, 0.95))
	# Puntos de alomancia sin gastar: un círculo dorado abajo a la izquierda (abre el árbol con K).
	var free := Progression.points_free()
	if free > 0:
		var pb := c + Vector2(-51, 53)
		draw_circle(pb, 17.0, Color(0.95, 0.78, 0.3, 0.95))
		HudKit.ring(self, pb, 17.0, 2.5, HudKit.GOLD_LIGHT)
		draw_string(font, pb + Vector2(-17.0, 5.5), "+%d" % free, HORIZONTAL_ALIGNMENT_CENTER, 34, 14, Color(0.1, 0.07, 0.02))


# ---------------------------------------------------------------- Habilidades

func _draw_skills(font: Font) -> void:
	# Dos filas del mismo tamaño: arriba las teclas 1 2 3 4 5 y debajo, bajo cada una, F Z X C V.
	var x := ROW_X
	for n in MAIN_SLOTS.size():
		var slot: int = MAIN_SLOTS[n]
		_skill_box(font, Rect2(x, ROW_Y, BOX, BOX), Progression.slot_skills[slot], _key_text(slot))
		var low: int = LOW_SLOTS[n]
		_skill_box(font, Rect2(x, LOW_Y, BOX, BOX), Progression.slot_skills[low], _key_text(low))
		x += BOX + BOX_GAP
	# Donde en el LoL van los hechizos de invocador: Empuje básico (Q), Tirón básico (E) y la moneda de combate (clic
	# derecho), las tres que vienen puestas por defecto.
	x += 8.0
	var y := (ROW_Y + LOW_Y + BOX - BASIC) * 0.5  # centradas entre las dos filas
	for i in [4, 5]:
		_skill_box(font, Rect2(x, y, BASIC, BASIC), Progression.slot_skills[i], _key_text(i))
		x += BASIC + 8.0
	_skill_box(font, Rect2(x, y, BASIC, BASIC), &"steel_combat_coin", "RMB")


## Tecla de una ranura, para su etiqueta.
func _key_text(slot: int) -> String:
	return OS.get_keycode_string(Progression.slot_keys[slot] as Key)


## Una casilla con el icono de la habilidad, su recarga y su tecla (que asoma por el borde de abajo).
func _skill_box(font: Font, rect: Rect2, skill: StringName, key_text: String, small := false) -> void:
	var learned := skill != &"" and player.skill_unlocked(skill)
	var active := learned and player.skill_active(skill)
	draw_rect(rect, Color(0.04, 0.045, 0.06, 0.96))
	if skill != &"" and not SkillTree.find(skill).is_empty():
		var metal: StringName = SkillTree.find(skill)["metal"]
		var col: Color = Allomancy.METALS[metal]["color"]
		draw_rect(rect.grow(-3.0), col.darkened(0.8 if learned else 0.9))
		if learned:
			_skill_icon(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.5, skill, col)
		else:
			draw_rect(rect.grow(-3.0), Color(0, 0, 0, 0.45))
			_padlock(rect.get_center())
		var cooldown := player.skill_cooldown(skill) if learned else 0.0
		if cooldown > 0.0:
			draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(rect.size.x - 2.0, (rect.size.y - 2.0) * cooldown)), Color(0, 0, 0, 0.62))
	draw_rect(rect, Color(HudKit.GOLD_LIGHT if active else HudKit.GOLD, 0.95 if active else 0.7), false, 2.0 if active else 1.4)
	var tag_w := maxf(22.0, key_text.length() * 8.0 + 8.0) if not small else maxf(16.0, key_text.length() * 7.0 + 6.0)
	var tag := Rect2(Vector2(rect.get_center().x - tag_w * 0.5, rect.end.y - 7.0), Vector2(tag_w, 15.0 if not small else 13.0))
	draw_rect(tag, Color(0.02, 0.022, 0.03, 0.92))
	draw_rect(tag, Color(HudKit.GOLD, 0.55), false, 1.0)
	draw_string(font, tag.position + Vector2(0.0, tag.size.y - 3.0), key_text, HORIZONTAL_ALIGNMENT_CENTER, tag_w, 11 if not small else 10,
			Color(1, 1, 1, 0.9 if learned or skill == &"" else 0.45))


## Candado de una habilidad todavía bloqueada.
func _padlock(c: Vector2) -> void:
	draw_arc(c + Vector2(0, -3.0), 5.0, PI, TAU, 12, Color(0.85, 0.8, 0.65, 0.8), 2.0, true)
	draw_rect(Rect2(c + Vector2(-7.0, -2.0), Vector2(14, 11)), Color(0.85, 0.8, 0.65, 0.8))


## Icono de una habilidad: el símbolo de su metal y una marca que la distingue de las demás de ese metal.
func _skill_icon(c: Vector2, half: float, skill: StringName, col: Color) -> void:
	var light := col.lightened(0.3)
	var r := half * 0.6
	MetalGlyph.draw(self, SkillTree.find(skill)["metal"], c, r, light, 2.2)
	match skill:
		&"steel_combat_coin":
			draw_circle(c + Vector2(half * 0.45, half * 0.45), half * 0.2, Color(0.82, 0.58, 0.32))
			draw_arc(c + Vector2(half * 0.45, half * 0.45), half * 0.2, 0.0, TAU, 14, Color(0.4, 0.26, 0.14), 1.2, true)
		&"steel_coin_burst":
			for k in 3:
				var ang := -PI / 2 + (k - 1) * 0.55
				draw_circle(c + Vector2(cos(ang), sin(ang)) * half * 0.78, half * 0.1, Color(0.82, 0.58, 0.32))
		&"steel_coin_shield":
			draw_arc(c, half * 0.82, 0.0, TAU, 28, Color(0.82, 0.58, 0.32, 0.9), 1.6, true)
			for k in 5:
				var ang := TAU * k / 5.0
				draw_circle(c + Vector2(cos(ang), sin(ang)) * half * 0.82, half * 0.09, Color(0.95, 0.75, 0.45))
		&"steel_magnetic_field":
			for k in 6:
				var a0 := TAU * k / 6.0
				draw_arc(c, half * 0.85, a0, a0 + 0.55, 6, light, 1.6, true)
		&"steel_spear":
			draw_line(c + Vector2(-half * 0.7, half * 0.7), c + Vector2(half * 0.7, -half * 0.7), Color(0.95, 0.9, 0.8), 2.6, true)
		&"iron_coin_magnet":
			draw_arc(c + Vector2(0, half * 0.1), half * 0.55, 0.0, PI, 14, Color(0.9, 0.35, 0.3), 3.0, true)


# ---------------------------------------------------------------- Buffs y debuffs

## Iconos flotando sobre la barra, de izquierda a derecha, como los efectos del LoL: borde verde si es bueno y rojo si es
## malo, el símbolo del metal, una sombra que baja con el tiempo y los segundos que quedan.
func _draw_effects(font: Font) -> void:
	var x := ROW_X
	for fx in player.active_effects():
		var box := Rect2(x, -EFFECT - 4.0, EFFECT, EFFECT)
		var buff: bool = fx["buff"]
		var edge := Color(0.35, 0.85, 0.4) if buff else Color(0.9, 0.3, 0.25)
		var metal: StringName = fx["metal"]
		draw_rect(box, Color(0.04, 0.045, 0.06, 0.92))
		var tint: Color = Allomancy.METALS[metal]["color"]
		draw_rect(box.grow(-2.0), tint.darkened(0.78))
		MetalGlyph.draw(self, metal, box.get_center() - Vector2(0, 2), EFFECT * 0.3, tint.lightened(0.3), 2.0)
		var left: float = fx["left"]
		if left >= 0.0 and float(fx["total"]) > 0.0:
			var gone := 1.0 - clampf(left / float(fx["total"]), 0.0, 1.0)
			draw_rect(Rect2(box.position + Vector2(1, 1), Vector2(EFFECT - 2.0, (EFFECT - 2.0) * gone)), Color(0, 0, 0, 0.55))
			draw_string_outline(font, box.position + Vector2(0, EFFECT - 4.0), "%.1f" % left if left < 10.0 else str(ceili(left)), HORIZONTAL_ALIGNMENT_CENTER, EFFECT, 9, 3, Color(0, 0, 0, 0.9))
			draw_string(font, box.position + Vector2(0, EFFECT - 4.0), "%.1f" % left if left < 10.0 else str(ceili(left)), HORIZONTAL_ALIGNMENT_CENTER, EFFECT, 9, Color(1, 1, 1, 0.95))
		draw_rect(box, edge, false, 2.0)
		x += EFFECT + 4.0


# ---------------------------------------------------------------- Vida y resistencia

func _draw_bars(font: Font) -> void:
	var hp_max := player.max_health
	var hp := clampf(player.health / hp_max, 0.0, 1.0)
	var low := hp < 0.3
	var green := GREEN if not low else GREEN.lerp(Color(0.85, 0.15, 0.1), 0.6 + 0.4 * sin(Time.get_ticks_msec() / 1000.0 * 8.0))
	_bar(font, Rect2(BAR_X, 120.0, BAR_W, 22.0), hp, clampf(_trail / hp_max, 0.0, 1.0), green, "%d / %d" % [ceili(player.health), int(hp_max)])
	var sp := clampf(player.stamina / player.max_stamina, 0.0, 1.0)
	var tired := player.is_exhausted()
	var blue := BLUE if not tired else Color(0.95, 0.55, 0.2)
	_bar(font, Rect2(BAR_X, 146.0, BAR_W, 18.0), sp, sp, blue, "Sin aliento" if tired else "%d / %d" % [ceili(player.stamina), int(player.max_stamina)])


## Barra rellena con degradado y brillo, y la estela clara de la vida recién perdida.
func _bar(font: Font, rect: Rect2, frac: float, trail: float, fill: Color, text: String) -> void:
	draw_rect(rect, Color(0.02, 0.022, 0.03, 0.9))
	if trail > frac:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * trail, rect.size.y)), Color(0.98, 0.9, 0.75, 0.55))
	if frac > 0.0:
		var f := Rect2(rect.position, Vector2(rect.size.x * frac, rect.size.y))
		draw_rect(f, fill.darkened(0.3))
		draw_rect(Rect2(f.position, Vector2(f.size.x, f.size.y * 0.6)), fill)
		draw_rect(Rect2(f.position, Vector2(f.size.x, f.size.y * 0.28)), Color(fill.lightened(0.45), 0.5))
	draw_rect(rect, Color(HudKit.GOLD, 0.6), false, 1.2)
	var tp := rect.position + Vector2(0.0, rect.size.y - 6.0)
	draw_string_outline(font, tp, text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 13, 4, Color(0, 0, 0, 0.85))
	draw_string(font, tp, text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 13, Color(1, 1, 1, 0.97))
