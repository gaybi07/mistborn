extends SceneTree
## Brazo derecho de Vin cuadro a cuadro en un clip: ángulo del codo (180 = estirado), hacia dónde apunta el antebrazo
## en planta (0 = adelante, + = a su derecha), su altura y dónde está la mano respecto del pecho (x + = a su derecha).
## Uso: -- clip[@res://donante.glb] [pasos]
func _init() -> void:
	Art.player_model = "vin"
	var a := OS.get_cmdline_user_args()
	var spec := a[0].split("@")
	var steps: int = int(a[1]) if a.size() > 1 else 20
	var w := Node3D.new(); root.add_child(w); current_scene = w
	var rig: ModelRig = Art.player_rig({})
	if spec.size() > 1:
		rig.extra_donors.push_front([spec[1], Art._mixamo_same()])
	rig.anim_overrides["fly"] = [spec[0]]
	w.add_child(rig); rig.set_process(false)
	for i in 5: await process_frame
	rig._play("fly", 0.0, true)
	var ap: AnimationPlayer = rig._src_ap if rig._borrowed else rig._ap
	var length := ap.get_animation(ap.current_animation).length
	var skel: Skeleton3D = rig._skel
	var b := rig._bones
	print("%s %.2fs" % [spec[0], length])
	for k in steps + 1:
		rig.set_process(false)  # si no, el rig vuelve a su reposo y pisa la pose del clip
		ap.seek(length * k / steps, true)
		if rig._borrowed: rig._retargeter.apply()
		await process_frame
		rig.set_process(false)
		ap.seek(length * k / steps, true)
		if rig._borrowed: rig._retargeter.apply()
		var inv := rig.global_transform.affine_inverse()
		var sh: Vector3 = inv * BoneTools.bone_world_pos(skel, b["upper_r"])
		var el: Vector3 = inv * BoneTools.bone_world_pos(skel, b["lower_r"])
		var ha: Vector3 = inv * BoneTools.bone_world_pos(skel, b["hand_r"])
		var chest: Vector3 = inv * BoneTools.bone_world_pos(skel, b["torso"])
		var elbow := 180.0 - rad_to_deg((el - sh).angle_to(ha - el))
		# El personaje mira a -z; su derecha es +x.
		var fore := ha - el
		var yaw := rad_to_deg(atan2(fore.x, -fore.z))
		var arm := ha - sh
		var arm_yaw := rad_to_deg(atan2(arm.x, -arm.z))
		var rel := ha - chest
		var shl: Vector3 = inv * BoneTools.bone_world_pos(skel, b["upper_l"])
		var hal: Vector3 = inv * BoneTools.bone_world_pos(skel, b["hand_l"])
		var ell: Vector3 = inv * BoneTools.bone_world_pos(skel, b["lower_l"])
		var elbow_l := 180.0 - rad_to_deg((ell - shl).angle_to(hal - ell))
		var rel_l := hal - chest
		var neck: Vector3 = inv * BoneTools.bone_world_pos(skel, b["neck"])
		var hips: Vector3 = inv * BoneTools.bone_world_pos(skel, b["hips"])
		var lean := rad_to_deg(atan2(-(neck - hips).z, (neck - hips).y))  # + = torso inclinado hacia adelante
		printraw("torso %+3.0f° " % lean)
		print("%.2f DER codo %3.0f° brazo %+4.0f° alto %+.2f mano x%+.2f y%+.2f z%+.2f | IZQ codo %3.0f° mano x%+.2f y%+.2f z%+.2f" % [float(k) / steps, elbow, arm_yaw, arm.y, rel.x, rel.y, rel.z, elbow_l, rel_l.x, rel_l.y, rel_l.z])
	quit()
