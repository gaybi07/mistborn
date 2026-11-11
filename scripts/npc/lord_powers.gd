class_name LordPowers
extends Node
## Poderes del Lord Legislador (ver docs/LORD_RULER.md): toda la alomancia de Vin más feruquimia. Cada poder que pega
## avisa en el piso con la misma forma que usa el daño (Telegraph) y lleva un aura del color de su metal. Los golpes
## comunes (Champion.KITS["LordRuler"]["blows"]) no avisan. Lo agrega Champion._setup cuando el kit tiene "lord".
##
## Campos: phase (1: siempre; 2: con menos del 60 % de vida; 3: menos del 30 %), range [mín, máx] de distancia al rival,
## warn (s de aviso antes de pegar), metal (color del aura), kind (cómo pega) y lo propio de cada kind.

const POWERS := [
	# ---- Acero
	{"name": "Empuje de acero", "phase": 1, "kind": "cone", "anim": "Punch_Forward_with_Both_Fists", "dur": 1.8, "warn": 0.9, "metal": "steel",
			"reach": 12.0, "half": 0.45, "damage": 0.8, "push": 18.0, "range": [2.0, 11.0], "cooldown": 10.0},
	{"name": "Moneda de combate", "phase": 1, "kind": "volley", "anim": "mage_soell_cast", "dur": 2.6, "warn": 0.75, "metal": "steel",
			"count": 3, "gap": 0.55, "damage": 0.45, "push": 6.0, "range": [4.0, 22.0], "cooldown": 8.0},
	{"name": "Ráfaga de monedas", "phase": 1, "kind": "cone", "anim": "mage_soell_cast_4", "dur": 2.0, "warn": 1.0, "metal": "steel",
			"reach": 10.0, "half": 0.8, "damage": 1.0, "push": 9.0, "range": [2.0, 9.0], "cooldown": 12.0},
	{"name": "Escudo de monedas", "phase": 1, "kind": "shield", "anim": "mage_soell_cast_6", "dur": 1.8, "warn": 1.0, "metal": "steel",
			"time": 4.0, "radius": 5.0, "damage": 1.2, "push": 12.0, "range": [0.0, 8.0], "cooldown": 18.0},
	{"name": "Campo magnético", "phase": 2, "kind": "field", "anim": "mage_soell_cast_2", "dur": 2.0, "warn": 0.0, "metal": "steel",
			"time": 6.0, "radius": 8.0, "range": [3.0, 20.0], "cooldown": 22.0},
	{"name": "Lanza de acero", "phase": 1, "kind": "strip", "anim": "mage_soell_cast_3", "dur": 2.2, "warn": 1.2, "metal": "steel",
			"length": 30.0, "width": 1.4, "damage": 1.8, "push": 14.0, "range": [6.0, 28.0], "cooldown": 13.0},
	# ---- Hierro
	{"name": "Tirón de hierro", "phase": 1, "kind": "pull", "anim": "Left_Slash", "dur": 2.0, "warn": 0.6, "metal": "iron",
			"push": 14.0, "range": [5.0, 16.0], "cooldown": 11.0},
	{"name": "Gancho", "phase": 1, "kind": "leap", "anim": "ninjajump_start", "dur": 2.2, "warn": 1.3, "air": 0.7, "metal": "iron",
			"radius": 3.0, "damage": 1.3, "push": 10.0, "count": 1, "range": [8.0, 20.0], "cooldown": 14.0},
	{"name": "Desarme", "phase": 2, "kind": "disarm", "anim": "Left_Slash", "dur": 1.8, "warn": 0.8, "metal": "iron",
			"reach": 15.0, "range": [3.0, 15.0], "cooldown": 20.0},
	{"name": "Imán de monedas", "phase": 2, "kind": "magnet", "anim": "mage_soell_cast_6", "dur": 2.4, "warn": 0.9, "metal": "iron",
			"count": 5, "spread": 7.0, "damage": 0.4, "push": 5.0, "range": [3.0, 18.0], "cooldown": 14.0},
	{"name": "Atracción masiva", "phase": 2, "kind": "yank", "anim": "Charged_Spell_Cast", "dur": 2.4, "warn": 1.0, "metal": "iron",
			"radius": 14.0, "strike": 4.0, "damage": 1.4, "push": 9.0, "range": [4.0, 13.0], "cooldown": 20.0},
	# ---- Peltre
	{"name": "Embestida", "phase": 2, "kind": "dash", "anim": "Weapon_Combo_1", "dur": 2.8, "warn": 0.8, "metal": "pewter",
			"hits": [0.23, 0.48, 0.7], "width": 1.6, "damage": 1.1, "push": 8.0, "range": [4.0, 11.0], "cooldown": 10.0},
	{"name": "Martillazo", "phase": 2, "kind": "slam", "anim": "Charged_Ground_Slam", "dur": 2.4, "warn": 1.1, "metal": "pewter",
			"radius": 6.0, "damage": 1.4, "push": 11.0, "stun": 1.2, "range": [0.0, 5.0], "cooldown": 12.0},
	{"name": "Furia", "phase": 2, "kind": "buff", "buff": "furia", "anim": "Sword_Shout", "dur": 1.8, "warn": 0.0, "metal": "pewter",
			"time": 8.0, "range": [0.0, 30.0], "cooldown": 30.0},
	# ---- Estaño y emociones
	{"name": "Marca del cazador", "phase": 2, "kind": "mark", "anim": "mage_soell_cast", "dur": 1.6, "warn": 0.0, "metal": "tin",
			"time": 10.0, "range": [2.0, 25.0], "cooldown": 25.0},
	{"name": "Mente despejada", "phase": 2, "kind": "buff", "buff": "despejada", "anim": "Skill_01", "dur": 1.8, "warn": 0.0, "metal": "tin",
			"time": 12.0, "range": [0.0, 30.0], "cooldown": 30.0},
	{"name": "Aplacar", "phase": 2, "kind": "soothe", "anim": "Skill_02", "dur": 1.8, "warn": 0.9, "metal": "brass",
			"reach": 14.0, "half": 0.6, "drain": 55.0, "range": [2.0, 13.0], "cooldown": 16.0},
	{"name": "Enardecer", "phase": 2, "kind": "riot", "anim": "Angry_Ground_Stomp", "dur": 2.0, "warn": 0.0, "metal": "zinc",
			"radius": 16.0, "range": [0.0, 30.0], "cooldown": 24.0},
	{"name": "Nube de cobre", "phase": 2, "kind": "buff", "buff": "cobre", "anim": "Skill_03", "dur": 1.8, "warn": 0.0, "metal": "copper",
			"time": 10.0, "radius": 10.0, "range": [0.0, 30.0], "cooldown": 30.0},
	{"name": "Atium", "phase": 3, "kind": "buff", "buff": "atium", "anim": "Combat_Idle_Turn_Left", "dur": 1.2, "warn": 0.0, "metal": "atium",
			"time": 6.0, "range": [0.0, 12.0], "cooldown": 28.0},
	# ---- Feruquimia (inventados)
	{"name": "Peso de hierro", "phase": 3, "kind": "leap", "anim": "ninjajump_start", "dur": 2.4, "warn": 1.5, "air": 0.8, "metal": "feru",
			"radius": 4.5, "damage": 2.0, "push": 14.0, "count": 1, "range": [3.0, 16.0], "cooldown": 16.0},
	{"name": "Ligereza de hierro", "phase": 3, "kind": "leap", "anim": "ninjajump_start", "dur": 1.6, "warn": 1.0, "air": 0.55, "metal": "feru",
			"radius": 2.5, "damage": 0.9, "push": 8.0, "count": 2, "range": [4.0, 18.0], "cooldown": 15.0},
	{"name": "Fuerza de peltre", "phase": 3, "kind": "buff", "buff": "fuerza", "anim": "Angry_Ground_Stomp_2", "dur": 2.0, "warn": 0.0, "metal": "feru",
			"time": 10.0, "range": [0.0, 30.0], "cooldown": 30.0},
	{"name": "Mente de oro", "phase": 2, "kind": "heal", "anim": "Catching_Breath", "dur": 3.0, "warn": 0.0, "metal": "gold",
			"amount": 0.25, "time": 3.0, "below": 0.6, "range": [6.0, 40.0], "cooldown": 30.0},
	{"name": "Paso de acero", "phase": 3, "kind": "blink", "anim": "Charged_Slash", "dur": 1.6, "warn": 0.75, "metal": "feru",
			"radius": 2.2, "damage": 1.2, "push": 9.0, "range": [3.0, 14.0], "cooldown": 11.0},
	{"name": "Ola de calor", "phase": 3, "kind": "heatwave", "anim": "Charged_Ground_Slam", "dur": 2.2, "warn": 0.9, "metal": "feru",
			"radius": 15.0, "speed": 7.0, "band": 0.8, "damage": 1.1, "push": 6.0, "range": [0.0, 12.0], "cooldown": 16.0},
	{"name": "Lluvia de monedas", "phase": 2, "kind": "rain", "anim": "mage_soell_cast_2", "dur": 2.4, "warn": 1.1, "metal": "steel",
			"count": 8, "spread": 6.0, "radius": 1.6, "stagger": 0.22, "damage": 0.6, "push": 5.0, "range": [3.0, 20.0], "cooldown": 15.0},
	{"name": "Tormenta de ceniza", "phase": 3, "kind": "storm", "anim": "Charged_Spell_Cast", "dur": 3.0, "warn": 1.1, "metal": "ash",
			"waves": 3, "count": 6, "spread": 9.0, "radius": 2.5, "gap": 1.3, "damage": 0.9, "push": 7.0, "range": [0.0, 14.0], "cooldown": 26.0},
]
## Tramo de cada clip [desde, hasta, golpe] (fracciones) y su largo en s, medidos en el Lord con
## tools/anim_check/clip_measure.gd: "golpe" es el pico de velocidad de la mano. cast() hace que el golpe caiga justo
## cuando se llena el aviso (acelera hasta MAX_SPEED o espera quieto). Los saltos van aparte (_leap).
const CUTS := {
	"Punch_Forward_with_Both_Fists": [0.3, 0.62, 0.45], "mage_soell_cast": [0.08, 0.5, 0.28],
	"mage_soell_cast_4": [0.05, 0.45, 0.24], "mage_soell_cast_6": [0.12, 0.6, 0.38], "mage_soell_cast_2": [0.15, 0.7, 0.42],
	"mage_soell_cast_3": [0.05, 0.55, 0.28], "Left_Slash": [0.08, 0.5, 0.27], "Charged_Spell_Cast": [0.05, 0.75, 0.25],
	"Charged_Ground_Slam": [0.25, 0.85, 0.56], "Sword_Shout": [0.05, 0.4, 0.19], "Skill_01": [0.0, 0.9, 0.42],
	"Skill_02": [0.0, 0.7, 0.17], "Skill_03": [0.0, 0.85, 0.63], "Angry_Ground_Stomp": [0.0, 1.0, 0.17],
	"Angry_Ground_Stomp_2": [0.0, 0.9, 0.36], "Catching_Breath": [0.1, 0.6, 0.27], "Charged_Slash": [0.3, 0.85, 0.54],
	"Axe_Spin_Attack": [0.05, 0.8, 0.37], "Combat_Idle_Turn_Left": [0.15, 0.8, 0.5],
	"ninjajump_start": [0.0, 1.0, 0.07], "ninjajump_land": [0.0, 0.55, 0.08],
}
const LENGTHS := {
	"Punch_Forward_with_Both_Fists": 3.5, "mage_soell_cast": 2.3, "mage_soell_cast_4": 2.23, "mage_soell_cast_6": 2.33,
	"mage_soell_cast_2": 3.03, "mage_soell_cast_3": 3.37, "Left_Slash": 3.2, "Charged_Spell_Cast": 2.7,
	"Charged_Ground_Slam": 3.03, "Sword_Shout": 6.2, "Skill_01": 1.1, "Skill_02": 1.33, "Skill_03": 1.67,
	"Angry_Ground_Stomp": 1.4, "Angry_Ground_Stomp_2": 1.83, "Catching_Breath": 7.03, "Charged_Slash": 2.23,
	"Axe_Spin_Attack": 2.53, "Combat_Idle_Turn_Left": 1.3, "ninjajump_start": 1.0, "ninjajump_land": 1.3,
}
const MAX_SPEED := 2.2

