extends SceneTree

var checks := 0
var failed := false
var selection: Control
var world: GridStageWorld
const CAPTURES := "res://artifacts/ending/"

func _initialize() -> void:
	call_deferred("run")
	create_timer(90).timeout.connect(func(): push_error("Ending verification timed out"); quit(1))

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("FAIL: " + message)
		quit(1)
		assert(condition, message)

func frames(count := 3) -> void:
	for index in range(count): await process_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	Input.parse_input_event(event)
	await frames(2)

func click() -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = Vector2(640, 350)
		event.pressed = pressed
		root.push_input(event, true)

func capture(name_: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(4)
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(CAPTURES)
	DirAccess.make_dir_recursive_absolute(path)
	check(root.get_texture().get_image().save_png(path + name_ + ".png") == OK, "save capture")

func run() -> void:
	root.size = Vector2i(1280, 720)
	selection = load("res://scenes/grid_stage/menu.tscn").instantiate()
	root.add_child(selection)
	selection.select_map(12)
	world = selection.world
	await frames(5)
	check(not is_instance_valid(world.ending), "selecting final stage does not open ending")
	world.transition.cancel()
	world.transition.set_process(false)
	world.stage_intro.set_process(false)
	var guide = world.stage_root.get_node("ButterflyGuide")
	guide.set_process(false)
	var goal: Vector2 = world.stage_data.goal_rect.get_center()
	world.player.position = Vector3(goal.x, world.stage_data.goal_height + 0.03, goal.y)
	for tick in range(60):
		await physics_frame
		if world.completed: break
	await frames()
	check(world.completed and world.player.input_locked, "real final goal completes and locks player")
	check(guide.state == "departing" and not world.transition.active, "butterfly leaves before pickup")
	check(not is_instance_valid(world.ending), "ending waits for butterfly")
	guide._process(2.6)
	await frames(4)
	check(world.transition.active, "hand starts after butterfly exits")
	world.transition._process(0.36)
	world.transition._process(1.16)
	world.transition._process(0.71)
	check(world.transition.phase == "ascend", "hand grasps before ascent")
	check(not is_instance_valid(world.ending), "ending waits for ascent")
	world.transition._process(1.21)
	await frames(5)
	var ending: GridEndingComic = world.ending
	for tick in range(40):
		if ending.narration_ready: break
		await process_frame
	check(ending.narration_ready, "narration layout finishes")
	check(is_instance_valid(ending) and not world.transition.active, "final ascent opens ending scene")
	check(not world.hud.visible and not world.stage_intro.panel.visible, "game HUD and title hidden")
	check(world.stage_root.process_mode == Node.PROCESS_MODE_DISABLED, "gameplay frozen behind ending")
	ending.set_process(false)
	for panel in ending.panels: panel.set_process(false)
	check(ending.revealed_count == 0 and not ending.panels[0].visible, "all three panels initially hidden")
	check(ending.prompt.visible and not ending.hint.visible, "opening-style prompt precedes footer hint")
	check(ending.UNFOLD_SECONDS == 1.15 and ending.FRAME_SECONDS == 0.14, "opening timings reused")
	for panel in ending.panels:
		check(panel.get_script() == ending.PAPER, "uses original opening paper implementation")
		check(panel.get_node_or_null("PaperShadow") != null, "opening paper shadow present")
	check(ending.narration_labels.size() == 5, "five text narration boxes")
	for i in range(5):
		var label := ending.narration_labels[i]
		var box: Rect2 = label.get_meta("narration_box")
		check(label.text.replace("\n", " ") == ending.NARRATION[i], "exact narration sentence %d" % i)
		check(label.modulate.a == 0, "narration initially hidden")
		check(label.get_theme_font("font") == ending.NARRATION_FONT, "main branch HS-Winter-Snowflake font reused")
		check(label.get_minimum_size().y <= box.size.y, "sentence fits box %d: %s <= %s" % [i, label.get_minimum_size().y, box.size.y])
	await key(KEY_E)
	check(selection.world == world, "E blocked before all panels")
	for code in [KEY_HOME, KEY_1, KEY_ESCAPE, KEY_ENTER]: await key(code)
	check(world.stage_number == 12 and not world.paused and world.ending == ending, "game shortcuts cannot interrupt ending")
	await capture("00_waiting")
	for index in range(3):
		click()
		var panel = ending.panels[index]
		check(ending.revealed_count == index + 1 and panel.unfold_progress == 0, "click reveals next paper")
		check(not ending.prompt.visible, "first click hides central prompt")
		for j in range(3): check(ending.panels[j].visible == (j <= index), "left-to-right visibility")
		panel._process(0.57)
		var progress: float = ending.papers[index].get_shader_parameter("unfold")
		check(progress > 0 and progress < 1, "paper has intermediate unfolding state")
		for label in panel.narration_labels: check(label.modulate.a == 0, "narration waits for late unfold")
		if index == 0: await capture("01_unfolding")
		await key(KEY_E)
		check(selection.world == world, "E blocked during unfold")
		panel._process(0.58)
		ending._process(0.1)
		check(ending.papers[index].get_shader_parameter("unfold") == 1.0, "sheet finishes unfolding")
		for label in panel.narration_labels: check(label.modulate.a == 1, "narration completely revealed")
		check(ending.hint.visible == (index == 2), "footer hint waits for all papers")
		await capture("0%d_revealed" % (index + 2))
	click()
	check(ending.revealed_count == 3, "extra clicks leave completed comic intact")
	var first_panel = ending.panels[0]
	first_panel.elapsed = ending.UNFOLD_SECONDS
	first_panel._process(0.01)
	await capture("05_paper_frame_a")
	var first: float = ending.papers[0].get_shader_parameter("idle_frame")
	first_panel._process(ending.FRAME_SECONDS)
	await capture("06_paper_frame_b")
	check(first != ending.papers[0].get_shader_parameter("idle_frame"), "paper alternates second pose")
	first_panel._process(ending.FRAME_SECONDS)
	check(first == ending.papers[0].get_shader_parameter("idle_frame"), "paper returns to first pose")
	var fog_time := ending.fog_elapsed
	ending._process(0.4)
	check(ending.fog_elapsed > fog_time, "independent fog continues after unfolding")
	for dimensions in [Vector2i(960, 540), Vector2i(1600, 900), Vector2i(1280, 720)]:
		root.size = dimensions
		await frames(5)
		for index in range(3):
			check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(ending.panel_rect(index)), "comic fits resized viewport")
		check(ending.panel_rect(0).end.x < ending.panel_rect(1).position.x and ending.panel_rect(1).end.x < ending.panel_rect(2).position.x, "panels stay separate")
	await key(KEY_E)
	check(not is_instance_valid(selection.world) and selection.menu.visible, "E returns to actual main menu")
	ending = load("res://scenes/grid_stage/ending.tscn").instantiate()
	root.add_child(ending)
	ending.set_process(false)
	for panel in ending.panels: panel.set_process(false)
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	root.push_input(emulated, true)
	check(ending.revealed_count == 0, "emulated mouse does not double-advance touch")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	root.push_input(touch, true)
	root.push_input(emulated, true)
	check(ending.revealed_count == 1, "one touch reveals exactly one panel")
	click(); click()
	check(ending.revealed_count == 3 and not ending._can_finish(), "rapid clicks start independent opening animations")
	for panel in ending.panels: check(panel.unfold_progress == 0, "rapid clicks do not skip paper unfolding")
	ending.queue_free()
	await frames()
	selection.select_map(11)
	world = selection.world
	world.transition.cancel()
	world.completed = true
	world.transition.set_process(false)
	world.transition.start()
	world.transition.advance("ascend")
	world.transition._process(1.21)
	check(world.stage_number == 12 and not is_instance_valid(world.ending), "penultimate map goes to playable final stage")
	world.load_stage(3)
	world.completed = true
	world.transition.start()
	world.transition.advance("ascend")
	world.transition._process(1.21)
	check(not is_instance_valid(world.ending), "PreMap3 never opens final comic")
	selection.queue_free()
	await frames()
	if not failed: print("PASS: %d ending comic checks" % checks)
	quit(1 if failed else 0)
