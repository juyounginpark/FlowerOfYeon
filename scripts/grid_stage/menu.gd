extends Control
const MAPS = preload("res://scripts/grid_stage/lotus_stages.gd")
const LOGO = preload("res://art/ui/lotus_pond/logo.png")
const INK_FRAME = preload("res://art/ui/lotus_pond/stage_titles/ink-frame.png")
const INK_TITLES := [
	preload("res://art/ui/lotus_pond/stage_titles/stage-01.png"),
	preload("res://art/ui/lotus_pond/stage_titles/stage-02-v2.png"),
	preload("res://art/ui/lotus_pond/stage_titles/stage-03.png"),
	preload("res://art/ui/lotus_pond/stage_titles/stage-04-v2.png"),
	preload("res://art/ui/lotus_pond/stage_titles/stage-05-v2.png"),
	preload("res://art/ui/lotus_pond/stage_titles/stage-06-v2.png"),
	preload("res://art/ui/lotus_pond/stage_titles/stage-07.png"),
	preload("res://art/ui/lotus_pond/stage_titles/stage-08.png"),
]
# Positions transcribed from the blue annotations, relative to the lotus radius.
const CAPTION_OFFSETS := [Vector2(0, -1.95), Vector2(1.78, -1.22),
	Vector2(2.25, -0.06), Vector2(1.78, 1.28), Vector2(0, 1.99),
	Vector2(-1.80, 1.40), Vector2(-2.30, -0.02), Vector2(-1.78, -1.22), Vector2(0, 0.60)]
var world: Node3D
var map_scene = preload("res://scripts/grid_stage/scene_preparation.gd").new()
var entering_map := false
var loading_layer: CanvasLayer
var loading_label: Label
var loading_clock := 0.0
var menu: Control
var preview: Control
var stage_buttons: Array[Button] = []
var logo: TextureRect
var logo_ink_bounds := Rect2()
var available := 1
var cleared: Array[int] = []
var entry_click_locked := false
var lettering := SystemFont.new()
var ink_captions: Array[TextureRect] = []
var chapter_labels: Array[Label] = []
var ink_frames: Array[TextureRect] = []
var caption_backgrounds: Array[ColorRect] = []

func _ready() -> void:
	BgmPlayer.play_title()
	add_child(map_scene)
	map_scene.request("res://scenes/grid_stage/main.tscn")
	_install_loading_cover()
	entry_click_locked = bool(get_tree().get_meta("lobby_after_opening", false))
	get_tree().remove_meta("lobby_after_opening")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	lettering.font_names = PackedStringArray(["AppleMyungjo", "Noto Serif CJK KR", "NanumMyeongjo", "serif"])
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	menu.gui_input.connect(_pond_input)
	get_window().mouse_exited.connect(_clear_hover)
	get_window().focus_exited.connect(_clear_hover)
	preview = preload("res://scripts/grid_stage/catalog_preview.gd").new()
	menu.add_child(preview)
	logo = TextureRect.new()
	var cropped := AtlasTexture.new()
	cropped.atlas = LOGO
	var logo_image := LOGO.get_image()
	cropped.region = Rect2(logo_image.get_used_rect())
	logo_ink_bounds = _painted_bounds(logo_image)
	logo.texture = cropped
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.material = ShaderMaterial.new()
	logo.material.shader = preload("res://shaders/lotus_logo_water.gdshader")
	menu.add_child(logo)
	for number in range(1, 10):
		var name_: String = MAPS.story_title(number)
		var caption := "%d장 %s" % [number, name_] if number < 9 else ""
		var button := _button(caption, number + 3)
		button.tooltip_text = caption
		button.set_meta("caption", caption)
		if number < 9:
			_add_ink_caption(button, number)
		button.mouse_entered.connect(preview.hover_stage.bind(number))
		button.mouse_exited.connect(preview.hover_stage.bind(0))
		stage_buttons.append(button)
	resized.connect(_layout)
	_refresh_progress(false)
	_layout.call_deferred()
	if entry_click_locked:
		get_tree().create_timer(2.0, true, false, true).timeout.connect(_unlock_entry_clicks)

