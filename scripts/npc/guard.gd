class_name Guard
extends Npc
## Guardia con armadura y lanza de metal: está en el grupo "metal", así que se le puede
## empujar o tirar de él (pesa 95 kg con el equipo). Patrulla y, si te ve, se acerca en guardia.

enum Mode { WAIT, PATROL, CHASE }

var mode := Mode.WAIT
var waypoints: Array[Vector3] = []

var _wp := 0
var _until := 0.0
var _replan_at := 0.0
var _player: Player


func _make_look() -> Dictionary:
	return {
		"skin": Citizen.SKIN.pick_random(),
		"hair_style": "short",
		"shirt": Color(0.32, 0.1, 0.08),
		"pants": Color(0.14, 0.12, 0.11),
		"boots": Color(0.08, 0.06, 0.05),
		"hat": "helmet",
		"armor": true,
		"spear": true,
		"height": randf_range(0.97, 1.03),
		"build": 1.1,
	}


func _role() -> String:
	return "guard"


func _setup() -> void:
	xp_reward = 180
	loot_coins = Vector2i(4, 8)
	loot_vial_chance = 0.25
	loot_item_chance = 0.1
	add_to_group(&"metal")
	allomantic_mass = 95.0
	walk_speed = 1.7
	run_speed = 4.2
	decision_lead = 0.6
	if waypoints.is_empty():
		for i in 3:
			waypoints.append(random_point_near_home())
	_until = randf_range(0.5, 2.0)


func _think(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
		if _player == null:
			return
	var d := global_position.distance_to(_player.global_position)
	# Enardecido (cinc) te ve desde más lejos; aplacado (latón) deja de perseguirte.
	var notice := 24.0 if is_rioted() else 14.0
	if mode != Mode.CHASE and d < notice and _knockback <= 0.0 and not is_soothed():
		mode = Mode.CHASE
		_replan_at = 0.0
	elif mode == Mode.CHASE and (d > 24.0 or is_soothed()):
		mode = Mode.WAIT
		_until = _world_time + 2.0
		plan_velocity(Vector3.ZERO)

	match mode:
		Mode.CHASE:
			rig.brace = move_toward(rig.brace, 1.0, delta * 3.0)
			face_point = _player.global_position
			if _world_time >= _replan_at:
				_replan_at = _world_time + 0.5
				var to := _player.global_position - global_position
				to.y = 0.0
				var speed := run_speed * (1.3 if is_rioted() else 1.0)
				plan_velocity(to.normalized() * speed if to.length() > 2.8 else Vector3.ZERO)
		Mode.WAIT:
			rig.brace = move_toward(rig.brace, 0.0, delta * 2.0)
			face_point = null
			if _world_time >= _until:
				mode = Mode.PATROL
				_wp = (_wp + 1) % waypoints.size()
				_replan_at = 0.0
		Mode.PATROL:
			var to := waypoints[_wp] - global_position
			to.y = 0.0
			if to.length() < 1.0:
				mode = Mode.WAIT
				_until = _world_time + randf_range(1.5, 3.5)
				plan_velocity(Vector3.ZERO)
			elif _world_time >= _replan_at:
				_replan_at = _world_time + 2.0
				plan_velocity(to.normalized() * walk_speed)
