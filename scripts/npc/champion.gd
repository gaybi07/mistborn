class_name Champion
extends Koloss
## Personajes de Meshy que pelean: Lord Legislador, koloss, inquisidores y obligadores. Piensan como el koloss, pero solo usan
## los clips de su propio paquete. `hits` y `at` son fracciones del tramo jugado: los picos de velocidad de la mano, medidos
## en cada clip (el golpe llega cuando la mano llega). Sin efectos todavía: los poderes se notan por el clip, el empujón y el daño.
##
## Poderes, por `kind`:
##   area: pega alrededor (radius).   cone: pega adelante, hasta range[1].   pull: te trae hacia él; `then` es el que sigue.
##   dash: se lanza encima tuyo con un golpe.   leap: salta encima tuyo (at: despega, cae).   heal: recupera vida (amount: fracción).

const KITS := {
	"LordRuler": {
		"height": 1.95, "health": 900.0, "speed": 4.6, "weapons": ["res://assets/weapons/sword_steel.glb"], "power_gap": 5.0,
		"states": {"idle": ["Combat_Stance"], "idle_armed": ["Combat_Stance"], "walk": ["Walking"], "run": ["Running"], "sprint": ["Running"],
				"flee": ["Running"], "down": ["falling_down"]},
		"blows": [
			{"anim": "Double_Combo_Attack", "dur": 2.3, "hits": [0.22, 0.42], "damage": 1.2, "push": 7.0, "travel": 0.6},
			{"anim": "Weapon_Combo", "dur": 2.9, "hits": [0.18, 0.34, 0.6], "damage": 1.0, "push": 6.0, "travel": 0.8},
			{"anim": "Triple_Combo_Attack", "dur": 3.4, "hits": [0.18, 0.35, 0.51], "damage": 1.2, "push": 9.0, "travel": 1.0},
		],
		"powers": [],  # los suyos están en LordPowers (todos los de Vin más feruquimia)
		"lord": true,
	},
	# Guardia imperial: no te busca pelea salvo que le pegues. Lleva acero: se lo puede tirar y empujar.
	"Soldado": {
		"height": 1.8, "health": 120.0, "speed": 5.0, "weapons": ["res://assets/weapons/sword_steel.glb"], "power_gap": 8.0, "passive": true,
		"states": {"idle": ["Combat_Stance"], "idle_armed": ["Combat_Stance"], "walk": ["Spear_Walk"], "run": ["Running"], "sprint": ["Running"],
				"flee": ["Running"], "down": ["Dead"]},
		"blows": [
			{"anim": "Weapon_Combo", "dur": 2.9, "hits": [0.18, 0.34, 0.6], "damage": 0.7, "push": 5.0, "travel": 0.8},
			{"anim": "Thrust_Slash", "dur": 2.6, "hits": [0.24, 0.46], "damage": 0.7, "push": 5.0, "travel": 0.8},
			{"anim": "Charged_Slash", "dur": 1.9, "hits": [0.52], "damage": 1.0, "push": 7.0, "travel": 0.4},
		],
		"powers": [],
	},
	# Mataneblino: sin nada de metal, así que el acero y el hierro no le hacen nada. Más liviano y rápido que el guardia.
	"Mataneblino": {
		"height": 1.75, "health": 100.0, "speed": 5.8, "weapons": ["res://assets/weapons/dueling_cane.glb"], "power_gap": 8.0, "wood": true,
		"states": {"idle": ["Lower_Weapon_Look_Raise"], "idle_armed": ["Lower_Weapon_Look_Raise"], "walk": ["Walking"], "run": ["Running"], "sprint": ["Running"],
				"flee": ["Running"], "down": ["dying_backwards"]},
		"dodge": ["Stand_Dodge", 1.1],
		"blows": [
			{"anim": "Weapon_Combo_1", "dur": 2.8, "hits": [0.23, 0.48, 0.7], "damage": 0.7, "push": 5.0, "travel": 0.8},
			{"anim": "Heavy_Hammer_Swing", "dur": 1.7, "hits": [0.82], "damage": 1.0, "push": 7.0, "travel": 0.3},
			{"anim": "Thrust_Slash", "dur": 2.6, "hits": [0.24, 0.46], "damage": 0.7, "push": 5.0, "travel": 0.8},
		],
		"powers": [],
	},
	"KolossAdulto": {
		"height": 2.9, "health": 300.0, "speed": 4.6, "weapons": ["res://assets/weapons/koloss_greatsword.glb"], "power_gap": 6.0,
		"states": {"idle": ["Combat_Stance"], "idle_armed": ["Combat_Stance"], "walk": ["Walking"], "run": ["Running"], "sprint": ["run_fast_3_inplace"],
				"flee": ["Running"], "down": ["Fall_Dead_from_Abdominal_Injury"]},
		"cuts": {"Basic_Jump": [0.26, 0.56]},
		"roar": ["Chest_Pound_Taunt", 3.8, 0.45],
		"rage": ["Chest_Pound_Taunt", 3.0],
		"blows": [
			{"anim": "Charged_Slash", "dur": 1.9, "hits": [0.52], "damage": 1.3, "push": 8.0, "travel": 0.4},
			{"anim": "Double_Combo_Attack", "dur": 2.4, "hits": [0.22, 0.42], "damage": 0.9, "push": 6.0, "travel": 0.5},
			{"anim": "Triple_Combo_Attack", "dur": 3.6, "hits": [0.18, 0.35, 0.51], "damage": 0.8, "push": 6.0, "travel": 1.0},
		],
		"powers": [
			{"name": "Aplastar", "kind": "area", "anim": "Heavy_Hammer_Swing", "dur": 1.9, "at": [0.82], "radius": 3.0, "damage": 1.5, "push": 10.0, "range": [0.0, 3.5], "cooldown": 8.0},
			{"name": "Tajo ascendente", "kind": "cone", "anim": "Charged_Upward_Slash", "dur": 2.6, "at": [0.32], "damage": 1.4, "push": 12.0, "range": [0.0, 3.0], "cooldown": 10.0},
			{"name": "Estocada", "kind": "dash", "anim": "Thrust_Slash", "dur": 2.6, "hits": [0.24, 0.46], "damage": 1.0, "push": 8.0, "range": [4.0, 9.0], "cooldown": 8.0},
			{"name": "Salto", "kind": "leap", "anim": "Basic_Jump", "dur": 2.4, "at": [0.17, 0.6], "range": [5.0, 12.0], "cooldown": 12.0},
		],
	},
	"KolossJoven": {
		"height": 2.0, "health": 170.0, "speed": 5.8, "weapons": ["res://assets/weapons/koloss_axe.glb", "res://assets/weapons/koloss_axe.glb"], "power_gap": 7.0,
		"states": {"idle": ["Lower_Weapon_Look_Raise"], "idle_armed": ["Lower_Weapon_Look_Raise"], "walk": ["Walking"], "run": ["Running"], "sprint": ["RunFast"],
				"flee": ["Running"], "down": ["dying_backwards"]},
		"cuts": {"Basic_Jump": [0.26, 0.56], "Charged_Axe_Chop": [0.35, 0.75]},
		"roar": ["Charged_Spell_Cast", 2.4, 0.64],
		"rage": ["Charged_Spell_Cast", 2.2],
		"blows": [
			{"anim": "Attack", "dur": 2.4, "hits": [0.38], "damage": 1.3, "push": 8.0, "travel": 0.3},
			{"anim": "Left_Slash", "dur": 2.6, "hits": [0.25, 0.4], "damage": 0.8, "push": 5.0, "travel": 0.4},
			{"anim": "Heavy_Hammer_Swing", "dur": 1.7, "hits": [0.82], "damage": 1.2, "push": 7.0, "travel": 0.3},
		],
		"powers": [
			{"name": "Golpe al suelo", "kind": "area", "anim": "Charged_Ground_Slam", "dur": 2.6, "at": [0.54], "radius": 3.5, "damage": 1.4, "push": 9.0, "range": [0.0, 3.5], "cooldown": 9.0},
			{"name": "Hachazo", "kind": "cone", "anim": "Charged_Axe_Chop", "dur": 2.8, "at": [0.55], "damage": 2.0, "push": 10.0, "range": [0.0, 3.0], "cooldown": 11.0},
			{"name": "Salto", "kind": "leap", "anim": "Basic_Jump", "dur": 2.4, "at": [0.17, 0.6], "range": [5.0, 12.0], "cooldown": 12.0},
		],
	},
	"MistbornHood": {
		"height": 1.8, "health": 320.0, "speed": 5.4, "weapons": ["res://assets/weapons/sword_obsidian.glb"], "power_gap": 6.0,
		"states": {"idle": ["Combat_Stance"], "idle_armed": ["Combat_Stance"], "walk": ["Walking"], "run": ["Running"], "sprint": ["RunFast"],
				"flee": ["Running"], "down": ["Dead"]},
		"cuts": {"Double_Blade_Spin": [0.05, 0.4]},
		"dodge": ["Stand_Dodge", 1.1],
		"blows": [
			{"anim": "Attack", "dur": 2.2, "hits": [0.38], "damage": 1.2, "push": 8.0, "travel": 0.4},
			{"anim": "Left_Slash", "dur": 2.5, "hits": [0.25, 0.4], "damage": 0.9, "push": 5.0, "travel": 0.4},
			{"anim": "Weapon_Combo_1", "dur": 2.8, "hits": [0.23, 0.48, 0.7], "damage": 0.9, "push": 6.0, "travel": 0.8},
		],
		"powers": [
			{"name": "Juicio", "kind": "cone", "anim": "Sword_Judgment", "dur": 3.4, "at": [0.23], "damage": 1.8, "push": 10.0, "range": [0.0, 5.0], "cooldown": 10.0},
			{"name": "Doble giro", "kind": "area", "anim": "Double_Blade_Spin", "dur": 1.8, "at": [0.29, 0.63], "radius": 3.0, "damage": 0.9, "push": 6.0, "range": [0.0, 3.0], "cooldown": 9.0},
			{"name": "Empujón", "kind": "cone", "anim": "Charged_Spell_Cast_1", "dur": 3.3, "at": [0.44], "damage": 0.6, "push": 15.0, "range": [2.0, 10.0], "cooldown": 12.0},
		],
	},
	"Obligador": {
		"height": 1.9, "health": 140.0, "speed": 4.0, "weapons": [], "power_gap": 3.5, "passive": true,
		"states": {"idle": ["Idle_11"], "idle_armed": ["Idle_11"], "walk": ["Walking"], "run": ["Running"], "sprint": ["Run_02"],
				"flee": ["Running"], "down": ["Knock_Down_1"]},
		"blows": [
			{"anim": "Left_Slash", "dur": 2.6, "hits": [0.25, 0.4], "damage": 0.5, "push": 4.0, "travel": 0.3},
			{"anim": "Axe_Spin_Attack", "dur": 2.2, "hits": [0.39], "damage": 0.8, "push": 6.0, "travel": 0.3},
		],
		"powers": [
			{"name": "Rayo", "kind": "cone", "anim": "mage_soell_cast", "dur": 2.0, "at": [0.26], "damage": 0.6, "push": 6.0, "range": [2.0, 12.0], "cooldown": 5.0},
			{"name": "Castigo", "kind": "cone", "anim": "mage_soell_cast_2", "dur": 2.6, "at": [0.41], "damage": 1.0, "push": 9.0, "range": [2.0, 14.0], "cooldown": 9.0},
			{"name": "Onda", "kind": "area", "anim": "Charged_Ground_Slam", "dur": 2.6, "at": [0.54], "radius": 4.5, "damage": 0.8, "push": 10.0, "range": [0.0, 4.0], "cooldown": 10.0},
		],
	},
}
## Sin arma (ver Player.start_disarm): cualquiera con arma pega así, mucho más flojo y sin poderes.
const FIST_BLOWS := [
	{"anim": "Punch_Combo", "dur": 2.0, "hits": [0.22, 0.5], "damage": 0.35, "push": 4.0, "travel": 0.4},
	{"anim": "Punch_Forward_with_Both_Fists", "dur": 2.4, "hits": [0.4], "damage": 0.5, "push": 6.0, "travel": 0.4},
	{"anim": "Step_in_High_Kick", "dur": 1.3, "hits": [0.4], "damage": 0.45, "push": 6.0, "travel": 0.3},
]
const CONE_DOT := 0.6  # adelante, unos 50° para cada lado
const PROVOKED_LONG := 30.0
const PROVOKE_RADIUS := 60.0

