class_name Player
extends CharacterBody3D
## Nacido de la bruma: movimiento en tercera persona, cámara y controles de alomancia.
## Las habilidades viven en nodos hijos (SteelIron, Atium, TinSenses); el peltre se aplica aquí.

@export var walk_speed := 6.0
@export var jump_velocity := 5.5
@export var ground_accel := 45.0
@export var air_accel := 8.0
@export var body_mass := 70.0
@export var mouse_sensitivity := 0.0025
@export var base_fov := 75.0
@export var max_coins_in_world := 120
@export_group("Salud")
@export var max_health := 100.0
## Velocidad de impacto (m/s) que aguantas sin daño. Caer 7 m ≈ 12 m/s, 20 m ≈ 20 m/s, 40 m ≈ 28 m/s.
@export var safe_impact_speed := 12.0
@export var impact_damage := 6.0  ## daño por cada m/s por encima del umbral
## Parte de la velocidad horizontal perdida que cuenta como impacto (chocar de costado duele menos).
const HORIZONTAL_IMPACT := 0.6
@export var regen_delay := 4.0
@export var regen_rate := 3.0

@export_group("Resistencia")
@export var max_stamina := 100.0
## Por segundo: se recupera quieto y se gasta caminando (más rápido cuanto más rápido vas).
const STAMINA_REGEN := 14.0
const STAMINA_MOVE_DRAIN := 1.5
## Costes por acción.
const JUMP_COST := 7.0
const ROLL_COST := 14.0
const DASH_COST := 10.0
const ATTACK_COST := 6.0
## Sin aliento (resistencia a 0) vas más lento y no saltas, ruedas ni pegas hasta recuperar esto.
const EXHAUSTED_SPEED := 0.7
const EXHAUSTED_RECOVER := 25.0

@export_group("Combate y movimiento")
@export var roll_speed := 9.0
@export var roll_duration := 0.6
@export var air_dash_speed := 8.0

signal damaged(amount: float, impact_speed: float)
signal died
## Esquivaste un golpe gracias al atium (el atacante no lo quemaba).
signal dodged
## Aviso corto para el HUD ("sin bolsa", "recogiste la bolsa"...).
signal notice(text: String)

## Armas: daño y empuje base (el peltre los multiplica) y alcance.
## combo: golpes encadenados [duración, × daño, × empuje]; el último es el remate (con estocada).
const WEAPONS := [
	{"name": "Puños", "damage": 8.0, "knockback": 4.0, "reach": 1.6,
		"combo": [[0.45, 1.0, 1.0], [0.5, 1.1, 1.2], [0.7, 1.7, 2.5]]},
	# Dagas: cuatro golpes distintos; el cuarto, un tajo doble que empuja lejos.
	{"name": "Dagas de obsidiana", "damage": 14.0, "knockback": 3.0, "reach": 1.8,
		"combo": [[0.42, 1.0, 1.0], [0.46, 1.05, 1.0], [0.5, 1.15, 1.2], [0.78, 2.1, 3.2]]},
	{"name": "Espada", "damage": 30.0, "knockback": 7.0, "reach": 2.4,
		"combo": [[0.55, 1.0, 1.0], [0.6, 1.1, 1.2], [0.85, 1.8, 3.0]]},
]
## Tiempo extra tras un golpe para encadenar el siguiente del combo.
const COMBO_WINDOW := 0.45
## Segundos sin pelear tras los que se considera que el combate terminó.
const COMBAT_TIMEOUT := 6.0

var health := 100.0
## Lo que se puede usar con E aquí al lado (puerta, armario...); lo pone Interactable.
var interactable: Interactable
## Resistencia: la gastan correr, saltar, rodar y pegar; el peltre la hace rendir más. Ver _update_stamina.
var stamina := 100.0
var _exhausted := false
var _tired_notice_ms := 0
var dead := false
var weapon := HumanoidRig.Weapon.NONE
## Bando: 0 = el jugador y sus aliados. Los alománticos de otro bando pueden atacarte.
var team := 0
## Llevas monedas encima: otros alománticos pueden empujarte o tirar de ti.
var allomantic_mass := 70.0

signal equipment_changed

## Inventario (ver Items): ranura -> id del objeto equipado ("" vacía) y los objetos que tienes.
var equipment := Items.START_EQUIPPED.duplicate()
var owned: Array[String] = []
var vial_charges := 3
## El inventario pasa de una escena a otra (ciudad, Kredik Shaw, arena).
static var _saved := {}
## Hay una ventana abierta (inventario): el ratón es para la interfaz, no para el juego.
var ui_open := false

var allomancy: Allomancy
var steel_iron: SteelIron
var atium: Atium
var senses: TinSenses

var yaw_pivot: Node3D
var pitch_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
## Contiene el cuerpo (HumanoidRig). Gira hacia donde caminas y el atium lo copia para las estelas.
var visual: Node3D
var rig: HumanoidRig
var spawn_point := Vector3.ZERO

## Red: id del par que controla a este jugador (0 = partida individual, sin cambios).
## En red el servidor simula a todos: cada cliente le manda sus teclas y copia el resultado.
var net_peer_id := 0
## Replicado por el servidor para animar el cuerpo en los clientes (que no simulan).
var net_on_floor := false
## Metales de red (ver NET_METALS) replicados por el servidor: estado (0 apagado / 1 quemando / 2 avivando)
## y reserva de cada uno, y el arrastre de peltre. net_grips: id del objetivo al que empuja y de cuál tira (0 si a ninguno; ver NetArena.target_id).
const NET_METALS: Array[StringName] = [&"steel", &"iron", &"pewter"]
var net_metal_states := PackedInt32Array([0, 0, 0])
var net_metal_reserves := PackedFloat32Array([100.0, 100.0, 100.0])
var net_pewter_drag := 0.0
var net_grips := PackedInt32Array([0, 0])
## Teclas que el servidor sabe de un jugador remoto: movimiento, acciones sostenidas y pulsaciones nuevas.
const NET_ACTIONS: Array[StringName] = [&"jump", &"move_forward", &"move_back", &"roll"]
## Sin recibir entrada durante este tiempo (ms) el servidor suelta las teclas del jugador remoto.
const NET_INPUT_TIMEOUT_MS := 500
var _net_move := Vector2.ZERO
var _net_held := {}
var _net_just := {}
var _net_last_ms := 0

## Combate en red: un único golpe cuerpo a cuerpo que decide el servidor (sin armas ni combos todavía).
const NET_ATTACK := {"damage": 20.0, "knockback": 5.0, "reach": 2.0, "arc": 1.0, "cooldown_ms": 600}
## Contadores replicados: al cambiar, los clientes dibujan el golpe y el impacto localmente.
var net_attacks := 0:
	set(value):
		if value != net_attacks and is_node_ready() and _is_net_client():
			_show_net_attack()
		net_attacks = value
var net_hits := 0:
	set(value):
		if value != net_hits and is_node_ready() and _is_net_client():
			_show_net_hit()
		net_hits = value
## Solo servidor: quién dio el último golpe (para contar la baja) y cuándo puede volver a pegar.
var net_last_attacker := 0
var _net_attack_ready_ms := 0
## Solo servidor: separación mínima entre dos monedas de un mismo jugador, para que no inunde la arena.
const COIN_COOLDOWN_MS := 150
var _net_coin_ready_ms := 0
## Lanzar monedas (clic derecho): a mano llega a COIN_HAND_SPEED; el acero suma COIN_STEEL_SPEED.
const COIN_HAND_SPEED := 13.0
const COIN_STEEL_SPEED := 14.0
## Alt+E: radio (m) en el que se atraen las monedas, velocidad a la que vuelan hacia ti y tiempo máximo (ms).
## Alt+E con acero: cuántas monedas salen en círculo y la pausa (ms) hasta poder repetirlo.
const COIN_RING_COUNT := 8
const COIN_RING_COOLDOWN_MS := 500
const GATHER_RADIUS := 15.0
const GATHER_SPEED := 24.0
const GATHER_MS := 2500
const COIN_CATCH_DIST := 1.1
var _gathering: Array[Coin] = []
var _gather_until_ms := 0
## Monedero: monedas que llevas (cada lanzamiento o soltada gasta una; las del suelo se recogen al pasar).
const COIN_START := 1000
const COIN_MAX := 9999
const COIN_PICKUP_RADIUS := 0.8
var coins_held := COIN_START
var net_coins := COIN_START  # replicado en red
## Cámara: el hombro de la cámara al lado; al mirar hacia abajo pasa al eje del personaje (apunta bajo tus pies).
const CAMERA_SHOULDER := 0.55
## Cliente: último estado visto, para disparar el parpadeo de daño y la pantalla de muerte.
var _seen_health := 100.0
var _seen_dead := false
## Protección tras reaparecer (la decide y cuenta el servidor; los clientes solo parpadean).
const NET_PROTECTION_MS := 3000
var net_protected := false
var _protected_until_ms := 0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## Aceleración alomántica recibida en el último paso (para no frenar en seco al empujar desde el suelo).
var _allomantic_accel := 0.0
var _shake := 0.0
var _since_damage := 99.0
var _attack_cd := 0.0
var _attack_side := 1
var _combo := 0
var _combo_window := 0.0
## Pulsaste atacar justo antes de poder: el golpe sale en cuanto se pueda.
var _attack_buffered := false
var _combat_ms := -1000000
## Moneda que se empuja sola (clic derecho o salto de acero), y cómo estaba el acero antes.
var _coin_push_steel := Allomancy.State.OFF
## La moneda empujada es un disparo del clic derecho (no se frena a GUIDED_COIN_SPEED).
var _coin_shot := false
## El empuje automático lo inició un salto de acero: se suelta al soltar Espacio.
var _jump_push := false
## Segundo salto en el aire (Espacio dos veces, sin acero): una vez por salto. Altura relativa al salto normal
## (AIR_JUMP_BOOST sin peltre, más AIR_JUMP_PEWTER por cada punto de peltre) y empuje extra hacia donde pulsas.
const AIR_JUMP_BOOST := 1.2
const AIR_JUMP_PEWTER := 1.1
const AIR_JUMP_FORWARD := 3.0
## Acero + peltre en el doble Espacio: impulso vertical extra (múltiplo del salto) por punto de peltre.
const PEWTER_STEEL_KICK := 1.0
var _air_jump_used := false
## Último toque de Espacio (ms), para detectar el doble toque.
var _last_jump_ms := -100000
## Doble toque en la tecla de un metal: tecla y momento del último toque, y lo que se aviva
## mientras se mantiene (tecla -> metales).
const DOUBLE_TAP_MS := 300
var _last_tap_key := KEY_NONE
var _last_tap_ms := 0
var _flare_held := {}
const PEWTER_DRAG_TIME := 15.0
var _pewter_drag := 0.0
var _was_flaring_pewter := false
## Alomancia emocional de enemigos (hasta cuándo, en ms).
var _soothed_ms := 0
var _rioted_ms := 0
var emotions: Emotions
var _roll_time := 0.0
var _roll_cd := 0.0
var _roll_dir := Vector3.ZERO
## Pulsar rodar justo antes de tocar el suelo amortigua la caída.
var _roll_buffer := 0.0
var _air_dash_used := false
## Dash en el aire: el impulso se reparte en unas décimas (más suave que de golpe).
const DASH_TIME := 0.22
var _dash_time := 0.0
var _dash_dir := Vector3.ZERO
var _dash_speed := 0.0
## Golpe aéreo (E en el aire): uno por salto, con un salto extra.
var _air_attack_used := false
## Tiempo que te queda siendo empujado por otro (no frenas en seco contra el suelo).
var _shoved := 0.0
## Las dagas se desenvainan solas al atacar y se guardan al terminar el combate,
## salvo que hayas elegido pelear con los puños (rueda del ratón).
var _auto_drawn := false
var _fists_chosen := false
## Bolsa de monedas soltada en el suelo (null: la llevas encima).
var _bag: MetalBag = null
var _bag_dropped_ms := 0
var _guide: JumpGuide
## Agarrarse a bordes: te agarras si el choque contra la pared no te haría más de este daño.
const LEDGE_MAX_DAMAGE := 10.0
## Alturas (sobre los pies) entre las que el borde queda a mano.
const LEDGE_REACH := Vector2(1.0, 2.6)
## Los pies quedan esto por debajo del borde al colgar.
const HANG_DROP := 2.0
const CLIMB_TIME := 0.65
## Nado: profundidad mínima del agua para flotar, cuánto queda el origen del personaje bajo la
## superficie (en las animaciones de nado el cuello va a esa altura) y velocidad respecto a la
## de correr.
const SWIM_DEPTH := 1.3
const SWIM_FLOAT := 0.1
const SWIM_SPEED := 0.4
var _hanging := false
var _climb_t := -1.0  # >= 0 mientras subes
var _climb_len := CLIMB_TIME  # lo que dura la animación de subir
var _climb_from := Vector3.ZERO
var _swimming := false
var _slide_t := 0.0  # > 0 mientras resbalas por una pendiente demasiado empinada para pisar
var _ledge := {}  # {"top", "normal", "wall"}
var _ledge_cd := 0.0


