class_name AllomancerNpc
extends Npc
## Alománticos que no son el jugador: brumosos (un solo metal) y nacidos de la bruma.
## Queman metales con su propia Allomancy, empujan y tiran con la misma física que el jugador
## (Metals.push_pull) y pelean según su poder.
##
## Solo actúan contra alguien si lo detectan:
##   - con la vista: la bruma la limita a unos metros; el estaño la amplía;
##   - con el bronce (Buscador, algunos nacidos de la bruma): sienten a quien queme metales,
##     salvo que solo queme cobre o esté dentro de una nube de cobre. Avisan a los suyos.
## Sus líneas de acero/hierro no se ven (como en los libros, solo ves las tuyas), salvo en el
## modo espectador de la arena (show_label).

enum Kind { THUG, COINSHOT, LURCHER, TINEYE, SMOKER, SEEKER, MISTBORN, SOOTHER, RIOTER }

const KEYS := {Kind.THUG: "thug", Kind.COINSHOT: "coinshot", Kind.LURCHER: "lurcher", Kind.TINEYE: "tineye",
		Kind.SMOKER: "smoker", Kind.SEEKER: "seeker", Kind.MISTBORN: "mistborn", Kind.SOOTHER: "soother",
		Kind.RIOTER: "rioter"}
const NAMES := {Kind.THUG: "Violento", Kind.COINSHOT: "Lanzamonedas", Kind.LURCHER: "Atraedor",
		Kind.TINEYE: "Ojo de estaño", Kind.SMOKER: "Humeador", Kind.SEEKER: "Buscador",
		Kind.MISTBORN: "Nacido de la bruma", Kind.SOOTHER: "Aplacador", Kind.RIOTER: "Encendedor"}
## Alcance de la alomancia emocional (Aplacador y Encendedor).
const EMOTION_RANGE := 20.0
const TEAM_COLORS := [Color(0.45, 0.7, 1.0), Color(1.0, 0.45, 0.4), Color(0.6, 1.0, 0.5), Color(1.0, 0.85, 0.4)]
const REACH := 40.0  ## alcance de su acero/hierro
const ALERT_RADIUS := 35.0

@export var kind := Kind.THUG
## Si es false, solo pelea si le atacan o le empujan.
var aggressive := true
## Muestra nombre, vida y sus líneas de acero/hierro (solo para el modo espectador de la arena).
var show_label := false
## Sabe dónde están sus enemigos (duelo en la arena). En la ciudad tiene que detectarlos.
var knows_enemies := false
## Nacido de la bruma con espada en vez de dagas (golpes más lentos, largos y fuertes).
var sword := false
## Atium que lleva encima (solo nacidos de la bruma; -1 = al azar en _setup). No se recarga.
var atium := -1.0
## Golpes esquivados gracias al atium (para el modo espectador).
var atium_dodges := 0

var allomancy: Allomancy
var target: Node3D = null

var _bolts: BoltMesh
var _label: Label3D
var _grips := []  # {"target": Node3D, "sign": float, "metal": StringName, "until": float}
var _cooldown := 0.0
var _melee_cd := 0.0
var _jump_cd := 0.0
var _replan_at := 0.0
var _wander_at := 0.0
var _seen_at := 0.0
var _uses_copper := false
var _in_combat := false
var _vision_timer := 0.0


func _role() -> String:
	return "allomancer:" + KEYS[kind] + ("_sword" if sword and kind == Kind.MISTBORN else "")


func _make_look() -> Dictionary:
	# Solo se usa con el estilo procedural.
	var look := {"shirt": Color(0.2, 0.2, 0.22), "pants": Color(0.12, 0.12, 0.13), "hat": "hood"}
	if kind == Kind.MISTBORN:
		look["cloak"] = true
		look["daggers"] = true
	if kind == Kind.THUG:
		look["build"] = 1.25
		look["sword"] = true
	return look


