extends Node
## Uso: Godot --path . res://tools/anim_check/slam_guard_check.tscn
## En la sala de poderes (sin enemigos), con Vin: hace el Martillazo y mide cuánto tarda en volver a la pose normal:
## cuándo termina el clip del poder y cuánto queda en guardia de combate (rig.brace) después.


func _ready() -> void:
	Art.player_model = "vin"
	var room: TrainingRoom = load("res://scenes/skill_room.tscn").instantiate()
	add_child(room)
	var tree := get_tree()
	for i in 60: await tree.physics_frame
	var player: Player = room.player
	player._combat_ms = -100000  # sin pelea previa
	player._skill_press(&"pewter_slam")
	for i in 3: await tree.physics_frame
	player._skill_release(&"pewter_slam")
	var t := 0.0
	var spell_end := -1.0
	var guard_end := 0.0
	while t < 9.0:
		await tree.physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if player.rig._spell <= 0.0 and spell_end < 0.0 and t > 0.2:
			spell_end = t
		if player.rig.brace > 0.0 or player.in_combat():
			guard_end = t
	print("clip del Martillazo hasta %.2f s; guardia de combate hasta %.2f s" % [spell_end, guard_end])
	print("RESULTADO: ", "bien" if guard_end <= spell_end + 0.05 else "queda en guardia %.1f s de más" % (guard_end - spell_end))
	tree.quit()
