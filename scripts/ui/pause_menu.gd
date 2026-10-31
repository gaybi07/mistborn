class_name PauseMenu
extends CanvasLayer
## Menú de Esc: pausa el juego y muestra todas las habilidades y cómo se usan
## (pestañas Controles, Metales y Combate), más Reanudar y Reaparecer.

## Tamaño del panel (px, antes de escalar): ancho para la tabla de controles y alto para las pestañas.
const PANEL_SIZE := Vector2(980, 640)

var player: Player

var _root: Control
var _restart_button: Button
var _reset_button: Button


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_TOP_LEFT)  # el tamaño lo fija _fit_to_window (la capa se escala)
	_root.visible = false
	_root.theme = HudKit.menu_theme()
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = PANEL_SIZE
	_root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := Label.new()
	title.text = "Pausa"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", HudKit.GOLD_LIGHT)
	head.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var hint := Label.new()
	hint.text = "Esc: volver al juego"
	hint.modulate.a = 0.6
	head.add_child(hint)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	tabs.add_child(_page("Guía", GUIDE))
	tabs.add_child(_page("Controles", CONTROLS))
	tabs.add_child(_metals_page())
	tabs.add_child(_page("Combate", COMBAT))
	tabs.add_child(_options_page())

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	buttons.add_child(_button("Reanudar", close))
	buttons.add_child(_button("Reaparecer", func() -> void:
		close()
		player.respawn()))
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(filler)
	_restart_button = _confirm_button("Reiniciar el mundo", "¿Seguro? Pulsá de nuevo", _restart_world)
	_restart_button.tooltip_text = "Vuelve a generar el escenario actual. Conservas tu inventario."
	buttons.add_child(_restart_button)
	_reset_button = _confirm_button("Empezar de cero", "¿Seguro? Pulsá de nuevo", _restart_all)
	_reset_button.tooltip_text = "Reinicia el escenario y además vacía tu inventario y equipo."
	buttons.add_child(_reset_button)
	buttons.add_child(_confirm_button("Salir del juego", "¿Seguro? Pulsá de nuevo", func() -> void: get_tree().quit()))


## Botón de un solo paso.
func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	return b


## Botón que pide una segunda pulsación (en 3 s) antes de hacer algo que no se puede deshacer.
func _confirm_button(text: String, confirm_text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void:
		if b.get_meta(&"armed", false):
			b.set_meta(&"armed", false)
			b.text = text
			action.call()
			return
		b.set_meta(&"armed", true)
		b.text = confirm_text
		get_tree().create_timer(3.0, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(b) and b.get_meta(&"armed", false):
				b.set_meta(&"armed", false)
				b.text = text))
	return b


func _restart_world() -> void:
	if NetworkManager.is_online():
		return
	close()
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _restart_all() -> void:
	if NetworkManager.is_online():
		return
	Player.clear_saved()
	_restart_world()


## Pestaña de opciones: sensibilidad, campo de visión, tamaño del HUD, volumen y pantalla completa
## (se guardan solas), y atajos para cambiar de escenario.
func _options_page() -> Control:
	var page := VBoxContainer.new()
	page.name = "Opciones"
	page.add_theme_constant_override("separation", 10)
	page.add_child(HudKit.section_label("Controles y vista"))
	page.add_child(_slider_row("Sensibilidad del ratón", 0.3, 3.0, 0.05, GameSettings.sensitivity, "×%.2f",
			func(v: float) -> void:
				GameSettings.sensitivity = v
				GameSettings.apply_to(player)))
	page.add_child(_slider_row("Campo de visión", 60.0, 100.0, 1.0, GameSettings.fov, "%d°",
			func(v: float) -> void:
				GameSettings.fov = v
				GameSettings.apply_to(player)))
	page.add_child(_slider_row("Tamaño del HUD", 0.7, 1.6, 0.05, GameSettings.hud_scale, "×%.2f",
			func(v: float) -> void: GameSettings.hud_scale = v))
	page.add_child(HudKit.section_label("Sonido y pantalla"))
	page.add_child(_slider_row("Volumen", 0.0, 1.0, 0.05, GameSettings.volume, "%d %%",
			func(v: float) -> void:
				GameSettings.volume = v
				GameSettings.apply_global(), 100.0))
	var full := CheckButton.new()
	full.text = "Pantalla completa"
	full.button_pressed = GameSettings.fullscreen
	full.toggled.connect(func(on: bool) -> void:
		GameSettings.fullscreen = on
		GameSettings.apply_global()
		GameSettings.save())
	page.add_child(full)
	page.add_child(HudKit.section_label("Ir a"))
	var go := HBoxContainer.new()
	go.add_theme_constant_override("separation", 10)
	page.add_child(go)
	go.add_child(_button("Ciudad (F1)", _go_to.bind("res://scenes/main.tscn")))
	go.add_child(_button("Arena (F2)", _go_to.bind("res://scenes/arena.tscn")))
	var note := Label.new()
	note.text = "Reiniciar el mundo, empezar de cero y cambiar de escenario no están disponibles mientras estás conectado en red."
	note.modulate.a = 0.6
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(note)
	return page


