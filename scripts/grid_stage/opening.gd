extends Control
## Reveal the four panels cumulatively, then continue to map selection.
## Both touch and mouse are handled here so an emulated mouse event cannot
## advance a second panel after the same physical tap.

const PAGE_SIZE := Vector2(1672, 941)
const NEXT_SCENE := "res://scenes/grid_stage/menu.tscn"
const FOOTER_HEIGHT := 48.0
const FOG_MAX_OPACITY := 0.14

@onready var page: Node2D = $Page
@onready var prompt: Label = $Prompt
@onready var panels: Array[Node] = $Page.get_children()
@onready var continue_hint: Label = $ContinueHint
@onready var fog_layer: ColorRect = $FloatingFog
@onready var fog_material: ShaderMaterial = $FloatingFog.material

var revealed_count := 0
var finishing := false
var narration_ready := false
var narration_labels: Array[Label] = []
var fog_elapsed := 0.0
var fog_playing := true
var next_scene = preload("res://scripts/grid_stage/scene_preparation.gd").new()

func _ready() -> void:
	BgmPlayer.play_title()
	add_child(next_scene)
	next_scene.request(NEXT_SCENE)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	preload("res://scripts/grid_stage/main_ui_style.gd").configure_continue_hint(continue_hint)
	prompt.add_theme_font_override("font", preload("res://scripts/grid_stage/main_ui_style.gd").font())
	resized.connect(_layout)
	_layout()
	narration_labels = preload("res://scripts/grid_stage/opening_dialogue.gd").install(panels)
	narration_ready = true
	var safe_areas := PackedVector4Array()
	for box in preload("res://scripts/grid_stage/opening_dialogue.gd").BOXES:
		var safe: Rect2 = box.rect.grow(14.0)
		safe_areas.append(Vector4(safe.position.x, safe.position.y, safe.size.x, safe.size.y))
	fog_material.set_shader_parameter("narration_boxes", safe_areas)
	fog_material.set_shader_parameter("max_opacity", FOG_MAX_OPACITY)
	fog_material.set_shader_parameter("footer_height", FOOTER_HEIGHT)
	_advance()
	_update_fog()

func _layout() -> void:
	var available := Vector2(size.x, maxf(1.0, size.y - FOOTER_HEIGHT))
	var fit := minf(available.x / PAGE_SIZE.x, available.y / PAGE_SIZE.y)
	page.scale = Vector2.ONE * fit
	page.position = (available - PAGE_SIZE * fit) * 0.5
	continue_hint.size = Vector2(minf(maxf(1.0, size.x - 24.0), maxf(230.0, continue_hint.get_minimum_size().x)), 38.0)
	continue_hint.position = Vector2((size.x - continue_hint.size.x) * 0.5, size.y - FOOTER_HEIGHT + 5.0)
	fog_material.set_shader_parameter("viewport_size", size)
	fog_material.set_shader_parameter("page_origin", page.position)
	fog_material.set_shader_parameter("page_scale", fit)
	var prompt_size := prompt.get_theme_font("font").get_string_size(prompt.text, HORIZONTAL_ALIGNMENT_LEFT, -1, prompt.get_theme_font_size("font_size")) + Vector2(32, 24)
	var prompt_origin := (size - prompt_size) * 0.5
	fog_material.set_shader_parameter("prompt_box", Vector4(prompt_origin.x, prompt_origin.y, prompt_size.x, prompt_size.y))

func _process(delta: float) -> void:
	if fog_playing:
		fog_elapsed += delta
	_update_fog()
	continue_hint.visible = _can_finish()

func _update_fog() -> void:
	var visibility := PackedFloat32Array()
	for panel in panels:
		visibility.append(smoothstep(0.45, 0.72, panel.unfold_progress) if panel.visible else 0.0)
	var captions := PackedFloat32Array()
	for box in preload("res://scripts/grid_stage/opening_dialogue.gd").BOXES:
		captions.append(visibility[box.panel])
	fog_material.set_shader_parameter("fog_time", fog_elapsed)
	fog_material.set_shader_parameter("panel_visibility", visibility)
	fog_material.set_shader_parameter("narration_visibility", captions)
	fog_material.set_shader_parameter("prompt_visible", 1.0 if prompt.visible else 0.0)

func _can_finish() -> bool:
	if revealed_count < panels.size():
		return false
	for panel in panels:
		if panel.unfold_progress < 1.0:
			return false
	return true

func _input(event: InputEvent) -> void:
	if finishing:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_E or event.keycode == KEY_E):
		BgmPlayer.play_ui_click()
		get_viewport().set_input_as_handled()
		if _can_finish():
			finishing = true
			_finish.call_deferred()
		return
	var activate := false
	if event is InputEventScreenTouch:
		activate = event.pressed and event.index == 0
	elif event is InputEventMouseButton:
		activate = (event.pressed and event.button_index == MOUSE_BUTTON_LEFT
			and event.device != InputEvent.DEVICE_ID_EMULATION)
	if activate:
		get_viewport().set_input_as_handled()
		_advance()

func _advance() -> void:
	if finishing:
		return
	if revealed_count < panels.size():
		panels[revealed_count].reveal()
		BgmPlayer.play_drop()
		revealed_count += 1
		prompt.hide()
		return
	# Further clicks/taps leave the completed comic on screen. E exits.

func _finish() -> void:
	continue_hint.text = "이야기를 펼치는 중…"
	var packed: PackedScene = await next_scene.fetch()
	if packed == null:
		finishing = false
		push_error("Could not load map selection")
		return
	get_tree().set_meta("lobby_after_opening", true)
	var error := get_tree().change_scene_to_packed(packed)
	if error != OK:
		get_tree().remove_meta("lobby_after_opening")
		finishing = false
		push_error("Could not open map selection: %s" % error_string(error))
