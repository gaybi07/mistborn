class_name Npc
extends CharacterBody3D
## Base para la gente de la ciudad (Citizen, Guard) y los alománticos (AllomancerNpc).
## Las decisiones de movimiento se planean `decision_lead` segundos antes de ejecutarse;
## predict_position() usa ese plan, y por eso el atium puede ver el futuro.

@export var walk_speed := 1.5
@export var run_speed := 5.0
@export var decision_lead := 0.5
@export var accel := 10.0
## Masa que cuenta para acero/hierro (solo si el Npc está en el grupo "metal").
@export var allomantic_mass := 75.0
@export var max_health := 60.0
@export var knockout_time := 8.0

var health := 60.0
## Noqueado: tumbado en el suelo hasta que se recupera.
var down := false
var _down_until := 0.0
## Botín al caer ante el jugador (una sola vez por Npc): monedas (mín, máx), probabilidad de frasco y de objeto.
var loot_coins := Vector2i(1, 3)
var loot_vial_chance := 0.05
var loot_item_chance := 0.0
var _looted := false
## Bando: -1 = gente que no pelea; 0 = el jugador y sus aliados; 1, 2... = otros bandos.
var team := -1

var home := Vector3.ZERO
var roam_radius := 12.0
## Si es true, los destinos se limitan a la plaza.
var stay_in_plaza := true
var rig: HumanoidRig
## Vector3 hacia el que se gira cuando está quieto, o null.
var face_point: Variant = null

var _world_time := 0.0
var _desired := Vector3.ZERO
var _pending := Vector3.ZERO
var _switch_at := INF
var _knockback := 0.0
## Se está impulsando con su propia alomancia: no corrige la velocidad caminando.
var _flying := 0.0
var _combat_ms := -1000000
## Alomancia emocional ajena (cinc / latón): dura un poco después de que dejen de quemarla.
var _rioted_until := -1.0
var _soothed_until := -1.0
## Cinc avivado: ataca a los suyos un rato.
var _frenzy_until := -1.0
## Se rindió (latón avivado con poca vida): ya no pelea.
var surrendered := false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	add_to_group(&"npc")
	add_to_group(&"combatant")
	add_to_group(&"atium_visible")
	collision_layer = Props.LAYER_PROPS
	collision_mask = Props.LAYER_WORLD | Props.LAYER_PROPS | Props.LAYER_PLAYER
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.8
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.9
	add_child(col)
	set_meta(&"center_offset", Vector3(0, 1.2, 0))
	var look := _make_look()
	rig = Art.npc_rig(_role(), look)
	add_child(rig)
	_setup()
	health = max_health


# --- Para sobrescribir ---
func _make_look() -> Dictionary:
	return {}


## "citizen", "noble" o "guard": elige el modelo según el estilo de arte (ver Art).
func _role() -> String:
	return "citizen"


func _setup() -> void:
	pass


func _think(_delta: float) -> void:
	pass


func _on_pushed() -> void:
	pass


## Le han golpeado (attacker puede ser null).
func _on_hit(_attacker: Node3D) -> void:
	pass
# -------------------------


func is_down() -> bool:
	return down


## Está peleando (golpeó o le golpearon hace poco): la HUD muestra su barra de vida.
func mark_combat() -> void:
	_combat_ms = Time.get_ticks_msec()


func in_combat() -> bool:
	return Time.get_ticks_msec() - _combat_ms < Player.COMBAT_TIMEOUT * 1000.0


## Cinc (enardecer): imprudente, ataca más rápido y recibe +25 % de daño.
func is_rioted() -> bool:
	return _world_time < _rioted_until


## Latón (aplacar): deja de atacar hasta que se le pase o le golpeen.
func is_soothed() -> bool:
	return _world_time < _soothed_until


func is_frenzied() -> bool:
	return _world_time < _frenzy_until


## Alguien le aplica cinc o latón (strength 2 = avivado). Devuelve false si lo resiste: quien
## quema cobre es inmune a la alomancia emocional.
func apply_emotion(metal: StringName, strength: float, _source: Node3D) -> bool:
	if down or surrendered or _burns_copper():
		return false
	if metal == &"zinc":
		_rioted_until = _world_time + 2.0
		_soothed_until = -1.0
		if strength > 1.0:
			_frenzy_until = _world_time + 2.0
	else:
		_soothed_until = _world_time + 2.0
		_rioted_until = -1.0
		_frenzy_until = -1.0
		if strength > 1.0 and health < max_health * 0.3 and team >= 0:
			_surrender()
	return true


func _burns_copper() -> bool:
	return false


func _surrender() -> void:
	surrendered = true
	team = -1


## Aceleración por su propio empujón/tirón alomántico.
func add_allomantic_acceleration(accel_vec: Vector3, delta: float) -> void:
	velocity += accel_vec * delta
	if accel_vec.length() > 2.0:
		_flying = 0.25


