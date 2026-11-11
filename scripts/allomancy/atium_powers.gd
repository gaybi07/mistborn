class_name AtiumPowers
extends MetalPowers
## Poderes del atium del jugador (L11, rehechos después de probarlos): más preciso y más espectacular, no más barato
## (cada nivel cuesta 2 puntos). Sombras del futuro (unos segundos quemando atium: lo que hace el atium, ver Atium),
## Esquiva perfecta (al esquivar con atium, cámara lenta y el siguiente golpe es crítico), Desarme (al esquivar, el
## atacante pierde el arma), Monedas guiadas (una a cada enemigo; gastan atium), Leer la pelea (marca al que te va a
## pegar, avisos de los jefes más temprano, sombra más adelantada) y Momento eterno (el mundo casi se detiene).
## La cámara lenta es solo fuera de red: con otros jugadores el atium tiene que funcionar en tiempo real (ver Atium).

## Sombras del futuro, golpe crítico pendiente (Esquiva perfecta) y Momento eterno en marcha (ms del reloj).
var _shadows_until := 0
var _crit_until := 0
var _eternal_until := 0
## Si el atium lo encendieron Sombras o Momento eterno (y hay que apagarlo al terminar).
var _forced := false
## Leer la pelea: la marca roja de cada enemigo que está por pegarte.
var _marks := {}


func _init() -> void:
	metal = &"atium"
	cooldowns = {
		&"atium_shadows": SkillTree.ATIUM_SHADOWS_COOLDOWN, &"atium_guided": SkillTree.ATIUM_GUIDED_COOLDOWN,
		&"atium_eternal": SkillTree.ATIUM_ETERNAL_COOLDOWN,
	}


func _ready() -> void:
	player.dodged.connect(_on_dodged)


func active(id: StringName) -> bool:
	match id:
		&"atium_shadows":
			return Time.get_ticks_msec() < _shadows_until
		&"atium_eternal":
			return Time.get_ticks_msec() < _eternal_until
	return false


func _process(_delta: float) -> void:
	# Leer la pelea: la sombra de cada enemigo se ve más adelante.
	player.atium.shadow_lookahead = SkillTree.ATIUM_READ_LOOKAHEAD if passive(&"atium_read") else 0.6
	# Sombras y Momento eterno queman el atium solo mientras duran (el eterno, avivado: lo gasta muy rápido).
	var now := Time.get_ticks_msec()
	var a := player.allomancy
	if now < _eternal_until:
		if not a.is_flaring(&"atium"):
			a.set_state(&"atium", Allomancy.State.FLARE)
		_forced = true
	elif now < _shadows_until:
		if not a.is_burning(&"atium") or a.is_flaring(&"atium"):
			a.set_state(&"atium", Allomancy.State.BURN)
		_forced = true
	elif _forced:
		a.set_state(&"atium", Allomancy.State.OFF)
		_forced = false
	_read_marks()


## Leer la pelea: una marca roja sobre cada enemigo cercano que arrancó un golpe hacia vos.
func _read_marks() -> void:
	var on := {}
	if passive(&"atium_read"):
		for n in _near(player.global_position, SkillTree.ATIUM_READ_RANGE):
			if n.team != player.team and not n.is_tamed() and _attacking_player(n):
				on[n] = true
				if not is_instance_valid(_marks.get(n)):
					var label := Label3D.new()
					label.text = "!"
					label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
					label.no_depth_test = true
					label.fixed_size = true
					label.pixel_size = 0.002
					label.font_size = 48
					label.outline_size = 10
					label.modulate = Color(1.0, 0.2, 0.15)
					label.position = Vector3(0, n.head_y(0.7), 0)
					n.add_child(label)
					_marks[n] = label
	for n in _marks.keys():
		if not on.has(n):
			if is_instance_valid(_marks[n]):
				(_marks[n] as Node).queue_free()
			_marks.erase(n)


## Arrancó un golpe (la animación de ataque, o el combo del koloss) y te está mirando.
func _attacking_player(n: Npc) -> bool:
	var swinging := n.rig._attack > 0.0 or (n is Koloss and n._world_time < (n as Koloss)._busy_until)
	if not swinging:
		return false
	var to := player.global_position - n.global_position
	to.y = 0.0
	return to.length() > 0.01 and (-n.global_basis.z).dot(to.normalized()) > 0.5


