class_name Koloss
extends Npc
## Koloss: bestia enorme que pelea con un espadón a dos manos o con un hacha en cada mano (ver
## Art.koloss_fighter_rig). Ruge al verte, corre, encadena golpes, salta encima tuyo y, herido, entra en
## furia. También esquiva y (con espadón) se cubre cuando le atacás de cerca. Se le puede empujar y tirar:
## lleva hierro encima.

const NOTICE := 24.0
const LOSE := 50.0
const DAMAGE := 15.0
const REACH_SWORD := 2.0
const REACH_AXES := 1.6
## Por cada golpe: clip, duración entera (s), fracciones en las que pega (pico de velocidad de la mano,
## medido en el FBX), multiplicadores de daño y empuje, y cuánto avanza en todo el golpe (m a 1,8 m de alto:
## el clip viaja y se juega en el lugar, así que el cuerpo lo acompaña).
const SWORD_BLOWS := [
	{"anim": "gs_slash_down", "dur": 1.0, "hits": [0.53], "damage": 1.0, "push": 6.0, "travel": 0.0},
	{"anim": "gs_slash_power", "dur": 1.25, "hits": [0.42], "damage": 1.3, "push": 8.0, "travel": 1.2},
	{"anim": "gs_slash_low", "dur": 1.2, "hits": [0.44], "damage": 0.9, "push": 5.0, "travel": 0.0},
]
const AXE_BLOWS := [
	{"anim": "mt_swipe_l", "dur": 1.3, "hits": [0.49], "damage": 1.0, "push": 6.0, "travel": 0.0},
	{"anim": "mt_swipe_r", "dur": 1.3, "hits": [0.49], "damage": 1.0, "push": 6.0, "travel": 0.0},
	{"anim": "mt_punch", "dur": 0.7, "hits": [0.26], "damage": 0.7, "push": 9.0, "travel": 0.0},
]
const SWORD_KICK := {"anim": "gs_kick", "dur": 1.1, "hits": [0.25], "damage": 0.5, "push": 15.0, "travel": 0.0}
const SWORD_COMBO := {"anim": "gs_combo", "dur": 2.8, "hits": [0.21, 0.47, 0.72], "damage": 0.8, "push": 5.0, "travel": 3.3}
## Salto aplastante: fracciones del clip en que despega y cae; a qué distancias lo usa (× tamaño).
const LEAP_DUR := 2.6
const LEAP_OFF := 0.15
const LEAP_LAND := 0.43
const LEAP_RANGE := Vector2(5.0, 12.0)
const LEAP_RADIUS := 3.5
const ROAR_RADIUS := 6.0
## Bajo esta fracción de vida entra en furia: más rápido y más fuerte.
const RAGE_AT := 0.4
const RAGE_DAMAGE := 1.35
const RAGE_SPEED := 1.25
## Cuánto queda tirado antes de desaparecer.
const CORPSE_TIME := 20.0

var axes := randf() < 0.5

var _player: Node3D
var _foe: Node3D
var _next_foe := 0.0
## Le pegaste hace poco: te persigue a vos aunque tenga a otro más cerca.
const PROVOKED_TIME := 6.0
var _provoked_until := 0.0
var _blow_id := 0
var _grow := 1.0
var _alerted := false
var _enraged := false
var _busy_until := 0.0
var _next_blow := 0.0
var _next_leap := 0.0
var _next_react := 0.0
var _next_plan := 0.0
var _combo_step := 0
var _guard_until := 0.0
var _evade_until := 0.0
var _foe_was_attacking := false
var _corpse := 0.0


func _role() -> String:
	return "koloss_axes" if axes else "koloss"


func _setup() -> void:
	add_to_group(&"koloss")
	add_to_group(&"metal")
	_grow = body_height / 1.8
	team = 1
	stay_in_plaza = false
	roam_radius = 10.0
	knockout_time = 1e6  # no se levanta: al rato desaparece (ver _physics_process)
	max_health = 170.0 * _grow
	allomantic_mass = 110.0
	walk_speed = 1.5 * _grow
	run_speed = (5.0 if axes else 5.4) * sqrt(_grow)
	accel = 14.0
	decision_lead = 0.2
	xp_reward = int(220 * _grow)
	loot_coins = Vector2i(3, 8)
	loot_vial_chance = 0.2
	rig.set_weapon(HumanoidRig.Weapon.SWORD)
	_next_leap = randf_range(2.0, 5.0)


