extends SceneTree
## Vin (Player de verdad) pega una vez con cada arma y cada golpe del combo; civiles quietos alrededor a distintas
## distancias y ángulos. Dice a quién le sacó vida.
const SPOTS := {"frente 0.8": Vector3(0, 0, -0.8), "frente 1.2": Vector3(0, 0, -1.2), "frente 1.6": Vector3(0, 0, -1.6),
	"frente 2.2": Vector3(0, 0, -2.2), "diagonal 1.2": Vector3(0.85, 0, -0.85), "costado 1.0": Vector3(1.0, 0, 0),
	"atrás 1.0": Vector3(0, 0, 1.0)}
func _init() -> void:
	var w := Node3D.new(); root.add_child(w); current_scene = w
	var floor := StaticBody3D.new(); floor.collision_layer = Props.LAYER_WORLD
	var cs := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(60, 1, 60); cs.shape = box
	floor.add_child(cs); floor.position.y = -0.5; w.add_child(floor)
	var player := Player.new()
	w.add_child(player)
	for i in 30: await physics_frame
	Art.player_model = "vin"  # sin guardar la elección
	player.rig.queue_free()
	player._add_rig()
	player._apply_equipment()
	var npcs := {}
	for name in SPOTS:
		var c := Citizen.new()
		w.add_child(c)
		c.global_position = player.global_position + SPOTS[name]
		npcs[name] = c
	for i in 30: await physics_frame
	for n in npcs.values():
		(n as Node).process_mode = Node.PROCESS_MODE_DISABLED
	for wp in [["puños", 0], ["dagas", 1], ["espada", 2]]:
		for step in (4 if wp[1] != 2 else 5):
			for name in npcs:
				npcs[name].global_position = player.global_position + SPOTS[name]
				npcs[name].velocity = Vector3.ZERO
				npcs[name].health = 9999.0; npcs[name].down = false
			player.weapon = wp[1]
			player._fists_chosen = wp[1] == 0
			player.rig.set_weapon(wp[1])
			player._attack_cd = 0.0; player._commit_t = 0.0
			player._combo = step - 1; player._combo_window = 1.0 if step > 0 else 0.0
			player.stamina = 999.0
			player.visual.rotation.y = 0.0
			player.attack()
			for i in 60: await physics_frame
			var hit := []
			for name in npcs:
				if npcs[name].health < 9999.0: hit.append(name)
			print("%-6s golpe %d -> %s" % [wp[0], step, ", ".join(hit) if hit else "nadie"])
			for i in 40: await physics_frame
			for name in npcs:
				npcs[name].global_position = player.global_position + SPOTS[name]
				npcs[name].velocity = Vector3.ZERO
	quit()
