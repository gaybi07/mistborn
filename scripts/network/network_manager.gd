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
var _dot: Panel
var _dot_style: StyleBoxFlat
var _ips: Label
var _port_box: SpinBox
var _host_button: Button
var _join_button: Button
var _leave_button: Button
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
	var online := is_online()
	var connecting := online and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING
	# Semáforo: gris sin conexión, amarillo conectando, verde conectado, rojo si hubo un error.
	var color := Color(0.5, 0.52, 0.56)
	if status.begins_with("Error") or status.begins_with("No se pudo") or status.begins_with("Se perdió"):
		color = Color(0.9, 0.3, 0.25)
	elif connecting:
		color = Color(0.95, 0.8, 0.3)
	elif online:
		color = Color(0.35, 0.85, 0.45)
	_dot_style.bg_color = color
	_dot.queue_redraw()
	_host_button.disabled = online
	_join_button.disabled = online
	_leave_button.disabled = not online
	_address.editable = not online
	_port_box.editable = not online
	if not online:
		_peers.text = "Nadie conectado todavía."
		return
	var lines := PackedStringArray()
	lines.append("Tú: %d (%s)" % [multiplayer.get_unique_id(), "anfitrión" if multiplayer.is_server() else "cliente"])
	for id in multiplayer.get_peers():
		lines.append("%s: %d" % ["Cliente" if multiplayer.is_server() else "Anfitrión", id])
	_peers.text = "\n".join(lines)


func _process(_delta: float) -> void:
	if _root.visible:
		_refresh()


func _toggle_panel() -> void:
	_root.visible = not _root.visible
	if _root.visible:
		_previous_mouse = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_ips.text = _local_addresses()
		_port_box.value = port
	else:
		Input.mouse_mode = _previous_mouse
	_refresh()


## Direcciones de esta computadora en la red local (la que hay que decirle a quien quiera unirse).
func _local_addresses() -> String:
	var found := PackedStringArray()
	for a in IP.get_local_addresses():
		if not a.contains(".") or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		if a.begins_with("192.168.") or a.begins_with("10.") or _is_172_private(a):
			found.append(a)
	return ", ".join(found) if found.size() > 0 else "No se encontró (¿hay red?)"


func _is_172_private(a: String) -> bool:
	if not a.begins_with("172."):
		return false
	var second := int(a.split(".")[1])
	return second >= 16 and second <= 31


func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.visible = false
	_root.theme = HudKit.menu_theme()
	_root.position = Vector2(24, 24)
	_root.custom_minimum_size = Vector2(400, 0)
	add_child(_root)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_root.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	var title := Label.new()
	title.text = "Conexión"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", HudKit.GOLD_LIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close_hint := Label.new()
	close_hint.text = "P para cerrar"
	close_hint.modulate.a = 0.6
	head.add_child(close_hint)

	var state := HBoxContainer.new()
	state.add_theme_constant_override("separation", 10)
	box.add_child(state)
	_dot = Panel.new()
	_dot.custom_minimum_size = Vector2(14, 14)
	_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dot_style = StyleBoxFlat.new()
	_dot_style.set_corner_radius_all(7)
	_dot_style.bg_color = Color(0.5, 0.52, 0.56)
	_dot.add_theme_stylebox_override("panel", _dot_style)
	state.add_child(_dot)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state.add_child(_label)

	box.add_child(HudKit.section_label("Tu dirección en esta red"))
	var mine := HBoxContainer.new()
	mine.add_theme_constant_override("separation", 8)
	box.add_child(mine)
	_ips = Label.new()
	_ips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mine.add_child(_ips)
	var copy := Button.new()
	copy.text = "Copiar"
	copy.focus_mode = Control.FOCUS_NONE
	copy.tooltip_text = "Copia la primera dirección y el puerto para pasárselos a quien se une."
	copy.pressed.connect(func() -> void:
		var first := _ips.text.split(",")[0].strip_edges()
		DisplayServer.clipboard_set("%s:%d" % [first, port])
		copy.text = "¡Copiado!"
		get_tree().create_timer(1.5, true, false, true).timeout.connect(func() -> void: copy.text = "Copiar"))
	mine.add_child(copy)

	box.add_child(HudKit.section_label("Conectarse"))
	var form := HBoxContainer.new()
	form.add_theme_constant_override("separation", 8)
	box.add_child(form)
	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	_address.placeholder_text = "IP del anfitrión"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(_address)
	_port_box = SpinBox.new()
	_port_box.min_value = 1024
	_port_box.max_value = 65535
	_port_box.value = port
	_port_box.prefix = "Puerto "
	_port_box.custom_minimum_size.x = 150
	_port_box.value_changed.connect(func(v: float) -> void: port = int(v))
	form.add_child(_port_box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_host_button = _make_button("Alojar", func() -> void: host())
	_join_button = _make_button("Unirse", func() -> void: join(_address.text.strip_edges()))
	_leave_button = _make_button("Desconectar", func() -> void: disconnect_network())
	for b in [_host_button, _join_button, _leave_button]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)

	box.add_child(HudKit.section_label("Jugadores"))
	_peers = Label.new()
	box.add_child(_peers)

	var help := Label.new()
	help.text = "1. Una persona pulsa Alojar.\n2. La otra escribe la IP del anfitrión y pulsa Unirse.\n3. Las dos van a la arena (Ctrl+F2), abren el menú (M) y entran al duelo en red."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.modulate.a = 0.65
	box.add_child(help)


func _make_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b