func _ready() -> void:
	add_to_group("player")
	add_to_group(&"combatant")
	add_to_group(&"allomancer_body")
	add_to_group(&"metal")  # la bolsa de monedas (ver carries_metal)
	owned.assign(Items.START_BAG)
	if not _saved.is_empty():
		equipment = _saved["equipment"].duplicate()
		owned.assign(_saved["owned"])
		vial_charges = _saved["vials"]
	set_meta(&"center_offset", Vector3(0, 1.1, 0))
	allomantic_mass = body_mass
	collision_layer = Props.LAYER_PLAYER
	collision_mask = Props.LAYER_WORLD | Props.LAYER_PROPS
	_build_body()
	_build_camera()

	allomancy = Allomancy.new()
	allomancy.name = "Allomancy"
	add_child(allomancy)
	steel_iron = SteelIron.new()
	steel_iron.name = "SteelIron"
	steel_iron.player = self
	add_child(steel_iron)
	atium = Atium.new()
	atium.name = "Atium"
	atium.player = self
	add_child(atium)
	senses = TinSenses.new()
	senses.name = "TinSenses"
	senses.player = self
	add_child(senses)
	var swirl := MistSwirl.new()
	swirl.holder = self
	add_child(swirl)
	var aura := PewterAura.new()
	aura.holder = self
	add_child(aura)
	var bronze := BronzeSense.new()
	bronze.holder = self
	add_child(bronze)
	emotions = Emotions.new()
	emotions.player = self
	add_child(emotions)
	_guide = JumpGuide.new()
	add_child(_guide)

	health = max_health
	stamina = max_stamina
	spawn_point = global_position
	_apply_equipment()
	if is_local_player():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_network()
	GameSettings.load_settings()
	GameSettings.apply_to(self)
	if is_local_player():
		Progression.load_progress()


## Borra el inventario y equipo que pasan de un escenario a otro (empezar de cero).
static func clear_saved() -> void:
	_saved = {}


func _exit_tree() -> void:
	_saved = {"equipment": equipment.duplicate(), "owned": owned.duplicate(), "vials": vial_charges}


func _build_body() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.9
	add_child(col)

	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	rig = Art.player_rig({
		"skin": Color(0.9, 0.77, 0.67),
		"hair": Color(0.07, 0.05, 0.05),
		"hair_style": "long",
		"shirt": Color(0.15, 0.15, 0.17),
		"pants": Color(0.12, 0.12, 0.13),
		"boots": Color(0.07, 0.06, 0.06),
		"cloak": true,
		"cloak_color": Color(0.2, 0.21, 0.25),
		"bracers": Color(0.14, 0.1, 0.08),
		"vials": true,
		"daggers": true,
		"sword": true,
		"height": 0.95,
		"build": 0.95,
	})
	rig.use_real_time = true
	visual.add_child(rig)


func _build_camera() -> void:
	yaw_pivot = Node3D.new()
	yaw_pivot.name = "YawPivot"
	yaw_pivot.position = Vector3(0, 1.6, 0)
	add_child(yaw_pivot)
	pitch_pivot = Node3D.new()
	yaw_pivot.add_child(pitch_pivot)
	spring_arm = SpringArm3D.new()
	spring_arm.spring_length = 3.8
	spring_arm.margin = 0.2
	spring_arm.position = Vector3(CAMERA_SHOULDER, 0, 0)
	spring_arm.collision_mask = Props.LAYER_WORLD
	spring_arm.add_excluded_object(get_rid())
	pitch_pivot.add_child(spring_arm)
	camera = Camera3D.new()
	camera.fov = base_fov
	camera.far = 2500.0  # para ver los montes de ceniza en el horizonte
	spring_arm.add_child(camera)
	if is_local_player():
		camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if not is_local_player():
		return  # el ratón y el teclado de este proceso son de otro jugador
	if dead and not event is InputEventMouseMotion:
		return
	if ui_open and (event is InputEventMouseMotion or event is InputEventMouseButton):
		return  # con el inventario abierto el ratón es para la ventana
	if net_peer_id != 0:
		_networked_input(event)
		return
	if event.is_action_pressed(&"drink"):
		drink_vial()
		return
	if _look(event):
		if event is InputEventMouseButton:
			return  # el clic que recaptura el ratón no ataca ni lanza
	elif event is InputEventKey and not event.echo:
		var key := event as InputEventKey
		var group := Allomancy.metals_for_key(key.physical_keycode)
		if not group.is_empty():
			if key.pressed:
				_metal_key_down(key.physical_keycode, group)
			else:
				_metal_key_up(key.physical_keycode)

	if event.is_action_pressed(&"stop_burning"):
		allomancy.stop_all()
	elif event.is_action_pressed(&"gather_coins"):
		coin_alt_action()
	elif event.is_action_pressed(&"coin_shot"):
		_start_coin_shot()
	elif event.is_action_released(&"coin_shot"):
		_end_coin_push()
	elif event.is_action_pressed(&"drop_bag"):
		toggle_bag()
	elif event.is_action_pressed(&"weapon_cycle"):
		var step := -1 if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN else 1
		if steel_iron.cycle_target(step):
			return  # con acero o hierro encendido y varios metales cerca de la mira, la rueda elige objetivo
		var w := posmod(weapon + step, WEAPONS.size())
		while not can_use_weapon(w):
			w = posmod(w + step, WEAPONS.size())  # las armas que no llevas se saltan
		weapon = w as HumanoidRig.Weapon
		_fists_chosen = weapon == HumanoidRig.Weapon.NONE
		_auto_drawn = false
		rig.set_weapon(weapon)
	elif event.is_action_pressed(&"interact") and interactable and interactable.prompt != "":
		interactable.use()
	elif event.is_action_pressed(&"attack"):
		attack()
	elif event.is_action_pressed(&"roll"):
		roll()
	elif event.is_action_pressed(&"hood") and rig.cloak:
		rig.cloak.set_hood(not rig.cloak.hood_up)


## Mover la cámara con el ratón o recapturarlo con un clic. Devuelve true si el evento era de ratón.
func _look(event: InputEvent) -> bool:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		yaw_pivot.rotate_y(-motion.relative.x * mouse_sensitivity)
		pitch_pivot.rotation.x = clampf(pitch_pivot.rotation.x - motion.relative.y * mouse_sensitivity,
				deg_to_rad(-89.0), deg_to_rad(60.0))
		return true
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return true
	return false


# ---------------------------------------------------------------- Red

## Este proceso es quien maneja a este jugador (siempre en partida individual).
func is_local_player() -> bool:
	return net_peer_id == 0 or (multiplayer.has_multiplayer_peer() and net_peer_id == multiplayer.get_unique_id())


## Experiencia por usar metales ("práctica"): por segundo quemando algo y con tope por minuto, para no farmear.
const XP_PRACTICE_RATE := 6.0
const XP_PRACTICE_CAP_PER_MIN := 180
var _practice_acc := 0.0
var _practice_window_ms := 0
var _practice_window_xp := 0


## Suma experiencia del jugador local (por ahora solo en partida individual; la red llega con el servidor).
func grant_xp(amount: int) -> void:
	if net_peer_id != 0 or not is_local_player():
		return
	var gained := Progression.add_xp(amount)
	if gained > 0:
		notice.emit("Nivel %d  ·  +%d punto%s de alomancia" % [Progression.level, gained, "" if gained == 1 else "s"])


func _update_practice_xp(rd: float) -> void:
	if net_peer_id != 0 or not is_local_player() or dead or allomancy.burning_metals().is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - _practice_window_ms >= 60000:
		_practice_window_ms = now
		_practice_window_xp = 0
	_practice_acc += XP_PRACTICE_RATE * rd
	if _practice_acc < 5.0:
		return
	var give := mini(int(_practice_acc), XP_PRACTICE_CAP_PER_MIN - _practice_window_xp)
	_practice_acc = 0.0
	if give > 0:
		_practice_window_xp += give
		grant_xp(give)


## Este proceso simula la física de este jugador (siempre en partida individual).
func is_simulated() -> bool:
	return net_peer_id == 0 or (multiplayer.has_multiplayer_peer() and multiplayer.is_server())


