class_name CopperPowers
extends MetalPowers
## Poderes del cobre del jugador (L9): sigilo y defensa contra la alomancia. La nube de siempre viene con quemar cobre.
## Desvanecerse (te pierden y el siguiente golpe es a traición), Señuelo (una nube falsa que los atrae y encandila),
## Golpe a traición (pasiva: más daño a quien no te ve), Nube compartida (tu domado queda bajo tu nube), Mente cerrada
## (pasiva: lo emocional ajeno dura la mitad, aunque no quemes cobre) y Fantasma (nadie te ve; atacar lo termina con un crítico).

## Golpe a traición pendiente (Desvanecerse) y Fantasma en marcha (ms del reloj).
var _ambush_until := 0
var _ghost_until := 0
## Señuelo: dónde está, hasta cuándo y a quiénes ya encandiló.
var _decoy_at := Vector3.ZERO
var _decoy_until := 0
var _decoy_hit := {}


func _init() -> void:
	metal = &"copper"
	cooldowns = {
		&"copper_vanish": SkillTree.COPPER_VANISH_COOLDOWN, &"copper_decoy": SkillTree.COPPER_DECOY_COOLDOWN,
		&"copper_shared": SkillTree.COPPER_SHARED_COOLDOWN,
		&"copper_ghost": SkillTree.COPPER_GHOST_COOLDOWN,
	}


func active(id: StringName) -> bool:
	return id == &"copper_ghost" and _ghosting()


func _ghosting() -> bool:
	return Time.get_ticks_msec() < _ghost_until


## Fantasma: nadie te ve.
func concealment() -> float:
	return 0.0 if _ghosting() else 1.0


## Mente cerrada: no hace falta quemar cobre, es un hábito de la mente.
func emotion_resist() -> float:
	return SkillTree.COPPER_CLOSED_MIND if Progression.skill_level(&"copper_closed_mind") >= 1 else 1.0


## Atacar desde Fantasma es un crítico y lo termina; después de Desvanecerse, el primer golpe es a traición; con Golpe a
## traición, también el golpe a quien no te ve (Npc.take_hit lo pregunta antes de marcarlo en combate).
func strike_bonus(npc: Npc) -> float:
	var now := Time.get_ticks_msec()
	if now < _ghost_until:
		_ghost_until = 0
		player.notice.emit("Golpe desde las sombras")
		return SkillTree.COPPER_GHOST_STRIKE
	if now < _ambush_until:
		_ambush_until = 0
		return SkillTree.COPPER_AMBUSH
	if passive(&"copper_ambush") and (not npc.in_combat() or npc.lost_track()):
		return SkillTree.COPPER_AMBUSH
	return 1.0


func _physics_process(_delta: float) -> void:
	_decoy_tick()
	# Fantasma: mientras dura, los que te venían siguiendo te siguen perdiendo.
	if _ghosting():
		for n in _near(player.global_position, SkillTree.COPPER_VANISH_RADIUS):
			n.lose_track(0.5)


func _use(id: StringName) -> bool:
	match id:
		&"copper_vanish":
			return _vanish()
		&"copper_decoy":
			return _decoy()
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


## Señuelo: una nube falsa donde estás; los enemigos cercanos van hacia ella (Npc.lure_to) y al que llega lo encandila.
func _decoy() -> bool:
	var time := SkillTree.COPPER_DECOY_TIME * scale(&"copper_decoy")
	_decoy_at = player.global_position
	_decoy_until = Time.get_ticks_msec() + int(time * 1000.0)
	_decoy_hit.clear()
	var count := 0
	for n in _near(_decoy_at, SkillTree.COPPER_DECOY_RADIUS):
		if n.team != player.team and not n.is_tamed() and not n is Citizen and n.lure_to(_decoy_at, time):
			count += 1
	player.rig.play_skill("burn_focus", 1.0)
	AirFx.cloud(get_tree().current_scene, _decoy_at + Vector3(0, 1.0, 0), 2.2, _color(), time, 8, 0.15)
	player.notice.emit("Señuelo" + (": %d lo siguen" % count if count > 0 else ""))
	return true


func _decoy_tick() -> void:
	if Time.get_ticks_msec() >= _decoy_until:
		return
	for n in _near(_decoy_at, 1.8):
		if n.team != player.team and not _decoy_hit.has(n):
			_decoy_hit[n] = true
			n.stun(SkillTree.COPPER_DECOY_STUN, _decoy_at)
			AirFx.cloud(get_tree().current_scene, n.global_position + Vector3(0, 1.4, 0), 1.2, _color(), 0.8, 4, 0.8)
