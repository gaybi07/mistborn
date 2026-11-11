class_name ZincPowers
extends Node
## Poderes del cinc del jugador (L7, ver docs/arbol-de-habilidades.md): Furia, Pánico, Avaricia, Domar y Tormenta de
## emociones, cada uno un toque con recarga, y Contagio emocional (pasiva). Lo que siente cada NPC lo lleva Npc
## (riot_for, panic_for, greed_for, tame_for, rage_at); acá se elige a quién y se cuentan las recargas.

const IDS: Array[StringName] = [&"zinc_fury", &"zinc_panic", &"zinc_greed", &"zinc_tame", &"zinc_storm"]
const COOLDOWNS := {
	&"zinc_fury": SkillTree.ZINC_FURY_COOLDOWN, &"zinc_panic": SkillTree.ZINC_PANIC_COOLDOWN,
	&"zinc_greed": SkillTree.ZINC_GREED_COOLDOWN, &"zinc_tame": SkillTree.ZINC_TAME_COOLDOWN,
	&"zinc_storm": SkillTree.ZINC_STORM_COOLDOWN,
}
const NAMES := {&"zinc_fury": "Furia", &"zinc_panic": "Pánico", &"zinc_greed": "Avaricia", &"zinc_tame": "Domar",
		&"zinc_storm": "Tormenta de emociones"}
const COLOR := Color(0.85, 0.35, 0.3, 0.2)

var player: Player
var _ready_ms := {}
## El único NPC domado (domar a otro suelta a este).
var _tamed: Npc = null


func has(id: StringName) -> bool:
	return id in IDS


## Cuánto falta de la recarga (1 = recién usado, 0 = listo), para el HUD.
func cooldown(id: StringName) -> float:
	return clampf(float(int(_ready_ms.get(id, 0)) - Time.get_ticks_msec()) / (COOLDOWNS[id] * 1000.0), 0.0, 1.0)


func active(id: StringName) -> bool:
	return id == &"zinc_tame" and is_instance_valid(_tamed) and _tamed.is_tamed()


## Duración con el nivel del poder: la de nivel 1 y un ZINC_PER_LEVEL más por cada nivel.
static func scale(id: StringName) -> float:
	return 1.0 + SkillTree.ZINC_PER_LEVEL * maxi(Progression.skill_level(id) - 1, 0)


## Usa el poder. Devuelve si se usó (si no, no hay recarga ni se queda el metal encendido).
func use(id: StringName) -> bool:
	if player.dead:
		return false
	var now := Time.get_ticks_msec()
	if now < int(_ready_ms.get(id, 0)):
		player.notice.emit("%s recargando (%d s)" % [NAMES[id], ceili((int(_ready_ms[id]) - now) / 1000.0)])
		return false
	var ok := false
	match id:
		&"zinc_fury":
			ok = _fury()
		&"zinc_panic":
			ok = _panic()
		&"zinc_greed":
			ok = _greed()
		&"zinc_tame":
			ok = _tame()
		&"zinc_storm":
			ok = _storm()
	if ok:
		_ready_ms[id] = now + int(COOLDOWNS[id] * 1000.0)
	return ok


func _target() -> Npc:
	var npc := player._aim_npc(SkillTree.ZINC_RANGE)
	if npc == null:
		player.notice.emit("Apuntá a alguien")
	return npc


func _fury() -> bool:
	var npc := _target()
	if npc == null:
		return false
	var time := SkillTree.ZINC_FURY_TIME * scale(&"zinc_fury")
	if not npc.riot_for(time, player, SkillTree.ZINC_FURY_XP):
		player.notice.emit("Lo resiste")
		return false
	_spread(npc, func(n: Npc) -> void: n.riot_for(time * 0.5, player, SkillTree.ZINC_FURY_XP))
	_fx(npc, "hunter_mark")
	player.notice.emit("Furia")
	return true


func _panic() -> bool:
	var npc := _target()
	if npc == null:
		return false
	var time := SkillTree.ZINC_PANIC_TIME * scale(&"zinc_panic")
	if not npc.panic_for(time, player.global_position):
		player.notice.emit("Lo resiste")
		return false
	# Los que lo ven huir se asustan con la mitad.
	for n in _near(npc.global_position, SkillTree.ZINC_PANIC_SEEN):
		if n != npc:
			n.panic_for(time * 0.5, player.global_position)
	_spread(npc, func(n: Npc) -> void: n.panic_for(time * 0.5, player.global_position))
	_fx(npc, "field")
	player.notice.emit("Pánico")
	return true


