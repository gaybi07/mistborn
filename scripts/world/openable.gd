class_name Openable
extends Node3D
## Puerta o ventana que se abre con E. Este nodo queda quieto (con la zona para usarla) y cada
## hoja cuelga de una bisagra (add_leaf) que gira. Las trabadas solo se abren desde adentro
## (el lado contrario a `outward`). Una vez abierta queda así hasta que cambia el día.

## Hacia dónde queda afuera (en el mundo).
var outward := Vector3.BACK
## Trabada desde afuera.
var locked := false
var noun := "la puerta"
var _hinges := []  # [bisagra, cuánto gira al abrir]
var _open := false
var _day := ""
var _zone: Interactable


## Bisagra en `pos` (local) que gira `swing` radianes al abrir; las piezas de la hoja van dentro.
func add_leaf(pos: Vector3, swing: float) -> Node3D:
	var h := Node3D.new()
	h.position = pos
	add_child(h)
	_hinges.append([h, swing])
	return h


## Zona para usarla con E (caja con centro en `offset` respecto a este nodo).
func add_zone(size: Vector3, offset: Vector3) -> void:
	_zone = Interactable.make(size, offset, "Abrir " + noun, _use)
	add_child(_zone)


func _ready() -> void:
	set_process(false)


func _use() -> void:
	if not _open and locked:
		var player := get_tree().get_first_node_in_group(&"player") as Node3D
		if player and (player.global_position - global_position).dot(outward) > 0.0:
			_zone.set_prompt("Trabada desde adentro")
			get_tree().create_timer(1.5).timeout.connect(func() -> void: _zone.set_prompt("Abrir " + noun))
			return
	_set_open(not _open)


func _set_open(value: bool) -> void:
	_open = value
	_day = Art.lighting
	set_process(_open)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.set_parallel()
	for h: Array in _hinges:
		tw.tween_property(h[0], "rotation:y", h[1] if _open else 0.0, 0.8)
	_zone.set_prompt(("Cerrar " if _open else "Abrir ") + noun)


func _process(_delta: float) -> void:
	if Art.lighting != _day:
		_set_open(false)
