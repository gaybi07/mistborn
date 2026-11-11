extends TrainingRoom
## Sala pelada para probar personaje y poderes: piso, luz y vos, sin ciudad ni enemigos. Todos los poderes al máximo
## mientras estás acá (solo en memoria: al salir se devuelven los niveles de siempre, no se guarda nada).
## Ctrl+F8 desde cualquier escenario.

const SIZE := 80.0

var _saved_skills := {}
var _saved_direct := {}


func _ready() -> void:
	_saved_skills = Progression.skill_levels.duplicate()
	_saved_direct = Progression.direct_levels.duplicate()
	for s: Dictionary in SkillTree.SKILLS:
		Progression.skill_levels[s["id"]] = SkillTree.max_level(s["id"])
	for metal: StringName in Allomancy.METALS:
		if Progression.is_direct_metal(metal):
			Progression.direct_levels[metal] = Progression.metal_cap(metal)
	_build_base(Vector3(SIZE, 30, SIZE), Vector3(0, 1, 0))
	add_child(Props.static_box(Vector3(SIZE, 2, SIZE), Vector3(0, -1, 0), WorldKit.materials()["ground"]))
	_banner.text = "Sala de poderes  (Ctrl+F1: ciudad)"


func _exit_tree() -> void:
	Progression.skill_levels = _saved_skills
	Progression.direct_levels = _saved_direct
