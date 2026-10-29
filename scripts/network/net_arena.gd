class_name NetArena
extends Node
## Duelo en red dentro de la arena. El servidor crea un jugador (Player) por cada par que entra
## y le avisa a los demás para que lo copien; cada cliente solo controla el suyo.
## Cada par entra por su cuenta con join() (botón del menú de la arena), esté o no el otro ya dentro.
## La arena lo agrega siempre como hijo llamado "NetPlayers" (misma ruta en todos los procesos).

## Puntos de aparición, uno por jugador. Libres de pilares (±9, ±9), farolas (radio 18),
## plataformas (±14, 0) y (0, -15) y frascos (±6, ±14) de la arena.
const SPAWNS: Array[Vector3] = [Vector3(-6, 1, 6), Vector3(6, 1, -6)]

## Bajas para ganar la ronda y segundos antes de empezar otra.
const KILLS_TO_WIN := 3
const NEW_ROUND_DELAY := 6.0
## Monedas: máximo a la vez (si hay más, desaparece la más vieja), vida de cada una, cada cuántos pasos de
## física se mandan las que se movieron, y cada cuántos se mandan todas (por si se perdió alguna).
## Los ids de monedas empiezan aquí; los menores son las anclas fijas del escenario.
const MAX_COINS := 40
const COIN_LIFETIME_MS := 30000
const COIN_SEND_EVERY := 3
const COIN_RESYNC_EVERY := 60
const COIN_ID_BASE := 1000

## Se creó el jugador que maneja este proceso.
signal local_player_spawned(player: Player)
## Se retiró al jugador local (se cortó la conexión o el anfitrión salió).
signal left_duel
## Hubo un problema que la arena puede mostrar en pantalla.
signal notice(text: String)

## id del par -> Player, en este proceso.
var players := {}
## Solo servidor: id del par -> punto de aparición que ocupa.
var _slots := {}
var _huds := {}
## Marcador (id -> bajas), igual en todos los procesos: el servidor lo manda cuando cambia.
var scores := {}
var round_over := false
var _tags := {}
var _winner := 0
## Monedas de red: id -> Coin (reales y simuladas en el servidor; copias que solo se muestran en los clientes).
var coins := {}
var _next_coin_id := COIN_ID_BASE
var _coin_born := {}  # servidor: id -> momento de creación (ms)
var _coin_sent := {}  # servidor: id -> última posición mandada
var _coin_goal := {}  # cliente: id -> posición a la que va la copia
var _tick := 0
var _anchors: Array[Node3D] = []
var _ground_cleared := false
var _score_label: Label


func is_active() -> bool:
	return multiplayer.has_multiplayer_peer() and players.has(multiplayer.get_unique_id())


## Se puede pegar (no hay ronda terminada esperando a la siguiente).
func can_fight() -> bool:
	return not round_over


## Este proceso pide entrar al duelo.
func join() -> void:
	if not NetworkManager.is_online():
		notice.emit("Primero conectate (tecla P)")
	elif multiplayer.is_server():
		_server_add(1)
	else:
		_hello.rpc_id(1)


func _ready() -> void:
	multiplayer.peer_disconnected.connect(func(id: int) -> void:
		if multiplayer.is_server():
			_server_remove(id))
	multiplayer.server_disconnected.connect(_clear)
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_score_label = Label.new()
	_score_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_score_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_score_label.offset_top = 70
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 22)
	_score_label.add_theme_constant_override("outline_size", 6)
	_score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_score_label)