func _physics_process(delta: float) -> void:
	super(delta)
	if down:
		_corpse += delta
		if _corpse > CORPSE_TIME:
			queue_free()


func _think(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
		if _player == null:
			return
	if _world_time < _busy_until:
		return
	(rig as ModelRig).armored = false
	if _world_time < _guard_until:
		return
	rig.blocking = false
	_pick_foe()
	if _foe == null or is_soothed():
		_alerted = false
		face_point = null
		_wander()
		return
	var to := _foe.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if not _alerted:
		_alerted = true
		face_point = _foe.global_position
		_roar()
		return
	face_point = _foe.global_position
	if not _enraged and health < max_health * RAGE_AT:
		_rage()
		return
	var reach := (REACH_AXES if axes else REACH_SWORD) * _grow
	if _foe == _player and _react_to_attack(d, reach):
		return
	if _use_power(d):
		return
	if d < reach and _world_time >= _next_blow:
		_next_attack(d)
	elif d > LEAP_RANGE.x * _grow and d < LEAP_RANGE.y * _grow and _world_time >= _next_leap:
		_leap()
	elif _world_time >= _next_plan:
		_next_plan = _world_time + 0.25
		var speed := run_speed * (RAGE_SPEED if _enraged else 1.0) * (1.3 if is_rioted() else 1.0)
		plan_velocity(to.normalized() * speed if d > reach * 0.75 else Vector3.ZERO)


## Todos los que no son de su bando: el jugador, la gente, los guardias, los alománticos rivales.
func _victims() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n: Node3D in get_tree().get_nodes_in_group(&"combatant"):
		if n != self and n.get(&"team") != team and not n.call(&"is_down"):
			out.append(n)
	return out


## Va por lo más cercano; si el jugador le pegó hace poco o ya lo venía persiguiendo, por él.
func _pick_foe() -> void:
	if _world_time < _next_foe and is_instance_valid(_foe) and not _foe.call(&"is_down"):
		return
	_next_foe = _world_time + 0.7
	_foe = null
	var player_alive: bool = not _player.call(&"is_down")
	if _world_time < _provoked_until and player_alive:
		_foe = _player
		return
	var best := NOTICE
	for v in _victims():
		var d := v.global_position.distance_to(global_position)
		if d < best:
			best = d
			_foe = v
	if _foe == null and _alerted and player_alive and _player.global_position.distance_to(global_position) < LOSE:
		_foe = _player


func _wander() -> void:
	if _world_time < _next_plan:
		return
	_next_plan = _world_time + randf_range(3.0, 6.0)
	var to := random_point_near_home() - global_position
	to.y = 0.0
	plan_velocity(to.normalized() * walk_speed if randf() < 0.6 else Vector3.ZERO)


## Cambia de velocidad ya, sin el plan por adelantado (golpes y saltos).
func _move_now(v: Vector3) -> void:
	_desired = v
	_switch_at = INF


func _forward() -> Vector3:
	return -global_basis.z


# ---------------------------------------------------------------- Golpes

## Sigue el combo; al arrancarlo, a veces (con el espadón) una patada o el combo largo.
func _next_attack(d: float) -> void:
	var blows: Array = AXE_BLOWS if axes else SWORD_BLOWS
	var blow: Dictionary = blows[_combo_step]
	if not axes and _combo_step == 0 and randf() < 0.3:
		blow = SWORD_COMBO if d > 1.2 * _grow and randf() < 0.5 else SWORD_KICK
	_combo_step = (_combo_step + 1) % blows.size()
	var total := _strike(blow)
	var rest := randf_range(0.7, 1.4) if _combo_step == 0 else 0.0
	_next_blow = _world_time + total * 0.85 + rest


func _strike(blow: Dictionary) -> float:
	var total := _play(blow["anim"], blow["dur"] * (0.8 if _enraged else 1.0))
	_busy_until = _world_time + total * 0.85
	_blow_id += 1
	# Avanza hasta el último golpe y ahí clava los pies: pega parado, no deslizándose.
	var last: float = blow["hits"][-1] * total
	_move_now(_forward() * blow["travel"] * _grow / last)
	get_tree().create_timer(last, false).timeout.connect(_end_travel.bind(_blow_id))
	Sfx.play("swing", global_position)
	for hit: float in blow["hits"]:
		get_tree().create_timer(hit * total, false).timeout.connect(_land_blow.bind(blow, _blow_id))
	return total


func _end_travel(id: int) -> void:
	if id == _blow_id:
		_move_now(Vector3.ZERO)


func _play(anim: String, duration: float) -> float:
	rig.play_spell(anim, duration)
	return (rig as ModelRig)._spell


## Llega el golpe, si no le cortaron la animación (aturdido, golpe fuerte), a todo el que esté delante y a tiro.
func _land_blow(blow: Dictionary, id: int) -> void:
	if id != _blow_id or down or is_stunned() or (rig as ModelRig)._spell_state != blow["anim"]:
		return
	var reach := (REACH_AXES if axes else REACH_SWORD) * _grow * 1.2
	for v in _victims():
		var to := v.global_position - global_position
		to.y = 0.0
		if to.length() > reach or _forward().dot(to.normalized()) < 0.1:
			continue
		mark_combat()
		var at := global_position + Vector3(0, body_height * 0.55, 0) + to.normalized() * minf(to.length(), reach * 0.6)
		Fx.sparks(get_tree().current_scene, at, Color(1.0, 0.55, 0.35))
		Sfx.play("punch", at)
		v.call(&"take_hit", to.normalized() * blow["push"], _damage(blow["damage"]), self)


func _damage(mult: float) -> float:
	return DAMAGE * _grow * mult * (RAGE_DAMAGE if _enraged else 1.0)


# ---------------------------------------------------------------- Poderes

## Los de Champion, antes de seguir con los golpes.
func _use_power(_d: float) -> bool:
	return false


## Rugido: asusta y empuja a quien esté cerca (y sacude la cámara).
func _roar() -> void:
	var total := _commit("mt_roar", 3.0)  # el clip dura 5,4 s: más rápido se ve acelerado
	get_tree().create_timer(total * 0.29, false).timeout.connect(_roar_blast)


func _roar_blast() -> void:
	if down or is_stunned():
		return
	var center := global_position + Vector3(0, body_height * 0.7, 0)
	Fx.shockwave(get_tree().current_scene, center, ROAR_RADIUS * _grow, Color(1.0, 0.45, 0.3, 0.5))
	Sfx.play("land_heavy", center, 6.0)
	for v in _victims():
		var away := v.global_position - global_position
		away.y = 0.0
		if away.length() < ROAR_RADIUS * _grow:
			v.call(&"apply_allomantic_impulse", away.normalized() * 7.0 + Vector3.UP * 2.0)
			if v is Player:
				v.call(&"add_trauma", 0.4)


## Furia: se golpea el pecho y queda más rápido, más fuerte y rojo.
func _rage() -> void:
	_enraged = true
	_commit("mt_flex", 2.6)
	(rig as ModelRig)._apply_tint(Color(1.0, 0.5, 0.42))
	rig.flash(Color(1.0, 0.2, 0.1))
	Fx.popup(get_tree().current_scene, global_position + Vector3(0, head_y(), 0), "¡Furia!", Color(1.0, 0.35, 0.25))
	Fx.burst(get_tree().current_scene, global_position + Vector3(0, body_height * 0.6, 0), Color(1.0, 0.25, 0.1), 40, 5.0, 0.7)


## Salto aplastante: cae donde estabas al despegar y la onda golpea alrededor (saltando la esquivás).
func _leap() -> void:
	var total := _commit("mt_jump_attack", LEAP_DUR)
	_next_leap = _world_time + randf_range(7.0, 12.0)
	# Círculo rojo donde va a caer: te sigue hasta que despega.
	if is_instance_valid(_foe):
		var tel := Telegraph.disc(get_tree().current_scene, _foe.global_position, LEAP_RADIUS * _grow, total * LEAP_LAND, Telegraph.RED, _foe)
		tel.alive = func() -> bool: return is_instance_valid(self) and not down and not is_stunned()
		get_tree().create_timer(total * LEAP_OFF, false).timeout.connect(func() -> void: tel.follow = null)
	get_tree().create_timer(total * LEAP_OFF, false).timeout.connect(_leap_off.bind(total * (LEAP_LAND - LEAP_OFF)))
	get_tree().create_timer(total * LEAP_LAND, false).timeout.connect(_leap_land)


func _leap_off(air: float) -> void:
	if down or is_stunned() or not is_instance_valid(_foe):
		return
	var to := _foe.global_position - global_position
	to.y = 0.0
	velocity.x = to.x / air
	velocity.z = to.z / air
	_move_now(Vector3(velocity.x, 0.0, velocity.z))


func _leap_land() -> void:
	_move_now(Vector3.ZERO)
	velocity.x = 0.0
	velocity.z = 0.0
	if down or is_stunned():
		return
	var radius := LEAP_RADIUS * _grow
	var scene := get_tree().current_scene
	Fx.shockwave(scene, global_position + Vector3(0, 0.1, 0), radius, Color(1.0, 0.7, 0.45, 0.7))
	Fx.dust(scene, global_position, 2.0)
	Sfx.play("land_heavy", global_position, 6.0)
	for v in _victims():
		var away := v.global_position - global_position
		var height := away.y
		away.y = 0.0
		if v is Player and away.length() < radius * 2.0:
			v.call(&"add_trauma", 0.6)
		if away.length() < radius and height < 1.2:
			mark_combat()
			v.call(&"take_hit", away.normalized() * 11.0 + Vector3.UP * 4.0, _damage(1.5 * (1.0 - away.length() / radius * 0.5)), self)


## Una animación que no se corta con nada y lo deja quieto hasta que termina.
func _commit(anim: String, duration: float) -> float:
	(rig as ModelRig).armored = true
	var total := _play(anim, duration)
	_busy_until = _world_time + total * 0.9
	_move_now(Vector3.ZERO)
	return total


# ---------------------------------------------------------------- Defensa

## Le estás por pegar: a veces se aparta o, con el espadón, se cubre.
func _react_to_attack(d: float, reach: float) -> bool:
	var attacking: bool = _player.get(&"_attack_cd") > 0.0
	var started := attacking and not _foe_was_attacking
	_foe_was_attacking = attacking
	if not started or d > reach + 2.0 or _world_time < _next_react:
		return false
	var roll := randf()
	if roll < 0.35:
		_next_react = _world_time + 3.0
		_dodge()
		return true
	if roll < 0.6 and not axes:
		_next_react = _world_time + 3.0
		_guard_until = _world_time + 0.9
		rig.blocking = true
		_move_now(Vector3.ZERO)
		return true
	return false


## El clip se desplaza 1,25 m a 1,8 m de alto, en el lugar: el cuerpo lo acompaña.
func _dodge() -> void:
	var left := randf() < 0.5
	var total := _play("dodge_left" if left else "dodge_right", 0.75)
	_busy_until = _world_time + total * 0.85
	_evade_until = _world_time + total * 0.7
	_move_now(global_basis.x * (-1.0 if left else 1.0) * 1.25 * _grow / total)


func take_hit(impulse: Vector3, damage: float, attacker: Node3D = null) -> void:
	if attacker is Player:
		_provoked_until = _world_time + PROVOKED_TIME
		_next_foe = 0.0
	if _world_time < _evade_until:
		Fx.popup(get_tree().current_scene, global_position + Vector3(0, head_y(), 0), "esquiva", Color(0.8, 0.8, 0.7))
		return
	if rig.blocking and attacker and not down and _forward().dot((attacker.global_position - global_position).normalized()) > 0.2:
		mark_combat()
		health -= damage * 0.25
		rig.block_impact()
		HumanoidRig.hit_stop([rig, attacker.get(&"rig")], damage)
		if attacker.get(&"rig"):
			attacker.get(&"rig").recoil(global_position, 0.35)  # el que pega contra la guardia rebota
		Fx.sparks(get_tree().current_scene, global_position + Vector3(0, body_height * 0.6, 0), Color(1.0, 0.75, 0.45))
		Sfx.play("clash", global_position)
		return
	super(impulse * 0.5, damage, attacker)  # pesa mucho: los empujones lo mueven poco
	if attacker:
		mark_combat()
	if (rig as ModelRig)._spell_state.begins_with("hit") and (rig as ModelRig)._spell > 0.0:
		# Un golpe fuerte le cortó el suyo: frena y espera a reponerse.
		_blow_id += 1
		_move_now(Vector3.ZERO)
		_busy_until = maxf(_busy_until, _world_time + (rig as ModelRig)._spell)
