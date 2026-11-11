class_name FosoMission
extends Mission
## El foso de ceniza (Story "foso"): despertás en el fondo, al lado de un preso herido. Hay que subir por las rampas
## hasta la entrada de la empalizada; la patrulla (cuatro, en las terrazas) te salta encima si te acercás. El herido,
## si lo ayudás, te sigue despacio: llegar con él a la entrada es "salvar"; sin él, "dejar".

const NOTICE := 14.0  ## a cuánto te ve un guardia de la patrulla
const SAVED_NEAR := 12.0  ## a cuánto tiene que estar el herido al cruzar la entrada

var _herido: Mission.Survivor
var _exit := Vector2.ZERO


func _begin() -> void:
	goal = "Subir hasta la entrada del foso"
	var start := AshPit.on_bench(AshPit.WALLS - 1, 3.0)
	player.global_position = Vector3(start.x, CityPlan.ground(start) + 1.0, start.y)
	player.velocity = Vector3.ZERO
	_herido = Mission.Survivor.new()
	var at := start + Vector2(2.0, 1.0)
	_herido.home = Vector3(at.x, CityPlan.ground(at), at.y)
	_herido.position = _herido.home + Vector3.UP * 0.1
	add_child(_herido)
	_herido.add_child(Interactable.make(Vector3(2.4, 2.0, 2.4), Vector3(0, 1.0, 0), "Hablar con el preso herido",
			func() -> void: DialogueBox.open(get_tree(), "preso_herido")))
	for spot: Array in [[3, 4.6], [2, 3.0], [1, 1.6], [0, 0.6]]:
		soldier(AshPit.on_bench(spot[0], spot[1]), 50.0, false)
	_exit = AshPit.CENTER + Vector2(AshPit.rim_at(0.0) + AshPit.FENCE_OUT + 6.0, 0.0)


func event(name: String) -> void:
	if name == "seguir":
		_herido.follow = player
		goal = "Subir con el herido hasta la entrada del foso"


func target() -> Variant:
	return _exit


func _physics_process(_delta: float) -> void:
	if _done:
		return
	for f in _foes:
		if is_instance_valid(f) and f.global_position.distance_to(player.global_position) < Npc.sight(player, NOTICE):
			provoke(f as Champion)
	var here := Vector2(player.global_position.x, player.global_position.z)
	if here.distance_to(_exit) < 6.0:
		var with_him := _herido.follow != null and _herido.global_position.distance_to(player.global_position) < SAVED_NEAR
		win("salvar" if with_him else "dejar")
