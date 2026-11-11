class_name MistWraith
extends Npc
## Espectro de la bruma (Story.FOES "espectro"): anda por las afueras. Te huele de cerca, se arrastra hacia vos y se
## lanza: se echa atrás, se estira y te pega en el pico del estirón. No se levanta: muere derritiéndose en bruma.
## El cuerpo es WraithRig (shader, sin esqueleto). Los pone GateForces (PEOPLE con el modelo "Espectro").

const NOTICE := 18.0
const LOSE := 40.0
const REACH := 2.4  ## hasta dónde llega lanzándose (a 2,2 m de alto)
const LUNGE_DUR := 1.1
const LUNGE_SPEED := 8.0  ## lo que avanza en el estirón
const DAMAGE := 12.0
const PUSH := 7.0

var _player: Node3D
var _foe: Node3D
var _grow := 1.0
var _busy_until := 0.0
var _next_lunge := 0.0
var _next_plan := 0.0
var _next_foe := 0.0
var _lunge_id := 0
var _gone := 0.0


func _ready() -> void:
	body_height = randf_range(1.9, 2.6)
	super()
	# Es ancho: el cuerpo de colisión también.
	for c in get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is CapsuleShape3D:
			((c as CollisionShape3D).shape as CapsuleShape3D).radius = body_height * 0.4


func _role() -> String:
	return "wraith"


func _make_look() -> Dictionary:
	return {"height": body_height}


func _setup() -> void:
	add_to_group(&"wraith")
	_grow = body_height / 2.2
	team = 1
	stay_in_plaza = false
	knockout_time = 1e6  # no se levanta: se derrite (ver _physics_process)
	max_health = 70.0 * _grow
	allomantic_mass = 40.0
	walk_speed = 0.8
	run_speed = 3.8
	accel = 8.0
	decision_lead = 0.2  # menos que lo que tarda en replanear (0,25 s): si no, nunca arranca
	xp_reward = int(40 * _grow)  # G22: con la curva nueva de Lucho, 90 subía un nivel cada dos espectros
	loot_coins = Vector2i(0, 2)
	loot_vial_chance = 0.1
	_next_lunge = randf_range(0.5, 1.5)


func _physics_process(delta: float) -> void:
	super(delta)
	rig.rotation.x = 0.0  # Npc lo tumba al caer; este se derrite
	if down:
		(rig as WraithRig).melt()
		_gone += delta
		if _gone > WraithRig.MELT_TIME + 0.5:
			queue_free()


func _think(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
		if _player == null:
			return
	if _world_time < _busy_until:
		return
	_pick_foe()
	if _foe == null or is_soothed():
		face_point = null
		_wander()
		return
	var to := _foe.global_position - global_position
	to.y = 0.0
	var d := to.length()
	face_point = _foe.global_position
	var reach := REACH * _grow
	if d < reach * 1.3 and _world_time >= _next_lunge:
		_lunge()
	elif _world_time >= _next_plan:
		_next_plan = _world_time + 0.25
		var speed := run_speed * (1.3 if is_rioted() else 1.0)
		plan_velocity(to.normalized() * speed if d > reach * 0.8 else Vector3.ZERO)


## El jugador si está cerca (o si ya lo venía siguiendo); si no, cualquiera de otro bando que esté a tiro.
func _pick_foe() -> void:
	if _world_time < _next_foe and is_instance_valid(_foe) and not _foe.call(&"is_down"):
		return
	_next_foe = _world_time + 0.7
	var was := _foe
	_foe = null
	var best := NOTICE
	for n: Node3D in get_tree().get_nodes_in_group(&"combatant"):
		if n == self or n.get(&"team") == team or n.call(&"is_down"):
			continue
		var d := n.global_position.distance_to(global_position)
		if d < best or (n == was and d < LOSE):
			best = d
			_foe = n


func _wander() -> void:
	if _world_time < _next_plan:
		return
	_next_plan = _world_time + randf_range(3.0, 6.0)
	var to := random_point_near_home() - global_position
	to.y = 0.0
	plan_velocity(to.normalized() * walk_speed if randf() < 0.6 else Vector3.ZERO)


func _move_now(v: Vector3) -> void:
	_desired = v
	_switch_at = INF


func _forward() -> Vector3:
	return -global_basis.z


## Se echa atrás quieto, se estira avanzando y pega en el pico del estirón (WraithRig.PEAK).
func _lunge() -> void:
	_lunge_id += 1
	var id := _lunge_id
	(rig as WraithRig).lunge(LUNGE_DUR)
	_busy_until = _world_time + LUNGE_DUR
	_next_lunge = _world_time + LUNGE_DUR + randf_range(1.0, 2.0)
	_move_now(Vector3.ZERO)
	var wind := WraithRig.WIND * LUNGE_DUR
	var peak := WraithRig.PEAK * LUNGE_DUR
	get_tree().create_timer(wind, false).timeout.connect(func() -> void:
		if id == _lunge_id and not down:
			_move_now(_forward() * LUNGE_SPEED * _grow))
	get_tree().create_timer(peak, false).timeout.connect(_land.bind(id))


func _land(id: int) -> void:
	_move_now(Vector3.ZERO)
	if id != _lunge_id or down or is_stunned():
		return
	var reach := REACH * _grow * 1.2
	for n: Node3D in get_tree().get_nodes_in_group(&"combatant"):
		if n == self or n.get(&"team") == team or n.call(&"is_down"):
			continue
		var to := n.global_position - global_position
		to.y = 0.0
		if to.length() > reach or _forward().dot(to.normalized()) < 0.2:
			continue
		mark_combat()
		Sfx.play("punch", n.global_position + Vector3.UP)
		n.call(&"take_hit", to.normalized() * PUSH, DAMAGE * _grow, self)


func _on_hit(_attacker: Node3D) -> void:
	(rig as WraithRig).cancel_action()  # un golpe le corta el estirón
	_lunge_id += 1
