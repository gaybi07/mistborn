extends SceneTree
## Prueba del sótano del taller: con la trampilla cerrada (y el armario encima), desde el pie de la escalera aparece
## "Abrir la trampilla" y al usarla se abre: nadie queda encerrado abajo. Con ventana:
## Godot --path . -s tools/world/workshop_check.gd
var _fails := 0


func _initialize() -> void:
	var prog := FileAccess.get_file_as_bytes("user://progression.cfg")
	Art.player_model = "vin"
	SaveSlots.current = 9
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(5.0).timeout
	var p := get_first_node_in_group(&"player") as Player
	var w: Workshop = root.find_children("*", "Workshop", true, false)[0]
	_ok(w._secret == 0, "al empezar, el armario tapa la trampilla")
	var foot := w.to_global(Vector3((Workshop.STAIR_X.x + Workshop.STAIR_X.y) / 2.0, -Workshop.DEPTH + 1.0, Workshop.STAIR_TOP + Workshop.STAIR_RUN + 0.4))
	p.global_position = foot
	p.velocity = Vector3.ZERO
	await create_timer(1.5).timeout
	_ok(p.interactable == w._below_zone, "al pie de la escalera del sótano se ve \"Abrir la trampilla\"")
	if p.interactable:
		p.interactable.use()
	await create_timer(2.5).timeout
	_ok(w._secret == 2 and absf(w._trapdoor.rotation.z) > 1.4, "la trampilla queda abierta")
	if not prog.is_empty():
		FileAccess.open("user://progression.cfg", FileAccess.WRITE).store_buffer(prog)
	print("FALLAS ", _fails)
	quit(1 if _fails > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FALLA ") + what)
	if not cond:
		_fails += 1
