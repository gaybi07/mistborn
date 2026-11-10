class_name SaveSlots
## Tres partidas guardadas en user://partidas/<n>/. Cada una tiene:
##   partida.cfg: historia (QuestLog), dónde estás, monedas, frascos, inventario y equipo, y un resumen para el menú.
##   progression.cfg y jugador.cfg: copias de los archivos de Progression y Art (nivel, puntos, personaje y traje).
## Esos dos se siguen leyendo y escribiendo en user:// como siempre; al cargar una partida se copian desde la partida, y
## al guardar se copian a la partida. Así progression.gd y art.gd no cambian.
## Se guarda sola al terminar cada misión y al salir del juego.

const COUNT := 3
const ROOT := "user://partidas"
const COPIED := ["progression.cfg", "jugador.cfg"]

## Partida en juego (0 = ninguna elegida todavía: se muestra StartScreen).
static var current := 0
## Lo que la escena nueva tiene que poner en el jugador al crearlo (ver Main): {"pos", "coins", "player"}.
static var pending := {}


static func dir(slot: int) -> String:
	return "%s/%d" % [ROOT, slot]


static func exists(slot: int) -> bool:
	return FileAccess.file_exists(dir(slot) + "/partida.cfg")


## Resumen para el menú: {"hero", "quest", "level", "date"} (vacío si la partida no existe).
static func summary(slot: int) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(dir(slot) + "/partida.cfg") != OK:
		return {}
	return cfg.get_value("resumen", "datos", {})


## Guarda la partida en juego. No hace nada si no hay partida o en la sala de pruebas (sin jugador de la ciudad).
static func save() -> void:
	if current == 0:
		return
	var tree := Engine.get_main_loop() as SceneTree
	var player := tree.get_first_node_in_group(&"player") as Player if tree else null
	if player == null or not player.is_local_player() or tree.current_scene.scene_file_path != "res://scenes/main.tscn":
		return
	DirAccess.make_dir_recursive_absolute(dir(current))
	Progression.save()
	for f: String in COPIED:
		_copy("user://" + f, dir(current) + "/" + f)
	var cfg := ConfigFile.new()
	cfg.set_value("historia", "estado", QuestLog.to_dict())
	cfg.set_value("jugador", "pos", player.global_position)
	cfg.set_value("jugador", "monedas", player.coins_held)
	cfg.set_value("jugador", "equipo", {"equipment": player.equipment.duplicate(), "owned": player.owned.duplicate(), "vials": player.vial_charges})
	cfg.set_value("resumen", "datos", {
		"hero": String(Art.HEROES.get(Art.player_model, {}).get("name", Art.player_model)),
		"quest": QuestLog.title(QuestLog.tracked) if QuestLog.tracked != "" else "",
		"level": Progression.level,
		"date": Time.get_datetime_string_from_system(false, true),
	})
	cfg.save(dir(current) + "/partida.cfg")


static func autosave() -> void:
	save()


## Carga la partida (o la empieza de cero si no existe) y recarga la escena de la ciudad.
static func play(slot: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if current != 0:
		save()
	current = slot
	pending = {"new": true}
	for f: String in COPIED:
		var from := dir(slot) + "/" + f
		if FileAccess.file_exists(from):
			_copy(from, "user://" + f)
		elif FileAccess.file_exists("user://" + f):
			DirAccess.remove_absolute("user://" + f)  # partida nueva: sin personaje elegido ni puntos gastados
	Progression._loaded = false
	Progression.reset()
	Progression.load_progress()
	Art.load_suit()
	QuestLog.reset()
	Player.clear_saved()
	var cfg := ConfigFile.new()
	if cfg.load(dir(slot) + "/partida.cfg") == OK:
		QuestLog.from_dict(cfg.get_value("historia", "estado", {}))
		pending = {"pos": cfg.get_value("jugador", "pos", null), "coins": cfg.get_value("jugador", "monedas", -1),
				"player": cfg.get_value("jugador", "equipo", {})}
	tree.paused = false
	if tree.current_scene.scene_file_path == "res://scenes/main.tscn":
		tree.reload_current_scene()
	else:
		tree.change_scene_to_file("res://scenes/main.tscn")


static func erase(slot: int) -> void:
	for f: String in ["partida.cfg"] + COPIED:
		DirAccess.remove_absolute(dir(slot) + "/" + f)
	if current == slot:
		current = 0


static func _copy(from: String, to: String) -> void:
	var data := FileAccess.get_file_as_bytes(from)
	var f := FileAccess.open(to, FileAccess.WRITE)
	if f:
		f.store_buffer(data)