func _unlock_entry_clicks() -> void:
	entry_click_locked = false
	for i in range(stage_buttons.size()):
		stage_buttons[i].disabled = i >= available or i == 8

func _painted_bounds(image_: Image) -> Rect2:
	var mask := BitMap.new()
	mask.create_from_image_alpha(image_, 0.12)
	var bounds := Rect2()
	var initialized := false
	for polygon in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO, image_.get_size()), 2.0):
		for point in polygon:
			if not initialized:
				bounds = Rect2(point, Vector2.ZERO)
				initialized = true
			else:
				bounds = bounds.expand(point)
	return bounds if initialized else Rect2(image_.get_used_rect())

func logo_ink_offset() -> Vector2:
	var crop: AtlasTexture = logo.texture
	var factor := minf(logo.size.x / crop.region.size.x, logo.size.y / crop.region.size.y)
	var letterbox := (logo.size - crop.region.size * factor) * 0.5
	return letterbox + (logo_ink_bounds.position - crop.region.position) * factor

func _add_ink_caption(button: Button, number: int) -> void:
	button.text = ""
	var background := ColorRect.new()
	background.name = "TranslucentWhite"
	background.color = Color(1, 1, 1, 0.55)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption_backgrounds.append(background)
	var frame := TextureRect.new()
	frame.name = "InkFrame"
	var border := AtlasTexture.new()
	border.atlas = INK_FRAME
	border.region = Rect2(INK_FRAME.get_image().get_used_rect())
	frame.texture = border
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ink_frames.append(frame)
	var chapter := Label.new()
	chapter.name = "ChapterNumber"
	chapter.text = "%d장" % number
	chapter.add_theme_font_override("font", preload("res://art/fonts/HS-Winter-Snowflake.ttf"))
	chapter.add_theme_color_override("font_color", Color("29251e"))
	chapter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chapter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(chapter)
	chapter_labels.append(chapter)
	var image_ := TextureRect.new()
	image_.name = "InkTitle"
	var cropped := AtlasTexture.new()
	cropped.atlas = INK_TITLES[number - 1]
	cropped.region = Rect2(INK_TITLES[number - 1].get_image().get_used_rect())
	image_.texture = cropped
	image_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(image_)
	image_.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ink_captions.append(image_)

func _button(caption: String, id: int) -> Button:
	var button := Button.new()
	button.name = "Stage%d" % (id - 3)
	button.text = caption
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", lettering)
	button.add_theme_color_override("font_color", Color("324b48"))
	button.add_theme_color_override("font_hover_color", Color("6d3f4c"))
	button.add_theme_color_override("font_focus_color", Color("6d3f4c"))
	for state in ["normal", "hover", "pressed", "focus"]:
		# Transparent interaction only; the generated ink stroke is the frame.
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(select_map.bind(id))
	menu.add_child(button)
	return button

