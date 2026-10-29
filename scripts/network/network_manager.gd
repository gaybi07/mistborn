extends CanvasLayer
## Conexión de red (autoload NetworkManager): un proceso aloja y hasta dos más se conectan por ENet.
## Todavía no crea jugadores de red: solo conecta y muestra el estado. P abre o cierra el panel (F9 y las demás F las usa el depurador de Godot).
## Sin interfaz (pruebas y dos instancias): argumentos de usuario tras `--`:
##   --host                 aloja en PORT
##   --join[=IP]            se conecta a IP (127.0.0.1 por defecto)
##   --port=N               cambia el puerto

## Único lugar donde se define el puerto y el límite de clientes.
const DEFAULT_PORT := 24565
const MAX_CLIENTS := 2

signal state_changed

var port := DEFAULT_PORT
## Último mensaje de error o de estado, para mostrar en pantalla.
var status := "Sin conexión"
var _label: Label
var _address: LineEdit
var _root: Control
var _peers: Label
var _previous_mouse := Input.MOUSE_MODE_VISIBLE


func is_online() -> bool:
	return multiplayer.multiplayer_peer != null \
			and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer \
			and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


func host() -> Error:
	disconnect_network()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		_set_status("No se pudo alojar en el puerto %d (%s)" % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	_set_status("Alojando en el puerto %d" % port)
	return OK


func join(address: String) -> Error:
	disconnect_network()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		_set_status("No se pudo conectar a %s:%d (%s)" % [address, port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	_set_status("Conectando a %s:%d..." % [address, port])
	return OK


func disconnect_network() -> void:
	if is_online():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_set_status("Sin conexión")


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(func(id: int) -> void:
		print("[red] par conectado: ", id)
		_set_status("Par conectado: %d" % id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void:
		print("[red] par desconectado: ", id)
		_set_status("Par desconectado: %d" % id))
	multiplayer.connected_to_server.connect(func() -> void:
		print("[red] conectado al servidor, mi id: ", multiplayer.get_unique_id())
		_set_status("Conectado al servidor"))
	multiplayer.connection_failed.connect(func() -> void:
		multiplayer.multiplayer_peer = null
		_set_status("Error: no se pudo conectar al servidor"))
	multiplayer.server_disconnected.connect(func() -> void:
		multiplayer.multiplayer_peer = null
		_set_status("Se perdió la conexión con el servidor"))
	_build_ui()
	_apply_cmdline()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P and event.get_modifiers_mask() == 0:
		_toggle_panel()
		get_viewport().set_input_as_handled()  # que la P no se escriba en el cuadro de la IP


func _apply_cmdline() -> void:
	var join_to := ""
	var do_host := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			do_host = true
		elif arg == "--join":
			join_to = "127.0.0.1"
		elif arg.begins_with("--join="):
			join_to = arg.trim_prefix("--join=")
		elif arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))
	if do_host:
		host()
	elif join_to != "":
		join(join_to)


func _set_status(text: String) -> void:
	status = text
	_refresh()
	state_changed.emit()


func _refresh() -> void:
	if _label == null:
		return
	_label.text = status
	if not is_online():
		_peers.text = "Mi ID: -"
		return
	var ids := PackedStringArray()
	for id in multiplayer.get_peers():
		ids.append(str(id))
	_peers.text = "Mi ID: %d (%s)\nPares: %s" % [multiplayer.get_unique_id(),
			"servidor" if multiplayer.is_server() else "cliente", ", ".join(ids) if ids.size() > 0 else "ninguno"]


func _process(_delta: float) -> void:
	if _root.visible:
		_refresh()


func _toggle_panel() -> void:
	_root.visible = not _root.visible
	if _root.visible:
		_previous_mouse = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = _previous_mouse
	_refresh()


func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.visible = false
	_root.position = Vector2(20, 20)
	add_child(_root)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_root.add_child(box)
	var title := Label.new()
	title.text = "Red (P cierra) · puerto %d" % port
	box.add_child(title)
	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	_address.custom_minimum_size.x = 220
	box.add_child(_address)
	var row := HBoxContainer.new()
	box.add_child(row)
	for spec in [["Alojar", func() -> void: host()], ["Unirse", func() -> void: join(_address.text.strip_edges())],
			["Desconectar", func() -> void: disconnect_network()]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		row.add_child(b)
	_label = Label.new()
	box.add_child(_label)
	_peers = Label.new()
	box.add_child(_peers)