## Texto de vida sobre los demás jugadores y marcador arriba (solo presentación local).
func _process(delta: float) -> void:
	if not _coin_goal.is_empty():
		_update_coin_puppets(delta)
	for id: int in _tags:
		var p: Player = players.get(id)
		if p != null:
			(_tags[id] as Label3D).text = "Jugador %d\n%s" % [id, "caído" if p.dead else str(ceili(p.health))]
	if not is_active():
		_score_label.text = ""
		return
	if _winner != 0:
		_score_label.text = "¡Gana el jugador %d!\nNueva ronda en unos segundos" % _winner
		return
	var parts := PackedStringArray()
	for id: int in players:
		parts.append("%d%s: %d" % [id, " (tú)" if id == multiplayer.get_unique_id() else "", scores.get(id, 0)])
	_score_label.text = "Primero a %d · %s" % [KILLS_TO_WIN, "   ".join(parts)]


func _exit_tree() -> void:
	if not NetworkManager.is_online():
		return
	if multiplayer.is_server():
		for id: int in _slots:
			if id != 1:
				_reset.rpc_id(id)
	elif players.has(multiplayer.get_unique_id()):
		_bye.rpc_id(1)


# ---------------------------------------------------------------- Servidor

@rpc("any_peer", "call_remote", "reliable")
func _hello() -> void:
	if multiplayer.is_server():
		_server_add(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _bye() -> void:
	if multiplayer.is_server():
		_server_remove(multiplayer.get_remote_sender_id())


func _server_add(id: int) -> void:
	if _slots.has(id):
		return
	var slot := -1
	for i in SPAWNS.size():
		if not _slots.values().has(i):
			slot = i
			break
	if slot < 0:
		if id != 1:
			_full.rpc_id(id)
		else:
			notice.emit("El duelo está lleno")
		return
	_slots[id] = slot
	_spawn_local(id, SPAWNS[slot])
	print("[red] jugador entra al duelo: ", id, " (punto ", slot, ")")
	if id != 1:
		_scores_changed.rpc_id(id, scores, _winner)
		for cid: int in coins:
			_coin_spawned.rpc_id(id, cid, (coins[cid] as Coin).global_position)
		# El nuevo crea a todos los que ya están (y a sí mismo); los demás lo crean a él.
		for other: int in _slots:
			_spawn.rpc_id(id, other, SPAWNS[_slots[other]])
			if other != 1 and other != id:
				_spawn.rpc_id(other, id, SPAWNS[slot])
	else:
		for other: int in _slots:
			if other != 1:
				_spawn.rpc_id(other, id, SPAWNS[slot])


func _server_remove(id: int) -> void:
	if not _slots.has(id):
		return
	_slots.erase(id)
	_despawn_local(id)
	print("[red] jugador sale del duelo: ", id)
	for other: int in _slots:
		if other != 1:
			_despawn.rpc_id(other, id)


## Un cliente ya creó ese jugador: desde ahora el servidor le replica su posición.
@rpc("any_peer", "call_remote", "reliable")
func _ack(spawned_id: int) -> void:
	if not multiplayer.is_server() or not players.has(spawned_id):
		return
	var sync := (players[spawned_id] as Player).get_node_or_null(^"NetSync") as MultiplayerSynchronizer
	if sync != null and _slots.has(multiplayer.get_remote_sender_id()):
		sync.set_visibility_for(multiplayer.get_remote_sender_id(), true)


# ---------------------------------------------------------------- Clientes

@rpc("authority", "call_remote", "reliable")
func _spawn(id: int, pos: Vector3) -> void:
	_spawn_local(id, pos)
	_ack.rpc_id(1, id)


@rpc("authority", "call_remote", "reliable")
func _despawn(id: int) -> void:
	_despawn_local(id)


@rpc("authority", "call_remote", "reliable")
func _full() -> void:
	notice.emit("El duelo está lleno")


## El servidor salió de la arena: nadie sigue simulando a estos jugadores.
@rpc("authority", "call_remote", "reliable")
func _reset() -> void:
	_clear()
	notice.emit("El anfitrión salió de la arena")


# ---------------------------------------------------------------- Ambos

func _spawn_local(id: int, pos: Vector3) -> void:
	if players.has(id):
		return
	_clear_ground_props()
	var player := Player.new()
	player.net_peer_id = id
	player.name = "Player_%d" % id
	player.position = pos
	add_child(player)
	players[id] = player
	if id == multiplayer.get_unique_id():
		var hud := Hud.new()
		hud.player = player
		add_child(hud)
		_huds[id] = hud
		local_player_spawned.emit(player)
	else:
		var tag := Label3D.new()
		tag.text = "Jugador %d" % id
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.pixel_size = 0.004
		tag.position = Vector3(0, 2.3, 0)
		player.add_child(tag)
		_tags[id] = tag
	if multiplayer.is_server():
		player.died.connect(_on_player_died.bind(id))


func _despawn_local(id: int) -> void:
	if players.has(id):
		(players[id] as Player).queue_free()
		players.erase(id)
	_tags.erase(id)
	scores.erase(id)
	if _huds.has(id):
		(_huds[id] as Node).queue_free()
		_huds.erase(id)


func _clear() -> void:
	if not players.is_empty():
		left_duel.emit()
	for id: int in players.keys():
		_despawn_local(id)
	_slots.clear()
	scores.clear()
	round_over = false
	_winner = 0
	for cid: int in coins.keys():
		_remove_coin_local(cid)


# ---------------------------------------------------------------- Marcador (servidor decide)

func _on_player_died(victim_id: int) -> void:
	if round_over or not players.has(victim_id):
		return
	var killer: int = (players[victim_id] as Player).net_last_attacker
	if killer == 0 or killer == victim_id or not players.has(killer):
		return
	scores[killer] = scores.get(killer, 0) + 1
	print("[red] baja: ", killer, " derriba a ", victim_id, " ", scores)
	if scores[killer] >= KILLS_TO_WIN:
		round_over = true
		print("[red] gana la ronda: ", killer)
		get_tree().create_timer(NEW_ROUND_DELAY).timeout.connect(_new_round)
	_broadcast_scores(killer if round_over else 0)


func _new_round() -> void:
	scores.clear()
	round_over = false
	for p: Player in players.values():
		p.net_reset()
	_broadcast_scores(0)


func _broadcast_scores(winner: int) -> void:
	_apply_scores(scores, winner)
	for id: int in _slots:
		if id != 1:
			_scores_changed.rpc_id(id, scores, winner)


@rpc("authority", "call_remote", "reliable")
func _scores_changed(new_scores: Dictionary, winner: int) -> void:
	_apply_scores(new_scores, winner)


func _apply_scores(new_scores: Dictionary, winner: int) -> void:
	scores = new_scores.duplicate()
	_winner = winner
	round_over = winner != 0


# ---------------------------------------------------------------- Monedas y objetivos de acero/hierro

## Cada proceso coloca al azar las monedas y cajas del suelo de la arena: en el duelo se quitan, y las
## monedas que hay son solo las que lanzan los jugadores (las crea el servidor).
func _clear_ground_props() -> void:
	if _ground_cleared:
		return
	_ground_cleared = true
	for n in get_tree().get_nodes_in_group(&"metal"):
		if n.has_meta(&"ground"):
			n.queue_free()


## Anclas fijas (pilares, farolas, braseros), en el mismo orden en todos los procesos: su id es la posición
## en la lista (desde 1), ordenada por coordenadas.
func anchors() -> Array[Node3D]:
	if _anchors.is_empty():
		for n in get_tree().get_nodes_in_group(&"metal"):
			if n is StaticBody3D and not n.has_meta(&"ground"):
				_anchors.append(n)
		_anchors.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			var pa := Metals.center_of(a)
			var pb := Metals.center_of(b)
			if not is_equal_approx(pa.x, pb.x):
				return pa.x < pb.x
			if not is_equal_approx(pa.z, pb.z):
				return pa.z < pb.z
			return pa.y < pb.y)
	return _anchors


