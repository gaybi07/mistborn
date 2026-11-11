extends Node
## Uso: Godot --headless --path . res://tools/anim_check/power_rework_check.tscn
## (escena y no -s: la sala de poderes lleva el HUD, que necesita los autoloads).
## Los poderes rehechos del latón, el cobre, el bronce y el atium, en la sala de poderes (todo al máximo, en memoria):
## - Sosiego: cerca, los NPC pegan menos seguido; lejos, igual que siempre;
## - Señuelo: los enemigos van a la nube; Golpe a traición: +50 % a quien no estaba peleando, nada después;
## - Ritmo y Resonancia: pegar en el aviso de Anticipar es crítico; Cazar marca a los alománticos;
## - Sombras del futuro enciende el atium y lo apaga al terminar; Monedas guiadas gasta atium; Desarme; Leer la pelea.
## La primera habilidad del cobre, el bronce y el atium es activa. Sale con código 1 si falla alguna.

var _fails := 0
var _room: TrainingRoom
var _player: Player


func _ready() -> void:
	Art.player_model = "vin"
	SaveSlots.current = 1
	_room = load("res://scenes/skill_room.tscn").instantiate()
	_room.set(&"open_menu", false)
	add_child(_room)
	for i in 30: await get_tree().physics_frame
	_player = _room.player
	for metal in [&"copper", &"bronze", &"atium"]:
		var first: StringName = SkillTree.LAYOUTS[&"allomancy"][metal][0][0]
		_expect(SkillTree.find(first)["kind"] == SkillTree.Kind.ACTIVE, "la primera del %s es activa" % metal)
	await _brass()
	await _copper()
	await _bronze()
	await _atium()
	print("power_rework_check: %s" % ("OK" if _fails == 0 else "%d fallas" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _expect(ok: bool, what: String) -> void:
	print(("OK    " if ok else "FALLA ") + what)
	if not ok:
		_fails += 1


func _npcs() -> Array[Npc]:
	var out: Array[Npc] = []
	for n in get_tree().get_nodes_in_group(&"npc"):
		if n is Npc and not n.is_queued_for_deletion():
			out.append(n)
	return out


func _setup(metal: StringName) -> void:
	_room.setup(metal)
	for i in 10: await get_tree().physics_frame


func _burn(metal: StringName) -> void:
	_player.allomancy.reserve[metal] = _player.allomancy.max_reserve(metal)
	_player.allomancy.set_state(metal, Allomancy.State.BURN)


func _brass() -> void:
	await _setup(&"copper")
	var npc := _npcs()[0]
	_burn(&"brass")
	npc.global_position = _player.global_position + Vector3(3, 0, 0)
	_expect(is_equal_approx(npc.attack_delay_scale(), 1.0 / SkillTree.BRASS_QUIET_ATTACK), "Sosiego: a 3 m pega menos seguido")
	npc.global_position = _player.global_position + Vector3(20, 0, 0)
	_expect(npc.attack_delay_scale() == 1.0, "Sosiego: a 20 m, como siempre")
	_player.allomancy.set_state(&"brass", Allomancy.State.OFF)


func _copper() -> void:
	await _setup(&"copper")
	_burn(&"copper")
	var foes := _npcs().filter(func(n: Npc) -> bool: return n.team != _player.team and not n is Citizen)
	for n: Npc in foes:
		n.global_position = _player.global_position + Vector3(randf_range(-8, 8), 0, -10)
	_expect(_player.copper.use(&"copper_decoy"), "Señuelo se usa")
	var lured := foes.filter(func(n: Npc) -> bool: return n._greed_until > n._world_time)
	_expect(lured.size() == foes.size(), "Señuelo: %d de %d van a la nube" % [lured.size(), foes.size()])
	var fresh: Npc = foes[0]
	fresh._combat_ms = -100000
	fresh._lost_until = -1.0
	_expect(is_equal_approx(_player.copper.strike_bonus(fresh), SkillTree.COPPER_AMBUSH), "Golpe a traición a quien no peleaba")
	fresh.mark_combat()
	_expect(_player.copper.strike_bonus(fresh) == 1.0, "en pelea y viéndote, sin traición")
	fresh.lose_track(3.0)
	_expect(is_equal_approx(_player.copper.strike_bonus(fresh), SkillTree.COPPER_AMBUSH), "Golpe a traición a quien te perdió")
	_player.allomancy.set_state(&"copper", Allomancy.State.OFF)


func _bronze() -> void:
	await _setup(&"bronze")
	_burn(&"bronze")
	var foe: AllomancerNpc = null
	# El Humeador tapa a los de al lado con su nube: lejos. Al resto le prende lo que pueda quemar.
	for n in _npcs():
		var al := n as AllomancerNpc
		if al == null:
			continue
		if al.allomancy.is_burning(&"copper"):
			al.global_position += Vector3(0, 0, -200)
			continue
		for m in Allomancy.METALS:
			if m != &"copper" and m != &"atium":
				al.allomancy.reserve[m] = 50.0
				al.allomancy.set_state(m, Allomancy.State.BURN)
		if foe == null and al.allomancy.burning_metals().size() > 0:
			foe = al
	_expect(foe != null, "hay un alomántico que quema metales")
	if foe == null:
		return
	foe.global_position = _player.global_position + Vector3(0, 0, -4)
	_expect(Metals.emits_pulses(foe), "y el bronce lo siente")
	_player.bronze._warn(foe, 0.5)
	var hit := _player.bronze.strike_bonus(foe)
	_expect(is_equal_approx(hit, Metals.CRIT_MULT * SkillTree.BRONZE_RESONANCE), "Ritmo + Resonancia: x%.2f" % hit)
	hit = _player.bronze.strike_bonus(foe)
	_expect(is_equal_approx(hit, SkillTree.BRONZE_RESONANCE), "sin aviso, solo Resonancia: x%.2f" % hit)
	_expect(_player.bronze.use(&"bronze_hunt") and _player.bronze.tracking() and _player.bronze.tracked().size() > 0, "Cazar marca a los alománticos")
	_player.allomancy.set_state(&"bronze", Allomancy.State.OFF)
	_expect(_player.bronze.use(&"bronze_pulse"), "Pulso se usa sin quemar bronce")
	for i in 3: await get_tree().process_frame
	_expect(not _player.bronze._labels.is_empty(), "Pulso: carteles de lejos")


func _atium() -> void:
	await _setup(&"atium")
	var a := _player.allomancy
	a.reserve[&"atium"] = a.max_reserve(&"atium")
	_expect(_player.atium_powers.use(&"atium_shadows"), "Sombras del futuro se usa")
	for i in 3: await get_tree().process_frame
	_expect(a.is_burning(&"atium"), "Sombras enciende el atium")
	_player.atium_powers._shadows_until = 0
	for i in 3: await get_tree().process_frame
	_expect(not a.is_burning(&"atium"), "al terminar, lo apaga")
	var before: float = a.reserve[&"atium"]
	_player.coins_held = 20
	var foes := _npcs().filter(func(n: Npc) -> bool: return n.team != _player.team)
	for n: Npc in foes:
		n.global_position = _player.global_position + Vector3(randf_range(-6, 6), 0, -8)
	_expect(_player.atium_powers.use(&"atium_guided"), "Monedas guiadas se usa")
	var spent := before - float(a.reserve[&"atium"])
	var want := a.max_reserve(&"atium") * SkillTree.ATIUM_GUIDED_COST * mini(foes.size(), SkillTree.ATIUM_GUIDED_COUNT)
	_expect(is_equal_approx(spent, want), "Monedas guiadas gasta %.1f de atium (esperado %.1f)" % [spent, want])
	_burn(&"atium")
	var foe: Npc = foes[0]
	_player.last_dodged = foe
	_player.dodged.emit()
	_expect(foe.is_disarmed(), "Desarme: el que te atacó pierde el arma")
	Engine.time_scale = 1.0
	foe.global_position = _player.global_position + Vector3(0, 0, -3)
	foe.look_at(_player.global_position, Vector3.UP)
	foe.rig._attack = 1.0
	_player.atium_powers._read_marks()
	_expect(_player.atium_powers._marks.has(foe), "Leer la pelea marca al que te va a pegar")