## Último aliento (peltre): pasiva, una vez por pelea.
const LAST_STAND_AT := 0.2
const LAST_STAND_TIME := 3.0
const LAST_STAND_HEAL := 0.4
const GAP_BY_PHASE := [1.0, 1.0, 0.8, 0.6]
const COLORS := {
	"steel": AirFx.STEEL, "iron": AirFx.IRON, "pewter": AirFx.PEWTER, "tin": AirFx.TIN, "gold": AirFx.GOLD, "ash": AirFx.ASH,
	"atium": Color(1.0, 0.85, 0.35, 0.3), "brass": Color(0.7, 0.45, 1.0, 0.22), "zinc": Color(0.8, 0.35, 0.9, 0.22),
	"copper": Color(0.55, 0.5, 0.48, 0.3), "feru": Color(0.45, 0.9, 0.55, 0.24),
}

var lord: Champion
var off: Array = []  # nombres apagados por la historia (Story.FINALE)
var buffs := {}  # nombre -> hasta cuándo (_world_time del Lord)
var _id := 0
var _last_stand_used := false
var _heal_left := 0.0
var _waves: Array = []  # olas de calor que avanzan: {center, r, max, speed, band, p, hit}


func phase() -> int:
	var k := lord.health / maxf(lord.max_health, 1.0)
	return 1 if k > 0.6 else (2 if k > 0.3 else 3)


