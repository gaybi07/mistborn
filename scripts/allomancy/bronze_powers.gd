class_name BronzePowers
extends MetalPowers
## Poderes del bronce del jugador (L10): leer al enemigo. Pulsos (pasiva base: BronzeSense), Leer metales (pasiva: qué
## quema cada uno, arriba de su cabeza), Anticipar (pasiva: aviso justo antes de que use un poder), Pulso perturbador
## (rompe las nubes de cobre), Rastreo (los alománticos en la brújula y el mapa) y Contrapulso (les apaga los metales).

## Medio segundo antes de que un alomántico ataque (su recarga, AllomancerNpc._cooldown), Anticipar avisa.
const FORESEE_LEAD := 0.5

var _track_until := 0
## Carteles de Leer metales, por alomántico.
var _labels := {}
## Alománticos ya avisados en esta recarga (para no avisar en cada cuadro).
var _warned := {}


func _init() -> void:
	metal = &"bronze"
	cooldowns = {
		&"bronze_disrupt": SkillTree.BRONZE_DISRUPT_COOLDOWN, &"bronze_track": SkillTree.BRONZE_TRACK_COOLDOWN,
		&"bronze_counter": SkillTree.BRONZE_COUNTER_COOLDOWN,
	}


func active(id: StringName) -> bool:
	return id == &"bronze_track" and tracking()


## Rastreo en marcha: la brújula y el mapa muestran a los alománticos (ver CompassBar y CityMap).
func tracking() -> bool:
	return Time.get_ticks_msec() < _track_until


## Alománticos a los que el Rastreo marca ahora.
func tracked() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if not tracking():
		return out
	for n in get_tree().get_nodes_in_group(&"allomancer"):
		var body := n as Node3D
		if body and not body.get(&"down") and body.global_position.distance_to(player.global_position) <= SkillTree.BRONZE_TRACK_RANGE:
			out.append(body)
	return out


func _process(_delta: float) -> void:
	var reading := passive(&"bronze_read")
	var foreseeing := passive(&"bronze_foresee")
	var seen := {}
	if reading or foreseeing:
		for n in get_tree().get_nodes_in_group(&"allomancer"):
			var npc := n as AllomancerNpc
			if npc == null or npc.down or npc.global_position.distance_to(player.global_position) > player.bronze_sense.sense_range \
					or not Metals.emits_pulses(npc):
				continue
			seen[npc] = true
			if reading:
				_show_metals(npc)
			if foreseeing:
				_foresee(npc)
	for npc in _labels.keys():
		if not seen.has(npc) or not reading:
			if is_instance_valid(_labels[npc]):
				(_labels[npc] as Node).queue_free()
			_labels.erase(npc)


## Leer metales: arriba de la cabeza, qué metales quema (se ve a través de las paredes).
func _show_metals(npc: AllomancerNpc) -> void:
	var label: Label3D = _labels.get(npc)
	if not is_instance_valid(label):
		label = Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = 0.0012
		label.font_size = 26
		label.outline_size = 8
		label.position = Vector3(0, npc.head_y(0.55), 0)
		npc.add_child(label)
		_labels[npc] = label
	var names := PackedStringArray()
	for m: StringName in npc.allomancy.burning_metals():
		if m != &"copper":
			names.append(String(Allomancy.METALS[m]["label"]))
	label.text = " · ".join(names)
	label.modulate = Color(Allomancy.METALS[metal]["color"], 1.0).lightened(0.3)


## Anticipar: medio segundo antes de que ataque, un pulso fuerte sobre él.
func _foresee(npc: AllomancerNpc) -> void:
	var soon: bool = npc.target != null and npc._cooldown > 0.0 and npc._cooldown <= FORESEE_LEAD
	if soon and not _warned.has(npc):
		_warned[npc] = true
		player.bronze_sense._spawn_pulse(npc.global_position + Vector3(0, 1.1, 0), Color(1.0, 0.95, 0.6))
		AirFx.wave(get_tree().current_scene, npc.global_position + Vector3(0, 1.2, 0), 1.6, Color(1.0, 0.9, 0.5, 0.35), 0.4, 0.03, null, true)
	elif not soon:
		_warned.erase(npc)


func _use(id: StringName) -> bool:
	match id:
		&"bronze_disrupt":
			return _disrupt()
		&"bronze_track":
			return _track()
		&"bronze_counter":
			return _counter()
	return false


## Rompe las nubes de cobre cercanas: los Humeadores no pueden quemar cobre un rato y se ve a los que tapaban.
func _disrupt() -> bool:
	var count := 0
	for n in _allomancers(SkillTree.BRONZE_DISRUPT_RADIUS):
		if n.allomancy.is_burning(&"copper"):
			count += 1
		n.allomancy.drain([&"copper"], SkillTree.BRONZE_DISRUPT_TIME * scale(&"bronze_disrupt"))
	player.rig.play_skill("field", 1.2)
	AirFx.wave(get_tree().current_scene, player.chest_position(), SkillTree.BRONZE_DISRUPT_RADIUS, _color(), 0.8, 0.04, null, true)
	player.notice.emit("Pulso perturbador" + (": %d nubes rotas" % count if count > 0 else ""))
	return true


func _track() -> bool:
	_track_until = Time.get_ticks_msec() + int(SkillTree.BRONZE_TRACK_TIME * scale(&"bronze_track") * 1000.0)
	player.rig.play_skill("extreme_senses", 1.4)
	player.notice.emit("Rastreo: %d alománticos cerca" % tracked().size())
	return true


## Contrapulso: a los alománticos enemigos cercanos se les apagan todos los metales.
func _counter() -> bool:
	var time := SkillTree.BRONZE_COUNTER_TIME * scale(&"bronze_counter")
	var count := 0
	for n in _allomancers(SkillTree.BRONZE_COUNTER_RADIUS):
		if n.team != player.get(&"team") and not n.is_tamed():
			n.allomancy.drain(Allomancy.METALS.keys(), time)
			n.stun(0.4, player.global_position)
			count += 1
	player.rig.play_skill("mass_yank", 1.3)
	AirFx.wave(get_tree().current_scene, player.chest_position(), SkillTree.BRONZE_COUNTER_RADIUS, _color(), 0.7, 0.05, null, true)
	player.notice.emit("Contrapulso: %d sin metales" % count)
	return true


func _allomancers(radius: float) -> Array[AllomancerNpc]:
	var out: Array[AllomancerNpc] = []
	for n in get_tree().get_nodes_in_group(&"allomancer"):
		var npc := n as AllomancerNpc
		if npc and not npc.down and npc.global_position.distance_to(player.global_position) <= radius:
			out.append(npc)
	return out
