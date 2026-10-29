class_name Interactable
extends Area3D
## Zona donde el jugador puede usar algo con E (abrir una puerta, empujar un armario...).
## Mientras está dentro, Player.interactable apunta aquí y E llama a `action` en vez de atacar.
## Con prompt vacío no se puede usar (ni se muestra el aviso).

var prompt := ""
var action: Callable
var _label: Label3D
var _inside := false


static func make(size: Vector3, pos: Vector3, text: String, on_use: Callable) -> Interactable:
	var it := Interactable.new()
	it.position = pos
	it.prompt = text
	it.action = on_use
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	it.add_child(col)
	return it


func _ready() -> void:
	collision_layer = 0
	collision_mask = Props.LAYER_PLAYER
	monitorable = false
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 30
	_label.outline_size = 8
	_label.pixel_size = 0.004
	_label.modulate = Color(1.0, 0.92, 0.75)
	_label.position.y = 0.6
	_label.visible = false
	add_child(_label)
	set_prompt(prompt)
	body_entered.connect(func(b: Node3D) -> void:
		if b is Player:
			(b as Player).interactable = self
			_inside = true
			set_prompt(prompt))
	body_exited.connect(func(b: Node3D) -> void:
		if b is Player:
			if (b as Player).interactable == self:
				(b as Player).interactable = null
			_inside = false
			_label.visible = false)


func set_prompt(text: String) -> void:
	prompt = text
	_label.text = "[E] " + text
	_label.visible = _inside and text != ""


func use() -> void:
	if prompt != "":
		action.call()