func has(buff: String) -> bool:
	return lord._world_time < float(buffs.get(buff, -1.0))


## Elige un poder que sirva a esta distancia y lo usa.
func try_use(d: float) -> bool:
	if lord._foe != lord._player or lord._world_time < lord._next_power or lord.is_disarmed():
		return false
	var options := POWERS.filter(func(p: Dictionary) -> bool:
		return p["phase"] <= phase() and not p["name"] in off and d >= p["range"][0] and d <= p["range"][1] \
				and lord._world_time >= float(lord._power_ready.get(p["name"], 0.0)) \
				and lord.health <= lord.max_health * float(p.get("below", 1.0)) and not (p["kind"] == "buff" and has(p["buff"])))
	if options.is_empty():
		return false
	cast(options.pick_random())
	return true


func cast(p: Dictionary) -> void:
	# Leer la pelea (atium del jugador): el aviso dura más.
	var reader: Node = lord._player
	if reader and reader.get(&"atium_powers"):
		p = p.duplicate()
		p["warn"] = float(p["warn"]) * reader.atium_powers.warn_scale()
	lord._power_ready[p["name"]] = lord._world_time + p["cooldown"]
	lord._next_power = lord._world_time + Champion.KITS[lord.kit]["power_gap"] * GAP_BY_PHASE[phase()]
	lord._announce(p["name"])
	# Anticipar (bronce del jugador): avisa cuando empieza a prepararlo.
	if reader and reader.get(&"bronze"):
		reader.bronze.foresee_lord(lord, float(p["warn"]))
	_id += 1
	var id := _id
	var color: Color = COLORS[p["metal"]]
	if not p["kind"] in ["dash", "leap"]:
		_play_synced(p["anim"], p["warn"], id)
	# El aura del metal que quema mientras prepara el poder: dice qué viene.
	var until := lord._world_time + maxf(float(p["warn"]), 0.6) + 0.2
	AirFx.shell(lord, color, 1.0 * lord._grow, func() -> bool: return _live(id) and lord._world_time < until, 1.0, 4)
	call("_" + p["kind"], p, id)