## Entrada del jugador que maneja este proceso, o la que mandó su cliente si el servidor lo simula.
func _held(action: StringName) -> bool:
	return Input.is_action_pressed(action) if is_local_player() else _net_held.get(action, false)


func _just(action: StringName) -> bool:
	if is_local_player():
		return Input.is_action_just_pressed(action)
	var pressed: bool = _net_just.get(action, false)
	_net_just[action] = false
	return pressed


func _move_vector() -> Vector2:
	if is_local_player():
		return Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	return _net_move


## En red se mira, rueda y golpea; metales y armas llegan en etapas posteriores.
func _networked_input(event: InputEvent) -> void:
	if _look(event):
		return
	if event.is_action_pressed(&"roll"):
		if multiplayer.is_server():
			roll()
		else:
			_net_roll.rpc_id(1)
	elif event is InputEventKey and not event.echo and _is_net_metal_key(event):
		var down: bool = event.pressed
		if multiplayer.is_server():
			_net_metal_key(event.physical_keycode, down)
		else:
			_net_metal.rpc_id(1, event.physical_keycode, down)
	elif event.is_action_pressed(&"gather_coins"):  # antes que pull: Alt+E también es E
		if multiplayer.is_server():
			coin_alt_action()
		else:
			_net_gather.rpc_id(1)
	elif (event.is_action(&"pull") or event.is_action(&"push")) and not event.is_echo():
		if not (event is InputEventKey and event.alt_pressed):
			_net_click(event)
	elif event.is_action_pressed(&"anchor"):
		steel_iron.anchor_pressed()
	elif event.is_action_pressed(&"weapon_cycle"):
		# En red todavía no hay armas que cambiar: la rueda solo elige objetivo de acero/hierro.
		steel_iron.cycle_target(-1 if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN else 1)
	elif event.is_action_pressed(&"coin_shot") or event.is_action_released(&"coin_shot"):
		var held := event.is_action_pressed(&"coin_shot")
		var aim := aim_point() if held else Vector3.ZERO
		var look := aim_direction() if held else Vector3.ZERO
		if multiplayer.is_server():
			_net_coin_shot_key(held, aim, look)
		else:
			_net_coin_shot.rpc_id(1, held, aim, look)
	elif event.is_action_pressed(&"attack"):
		if multiplayer.is_server():
			server_attack()
		else:
			_net_attack.rpc_id(1)


## Clic de tirar/empujar: pide al servidor agarrar (con el ancla que tienes en la mira) o soltar.
## Igual que en el juego individual: con un solo metal encendido sirven los dos clics.
func _net_click(event: InputEvent) -> void:
	var pressed := event.is_pressed()
	for is_push in [true, false]:
		var metal: StringName = &"steel" if is_push else &"iron"
		var other: StringName = &"iron" if is_push else &"steel"
		var mine := event.is_action(&"push" if is_push else &"pull")
		if not allomancy.is_burning(metal) or not (mine or not allomancy.is_burning(other)):
			continue
		var id := 0
		if pressed:
			# Igual que en individual: lo que miras, lo que tienes
			# bajo los pies o lo que más ayuda a moverte; el servidor valida cualquiera de ellos.
			var t := steel_iron.click_target(is_push, chest_position())
			id = get_parent().target_id(t)
		steel_iron.net_request(is_push, pressed, id)


func _is_net_client() -> bool:
	return net_peer_id != 0 and multiplayer.has_multiplayer_peer() and not multiplayer.is_server()


## Servidor: valida y resuelve un golpe. Nadie más aplica daño: el cliente solo lo pide.
func server_attack() -> void:
	var now := Time.get_ticks_msec()
	var arena := get_parent()  # NetArena (sin tipar, para no depender de esa clase desde aquí)
	if dead or now < _net_attack_ready_ms or _hanging or _climb_t >= 0.0 or (arena.has_method(&"can_fight") and not arena.can_fight()):
		return
	if not _spend_stamina(ATTACK_COST):
		return
	_net_attack_ready_ms = now + int(NET_ATTACK["cooldown_ms"])
	var forward := -yaw_pivot.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	visual.rotation.y = atan2(-forward.x, -forward.z)
	rig.play_attack(1, 0.4, 0)
	net_protected = false  # atacar cancela la protección: no sirve para pegar sin riesgo
	net_attacks += 1
	for other: Node in get_tree().get_nodes_in_group(&"player"):
		var target := other as Player
		if target == null or target == self or target.net_peer_id == 0 or target.dead or target.net_protected:
			continue
		var to := target.global_position - global_position
		to.y = 0.0
		if to.length() > NET_ATTACK["reach"] or forward.angle_to(to) > NET_ATTACK["arc"]:
			continue
		var pewter := allomancy.strength(&"pewter")
		var damage: float = NET_ATTACK["damage"] * (1.0 + 0.75 * pewter) * (0.6 if _pewter_drag > 0.0 else 1.0)
		var knockback: float = NET_ATTACK["knockback"] * (1.0 + pewter)
		target._receive_net_hit(to.normalized() * knockback, damage, net_peer_id)


## Servidor: aplica un golpe confirmado.
func _receive_net_hit(impulse: Vector3, damage: float, attacker_id: int) -> void:
	net_last_attacker = attacker_id
	# El peltre endurece el cuerpo: menos empujón y menos daño (igual que en take_hit).
	var pewter := allomancy.strength(&"pewter")
	impulse /= 1.0 + 0.5 * pewter
	damage /= 1.0 + 0.6 * pewter
	velocity += impulse + Vector3.UP * impulse.length() * 0.2
	_shoved = 0.35
	net_hits += 1
	Fx.sparks(get_tree().current_scene, chest_position(), Color(0.6, 0.1, 0.1))
	take_damage(damage)


## Servidor: vuelve a empezar (nueva ronda) con vida completa en su punto de aparición.
func net_reset() -> void:
	respawn()
	health = max_health
	dead = false


func _show_net_attack() -> void:
	rig.play_attack(1, 0.4, 0)


func _show_net_hit() -> void:
	rig.stagger = 1.0
	Fx.sparks(get_tree().current_scene, chest_position(), Color(0.6, 0.1, 0.1))


