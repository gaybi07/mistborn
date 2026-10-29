class_name Coin
extends RigidBody3D
## Moneda: metal ligero que se puede empujar o tirar. Si golpea a alguien a gran velocidad
## (lanzada y empujada con acero) le hace daño, como una bala. Solo hiere una vez por vuelo.

const HARMFUL_SPEED := 12.0

## Quien la lanzó: no le hace daño a él.
var shooter: Node3D = null
## Red: id de la moneda (el mismo en todos los procesos; 0 = no es de red) y si es una copia que solo
## muestra lo que manda el servidor (sin física ni daño).
var net_id := 0
var puppet := false

var _last_velocity := Vector3.ZERO


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


func _physics_process(_delta: float) -> void:
	# La velocidad de antes del choque (después del choque ya está frenada).
	_last_velocity = linear_velocity


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
	_last_velocity = Vector3.ZERO
