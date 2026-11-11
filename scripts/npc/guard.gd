class_name Guard
extends Npc
## Guardia con armadura y lanza de metal: está en el grupo "metal", así que se le puede
## empujar o tirar de él (pesa 95 kg con el equipo). Patrulla y, si te ve, se acerca en guardia.
## Pega con la lanza a los koloss que vea, y a vos solo si le pegaste antes o está enardecido.

enum Mode { WAIT, PATROL, CHASE }

var mode := Mode.WAIT
var waypoints: Array[Vector3] = []

var _wp := 0
var _until := 0.0
var _replan_at := 0.0
var _player: Player
const STRIKE_REACH := 2.4
const STRIKE_DAMAGE := 12.0
const STRIKE_EVERY := 1.4
const KOLOSS_NOTICE := 20.0
const PROVOKED_TIME := 12.0
var _provoked_until := 0.0
var _next_strike := 0.0


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


## El guardia lleva una lanza de metal.
func is_armed() -> bool:
	return not is_disarmed()


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
	var foe := _pick_foe()
	var chased: Node3D = foe if foe else _player
	var d := global_position.distance_to(chased.global_position)
	# Enardecido (cinc) te ve desde más lejos; aplacado (latón) deja de perseguirte.
	var notice := Npc.sight(_player, 24.0 if is_rioted() else 14.0)
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
			face_point = chased.global_position
			var to := chased.global_position - global_position
			to.y = 0.0
			if foe and to.length() < STRIKE_REACH and _world_time >= _next_strike:
				_strike(foe)
			if _world_time >= _replan_at:
				_replan_at = _world_time + 0.5
				var speed := run_speed * (1.3 if is_rioted() else 1.0)
				plan_velocity(to.normalized() * speed if to.length() > (2.0 if foe else 2.8) else Vector3.ZERO)
		Mode.WAIT:
			rig.brace = move_toward(rig.brace, 0.0, delta * 2.0)
			face_point = null
			if _world_time >= _until:
				mode = Mode.PATROL
				_wp = (_wp + 1) % waypoints.size()
				_replan_at = 0.0
		Mode.PATROL:
			var way := waypoints[_wp] - global_position
			way.y = 0.0
			if way.length() < 1.0:
				mode = Mode.WAIT
				_until = _world_time + randf_range(1.5, 3.5)
				plan_velocity(Vector3.ZERO)
			elif _world_time >= _replan_at:
				_replan_at = _world_time + 2.0
				plan_velocity(way.normalized() * walk_speed)



## A quién pegarle: un koloss cerca, o el jugador si lo provocó.
func _pick_foe() -> Node3D:
	var best: Node3D = null
	var best_d := KOLOSS_NOTICE
	for k: Npc in get_tree().get_nodes_in_group(&"koloss"):
		var d := k.global_position.distance_to(global_position)
		if not k.down and d < best_d:
			best = k
			best_d = d
	if best == null and not _player.is_down() and not is_soothed() and (_world_time < _provoked_until or is_rioted()):
		return _player
	return best


## La lanza llega en el impacto de la animación, si no le cortaron el golpe y el otro sigue a tiro.
func _strike(foe: Node3D) -> void:
	_next_strike = _world_time + STRIKE_EVERY
	rig.play_attack(1, 0.6)
	get_tree().create_timer(rig.impact_delay(), false).timeout.connect(func() -> void:
		if down or is_stunned() or rig._attack <= 0.0 or not is_instance_valid(foe) or foe.call(&"is_down"):
			return
		var to := foe.global_position - global_position
		to.y = 0.0
		if to.length() <= STRIKE_REACH + 0.5:
			Sfx.play("slash", foe.global_position + Vector3(0, 1.2, 0))
			foe.call(&"take_hit", to.normalized() * 5.0, STRIKE_DAMAGE, self))


func _on_hit(attacker: Node3D) -> void:
	if attacker is Player:
		_provoked_until = _world_time + PROVOKED_TIME
