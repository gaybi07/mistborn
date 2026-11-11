class_name Player
extends CharacterBody3D
## Nacido de la bruma: movimiento en tercera persona, cámara y controles de alomancia.
## Las habilidades viven en nodos hijos (SteelIron, Atium, TinSenses); el peltre se aplica aquí.

@export var walk_speed := 6.0
@export var jump_velocity := 5.0
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
@export var roll_speed := 7.5
@export var roll_duration := 0.75
@export var air_dash_speed := 8.0

signal damaged(amount: float, impact_speed: float)
signal died
## Esquivaste un golpe gracias al atium (el atacante no lo quemaba).
signal dodged
## Aviso corto para el HUD ("sin monedas", "nivel 5"...).
signal notice(text: String)

## Armas: daño y empuje base (el peltre los multiplica) y alcance.
## combo: golpes encadenados [duración, × daño, × empuje]; el último es el remate (con estocada).
const WEAPONS := [
	{"name": "Puños", "damage": 8.0, "knockback": 4.0, "reach": 1.6,
		"combo": [[0.45, 1.0, 1.0], [0.5, 1.1, 1.2], [0.55, 1.2, 1.2], [0.7, 1.7, 2.5]]},
	# Dagas: cuatro golpes distintos; el cuarto, un tajo doble que empuja lejos.
	{"name": "Dagas de obsidiana", "damage": 14.0, "knockback": 3.0, "reach": 1.8,
		"combo": [[0.42, 1.0, 1.0], [0.46, 1.05, 1.0], [0.5, 1.15, 1.2], [0.78, 2.1, 3.2]]},
	{"name": "Espada", "damage": 30.0, "knockback": 7.0, "reach": 2.4,
		"combo": [[0.55, 1.0, 1.0], [0.6, 1.1, 1.2], [0.6, 1.2, 1.3], [0.7, 1.4, 1.6], [0.85, 1.8, 3.0]]},
]
## Espada con escudo: su propio combo; el remate es un golpe de escudo que empuja lejos.
## Los golpes del combo antes del remate casi no empujan: el rival queda a tiro del siguiente. El remate sí lo tira.
const COMBO_KNOCK := 0.25
const SHIELD_COMBO := [[0.5, 1.0, 1.0], [0.55, 1.1, 1.2], [0.8, 1.5, 3.5]]
## Al golpear en el suelo el cuerpo frena a esta aceleración (m/s²): de correr a parado en ~0,2 s.
const ATTACK_BRAKE := 28.0
## Tiempo extra tras un golpe para encadenar el siguiente del combo.
const COMBO_WINDOW := 0.45
## Segundos sin pelear tras los que se considera que el combate terminó.
const COMBAT_TIMEOUT := 6.0
## Segundos con el arma recién sacada en guardia antes de relajarse (si no peleás).
const RELAX_AFTER := 6.0

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
signal character_changed

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
var _step_acc := 0.0
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
## Imán de monedas: radio (m) en el que se atraen las monedas, velocidad a la que vuelan hacia ti y tiempo máximo (ms).
## Ráfaga de monedas: la pausa (ms) hasta poder repetirla.
const COIN_BURST_COOLDOWN_MS := 500
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
## Servidor: nivel de cada metal que mandó el cliente de este jugador (ver _net_progress); acero y hierro, 1.
var net_levels: Dictionary = {&"steel": 1, &"iron": 1}
var _sent_progress_rev := -1
## Cámara: el hombro de la cámara al lado; al mirar hacia abajo pasa al eje del personaje (apunta bajo tus pies).
const CAMERA_SHOULDER := 0.55
## Cámara: el spring_arm (una esfera, choca con el mundo y con la gente) solo mide cuánto espacio hay;
## la cámara va en _boom. Si algo se mete entre vos y la cámara se acerca al instante (nunca ve a
## través de una pared o un cuerpo) y al despejarse vuelve despacio (CAMERA_RETURN m/s).
const CAMERA_RETURN := 2.5
## Si la cámara queda tapada y no movés el ratón hace CAMERA_ASSIST_IDLE_MS, gira sola hacia el lado
## más libre (hasta CAMERA_ASSIST_SPEED rad/s) para que no te pierdas de vista.
const CAMERA_ASSIST_IDLE_MS := 600
const CAMERA_ASSIST_SPEED := 0.9
var _boom: Node3D
var _cam_len := 3.8
var _look_ms := 0
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
var _shake := 0.0  # "trauma" de 0 a 1: la cámara tiembla con trauma² y ruido suave
var _shake_noise := FastNoiseLite.new()
var _since_damage := 99.0
## Tras un golpe, un instante sin recibir otro (que dos golpes juntos no se lleven media vida).
const IFRAMES := 0.4
## Defensa (Ctrl). Mantener: guardia arriba; los golpes cuerpo a cuerpo de frente (BLOCK_ARC rad a cada
## lado) hacen BLOCK_DAMAGE del daño y gastan BLOCK_STAMINA de resistencia por punto de daño; sin
## resistencia la guardia se rompe (te tambaleas y el golpe entra entero). Pulsar como mucho
## PARRY_WINDOW_MS antes del golpe: parry, sin daño, y el atacante queda aturdido PARRY_STUN s (el próximo
## golpe que le des es crítico). Mientras bloqueas vas a BLOCK_SPEED de tu velocidad y no atacas.
const BLOCK_ARC := 1.2
const BLOCK_DAMAGE := 0.2
const BLOCK_STAMINA := 1.2
const BLOCK_SPEED := 0.3  # 1,8 m/s: lo más que da la caminata sin que los pies patinen
## Agachado (Alt alterna): a esta fracción de tu velocidad, a la que pisa crouch_walk.
const CROUCH_SPEED := 0.2
## Bloqueando con escudo.
const SHIELD_BLOCK_ARC := 1.8
const SHIELD_BLOCK_DAMAGE := 0.05
const SHIELD_BLOCK_STAMINA := 0.7
const PARRY_WINDOW_MS := 200
const PARRY_STUN := 1.5
var blocking := false
var _block_pressed_ms := -100000
var _guard_broken := false
## Esquive (Shift + A/D): paso al costado con la animación (el cuerpo lo mueve ella); la voltereta y el
## esquive te hacen intocable los primeros EVADE_TIME s.
const DODGE_TIME := 0.55
const EVADE_TIME := 0.35
var _dodge_t := 0.0
var _evade_t := 0.0
var _attack_cd := 0.0
var _attack_side := 1
var _combo := 0
var _combo_window := 0.0
## Pulsaste atacar justo antes de poder: el golpe sale en cuanto se pueda.
var _attack_buffered := false
## Hasta que pega el golpe o sale el poder no se empieza otra acción (las de escape sí la cortan: _cancel_action).
var _commit_t := 0.0
var _queued_skill := &""
## Sube al empezar o cortar una acción: lo que tenía que pasar en el impacto ve que ya no vale.
var _action_id := 0
var _combat_ms := -1000000
## Moneda que se empuja sola (clic derecho o salto de acero), y cómo estaba el acero antes.
var _coin_push_steel := Allomancy.State.OFF
## La moneda empujada es un disparo del clic derecho (no se frena a GUIDED_COIN_SPEED).
var _coin_shot := false
## Salto normal (sin peltre): altura y distancia que recorre, parado y corriendo a walk_speed (en medio,
## se interpola). Corriendo, el salto frena tu velocidad horizontal a la que hace falta para esa distancia,
## y en el aire WASD no te deja ir más rápido que eso.
const JUMP_HEIGHT_STAND := 1.0
const JUMP_DIST_STAND := 2.0
const JUMP_HEIGHT_RUN := 1.5
const JUMP_DIST_RUN := 3.0
## Segundo salto en el aire (Espacio dos veces, sin acero): una vez por salto. Sube AIR_JUMP_HEIGHT m más
## y conserva tu velocidad horizontal.
const AIR_JUMP_HEIGHT := 1.3
## Velocidad horizontal máxima que da el control en el aire tras un salto normal (INF: sin límite).
var _jump_hcap := INF
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
var zinc: ZincPowers
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
var _drawn_ms := 0  # cuándo sacaste el arma a mano (ver RELAX_AFTER)
var _fists_chosen := false
## Bolsa de monedas soltada en el suelo (null: la llevas encima).
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
	allomancy.can_burn = func(metal: StringName) -> bool: return metal_level(metal) > 0
	allomancy.metal_level = metal_level
	allomancy.blocked.connect(func(metal: StringName) -> void:
		notice.emit("%s bloqueado: gasta un punto en el árbol (K)" % Allomancy.METALS[metal]["label"]))
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
	zinc = ZincPowers.new()
	zinc.player = self
	add_child(zinc)
	_guide = JumpGuide.new()
	add_child(_guide)

	health = max_health
	stamina = max_stamina
	spawn_point = global_position
	_apply_equipment()
	rig.set_suit(Art.suit)
	Sfx.start()
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
	_body_col = col

	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	Art.load_suit()
	_add_rig()


## Ritmo del personaje elegido (ver Art.HEROES): Vin es más rápida, el terrisano más lento. También en los golpes.
var _base_walk_speed := 0.0
var _body_col: CollisionShape3D


func _pace() -> float:
	return float(Art.HEROES.get(Art.player_model, {}).get("pace", 1.0))


## Otro personaje (ver Art.HEROES): cambia el cuerpo y se conserva lo demás.
func change_character(who: String) -> void:
	Art.save_character(who)
	rig.queue_free()
	_add_rig()
	_apply_equipment()
	rig.set_suit(Art.suit)
	character_changed.emit()


## La cápsula a la medida del personaje elegido: con la de 1,8 m Vin (1,55 m) chocaba con lo que no tocaba.
func _fit_body() -> void:
	if _body_col == null:
		return
	var h: float = Art.HEROES.get(Art.player_model, {}).get("height", 1.8)
	var cap := _body_col.shape as CapsuleShape3D
	cap.radius = 0.3 if h < 1.7 else 0.35
	cap.height = clampf(h + 0.05, 1.5, 1.8)
	_body_col.position.y = cap.height * 0.5


func _add_rig() -> void:
	_fit_body()
	if _base_walk_speed == 0.0:
		_base_walk_speed = walk_speed
	walk_speed = _base_walk_speed * _pace()
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
	spring_arm.margin = 0.1
	var probe := SphereShape3D.new()
	probe.radius = 0.3
	spring_arm.shape = probe
	spring_arm.position = Vector3(CAMERA_SHOULDER, 0, 0)
	spring_arm.collision_mask = Props.LAYER_WORLD | Props.LAYER_PROPS  # paredes y también gente (monstruos)
	spring_arm.add_excluded_object(get_rid())
	pitch_pivot.add_child(spring_arm)
	_boom = Node3D.new()
	_boom.position = spring_arm.position
	pitch_pivot.add_child(_boom)
	camera = Camera3D.new()
	camera.fov = base_fov
	camera.far = 2500.0  # para ver los montes de ceniza en el horizonte
	camera.position.z = spring_arm.spring_length
	_boom.add_child(camera)
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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
		if event.shift_pressed:
			_debug_spawn_koloss()
		else:
			_debug_next_anim()
		return
	if event is InputEventKey and not event.echo and (not event.ctrl_pressed or not event.pressed) and _slot_key(event):
		return
	if _look(event):
		if event is InputEventMouseButton:
			return  # el clic que recaptura el ratón no ataca ni lanza
	elif event is InputEventKey and not event.echo:
		var key := event as InputEventKey
		var group := Allomancy.metals_for_key(key.physical_keycode)
		if not group.is_empty() and (not key.ctrl_pressed or not key.pressed):  # Ctrl+F1..F5 son de depuración (escenas, clima)
			if key.pressed:
				_metal_key_down(key.physical_keycode, group)
			else:
				_metal_key_up(key.physical_keycode)

	if event.is_action_pressed(&"stop_burning"):
		allomancy.stop_all()
	elif event.is_action_pressed(&"coin_shot"):
		_start_coin_shot()
	elif event.is_action_released(&"coin_shot"):
		_end_coin_push()
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
		_drawn_ms = Time.get_ticks_msec()
		rig.set_weapon(weapon)
	elif event.is_action_pressed(&"interact") and interactable and interactable.prompt != "":
		interactable.use()
	elif event.is_action_pressed(&"attack"):
		attack()
	elif event.is_action_pressed(&"roll"):
		roll()
	elif event.is_action_pressed(&"hood") and rig.cloak:
		rig.cloak.set_hood(not rig.cloak.hood_up)
	elif event.is_action_pressed(&"crouch"):
		rig.crouched = not rig.crouched


## Mover la cámara con el ratón o recapturarlo con un clic. Devuelve true si el evento era de ratón.
func _look(event: InputEvent) -> bool:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_look_ms = Time.get_ticks_msec()
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
	if event is InputEventKey and not event.echo and (not event.ctrl_pressed or not event.pressed) and _net_slot_key(event):
		return
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


## Nivel de un metal para este jugador: el de su propio árbol si lo manejas tú; en el servidor, el que mandó
## ese cliente (ver _net_progress), ya acotado a lo que sus puntos pagan.
func metal_level(metal: StringName) -> int:
	if net_peer_id != 0 and not is_local_player():
		return int(net_levels.get(metal, 0))
	return Progression.metal_level(metal)


## Local: con un punto en el poder. Remoto (servidor): todavía por nivel de metal, hasta L19.
func skill_unlocked(id: StringName) -> bool:
	if net_peer_id != 0 and not is_local_player():
		var s := SkillTree.find(id)
		return not s.is_empty() and metal_level(s["metal"]) >= int(s["legacy_level"])
	return SkillTree.is_unlocked(id)


## Nivel de un poder en la escala vieja de 1-20 que reciben las fórmulas (SkillTree.equiv_level). Remoto: el nivel
## de su metal, como antes, hasta L19.
func power_level(id: StringName) -> int:
	if net_peer_id != 0 and not is_local_player():
		return metal_level(SkillTree.find(id).get("metal", &""))
	return SkillTree.equiv_level(id, Progression.skill_level(id))


## Cliente: tecla de una ranura. Manda al servidor la habilidad (y el metal que miras si es un tirón o empuje).
func _net_slot_key(key: InputEventKey) -> bool:
	var slot := Progression.slot_for_key(key.physical_keycode)
	if slot < 0:
		return false
	var skill := Progression.slot_skills[slot]
	var id := 0
	var aim := Vector3.ZERO
	if key.pressed:
		if ui_open or dead:
			return false
		if key.physical_keycode == KEY_E and interactable != null and interactable.prompt != "":
			return false
		if skill == &"iron_pull" or skill == &"steel_light_push":
			id = get_parent().target_id(steel_iron.click_target(skill == &"steel_light_push", chest_position()))
		elif skill == &"steel_coin_burst" or skill == &"iron_coin_magnet" or skill == &"steel_spear":
			aim = _burst_aim(Vector3.INF)
	if multiplayer.is_server():
		_net_skill_run(skill, key.pressed, id, aim)
	else:
		_net_skill.rpc_id(1, skill, key.pressed, id, aim)
	return true


@rpc("any_peer", "call_remote", "reliable")
func _net_skill(skill: StringName, pressed: bool, target_id: int, aim: Vector3) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == net_peer_id:
		_net_skill_run(skill, pressed, target_id, aim)


## Servidor: activa o termina una habilidad de ranura si ese jugador la tiene desbloqueada.
func _net_skill_run(skill: StringName, pressed: bool, target_id: int, aim := Vector3.INF) -> void:
	if dead or not SkillTree.is_assignable(skill) or not skill_unlocked(skill):
		if not pressed:
			_net_release_skill(skill)
		return
	match skill:
		&"iron_pull", &"steel_light_push":
			var is_push := skill == &"steel_light_push"
			var metal: StringName = &"steel" if is_push else &"iron"
			if pressed:
				_skill_burn_on(metal)
				steel_iron.net_grip_request(is_push, true, target_id)
			else:
				_net_release_skill(skill)
		&"steel_coin_burst":
			if pressed:
				_tap_skill(&"steel", fire_coin_burst.bind(aim), SKILL_TAP_BURN_MS)
		&"steel_spear":
			if pressed:
				_tap_skill(&"steel", fire_steel_spear.bind(aim), SKILL_TAP_BURN_MS)
		&"steel_magnetic_field":
			if pressed:
				_tap_skill(&"steel", activate_magnetic_field, SKILL_TAP_BURN_MS)
		&"iron_coin_magnet":
			if pressed:
				_tap_skill(&"iron", start_gather.bind(aim), GATHER_MS + 200)


func _net_release_skill(skill: StringName) -> void:
	if skill == &"iron_pull" or skill == &"steel_light_push":
		var is_push := skill == &"steel_light_push"
		steel_iron.net_grip_request(is_push, false, 0)
		_skill_burn_off(&"steel" if is_push else &"iron")


## Cliente: manda su progreso (nivel y nivel de cada metal) para que el servidor sepa qué puede usar.
func _send_progress() -> void:
	_sent_progress_rev = Progression.revision
	var levels := PackedInt32Array()
	for m: StringName in Allomancy.METALS:
		levels.append(Progression.metal_level(m))
	_net_progress.rpc_id(1, Progression.level, levels)


## Servidor: guarda el progreso de ese cliente, acotado: sin más niveles de los que pagan sus puntos
## (si se pasa, queda con los niveles gratis).
@rpc("any_peer", "call_remote", "reliable")
func _net_progress(level: int, levels: PackedInt32Array) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != net_peer_id:
		return
	var metals := Allomancy.METALS.keys()
	if levels.size() != metals.size():
		return
	var spent := 0
	var checked := {}
	for i in metals.size():
		var m: StringName = metals[i]
		var free := 1 if m in Progression.FREE_METALS else 0
		var lvl := clampi(levels[i], free, Progression.metal_cap(m))
		checked[m] = lvl
		spent += (lvl - free) * Progression.point_cost(m)
	if spent > clampi(level, 1, Progression.MAX_LEVEL) - 1:
		for m: StringName in metals:
			checked[m] = 1 if m in Progression.FREE_METALS else 0
	net_levels = checked
	for m: StringName in metals:
		if checked[m] <= 0 and allomancy.is_burning(m):
			allomancy.set_state(m, Allomancy.State.OFF)


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
		var pewter := pewter_for(&"pewter_strike")
		var damage: float = NET_ATTACK["damage"] * (1.0 + 0.75 * pewter) * (0.6 if _pewter_drag > 0.0 else 1.0)
		var knockback: float = NET_ATTACK["knockback"] * (1.0 + pewter)
		target._receive_net_hit(to.normalized() * knockback, damage, net_peer_id)