## Clave de KITS. shortcut: los inquisidores usan el modelo encapuchado, cambiarlo cuando haya uno propio.
var kit := "MistbornHood"
var _next_power := 0.0
var _power_ready := {}  # nombre del poder -> cuándo se puede volver a usar
var lord_powers: LordPowers  # solo el Lord Legislador


## Todos los clips sueltos que juega este kit, además de los de `states`.
static func clips_of(kit_name: String) -> Array:
	var spec: Dictionary = KITS[kit_name]
	var out := []
	for entry: Dictionary in spec["blows"] + spec["powers"] + (LordPowers.POWERS if spec.get("lord", false) else []):
		if not entry["anim"] in out:
			out.append(entry["anim"])
	if spec.get("lord", false):
		out.append_array(["Axe_Spin_Attack", "ninjajump_land"])  # el giro de la Atracción masiva y la caída de los saltos
	for key in ["roar", "rage", "dodge"]:
		if spec.has(key):
			out.append(spec[key][0])
	return out


func _role() -> String:
	return "champion:" + kit


func can_be_tamed() -> bool:
	return false  # jefe: el Domar del cinc no le hace efecto


func _setup() -> void:
	axes = true  # sin la guardia del espadón
	super()
	var spec: Dictionary = KITS[kit]
	if spec.get("lord", false):
		lord_powers = LordPowers.new()
		lord_powers.lord = self
		add_child(lord_powers)
	max_health = spec["health"]
	walk_speed = 1.3 * _grow
	run_speed = spec["speed"]
	_next_leap = INF
	_next_power = randf_range(1.0, 3.0)
	if spec["weapons"].is_empty():
		rig.set_weapon(HumanoidRig.Weapon.NONE)
	if spec.get("wood", false):
		remove_from_group(&"metal")
	if spec.get("passive", false):
		remove_from_group(&"koloss")  # la gente no le escapa
		add_to_group(&"passive_champion")


