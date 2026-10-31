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
	## Segundos con el agarre activo: la fuerza sube en los primeros instantes (ver ramp), no de golpe.
	var held := 0.0
	## Partida individual: la ranura con la habilidad de este agarre está pulsada (input_just: solo este paso).
	var input_held := false
	var input_just := false
	## Ya se avisó que el objetivo no se puede agarrar (hasta soltar la tecla).
	var warned := false

	func ramp() -> float:
		return lerpf(0.35, 1.0, clampf(held / 0.12, 0.0, 1.0))

	func _init(p_metal: StringName, p_action: StringName, p_sign: float, p_color: Color) -> void:
		metal = p_metal
		action = p_action
		dir_sign = p_sign
		color = p_color


@export var sense_range := 40.0
@export var base_force := Metals.BASE_FORCE  ## Newtons a distancia cero (quemando)
@export var select_degrees := 4.5  ## radio de selección alrededor de la mira (grados; antes ~9° de pantalla)
@export var bolt_amplitude := 0.05  ## cuánto serpentean los rayos (fracción de su longitud)

## Red (ver Player._setup_network): el servidor decide y aplica la fuerza; cada cliente solo pide
## agarrar o soltar el objetivo (ancla fija o moneda) que tiene en la mira y dibuja las líneas.
## Cada objetivo tiene un id (ver NetArena.target_id); cajas y otros jugadores llegan en etapas posteriores.
var net := false
## La moneda del servidor se está empujando sola (tecla G), no por un clic.
var _net_auto_grip := false

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
## Los que se pueden elegir ahora (cerca de la mira), de mejor a peor; ver _pick_target y cycle_target.
var _cands: Array[Node3D] = []
var _manual: Node3D = null
var _manual_until := 0
var _los_cache := {}  # id -> [cuándo, hay línea de vista] (solo en red)
var _dots: Array[MeshInstance3D] = []  # puntos suaves sobre lo que puedes usar

## Cuántos puntos se muestran: pocos quemando, más (también los lejanos) avivando.
const DOTS_BURN := 6
const DOTS_FLARE := 14
## Tras elegir con la rueda, se mantiene esa elección este tiempo (ms).
const MANUAL_HOLD_MS := 2000
## Auto-selección sin objetivo a la vista: puntaje mínimo y masa mínima (solo anclas y cosas pesadas).
const AUTO_MIN_SCORE := 0.2
const AUTO_MIN_MASS := 50.0


func _ready() -> void:
	_bolts = BoltMesh.new()
	add_child(_bolts)
	_markers["hover"] = _make_marker(Color(0.45, 0.75, 1.0, 0.55))
	_markers[push_grip] = _make_marker(push_grip.color)
	_markers[pull_grip] = _make_marker(pull_grip.color)
	for i in DOTS_FLARE + 2:
		_dots.append(_make_marker(Color(0.45, 0.72, 1.0, 0.5)))


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
			g.held += delta
			var accel := Metals.push_pull(origin, player.body_mass, g.target, strength * g.ramp(), g.dir_sign, delta, _reach, base_force)
			player.add_allomantic_acceleration(accel, player.real_delta(delta))
			applying_force = true

	if Input.is_action_just_pressed(&"anchor"):
		anchor_pressed()
	for g in grips():
		g.input_just = false


## Si se pulsa la ranura con la habilidad de este agarre (tirón básico o empuje ligero; ver Player._skill_key).
func _grip_input(g: Grip, just: bool) -> bool:
	if player.ui_open:
		return false
	return g.input_just if just else g.input_held


## Masa máxima (kg) que este agarre puede mover según el nivel de su metal. Lo que no se mueve (anclas) cuenta
## como infinito: con hierro hace falta Balanceo (nivel 16) y con acero llegar al nivel 20.
func mass_limit(g: Grip) -> float:
	var level := player.metal_level(g.metal)
	if g == pull_grip and level >= 16:
		return INF
	return SkillTree.push_mass_limit(level)


