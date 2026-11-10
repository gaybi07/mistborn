class_name MensajeroMission
extends Mission
## Lo que come en el Bosque Muerto (Story "mensajero", de Tindwyl): el mensajero terrisano está rodeado de seis
## espectros. Hay que acabar con ellos y hablarle (Dialogues "mensajero_terris"); después se vuelve con Tindwyl.

const WRAITHS := 6

var _messenger: Mission.Survivor


func _begin() -> void:
	var c: Vector2 = Story.PLACES["bosque"]["at"]
	_messenger = Mission.Survivor.new()
	_messenger.home = Vector3(c.x, CityPlan.ground(c), c.y)
	_messenger.position = _messenger.home + Vector3.UP * 0.1
	add_child(_messenger)
	_messenger.add_child(Interactable.make(Vector3(2.4, 2.0, 2.4), Vector3(0, 1.0, 0), "Hablar con el mensajero",
			func() -> void: DialogueBox.open(get_tree(), "mensajero_terris")))
	for i in WRAITHS:
		var p := c + Vector2.from_angle(TAU * i / WRAITHS) * (10.0 + (i % 2) * 5.0)
		var w := MistWraith.new()
		w.home = Vector3(p.x, CityPlan.ground(p), p.y)
		w.position = w.home + Vector3.UP * 0.1
		w.roam_radius = 4.0
		add_child(w)
		_foes.append(w)


func target() -> Variant:
	return Vector2(_messenger.global_position.x, _messenger.global_position.z)


func _process(_delta: float) -> void:
	var left := foes_left()
	goal = "Acabar con los espectros (%d)" % left if left > 0 else "Hablar con el mensajero"