func _setup_network() -> void:
	if net_peer_id == 0:
		return
	collision_mask |= Props.LAYER_PLAYER  # en red los jugadores se chocan entre sí
	# Acero y hierro: el servidor aplica la fuerza (solo donde se simula); todos dibujan las líneas.
	steel_iron.net = true
	steel_iron.set_physics_process(is_simulated())
	if not is_simulated():
		allomancy.set_process(false)  # en el cliente la reserva la manda el servidor
	var sync := MultiplayerSynchronizer.new()
	sync.name = "NetSync"
	var config := SceneReplicationConfig.new()
	for path in [^".:position", ^".:velocity", ^".:net_on_floor", ^"Visual:rotation",
			^".:health", ^".:stamina", ^".:_exhausted", ^".:dead", ^".:net_attacks", ^".:net_hits", ^".:net_protected",
			^".:net_metal_states", ^".:net_metal_reserves", ^".:net_pewter_drag", ^".:net_grips", ^".:net_coins"]:
		config.add_property(path)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	# Los agarres solo cambian al agarrar o soltar: se mandan cuando cambian, no cada fotograma.
	config.property_set_replication_mode(^".:net_grips", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = config
	# El servidor se lo muestra a cada par (ver NetArena) cuando ya creó este jugador; los clientes
	# lo ven siempre, si no no pueden enviarle RPCs al servidor.
	sync.public_visibility = not multiplayer.is_server()
	add_child(sync)
	if multiplayer.is_server():
		_start_protection()  # también al entrar al duelo


## Cliente: manda al servidor sus teclas, hacia dónde mira y el giro de la cámara.
func _send_net_input() -> void:
	if not is_local_player():
		return
	var mask := 0
	for i in NET_ACTIONS.size():
		if Input.is_action_pressed(NET_ACTIONS[i]):
			mask |= 1 << i
	_net_input.rpc_id(1, Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back"),
			yaw_pivot.rotation.y, mask)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _net_input(move: Vector2, yaw: float, mask: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != net_peer_id:
		return
	if not (is_finite(move.x) and is_finite(move.y) and is_finite(yaw)):
		return
	_net_move = move.limit_length(1.0)
	yaw_pivot.rotation.y = yaw
	for i in NET_ACTIONS.size():
		var held := mask & (1 << i) != 0
		if held and not _net_held.get(NET_ACTIONS[i], false):
			_net_just[NET_ACTIONS[i]] = true
		_net_held[NET_ACTIONS[i]] = held
	_net_last_ms = Time.get_ticks_msec()


@rpc("any_peer", "call_remote", "reliable")
func _net_roll() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == net_peer_id:
		roll()


## Metales que funcionan en red por ahora: acero (1), hierro (2) y peltre (3).
func _is_net_metal_key(event: InputEventKey) -> bool:
	var group := Allomancy.metals_for_key(event.physical_keycode)
	return group.size() == 1 and NET_METALS.has(group[0])


## Servidor: pulsar o soltar una tecla de metal (encender/apagar; doble toque y mantener: avivar).
func _net_metal_key(code: Key, pressed: bool) -> void:
	var group := Allomancy.metals_for_key(code)
	if dead or group.size() != 1 or not NET_METALS.has(group[0]):
		return
	if pressed:
		_metal_key_down(code, group)
	else:
		_metal_key_up(code)


@rpc("any_peer", "call_remote", "reliable")
func _net_metal(code: int, pressed: bool) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == net_peer_id:
		_net_metal_key(code as Key, pressed)


## Servidor: al reaparecer o empezar una ronda los metales vuelven a estar llenos, apagados y sin agarres.
func _refill_net_metals() -> void:
	for m in NET_METALS:
		allomancy.reserve[m] = Allomancy.METALS[m]["max"]
		allomancy.state[m] = Allomancy.State.OFF
	steel_iron.net_release_all()
	_pewter_drag = 0.0
	_was_flaring_pewter = false
	coins_held = COIN_START


## Servidor: clic derecho mantenido (lanza una moneda fuerte hacia donde apunta y la empuja sola) o soltado.
func _net_coin_shot_key(held: bool, aim: Vector3, look: Vector3) -> void:
	if not held:
		_end_coin_push()
		return
	var now := Time.get_ticks_msec()
	if dead or now < _net_coin_ready_ms or steel_iron.auto_push != null:
		return
	if not aim.is_finite() or aim.length() > 5000.0 or not look.is_finite() or look.length() < 0.5:
		return
	_net_coin_ready_ms = now + COIN_COOLDOWN_MS
	_start_coin_shot(aim, look)


@rpc("any_peer", "call_remote", "reliable")
func _net_gather() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == net_peer_id:
		coin_alt_action()


@rpc("any_peer", "call_remote", "reliable")
func _net_coin_shot(held: bool, aim: Vector3, look: Vector3) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == net_peer_id:
		_net_coin_shot_key(held, aim, look)


@rpc("any_peer", "call_remote", "reliable")
func _net_attack() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == net_peer_id:
		server_attack()


## Cliente: no simula, solo anima el cuerpo con lo que replica el servidor.
func _update_remote_rig() -> void:
	rig.move_speed = Vector2(velocity.x, velocity.z).length()
	rig.vertical_speed = velocity.y
	rig.on_floor = net_on_floor
	rig.body_velocity = velocity
	# Metales: el estado y la reserva los manda el servidor; el HUD y el aura los leen de allomancy.
	for i in NET_METALS.size():
		allomancy.state[NET_METALS[i]] = net_metal_states[i]
		allomancy.reserve[NET_METALS[i]] = net_metal_reserves[i]
	_pewter_drag = net_pewter_drag
	coins_held = net_coins
	# La vida y la muerte las decide el servidor; aquí solo se muestran (parpadeo, pantalla de muerte).
	if health < _seen_health - 0.01 and not dead:
		damaged.emit(_seen_health - health, 0.0)
	if dead and not _seen_dead:
		died.emit()
	_seen_health = health
	_seen_dead = dead


## Tocar la tecla de un metal lo enciende o lo apaga.
## Doble toque y mantener: aviva mientras la mantengas; al soltar vuelve a quemar normal.
func _metal_key_down(key: Key, group: Array[StringName]) -> void:
	var now := Time.get_ticks_msec()
	if key == _last_tap_key and now - _last_tap_ms < DOUBLE_TAP_MS:
		_last_tap_key = KEY_NONE
		for m in group:
			if not (m == &"pewter" and _pewter_drag > 0.0):
				allomancy.set_state(m, Allomancy.State.FLARE)
		_flare_held[key] = group
		return
	_last_tap_key = key
	_last_tap_ms = now
	var any_on := group.any(func(m: StringName) -> bool: return allomancy.is_burning(m))
	for m in group:
		if m == &"pewter" and _pewter_drag > 0.0:
			continue  # con arrastre de peltre no puedes volver a quemarlo
		allomancy.set_state(m, Allomancy.State.OFF if any_on else Allomancy.State.BURN)


func _metal_key_up(key: Key) -> void:
	if not _flare_held.has(key):
		return
	for m: StringName in _flare_held[key]:
		if allomancy.is_flaring(m):
			allomancy.set_state(m, Allomancy.State.BURN)
	_flare_held.erase(key)


## Latón o cinc de un enemigo (strength 2 = avivado). El cobre te protege: devuelve false.
## Aplacado: no puedes avivar. Enardecido: pegas +15 % pero recibes +25 %.
func apply_emotion(metal: StringName, _strength: float, _source: Node3D) -> bool:
	if dead or allomancy.is_burning(&"copper"):
		return false
	var until := Time.get_ticks_msec() + 2000
	if metal == &"zinc":
		_rioted_ms = until
	else:
		_soothed_ms = until
	mark_combat()
	return true


func is_soothed() -> bool:
	return Time.get_ticks_msec() < _soothed_ms


func is_rioted() -> bool:
	return Time.get_ticks_msec() < _rioted_ms


## Segundos que le quedan al arrastre de peltre (0 si no lo tienes).
func pewter_drag() -> float:
	return maxf(_pewter_drag, 0.0)


func is_exhausted() -> bool:
	return _exhausted


## Peltre: gastas menos (×0,67 quemando, ×0,5 avivando) y recuperas más rápido; con arrastre, al revés.
func _stamina_cost_mult() -> float:
	return (1.0 / (1.0 + 0.5 * allomancy.strength(&"pewter"))) * (1.5 if _pewter_drag > 0.0 else 1.0)


## Quieto en el suelo recuperas; caminando gastas un poco; en el aire ni una cosa ni la otra
## (volar con metales no cansa). Al quedarte en 0 estás sin aliento hasta recuperar EXHAUSTED_RECOVER.
func _update_stamina(rd: float) -> void:
	if dead or not is_on_floor():
		return
	var pewter := allomancy.strength(&"pewter")
	if _move_vector().length() < 0.1:
		var regen := STAMINA_REGEN * (1.0 + 0.5 * pewter) * (0.5 if _pewter_drag > 0.0 else 1.0)
		stamina += regen * rd
	else:
		var ratio := clampf(Vector2(velocity.x, velocity.z).length() / walk_speed, 0.0, 2.5)
		stamina -= STAMINA_MOVE_DRAIN * ratio * _stamina_cost_mult() * rd
	stamina = clampf(stamina, 0.0, max_stamina)
	if stamina <= 0.0:
		_exhausted = true
	elif _exhausted and stamina >= EXHAUSTED_RECOVER:
		_exhausted = false


## Gasta `cost` si puedes (con poca resistencia igual haces la acción y quedas en 0).
func _spend_stamina(cost: float) -> bool:
	if _exhausted:
		var now := Time.get_ticks_msec()
		if now - _tired_notice_ms > 1500:
			_tired_notice_ms = now
			notice.emit("Sin aliento")
		return false
	stamina = maxf(stamina - cost * _stamina_cost_mult(), 0.0)
	if stamina <= 0.0:
		_exhausted = true
	return true


## Tras quemar todo el peltre avivando: lento y débil un rato, y no puedes volver a quemarlo.
func _update_pewter_drag(rd: float) -> void:
	if _was_flaring_pewter and allomancy.reserve[&"pewter"] <= 0.0:
		_pewter_drag = PEWTER_DRAG_TIME
	_was_flaring_pewter = allomancy.is_flaring(&"pewter")
	if _pewter_drag > 0.0:
		_pewter_drag -= rd
		allomancy.set_state(&"pewter", Allomancy.State.OFF)


## Espacio + WASD con el acero encendido: suelta una moneda detrás de ti (según la dirección) y la
## empuja sola mientras mantengas Espacio: el empuje te lanza hacia arriba y hacia donde pulsas.
## Cayendo, la moneda sale disparada hacia abajo, llega antes al suelo y el empuje te frena.
## Ayudas (ver _assist_coin_push): la moneda no sale volando más rápido que GUIDED_COIN_SPEED y
## se clava al tocar el suelo; con WASD dirigís el salto; se dibuja dónde caerías al soltar.
const GUIDED_COIN_SPEED := 20.0
## Cuánto detrás de ti (en m) cae la moneda del salto de acero: más atrás, salto más largo y menos alto.
## Con 0.4 el empuje sale unos 65° hacia arriba: una parábola alta que luego avanza hacia donde pulsas.
const STEEL_JUMP_BACK := 0.4


func _start_coin_push(back := Vector3.ZERO) -> void:
	if dead:
		return
	var coin := drop_coin(back)
	if coin == null:
		return
	if not is_on_floor():
		# Algo más rápida que tú, lo justo para ir por debajo (si va muy rápida, no da apoyo).
		coin.linear_velocity = Vector3(velocity.x, minf(velocity.y, 0.0) - 8.0, velocity.z)
	_engage_coin_push(coin)


## Clic derecho: lanza una moneda a plena fuerza hacia donde apuntas y la empuja con acero mientras
## mantengas el clic. Sirve para pegar con la moneda o, apuntando abajo, para frenar una caída.
func _start_coin_shot(aim_target := Vector3.INF, aim_dir := Vector3.INF) -> void:
	if dead:
		return
	var coin := throw_coin(aim_target, aim_dir)
	if coin == null:
		return
	_coin_shot = true
	_engage_coin_push(coin)


## Enciende el acero si hace falta y deja la moneda como objetivo del empuje automático.
func _engage_coin_push(coin: RigidBody3D) -> void:
	_coin_push_steel = allomancy.state[&"steel"]
	# Cayendo rápido se aviva solo: quemando normal no alcanza para frenar una caída alta.
	if velocity.y < -8.0:
		allomancy.set_state(&"steel", Allomancy.State.FLARE)
	elif _coin_push_steel == Allomancy.State.OFF:
		allomancy.set_state(&"steel", Allomancy.State.BURN)
	steel_iron.auto_push = coin


## Salto de acero: con el acero encendido y monedas en el monedero.
func _can_steel_jump() -> bool:
	return not dead and has_bag() and coins_held > 0 and allomancy.strength(&"steel") > 0.0 \
			and steel_iron.auto_push == null and Time.get_ticks_msec() >= _net_coin_ready_ms


func _end_coin_push() -> void:
	_jump_push = false
	_coin_shot = false
	if steel_iron.auto_push == null:
		return
	var coin := steel_iron.auto_push as RigidBody3D
	if is_instance_valid(coin):
		coin.set_deferred(&"freeze", false)  # vuelve a ser una moneda suelta
		coin.gravity_scale = 1.0
	steel_iron.auto_push = null
	allomancy.set_state(&"steel", _coin_push_steel)


## Mientras se empuja la moneda de la G: que no se vaya volando (así el empuje no se pierde en
## el aire) y que se clave al tocar el suelo, como un ancla.
func _assist_coin_push() -> bool:
	var coin := steel_iron.auto_push as RigidBody3D
	if not is_instance_valid(coin):
		return false
	if not coin.freeze:
		if coin.get_contact_count() > 0:
			coin.set_deferred(&"freeze", true)
			coin.linear_velocity = Vector3.ZERO
		elif coin.linear_velocity.length() > GUIDED_COIN_SPEED and not _coin_shot:
			coin.linear_velocity = coin.linear_velocity.normalized() * GUIDED_COIN_SPEED
	return steel_iron.push_grip.active and steel_iron.push_grip.target == coin


## Soltar la bolsa (F): sin metal encima nadie puede empujarte ni tirar de ti, pero tampoco
## tienes monedas. F cerca de ella (o pasar por encima) la recoge.
func toggle_bag() -> void:
	if dead:
		return
	if _bag == null:
		_bag = MetalBag.new()
		get_tree().current_scene.add_child(_bag)
		_bag.global_position = global_position + Vector3(0, 0.4, 0) - visual.global_basis.z * 0.5
		_bag.linear_velocity = velocity * 0.5
		_bag_dropped_ms = Time.get_ticks_msec()
		_update_metal_group()
		if carries_metal():
			notice.emit("Soltaste la bolsa, pero llevás otro metal encima (mirá el inventario)")
		else:
			notice.emit("Soltaste la bolsa: nadie puede empujarte, pero no tenés monedas")
		return
	var d := _bag.global_position.distance_to(global_position)
	if d < 2.5:
		_pick_up_bag()
	else:
		notice.emit("Tu bolsa está a %d m (traéla con hierro o andá a buscarla)" % int(d))


func _pick_up_bag(animate := true) -> void:
	if animate:
		rig.play_pickup()
	if is_instance_valid(_bag):
		_bag.queue_free()
	_bag = null
	_update_metal_group()
	notice.emit("Recogiste la bolsa de monedas")


## En el río, donde el agua cubre más de SWIM_DEPTH (solo en escenarios con río).
func _in_deep_water() -> bool:
	if get_tree().get_node_count_in_group(&"water") == 0:
		return false
	var bed := CityPlan.river_bed(Vector2(global_position.x, global_position.z))
	var y := global_position.y
	return CityPlan.WATER_LEVEL - bed > SWIM_DEPTH and y < CityPlan.WATER_LEVEL - 0.05 and y > bed - 0.5


func has_bag() -> bool:
	return _bag == null


func _update_bag() -> void:
	if _bag == null:
		return
	if not is_instance_valid(_bag) or _bag.global_position.y < -40.0:
		_pick_up_bag(false)  # se perdió: aparece de nuevo contigo
		return
	# Pasar por encima la recoge (no justo al soltarla).
	if Time.get_ticks_msec() - _bag_dropped_ms > 1200 \
			and _bag.global_position.distance_to(global_position + Vector3(0, 0.5, 0)) < 1.1:
		_pick_up_bag()


func mark_combat() -> void:
	_combat_ms = Time.get_ticks_msec()


func in_combat() -> bool:
	return Time.get_ticks_msec() - _combat_ms < COMBAT_TIMEOUT * 1000.0


func _physics_process(delta: float) -> void:
	if net_peer_id != 0:
		if not multiplayer.has_multiplayer_peer():
			return  # se cortó la conexión: NetArena ya está retirando a los jugadores
		if not multiplayer.is_server():
			_send_net_input()
			return
		net_on_floor = is_on_floor()
		for i in NET_METALS.size():
			net_metal_states[i] = allomancy.state[NET_METALS[i]]
			net_metal_reserves[i] = allomancy.reserve[NET_METALS[i]]
		net_pewter_drag = _pewter_drag
		net_coins = coins_held
		if net_protected and Time.get_ticks_msec() >= _protected_until_ms:
			net_protected = false
		if not is_local_player() and Time.get_ticks_msec() - _net_last_ms > NET_INPUT_TIMEOUT_MS:
			_net_move = Vector2.ZERO
			_net_held.clear()
	var rd := real_delta(delta)
	_update_practice_xp(rd)
	_update_pewter_drag(rd)
	allomancy.flare_blocked = is_soothed()
	var pewter := allomancy.strength(&"pewter")
	var speed_mult := (1.0 + 0.6 * pewter) * gear_stat("speed")  # peltre: 1.6x quemando, 2.2x avivando
	var jump_mult := 1.0 + 0.3 * pewter
	if _pewter_drag > 0.0:
		speed_mult = 0.6
		jump_mult = 0.7
	_update_stamina(rd)
	if _exhausted:
		speed_mult *= EXHAUSTED_SPEED

	_update_bag()
	_collect_coins()
	_ledge_cd -= rd
	var was_swimming := _swimming
	_swimming = _in_deep_water()
	if _swimming and not was_swimming:
		velocity.y *= 0.2  # el agua frena la caída
		Fx.burst(get_tree().current_scene, global_position + Vector3(0, 0.3, 0), Color(0.6, 0.7, 0.8, 0.5), 16, 3.0, 0.8, 0.6, -6.0, false)
	if _hanging or _climb_t >= 0.0:
		_update_ledge(rd)
		return
	# Con la moneda de la G o con cualquier agarre activo, WASD dirige mucho más en el aire.
	var guided := _assist_coin_push() or steel_iron.holding
	if _swimming and velocity.y <= 2.0:
		# Flota con la cabeza fuera: un resorte hacia la superficie (saltando, sale del agua).
		var float_y := CityPlan.WATER_LEVEL - SWIM_FLOAT
		velocity.y = move_toward(velocity.y, (float_y - global_position.y) * 3.0, 15.0 * rd)
	elif not is_on_floor():
		# Durante el dash planeas un poco (cae más despacio).
		velocity.y -= _gravity * rd * (0.35 if _dash_time > 0.0 else 1.0)
	if _jump_push and not _held(&"jump"):
		_end_coin_push()
	if _just(&"jump") and not dead and not ui_open:
		var now := Time.get_ticks_msec()
		var double_tap := now - _last_jump_ms <= DOUBLE_TAP_MS
		_last_jump_ms = now
		var move := _move_vector()
		# Con WASD: salto de acero hacia esa dirección; con doble Espacio sin dirección: recto hacia arriba.
		if _can_steel_jump() and (move != Vector2.ZERO or double_tap):
			# Moneda detrás de ti según WASD: el empuje te manda hacia arriba y hacia esa dirección.
			var back := -(yaw_pivot.global_basis * Vector3(move.x, 0.0, move.y))
			back.y = 0.0
			_net_coin_ready_ms = now + COIN_COOLDOWN_MS
			_start_coin_push(back.normalized() * STEEL_JUMP_BACK)
			_jump_push = steel_iron.auto_push != null
			_last_jump_ms = -DOUBLE_TAP_MS * 10
			# Acero + peltre en el doble Espacio: además del empuje de la moneda, el cuerpo reforzado da un impulso.
			if double_tap and move == Vector2.ZERO and pewter > 0.0 and _jump_push:
				velocity.y = maxf(velocity.y, 0.0) + jump_velocity * PEWTER_STEEL_KICK * pewter
				_air_jump_used = true
		elif double_tap and not is_on_floor() and not _swimming and not _air_jump_used and _spend_stamina(JUMP_COST):
			# Doble Espacio en el aire sin acero: segundo salto (el peltre lo hace mucho más fuerte).
			_air_jump_used = true
			_last_jump_ms = -DOUBLE_TAP_MS * 10
			velocity.y = jump_velocity * (AIR_JUMP_BOOST + AIR_JUMP_PEWTER * pewter)
			var push := yaw_pivot.global_basis * Vector3(move.x, 0.0, move.y)
			velocity += push.normalized() * AIR_JUMP_FORWARD * (1.0 + 0.5 * pewter)
			rig.play_jump()
		elif (is_on_floor() or _swimming) and _spend_stamina(JUMP_COST):
			velocity.y = jump_velocity * jump_mult
			rig.play_jump()

	var input := Vector2.ZERO if dead else _move_vector()
	var dir := yaw_pivot.global_basis * Vector3(input.x, 0, input.y)
	dir.y = 0.0
	dir = dir.normalized()
	var target := Vector2(dir.x, dir.z) * walk_speed * speed_mult
	var hv := Vector2(velocity.x, velocity.z)
	_shoved -= rd
	var being_pushed := _allomantic_accel > 2.0 or _shoved > 0.0
	_attack_cd -= rd
	_combo_window -= rd
	if _attack_buffered and _attack_cd <= 0.0:
		_attack_buffered = false
		attack()
	_roll_cd -= rd
	_roll_buffer -= rd
	if is_on_floor():
		_air_dash_used = false
		_air_attack_used = false
		_air_jump_used = false
	if _dash_time > 0.0:
		# El dash acelera rápido al principio y se suaviza al final.
		var k := _dash_time / DASH_TIME
		_dash_time -= rd
		hv += Vector2(_dash_dir.x, _dash_dir.z) * _dash_speed * (2.0 * k) * rd / DASH_TIME
		velocity.y = lerpf(velocity.y, maxf(velocity.y, 1.0), minf(10.0 * rd, 1.0))
	if _roll_time > 0.0:
		# Durante la voltereta mantienes la dirección y velocidad del impulso.
		_roll_time -= rd
		if is_on_floor():
			hv = Vector2(_roll_dir.x, _roll_dir.z) * roll_speed * (1.0 + 0.3 * pewter)
	elif (is_on_floor() or _swimming) and not being_pushed:
		hv = hv.move_toward(target * (SWIM_SPEED if _swimming else 1.0), ground_accel * rd)
	elif input != Vector2.ZERO:
		# En el aire solo añadimos control, sin frenar el impulso de un empujón.
		# Empujando la moneda de la G, el triple: así diriges el salto.
		var along := hv.dot(target.normalized())
		if along < target.length() * (1.5 if guided else 1.0):
			hv += target.normalized() * air_accel * (3.0 if guided else 1.0) * rd
	velocity.x = hv.x
	velocity.z = hv.y
	_allomantic_accel = 0.0

	var was_on_floor := is_on_floor()
	var fall_speed := velocity.y
	var velocity_before := velocity
	# Durante el Sandevistan el mundo va lento pero tú no: compensamos el time_scale.
	var ts := Engine.time_scale
	velocity /= ts
	move_and_slide()
	velocity *= ts

	# Pendiente de más de floor_max_angle (45°): Godot la cuenta como pared y resbalas.
	_slide_t -= rd
	if not is_on_floor() and not _swimming and velocity.y < 0.0:
		for i in get_slide_collision_count():
			if get_slide_collision(i).get_normal().y > 0.2:
				_slide_t = 0.2  # margen: el contacto parpadea de un frame a otro
	if is_on_floor() and not was_on_floor:
		if fall_speed < -4.0 and _roll_time <= 0.0:
			rig.play_land(clampf(-fall_speed / 15.0, 0.3, 1.0))
		if fall_speed < -7.0:
			var strength := clampf(-fall_speed / 20.0, 0.3, 1.5)
			_shake = maxf(_shake, strength * 0.35)
			Fx.dust(get_tree().current_scene, global_position, strength)
	# Impacto = velocidad perdida al chocar (suelo, paredes o techo). Contra una pared (de costado)
	# cuenta el 60 %: volando con acero te frenas con brazos y piernas; cayendo, no.
	var lost := velocity_before - velocity
	var impact := Vector3(lost.x * HORIZONTAL_IMPACT, lost.y, lost.z * HORIZONTAL_IMPACT).length()
	# Contra un edificio con el borde a mano: si el golpe no te haría más de LEDGE_MAX_DAMAGE
	# (el peltre aguanta más), te agarras al borde en vez de rebotar.
	var ledge := {} if is_on_floor() or dead or _ledge_cd > 0.0 or velocity_before.y > 3.0 \
			else _find_ledge(velocity_before)
	var ledge_damage := impact_damage_for(impact)
	if not ledge.is_empty() and ledge_damage <= LEDGE_MAX_DAMAGE:
		if ledge_damage > 0.0:
			take_damage(ledge_damage, impact)
		_grab_ledge(ledge)
	else:
		_check_impact(impact)

	var guide_on := is_instance_valid(steel_iron.auto_push) and not dead
	var exclude: Array[RID] = [get_rid()]
	if guide_on:
		exclude.append((steel_iron.auto_push as CollisionObject3D).get_rid())
	_guide.show_path(guide_on and is_local_player(), global_position + Vector3(0, 0.1, 0), velocity, exclude)
	_update_rig(hv, rd)

	var target_fov := base_fov + 5.0 * pewter + 12.0 * atium.intensity
	camera.fov = lerpf(camera.fov, target_fov, 6.0 * rd)

	if global_position.y < -40.0:
		respawn()


# ---------------------------------------------------------------- Bordes

## Busca un borde al que agarrarse en la pared contra la que acabas de chocar: el techo o la
## cornisa tiene que quedar a la altura de las manos. Devuelve {} si no hay.
func _find_ledge(moving: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		if absf(n.y) > 0.3:
			continue
		var nh := Vector3(n.x, 0, n.z).normalized()
		# Ibas hacia la pared (o cayendo pegado a ella).
		if Vector3(moving.x, 0, moving.z).dot(-nh) < 1.0 and moving.y > -2.0:
			continue
		var p := c.get_position()
		var from := Vector3(p.x, global_position.y + LEDGE_REACH.y + 0.4, p.z) - nh * 0.35
		var to := Vector3(from.x, global_position.y + LEDGE_REACH.x, from.z)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Props.LAYER_WORLD, [get_rid()]))
		if hit.is_empty() or (hit["normal"] as Vector3).y < 0.6:
			continue
		var top: Vector3 = hit["position"]
		# Lugar para subir: nada encima del borde.
		var up := PhysicsRayQueryParameters3D.create(top + Vector3.UP * 0.1, top + Vector3.UP * 1.9, Props.LAYER_WORLD, [get_rid()])
		if not space.intersect_ray(up).is_empty():
			continue
		return {"top": top, "normal": nh, "wall": p}
	return {}


func _grab_ledge(ledge: Dictionary) -> void:
	_ledge = ledge
	_hanging = true
	_climb_t = -1.0
	var nh: Vector3 = ledge["normal"]
	var top: Vector3 = ledge["top"]
	var wall: Vector3 = ledge["wall"]
	global_position = Vector3(wall.x, top.y - HANG_DROP, wall.z) + nh * 0.37
	velocity = Vector3.ZERO
	_dash_time = 0.0
	_end_coin_push()
	visual.rotation.y = atan2(nh.x, nh.z)  # de cara a la pared
	rig.hanging = true
	Fx.dust(get_tree().current_scene, top, 0.4)
	_shake = maxf(_shake, 0.15)


## Colgado: W o Espacio suben al borde; S o Shift te sueltan.
func _update_ledge(rd: float) -> void:
	velocity = Vector3.ZERO
	var nh: Vector3 = _ledge["normal"]
	var top: Vector3 = _ledge["top"]
	if _hanging:
		if dead or ui_open:
			pass
		elif _just(&"jump") or _held(&"move_forward"):
			_hanging = false
			_climb_t = 0.0
			_climb_from = global_position
			rig.hanging = false
			_climb_len = rig.play_climb(CLIMB_TIME)
		elif _just(&"move_back") or _just(&"roll") or dead:
			_release_ledge(nh * 2.0)
	else:
		# Subida: primero arriba pegado a la pared, después hacia dentro sobre el borde.
		_climb_t += rd / _climb_len
		var k := clampf(_climb_t, 0.0, 1.0)
		var high := Vector3(_climb_from.x, top.y + 0.05, _climb_from.z)
		var over := Vector3(top.x, top.y + 0.05, top.z) - nh * 0.6
		var u := smoothstep(0.0, 1.0, k / 0.6)
		var f := smoothstep(0.0, 1.0, (k - 0.5) / 0.5)
		global_position = _climb_from.lerp(high, u).lerp(over, f)
		if _climb_t >= 1.0:
			_climb_t = -1.0
			_ledge_cd = 0.3
	_update_rig(Vector2(-nh.x, -nh.z) * 0.01, rd)


func _release_ledge(push: Vector3) -> void:
	_hanging = false
	_climb_t = -1.0
	rig.hanging = false
	velocity = push
	_ledge_cd = 0.5


func is_hanging() -> bool:
	return _hanging


func _update_rig(hv: Vector2, rd: float) -> void:
	rig.move_speed = Vector2(velocity.x, velocity.z).length()
	rig.vertical_speed = velocity.y
	rig.on_floor = is_on_floor() or _swimming
	rig.swimming = _swimming
	rig.sliding = _slide_t > 0.0
	rig.body_velocity = velocity
	# Brazo derecho al objetivo de empuje, izquierdo al de tirón.
	var face := hv
	rig.aim_target = null
	rig.aim_target_left = null
	if rig is ModelRig:
		rig.push_power = allomancy.strength(&"steel")
		rig.pull_power = allomancy.strength(&"iron")
	if _hanging:
		# Las dos manos en el borde.
		var nh: Vector3 = _ledge["normal"]
		var top: Vector3 = _ledge["top"]
		var side := nh.cross(Vector3.UP)
		rig.aim_target = top - nh * 0.1 + side * 0.3
		rig.aim_target_left = top - nh * 0.1 - side * 0.3
		if rig is ModelRig:
			rig.push_power = 1.0
			rig.pull_power = 1.0
		return
	for g in [steel_iron.pull_grip, steel_iron.push_grip]:
		if not g.active or not is_instance_valid(g.target):
			continue
		var aim := steel_iron.center_of(g.target)
		if g == steel_iron.push_grip:
			rig.aim_target = aim
		else:
			rig.aim_target_left = aim
		# Gírate hacia el objetivo salvo que esté justo debajo (moneda a los pies).
		var to := Vector2(aim.x - global_position.x, aim.z - global_position.z)
		if to.length() > 1.0:
			face = to.normalized() * 10.0
	if face.length() > 0.5:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-face.x, -face.y), 12.0 * rd)


