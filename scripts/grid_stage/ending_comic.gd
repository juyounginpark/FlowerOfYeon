class_name GridEndingComic
extends Control
## The ending reuses firstStory's tessellated paper, timing and cumulative reveal.

signal finished

const PAPER_SIZE := Vector2(564, 940)
const PANEL_GAP := 12.0
const PAGE_SIZE := Vector2(1716, 940)
const FOOTER_HEIGHT := 48.0
const UNFOLD_SECONDS := 1.15
const FRAME_SECONDS := 0.14
const NARRATION_FONT := preload("res://art/fonts/HS-Winter-Snowflake.ttf")
const HANJI := preload("res://art/materials/hanji/paper_light.png")
const WHITE_BORDER_PIXELS := 32.0
const END_BOX := Rect2(410, 846, 116, 58)
const PAPER := preload("res://scripts/grid_stage/opening_paper.gd")
const FOG := preload("res://shaders/ending_fog.gdshader")
const ART := [
	preload("res://art/minhwa/ending/01_awakening.jpeg"),
	preload("res://art/minhwa/ending/02_dragon.jpeg"),
	preload("res://art/minhwa/ending/03_ascent.jpeg"),
]
const NARRATION := [
	"깨달음을 얻은 순간, 이무기의 몸이 두둥실 떠올랐습니다.",
	"금빛 후광이 비추고 번쩍이는 비늘과 뿔이 돋아났습니다.",
	"그토록 염원하던 용이 된 것이었습니다.",
	"게으르고 어리석어 용이 되지 못했던 이무기는 그렇게 하늘로 높이 날아갔습니다.",
	"그동안의 경험과 감동, 이야기들을 뒤로한 채 높이 높이 날아갔습니다.",
]
const BOXES := [
	[Rect2(64, 52, 264, 133), Rect2(277, 725, 244, 151)],
	[Rect2(48, 720, 244, 155)],
	[Rect2(51, 53, 213, 137), Rect2(249, 283, 266, 125)],
]

var narration_font: Font = NARRATION_FONT
var panels: Array[Node] = []
var papers: Array[ShaderMaterial] = []
var narration_labels: Array[Label] = []
var page: Node2D
var prompt: Label
var hint: Label
var end_box: Label
var fog_layer: ColorRect
var fog_material: ShaderMaterial
var revealed_count := 0
var returning := false
var narration_ready := false
var fog_elapsed := 0.0

func _ready() -> void:
	BgmPlayer.play_title()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if finished.get_connections().is_empty():
		finished.connect(_return_to_title, CONNECT_DEFERRED)
	var background := TextureRect.new()
	background.name = "HanjiBackground"
	background.texture = HANJI
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	page = Node2D.new()
	page.name = "Page"
	page.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(page)
	var sentence := 0
	var safe_areas := PackedVector4Array()
	for index in range(3):
		var panel = PAPER.new()
		panel.name = "ComicPanel%d" % (index + 1)
		panel.texture = ART[index]
		panel.page_size = PAPER_SIZE
		panel.outline = PackedVector2Array([Vector2.ZERO, Vector2(PAPER_SIZE.x, 0), PAPER_SIZE, Vector2(0, PAPER_SIZE.y)])
		panel.phase = [0.4, 2.1, 5.5][index]
		panel.unfold_duration = UNFOLD_SECONDS
		panel.white_border_pixels = WHITE_BORDER_PIXELS
		panel.paper_shadow_enabled = false
		panel.position = Vector2(index * (PAPER_SIZE.x + PANEL_GAP), 0)
		panel.hide()
		page.add_child(panel)
		panels.append(panel)
		papers.append(panel.paper_material)
		for box: Rect2 in BOXES[index]:
			var label := Label.new()
			label.name = "Narration%d" % (sentence + 1)
			label.set_meta("narration", NARRATION[sentence])
			label.set_meta("narration_box", box)
			label.position = box.position
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.clip_text = true
			label.add_theme_font_override("font", narration_font)
			label.add_theme_color_override("font_color", Color("29251f"))
			label.add_theme_constant_override("line_spacing", 2)
			panel.add_child(label)
			_fit_narration(label, NARRATION[sentence], box, 26 if index < 2 else 24)
			label.modulate.a = 0.0
			panel.narration_labels.append(label)
			narration_labels.append(label)
			sentence += 1
			var safe := Rect2(box.position + panel.position, box.size).grow(14.0)
			safe_areas.append(Vector4(safe.position.x, safe.position.y, safe.size.x, safe.size.y))
	_install_end_box()
	var end_safe := Rect2(END_BOX.position + panels[2].position, END_BOX.size).grow(14.0)
	safe_areas.append(Vector4(end_safe.position.x, end_safe.position.y, end_safe.size.x, end_safe.size.y))
	narration_ready = true
	fog_layer = ColorRect.new()
	fog_layer.name = "FloatingFog"
	fog_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog_material = ShaderMaterial.new()
	fog_material.shader = FOG
	fog_material.set_shader_parameter("narration_boxes", safe_areas)
	fog_material.set_shader_parameter("max_opacity", 0.14)
	fog_material.set_shader_parameter("footer_height", FOOTER_HEIGHT)
	fog_layer.material = fog_material
	add_child(fog_layer)
	prompt = _caption("", 24, Color(0.27, 0.25, 0.21, 1))
	prompt.hide()
	prompt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint = _caption("E 키를 눌러 타이틀로", 22, Color("f3e7ce"))
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("315c5b")
	paper.border_color = Color("c6ac73")
	paper.set_border_width_all(1)
	paper.set_corner_radius_all(6)
	paper.content_margin_left = 16
	paper.content_margin_right = 16
	paper.content_margin_top = 5
	paper.content_margin_bottom = 5
	hint.add_theme_stylebox_override("normal", paper)
	hint.hide()
	resized.connect(_layout)
	_layout()
	reveal_next()

