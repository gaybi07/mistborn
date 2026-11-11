extends TrainingRoom
## Sala de pruebas de poderes (Ctrl+F8 desde cualquier escenario). Al entrar, un menú para elegir qué metal probar: el
## escenario se arma para sus poderes (lo que hace falta para usarlos y verlos), aparecen los NPC que sirven y sus
## activas quedan puestas en las ranuras. Todos los poderes al máximo mientras estás acá; al salir, tus puntos y tus
## ranuras vuelven a como estaban (no se guarda nada).
##   F10: abrir el menú.   Retroceso: rearmar la prueba (vuelven los NPC que cayeron).

const SIZE := 80.0
## Teclas de la sala (fuera de las de juego).
const MENU_KEY := KEY_F10
const REARM_KEY := KEY_BACKSPACE
## Qué hay que poner en cada prueba. "props": piezas del escenario; "npcs": [tipo, cantidad]. Tipos: ver _make_npc.
const SETUPS := {
	&"steel": {"props": ["posts", "pillars", "coins", "blocks"], "npcs": [["guard", 2], ["koloss", 1], ["coinshot", 1]]},
	&"iron": {"props": ["posts", "pillars", "coins", "blocks", "roof"], "npcs": [["guard", 2], ["thug", 1], ["koloss", 1]]},
	&"pewter": {"props": ["blocks", "walls"], "npcs": [["koloss", 2], ["guard", 2]]},
	&"tin": {"props": ["walls"], "npcs": [["citizen_hidden", 3], ["guard_hidden", 2], ["coinshot", 1]]},
	&"zinc": {"props": ["blocks"], "npcs": [["citizen", 3], ["guard", 2], ["koloss", 1], ["thug", 1], ["smoker", 1]]},
	&"brass": {"props": ["blocks"], "npcs": [["citizen", 3], ["guard", 2], ["koloss", 1], ["thug", 1], ["smoker", 1]]},
	&"copper": {"props": ["walls", "blocks"], "npcs": [["guard", 3], ["seeker", 1], ["tineye", 1], ["koloss", 1]]},
	&"bronze": {"props": ["walls"], "npcs": [["smoker", 1], ["coinshot", 1], ["soother", 1], ["lurcher", 1], ["rioter", 1]]},
	&"atium": {"props": ["coins", "blocks"], "npcs": [["koloss", 2], ["coinshot", 2], ["thug", 1]]},
}
const ALLOMANCER_KINDS := {
	"coinshot": AllomancerNpc.Kind.COINSHOT, "thug": AllomancerNpc.Kind.THUG, "lurcher": AllomancerNpc.Kind.LURCHER,
	"smoker": AllomancerNpc.Kind.SMOKER, "seeker": AllomancerNpc.Kind.SEEKER, "tineye": AllomancerNpc.Kind.TINEYE,
	"soother": AllomancerNpc.Kind.SOOTHER, "rioter": AllomancerNpc.Kind.RIOTER,
}

## Abrir el menú al entrar (aim_pitch_check lo apaga para usar la sala sin tocar nada).
var open_menu := true

var _saved_skills := {}
var _saved_slots: Array[StringName] = []
var _metal: StringName = &""
var _stage: Node3D
var _menu: Control
var _menu_layer: CanvasLayer


func _ready() -> void:
	_saved_skills = Progression.skill_levels.duplicate()
	_saved_slots = Progression.slot_skills.duplicate()
	for s: Dictionary in SkillTree.SKILLS:
		Progression.skill_levels[s["id"]] = SkillTree.max_level(s["id"])
	_build_base(Vector3(SIZE, 30, SIZE), Vector3(0, 1, 12))
	add_child(Props.static_box(Vector3(SIZE, 2, SIZE), Vector3(0, -1, 0), WorldKit.materials()["ground"]))
	_stage = Node3D.new()
	add_child(_stage)
	_build_menu()
	_banner.text = "Sala de pruebas  ·  F10: elegir metal  ·  Ctrl+F1: ciudad"
	if open_menu:
		_show_menu.call_deferred(true)


func _exit_tree() -> void:
	Progression.skill_levels = _saved_skills
	Progression.slot_skills = _saved_slots


# ---------------------------------------------------------------- Menú

func _build_menu() -> void:
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 40
	add_child(_menu_layer)
	_menu = PanelContainer.new()
	_menu.theme = HudKit.menu_theme()
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_menu.visible = false
	_menu_layer.add_child(_menu)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_menu.add_child(col)
	var title := Label.new()
	title.text = "¿Qué metal probás?"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)
	for metal: StringName in Allomancy.METALS:
		var b := Button.new()
		b.text = "Probar %s" % Allomancy.METALS[metal]["label"]
		b.custom_minimum_size = Vector2(220, 48)
		b.add_theme_color_override("font_color", (Allomancy.METALS[metal]["color"] as Color).lightened(0.35))
		b.pressed.connect(func() -> void:
			_show_menu(false)
			setup(metal))
		grid.add_child(b)
	var hint := Label.new()
	hint.text = "Todos los poderes al máximo; las activas del metal elegido quedan en las ranuras.\nF10: volver a este menú  ·  Retroceso: rearmar la prueba  ·  Esc: cerrar"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(0.75, 0.78, 0.85)
	col.add_child(hint)


