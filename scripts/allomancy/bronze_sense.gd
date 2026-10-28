class_name BronzeSense
extends Node3D
## Bronce del jugador: mientras lo quemas, sientes los pulsos de los alománticos cercanos que
## están quemando metales: ondas del color de su metal, a través de las paredes.
## No sientes a nadie que esté dentro de una nube de cobre (ni a quien solo quema cobre).
## Avivar el bronce amplía el alcance y acelera el ritmo.

const PULSE_SHADER := preload("res://shaders/pulse.gdshader")

@export var sense_range := 60.0

var holder: Node3D

var _timer := 0.0
var _sphere := SphereMesh.new()


func _ready() -> void:
	_sphere.radius = 1.0
	_sphere.height = 2.0
	_sphere.radial_segments = 24
	_sphere.rings = 12


func _process(delta: float) -> void:
	var a: Allomancy = holder.allomancy
	var s := a.strength(&"bronze")
	if s <= 0.0:
		return
	_timer -= delta / Engine.time_scale
	if _timer > 0.0:
		return
	_timer = 0.8 / s
	var reach := sense_range * (1.0 + 0.5 * (s - 1.0))
	for n in get_tree().get_nodes_in_group(&"allomancer_body"):
		var body := n as Node3D
		if body == holder or body.global_position.distance_to(holder.global_position) > reach:
			continue
		if not Metals.emits_pulses(body):
			continue
		var metals: Array = body.allomancy.burning_metals().filter(func(m): return m != &"copper")
		_spawn_pulse(body.global_position + Vector3(0, 1.1, 0), Allomancy.METALS[metals.pick_random()]["color"])


func _spawn_pulse(pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere
	var mat := ShaderMaterial.new()
	mat.shader = PULSE_SHADER
	mat.set_shader_parameter(&"tint", color)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.3
	var tw := mi.create_tween().set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 2.2, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(v: float): mat.set_shader_parameter(&"strength", v), 1.0, 0.0, 0.7)
	tw.chain().tween_callback(mi.queue_free)
