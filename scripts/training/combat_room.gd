extends TrainingRoom
## Sala de práctica de combate: oleadas cada vez más difíciles, primero koloss de a uno, después en grupo y
## con alománticos. Al terminar una te recarga todo; si morís, se repite esa misma.
##   Retroceso: repetir la oleada.   Av Pág / Re Pág: siguiente / anterior.

const SIZE := 40.0
const BREAK_TIME := 4.0
const WAVES := [
	{"name": "Un koloss con espadón", "foes": ["koloss"]},
	{"name": "Un koloss con hachas", "foes": ["axes"]},
	{"name": "Dos koloss", "foes": ["koloss", "axes"]},
	{"name": "Tres koloss", "foes": ["koloss", "axes", "axes"]},
	{"name": "Un Violento", "foes": ["thug"]},
	{"name": "Un Lanzamonedas", "foes": ["coinshot"]},
	{"name": "Dos koloss y un Lanzamonedas", "foes": ["koloss", "axes", "coinshot"]},
	{"name": "Violento y Atraedor", "foes": ["thug", "lurcher"]},
	{"name": "Un Nacido de la bruma", "foes": ["mistborn"]},
	{"name": "Tres koloss y un Nacido de la bruma", "foes": ["koloss", "axes", "axes", "mistborn"]},
]
const KINDS := {"thug": AllomancerNpc.Kind.THUG, "coinshot": AllomancerNpc.Kind.COINSHOT,
		"lurcher": AllomancerNpc.Kind.LURCHER, "mistborn": AllomancerNpc.Kind.MISTBORN}

var _wave := 0
var _foes: Array[Npc] = []
## Cuenta atrás hasta que salga la oleada (<= 0: peleando).
var _break := BREAK_TIME
var _finished := false


func _ready() -> void:
	_build_base(Vector3(SIZE, 30, SIZE), Vector3(0, 1, 15))
	_build_room()
	player.died.connect(_on_player_died)


func _build_room() -> void:
	var m := WorldKit.materials()
	add_child(Props.static_box(Vector3(SIZE + 20, 2, SIZE + 20), Vector3(0, -1, 0), m["ground"]))
	var h := 14.0
	for side in [-1.0, 1.0]:
		add_child(Props.static_box(Vector3(SIZE + 4, h, 2), Vector3(0, h / 2.0, side * (SIZE / 2.0 + 1)), m["wall"]))
		add_child(Props.static_box(Vector3(2, h, SIZE + 4), Vector3(side * (SIZE / 2.0 + 1), h / 2.0, 0), m["wall"]))
	# Pilares de hierro para empujar y tirar; bloques para subirse y cubrirse.
	for x in [-10.0, 10.0]:
		for z in [-10.0, 10.0]:
			add_child(Props.static_box(Vector3(0.8, 10, 0.8), Vector3(x, 5, z), m["iron"], true))
	for p in [Vector3(-14, 1, 0), Vector3(14, 1.5, 0), Vector3(0, 0.75, 0)]:
		add_child(Props.static_box(Vector3(4, p.y * 2, 4), p, m["stone"]))
	for i in 8:
		var a := TAU * i / 8.0
		add_child(Props.lamp_post(Vector3(cos(a) * 15.0, 0, sin(a) * 15.0), m["iron"], m["lamp_glass"]))
	for p in [Vector3(-18, 0, -18), Vector3(18, 0, -18), Vector3(-18, 0, 18), Vector3(18, 0, 18)]:
		var b := Brazier.new()
		b.position = p
		add_child(b)
	for i in 30:
		var coin := Props.coin()
		coin.position = Vector3(randf_range(-18, 18), 0.2, randf_range(-18, 18))
		add_child(coin)


func _process(delta: float) -> void:
	if _finished or player.dead:
		return
	if _break > 0.0:
		_break -= delta
		_banner.text = "Oleada %d/%d: %s\nEmpieza en %d" % [_wave + 1, WAVES.size(), WAVES[_wave]["name"], ceili(_break)]
		if _break <= 0.0:
			_spawn_wave()
		return
	var left := 0
	for foe in _foes:
		if is_instance_valid(foe) and not foe.is_down():
			left += 1
	_banner.text = "Oleada %d/%d · quedan %d" % [_wave + 1, WAVES.size(), left]
	if left == 0:
		_refill()
		_go_to_wave(_wave + 1)


func _spawn_wave() -> void:
	var foes: Array = WAVES[_wave]["foes"]
	# Salen del otro lado de la sala, a la vista.
	var flat := Vector3(player.global_position.x, 0, player.global_position.z)
	var dir := -flat.normalized() if flat.length() > 2.0 else Vector3.FORWARD
	var center := flat + dir * 16.0
	var limit := SIZE / 2.0 - 3.0
	center = Vector3(clampf(center.x, -limit, limit), 0.5, clampf(center.z, -limit, limit))
	var side := dir.cross(Vector3.UP)
	for i in foes.size():
		var pos := center + side * (i - (foes.size() - 1) / 2.0) * 3.5
		pos.x = clampf(pos.x, -limit, limit)
		pos.z = clampf(pos.z, -limit, limit)
		var foe := _make_foe(foes[i], pos)
		add_child(foe)
		# _setup los fija al entrar: practicar no da experiencia ni botín.
		foe.xp_reward = 0
		foe.loot_coins = Vector2i.ZERO
		foe.loot_vial_chance = 0.0
		_foes.append(foe)
		Fx.dust(self, pos, 1.0)


func _make_foe(key: String, pos: Vector3) -> Npc:
	var foe: Npc
	if key == "koloss" or key == "axes":
		var k := Koloss.new()
		k.axes = key == "axes"
		foe = k
	else:
		var a := AllomancerNpc.new()
		a.kind = KINDS[key]
		a.atium = 0.0
		a.team = 1
		a.aggressive = true
		a.knows_enemies = true
		a.stay_in_plaza = false
		a.knockout_time = 1e9
		a.roam_radius = 4.0
		foe = a
	foe.home = pos
	foe.position = pos
	return foe


func _go_to_wave(index: int) -> void:
	for foe in _foes:
		if is_instance_valid(foe) and not foe.is_down():
			foe.queue_free()
	_foes.clear()
	_finished = index >= WAVES.size()
	if _finished:
		_banner.text = "¡Sala completada!\nRetroceso: de nuevo desde la última · Re Pág: oleada anterior · Ctrl+F1: volver a la ciudad"
		return
	_wave = maxi(index, 0)
	_break = BREAK_TIME


## Morir repite la oleada cuando reaparecés (Player._die tarda 2,5 s).
func _on_player_died() -> void:
	_banner.text = "Caíste. Se repite la oleada."
	get_tree().create_timer(2.6, true, false, true).timeout.connect(func() -> void:
		_refill()
		_go_to_wave(_wave))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or player.dead:
		return
	var from_end := mini(_wave, WAVES.size() - 1)
	match event.keycode:
		KEY_BACKSPACE:
			_go_to_wave(from_end)
		KEY_PAGEDOWN:
			_go_to_wave(mini(from_end + 1, WAVES.size() - 1))
		KEY_PAGEUP:
			_go_to_wave(from_end - 1)
		_:
			return
	_refill()