## Id de un objetivo de acero/hierro (ancla o moneda); 0 si no es de red.
func target_id(n: Node3D) -> int:
	if n == null or not is_instance_valid(n):
		return 0
	if n is Coin:
		return (n as Coin).net_id
	return anchors().find(n) + 1


func target_node(id: int) -> Node3D:
	if id >= COIN_ID_BASE:
		var c = coins.get(id)
		return c if is_instance_valid(c) else null
	var list := anchors()
	return list[id - 1] if id >= 1 and id <= list.size() else null


## Todo lo que se puede empujar o tirar: las anclas y las monedas.
func targets() -> Array[Node3D]:
	var out: Array[Node3D] = anchors().duplicate()
	for c: Coin in coins.values():
		if is_instance_valid(c):
			out.append(c)
	return out


## Servidor: crea una moneda y avisa a los clientes. Si ya hay el máximo, desaparece la más vieja.
func server_spawn_coin(pos: Vector3) -> Coin:
	if coins.size() >= MAX_COINS:
		_server_remove_coin(coins.keys()[0])
	var coin := Props.coin()
	coin.net_id = _next_coin_id
	_next_coin_id += 1
	coin.position = pos
	add_child(coin)
	coins[coin.net_id] = coin
	_coin_born[coin.net_id] = Time.get_ticks_msec()
	for peer: int in _slots:
		if peer != 1:
			_coin_spawned.rpc_id(peer, coin.net_id, pos)
	return coin


