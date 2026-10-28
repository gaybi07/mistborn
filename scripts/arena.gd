extends Node3D
## Arena cerrada para ver o pelear combates entre alománticos.
## Un patio amurallado con anclas de metal (pilares, farolas, verjas), cajas, monedas en el suelo
## y plataformas para moverse en vertical.
##   M: menú de combates (y Esc mirando).   R: repetir el combate.   F1: volver a la ciudad.
## Modo espectador: nombre, vida y líneas de acero/hierro de cada luchador a la vista.
## Modo pelea: entras tú, sin ayudas: solo ves lo que tus sentidos alománticos te dejan ver.

const MATCHES := [
	{"name": "Nacido de la bruma vs nacido de la bruma", "a": ["mistborn"], "b": ["mistborn"]},
	{"name": "Duelo a espada: nacido de la bruma vs nacido de la bruma", "a": ["mistborn"], "b": ["mistborn"], "sword": true},
	# atium: reserva de cada equipo (se quema a 2 por segundo: 30 = 15 s). El rojo tiene menos.
	{"name": "Duelo de atium: nacido de la bruma vs nacido de la bruma", "a": ["mistborn"], "b": ["mistborn"],
		"atium": [30.0, 16.0]},
	{"name": "Violento vs Lanzamonedas", "a": ["thug"], "b": ["coinshot"]},
	{"name": "Violento vs Violento", "a": ["thug"], "b": ["thug"]},
	{"name": "Atraedor + Lanzamonedas vs dos Violentos", "a": ["lurcher", "coinshot"], "b": ["thug", "thug"]},
	{"name": "Banda (Violento, Lanzamonedas, Humeador) vs Nacido de la bruma + Buscador",
		"a": ["thug", "coinshot", "smoker"], "b": ["mistborn", "seeker"]},
	{"name": "Tú vs Violento", "player": true, "b": ["thug"]},
	{"name": "Tú vs Lanzamonedas + Atraedor", "player": true, "b": ["coinshot", "lurcher"]},
	{"name": "Tú vs Nacido de la bruma", "player": true, "b": ["mistborn"]},
	{"name": "Tú vs Nacido de la bruma con atium (4: atium)", "player": true, "b": ["mistborn"], "atium": [0.0, 30.0]},
	{"name": "Tú vs banda (Violento, Lanzamonedas, Buscador, Humeador)", "player": true,
		"b": ["thug", "coinshot", "seeker", "smoker"]},
	{"name": "Tú + Violento vs dos Nacidos de la bruma", "player": true, "a": ["thug"], "b": ["mistborn", "mistborn"]},
]
const KIND_BY_KEY := {
	"thug": AllomancerNpc.Kind.THUG, "coinshot": AllomancerNpc.Kind.COINSHOT, "lurcher": AllomancerNpc.Kind.LURCHER,
	"tineye": AllomancerNpc.Kind.TINEYE, "smoker": AllomancerNpc.Kind.SMOKER, "seeker": AllomancerNpc.Kind.SEEKER,
	"mistborn": AllomancerNpc.Kind.MISTBORN, "soother": AllomancerNpc.Kind.SOOTHER, "rioter": AllomancerNpc.Kind.RIOTER,
}
const TEAM_NAMES := ["azul", "rojo"]
const SIZE := 44.0

## Combate que se arranca al (re)cargar la escena (-1 = mostrar el menú).
static var pending := -1

## Cámara del modo espectador (null si estás peleando).
var spectator: SpectatorCam = null

var _menu: CanvasLayer
var _banner: Label
var _fighters: Array[Node3D] = []
var _match := -1
var _over := false


func _ready() -> void:
	WorldKit.add_environment(self, 0.45, Vector3(SIZE, 30, SIZE))
	_build_arena()
	add_child(WorldFx.new())
	_build_menu()
	if pending >= 0:
		_start(pending)
	else:
		_show_menu(true)
		var cam := SpectatorCam.new()
		cam.position = Vector3(0, 14, 26)
		add_child(cam)


# ---------------------------------------------------------------- Escenario

func _build_arena() -> void:
	var m := WorldKit.materials()
	add_child(Props.static_box(Vector3(SIZE + 20, 2, SIZE + 20), Vector3(0, -1, 0), m["ground"]))
	var h := 14.0
	for side in [-1.0, 1.0]:
		add_child(Props.static_box(Vector3(SIZE + 4, h, 2), Vector3(0, h / 2.0, side * (SIZE / 2.0 + 1)), m["wall"]))
		add_child(Props.static_box(Vector3(2, h, SIZE + 4), Vector3(side * (SIZE / 2.0 + 1), h / 2.0, 0), m["wall"]))
	# Pilares de hierro en las esquinas del centro: grandes anclas para empujar y tirar.
	for x in [-9.0, 9.0]:
		for z in [-9.0, 9.0]:
			add_child(Props.static_box(Vector3(0.8, 10, 0.8), Vector3(x, 5, z), m["iron"], true))
	# Farolas de hierro a lo largo de las murallas.
	for i in 8:
		var a := TAU * i / 8.0
		add_child(Props.lamp_post(Vector3(cos(a) * 18.0, 0, sin(a) * 18.0), m["iron"], m["lamp_glass"]))
	# Plataformas de piedra para moverse en vertical.
	for p in [Vector3(-14, 2, 0), Vector3(14, 3, 0), Vector3(0, 4, -15)]:
		add_child(Props.static_box(Vector3(5, p.y * 2, 5), Vector3(p.x, p.y, p.z), m["stone"]))
	for i in 6:
		var s := randf_range(0.6, 1.1)
		add_child(Props.metal_crate(Vector3.ONE * s, Vector3(randf_range(-15, 15), s, randf_range(-15, 15)), 60.0 * s * s * s, m["rusty"], m["iron"]))
	for i in 40:
		var coin := Props.coin()
		coin.position = Vector3(randf_range(-19, 19), 0.2, randf_range(-19, 19))
		add_child(coin)
	for p in [Vector3(-19, 0, -19), Vector3(19, 0, -19), Vector3(-19, 0, 19), Vector3(19, 0, 19)]:
		var b := Brazier.new()
		b.position = p
		add_child(b)
	for p in [Vector3(-6, 1, 14), Vector3(6, 1, 14), Vector3(-6, 1, -14), Vector3(6, 1, -14)]:
		var v := Vial.new()
		v.position = p
		add_child(v)