func _go_to(scene: String) -> void:
	if NetworkManager.is_online() or get_tree().current_scene.scene_file_path == scene:
		return
	close()
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(scene)


## Fila "nombre — deslizador — valor". `display_scale` multiplica el valor mostrado (0-1 -> porcentaje).
func _slider_row(label: String, lo: float, hi: float, step: float, value: float, fmt: String, on_change: Callable,
		display_scale := 1.0) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var name_label := Label.new()
	name_label.text = label
	name_label.custom_minimum_size.x = 210
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(300, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 70
	value_label.text = fmt % (value * display_scale)
	row.add_child(value_label)
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = fmt % (v * display_scale)
		on_change.call(v))
	# Se guarda al soltar el deslizador, no en cada movimiento.
	slider.drag_ended.connect(func(_changed: bool) -> void: GameSettings.save())
	return row


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _root.visible:
			close()
		elif not player.ui_open:
			open()
		else:
			return  # otra ventana abierta (inventario): que la cierre ella
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _root.visible:
		_fit_to_window()


## El menú crece con la ventana igual que el HUD (ver HudKit.ui_scale), sin pasarse de lo que cabe:
## la capa se escala y la raíz ocupa toda la ventana en esas unidades.
func _fit_to_window() -> void:
	var vp := _root.get_viewport_rect().size
	var s := minf(HudKit.ui_scale(_root), minf(vp.x / (PANEL_SIZE.x + 20.0), vp.y / (PANEL_SIZE.y + 20.0)))
	scale = Vector2(s, s)
	_root.position = Vector2.ZERO
	_root.size = vp / s


func open() -> void:
	_fit_to_window()
	_root.visible = true
	var online := NetworkManager.is_online()
	_restart_button.disabled = online
	_reset_button.disabled = online
	player.ui_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	_root.visible = false
	player.ui_open = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _page(title: String, text: String) -> Control:
	var rt := RichTextLabel.new()
	rt.name = title
	rt.bbcode_enabled = true
	rt.text = text
	rt.add_theme_constant_override("table_h_separation", 18)
	rt.add_theme_constant_override("table_v_separation", 6)
	return rt


func _metals_page() -> Control:
	var lines := PackedStringArray()
	lines.append("Tocar la tecla: encender / apagar.   Doble toque y mantener: [b]avivar[/b] (al soltar vuelve a quemar).\n")
	lines.append("[table=3]")
	lines.append("[cell][b]Metal[/b][/cell][cell][b]Quemado[/b][/cell][cell][b]Avivado[/b][/cell]")
	for m in Allomancy.METALS:
		var info: Dictionary = Allomancy.METALS[m]
		var desc: Array = METAL_TEXT[m]
		lines.append("[cell][color=#%s][b]%s  %s[/b][/color][/cell][cell]%s[/cell][cell]%s[/cell]" % [
				(info["color"] as Color).to_html(false), OS.get_keycode_string(info["key"]), info["label"], desc[0], desc[1]])
	lines.append("[/table]")
	lines.append("\nLo único que contrarresta el atium es el atium: si los dos lo queman, se anulan.")
	lines.append("Los frascos (T) recargan todo menos el atium.")
	return _page("Metales", "\n".join(lines))