func _layout() -> void:
	if not is_instance_valid(preview):
		return
	preview.position = Vector2.ZERO
	preview.size = size
	preview._layout()
	var scale_ := clampf(size.y / 720.0, 0.75, 1.4)
	logo.size = Vector2(427.5, 607.5) * scale_
	# Match the visible ink margins, including transparent padding and letterboxing.
	var ink_offset := logo_ink_offset()
	var inset := maxf(48 * scale_, maxf(ink_offset.x, ink_offset.y) + 2 * scale_)
	logo.position = Vector2.ONE * inset - ink_offset
	logo.material.set_shader_parameter("ripple_center_px", preview.position + preview.map_center(9))
	logo.material.set_shader_parameter("surface_size", preview.size)
	var center: Vector2 = preview.map_center(9)
	var radius: float = preview.lotus_radius()
	for i in range(stage_buttons.size()):
		var button := stage_buttons[i]
		button.add_theme_font_size_override("font_size", maxi(14, int(18 * scale_)) if i < 8 else maxi(12, int(15 * scale_)))
		button.size = Vector2(202 if i < 8 else 126, 34) * scale_
		button.position = center + CAPTION_OFFSETS[i] * radius - button.size * 0.5
		if i < ink_captions.size():
			caption_backgrounds[i].offset_left = 2 * scale_
			caption_backgrounds[i].offset_right = -2 * scale_
			caption_backgrounds[i].offset_top = 2 * scale_
			caption_backgrounds[i].offset_bottom = -2 * scale_
			chapter_labels[i].position = Vector2(8, 0) * scale_
			chapter_labels[i].size = Vector2(36, 34) * scale_
			chapter_labels[i].add_theme_font_size_override("font_size", roundi(17 * scale_))
			ink_captions[i].offset_left = 44 * scale_
			ink_captions[i].offset_right = -8 * scale_
			ink_captions[i].offset_top = 5 * scale_
			ink_captions[i].offset_bottom = -5 * scale_

func select_map(number: int) -> void:
	if entering_map or entry_click_locked or is_instance_valid(world) or (number >= 4 and number - 3 > available):
		return
	BgmPlayer.play_ui_click()
	entering_map = true
	_clear_hover()
	loading_clock = 0.0
	loading_layer.show()
	# Present feedback before instantiation and split stage setup begins.
	await get_tree().process_frame
	await get_tree().process_frame
	var packed: PackedScene = await map_scene.fetch()
	if packed == null:
		loading_layer.hide()
		entering_map = false
		push_error("Could not load stage scene")
		return
	menu.hide()
	world = packed.instantiate()
	world.stage_number = clampi(number, 1, 12)
	world.book_on_entry = true
	world.incremental_entry = true
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.map_selection_requested.connect(show_selection)
	world.entry_prepared.connect(_map_prepared, CONNECT_ONE_SHOT)
	add_child(world)

func _map_prepared() -> void:
	world.process_mode = Node.PROCESS_MODE_INHERIT
	loading_layer.hide()
	entering_map = false

func _install_loading_cover() -> void:
	loading_layer = CanvasLayer.new()
	loading_layer.layer = 100
	add_child(loading_layer)
	var paper := ColorRect.new()
	paper.color = Color("eee1c7")
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_layer.add_child(paper)
	loading_label = Label.new()
	loading_label.text = "이야기를 펼치는 중…"
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", 28)
	loading_label.add_theme_color_override("font_color", Color("514736"))
	loading_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.add_child(loading_label)
	loading_layer.hide()

func _process(delta: float) -> void:
	if not entering_map: return
	loading_clock += delta
	loading_label.text = "이야기를 펼치는 중" + ".".repeat(1 + int(loading_clock * 3.0) % 3)

func show_selection() -> void:
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.show()
	_refresh_progress()
	_layout()

func _refresh_progress(animate := true) -> void:
	cleared = LotusProgress.cleared_stages()
	available = LotusProgress.available_count(cleared)
	preview.set_progress(cleared, animate)
	for i in range(stage_buttons.size()):
		stage_buttons[i].visible = i < mini(available, 8)
		stage_buttons[i].disabled = entry_click_locked or i >= available or i == 8
		stage_buttons[i].tooltip_text = String(stage_buttons[i].get_meta("caption", "")) + (" · 완료" if i < 8 and cleared.has(i + 1) else "")

func _pond_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		var number: int = preview.stage_at(event.position - preview.position)
		if event is InputEventMouseMotion:
			menu.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if number > 0 else Control.CURSOR_ARROW
			if preview.flower.hovered != number:
				preview.hover_stage(number)
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and number > 0:
			select_map(number + 3)

func _clear_hover() -> void:
	preview.hover_stage(0)
	menu.mouse_default_cursor_shape = Control.CURSOR_ARROW
