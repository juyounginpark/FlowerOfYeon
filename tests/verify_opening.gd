extends SceneTree

const OPENING := "res://scenes/grid_stage/opening.tscn"
const CAPTURES := "res://output/opening_verification/"
var checks := 0

func _initialize() -> void:
	call_deferred("run")
	create_timer(30).timeout.connect(func(): push_error("Opening verification timed out"); quit(1))

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("FAIL: " + message)
		quit(1)
		assert(condition, message)

func frames(count := 3) -> void:
	for frame in range(count):
		await process_frame

func mouse(pressed: bool, at: Vector2, button := MOUSE_BUTTON_LEFT, device := 0) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = at
	event.global_position = at
	event.device = device
	root.push_input(event, true)

func touch(pressed: bool, index := 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = Vector2(20, 20)
	root.push_input(event, true)

func key(code: Key, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	event.echo = echo
	root.push_input(event, true)
	event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	root.push_input(event, true)

func check_panels(opening: Control, count: int) -> void:
	check(opening.revealed_count == count, "one press reveals one panel (%d)" % count)
	for index in range(4):
		check(opening.panels[index].visible == (index < count), "cumulative reading order at panel %d" % index)

func capture(caption: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(CAPTURES + caption + ".png"))
	check(result == OK, "save preview " + caption)

func settle(paper: MeshInstance2D) -> void:
	paper._process(paper.unfold_duration)
	check(is_equal_approx(paper.unfold_progress, 1.0), "paper finishes unfolding")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURES))
	root.size = Vector2i(1280, 720)
	check(ProjectSettings.get_setting("application/run/main_scene") == OPENING, "opening is the game's first scene")
	check(change_scene_to_file(OPENING) == OK, "load opening")
	await frames()
	var opening: Control = current_scene
	if DisplayServer.get_name() != "headless":
		for frame in range(30):
			if opening.narration_ready:
				break
			await process_frame
		check(opening.narration_ready, "six native narration labels are ready")
	check(opening.narration_labels.size() == 6, "every narration box has editable text")
	var main_font: Font = preload("res://scripts/grid_stage/traditional_font.gd").create()
	print("Opening / main title font: ", main_font.get_font_name())
	check(opening.continue_hint.get_theme_font("font") == main_font, "E prompt shares main's stage-title font resource")
	check(opening.prompt.get_theme_font("font") == main_font, "start prompt shares main's font resource")
	check(opening.continue_hint.get_theme_font_size("font_size") == 22, "E prompt uses main's 22px HUD size")
	check(opening.continue_hint.get_theme_color("font_color") == Color("f3e7ce"), "E prompt uses main's cream HUD color")
	for label in opening.narration_labels:
		check(label.get_theme_font("font") == main_font, "narration shares main's stage-title font resource")
		check(label.text.replace("\n", " ") == str(label.get_meta("narration")), "word wrapping preserves all supplied narration and spacing")
		var font_size: int = label.get_theme_font_size("font_size")
		for line in label.text.split("\n"):
			check(label.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= label.size.x, "each complete-word line fits the box width")
		var lines: int = label.get_line_count()
		var text_height: int = lines * label.get_line_height() + maxi(0, lines - 1) * 2
		check(text_height <= label.size.y, "all shaped narration lines fit inside their box")
		check(label.get_visible_line_count() == lines, "no narration lines are clipped")
	key(KEY_E)
	check(not opening.finishing and opening.revealed_count == 0, "early E cannot exit or reveal a panel")
	check_panels(opening, 0)
	check(opening.prompt.visible, "initial prompt is visible")
	for paper in opening.panels:
		check(is_zero_approx(paper.elapsed), "hidden paper waits for its own press")
		check(paper.mesh.surface_get_array_len(0) > 100, "paper has interior vertices for creases")
	check(opening.fog_layer.visible and opening.fog_elapsed > 0.0, "scene-wide fog runs before the first click")
	check(opening.fog_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "fog never intercepts clicks")
	opening.fog_playing = false
	await capture("00_start")
	var initial_fog: Image
	if DisplayServer.get_name() != "headless":
		initial_fog = root.get_texture().get_image()
	opening.fog_elapsed += 7.0
	opening._update_fog()
	await capture("00_fog_drift")
	if initial_fog != null:
		check(initial_fog.get_data() != root.get_texture().get_image().get_data(), "fog drifts even while every paper is hidden")
	var scene_clock: float = opening.fog_elapsed

	mouse(true, Vector2(10, 10), MOUSE_BUTTON_RIGHT)
	mouse(false, Vector2(10, 10), MOUSE_BUTTON_RIGHT)
	check_panels(opening, 0)
	mouse(true, Vector2(1, 1))
	mouse(false, Vector2(1, 1))
	check(opening.fog_elapsed == scene_clock, "revealing a cut does not reset the scene fog")
	check_panels(opening, 1)
	check(not opening.prompt.visible, "prompt clears on first reveal")
	var first_paper: MeshInstance2D = opening.panels[0]
	first_paper.set_process(false)
	first_paper._process(0.10)
	check(first_paper.unfold_progress > 0.0 and first_paper.unfold_progress < 1.0, "first press starts paper unfolding")
	await capture("unfold_01_crumpled")
	first_paper._process(0.24)
	await capture("unfold_02_opening")
	first_paper._process(0.32)
	await capture("unfold_03_relaxing")
	settle(first_paper)
	await capture("unfold_04_flat")
	first_paper.elapsed = first_paper.unfold_duration
	first_paper._process(0.01)
	check(first_paper.idle_frame == 0, "idle starts on drawing A")
	await capture("idle_A")
	var image_a: Image
	if DisplayServer.get_name() != "headless":
		image_a = root.get_texture().get_image()
	first_paper._process(0.06)
	check(first_paper.idle_frame == 0, "each drawing is held without interpolation")
	first_paper._process(0.08)
	check(first_paper.idle_frame == 1, "idle switches to drawing B")
	await capture("idle_B")
	if image_a != null:
		check(image_a.get_data() != root.get_texture().get_image().get_data(), "two idle drawings visibly differ")
	first_paper._process(first_paper.IDLE_FRAME_SECONDS)
	check(first_paper.idle_frame == 0, "idle repeats A after B")
	await capture("idle_A_repeat")
	if image_a != null:
		check(image_a.get_data() == root.get_texture().get_image().get_data(), "A-B-A repeats the exact same rendered drawing")
	check(is_equal_approx(first_paper.unfold_progress, 1.0), "two-frame crumple does not restart the entrance")
	check(opening.fog_material.get_shader_parameter("max_opacity") <= 0.15, "smoky fog is capped at a transparent opacity")
	opening.fog_elapsed += 7.0
	opening._update_fog()
	await capture("mist_drift")
	if image_a != null:
		var mist_image := root.get_texture().get_image()
		check(image_a.get_data() != mist_image.get_data(), "mist floats independently of the two paper frames")
		for label in first_paper.narration_labels:
			var region := Rect2i(label.get_global_rect().grow(-2.0))
			check(image_a.get_region(region).get_data() == mist_image.get_region(region).get_data(), "moving mist never changes the narration box or text")
		var face := Rect2i(Rect2(opening.page.to_global(Vector2(320, 550)), Vector2(35, 25) * opening.page.scale).grow(-1.0))
		check(image_a.get_region(face).get_data() == mist_image.get_region(face).get_data(), "mist leaves the snake's face clear")
	opening.fog_playing = true
	first_paper.set_process(true)
	await capture("01_left")

	touch(true)
	mouse(true, Vector2(20, 20), MOUSE_BUTTON_LEFT, InputEvent.DEVICE_ID_EMULATION)
	mouse(false, Vector2(20, 20), MOUSE_BUTTON_LEFT, InputEvent.DEVICE_ID_EMULATION)
	touch(false)
	check_panels(opening, 2)
	check(opening.panels[1].unfold_progress < 1.0, "second panel unfolds independently")
	check(opening.panels[0].unfold_progress == 1.0, "second reveal leaves earlier paper open")
	touch(true, 1)
	touch(false, 1)
	check_panels(opening, 2)
	settle(opening.panels[1])
	await capture("02_middle_top")

	mouse(true, Vector2(1279, 719))
	mouse(false, Vector2(1279, 719))
	check_panels(opening, 3)
	settle(opening.panels[2])
	await capture("03_middle_bottom")
	touch(true)
	touch(false)
	check_panels(opening, 4)
	key(KEY_E)
	check(not opening.finishing, "E waits until the last paper has finished unfolding")
	settle(opening.panels[3])
	await frames()
	check(current_scene == opening, "fourth press keeps the completed page visible")
	check(opening.continue_hint.visible, "E hint appears after all paper is open")
	await capture("04_complete")

	for dimensions in [Vector2i(960, 540), Vector2i(1600, 900), Vector2i(720, 1280), Vector2i(1280, 720)]:
		root.size = dimensions
		await frames()
		var page_rect := Rect2(opening.page.position, opening.PAGE_SIZE * opening.page.scale)
		check(page_rect.position.x >= -0.01 and page_rect.position.y >= -0.01, "page starts within resized window")
		check(page_rect.end.x <= opening.size.x + 0.01 and page_rect.end.y <= opening.size.y + 0.01, "whole page fits resized window")
		check(is_equal_approx(opening.page.scale.x, opening.page.scale.y), "resize preserves illustration proportions")
		check(Rect2(Vector2.ZERO, opening.size).encloses(opening.continue_hint.get_rect()), "E prompt stays inside the window")
		check(not page_rect.intersects(opening.continue_hint.get_rect()), "E prompt never covers the painting")
		check(opening.fog_layer.size == opening.size, "fog covers the whole scene after resizing")
		check_panels(opening, 4)
		await capture("resize_%dx%d" % [dimensions.x, dimensions.y])

	# The completed page remains until a fresh E key press, including after
	# extra mouse/touch input or a key-repeat event from a held E.
	mouse(true, Vector2(488, 682))
	mouse(false, Vector2(488, 682))
	touch(true)
	touch(false)
	key(KEY_SPACE)
	key(KEY_E, true)
	await frames()
	check(current_scene == opening and not opening.finishing, "click, tap, other keys and held E do not exit")
	key(KEY_E)
	check(opening.finishing, "fresh E finishes the opening")
	await frames(6)
	check(current_scene.scene_file_path == "res://scenes/grid_stage/menu.tscn", "E opens map selection")
	check(current_scene.world == null, "exit input does not select a map")
	check(current_scene.stage_buttons.size() == 9 and current_scene.pre_buttons.size() == 3, "existing map selection remains intact")
	await capture("05_map_selection")
	print("PASS: %d opening checks (main HUD styling, text fitting, paper loop, protected floating mist, input, resize, E exit)" % checks)
	quit()