## Los pasivos no buscan pelea: te persiguen solo si les pegaste.
func _pick_foe() -> void:
	if not KITS[kit].get("passive", false):
		super()
		return
	_foe = _player if _world_time < _provoked_until and not _player.call(&"is_down") else null


func take_hit(impulse: Vector3, damage: float, attacker: Node3D = null) -> void:
	if attacker is Player and KITS[kit].get("passive", false):
		for other: Champion in get_tree().get_nodes_in_group(&"passive_champion"):
			if other.global_position.distance_to(global_position) < PROVOKE_RADIUS:  # los de cerca, no los de toda la ciudad
				other._provoked_until = other._world_time + PROVOKED_LONG
	if lord_powers:
		damage = lord_powers.filter_damage(damage, attacker)
		if damage <= 0.0:
			return  # lo esquivó (atium) o no le entra (último aliento)
		impulse = lord_powers.filter_impulse(impulse)
	super(impulse, damage, attacker)


func apply_allomantic_impulse(dv: Vector3) -> void:
	super(lord_powers.filter_impulse(dv) if lord_powers else dv)


func _damage(mult: float) -> float:
	return super(mult) * (lord_powers.damage_mult() if lord_powers else 1.0)


func is_armed() -> bool:
	return not KITS[kit]["weapons"].is_empty() and not KITS[kit].get("wood", false) and not is_disarmed()