## Si el agarre puede con ese objetivo; si no, avisa por qué.
func _can_grip(g: Grip, t: Node3D) -> bool:
	var mass := Metals.movable_mass(t)
	var limit := mass_limit(g)
	if mass <= 0.0:
		mass = INF
	if mass <= limit:
		return true
	if g.warned:
		return false
	g.warned = true
	if mass == INF:
		player.notice.emit("Esa ancla es demasiado firme: " + ("Balanceo (hierro 16)" if g == pull_grip else "acero nivel 20"))
	else:
		player.notice.emit("Pesa %.1f kg: tu %s solo mueve hasta %.1f kg" % [mass, "hierro" if g == pull_grip else "acero", limit])
	return false


func _update_grip(g: Grip, strength: float, origin: Vector3) -> void:
	# G mantenida: el empuje va solo a la moneda soltada, sin tocar el ratón.
	if g == push_grip and is_instance_valid(auto_push) and strength > 0.0 \
			and center_of(auto_push).distance_to(origin) <= _reach:
		if g.target != auto_push:
			g.target = auto_push
			g.active = true
			Fx.sparks(get_tree().current_scene, center_of(auto_push), g.color)
			Fx.effect(get_tree().current_scene, "ef_lightning01", center_of(auto_push), 0.25, g.color)
		return
	var pressed := _grip_input(g, false)
	if _grip_input(g, true) and g.latched:
		g.latched = false  # volver a pulsar suelta el anclaje
		g.consume = true
	if not pressed:
		g.consume = false
		g.warned = false
	var wanted := strength > 0.0 and ((pressed and not g.consume) or g.latched)
	if not wanted:
		_release(g)
		return
	if g.active and not _is_valid(g.target, origin):
		_release(g)  # el objetivo se fue de alcance: se pierde el agarre (y el anclaje)
		return
	if not g.active:
		# Lo que miras (o, sin nada a la vista, lo de los pies o lo que más ayuda a moverte).
		var t := click_target(g == push_grip, origin)
		if t == null:
			return  # sigue pulsado: se agarrará en cuanto haya algo que agarrar
		if not _can_grip(g, t):
			return
		g.target = t
		g.active = true
		Fx.sparks(get_tree().current_scene, center_of(t), g.color)
		Fx.effect(get_tree().current_scene, "ef_lightning01", center_of(t), 0.25, g.color)


func _release(g: Grip) -> void:
	g.active = false
	g.latched = false
	g.target = null
	g.held = 0.0


func _process(_delta: float) -> void:
	if net:
		_net_presentation()
	_draw_lines()


# ---------------------------------------------------------------- Red

## NetArena (el padre del jugador en el duelo): numera los objetivos y guarda las monedas.
func _arena() -> Node:
	return player.get_parent()


func _net_reach() -> float:
	var a := player.allomancy
	return sense_range * (1.0 + 0.5 * (maxf(maxf(a.strength(&"steel"), a.strength(&"iron")), 1.0) - 1.0))


## Hay línea de vista (ningún muro ni objeto en medio) entre `origin` y el objetivo.
func _net_line_of_sight(origin: Vector3, t: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin, center_of(t), Props.LAYER_WORLD | Props.LAYER_PROPS, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] == t


## Servidor: aplica la fuerza de los agarres confirmados. Se suelta si el metal se apaga o el objetivo
## sale de alcance. La moneda de la tecla G (auto_push) se empuja sola con el acero.
func _net_physics(delta: float) -> void:
	applying_force = false
	holding = false
	var a := player.allomancy
	if maxf(a.strength(&"steel"), a.strength(&"iron")) <= 0.0:
		net_release_all()
		return
	_reach = _net_reach()
	var origin := player.chest_position()
	if is_instance_valid(auto_push) and a.strength(&"steel") > 0.0 and center_of(auto_push).distance_to(origin) <= _reach:
		if push_grip.target != auto_push:
			push_grip.target = auto_push
			push_grip.active = true
			push_grip.latched = false
			Fx.sparks(get_tree().current_scene, center_of(auto_push), push_grip.color)
		_net_auto_grip = true
	elif _net_auto_grip:
		_net_auto_grip = false
		_release(push_grip)
	for g in grips():
		if not g.active:
			continue
		var strength := a.strength(g.metal)
		if strength <= 0.0 or not _is_valid(g.target, origin):
			_release(g)
			continue
		holding = true
		g.held += delta
		var accel := Metals.push_pull(origin, player.body_mass, g.target, strength * g.ramp(), g.dir_sign, delta, _reach, base_force)
		player.add_allomantic_acceleration(accel, player.real_delta(delta))
		applying_force = true
	_net_publish()