func _setup() -> void:
	loot_coins = Vector2i(3, 6)
	loot_vial_chance = 0.5
	add_to_group(&"allomancer")
	add_to_group(&"allomancer_body")
	add_to_group(&"metal")  # todos llevan monedas encima
	allomancy = Allomancy.new()
	add_child(allomancy)
	_bolts = BoltMesh.new()
	add_child(_bolts)
	var aura := PewterAura.new()
	aura.holder = self
	add_child(aura)
	if kind == Kind.MISTBORN:
		var swirl := MistSwirl.new()
		swirl.holder = self
		add_child(swirl)
		_uses_copper = randf() < 0.5  # algunos se ocultan del bronce
	decision_lead = 0.2
	if atium < 0.0:
		atium = 15.0 if kind == Kind.MISTBORN and randf() < 0.3 else 0.0
	allomancy.reserve[&"atium"] = atium if kind == Kind.MISTBORN else 0.0
	match kind:
		Kind.THUG:
			max_health = 140.0
			allomantic_mass = 95.0
			run_speed = 5.0
		Kind.MISTBORN:
			max_health = 120.0
			run_speed = 5.5
		_:
			max_health = 70.0
			run_speed = 4.6
	if show_label:
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.font_size = 40
		_label.outline_size = 8
		_label.pixel_size = 0.007
		_label.position = Vector3(0, 2.15, 0)
		_label.modulate = TEAM_COLORS[clampi(team, 0, TEAM_COLORS.size() - 1)]
		add_child(_label)


# ---------------------------------------------------------------- Percepción

func _is_enemy(n: Node) -> bool:
	if n == self or not is_instance_valid(n):
		return false
	var other_team: int = n.team
	return other_team >= 0 and other_team != team and not n.is_down()


func _can_perceive(n: Node3D) -> bool:
	if knows_enemies:
		return true
	var d := global_position.distance_to(n.global_position)
	var sight := Art.sight_range()  # la niebla, la noche y el clima limitan la vista
	sight *= 1.0 + 1.4 * allomancy.strength(&"tin")
	if n.has_method(&"concealment"):
		sight *= n.concealment()  # capa de bruma y traje oscuro
	if d <= sight and _line_of_sight(n):
		return true
	var bronze := allomancy.strength(&"bronze")
	if bronze > 0.0 and n.is_in_group(&"allomancer_body") and d <= 60.0 * bronze and Metals.emits_pulses(n):
		return true
	return false


