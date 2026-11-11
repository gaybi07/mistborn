class_name BrassPowers
extends MetalPowers
## Poderes del latón del jugador (L8): Calma, Desaliento, Rendición, Sosegar multitud y Paz absoluta (activas) y Sosiego
## (pasiva: te ven desde menos distancia). El espejo frío del cinc: apaga a la gente en vez de moverla. Lo que siente
## cada NPC lo lleva Npc (soothe_for, dishearten_for, yield_to).


func _init() -> void:
	metal = &"brass"
	cooldowns = {
		&"brass_calm": SkillTree.BRASS_CALM_COOLDOWN, &"brass_dishearten": SkillTree.BRASS_DISHEARTEN_COOLDOWN,
		&"brass_yield": SkillTree.BRASS_YIELD_COOLDOWN, &"brass_crowd": SkillTree.BRASS_CROWD_COOLDOWN,
		&"brass_peace": SkillTree.BRASS_PEACE_COOLDOWN,
	}


## Sosiego: con latón encendido te ven desde la mitad de distancia.
func concealment() -> float:
	return SkillTree.BRASS_QUIET if passive(&"brass_quiet") else 1.0


## Sosiego: con latón encendido, quien está a BRASS_QUIET_AURA m de vos pelea con menos ganas (ver Npc.attack_delay_scale).
func soothing(pos: Vector3) -> bool:
	return passive(&"brass_quiet") and pos.distance_to(player.global_position) <= SkillTree.BRASS_QUIET_AURA


func _use(id: StringName) -> bool:
	match id:
		&"brass_calm":
			return _on_target(id, func(n: Npc) -> bool: return n.soothe_for(SkillTree.BRASS_CALM_TIME * scale(id)), "Calma", "clear_mind")
		&"brass_dishearten":
			return _on_target(id, func(n: Npc) -> bool: return n.dishearten_for(SkillTree.BRASS_DISHEARTEN_TIME * scale(id)), "Desaliento", "field")
		&"brass_yield":
			return _yield()
		&"brass_crowd":
			return _crowd()
		&"brass_peace":
			return _peace()
	return false


## Aplica `apply` al NPC de la mira; si lo resiste (cobre), avisa y no gasta la recarga.
func _on_target(_id: StringName, apply: Callable, label: String, gesture: String) -> bool:
	var npc := _target(SkillTree.ZINC_RANGE)
	if npc == null:
		return false
	if not apply.call(npc):
		player.notice.emit("Lo resiste")
		return false
	_fx(npc, gesture)
	player.notice.emit(label)
	return true


func _yield() -> bool:
	var npc := _target(SkillTree.ZINC_RANGE)
	if npc == null:
		return false
	if not npc.can_be_tamed():
		player.notice.emit("No se rinde")
		return false
	if npc.health > npc.max_health * SkillTree.BRASS_YIELD_HEALTH:
		player.notice.emit("Todavía tiene ganas de pelear (bajale la vida)")
		return false
	if not npc.yield_to(player, SkillTree.BRASS_YIELD_XP):
		player.notice.emit("Lo resiste")
		return false
	_fx(npc, "burn_focus")
	player.notice.emit("Se rinde")
	return true


func _crowd() -> bool:
	var count := 0
	for n in _cone(SkillTree.BRASS_CROWD_RANGE * scale(&"brass_crowd"), deg_to_rad(40.0)):
		if n.soothe_for(SkillTree.BRASS_CROWD_TIME * scale(&"brass_crowd")):
			count += 1
	player.rig.play_skill("field", 1.2)
	AirFx.wave(get_tree().current_scene, player.chest_position() + player.aim_direction() * 3.0, 4.0, _color(), 0.6, 0.03, null, true)
	player.notice.emit("Sosegar: %d se calman" % count)
	return true


## Nadie ataca a nadie: todos se calman; los jefes, que no se calman del todo, quedan desalentados.
func _peace() -> bool:
	var time := SkillTree.BRASS_PEACE_TIME * scale(&"brass_peace")
	for n in _near(player.global_position, SkillTree.BRASS_PEACE_RADIUS):
		if n.can_be_tamed():
			n.soothe_for(time)
		else:
			n.dishearten_for(time)
	player.rig.play_skill("clear_mind", 1.4)
	AirFx.wave(get_tree().current_scene, player.chest_position(), SkillTree.BRASS_PEACE_RADIUS, _color(), 0.9, 0.04, null, true)
	player.notice.emit("Paz absoluta")
	return true
