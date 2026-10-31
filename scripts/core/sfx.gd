class_name Sfx
extends Node
## Sonidos del juego. Un solo nodo que se crea solo la primera vez que se usa (cuelga de la raíz y
## dura toda la partida). Los archivos: assets/audio/kenney (packs de Kenney, CC0) y
## assets/audio/synth (hechos con tools/synth_sfx.py: ambiente, chapoteos y alomancia).
##   Sfx.play("punch", posición)  -> una variante al azar con el tono un poco cambiado, en 3D.
##   Sfx.play("click")            -> sin posición: en 2D (interfaz, metales del jugador).
##   Sfx.step(cuerpo)             -> un paso según el suelo que tiene debajo.
##   Sfx.loop(nodo, "fire_loop")  -> un bucle pegado a un nodo (braseros, el río).
## Canales: SFX (con eco bajo techo), Ambiente (viento, lluvia, vuelo) e UI. Los botones de la
## interfaz hacen clic solos.

const KENNEY := "res://assets/audio/kenney/"
const SYNTH := "res://assets/audio/synth/"
const BUSES := ["SFX", "Ambiente", "UI"]
const POOL_3D := 32
const POOL_2D := 8

static var _inst: Sfx

var _bank := {}  # nombre -> [Array[AudioStream], volumen dB, variación de tono, canal]
var _pool3: Array[AudioStreamPlayer3D] = []
var _pool2: Array[AudioStreamPlayer] = []
var _next3 := 0
var _next2 := 0
var _wind: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _fly: AudioStreamPlayer
var _reverb: AudioEffectReverb


func _enter_tree() -> void:
	for b: String in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	# Eco de sala bajo techo (lo sube _process cuando Weather.sheltered).
	_reverb = AudioEffectReverb.new()
	_reverb.room_size = 0.6
	_reverb.damping = 0.6
	_reverb.wet = 0.0
	_reverb.dry = 1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), _reverb)


static func _instance() -> Sfx:
	if not is_instance_valid(_inst):
		_inst = Sfx.new()
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_inst)
	return _inst


func _init() -> void:
	_add("step_stone", _seq("footstep_concrete_%03d.ogg", 0, 5), -12.0, 0.08)
	_add("step_wood", _seq("footstep_wood_%03d.ogg", 0, 5), -11.0, 0.08)
	_add("step_dirt", _seq("footstep%02d.ogg", 0, 10), -10.0, 0.08)
	_add("step_metal", _seq("impactMetal_light_%03d.ogg", 0, 5), -20.0, 0.1)
	_add("step_water", _seq("splash_%d.wav", 0, 4, SYNTH), -12.0, 0.1)
	_add("land_soft", _seq("impactSoft_medium_%03d.ogg", 0, 5), -6.0, 0.06)
	_add("land_heavy", _seq("impactSoft_heavy_%03d.ogg", 0, 5), -1.0, 0.05)
	_add("jump", _seq("cloth%d.ogg", 1, 4), -12.0, 0.1)
	_add("roll", _seq("whoosh_%d.wav", 0, 3, SYNTH), -10.0, 0.1)
	_add("swing", _seq("whoosh_%d.wav", 0, 3, SYNTH), -7.0, 0.15)
	_add("punch", _seq("impactPunch_medium_%03d.ogg", 0, 5), -3.0, 0.08)
	_add("punch_heavy", _seq("impactPunch_heavy_%03d.ogg", 0, 5), -1.0, 0.06)
	_add("slash", [KENNEY + "knifeSlice.ogg", KENNEY + "knifeSlice2.ogg"], -3.0, 0.1)
	_add("clash", _seq("impactMetal_heavy_%03d.ogg", 0, 5), -4.0, 0.08)
	_add("hurt", _seq("impactSoft_heavy_%03d.ogg", 0, 5), -3.0, 0.1)
	_add("coin_throw", [KENNEY + "handleCoins.ogg", KENNEY + "handleCoins2.ogg"], -9.0, 0.1)
	_add("coin_metal", _seq("impactTin_medium_%03d.ogg", 0, 5), -12.0, 0.15)
	_add("coin_stone", _seq("impactGeneric_light_%03d.ogg", 0, 5) + _seq("impactPlate_light_%03d.ogg", 0, 5), -14.0, 0.2)
	_add("coin_hit", _seq("impactPunch_medium_%03d.ogg", 0, 5), -5.0, 0.1)
	_add("steel_push", _seq("steel_push_%d.wav", 0, 3, SYNTH), -5.0, 0.06)
	_add("iron_pull", _seq("iron_pull_%d.wav", 0, 3, SYNTH), -5.0, 0.06)
	_add("burn_on", [SYNTH + "burn_on.wav"], -14.0, 0.1)
	_add("burn_off", [SYNTH + "burn_off.wav"], -16.0, 0.1)
	_add("flare", [SYNTH + "flare.wav"], -6.0, 0.05)
	_add("atium", [SYNTH + "atium.wav"], -8.0, 0.02)
	_add("bronze_pulse", [SYNTH + "bronze_pulse.wav"], -10.0, 0.05)
	_add("bell", _seq("impactBell_heavy_%03d.ogg", 0, 5), 0.0, 0.02)
	_add("drink", _seq("glass_%03d.ogg", 1, 4), -8.0, 0.05, "UI")
	_add("pickup", _seq("confirmation_%03d.ogg", 1, 4), -8.0, 0.0, "UI")
	_add("click", _seq("click_%03d.ogg", 1, 5), -12.0, 0.05, "UI")
	for loop: String in ["wind_loop", "fly_wind_loop", "rain_loop", "river_loop", "fire_loop", "steel_hum_loop"]:
		_add(loop, [SYNTH + loop + ".wav"], 0.0, 0.0, "Ambiente")


