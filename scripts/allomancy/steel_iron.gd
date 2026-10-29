class_name SteelIron
extends Node3D
## Acero (empujar) y Hierro (tirar) del jugador.
## Dibuja rayos de bruma azul desde el pecho a cada objeto del grupo "metal" (también a la gente
## que lleva metal encima) y aplica la física de Metals.push_pull.
##
## Empujar y tirar son dos "agarres" independientes, cada uno con su objetivo, y pueden ir a la vez.
## Con los dos metales encendidos, clic izquierdo tira y clic derecho empuja; con uno solo,
## cualquier clic usa ese. La acción "anchor" (F) ancla los agarres activos: siguen aunque
## sueltes el botón, hasta que vuelvas a pulsarlo.
##
## Cada metal tiene un alcance efectivo según su masa (una moneda solo sirve de cerca, una farola
## desde lejos). Dentro de él la línea se ve azul y se puede seleccionar; fuera, apenas un hilo tenue.

class Grip:
	var metal: StringName
	var action: StringName
	var dir_sign: float
	var color: Color
	var target: Node3D = null
	var active := false
	var latched := false
	## Tras soltar un anclaje con un clic, ese clic no inicia un agarre nuevo.
	var consume := false

	func _init(p_metal: StringName, p_action: StringName, p_sign: float, p_color: Color) -> void:
		metal = p_metal
		action = p_action
		dir_sign = p_sign
		color = p_color


@export var sense_range := 40.0
@export var base_force := Metals.BASE_FORCE  ## Newtons a distancia cero (quemando)
@export var select_radius := 0.12  ## radio de selección alrededor de la mira (fracción del alto de pantalla)
@export var bolt_amplitude := 0.05  ## cuánto serpentean los rayos (fracción de su longitud)

## Red (ver Player._setup_network): el servidor decide y aplica la fuerza; cada cliente solo pide
## agarrar o soltar el ancla que tiene en la mira y dibuja las líneas. Solo valen anclas fijas
## (StaticBody3D del grupo "metal"): monedas, cajas y jugadores llegan en etapas posteriores.
var net := false
## "Ningún objetivo" al mandar o replicar una posición.
const NO_TARGET := Vector3(1e9, 1e9, 1e9)
## Cuánto puede distar el punto que manda el cliente del centro del ancla que elige.
const NET_MATCH_DIST := 0.8

var player: Player
## Metal bajo la mira (el que se agarrará al pulsar).
var target: Node3D = null
var push_grip := Grip.new(&"steel", &"push", 1.0, Color(0.4, 0.78, 1.0))
var pull_grip := Grip.new(&"iron", &"pull", -1.0, Color(0.5, 0.55, 1.0))
## Si hay algún agarre activo.
var holding := false
## Si se ha aplicado fuerza este paso (la gente se asusta).
var applying_force := false

## Moneda que se empuja sola mientras el jugador mantiene G (o null).
var auto_push: Node3D = null

var _bolts: BoltMesh
var _markers := {}  # "hover"/Grip -> MeshInstance3D
var _metals: Array[Node3D] = []
var _reach := 0.0


func _ready() -> void:
	_bolts = BoltMesh.new()
	add_child(_bolts)
	_markers["hover"] = _make_marker(Color(0.45, 0.75, 1.0, 0.55))
	_markers[push_grip] = _make_marker(push_grip.color)
	_markers[pull_grip] = _make_marker(pull_grip.color)


