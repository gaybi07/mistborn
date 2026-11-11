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
## Vida "fantasma" que baja despacio tras un golpe (la barra de Hud), y hasta cuándo se queda quieta.
var health_trail := -1.0
var trail_hold_ms := 0
## Noqueado: tumbado en el suelo hasta que se recupera.
var down := false
var _down_until := 0.0
## Botín al caer ante el jugador (una sola vez por Npc): monedas (mín, máx), probabilidad de frasco y de objeto.
var loot_coins := Vector2i(1, 3)
var loot_vial_chance := 0.05
var loot_item_chance := 0.0
var _looted := false
## Experiencia que da derrotarlo (ver Progression).
var xp_reward := 60
## Bando: -1 = gente que no pelea; 0 = el jugador y sus aliados; 1, 2... = otros bandos.
var team := -1

var home := Vector3.ZERO
var roam_radius := 12.0
## Si es true, los destinos se limitan a la plaza.
var stay_in_plaza := true
var rig: HumanoidRig
## Alto del cuerpo (m): el del modelo; la barra de vida y los avisos flotan sobre la cabeza (ver head_y).
var body_height := 1.8
## Vector3 hacia el que se gira cuando está quieto, o null.
var face_point: Variant = null

var _world_time := 0.0
var _step_acc := 0.0
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
## Aturdido (le hicieron parry): no piensa ni ataca hasta _stun_until.
var _stun_until := -1.0
## Desarmado con hierro: hasta _disarmed_until pega mucho menos.
var _disarmed_until := -1.0
## Poderes del cinc del jugador (L7, ver ZincPowers): pánico (huye), codicia (va a una moneda), lealtad (domado: sigue
## a su dueño y pelea por él) e ira contra otro NPC (Tormenta). Mientras dura alguno, manda sobre _think.
var _panic_until := -1.0
var _panic_from := Vector3.ZERO
var _greed_until := -1.0
var _greed_point := Vector3.ZERO
var _tame_until := -1.0
var tamed_by: Node3D = null
var _rage_foe: Npc = null
var _rage_until := -1.0
var _next_emotion_strike := 0.0
var _emotion_replan := 0.0
## A quién va la experiencia de lo que mate mientras dura (Ira del cinc: la mitad; domado: toda).
var _xp_to: Node3D = null
var _xp_share := 0.0
var _xp_until := -1.0
const EMOTION_REACH := 2.2
const EMOTION_DAMAGE := 12.0
## Latón (L8, ver BrassPowers): desalentado pega menos, se mueve más lento y no bloquea.
var _dishearten_until := -1.0
## Cobre (L9, ver CopperPowers): te perdió de vista hasta _lost_until; bajo tu nube (inmune) hasta _cloud_until.
var _lost_until := -1.0
var _cloud_until := -1.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	add_to_group(&"npc")
	add_to_group(&"combatant")
	add_to_group(&"atium_visible")
	collision_layer = Props.LAYER_PROPS
	collision_mask = Props.LAYER_WORLD | Props.LAYER_PROPS | Props.LAYER_PLAYER
	var look := _make_look()
	rig = Art.npc_rig(_role(), look)
	add_child(rig)
	if rig is ModelRig:
		body_height = (rig as ModelRig).target_height
	# Cuerpo, centro de masa y masa alomántica crecen con el alto (1,8 m = el tamaño de siempre).
	var grow := body_height / 1.8
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32 * lerpf(1.0, grow, 0.7)
	shape.height = body_height
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = body_height * 0.5
	add_child(col)
	set_meta(&"center_offset", Vector3(0, body_height * 0.667, 0))
	_setup()
	allomantic_mass *= grow * grow
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


## Altura (m) sobre sus pies a la que flotan su barra de vida y sus avisos.
func head_y(extra := 0.35) -> float:
	return body_height + extra


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
		_rioted_until = maxf(_rioted_until, _world_time + 2.0)  # no acorta una Furia más larga
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
	return _world_time < _cloud_until  # bajo la Nube compartida del jugador (cobre)


# ---------------------------------------------------------------- Cinc (L7)

## Si le hacen efecto los poderes del cinc: en pie, sin rendirse y sin cobre.
func feels_emotions() -> bool:
	return not down and not surrendered and not _burns_copper()


## Ira (cinc): enardecido `time` s; si mata a alguien en ese tiempo, `share` de la experiencia va a `who`.
func riot_for(time: float, who: Node3D, share: float) -> bool:
	if not feels_emotions():
		return false
	_rioted_until = maxf(_rioted_until, _world_time + time)
	_soothed_until = -1.0
	_share_xp(who, share, time)
	return true


