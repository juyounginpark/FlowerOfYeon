extends SceneTree
var world: GridStageWorld
var failed := false
var checks := 0

func _initialize() -> void:
	call_deferred("run")
	create_timer(90).timeout.connect(func(): push_error("Stage3 puzzle test timeout"); quit(1))

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error(message)

func frames(count := 2) -> void:
	for i in range(count):
		await process_frame

func ticks(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func mouse(point: Vector2, pressed: bool) -> void:
	if DisplayServer.get_name() != "headless":
		Input.warp_mouse(point)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames()

func motion(point: Vector2, held := false) -> void:
	# The display backend refreshes the pointer from the OS between frames;
	# keep the visible pointer and injected event in the same viewport position.
	if DisplayServer.get_name() != "headless":
		Input.warp_mouse(point)
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)
	await frames()

func stroke(a: Vector2, b: Vector2) -> void:
	await motion(a)
	await mouse(a, true)
	await motion(b, true)
	await mouse(b, false)
	await frames(4)

func capture(file: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/" + file + ".png")

func sun_point(puzzle: Node) -> Vector2:
	var piece: Dictionary = puzzle.sun_piece
	return world.camera.unproject_position(piece.visual.to_global(Vector3(0,100,0)))

func run() -> void:
	root.size = Vector2i(1280,720)
	var menu = load("res://scenes/grid_stage/menu.tscn").instantiate()
	root.add_child(menu)
	menu.stage_buttons[2].pressed.emit()
	world = menu.world
	check(world.stage_number == 6 and world.scene_file_path == "res://scenes/grid_stage/main.tscn", "Stage3 menu opens main")
	world.transition.cancel()
	world.stage_intro.hide()
	await frames(8)
	var puzzle = world.stage_root.get_node("Stage3SunPuzzle")
	var pose: Transform3D = puzzle.original.global_transform
	var unit: float = puzzle.original.pixel_size
	var camera_pose := world.camera.global_transform
	var count: int = puzzle.clouds.size()
	check(count > 1 and puzzle.original.visible, "initial art and clouds present")
	await capture("stage3-before")
	if "--preview-only" in OS.get_cmdline_user_args():
		menu.queue_free(); await frames(); quit(); return
	await stroke(Vector2(10,10),Vector2(20,10))
	check(puzzle.state == 0, "missed cut does not split")
	# Cross the visible sun cap, above the mountain, using shared finite stroke.
	var cut_center: Vector2 = world.camera.unproject_position(pose * Vector3((919.0-887.0)*unit,(443.5-400.0)*unit,0))
	await stroke(cut_center-Vector2(200,0),cut_center+Vector2(200,0))
	check(puzzle.state == 1, "real mouse cut separates composite")
	if puzzle.state != 1:
		quit(1); return
	check(puzzle.mountain.visible and puzzle.mountain.global_transform.is_equal_approx(pose) and is_equal_approx(puzzle.mountain.pixel_size,unit), "mountain keeps exact canvas transform and size")
	check(puzzle.pieces.size() == 1 and puzzle.sun_piece.visual.visible, "only one draggable sun")
	puzzle._cut(Vector2.ZERO,Vector2(1800,1000))
	check(puzzle.pieces.size() == 1, "duplicate cut ignored")
	await capture("stage3-split")
	var point := sun_point(puzzle)
	await motion(point)
	await mouse(point,true)
	check(is_instance_valid(puzzle.grabbed), "sun uses shared drag")
	await motion(Vector2(500,180),true)
	check(puzzle.state == 1 and puzzle.clouds.size() == count, "drag through sky does not clear clouds")
	await motion(Vector2(1450,800),true)
	await mouse(Vector2(1450,800),false)
	check(puzzle.state == 1 and not puzzle.sun_piece.sticker, "outside sky rejected without consuming sun")
	point = sun_point(puzzle)
	await motion(point)
	await mouse(point,true)
	check(is_instance_valid(puzzle.grabbed), "invalid drop can be picked again")
	await motion(Vector2(900,170),true)
	check(puzzle.state == 1, "preview does not trigger animation")
	await mouse(Vector2(900,170),false)
	check(puzzle.state == 2 and puzzle.sun_piece.sticker and puzzle.sun_piece.host == puzzle.sky_host, "sky release attaches via shared sticker")
	check(puzzle.cleared_count == 1, "one clearing sequence")
	var sun_pose: Transform3D = puzzle.sun_piece.visual.global_transform
	await frames(35)
	for entry in puzzle.clouds:
		var moved: float = (entry.node.global_position-entry.start).dot(world.camera.global_basis.x)
		check(moved*entry.direction > 0 and entry.node.modulate.a < 1, "cloud moves outward and fades")
	await capture("stage3-clearing")
	world.paused = true
	var elapsed: float = puzzle.elapsed
	await frames(8)
	check(puzzle.elapsed == elapsed, "pause freezes cloud animation")
	world.paused = false
	await frames(150)
	check(puzzle.state == 3 and puzzle.clouds.is_empty(), "all clouds removed")
	check(puzzle.sun_piece.visual.global_transform.is_equal_approx(sun_pose), "sun stays attached")
	check(world.camera.global_transform.is_equal_approx(camera_pose), "camera unchanged")
	check(puzzle.mountain.global_transform.is_equal_approx(pose), "mountain remains fixed")
	await capture("stage3-clear")
	world.restart(); world.transition.cancel(); await frames(5)
	check(not is_instance_valid(puzzle), "restart removes old puzzle")
	puzzle = world.stage_root.get_node("Stage3SunPuzzle")
	check(puzzle.state == 0 and puzzle.clouds.size() == count, "restart restores initial state")
	# Sky supports multiple distinct x positions, including over clouds.
	puzzle.state = 1
	for pixel in [Vector2(90,100),Vector2(640,210),Vector2(1180,100)]:
		await motion(pixel)
		check(not puzzle._preview_surface(puzzle.sun_piece).is_empty(), "broad sky target at %s" % pixel)
	world.load_stage(5); world.transition.cancel(); await frames(4)
	check(not is_instance_valid(puzzle) and not world.stage_root.has_node("Stage3SunPuzzle"), "Stage2 has no leftover clouds")
	check(world.stage_root.has_node("StartAndPath") and not world.rune_candidates.is_empty(), "Stage2 base map retained")
	world.load_stage(4); world.transition.cancel(); await frames(3)
	check(not world.stage_root.has_node("Stage3SunPuzzle") and not world.stage_root.has_node("Stage2RobePuzzle"), "Stage1 remains isolated")
	menu.queue_free(); await frames()
	if not failed: print("PASS: %d Stage3 sun/cloud checks" % checks)
	quit(1 if failed else 0)