## Servidor: aplica un golpe confirmado.
func _receive_net_hit(impulse: Vector3, damage: float, attacker_id: int) -> void:
	net_last_attacker = attacker_id
	# El peltre endurece el cuerpo: menos empujón y menos daño (igual que en take_hit).
	var pewter := pewter_for(&"pewter_endurance")
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
	if is_local_player() and not multiplayer.is_server():
		Progression.load_progress()
		_send_progress()
	if multiplayer.is_server():
		_start_protection()  # también al entrar al duelo


## Cliente: manda al servidor sus teclas, hacia dónde mira y el giro de la cámara.
func _send_net_input() -> void:
	if not is_local_player():
		return
	if Progression.revision != _sent_progress_rev:
		_send_progress()  # subiste un metal o reasignaste puntos
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
	if event.ctrl_pressed and event.pressed:
		return false
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
		allomancy.reserve[m] = allomancy.max_reserve(m)
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
		_metal_gesture(group)
		return
	_last_tap_key = key
	_last_tap_ms = now
	var any_on := group.any(func(m: StringName) -> bool: return allomancy.is_burning(m))
	for m in group:
		if m == &"pewter" and _pewter_drag > 0.0:
			continue  # con arrastre de peltre no puedes volver a quemarlo
		allomancy.set_state(m, Allomancy.State.OFF if any_on else Allomancy.State.BURN)
	if not any_on:
		_metal_gesture(group)


## Acero y hierro no: su gesto es el del poder que uses. Sin aprender o sin reserva tampoco: no se encendió.
func _metal_gesture(group: Array[StringName]) -> void:
	if group.any(func(m: StringName) -> bool: return m != &"steel" and m != &"iron" and allomancy.is_burning(m)):
		rig.burn_gesture(&"pewter" in group)


## Clic sobre el icono de un metal en el HUD: igual que apretar o soltar su tecla (doble clic y mantener: avivar).
func click_metal(metal: StringName, pressed: bool) -> void:
	if dead:
		return
	var code: Key = Allomancy.METALS[metal]["key"]
	var group: Array[StringName] = [metal]
	if net_peer_id == 0:
		if pressed:
			_metal_key_down(code, group)
		else:
			_metal_key_up(code)
	elif NET_METALS.has(metal):
		if multiplayer.is_server():
			_net_metal_key(code, pressed)
		else:
			_net_metal.rpc_id(1, code, pressed)


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
	if dead or allomancy.is_burning(&"copper") or is_clear_minded():
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
## Fuerza del peltre para el efecto de una habilidad: si todavía no la tienes (sin puntos en el poder), 0.
func pewter_for(skill: StringName) -> float:
	var p := allomancy.strength(&"pewter")
	if p <= 0.0 or skill_unlocked(skill):
		return p
	return 0.0


func pewter_drag() -> float:
	return maxf(_pewter_drag, 0.0)


func is_exhausted() -> bool:
	return _exhausted


## Peltre: gastas menos (×0,67 quemando, ×0,5 avivando) y recuperas más rápido; con arrastre, al revés.
func _stamina_cost_mult() -> float:
	return (1.0 / (1.0 + 0.5 * pewter_for(&"pewter_endurance"))) * (1.5 if _pewter_drag > 0.0 else 1.0)


## Quieto en el suelo recuperas; caminando gastas un poco; en el aire ni una cosa ni la otra
## (volar con metales no cansa). Al quedarte en 0 estás sin aliento hasta recuperar EXHAUSTED_RECOVER.
func _update_stamina(rd: float) -> void:
	if dead or not is_on_floor():
		return
	var pewter := pewter_for(&"pewter_endurance")
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


## Moneda empujada sola (ver _assist_coin_push): no sale volando más rápido que GUIDED_COIN_SPEED y se clava al tocar
## el suelo.
const GUIDED_COIN_SPEED := 20.0
## Cuánto detrás de ti (en m) cae la moneda del salto de acero (de donde te empujás).
const STEEL_JUMP_BACK := 0.4
## Salto de acero (WASD + Espacio con acero): un arco fijo, como una parábola, sin importar cuánto mantengas Espacio.
## Antes era un empuje continuo mientras mantenías la tecla: un toque daba 2 m y medio segundo, más de 40 m.
const STEEL_LEAP_DIST := 10.0  # m de avance en terreno plano
const STEEL_LEAP_HEIGHT := 3.5  # m de altura máxima
const STEEL_LEAP_UP_HEIGHT := 5.0  # m del salto recto hacia arriba (doble Espacio sin dirección)
const STEEL_LEAP_COOLDOWN := 4.0  # s
var _leap_ready_ms := 0


## Clic derecho: lanza una moneda a plena fuerza hacia donde apuntas y la empuja con acero mientras
## mantengas el clic. Sirve para pegar con la moneda o, apuntando abajo, para frenar una caída.
## Punto del mundo al que apunta la moneda de combate y velocidad a la que va hacia él (ver _assist_coin_push).
var _shot_point := Vector3.ZERO
var _push_slide := false  # un empuje te arrastra por el piso (ver rig.pushed_on_floor)
var _shot_speed := 0.0


func _start_coin_shot(aim_target := Vector3.INF, aim_dir := Vector3.INF) -> void:
	if dead or _coin_windup:
		return
	if not skill_unlocked(&"steel_combat_coin"):
		notice.emit("Moneda de combate bloqueada: gasta un punto en acero (K)")
		return
	if not _check_coins():
		return
	# Primero el gesto; la moneda sale cuando el brazo la tira (ver _release_coin_shot).
	var look := (aim_dir if aim_dir.is_finite() else aim_direction())
	visual.rotation.y = atan2(-look.x, -look.z)
	rig.play_skill("coin_flick", 0.7, COIN_FLICK_FROM)
	_coin_windup = true
	_coin_tap_ms = -1
	_coin_press_ms = Time.get_ticks_msec()
	get_tree().create_timer(rig.impact_delay(), false, false, true).timeout.connect(_release_coin_shot.bind(aim_target, aim_dir))


## Mientras el brazo arma el tiro: la moneda todavía no salió.
var _coin_windup := false
var _coin_press_ms := 0
## Si soltaste el clic antes del tiro: cuánto lo mantuviste (ms); -1 si sigue apretado.
var _coin_tap_ms := -1


func _release_coin_shot(aim_target: Vector3, aim_dir: Vector3) -> void:
	_coin_windup = false
	if dead:
		return
	var coin := throw_coin(aim_target, aim_dir)
	if coin == null:
		return
	_coin_shot = true
	_engage_coin_push(coin)
	if _coin_tap_ms >= 0:
		# Clic corto: se empuja solo lo que duró el clic, como si hubiera salido al apretar.
		get_tree().create_timer(_coin_tap_ms / 1000.0, false, false, true).timeout.connect(func() -> void:
			if steel_iron.auto_push == coin:
				_end_coin_push())


# ---------------------------------------------------------------- Ranuras de habilidades

## Cuánto queda encendido un metal que una habilidad de un toque (anillo, imán) encendió por su cuenta.
const SKILL_TAP_BURN_MS := 1200
## Metales que encendió una habilidad (no el jugador): se apagan solos al terminar.
var _skill_started := {}
## Cuál fue el último apagado pedido de cada metal: solo ese lo apaga (si después otro poder lo volvió a pedir, espera).
var _skill_off_turn := {}


## Tecla de una ranura: pulsarla activa su habilidad y soltarla la termina. Devuelve true si era de una ranura.
## Donde hay algo que usar con E (puerta, armario), E abre y la ranura no se activa.
func _slot_key(key: InputEventKey) -> bool:
	var slot := Progression.slot_for_key(key.physical_keycode)
	if slot < 0:
		return false
	var skill := Progression.slot_skills[slot]
	if not key.pressed:
		_skill_release(skill)
		return true
	if ui_open or dead:
		return false
	if key.physical_keycode == KEY_E and interactable != null and interactable.prompt != "":
		return false
	_skill_press(skill)
	if _aim_skill == skill:
		_aim_key = key.physical_keycode
	return true


## Poderes que se apuntan: mantenés la tecla y ves la zona donde va a pegar (Telegraph, en azul: es tuya); al soltar,
## sale. [forma, alcance (m), ancho (franja) o medio ángulo (cono)].
const AIMED := {
	&"steel_coin_burst": ["cone", 16.0, 0.0], &"steel_spear": ["strip", 30.0, 1.2], &"pewter_charge": ["strip", CHARGE_SPEED * CHARGE_TIME, 1.4],
	&"pewter_slam": ["disc", SkillTree.SLAM_RADIUS, 0.0], &"iron_mass_yank": ["sphere", SkillTree.YANK_RADIUS, 0.0],
	&"steel_magnetic_field": ["sphere", SkillTree.FIELD_RADIUS, 0.0],
}
var _aim_skill := &""
var _aim_preview: Telegraph
var _aim_firing := false
## Tecla con la que se está apuntando: si se suelta fuera del juego (Esc, alt+tab) no llega el evento, así que se revisa a mano.
var _aim_key: Key = KEY_NONE
## Poderes que salen hacia donde apunta la mira en 3D (también arriba o abajo): su zona se inclina igual. El resto va a ras del piso.
const AIM_3D: Array[StringName] = [&"steel_coin_burst", &"steel_spear"]
## Alto (m) sobre los pies del humo de los poderes que van por el piso (la embestida y los aros alrededor tuyo).
const AIM_GROUND_SMOKE := 0.35


func _skill_press(skill: StringName) -> void:
	if AIMED.has(skill) and not _aim_firing and skill_unlocked(skill):
		if _aim_skill == &"":
			_start_aim(skill)
		return  # sale al soltar (_skill_release)
	if _commit_t > 0.0 and not skill in [&"iron_pull", &"steel_light_push"]:
		_queued_skill = skill
		return
	match skill:
		&"iron_pull":
			_grip_skill(steel_iron.pull_grip, &"iron", true)
		&"steel_light_push":
			_grip_skill(steel_iron.push_grip, &"steel", true)
		&"steel_coin_burst":
			_tap_skill(&"steel", fire_coin_burst, SKILL_TAP_BURN_MS)
		&"steel_coin_shield":
			_tap_skill(&"steel", toggle_coin_shield, SKILL_TAP_BURN_MS)
		&"steel_spear":
			_tap_skill(&"steel", fire_steel_spear, SKILL_TAP_BURN_MS)
		&"steel_magnetic_field":
			_tap_skill(&"steel", activate_magnetic_field, SKILL_TAP_BURN_MS)
		&"iron_coin_magnet":
			_tap_skill(&"iron", start_gather, GATHER_MS + 200)
		&"iron_drag":
			_tap_skill(&"iron", start_iron_drag, SKILL_TAP_BURN_MS)
		&"iron_hook":
			_tap_skill(&"iron", start_iron_hook, SKILL_TAP_BURN_MS)
		&"iron_disarm":
			_tap_skill(&"iron", start_disarm, SKILL_TAP_BURN_MS)
		&"iron_mass_yank":
			_tap_skill(&"iron", start_mass_yank, SKILL_TAP_BURN_MS)
		&"pewter_charge":
			_tap_skill(&"pewter", start_charge, SKILL_TAP_BURN_MS)
		&"pewter_slam":
			_tap_skill(&"pewter", start_slam, SKILL_TAP_BURN_MS)
		&"pewter_fury":
			start_fury()
		&"tin_focus":
			_timed_skill(&"tin", start_focus, int(SkillTree.FOCUS_TIME * 1000.0))
		&"tin_mark":
			_timed_skill(&"tin", start_mark, int(SkillTree.MARK_TIME * 1000.0))
		&"tin_clear_mind":
			_timed_skill(&"tin", start_clear_mind, int(SkillTree.CLEAR_TIME * 1000.0))
		&"tin_extreme":
			_timed_skill(&"tin", start_extreme, int(SkillTree.EXTREME_TIME * 1000.0))
		&"zinc_fury", &"zinc_panic", &"zinc_greed", &"zinc_tame", &"zinc_storm":
			_timed_skill(&"zinc", zinc.use.bind(skill), SKILL_TAP_BURN_MS)


func _skill_release(skill: StringName) -> void:
	if skill == _aim_skill:
		_end_aim()
		_aim_firing = true
		_skill_press(skill)
		_aim_firing = false
		return
	match skill:
		&"iron_pull":
			_grip_skill(steel_iron.pull_grip, &"iron", false)
		&"steel_light_push":
			_grip_skill(steel_iron.push_grip, &"steel", false)


func _start_aim(skill: StringName) -> void:
	_aim_skill = skill
	var spec: Array = AIMED[skill]
	var scene := get_tree().current_scene
	# Todas de humo, como la lanza: no se llenan (eso es de los avisos de daño), solo muestran por dónde va el poder. Del
	# color del metal del poder, el mismo que en el HUD.
	var tint: Color = Allomancy.METALS[SkillTree.find(skill)["metal"]]["color"]
	match spec[0]:
		"cone":
			# Un rayo de humo por moneda, en las mismas direcciones que _release_burst (sin contar si te alcanzan las monedas).
			var level := power_level(&"steel_coin_burst")
			_aim_preview = Telegraph.smoke_rays(scene, 1e6, tint, SkillTree.burst_dirs(level, SkillTree.fan_count(level, SkillTree.BURST_MIN_LEVEL)))
		"strip":
			# El ancho de la cinta (~0,9 m) se lleva al de la franja; por el piso no hay cuerpo que tape el comienzo.
			var on_ground := not skill in AIM_3D
			_aim_preview = Telegraph.smoke_path(scene, 1e6, tint, spec[2] / 0.9 if on_ground else 1.0, 0.5 if on_ground else 2.5)
		"sphere":
			_aim_preview = Telegraph.smoke_sphere(scene, spec[1], 1e6, tint)
		_:
			_aim_preview = Telegraph.smoke_ring(scene, spec[1], 1e6, tint)
	_aim_to_view()


func _end_aim() -> void:
	_aim_skill = &""
	_aim_key = KEY_NONE
	if is_instance_valid(_aim_preview):
		_aim_preview.queue_free()
	_aim_preview = null


## Apuntando: la zona sigue la mira (los círculos van alrededor tuyo).
func _update_aim() -> void:
	if _aim_skill == &"" or not is_instance_valid(_aim_preview):
		return
	if dead or (_aim_key != KEY_NONE and not Input.is_physical_key_pressed(_aim_key)):
		_end_aim()  # la soltaste fuera del juego: se cancela sin lanzar
		return
	_aim_to_view()


## Pone el humo donde irá el poder. La lanza y la ráfaga van del pecho al punto bajo la mira (también arriba o abajo); la
## embestida, por el piso hacia donde mira la cámara; el aro del martillazo, alrededor de los pies; las esferas, en el
## mismo centro desde el que el poder mide la distancia (el campo desde el pecho, la atracción desde los pies).
func _aim_to_view() -> void:
	if _aim_skill == &"" or not is_instance_valid(_aim_preview):
		return
	var spec: Array = AIMED[_aim_skill]
	var feet := global_position + Vector3.UP * AIM_GROUND_SMOKE
	if _aim_skill in AIM_3D:
		# El alcance se cuenta desde el pecho, no desde la cámara.
		var boom := (chest_position() - camera.global_position).dot(aim_direction())
		_aim_preview.aim_path(chest_position(), aim_point(spec[1] + maxf(boom, 0.0)))
	elif spec[0] == "disc":
		_aim_preview.global_position = feet
	elif spec[0] == "sphere":
		_aim_preview.global_position = chest_position() if _aim_skill == &"steel_magnetic_field" else global_position
	else:
		_aim_preview.aim_path(feet, feet + _aim_flat() * spec[1])


func _aim_flat() -> Vector3:
	var dir := aim_direction()
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.1 else -visual.global_basis.z


## Habilidad sostenida (tirón, empuje): enciende su metal mientras mantienes la tecla y suelta al terminar.
func _grip_skill(g: SteelIron.Grip, metal: StringName, pressed: bool) -> void:
	if pressed:
		_skill_burn_on(metal)
		g.input_held = true
		g.input_just = true
	else:
		g.input_held = false
		_skill_burn_off(metal)


## Habilidad de un toque (anillo de monedas, imán): enciende su metal, actúa y lo apaga un momento después.
func _tap_skill(metal: StringName, action: Callable, burn_ms: int) -> void:
	_skill_burn_on(metal)
	action.call()
	_skill_burn_off_in(metal, burn_ms)


## Habilidad con duración (Foco, Marca, Mente despejada, Sentidos extremos): enciende su metal al empezar y lo apaga cuando
## termina. Si no llega a empezar (recarga, sin objetivo), no lo deja encendido. `action` devuelve si empezó.
func _timed_skill(metal: StringName, action: Callable, burn_ms: int) -> void:
	_skill_burn_on(metal)
	if not action.call():
		_skill_burn_off(metal)
		return
	_skill_burn_off_in(metal, burn_ms)


## Apaga el metal dentro de `burn_ms`, salvo que mientras tanto otro poder lo haya vuelto a pedir. Antes se comparaba la
## hora real con la del temporizador, que va con el tiempo del juego: si llegaba unos ms antes, el metal no se apagaba
## nunca.
func _skill_burn_off_in(metal: StringName, burn_ms: int) -> void:
	var turn := int(_skill_off_turn.get(metal, 0)) + 1
	_skill_off_turn[metal] = turn
	get_tree().create_timer(burn_ms / 1000.0).timeout.connect(func() -> void:
		if int(_skill_off_turn.get(metal, 0)) == turn:
			_skill_burn_off(metal))


