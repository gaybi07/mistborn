class_name Coin
extends RigidBody3D
## Moneda: metal ligero que se puede empujar o tirar. Si golpea a alguien a gran velocidad
## (lanzada y empujada con acero) le hace daño, como una bala. Solo hiere una vez por vuelo.

const HARMFUL_SPEED := 12.0

## Quien la lanzó: no le hace daño a él.
var shooter: Node3D = null

var _last_velocity := Vector3.ZERO


func _ready() -> void:
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
	body.take_hit(_last_velocity.normalized() * speed * 0.06, damage, shooter)
	Fx.sparks(get_tree().current_scene, global_position, Color(1.0, 0.75, 0.45))
	_last_velocity = Vector3.ZERO
