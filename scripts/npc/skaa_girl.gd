class_name SkaaGirl
extends Node3D
## Nena skaa: camina de un punto a otro de la calle, se sienta en el piso un rato y se levanta. Todo sale de los clips
## del modelo: Walking_Woman y Arise, que al revés es sentarse. Sin colisión, no se le puede pegar.

const MODEL := "res://assets/skaa/SkaaPilgrim.glb"
const SIZE := 0.72
const WALK_SPEED := 0.83  # Walking_Woman pisa a 1,15 m/s en tamaño adulto
const SIT_TIME := Vector2(4.0, 9.0)
const TURN_SPEED := 5.0
const FLOOR_TIME := 0.2  # segundo de Arise en el que está sentada en el piso

enum Step { WALK, SIT_DOWN, SITTING, RISE }

var spots: Array[Vector3] = []  # entre estos dos puntos va y viene
var facing := 0.0  # hacia dónde mira sentada

var rig: ModelRig
var _step := Step.WALK
var _target := 1
var _left := 0.0
var _clip_t := 0.0


func _ready() -> void:
	add_to_group(&"map_npc")
	scale = Vector3.ONE * SIZE
	rig = Art.skaa_girl_rig()
	add_child(rig)
	position = spots[0]
	rotation.y = facing


func _process(delta: float) -> void:
	match _step:
		Step.WALK:
			var to := spots[_target] - position
			to.y = 0.0
			if to.length() < 0.05:
				_sit_down()
				return
			position += to.normalized() * minf(WALK_SPEED * delta, to.length())
			position.y = CityPlan.ground(Vector2(position.x, position.z))
			_turn_to(atan2(-to.x, -to.z), delta)
			if rig._spell <= 0.0:
				rig.play_spell("walk", 60.0)
		Step.SIT_DOWN:
			_turn_to(facing, delta)
			_clip_t -= delta
			if _clip_t <= FLOOR_TIME:
				_clip_t = FLOOR_TIME
				_left = randf_range(SIT_TIME.x, SIT_TIME.y)
				_step = Step.SITTING
			_hold_clip()
		Step.SITTING:
			_left -= delta
			_hold_clip()
			if _left <= 0.0:
				_step = Step.RISE
		Step.RISE:
			_clip_t += delta
			if _clip_t >= rig._current_length():
				_target = 1 - _target
				_step = Step.WALK
				rig._spell = 0.0
				return
			_hold_clip()


func _sit_down() -> void:
	_step = Step.SIT_DOWN
	rig.play_spell("get_up", 60.0)
	_clip_t = rig._current_length()
	_hold_clip()


## Este clip lo maneja la nena: el rig lo deja donde ella dice.
func _hold_clip() -> void:
	rig._seek_time(_clip_t)
	rig._spell = 1.0


func _turn_to(yaw: float, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-TURN_SPEED * delta))
