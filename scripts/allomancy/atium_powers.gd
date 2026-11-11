class_name AtiumPowers
extends MetalPowers
## Poderes del atium del jugador (L11): más preciso y más espectacular, no más barato (cada nivel cuesta 2 puntos).
## Sombras del futuro (pasiva base: Atium), Esquiva perfecta (al esquivar con atium, cámara lenta y el siguiente golpe
## es crítico), Golpe certero (más críticos y aturden), Monedas guiadas (una a cada enemigo), Leer la pelea (avisos de
## los jefes más temprano, sombra más adelantada) y Momento eterno (el mundo casi se detiene).
## La cámara lenta es solo fuera de red: con otros jugadores el atium tiene que funcionar en tiempo real (ver Atium).

## Golpe crítico pendiente (Esquiva perfecta) y Momento eterno en marcha (ms del reloj).
var _crit_until := 0
var _eternal_until := 0
var _was_eternal := false


func _init() -> void:
	metal = &"atium"
	cooldowns = {&"atium_guided": SkillTree.ATIUM_GUIDED_COOLDOWN, &"atium_eternal": SkillTree.ATIUM_ETERNAL_COOLDOWN}


func _ready() -> void:
	player.dodged.connect(_on_dodged)


func active(id: StringName) -> bool:
	return id == &"atium_eternal" and Time.get_ticks_msec() < _eternal_until


func _process(_delta: float) -> void:
	# Leer la pelea: la sombra de cada enemigo se ve más adelante.
	player.atium.shadow_lookahead = SkillTree.ATIUM_READ_LOOKAHEAD if passive(&"atium_read") else 0.6
	var eternal := Time.get_ticks_msec() < _eternal_until
	if eternal:
		player.allomancy.set_state(&"atium", Allomancy.State.FLARE)  # gasta el atium muy rápido
	elif _was_eternal:
		player.allomancy.set_state(&"atium", Allomancy.State.OFF)
	_was_eternal = eternal


## Golpe certero: más probabilidad de crítico con atium encendido (Metals.crit_chance).
func crit_bonus() -> float:
	return SkillTree.ATIUM_SURE_CRIT if passive(&"atium_sure") else 0.0


## Golpe certero: el crítico aturde (los jefes, menos).
func crit_stun(npc: Npc) -> float:
	if not passive(&"atium_sure"):
		return 0.0
	return SkillTree.ATIUM_SURE_STUN if npc.can_be_tamed() else SkillTree.ATIUM_SURE_STUN * 0.4


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
	if not passive(&"atium_perfect"):
		return
	_crit_until = Time.get_ticks_msec() + int(SkillTree.ATIUM_PERFECT_CRIT_WINDOW * 1000.0)
	_slow(SkillTree.ATIUM_PERFECT_SLOW, SkillTree.ATIUM_PERFECT_TIME)
	player.notice.emit("Esquiva perfecta")


func _use(id: StringName) -> bool:
	match id:
		&"atium_guided":
			return _guided()
		&"atium_eternal":
			return _eternal()
	return false


## Una moneda a cada enemigo distinto (hasta ATIUM_GUIDED_COUNT), que lo sigue hasta pegarle.
func _guided() -> bool:
	var foes: Array[Npc] = []
	for n in _near(player.global_position, SkillTree.ATIUM_GUIDED_RANGE):
		if n.team != player.team and not n.is_tamed() and not n.surrendered and not n is Citizen:
			foes.append(n)
	foes.sort_custom(func(a: Npc, b: Npc) -> bool:
		return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
	foes = foes.slice(0, mini(SkillTree.ATIUM_GUIDED_COUNT, player.coins_held))
	if foes.is_empty():
		player.notice.emit("Sin enemigos cerca" if player.coins_held > 0 else "Sin monedas")
		return false
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
