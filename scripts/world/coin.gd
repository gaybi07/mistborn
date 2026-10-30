class_name Coin
extends RigidBody3D
## Moneda: metal ligero que se puede empujar o tirar. Si golpea a alguien a gran velocidad
## (lanzada y empujada con acero) le hace daño, como una bala. Solo hiere una vez por vuelo.
## Si quien la lanzó quema atium, casi siempre (HOMING_CHANCE) se guía hasta el enemigo al que
## apuntaba: vio dónde iba a estar.

const HARMFUL_SPEED := 12.0
const HOMING_CHANCE := 0.9
const HOMING_CONE := 0.35  ## rad alrededor de la dirección de vuelo para elegir el blanco
const HOMING_RANGE := 70.0

## Quien la lanzó: no le hace daño a él.
var shooter: Node3D = null
## Red: id de la moneda (el mismo en todos los procesos; 0 = no es de red) y si es una copia que solo
## muestra lo que manda el servidor (sin física ni daño).
var net_id := 0
var puppet := false

var _last_velocity := Vector3.ZERO
## Recogida: solo si está casi quieta; y quien la soltó o lanzó no la recoge hasta que se aleje de él
## (o pasen unos segundos): la moneda que dejas bajo los pies para impulsarte no te la guardas de nuevo.
const PICKUP_MAX_SPEED := 2.0
const SHOOTER_CLEAR_DIST := 1.5
const SHOOTER_GRACE_MS := 4000
var _born_ms := Time.get_ticks_msec()
var _left_shooter := false
var _homing: Node3D = null
var _homing_rolled := false


func _ready() -> void:
	if puppet:
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true
		collision_layer = 0
		collision_mask = 0
		return
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_steer(delta)
	# La velocidad de antes del choque (después del choque ya está frenada).
	_last_velocity = linear_velocity
	if not _left_shooter and shooter != null and is_instance_valid(shooter) \
			and global_position.distance_to(shooter.global_position + Vector3(0, 1.2, 0)) > SHOOTER_CLEAR_DIST:
		_left_shooter = true


## Si `by` puede recogerla ahora.
func pickable(by: Node3D) -> bool:
	if puppet or linear_velocity.length() > PICKUP_MAX_SPEED:
		return false
	return shooter != by or _left_shooter or Time.get_ticks_msec() - _born_ms > SHOOTER_GRACE_MS


## Atium: al salir disparada elige el enemigo más alineado con su vuelo y se curva hacia él.
func _steer(delta: float) -> void:
	var speed := linear_velocity.length()
	if speed < HARMFUL_SPEED * 0.8:
		_homing_rolled = false  # quieta o frenada: el próximo disparo vuelve a elegir
		_homing = null
		return
	if not _homing_rolled:
		_homing_rolled = true
		if Metals.burns_atium(shooter) and randf() < HOMING_CHANCE:
			_homing = _pick_target()
	if _homing == null or not is_instance_valid(_homing) or _homing.is_down():
		return
	var to := Metals.center_of(_homing) - global_position
	linear_velocity = linear_velocity.normalized().slerp(to.normalized(), minf(1.0, 14.0 * delta)) * speed


func _pick_target() -> Node3D:
	var best: Node3D = null
	var best_angle := HOMING_CONE
	for group in [&"npc", &"player"]:
		for n in get_tree().get_nodes_in_group(group):
			var body := n as Node3D
			# Solo enemigos: de otro equipo, o un neutral que lo está atacando (no la gente de la calle).
			var team: int = body.get(&"team")
			if body == shooter or not body.has_method(&"take_hit") or body.is_down() \
					or team == shooter.get(&"team") or (team < 0 and body.get(&"target") != shooter):
				continue
			var to := Metals.center_of(body) - global_position
			var angle := linear_velocity.angle_to(to)
			if to.length() < HOMING_RANGE and angle < best_angle:
				best_angle = angle
				best = body
	return best


func _on_body_entered(body: Node) -> void:
	var speed := _last_velocity.length()
	if speed < HARMFUL_SPEED or body == shooter or not body.has_method(&"take_hit"):
		return
	var damage := clampf((speed - 10.0) * 1.1, 3.0, 25.0)
	var impulse := _last_velocity.normalized() * speed * 0.06
	if body.has_method(&"_receive_net_hit") and body.net_peer_id != 0:
		# Jugador de red: solo el servidor (único que simula monedas) decide el impacto.
		if body.dead or body.net_protected:
			return
		body._receive_net_hit(impulse, damage, shooter.net_peer_id if shooter != null and shooter.get(&"net_peer_id") != null else 0)
	else:
		body.take_hit(impulse, damage, shooter)
	Fx.sparks(get_tree().current_scene, global_position, Color(1.0, 0.75, 0.45))
	Fx.effect(get_tree().current_scene, "ef_fire01", global_position, 0.2)
	_last_velocity = Vector3.ZERO