## Juega `anim` (su tramo de CUTS) para que el golpe caiga a los `warn` s: si el clip llega antes, espera quieto (con el
## aura) y arranca después; si llega tarde, lo acelera hasta MAX_SPEED. Sin aviso (mejoras), a su velocidad.
func _play_synced(anim: String, warn: float, id: int) -> void:
	var cut: Array = CUTS.get(anim, [0.0, 1.0, 0.5])
	var length: float = LENGTHS.get(anim, 2.0)
	var to_hit: float = (cut[2] - cut[0]) * length
	var speed := clampf(to_hit / warn, 1.0, MAX_SPEED) if warn > 0.0 else 1.0
	var wait := maxf(warn - to_hit / speed, 0.0) if warn > 0.0 else 0.0
	var dur: float = (cut[1] - cut[0]) * length / speed
	lord._busy_until = lord._world_time + wait + dur * 0.9
	lord._move_now(Vector3.ZERO)
	if wait <= 0.0:
		lord._commit(anim, dur)
		return
	(lord.rig as ModelRig).armored = true
	_later(wait, func() -> void:
		if _live(id):
			lord._commit(anim, dur))


# ---------------------------------------------------------------- Lo que se ve y lo que pega

func _live(id: int) -> bool:
	return is_instance_valid(lord) and id == _id and not lord.down and not lord.is_stunned()


func _later(time: float, effect: Callable) -> void:
	lord.get_tree().create_timer(time, false).timeout.connect(effect)


func _scene() -> Node:
	return lord.get_tree().current_scene


func _foe_dir() -> Vector3:
	var to := lord._foe.global_position - lord.global_position if is_instance_valid(lord._foe) else lord._forward()
	to.y = 0.0
	return to.normalized() if to.length_squared() > 1e-4 else lord._forward()


func _chest(n: Node3D) -> Vector3:
	return n.global_position + Vector3(0, 1.2, 0)


func _face(dir: Vector3) -> void:
	lord.face_point = lord.global_position + dir * 5.0


func _hit(v: Node3D, away: Vector3, p: Dictionary, k := 1.0) -> void:
	lord.mark_combat()
	var flat := Vector3(away.x, 0.0, away.z).normalized()
	var push: float = p.get("push", 0.0) * k
	v.call(&"take_hit", flat * push + Vector3.UP * push * 0.3, lord._damage(p["damage"] * k), lord)
	if p.has("stun") and v.has_method(&"stun") and not v is Player:
		v.call(&"stun", p["stun"], lord.global_position)
	AirFx.impact(_scene(), _chest(v), COLORS.get(p["metal"], AirFx.ASH), 1.6)
	AirFx.cloud(_scene(), _chest(v), 0.9, COLORS.get(p["metal"], AirFx.ASH), 0.9, 3, 1.2)


## Un golpe de aire que sale de `from` hacia `dir` hasta `reach` m: onda en el origen, frentes y bruma a lo largo.
func _sweep(from: Vector3, dir: Vector3, reach: float, color: Color, power: float) -> void:
	var chest := from + Vector3.UP * 1.2
	AirFx.wave(_scene(), chest, 2.6, color, 0.45, 0.06, dir)
	var steps := clampi(int(reach / 3.0), 2, 8)
	for i in steps:
		var at := chest + dir * reach * (i + 0.5) / steps
		AirFx._later(_scene(), i * 0.04, func() -> void:
			AirFx.push(_scene(), at - dir * 1.5, dir, color, power * 0.6)
			AirFx.mist(_scene(), at + Vector3.DOWN * 0.8, 1.2, color, 0.9, dir * 3.0))
	var player := lord._player
	if is_instance_valid(player) and player.global_position.distance_to(from) < reach + 4.0:
		player.call(&"add_trauma", 0.3)


## pos primero: se usan con bind(...) y el que llama pasa la posición.
static func in_disc(pos: Vector3, center: Vector3, radius: float) -> bool:
	return Vector2(pos.x - center.x, pos.z - center.z).length() <= radius


static func in_cone(pos: Vector3, origin: Vector3, dir: Vector3, reach: float, half: float) -> bool:
	var to := Vector3(pos.x - origin.x, 0.0, pos.z - origin.z)
	return to.length() <= reach and (to.length() < 0.5 or to.normalized().angle_to(dir) <= half)


static func in_strip(pos: Vector3, from: Vector3, dir: Vector3, length: float, width: float) -> bool:
	var to := Vector3(pos.x - from.x, 0.0, pos.z - from.z)
	var along := to.dot(dir)
	return along >= 0.0 and along <= length and (to - dir * along).length() <= width * 0.5


func _each_in(test: Callable, effect: Callable) -> void:
	for v in lord._victims():
		if test.call(v.global_position):
			effect.call(v)


# ---------------------------------------------------------------- Formas

