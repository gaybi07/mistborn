class_name GameSettings
## Opciones del jugador: sensibilidad del ratón, campo de visión, tamaño del HUD, volumen y pantalla
## completa. Se guardan en user://settings.cfg y se aplican al entrar al juego (ver Player._ready).

const PATH := "user://settings.cfg"
const BASE_SENSITIVITY := 0.0025

## Multiplicador de la sensibilidad (1 = la de siempre).
static var sensitivity := 1.0
static var fov := 75.0
## Multiplicador del tamaño del HUD, además de su escala automática según la ventana.
static var hud_scale := 1.0
static var volume := 1.0
static var fullscreen := false
static var _loaded := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	sensitivity = clampf(float(cfg.get_value("controles", "sensibilidad", sensitivity)), 0.2, 4.0)
	fov = clampf(float(cfg.get_value("video", "fov", fov)), 55.0, 110.0)
	hud_scale = clampf(float(cfg.get_value("video", "hud", hud_scale)), 0.6, 1.4)
	volume = clampf(float(cfg.get_value("audio", "volumen", volume)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("video", "pantalla_completa", fullscreen))
	apply_global()


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controles", "sensibilidad", sensitivity)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "hud", hud_scale)
	cfg.set_value("audio", "volumen", volume)
	cfg.set_value("video", "pantalla_completa", fullscreen)
	cfg.save(PATH)


## Volumen y pantalla completa (lo demás lo lee quien lo usa).
static func apply_global() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if full != fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


static func apply_to(player: Player) -> void:
	player.mouse_sensitivity = BASE_SENSITIVITY * sensitivity
	player.base_fov = fov
	if player.camera != null:
		player.camera.fov = fov