## Programa una velocidad que se aplicará dentro de decision_lead segundos.
func plan_velocity(v: Vector3) -> void:
	_pending = v
	_switch_at = _world_time + decision_lead


func apply_allomantic_impulse(dv: Vector3) -> void:
	velocity += dv
	_knockback = 0.7
	_on_pushed()


## Golpe cuerpo a cuerpo o de moneda: empujón, daño y, si se queda sin vida, noqueado un rato.
func take_hit(impulse: Vector3, damage: float, attacker: Node3D = null) -> void:
	apply_allomantic_impulse(impulse + Vector3.UP * impulse.length() * 0.25)
	if down:
		return
	if attacker:
		mark_combat()
		_soothed_until = -1.0  # un golpe rompe la calma
	if is_rioted():
		damage *= 1.25
	_on_hit(attacker)
	health -= damage
	if health <= 0.0:
		down = true
		_down_until = _world_time + knockout_time
		plan_velocity(Vector3.ZERO)
		_desired = Vector3.ZERO
		if attacker is Player:
			_drop_loot_common(attacker)


func random_point_near_home() -> Vector3:
	var p := home + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * roam_radius
	if not stay_in_plaza:
		return p
	return Vector3(clampf(p.x, -33, 33), 0, clampf(p.z, -33, 33))


func _physics_process(delta: float) -> void:
	_world_time += delta
	if down and _world_time >= _down_until:
		down = false
		health = max_health
	if down:
		_desired = Vector3.ZERO
		_switch_at = INF
	else:
		_think(delta)
	if rig is ModelRig:
		rig.down = down
	else:
		rig.rotation.x = lerpf(rig.rotation.x, PI / 2 if down else 0.0, minf(delta * 6.0, 1.0))  # tumbado
	if _world_time >= _switch_at:
		_desired = _pending
		_switch_at = INF
	_flying -= delta
	if _flying > 0.0 and not is_on_floor():
		pass  # volando por su propia alomancia: conserva el impulso
	elif _knockback > 0.0:
		_knockback -= delta
		if is_on_floor():
			var h := Vector2(velocity.x, velocity.z).move_toward(Vector2.ZERO, 9.0 * delta)
			velocity.x = h.x
			velocity.z = h.y
	else:
		velocity.x = move_toward(velocity.x, _desired.x, accel * delta)
		velocity.z = move_toward(velocity.z, _desired.z, accel * delta)
	velocity.y -= _gravity * delta
	move_and_slide()
	_update_facing(delta)

	rig.move_speed = Vector2(velocity.x, velocity.z).length()
	rig.vertical_speed = velocity.y
	rig.on_floor = is_on_floor()
	rig.body_velocity = velocity
	rig.stagger = move_toward(rig.stagger, 1.0 if _knockback > 0.0 else 0.0, delta * 6.0)


func _update_facing(delta: float) -> void:
	if _knockback > 0.0:
		return
	var dir := Vector2(velocity.x, velocity.z)
	if dir.length() < 0.4 and face_point != null:
		var fp: Vector3 = face_point
		dir = Vector2(fp.x - global_position.x, fp.z - global_position.z)
	if dir.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.y), 7.0 * delta)


func predict_position(t: float) -> Vector3:
	if _knockback > 0.0:
		return global_position + velocity * t
	var until_switch := _switch_at - _world_time
	if until_switch < t:
		var a := maxf(until_switch, 0.0)
		return global_position + _desired * a + _pending * (t - a)
	return global_position + _desired * t


## Al derrotarlo el jugador suelta monedas y, a veces, un frasco o un objeto nuevo. Solo la primera vez.
func _drop_loot_common(player: Player) -> void:
	if _looted:
		return
	_looted = true
	var scene := get_tree().current_scene
	var origin := global_position + Vector3(0, 0.8, 0)
	for i in randi_range(loot_coins.x, loot_coins.y):
		var coin := Props.coin()
		scene.add_child(coin)
		coin.global_position = origin
		var a := randf() * TAU
		coin.linear_velocity = Vector3(cos(a) * randf_range(1.0, 2.5), randf_range(2.5, 4.5), sin(a) * randf_range(1.0, 2.5))
		# Si nadie la recoge, desaparece para no llenar el suelo de monedas.
		get_tree().create_timer(90.0).timeout.connect(func() -> void:
			if is_instance_valid(coin):
				coin.queue_free())
	if randf() < loot_vial_chance:
		var vial := Vial.new()
		vial.kind = &"mix"
		scene.add_child(vial)
		vial.global_position = global_position + Vector3(randf_range(-0.6, 0.6), 0.7, randf_range(-0.6, 0.6))
	if randf() < loot_item_chance:
		var id := ItemPickup.random_new_item(player)
		if id != "":
			var pickup := ItemPickup.new()
			pickup.item_id = id
			scene.add_child(pickup)
			pickup.global_position = global_position + Vector3(0, 0.1, 0)