func _cone(p: Dictionary, id: int) -> void:
	var origin := lord.global_position
	var dir := _foe_dir()
	_face(dir)
	var reach: float = p["reach"] * lord._grow
	var color := Telegraph.VIOLET if p["kind"] == "soothe" else Telegraph.RED
	Telegraph.cone(_scene(), origin, dir, reach, p["half"], p["warn"], color).alive = _live.bind(id)
	_later(p["warn"], func() -> void:
		if not _live(id):
			return
		_sweep(origin, dir, reach, COLORS[p["metal"]], 2.6)
		_each_in(in_cone.bind(origin, dir, reach, p["half"]), func(v: Node3D) -> void:
			if p["kind"] == "soothe":
				_soothe_hit(v, p)
			else:
				_hit(v, v.global_position - origin, p)))


func _soothe(p: Dictionary, id: int) -> void:
	_cone(p, id)


func _soothe_hit(v: Node3D, p: Dictionary) -> void:
	AirFx.cloud(_scene(), _chest(v), 1.2, COLORS["brass"], 1.5, 4, 0.5)
	if v is Player:
		v.set(&"stamina", maxf(float(v.get(&"stamina")) - p["drain"] * float(v.call(&"emotion_resist")), 0.0))  # Mente cerrada
		v.emit_signal(&"notice", "Te aplacan: sin aliento")


func _slam(p: Dictionary, id: int) -> void:
	var center := lord.global_position
	var radius: float = p["radius"] * lord._grow
	Telegraph.disc(_scene(), center, radius, p["warn"]).alive = _live.bind(id)
	_later(p["warn"], func() -> void:
		if not _live(id):
			return
		_shockwave(center, radius, COLORS[p["metal"]])
		_each_in(in_disc.bind(center, radius), func(v: Node3D) -> void: _hit(v, v.global_position - center, p)))


func _shockwave(center: Vector3, radius: float, color: Color) -> void:
	AirFx.ground(_scene(), center, radius, color, 0.8)
	AirFx.wave(_scene(), center + Vector3.UP * 0.8, radius * 0.6, color, 0.5, 0.05)
	Fx.dust(_scene(), center, 1.5)
	Sfx.play("land_heavy", center, 6.0)
	var player := lord._player
	if is_instance_valid(player) and player.global_position.distance_to(center) < radius * 2.0:
		player.call(&"add_trauma", 0.45)


func _strip(p: Dictionary, id: int) -> void:
	var from := lord.global_position
	var dir := _foe_dir()
	_face(dir)
	var length: float = p["length"]
	Telegraph.strip(_scene(), from, dir, length, p["width"], p["warn"]).alive = _live.bind(id)
	_later(p["warn"], func() -> void:
		if not _live(id):
			return
		# La lanza: frentes de aire que corren por toda la franja, con bruma a lo largo.
		_sweep(from, dir, length, COLORS[p["metal"]], 2.2)
		Sfx.play("clash", from)
		_each_in(in_strip.bind(from, dir, length, p["width"]), func(v: Node3D) -> void: _hit(v, dir, p)))


## Proyectiles hacia vos: una línea que te sigue y se fija antes del tiro (salí de la línea).
func _volley(p: Dictionary, id: int) -> void:
	for i in p["count"]:
		_later(i * p["gap"], func() -> void:
			if _live(id) and is_instance_valid(lord._foe):
				_aimed_shot(lord, lord._foe, p, id))


func _aimed_shot(from_node: Node3D, target: Node3D, p: Dictionary, id: int) -> void:
	var tel := Telegraph.line(_scene(), from_node, target, p["warn"], Telegraph.RED, 0.45)
	tel.alive = _live.bind(id)
	var locked := [Vector3.ZERO, Vector3.ZERO]
	_later(p["warn"] - Telegraph.LOCK, func() -> void:
		if is_instance_valid(from_node) and is_instance_valid(target):
			locked[0] = from_node.global_position
			locked[1] = target.global_position)
	_later(p["warn"], func() -> void:
		if not _live(id) or locked[0] == locked[1]:
			return
		var dir := Vector3(locked[1].x - locked[0].x, 0.0, locked[1].z - locked[0].z)
		var length := dir.length() + 3.0
		dir = dir.normalized()
		AirFx.push(_scene(), locked[0] + Vector3.UP * 1.2, dir, COLORS[p["metal"]], 0.8)
		Sfx.play("swing", locked[0])
		_each_in(in_strip.bind(locked[0], dir, length, 1.0), func(v: Node3D) -> void: _hit(v, dir, p)))


## Imán de monedas: las monedas sueltas alrededor tuyo vuelven todas hacia vos.
func _magnet(p: Dictionary, id: int) -> void:
	var foe := lord._foe
	if not is_instance_valid(foe):
		return
	for i in p["count"]:
		var a: float = TAU * i / p["count"] + randf() * 0.5
		var marker := Node3D.new()
		_scene().add_child(marker)
		marker.global_position = foe.global_position + Vector3(cos(a), 0.0, sin(a)) * p["spread"]
		AirFx.mist(_scene(), marker.global_position + Vector3.UP * 0.3, 0.6, COLORS[p["metal"]], p["warn"] + 0.3)
		_aimed_shot(marker, foe, p, id)
		_later(p["warn"] + 0.5, marker.queue_free)