func _install_end_box() -> void:
	# Reuse the third cut's yellow narration paper inside a clean white frame.
	var sample := AtlasTexture.new()
	sample.atlas = ART[2]
	sample.region = BOXES[2][1]
	var paper := StyleBoxTexture.new()
	paper.texture = sample
	paper.texture_margin_left = 8
	paper.texture_margin_right = 8
	paper.texture_margin_top = 8
	paper.texture_margin_bottom = 8
	end_box = Label.new()
	end_box.name = "EndBox"
	end_box.text = "end"
	end_box.position = END_BOX.position
	end_box.size = END_BOX.size
	end_box.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_box.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_box.add_theme_font_override("font", narration_font)
	end_box.add_theme_font_size_override("font_size", 28)
	end_box.add_theme_color_override("font_color", Color("29251f"))
	end_box.add_theme_stylebox_override("normal", paper)
	end_box.modulate.a = 0.0
	panels[2].add_child(end_box)
	var frame := Line2D.new()
	frame.name = "WhiteFrame"
	frame.points = PackedVector2Array([Vector2.ZERO, Vector2(END_BOX.size.x, 0), END_BOX.size, Vector2(0, END_BOX.size.y)])
	frame.closed = true
	frame.width = 5.0
	frame.default_color = Color.WHITE
	frame.antialiased = true
	end_box.add_child(frame)
	panels[2].narration_labels.append(end_box)

func _caption(text_: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", narration_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _fit_narration(label: Label, text_: String, box: Rect2, max_font: int) -> void:
	for font_size in range(max_font, 13, -1):
		label.add_theme_font_size_override("font_size", font_size)
		label.text = _wrap_words(text_, font_size, box.size.x)
		label.size = box.size
		var lines := label.get_line_count()
		var height := lines * label.get_line_height() + maxi(0, lines - 1) * 2
		if height <= box.size.y: break

func _wrap_words(text_: String, font_size: int, width: float) -> String:
	var lines := PackedStringArray()
	var line := ""
	for word in text_.split(" ", false):
		var candidate: String = word if line.is_empty() else line + " " + word
		if not line.is_empty() and narration_font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			lines.append(line)
			line = word
		else:
			line = candidate
	if not line.is_empty(): lines.append(line)
	return "\n".join(lines)

func panel_rect(index: int) -> Rect2:
	return Rect2(page.position + panels[index].position * page.scale, PAPER_SIZE * page.scale)

func _layout() -> void:
	if not is_instance_valid(hint): return
	var available := Vector2(size.x, maxf(1.0, size.y - FOOTER_HEIGHT))
	var fit := minf(available.x / PAGE_SIZE.x, available.y / PAGE_SIZE.y)
	page.scale = Vector2.ONE * fit
	page.position = (available - PAGE_SIZE * fit) * 0.5
	hint.size = Vector2(minf(maxf(1.0, size.x - 24.0), maxf(230.0, hint.get_minimum_size().x)), 38.0)
	hint.position = Vector2((size.x - hint.size.x) * 0.5, size.y - FOOTER_HEIGHT + 5.0)
	fog_material.set_shader_parameter("viewport_size", size)
	fog_material.set_shader_parameter("page_origin", page.position)
	fog_material.set_shader_parameter("page_scale", fit)
	var prompt_size := narration_font.get_string_size(prompt.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24) + Vector2(32, 24)
	var prompt_origin := (size - prompt_size) * 0.5
	fog_material.set_shader_parameter("prompt_box", Vector4(prompt_origin.x, prompt_origin.y, prompt_size.x, prompt_size.y))
	_update_fog()

func reveal_next() -> void:
	if returning or revealed_count >= panels.size(): return
	panels[revealed_count].reveal()
	BgmPlayer.play_drop()
	revealed_count += 1
	prompt.hide()
	_update_fog()

func _can_finish() -> bool:
	if revealed_count < panels.size(): return false
	for panel in panels:
		if panel.unfold_progress < 1.0: return false
	return true

func _process(delta: float) -> void:
	fog_elapsed += delta
	_update_fog()
	hint.visible = _can_finish()

func _update_fog() -> void:
	var visibility := PackedFloat32Array()
	var captions := PackedFloat32Array()
	for index in range(panels.size()):
		var panel = panels[index]
		var opacity := smoothstep(0.45, 0.72, panel.unfold_progress) if panel.visible else 0.0
		visibility.append(opacity)
		for box in BOXES[index]: captions.append(opacity)
	captions.append(visibility[2])
	fog_material.set_shader_parameter("fog_time", fog_elapsed)
	fog_material.set_shader_parameter("panel_visibility", visibility)
	fog_material.set_shader_parameter("narration_visibility", captions)
	fog_material.set_shader_parameter("prompt_visible", 1.0 if prompt.visible else 0.0)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if not returning:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_E or event.keycode == KEY_E:
				BgmPlayer.play_ui_click()
				if _can_finish():
					returning = true
					finished.emit()
		elif event is InputEventScreenTouch:
			if event.pressed and event.index == 0: reveal_next()
		elif event is InputEventMouseButton:
			if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
				reveal_next()
	get_viewport().set_input_as_handled()

func _return_to_title() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/gametitle/GameTitleAnimated.tscn")
	if error != OK:
		returning = false
		push_error("Could not return to title: %s" % error_string(error))
