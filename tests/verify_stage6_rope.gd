extends "res://tests/verify_stage6.gd"
func ink_point(piece:Dictionary) -> Vector2:
	var center:=Vector2.ZERO
	for point:Vector2 in piece.polygon:center+=point
	center/=float(piece.polygon.size())
	return world.camera.unproject_position(piece.visual.global_transform*Vector3(center.x,-center.y,0))
func run() -> void:
	root.size=Vector2i(1280,720)
	world=load("res://scripts/grid_stage/world.gd").new();world.stage_number=9;root.add_child(world)
	await create_timer(7.0).timeout
	var story=world.story
	story.set_process(false);world.player.paused=true
	await capture("tiger-start")
	await cut_source(story.rice)
	var rice_piece:Dictionary=loose(story.rice)
	check(not rice_piece.is_empty(),"rice cuts through native input")
	if not rice_piece.is_empty():
		var target:Vector2=world.camera.unproject_position(story.rotten.global_position)
		var start:=ink_point(rice_piece)
		await drag(start,target)
		check(story._bait_ready(),"native rice drop attaches to rotten rope")
	story._build_bridge()
	story.tiger_base=story.span[0].lerp(story.span[1],.5)
	story.tiger.position=story.tiger_base+world.camera.global_basis.y*1.1
	await frames(4);await capture("tiger-bridge")
	story.crossed=true;world.player.position=Vector3(1,1.8,0)
	story.sister_base=Vector3(.5,1.8,0);story.sister.position=story.sister_base+world.camera.global_basis.y*.625
	story.tiger_base=Vector3(0,1.8,.6);story._reached_middle()
	story.tiger.position=story.tiger_base+world.camera.global_basis.y*1.1
	await frames(4);await capture("tiger-middle")
	check(story.phase==story.Phase.ROPE,"tiger chooses rope when arriving at middle")
	var prepared_bait:Dictionary=story.rope_bait
	story.rope_bait={}
	story._reached_middle()
	check(story.phase==story.Phase.HUNT,"tiger pursues when no rope bait is attached")
	story.rope_bait=prepared_bait
	story._advance_tiger(.1)
	check(story.phase==story.Phase.ROPE,"tiger switches from pursuit to newly attached bait")
	if story.phase==story.Phase.ROPE:
		story.set_process(true)
		await create_timer(2.5).timeout
		await capture("tiger-rope")
		await create_timer(3.5).timeout
		check(story.phase==story.Phase.CLEARED and story.path_open,"tiger falls and opens the final lift")
		check(world.rune_candidates[0].enabled,"final lift unlocks after tiger falls")
		await capture("tiger-cleared")
	print("STAGE6_ROPE_RESULT failures=",failures)
	quit(failures)
