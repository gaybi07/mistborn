class_name MetalBag
extends RigidBody3D
## La bolsa de monedas del jugador, soltada en el suelo (F). Es metal: se puede empujar y tirar
## (con hierro la traes de lejos). Sin ella encima nadie puede empujar al jugador ni tirar de él.

const MASS := 1.5

var _mat_leather := Props.material(Color(0.24, 0.16, 0.1), 0.0, 0.85)
var _mat_coins := Props.material(Color(0.85, 0.6, 0.3), 1.0, 0.3)


func _ready() -> void:
	mass = MASS
	collision_layer = Props.LAYER_PROPS
	collision_mask = Props.LAYER_WORLD | Props.LAYER_PROPS
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.bounce = 0.05
	physics_material_override = pm
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.14
	col.shape = shape
	add_child(col)
	var pouch := SphereMesh.new()
	pouch.radius = 0.15
	pouch.height = 0.24
	_mesh(pouch, Vector3.ZERO, _mat_leather)
	var neck := CylinderMesh.new()
	neck.top_radius = 0.06
	neck.bottom_radius = 0.04
	neck.height = 0.08
	_mesh(neck, Vector3(0, 0.14, 0), _mat_leather)
	var coin := CylinderMesh.new()
	coin.top_radius = 0.045
	coin.bottom_radius = 0.045
	coin.height = 0.012
	_mesh(coin, Vector3(0, 0.185, 0), _mat_coins)
	add_to_group(&"metal")
	add_to_group(&"atium_visible")


func _mesh(mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
