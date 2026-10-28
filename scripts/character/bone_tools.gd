class_name BoneTools
## Utilidades de esqueleto:
## - aim(): orienta un hueso para que apunte en una dirección del mundo (su eje +Y es "a lo largo").
## - Retargeter: copia la pose de un esqueleto a otro distinto haciendo que cada hueso apunte
##   en la misma dirección. Funciona aunque las poses de reposo, proporciones y jerarquías difieran
##   (p. ej. Quaternius tiene los pies colgando de la raíz, KayKit de la pierna).


static func find_bone(skel: Skeleton3D, names: Array) -> int:
	for n in names:
		var i := skel.find_bone(n)
		if i >= 0:
			return i
	return -1


static func bone_world_pos(skel: Skeleton3D, bone: int) -> Vector3:
	return skel.global_transform * skel.get_bone_global_pose(bone).origin


## Gira el hueso (respecto a su pose actual) para que su eje +Y apunte a world_dir.
## weight 0..1 mezcla con la pose actual.
static func aim(skel: Skeleton3D, bone: int, world_dir: Vector3, weight := 1.0) -> void:
	if bone < 0 or world_dir.length_squared() < 1e-8:
		return
	var parent := skel.get_bone_parent(bone)
	var parent_basis := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var global_basis := parent_basis * skel.get_bone_pose(bone).basis.orthonormalized()
	var desired := (skel.global_basis.orthonormalized().inverse() * world_dir).normalized()
	var current := (global_basis * Vector3.UP).normalized()
	desired = current.slerp(desired, clampf(weight, 0.0, 1.0)).normalized()
	if current.dot(desired) > 0.99999:
		return
	var q := Quaternion(current, desired) if current.dot(desired) > -0.9999 else Quaternion(global_basis * Vector3.RIGHT, PI)
	var new_global := Basis(q) * global_basis
	skel.set_bone_pose_rotation(bone, (parent_basis.inverse() * new_global).get_rotation_quaternion())


class Retargeter:
	## Cada entrada: [hueso destino, hueso fuente, hueso fuente hijo (o ""), modo]
	## modos: "root" (rotación + desplazamiento), "rot" (copia el giro), "aim" (misma dirección),
	##        "foot" (misma dirección y colocado al final de `extra`, el hueso de la pierna).
	var src: Skeleton3D
	var dst: Skeleton3D
	var _entries := []
	var _height_ratio := 1.0

	func _init(source: Skeleton3D, target: Skeleton3D, mapping: Array) -> void:
		src = source
		dst = target
		for m in mapping:
			var e := {
				"dst": dst.find_bone(m[0]), "src": src.find_bone(m[1]),
				"src_child": src.find_bone(m[2]) if m[2] != "" else -1, "mode": m[3],
				"extra": dst.find_bone(m[4]) if m.size() > 4 else -1,
			}
			if e["dst"] < 0 or e["src"] < 0:
				continue
			if e["mode"] == "foot" and e["extra"] >= 0:
				# Dónde cae el pie respecto al hueso de la pierna en reposo.
				var leg_rest := dst.get_bone_global_rest(e["extra"])
				e["foot_offset"] = leg_rest.affine_inverse() * dst.get_bone_global_rest(e["dst"]).origin
			_entries.append(e)
		_entries.sort_custom(func(a, b): return a["dst"] < b["dst"])  # padres antes que hijos

	func apply() -> void:
		var src_basis := src.global_basis.orthonormalized()
		var dst_basis := dst.global_basis.orthonormalized()
		dst.reset_bone_poses()
		for e in _entries:
			var d: int = e["dst"]
			var s: int = e["src"]
			match e["mode"]:
				"root", "rot":
					var src_now: Basis = src_basis * src.get_bone_global_pose(s).basis.orthonormalized()
					var src_rest: Basis = src_basis * src.get_bone_global_rest(s).basis.orthonormalized()
					var dst_rest: Basis = dst_basis * dst.get_bone_global_rest(d).basis.orthonormalized()
					var new_global: Basis = dst_basis.inverse() * ((src_now * src_rest.inverse()) * dst_rest)
					var parent := dst.get_bone_parent(d)
					var parent_basis := dst.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
					dst.set_bone_pose_rotation(d, (parent_basis.inverse() * new_global).get_rotation_quaternion())
					if e["mode"] == "root":
						var src_scale := src.global_basis.get_scale().x
						var dst_scale := dst.global_basis.get_scale().x
						var src_h := src.get_bone_global_rest(s).origin.y * src_scale
						var dst_h := dst.get_bone_global_rest(d).origin.y * dst_scale
						var offset := src_basis * (src.get_bone_global_pose(s).origin - src.get_bone_global_rest(s).origin) * src_scale
						if src_h > 0.001:
							offset *= dst_h / src_h
						var parent_pose := dst.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
						var target_pos := dst.get_bone_global_rest(d).origin + dst_basis.inverse() * offset / dst_scale
						dst.set_bone_pose_position(d, parent_pose.affine_inverse() * target_pos)
				"aim", "foot":
					if e["mode"] == "foot" and e["extra"] >= 0:
						var leg := dst.get_bone_global_pose(e["extra"])
						var parent := dst.get_bone_parent(d)
						var parent_pose := dst.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
						dst.set_bone_pose_position(d, parent_pose.affine_inverse() * (leg * e["foot_offset"]))
					var c: int = e["src_child"]
					if c >= 0:
						var dir := BoneTools.bone_world_pos(src, c) - BoneTools.bone_world_pos(src, s)
						BoneTools.aim(dst, d, dir)


## Mapeo KayKit (fuente) -> Quaternius (destino).
const KAYKIT_TO_QUATERNIUS := [
	["Body", "hips", "", "root"],
	["Abdomen", "spine", "chest", "aim"],
	["Torso", "chest", "head", "aim"],
	["Head", "head", "", "rot"],
	["UpperArm.L", "upperarm.l", "lowerarm.l", "aim"],
	["LowerArm.L", "lowerarm.l", "wrist.l", "aim"],
	["UpperArm.R", "upperarm.r", "lowerarm.r", "aim"],
	["LowerArm.R", "lowerarm.r", "wrist.r", "aim"],
	["UpperLeg.L", "upperleg.l", "lowerleg.l", "aim"],
	["LowerLeg.L", "lowerleg.l", "foot.l", "aim"],
	["Foot.L", "foot.l", "toes.l", "foot", "LowerLeg.L"],
	["UpperLeg.R", "upperleg.r", "lowerleg.r", "aim"],
	["LowerLeg.R", "lowerleg.r", "foot.r", "aim"],
	["Foot.R", "foot.r", "toes.r", "foot", "LowerLeg.R"],
]