func _process(delta: float) -> void:
	var rd := real_delta(delta)
	if is_local_player():
		# Hacia abajo la cámara pasa del hombro al eje del personaje: la mira apunta justo bajo tus pies.
		var down := clampf(inverse_lerp(deg_to_rad(40.0), deg_to_rad(80.0), -pitch_pivot.rotation.x), 0.0, 1.0)
		spring_arm.position.x = lerpf(CAMERA_SHOULDER, 0.0, down)
	# Regeneración; el peltre acelera la curación.
	_since_damage += rd
	if not dead and _since_damage > regen_delay and is_simulated():
		health = minf(health + regen_rate * (1.0 + 2.0 * allomancy.strength(&"pewter")) * rd, max_health)
	# El estaño (el dolor te despeja) te recupera antes de un golpe: avivado, el triple de rápido.
	var recover := rd * 3.0 * (1.0 + allomancy.strength(&"tin"))
	if rig is ModelRig:
		rig.down = dead  # animación de caída del modelo
		rig.stagger = move_toward(rig.stagger, 0.0, recover)
	else:
		rig.stagger = 1.0 if dead else move_toward(rig.stagger, 0.0, recover)
		visual.rotation.x = lerpf(visual.rotation.x, PI / 2 if dead else 0.0, minf(rd * 6.0, 1.0))  # tumbado al morir
	# Dagas desenvainadas solas: se guardan un rato después de dejar de pelear.
	if _auto_drawn and not in_combat() and _attack_cd < -4.0:
		_auto_drawn = false
		weapon = HumanoidRig.Weapon.NONE
		rig.set_weapon(weapon)
	_shake = move_toward(_shake, 0.0, rd * 1.2)
	camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.25
	camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.25
	if net_peer_id != 0:
		# Protegido tras reaparecer: parpadea (el servidor lo marca, ambos clientes lo dibujan).
		visual.visible = not net_protected or int(Time.get_ticks_msec() / 120.0) % 2 == 0
	if net_peer_id != 0 and multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_update_remote_rig()