## Pánico: huye de `from` durante `time` s (y suelta la guardia).
func panic_for(time: float, from: Vector3) -> bool:
	if not feels_emotions():
		return false
	_panic_until = maxf(_panic_until, _world_time + time)
	_panic_from = from
	_emotion_replan = 0.0
	_tame_until = -1.0
	return true


## Avaricia: va a buscar la moneda de `point` durante `time` s.
func greed_for(time: float, point: Vector3) -> bool:
	if not feels_emotions():
		return false
	_greed_until = _world_time + time
	_greed_point = point
	_emotion_replan = 0.0
	return true


## Si se deja domar (los jefes no: ver Champion).
func can_be_tamed() -> bool:
	return true


## Domar: sigue a `who` y pelea por él `time` s (los fuertes, menos); toda la experiencia de lo que mate es suya.
func tame_for(time: float, who: Node3D) -> bool:
	if not feels_emotions() or not can_be_tamed():
		return false
	if max_health > 100.0:
		time *= SkillTree.ZINC_TAME_STRONG
	_tame_until = _world_time + time
	tamed_by = who
	_emotion_replan = 0.0
	_panic_until = -1.0
	_greed_until = -1.0
	_share_xp(who, 1.0, time)
	return true


func untame() -> void:
	_tame_until = -1.0
	tamed_by = null
	_xp_until = -1.0


func is_tamed() -> bool:
	return _world_time < _tame_until and is_instance_valid(tamed_by)


## Tormenta: pelea contra `foe` durante `time` s.
func rage_at(foe: Npc, time: float) -> void:
	_rage_foe = foe
	_rage_until = _world_time + time
	_emotion_replan = 0.0


## Quién se lleva experiencia si este NPC mata a alguien ahora (null = nadie).
func xp_receiver() -> Node3D:
	return _xp_to if _world_time < _xp_until and is_instance_valid(_xp_to) else null


func _share_xp(who: Node3D, share: float, time: float) -> void:
	if who == null:
		return
	_xp_to = who
	_xp_share = maxf(share, _xp_share if xp_receiver() != null else 0.0)
	_xp_until = maxf(_xp_until, _world_time + time)


# ---------------------------------------------------------------- Latón (L8)

## Calma: deja de atacar `time` s (un golpe lo despierta, ver take_hit).
func soothe_for(time: float) -> bool:
	if not feels_emotions():
		return false
	_soothed_until = maxf(_soothed_until, _world_time + time)
	_rioted_until = -1.0
	_frenzy_until = -1.0
	_rage_until = -1.0
	return true


## Desaliento: `time` s pegando un 40 % menos, más lento y sin bloquear.
func dishearten_for(time: float) -> bool:
	if not feels_emotions():
		return false
	_dishearten_until = maxf(_dishearten_until, _world_time + time)
	return true


func is_disheartened() -> bool:
	return _world_time < _dishearten_until


## Cuánto de su velocidad usa (desalentado, menos).
func _speed_scale() -> float:
	return 0.6 if is_disheartened() else 1.0


## Rendición: con poca vida se rinde ante `who`; suelta el arma y el botín, y `who` se lleva `xp_share` de su experiencia.
func yield_to(who: Player, xp_share: float) -> bool:
	if not feels_emotions() or not can_be_tamed() or health > max_health * SkillTree.BRASS_YIELD_HEALTH:
		return false
	_surrender()
	disarm(1e6)
	untame()
	_drop_loot_common(who, xp_share)
	return true


# ---------------------------------------------------------------- Cobre (L9)

## Desvanecerse / Fantasma: deja de seguirte `time` s y se queda buscando.
func lose_track(time: float) -> void:
	if not down and not is_tamed():
		_lost_until = maxf(_lost_until, _world_time + time)


## Nube compartida: `time` s bajo la nube del jugador (inmune al cinc y al latón ajenos).
func cloud_for(time: float) -> void:
	_cloud_until = maxf(_cloud_until, _world_time + time)