## Pide agarrar (`pressed`, con el id del objetivo elegido) o soltar un agarre: el servidor lo valida.
func net_request(is_push: bool, pressed: bool, id: int) -> void:
	if multiplayer.is_server():
		net_grip_request(is_push, pressed, id)
	else:
		_net_grip.rpc_id(1, is_push, pressed, id)


func net_anchor_request() -> void:
	if multiplayer.is_server():
		net_anchor()
	else:
		_net_anchor.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _net_grip(is_push: bool, pressed: bool, id: int) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.net_peer_id:
		net_grip_request(is_push, pressed, id)


@rpc("any_peer", "call_remote", "reliable")
func _net_anchor() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.net_peer_id:
		net_anchor()


## Servidor: valida un agarre pedido. Rechaza si no quemas ese metal, si el objetivo no existe, si está
## fuera de alcance o si algo tapa la línea.
func net_grip_request(is_push: bool, pressed: bool, id: int) -> void:
	var g: Grip = push_grip if is_push else pull_grip
	if not pressed:
		g.consume = false
		if not g.latched and not (g == push_grip and _net_auto_grip):
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
	if g.active or g.consume or id == 0 or player.allomancy.strength(g.metal) <= 0.0:
		return
	var t: Node3D = _arena().target_node(id)
	if t == null:
		return
	var origin := player.chest_position()
	_reach = _net_reach()
	if center_of(t).distance_to(origin) > effective_reach(t) or not _net_line_of_sight(origin, t):
		return
	if not _can_grip(g, t):
		return
	g.target = t
	g.active = true
	if g == push_grip:
		_net_auto_grip = false
	Fx.sparks(get_tree().current_scene, center_of(t), g.color)
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
	_net_auto_grip = false
	_net_publish()


## Servidor: deja en el jugador, para replicar, el id del objetivo al que empuja y de cuál tira.
func _net_publish() -> void:
	for i in 2:
		var g: Grip = grips()[i]
		var id: int = _arena().target_id(g.target) if g.active else 0
		if player.net_grips[i] != id:
			player.net_grips[i] = id


## Presentación local: los clientes reciben los agarres del servidor; el jugador de este proceso además
## busca el objetivo bajo su mira (para pedirlo) y ve las líneas a todos los que alcanza.
func _net_presentation() -> void:
	var a := player.allomancy
	var power := maxf(a.strength(&"steel"), a.strength(&"iron"))
	var arena := _arena()
	if not player.is_simulated():
		for i in 2:
			var g: Grip = grips()[i]
			g.target = arena.target_node(player.net_grips[i]) if player.net_grips[i] != 0 else null
			g.active = g.target != null
	_metals.clear()
	target = null
	if power <= 0.0:
		return
	_reach = _net_reach()
	if player.is_local_player():
		var origin := player.chest_position()
		for m in arena.targets():
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


## Elige el metal alcanzable más cercano a la mira (sin contar los ya agarrados) y deja en `_cands` todos
## los que podrías elegir, del más al menos cercano. La mira mide `select_degrees` de radio. El actual
## tiene ventaja para que la selección no salte entre dos objetos parecidos. Con la rueda se elige
## otro (ver cycle_target).
func _pick_target(origin: Vector3) -> Node3D:
	var cam := player.camera
	var cam_pos := cam.global_position
	var aim := player.aim_direction()
	var max_angle := deg_to_rad(select_degrees)
	# En tercera persona el personaje tapa la mira: solo cuenta lo que está más allá de él.
	var min_depth := (origin - cam_pos).dot(aim) + 0.8
	var scored := []
	for m in _metals:
		if m == push_grip.target or m == pull_grip.target:
			continue
		var c := center_of(m)
		var dist := c.distance_to(origin)
		if dist > effective_reach(m) or (c - cam_pos).dot(aim) < min_depth:
			continue
		var angle := aim.angle_to(c - cam_pos)
		if angle > max_angle or not _los_ok(m, origin):
			continue
		var score := angle + dist * 0.0003
		if m == target:
			score -= deg_to_rad(1.0)
		scored.append([score, m])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_cands.clear()
	for s in scored:
		_cands.append(s[1])
	if _manual != null and Time.get_ticks_msec() < _manual_until and _cands.has(_manual):
		return _manual
	_manual = null
	return _cands[0] if not _cands.is_empty() else null