## Daño que haría un impacto a esa velocidad. El peltre sube el umbral y reduce el daño
## (quemando: 20 m/s y la mitad; avivando: 28 m/s y un tercio); las botas suben el umbral.
func impact_damage_for(impact_speed: float) -> float:
	var pewter := allomancy.strength(&"pewter")
	var safe := safe_impact_speed + 8.0 * pewter + gear_stat("impact", true)
	return maxf(impact_speed - safe, 0.0) * impact_damage / (1.0 + pewter)


func _check_impact(impact_speed: float) -> void:
	var damage := impact_damage_for(impact_speed)
	if dead or damage <= 0.0:
		return
	if _roll_buffer > 0.0 and is_on_floor():
		# Rodar al aterrizar: el golpe se reparte y haces poco daño.
		damage *= 0.35
		_roll_buffer = 0.0
		_start_roll(Vector3(velocity.x, 0, velocity.z))
	take_damage(damage, impact_speed)


## Equipa un objeto que tienes (el que estaba en esa ranura vuelve a la mochila).
func equip(id: String) -> void:
	var it := Items.get_item(id)
	if it.is_empty() or not id in owned:
		return
	var slot: String = it["slot"]
	var old: String = equipment.get(slot, "")
	if old != "":
		owned.append(old)
	owned.erase(id)
	equipment[slot] = id
	_apply_equipment()


## Quita lo de una ranura y lo guarda en la mochila.
func unequip(slot: String) -> void:
	var old: String = equipment.get(slot, "")
	if old == "":
		return
	owned.append(old)
	equipment[slot] = ""
	_apply_equipment()


## Recoges un objeto (cofre, alomántico derrotado...). Si la ranura está vacía, te lo pones.
func give_item(id: String) -> void:
	var it := Items.get_item(id)
	if it.is_empty():
		return
	owned.append(id)
	if equipment.get(it["slot"], "") == "":
		equip(id)
	notice.emit("Conseguiste: %s  (I: inventario)" % it["name"])
	equipment_changed.emit()


func has_item(id: String) -> bool:
	return id in owned or id in equipment.values()


## Producto (o suma, si additive) de un stat de todo lo equipado, sin contar las armas
## (sus stats solo cuentan al usarlas, ver weapon_stats).
func gear_stat(key: String, additive := false) -> float:
	var v := 0.0 if additive else 1.0
	for slot in Items.SLOTS:
		var id: String = equipment.get(slot, "")
		if id == "" or slot == "daggers" or slot == "sword":
			continue
		var s := Items.stat(id, key, 0.0 if additive else 1.0)
		v = v + s if additive else v * s
	return v


