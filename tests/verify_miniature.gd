extends "res://tests/verify_fairy_story.gd"
func run() -> void:
	root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURES))
	world=load("res://scripts/grid_stage/world.gd").new();root.add_child(world)
	world.transition.cancel();world.stage_intro.hide();await frames(12)
	var slices:Node
	var cutter:GridPaperCutting
	for child in world.stage_root.get_children():
		if child.get_script()==load("res://scripts/grid_stage/screen_slices.gd"):slices=child
		if child is GridFlowerBackdrop:
			for candidate in child.get_children():
				if candidate is GridPaperCutting:cutter=candidate
	check(slices!=null and cutter!=null,"post effect and cuttable illustrations available")
	check(slices.canvas.layer<world.hud.layer,"HUD stays outside miniature blur")
	await capture("miniature_enabled")
	slices.miniature.hide();await capture("miniature_disabled");slices.miniature.show()
	for piece in cutter.pieces:
		check(piece.shadow.get_parent()==piece.visual,"shadow follows piece transform")
		check(piece.shadow.get_meta("resolved_screen_band")==piece.visual.get_meta("resolved_screen_band"),"shadow shares original render band")
	var piece:Dictionary=cutter.pieces[0]
	var bounds:=Rect2(piece.polygon[0],Vector2.ZERO)
	for point:Vector2 in piece.polygon:bounds=bounds.expand(point)
	var count:=cutter.pieces.size()
	cutter._cut(piece.body.transform*Vector2(bounds.position.x-20,bounds.get_center().y),piece.body.transform*Vector2(bounds.end.x+20,bounds.get_center().y))
	await frames(6)
	check(cutter.pieces.size()>count,"cut creates new fragments")
	for fragment in cutter.pieces:check(is_instance_valid(fragment.shadow),"new fragments retain their own shadow")
	await capture("miniature_cut_shadows")
	world.load_stage(5);world.transition.cancel();world.stage_intro.hide();await frames(12)
	await capture("miniature_stage2")
	world.queue_free();await frames()
	if not failed:print("PASS: %d miniature and cut-shadow checks"%checks)
	quit(1 if failed else 0)
