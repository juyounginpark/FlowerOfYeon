extends "res://tests/verify_fairy_story.gd"
func _initialize() -> void:
	call_deferred("run")
	create_timer(180).timeout.connect(func():push_error("butterfly lifecycle timeout");quit(1))
func run() -> void:
	root.size=Vector2i(1280,720)
	world=load("res://scripts/grid_stage/world.gd").new();root.add_child(world)
	for runtime in range(1,13):
		world.load_stage(runtime)
		var guide=world.stage_root.get_node("ButterflyGuide");guide.set_process(false)
		check(guide.state=="entering","starts with entrance")
		# Hand entry is covered by verify_bodhisattva_hands; isolate this lifecycle.
		world.transition.cancel()
		check(not Rect2(Vector2.ZERO,Vector2(root.size)).has_point(world.camera.unproject_position(guide.position)),"starts outside screen")
		for tick in range(180):guide._process(1.0/60)
		check(guide.state=="waiting","entrance reaches waiting point")
		check(guide.anchor.distance_to(guide.start_anchor)<.01,"waits at intended position")
		world.player.position=guide.start_anchor-Vector3.UP*guide.CLEARANCE
		world.player.input_locked=true;guide._process(.016)
		check(guide.state=="guiding","approach starts guidance")
		for tick in range(4000):
			guide._process(1.0/60)
			if guide.state=="perched":break
		check(guide.arrived and guide.state=="perched","lands at goal")
		check(absf(guide.position.y-world.stage_data.goal_height-.04)<.001,"rests on ground")
		var pose:Vector3=guide.position;var fold:float=guide.wings[0].rotation.y
		guide._process(.5)
		check(guide.position==pose and guide.wings[0].rotation.y==fold,"perched wings and body stay still")
		check(not guide.trail.emitting,"landed trail stops")
		await frames(3)
		if runtime in [1,11]:await capture("butterfly_%d_landed"%runtime)
		var goal:Vector2=world.stage_data.goal_rect.get_center()
		# Isolate departure from Stage8's separately covered return-dialogue gate.
		if world.story!=null:
			world.story.set_process(false);world.story.path_open=true
		world.player.input_locked=false
		if is_instance_valid(world.story):world.story.path_open=true
		world.player.position=Vector3(goal.x,world.stage_data.goal_height+.03,goal.y)
		for tick in range(45):
			await physics_frame
			if world.completed:break
		await frames(3)
		check(world.completed and world.player.input_locked,"goal immediately locks player")
		check(guide.state=="departing" and not world.transition.active,"butterfly leaves before hand")
		var stopped:Vector3=world.player.position
		Input.action_press("forward");await frames(5);Input.action_release("forward")
		check(world.player.position==stopped,"movement ignored during departure")
		world.paused=true;pose=guide.position;guide._process(.5)
		check(guide.position==pose and guide.trail.speed_scale==0,"departure pauses")
		world.paused=false
		for tick in range(155):guide._process(1.0/60)
		check(guide.departure_ready and guide.state=="gone","leaves screen completely")
		check(not Rect2(Vector2.ZERO,Vector2(root.size)).has_point(world.camera.unproject_position(guide.anchor)),"exit is offscreen")
		await frames(4)
		check(world.transition.active and world.player.input_locked,"hand starts after exit")
		world.load_stage(runtime)
		check(world.stage_root.get_node("ButterflyGuide").state=="entering","restart restores entrance")
	world.queue_free();await frames()
	if not failed:print("PASS: %d butterfly lifecycle checks"%checks)
	quit(1 if failed else 0)