## Guía rápida: qué hace cada control según el metal que estés quemando. Sin metales ni monedas
## solo valen los movimientos básicos; el resto se desbloquea al encender el metal.
const GUIDE := """[color=#f2dca8][b]EMPEZAR EN 4 PASOS[/b][/color]
[b]1.[/b] Encendé un metal con su tecla (1 acero, 2 hierro, 3 peltre...). Tocar: encender o apagar. Doble toque y mantener: avivar.
[b]2.[/b] Mirá la mira: los puntos azules son metales que podés usar. Acero (1) los empuja, hierro (2) tira de ellos.
[b]3.[/b] Empujá con [b]G[/b], tirá con [b]E[/b] (o el clic derecho para tirar una moneda), anclá con [b]R[/b].
[b]4.[/b] Combiná: con acero y monedas, [b]Espacio + WASD[/b] te lanza por el aire.

[color=#f2dca8][b]SIN METALES[/b][/color]
[b]Espacio, Espacio[/b] (en el aire): segundo salto, más alto y con empuje hacia donde pulsás. Uno por salto.
[b]Shift[/b]: rodar · en el aire: dash. [b]Clic izquierdo[/b]: atacar. [b]Rueda[/b]: cambiar de arma.

[color=#6b9bff][b]ACERO (1)[/b][/color]  empuja metales
[b]Clic derecho[/b]: moneda fuerte hacia la mira (mantené para seguir empujándola). Apuntá abajo para frenar una caída.
[b]G[/b]: empujar el metal que miras · [b]R[/b]: anclar el agarre.
[b]Espacio + WASD[/b]: salto de acero en arco hacia esa dirección (mantené Espacio para seguir empujando).
[b]Espacio, Espacio[/b]: salto de acero recto hacia arriba.
[b]Alt + E[/b]: lluvia de 8 monedas en círculo a tu alrededor. Cada una cuesta una moneda.

[color=#a0a8c0][b]HIERRO (2)[/b][/color]  tira de metales
[b]E[/b]: tirar del metal que miras. Si es una moneda, viene a vos y se guarda al tocarte.
[b]Alt + E[/b]: atrae todas las monedas cercanas y las guarda en el monedero.
Con un solo metal encendido (acero o hierro), E y G hacen lo mismo.

[color=#f28c40][b]PELTRE (3)[/b][/color]  cuerpo reforzado
Más velocidad, salto, daño y aguante. [b]Espacio, Espacio[/b] sin acero: segundo salto [b]mucho[/b] más fuerte.
Avivarlo hasta agotarlo te deja 15 s lento y débil (arrastre de peltre).

[color=#ffe9a8][b]ACERO + PELTRE[/b][/color]  el salto máximo
[b]Espacio, Espacio[/b] sin dirección: salto de acero recto hacia arriba y, encima, el impulso del peltre. Gasta una moneda.
[b]Espacio + WASD[/b]: el salto de acero direccional (el peltre ya suma por la mayor velocidad).

[color=#fff2c8][b]ATIUM (4)[/b][/color]  esquivás solos los golpes y monedas de quien no lo quema.

[color=#d9604d][b]CINC (Z)[/b][/color] y [color=#8fbf9a][b]LATÓN (B)[/b][/color]  alomancia emocional sobre el que tenés en la mira. Cinc lo enardece (ataca más, recibe más); latón lo aplaca (deja de atacar).
[color=#c77a4d][b]COBRE (X)[/b][/color]  te vuelve invisible al bronce e inmune a cinc y latón.
[color=#d9a65a][b]BRONCE (C)[/b][/color]  sentís a los alománticos que queman metales. [color=#d1dbb3][b]ESTAÑO (V)[/b][/color]  ves más lejos en la bruma y te recuperás antes de los golpes.

[color=#f2dca8][b]TRUCOS[/b][/color]
Sin la bolsa (F) nadie puede empujarte ni tirar de vos, pero tampoco tenés monedas.
[b]Tab[/b] abre la rueda de metales (apuntá y soltá). [b]N[/b] apaga todo. [b]T[/b] bebe un frasco. [b]I[/b] inventario."""

