class_name TinVision
extends Node3D
## Estaño: percibir a la gente. Si la ves de frente, solo se remarca su silueta con un borde luminoso. Si una pared te la tapa,
## se ve como una estela de humo sin forma definida que sale de donde estaba hace un momento (el retraso depende del poder).
##  · Oído agudo (pasiva): cerca, humo tenue con 0,5 s de retraso.
##  · Marca del cazador: el enemigo marcado, humo más denso y concentrado con 0,2 s de retraso, y un borde fuerte si lo ves.
##  · Sentidos extremos: todos los de alrededor en tiempo real, con más humo.

const EAR_RANGE := 22.0
const EAR_DELAY := 0.5
const MARK_DELAY := 0.2
const EXTREME_RANGE := 45.0
const MARK_RANGE := 80.0
const SAMPLE := 0.05
const HISTORY := 2.0
const MAX_GHOSTS := 14
const TINT := Color(0.82, 0.86, 0.72)
const MARK_TINT := Color(1.0, 0.92, 0.65)

## Borde luminoso para el enemigo que ves de frente (se superpone a su modelo).
const RIM_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.82, 0.86, 0.72, 1.0);
uniform float strength = 1.0;

void fragment() {
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
	ALBEDO = tint.rgb;
	ALPHA = clamp(fres * strength, 0.0, 1.0);
}
"""

var player: Player

var _quad := QuadMesh.new()
var _soft := GradientTexture2D.new()
var _rim_shader := Shader.new()
var _rims := {}  ## modo -> ShaderMaterial del borde
var _profiles := {}  ## modo -> ParticleProcessMaterial
## id de enemigo -> [Vector4(t, x, y, z)] con su posición reciente.
var _history := {}
## id de enemigo -> {npc, particles, mat, mode, blocked, next_los, seen, overlay, meshes}
var _ghosts := {}


func _ready() -> void:
	top_level = true
	_rim_shader.code = RIM_CODE
	for mode in ["ear", "extreme", "mark"]:
		var rim := ShaderMaterial.new()
		rim.shader = _rim_shader
		rim.set_shader_parameter(&"tint", MARK_TINT if mode == "mark" else TINT)
		rim.set_shader_parameter(&"strength", {"ear": 0.7, "extreme": 0.95, "mark": 1.6}[mode])
		_rims[mode] = rim
	_quad.size = Vector2.ONE
	# Un punto blando y redondo: cada voluta de humo es uno, y juntos forman una estela sin contorno.
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_soft.gradient = ramp
	_soft.fill = GradientTexture2D.FILL_RADIAL
	_soft.fill_from = Vector2(0.5, 0.5)
	_soft.fill_to = Vector2(0.5, 0.0)
	_soft.width = 64
	_soft.height = 64
	_profiles["ear"] = _profile(Vector3(0.2, 0.65, 0.2), 0.5, 0.9, 1.7)
	_profiles["extreme"] = _profile(Vector3(0.2, 0.65, 0.2), 0.5, 0.95, 1.8)
	_profiles["mark"] = _profile(Vector3(0.14, 0.6, 0.14), 0.35, 0.6, 1.0)


## Cómo se mueve y crece el humo: sube despacio, se agranda y se desvanece, con un poco de remolino.
func _profile(extents: Vector3, scale_min: float, scale_max: float, growth: float) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.direction = Vector3.UP
	pm.spread = 30.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.4
	pm.gravity = Vector3(0.0, 0.22, 0.0)
	pm.damping_min = 0.2
	pm.damping_max = 0.6
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.scale_min = scale_min
	pm.scale_max = scale_max
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.6))
	grow.add_point(Vector2(1.0, growth))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	pm.scale_curve = grow_tex
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	pm.color_ramp = fade_tex
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.5
	pm.turbulence_noise_scale = 1.6
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.2
	return pm


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player) or not player.is_local_player() or player.dead:
		_hide_all()
		return
	var now := Time.get_ticks_msec() / 1000.0
	var strength := player.allomancy.strength(&"tin")
	var ear := player.skill_unlocked(&"tin_ear") and strength > 0.0
	var extreme := player.is_extreme_senses()
	var marked := player.marked_npc()
	if not (ear or extreme or marked != null):
		_hide_all()
		_history.clear()
		return
	var origin := player.global_position
	var wanted: Array = []
	for n in get_tree().get_nodes_in_group(&"npc"):
		var npc := n as Npc
		if npc == null or npc.down:
			continue
		var d := npc.global_position.distance_to(origin)
		if d > MARK_RANGE + 5.0:
			continue
		_record(npc, now)
		var mode := ""
		if npc == marked and d <= MARK_RANGE:
			mode = "mark"
		elif extreme and d <= EXTREME_RANGE:
			mode = "extreme"
		elif ear and d <= EAR_RANGE + 8.0 * (strength - 1.0):
			mode = "ear"
		if mode != "":
			wanted.append([d, npc, mode])
	wanted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var shown := {}
	for i in mini(wanted.size(), MAX_GHOSTS):
		var npc: Npc = wanted[i][1]
		shown[npc.get_instance_id()] = true
		_update_ghost(npc, wanted[i][2], now)
	for id: int in _ghosts.keys():
		var g: Dictionary = _ghosts[id]
		if not is_instance_valid(g["npc"]):
			_free_ghost(id)
		elif not shown.has(id):
			_quiet(g)
			if now - float(g["seen"]) > 8.0:
				_free_ghost(id)


func _record(npc: Npc, now: float) -> void:
	var id := npc.get_instance_id()
	var arr: Array = _history.get(id, [])
	if arr.is_empty() or now - (arr[-1] as Vector4).x >= SAMPLE:
		var p := npc.global_position
		arr.append(Vector4(now, p.x, p.y, p.z))
		while arr.size() > 2 and (arr[0] as Vector4).x < now - HISTORY:
			arr.pop_front()
	_history[id] = arr


## Dónde estaba el enemigo en el instante `t` (o `fallback` si es ahora mismo o no hay historia).
func _sample(id: int, t: float, fallback: Vector3) -> Vector3:
	var arr: Array = _history.get(id, [])
	if arr.is_empty() or t >= (arr[-1] as Vector4).x:
		return fallback
	if t <= (arr[0] as Vector4).x:
		var first: Vector4 = arr[0]
		return Vector3(first.y, first.z, first.w)
	for i in range(arr.size() - 1, 0, -1):
		var a: Vector4 = arr[i - 1]
		if a.x <= t:
			var b: Vector4 = arr[i]
			var k := clampf((t - a.x) / maxf(b.x - a.x, 0.001), 0.0, 1.0)
			return Vector3(lerpf(a.y, b.y, k), lerpf(a.z, b.z, k), lerpf(a.w, b.w, k))
	return fallback


func _ghost_for(npc: Npc) -> Dictionary:
	var id := npc.get_instance_id()
	if _ghosts.has(id):
		return _ghosts[id]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.particles_anim_h_frames = 1
	mat.particles_anim_v_frames = 1
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft
	mat.no_depth_test = true
	mat.disable_fog = true
	var particles := GPUParticles3D.new()
	particles.top_level = true
	particles.emitting = false
	particles.local_coords = false
	particles.draw_pass_1 = _quad
	particles.material_override = mat
	particles.visibility_aabb = AABB(Vector3(-15.0, -5.0, -15.0), Vector3(30.0, 12.0, 30.0))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	var g := {"npc": npc, "particles": particles, "mat": mat, "mode": "", "blocked": true, "next_los": 0.0, "seen": 0.0,
			"overlay": null, "meshes": []}
	_ghosts[id] = g
	return g


## Cambia el humo de un enemigo al estilo de ese modo (densidad, tamaño y duración).
func _configure(g: Dictionary, mode: String) -> void:
	g["mode"] = mode
	var particles: GPUParticles3D = g["particles"]
	particles.process_material = _profiles[mode]
	var alpha := 0.2
	match mode:
		"ear":
			particles.amount = 28
			particles.lifetime = 1.7
		"extreme":
			particles.amount = 44
			particles.lifetime = 1.8
			alpha = 0.3
		"mark":
			particles.amount = 40
			particles.lifetime = 0.9
			alpha = 0.5
	var color := MARK_TINT if mode == "mark" else TINT
	(g["mat"] as StandardMaterial3D).albedo_color = Color(color, alpha)


func _update_ghost(npc: Npc, mode: String, now: float) -> void:
	var g := _ghost_for(npc)
	g["seen"] = now
	if g["mode"] != mode:
		_configure(g, mode)
	# ¿Hay una pared entre tu cámara y él? Solo entonces se ve el humo; si no, ya lo ves de verdad.
	if now >= float(g["next_los"]):
		g["next_los"] = now + 0.12
		var chest := npc.global_position + Vector3(0.0, 1.0, 0.0)
		var query := PhysicsRayQueryParameters3D.create(player.camera.global_position, chest, Props.LAYER_WORLD)
		g["blocked"] = not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	var blocked: bool = g["blocked"]
	var particles: GPUParticles3D = g["particles"]
	_apply_overlay(g, null if blocked else _rims[mode])
	if particles.emitting != blocked:
		particles.emitting = blocked
	if not blocked:
		return
	var delay := EAR_DELAY
	match mode:
		"mark":
			delay = MARK_DELAY
		"extreme":
			delay = 0.0
	var p := _sample(npc.get_instance_id(), now - delay, npc.global_position) if delay > 0.0 else npc.global_position
	particles.global_position = p + Vector3(0.0, 0.95 * maxf(npc.body_height / 1.8, 0.5), 0.0)


## Pone (o quita, con null) el borde luminoso sobre el modelo del enemigo.
func _apply_overlay(g: Dictionary, mat: Material) -> void:
	if g["overlay"] == mat:
		return
	g["overlay"] = mat
	var meshes: Array = g["meshes"]
	if meshes.is_empty() and mat != null:
		meshes = (g["npc"] as Node).find_children("*", "MeshInstance3D", true, false)
		g["meshes"] = meshes
	for mi in meshes:
		if is_instance_valid(mi):
			(mi as MeshInstance3D).material_overlay = mat


func _quiet(g: Dictionary) -> void:
	_apply_overlay(g, null)
	(g["particles"] as GPUParticles3D).emitting = false


func _hide_all() -> void:
	for id: int in _ghosts:
		_quiet(_ghosts[id])


func _free_ghost(id: int) -> void:
	var g: Dictionary = _ghosts[id]
	if is_instance_valid(g["npc"]):
		_apply_overlay(g, null)
	(g["particles"] as GPUParticles3D).queue_free()
	_ghosts.erase(id)
	_history.erase(id)
