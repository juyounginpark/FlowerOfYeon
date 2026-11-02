extends SceneTree
var failed := false
var checks := 0
var world: GridStageWorld

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error(message)

func frames(count := 2) -> void:
	for i in range(count):
		await process_frame

func key(pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	await frames()

func mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(640, 600)
	event.global_position = event.position
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames()

func capture(file: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/" + file + ".png")

func run() -> void:
	root.size = Vector2i(1280, 720)
	world = load("res://scenes/grid_stage/main.tscn").instantiate()
	world.stage_number = 5
	root.add_child(world)
	world.transition.cancel()
	world.stage_intro.hide()
	await frames(4)
	var dialogue = world.get("stage2_dialogue")
	check(world.dialogue == dialogue, "uses shared world interaction target")
	await key(true)
	await key(false)
	check(not dialogue.active, "far E does not start dialogue")
	world.player.position = Vector3(-1.12, 0.04, 1.8)
	world.player.velocity = Vector3.ZERO
	await frames(20)
	await key(true)
	await key(false)
	check(dialogue.active and dialogue.bubble.visible, "near E shows shared bubble")
	check(dialogue.line.text == dialogue.lines[0], "configured woodcutter line")
	check(not world.player.input_locked, "shared dialogue does not lock player")
	await capture("stage2-dialogue-shared")
	var elapsed: float = dialogue.elapsed
	await key(true)
	await key(false)
	check(dialogue.elapsed > elapsed, "repeated E does not restart speech")
	dialogue._process(dialogue.display_seconds + dialogue.fade_seconds)
	check(not dialogue.active and not dialogue.bubble.visible, "shared timeout hides bubble")
	await key(true)
	await key(false)
	check(dialogue.active, "E can reopen dialogue")
	world.restart()
	world.transition.cancel()
	await frames(5)
	check(not is_instance_valid(dialogue) and not world.player.input_locked, "restart cleans dialogue")
	world.load_stage(4)
	world.transition.cancel()
	await frames(5)
	check(world.dialogue == null and not world.stage_root.has_node("Stage2Dialogue"), "other stage has no Stage2 dialogue")
	world.queue_free()
	await frames(3)
	print("Stage2 shared dialogue: ",checks," checks, failed=",failed)
	quit(1 if failed else 0)
