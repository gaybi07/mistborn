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
		"height": 1.95, "health": 900.0, "speed": 5.0, "weapons": ["res://assets/weapons/sword_steel.glb"], "power_gap": 5.0,
		"states": {"idle": ["Combat_Stance"], "idle_armed": ["Combat_Stance"], "walk": ["Walking"], "run": ["Running"], "sprint": ["Running"],
				"flee": ["Running"], "down": ["falling_down"]},
		"blows": [
			{"anim": "Double_Combo_Attack", "dur": 2.3, "hits": [0.22, 0.42], "damage": 1.2, "push": 7.0, "travel": 0.6},
			{"anim": "Weapon_Combo", "dur": 2.9, "hits": [0.18, 0.34, 0.6], "damage": 1.0, "push": 6.0, "travel": 0.8},
			{"anim": "Triple_Combo_Attack", "dur": 3.4, "hits": [0.18, 0.35, 0.51], "damage": 1.2, "push": 9.0, "travel": 1.0},
		],
		"powers": [
			{"name": "Torbellino", "kind": "area", "anim": "Axe_Spin_Attack", "dur": 2.2, "at": [0.39], "radius": 4.0, "damage": 1.6, "push": 10.0, "range": [0.0, 4.0], "cooldown": 9.0},
			{"name": "Temblor", "kind": "area", "anim": "Kneel_on_One_Knee_and_Stand", "dur": 2.2, "at": [0.08], "radius": 8.0, "damage": 1.0, "push": 8.0, "range": [0.0, 7.0], "cooldown": 15.0},
			{"name": "Empujón de acero", "kind": "cone", "anim": "Punch_Combo", "dur": 2.0, "at": [0.51], "damage": 0.8, "push": 18.0, "range": [2.0, 12.0], "cooldown": 10.0},
			{"name": "Tirón de hierro", "kind": "pull", "anim": "Left_Slash", "dur": 2.6, "at": [0.38], "push": 14.0, "range": [5.0, 16.0], "cooldown": 11.0, "then": "Torbellino"},
			{"name": "Embestida", "kind": "dash", "anim": "Weapon_Combo_1", "dur": 2.8, "hits": [0.23, 0.48, 0.7], "damage": 1.1, "push": 8.0, "range": [4.0, 11.0], "cooldown": 9.0},
			{"name": "Regeneración", "kind": "heal", "anim": "Limping_Walk", "dur": 3.5, "at": [0.85], "amount": 0.15, "advance": 0.7, "below": 0.6, "range": [0.0, 30.0], "cooldown": 25.0},
		],
	},
	"KolossAdulto": {
		"height": 2.9, "health": 300.0, "speed": 6.0, "weapons": ["res://assets/weapons/koloss_greatsword.glb"], "power_gap": 6.0,
		"states": {"idle": ["Chest_Pound_Taunt"], "idle_armed": ["Chest_Pound_Taunt"], "walk": ["Walking"], "run": ["Running"], "sprint": ["run_fast_3_inplace"],
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
		"height": 2.0, "health": 170.0, "speed": 5.2, "weapons": ["res://assets/weapons/koloss_axe.glb", "res://assets/weapons/koloss_axe.glb"], "power_gap": 7.0,
		"states": {"idle": ["Axe_Stance"], "idle_armed": ["Axe_Stance"], "walk": ["Walking"], "run": ["Running"], "sprint": ["RunFast"],
				"flee": ["Running"], "down": ["dying_backwards"]},
		"holds": {"idle": 0.9, "idle_armed": 0.9},  # el paquete no trae clip de estar parado: el último tramo de Axe_Stance
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
		"height": 1.9, "health": 140.0, "speed": 4.6, "weapons": [], "power_gap": 3.5, "passive": true,
		"states": {"idle": ["mage_soell_cast_7"], "idle_armed": ["mage_soell_cast_7"], "walk": ["Walking"], "run": ["Running"], "sprint": ["Run_02"],
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
const CONE_DOT := 0.6  # adelante, unos 50° para cada lado
const PROVOKED_LONG := 30.0

## Clave de KITS. shortcut: los inquisidores usan el modelo encapuchado, cambiarlo cuando haya uno propio.
var kit := "MistbornHood"
var _next_power := 0.0
var _power_ready := {}  # nombre del poder -> cuándo se puede volver a usar


## Todos los clips sueltos que juega este kit, además de los de `states`.
static func clips_of(kit_name: String) -> Array:
	var spec: Dictionary = KITS[kit_name]
	var out := []
	for entry: Dictionary in spec["blows"] + spec["powers"]:
		out.append(entry["anim"])
	for key in ["roar", "rage", "dodge"]:
		if spec.has(key):
			out.append(spec[key][0])
	return out


func _role() -> String:
	return "champion:" + kit


func _setup() -> void:
	axes = true  # sin la guardia del espadón
	super()
	var spec: Dictionary = KITS[kit]
	max_health = spec["health"]
	walk_speed = 1.3 * _grow
	run_speed = spec["speed"]
	_next_leap = INF
	_next_power = randf_range(1.0, 3.0)
	if spec["weapons"].is_empty():
		rig.set_weapon(HumanoidRig.Weapon.NONE)
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
			other._provoked_until = other._world_time + PROVOKED_LONG
	super(impulse, damage, attacker)


func _next_attack(_d: float) -> void:
	var blows: Array = KITS[kit]["blows"]
	var total := _strike(blows[_combo_step % blows.size()])
	_combo_step += 1
	_next_blow = _world_time + total * 0.85 + randf_range(0.3, 0.9)


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
	if _foe != _player or _world_time < _next_power:
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
		return
	_blow_id += 1
	var total := _commit(p["anim"], p["dur"])
	if p["kind"] == "leap":
		var off: float = p["at"][0] * total
		var land: float = p["at"][1] * total
		get_tree().create_timer(off, false).timeout.connect(_leap_off.bind(land - off))
		get_tree().create_timer(land, false).timeout.connect(_leap_land)
		return
	if p.has("advance"):
		_move_now(_forward() * p["advance"])
		get_tree().create_timer(total * 0.9, false).timeout.connect(_end_travel.bind(_blow_id))
	for at: float in p["at"]:
		get_tree().create_timer(at * total, false).timeout.connect(_release.bind(p, _blow_id))


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
	for v in _victims():
		var away := v.global_position - global_position
		away.y = 0.0
		if v is Player and away.length() < radius * 2.0:
			v.call(&"add_trauma", 0.5)
		if away.length() < radius:
			_power_hit(v, away, p)


func _hit_ahead(p: Dictionary) -> void:
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
