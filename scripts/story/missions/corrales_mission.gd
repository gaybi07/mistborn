class_name CorralesMission
extends Mission
## La deuda de los corrales (Story "corrales", de Tesa): el capataz y cuatro guardias junto al carbón. Hablando con el
## capataz se elige (Dialogues "capataz"): pagar 50 monedas, pelear (él y los guardias, hasta tumbarlos a todos) o no
## meterse y escuchar lo que sabe. Después se vuelve con Tesa.

var _capataz: Champion
var _fighting := false


func _begin() -> void:
	goal = "Hablar con el capataz"
	var c: Vector2 = Story.PLACES["corrales"]["at"]
	_capataz = soldier(c + Vector2(8, 5), 90.0, false)
	_capataz.add_child(Interactable.make(Vector3(2.6, 2.2, 2.6), Vector3(0, 1.1, 0), "Hablar con el capataz",
			func() -> void: DialogueBox.open(get_tree(), "capataz")))
	for off: Vector2 in [Vector2(12, 1), Vector2(11, 9), Vector2(4, 10), Vector2(14, 6)]:
		soldier(c + off, 60.0, false)


func event(name: String) -> void:
	if name == "pelea":
		_fighting = true
		goal = "Echar al capataz y a sus guardias"
		for f in _foes:
			if is_instance_valid(f):
				provoke(f as Champion)


func target() -> Variant:
	return Vector2(_capataz.global_position.x, _capataz.global_position.z) if is_instance_valid(_capataz) else null


func _physics_process(_delta: float) -> void:
	if not _done and _fighting and foes_left() == 0:
		win("pelear")