func disarm(time: float) -> void:
	rig.brace = 1.0
	super(time)


func _rearm_check() -> void:
	var was := _disarmed_until > 0.0
	super()
	if was and _disarmed_until < 0.0:
		rig.brace = 0.0
		rig.set_weapon(HumanoidRig.Weapon.SWORD)


func _next_attack(_d: float) -> void:
	var blows: Array = FIST_BLOWS if is_disarmed() else KITS[kit]["blows"]
	var total := _strike(blows[_combo_step % blows.size()])
	_combo_step += 1
	_next_blow = _world_time + (total * 0.85 + randf_range(0.3, 0.9)) * attack_delay_scale()


func _roar() -> void:
	var roar: Array = KITS[kit].get("roar", [])
	if roar.is_empty():
		return
	var total := _commit(roar[0], roar[1])
	get_tree().create_timer(total * roar[2], false).timeout.connect(_roar_blast)


func _rage() -> void:
	_enraged = true
	var rage: Array = KITS[kit].get("rage", [])
	if not rage.is_empty():
		_commit(rage[0], rage[1])
		_announce("¡Furia!")


func _announce(text: String) -> void:
	Fx.popup(get_tree().current_scene, global_position + Vector3(0, head_y(), 0), text, Color(1.0, 0.6, 0.4), 1.4)