## Lo que manda el cinc en vez de _think. Devuelve false si no hay ninguna emoción en marcha.
func _emotion_think(delta: float) -> bool:
	if surrendered:
		_emotion_move(Vector3.ZERO)  # rendido (latón): se queda quieto, sin pelear
		face_point = null
		return true
	if _world_time < _lost_until and not is_tamed():
		_emotion_move(Vector3.ZERO)  # te perdió de vista (cobre): se queda buscando
		face_point = null
		return true
	if _panic_until > 0.0 and _world_time >= _panic_until:
		_panic_until = -1.0
		rig.panic = 0.0  # se le pasó el susto (el ciudadano maneja el suyo aparte)
	if _world_time < _panic_until:
		var away := global_position - _panic_from
		away.y = 0.0
		_emotion_move((away.normalized() if away.length() > 0.1 else -global_basis.z) * run_speed)
		face_point = null
		rig.panic = 1.0
		return true
	if is_tamed():
		var foe := _tame_foe()
		if foe:
			_emotion_fight(foe, delta)
		else:
			var to := tamed_by.global_position - global_position
			to.y = 0.0
			face_point = tamed_by.global_position
			_emotion_move(to.normalized() * run_speed if to.length() > 3.0 else Vector3.ZERO)
		return true
	if _world_time < _greed_until:
		var to := _greed_point - global_position
		to.y = 0.0
		face_point = _greed_point
		_emotion_move(to.normalized() * run_speed if to.length() > 1.0 else Vector3.ZERO)
		return true
	if _world_time < _rage_until and is_instance_valid(_rage_foe) and not _rage_foe.down:
		_emotion_fight(_rage_foe, delta)
		return true
	return false


## Domado: el enemigo más cercano a su dueño que esté peleando (koloss, espectros, alománticos o quien esté en combate).
func _tame_foe() -> Npc:
	var best: Npc = null
	var best_d := 14.0
	for n in get_tree().get_nodes_in_group(&"npc"):
		var npc := n as Npc
		if npc == null or npc == self or npc.down or npc.is_tamed():
			continue
		var hostile := npc.in_combat() or npc.is_in_group(&"koloss") or npc.is_in_group(&"wraith") or npc.is_in_group(&"allomancer")
		var d := npc.global_position.distance_to(tamed_by.global_position)
		if hostile and d < best_d:
			best = npc
			best_d = d
	return best


## Va hacia `foe` y le pega cuando lo tiene a tiro (el golpe llega en el impacto de la animación, como el guardia).
func _emotion_fight(foe: Npc, _delta: float) -> void:
	face_point = foe.global_position
	var to := foe.global_position - global_position
	to.y = 0.0
	_emotion_move(to.normalized() * run_speed * (1.3 if is_rioted() else 1.0) if to.length() > EMOTION_REACH * 0.8 else Vector3.ZERO)
	if to.length() > EMOTION_REACH or _world_time < _next_emotion_strike:
		return
	_next_emotion_strike = _world_time + (0.9 if is_rioted() else 1.4)
	rig.play_attack(1, 0.6)
	get_tree().create_timer(rig.impact_delay(), false).timeout.connect(func() -> void:
		if down or is_stunned() or not is_instance_valid(foe) or foe.down:
			return
		var hit := foe.global_position - global_position
		hit.y = 0.0
		if hit.length() <= EMOTION_REACH + 0.5:
			Sfx.play("slash", foe.global_position + Vector3(0, 1.2, 0))
			foe.take_hit(hit.normalized() * 5.0, EMOTION_DAMAGE, self))


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


## Lleva un arma de metal que se le puede quitar (lo definen los que pelean con ella).
func is_armed() -> bool:
	return false


func is_disarmed() -> bool:
	return _world_time < _disarmed_until


## Vuelve a empuñar el arma cuando se acaba el desarme.
func _rearm_check() -> void:
	if _disarmed_until > 0.0 and _world_time >= _disarmed_until:
		_disarmed_until = -1.0
		if rig.spear_grip != null:
			rig.spear_grip.visible = true


## Se le quita el arma `time` s (ver Player.start_disarm): la guarda y pega mucho menos.
func disarm(time: float) -> void:
	_disarmed_until = _world_time + time
	rig.set_weapon(HumanoidRig.Weapon.NONE)
	if rig.spear_grip != null:
		rig.spear_grip.visible = false


