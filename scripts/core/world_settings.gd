class_name WorldSettings
## Hora, clima, niebla y efectos del mundo que se eligen en la pestaña Mundo del menú (Esc). Se guardan aparte de las
## opciones (user://world.cfg) y no dependen de otras clases: así GameSettings y Weather no se referencian entre sí.

const PATH := "user://world.cfg"
const HOURS: Array[String] = ["noche", "dia"]
const WEATHERS: Array[String] = ["despejado", "lluvia", "ceniza"]
const FOGS: Array[String] = ["ninguna", "poca", "mucha"]

static var _loaded := false


## Carga lo guardado en Art (una sola vez); los valores raros se ignoran.
static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	var hour := str(cfg.get_value("mundo", "hora", Art.lighting))
	if hour in HOURS:
		Art.lighting = hour
	var weather := str(cfg.get_value("mundo", "clima", Art.weather))
	if weather in WEATHERS:
		Art.weather = weather
	var fog := str(cfg.get_value("mundo", "niebla", Art.fog))
	if fog in FOGS:
		Art.fog = fog
	Art.mist = bool(cfg.get_value("mundo", "bruma", Art.mist))
	Art.ash_fall = bool(cfg.get_value("mundo", "ceniza", Art.ash_fall))
	Art.lightning = bool(cfg.get_value("mundo", "relampagos", Art.lightning))


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("mundo", "hora", Art.lighting)
	cfg.set_value("mundo", "clima", Art.weather)
	cfg.set_value("mundo", "niebla", Art.fog)
	cfg.set_value("mundo", "bruma", Art.mist)
	cfg.set_value("mundo", "ceniza", Art.ash_fall)
	cfg.set_value("mundo", "relampagos", Art.lightning)
	cfg.save(PATH)
