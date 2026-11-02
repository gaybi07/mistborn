class_name Fx
## Efectos de partículas reutilizables y texturas suaves generadas por código.

static var _soft_tex: Texture2D
## Efectos de Effekseer (assets/effects/effekseer, de los ejemplos oficiales, MIT).
const EFFEKSEER := "res://assets/effects/effekseer/%s.efkefc"
static var _effects := {}


static func soft_texture() -> Texture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 64
		t.height = 64
		_soft_tex = t
	return _soft_tex


static func particle_material(color: Color, additive: bool, soft_distance := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_texture()
	m.albedo_color = color
	if soft_distance > 0.0:
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = soft_distance
	return m


## Curva de color: aparece, se mantiene y se desvanece.
static func fade_ramp(fade_in := 0.0) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0 if fade_in > 0.0 else 1.0))
	g.set_color(1, Color(1, 1, 1, 0))
	if fade_in > 0.0:
		g.add_point(fade_in, Color(1, 1, 1, 1))
		g.add_point(1.0 - fade_in, Color(1, 1, 1, 1))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## Ráfaga de un solo uso (chispas, polvo...). Se borra sola.
static func burst(parent: Node, pos: Vector3, color: Color, amount := 24, speed := 4.0, life := 0.5,
		size := 0.08, gravity := -4.0, additive := true, spread := 180.0) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = spread
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, gravity, 0)
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.color_ramp = fade_ramp()
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = particle_material(color, additive, 0.3 if not additive else 0.0)
	p.draw_pass_1 = quad
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(life + 0.5, false).timeout.connect(p.queue_free)


static func sparks(parent: Node, pos: Vector3, color: Color) -> void:
	burst(parent, pos, color * 3.0, 20, 5.0, 0.35, 0.06, -6.0, true)


## Efecto de Effekseer que se reproduce una vez y se borra solo. color tiñe el efecto.
static func effect(parent: Node, name: String, pos: Vector3, size := 1.0, color := Color.WHITE) -> void:
	if not _effects.has(name):
		_effects[name] = load(EFFEKSEER % name)
	var e := EffekseerEmitter3D.new()
	e.effect = _effects[name]
	e.color = color
	e.autofree = true
	e.scale = Vector3.ONE * size
	parent.add_child(e)
	e.global_position = pos
	e.play()


## Hojas de sprites de pixelfx (assets/effects/pixelfx, MIT): [columnas, cuadros, pivote en px].
const PIXELFX := "res://assets/effects/pixelfx/%s.png"
const SHEETS := {
	"zap-hit": [5, 28, Vector2(76, 56)],
	"hit-spark": [4, 16, Vector2(44, 64)],
	"crit-hit": [5, 28, Vector2(84, 106)],
	"heavy-landing": [5, 49, Vector2(88, 60)],
	"spin-slash": [4, 25, Vector2(104, 84)],
	"parry": [5, 31, Vector2(100, 56)],
}
static var _sheet_tex := {}


## Efecto de pixelfx que se reproduce una vez (30 fps) y se borra solo. width: ancho en metros.
## from: si se da, el efecto se orienta para que su lado izquierdo apunte hacia ahí (de donde
## viene el rayo o el golpe); si no, mira siempre a la cámara. additive: brilla (rayos, chispas).
static func sprite(parent: Node, name: String, pos: Vector3, width := 1.0, color := Color.WHITE,
		from: Variant = null, additive := true) -> void:
	if not _sheet_tex.has(name):
		_sheet_tex[name] = load(PIXELFX % name)
	var tex: Texture2D = _sheet_tex[name]
	var info: Array = SHEETS[name]
	var cols: int = info[0]
	var frames: int = info[1]
	var rows := ceili(float(frames) / cols)
	var fs := Vector2(tex.get_width() / cols, tex.get_height() / rows)
	var s := Sprite3D.new()
	s.texture = tex
	s.hframes = cols
	s.vframes = rows
	s.pixel_size = width / fs.x
	s.offset = Vector2(fs.x * 0.5 - info[2].x, info[2].y - fs.y * 0.5)
	s.modulate = color
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	s.material_override = m
	parent.add_child(s)
	s.global_position = pos
	var cam := parent.get_viewport().get_camera_3d()
	if from != null and cam:
		var z := (cam.global_position - pos).normalized()
		var x: Vector3 = pos - from
		x = (x - z * x.dot(z)).normalized()
		if x.length() > 0.5:
			s.global_basis = Basis(x, z.cross(x), z)
	else:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var tw := s.create_tween()
	tw.tween_property(s, "frame", frames - 1, frames / 30.0).from(0)
	tw.tween_callback(s.queue_free)


## Texto que sube y se desvanece en `pos` ("¡Parry!", "Crítico"...).
static func popup(parent: Node, pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 36
	l.outline_size = 8
	l.pixel_size = 0.007
	l.modulate = color
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "global_position:y", pos.y + 0.8, 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


static func dust(parent: Node, pos: Vector3, strength := 1.0) -> void:
	burst(parent, pos + Vector3(0, 0.1, 0), Color(0.42, 0.4, 0.38, 0.45), int(14 + 20 * strength),
			3.0 * strength, 0.9, 0.7, 0.5, false, 70.0)