func _ready() -> void:
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 6.0
		p.max_distance = 70.0
		_pool3.append(p)
		add_child(p)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		_pool2.append(p)
		add_child(p)
	_wind = _ambient("wind_loop")
	_rain = _ambient("rain_loop")
	_fly = _ambient("fly_wind_loop")
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is BaseButton:
			(n as BaseButton).pressed.connect(func() -> void: _play("click", null, 0.0, 70.0)))


func _seq(pattern: String, from: int, count: int, dir := KENNEY) -> Array:
	var out := []
	for i in range(from, from + count):
		out.append(dir + pattern % i)
	return out


func _add(name: String, files: Array, db: float, pitch_var: float, bus := "SFX") -> void:
	var streams: Array[AudioStream] = []
	for f: String in files:
		if ResourceLoader.exists(f):
			var s := load(f) as AudioStream
			if s is AudioStreamWAV and name.ends_with("_loop"):
				var w := s as AudioStreamWAV
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_begin = 0
				w.loop_end = int(w.get_length() * w.mix_rate)
			streams.append(s)
	_bank[name] = [streams, db, pitch_var, bus]


## Lo crea si todavía no existe (para que arranquen el viento y la lluvia sin esperar otro sonido).
static func start() -> void:
	_instance()


static func stream(name: String) -> AudioStream:
	return _instance()._stream(name)


## Suena `name` en `pos` (3D) o sin posición (2D). vol: dB que se suman al del banco.
static func play(name: String, pos: Variant = null, vol := 0.0, max_distance := 70.0) -> void:
	_instance()._play(name, pos, vol, max_distance)


func _stream(name: String) -> AudioStream:
	var e: Array = _bank.get(name, [[]])
	return null if e[0].is_empty() else e[0].pick_random()


func _play(name: String, pos: Variant, vol: float, max_distance: float) -> void:
	if not _bank.has(name) or _bank[name][0].is_empty() or _pool3.is_empty():
		return
	var e: Array = _bank[name]
	var pitch := 1.0 + randf_range(-e[2], e[2])
	if pos == null:
		var p := _pool2[_next2]
		_next2 = (_next2 + 1) % _pool2.size()
		p.stream = e[0].pick_random()
		p.volume_db = e[1] + vol
		p.pitch_scale = pitch
		p.bus = e[3]
		p.play()
		return
	var p3 := _pool3[_next3]
	_next3 = (_next3 + 1) % _pool3.size()
	p3.stream = e[0].pick_random()
	p3.volume_db = e[1] + vol
	p3.pitch_scale = pitch
	p3.max_distance = max_distance
	p3.global_position = pos
	p3.play()


## Bucle pegado a un nodo (braseros, el río): solo se oye cerca (max_distance).
static func loop(parent: Node3D, name: String, max_distance := 15.0, vol := 0.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = _instance()._stream(name)
	p.bus = "Ambiente"
	p.volume_db = vol
	p.unit_size = 4.0
	p.max_distance = max_distance
	p.autoplay = true
	parent.add_child(p)
	return p


func _ambient(name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _stream(name)
	p.bus = "Ambiente"
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


## Un paso de `body` según lo que tiene debajo: agua (en el río), madera (taller, mansión, muelles),
## metal, piedra (ciudad, Kredik Shaw) o tierra con ceniza (fuera de la muralla).
static func step(body: Node3D, vol := 0.0) -> void:
	play("step_" + surface(body), body.global_position, vol, 30.0)


static func surface(body: Node3D) -> String:
	var pos := body.global_position
	var xz := Vector2(pos.x, pos.z)
	if body.get_tree().get_node_count_in_group(&"water") > 0 and CityPlan.river_bed(xz) < 0.0 and pos.y < CityPlan.water_level(xz) + 0.15:
		return "water"
	var space := body.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.3, 0), pos + Vector3(0, -1.0, 0), Props.LAYER_WORLD)
	if body is CollisionObject3D:
		q.exclude = [(body as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(q)
	var n: Node = hit.get("collider") as Node
	while n:
		if n.is_in_group(&"metal"):
			return "metal"
		if n is VentureManor or n is Workshop:
			return "wood"
		if n is KredikLevel or n is KredikCitadel or n is KredikInterior:
			return "stone"
		n = n.get_parent()
	if hit.is_empty() or hit.get("collider") == null:
		return "stone" if CityPlan.inside(xz) else "dirt"  # el terreno (Terrain3D no tiene nodo)
	return "stone"


func _process(delta: float) -> void:
	var weather := get_tree().get_first_node_in_group(&"weather") as Weather
	var player := get_tree().get_first_node_in_group(&"player") as Player
	var indoor := weather != null and (weather.sheltered or weather.indoor)
	_reverb.wet = move_toward(_reverb.wet, 0.22 if indoor else 0.0, delta * 0.5)
	var outside := weather != null and not indoor
	var high := 0.0 if player == null else clampf((player.global_position.y - CityPlan.ground(Vector2(player.global_position.x, player.global_position.z))) / 40.0, 0.0, 1.0)
	_fade(_wind, (-16.0 + 8.0 * high) if outside else (-30.0 if weather else -80.0))
	_fade(_rain, (-10.0 if outside else -24.0) if weather and Art.weather == "lluvia" else -80.0)
	var speed := 0.0
	if player and not player.is_on_floor():
		speed = player.velocity.length()
	_fade(_fly, lerpf(-60.0, -4.0, clampf((speed - 7.0) / 25.0, 0.0, 1.0)) if speed > 7.0 else -80.0)


func _fade(p: AudioStreamPlayer, target: float) -> void:
	p.volume_db = move_toward(p.volume_db, target, 1.5)