func _make_marker(color: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	mat.albedo_texture = Fx.soft_texture()
	mat.albedo_color = color
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := MeshInstance3D.new()
	m.mesh = quad
	m.material_override = mat
	m.top_level = true
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	add_child(m)
	return m


func grips() -> Array:
	return [push_grip, pull_grip]


func _physics_process(delta: float) -> void:
	if net:
		_net_physics(delta)
		return
	applying_force = false
	holding = false
	var a := player.allomancy
	var power := maxf(a.strength(&"steel"), a.strength(&"iron"))
	if power <= 0.0:
		target = null
		for g in grips():
			_release(g)
		_metals.clear()
		return

	_reach = sense_range * (1.0 + 0.5 * (power - 1.0))
	var origin := player.chest_position()
	_metals = _metals_in_range(origin, _reach)
	target = _pick_target(origin)

	for g in grips():
		var strength := a.strength(g.metal)
		_update_grip(g, strength, origin)
		if g.active:
			holding = true
			var accel := Metals.push_pull(origin, player.body_mass, g.target, strength, g.dir_sign, delta, _reach, base_force)
			player.add_allomantic_acceleration(accel, player.real_delta(delta))
			applying_force = true

	if Input.is_action_just_pressed(&"anchor"):
		for g in grips():
			if g.active:
				g.latched = true


## Si se pulsa el clic de este agarre. Con un solo metal encendido sirven los dos clics.
func _grip_input(g: Grip, just: bool) -> bool:
	if player.ui_open:
		return false
	var other: Grip = pull_grip if g == push_grip else push_grip
	var actions: Array[StringName] = [g.action]
	if not player.allomancy.is_burning(other.metal):
		actions.append(other.action)
	for a in actions:
		if Input.is_action_just_pressed(a) if just else Input.is_action_pressed(a):
			return true
	return false


func _update_grip(g: Grip, strength: float, origin: Vector3) -> void:
	# G mantenida: el empuje va solo a la moneda soltada, sin tocar el ratón.
	if g == push_grip and is_instance_valid(auto_push) and strength > 0.0 \
			and center_of(auto_push).distance_to(origin) <= _reach:
		if g.target != auto_push:
			g.target = auto_push
			g.active = true
			Fx.sparks(get_tree().current_scene, center_of(auto_push), g.color)
		return
	var pressed := _grip_input(g, false)
	if _grip_input(g, true) and g.latched:
		g.latched = false  # volver a pulsar suelta el anclaje
		g.consume = true
	if not pressed:
		g.consume = false
	var wanted := strength > 0.0 and ((pressed and not g.consume) or g.latched)
	if not wanted:
		_release(g)
		return
	if g.active and not _is_valid(g.target, origin):
		_release(g)  # el objetivo se fue de alcance: se pierde el agarre (y el anclaje)
		return
	if not g.active:
		var t := target if target else _feet_target(origin)
		if t == null:
			return  # sigue pulsado: se agarrará en cuanto haya algo en la mira
		g.target = t
		g.active = true
		Fx.sparks(get_tree().current_scene, center_of(t), g.color)


func _release(g: Grip) -> void:
	g.active = false
	g.latched = false
	g.target = null


func _process(_delta: float) -> void:
	if net:
		_net_presentation()
	_draw_lines()


# ---------------------------------------------------------------- Red

## Anclas fijas del escenario (iguales en todos los procesos).
func _net_anchors() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in get_tree().get_nodes_in_group(&"metal"):
		if n is StaticBody3D:
			out.append(n)
	return out


## El ancla cuyo centro está más cerca de `pos` (a menos de NET_MATCH_DIST), o null.
func _net_anchor_near(pos: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := NET_MATCH_DIST
	for a in _net_anchors():
		var d := center_of(a).distance_to(pos)
		if d <= best_d:
			best_d = d
			best = a
	return best


## Hay línea de vista (ningún muro ni objeto en medio) entre `origin` y el ancla.
func _net_line_of_sight(origin: Vector3, anchor: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin, center_of(anchor), Props.LAYER_WORLD | Props.LAYER_PROPS, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] == anchor


func _net_reach() -> float:
	var a := player.allomancy
	return sense_range * (1.0 + 0.5 * (maxf(maxf(a.strength(&"steel"), a.strength(&"iron")), 1.0) - 1.0))


## Servidor: aplica la fuerza de los agarres confirmados. Se suelta si el metal se apaga o el ancla sale de alcance.
func _net_physics(delta: float) -> void:
	applying_force = false
	holding = false
	var a := player.allomancy
	if maxf(a.strength(&"steel"), a.strength(&"iron")) <= 0.0:
		net_release_all()
		return
	_reach = _net_reach()
	var origin := player.chest_position()
	for g in grips():
		if not g.active:
			continue
		var strength := a.strength(g.metal)
		if strength <= 0.0 or not _is_valid(g.target, origin):
			_release(g)
			continue
		holding = true
		var accel := Metals.push_pull(origin, player.body_mass, g.target, strength, g.dir_sign, delta, _reach, base_force)
		player.add_allomantic_acceleration(accel, player.real_delta(delta))
		applying_force = true
	_net_publish()


## Pide agarrar (`pressed` con el punto del ancla elegido) o soltar un agarre: el servidor lo valida.
func net_request(is_push: bool, pressed: bool, pos: Vector3) -> void:
	if multiplayer.is_server():
		net_grip_request(is_push, pressed, pos)
	else:
		_net_grip.rpc_id(1, is_push, pressed, pos)


func net_anchor_request() -> void:
	if multiplayer.is_server():
		net_anchor()
	else:
		_net_anchor.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _net_grip(is_push: bool, pressed: bool, pos: Vector3) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.net_peer_id:
		net_grip_request(is_push, pressed, pos)


@rpc("any_peer", "call_remote", "reliable")
func _net_anchor() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.net_peer_id:
		net_anchor()


## Servidor: valida un agarre pedido. Rechaza si no quemas ese metal, si no hay un ancla en ese punto,
## si está fuera de alcance o si algo tapa la línea.
func net_grip_request(is_push: bool, pressed: bool, pos: Vector3) -> void:
	var g: Grip = push_grip if is_push else pull_grip
	if not (is_finite(pos.x) and is_finite(pos.y) and is_finite(pos.z)):
		return
	if not pressed:
		g.consume = false
		if not g.latched:
			_release(g)
			_net_publish()
		return
	if player.dead:
		return
	if g.latched:
		_release(g)  # volver a pulsar suelta el anclaje
		g.consume = true
		_net_publish()
		return
	if g.active or g.consume or pos == NO_TARGET or player.allomancy.strength(g.metal) <= 0.0:
		return
	var anchor := _net_anchor_near(pos)
	if anchor == null:
		return
	var origin := player.chest_position()
	_reach = _net_reach()
	if center_of(anchor).distance_to(origin) > effective_reach(anchor) or not _net_line_of_sight(origin, anchor):
		return
	g.target = anchor
	g.active = true
	Fx.sparks(get_tree().current_scene, center_of(anchor), g.color)
	_net_publish()


## Servidor: ancla los agarres activos (siguen aunque se suelte el clic).
func net_anchor() -> void:
	for g in grips():
		if g.active:
			g.latched = true


func net_release_all() -> void:
	for g in grips():
		_release(g)
		g.consume = false
	_net_publish()


## Servidor: deja en el jugador, para replicar, a qué ancla empuja y de cuál tira.
func _net_publish() -> void:
	for i in 2:
		var g: Grip = grips()[i]
		var pos: Vector3 = center_of(g.target) if g.active and is_instance_valid(g.target) else NO_TARGET
		if player.net_grips[i] != pos:
			player.net_grips[i] = pos


## Presentación local: los clientes reciben los agarres del servidor; el jugador de este proceso además
## busca el ancla bajo su mira (para pedirla) y ve las líneas a todas las que alcanza.
func _net_presentation() -> void:
	var a := player.allomancy
	var power := maxf(a.strength(&"steel"), a.strength(&"iron"))
	if not player.is_simulated():
		for i in 2:
			var g: Grip = grips()[i]
			var pos: Vector3 = player.net_grips[i]
			g.target = _net_anchor_near(pos) if pos != NO_TARGET else null
			g.active = g.target != null
	_metals.clear()
	target = null
	if power <= 0.0:
		return
	_reach = _net_reach()
	if player.is_local_player():
		var origin := player.chest_position()
		for m in _net_anchors():
			if center_of(m).distance_to(origin) <= _reach:
				_metals.append(m)
		target = _pick_target(origin)
	else:
		for g in grips():
			if g.active and is_instance_valid(g.target):
				_metals.append(g.target)


func center_of(t: Node3D) -> Vector3:
	return Metals.center_of(t)


func movable_mass(t: Node3D) -> float:
	return Metals.movable_mass(t)


func effective_reach(t: Node3D) -> float:
	return Metals.effective_reach(t, _reach)


func _metals_in_range(origin: Vector3, reach: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in get_tree().get_nodes_in_group(&"metal"):
		var body := n as Node3D
		if body and body != player and center_of(body).distance_to(origin) <= reach:
			out.append(body)
	return out


func _is_valid(t: Node3D, origin: Vector3) -> bool:
	return is_instance_valid(t) and t.is_inside_tree() and center_of(t).distance_to(origin) <= _reach


## Elige el metal alcanzable más cercano a la mira en pantalla (sin contar los ya agarrados).
## El actual tiene ventaja para que la selección no salte entre dos objetos parecidos.
func _pick_target(origin: Vector3) -> Node3D:
	var cam := player.camera
	var view := get_viewport().get_visible_rect().size
	var center := view * 0.5
	var cam_pos := cam.global_position
	var aim := player.aim_direction()
	# En tercera persona el personaje tapa la mira: solo cuenta lo que está más allá de él.
	var min_depth := (origin - cam_pos).dot(aim) + 0.8
	var best: Node3D = null
	var best_score := INF
	for m in _metals:
		if m == push_grip.target or m == pull_grip.target:
			continue
		var c := center_of(m)
		var dist := c.distance_to(origin)
		if dist > effective_reach(m) or (c - cam_pos).dot(aim) < min_depth:
			continue
		var off := cam.unproject_position(c).distance_to(center) / view.y
		if off > select_radius:
			continue
		var score := off + dist * 0.002
		if m == target:
			score -= 0.03
		if score < best_score:
			best_score = score
			best = m
	return best


## Sin nada en la mira: el metal justo debajo (moneda soltada con G).
func _feet_target(origin: Vector3) -> Node3D:
	var best: Node3D = null
	var best_dist := 3.0
	for m in _metals:
		if m == push_grip.target or m == pull_grip.target:
			continue
		var to := center_of(m) - origin
		if to.length() < best_dist and to.normalized().dot(Vector3.DOWN) > 0.75:
			best_dist = to.length()
			best = m
	return best


func _draw_lines() -> void:
	_bolts.begin()
	for m in _markers.values():
		m.visible = false
	if _metals.is_empty():
		_bolts.end()
		return
	var origin := player.chest_position()
	var view_cam := get_viewport().get_camera_3d()
	var cam := (view_cam if view_cam != null else player.camera).global_position
	var now := Time.get_ticks_msec() / 1000.0
	for m in _metals:
		if not is_instance_valid(m):
			continue
		var end := center_of(m)
		var dist := origin.distance_to(end)
		var eff := effective_reach(m)
		var seed := float(m.get_instance_id() % 997) * 0.37
		var grip: Grip = push_grip if m == push_grip.target else (pull_grip if m == pull_grip.target else null)
		if grip:
			_bolts.add(origin, end, 0.012, Color(grip.color.r, grip.color.g, grip.color.b, 1.0), 2.5 * grip.dir_sign,
					seed, bolt_amplitude * 1.3, true, true)
		elif m == target:
			_bolts.add(origin, end, 0.011, Color(0.3, 0.65, 1.0, 1.0), 0.6, seed, bolt_amplitude, false, true)
		elif dist <= eff:
			# Alcanzable: azul, más sólido y ancho cuanto más cerca.
			var close := 1.0 - dist / eff
			_bolts.add(origin, end, 0.004 + 0.005 * close, Color(0.12, 0.38, 1.0, 0.12 + 0.55 * close * close), 0.4,
					seed, bolt_amplitude * (0.6 + 0.4 * close))
		else:
			# Fuera de alcance: un hilo tenue y recto que desaparece hacia el límite.
			var far := clampf((dist - eff) / maxf(_reach - eff, 0.01), 0.0, 1.0)
			_bolts.add(origin, end, 0.003, Color(0.4, 0.5, 0.75, 0.08 * (1.0 - far)), 0.4, seed, 0.0)
		if grip or m == target:
			var marker: MeshInstance3D = _markers[grip] if grip else _markers["hover"]
			var pulse := 1.0 + (0.2 * sin(now * 12.0) if grip else 0.0)
			if grip and grip.latched:
				pulse *= 1.3  # anclado: destello más grande
			marker.visible = true
			marker.global_position = end
			marker.scale = Vector3.ONE * cam.distance_to(end) * 0.07 * pulse
	_bolts.end()