func _skill_burn_on(metal: StringName) -> void:
	if allomancy.is_burning(metal):
		return
	allomancy.set_state(metal, Allomancy.State.BURN)
	if allomancy.is_burning(metal):
		_skill_started[metal] = true


## Apaga el metal solo si lo encendió una habilidad (uno encendido por el jugador no se toca).
func _skill_burn_off(metal: StringName) -> void:
	if not _skill_started.has(metal):
		return
	_skill_started.erase(metal)
	if metal == &"steel" and steel_iron.auto_push != null:
		# Empujando una moneda: el acero sigue hasta que termine el empuje, y ahí se apaga (no vuelve a quemar como al
		# empezar el empuje, que fue con el acero de este poder).
		_coin_push_steel = Allomancy.State.OFF
		return
	allomancy.set_state(metal, Allomancy.State.OFF)


## Enciende el acero si hace falta y deja la moneda como objetivo del empuje automático.
func _engage_coin_push(coin: RigidBody3D) -> void:
	_coin_push_steel = allomancy.state[&"steel"]
	# Cayendo rápido se aviva solo: quemando normal no alcanza para frenar una caída alta.
	if velocity.y < -8.0:
		allomancy.set_state(&"steel", Allomancy.State.FLARE)
	elif _coin_push_steel == Allomancy.State.OFF:
		allomancy.set_state(&"steel", Allomancy.State.BURN)
	steel_iron.auto_push = coin


## Salto de acero: deja caer una moneda detrás tuyo y te empujás de ella. Sale con la velocidad justa para un arco de
## STEEL_LEAP_DIST de largo y STEEL_LEAP_HEIGHT de alto, y desde ahí solo actúa la gravedad: una parábola. Sin
## dirección (doble Espacio), recto hacia arriba. En recarga, Espacio hace el salto común.
func _steel_leap(move: Vector2) -> void:
	var now := Time.get_ticks_msec()
	_leap_ready_ms = now + int(STEEL_LEAP_COOLDOWN * 1000.0)
	_net_coin_ready_ms = now + COIN_COOLDOWN_MS
	var dir := yaw_pivot.global_basis * Vector3(move.x, 0.0, move.y)
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.ZERO
	var coin := drop_coin(-dir * STEEL_JUMP_BACK)
	if coin != null:
		AirFx.push(get_tree().current_scene, coin.global_position, (global_position - coin.global_position).normalized(), AirFx.STEEL, 1.0)
	_cancel_action()
	var height := STEEL_LEAP_HEIGHT if dir != Vector3.ZERO else STEEL_LEAP_UP_HEIGHT
	var up := sqrt(2.0 * _gravity * height)
	var ahead := STEEL_LEAP_DIST / (2.0 * up / _gravity)  # el avance repartido en el tiempo que dura el arco
	velocity = dir * ahead + Vector3.UP * up
	_jump_hcap = INF  # el control en el aire no frena el arco
	_coin_flight = true
	Sfx.play("jump", global_position)


## Salto de acero: con el acero encendido y monedas en el monedero.
func _can_steel_jump() -> bool:
	return not dead and coins_held > 0 and allomancy.strength(&"steel") > 0.0 \
			and steel_iron.auto_push == null and Time.get_ticks_msec() >= _net_coin_ready_ms


func _end_coin_push() -> void:
	if _coin_windup:
		_coin_tap_ms = Time.get_ticks_msec() - _coin_press_ms
		return
	var was_shot := _coin_shot
	_coin_shot = false
	if steel_iron.auto_push == null:
		return
	var coin := steel_iron.auto_push as RigidBody3D
	if is_instance_valid(coin):
		coin.set_deferred(&"freeze", false)  # vuelve a ser una moneda suelta
		coin.gravity_scale = 1.0
		if was_shot and not coin.freeze:
			# Un clic corto: soltar el botón deja de empujar la moneda y casi se frena en el aire, en vez de seguir
			# volando a toda velocidad lejos de ti.
			coin.linear_velocity *= 0.2
	steel_iron.auto_push = null
	allomancy.set_state(&"steel", _coin_push_steel)


## Mientras se empuja la moneda de la G: que no se vaya volando (así el empuje no se pierde en
## el aire) y que se clave al tocar el suelo, como un ancla.
func _assist_coin_push() -> bool:
	var coin := steel_iron.auto_push as RigidBody3D
	if not is_instance_valid(coin):
		return false
	if _coin_shot and coin.global_position.distance_to(chest_position()) > ANCHOR_RANGE:
		_end_coin_push()  # la moneda de combate llegó a su alcance: se corta el enlace y volvés al reposo
		return false
	if not coin is Coin:
		return steel_iron.push_grip.active and steel_iron.push_grip.target == coin  # ya se empuja el objeto que chocó
	if not coin.freeze:
		if coin.get_contact_count() > 0:
			var object := _movable_contact(coin)
			if object != null:
				# Chocó con un objeto que se mueve: desde ahora se empuja ese objeto (y te empuja según lo que pese).
				coin.gravity_scale = 1.0
				steel_iron.auto_push = object
				return true
			if _coin_shot:
				var now := Time.get_ticks_msec()
				if now < _anchor_ready_ms or coin.global_position.distance_to(chest_position()) > ANCHOR_RANGE:
					_end_coin_push()  # sin recarga o demasiado lejos: la moneda solo cae
					return false
				_anchor_ready_ms = now + ANCHOR_COOLDOWN_MS
			coin.set_deferred(&"freeze", true)
			coin.linear_velocity = Vector3.ZERO
		elif coin.linear_velocity.length() > GUIDED_COIN_SPEED and not _coin_shot:
			coin.linear_velocity = coin.linear_velocity.normalized() * GUIDED_COIN_SPEED
		elif _coin_shot:
			# Moneda de combate: siempre apunta al punto que mirabas al lanzarla, aunque te muevas o el empuje
			# la desvíe; así es fácil acertar en movimiento.
			var to := _shot_point - coin.global_position
			if to.length() > 0.6:
				coin.linear_velocity = to.normalized() * _shot_speed
	return steel_iron.push_grip.active and steel_iron.push_grip.target == coin


## Tirón de hierro sobre una moneda u objeto suelto (ver SteelIron._steer_pulled): va hacia tu pecho curvando
## según te muevas, sin gravedad mientras mantienes la tecla. Una moneda no te hace daño y se guarda al
## llegar; un objeto cualquiera sí puede golpearte.
const PULL_COIN_SPEED := 22.0
const PULL_OBJECT_SPEED := 14.0
const PULL_COIN_ACCEL := 160.0
const PULL_OBJECT_ACCEL := 60.0


func steer_pulled(body: RigidBody3D, delta: float) -> void:
	var to := chest_position() - body.global_position
	var dist := to.length()
	if dist < 0.01:
		return
	var is_coin := body is Coin
	if is_coin:
		(body as Coin).pull_owner = self
		body.add_collision_exception_with(self)
	var speed := (PULL_COIN_SPEED if is_coin else PULL_OBJECT_SPEED) * clampf(dist / 2.0, 0.35, 1.0)
	# Cerca de ti iguala tu velocidad, para que te alcance aunque corras.
	var wanted := to / dist * speed + velocity * clampf(1.0 - dist / 4.0, 0.0, 1.0)
	body.gravity_scale = 0.0
	body.linear_velocity = body.linear_velocity.move_toward(wanted, (PULL_COIN_ACCEL if is_coin else PULL_OBJECT_ACCEL) * delta)


## Un objeto suelto (caja, barril...) contra el que choca la moneda, o null si solo toca algo fijo.
func _movable_contact(coin: RigidBody3D) -> RigidBody3D:
	for b in coin.get_colliding_bodies():
		var rb := b as RigidBody3D
		if rb != null and not rb.freeze and not rb is Coin and Metals.movable_mass(rb) > 0.0:
			return rb
	return null


## En el río, donde el agua cubre más de SWIM_DEPTH (solo en escenarios con río).
func _in_deep_water() -> bool:
	if get_tree().get_node_count_in_group(&"water") == 0:
		return false
	var bed := CityPlan.river_bed(Vector2(global_position.x, global_position.z))
	var y := global_position.y
	var top := CityPlan.water_level(Vector2(global_position.x, global_position.z))
	return CityPlan.WATER_LEVEL - bed > SWIM_DEPTH and y < top - 0.05 and y > top - CityPlan.WATER_LEVEL + bed - 0.5


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
	_update_shield(rd)
	_update_field()
	_update_landing_cue()
	_update_iron_powers(delta, rd)
	_update_pewter_powers(rd)
	_update_pewter_drag(rd)
	allomancy.flare_blocked = is_soothed()
	var pewter := allomancy.strength(&"pewter")
	var speed_mult := (1.0 + 0.6 * pewter) * gear_stat("speed")  # peltre: 1.6x quemando, 2.2x avivando
	var jump_mult := 1.0
	if _pewter_drag > 0.0:
		speed_mult = 0.6
		jump_mult = 0.7
	_update_stamina(rd)
	if _exhausted:
		speed_mult *= EXHAUSTED_SPEED
	_update_block()
	if blocking:
		speed_mult *= BLOCK_SPEED
	elif rig.crouched and is_on_floor():
		speed_mult *= CROUCH_SPEED

	_collect_coins()
	_ledge_cd -= rd
	_commit_t -= rd
	if _commit_t <= 0.0 and _queued_skill != &"":
		var queued := _queued_skill
		_queued_skill = &""
		_aim_firing = true  # ya se apuntó y se soltó: sale directo
		_skill_press(queued)
		_aim_firing = false
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
		var float_y := CityPlan.water_level(Vector2(global_position.x, global_position.z)) - SWIM_FLOAT
		velocity.y = move_toward(velocity.y, (float_y - global_position.y) * 3.0, 15.0 * rd)
	elif not is_on_floor():
		# Durante el dash planeas un poco (cae más despacio).
		velocity.y -= _gravity * rd * (0.35 if _dash_time > 0.0 else 1.0)
	var jumped := false
	if _just(&"jump") and not dead and not ui_open:
		var now := Time.get_ticks_msec()
		var double_tap := now - _last_jump_ms <= DOUBLE_TAP_MS
		_last_jump_ms = now
		var move := _move_vector()
		# Con WASD: salto de acero hacia esa dirección; con doble Espacio sin dirección: recto hacia arriba.
		if _can_steel_jump() and now >= _leap_ready_ms and (move != Vector2.ZERO or double_tap):
			_steel_leap(move)
			_last_jump_ms = -DOUBLE_TAP_MS * 10
		elif double_tap and not is_on_floor() and not _swimming and _air_action_free() and _spend_stamina(JUMP_COST):
			# Doble Espacio en el aire sin acero: segundo salto.
			_air_jump_used = true
			_last_jump_ms = -DOUBLE_TAP_MS * 10
			_air_jump(move)
			rig.play_jump(true)
		elif (is_on_floor() or _swimming) and _spend_stamina(JUMP_COST):
			_cancel_action()
			_ground_jump(move, speed_mult, jump_mult)
			jumped = true
			if rig.crouched:
				rig.next_jump = "_crouch"
			rig.crouched = false
			rig.play_jump()
			Sfx.play("jump", global_position)

	var input := Vector2.ZERO if dead else _move_vector()
	var dir := yaw_pivot.global_basis * Vector3(input.x, 0, input.y)
	dir.y = 0.0
	dir = dir.normalized()
	var target := (Vector2(dir.x, dir.z) * walk_speed * speed_mult).limit_length(_walk_limit(rd, input != Vector2.ZERO, pewter, walk_speed * speed_mult))
	var hv := Vector2(velocity.x, velocity.z)
	_shoved -= rd
	var being_pushed := _allomantic_accel > 2.0 or _shoved > 0.0
	# Desde que el empuje te arrastra hasta soltar o despegar: si no, al debilitarse con la distancia se pondría a correr.
	_push_slide = (_push_slide or _allomantic_accel > 2.0) and is_on_floor() 			and (steel_iron.push_grip.active or steel_iron.pull_grip.active)
	rig.pushed_on_floor = _push_slide
	_attack_cd -= rd
	_combo_window -= rd
	if _attack_buffered and _attack_cd <= 0.0 and _commit_t <= 0.0:
		_attack_buffered = false
		attack()
	_roll_cd -= rd
	_roll_buffer -= rd
	if is_on_floor() and not jumped:
		_jump_hcap = INF
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
	_evade_t -= rd
	if _dodge_t > 0.0:
		# Esquive: el paso lo da la animación (root motion); tu velocidad se queda quieta.
		_dodge_t -= rd
		if is_on_floor():
			hv = Vector2.ZERO
	elif _charge_t > 0.0:
		_charge_t -= rd
		hv = Vector2(_charge_dir.x, _charge_dir.z) * CHARGE_SPEED * (1.0 + 0.3 * pewter)
	elif _roll_time > 0.0:
		# Durante la voltereta mantienes la dirección y velocidad del impulso.
		_roll_time -= rd
		if is_on_floor():
			hv = Vector2(_roll_dir.x, _roll_dir.z) * roll_speed * (1.0 + 0.3 * pewter)
	elif is_on_floor() and _attack_cd > 0.0 and not being_pushed and not jumped:
		hv = hv.move_toward(Vector2.ZERO, ATTACK_BRAKE * rd)
	elif (is_on_floor() or _swimming) and not being_pushed and not jumped:
		hv = hv.move_toward(target * (SWIM_SPEED if _swimming else 1.0), ground_accel * rd)
	elif input != Vector2.ZERO:
		# En el aire solo añadimos control, sin frenar el impulso de un empujón.
		# Empujando la moneda de la G, el triple: así diriges el salto.
		var along := hv.dot(target.normalized())
		var cap := target.length() * (1.5 if guided else 1.0)
		if not guided and not being_pushed:
			cap = minf(cap, _jump_hcap)
		if along < cap:
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
		if fall_speed < -4.0:
			Sfx.play("land_heavy" if fall_speed < -12.0 else "land_soft", global_position)
			Sfx.step(self)
		if fall_speed < -4.0 and _roll_time <= 0.0:
			rig.play_land(clampf(-fall_speed / 15.0, 0.3, 1.0))
		if fall_speed < -7.0:
			var strength := clampf(-fall_speed / 20.0, 0.3, 1.5)
			add_trauma(strength * 0.35)
			AirFx.ground(get_tree().current_scene, global_position, 1.5 + 3.0 * strength, AirFx.ASH, 0.6)
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
	if is_focused():
		target_fov *= FOCUS_FOV
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
		# Que se pueda llegar: nada entre tu cabeza y el borde (si no, el "borde" es el piso de arriba
		# visto a través del techo, o lo de arriba de un dintel, y al trepar atravesarías la pared).
		var head := global_position + Vector3.UP * 1.7
		var lip := top + Vector3.UP * 0.4 + nh * 0.25
		var corner := Vector3(head.x, lip.y, head.z)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(head, corner, Props.LAYER_WORLD, [get_rid()])).is_empty():
			continue
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(corner, lip, Props.LAYER_WORLD, [get_rid()])).is_empty():
			continue
		# Y que quepas parado arriba.
		var q := PhysicsShapeQueryParameters3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.35
		cap.height = 1.7
		q.shape = cap
		q.transform = Transform3D(Basis(), top + Vector3.UP * 0.95 - nh * 0.45)
		q.collision_mask = Props.LAYER_WORLD
		q.exclude = [get_rid()]
		if not space.intersect_shape(q, 1).is_empty():
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
	add_trauma(0.15)


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


## Pasos al ritmo de la zancada (cada ~0,7 m caminando, ~1,4 m corriendo); nadando, brazadas.
func _footsteps(rd: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.6 or not (is_on_floor() or _swimming):
		_step_acc = 0.0
		return
	_step_acc += speed * rd
	if _step_acc >= clampf(0.45 + speed * 0.13, 0.65, 1.7) * (1.8 if _swimming else 1.0):
		_step_acc = 0.0
		if _swimming:
			Sfx.play("step_water", global_position)
		else:
			Sfx.step(self)


func _update_rig(hv: Vector2, rd: float) -> void:
	_footsteps(rd)
	rig.move_speed = Vector2(velocity.x, velocity.z).length()
	rig.vertical_speed = velocity.y
	rig.on_floor = is_on_floor() or _swimming
	rig.swimming = _swimming
	rig.sliding = _slide_t > 0.0
	rig.body_velocity = velocity
	_update_air_pose(rd)
	rig.set_vials(equipment.get("vials", ""), max_vials(), vial_charges)
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
	if face.length() > 0.5 and _attack_cd <= 0.0:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-face.x, -face.y), 12.0 * rd)


func _process(delta: float) -> void:
	var rd := real_delta(delta)
	if is_local_player():
		# Hacia abajo la cámara pasa del hombro al eje del personaje: la mira apunta justo bajo tus pies.
		var down := clampf(inverse_lerp(deg_to_rad(40.0), deg_to_rad(80.0), -pitch_pivot.rotation.x), 0.0, 1.0)
		var shoulder := _shoulder_room(lerpf(CAMERA_SHOULDER, 0.0, down))
		# Se mete enseguida si hay pared; vuelve despacio, así no salta al pasar junto a un poste.
		spring_arm.position.x = shoulder if shoulder < spring_arm.position.x else move_toward(spring_arm.position.x, shoulder, 1.5 * rd)
		_update_camera_boom(rd)
		_update_aim()
	# Regeneración; el peltre acelera la curación.
	_since_damage += rd
	if not dead and _since_damage > regen_delay and is_simulated():
		health = minf(health + regen_rate * rd, max_health)
	if not dead and Time.get_ticks_msec() < _last_stand_until_ms:
		health = minf(health + max_health * LAST_STAND_HEAL / SkillTree.LAST_STAND_TIME * rd, max_health)
	# El estaño (el dolor te despeja) te recupera antes de un golpe: avivado, el triple de rápido.
	var recover := rd * 3.0 * (1.0 + allomancy.strength(&"tin"))
	if rig is ModelRig:
		rig.down = dead  # animación de caída del modelo
		rig.stagger = move_toward(rig.stagger, 0.0, recover)
	else:
		rig.stagger = 1.0 if dead else move_toward(rig.stagger, 0.0, recover)
		visual.rotation.x = lerpf(visual.rotation.x, PI / 2 if dead else 0.0, minf(rd * 6.0, 1.0))  # tumbado al morir
	rig.brace = 1.0 if in_combat() else 0.0  # a puños, en guardia solo peleando
	# Con el arma en la mano, un rato sin pelear (ni recién sacada): reposo común, sin la guardia.
	rig.relaxed = not in_combat() and Time.get_ticks_msec() - _drawn_ms > RELAX_AFTER * 1000.0
	# Dagas desenvainadas solas: se guardan un rato después de dejar de pelear.
	if _auto_drawn and not in_combat() and _attack_cd < -4.0:
		_auto_drawn = false
		weapon = HumanoidRig.Weapon.NONE
		rig.set_weapon(weapon)
	_shake = move_toward(_shake, 0.0, rd)
	var amp := _shake * _shake
	var nt := Time.get_ticks_msec() * 0.02
	camera.h_offset = _shake_noise.get_noise_2d(nt, 0.0) * amp * 0.8
	camera.v_offset = _shake_noise.get_noise_2d(0.0, nt) * amp * 0.8
	camera.rotation.z = _shake_noise.get_noise_2d(nt, nt) * amp * 0.06
	if net_peer_id != 0:
		# Protegido tras reaparecer: parpadea (el servidor lo marca, ambos clientes lo dibujan).
		visual.visible = not net_protected or int(Time.get_ticks_msec() / 120.0) % 2 == 0
	if net_peer_id != 0 and multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_update_remote_rig()


