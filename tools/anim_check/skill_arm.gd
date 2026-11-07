extends SceneTree
## Brazo derecho de Vin mientras hace un poder en el juego (la capa de arriba sobre la guardia), cada 1/15 s:
## codo, hacia dónde apunta el brazo (0 = adelante, + = a su derecha), su altura y la mano respecto del pecho.
## Uso: -- <poder de HeroClips.SKILLS>
const DT := 1.0 / 60.0
func _init() -> void:
	Art.player_model = "vin"
	var skill: String = OS.get_cmdline_user_args()[0]
	var w := Node3D.new(); root.add_child(w); current_scene = w
	var rig: ModelRig = Art.player_rig({})
	w.add_child(rig); rig.set_process(false)
	for i in 5: await process_frame
	rig.brace = 1.0
	for i in 30:
		rig.set_process(false); rig._process(DT); await process_frame
	var t0 := rig.play_skill(skill, 0.9, 0.25)
	print("%s: dura %.2f s, suelta a %.2f s" % [skill, t0, rig.impact_delay()])
	var skel: Skeleton3D = rig._skel
	var b := rig._bones
	var t := 0.0
	while t < t0 + 0.2:
		rig.set_process(false); rig._process(DT); await process_frame
		t += DT
		if int(t * 60.0) % 4 != 0:
			continue
		var inv := rig.global_transform.affine_inverse()
		var sh: Vector3 = inv * BoneTools.bone_world_pos(skel, b["upper_r"])
		var el: Vector3 = inv * BoneTools.bone_world_pos(skel, b["lower_r"])
		var ha: Vector3 = inv * BoneTools.bone_world_pos(skel, b["hand_r"])
		var chest: Vector3 = inv * BoneTools.bone_world_pos(skel, b["torso"])
		var neck: Vector3 = inv * BoneTools.bone_world_pos(skel, b["neck"])
		var hips: Vector3 = inv * BoneTools.bone_world_pos(skel, b["hips"])
		var lean := rad_to_deg(atan2(-(neck - hips).z, (neck - hips).y))
		var elbow := 180.0 - rad_to_deg((el - sh).angle_to(ha - el))
		var arm := ha - sh
		var rel := ha - chest
		var shl: Vector3 = inv * BoneTools.bone_world_pos(skel, b["upper_l"])
		var shoulders := rad_to_deg(atan2(-(sh - shl).z, (sh - shl).x))  # giro del pecho (0 = de frente)
		print("%.2fs codo %3.0f° brazo %+4.0f° alto %+.2f  mano-pecho x%+.2f y%+.2f z%+.2f torso %+3.0f° hombros %+4.0f°%s" % [t, elbow, rad_to_deg(atan2(arm.x, -arm.z)), arm.y, rel.x, rel.y, rel.z, lean, shoulders, "  <- suelta" if absf(t - rig.impact_delay()) < 0.034 else ""])
	quit()