## Leer la pelea: cuánto más largo es el aviso de un jefe antes de pegar (LordPowers.cast).
func warn_scale() -> float:
	return SkillTree.ATIUM_READ_WARN if passive(&"atium_read") else 1.0


## Después de una Esquiva perfecta, el siguiente golpe es crítico; en Momento eterno, todos.
func strike_bonus(_npc: Npc) -> float:
	var now := Time.get_ticks_msec()
	if now < _eternal_until:
		return Metals.CRIT_MULT
	if now < _crit_until:
		_crit_until = 0
		return Metals.CRIT_MULT
	return 1.0


func _on_dodged() -> void:
	if passive(&"atium_disarm"):
		var foe := player.last_dodged as Npc
		if foe and not foe.down and not foe.is_disarmed():
			foe.disarm(SkillTree.ATIUM_DISARM_TIME * scale(&"atium_disarm"))
			player.notice.emit("Desarme")
	if passive(&"atium_perfect"):
		_crit_until = Time.get_ticks_msec() + int(SkillTree.ATIUM_PERFECT_CRIT_WINDOW * 1000.0)
		_slow(SkillTree.ATIUM_PERFECT_SLOW, SkillTree.ATIUM_PERFECT_TIME)
		player.notice.emit("Esquiva perfecta")


func _use(id: StringName) -> bool:
	if player.allomancy.reserve[&"atium"] <= 0.0:
		player.notice.emit("Sin atium")
		return false
	match id:
		&"atium_shadows":
			return _shadows()
		&"atium_guided":
			return _guided()
		&"atium_eternal":
			return _eternal()
	return false


func _shadows() -> bool:
	_shadows_until = Time.get_ticks_msec() + int(SkillTree.ATIUM_SHADOWS_TIME * scale(&"atium_shadows") * 1000.0)
	player.atium.pulse()
	player.notice.emit("Sombras del futuro")
	return true


## Una moneda a cada enemigo distinto (hasta ATIUM_GUIDED_COUNT), que lo sigue hasta pegarle. Cada una gasta atium.
func _guided() -> bool:
	var cost := player.allomancy.max_reserve(&"atium") * SkillTree.ATIUM_GUIDED_COST
	var foes: Array[Npc] = []
	for n in _near(player.global_position, SkillTree.ATIUM_GUIDED_RANGE):
		if n.team != player.team and not n.is_tamed() and not n.surrendered and not n is Citizen:
			foes.append(n)
	foes.sort_custom(func(a: Npc, b: Npc) -> bool:
		return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
	var affordable := maxi(floori(player.allomancy.reserve[&"atium"] / cost), 1)
	foes = foes.slice(0, mini(mini(SkillTree.ATIUM_GUIDED_COUNT, player.coins_held), affordable))
	if foes.is_empty():
		player.notice.emit("Sin enemigos cerca" if player.coins_held > 0 else "Sin monedas")
		return false
	player.allomancy.reserve[&"atium"] = maxf(player.allomancy.reserve[&"atium"] - cost * foes.size(), 0.0)
	var start := player.chest_position() + player.aim_direction() * 0.6
	for foe in foes:
		var coin := player._spawn_coin(start) as Coin
		if coin == null:
			continue
		coin._homing = foe
		coin._homing_rolled = true
		coin.gravity_scale = 0.08
		coin.linear_velocity = (Metals.center_of(foe) - start).normalized() * SkillTree.ATIUM_GUIDED_SPEED
	player.rig.play_skill("coin_wave", 1.0)
	player.notice.emit("Monedas guiadas: %d" % foes.size())
	return true


func _eternal() -> bool:
	var time := SkillTree.ATIUM_ETERNAL_TIME * scale(&"atium_eternal")
	_eternal_until = Time.get_ticks_msec() + int(time * 1000.0)
	_slow(SkillTree.ATIUM_ETERNAL_SLOW, time)
	player.rig.play_skill("burn_focus", 1.0)
	player.atium.pulse()
	player.notice.emit("Momento eterno")
	return true


## Cámara lenta del mundo (el jugador la compensa: Player.real_delta). Solo fuera de red.
func _slow(scale_to: float, seconds: float) -> void:
	var net := get_node_or_null(^"/root/NetworkManager")
	if net and net.call(&"is_online"):
		return
	Engine.time_scale = minf(Engine.time_scale, scale_to)
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		if Time.get_ticks_msec() >= _eternal_until - 50:
			Engine.time_scale = 1.0)