## Daño que haría un impacto a esa velocidad; las botas suben el umbral.
func impact_damage_for(impact_speed: float) -> float:
	if Time.get_ticks_msec() < _hook_safe_ms:
		impact_speed *= 0.7  # recién llegaste con el gancho: la soga te frenó un poco
	var safe := safe_impact_speed + gear_stat("impact", true)
	return maxf(impact_speed - safe, 0.0) * impact_damage


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


## Siempre llevas metal encima (el monedero): los alománticos te pueden empujar y tirar de ti.
func carries_metal() -> bool:
	return true


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
	if w == HumanoidRig.Weapon.SWORD and equipment.get("shield", "") != "":
		stats["name"] += " y escudo"
		stats["combo"] = SHIELD_COMBO
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
	rig.shield_owned = equipment.get("shield", "") != ""
	rig.set_weapon(weapon)
	_update_metal_group()
	equipment_changed.emit()


## Cuánto se reduce la distancia a la que te ven (ropa oscura y capa de bruma, sobre todo de noche).
func concealment() -> float:
	return gear_stat("conceal_night" if Art.lighting == "noche" else "conceal_day")


## shortcut: tecla de prueba (F7) para ver las animaciones de Mixamo sin asignar; borrarla cuando
## los poderes las usen.
const DEBUG_ANIMS := ["coin_wave", "coin_shield", "steel_push", "iron_pull", "coin_flick", "burn_focus",
		"pewter_flex", "block", "dodge_left", "dodge_right", "hit_front", "hit_back", "hit_left", "hit_right",
		"get_up", "crouch_idle", "crouch_walk", "climb_wall", "vault", "fall_roll", "freefall", "drink",
		"open_door", "sit"]
var _debug_anim := -1
var _debug_kit := -1


## shortcut: Mayús+F7 trae a cada uno de los que pelean, de a uno, para probarlos; borrarla cuando estén ajustados.
func _debug_spawn_koloss() -> void:
	var k := Champion.new()
	_debug_kit = (_debug_kit + 1) % Champion.KITS.size()
	k.kit = Champion.KITS.keys()[_debug_kit]
	notice.emit("Mayús+F7: " + k.kit)
	k.home = global_position
	k.position = global_position - visual.global_basis.z * 14.0 + Vector3.UP * 0.5
	get_tree().current_scene.add_child(k)


func _debug_next_anim() -> void:
	_debug_anim = (_debug_anim + 1) % DEBUG_ANIMS.size()
	var anim: String = DEBUG_ANIMS[_debug_anim]
	rig.play_spell(anim, 60.0)  # duración larga: se reproduce a su velocidad natural
	notice.emit("F7: %s (%d/%d)" % [anim, _debug_anim + 1, DEBUG_ANIMS.size()])


## Bebe un frasco: recupera de cada metal salvo atium (según el tipo de frasco).
func drink_vial() -> void:
	if dead or equipment.get("vials", "") == "" or vial_charges <= 0 or _commit_t > 0.0:
		return
	_cast("drink", 1.2, 0.2, _finish_drink, 0.42)
	rig.take_vial()


## La mano llegó a la boca (si cortaste antes con una voltereta, el frasco no se gasta).
func _finish_drink() -> void:
	if vial_charges <= 0:
		return
	vial_charges -= 1
	rig.drop_vial()
	Sfx.play("drink")
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
func take_hit(impulse: Vector3, damage: float, attacker: Node3D = null, ranged := false) -> void:
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
	if _since_damage < IFRAMES:
		return
	if _evade_t > 0.0:
		# Esquive a tiempo: el golpe pasa de largo.
		Atium.dodge_trail(visual)
		Fx.popup(get_tree().current_scene, chest_position() + Vector3(0, 0.8, 0), "esquiva", Color(0.7, 0.85, 1.0))
		mark_combat()
		return
	# Con atium, el atacante ve el hueco: ni armadura ni peltre frenan el golpe.
	var unblockable := attacker != null and Metals.atium_edge(attacker, self)
	if attacker and not ranged and not unblockable and _facing(attacker):
		if Time.get_ticks_msec() - _block_pressed_ms <= PARRY_WINDOW_MS:
			_parry(attacker)
			return
		if blocking:
			if _spend_stamina(damage * (SHIELD_BLOCK_STAMINA if rig.shield_up() else BLOCK_STAMINA)) or is_clear_minded():
				_block_hit(attacker, impulse, damage)
				return
			_guard_broken = true  # sin resistencia: la guardia cede y el golpe entra entero
			blocking = false
			notice.emit("Guardia rota")
	if _shield > 0 and not unblockable and not ranged and randf() < SkillTree.shield_block_chance(_shield):
		_shield_block(attacker)  # el escudo de monedas desvía el golpe cuerpo a cuerpo
		return
	if is_rioted():
		damage *= 1.25
	if not unblockable:
		damage *= 1.0 - clampf(gear_stat("armor", true), 0.0, 0.8)
	if _hanging or _climb_t >= 0.0:
		_release_ledge(Vector3.ZERO)  # un golpe te suelta del borde
	# El peltre endurece el cuerpo: menos daño y menos empujón (quemando ~40 %, avivando ~55 %).
	var pewter := 0.0 if unblockable else pewter_for(&"pewter_endurance")
	impulse /= 1.0 + 0.5 * pewter
	if is_clear_minded():
		impulse *= 0.3  # Mente despejada: casi no te empujan
	velocity += impulse + Vector3.UP * impulse.length() * 0.2
	_shoved = 0.1 if is_clear_minded() else 0.35
	mark_combat()
	if attacker and attacker.has_method(&"mark_combat"):
		attacker.mark_combat()
	HumanoidRig.hit_stop([rig, attacker.get(&"rig") if attacker else null], damage)
	if attacker:
		if damage >= 20.0 or _guard_broken:
			_cancel_action()
		rig.play_hit(attacker.global_position, damage >= 20.0 or _guard_broken)
	take_damage(damage / (1.0 + 0.6 * pewter))


func is_down() -> bool:
	return dead


## El atacante está delante (dentro de BLOCK_ARC de hacia donde miras).
func _facing(attacker: Node3D) -> bool:
	var to := attacker.global_position - global_position
	to.y = 0.0
	var fwd := -visual.global_basis.z
	fwd.y = 0.0
	return to.length() < 0.1 or fwd.angle_to(to) <= (SHIELD_BLOCK_ARC if rig.shield_up() else BLOCK_ARC)


## Ctrl: guardia mientras lo mantienes (en el suelo, sin rodar ni atacar). Pulsarlo abre la ventana de parry.
func _update_block() -> void:
	var held := is_local_player() and not ui_open and not dead and Input.is_action_pressed(&"block")
	if is_local_player() and Input.is_action_just_pressed(&"block") and not ui_open:
		_block_pressed_ms = Time.get_ticks_msec()
	if not held:
		_guard_broken = false
	var was_blocking := blocking
	blocking = held and not _guard_broken and is_on_floor() and _roll_time <= 0.0 and _dodge_t <= 0.0 and not _hanging
	if blocking and not was_blocking:
		_cancel_action()
	rig.blocking = blocking


func _parry(attacker: Node3D) -> void:
	_block_pressed_ms = -100000  # un parry por pulsación
	var at := (chest_position() + Metals.center_of(attacker)) * 0.5
	AirFx.impact(get_tree().current_scene, at, AirFx.GOLD, 1.4)
	Fx.popup(get_tree().current_scene, chest_position() + Vector3(0, 0.8, 0), "¡Parry!", Color(1.0, 0.85, 0.4))
	HumanoidRig.hit_stop([rig, attacker.get(&"rig")], 60.0)
	add_trauma(0.35)
	rig.block_impact()
	Sfx.play("clash", at)
	mark_combat()
	if attacker.has_method(&"stun"):
		attacker.stun(PARRY_STUN, global_position)


func _block_hit(attacker: Node3D, impulse: Vector3, damage: float) -> void:
	var at := chest_position() + (Metals.center_of(attacker) - chest_position()).normalized() * 0.4
	Fx.sparks(get_tree().current_scene, at, Color(1.0, 0.75, 0.45))
	HumanoidRig.hit_stop([rig, attacker.get(&"rig")], damage * 0.5)
	if attacker.get(&"rig"):
		attacker.get(&"rig").recoil(global_position, 0.35)
	velocity += impulse * 0.3
	_shoved = 0.15
	rig.block_impact()
	Sfx.play("clash", at)
	mark_combat()
	take_damage(damage * (SHIELD_BLOCK_DAMAGE if rig.shield_up() else BLOCK_DAMAGE))


func _update_camera_boom(rd: float) -> void:
	_boom.position = spring_arm.position
	var free := spring_arm.get_hit_length()
	_cam_len = free if free < _cam_len else move_toward(_cam_len, free, CAMERA_RETURN * rd)
	camera.position.z = _cam_len
	# Tapada (algo detrás tuyo) y sin tocar el ratón: gira hacia el lado con más espacio.
	var full := spring_arm.spring_length
	if free > full * 0.7 or Time.get_ticks_msec() - _look_ms < CAMERA_ASSIST_IDLE_MS or dead:
		return
	var origin := spring_arm.global_position
	var back := pitch_pivot.global_basis.z
	var left := _camera_room(origin, back.rotated(Vector3.UP, 0.5), full)
	var right := _camera_room(origin, back.rotated(Vector3.UP, -0.5), full)
	if maxf(left, right) < free + 0.3:
		return  # ningún lado está mejor
	var push := (1.0 - free / full) * CAMERA_ASSIST_SPEED * rd
	yaw_pivot.rotate_y(push if left >= right else -push)


## Cuánto se puede correr la cámara al hombro sin meterse en una pared de al lado: el brazo de la cámara
## arranca ahí, y si arranca dentro del muro no lo ve y la cámara queda del otro lado.
func _shoulder_room(want: float) -> float:
	if want <= 0.0:
		return want
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = spring_arm.shape
	q.transform = Transform3D(Basis(), pitch_pivot.global_position)
	q.motion = pitch_pivot.global_basis.x * want
	q.collision_mask = spring_arm.collision_mask
	q.exclude = [get_rid()]
	var free := get_world_3d().direct_space_state.cast_motion(q)
	return want * free[0]