# ---------------------------------------------------------------- Poderes

## Elige un poder que sirva a esta distancia y lo usa. Herido los encadena más seguido.
func _use_power(d: float) -> bool:
	if lord_powers:
		return lord_powers.try_use(d)
	if _foe != _player or _world_time < _next_power or is_disarmed():
		return false
	var options: Array = KITS[kit]["powers"].filter(_fits.bind(d))
	if options.is_empty():
		return false
	_power(options.pick_random(), d)
	return true


func _fits(p: Dictionary, d: float) -> bool:
	return d >= p["range"][0] and d <= p["range"][1] and _world_time >= _power_ready.get(p["name"], 0.0) \
			and health <= max_health * p.get("below", 1.0)


func _power(p: Dictionary, d: float) -> void:
	_power_ready[p["name"]] = _world_time + p["cooldown"]
	_next_power = _world_time + KITS[kit]["power_gap"] * (0.6 if _enraged else 1.0)
	_announce(p["name"])
	if p["kind"] == "dash":
		var lunge := p.duplicate()
		lunge["travel"] = maxf(d - 1.5 * _grow, 0.0) / _grow
		var strike := _strike(lunge)
		(rig as ModelRig).armored = true
		_next_blow = _world_time + strike * 0.85
		# Franja roja hasta donde llega la estocada.
		_warn(Telegraph.strip(get_tree().current_scene, global_position, _forward(), d + 1.5 * _grow, 1.4 * _grow, p["hits"][0] * strike))
		return
	_blow_id += 1
	# Aviso mínimo: si el clip pega antes de POWER_WARN s, espera quieto un momento antes de arrancar.
	var first: float = p["at"][0] * p["dur"] if p["kind"] != "leap" else p["at"][1] * p["dur"]
	var wait := maxf(POWER_WARN - first, 0.0) if p["kind"] in ["area", "cone", "leap"] else 0.0
	# El aviso sale ya; _power_go le pone el tiempo cuando sabe cuándo pega el clip.
	var scene := get_tree().current_scene
	var tel: Telegraph = null
	match p["kind"]:
		"area":
			tel = Telegraph.disc(scene, global_position, p["radius"] * sqrt(_grow), 1e6)
		"cone":
			tel = Telegraph.cone(scene, global_position, _forward(), p["range"][1] * sqrt(_grow), acos(CONE_DOT), 1e6)
		"leap":
			if is_instance_valid(_foe):
				tel = Telegraph.disc(scene, _foe.global_position, LEAP_RADIUS * _grow, 1e6, Telegraph.RED, _foe)
		"pull":
			if is_instance_valid(_foe):
				tel = Telegraph.line(scene, self, _foe, 1e6, Telegraph.CYAN, 0.25)
	if tel:
		_warn(tel)
	if wait > 0.0:
		_busy_until = _world_time + wait + 0.1
		_move_now(Vector3.ZERO)
		(rig as ModelRig).armored = true
		get_tree().create_timer(wait, false).timeout.connect(_power_go.bind(p, _blow_id, wait, tel))
	else:
		_power_go(p, _blow_id, 0.0, tel)


## Aviso mínimo (s) de los poderes que pegan en una zona (ver _power).
const POWER_WARN := 0.6