func _show_menu(on: bool) -> void:
	_menu.visible = on
	player.ui_open = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		MENU_KEY:
			_show_menu(not _menu.visible)
		REARM_KEY:
			if _metal != &"":
				setup(_metal)
		KEY_ESCAPE:
			if not _menu.visible:
				return
			_show_menu(false)
		_:
			return
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- Prueba de un metal

## Arma la prueba de `metal`: escenario, NPC y sus activas en las ranuras (lo de antes se borra).
func setup(metal: StringName) -> void:
	_metal = metal
	for c in _stage.get_children():
		c.queue_free()
	for n in get_tree().get_nodes_in_group(&"npc"):
		n.queue_free()
	for c in get_tree().get_nodes_in_group(&"coin"):
		c.queue_free()
	var plan: Dictionary = SETUPS.get(metal, {})
	for p: String in plan.get("props", []):
		_add_props(p)
	var spots := _spots()
	var k := 0
	for entry: Array in plan.get("npcs", []):
		for i in int(entry[1]):
			var npc := _make_npc(entry[0], spots[k % spots.size()])
			k += 1
			_stage.add_child(npc)
	_put_in_slots(metal)
	player.global_position = Vector3(0, 1, 12)
	_refill()
	_banner.text = "Probando %s  ·  F10: otro metal  ·  Retroceso: rearmar" % Allomancy.METALS[metal]["label"]


## Las activas del metal en las ranuras 1, 2, 3… (Empuje y Tirón básicos siguen en Q y E). Solo en memoria.
func _put_in_slots(metal: StringName) -> void:
	for i in Progression.SLOT_COUNT:
		if i != Progression.BASIC_PUSH_SLOT and i != Progression.BASIC_PULL_SLOT:
			Progression.slot_skills[i] = &""
	var free := 0
	for s: Dictionary in SkillTree.skills_of(metal, &"allomancy"):
		if not SkillTree.is_assignable(s["id"]) or Progression.slot_of(s["id"]) >= 0:
			continue
		while free < Progression.SLOT_COUNT and (free == Progression.BASIC_PUSH_SLOT or free == Progression.BASIC_PULL_SLOT):
			free += 1
		if free >= Progression.SLOT_COUNT:
			break
		Progression.slot_skills[free] = s["id"]
		free += 1


## Dónde aparecen los NPC: un arco delante del jugador, a distintas distancias.
func _spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in 12:
		var a := -PI * 0.5 + (float(i % 6) - 2.5) * 0.32
		var r := 9.0 + 6.0 * float(i / 6)
		out.append(Vector3(cos(a) * r, 0.5, sin(a) * r - 2.0))
	return out


func _make_npc(kind: String, pos: Vector3) -> Npc:
	var npc: Npc
	var hidden := kind.ends_with("_hidden")
	if hidden:
		pos = Vector3(pos.x, pos.y, -16.0 - randf() * 6.0)  # detrás de las paredes (ver "walls")
	match kind.trim_suffix("_hidden"):
		"citizen":
			npc = Citizen.new()
		"guard":
			npc = Guard.new()
		"koloss":
			npc = Koloss.new()
		_:
			var a := AllomancerNpc.new()
			a.kind = ALLOMANCER_KINDS.get(kind, AllomancerNpc.Kind.THUG)
			a.atium = 0.0
			a.team = 1
			a.aggressive = true
			a.roam_radius = 3.0
			npc = a
	npc.home = pos
	npc.position = pos
	npc.stay_in_plaza = false
	# Practicar no da experiencia ni botín (como CombatRoom); los que caen vuelven con Retroceso.
	npc.ready.connect(func() -> void:
		npc.xp_reward = 0
		npc.loot_coins = Vector2i.ZERO
		npc.loot_vial_chance = 0.0)
	return npc


func _add_props(kind: String) -> void:
	var m := WorldKit.materials()
	match kind:
		"posts":  # farolas de hierro para empujar y tirar
			for i in 6:
				var a := TAU * i / 6.0
				_stage.add_child(Props.lamp_post(Vector3(cos(a) * 14.0, 0, sin(a) * 14.0), m["iron"], m["lamp_glass"]))
		"pillars":  # pilares de hierro altos, para subir con el Tirón y el Gancho
			for x in [-12.0, 12.0]:
				_stage.add_child(Props.static_box(Vector3(0.8, 12, 0.8), Vector3(x, 6, -14), m["iron"], true))
		"roof":  # un techo alto de hierro para colgarse
			_stage.add_child(Props.static_box(Vector3(10, 0.6, 10), Vector3(0, 9, -24), m["iron"], true))
		"coins":  # monedas sueltas para el Imán y la Ráfaga
			for i in 30:
				var coin := Props.coin()
				coin.position = Vector3(randf_range(-12, 12), 0.2, randf_range(-12, 8))
				_stage.add_child(coin)
		"blocks":  # bloques para subirse y cubrirse
			for p in [Vector3(-8, 1, -4), Vector3(8, 1.5, -6), Vector3(0, 0.75, -10)]:
				_stage.add_child(Props.static_box(Vector3(4, p.y * 2, 4), p, m["stone"]))
		"walls":  # paredes para esconderse (y detrás, NPC para el estaño y el bronce)
			for x in [-10.0, 0.0, 10.0]:
				_stage.add_child(Props.static_box(Vector3(7, 5, 0.6), Vector3(x, 2.5, -13), m["wall"]))