func _pull(p: Dictionary, id: int) -> void:
	var foe := lord._foe
	if not is_instance_valid(foe):
		return
	_face(_foe_dir())
	var tel := Telegraph.line(_scene(), lord, foe, p["warn"], Telegraph.CYAN, 0.25)
	tel.alive = _live.bind(id)
	_later(p["warn"], func() -> void:
		if not _live(id) or not is_instance_valid(foe):
			return
		AirFx.pull(_scene(), _chest(foe), _chest(lord), COLORS["iron"], 1.5)
		var to := lord.global_position - foe.global_position
		to.y = 0.0
		foe.call(&"apply_allomantic_impulse", to.normalized() * p["push"] + Vector3.UP * 3.0)
		lord.mark_combat()
		lord._next_blow = 0.0)


func _disarm(p: Dictionary, id: int) -> void:
	var foe := lord._foe
	if not is_instance_valid(foe):
		return
	Telegraph.line(_scene(), lord, foe, p["warn"], Telegraph.CYAN, 0.2).alive = _live.bind(id)
	if foe is Player:
		foe.emit_signal(&"notice", "¡Te quiere sacar el arma!")
	_later(p["warn"], func() -> void:
		if not _live(id) or not is_instance_valid(foe) or foe.global_position.distance_to(lord.global_position) > p["reach"]:
			return
		AirFx.pull(_scene(), _chest(foe), _chest(lord), COLORS["iron"], 1.0)
		if foe.has_method(&"lose_weapon"):
			foe.call(&"lose_weapon"))


func _yank(p: Dictionary, id: int) -> void:
	var center := lord.global_position
	var radius: float = p["radius"]
	Telegraph.disc(_scene(), center, radius, p["warn"], Telegraph.CYAN).alive = _live.bind(id)
	_later(p["warn"], func() -> void:
		if not _live(id):
			return
		AirFx.ground(_scene(), center, radius, COLORS["iron"], 0.8, true)
		_each_in(in_disc.bind(center, radius), func(v: Node3D) -> void:
			var to := center - v.global_position
			to.y = 0.0
			v.call(&"apply_allomantic_impulse", to.normalized() * minf(to.length() * 1.6, 18.0) + Vector3.UP * 2.0))
		# Y el giro que pega a los que trajo.
		var strike := {"radius": p["strike"], "damage": p["damage"], "push": p["push"], "metal": "iron"}
		_play_synced("Axe_Spin_Attack", 0.7, id)
		_slam(strike.merged({"warn": 0.7}), id))


func _dash(p: Dictionary, id: int) -> void:
	var dir := _foe_dir()
	var d := lord.global_position.distance_to(lord._foe.global_position) if is_instance_valid(lord._foe) else 6.0
	_face(dir)
	lord._busy_until = lord._world_time + p["warn"]
	lord._move_now(Vector3.ZERO)
	Telegraph.strip(_scene(), lord.global_position, dir, d + 2.0, p["width"], p["warn"]).alive = _live.bind(id)
	_later(p["warn"], func() -> void:
		if not _live(id):
			return
		var lunge := p.duplicate()
		lunge["travel"] = maxf(d - 1.5 * lord._grow, 0.0) / lord._grow
		AirFx.trail(lord, COLORS["pewter"], 1.0, func() -> bool: return lord._world_time < lord._busy_until)
		lord._strike(lunge)
		(lord.rig as ModelRig).armored = true)


## Salta y cae donde estabas: el círculo te sigue hasta que despega, y ahí se fija.
func _leap(p: Dictionary, id: int, left := -1) -> void:
	var foe := lord._foe
	if not is_instance_valid(foe):
		return
	var count: int = p["count"] if left < 0 else left
	var radius: float = p["radius"] * lord._grow
	var tel := Telegraph.disc(_scene(), foe.global_position, radius, p["warn"], Telegraph.RED, foe)
	tel.alive = _live.bind(id)
	var air: float = p["air"]
	_later(p["warn"] - air, func() -> void:
		if not _live(id):
			return
		tel.follow = null  # se fija: ahí va a caer
		# Ninjajump de ActionForge: despega al 7 % y queda en el aire hasta el final; lo estira lo que dura el vuelo.
		lord._commit("ninjajump_start", air + 0.07)
		var to := tel.global_position - lord.global_position
		to.y = 0.0
		lord.velocity = to / air
		lord._move_now(Vector3(lord.velocity.x, 0.0, lord.velocity.z))
		AirFx.cloud(_scene(), lord.global_position, 1.2, COLORS[p["metal"]], 0.8, 4, 1.0))
	_later(p["warn"], func() -> void:
		lord._move_now(Vector3.ZERO)
		lord.velocity = Vector3.ZERO
		if not _live(id):
			return
		lord._commit("ninjajump_land", CUTS["ninjajump_land"][1] * LENGTHS["ninjajump_land"])
		var center := tel.global_position
		_shockwave(center, radius, COLORS[p["metal"]])
		_each_in(in_disc.bind(center, radius), func(v: Node3D) -> void: _hit(v, v.global_position - center, p))
		if count > 1:
			_later(0.25, func() -> void:
				if _live(id):
					_leap(p, id, count - 1)))


