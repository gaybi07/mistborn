extends TrainingRoom
## Sala pelada para probar personaje y poderes: piso, luz y vos, sin ciudad ni enemigos. Todos los metales al máximo
## mientras estás acá (solo en memoria: al salir se devuelven los niveles de siempre, no se guarda nada).
## Ctrl+F8 desde cualquier escenario.

const SIZE := 80.0

var _saved_levels := {}


func _ready() -> void:
	_saved_levels = Progression.metal_levels.duplicate()
	for metal: StringName in Progression.metal_levels:
		Progression.metal_levels[metal] = Progression.metal_cap(metal)
	_build_base(Vector3(SIZE, 30, SIZE), Vector3(0, 1, 0))
	add_child(Props.static_box(Vector3(SIZE, 2, SIZE), Vector3(0, -1, 0), WorldKit.materials()["ground"]))
	_banner.text = "Sala de poderes  (Ctrl+F1: ciudad)"


func _exit_tree() -> void:
	if not _saved_levels.is_empty():
		Progression.metal_levels = _saved_levels
