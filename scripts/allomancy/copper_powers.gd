class_name CopperPowers
extends MetalPowers
## Poderes del cobre del jugador (L9): sigilo y defensa contra la alomancia. Nube de cobre (pasiva base: lo de siempre),
## Silencio (pasiva: te ven desde menos lejos y el estaño ajeno no ayuda), Desvanecerse (te pierden y el siguiente golpe
## es a traición), Nube compartida (tu domado queda bajo tu nube), Mente cerrada (pasiva: lo emocional ajeno dura la
## mitad, aunque no quemes cobre) y Fantasma (nadie te ve; atacar lo termina con un crítico).

## Golpe a traición pendiente (Desvanecerse) y Fantasma en marcha (ms del reloj).
var _ambush_until := 0
var _ghost_until := 0


func _init() -> void:
	metal = &"copper"
	cooldowns = {
		&"copper_vanish": SkillTree.COPPER_VANISH_COOLDOWN, &"copper_shared": SkillTree.COPPER_SHARED_COOLDOWN,
		&"copper_ghost": SkillTree.COPPER_GHOST_COOLDOWN,
	}


func active(id: StringName) -> bool:
	return id == &"copper_ghost" and _ghosting()


func _ghosting() -> bool:
	return Time.get_ticks_msec() < _ghost_until


## Silencio (con cobre encendido) y Fantasma (nadie te ve).
func concealment() -> float:
	if _ghosting():
		return 0.0
	return SkillTree.COPPER_SILENCE if passive(&"copper_silence") else 1.0


## Mente cerrada: no hace falta quemar cobre, es un hábito de la mente.
func emotion_resist() -> float:
	return SkillTree.COPPER_CLOSED_MIND if Progression.skill_level(&"copper_closed_mind") >= 1 else 1.0


## Atacar desde Fantasma es un crítico y lo termina; después de Desvanecerse, el primer golpe es a traición.
func strike_bonus(_npc: Npc) -> float:
	var now := Time.get_ticks_msec()
	if now < _ghost_until:
		_ghost_until = 0
		player.notice.emit("Golpe desde las sombras")
		return SkillTree.COPPER_GHOST_STRIKE
	if now < _ambush_until:
		_ambush_until = 0
		return SkillTree.COPPER_AMBUSH
	return 1.0


func _physics_process(_delta: float) -> void:
	# Fantasma: mientras dura, los que te venían siguiendo te siguen perdiendo.
	if _ghosting():
		for n in _near(player.global_position, SkillTree.COPPER_VANISH_RADIUS):
			n.lose_track(0.5)


func _use(id: StringName) -> bool:
	match id:
		&"copper_vanish":
			return _vanish()
		&"copper_shared":
			return _shared()
		&"copper_ghost":
			return _ghost()
	return false


func _vanish() -> bool:
	var time := SkillTree.COPPER_VANISH_TIME * scale(&"copper_vanish")
	for n in _near(player.global_position, SkillTree.COPPER_VANISH_RADIUS):
		n.lose_track(time)
	_ambush_until = Time.get_ticks_msec() + int((time + SkillTree.COPPER_AMBUSH_GRACE) * 1000.0)
	player.rig.play_skill("burn_focus", 1.0)
	AirFx.cloud(get_tree().current_scene, player.chest_position(), 1.6, _color(), 1.2, 6, 0.6)
	player.notice.emit("Te desvanecés")
	return true


func _shared() -> bool:
	var time := SkillTree.COPPER_SHARED_TIME * scale(&"copper_shared")
	var count := 0
	for n in _near(player.global_position, SkillTree.COPPER_SHARED_RADIUS):
		if n.tamed_by == player:
			n.cloud_for(time)
			count += 1
	player.rig.play_skill("field", 1.2)
	AirFx.wave(get_tree().current_scene, player.chest_position(), SkillTree.COPPER_SHARED_RADIUS, _color(), 0.8, 0.03, null, true)
	player.notice.emit("Nube compartida" + (" (%d aliados)" % count if count > 0 else ""))
	return true


func _ghost() -> bool:
	_ghost_until = Time.get_ticks_msec() + int(SkillTree.COPPER_GHOST_TIME * scale(&"copper_ghost") * 1000.0)
	for n in _near(player.global_position, SkillTree.COPPER_VANISH_RADIUS):
		n.lose_track(0.5)
	player.rig.play_skill("burn_focus", 1.2)
	AirFx.shell(player, _color(), 0.9, _ghosting, 1.2, 4)
	player.notice.emit("Fantasma")
	return true
