class_name PauseMenu
extends CanvasLayer
## Menú de Esc: pausa el juego y muestra todas las habilidades y cómo se usan
## (pestañas Controles, Metales y Combate), más Reanudar y Reaparecer.

var player: Player

var _root: Control


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(900, 600)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.065, 0.085, 0.96)
	style.border_color = Color(0.4, 0.42, 0.5, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Pausa"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	tabs.add_child(_page("Controles", CONTROLS))
	tabs.add_child(_metals_page())
	tabs.add_child(_page("Combate", COMBAT))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var resume := Button.new()
	resume.text = "Reanudar (Esc)"
	resume.pressed.connect(close)
	buttons.add_child(resume)
	var respawn := Button.new()
	respawn.text = "Reaparecer"
	respawn.pressed.connect(func() -> void:
		close()
		player.respawn()
	)
	buttons.add_child(respawn)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _root.visible:
			close()
		elif not player.ui_open:
			open()
		else:
			return  # otra ventana abierta (inventario): que la cierre ella
		get_viewport().set_input_as_handled()


func open() -> void:
	_root.visible = true
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


const CONTROLS := """[table=2]
[cell][b]WASD[/b][/cell][cell]Moverse[/cell]
[cell][b]Espacio[/b][/cell][cell]Saltar[/cell]
[cell][b]Shift[/b][/cell][cell]Rodar · en el aire: dash · justo antes de aterrizar: amortigua la caída[/cell]
[cell][b]1 2 3 4[/b][/cell][cell]Acero, hierro, peltre, atium[/cell]
[cell][b]Z X C V B[/b][/cell][cell]Cinc, cobre, bronce, estaño, latón[/cell]
[cell][b]N[/b][/cell][cell]Apagar todos los metales[/cell]
[cell][b]Tab[/b] (mantener)[/cell][cell]Rueda de metales: apuntá con el ratón y soltá Tab; clic = avivar[/cell]
[cell][b]Clic izquierdo[/b][/cell][cell]Tirar (hierro). Con un solo metal encendido, cualquier clic lo usa[/cell]
[cell][b]Clic derecho[/b][/cell][cell]Empujar (acero)[/cell]
[cell][b]R[/b][/cell][cell]Anclar los agarres activos (siguen sin mantener el clic)[/cell]
[cell][b]Q[/b][/cell][cell]Lanzar moneda a la mira · corriendo con acero/hierro: recta hacia delante, con acero más rápida (avivado, aún más)[/cell]
[cell][b]G[/b] (mantener)[/cell][cell]Moneda a los pies y empuje: salto alto o frenar una caída. Con WASD dirigís el salto; se dibuja dónde caerías[/cell]
[cell][b]F[/b][/cell][cell]Soltar / recoger la bolsa de monedas: sin ella nadie puede empujarte ni tirar de vos (pero no tenés monedas)[/cell]
[cell][b]E[/b][/cell][cell]Usar lo que tengas al lado (puertas, armarios) o atacar (desenvaina las dagas sola) · seguido: combo · en el aire: golpe giratorio con salto extra[/cell]
[cell][b]Rueda del ratón[/b][/cell][cell]Cambiar de arma (puños, dagas, espada)[/cell]
[cell][b]T[/b][/cell][cell]Beber un frasco[/cell]
[cell][b]H[/b][/cell][cell]Capucha[/cell]
[cell][b]I[/b][/cell][cell]Inventario: capa, ropa, botas, dagas, espada y frascos. Doble clic para equipar o quitar[/cell]
[cell][b]M[/b][/cell][cell]Mapa de Luthadel con dónde estás (arriba a la derecha está siempre el minimapa)[/cell]
[cell][b]Contra un borde[/b][/cell][cell]Volando o cayendo contra un edificio te agarrás al borde si el choque no te haría más de 10 de daño (el peltre aguanta más). W o Espacio: subir · S o Shift: soltarte[/cell]
[cell][b]F1 / F2[/b][/cell][cell]Ciudad / arena[/cell]
[cell][b]F3 F4 F5[/b][/cell][cell]Día/noche · clima · niebla[/cell]
[/table]"""

const COMBAT := """[b]Combos[/b] (E seguido, a tiempo):
  Puños: directo, patada, remate.
  Dagas: cuatro golpes distintos; el cuarto es un tajo doble más fuerte que empuja lejos.
  Espada: dos tajos y un remate fuerte que empuja lejos.
  El remate va con una estocada hacia delante.

[b]Golpe aéreo[/b]: E en el aire. Un tajo giratorio que pega alrededor tuyo y te da un salto extra (uno por salto).

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
	&"atium": ["Ves el futuro (~0,6 s) y esquivás solo", "Cámara lenta (Sandevistan)"],
	&"zinc": ["Enardece al de la mira: ataca más pero recibe más", "Cono: frenesí, los alománticos atacan a los suyos"],
	&"copper": ["Nube: el bronce no te detecta; inmune a cinc y latón", "Nube del doble de radio"],
	&"bronze": ["Sentís a los alománticos que queman metales", "Más alcance"],
	&"tin": ["Ves más lejos en la bruma; te recuperás antes de los golpes", "Casi a través de la bruma; un relámpago te encandila"],
	&"brass": ["Aplaca al de la mira: deja de atacar", "Cono; un enemigo con poca vida se rinde"],
}