## Paso de acero: aparece detrás tuyo. El círculo marca dónde aparece y pega.
func _blink(p: Dictionary, id: int) -> void:
	var foe := lord._foe
	if not is_instance_valid(foe):
		return
	var behind := foe.global_position + _foe_dir() * 1.4
	var radius: float = p["radius"]
	Telegraph.disc(_scene(), behind, radius, p["warn"]).alive = _live.bind(id)
	AirFx.mist(_scene(), behind + Vector3.UP, 1.0, COLORS["feru"], p["warn"])
	_later(p["warn"] * 0.6, func() -> void:
		if not _live(id):
			return
		AirFx.cloud(_scene(), _chest(lord), 1.0, COLORS["feru"], 0.6, 5, 1.5)
		lord.global_position = behind
		if is_instance_valid(foe):
			_face((foe.global_position - behind).normalized())
		AirFx.cloud(_scene(), behind + Vector3.UP, 1.0, COLORS["feru"], 0.6, 5, 1.5))
	_later(p["warn"], func() -> void:
		if _live(id):
			AirFx.push(_scene(), behind + Vector3.UP * 1.2, -_foe_dir(), COLORS["feru"], 1.0)
			_each_in(in_disc.bind(behind, radius), func(v: Node3D) -> void: _hit(v, v.global_position - behind, p)))


func _heatwave(p: Dictionary, id: int) -> void:
	var center := lord.global_position
	Telegraph.disc(_scene(), center, 2.0, p["warn"]).alive = _live.bind(id)
	_later(p["warn"], func() -> void:
		if not _live(id):
			return
		var ring := Telegraph.ring(_scene(), center, 0.1, 1.0, 99.0).solid()
		AirFx.ground(_scene(), center, p["radius"], Color(1.0, 0.45, 0.2, 0.25), p["radius"] / p["speed"])
		_waves.append({"center": center, "r": 0.0, "p": p, "hit": [], "ring": ring}))


func _rain(p: Dictionary, id: int) -> void:
	var foe := lord._foe
	if not is_instance_valid(foe):
		return
	for i in p["count"]:
		_later(i * p["stagger"], func() -> void:
			if not _live(id) or not is_instance_valid(foe):
				return
			var at: Vector3 = foe.global_position if i == 0 else foe.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * p["spread"]
			_falling(at, p, id))


func _falling(at: Vector3, p: Dictionary, id: int) -> void:
	var tel := Telegraph.disc(_scene(), at, p["radius"], p["warn"])
	tel.alive = _live.bind(id)
	_later(p["warn"] - 0.25, func() -> void:
		if _live(id):
			AirFx.push(_scene(), tel.global_position + Vector3.UP * 7.0, Vector3.DOWN, COLORS[p["metal"]], 0.7))
	_later(p["warn"], func() -> void:
		if not _live(id):
			return
		var c := tel.global_position
		AirFx.impact(_scene(), c + Vector3.UP * 0.2, COLORS[p["metal"]], 1.3)
		AirFx.ground(_scene(), c, p["radius"], COLORS[p["metal"]], 0.4)
		_each_in(in_disc.bind(c, p["radius"]), func(v: Node3D) -> void: _hit(v, v.global_position - c, p)))


func _storm(p: Dictionary, id: int) -> void:
	var center := lord.global_position
	AirFx.cloud(_scene(), center + Vector3.UP * 2.0, 4.0, AirFx.ASH, p["waves"] * p["gap"] + 1.0, 8, 0.6)
	for w in p["waves"]:
		_later(w * p["gap"], func() -> void:
			if not _live(id):
				return
			# Una tanda de círculos repartidos con huecos: siempre queda dónde pararse.
			for i in p["count"]:
				var a: float = TAU * (i + randf() * 0.5) / p["count"] + w * 0.7
				var r := randf_range(2.0, p["spread"])
				_falling(center + Vector3(cos(a), 0.0, sin(a)) * r, p, id))


# ---------------------------------------------------------------- Estados

