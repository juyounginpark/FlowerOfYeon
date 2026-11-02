extends "res://tests/verify_fairy_story.gd"
func _initialize() -> void:
	call_deferred("run")
	create_timer(180).timeout.connect(func():push_error("hands timeout");quit(1))
func advance_both(seconds:float) -> void:
	for i in range(roundi(seconds*60)):
		world.transition._process(1.0/60)
		world.stage_intro._process(1.0/60)
func run() -> void:
	root.size=Vector2i(1280,720)
	world=load("res://scripts/grid_stage/world.gd").new();root.add_child(world)
	world.transition.set_process(false);world.stage_intro.set_process(false)
	for runtime in range(1,13):
		world.load_stage(runtime)
		check(world.transition.phase=="descend" and world.player.input_locked,"direct entry carries player")
		check(not world.player.sprite.visible and world.transition.proxy.visible,"carried player rendered once")
		advance_both(1.3)
		check(world.transition.phase=="release" and world.transition.hand.visible,"left hand releases")
		check(world.stage_intro.elapsed==0 and world.stage_intro.brush.modulate.a==0,"right hand waits during placement")
		check(world.stage_intro.brush.texture.resource_path.contains("right_brush"),"reference-based right arm is active")
		check(world.transition.palm.opened.texture.resource_path.contains("left_open"),"new left hand artwork is active")
		await frames(3)
		if runtime in [1,11]:await capture("hands_%d_simultaneous"%runtime)
		world.paused=true;var time:float=world.transition.phase_time;var intro_time:float=world.stage_intro.elapsed
		advance_both(.2)
		check(time==world.transition.phase_time and intro_time==world.stage_intro.elapsed,"both hands pause together")
		world.paused=false
		advance_both(.7)
		check(world.player.sprite.visible and not world.player.input_locked,"left hand places and unlocks player")
		check(not world.stage_intro.waiting_for_hand,"release signals title")
		advance_both(1)
		check(not world.transition.active and not world.transition_consumed,"entry leaves ending transition available")
		advance_both(4.2)
		check(not world.stage_intro.panel.visible,"two-second title hold fades")
	world.load_stage(10);advance_both(3)
	world.transition.start()
	var book=world.transition.book
	for tick in range(120):
		if book.state=="shrink":break
		await frames(1)
	book.tick(2);book.tick(1);book.tick(2);book.request_turn()
	book.tick(.7);book.tick(.24);book.tick(.65);book.tick(1.1)
	for tick in range(120):
		if book.state=="turn":break
		await frames(1)
	book.tick(3);book.tick(1);book.tick(7);book.request_turn();book.tick(2)
	check(world.stage_number==11 and world.transition.phase=="descend","book transition enters next map")
	advance_both(1.3)
	check(world.transition.phase=="release" and world.stage_intro.elapsed==0,"next map title waits for placement")
	await capture("hands_next_stage")
	world.restart()
	check(world.transition.phase=="descend" and world.stage_intro.elapsed==0,"restart replays synchronized entry")
	world.queue_free();await frames()
	if not failed:print("PASS: %d sequential hand checks"%checks)
	quit(1 if failed else 0)
