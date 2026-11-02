extends SceneTree
var checks := 0
var failed := false
var selection: Control
const SAVE := "/private/tmp/topofyean-lotus-verification.cfg"

func _initialize() -> void:
	call_deferred("run")
	create_timer(90).timeout.connect(func(): push_error("Lotus menu verification timed out"); quit(1))

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("FAIL: " + message)

func frames(count := 3) -> void:
	for i in range(count):
		await process_frame

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await frames(4)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("/private/tmp/" + filename + ".png") == OK, "capture " + filename)

func click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click, true)

func run() -> void:
	LotusProgress.storage_path = SAVE
	DirAccess.remove_absolute(SAVE)
	root.size = Vector2i(1280, 720)
	selection = load("res://scenes/grid_stage/menu.tscn").instantiate()
	root.add_child(selection)
	await frames(8)
	check(selection.available == 1 and selection.preview.flower.petal_count == 1, "fresh save has exactly one petal")
	check(selection.stage_buttons[0].visible, "stage one is selectable")
	check(selection.logo.texture != null, "generated ink logo is loaded")
	check(selection.ink_captions.size() == 8 and selection.ink_frames.size() == 8, "eight story names have brush-calligraphy frames")
	var expected_names := ["단오", "선녀와 나무꾼", "심청전", "빨간부채  파란부채", "손톱먹은 쥐", "해와 달이 된 오누이", "흥부전", "견우와 직녀", "용이 되지 못한 이무기"]
	for i in range(9):
		check(selection.MAPS.story_title(i + 1) == expected_names[i], "stage title matches requested name %d" % (i + 1))
	var frame_image: Image = selection.INK_FRAME.get_image()
	check(frame_image.get_pixelv(frame_image.get_size() / 2).a < 0.01, "ink frame has a transparent center")
	for i in range(8):
		check(selection.stage_buttons[i].text.is_empty() and selection.ink_captions[i].texture != null, "story title is an ink image instead of typeset text")
		for state in ["normal", "hover", "pressed", "focus"]:
			check(selection.stage_buttons[i].get_theme_stylebox(state) is StyleBoxEmpty, "plain rectangular UI panel is removed in every state")
	check(not selection.stage_buttons[8].visible and selection.stage_buttons[8].text.is_empty(), "Stage9 has no lobby caption")
	check(selection.preview.DEW_TEXTURES.size() == 2, "generated round and elongated dew assets replace blocks")
	check(selection.preview.surface_shadow.rotation == 0, "floating lotus shadow stays directly beneath the flower")
	var koi: Control = selection.preview.koi
	koi.set_process(false)
	check(koi.FRAME_COUNT == 8 and koi.frame_offsets.size() == 8, "koi uses eight registered generated frames")
	for frame in range(8):
		check(koi.frame_index(float(frame) / koi.FPS + 0.0001) == frame, "swimming advances through frame %d" % frame)
	check(koi.frame_index(8.0 / koi.FPS) == 0, "eighth frame loops back to first")
	koi.rng.seed = 142
	koi.advance(4.1)
	check(koi.visitors.size() == 1 and koi.MAX_FISH == 3, "koi population is reduced to roughly one third")
	for visitor in koi.visitors:
		check(visitor.length >= 260 and visitor.length <= 350, "koi are enlarged to 260–350 pixels")
	check(koi.next_visit >= 3.0 and koi.next_visit <= 5.0, "next group follows after only three to five seconds")
	var swimmer: Dictionary = koi.visitors[0]
	var start: Vector2 = koi.swim_position(swimmer, swimmer.age / swimmer.duration)
	koi.advance(2.0)
	check(start.distance_to(koi.swim_position(swimmer, swimmer.age / swimmer.duration)) > 1.0, "fish swims across the pond")
	var previous_visits: int = koi.visit_count
	koi.advance(5.1)
	check(koi.visit_count > previous_visits, "new fish enter while the previous group is still swimming")
	for tick in range(60):
		koi.advance(1.0)
		check(koi.visitors.size() <= 3, "pond keeps at most three koi")
		for fish in koi.visitors:
			var direction: Vector2 = (fish.to - fish.from) * koi.size
			check(absf(direction.y / direction.x) > 0.4, "each fish follows a diagonal route")
	var wait_time: float = koi.next_visit
	selection.menu.hide()
	koi._process(2.0)
	check(is_equal_approx(koi.next_visit, wait_time), "hidden selection freezes the fish schedule")
	selection.menu.show()
	var texture_paths: Array[String] = []
	for texture in selection.preview.PAINTING.TEXTURES:
		check(not texture_paths.has(texture.resource_path), "each stage has a separately generated image")
		texture_paths.append(texture.resource_path)
		check(texture.get_image().detect_alpha() != Image.ALPHA_NONE, "generated asset preserves transparency")
	for i in range(1, 9):
		check(not selection.stage_buttons[i].visible and selection.stage_buttons[i].disabled, "future stage is hidden and disabled")
	selection.select_map(5)
	check(selection.world == null, "future stage cannot be entered directly")
	await capture("lotus-menu-initial")
	check(LotusProgress.record_clear(1) == OK and LotusProgress.cleared_stages().is_empty(), "practice maps do not unlock petals")
	check(LotusProgress.available_count([1, 2, 3, 4, 5, 7]) == 8, "missing older clear does not hide later cleared maps")
	check(LotusProgress.available_count([1, 2, 3, 4, 5, 7, 8]) == 9, "boss remains accessible after stage eight despite an older save gap")
	for stage in range(1, 10):
		check(LotusProgress.record_clear(stage + 3) == OK, "save stage %d" % stage)
		selection._refresh_progress()
		check(selection.available == mini(stage + 1, 9), "one new petal after stage %d" % stage)
		check(selection.preview.flower.petal_count == selection.available, "painting follows unlocks")
		check(LotusProgress.cleared_stages().size() == stage, "completion persists on disk")
		check(LotusProgress.record_clear(stage + 3) == OK and LotusProgress.cleared_stages().size() == stage, "replay is idempotent")
		if stage == 7:
			check(selection.available == 8 and not selection.stage_buttons[8].visible, "eight outer petals precede the heart")
		if stage == 8:
			check(selection.available == 9 and not selection.stage_buttons[8].visible, "the heart unlocks without adding a lobby nameplate")
		if stage == 3:
			selection.preview.bloom_time = 1.0
			selection.preview.flower.bloom = 1.0
			selection.preview.flower.queue_redraw()
			await capture("lotus-menu-growing")
	selection.preview.bloom_time = 1.0
	selection.preview.flower.bloom = 1.0
	selection.preview.flower.queue_redraw()
	# One diagonal visitor represents one third of the previous three-fish capture.
	koi.visitors.clear()
	koi.visitors.append({"age": 5.0, "duration": 15.0, "from": Vector2(-0.10, 1.25), "to": Vector2(0.80, -0.25), "bend": 0.0, "length": 320.0, "phase": 0.0})
	for frame in range(8):
		koi.visitors[0].phase = float(frame) / koi.FPS + 0.0001 - 5.0
		koi.queue_redraw()
		await capture("lotus-koi-frame-%02d" % frame)
	koi.visitors[0].phase = 0.0
	koi.queue_redraw()
	for dimensions in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1600, 900)]:
		root.size = dimensions
		await frames(6)
		var original_center: Vector2 = selection.preview.size * Vector2(0.5, 0.53)
		check(selection.preview.map_center(9).distance_to(original_center) < 0.01, "Stage9 remains exactly at the original center")
		var preview: Control = selection.preview
		var ripple_origin: Vector2 = preview.pond.material.get_shader_parameter("origin") * preview.size
		check(ripple_origin.distance_to(original_center) < 0.01, "circular ripples originate at the lotus center")
		check(preview.surface_shadow.size.is_equal_approx(preview.flower_rect.size), "lotus shadow is not a mirrored reflection")
		check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(selection.logo.get_global_rect()), "ink logo stays in the upper-left of the window")
		for i in range(9):
			var button: Button = selection.stage_buttons[i]
			var radius: float = selection.preview.lotus_radius()
			var original_position: Vector2 = original_center if i == 8 else original_center + Vector2.from_angle(-PI * 0.5 + i * TAU / 8.0) * radius
			check(selection.preview.map_center(i + 1).distance_to(original_position) < 0.01, "original radial placement and angle are preserved")
			check(selection.preview.stage_at(selection.preview.map_center(i + 1)) == i + 1, "petal hit area agrees with its stage number")
			check(selection.preview.map_is_contained(i + 1), "Stage%d dew footprints stay inside their own painted image" % (i + 1))
			check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(button.get_global_rect()), "caption stays inside window")
			var expected_caption: Vector2 = original_center + selection.CAPTION_OFFSETS[i] * radius
			check(button.position.distance_to(expected_caption - button.size * 0.5) < 0.01, "caption follows annotated placement")
			if i < 8:
				check(preview.stage_at(button.position + button.size * 0.5) == 0, "story name is outside the painted petals")
			for j in range(i):
				check(not button.get_global_rect().intersects(selection.stage_buttons[j].get_global_rect()), "petal buttons remain separate")
		check(selection.preview.size.is_equal_approx(selection.size), "pond fills the menu without a practice footer")
		await capture("lotus-menu-full-%dx%d" % [dimensions.x, dimensions.y])
	# Recreate the scene to verify restoration rather than retaining in-memory state.
	selection.queue_free()
	await frames()
	selection = load("res://scenes/grid_stage/menu.tscn").instantiate()
	root.add_child(selection)
	await frames()
	check(selection.available == 9 and selection.cleared.size() == 9, "new menu restores all saved progress")
	check(not selection.stage_buttons[8].visible and selection.stage_buttons[8].tooltip_text.is_empty(), "Stage9 name stays absent after reload")
	click_at(selection.preview.position + selection.preview.map_center(9))
	await frames(5)
	check(selection.world != null and selection.world.stage_number == 12, "unlabeled central stage remains selectable")
	check(selection.world.stage_data.story_title == "용이 되지 못한 이무기", "Stage9 uses the new title inside the game")
	selection.show_selection()
	await frames()
	DirAccess.remove_absolute(SAVE)
	selection._refresh_progress(false)
	# Click inside the painted petal, away from the original outer caption button.
	var point: Vector2 = selection.preview.position + selection.preview.map_center(1) + Vector2(0, -38)
	click_at(point)
	await frames(5)
	check(selection.world != null and selection.world.stage_number == 4, "clicking petal surface opens runtime map four")
	if selection.world != null:
		var world: GridStageWorld = selection.world
		world.transition.cancel()
		var goal: Vector2 = world.stage_data.goal_rect.get_center()
		world.player.position = Vector3(goal.x, world.stage_data.goal_height + 0.03, goal.y)
		for tick in range(45):
			await physics_frame
			if world.completed:
				break
		check(world.completed, "real goal collision completes stage")
		check(LotusProgress.cleared_stages() == [1], "goal saves completion before transition")
	selection.show_selection()
	await frames()
	check(selection.world == null and selection.menu.visible, "Back restores flower selection")
	check(selection.available == 2 and selection.preview.flower.previous_count == 1, "returning blooms only the new second petal")
	selection.queue_free()
	DirAccess.remove_absolute(SAVE)
	print("%s: %d lotus menu checks" % ["FAIL" if failed else "PASS", checks])
	quit(1 if failed else 0)