## Qué agarrar al pulsar: lo que está bajo la mira; si no miras nada, el metal que tienes justo debajo
## (la moneda de los pies) y, por último, uno elegido según hacia dónde te mueves.
func click_target(is_push: bool, origin: Vector3) -> Node3D:
	if target != null:
		return target
	var feet := _feet_target(origin)
	if feet != null:
		return feet
	return _auto_target(is_push, origin)


## Tecla R: ancla los agarres activos (siguen aunque se suelte el clic; volver a pulsar el clic los suelta).
func anchor_pressed() -> void:
	if net:
		net_anchor_request()
	else:
		for g in grips():
			if g.active:
				g.latched = true


## Hacia dónde quieres ir (plano): lo que pulsas con WASD según la cámara, o hacia donde mira la cámara.
func _wanted_direction() -> Vector3:
	var input := player._move_vector()
	var basis := player.yaw_pivot.global_basis
	var dir := basis * Vector3(input.x, 0.0, input.y) if input != Vector2.ZERO else -basis.z
	dir.y = 0.0
	return dir.normalized()


## Sin nada a la vista: el metal firme (ancla o cosa pesada) que más ayuda a moverte hacia donde quieres.
## Tirar te acerca al objetivo, así que conviene el que está hacia donde vas y arriba; empujar te aleja,
## así que conviene el del lado contrario y abajo. Prefiere los más cercanos.
func _auto_target(is_push: bool, origin: Vector3) -> Node3D:
	var want := _wanted_direction()
	var best: Node3D = null
	var best_score := AUTO_MIN_SCORE
	for m in _metals:
		if m == push_grip.target or m == pull_grip.target:
			continue
		var mass := Metals.movable_mass(m)
		if mass > 0.0 and mass < AUTO_MIN_MASS:
			continue
		var to := center_of(m) - origin
		var dist := to.length()
		if dist < 2.0 or dist > effective_reach(m) or not _los_ok(m, origin):
			continue
		var dir := to / dist
		var sign := -1.0 if is_push else 1.0
		var score := 0.65 * dir.dot(want) * sign + 0.35 * dir.y * sign - dist * 0.004
		if score > best_score:
			best_score = score
			best = m
	return best


## Rueda del ratón con acero o hierro encendido: pasa al siguiente (o anterior) metal cerca de la mira.
## Devuelve false si no hay donde elegir (entonces la rueda sigue cambiando de arma).
func cycle_target(step: int) -> bool:
	var a := player.allomancy
	if maxf(a.strength(&"steel"), a.strength(&"iron")) <= 0.0 or _cands.size() < 2:
		return false
	var i := _cands.find(target)
	_manual = _cands[posmod((i if i >= 0 else 0) + step, _cands.size())]
	_manual_until = Time.get_ticks_msec() + MANUAL_HOLD_MS
	target = _manual
	return true


## En red el servidor exige línea de vista: lo que tapa un muro no se puede elegir (se ve apagado).
## Individual: sin cambios, siempre true. El resultado se guarda unas décimas para no lanzar tantos rayos.
func _los_ok(t: Node3D, origin: Vector3) -> bool:
	if not net:
		return true
	var id := t.get_instance_id()
	var now := Time.get_ticks_msec()
	var entry: Array = _los_cache.get(id, [0, true])
	if now - int(entry[0]) > 120:
		entry = [now, _net_line_of_sight(origin, t)]
		_los_cache[id] = entry
	return entry[1]


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


