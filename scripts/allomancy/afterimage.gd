class_name Afterimage
extends Node3D
## Estela del Sandevistan: copia congelada de las mallas del personaje que se desvanece.
## Usa tiempo real para no quedarse "congelada" mientras el mundo va a cámara lenta.

const GHOST_SHADER := preload("res://shaders/ghost.gdshader")

var _mat := ShaderMaterial.new()
var _life := 0.5
var _born := 0.0


func setup(source: Node3D, color: Color, life: float) -> void:
	_life = life
	_born = Time.get_ticks_msec() / 1000.0
	_mat.shader = GHOST_SHADER
	_mat.set_shader_parameter(&"tint", color)
	_mat.set_shader_parameter(&"strength", 1.0)
	global_transform = source.global_transform
	copy_meshes(source, self, _mat)


func _process(_delta: float) -> void:
	var t := (Time.get_ticks_msec() / 1000.0 - _born) / _life
	if t >= 1.0:
		queue_free()
		return
	_mat.set_shader_parameter(&"strength", 1.0 - t)


static func ghost_material(color: Color, strength: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GHOST_SHADER
	m.set_shader_parameter(&"tint", color)
	m.set_shader_parameter(&"strength", strength)
	return m


## Copia todas las MeshInstance3D descendientes de `source` dentro de `into`, con `mat`.
## Devuelve pares [malla_original, copia] por si se quiere seguir actualizando la pose.
static func copy_meshes(source: Node3D, into: Node3D, mat: Material) -> Array:
	var pairs := []
	var inv := source.global_transform.affine_inverse()
	var stack: Array[Node] = [source]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var copy := MeshInstance3D.new()
		# Mallas con esqueleto: se congela la pose actual (si no, saldría en pose T).
		copy.mesh = mi.bake_mesh_from_current_skeleton_pose() if mi.skin else mi.mesh
		copy.transform = inv * mi.global_transform
		copy.material_override = mat
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		into.add_child(copy)
		pairs.append([mi, copy])
	return pairs
