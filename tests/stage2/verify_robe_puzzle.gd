extends SceneTree
var world: GridStageWorld
var failed := false
var checks := 0

func _initialize() -> void:
	call_deferred("run")
	create_timer(90).timeout.connect(func(): push_error("Stage2 puzzle test timeout"); quit(1))

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

func robe_point(puzzle: Node) -> Vector2:
	var piece: Dictionary = puzzle.robe_piece
	var center := Vector2.ZERO
	for p: Vector2 in piece.polygon:
		center += p
	center /= piece.polygon.size()
	return world.camera.unproject_position(piece.visual.to_global(Vector3(center.x, -center.y, 0)))

func drive_x(pressed: bool) -> void:
	# Camera's +X world direction is back+right for this fixed isometric view.
	if pressed:
		Input.action_press("back", 0.70710678)
		Input.action_press("right", 0.70710678)
	else:
		Input.action_release("back")
		Input.action_release("right")

# Runtime regression scenarios retained for a future authorized run.
# Current project policy allows --check-only, never execution of this script.
func cut_and_settle(puzzle: Node) -> bool:
	var center: Vector2 = puzzle.original_piece.body.position
	var low := INF
	var high := -INF
	for point: Vector2 in puzzle.original_piece.polygon:
		low = minf(low, point.x)
		high = maxf(high, point.x)
	puzzle._cut(center + Vector2(low - 30, 0), center + Vector2(high + 30, 0))
	check(puzzle.state == puzzle.State.SETTLING, "cut retains falling fragments before creating robe")
	check(puzzle.pieces.size() >= 2 and puzzle.robe_piece.is_empty(), "no immediate replacement of fragments")
	for i in range(360):
		if puzzle.state == puzzle.State.ROBE_READY: return true
		await ticks(1)
	check(false, "largest physical fragment must settle and release one robe")
	return false

func wait_restart() -> void:
	for i in range(600):
		if not world.get("stage2_resetting"): return
		await frames(1)
	check(false, "incremental reset must finish")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var menu = load("res://scenes/grid_stage/menu.tscn").instantiate()
	root.add_child(menu)
	menu.stage_buttons[1].pressed.emit()
	world = menu.world
	world.transition.cancel()
	world.stage_intro.hide()
	await frames(6)
	var puzzle = world.stage_root.get_node("Stage2RobePuzzle")
	if not await cut_and_settle(puzzle):
		quit(1)
		return
	var fragment_bodies: Array = []
	for piece: Dictionary in puzzle.pieces:
		if piece != puzzle.robe_piece: fragment_bodies.append(piece.body)
	var piece_count: int = puzzle.pieces.size()
	world._respawn()
	await frames(2)
	check(puzzle.pieces.size() == piece_count, "fall recovery preserves cut state")
	var pickup := robe_point(puzzle)
	await motion(pickup)
	await mouse(pickup, true)
	check(is_instance_valid(puzzle.grabbed), "settled robe uses shared drag")
	var actor: AnimatedSprite3D = puzzle.actor
	var target: Vector3 = actor.global_position + world.camera.global_basis.y * actor.character_height * .55
	var pixel := world.camera.unproject_position(target)
	await motion(pixel, true)
	check(puzzle.surface_preview.get("host") == actor, "alpha hit selects real woodcutter")
	await mouse(pixel, false)
	check(puzzle.state == puzzle.State.ESCAPING and puzzle.robe_piece.is_empty(), "delivery starts run with robe")
	puzzle._deliver()
	check(puzzle.state == puzzle.State.ESCAPING, "duplicate delivery is ignored")
	check(puzzle.blocker.collision_layer == 0 and world.dialogue == null, "escape opens passage and disables dialogue")
	world.paused = true
	var start: Vector3 = actor.global_position
	await ticks(12)
	check(actor.global_position == start, "escape freezes during pause")
	world.paused = false
	await ticks(1800)
	check(puzzle.state == puzzle.State.OPEN and not actor.visible and puzzle.fairy.visible and is_instance_valid(puzzle.fairy_ramp), "fairy waits at former lift with head ramp")
	for body: Node in fragment_bodies: check(not is_instance_valid(body), "cut fragments fade after robe generation")
	var stage := world.stage_root
	world.restart()
	await wait_restart()
	check(world.stage_root == stage and puzzle.state == puzzle.State.UNCUT, "reset reuses stage and restores puzzle")
	check(world.transition.active and world.transition.phase == "descend", "restart begins with descending hand")
	check(puzzle.blocker.collision_layer == 1 and world.dialogue != null, "reset restores barrier and dialogue")
	menu.queue_free()
	await frames()
	print("Stage2 cut/escape regression: ", checks, " checks, failed=", failed)
	quit(1 if failed else 0)