## Llevas algo de metal encima (bolsa de monedas o un objeto metálico): te pueden empujar.
func carries_metal() -> bool:
	if has_bag():
		return true
	for id: String in equipment.values():
		if id != "" and Items.get_item(id).get("metal", false):
			return true
	return false


func _update_metal_group() -> void:
	if carries_metal():
		add_to_group(&"metal")
	elif is_in_group(&"metal"):
		remove_from_group(&"metal")


func max_vials() -> int:
	return int(Items.stat(equipment.get("vials", ""), "charges", 0.0))


## Estadísticas del arma `w` con el objeto equipado en su ranura.
func weapon_stats(w: int) -> Dictionary:
	var stats: Dictionary = WEAPONS[w].duplicate()
	var id := _weapon_item(w)
	if id != "":
		stats["name"] = Items.get_item(id)["name"]
		stats["damage"] *= Items.stat(id, "damage", 1.0)
		stats["knockback"] *= Items.stat(id, "knockback", 1.0)
		stats["reach"] += Items.stat(id, "reach", 0.0)
	return stats


func _weapon_item(w: int) -> String:
	match w:
		HumanoidRig.Weapon.DAGGERS:
			return equipment.get("daggers", "")
		HumanoidRig.Weapon.SWORD:
			return equipment.get("sword", "")
	return ""


## Puedes usar el arma (los puños siempre; dagas y espada si las llevas equipadas).
func can_use_weapon(w: int) -> bool:
	return w == HumanoidRig.Weapon.NONE or _weapon_item(w) != ""


func _apply_equipment() -> void:
	if not can_use_weapon(weapon):
		weapon = HumanoidRig.Weapon.NONE
	vial_charges = mini(vial_charges, max_vials())
	var body := Items.get_item(equipment.get("body", ""))
	rig.set_equipment(body.get("dark", false), equipment.get("cloak", "") != "",
			equipment.get("vials", "") != "", equipment.get("daggers", "") != "")
	rig.set_weapon(weapon)
	_update_metal_group()
	equipment_changed.emit()


## Cuánto se reduce la distancia a la que te ven (ropa oscura y capa de bruma, sobre todo de noche).
func concealment() -> float:
	return gear_stat("conceal_night" if Art.lighting == "noche" else "conceal_day")


## Bebe un frasco: recupera de cada metal salvo atium (según el tipo de frasco).
func drink_vial() -> void:
	if dead or equipment.get("vials", "") == "" or vial_charges <= 0:
		return
	vial_charges -= 1
	var refill := Items.stat(equipment["vials"], "refill", 40.0)
	for m in Allomancy.METALS:  # todo menos el atium
		if m != &"atium":
			allomancy.refill(m, refill)
	Fx.sparks(get_tree().current_scene, chest_position(), Color(0.45, 0.7, 1.0))
	equipment_changed.emit()


## Otro alomántico te empuja o tira de ti (a través de tu bolsa de monedas).
func apply_allomantic_impulse(dv: Vector3) -> void:
	velocity += dv
	_shoved = 0.3


## Golpe cuerpo a cuerpo o de una moneda.
func take_hit(impulse: Vector3, damage: float, attacker: Node3D = null) -> void:
	if dead:
		return
	if attacker and Metals.atium_edge(self, attacker):
		# Atium: viste venir el golpe y te apartas (salvo que el atacante también queme atium).
		var side := (global_position - attacker.global_position).cross(Vector3.UP).normalized()
		velocity += side * (11.0 if randf() < 0.5 else -11.0) + Vector3.UP * 2.0
		_shoved = 0.25
		Atium.dodge_trail(visual)
		atium.pulse()
		Fx.sparks(get_tree().current_scene, chest_position(), Metals.ATIUM_COLOR)
		mark_combat()
		dodged.emit()
		return
	# Con atium, el atacante ve el hueco: ni armadura ni peltre frenan el golpe.
	var unblockable := attacker != null and Metals.atium_edge(attacker, self)
	if is_rioted():
		damage *= 1.25
	if not unblockable:
		damage *= 1.0 - clampf(gear_stat("armor", true), 0.0, 0.8)
	if _hanging or _climb_t >= 0.0:
		_release_ledge(Vector3.ZERO)  # un golpe te suelta del borde
	# El peltre endurece el cuerpo: menos daño y menos empujón (quemando ~40 %, avivando ~55 %).
	var pewter := 0.0 if unblockable else allomancy.strength(&"pewter")
	impulse /= 1.0 + 0.5 * pewter
	velocity += impulse + Vector3.UP * impulse.length() * 0.2
	_shoved = 0.35
	mark_combat()
	if attacker and attacker.has_method(&"mark_combat"):
		attacker.mark_combat()
	take_damage(damage / (1.0 + 0.6 * pewter))


func is_down() -> bool:
	return dead


func take_damage(amount: float, impact_speed := 0.0) -> void:
	if dead:
		return
	health -= amount
	_since_damage = 0.0
	_shake = maxf(_shake, clampf(amount / 60.0, 0.2, 0.7))
	rig.stagger = 1.0
	damaged.emit(amount, impact_speed)
	if health <= 0.0:
		_die()


func _die() -> void:
	health = 0.0
	dead = true
	allomancy.stop_all()
	died.emit()
	get_tree().create_timer(2.5, true, false, true).timeout.connect(func() -> void:
		respawn()
		health = max_health
		dead = false
	)


## Ataque cuerpo a cuerpo con el arma actual. Pulsando a tiempo se encadena el combo
## (golpe, golpe, remate). El peltre da más velocidad, daño y empuje.
func attack() -> void:
	if dead or rig.is_rolling() or ui_open or _hanging or _climb_t >= 0.0:
		return
	if _attack_cd > 0.0:
		_attack_buffered = _attack_cd < 0.3
		return
	if not _spend_stamina(ATTACK_COST):
		return
	if weapon == HumanoidRig.Weapon.NONE and can_use_weapon(HumanoidRig.Weapon.DAGGERS) and not _fists_chosen:
		weapon = HumanoidRig.Weapon.DAGGERS  # desenvaina sola
		_auto_drawn = true
		rig.set_weapon(weapon)
	var pewter := allomancy.strength(&"pewter")
	var stats := weapon_stats(weapon)
	if not is_on_floor() and not _air_attack_used:
		_air_attack(stats, pewter)
		return
	var combo: Array = stats["combo"]
	_combo = (_combo + 1) % combo.size() if _combo_window > 0.0 else 0
	var step: Array = combo[_combo]
	var duration: float = step[0] / (1.0 + 0.5 * pewter)
	_attack_cd = duration * 0.85
	_combo_window = duration + COMBO_WINDOW
	if weapon == HumanoidRig.Weapon.DAGGERS:
		_attack_side = 1 - _attack_side  # alterna las manos
	else:
		_attack_side = 1
	# Golpea hacia donde mira la cámara.
	var fwd := aim_direction()
	fwd.y = 0.0
	fwd = fwd.normalized()
	visual.rotation.y = atan2(-fwd.x, -fwd.z)
	# Remate: el último golpe de un combo (un arma de un solo golpe no tiene remate).
	var finisher := combo.size() > 1 and _combo == combo.size() - 1
	if finisher and is_on_floor():
		velocity += fwd * 4.0  # el remate va con una estocada hacia delante
		_shoved = 0.15
	rig.play_attack(_attack_side, duration, _combo)
	get_tree().create_timer(duration * (0.55 if finisher else 0.4), true, false, true).timeout.connect(
			_resolve_hit.bind(stats, pewter, step[1], step[2], 1.2, 0.0, finisher))


## Golpe aéreo: un tajo giratorio que pega alrededor y te da un salto extra (uno por salto).
func _air_attack(stats: Dictionary, pewter: float) -> void:
	_air_attack_used = true
	var duration := 0.55 / (1.0 + 0.3 * pewter)
	_attack_cd = duration * 0.9
	_combo_window = 0.0
	var fwd := aim_direction()
	fwd.y = 0.0
	fwd = fwd.normalized()
	visual.rotation.y = atan2(-fwd.x, -fwd.z)
	velocity.y = maxf(velocity.y, jump_velocity * 0.9)
	velocity += fwd * 2.5
	rig.play_air_attack(duration)
	Fx.burst(get_tree().current_scene, chest_position(), Color(0.75, 0.8, 0.9, 0.35), 18, 4.0, 0.5, 0.5, 0.0, false)
	get_tree().create_timer(duration * 0.45, true, false, true).timeout.connect(
			_resolve_hit.bind(stats, pewter, 1.4, 1.8, PI, 0.8, true))


## arc: medio ángulo (rad) del golpe hacia delante (PI = todo alrededor). heavy: remate (sacude la cámara).
func _resolve_hit(stats: Dictionary, pewter: float, damage_mult: float, knockback_mult: float,
		arc := 1.2, extra_reach := 0.0, heavy := false) -> void:
	var forward := -visual.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var reach: float = stats["reach"] + extra_reach
	var damage: float = stats["damage"] * damage_mult * (1.0 + 0.75 * pewter)
	if _pewter_drag > 0.0:
		damage *= 0.6
	if is_rioted():
		damage *= 1.15
	var knockback: float = stats["knockback"] * knockback_mult * (1.0 + 1.0 * pewter)
	for n in get_tree().get_nodes_in_group(&"npc"):
		var npc := n as Npc
		var to := npc.global_position - global_position
		to.y = 0.0
		if to.length() > reach or forward.angle_to(to) > arc:
			continue
		var crit := randf() < Metals.crit_chance(self, npc)
		npc.take_hit(to.normalized() * knockback, damage * (Metals.CRIT_MULT if crit else 1.0), self)
		mark_combat()
		if crit:
			Fx.effect(get_tree().current_scene, "ef_fire01", npc.global_position + Vector3(0, 1.2, 0), 0.45, Metals.ATIUM_COLOR)
			_shake = maxf(_shake, 0.3)
		var color := Color(1.0, 0.7, 0.4) if npc.is_in_group(&"metal") else Color(0.6, 0.1, 0.1)
		Fx.sparks(get_tree().current_scene, npc.global_position + Vector3(0, 1.2, 0), color)
		if npc.is_in_group(&"metal"):
			Fx.effect(get_tree().current_scene, "ef_fire01", npc.global_position + Vector3(0, 1.2, 0), 0.3)
		if heavy:
			_shake = maxf(_shake, 0.35)
	for n in get_tree().get_nodes_in_group(&"metal"):
		var rb := n as RigidBody3D
		if rb == null:
			continue
		var to := rb.global_position - global_position
		if to.length() <= reach + 0.5 and forward.angle_to(Vector3(to.x, 0, to.z)) < arc:
			rb.apply_central_impulse(forward * knockback * minf(rb.mass, 20.0) * 0.5)


