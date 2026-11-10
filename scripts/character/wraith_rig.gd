class_name WraithRig
extends HumanoidRig
## Cuerpo del espectro de la bruma (MistWraith): el modelo de Meshy (una masa de bruma con huesos adentro) sin
## esqueleto. No usa clips: lo mueve el shader shaders/mist_wraith.gdshader (respira, ondula, se arrastra, se lanza
## y se derrite), por decisión del 10/11, porque no tiene forma de cuerpo para riggearlo. Lo rodea una bruma propia
## (FogVolume) que al morir se espesa y se va.

const MODEL := "res://assets/meshy/Espectro.glb"
const MODEL_HEIGHT := 1.2122  ## alto de la malla tal como viene
const SHADER := preload("res://shaders/mist_wraith.gdshader")
const MELT_TIME := 2.5
## Lanzarse, en fracciones de lo que dura: se echa atrás hasta WIND, se estira hasta PEAK (ahí pega) y vuelve.
const WIND := 0.4
const PEAK := 0.55

var height := 2.2
var _body_mat: ShaderMaterial
var _fog: FogMaterial
var _crawl := 0.0
var _lunge_t := -1.0
var _lunge_len := 1.0
var _melt := -1.0
var _flash := 0.0


func _ready() -> void:  # sin super: no arma el cuerpo de primitivas
	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	model.rotation.y = PI  # el frente del modelo mira a +Z; el de los NPC, a -Z
	model.scale = Vector3.ONE * height / MODEL_HEIGHT
	add_child(model)
	var mi := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var src := mi.get_active_material(0) as StandardMaterial3D
	_body_mat = ShaderMaterial.new()
	_body_mat.shader = SHADER
	_body_mat.set_shader_parameter(&"albedo_tex", src.albedo_texture)
	_body_mat.set_shader_parameter(&"normal_tex", src.normal_texture)
	_body_mat.set_shader_parameter(&"orm_tex", src.roughness_texture)
	_body_mat.set_shader_parameter(&"height", MODEL_HEIGHT)
	_body_mat.set_shader_parameter(&"seed", randf() * 100.0)
	mi.material_override = _body_mat
	# Bruma alrededor, pegada al piso.
	_fog = FogMaterial.new()
	_fog.density = 0.5
	_fog.albedo = Color(0.78, 0.8, 0.82)
	_fog.height_falloff = 1.5
	_fog.edge_fade = 0.7
	var fv := FogVolume.new()
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	fv.size = Vector3(height * 2.4, height * 0.9, height * 2.4)
	fv.position.y = height * 0.25
	fv.material = _fog
	add_child(fv)


## Se echa atrás y se lanza hacia adelante; el golpe es a PEAK * duration.
func lunge(duration: float) -> void:
	_lunge_t = 0.0
	_lunge_len = duration


func melt() -> void:
	if _melt < 0.0:
		_melt = 0.0


func cancel_action() -> void:
	_lunge_t = -1.0


func flash(_color := Color(1.0, 0.3, 0.25)) -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	if hitstop > 0.0:
		hitstop -= delta / Engine.time_scale
		return
	_crawl = lerpf(_crawl, clampf(move_speed / 3.5, 0.0, 1.0), minf(delta * 4.0, 1.0))
	var lunge_amount := 0.0
	if _lunge_t >= 0.0:
		_lunge_t += delta
		var k := _lunge_t / _lunge_len
		if k >= 1.0:
			_lunge_t = -1.0
		elif k < WIND:
			lunge_amount = -0.3 * sin(k / WIND * PI / 2.0)
		elif k < PEAK:
			lunge_amount = lerpf(-0.3, 1.0, smoothstep(WIND, PEAK, k))
		else:
			lunge_amount = 1.0 - smoothstep(PEAK, 1.0, k)
	lunge_amount -= stagger * 0.2  # el golpe lo hace retroceder
	stagger = move_toward(stagger, 0.0, delta * 3.0)
	_flash = move_toward(_flash, 0.0, delta * 5.0)
	if _melt >= 0.0:
		_melt = minf(_melt + delta / MELT_TIME, 1.0)
		_fog.density = 0.5 + sin(_melt * PI) * 1.5 - _melt * 0.5  # se espesa y se va
	_body_mat.set_shader_parameter(&"crawl", _crawl)
	_body_mat.set_shader_parameter(&"lunge", lunge_amount)
	_body_mat.set_shader_parameter(&"melt", maxf(_melt, 0.0))
	_body_mat.set_shader_parameter(&"flash", _flash)
