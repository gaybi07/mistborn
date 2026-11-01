class_name SkaaWorker
extends Node3D
## Skaa trabajando en el lugar: repite su tarea (cavar, empujar un cajón, tirar de una soga...).
## Con `route` distinto de cero es un cargador: levanta una caja, la lleva hasta position + route,
## la deja y vuelve con las manos vacías. Modelo con el esqueleto del Mistborn
## (tools/blender/rig_like_mistborn.py) y animaciones de Mixamo (MixamoSpells.glb).

## Estados de ModelRig.ANIMS que sirven de trabajo en el lugar.
const TASKS := ["dig", "push_heavy", "pull_heavy", "iron_pull", "lift_heavy", "kneel_pull", "kneel_inspect",
		"kneel_work", "sad_idle"]
## Tareas que necesitan un cajón delante.
const WITH_CRATE := ["push_heavy", "pull_heavy", "lift_heavy"]
const CARRY_SPEED := 1.1  # a la velocidad a la que pisa carry_walk (si no, patina)
const WALK_SPEED := 0.72  # la de sad_walk

var task := ""
var route := Vector3.ZERO
var rig: ModelRig

var _crate: MeshInstance3D
var _big: MeshInstance3D  # cajón de las tareas WITH_CRATE: se ubica donde quedan las manos
var _big_at := 0.6  # segundos de animación antes de medir las manos
var _start := Vector3.ZERO
var _step := 0  # cargador: 0 levanta, 1 lleva, 2 deja, 3 vuelve
var _loaded_at := 0.0


func _ready() -> void:
	if task == "" and route == Vector3.ZERO:
		task = TASKS.pick_random()
	rig = Art.skaa_rig()
	add_child(rig)
	_start = position
	if route != Vector3.ZERO:
		_crate = _make_crate(0.42)
		add_child(_crate)
		_crate.visible = false
		_face(_start + route)
		_begin(0)
	elif task in WITH_CRATE:
		_big = _make_crate(0.5 if task == "lift_heavy" else 0.8)
		_big.visible = false
		add_child(_big)


func _process(delta: float) -> void:
	if route == Vector3.ZERO:
		if rig._spell <= 0.0:
			rig.play_spell(task, 60.0)  # duración larga: a su velocidad natural, y se vuelve a empezar
		if _big and not _big.visible:
			_big_at -= delta
			if _big_at <= 0.0:
				_place_big_crate()
		return
	match _step:
		0, 2:  # levantando o dejando la caja: la caja aparece o desaparece a mitad del gesto
			_crate.visible = (_step == 0) == (rig._spell < _loaded_at)
			if rig._spell <= 0.0:
				_begin(_step + 1)
		1, 3:
			var goal := _start + route if _step == 1 else _start
			var to := goal - position
			var speed := CARRY_SPEED if _step == 1 else WALK_SPEED
			if to.length() < 0.1:
				_face(_start if _step == 1 else _start + route)
				_begin((_step + 1) % 4)
				return
			position += to.normalized() * minf(speed * delta, to.length())
			if rig._spell <= 0.0:
				rig.play_spell("carry_walk" if _step == 1 else "sad_walk", 60.0)
	if _crate.visible:
		# La caja va entre las manos (las sostiene de los costados).
		_crate.global_position = _hands_mid()


func _begin(step: int) -> void:
	_step = step
	var anim: String = ["pick_up", "carry_walk", "put_down", "sad_walk"][step]
	rig.play_spell(anim, 60.0)
	_loaded_at = rig._spell * 0.5
	if step == 1 or step == 3:
		_face(_start + route if step == 1 else _start)
	_crate.visible = step == 1 or step == 2


func _hands_mid() -> Vector3:
	var skel := rig._skel
	return (BoneTools.bone_world_pos(skel, rig._bones["hand_l"]) + BoneTools.bone_world_pos(skel, rig._bones["hand_r"])) * 0.5


## El cajón grande se apoya en el suelo con una cara donde están las manos (delante o detrás según
## empuje, tire o levante).
func _place_big_crate() -> void:
	var hands := to_local(_hands_mid())
	if task == "lift_heavy":
		# Lo que levanta va delante de los pies (al empezar las manos todavía están en el cuerpo).
		_big.position = Vector3(hands.x, 0.25, minf(hands.z, -0.45))
	else:
		var dir := signf(hands.z) if absf(hands.z) > 0.05 else -1.0
		_big.position = Vector3(hands.x, 0.4, hands.z + dir * 0.4)
	_big.visible = true


func _face(target: Vector3) -> void:
	var d := target - position
	d.y = 0.0
	if d.length() > 0.01:
		rotation.y = atan2(-d.x, -d.z)  # -Z es el frente


static func _make_crate(size: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.25, 0.15)
	mat.roughness = 0.9
	box.material = mat
	m.mesh = box
	return m
