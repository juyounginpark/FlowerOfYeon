extends "res://tests/stage2/verify_robe_puzzle.gd"
# --check-only only under current AGENTS.md; runtime scenario not executed.
func run() -> void:
	root.size = Vector2i(1280, 720)
	world = load("res://scenes/grid_stage/main.tscn").instantiate()
	world.stage_number = 5
	root.add_child(world)
	world.transition.cancel()
	world.stage_intro.hide()
	await frames(6)
	var puzzle = world.stage_root.get_node("Stage2RobePuzzle")
	if not await cut_and_settle(puzzle):
		quit(1)
		return
	var stage := world.stage_root
	var pickup := robe_point(puzzle)
	await motion(pickup)
	await mouse(pickup, true)
	var target := world.camera.unproject_position(puzzle.fairy.global_position)
	await motion(target, true)
	check(puzzle.surface_preview.get("host") == puzzle.fairy, "robe targets visible fairy")
	await mouse(target, false)
	check(puzzle.state in [puzzle.State.ASCENDING, puzzle.State.APPROACHING, puzzle.State.PUSHING], "wrong delivery begins woodcutter punishment")
	check(world.player.input_locked, "knockback owns player controls")
	var saw_impact := false
	var saw_hand := false
	for i in range(900):
		saw_impact = saw_impact or puzzle.impact.visible
		if puzzle.state == puzzle.State.UNCUT and world.transition.active:
			saw_hand = world.transition.phase == "descend"
			break
		await ticks(1)
	check(saw_impact, "shove shows painted impact")
	check(saw_hand, "restart repeats hand descent")
	check(world.stage_root == stage, "reset does not rebuild map or render viewports")
	check(puzzle.state == puzzle.State.UNCUT and puzzle.fairy.visible, "reset restores cut source and fairy")
	check(puzzle.actor.visible and puzzle.actor.animation == "axe", "reset restores idle woodcutter")
	check(puzzle.blocker.collision_layer == 1 and world.dialogue != null, "reset restores progression gate")
	world.queue_free()
	await frames()
	print("Stage2 shove/reset regression: ", checks, " checks, failed=", failed)
	quit(1 if failed else 0)