## Distancia libre desde `origin` en `dir` (hasta `length`).
func _camera_room(origin: Vector3, dir: Vector3, length: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * length, spring_arm.collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return origin.distance_to(hit["position"]) if hit else length


## Suma "trauma" a la cámara (0 a 1); el temblor va con su cuadrado y se apaga en ~1 s.
func add_trauma(amount: float) -> void:
	_shake = minf(_shake + amount, 1.0)


func take_damage(amount: float, impact_speed := 0.0) -> void:
	if dead:
		return
	var now := Time.get_ticks_msec()
	if now < _last_stand_until_ms:
		return  # Último aliento: nada te toca
	if now >= _last_stand_ready_ms and skill_unlocked(&"pewter_last_stand") and health - amount < max_health * LAST_STAND_HEALTH:
		_last_stand_until_ms = now + int(SkillTree.LAST_STAND_TIME * 1000.0)
		_last_stand_ready_ms = now + int(SkillTree.LAST_STAND_COOLDOWN * 1000.0)
		amount = minf(amount, maxf(health - 1.0, 0.0))
		notice.emit("¡Último aliento!")
		AirFx.wave(get_tree().current_scene, chest_position(), 5.0, AirFx.PEWTER, 0.7, 0.05)
		AirFx.shell(self, AirFx.PEWTER, 1.5, func() -> bool: return Time.get_ticks_msec() < _last_stand_until_ms)
	health -= amount
	Sfx.play("hurt", global_position + Vector3(0, 1.2, 0))
	_since_damage = 0.0
	add_trauma(clampf(amount / 40.0, 0.3, 0.8))
	rig.stagger = 0.2 if is_clear_minded() else 1.0
	rig.flash()
	damaged.emit(amount, impact_speed)
	if health <= 0.0:
		_die()


func _die() -> void:
	health = 0.0
	dead = true
	allomancy.stop_all()
	_dismiss_shield()
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
	if blocking:
		return
	if _attack_cd > 0.0 or _commit_t > 0.0:
		_attack_buffered = _attack_cd < 0.3
		return
	if not _spend_stamina(ATTACK_COST):
		return
	if weapon == HumanoidRig.Weapon.NONE and can_use_weapon(HumanoidRig.Weapon.DAGGERS) and not _fists_chosen:
		weapon = HumanoidRig.Weapon.DAGGERS  # desenvaina sola
		_auto_drawn = true
		rig.set_weapon(weapon)
	var pewter := pewter_for(&"pewter_strike")
	var stats := weapon_stats(weapon)
	if not is_on_floor():
		# En el aire, un solo golpe y solo si todavía no hiciste otra acción (segundo salto o dash).
		if _air_action_free():
			_air_attack(stats, pewter)
		return
	var combo: Array = stats["combo"]
	_combo = (_combo + 1) % combo.size() if _combo_window > 0.0 else 0
	var step: Array = combo[_combo]
	var duration: float = step[0] / (1.0 + 0.5 * pewter) / _pace()
	if weapon == HumanoidRig.Weapon.DAGGERS:
		_attack_side = 1 - _attack_side  # alterna las manos
	else:
		_attack_side = 1
	# El ritmo del golpe (cuándo pega, cuándo se puede encadenar) sigue a la animación de verdad.
	duration = rig.play_attack(_attack_side, duration, _combo)
	var impact := rig.impact_delay()
	# Encadenar se puede pasado el impacto, sin esperar a que termine la recuperación.
	_attack_cd = maxf(impact + 0.1, duration * 0.6)
	_commit_t = impact
	_combo_window = duration + COMBO_WINDOW
	# Golpea hacia donde mira la cámara.
	var fwd := aim_direction()
	fwd.y = 0.0
	fwd = fwd.normalized()
	visual.rotation.y = atan2(-fwd.x, -fwd.z)
	# Remate: el último golpe de un combo (un arma de un solo golpe no tiene remate).
	var finisher := combo.size() > 1 and _combo == combo.size() - 1
	if finisher and is_on_floor():
		# El remate da un paso corto hacia delante, en vez de sumarse a la carrera.
		velocity.x = fwd.x * 4.0
		velocity.z = fwd.z * 4.0
		_shoved = 0.15
	Sfx.play("swing", global_position + Vector3(0, 1.2, 0))
	_after(impact, _resolve_hit.bind(stats, pewter, step[1], step[2] * (1.0 if finisher else COMBO_KNOCK), 1.2, 0.0, finisher))


## Golpe por el miembro: cuánto se perdona (m) entre lo que golpea y el cuerpo del otro, y cuánto se alarga más allá.
const STRIKE_RADIUS := 0.5
const STRIKE_SLACK := 0.15
const ARM_REACH := 0.6  # del pecho a la mano con el brazo estirado


## Si el tramo pecho -> puño/hoja toca el cuerpo de alguien parado en `feet` (de los pies a `top` de alto).
func _limb_hits(from: Vector3, tip: Vector3, feet: Vector3, top: float) -> bool:
	var pts := Geometry3D.get_closest_points_between_segments(from, tip, feet + Vector3.UP * 0.2, feet + Vector3.UP * maxf(top, 0.6))
	return pts[0].distance_to(pts[1]) < STRIKE_RADIUS


## Corre `effect` en el impacto, salvo que antes hayan cortado la acción.
func _after(delay: float, effect: Callable) -> void:
	_action_id += 1
	var id := _action_id
	get_tree().create_timer(delay, true, false, true).timeout.connect(func() -> void:
		if id == _action_id and not dead:
			effect.call())


## Gesto de un poder y su efecto cuando la mano llega (from: ver ModelRig.play_skill).
func _cast(state: String, duration: float, from: float, effect: Callable, to := 1.0) -> void:
	rig.play_skill(state, duration, from, to)
	_commit_t = rig.impact_delay()
	_after(_commit_t, effect)


func _cancel_action() -> void:
	_action_id += 1
	_commit_t = 0.0
	_attack_cd = 0.0
	_attack_buffered = false
	_queued_skill = &""
	rig.cancel_action()


const AIR_ATTACK_TIME := 0.55
## Golpe aéreo: un tajo giratorio que pega alrededor y te da un salto extra (uno por salto).
func _air_attack(stats: Dictionary, pewter: float) -> void:
	_air_attack_used = true
	var duration := rig.play_air_attack(AIR_ATTACK_TIME / (1.0 + 0.3 * pewter))
	_commit_t = rig.impact_delay()
	_attack_cd = duration * 0.9
	_combo_window = 0.0
	var fwd := aim_direction()
	fwd.y = 0.0
	fwd = fwd.normalized()
	visual.rotation.y = atan2(-fwd.x, -fwd.z)
	velocity.y = maxf(velocity.y, jump_velocity * 0.9)
	velocity += fwd * 2.5
	AirFx.wave(get_tree().current_scene, chest_position(), 2.2, AirFx.ASH, 0.45, 0.04)
	_shield_spin = ModelRig.SPIN_TIME + 0.2  # las monedas del escudo giran con el cuerpo
	_after(_commit_t, _resolve_hit.bind(stats, pewter, 1.4, 1.8, PI, 0.8, true))


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
	damage *= _fury_mult()
	var knockback: float = stats["knockback"] * knockback_mult * (1.0 + 1.0 * pewter)
	# Pega donde está de verdad el puño, el pie o la hoja en este cuadro (no en un cono delante del cuerpo).
	# Los giros (arco de media vuelta o más) pegan alrededor, como antes.
	var from := chest_position()
	var tips: Array[Vector3] = []
	for p in rig.strike_points():
		if forward.dot(p - global_position) > 0.0:  # lo que queda atrás (la hoja en el armado) no pega
			# En el pico de velocidad el brazo todavía no se estiró: se cuenta hasta su alcance, en la dirección del golpe.
			var arm: float = ARM_REACH + float(ModelRig.STRIKE_REACH.get(weapon, 0.05))
			tips.append(from + (p - from).normalized() * (maxf(from.distance_to(p), arm) + STRIKE_SLACK + extra_reach))
	var by_limb := arc < PI and not tips.is_empty()
	for n in get_tree().get_nodes_in_group(&"npc"):
		var npc := n as Npc
		var to := npc.global_position - global_position
		to.y = 0.0
		if by_limb:
			if to.length() > reach + 1.0 or not tips.any(func(t: Vector3) -> bool: return _limb_hits(from, t, npc.global_position, npc.head_y(0.0))):
				continue
		elif to.length() > reach or forward.angle_to(to) > arc:
			continue
		# Crítico: la suerte de siempre (más con atium), un rival aturdido (parry) o por la espalda.
		var behind := (-npc.global_basis.z).dot(-to.normalized()) < -0.4
		var crit := randf() < Metals.crit_chance(self, npc) or npc.is_stunned() or behind
		npc.take_hit(to.normalized() * knockback * (1.5 if crit else 1.0), damage * (Metals.CRIT_MULT if crit else 1.0), self)
		if crit:
			npc.stun(0.0, global_position)  # el crítico lo saca del aturdimiento y lo tira para atrás
			Fx.popup(get_tree().current_scene, npc.global_position + Vector3(0, npc.head_y() + 0.5, 0), "¡Crítico!", Color(1.0, 0.85, 0.35), 1.5)
			# Se nota más que un golpe común: todo se congela un poco más y el golpeado brilla.
			npc.rig.flash(Color(1.0, 0.9, 0.55))
			npc.rig.hitstop = 0.2
			rig.hitstop = 0.15
		var hit_sound := "punch_heavy" if heavy else "punch"
		if weapon != HumanoidRig.Weapon.NONE:
			hit_sound = "clash" if npc.is_in_group(&"metal") else "slash"
		Sfx.play(hit_sound, npc.global_position + Vector3(0, 1.2, 0))
		add_trauma(0.12)
		mark_combat()
		if crit:
			AirFx.wave(get_tree().current_scene, npc.global_position + Vector3(0, 1.2, 0), 2.6, AirFx.GOLD, 0.45, 0.05)
			add_trauma(0.3)
		# Golpe reforzado (peltre encendido): la onda es más grande y va con su color.
		AirFx.impact(get_tree().current_scene, npc.global_position + Vector3(0, 1.2, 0), AirFx.PEWTER if pewter > 0.0 else AirFx.ASH, 1.0 + pewter * 0.5 + (0.5 if heavy else 0.0))
		if heavy:
			add_trauma(0.35)
	for n in get_tree().get_nodes_in_group(&"metal"):
		var rb := n as RigidBody3D
		if rb == null:
			continue
		var to := rb.global_position - global_position
		var near_limb := tips.any(func(t: Vector3) -> bool: return Geometry3D.get_closest_point_to_segment(rb.global_position, from, t).distance_to(rb.global_position) < STRIKE_RADIUS + 0.2)
		if near_limb if by_limb else to.length() <= reach + 0.5 and forward.angle_to(Vector3(to.x, 0, to.z)) < arc:
			rb.apply_central_impulse(forward * knockback * minf(rb.mass, 20.0) * 0.5)


## Voltereta en el suelo; en el aire, un dash hacia delante (uno por salto).
## En el aire, por encima de esta velocidad vertical (m/s; un salto normal llega a ~5) no se puede hacer el dash ni dejar
## pedida la voltereta del aterrizaje.
const AIR_ROLL_MAX_VSPEED := 12.0


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
		if absf(input.x) > 0.5 and absf(input.y) < 0.5:
			if not _spend_stamina(ROLL_COST * 0.7):
				return
			_start_dodge(signf(input.x))
			return
		if not _spend_stamina(ROLL_COST):
			return
		_start_roll(dir)
	elif absf(velocity.y) <= AIR_ROLL_MAX_VSPEED:  # cayendo o subiendo a toda velocidad no hay voltereta ni dash
		_roll_buffer = 0.35  # si tocas el suelo enseguida, ruedas al aterrizar
		if _air_action_free():
			if not _spend_stamina(DASH_COST):
				return
			# El impulso se reparte en DASH_TIME y el cuerpo gira suave hacia la dirección
			# (lo hace _update_rig siguiendo la velocidad).
			_cancel_action()
			_air_dash_used = true
			_dash_dir = dir
			_dash_speed = air_dash_speed * (1.0 + 0.3 * allomancy.strength(&"pewter"))
			_dash_time = DASH_TIME
			rig.play_dash(0.45)
			AirFx.wave(get_tree().current_scene, chest_position() + dir * 0.6, 1.4, AirFx.ASH, 0.35, 0.04, dir)
			AirFx.trail(self, Color(AirFx.ASH, 0.2), 1.0, func() -> bool: return _dash_time > 0.0)
			_roll_cd = 0.3


## Paso al costado (side: -1 izquierda, 1 derecha, según la cámara).
func _start_dodge(side: float) -> void:
	_cancel_action()
	blocking = false
	var fwd := aim_direction()
	visual.rotation.y = atan2(-fwd.x, -fwd.z)
	_dodge_t = DODGE_TIME
	_evade_t = EVADE_TIME
	_roll_cd = DODGE_TIME + 0.1
	rig.play_spell("dodge_right" if side > 0.0 else "dodge_left", DODGE_TIME)
	Fx.dust(get_tree().current_scene, global_position, 0.3)


## Al arrancar camina WALK_START_TIME s y después pasa al trote; con peltre encendido arranca corriendo. Igual con todas las armas.
const WALK_START_SPEED := 1.6
const WALK_START_TIME := 0.6  # antes 3 s: tardaba casi 4 s en correr y se hacía largo
const TROT_RAMP_TIME := 0.5
const WALK_RESET_TIME := 0.3  # frenar un instante no te hace empezar de nuevo
var _walk_t := 0.0
var _still_t := 0.0


func _walk_limit(rd: float, moving: bool, pewter: float, full: float) -> float:
	if moving and is_on_floor():
		_still_t = 0.0
		_walk_t += rd
	elif is_on_floor():  # en el aire no cuenta ni descuenta
		_still_t += rd
		if _still_t > WALK_RESET_TIME:
			_walk_t = 0.0
	if pewter > 0.0:
		return full
	var k := smoothstep(WALK_START_TIME, WALK_START_TIME + TROT_RAMP_TIME, _walk_t)
	return lerpf(minf(WALK_START_SPEED * _pace(), full), full, k)


const SLIDE_MIN_SPEED := 4.0
const SLIDE_CHANCE := 0.5


func _start_roll(dir: Vector3) -> void:
	_cancel_action()
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = -visual.global_basis.z
	_roll_dir = dir.normalized()
	_roll_time = roll_duration
	_evade_t = EVADE_TIME
	blocking = false
	_roll_cd = roll_duration + 0.15
	visual.rotation.y = atan2(-_roll_dir.x, -_roll_dir.z)
	# Corriendo, a veces se desliza en vez de rodar: mismo movimiento, otro clip.
	var slide := Vector2(velocity.x, velocity.z).length() > SLIDE_MIN_SPEED and randf() < SLIDE_CHANCE
	rig.play_roll(roll_duration, slide)
	Sfx.play("roll", global_position)
	if slide:
		AirFx.trail(self, Color(AirFx.ASH, 0.2), 0.9, func() -> bool: return _roll_time > 0.0, 0.2)


## Salto desde el suelo: altura y velocidad horizontal según lo rápido que ibas (ver JUMP_HEIGHT_STAND...).
## Parado y pulsando una dirección, sale hacia ella.
func _ground_jump(move: Vector2, speed_mult: float, jump_mult: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var run := clampf(flat.length() / (walk_speed * speed_mult), 0.0, 1.0)
	var vy := sqrt(2.0 * _gravity * lerpf(JUMP_HEIGHT_STAND, JUMP_HEIGHT_RUN, run))
	# Distancia = velocidad horizontal x tiempo en el aire (2 vy / g).
	var hs := lerpf(JUMP_DIST_STAND, JUMP_DIST_RUN, run) * _gravity / (2.0 * vy) * jump_mult
	var dir := yaw_pivot.global_basis * Vector3(move.x, 0.0, move.y)
	dir.y = 0.0
	# Conserva la velocidad que traías (corriendo a 7,6 m/s el salto la bajaba a 2,7 y saltar te frenaba); `hs` es
	# solo el mínimo, para que parado o caminando el salto igual avance. Con WASD, sale hacia esa dirección.
	var speed := maxf(hs, flat.length())
	if dir.length() > 0.1:
		flat = dir.normalized() * speed
	velocity = Vector3(flat.x, vy * jump_mult, flat.z)
	_jump_hcap = speed


## Segundo salto: sube AIR_JUMP_HEIGHT y conserva la velocidad horizontal, girada hacia donde pulsas.
func _air_jump(move: Vector2) -> void:
	velocity.y = sqrt(2.0 * _gravity * AIR_JUMP_HEIGHT)
	AirFx.wave(get_tree().current_scene, global_position, 1.8, AirFx.ASH, 0.4, 0.035, Vector3.UP)
	var push := yaw_pivot.global_basis * Vector3(move.x, 0.0, move.y)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if push.length() > 0.1:
		flat = Vector3(push.x, 0.0, push.z).normalized() * flat.length()
	velocity.x = flat.x
	velocity.z = flat.z


## En el aire se puede hacer una sola acción más: segundo salto, golpe o dash (vuelve a valer al tocar el suelo).
func _air_action_free() -> bool:
	return not (_air_jump_used or _air_attack_used or _air_dash_used)


## Delta en tiempo real (inmune al time_scale del atium).
func real_delta(delta: float) -> float:
	return delta / Engine.time_scale


## Vuelo: un metal te lleva por el aire; sigue mientras subas por ese impulso. Saltar no cuenta.
const FLY_MIN_ACCEL := 4.0
const FLY_KEEP_TIME := 0.25
const FLY_END_SPEED := -2.0
const FLY_LAND_HEIGHT := 1.5
const DIVE_END_TIME := 0.35  # a cuántos segundos del piso deja la zambullida para caer de pie
var _fly_t := 0.0
var _flying := false
var _coin_flight := false  # salto de acero con moneda: vuela con Vuelo_Moneda, sin el impulso


func _update_air_pose(rd: float) -> void:
	_fly_t -= rd
	if is_on_floor() or _swimming:
		_flying = false
		_coin_flight = false
	elif _fly_t > 0.0:
		if not _flying and not _coin_flight:
			rig.play_fly_launch()
		_flying = true
	elif velocity.y < FLY_END_SPEED:
		_flying = false
	rig.flying = _flying
	rig.coin_flight = _coin_flight
	rig.near_ground = false
	if velocity.y < 0.0 and not is_on_floor():
		# Bajando y cerca del piso: deja el vuelo o la zambullida para caer de pie.
		var reach := maxf(-velocity.y * DIVE_END_TIME, FLY_LAND_HEIGHT)
		var ray := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * reach, Props.LAYER_WORLD, [get_rid()])
		rig.near_ground = not get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func add_allomantic_acceleration(accel: Vector3, rd: float) -> void:
	velocity += accel * rd
	_allomantic_accel = maxf(_allomantic_accel, accel.length())
	if accel.length() > FLY_MIN_ACCEL:
		_fly_t = FLY_KEEP_TIME


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
## Ángulo mínimo (grados bajo la horizontal) al que sale la moneda de combate cuando estás cayendo.
const LANDING_COIN_PITCH := 55.0
## Moneda de combate (clic derecho): ancla instantánea sobre lo fijo hasta ANCHOR_RANGE (m), con ANCHOR_COOLDOWN_MS entre
## impulsos, y proyectil rápido (COIN_SHOT_SPEED m/s) para enemigos, objetos sueltos y lo lejano.
const COIN_SHOT_SPEED := 60.0
## La moneda de combate sale en el acto (sirve para frenar una caída): el gesto arranca con la mano ya en camino.
const COIN_FLICK_FROM := 0.35
const ANCHOR_RANGE := 25.0
const ANCHOR_COOLDOWN_MS := 1000
var _anchor_ready_ms := 0
## 0 o 1: estás a distancia de impulsarte con la moneda del objeto que apuntas (lo muestra el HUD con un aro sutil en la mira).
var landing_cue := 0.0


## Cayendo, la dirección de la moneda baja al menos LANDING_COIN_PITCH grados bajo la horizontal (hacia donde miras): el
## suelo queda debajo y el empuje te frena, en vez de lanzarte hacia atrás por un suelo lejano.
func _landing_clamp(dir: Vector3) -> Vector3:
	if is_on_floor() or velocity.y > -3.0 or dir.y <= -sin(deg_to_rad(LANDING_COIN_PITCH)):
		return dir
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		return Vector3.DOWN
	return flat.normalized() * cos(deg_to_rad(LANDING_COIN_PITCH)) + Vector3.DOWN * sin(deg_to_rad(LANDING_COIN_PITCH))


## Lo fijo (suelo, pared, farola) que toca un rayo desde el pecho hasta ANCHOR_RANGE; vacío si no hay nada o es gente u un
## objeto suelto.
func _fixed_hit(start: Vector3, dir: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(start, start + dir * ANCHOR_RANGE, Props.LAYER_WORLD | Props.LAYER_PROPS, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var body: Object = hit["collider"]
	if body is CharacterBody3D or (body is RigidBody3D and not (body as RigidBody3D).freeze):
		return {}
	return hit


## Efectos que tienes ahora, para los iconos flotantes sobre la barra del HUD: id, nombre, si es bueno (buff), segundos
## que quedan (-1 si no tiene tiempo), duración total y el metal cuyo símbolo se dibuja.
func active_effects() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var now := Time.get_ticks_msec()
	if _shield > 0:
		out.append({"id": &"shield", "name": "Escudo de monedas", "buff": true, "left": maxf((_shield_until_ms - now) / 1000.0, 0.0), "total": SkillTree.SHIELD_DURATION, "metal": &"steel"})
	if _field_shell != null and _field_shell.visible:
		out.append({"id": &"field", "name": "Campo magnético", "buff": true, "left": maxf((_field_until_ms - now) / 1000.0, 0.0), "total": SkillTree.FIELD_DURATION, "metal": &"steel"})
	if is_focused():
		out.append({"id": &"focus", "name": "Foco", "buff": true, "left": maxf((_focus_until_ms - now) / 1000.0, 0.0), "total": SkillTree.FOCUS_TIME, "metal": &"tin"})
	if is_clear_minded():
		out.append({"id": &"clear_mind", "name": "Mente despejada", "buff": true, "left": maxf((_clear_until_ms - now) / 1000.0, 0.0), "total": SkillTree.CLEAR_TIME, "metal": &"tin"})
	if is_extreme_senses():
		out.append({"id": &"extreme", "name": "Sentidos extremos", "buff": true, "left": maxf((_extreme_until_ms - now) / 1000.0, 0.0), "total": SkillTree.EXTREME_TIME, "metal": &"tin"})
	if marked_npc() != null:
		out.append({"id": &"mark", "name": "Marca del cazador", "buff": true, "left": maxf((_marked_until_ms - now) / 1000.0, 0.0), "total": SkillTree.MARK_TIME, "metal": &"tin"})
	if _fury_until_ms > 0:
		out.append({"id": &"fury", "name": "Furia", "buff": true, "left": maxf((_fury_until_ms - now) / 1000.0, 0.0), "total": SkillTree.FURY_TIME, "metal": &"pewter"})
	if now < _last_stand_until_ms:
		out.append({"id": &"last_stand", "name": "Último aliento", "buff": true, "left": maxf((_last_stand_until_ms - now) / 1000.0, 0.0), "total": SkillTree.LAST_STAND_TIME, "metal": &"pewter"})
	if net_protected:
		out.append({"id": &"protected", "name": "Protegido", "buff": true, "left": -1.0, "total": 0.0, "metal": &"pewter"})
	if pewter_drag() > 0.0:
		out.append({"id": &"drag", "name": "Arrastre de peltre", "buff": false, "left": pewter_drag(), "total": PEWTER_DRAG_TIME, "metal": &"pewter"})
	if is_soothed():
		out.append({"id": &"soothed", "name": "Aplacado", "buff": false, "left": maxf((_soothed_ms - now) / 1000.0, 0.0), "total": 2.0, "metal": &"brass"})
	if is_rioted():
		out.append({"id": &"rioted", "name": "Enardecido", "buff": false, "left": maxf((_rioted_ms - now) / 1000.0, 0.0), "total": 2.0, "metal": &"zinc"})
	if senses != null and senses.blinded > 0.0:
		out.append({"id": &"blinded", "name": "Encandilado", "buff": false, "left": -1.0, "total": 0.0, "metal": &"tin"})
	if atium != null and atium.contested:
		out.append({"id": &"atium_contested", "name": "Atium anulado", "buff": false, "left": -1.0, "total": 0.0, "metal": &"atium"})
	if is_exhausted():
		out.append({"id": &"exhausted", "name": "Sin aliento", "buff": false, "left": -1.0, "total": 0.0, "metal": &"pewter"})
	return out


## Fracción (0 a 1) que le falta a una habilidad para recargarse, para el HUD.
func skill_cooldown(skill: StringName) -> float:
	var now := Time.get_ticks_msec()
	match skill:
		&"steel_combat_coin":
			return clampf(float(_anchor_ready_ms - now) / ANCHOR_COOLDOWN_MS, 0.0, 1.0)
		&"steel_spear":
			return clampf(float(_spear_ready_ms - now) / (SkillTree.SPEAR_COOLDOWN * 1000.0), 0.0, 1.0)
		&"steel_magnetic_field":
			return clampf(float(_field_ready_ms - now) / (SkillTree.FIELD_COOLDOWN * 1000.0), 0.0, 1.0)
		&"iron_drag":
			return clampf(float(_drag_ready_ms - now) / (SkillTree.DRAG_COOLDOWN * 1000.0), 0.0, 1.0)
		&"iron_hook":
			return clampf(float(_hook_ready_ms - now) / (SkillTree.HOOK_COOLDOWN * 1000.0), 0.0, 1.0)
		&"iron_disarm":
			return clampf(float(_disarm_ready_ms - now) / (SkillTree.DISARM_COOLDOWN * 1000.0), 0.0, 1.0)
		&"iron_mass_yank":
			return clampf(float(_yank_ready_ms - now) / (SkillTree.YANK_COOLDOWN * 1000.0), 0.0, 1.0)
		&"pewter_charge":
			return clampf(float(_charge_ready_ms - now) / (SkillTree.CHARGE_COOLDOWN * 1000.0), 0.0, 1.0)
		&"pewter_slam":
			return clampf(float(_slam_ready_ms - now) / (SkillTree.SLAM_COOLDOWN * 1000.0), 0.0, 1.0)
		&"pewter_fury":
			return clampf(float(_fury_ready_ms - now) / (SkillTree.FURY_COOLDOWN * 1000.0), 0.0, 1.0)
		&"tin_focus":
			return clampf(float(_focus_ready_ms - now) / (SkillTree.FOCUS_COOLDOWN * 1000.0), 0.0, 1.0)
		&"tin_mark":
			return clampf(float(_mark_ready_ms - now) / (SkillTree.MARK_COOLDOWN * 1000.0), 0.0, 1.0)
		&"tin_clear_mind":
			return clampf(float(_clear_ready_ms - now) / (SkillTree.CLEAR_COOLDOWN * 1000.0), 0.0, 1.0)
		&"tin_extreme":
			return clampf(float(_extreme_ready_ms - now) / (SkillTree.EXTREME_COOLDOWN * 1000.0), 0.0, 1.0)
	return zinc.cooldown(skill) if zinc.has(skill) else 0.0


## Si la habilidad está haciendo algo ahora (agarre sostenido, escudo o campo en marcha), para el HUD.
func skill_active(skill: StringName) -> bool:
	match skill:
		&"steel_light_push":
			return steel_iron.push_grip.active
		&"iron_pull":
			return steel_iron.pull_grip.active
		&"steel_coin_shield":
			return _shield > 0
		&"steel_magnetic_field":
			return _field_shell != null and _field_shell.visible
		&"steel_combat_coin":
			return _coin_shot
		&"pewter_fury":
			return _fury_until_ms > 0
		&"tin_focus":
			return is_focused()
		&"tin_clear_mind":
			return is_clear_minded()
		&"tin_extreme":
			return is_extreme_senses()
		&"tin_mark":
			return marked_npc() != null
		&"pewter_charge":
			return _charge_t > 0.0
	return zinc.active(skill)


## Aro sutil en la mira: en el aire, cuando lo que apuntas es algo fijo (suelo, pared, farola) que está al alcance para
## impulsarte con la moneda (ANCHOR_RANGE) y no hay que esperar la recarga. Avisa con tiempo para que lances la moneda.
func _update_landing_cue() -> void:
	landing_cue = 0.0
	if is_local_player() and not dead and coins_held > 0 and Time.get_ticks_msec() >= _hook_ready_ms \
			and Progression.slot_of(&"iron_hook") >= 0 and skill_unlocked(&"iron_hook") and not _hook_aim().is_empty():
		landing_cue = 1.0  # puedes engancharte ahí (Gancho)
		return
	if not is_local_player() or dead or is_on_floor() or coins_held <= 0:
		return
	if Time.get_ticks_msec() < _anchor_ready_ms:
		return
	var dir := _landing_clamp(_burst_aim(Vector3.INF))
	if not _fixed_hit(chest_position(), dir).is_empty():
		landing_cue = 1.0  # está dentro de ANCHOR_RANGE: ya puedes lanzar la moneda


func throw_coin(aim_target := Vector3.INF, aim_dir := Vector3.INF) -> RigidBody3D:
	if not _check_coins():
		return null
	var look := (aim_dir if aim_dir.is_finite() else aim_direction()).normalized()
	var start := _coin_origin(aim_target.is_finite())
	var hit := aim_target if aim_target.is_finite() else aim_point()
	# Un punto detrás de ti (la cámara pegada a un muro): usa uno lejano en la dirección de la mira.
	if (hit - start).dot(look) < 0.5:
		hit = camera.global_position + look * 150.0
	var speed := COIN_SHOT_SPEED
	var dir := _landing_clamp((hit - start).normalized())
	if dir != (hit - start).normalized():
		hit = start + dir * 60.0
	# Algo fijo (suelo, pared, farola) al alcance: la moneda queda clavada al instante y el empuje empieza ya. Hace falta
	# que haya pasado la recarga del impulso. Enemigos, objetos sueltos y lo lejano van con el proyectil.
	var now := Time.get_ticks_msec()
	if now >= _anchor_ready_ms:
		var fixed := _fixed_hit(start, dir)
		if not fixed.is_empty():
			_anchor_ready_ms = now + ANCHOR_COOLDOWN_MS
			var anchor := _spawn_coin((fixed["position"] as Vector3) + (fixed["normal"] as Vector3) * 0.04)
			anchor.gravity_scale = 0.0
			anchor.freeze = true
			AirFx.wave(get_tree().current_scene, anchor.global_position, 1.0, AirFx.STEEL, 0.35, 0.03)
			_shot_point = fixed["position"]
			_shot_speed = 0.0
			visual.rotation.y = atan2(-dir.x, -dir.z)
			return anchor
	var coin := _spawn_coin(start + dir * 0.35)
	coin.gravity_scale = 0.0  # vuela en línea recta hasta el punto apuntado (se restaura en _end_coin_push)
	coin.linear_velocity = dir * speed  # sin sumar tu velocidad: así la trayectoria pasa por la mira
	_shot_point = hit
	_shot_speed = speed
	visual.rotation.y = atan2(-dir.x, -dir.z)
	Sfx.play("coin_throw", global_position + Vector3(0, 1.2, 0))
	AirFx.wave(get_tree().current_scene, start + dir * 0.5, 0.7, AirFx.STEEL, 0.28, 0.025, dir)
	return coin


## Suelta una moneda a los pies (null si no te quedan monedas).
func drop_coin(offset := Vector3.ZERO) -> RigidBody3D:
	if not _check_coins():
		return null
	return _spawn_coin(global_position + Vector3(0, 0.3, 0) + offset)


func _check_coins() -> bool:
	if dead:
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

## Ráfaga de monedas: lanza un abanico de monedas hacia donde apuntas que se abre con cada nivel hasta cerrar el
## círculo en el 15; las que se suman después salen hacia arriba y hacia abajo (ver SkillTree.burst_dirs). Gastan una
## moneda cada una.


func fire_coin_burst(aim := Vector3.INF) -> void:
	if dead or (_shield <= 0 and not _check_coins()):
		return
	var now := Time.get_ticks_msec()
	if now < _net_coin_ready_ms:
		return
	_net_coin_ready_ms = now + COIN_BURST_COOLDOWN_MS
	if _shield > 0:
		_cast("coin_wave", 0.9, 0.25, _shield_nova)
		return
	_cast("coin_wave", 0.9, 0.25, _release_burst.bind(aim))


func _release_burst(aim: Vector3) -> void:
	if not _check_coins():
		return
	# Todo sale hacia donde apunta el ratón, también hacia arriba o abajo (no a la altura del cuerpo). El abanico (y el
	# círculo) se abre a izquierda y derecha de esa dirección, vista desde la cámara; las monedas de más van hacia el
	# arriba y el abajo de esa vista. El humo del apuntado (_start_aim) usa las mismas direcciones.
	var base := _burst_aim(aim)
	var right := base.cross(Vector3.UP)
	right = right.normalized() if right.length() > 0.05 else (camera.global_basis.x if camera != null else Vector3.RIGHT)
	var view_up := right.cross(base).normalized()
	var speed := COIN_HAND_SPEED + COIN_STEEL_SPEED * allomancy.strength(&"steel")
	var start := _coin_origin(aim.is_finite())
	var level := power_level(&"steel_coin_burst")
	var count := mini(SkillTree.fan_count(level, SkillTree.BURST_MIN_LEVEL), coins_held)
	if count % 2 == 0:
		count -= 1  # con pocas monedas también sale una cantidad impar: siempre hay una al centro
	AirFx.push(get_tree().current_scene, start, base, AirFx.STEEL, 1.3)
	for d in SkillTree.burst_dirs(level, count):
		var dir := (base * cos(d.x) + right * sin(d.x)) * cos(d.y) + view_up * sin(d.y)
		var coin := _spawn_coin(start + dir * 0.5)
		coin.gravity_scale = 0.08  # casi recta: cae muy despacio, para que acierte donde apuntas
		coin.linear_velocity = dir * speed


## Escudo de monedas (acero 8): monedas del monedero que giran a tu alrededor y dan una probabilidad de desviar cada golpe
## cuerpo a cuerpo (más monedas, más probabilidad; ver SkillTree.shield_block_chance). Dura SkillTree.SHIELD_DURATION s y
## se retira solo (o pulsando otra vez): las monedas no se gastan, vuelven al monedero. Los proyectiles los para el Campo magnético. Solo en partida individual.
const SHIELD_RADIUS := 0.95
var _shield := 0
var _shield_until_ms := 0
var _shield_root: Node3D
var _shield_orbits: Array[Dictionary] = []
var _shield_spin := 0.0


func toggle_coin_shield() -> void:
	if net_peer_id != 0:
		return
	if _shield > 0:
		_dismiss_shield()
		notice.emit("Escudo de monedas guardado")
		return
	if not _check_coins():
		return
	_cast("coin_shield", 0.9, 0.0, _raise_shield)


## Lo que tardan los brazos en abrirse (ver ModelRig.open_arms): recién ahí nace el efecto.
const ARMS_OPEN_TIME := 0.18


func _raise_shield() -> void:
	_shield = mini(SkillTree.shield_count(power_level(&"steel_coin_shield")), coins_held)
	coins_held -= _shield
	_shield_until_ms = Time.get_ticks_msec() + int(SkillTree.SHIELD_DURATION * 1000.0)
	_rebuild_shield()
	AirFx.wave(get_tree().current_scene, chest_position(), SHIELD_RADIUS * 2.2, AirFx.STEEL, 0.4, 0.03)
	AirFx.shell(self, Color(AirFx.STEEL, 0.1), SHIELD_RADIUS * 1.3, func() -> bool: return _shield > 0, 1.0, 4)


## Combinación: Ráfaga o Campo magnético con el escudo puesto. El escudo revienta: sus monedas y NOVA_EXTRA_COINS más del monedero
## salen en todas direcciones, con una onda magnética que hiere y empuja alrededor.
const NOVA_EXTRA_COINS := 40
const NOVA_RADIUS := 8.0
const NOVA_DAMAGE := 25.0
const NOVA_FORCE := 14.0
func _shield_nova() -> void:
	var center := chest_position()
	var speed := COIN_HAND_SPEED + COIN_STEEL_SPEED * allomancy.strength(&"steel")
	var orbiting := _shield
	coins_held += orbiting
	_shield = 0
	_rebuild_shield()
	var count := mini(orbiting + NOVA_EXTRA_COINS, coins_held)
	for i in count:
		# Espiral de Fibonacci: reparte las direcciones parejo; solo roza el suelo, casi todo sale por encima.
		var y := lerpf(0.75, -0.25, (i + 0.5) / count)
		var around := i * 2.39996
		var flat := sqrt(1.0 - y * y)
		var dir := Vector3(cos(around) * flat, y, sin(around) * flat)
		var coin := _spawn_coin(center + dir * 0.5)
		coin.gravity_scale = 0.08
		coin.linear_velocity = dir * speed
	_magnetic_wave(center, NOVA_RADIUS, NOVA_DAMAGE, NOVA_FORCE)
	notice.emit("¡El escudo revienta!")


## Onda de choque magnética: hiere y empuja a todos en `radius` (menos cuanto más lejos).
func _magnetic_wave(center: Vector3, radius: float, damage: float, force: float) -> void:
	AirFx.ground(get_tree().current_scene, global_position, radius, AirFx.STEEL, 0.75)
	AirFx.wave(get_tree().current_scene, center, radius, AirFx.STEEL, 0.6, 0.06)
	add_trauma(0.5)
	mark_combat()
	for n in get_tree().get_nodes_in_group(&"combatant"):
		var other := n as Node3D
		if other == self or other == null or (other.has_method(&"is_down") and other.is_down()):
			continue
		var to := other.global_position - global_position
		var dist := to.length()
		if dist > radius:
			continue
		var k := 1.0 - 0.6 * dist / radius
		other.take_hit((to.normalized() + Vector3.UP * 0.35) * force * k, damage * k, self)


## Guarda de nuevo en el monedero las monedas que quedan en el escudo.
func _dismiss_shield() -> void:
	coins_held += _shield
	_shield = 0
	_rebuild_shield()


## El escudo desvía un golpe cuerpo a cuerpo: no hace daño ni empuja. Las monedas siguen girando.
func _shield_block(attacker: Node3D) -> void:
	AirFx.wave(get_tree().current_scene, chest_position(), SHIELD_RADIUS * 1.8, AirFx.STEEL, 0.3, 0.035)
	mark_combat()
	if attacker != null and attacker.has_method(&"mark_combat"):
		attacker.mark_combat()
	if attacker != null and attacker.get(&"rig"):
		attacker.get(&"rig").recoil(global_position)
	notice.emit("¡Bloqueado!")


func _rebuild_shield() -> void:
	_shield_orbits.clear()  # antes de liberar las monedas: si no, quedan referencias a nodos liberados
	if _shield_root != null:
		_shield_root.queue_free()
		_shield_root = null
	if _shield <= 0:
		return
	_shield_root = Node3D.new()
	_shield_root.position.y = 1.2
	add_child(_shield_root)
	_shield_orbits.clear()
	# La misma moneda 3D del juego (CoinKit), cinco veces más chica, con un leve brillo para que se vea de lejos.
	var mesh := CoinKit.mesh()
	var mat := CoinKit.material().duplicate() as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.5, 0.25)
	mat.emission_energy_multiplier = 0.3
	# Como el escudo de maná del mago: cada moneda recorre su propia órbita inclinada alrededor del cuerpo, con
	# otro plano, otra velocidad y otro sentido, así que se cruzan en tres dimensiones (como un átomo).
	for i in _shield:
		var pivot := Node3D.new()
		# Planos repartidos por todo el cuerpo: giro en vertical (golden angle) e inclinación entre 25° y 85°.
		var yaw := TAU * fposmod(i * 0.381966, 1.0)
		var tilt := deg_to_rad(25.0 + 60.0 * fposmod(i * 0.618034, 1.0))
		pivot.rotation = Vector3(tilt, yaw, 0.0)
		_shield_root.add_child(pivot)
		var coin := MeshInstance3D.new()
		coin.mesh = mesh
		coin.material_override = mat
		coin.position = Vector3(SHIELD_RADIUS * (0.85 + 0.12 * (i % 3)), 0.0, 0.0)
		coin.rotation = Vector3(0.0, 0.0, PI / 2.0)  # la cara mira hacia afuera
		coin.scale = Vector3.ONE * 0.2
		coin.add_child(_shield_trail())
		pivot.add_child(coin)
		pivot.rotate_object_local(Vector3.UP, TAU * i / _shield)  # cada una empieza en otro punto de su órbita
		var speed := (2.2 + 0.5 * (i % 3)) * (1.0 if i % 2 == 0 else -1.0)
		_shield_orbits.append({"pivot": pivot, "speed": speed})


## Estela dorada y difuminada que deja cada moneda del escudo al pasar (partículas suaves que quedan en el mundo y se
## desvanecen despacio).
func _shield_trail() -> GPUParticles3D:
	var trail := GPUParticles3D.new()
	trail.visible = Fx.ENABLED
	trail.amount = 10
	trail.lifetime = 0.4
	trail.local_coords = false
	trail.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.0
	pm.color_ramp = Fx.fade_ramp()
	trail.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)  # una estela apenas insinuada: suave y casi transparente
	quad.material = Fx.particle_material(Color(1.0, 0.82, 0.4, 0.035), true)
	trail.draw_pass_1 = quad
	return trail


func _update_shield(rd: float) -> void:
	if _shield > 0 and Time.get_ticks_msec() > _shield_until_ms:
		_dismiss_shield()  # se agota solo: las monedas vuelven al monedero
		notice.emit("Escudo agotado")
		return
	_shield_spin -= rd
	for orbit in _shield_orbits:
		var node: Variant = orbit["pivot"]
		if is_instance_valid(node):
			(node as Node3D).rotate_object_local(Vector3.UP, float(orbit["speed"]) * rd * (6.0 if _shield_spin > 0.0 else 1.0))


## Poderes de estaño (solo en una partida de un jugador): Foco, Marca del cazador, Mente despejada y Sentidos extremos. Los dos
## primeros y el último se ven con TinVision (siluetas a través de las paredes).
const FOCUS_FOV := 0.6
const MARK_BONUS := 1.25
const MARK_RANGE := 80.0
var _focus_until_ms := 0
var _focus_ready_ms := 0
var _mark_ready_ms := 0
var _marked: Npc
var _marked_until_ms := 0
var _clear_until_ms := 0
var _clear_ready_ms := 0
var _extreme_until_ms := 0
var _extreme_ready_ms := 0


func is_focused() -> bool:
	return Time.get_ticks_msec() < _focus_until_ms


func is_clear_minded() -> bool:
	return Time.get_ticks_msec() < _clear_until_ms


func is_extreme_senses() -> bool:
	return Time.get_ticks_msec() < _extreme_until_ms


## El enemigo marcado por la Marca del cazador (null si no hay o ya se acabó).
func marked_npc() -> Npc:
	if not is_instance_valid(_marked) or Time.get_ticks_msec() >= _marked_until_ms or _marked.down:
		return null
	return _marked


## Multiplicador del daño que le haces a ese enemigo (lo usa Npc.take_hit).
func mark_bonus(npc: Node) -> float:
	return MARK_BONUS if npc == marked_npc() else 1.0


## El enemigo más cerca de la mira (dentro de unos 9°), o null.
func _aim_npc(max_dist: float) -> Npc:
	var from := camera.global_position
	var dir := aim_direction()
	var best: Npc = null
	var best_angle := deg_to_rad(9.0)
	for n in get_tree().get_nodes_in_group(&"npc"):
		var npc := n as Npc
		if npc == null or npc.down:
			continue
		var to := npc.global_position + Vector3(0, 1.0, 0) - from
		if to.length() > max_dist:
			continue
		var angle := dir.angle_to(to)
		if angle < best_angle:
			best = npc
			best_angle = angle
	return best


func start_focus() -> bool:
	if dead or not _iron_ready(_focus_ready_ms, "Foco"):
		return false
	var now := Time.get_ticks_msec()
	_focus_ready_ms = now + int(SkillTree.FOCUS_COOLDOWN * 1000.0)
	_focus_until_ms = now + int(SkillTree.FOCUS_TIME * 1000.0)
	notice.emit("Foco")
	rig.play_skill("tin_focus", 1.6)
	AirFx.wave(get_tree().current_scene, chest_position() + Vector3(0, 0.4, 0), 1.8, AirFx.TIN, 0.45, 0.03, null, true)
	AirFx.shell(self, Color(AirFx.TIN, 0.08), 0.8, is_focused, 1.5, 3)
	return true


func start_mark() -> bool:
	if dead or not _iron_ready(_mark_ready_ms, "Marca del cazador"):
		return false
	var npc := _aim_npc(MARK_RANGE)
	if npc == null:
		notice.emit("Apunta a un enemigo")
		return false
	var now := Time.get_ticks_msec()
	_mark_ready_ms = now + int(SkillTree.MARK_COOLDOWN * 1000.0)
	_marked = npc
	_marked_until_ms = now + int(SkillTree.MARK_TIME * 1000.0)
	notice.emit("Enemigo marcado")
	rig.play_skill("hunter_mark", 1.2)
	AirFx.wave(get_tree().current_scene, npc.global_position + Vector3(0, 1.2, 0), 2.0, AirFx.TIN, 0.5, 0.03, null, true)
	AirFx.shell(npc, Color(AirFx.TIN, 0.12), 1.1, func() -> bool: return marked_npc() == npc, 1.1, 4)
	return true


## Mente despejada: se te quita al instante lo que te descontrole y por un rato casi nada puede hacerlo.
func start_clear_mind() -> bool:
	if dead or not _iron_ready(_clear_ready_ms, "Mente despejada"):
		return false
	var now := Time.get_ticks_msec()
	_clear_ready_ms = now + int(SkillTree.CLEAR_COOLDOWN * 1000.0)
	_clear_until_ms = now + int(SkillTree.CLEAR_TIME * 1000.0)
	_soothed_ms = 0
	_rioted_ms = 0
	_shoved = 0.0
	_guard_broken = false
	rig.stagger = 0.0
	if senses != null:
		senses.blinded = 0.0
	notice.emit("Mente despejada")
	rig.play_skill("clear_mind", 1.8)
	AirFx.wave(get_tree().current_scene, chest_position() + Vector3(0, 0.4, 0), 3.5, AirFx.TIN, 0.6, 0.04)
	AirFx.cloud(get_tree().current_scene, chest_position(), 1.2, AirFx.TIN, 1.0, 4, 2.5)
	return true


func start_extreme() -> bool:
	if dead or not _iron_ready(_extreme_ready_ms, "Sentidos extremos"):
		return false
	var now := Time.get_ticks_msec()
	_extreme_ready_ms = now + int(SkillTree.EXTREME_COOLDOWN * 1000.0)
	_extreme_until_ms = now + int(SkillTree.EXTREME_TIME * 1000.0)
	notice.emit("Sentidos extremos")
	rig.play_skill("extreme_senses", 2.4)
	AirFx.wave(get_tree().current_scene, chest_position() + Vector3(0, 0.4, 0), 6.0, AirFx.TIN, 0.8, 0.045, null, true)
	AirFx.shell(self, Color(AirFx.TIN, 0.1), 1.3, is_extreme_senses, 1.2, 5)
	return true


## Poderes de peltre (solo en una partida de un jugador): Embestida, Martillazo y Furia, y el efecto del Último aliento
## (que se activa solo al recibir un golpe, ver take_damage).
const CHARGE_SPEED := 19.0
const CHARGE_TIME := 0.4
const CHARGE_DAMAGE := 18.0
const SLAM_DAMAGE := 26.0
const FURY_DAMAGE := 1.3
## Último aliento: vida (fracción) por debajo de la cual salta, y la fracción de la vida máxima que te cura.
const LAST_STAND_HEALTH := 0.2
const LAST_STAND_HEAL := 0.4
var _charge_t := 0.0
var _charge_dir := Vector3.ZERO
var _charge_hit: Array = []
var _charge_ready_ms := 0
var _slam_ready_ms := 0
var _fury_ready_ms := 0
var _fury_until_ms := 0
var _fury_was_burning := false
var _last_stand_until_ms := 0
var _last_stand_ready_ms := 0


func _fury_mult() -> float:
	return FURY_DAMAGE if _fury_until_ms > 0 else 1.0


## Embestida: te lanzas hacia donde miras y llevas por delante a quien toques (golpe, empujón y aturdimiento).
func start_charge() -> void:
	if dead or _swimming or _hanging or not _iron_ready(_charge_ready_ms, "Embestida"):
		return
	_charge_ready_ms = Time.get_ticks_msec() + int(SkillTree.CHARGE_COOLDOWN * 1000.0)
	var dir := aim_direction()
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else -visual.global_basis.z
	_charge_dir = dir
	_charge_t = CHARGE_TIME
	_charge_hit.clear()
	visual.rotation.y = atan2(-dir.x, -dir.z)
	rig.play_dash(CHARGE_TIME + 0.1)
	Sfx.play("roll", global_position)
	AirFx.ground(get_tree().current_scene, global_position, 2.5, AirFx.ASH, 0.45)
	AirFx.wave(get_tree().current_scene, chest_position() + dir * 0.8, 1.6, AirFx.PEWTER, 0.35, 0.04, dir)
	AirFx.trail(self, Color(AirFx.ASH, 0.2), 1.3, func() -> bool: return _charge_t > 0.0, 0.7)


## Martillazo: una onda de choque en el suelo que daña, empuja y aturde a todos los que te rodean.
func start_slam() -> void:
	if dead or not _iron_ready(_slam_ready_ms, "Martillazo"):
		return
	if not is_on_floor():
		notice.emit("El Martillazo se hace en el suelo")
		return
	_slam_ready_ms = Time.get_ticks_msec() + int(SkillTree.SLAM_COOLDOWN * 1000.0)
	rig.play_land(1.0)
	get_tree().create_timer(0.3, true, false, true).timeout.connect(_slam_hit)


func _slam_hit() -> void:
	if dead:
		return
	var strength := (1.0 + 0.75 * allomancy.strength(&"pewter")) * _fury_mult()
	var scene := get_tree().current_scene
	var hit := false
	for n in get_tree().get_nodes_in_group(&"npc"):
		var npc := n as Npc
		if npc == null or npc.down:
			continue
		var to := npc.global_position - global_position
		if absf(to.y) > 2.5:
			continue
		to.y = 0.0
		if to.length() > SkillTree.SLAM_RADIUS:
			continue
		hit = true
		var away := to.normalized() if to.length() > 0.1 else -visual.global_basis.z
		npc.take_hit(away * 16.0, SLAM_DAMAGE * strength, self)
		npc.stun(1.2, global_position)
		AirFx.impact(scene, npc.global_position + Vector3(0, 1.0, 0), AirFx.ASH, 1.1)
	for n in get_tree().get_nodes_in_group(&"metal"):
		var rb := n as RigidBody3D
		if rb != null and rb.global_position.distance_to(global_position) <= SkillTree.SLAM_RADIUS:
			rb.apply_central_impulse((rb.global_position - global_position).normalized() * minf(rb.mass, 20.0) * 8.0)
	Sfx.play("land_heavy", global_position)
	AirFx.ground(scene, global_position, SkillTree.SLAM_RADIUS * 1.3, AirFx.ASH, 0.8)
	AirFx.ground(scene, global_position, SkillTree.SLAM_RADIUS, AirFx.PEWTER, 0.5)
	add_trauma(0.8)
	# Solo si le pegó a alguien: si no, quedaba 6 s en guardia de puños (COMBAT_TIMEOUT) tras golpear el piso solo,
	# como la Embestida, que también marca el combate solo al pegar.
	if hit:
		mark_combat()


## Furia: durante SkillTree.FURY_TIME el peltre arde avivado sin gastar metal y pegas más fuerte; al terminar quedas sin aliento.
func start_fury() -> void:
	if dead or not _iron_ready(_fury_ready_ms, "Furia"):
		return
	if _pewter_drag > 0.0:
		notice.emit("No puedes quemar peltre ahora")
		return
	var now := Time.get_ticks_msec()
	_fury_ready_ms = now + int(SkillTree.FURY_COOLDOWN * 1000.0)
	_fury_until_ms = now + int(SkillTree.FURY_TIME * 1000.0)
	_fury_was_burning = allomancy.is_burning(&"pewter")
	notice.emit("¡Furia!")
	rig.play_skill("fury", 2.0)
	add_trauma(0.5)
	AirFx.wave(get_tree().current_scene, chest_position(), 4.5, AirFx.PEWTER, 0.6, 0.05)
	AirFx.shell(self, AirFx.PEWTER, 1.6, func() -> bool: return _fury_until_ms > 0, 1.0, 6)


## Cada fotograma: la embestida golpea a lo que toca y la Furia mantiene el peltre avivado y lleno.
func _update_pewter_powers(rd: float) -> void:
	var now := Time.get_ticks_msec()
	if _charge_t > 0.0:
		var strength := (1.0 + 0.75 * allomancy.strength(&"pewter")) * _fury_mult()
		for n in get_tree().get_nodes_in_group(&"npc"):
			var npc := n as Npc
			if npc == null or npc.down or npc in _charge_hit:
				continue
			var to := npc.global_position - global_position
			if absf(to.y) > 2.0:
				continue
			to.y = 0.0
			if to.length() > 1.8 or (to.length() > 0.3 and _charge_dir.dot(to.normalized()) < 0.2):
				continue
			_charge_hit.append(npc)
			npc.take_hit(_charge_dir * 14.0, CHARGE_DAMAGE * strength, self)
			npc.stun(1.5, global_position)
			Sfx.play("punch_heavy", npc.global_position + Vector3(0, 1.2, 0))
			AirFx.impact(get_tree().current_scene, npc.global_position + Vector3(0, 1.2, 0), AirFx.PEWTER, 1.5)
			add_trauma(0.3)
			mark_combat()
	if _fury_until_ms > 0:
		if now < _fury_until_ms and not dead:
			allomancy.reserve[&"pewter"] = allomancy.max_reserve(&"pewter")
			if not allomancy.is_flaring(&"pewter"):
				allomancy.set_state(&"pewter", Allomancy.State.FLARE)
		else:
			_fury_until_ms = 0
			allomancy.set_state(&"pewter", Allomancy.State.BURN if _fury_was_burning and not dead else Allomancy.State.OFF)
			if not dead:
				stamina = 0.0
				_exhausted = true
				notice.emit("La Furia se apaga")


## Poderes de hierro de un toque (solo en una partida de un jugador, como el escudo): Arrastre, Gancho, Desarme y
## Atracción masiva. Las recargas son SkillTree.*_COOLDOWN.
const DRAG_SPEED := 16.0
const DRAG_TIME_MS := 1500
const DRAG_STOP := 2.0
const DRAG_STUN := 1.0
const YANK_STOP := 3.0
const YANK_STUN := 1.2
const HOOK_TIME_MS := 1600
const HOOK_ACCEL := 80.0
const HOOK_MAX_SPEED := 28.0
const HOOK_EXIT_SPEED := 12.0
const HOOK_SAFE_MS := 1000
## Velocidad de caída (m/s) a la que la soga te retiene, y cuánto frena por segundo (el umbral sin daño es 12 m/s).
const HOOK_FALL_CAP := 16.0
const HOOK_FALL_BRAKE := 45.0
var _hook_safe_ms := 0
var _hook_rope: MeshInstance3D
var _drag_ready_ms := 0
var _hook_ready_ms := 0
var _disarm_ready_ms := 0
var _yank_ready_ms := 0
var _drags: Array[Dictionary] = []
var _hook_pos := Vector3.INF
var _hook_until_ms := 0


## True si ya puede usarse; si no, avisa de cuánto falta.
func _iron_ready(ready_ms: int, what: String) -> bool:
	var now := Time.get_ticks_msec()
	if now < ready_ms:
		notice.emit("%s recargando (%d s)" % [what, ceili((ready_ms - now) / 1000.0)])
		return false
	return true


## Un enemigo que se puede arrastrar: con metal, en pie, que pese hasta tu poder de tirón y con línea de visión.
func _can_yank(n: Node3D, announce: bool) -> bool:
	var npc := n as Npc
	if npc == null or npc.down or not npc.is_in_group(&"metal"):
		return false
	if Metals.movable_mass(npc) > SkillTree.power_mass(power_level(&"iron_pull"), body_mass):
		if announce:
			notice.emit("Pesa demasiado para tu poder de tirón")
		return false
	var query := PhysicsRayQueryParameters3D.create(chest_position(), npc.global_position + Vector3(0, 1.0, 0), Props.LAYER_WORLD, [get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		if announce:
			notice.emit("Algo se interpone")
		return false
	return true


func _begin_drag(npc: Npc, stop: float, stun_time: float) -> void:
	for d in _drags:
		if d["npc"] == npc:
			_drags.erase(d)
			break
	_drags.append({"npc": npc, "until_ms": Time.get_ticks_msec() + DRAG_TIME_MS, "stop": stop, "stun": stun_time})
	AirFx.pull(get_tree().current_scene, npc.global_position + Vector3(0, 1.2, 0), chest_position(), AirFx.IRON)
	AirFx.trail(npc, Color(AirFx.IRON, 0.12), 1.2, func() -> bool: return _drags.any(func(d: Dictionary) -> bool: return d["npc"] == npc))


## Arrastre: tira del enemigo que apuntas hacia ti y lo deja aturdido al llegar.
func start_iron_drag() -> void:
	if dead or not _iron_ready(_drag_ready_ms, "Arrastre"):
		return
	var t := steel_iron.aim_target()
	if t == null or not (t is Npc):
		notice.emit("Apunta a un enemigo con metal")
		return
	if not _can_yank(t, true):
		return
	_drag_ready_ms = Time.get_ticks_msec() + int(SkillTree.DRAG_COOLDOWN * 1000.0)
	_begin_drag(t as Npc, DRAG_STOP, DRAG_STUN)
	rig.play_skill("iron_drag", 2.4)


## Atracción masiva: arrastra a todos los enemigos con metal cercanos hasta un anillo a tu alrededor.
func start_mass_yank() -> void:
	if dead or not _iron_ready(_yank_ready_ms, "Atracción masiva"):
		return
	var got := 0
	for n in get_tree().get_nodes_in_group(&"metal"):
		var npc := n as Npc
		if npc != null and npc.global_position.distance_to(global_position) <= SkillTree.YANK_RADIUS and _can_yank(npc, false):
			_begin_drag(npc, YANK_STOP, YANK_STUN)
			got += 1
	if got == 0:
		notice.emit("No hay enemigos con metal a tu alcance")
		return
	_yank_ready_ms = Time.get_ticks_msec() + int(SkillTree.YANK_COOLDOWN * 1000.0)
	rig.play_skill("mass_yank", 1.0)
	AirFx.ground(get_tree().current_scene, global_position, SkillTree.YANK_RADIUS, AirFx.IRON, 0.8, true)


## Gancho: clava una moneda en cualquier superficie fija que apuntes (hasta SkillTree.HOOK_RANGE) y te tira hacia ella
## con una soga. Frena al llegar y, un momento después, los golpes casi no te lastiman (HOOK_SAFE_MS).
func start_iron_hook() -> void:
	if dead or not _iron_ready(_hook_ready_ms, "Gancho") or not _check_coins():
		return
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + aim_direction() * (SkillTree.HOOK_RANGE + 4.0), Props.LAYER_WORLD | Props.LAYER_PROPS, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var body: Object = hit.get("collider")
	if hit.is_empty() or body is CharacterBody3D or (body is RigidBody3D and not (body as RigidBody3D).freeze):
		notice.emit("Apunta a una superficie fija a menos de %d m" % int(SkillTree.HOOK_RANGE))
		return
	var point: Vector3 = hit["position"]
	if point.distance_to(chest_position()) > SkillTree.HOOK_RANGE:
		notice.emit("Está demasiado lejos")
		return
	var los := PhysicsRayQueryParameters3D.create(chest_position(), point + (hit["normal"] as Vector3) * 0.1, Props.LAYER_WORLD, [get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(los).is_empty():
		notice.emit("Algo se interpone")
		return
	_hook_ready_ms = Time.get_ticks_msec() + int(SkillTree.HOOK_COOLDOWN * 1000.0)
	var anchor := _spawn_coin(point + (hit["normal"] as Vector3) * 0.04)
	anchor.gravity_scale = 0.0
	anchor.freeze = true
	var life := Timer.new()
	life.wait_time = 5.0
	life.one_shot = true
	life.autostart = true
	life.timeout.connect(anchor.queue_free)
	anchor.add_child(life)
	_hook_pos = point
	_hook_until_ms = Time.get_ticks_msec() + HOOK_TIME_MS
	AirFx.pull(get_tree().current_scene, point, chest_position(), AirFx.IRON, 1.1)
	AirFx.trail(self, Color(AirFx.IRON, 0.1), 1.0, func() -> bool: return _hook_pos.is_finite())
	if _hook_rope == null:
		_hook_rope = MeshInstance3D.new()
		var rope_mesh := CylinderMesh.new()
		rope_mesh.top_radius = 0.015
		rope_mesh.bottom_radius = 0.015
		rope_mesh.height = 1.0
		rope_mesh.radial_segments = 6
		_hook_rope.mesh = rope_mesh
		_hook_rope.material_override = Props.material(Color(0.42, 0.3, 0.18), 0.0, 0.9)
		_hook_rope.top_level = true
		add_child(_hook_rope)
	_hook_rope.visible = true
	var dir := (point - chest_position()).normalized()
	visual.rotation.y = atan2(-dir.x, -dir.z)
	rig.play_throw()
	if is_on_floor():
		velocity.y = maxf(velocity.y, 4.0)


## La superficie fija que el Gancho podría agarrar ahora mismo (en alcance y a la vista); vacío si no hay.
func _hook_aim() -> Dictionary:
	var from := camera.global_position
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + aim_direction() * (SkillTree.HOOK_RANGE + 4.0), Props.LAYER_WORLD | Props.LAYER_PROPS, [get_rid()]))
	if hit.is_empty():
		return {}
	var body: Object = hit["collider"]
	if body is CharacterBody3D or (body is RigidBody3D and not (body as RigidBody3D).freeze):
		return {}
	var point: Vector3 = hit["position"]
	if point.distance_to(chest_position()) > SkillTree.HOOK_RANGE:
		return {}
	var los := PhysicsRayQueryParameters3D.create(chest_position(), point + (hit["normal"] as Vector3) * 0.1, Props.LAYER_WORLD, [get_rid()])
	return {} if not space.intersect_ray(los).is_empty() else hit


## Estira la soga del gancho entre tu pecho y la moneda clavada.
func _update_hook_rope() -> void:
	if _hook_rope == null or not _hook_rope.visible:
		return
	var a := chest_position() + Vector3(0, -0.1, 0)
	var span := _hook_pos - a
	if not _hook_pos.is_finite() or span.length() < 0.1:
		_hook_rope.visible = false
		return
	var y := span.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	_hook_rope.global_transform = Transform3D(Basis(x, y * span.length(), z), a + span * 0.5)


## Te sacan el arma (el Desarme del Lord Legislador): quedas a puños; la volvés a sacar con la rueda.
func lose_weapon() -> void:
	if dead or weapon == HumanoidRig.Weapon.NONE:
		return
	weapon = HumanoidRig.Weapon.NONE
	_fists_chosen = true
	_auto_drawn = false
	rig.set_weapon(weapon)
	notice.emit("¡Te sacaron el arma!")


## Desarme: el arma del enemigo que apuntas sale despedida y cae al piso a mitad de camino entre él y tú.
func start_disarm() -> void:
	if dead or not _iron_ready(_disarm_ready_ms, "Desarme"):
		return
	var npc := steel_iron.aim_target() as Npc
	if npc == null or not npc.is_armed():
		notice.emit("Apunta a un enemigo con arma de metal")
		return
	_disarm_ready_ms = Time.get_ticks_msec() + int(SkillTree.DISARM_COOLDOWN * 1000.0)
	npc.disarm(SkillTree.DISARM_SECONDS)
	rig.play_skill("disarm", 1.0)
	var from := npc.global_position + Vector3(0, 1.2, 0)
	AirFx.pull(get_tree().current_scene, from, chest_position(), AirFx.IRON, 0.8)
	var mid := (npc.global_position + global_position) * 0.5
	var down := PhysicsRayQueryParameters3D.create(mid + Vector3(0, 3.0, 0), mid + Vector3(0, -6.0, 0), Props.LAYER_WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(down)
	mid.y = (hit["position"].y if not hit.is_empty() else npc.global_position.y) + 0.15
	var weapon := Props.dropped_weapon()
	get_parent().add_child(weapon)
	weapon.global_position = from
	weapon.rotation.y = randf() * TAU
	# Vuelo de 0,6 s con gravedad normal: aterriza en el punto medio.
	var t_fly := 0.6
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var flat := Vector3(mid.x - from.x, 0.0, mid.z - from.z) / t_fly
	weapon.linear_velocity = Vector3(flat.x, (mid.y - from.y + 0.5 * g * t_fly * t_fly) / t_fly, flat.z)
	weapon.angular_velocity = Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
	var life := Timer.new()
	life.wait_time = 40.0
	life.one_shot = true
	life.autostart = true
	life.timeout.connect(weapon.queue_free)
	weapon.add_child(life)


## Cada fotograma: lleva a los arrastrados hacia ti y, mientras dura, tira de ti hacia el gancho.
func _update_iron_powers(delta: float, rd: float) -> void:
	var now := Time.get_ticks_msec()
	for i in range(_drags.size() - 1, -1, -1):
		var d := _drags[i]
		var raw: Variant = d["npc"]
		if not is_instance_valid(raw) or (raw as Npc).down:
			_drags.remove_at(i)
			continue
		var npc := raw as Npc
		var to := chest_position() - npc.global_position
		var flat := Vector2(to.x, to.z).length()
		if flat <= float(d["stop"]) or now >= int(d["until_ms"]):
			npc.stun(float(d["stun"]), global_position)
			_drags.remove_at(i)
			continue
		npc.pull_toward(to, DRAG_SPEED, delta)
	if _hook_pos.is_finite():
		var pull := _hook_pos - chest_position()
		if now >= _hook_until_ms or pull.length() < 2.5 or dead:
			# Llegaste (o se cortó): frenas y por un momento los golpes casi no duelen.
			_hook_pos = Vector3.INF
			velocity = velocity.limit_length(HOOK_EXIT_SPEED)
			_hook_safe_ms = now + HOOK_SAFE_MS
		else:
			_hook_safe_ms = now + HOOK_SAFE_MS
			add_allomantic_acceleration(pull.normalized() * HOOK_ACCEL, rd)
			# La soga retiene la caída, pero no del todo: una caída larga sigue lastimando.
			if velocity.y < -HOOK_FALL_CAP:
				velocity.y = move_toward(velocity.y, -HOOK_FALL_CAP, HOOK_FALL_BRAKE * rd)
			# Cerca de la pared frenas de a poco para no estrellarte.
			velocity = velocity.limit_length(minf(HOOK_MAX_SPEED, maxf(pull.length() * 3.5, 9.0)))
	_update_hook_rope()


## Lanza de acero (acero 20): gasta 5 monedas en un solo proyectil muy rápido y pesado que atraviesa hasta 4 enemigos,
## con mucho daño y empuje. Recarga SkillTree.SPEAR_COOLDOWN.
var _spear_ready_ms := 0


## El gesto de la lanza a la velocidad propia del clip: más rápido no se lee.
const SPEAR_CAST_TIME := 1.5


func fire_steel_spear(aim := Vector3.INF) -> void:
	if dead or not _check_coins():
		return
	var now := Time.get_ticks_msec()
	if now < _spear_ready_ms:
		notice.emit("Lanza de acero recargando (%d s)" % ceili((_spear_ready_ms - now) / 1000.0))
		return
	if coins_held < SkillTree.SPEAR_COST:
		notice.emit("La lanza necesita %d monedas" % SkillTree.SPEAR_COST)
		return
	_spear_ready_ms = now + int(SkillTree.SPEAR_COOLDOWN * 1000.0)
	var dir := _burst_aim(aim)
	visual.rotation.y = atan2(-dir.x, -dir.z)
	_cast("spear", SPEAR_CAST_TIME, 0.0, _launch_spear.bind(aim))


func _launch_spear(aim: Vector3) -> void:
	if coins_held < SkillTree.SPEAR_COST:
		return
	coins_held -= SkillTree.SPEAR_COST - 1  # _spawn_coin descuenta la última
	var dir := _burst_aim(aim)
	var spear := _spawn_coin(_coin_origin(aim.is_finite()) + dir * 0.6) as Coin
	spear.gravity_scale = 0.0
	spear.mass = 0.5
	spear.linear_damp = 0.0
	spear.pierce_left = 4
	spear.hit_power = 2.0
	spear.linear_velocity = dir * SkillTree.SPEAR_SPEED
	AirFx.push(get_tree().current_scene, spear.global_position, dir, AirFx.STEEL, 1.7)
	AirFx.trail(spear, Color(AirFx.STEEL, 0.12), 0.6, Callable(), 0.0)
	visual.rotation.y = atan2(-dir.x, -dir.z)
	get_tree().create_timer(3.0).timeout.connect(spear.queue_free)


## Campo magnético (acero 12): durante unos segundos las monedas y proyectiles metálicos que se acercan a ti se
## desvían y vuelven hacia quien los lanzó, con el mismo daño.
var _field_until_ms := 0
var _field_ready_ms := 0
## Visible mientras dura el campo (la bruma es de AirFx.shell).
var _field_shell: Node3D


func activate_magnetic_field() -> void:
	if dead:
		return
	var now := Time.get_ticks_msec()
	if now < _field_ready_ms:
		notice.emit("Campo magnético recargando (%d s)" % ceili((_field_ready_ms - now) / 1000.0))
		return
	_field_until_ms = now + int(SkillTree.FIELD_DURATION * 1000.0 + ARMS_OPEN_TIME * 1000.0)
	_field_ready_ms = now + int(SkillTree.FIELD_COOLDOWN * 1000.0)
	_cast("field", 1.0, 0.0, _raise_field)


func _raise_field() -> void:
	if _field_shell == null:
		_field_shell = Node3D.new()
		add_child(_field_shell)
	_field_shell.visible = true
	AirFx.wave(get_tree().current_scene, chest_position(), SkillTree.FIELD_RADIUS, AirFx.STEEL, 0.5, 0.045)
	AirFx.shell(self, Color(AirFx.STEEL, 0.09), SkillTree.FIELD_RADIUS * 0.8, func() -> bool: return _field_shell.visible, 1.0, 6, SkillTree.FIELD_RADIUS * 1.15)
	if _shield > 0:
		_shield_nova()


func _update_field() -> void:
	if _field_shell == null or not _field_shell.visible:
		return
	if dead or Time.get_ticks_msec() > _field_until_ms:
		_field_shell.visible = false
		return
	var center := chest_position()
	for n in get_tree().get_nodes_in_group(&"coin"):
		var coin := n as Coin
		if coin == null or coin.puppet or coin.shooter == self or coin.freeze:
			continue
		var to_me := center - coin.global_position
		var dist := to_me.length()
		var speed := coin.linear_velocity.length()
		if dist > SkillTree.FIELD_RADIUS or speed < 8.0 or coin.linear_velocity.dot(to_me) <= 0.0:
			continue
		# Vuelve hacia quien la lanzó (o hacia donde vino) y desde ahora es tuya: hiere a los demás.
		var back := -coin.linear_velocity.normalized()
		if is_instance_valid(coin.shooter):
			back = (Metals.center_of(coin.shooter) - coin.global_position).normalized()
		coin.linear_velocity = back * speed * 1.1
		coin.gravity_scale = 0.0
		coin.shooter = self
		AirFx.impact(get_tree().current_scene, coin.global_position, AirFx.STEEL, 0.8)


## Dirección hacia donde apunta el ratón desde el pecho (la mandó el cliente en red, o se calcula aquí).
func _burst_aim(aim: Vector3) -> Vector3:
	if aim.is_finite() and aim.length() > 0.5:
		return aim.normalized()
	return aim_direction().normalized()  # la de la cámara: pasa justo por el centro de la mira


## Desde dónde salen las monedas que van a la mira: el punto de la línea de la cámara más cercano al pecho. Así la moneda
## del medio viaja por la misma línea que ve la cámara y se ve justo en el centro del puntero, sin quedar desviada hacia el
## costado del personaje. En red (la dirección la manda el cliente) sale del pecho.
func _coin_origin(from_network := false) -> Vector3:
	var chest := chest_position()
	if from_network or camera == null:
		return chest
	var look := aim_direction().normalized()
	return camera.global_position + look * maxf((chest - camera.global_position).dot(look), 0.5)


## Imán de monedas (con hierro encendido): las monedas sueltas del abanico vuelan hacia ti y se guardan al tocarte.
func start_gather(aim := Vector3.INF) -> void:
	if dead:
		return
	if allomancy.strength(&"iron") <= 0.0:
		notice.emit("Sin hierro encendido no se pueden atraer monedas")
		return
	_stop_gather()
	var chest := chest_position()
	var blast := _field_shell != null and _field_shell.visible and Time.get_ticks_msec() < _field_until_ms
	# Imán de monedas: las más cercanas dentro del abanico hacia adelante (crece con su nivel; todas si es radial).
	var level := power_level(&"iron_coin_magnet")
	var angle := TAU if blast else SkillTree.fan_angle(level)
	var base := _burst_aim(aim)  # el abanico apunta hacia donde apunta el ratón
	var front := Vector3(base.x, 0.0, base.z)
	front = front.normalized() if front.length() > 0.1 else -visual.global_basis.z
	var found := []
	for n in get_tree().get_nodes_in_group(&"coin"):
		var coin := n as Coin
		if coin == null or coin.puppet or coin == steel_iron.auto_push:
			continue
		var to := coin.global_position - chest
		var dist := to.length()
		if dist > GATHER_RADIUS:
			continue
		to.y = 0.0
		if angle < TAU and to.length() > 0.5 and front.angle_to(to) > angle * 0.5:
			continue
		found.append([dist, coin])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for entry in found.slice(0, found.size() if angle >= TAU else SkillTree.fan_count(level)):
		var pulled: Coin = entry[1]
		pulled.pull_owner = self
		pulled.add_collision_exception_with(self)
		_gathering.append(pulled)
	_gather_until_ms = Time.get_ticks_msec() + GATHER_MS
	if _gathering.is_empty():
		notice.emit("No hay monedas cerca")
	else:
		rig.play_skill("coin_magnet", 0.9)
		AirFx.wave(get_tree().current_scene, chest + base * 0.5, 2.6, AirFx.IRON, 0.55, 0.035, null, true)
		_gather_blast_ms = Time.get_ticks_msec() + BLAST_WAIT_MS if blast else 0


## Combinación: Imán con el Campo puesto. Todas las monedas cerca vienen y se juntan contra el campo; cuando llegan
## (o pasados BLAST_WAIT_MS) rebotan hacia afuera con daño, el campo se rompe y sale una onda de choque.
const BLAST_WAIT_MS := 1100
const BLAST_DAMAGE := 20.0
const BLAST_FORCE := 16.0
const BLAST_COIN_SPEED := 34.0
var _gather_blast_ms := 0


func _field_blast() -> void:
	var center := chest_position()
	var sparks := 0
	for coin in _gathering:
		if not is_instance_valid(coin):
			continue
		var out := (coin.global_position - center).normalized()
		coin.pull_owner = null
		coin.shooter = self
		coin.gravity_scale = 0.08
		coin.linear_velocity = out * BLAST_COIN_SPEED
		if sparks < 15:
			sparks += 1
			Fx.sparks(get_tree().current_scene, coin.global_position, Color(0.45, 0.7, 1.0))
	_gathering.clear()
	_gather_blast_ms = 0
	_field_until_ms = Time.get_ticks_msec()
	_magnetic_wave(center, SkillTree.FIELD_RADIUS * 2.0, BLAST_DAMAGE, BLAST_FORCE)
	rig.open_arms(0.5, 0.1, 0.1)
	notice.emit("¡El campo se rompe!")


## Mantiene las monedas atraídas yendo hacia ti (sin gravedad); termina al pasar GATHER_MS.
func _update_gather() -> void:
	if _gathering.is_empty():
		return
	if Time.get_ticks_msec() > _gather_until_ms:
		_stop_gather()
		return
	var chest := chest_position()
	var alive: Array[Coin] = []
	var waiting := false
	for coin in _gathering:
		if not is_instance_valid(coin):
			continue
		alive.append(coin)
		coin.set_deferred(&"freeze", false)
		coin.gravity_scale = 0.0
		var to := chest - coin.global_position
		if _gather_blast_ms > 0 and to.length() < SkillTree.FIELD_RADIUS * 0.6:
			coin.linear_velocity = Vector3.ZERO  # queda pegada al campo hasta que reviente
		else:
			waiting = true
			coin.linear_velocity = to.normalized() * GATHER_SPEED
	_gathering = alive
	if _gather_blast_ms > 0 and not alive.is_empty() and (not waiting or Time.get_ticks_msec() > _gather_blast_ms):
		_field_blast()


func _stop_gather() -> void:
	for coin in _gathering:
		if is_instance_valid(coin):
			coin.gravity_scale = 1.0
	_gathering.clear()
	_gather_blast_ms = 0

## Recoge las monedas quietas del suelo que tengas bajo los pies.
## No recoge las que estás usando (agarradas con acero/hierro) ni las que acabas de soltar o lanzar y
## todavía no se alejaron de ti (ver Coin.pickable): así la moneda que dejas bajo los pies para
## impulsarte no te la guardas de nuevo, y al caer de vuelta sí.
## Las que traes con hierro (E sobre una moneda) o con Alt+E (ver start_gather) se guardan en cuanto te
## tocan (a menos de COIN_CATCH_DIST del pecho), aunque vayan rápido.
func _collect_coins() -> void:
	if dead or coins_held >= COIN_MAX:
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