# ---------------------------------------------------------------- Combates

func _start(index: int) -> void:
	_match = index
	_over = false
	var spec: Dictionary = MATCHES[index]
	var with_player: bool = spec.get("player", false)
	var sword: bool = spec.get("sword", false)
	var atium: Array = spec.get("atium", [0.0, 0.0])
	_spawn_team(spec.get("a", []), 0, Vector3(0, 0.1, 15), not with_player, sword, atium[0])
	_spawn_team(spec.get("b", []), 1, Vector3(0, 0.1, -15), not with_player, sword, atium[1])
	if with_player:
		var player := Player.new()
		player.name = "Player"
		player.position = Vector3(0, 1, 17)
		add_child(player)
		var hud := Hud.new()
		hud.player = player
		add_child(hud)
		_fighters.append(player)
		_show_menu(false)
	else:
		spectator = SpectatorCam.new()
		spectator.position = Vector3(0, 12, 24)
		add_child(spectator)
		_show_menu(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_banner.text = spec["name"]
	_banner.modulate.a = 1.0
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if not _over:
			_banner.text = ""
	)


func _spawn_team(kinds: Array, team: int, center: Vector3, spectate: bool, sword := false, atium := 0.0) -> void:
	for i in kinds.size():
		var a := AllomancerNpc.new()
		a.kind = KIND_BY_KEY[kinds[i]]
		a.sword = sword
		a.atium = atium
		a.team = team
		a.aggressive = true
		a.knows_enemies = true  # es un duelo: saben dónde está el rival
		a.show_label = spectate
		a.stay_in_plaza = false
		a.knockout_time = 1e9  # en la arena, fuera de combate es definitivo
		a.home = center
		a.roam_radius = 4.0
		a.position = center + Vector3((i - (kinds.size() - 1) / 2.0) * 3.0, 0, 0)
		a.rotation.y = 0.0 if center.z > 0.0 else PI
		add_child(a)
		_fighters.append(a)


func _process(_delta: float) -> void:
	if _match < 0 or _over:
		return
	var standing := {}
	for f in _fighters:
		if is_instance_valid(f) and not f.is_down():
			standing[f.team] = true
	if standing.size() <= 1:
		_over = true
		var winner: int = standing.keys()[0] if standing.size() == 1 else -1
		_banner.text = ("Gana el equipo %s" % TEAM_NAMES[winner] if winner >= 0 else "Empate") + \
				"\nR: repetir   ·   M: elegir otro combate   ·   F1: volver a la ciudad"


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# Peleando, Esc es el menú de pausa del jugador y R ancla los agarres: aquí solo M
	# (y R cuando ya terminó el combate).
	match event.keycode:
		KEY_M, KEY_ESCAPE:
			if not _menu.visible and (event.keycode == KEY_M or spectator != null or _match < 0):
				_show_menu(true)
				get_viewport().set_input_as_handled()
		KEY_R:
			if _match >= 0 and (spectator != null or _over):
				_restart(_match)


func _restart(index: int) -> void:
	pending = index
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- Menú

func _build_menu() -> void:
	_menu = CanvasLayer.new()
	_menu.layer = 20
	add_child(_menu)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.92)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	_menu.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Arena"
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	box.add_child(_section("Mirar (espectador)"))
	var fight_section := false
	for i in MATCHES.size():
		if MATCHES[i].get("player", false) and not fight_section:
			fight_section = true
			box.add_child(_section("Pelear"))
		var b := Button.new()
		b.text = MATCHES[i]["name"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_restart.bind(i))
		box.add_child(b)
	var help := Label.new()
	help.text = "Espectador: WASD mover · Q/E bajar/subir · clic derecho mirar · Tab seguir luchador · rueda acercar\nR repetir · M menú · F1 volver a la ciudad · F3 día/noche · F4 clima · F5 niebla"
	help.modulate.a = 0.7
	box.add_child(help)

	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 24
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 26)
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	var banner_layer := CanvasLayer.new()
	banner_layer.layer = 15
	banner_layer.add_child(_banner)
	add_child(banner_layer)


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
	return l


func _show_menu(on: bool) -> void:
	_menu.visible = on
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