## Arrastre de hierro: lo lleva hacia `dir` (en horizontal) a `speed`, sin que su propio movimiento lo frene.
func pull_toward(dir: Vector3, speed: float, delta: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		return
	var want := flat.normalized() * speed
	velocity.x = move_toward(velocity.x, want.x, 90.0 * delta)
	velocity.z = move_toward(velocity.z, want.z, 90.0 * delta)
	_knockback = 0.3


func is_stunned() -> bool:
	return _world_time < _stun_until


## Aturdido `time` s (0: solo la animación de caer hacia atrás) por un golpe que vino de `from`.
func stun(time: float, from: Vector3) -> void:
	_stun_until = _world_time + time if time > 0.0 else -1.0
	plan_velocity(Vector3.ZERO)
	_desired = Vector3.ZERO
	if not down:
		rig.play_hit(from, true, true)


## Golpe cuerpo a cuerpo o de moneda: empujón, daño y, si se queda sin vida, noqueado un rato.
## Pasos de la gente que está cerca de la cámara (los demás no se oirían).
func _footsteps(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.6 or not is_on_floor():
		return
	_step_acc += speed * delta
	if _step_acc >= clampf(0.45 + speed * 0.13, 0.65, 1.7):
		_step_acc = 0.0
		var cam := get_viewport().get_camera_3d()
		if cam and cam.global_position.distance_to(global_position) < 18.0:
			Sfx.step(self, -4.0)


func take_hit(impulse: Vector3, damage: float, attacker: Node3D = null) -> void:
	apply_allomantic_impulse(impulse + Vector3.UP * impulse.length() * 0.25)
	if down:
		return
	if attacker:
		mark_combat()
		_soothed_until = -1.0  # un golpe rompe la calma
	if is_rioted():
		damage *= 1.25
	if attacker is Npc and (attacker as Npc).is_disheartened():
		damage *= 0.6  # Desaliento (latón)
	if attacker != null and attacker.has_method(&"mark_bonus"):
		damage *= attacker.mark_bonus(self)  # Marca del cazador (estaño)
	if attacker is Player:
		damage *= (attacker as Player).strike_bonus(self)  # golpe a traición (cobre), atium
	_on_hit(attacker)
	if damage > 0.0:
		rig.flash()
		HumanoidRig.hit_stop([rig, attacker.get(&"rig") if attacker else null], damage)
		if attacker:
			rig.play_hit(attacker.global_position, damage >= 20.0)
		health_trail = maxf(health_trail, health)
		trail_hold_ms = Time.get_ticks_msec() + 700
		if attacker is Player:
			Fx.popup(get_tree().current_scene, global_position + Vector3(randf_range(-0.3, 0.3), head_y() + 0.1, randf_range(-0.3, 0.3)), str(roundi(damage)), Color.WHITE)
	health -= damage
	if health <= 0.0:
		down = true
		_down_until = _world_time + knockout_time
		plan_velocity(Vector3.ZERO)
		_desired = Vector3.ZERO
		if attacker is Player:
			_drop_loot_common(attacker)
		elif attacker is Npc and not _looted and (attacker as Npc).xp_receiver() != null:
			_looted = true  # lo mató un NPC enardecido o domado por el jugador: le toca su parte
			(attacker as Npc).xp_receiver().call(&"grant_xp", roundi(xp_reward * (attacker as Npc)._xp_share))


func random_point_near_home() -> Vector3:
	var p := home + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * roam_radius
	if not stay_in_plaza:
		return p
	return Vector3(clampf(p.x, -33, 33), 0, clampf(p.z, -33, 33))


func _physics_process(delta: float) -> void:
	_world_time += delta
	_rearm_check()
	if down and _world_time >= _down_until:
		down = false
		health = max_health
	if down or is_stunned():
		_desired = Vector3.ZERO
		_switch_at = INF
	elif not _emotion_think(delta):
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
		velocity.x = move_toward(velocity.x, _desired.x * _speed_scale(), accel * delta)
		velocity.z = move_toward(velocity.z, _desired.z * _speed_scale(), accel * delta)
	velocity.y -= _gravity * delta
	move_and_slide()
	_footsteps(delta)
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
func _drop_loot_common(player: Player, xp_scale := 1.0) -> void:
	if _looted:
		return
	_looted = true
	player.grant_xp(roundi(xp_reward * xp_scale))
	var scene := get_tree().current_scene
	var origin := global_position + Vector3(0, 0.8, 0)
	for i in randi_range(loot_coins.x, loot_coins.y):
		var coin := Props.coin()
		scene.add_child(coin)
		coin.global_position = origin
		var a := randf() * TAU
		coin.linear_velocity = Vector3(cos(a) * randf_range(1.0, 2.5), randf_range(2.5, 4.5), sin(a) * randf_range(1.0, 2.5))
		# Si nadie la recoge, desaparece para no llenar el suelo de monedas.
		get_tree().create_timer(90.0).timeout.connect(coin.queue_free)
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


## Como plan_velocity, pero espaciada más que su tiempo de reacción (decision_lead): llamarla antes de que llegue
## la orden anterior la posterga para siempre.
func _emotion_move(v: Vector3) -> void:
	if _world_time >= _emotion_replan:
		_emotion_replan = _world_time + decision_lead + 0.2
		plan_velocity(v)


## Distancia a la que este NPC nota a `n`: `base` por lo que se esconda (Player.concealment: ropa, Sosiego, Silencio).
static func sight(n: Node3D, base: float) -> float:
	return base * (n.call(&"concealment") as float if n != null and n.has_method(&"concealment") else 1.0)
