extends SceneTree
var failed := false
var checks := 0
const FEATURES := ["Stage2Woodcutter", "Stage2WoodcutterBlocker", "Stage2Photos", "Stage2Dialogue", "Stage2RobePuzzle"]

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error(message)

func frames(count := 3) -> void:
	for i in range(count):
		await process_frame

func split_robe(world: GridStageWorld) -> Node:
	var puzzle := world.stage_root.get_node("Stage2RobePuzzle")
	var center: Vector2 = puzzle.original_piece.body.position
	var low := INF
	var high := -INF
	for point: Vector2 in puzzle.original_piece.polygon:
		low = minf(low, point.x)
		high = maxf(high, point.x)
	puzzle._cut(center + Vector2(low - 30, 0), center + Vector2(high + 30, 0))
	check(puzzle.state == puzzle.State.SETTLING, "physical split available inside integrated scene")
	for i in range(360):
		if puzzle.state == puzzle.State.ROBE_READY: break
		await physics_frame
		await process_frame
	return puzzle

func run() -> void:
	var menu = load("res://scenes/grid_stage/menu.tscn").instantiate()
	root.add_child(menu)
	menu.stage_buttons[0].pressed.emit()
	var world: GridStageWorld = menu.world
	check(world.stage_number == 4 and world.scene_file_path == "res://scenes/grid_stage/main.tscn", "Stage1 menu still opens shared main scene")
	check(not world.stage_root.has_node("Stage2RobePuzzle"), "Stage1 has no Stage2 puzzle")
	# Exercise upstream book transition into the integrated Stage2 scene.
	world.transition.cancel()
	world.transition.set_process(false)
	world.transition.start()
	await frames(6)
	var book = world.transition.book
	check(book.state == "shrink", "Stage1 starts upstream book transition")
	book.tick(2); book.tick(1); book.tick(2)
	await frames(6)
	check(book.state == "turn", "book captures integrated Stage2")
	book.tick(3); book.tick(1); book.tick(3)
	check(book.request_turn(), "book accepts entry click")
	book.tick(2)
	world.transition.set_process(true)
	check(world.stage_number == 5, "existing Stage1 clear transition enters Stage2")
	check(world.dialogue == world.get("stage2_dialogue") and not world.stage_root.has_node("WoodcutterDialogue"), "no duplicate upstream woodcutter")
	for node_name: String in FEATURES:
		check(world.stage_root.has_node(node_name), "Stage2 owns " + node_name)
	world.transition.cancel()
	world.player.position = Vector3(-1.12, 0.04, 1.8)
	await frames(20)
	world.get("stage2_dialogue").begin()
	check(world.get("stage2_dialogue").active and not world.player.input_locked, "shared dialogue keeps normal controls")
	var old_stage := world.stage_root
	world.load_stage(6)
	world.transition.cancel()
	await frames()
	check(not is_instance_valid(old_stage), "switch removes old Stage2 subtree")
	check(world.get("stage2_dialogue") == null and not world.player.input_locked and not world.paused, "active dialogue leaves no lock/UI in next stage")
	for node_name: String in FEATURES:
		check(not world.stage_root.has_node(node_name), "Stage3 excludes " + node_name)
	world.load_stage(5)
	world.transition.cancel()
	var dragging := await split_robe(world)
	await frames()
	dragging._begin_drag(dragging.robe_piece)
	check(is_instance_valid(dragging.grabbed), "item drag active before transition")
	var old_body: Node = dragging.grabbed
	world.load_stage(4)
	world.transition.cancel()
	await frames()
	check(not is_instance_valid(dragging) and not is_instance_valid(old_body), "drag and physics body removed on stage change")
	check(not world.player.input_locked, "no drag-related lock in next map")
	world.load_stage(5)
	world.transition.cancel()
	var fading := await split_robe(world)
	fading._deliver()
	check(fading.state == fading.State.ESCAPING, "escape active before restart")
	world.restart()
	world.transition.cancel()
	await frames(60)
	check(is_instance_valid(fading) and fading.state == fading.State.UNCUT, "restart resets reused escape controller")
	check(world.stage_root.get_node("Stage2Woodcutter").modulate.a == 1.0 and world.stage_root.has_node("Stage2WoodcutterBlocker"), "old fade cannot remove the restarted woodcutter")
	# Every other runtime id continues to use the inherited base gameplay.
	for number in range(1, 13):
		if number == 5:
			continue
		world.load_stage(number)
		world.transition.cancel()
		await frames()
		check(world.stage_number == number and world.get("stage2_dialogue") == null, "runtime %d has no Stage2 dialogue" % number)
		check(world.stage_root.has_node("StartAndPath") and world.stage_root.has_node("HighGoalAndTerrace")  , "runtime %d retains base terrain" % number)
		for node_name: String in FEATURES:
			check(not world.stage_root.has_node(node_name), "runtime %d excludes %s" % [number, node_name])
	world.load_stage(5)
	world.transition.cancel()
	world._return_to_selection()
	await frames()
	check(menu.world == null and menu.menu.visible, "Back returns to original menu")
	menu.stage_buttons[1].pressed.emit()
	await frames()
	check(menu.world.stage_number == 5 and menu.world.scene_file_path == "res://scenes/grid_stage/main.tscn", "reselecting Stage2 uses main scene")
	check(menu.world.stage_root.get_node("Stage2RobePuzzle").state == 0, "reentry starts fresh puzzle")
	menu.queue_free()
	await frames()
	if not failed:
		print("PASS: %d main.tscn integration/lifecycle checks" % checks)
	quit(1 if failed else 0)
