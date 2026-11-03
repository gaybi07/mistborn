extends SceneTree
## Comprueba al koloss contra un jugador falso, sin ventana: ruge al verlo, le pega, salta, esquiva, entra
## en furia, cae y desaparece. Uso (desde la carpeta del proyecto):
##   godot --headless --path . -s tools/anim_check/koloss_check.gd

class FakePlayer extends CharacterBody3D:
	var hits := 0
	var damage := 0.0
	var impulses := 0
	var trauma := 0.0
	var _attack_cd := 0.0

	func _ready() -> void:
		add_to_group(&"player")

	func is_down() -> bool:
		return false

	func take_hit(_impulse: Vector3, amount: float, _attacker: Node3D = null) -> void:
		hits += 1
		damage += amount

	func apply_allomantic_impulse(_dv: Vector3) -> void:
		impulses += 1

	func add_trauma(amount: float) -> void:
		trauma += amount

	func mark_combat() -> void:
		pass


var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("OK    " if ok else "FALLA ") + what)
	if not ok:
		fails += 1


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _init() -> void:
	await process_frame
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = Props.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	world.add_child(floor_body)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0, 3, 12)
	var player := FakePlayer.new()
	world.add_child(player)
	for axes in [false, true]:
		await _run(world, player, axes)
	print("KOLOSS_CHECK %s" % ("OK" if fails == 0 else "%d FALLAS" % fails))
	quit(1 if fails else 0)


func _run(world: Node3D, player: FakePlayer, axes: bool) -> void:
	print("--- ", "dos hachas" if axes else "espadón")
	player.hits = 0
	player.damage = 0.0
	player.impulses = 0
	player.trauma = 0.0
	player.global_position = Vector3.ZERO
	var k := Koloss.new()
	k.axes = axes
	k.position = Vector3(0, 0.2, -5)
	k.home = k.position
	world.add_child(k)
	var r := k.rig as ModelRig
	for state in ["idle", "walk", "run", "down", "hit", "dodge_left", "mt_roar", "mt_flex", "mt_jump_attack", "mt_punch", "gs_kick"]:
		_check(r._resolved[state]["name"] != "", "%s tiene clip (%s)" % [state, r._resolved[state]["name"]])
	var held: Array = r._weapon_nodes[HumanoidRig.Weapon.SWORD]["held"]
	_check(held.size() == (2 if axes else 1) and held[0].visible, "arma en la mano: %d" % held.size())
	await _wait(0.2)
	_check(r._spell_state == "mt_roar", "ruge al verte (%s)" % r._spell_state)
	await _wait(2.4)
	_check(player.impulses > 0 and player.trauma > 0.0, "el rugido empuja y sacude")
	await _wait(6.0)
	_check(player.hits > 0 and player.damage > 0.0, "pega: %d golpes, %.0f de daño" % [player.hits, player.damage])
	# Salto: lejos, y con el salto listo.
	k._next_leap = 0.0
	k._busy_until = 0.0
	player.global_position = k.global_position + Vector3(0, 0, 8.0 * k._grow)
	var before := player.hits
	await _wait(0.2)
	_check(r._spell_state == "mt_jump_attack", "salta a %.1f m (%s)" % [8.0 * k._grow, r._spell_state])
	await _wait(1.5)
	var gap := k.global_position.distance_to(player.global_position)
	_check(gap < 3.5 * k._grow, "cae cerca (a %.1f m)" % gap)
	_check(player.hits > before, "la onda golpea")
	await _wait(1.5)
	# Esquiva: atacale muchas veces hasta que reaccione.
	k._next_blow = 1e9
	var dodged := false
	for i in 40:
		k._next_react = 0.0
		k._guard_until = 0.0
		player._attack_cd = 1.0
		await physics_frame
		await physics_frame
		if r._spell_state.begins_with("dodge") and r._spell > 0.0:
			dodged = true
			break
		player._attack_cd = 0.0
		await physics_frame
		await physics_frame
	player._attack_cd = 0.0
	_check(dodged, "esquiva cuando le atacás")
	if dodged:
		var h := k.health
		k.take_hit(Vector3.ZERO, 30.0, player)
		_check(k.health == h, "esquivando no le entra el golpe")
	await _wait(1.0)
	if not axes:
		k._evade_until = 0.0
		k.rig.blocking = true
		k.face_point = null
		k.rotation.y = atan2(-(player.global_position.x - k.global_position.x), -(player.global_position.z - k.global_position.z))
		var h := k.health
		k.take_hit(Vector3.ZERO, 40.0, player)
		_check(is_equal_approx(k.health, h - 10.0), "cubriéndose recibe un cuarto (%.0f)" % (h - k.health))
		k.rig.blocking = false
	k._evade_until = 0.0
	k.health = k.max_health * 0.35
	k._busy_until = 0.0
	k._guard_until = 0.0
	await _wait(0.3)
	_check(k._enraged and r._spell_state == "mt_flex", "entra en furia (%s)" % r._spell_state)
	k.rig.blocking = false
	k.take_hit(Vector3.ZERO, 1e6, player)
	await _wait(0.3)
	_check(k.down, "cae")
	k._corpse = Koloss.CORPSE_TIME
	await _wait(0.2)
	_check(not is_instance_valid(k), "desaparece al rato")