## Voltereta en el suelo; en el aire, un dash hacia delante (uno por salto).
func roll() -> void:
	if dead or _roll_cd > 0.0 or _hanging or _climb_t >= 0.0 or _swimming:
		return
	var input := _move_vector()
	var dir := yaw_pivot.global_basis * Vector3(input.x, 0, input.y)
	if input == Vector2.ZERO:
		dir = -visual.global_basis.z
	dir.y = 0.0
	dir = dir.normalized()
	if is_on_floor():
		if not _spend_stamina(ROLL_COST):
			return
		_start_roll(dir)
	else:
		_roll_buffer = 0.35  # si tocas el suelo enseguida, ruedas al aterrizar
		if not _air_dash_used:
			if not _spend_stamina(DASH_COST):
				return
			# El impulso se reparte en DASH_TIME y el cuerpo gira suave hacia la dirección
			# (lo hace _update_rig siguiendo la velocidad).
			_air_dash_used = true
			_dash_dir = dir
			_dash_speed = air_dash_speed * (1.0 + 0.3 * allomancy.strength(&"pewter"))
			_dash_time = DASH_TIME
			rig.play_dash(0.45)
			Fx.burst(get_tree().current_scene, chest_position(), Color(0.72, 0.77, 0.88, 0.2), 10, 1.5, 0.8, 0.5, 0.0, false)
			_roll_cd = 0.3


func _start_roll(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = -visual.global_basis.z
	_roll_dir = dir.normalized()
	_roll_time = roll_duration
	_roll_cd = roll_duration + 0.15
	visual.rotation.y = atan2(-_roll_dir.x, -_roll_dir.z)
	rig.play_roll(roll_duration)
	Fx.dust(get_tree().current_scene, global_position, 0.5)


## Delta en tiempo real (inmune al time_scale del atium).
func real_delta(delta: float) -> float:
	return delta / Engine.time_scale


func add_allomantic_acceleration(accel: Vector3, rd: float) -> void:
	velocity += accel * rd
	_allomantic_accel = maxf(_allomantic_accel, accel.length())


func chest_position() -> Vector3:
	return global_position + Vector3(0, 1.2, 0)


func aim_direction() -> Vector3:
	return -camera.global_basis.z


## Punto del mundo bajo la mira (para lanzar monedas hacia donde apuntas).
func aim_point(max_dist := 150.0) -> Vector3:
	var from := camera.global_position
	var to := from + aim_direction() * max_dist
	var query := PhysicsRayQueryParameters3D.create(from, to, Props.LAYER_WORLD | Props.LAYER_PROPS, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if hit else to


## Lanza una moneda a plena fuerza justo hacia el centro de la mira: sale del pecho hacia el punto que
## ve la cámara (el del mundo bajo el puntero, o uno lejano en esa dirección si no hay nada), en línea
## recta (sin gravedad mientras vuela). Con acero va empujada y más rápida (como una bala).
## `aim_target` es el punto que ve la cámara y `aim_dir` su dirección (en red los manda el cliente).
func throw_coin(aim_target := Vector3.INF, aim_dir := Vector3.INF) -> RigidBody3D:
	if not _check_coins():
		return null
	var look := (aim_dir if aim_dir.is_finite() else aim_direction()).normalized()
	var start := chest_position()
	var hit := aim_target if aim_target.is_finite() else aim_point()
	# Un punto detrás de ti (la cámara pegada a un muro): usa uno lejano en la dirección de la mira.
	if (hit - start).dot(look) < 0.5:
		hit = camera.global_position + look * 150.0
	var speed := COIN_HAND_SPEED + COIN_STEEL_SPEED * allomancy.strength(&"steel")
	var dir := (hit - start).normalized()
	var coin := _spawn_coin(start + dir * 0.35)
	coin.gravity_scale = 0.0  # vuela en línea recta hasta el punto apuntado (se restaura en _end_coin_push)
	coin.linear_velocity = dir * speed  # sin sumar tu velocidad: así la trayectoria pasa por la mira
	visual.rotation.y = atan2(-dir.x, -dir.z)
	rig.play_throw()
	return coin


## Suelta una moneda a los pies (null si no llevas la bolsa).
func drop_coin(offset := Vector3.ZERO) -> RigidBody3D:
	if not _check_coins():
		return null
	return _spawn_coin(global_position + Vector3(0, 0.3, 0) + offset)


func _check_coins() -> bool:
	if dead:
		return false
	if not has_bag():
		notice.emit("Sin bolsa no tenés monedas (F para recogerla)")
		return false
	if coins_held <= 0:
		notice.emit("Sin monedas (pasá por encima de las del suelo para recogerlas)")
		return false
	return true


func _spawn_coin(pos: Vector3) -> RigidBody3D:
	coins_held = maxi(coins_held - 1, 0)
	if net_peer_id != 0:
		# En red solo el servidor crea monedas (NetArena las numera, limita y manda a los clientes).
		var net_coin: Coin = get_parent().server_spawn_coin(pos)
		net_coin.shooter = self
		net_coin.add_collision_exception_with(self)
		return net_coin
	var coins := get_tree().get_nodes_in_group(&"coin")
	if coins.size() >= max_coins_in_world:
		coins[0].queue_free()
	var coin := Props.coin()
	coin.shooter = self
	get_tree().current_scene.add_child(coin)
	coin.global_position = pos
	coin.add_collision_exception_with(self)
	return coin


func respawn() -> void:
	if net_peer_id != 0 and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_start_protection()
		_refill_net_metals()
	if _hanging or _climb_t >= 0.0:
		_release_ledge(Vector3.ZERO)
	global_position = spawn_point
	velocity = Vector3.ZERO
	_since_damage = 99.0
	stamina = max_stamina
	_exhausted = false


## Servidor: unos segundos sin poder ser dañado tras reaparecer o al empezar una ronda.
func _start_protection() -> void:
	net_protected = true
	_protected_until_ms = Time.get_ticks_msec() + NET_PROTECTION_MS


# ---------------------------------------------------------------- Monedero

## Alt+E: con acero encendido lanza una ronda de monedas en todas las direcciones; si no, con hierro
## encendido atrae las monedas cercanas (ver start_gather).
func coin_alt_action() -> void:
	if allomancy.strength(&"steel") > 0.0:
		fire_coin_ring()
	else:
		start_gather()


## Lanza COIN_RING_COUNT monedas a ras del pecho, repartidas a partes iguales alrededor tuyo (como las
## porciones de una pizza), la primera hacia donde mira el cuerpo. Gastan una moneda cada una.
func fire_coin_ring() -> void:
	if dead or not _check_coins():
		return
	var now := Time.get_ticks_msec()
	if now < _net_coin_ready_ms:
		return
	_net_coin_ready_ms = now + COIN_RING_COOLDOWN_MS
	var front := -visual.global_basis.z
	front.y = 0.0
	front = front.normalized()
	var speed := COIN_HAND_SPEED + COIN_STEEL_SPEED * allomancy.strength(&"steel")
	var start := chest_position()
	for i in mini(COIN_RING_COUNT, coins_held):
		var dir := front.rotated(Vector3.UP, TAU * i / COIN_RING_COUNT)
		var coin := _spawn_coin(start + dir * 0.5)
		coin.gravity_scale = 0.25  # casi a ras: cae despacio, no queda flotando
		coin.linear_velocity = dir * speed
	rig.play_throw()


## Alt+E (con hierro encendido): todas las monedas sueltas cercanas vuelan hacia ti y se guardan al tocarte.
func start_gather() -> void:
	if dead or not has_bag():
		return
	if allomancy.strength(&"iron") <= 0.0:
		notice.emit("Alt+E: con acero (1) lanza monedas en círculo, con hierro (2) las atrae")
		return
	_stop_gather()
	var chest := chest_position()
	for n in get_tree().get_nodes_in_group(&"coin"):
		var coin := n as Coin
		if coin != null and not coin.puppet and coin != steel_iron.auto_push \
				and coin.global_position.distance_to(chest) <= GATHER_RADIUS:
			_gathering.append(coin)
	_gather_until_ms = Time.get_ticks_msec() + GATHER_MS
	if _gathering.is_empty():
		notice.emit("No hay monedas cerca")


## Mantiene las monedas atraídas yendo hacia ti (sin gravedad); termina al pasar GATHER_MS.
func _update_gather() -> void:
	if _gathering.is_empty():
		return
	if Time.get_ticks_msec() > _gather_until_ms:
		_stop_gather()
		return
	var chest := chest_position()
	var alive: Array[Coin] = []
	for coin in _gathering:
		if not is_instance_valid(coin):
			continue
		alive.append(coin)
		coin.set_deferred(&"freeze", false)
		coin.gravity_scale = 0.0
		coin.linear_velocity = (chest - coin.global_position).normalized() * GATHER_SPEED
	_gathering = alive


func _stop_gather() -> void:
	for coin in _gathering:
		if is_instance_valid(coin):
			coin.gravity_scale = 1.0
	_gathering.clear()

## Recoge las monedas quietas del suelo que tengas bajo los pies (solo con la bolsa puesta).
## No recoge las que estás usando (agarradas con acero/hierro) ni las que acabas de soltar o lanzar y
## todavía no se alejaron de ti (ver Coin.pickable): así la moneda que dejas bajo los pies para
## impulsarte no te la guardas de nuevo, y al caer de vuelta sí.
## Las que traes con hierro (E sobre una moneda) o con Alt+E (ver start_gather) se guardan en cuanto te
## tocan (a menos de COIN_CATCH_DIST del pecho), aunque vayan rápido.
func _collect_coins() -> void:
	if dead or coins_held >= COIN_MAX or not has_bag():
		_stop_gather()
		return
	_update_gather()
	var chest := chest_position()
	for n in get_tree().get_nodes_in_group(&"coin"):
		var coin := n as Coin
		if coin == null or coin.puppet or coin == steel_iron.auto_push:
			continue
		if coin == steel_iron.pull_grip.target or _gathering.has(coin):
			if coin.global_position.distance_to(chest) > COIN_CATCH_DIST:
				continue
		else:
			if not coin.pickable(self) or coin == steel_iron.push_grip.target:
				continue
			var rel := coin.global_position - global_position
			if Vector2(rel.x, rel.z).length() > COIN_PICKUP_RADIUS or rel.y > 1.0 or rel.y < -0.4:
				continue
		coins_held += 1
		Fx.sparks(get_tree().current_scene, coin.global_position, Color(1.0, 0.8, 0.4))
		if net_peer_id != 0:
			get_parent().server_take_coin(coin)
		else:
			coin.queue_free()
		if coins_held >= COIN_MAX:
			return
