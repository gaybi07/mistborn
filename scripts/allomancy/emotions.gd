class_name Emotions
extends Node
## Cinc (enardecer) y latón (aplacar) del jugador.
## Quemando: afecta al PNJ más cercano a la mira. Avivando: a todos los que tengas delante (un cono).
## Quien quema cobre es inmune.

@export var reach := 25.0
@export var select_radius := 0.15  ## fracción del alto de pantalla alrededor de la mira
@export var cone_range := 20.0
@export var cone_angle := deg_to_rad(35.0)

var player: Player
## PNJ afectados en el último paso (para la HUD).
var affected: Array[Npc] = []


func _physics_process(_delta: float) -> void:
	affected.clear()
	for metal: StringName in [&"zinc", &"brass"]:
		var s := player.allomancy.strength(metal)
		if s <= 0.0:
			continue
		var targets: Array[Npc] = _cone() if s > 1.0 else _under_aim()
		for npc in targets:
			if npc.apply_emotion(metal, s, player) and not affected.has(npc):
				affected.append(npc)


func _under_aim() -> Array[Npc]:
	var cam := player.camera
	var view := get_viewport().get_visible_rect().size
	var best: Npc = null
	var best_off := select_radius
	for n in get_tree().get_nodes_in_group(&"npc"):
		var npc := n as Npc
		var c := Metals.center_of(npc)
		if npc.down or c.distance_to(player.global_position) > reach or cam.is_position_behind(c):
			continue
		var off := cam.unproject_position(c).distance_to(view * 0.5) / view.y
		if off < best_off:
			best_off = off
			best = npc
	var out: Array[Npc] = []
	if best:
		out.append(best)
	return out


func _cone() -> Array[Npc]:
	var fwd := player.aim_direction()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var out: Array[Npc] = []
	for n in get_tree().get_nodes_in_group(&"npc"):
		var npc := n as Npc
		var to := npc.global_position - player.global_position
		to.y = 0.0
		if not npc.down and to.length() <= cone_range and fwd.angle_to(to) <= cone_angle:
			out.append(npc)
	return out
