extends "res://tests/verify_fairy_story.gd"
func run() -> void:
	root.size=Vector2i(1280,720)
	world=load("res://scripts/grid_stage/world.gd").new();world.stage_number=11;root.add_child(world)
	await create_timer(1.2).timeout
	await capture("butterfly_entrance")
	await create_timer(1.8).timeout
	var guide=world.stage_root.get_node("ButterflyGuide")
	check(guide.state=="waiting","real entrance finishes")
	world.player.position=guide.start_anchor-Vector3.UP*guide.CLEARANCE
	await create_timer(1).timeout
	check(guide.flying,"live approach starts flight")
	await capture("butterfly_in_flight")
	guide.set_process(false)
	for tick in range(4000):
		guide._process(1.0/60)
		if guide.state=="perched":break
	await create_timer(1.5).timeout
	await capture("butterfly_landed")
	guide.set_process(true)
	var goal:Vector2=world.stage_data.goal_rect.get_center()
	world.player.position=Vector3(goal.x,world.stage_data.goal_height+.03,goal.y)
	await create_timer(1).timeout
	check(guide.state=="departing" and world.player.input_locked and not world.transition.active,"live departure precedes hand")
	await capture("butterfly_departure")
	await create_timer(2.1).timeout
	check(world.transition.active and world.transition.hand.visible,"hand appears after butterfly leaves")
	await capture("butterfly_hand_after_exit")
	world.queue_free();await frames()
	if not failed:print("PASS: real-time entrance, landing, departure and hand sequence")
	quit(1 if failed else 0)