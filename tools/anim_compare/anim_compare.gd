extends Node3D
## Visor para comparar animaciones de dos modelos lado a lado (abrir anim_compare.tscn y F6).
## Arriba, un selector de animación por modelo; abajo, pausa, velocidad, "en el sitio" y reiniciar.
## Cámara: arrastrar con clic derecho para girar, rueda para acercar.

const MODELS := [
	["ActionForge", "res://assets/mixamo/Mistborn.glb"],
	["Meshy", "res://assets/meshy/Mistborn_Meshy.glb"],
]
const SPACING := 1.4

var _players: Array[AnimationPlayer] = []
var _skels: Array[Skeleton3D] = []
var _hips: Array[int] = []
var _speed := 1.0
var _paused := false
var _in_place := true
var _cam: Camera3D
var _yaw := 0.0
var _pitch := -0.15
var _dist := 4.0
var _time_labels: Array[Label] = []


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.57, 0.62)
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.4, 0.41, 0.44)
	floor_mesh.material_override = floor_mat
	add_child(floor_mesh)
	_cam = Camera3D.new()
	_cam.fov = 45
	add_child(_cam)
	_update_camera()

	var ui := CanvasLayer.new()
	add_child(ui)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 12)
	top.add_theme_constant_override("separation", 40)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	ui.add_child(top)
	for i in MODELS.size():
		_load_model(i, top)
	_build_controls(ui)


func _load_model(i: int, top: HBoxContainer) -> void:
	var model: Node3D = (load(MODELS[i][1]) as PackedScene).instantiate()
	add_child(model)
	model.position.x = (i - (MODELS.size() - 1) / 2.0) * SPACING
	_fix_materials(model)
	var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	_players.append(ap)
	_skels.append(skel)
	_hips.append(BoneTools.find_bone(skel, ["pelvis", "mixamorig:Hips", "Hips"]))

	var box := VBoxContainer.new()
	top.add_child(box)
	var title := Label.new()
	title.text = MODELS[i][0]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var pick := OptionButton.new()
	var names := Array(ap.get_animation_list())
	names.sort()
	for n in names:
		pick.add_item(n)
	pick.item_selected.connect(func(idx: int) -> void: _play(i, pick.get_item_text(idx)))
	box.add_child(pick)
	var time := Label.new()
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(time)
	_time_labels.append(time)
	# Empieza con el idle si lo hay, si no con la primera.
	var first := names.find("idle")
	pick.select(maxi(first, 0))
	_play(i, pick.get_item_text(pick.selected))


## ActionForge y Meshy exportan el color como emisión: se pasa a color base para que tenga sombras.
func _fix_materials(model: Node3D) -> void:
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if m == null or m.emission_texture == null:
				continue
			m = m.duplicate()
			m.albedo_texture = m.emission_texture
			m.albedo_color = Color.WHITE
			m.emission_enabled = false
			m.roughness = 0.85
			mi.set_surface_override_material(s, m)


func _play(i: int, anim: String) -> void:
	_players[i].get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	_players[i].play(anim)
	_players[i].seek(0.0, true)


func _build_controls(ui: CanvasLayer) -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 12)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 16)
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN  # crece hacia arriba desde el borde inferior
	ui.add_child(bar)
	var pause := Button.new()
	pause.text = "Pausa"
	pause.pressed.connect(func() -> void:
		_paused = not _paused
		pause.text = "Seguir" if _paused else "Pausa")
	bar.add_child(pause)
	var restart := Button.new()
	restart.text = "Reiniciar las dos"
	restart.pressed.connect(func() -> void:
		for ap in _players:
			ap.seek(0.0, true))
	bar.add_child(restart)
	var speed_label := Label.new()
	speed_label.text = "Velocidad ×1.0"
	bar.add_child(speed_label)
	var speed := HSlider.new()
	speed.min_value = 0.1
	speed.max_value = 2.0
	speed.step = 0.05
	speed.value = 1.0
	speed.custom_minimum_size.x = 200
	speed.value_changed.connect(func(v: float) -> void:
		_speed = v
		speed_label.text = "Velocidad ×%.2f" % v)
	bar.add_child(speed)
	var in_place := CheckBox.new()
	in_place.text = "En el sitio"
	in_place.button_pressed = true
	in_place.toggled.connect(func(on: bool) -> void: _in_place = on)
	bar.add_child(in_place)


func _process(delta: float) -> void:
	for i in _players.size():
		var ap := _players[i]
		if not _paused:
			ap.advance(delta * _speed)
		if _in_place and _hips[i] >= 0:
			_pin_hips(_skels[i], _hips[i])
		var anim := ap.get_animation(ap.current_animation)
		_time_labels[i].text = "%.2f / %.2f s" % [ap.current_animation_position, anim.length if anim else 0.0]


## Anula el avance horizontal de la cadera (las de Meshy no vienen "en el sitio").
func _pin_hips(skel: Skeleton3D, hips: int) -> void:
	var rest := skel.global_transform * skel.get_bone_global_rest(hips).origin
	var now := BoneTools.bone_world_pos(skel, hips)
	var target := Vector3(rest.x, now.y, rest.z)
	var parent := skel.get_bone_parent(hips)
	var parent_pose := skel.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	var local := (skel.global_transform * parent_pose).affine_inverse() * target
	skel.set_bone_pose_position(hips, local)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		_yaw -= event.relative.x * 0.01
		_pitch = clampf(_pitch - event.relative.y * 0.01, -1.2, 0.4)
		_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist - 0.3, 1.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(_dist + 0.3, 12.0)
		_update_camera()


func _update_camera() -> void:
	var center := Vector3(0, 0.9, 0)
	var offset := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch) * Vector3(0, 0, _dist)
	_cam.look_at_from_position(center + offset, center)
