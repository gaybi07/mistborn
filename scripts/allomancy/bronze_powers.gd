class_name BronzePowers
extends MetalPowers
## Poderes del bronce del jugador (L10, rehechos después de probarlos): leer al enemigo. Quemar bronce ya hace sentir los
## pulsos (BronzeSense) y leer qué metales quema cada uno, de cerca. Pulso (una onda que los marca de lejos, a través
## de las paredes), Anticipar (pasiva: aviso justo antes de que use un poder), Ritmo (pasiva: pegar en ese momento es
## crítico), Cazar (rompe las nubes de cobre y los muestra en la brújula y el mapa), Resonancia (pasiva: más daño a los
## que sentís) y Contrapulso (les apaga los metales).

## Medio segundo antes de que un alomántico ataque (su recarga, AllomancerNpc._cooldown), Anticipar avisa.
const FORESEE_LEAD := 0.5

var _pulse_until := 0
var _hunt_until := 0
## Carteles de lo que quema cada alomántico.
var _labels := {}
## Alománticos ya avisados en esta recarga (para no avisar en cada cuadro).
var _warned := {}
## Ritmo: hasta cuándo (ms) pegarle a cada uno es crítico.
var _rhythm_until := {}


func _init() -> void:
	metal = &"bronze"
	cooldowns = {
		&"bronze_pulse": SkillTree.BRONZE_PULSE_COOLDOWN, &"bronze_hunt": SkillTree.BRONZE_HUNT_COOLDOWN,
		&"bronze_counter": SkillTree.BRONZE_COUNTER_COOLDOWN,
	}


func active(id: StringName) -> bool:
	match id:
		&"bronze_pulse":
			return Time.get_ticks_msec() < _pulse_until
		&"bronze_hunt":
			return tracking()
	return false


## Cazar en marcha: la brújula y el mapa muestran a los alománticos (ver CompassBar y CityMap).
func tracking() -> bool:
	return Time.get_ticks_msec() < _hunt_until


## Alománticos a los que Cazar marca ahora.
func tracked() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if not tracking():
		return out
	for n in get_tree().get_nodes_in_group(&"allomancer"):
		var body := n as Node3D
		if body and not body.get(&"down") and body.global_position.distance_to(player.global_position) <= SkillTree.BRONZE_HUNT_RANGE:
			out.append(body)
	return out


func _process(_delta: float) -> void:
	var burning := player.allomancy.is_burning(metal)
	var pulsing := Time.get_ticks_msec() < _pulse_until
	var foreseeing := passive(&"bronze_foresee")
	var seen := {}
	if burning or pulsing:
		for n in get_tree().get_nodes_in_group(&"allomancer"):
			var npc := n as AllomancerNpc
			if npc == null or npc.down or not Metals.emits_pulses(npc):
				continue
			var d := npc.global_position.distance_to(player.global_position)
			var near := burning and d <= player.bronze_sense.sense_range
			if not near and not (pulsing and d <= SkillTree.BRONZE_PULSE_RANGE):
				continue
			seen[npc] = true
			_show_metals(npc, not near)
			if foreseeing and near:
				_foresee(npc)
	for npc in _labels.keys():
		if not seen.has(npc):
			if is_instance_valid(_labels[npc]):
				(_labels[npc] as Node).queue_free()
			_labels.erase(npc)


## Arriba de la cabeza, qué metales quema (se ve a través de las paredes). De lejos (por el Pulso), más grande.
func _show_metals(npc: AllomancerNpc, far: bool) -> void:
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
	label.text = ("◆ " if far else "") + " · ".join(names)
	label.modulate = Color(Allomancy.METALS[metal]["color"], 1.0).lightened(0.3)


## Anticipar: medio segundo antes de que ataque, un pulso fuerte sobre él (y abre la ventana del Ritmo).
func _foresee(npc: AllomancerNpc) -> void:
	var soon: bool = npc.target != null and npc._cooldown > 0.0 and npc._cooldown <= FORESEE_LEAD
	if soon and not _warned.has(npc):
		_warned[npc] = true
		_warn(npc, FORESEE_LEAD)
	elif not soon:
		_warned.erase(npc)


## Anticipar con el Lord Legislador: avisa cuando empieza a preparar un poder (LordPowers.cast), que cae a los `warn` s.
func foresee_lord(lord: Node3D, warn: float) -> void:
	if passive(&"bronze_foresee"):
		_warn(lord, warn)


func _warn(who: Node3D, lead: float) -> void:
	player.bronze_sense._spawn_pulse(who.global_position + Vector3(0, 1.1, 0), Color(1.0, 0.95, 0.6))
	AirFx.wave(get_tree().current_scene, who.global_position + Vector3(0, 1.2, 0), 1.6, Color(1.0, 0.9, 0.5, 0.35), 0.4, 0.03, null, true)
	_rhythm_until[who] = Time.get_ticks_msec() + int((lead + SkillTree.BRONZE_RHYTHM_WINDOW) * 1000.0)


## Ritmo: pegarle justo cuando avisó Anticipar es crítico. Resonancia: más daño a quien sentís quemar metales.
func strike_bonus(npc: Npc) -> float:
	var m := 1.0
	if passive(&"bronze_rhythm") and Time.get_ticks_msec() < int(_rhythm_until.get(npc, 0)):
		_rhythm_until.erase(npc)
		player.notice.emit("Ritmo: contraataque")
		m *= Metals.CRIT_MULT
	if passive(&"bronze_resonance") and npc is AllomancerNpc and Metals.emits_pulses(npc) \
			and npc.global_position.distance_to(player.global_position) <= player.bronze_sense.sense_range:
		m *= SkillTree.BRONZE_RESONANCE
	return m


func _use(id: StringName) -> bool:
	match id:
		&"bronze_pulse":
			return _pulse()
		&"bronze_hunt":
			return _hunt()
		&"bronze_counter":
			return _counter()
	return false


## Pulso: una onda que marca a los alománticos de lejos, aunque no quemes bronce.
func _pulse() -> bool:
	_pulse_until = Time.get_ticks_msec() + int(SkillTree.BRONZE_PULSE_TIME * scale(&"bronze_pulse") * 1000.0)
	var count := 0
	for n in _allomancers(SkillTree.BRONZE_PULSE_RANGE):
		if Metals.emits_pulses(n):
			count += 1
	player.rig.play_skill("field", 1.2)
	AirFx.wave(get_tree().current_scene, player.chest_position(), 8.0, _color(), 0.9, 0.04)
	player.notice.emit("Pulso: %d alománticos" % count)
	return true


## Cazar: rompe las nubes de cobre cercanas (los Humeadores no pueden quemar cobre un rato) y muestra a los alománticos
## en la brújula y el mapa.
func _hunt() -> bool:
	var time := SkillTree.BRONZE_HUNT_TIME * scale(&"bronze_hunt")
	var count := 0
	for n in _allomancers(SkillTree.BRONZE_HUNT_RADIUS):
		if n.allomancy.is_burning(&"copper"):
			count += 1
		n.allomancy.drain([&"copper"], time)
	_hunt_until = Time.get_ticks_msec() + int(time * 1000.0)
	player.rig.play_skill("extreme_senses", 1.4)
	AirFx.wave(get_tree().current_scene, player.chest_position(), SkillTree.BRONZE_HUNT_RADIUS, _color(), 0.8, 0.04, null, true)
	player.notice.emit("Cazar: %d alománticos cerca" % tracked().size() + (", %d nubes rotas" % count if count > 0 else ""))
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
