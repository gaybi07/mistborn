class_name Champion
extends Koloss
## Lord Legislador e Inquisidores: pelean con el cerebro del koloss, pero con sus propios clips de Meshy y sin rugir,
## saltar ni enfurecerse. `hits` son los picos de velocidad de la mano, medidos en cada clip.

const KITS := {
	"LordRuler": {"health": 900.0, "weapon": "res://assets/weapons/sword_steel.glb", "blows": [
		{"anim": "Double_Combo_Attack", "dur": 2.2, "hits": [0.24, 0.42], "damage": 1.2, "push": 7.0, "travel": 0.6},
		{"anim": "Weapon_Combo", "dur": 2.8, "hits": [0.15, 0.35, 0.61], "damage": 1.0, "push": 6.0, "travel": 0.8},
		{"anim": "Triple_Combo_Attack", "dur": 3.3, "hits": [0.18, 0.36, 0.52], "damage": 1.2, "push": 9.0, "travel": 1.0},
	]},
	"MistbornHood": {"health": 320.0, "weapon": "res://assets/weapons/sword_obsidian.glb", "blows": [
		{"anim": "Attack", "dur": 2.1, "hits": [0.39], "damage": 1.2, "push": 8.0, "travel": 0.4},
		{"anim": "Left_Slash", "dur": 2.4, "hits": [0.24, 0.44], "damage": 0.9, "push": 5.0, "travel": 0.4},
		{"anim": "Weapon_Combo_1", "dur": 2.7, "hits": [0.23, 0.41, 0.7], "damage": 0.9, "push": 6.0, "travel": 0.8},
	]},
}

## Clave de KITS. shortcut: los inquisidores usan el modelo encapuchado, cambiarlo cuando haya uno propio.
var kit := "MistbornHood"


func _role() -> String:
	return "champion:" + kit


func _setup() -> void:
	axes = true  # sin la guardia del espadón
	super()
	max_health = KITS[kit]["health"]
	walk_speed = 1.3
	run_speed = 5.0
	_next_leap = INF


func _next_attack(_d: float) -> void:
	var blows: Array = KITS[kit]["blows"]
	var total := _strike(blows[_combo_step % blows.size()])
	_combo_step += 1
	_next_blow = _world_time + total * 0.85 + randf_range(0.3, 0.9)


func _roar() -> void:
	pass


func _rage() -> void:
	_enraged = true
