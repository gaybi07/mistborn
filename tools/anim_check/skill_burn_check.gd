extends Node
## Uso: Godot --path . res://tools/anim_check/skill_burn_check.tscn
## En la sala de poderes, con Vin: usa cada poder activo con todos los metales apagados y revisa que, al terminar, el
## poder no deje ningún metal encendido. También revisa que un metal que encendiste vos siga encendido después.
## Los niveles van solo en memoria (la sala no guarda).
const WAIT_MAX := 18.0  # s: la Marca dura 15


func _ready() -> void:
	Art.player_model = "vin"
	var room: TrainingRoom = load("res://scenes/skill_room.tscn").instantiate()
	add_child(room)
	var tree := get_tree()
	for i in 30: await tree.physics_frame
	var player: Player = room.player
	var failed := false
	for s: Dictionary in SkillTree.SKILLS:
		var skill: StringName = s["id"]
		if s["kind"] != SkillTree.Kind.ACTIVE or not SkillTree.is_assignable(skill):
			continue
		for own in [false, true]:
			_reset(player)
			var metal: StringName = s["metal"]
			if own:
				player.allomancy.set_state(metal, Allomancy.State.BURN)  # lo encendiste vos antes
			player._skill_press(skill)
			for i in 3: await tree.physics_frame
			player._skill_release(skill)
			var t := 0.0
			var on: Array = []
			while t < WAIT_MAX:
				await tree.create_timer(0.25).timeout
				t += 0.25
				on = _burning(player)
				if own:
					on.erase(metal)
				if on.is_empty() and (own or t > 1.5):
					break
			var ok: bool = on.is_empty() and (not own or player.allomancy.is_burning(metal))
			if not ok:
				failed = true
			var what := "quedan encendidos: %s" % [on] if not on.is_empty() else ("se apagó el tuyo" if own and not ok else "todo apagado a los %.2f s" % t)
			print("%-22s %-14s %s  %s" % [skill, "(ya quemando)" if own else "", what, "OK" if ok else "MAL"])
	print("RESULTADO: ", "FALLÓ" if failed else "todo bien")
	tree.quit()


func _burning(player: Player) -> Array:
	var out := []
	for m: StringName in Allomancy.METALS:
		if player.allomancy.is_burning(m):
			out.append(m)
	return out


## Todo apagado, reservas llenas, en el piso y sin poderes en curso.
func _reset(player: Player) -> void:
	for m: StringName in Allomancy.METALS:
		player.allomancy.set_state(m, Allomancy.State.OFF)
		player.allomancy.reserve[m] = float(Allomancy.METALS[m]["max"])
	player._skill_started.clear()
	player.global_position = Vector3(0, 1.0, 0)
	player.velocity = Vector3.ZERO
