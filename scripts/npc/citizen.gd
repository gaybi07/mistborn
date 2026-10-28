class_name Citizen
extends Npc
## Gente de Luthadel: skaa (ropa gris, encorvados) y algún noble (colores, sombrero de copa).
## Pasean, se paran y huyen despavoridos cuando el alomántico usa sus poderes cerca.

enum Mode { IDLE, WALK, FLEE }

const SKIN := [Color(0.94, 0.8, 0.68), Color(0.85, 0.66, 0.52), Color(0.7, 0.5, 0.37),
		Color(0.5, 0.35, 0.25), Color(0.36, 0.25, 0.18)]
const HAIR := [Color(0.08, 0.06, 0.05), Color(0.2, 0.13, 0.08), Color(0.4, 0.3, 0.2),
		Color(0.5, 0.48, 0.46), Color(0.45, 0.2, 0.1)]
const DRAB := [Color(0.35, 0.31, 0.26), Color(0.28, 0.27, 0.26), Color(0.41, 0.37, 0.31),
		Color(0.23, 0.21, 0.19), Color(0.31, 0.26, 0.22), Color(0.38, 0.34, 0.3)]
const NOBLE := [Color(0.12, 0.18, 0.4), Color(0.42, 0.08, 0.12), Color(0.15, 0.3, 0.2),
		Color(0.3, 0.15, 0.35), Color(0.55, 0.45, 0.2)]

var mode := Mode.IDLE
var noble := false

var _until := 0.0
var _replan_at := 0.0
var _goal := Vector3.ZERO
var _player: Player


func _make_look() -> Dictionary:
	noble = randf() < 0.2
	var look := {
		"skin": SKIN.pick_random(),
		"hair": HAIR.pick_random(),
		"hair_style": ["short", "short", "long", "bald"].pick_random(),
		"height": randf_range(0.88, 1.0),
		"build": randf_range(0.9, 1.15),
	}
	if noble:
		var c: Color = NOBLE.pick_random()
		look["shirt"] = c
		look["coat"] = c.darkened(0.25)
		look["pants"] = Color(0.08, 0.08, 0.1)
		look["boots"] = Color(0.04, 0.04, 0.04)
		look["hat"] = ["tophat", "tophat", "none"].pick_random()
	else:
		look["shirt"] = DRAB.pick_random()
		look["pants"] = (DRAB.pick_random() as Color).darkened(0.25)
		look["coat"] = DRAB.pick_random() if randf() < 0.35 else null
		look["hat"] = ["none", "none", "cap", "hood"].pick_random()
	return look


func _role() -> String:
	return "noble" if noble else "citizen"


func _setup() -> void:
	rig.slouch = 0.0 if noble else randf_range(0.2, 0.5)
	walk_speed = randf_range(1.1, 1.6)
	run_speed = randf_range(4.0, 5.5)
	_until = randf_range(0.0, 3.0)


func _think(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
	if is_rioted():
		_brawl()
		return
	if _player and not is_soothed() and _is_threatened():
		if mode != Mode.FLEE:
			_replan_at = 0.0
		mode = Mode.FLEE
		_until = _world_time + randf_range(3.0, 5.0)

	match mode:
		Mode.FLEE:
			rig.panic = move_toward(rig.panic, 1.0, delta * 4.0)
			if _world_time >= _until:
				mode = Mode.IDLE
				_until = _world_time + randf_range(1.0, 3.0)
				plan_velocity(Vector3.ZERO)
			elif _world_time >= _replan_at:
				_replan_at = _world_time + 0.8
				var away := global_position - _player.global_position
				away.y = 0.0
				if is_on_wall():
					away = away.rotated(Vector3.UP, randf_range(-1.8, 1.8))
				plan_velocity(away.normalized() * run_speed)
		Mode.IDLE:
			if _world_time >= _until:
				_goal = random_point_near_home()
				mode = Mode.WALK
				_head_to_goal()
		Mode.WALK:
			var to := _goal - global_position
			to.y = 0.0
			if to.length() < 1.0 or (is_on_wall() and _world_time > _replan_at - 1.0):
				mode = Mode.IDLE
				_until = _world_time + randf_range(2.0, 6.0)
				plan_velocity(Vector3.ZERO)
			elif _world_time >= _replan_at:
				_head_to_goal()
	if mode != Mode.FLEE:
		rig.panic = move_toward(rig.panic, 0.0, delta * 2.0)


## Enardecido con cinc: va a por el vecino más cercano y lo empuja (sin hacer daño).
func _brawl() -> void:
	rig.panic = 0.0
	var best: Citizen = null
	var best_d := 10.0
	for n in get_tree().get_nodes_in_group(&"npc"):
		var c := n as Citizen
		if c and c != self and not c.down:
			var d := c.global_position.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = c
	if best == null:
		return
	face_point = best.global_position
	var to := best.global_position - global_position
	to.y = 0.0
	if _world_time >= _replan_at:
		_replan_at = _world_time + 0.4
		plan_velocity(to.normalized() * run_speed if best_d > 1.2 else Vector3.ZERO)
	if best_d < 1.4 and _world_time >= _until:
		_until = _world_time + 1.2
		rig.play_attack(1, 0.5)
		best.take_hit(to.normalized() * 4.0, 0.0)


func _head_to_goal() -> void:
	var to := _goal - global_position
	to.y = 0.0
	plan_velocity(to.normalized() * walk_speed)
	_replan_at = _world_time + 2.0


func _is_threatened() -> bool:
	var d := global_position.distance_to(_player.global_position)
	if d > 12.0:
		return false
	if _player.steel_iron.applying_force:
		return true
	return _player.velocity.length() > 10.0 and d < 7.0


func _on_pushed() -> void:
	mode = Mode.FLEE
	_until = _world_time + 4.0
	_replan_at = _world_time + 0.7
