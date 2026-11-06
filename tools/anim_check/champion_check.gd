extends SceneTree
## Cada Champion con poderes (koloss, inquisidor, obligador) tira cada poder de su kit contra Vin, quieta a la distancia
## del medio de su alcance. Con "esquivar", Vin se corre 8 m al costado 0,15 s antes de que se llene el aviso.
## Dice cuánta vida le sacó y cuánto aviso tuvo. Uso: -- [kit,...|all] [esquivar]
const DT := 1.0 / 60.0
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var kits: Array = ["KolossAdulto", "KolossJoven", "MistbornHood", "Obligador"] if a.size() == 0 or a[0] == "all" else Array(a[0].split(","))
	var dodge := a.size() > 1 and a[1] == "esquivar"
	var w := Node3D.new(); root.add_child(w); current_scene = w
	var floor := StaticBody3D.new(); floor.collision_layer = Props.LAYER_WORLD
	var cs := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(80, 1, 80); cs.shape = box
	floor.add_child(cs); floor.position.y = -0.5; w.add_child(floor)
	var player := Player.new()
	w.add_child(player)
	for i in 20: await physics_frame
	for kit: String in kits:
		var foe := Champion.new()
		foe.kit = kit
		w.add_child(foe)
		for i in 60: await physics_frame
		for p: Dictionary in Champion.KITS[kit]["powers"]:
			if p["kind"] == "heal":
				continue
			var dist: float = clampf((p["range"][0] + p["range"][1]) * 0.5, 2.5, 9.0)
			player.health = player.max_health; player.dead = false
			player.global_position = Vector3.ZERO; player.velocity = Vector3.ZERO
			foe.global_position = Vector3(0, 0, -dist); foe.velocity = Vector3.ZERO
			foe.look_at(Vector3(0, foe.global_position.y, 0.001))
			foe._foe = player; foe._player = player; foe._busy_until = 0.0
			var hp0: float = player.health
			foe._power(p, dist)
			var warn := -1.0
			var t := 0.0
			var moved := false
			while t < 4.0:
				foe._foe = player
				foe._next_blow = INF
				foe._next_power = INF
				# El aviso que salió: cuándo termina de llenarse.
				if warn < 0.0:
					for n in w.get_children():
						if n is Telegraph and (n as Telegraph).time < 1e5:
							warn = (n as Telegraph).time
				if dodge and not moved and warn > 0.0 and t >= warn - 0.15:
					player.global_position += Vector3(8, 0, 0)
					moved = true
				await physics_frame
				t += DT
			print("%-13s %-18s %-5s aviso %.2f s  vida %.0f -> %.0f" % [kit, p["name"], p["kind"], warn, hp0, player.health])
			for i in 30: await physics_frame
		foe.queue_free()
		for i in 5: await physics_frame
	quit()