const CONTROLS := """[table=2]
[cell][color=#f2dca8][b]MOVIMIENTO[/b][/color][/cell][cell][/cell]
[cell][b]W A S D[/b][/cell][cell]Moverse[/cell]
[cell][b]Espacio[/b][/cell][cell]Saltar[/cell]
[cell][b]Espacio + WASD[/b][/cell][cell]Con el acero encendido y monedas: salto de acero en esa dirección, en arco hacia arriba. Mantené Espacio para seguir empujando[/cell]
[cell][b]Espacio, Espacio[/b][/cell][cell]Sin metales: segundo salto en el aire, más alto (con peltre, mucho más). Con acero y monedas: salto de acero recto hacia arriba (con peltre, además un impulso extra)[/cell]
[cell][b]Shift[/b][/cell][cell]Rodar · en el aire: dash · justo antes de aterrizar: amortigua la caída[/cell]
[cell][b]Contra un borde[/b][/cell][cell]Volando o cayendo contra un edificio te agarrás al borde si el choque no te haría más de 10 de daño (el peltre aguanta más). W o Espacio: subir · S o Shift: soltarte[/cell]
[cell][color=#f2dca8][b]COMBATE[/b][/color][/cell][cell][/cell]
[cell][b]Clic izquierdo[/b][/cell][cell]Atacar con el arma elegida (con puños, desenvaina las dagas sola si las tenés) · seguido: combo · en el aire: golpe giratorio con salto extra[/cell]
[cell][b]Rueda del ratón[/b][/cell][cell]Cambiar de arma (puños, dagas, espada). Con acero o hierro encendidos y varios metales junto a la mira: elige a cuál agarrar[/cell]
[cell][color=#f2dca8][b]METALES[/b][/color][/cell][cell][/cell]
[cell][b]1 2 3 4[/b][/cell][cell]Acero, hierro, peltre, atium (tocar: encender o apagar · doble toque y mantener: avivar)[/cell]
[cell][b]Z X C V B[/b][/cell][cell]Cinc, cobre, bronce, estaño, latón (igual que los anteriores)[/cell]
[cell][b]N[/b][/cell][cell]Apagar todos los metales[/cell]
[cell][b]Tab[/b] (mantener)[/cell][cell]Rueda de metales: apuntá con el ratón y soltá Tab; clic = avivar[/cell]
[cell][b]Clic derecho[/b][/cell][cell]Lanza una moneda fuerte justo hacia la mira y la empuja con acero mientras mantengas el clic: pega con la moneda o, apuntando abajo, frena una caída[/cell]
[cell][b]E[/b][/cell][cell]Tirar (hierro) del metal que miras; donde hay algo que usar (puerta, armario) abre en vez de tirar; una moneda viene a vos y se guarda al tocarte. Con un solo metal encendido, E o G lo usan. Sin nada a la vista, agarra el que más ayuda a moverte hacia donde vas[/cell]
[cell][b]G[/b][/cell][cell]Empujar (acero) el metal que miras[/cell]
[cell][b]Alt + E[/b][/cell][cell]Con acero encendido: lanza 8 monedas en círculo a tu alrededor. Con hierro (sin acero): atrae todas las monedas cercanas y las guarda en el monedero[/cell]
[cell][b]R[/b][/cell][cell]Anclar los agarres activos (siguen sin mantener la tecla; volver a tirar o empujar los suelta). En el aire, WASD dirige mucho más mientras tenés un agarre[/cell]
[cell][color=#f2dca8][b]OBJETOS[/b][/color][/cell][cell][/cell]
[cell][b]F[/b][/cell][cell]Soltar / recoger la bolsa de monedas: sin ella nadie puede empujarte ni tirar de vos (pero no tenés monedas)[/cell]
[cell][b]M[/b][/cell][cell]Mapa de Luthadel con dónde estás (arriba a la derecha está siempre el minimapa)[/cell]
[cell][b]T[/b][/cell][cell]Beber un frasco[/cell]
[cell][b]H[/b][/cell][cell]Capucha[/cell]
[cell][b]I[/b][/cell][cell]Inventario: capa, ropa, botas, dagas, espada y frascos. Doble clic para equipar o quitar[/cell]
[cell][color=#f2dca8][b]JUEGO[/b][/color][/cell][cell][/cell]
[cell][b]Esc[/b][/cell][cell]Este menú[/cell]
[cell][b]P[/b][/cell][cell]Elegir personaje: color del traje y la capucha (negro, blanco, rojo o azul)[/cell]
[cell][b]Contra un borde[/b][/cell][cell]Volando o cayendo contra un edificio te agarrás al borde si el choque no te haría más de 10 de daño (el peltre aguanta más). W o Espacio: subir · S o Shift: soltarte[/cell]
[cell][b]F1 / F2[/b][/cell][cell]Ciudad / arena[/cell]
[cell][b]F3 F4 F5[/b][/cell][cell]Día/noche · clima · niebla[/cell]
[/table]"""

