extends "res://tests/verify_fairy_story.gd"
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURES))
	world=load("res://scripts/grid_stage/world.gd").new();world.stage_number=5;root.add_child(world)
	world.transition.cancel();world.stage_intro.hide();world.stage_intro.set_process(false)
	for tick in range(10):await physics_frame
	var d=world.dialogue
	check(world.label.get_theme_font("font").resource_path.ends_with("HS-Winter-Snowflake.ttf"),"HUD uses bundled font")
	check(d.line.get_theme_font("font").resource_path.ends_with("HS-Winter-Snowflake.ttf"),"speech uses bundled font")
	world._update_interaction_icon(0)
	check(world.interaction_icon.visible and world.nearest_interaction()==d,"nearest NPC icon")
	await capture("interaction_npc")
	var camera_pose:=world.camera.global_transform
	await key(KEY_E)
	check(d.active and d.line.text in ["곶감이 먹고 싶네.","나무를 배어야하는데"],"E selects one random line")
	check(not world.player.input_locked and camera_pose==world.camera.global_transform,"no movement lock or camera change")
	var text_before:String=d.line.text
	var time_before:float=d.elapsed
	await key(KEY_E)
	check(d.line.text==text_before and d.elapsed>time_before,"E cannot restart active speech")
	await create_timer(.3).timeout
	await capture("woodcutter_floating")
	d.set_process(false)
	d._process(d.display_seconds-d.elapsed+.4)
	check(d.active and d.bubble.modulate.a<.9 and d.bubble.modulate.a>0,"timed fade")
	d._process(1)
	check(not d.active and not d.bubble.visible,"speech disappears")
	var seen:Dictionary={}
	d.rng.seed=42
	for i in range(30):
		check(d.begin(),"repeat interaction after expiry")
		seen[d.line.text]=true;d.cancel()
	check(seen.size()==2,"both configured random lines reachable")
	world.player.position=Vector3(-.4,.04,1.05);world.player.velocity=Vector3.ZERO
	for tick in range(10):await physics_frame
	check(d.can_interact(),"NPC and lift share interaction range")
	check(world.nearest_interaction()==world.lift,"closer lift wins over NPC")
	world._update_interaction_icon(0)
	await capture("interaction_lift")
	await key(KEY_E)
	check(world.rune_candidates[0].phase==world.LiftPhase.RISING and not d.active,"E activates only nearest lift")
	world.player.position=Vector3(-4,.04,2.4)
	check(not d.begin(),"range gate")
	world.restart();await frames(2)
	check(not world.dialogue.active,"restart clears speech")
	world.queue_free();await frames()
	if not failed:print("PASS: %d floating speech checks"%checks)
	quit(1 if failed else 0)
