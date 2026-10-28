class_name TinSenses
extends Node
## Estaño: sentidos aumentados. Disipa la bruma y aclara la noche (más aún al avivar).
## Riesgo de avivar: un relámpago te encandila (pantalla blanca ~1 s).

const BLIND_TIME := 1.0

var player: Player
## Encandilado: segundos que quedan (la HUD lo muestra).
var blinded := 0.0

var _blind_rect: ColorRect
var _weather: Weather

var _env: Environment
var _base_fog := 0.0
var _base_vol_fog := 0.0
var _base_exposure := 1.0
var _amount := 0.0
var _version := -1
var _base_ext_fog := 0.05


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_blind_rect = ColorRect.new()
	_blind_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blind_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blind_rect.color = Color(1, 1, 0.97, 0.0)
	layer.add_child(_blind_rect)


## Destello fuerte: si estás avivando estaño, te encandila.
func flash() -> void:
	if player.allomancy.is_flaring(&"tin"):
		blinded = BLIND_TIME


func _process(delta: float) -> void:
	var rd := delta / Engine.time_scale
	if _weather == null:
		_weather = get_tree().get_first_node_in_group(&"weather") as Weather
		if _weather:
			_weather.lightning.connect(flash)
	blinded = maxf(blinded - rd, 0.0)
	_blind_rect.color.a = clampf(blinded / BLIND_TIME, 0.0, 1.0) * 0.95
	if (_env == null or _version != Art.env_version) and not _grab_environment():
		return
	_amount = move_toward(_amount, player.allomancy.strength(&"tin"), rd * 2.0)
	_env.fog_density = _curve(_base_fog, _base_fog * 0.35, _base_fog * 0.08)
	_env.volumetric_fog_density = _curve(_base_vol_fog, _base_vol_fog * 0.35, _base_vol_fog * 0.08)
	_env.tonemap_exposure = _curve(_base_exposure, _base_exposure * 1.5, _base_exposure * 2.2)
	(WorldKit.materials()["exterior_fog"] as FogMaterial).density = _curve(_base_ext_fog, _base_ext_fog * 0.4, _base_ext_fog * 0.12)
	var world_fx := get_tree().get_first_node_in_group(&"world_fx") as WorldFx
	if world_fx:
		world_fx.set_mist_strength(_curve(1.0, 0.4, 0.1))


## Interpola entre apagado (0), quemando (1) y avivando (2).
func _curve(off: float, burn: float, flare: float) -> float:
	if _amount <= 1.0:
		return lerpf(off, burn, _amount)
	return lerpf(burn, flare, (_amount - 1.0) / (Allomancy.FLARE_STRENGTH - 1.0))


func _grab_environment() -> bool:
	var we := get_tree().get_first_node_in_group(&"world_env") as WorldEnvironment
	if we == null or we.environment == null:
		return false
	_env = we.environment
	_version = Art.env_version
	_base_fog = _env.fog_density
	_base_vol_fog = _env.volumetric_fog_density
	_base_exposure = _env.tonemap_exposure
	_base_ext_fog = (WorldKit.materials()["exterior_fog"] as FogMaterial).density
	return true
