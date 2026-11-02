extends "res://tests/stage3/verify_sun_puzzle.gd"

func press_e() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	await ticks(2)
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = false
	Input.parse_input_event(event)
	await ticks(2)

func run() -> void:
	root.size = Vector2i(1280,720)
	world = load("res://scenes/grid_stage/main.tscn").instantiate()
	world.stage_number = 6
	root.add_child(world)
	world.transition.cancel()
	world.stage_intro.hide()
	await ticks(20)
	var speech = world.dialogue
	check(is_instance_valid(speech), "Stage3 dialogue connected")
	check(speech.position == world.stage_root.get_node("Stage3Character9").position, "dialogue anchored to character9")
	check(world.nearest_interaction() == speech, "nearby E selects character9")
	await press_e()
	check(speech.active and speech.bubble.visible, "physical E opens dialogue")
	check(speech.line.text == speech.SCRIPT_LINE, "exact requested script")
	await ticks(15)
	var elapsed: float = speech.elapsed
	await press_e()
	check(speech.elapsed > elapsed, "repeated E does not restart active speech")
	await capture("stage3-character9-dialogue")
	speech._process(speech.display_seconds + speech.fade_seconds)
	check(not speech.active and not speech.bubble.visible, "shared timed fade closes dialogue")
	await press_e()
	check(speech.active, "nearby E reopens completed dialogue")
	speech.cancel()
	var puzzle = world.story
	puzzle._start_bridge()
	await press_e()
	check(speech.line.text == speech.SCRIPT_LINE, "assembly keeps the jump-into-sea hint")
	speech.cancel()
	puzzle._advance_bridge(3)
	puzzle._advance_clouds(1.8)
	await frames(3)
	check(puzzle.path_open and puzzle.clouds.is_empty(), "completed creature path clears clouds")
	await press_e()
	check(speech.active and speech.line.text == speech.CLEAR_LINE, "E after opening acknowledges fish and turtles")
	await capture("stage3-character9-fish-hint")
	speech.cancel()
	world.player.position = Vector3(.7,.04,4.3)
	world.player.velocity = Vector3.ZERO
	await ticks(15)
	check(not speech.can_interact(), "far away cannot interact")
	await press_e()
	check(not speech.active, "far away E does not open dialogue")
	world.load_stage(6)
	world.transition.cancel()
	await ticks(3)
	check(not is_instance_valid(speech), "restart frees old dialogue and UI")
	check(is_instance_valid(world.dialogue) and not world.dialogue.active, "restart creates idle dialogue")
	await ticks(20)
	await press_e()
	check(world.dialogue.active and world.dialogue.line.text == world.dialogue.SCRIPT_LINE, "restart restores original dialogue")
	world.load_stage(4)
	world.transition.cancel()
	await ticks(3)
	check(not world.stage_root.has_node("Stage3Character9Dialogue"), "other stage has no character9 dialogue")
	world.queue_free()
	await frames(3)
	print("Stage3 character9 dialogue: ", checks, " checks, failed=", failed)
	quit(1 if failed else 0)