## Dibujo "de aurora": en reposo solo puntos suaves sobre lo que puedes usar (pocos si quemas, más si
## avivas); una cinta lenta y ondulante hacia el objetivo bajo la mira, y una más intensa (con núcleo fino)
## hacia cada agarre activo. Nada serpentea rápido ni parpadea.
func _draw_lines() -> void:
	_bolts.begin()
	for m in _markers.values():
		m.visible = false
	for d in _dots:
		d.visible = false
	var view_cam := get_viewport().get_camera_3d()
	if _metals.is_empty() or view_cam == null:
		_bolts.end()
		return
	var origin := player.chest_position()
	var cam := view_cam.global_position
	var aim := -view_cam.global_basis.z
	var view := get_viewport().get_visible_rect().size
	var now := Time.get_ticks_msec() / 1000.0
	var a := player.allomancy
	var flare := maxf(a.strength(&"steel"), a.strength(&"iron")) > 1.5
	var shown := []
	for m in _metals:
		if not is_instance_valid(m):
			continue
		var end := center_of(m)
		var seed := float(m.get_instance_id() % 997) * 0.37
		var grip: Grip = push_grip if m == push_grip.target else (pull_grip if m == pull_grip.target else null)
		if grip:
			# Agarre activo: cinta intensa con núcleo; el flujo lento marca si empuja (se aleja) o tira.
			_bolts.add(origin, end, 0.012, Color(grip.color.r, grip.color.g, grip.color.b, 1.0), 0.5 * grip.dir_sign,
					seed, bolt_amplitude * 0.8, false, true, true)
		elif m == target:
			_bolts.add(origin, end, 0.009, Color(0.35, 0.65, 1.0, 0.55), 0.3, seed, bolt_amplitude * 0.7, false, false, true)
		else:
			var to := end - cam
			var depth := to.dot(aim)
			if depth <= 0.5:
				continue
			var dist := origin.distance_to(end)
			var eff := effective_reach(m)
			var usable := dist <= eff
			if not usable and not flare:
				continue
			var off := view_cam.unproject_position(end).distance_to(view * 0.5) / view.y
			shown.append([off + dist * 0.002, m, dist, eff, usable, depth / to.length()])
		if grip or m == target:
			var marker: MeshInstance3D = _markers[grip] if grip else _markers["hover"]
			var pulse := 1.0 + (0.12 * sin(now * 3.0) if grip else 0.0)
			if grip and grip.latched:
				pulse *= 1.3  # anclado: destello más grande
			marker.visible = true
			marker.global_position = end
			marker.scale = Vector3.ONE * cam.distance_to(end) * 0.07 * pulse
	# Puntos suaves: los más cercanos a la mira, hasta el tope (quemando pocos, avivando más y los lejanos).
	shown.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var budget := DOTS_FLARE if flare else DOTS_BURN
	for i in mini(mini(shown.size(), budget), _dots.size()):
		var s: Array = shown[i]
		var m: Node3D = s[1]
		var weight := _importance(m)
		# Desvanece lo que queda de costado o detrás, y lo que está al límite de su alcance.
		var view_fade := smoothstep(0.15, 0.7, float(s[5]))
		var far_fade := 1.0 - smoothstep(0.55, 1.0, float(s[2]) / float(s[3])) if s[4] else 0.35
		var alpha := 0.85 * weight * view_fade * far_fade
		var col := Color(0.45, 0.72, 1.0, alpha)
		if not _los_ok(m, origin):
			col = Color(0.55, 0.6, 0.7, alpha * 0.45)  # tapado: se ve, pero no se puede elegir
		var dot := _dots[i]
		var pos := center_of(m)
		dot.visible = true
		dot.global_position = pos
		dot.scale = Vector3.ONE * minf(cam.distance_to(pos) * (0.012 + 0.012 * weight), 0.3)
		(dot.material_override as StandardMaterial3D).albedo_color = col
	_bolts.end()


## Qué tan "firme" se ve un metal: lo anclado y lo pesado brillan más; una moneda suelta, apenas.
func _importance(t: Node3D) -> float:
	var mass := Metals.movable_mass(t)
	if mass <= 0.0:
		return 1.0
	return lerpf(0.4, 0.9, clampf(log(mass + 1.0) / 7.6, 0.0, 1.0))