func _line_of_sight(n: Node3D) -> bool:
	var from := global_position + Vector3(0, 1.6, 0)
	var to := n.global_position + Vector3(0, 1.2, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to, Props.LAYER_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _update_target() -> void:
	if surrendered or is_soothed():
		target = null  # aplacado: se olvida de pelear mientras le dure
		return
	if target and (not is_instance_valid(target) or target.is_down()):
		target = null
	if is_frenzied():
		var ally := _nearest_ally(15.0)
		if ally:
			target = ally  # cinc avivado: la toma con uno de los suyos
			return
	elif target and target.get(&"team") == team:
		target = null  # se le pasó el frenesí
	if target:
		if _can_perceive(target):
			_seen_at = _world_time
			# Te persigue y te ve: es combate (aparecen las barras de vida de los dos).
			if target is Player and aggressive and not is_frenzied() \
					and global_position.distance_to(target.global_position) < 30.0:
				mark_combat()
				target.mark_combat()
		elif _world_time - _seen_at > 4.0:
			target = null  # lo perdió de vista
		return
	if not aggressive:
		return
	var best: Node3D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(&"combatant"):
		if not _is_enemy(n) or not _can_perceive(n):
			continue
		var d := global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	if best:
		_engage(best)


func _engage(t: Node3D) -> void:
	if surrendered:
		return
	target = t
	aggressive = true
	_seen_at = _world_time
	# Avisa a los suyos cercanos (el Ojo de estaño y el Buscador sirven de vigías).
	for n in get_tree().get_nodes_in_group(&"allomancer"):
		var ally := n as AllomancerNpc
		if ally and ally != self and ally.team == team and ally.target == null and not ally.down \
				and ally.global_position.distance_to(global_position) < ALERT_RADIUS:
			ally.target = t
			ally.aggressive = true
			ally._seen_at = ally._world_time


## El peltre endurece el cuerpo: menos daño (quemando ~40 %, avivando ~55 %).
func take_hit(impulse: Vector3, damage: float, attacker: Node3D = null) -> void:
	if attacker and not down and Metals.atium_edge(self, attacker):
		# Vio venir el golpe con el atium: se aparta.
		var side := (global_position - attacker.global_position).cross(Vector3.UP).normalized()
		velocity += side * (5.0 if randf() < 0.5 else -5.0)
		_flying = 0.2
		atium_dodges += 1
		mark_combat()
		_on_hit(attacker)
		Fx.sparks(get_tree().current_scene, Metals.center_of(self), Metals.ATIUM_COLOR)
		_popup("esquiva")
		return
	var pewter := allomancy.strength(&"pewter")
	var was_down := down
	super(impulse / (1.0 + 0.5 * pewter), damage / (1.0 + 0.6 * pewter), attacker)
	if down and not was_down and attacker is Player:
		_drop_loot(attacker)


## Derrotado por el jugador: a veces suelta un objeto que todavía no tiene.
const LOOT_CHANCE := 0.4


func _drop_loot(player: Player) -> void:
	if randf() > LOOT_CHANCE:
		return
	var id := ItemPickup.random_new_item(player)
	if id == "":
		return
	var pickup := ItemPickup.new()
	pickup.item_id = id
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = global_position + Vector3(0, 0.1, 0)


func _on_hit(attacker: Node3D) -> void:
	if attacker and attacker != self and (target == null or not aggressive):
		var other_team: int = attacker.team
		if other_team != team and other_team >= 0:
			_engage(attacker)


func _burns_copper() -> bool:
	return allomancy.is_burning(&"copper")


func _surrender() -> void:
	super()
	aggressive = false
	target = null
	_grips.clear()
	_set_combat(false)
	Fx.sparks(get_tree().current_scene, Metals.center_of(self), Color(0.55, 0.75, 0.6))


func _nearest_ally(max_d: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_d
	for n in get_tree().get_nodes_in_group(&"allomancer"):
		var a := n as AllomancerNpc
		if a and a != self and a.team == team and not a.down:
			var d := a.global_position.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = a
	return best


func _on_pushed() -> void:
	# Alguien le ha empujado o tirado de él: si el jugador está cerca y usando acero/hierro, es él.
	if target != null:
		return
	var p := get_tree().get_first_node_in_group(&"player") as Player
	if p and p.team != team and p.steel_iron.applying_force and p.global_position.distance_to(global_position) < 45.0:
		_engage(p)


# ---------------------------------------------------------------- Decisiones

func _think(delta: float) -> void:
	# Enardecido: ataca más seguido (y sin cubrirse; ver take_hit en Npc).
	var haste := 1.5 if is_rioted() else 1.0
	_cooldown -= delta * haste
	_melee_cd -= delta * haste
	_jump_cd -= delta
	for m in Allomancy.METALS:
		if m != &"atium":
			allomancy.refill(m, 2.0 * delta)  # llevan frascos de sobra (el atium no se recarga)
	_update_target()
	_set_combat(target != null)
	_passive_metals()
	if target == null:
		_wander()
	else:
		face_point = target.global_position
		match kind:
			Kind.THUG:
				_think_thug()
			Kind.COINSHOT:
				_think_coinshot()
			Kind.LURCHER:
				_think_lurcher()
			Kind.MISTBORN:
				_think_mistborn()
			Kind.SOOTHER, Kind.RIOTER:
				_think_support()
				_think_emotions()
			_:
				_think_support()
	_apply_grips(delta)


func _set_combat(on: bool) -> void:
	if on == _in_combat:
		return
	_in_combat = on
	if kind == Kind.MISTBORN:
		var w := HumanoidRig.Weapon.SWORD if sword else HumanoidRig.Weapon.DAGGERS
		rig.set_weapon(w if on else HumanoidRig.Weapon.NONE)
	elif kind == Kind.THUG:
		rig.set_weapon(HumanoidRig.Weapon.SWORD if on else HumanoidRig.Weapon.NONE)
	if not on:
		for m in [&"steel", &"iron", &"pewter"]:
			allomancy.set_state(m, Allomancy.State.OFF)
		face_point = null


func _passive_metals() -> void:
	var fight := _in_combat
	match kind:
		Kind.TINEYE:
			allomancy.set_state(&"tin", Allomancy.State.FLARE if fight else Allomancy.State.BURN)
		Kind.SMOKER:
			allomancy.set_state(&"copper", Allomancy.State.FLARE if fight else Allomancy.State.BURN)
		Kind.SEEKER:
			allomancy.set_state(&"bronze", Allomancy.State.FLARE if fight else Allomancy.State.BURN)
		Kind.SOOTHER, Kind.RIOTER:
			var metal := &"brass" if kind == Kind.SOOTHER else &"zinc"
			allomancy.set_state(metal, Allomancy.State.BURN if fight else Allomancy.State.OFF)
		Kind.MISTBORN:
			allomancy.set_state(&"tin", Allomancy.State.BURN)
			allomancy.set_state(&"bronze", Allomancy.State.BURN)
			allomancy.set_state(&"copper", Allomancy.State.BURN if _uses_copper else Allomancy.State.OFF)
			allomancy.set_state(&"pewter", Allomancy.State.BURN if fight else Allomancy.State.OFF)
			# Atium: lo enciende si el rival lo quema (es lo único que lo contrarresta) o si va
			# perdiendo; una vez encendido no lo suelta hasta que se acaba la pelea o el atium.
			var rival := target != null and Metals.burns_atium(target)
			var want: bool = fight and allomancy.reserve[&"atium"] > 0.0 \
					and (allomancy.is_burning(&"atium") or rival or health < max_health * 0.6)
			allomancy.set_state(&"atium", Allomancy.State.BURN if want else Allomancy.State.OFF)


func _wander() -> void:
	if _world_time >= _wander_at:
		_wander_at = _world_time + randf_range(4.0, 8.0)
		var to := random_point_near_home() - global_position
		to.y = 0.0
		plan_velocity(to.normalized() * walk_speed if to.length() > 1.0 else Vector3.ZERO)


## Cambia de rumbo como mucho cada 0,3 s (el plan tarda decision_lead en aplicarse).
func _steer(v: Vector3) -> void:
	if _world_time < _replan_at:
		return
	_replan_at = _world_time + 0.3
	if is_on_wall() and v.length() > 0.1:
		v = v.rotated(Vector3.UP, randf_range(0.8, 1.6) * (1.0 if randf() < 0.5 else -1.0))
	plan_velocity(v)


func _to_target() -> Vector3:
	var to := target.global_position - global_position
	to.y = 0.0
	return to


func _think_thug() -> void:
	var to := _to_target()
	var d := to.length()
	allomancy.set_state(&"pewter", Allomancy.State.FLARE if d < 6.0 else Allomancy.State.BURN)
	var pewter := allomancy.strength(&"pewter")
	_steer(to.normalized() * run_speed * (1.0 + 0.4 * pewter) if d > 1.8 else Vector3.ZERO)
	if d < 2.5 and _melee_cd <= 0.0:
		_melee(14.0, 5.0, 2.7, 1.0)


func _think_coinshot() -> void:
	var to := _to_target()
	var d := to.length()
	allomancy.set_state(&"steel", Allomancy.State.FLARE if d < 7.0 or health < max_health * 0.4 else Allomancy.State.BURN)
	if d < 6.0 and not is_rioted():  # enardecido no retrocede
		_steer(-to.normalized() * run_speed)
		if is_on_floor() and _jump_cd <= 0.0:
			_steel_jump(-to.normalized())  # se aleja saltando sobre una moneda
	elif d > 16.0:
		_steer(to.normalized() * run_speed * 0.8)
	else:
		_steer(Vector3.ZERO)
	if _cooldown <= 0.0 and d < 24.0 and _line_of_sight(target):
		_shoot_coin()
		_cooldown = 0.9 if allomancy.is_flaring(&"steel") else 1.4
	elif _cooldown <= 0.0 and d < 10.0 and target.is_in_group(&"metal"):
		_start_grip(target, 1.0, &"steel", 0.5)  # te empuja lejos por tus monedas
		_cooldown = 2.0


func _think_lurcher() -> void:
	var to := _to_target()
	var d := to.length()
	allomancy.set_state(&"iron", Allomancy.State.FLARE if d > 10.0 else Allomancy.State.BURN)
	if _cooldown <= 0.0 and d < 20.0 and d > 3.0 and target.is_in_group(&"metal"):
		_start_grip(target, -1.0, &"iron", 0.9)  # te atrae hacia él
		_cooldown = 3.0
	_steer(to.normalized() * run_speed * 0.6 if d > 2.5 else Vector3.ZERO)
	if d < 2.3 and _melee_cd <= 0.0:
		_melee(8.0, 4.0, 2.5, 1.0)


## Ojo de estaño, Humeador y Buscador: no son luchadores. Vigilan, avisan y se mantienen
## a distancia (el Humeador se queda cerca de sus aliados para cubrirlos con su nube).
func _think_support() -> void:
	var to := _to_target()
	var d := to.length()
	if kind == Kind.SMOKER:
		var ally := _nearest_fighting_ally()
		if ally:
			var to_ally := ally.global_position - global_position
			to_ally.y = 0.0
			_steer(to_ally.normalized() * run_speed if to_ally.length() > 4.0 else Vector3.ZERO)
			return
	if d < 9.0:
		_steer(-to.normalized() * run_speed)
	elif d > 18.0:
		_steer(to.normalized() * walk_speed)
	else:
		_steer(Vector3.ZERO)
	if d < 2.0 and _melee_cd <= 0.0:
		_melee(6.0, 3.0, 2.2, 1.2)


## Aplacador / Encendedor: le aplica latón o cinc a su objetivo (cerca y a la vista). Aviva si
## está muy cerca. El cobre del objetivo lo protege.
func _think_emotions() -> void:
	var metal := &"brass" if kind == Kind.SOOTHER else &"zinc"
	var d := global_position.distance_to(target.global_position)
	if d > EMOTION_RANGE or not _line_of_sight(target):
		return
	allomancy.set_state(metal, Allomancy.State.FLARE if d < 8.0 else Allomancy.State.BURN)
	if target.has_method(&"apply_emotion"):
		target.apply_emotion(metal, allomancy.strength(metal), self)


func _nearest_fighting_ally() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(&"allomancer"):
		var a := n as AllomancerNpc
		if a and a != self and a.team == team and a.target != null and not a.down:
			var d := a.global_position.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = a
	return best


func _think_mistborn() -> void:
	var to := _to_target()
	var d := to.length()
	var dir := to.normalized()
	allomancy.set_state(&"pewter", Allomancy.State.FLARE if d < 4.0 else Allomancy.State.BURN)
	if d > 14.0:
		# Lejos: se acerca corriendo, saltando con monedas o atrayéndote si llevas metal.
		_steer(dir * run_speed * 1.3)
		if _cooldown <= 0.0:
			_cooldown = 2.2
			if target.is_in_group(&"metal") and randf() < 0.6:
				_start_grip(target, -1.0, &"iron", 0.6)
			elif is_on_floor() and _jump_cd <= 0.0:
				_steel_jump(dir)
	elif d > 3.2:
		_steer(dir * run_speed)
		if _cooldown <= 0.0:
			_cooldown = randf_range(0.8, 1.3)
			var r := randf()
			if r < 0.55:
				_shoot_coin()
			elif r < 0.8 and target.is_in_group(&"metal"):
				_start_grip(target, -1.0, &"iron", 0.45)  # te acerca para rematarte con las dagas
			elif is_on_floor() and _jump_cd <= 0.0:
				_steel_jump(dir.rotated(Vector3.UP, PI / 2 * (1.0 if randf() < 0.5 else -1.0)))  # esquiva lateral
	else:
		_steer(Vector3.ZERO)
		if _melee_cd <= 0.0:
			if sword:
				_melee(17.0, 6.0, 2.9, 0.95)
			else:
				_melee(11.0, 4.0, 2.4, 0.6)


# ---------------------------------------------------------------- Acciones

## Golpe cuerpo a cuerpo con arma o puños; el peltre lo hace más rápido, fuerte y potente.
func _melee(damage: float, knockback: float, reach: float, cooldown: float) -> void:
	var pewter := allomancy.strength(&"pewter")
	_melee_cd = cooldown / (1.0 + 0.5 * pewter)
	var to := _to_target()
	rotation.y = atan2(-to.x, -to.z)
	rig.play_attack(1, 0.55 / (1.0 + 0.4 * pewter))
	var t := target
	var windup := 0.25 / (1.0 + 0.4 * pewter)
	get_tree().create_timer(windup, false).timeout.connect(func() -> void:
		if down or not is_instance_valid(t) or t.is_down():
			return
		var now := t.global_position - global_position
		now.y = 0.0
		# Con atium (y el rival sin él) sabe adónde se va a mover: el golpe llega igual.
		var lead := 1.2 if Metals.atium_edge(self, t) else 0.0
		if now.length() <= reach + lead:
			t.take_hit(now.normalized() * knockback * (1.0 + pewter), damage * (1.0 + 0.75 * pewter), self)
			Fx.sparks(get_tree().current_scene, t.global_position + Vector3(0, 1.2, 0), Color(1.0, 0.6, 0.4))
	)


## Lanza una moneda hacia el objetivo y la empuja con acero para dispararla.
func _shoot_coin() -> void:
	var from := Metals.center_of(self) + Vector3(0, 0.2, 0)
	var target_velocity: Vector3 = target.velocity
	var aim: Vector3 = target.global_position + Vector3(0, 1.1, 0) + target_velocity * 0.15
	var dir := (aim - from).normalized()
	var coin := Props.coin()
	coin.shooter = self
	get_tree().current_scene.add_child(coin)
	coin.global_position = from + dir * 0.6
	coin.add_collision_exception_with(self)
	coin.linear_velocity = dir * 14.0
	rotation.y = atan2(-dir.x, -dir.z)
	rig.play_throw()
	_start_grip(coin, 1.0, &"steel", 0.45)


## Salto con acero: suelta una moneda a sus pies y la empuja, saliendo despedido.
func _steel_jump(horizontal_dir: Vector3) -> void:
	_jump_cd = 2.5
	var coin := Props.coin()
	coin.shooter = self
	get_tree().current_scene.add_child(coin)
	coin.global_position = global_position + Vector3(0, 0.1, 0)
	coin.add_collision_exception_with(self)
	velocity += horizontal_dir * 5.0
	_flying = 0.3
	_start_grip(coin, 1.0, &"steel", 0.45)


func _start_grip(t: Node3D, dir_sign: float, metal: StringName, duration: float) -> void:
	if not allomancy.is_burning(metal):
		allomancy.set_state(metal, Allomancy.State.BURN)
	_grips.append({"target": t, "sign": dir_sign, "metal": metal, "until": _world_time + duration})


func _apply_grips(delta: float) -> void:
	var push_target: Node3D = null
	var pull_target: Node3D = null
	for g in _grips.duplicate():
		var t: Node3D = g["target"]
		# Si el objetivo deja de llevar metal (el jugador soltó su bolsa), se pierde el agarre.
		if down or _world_time > g["until"] or not is_instance_valid(t) or not t.is_inside_tree() \
				or not t.is_in_group(&"metal"):
			_grips.erase(g)
			continue
		var strength := maxf(allomancy.strength(g["metal"]), 1.0)
		var reach := REACH * (1.0 + 0.5 * (strength - 1.0))
		var accel := Metals.push_pull(Metals.center_of(self), allomantic_mass, t, strength, g["sign"], delta, reach)
		add_allomantic_acceleration(accel, delta)
		if g["sign"] > 0.0:
			push_target = t
		else:
			pull_target = t
	# Gesto visible: brazo derecho al empujar, izquierdo al tirar.
	rig.aim_target = Metals.center_of(push_target) if push_target else null
	rig.aim_target_left = Metals.center_of(pull_target) if pull_target else null
	if rig is ModelRig:
		rig.push_power = allomancy.strength(&"steel")
		rig.pull_power = allomancy.strength(&"iron")


## Texto que sube y se desvanece sobre la cabeza (p. ej. "esquiva").
func _popup(text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 36
	l.outline_size = 8
	l.pixel_size = 0.007
	l.modulate = Metals.ATIUM_COLOR
	l.top_level = true
	add_child(l)
	l.global_position = global_position + Vector3(0, 2.5, 0)
	var tw := l.create_tween()
	tw.tween_property(l, "global_position:y", l.global_position.y + 0.8, 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


## Modo espectador: lo que ve con el atium. La sombra de su rival donde estará en un instante;
## si el rival también quema atium, la sombra se parte en varios futuros que no se deciden.
func _show_atium_vision(rd: float) -> void:
	_vision_timer -= rd
	if _vision_timer > 0.0 or not allomancy.is_burning(&"atium") or not is_instance_valid(target):
		return
	_vision_timer = 0.12
	var source: Node3D = target.visual if target is Player else target.rig
	var ahead: Vector3 = target.predict_position(0.6) if target.has_method(&"predict_position") \
			else target.global_position + target.velocity * 0.6
	var contested := Metals.burns_atium(target)
	var color: Color = (TEAM_COLORS[clampi(team, 0, TEAM_COLORS.size() - 1)] as Color).lerp(Metals.ATIUM_COLOR, 0.5)
	for i in (3 if contested else 1):
		var ghost := Afterimage.new()
		get_tree().current_scene.add_child(ghost)
		ghost.setup(source, color, 0.25)
		var jitter := Vector3(randf_range(-1.8, 1.8), 0, randf_range(-1.8, 1.8)) if contested else Vector3.ZERO
		ghost.global_position += ahead - target.global_position + jitter


func _process(delta: float) -> void:
	if show_label:
		_show_atium_vision(delta / Engine.time_scale)
	if _label:
		var text: String = "%s\n%d" % [NAMES[kind], ceili(maxf(health, 0.0))] if not down else NAMES[kind] + "\nfuera de combate"
		if allomancy.is_burning(&"atium"):
			text += "\nATIUM %.0f s" % (allomancy.reserve[&"atium"] / Allomancy.METALS[&"atium"]["burn"])
		elif kind == Kind.MISTBORN and atium > 0.0 and allomancy.reserve[&"atium"] <= 0.0:
			text += "\nsin atium"
		_label.text = text
	_bolts.begin()
	if show_label:
		var origin := Metals.center_of(self)
		for g in _grips:
			var t: Node3D = g["target"]
			if is_instance_valid(t):
				var col := Color(0.4, 0.78, 1.0) if g["sign"] > 0.0 else Color(0.5, 0.55, 1.0)
				_bolts.add(origin, Metals.center_of(t), 0.012, col, 2.5 * g["sign"], float(get_instance_id() % 97), 0.06, true, true)
	_bolts.end()
