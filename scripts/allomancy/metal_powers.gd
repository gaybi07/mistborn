class_name MetalPowers
extends Node
## Base de los poderes de un metal del jugador (cinc, latón, cobre, bronce, atium): recargas, a quién apuntar y quién
## está cerca. Cada metal hereda y llena `metal`, `cooldowns` y _use. Player solo despacha (ver Player._skill_press).

var player: Player
## Metal de estos poderes (se enciende un momento al usarlos).
var metal: StringName
## id -> recarga (s) de cada activa.
var cooldowns := {}
var _ready_ms := {}


func has(id: StringName) -> bool:
	return cooldowns.has(id)


## Cuánto falta de la recarga (1 = recién usado, 0 = listo), para el HUD.
func cooldown(id: StringName) -> float:
	return clampf(float(int(_ready_ms.get(id, 0)) - Time.get_ticks_msec()) / (float(cooldowns[id]) * 1000.0), 0.0, 1.0)


## Si el poder está haciendo algo ahora (para el HUD). Cada metal dice cuáles.
func active(_id: StringName) -> bool:
	return false


## Duración con el nivel del poder: la de nivel 1 y un ZINC_PER_LEVEL más por cada nivel.
static func scale(id: StringName) -> float:
	return 1.0 + SkillTree.ZINC_PER_LEVEL * maxi(Progression.skill_level(id) - 1, 0)


## Pasiva del metal: con al menos un punto y el metal encendido.
func passive(id: StringName) -> bool:
	return Progression.skill_level(id) >= 1 and player.allomancy.is_burning(metal)


## Usa el poder. Devuelve si se usó (si no, no hay recarga ni se queda el metal encendido).
func use(id: StringName) -> bool:
	if player.dead:
		return false
	var now := Time.get_ticks_msec()
	if now < int(_ready_ms.get(id, 0)):
		player.notice.emit("%s recargando (%d s)" % [_name(id), ceili((int(_ready_ms[id]) - now) / 1000.0)])
		return false
	if not _use(id):
		return false
	_ready_ms[id] = now + int(float(cooldowns[id]) * 1000.0)
	return true


## Lo que hace cada activa; devuelve si se usó.
func _use(_id: StringName) -> bool:
	return false


func _name(id: StringName) -> String:
	return String(SkillTree.find(id).get("name", id))


## El NPC de la mira (o null, avisando).
func _target(range_m: float) -> Npc:
	var npc := player._aim_npc(range_m)
	if npc == null:
		player.notice.emit("Apuntá a alguien")
	return npc


func _near(center: Vector3, radius: float) -> Array[Npc]:
	var out: Array[Npc] = []
	for n in get_tree().get_nodes_in_group(&"npc"):
		var npc := n as Npc
		if npc and not npc.down and npc.global_position.distance_to(center) <= radius:
			out.append(npc)
	return out


## Los NPC en un cono hacia donde mirás.
func _cone(range_m: float, angle: float) -> Array[Npc]:
	var fwd := player.aim_direction()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var out: Array[Npc] = []
	for npc in _near(player.global_position, range_m):
		var to := npc.global_position - player.global_position
		to.y = 0.0
		if fwd.angle_to(to) <= angle:
			out.append(npc)
	return out


func _closest(npc: Node3D, among: Array[Npc]) -> Npc:
	var best: Npc = null
	var best_d := INF
	for other in among:
		var d := other.global_position.distance_to(npc.global_position)
		if other != npc and d < best_d:
			best = other
			best_d = d
	return best


## Color del metal para las ondas.
func _color() -> Color:
	return Color(Allomancy.METALS[metal]["color"], 0.2)


## Gesto del jugador (clip provisorio, ver Pedidos de animación en docs/TAREAS.md) y la onda sobre `at`.
func _fx(at: Node3D, gesture: String, radius := 2.0) -> void:
	player.rig.play_skill(gesture, 1.2)
	AirFx.wave(get_tree().current_scene, at.global_position + Vector3(0, 1.2, 0), radius, _color(), 0.5, 0.03, null, true)


## Cuánto multiplica la distancia a la que te ven (Player.concealment). 1 = nada.
func concealment() -> float:
	return 1.0


## Multiplicador del golpe que el jugador le da a `npc` ahora (golpe a traición, crítico); puede gastar el efecto.
func strike_bonus(_npc: Npc) -> float:
	return 1.0


## Cuánto dura sobre el jugador el cinc o el latón ajenos (Mente cerrada). 1 = entero.
func emotion_resist() -> float:
	return 1.0