const COMBAT := """[b]Combos[/b] (clic izquierdo seguido, a tiempo):
  Puños: directo, patada, remate.
  Dagas: cuatro golpes distintos; el cuarto es un tajo doble más fuerte que empuja lejos.
  Espada: dos tajos y un remate fuerte que empuja lejos.
  El remate va con una estocada hacia delante.

[b]Golpe aéreo[/b]: clic izquierdo en el aire. Un tajo giratorio que pega alrededor tuyo y te da un salto extra (uno por salto).

[b]Dash[/b]: Shift en el aire, uno por salto.

[b]Peltre[/b]: más daño, empuje y velocidad de golpe. Avivado hasta agotarlo: arrastre de peltre (15 s lento y débil).

[b]Atium[/b]: esquivás solo los golpes y monedas de quien no lo quema, y tus golpes llegan aunque se mueva.

[b]Bolsa de monedas[/b]: los alománticos enemigos te empujan y tiran a través de ella. Soltala (F) para que no puedan; volvé a pasar por encima o pulsá F cerca para recogerla. Con hierro podés traerla de lejos.

[b]Equipo y metal[/b]: la cota de malla, las botas con clavos, las armas de acero y los frascos con tapón de metal cuentan como metal: con cualquiera puesto te pueden empujar aunque sueltes la bolsa. Los alománticos derrotados a veces sueltan objetos.

[b]Alomancia emocional enemiga[/b]: el Aplacador (latón) no te deja avivar; el Encendedor (cinc) te hace pegar más pero recibir más. El cobre (X) te protege de los dos."""

## Quemado / avivado de cada metal (resumen de docs/METALES.md).
const METAL_TEXT := {
	&"steel": ["Empuja metales hasta 40 m", "Doble de fuerza y +50 % de alcance; monedas como balas"],
	&"iron": ["Tira de metales hasta 40 m", "Doble de fuerza y más alcance"],
	&"pewter": ["1,6× velocidad, 1,3× salto, +75 % daño, aguantás caídas de ~20 m", "2,2× velocidad, doble de daño; si se agota avivando: arrastre"],
	&"atium": ["Ves el futuro: esquivás todo, tus monedas no fallan y tus golpes no se bloquean (45 % crítico)",
			"Más críticos (70 %) y estela Sandevistan"],
	&"zinc": ["Enardece al de la mira: ataca más pero recibe más", "Cono: frenesí, los alománticos atacan a los suyos"],
	&"copper": ["Nube: el bronce no te detecta; inmune a cinc y latón", "Nube del doble de radio"],
	&"bronze": ["Sentís a los alománticos que queman metales", "Más alcance"],
	&"tin": ["Ves más lejos en la bruma; te recuperás antes de los golpes", "Casi a través de la bruma; un relámpago te encandila"],
	&"brass": ["Aplaca al de la mira: deja de atacar", "Cono; un enemigo con poca vida se rinde"],
}