func _server_remove_coin(id: int) -> void:
	_remove_coin_local(id)
	for peer: int in _slots:
		if peer != 1:
			_coin_gone.rpc_id(peer, id)


func _remove_coin_local(id: int) -> void:
	if coins.has(id):
		if is_instance_valid(coins[id]):
			(coins[id] as Node).queue_free()
		coins.erase(id)
	_coin_born.erase(id)
	_coin_sent.erase(id)
	_coin_goal.erase(id)


func _physics_process(_delta: float) -> void:
	if coins.is_empty() or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var now := Time.get_ticks_msec()
	for id: int in coins.keys():
		if now - _coin_born[id] > COIN_LIFETIME_MS:
			_server_remove_coin(id)
	_tick += 1
	if _tick % COIN_SEND_EVERY != 0:
		return
	var everything := _tick % COIN_RESYNC_EVERY == 0
	var ids := PackedInt32Array()
	var positions := PackedVector3Array()
	for id: int in coins:
		var p := (coins[id] as Coin).global_position
		if everything or not _coin_sent.has(id) or (_coin_sent[id] as Vector3).distance_squared_to(p) > 0.0004:
			ids.append(id)
			positions.append(p)
			_coin_sent[id] = p
	if ids.is_empty():
		return
	for peer: int in _slots:
		if peer != 1:
			_coin_states.rpc_id(peer, ids, positions)


## Cliente: las copias de las monedas se acercan suavemente a lo que manda el servidor.
func _update_coin_puppets(delta: float) -> void:
	for id: int in _coin_goal:
		var c = coins.get(id)
		if is_instance_valid(c):
			var coin := c as Coin
			coin.global_position = coin.global_position.lerp(_coin_goal[id], clampf(delta * 18.0, 0.0, 1.0))


@rpc("authority", "call_remote", "reliable")
func _coin_spawned(id: int, pos: Vector3) -> void:
	if coins.has(id):
		return
	var coin := Props.coin()
	coin.puppet = true
	coin.net_id = id
	coin.position = pos
	add_child(coin)
	coins[id] = coin
	_coin_goal[id] = pos


@rpc("authority", "call_remote", "reliable")
func _coin_gone(id: int) -> void:
	_remove_coin_local(id)


@rpc("authority", "call_remote", "unreliable_ordered")
func _coin_states(ids: PackedInt32Array, positions: PackedVector3Array) -> void:
	for i in ids.size():
		if coins.has(ids[i]):
			_coin_goal[ids[i]] = positions[i]