func _buff(p: Dictionary, id: int) -> void:
	var name: String = p["buff"]
	buffs[name] = lord._world_time + p["time"]
	var color: Color = COLORS[p["metal"]]
	var until: float = buffs[name]
	AirFx.shell(lord, color, 1.3 * lord._grow, func() -> bool: return is_instance_valid(lord) and not lord.down and lord._world_time < until, 1.0, 6)
	match name:
		"fuerza":
			var tw := lord.create_tween()
			tw.tween_property(lord, "scale", Vector3.ONE * 1.3, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_later(p["time"], func() -> void:
				if is_instance_valid(lord):
					lord.create_tween().tween_property(lord, "scale", Vector3.ONE, 0.6))
		"cobre":
			var radius: float = p["radius"]
			Telegraph.disc(_scene(), lord.global_position, radius, p["time"], Telegraph.GREY, lord).outline_only()
			for i in int(p["time"] / 1.5):
				_later(i * 1.5, func() -> void:
					if is_instance_valid(lord) and not lord.down:
						AirFx.cloud(_scene(), lord.global_position + Vector3.UP, radius * 0.4, COLORS["copper"], 2.0, 5, 0.4))
		"atium":
			AirFx.wave(_scene(), _chest(lord), 2.5, COLORS["atium"], 0.5, 0.05)


func _field(p: Dictionary, _id: int) -> void:
	buffs["campo"] = lord._world_time + p["time"]
	Telegraph.disc(_scene(), lord.global_position, p["radius"], p["time"], Telegraph.BLUE, lord).outline_only()
	var until: float = buffs["campo"]
	AirFx.shell(lord, COLORS["steel"], p["radius"] * 0.5, func() -> bool: return is_instance_valid(lord) and lord._world_time < until, 1.6, 8, p["radius"])


## Escudo de monedas: lo cubre un rato (le pegan la mitad) y revienta alrededor.
func _shield(p: Dictionary, id: int) -> void:
	buffs["escudo"] = lord._world_time + p["time"]
	var until: float = buffs["escudo"]
	AirFx.shell(lord, COLORS["steel"], 1.4, func() -> bool: return is_instance_valid(lord) and lord._world_time < until, 1.2, 8, 1.6)
	_later(p["time"] - p["warn"], func() -> void:
		if is_instance_valid(lord) and not lord.down:
			_id += 1
			_slam(p, _id))


func _mark(p: Dictionary, _id_unused: int) -> void:
	var foe := lord._foe
	if not is_instance_valid(foe):
		return
	buffs["marca"] = lord._world_time + p["time"]
	Telegraph.disc(_scene(), foe.global_position, 0.9, p["time"], Telegraph.RED, foe).outline_only()
	if foe is Player:
		foe.emit_signal(&"notice", "Te marcó: sus golpes te duelen más")


func _riot(p: Dictionary, _id_unused: int) -> void:
	var center := lord.global_position
	AirFx.ground(_scene(), center, p["radius"], COLORS["zinc"], 1.0)
	for k in lord.get_tree().get_nodes_in_group(&"koloss"):
		if k != lord and k is Koloss and (k as Node3D).global_position.distance_to(center) < p["radius"]:
			k.set(&"_enraged", true)
			AirFx.cloud(_scene(), (k as Node3D).global_position + Vector3.UP * 1.5, 1.0, COLORS["zinc"], 1.2, 4, 0.8)


func _heal(p: Dictionary, id: int) -> void:
	_heal_left = p["time"]
	var per: float = lord.max_health * p["amount"] / (p["time"] / 0.5)
	AirFx.shell(lord, COLORS["gold"], 1.2, func() -> bool: return _heal_left > 0.0 and _live(id), 1.0, 6)
	for i in int(p["time"] / 0.5):
		_later((i + 1) * 0.5, func() -> void:
			if _heal_left <= 0.0 or not _live(id):
				return
			lord.health = minf(lord.health + per, lord.max_health)
			Fx.popup(_scene(), lord.global_position + Vector3(0, lord.head_y(), 0), "+%d" % roundi(per), Color(0.6, 1.0, 0.6), 1.0))
	_later(p["time"], func() -> void: _heal_left = 0.0)


# ---------------------------------------------------------------- Lo que le hacen a él (ver Champion)

func damage_mult() -> float:
	return (1.3 if has("furia") else 1.0) * (1.4 if has("fuerza") else 1.0) * (1.25 if has("marca") else 1.0)


## El daño que de verdad recibe (0: no le hizo nada).
func filter_damage(damage: float, attacker: Node3D) -> float:
	if has("ultimo"):
		return 0.0
	if has("atium") and attacker is Player:
		Atium.dodge_trail(lord.rig)
		return 0.0
	if has("escudo"):
		damage *= 0.5
	if has("campo") and attacker is Player and attacker.global_position.distance_to(lord.global_position) > 3.0:
		damage *= 0.2  # las monedas se desvían
	if _heal_left > 0.0 and damage >= 25.0:
		_heal_left = 0.0
		lord._announce("¡Cortado!")
	if not _last_stand_used and lord.health - damage < lord.max_health * LAST_STAND_AT:
		_last_stand_used = true
		buffs["ultimo"] = lord._world_time + LAST_STAND_TIME
		damage = minf(damage, maxf(lord.health - 1.0, 0.0))
		lord._announce("¡Último aliento!")
		var cure := lord.max_health * LAST_STAND_HEAL / 6.0
		AirFx.shell(lord, COLORS["gold"], 1.6, func() -> bool: return has("ultimo"), 1.0, 8)
		for i in 6:
			_later((i + 1) * LAST_STAND_TIME / 6.0, func() -> void:
				if is_instance_valid(lord) and not lord.down:
					lord.health = minf(lord.health + cure, lord.max_health))
	return damage


## Empujes y tirones de metal que le hacen: con la mente despejada o el campo, nada.
func filter_impulse(dv: Vector3) -> Vector3:
	return Vector3.ZERO if has("despejada") or has("campo") or has("ultimo") else dv


func _process(delta: float) -> void:
	for w: Dictionary in _waves.duplicate():
		var p: Dictionary = w["p"]
		w["r"] += p["speed"] * delta
		var r: float = w["r"]
		var band: float = p["band"]
		var ring: Telegraph = w["ring"]
		if r >= p["radius"] or not is_instance_valid(lord):
			_waves.erase(w)
			if is_instance_valid(ring):
				ring.time = 0.0
			continue
		if is_instance_valid(ring):
			ring.set_ring(maxf(r - band, 0.05), r + band)
		for v in lord._victims():
			if v in w["hit"]:
				continue
			var d := Vector2(v.global_position.x - w["center"].x, v.global_position.z - w["center"].z).length()
			var grounded: bool = (v as CharacterBody3D).is_on_floor() if v is CharacterBody3D else true
			if absf(d - r) <= band and grounded:  # saltando pasa por arriba
				w["hit"].append(v)
				_hit(v, v.global_position - w["center"], p)