func _greed() -> bool:
	if player.coins_held <= 0:
		player.notice.emit("Sin monedas")
		return false
	var point := player.aim_point(SkillTree.ZINC_RANGE)
	player.coins_held -= 1
	var coin := Props.coin()
	get_tree().current_scene.add_child(coin)
	coin.global_position = point + Vector3(0, 0.3, 0)
	get_tree().create_timer(90.0).timeout.connect(coin.queue_free)
	var time := SkillTree.ZINC_GREED_TIME * scale(&"zinc_greed")
	var count := 0
	for n in _near(point, SkillTree.ZINC_GREED_RADIUS):
		if n.greed_for(time, point):
			count += 1
	player.rig.play_throw()
	AirFx.wave(get_tree().current_scene, point + Vector3(0, 0.5, 0), SkillTree.ZINC_GREED_RADIUS * 0.4, COLOR, 0.6, 0.03, null, true)
	player.notice.emit("Avaricia: %d van por la moneda" % count if count > 0 else "Avaricia: nadie cerca")
	return true


func _tame() -> bool:
	var npc := _target()
	if npc == null:
		return false
	if not npc.can_be_tamed():
		player.notice.emit("No se deja domar")
		return false
	if is_instance_valid(_tamed) and _tamed != npc:
		_tamed.untame()
	if not npc.tame_for(SkillTree.ZINC_TAME_TIME * scale(&"zinc_tame"), player):
		player.notice.emit("Lo resiste")
		return false
	_tamed = npc
	_fx(npc, "burn_focus")
	player.notice.emit("Domado")
	return true


## A cada NPC cerca, la emoción que mejor le encaja: ira a los que pelean (se atacan entre ellos), pánico a los
## ciudadanos y lealtad al más débil de los que pelean.
func _storm() -> bool:
	var time := SkillTree.ZINC_STORM_TIME * scale(&"zinc_storm")
	var fighters: Array[Npc] = []
	var weakest: Npc = null
	for n in _near(player.global_position, SkillTree.ZINC_STORM_RADIUS):
		if n is Citizen:
			n.panic_for(time, player.global_position)
		elif n.feels_emotions():
			fighters.append(n)
			if n.can_be_tamed() and (weakest == null or n.max_health < weakest.max_health):
				weakest = n
	if fighters.size() > 1 and weakest:
		if is_instance_valid(_tamed) and _tamed != weakest:
			_tamed.untame()
		weakest.tame_for(time, player)
		_tamed = weakest
		fighters.erase(weakest)
	for n in fighters:
		n.riot_for(time, player, SkillTree.ZINC_FURY_XP)
		var foe := _closest(n, fighters)
		if foe:
			n.rage_at(foe, time)
	player.rig.play_skill("fury", 1.4)
	AirFx.wave(get_tree().current_scene, player.chest_position(), SkillTree.ZINC_STORM_RADIUS, COLOR, 0.9, 0.04, null, true)
	player.notice.emit("Tormenta de emociones")
	return true


## Contagio emocional (pasiva): pasa la emoción a los que están cerca del primero.
func _spread(from: Npc, apply: Callable) -> void:
	if Progression.skill_level(&"zinc_contagion") < 1:
		return
	for n in _near(from.global_position, SkillTree.ZINC_CONTAGION_RADIUS * scale(&"zinc_contagion")):
		if n != from:
			apply.call(n)


func _near(center: Vector3, radius: float) -> Array[Npc]:
	var out: Array[Npc] = []
	for n in get_tree().get_nodes_in_group(&"npc"):
		var npc := n as Npc
		if npc and not npc.down and npc.global_position.distance_to(center) <= radius:
			out.append(npc)
	return out


func _closest(npc: Npc, among: Array[Npc]) -> Npc:
	var best: Npc = null
	var best_d := INF
	for other in among:
		var d := other.global_position.distance_to(npc.global_position)
		if other != npc and d < best_d:
			best = other
			best_d = d
	return best


## Gesto del jugador (clip provisorio, ver Pedidos de animación en docs/TAREAS.md) y la onda sobre el NPC.
func _fx(npc: Npc, gesture: String) -> void:
	player.rig.play_skill(gesture, 1.2)
	AirFx.wave(get_tree().current_scene, npc.global_position + Vector3(0, 1.2, 0), 2.0, COLOR, 0.5, 0.03, null, true)