func _power_go(p: Dictionary, id: int, waited: float, tel: Telegraph) -> void:
	if id != _blow_id or down or is_stunned():
		return
	var total := _commit(p["anim"], p["dur"])
	if p["kind"] == "leap":
		var off: float = p["at"][0] * total
		var land: float = p["at"][1] * total
		if is_instance_valid(tel):
			tel.time = waited + land  # el círculo te sigue hasta que despega y queda donde va a caer
			get_tree().create_timer(off, false).timeout.connect(func() -> void:
				if is_instance_valid(tel):
					tel.follow = null)
		get_tree().create_timer(off, false).timeout.connect(_leap_off.bind(land - off))
		get_tree().create_timer(land, false).timeout.connect(_leap_land)
		return
	if is_instance_valid(tel):
		tel.time = waited + p["at"][0] * total
	if p.has("advance"):
		_move_now(_forward() * p["advance"])
		get_tree().create_timer(total * 0.9, false).timeout.connect(_end_travel.bind(_blow_id))
	for at: float in p["at"]:
		get_tree().create_timer(at * total, false).timeout.connect(_release.bind(p, _blow_id))


## El aviso se apaga si lo aturden o lo tiran antes de pegar.
func _warn(tel: Telegraph) -> void:
	var id := _blow_id
	tel.alive = func() -> bool: return is_instance_valid(self) and not down and not is_stunned() and id == _blow_id


## Llega el poder, si no lo cortaron.
func _release(p: Dictionary, id: int) -> void:
	if id != _blow_id or down or is_stunned() or (rig as ModelRig)._spell_state != p["anim"]:
		return
	match p["kind"]:
		"area":
			_hit_around(p)
		"cone":
			_hit_ahead(p)
		"pull":
			_pull(p)
		"heal":
			var cured: float = minf(max_health * p["amount"], max_health - health)
			health += cured
			Fx.popup(get_tree().current_scene, global_position + Vector3(0, head_y(), 0), "+%d" % roundi(cured), Color(0.5, 1.0, 0.55), 1.4)


func _hit_around(p: Dictionary) -> void:
	var radius: float = p["radius"] * sqrt(_grow)
	AirFx.ground(get_tree().current_scene, global_position, radius, AirFx.ASH, 0.7)
	AirFx.wave(get_tree().current_scene, global_position + Vector3.UP * 0.8, radius * 0.6, AirFx.ASH, 0.45, 0.05)
	Fx.dust(get_tree().current_scene, global_position, 1.2)
	for v in _victims():
		var away := v.global_position - global_position
		away.y = 0.0
		if v is Player and away.length() < radius * 2.0:
			v.call(&"add_trauma", 0.5)
		if away.length() < radius:
			_power_hit(v, away, p)


func _hit_ahead(p: Dictionary) -> void:
	var reach: float = p["range"][1] * sqrt(_grow)
	for i in 3:
		AirFx.push(get_tree().current_scene, global_position + Vector3.UP * 1.2 + _forward() * reach * i / 3.0, _forward(), AirFx.ASH, 1.2)
	for v in _victims():
		var to := v.global_position - global_position
		to.y = 0.0
		if to.length() < p["range"][1] * sqrt(_grow) and _forward().dot(to.normalized()) > CONE_DOT:
			_power_hit(v, to, p)


func _power_hit(v: Node3D, away: Vector3, p: Dictionary) -> void:
	mark_combat()
	Sfx.play("punch", v.global_position)
	var push: float = p["push"]
	v.call(&"take_hit", away.normalized() * push + Vector3.UP * push * 0.3, _damage(p["damage"]), self)


## Te arrastra hasta él y encadena el poder que sigue.
func _pull(p: Dictionary) -> void:
	if not is_instance_valid(_foe):
		return
	var to := global_position - _foe.global_position
	to.y = 0.0
	_foe.call(&"apply_allomantic_impulse", to.normalized() * p["push"] + Vector3.UP * 3.0)
	mark_combat()
	_power_ready.erase(p.get("then", ""))
	_next_power = _world_time + 0.6
	_next_blow = 0.0


## Esquiva si su paquete trae el clip; si no, aguanta.
func _react_to_attack(d: float, reach: float) -> bool:
	var dodge: Array = KITS[kit].get("dodge", [])
	if dodge.is_empty():
		return false
	var attacking: bool = _player.get(&"_attack_cd") > 0.0
	var started := attacking and not _foe_was_attacking
	_foe_was_attacking = attacking
	if not started or d > reach + 2.0 or _world_time < _next_react or randf() > 0.35:
		return false
	_next_react = _world_time + 3.0
	var total := _commit(dodge[0], dodge[1])
	_evade_until = _world_time + total * 0.6
	return true
