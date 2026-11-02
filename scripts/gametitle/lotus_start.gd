extends Control
## Reuses stage_intro.gd's cropped ink wash, sweep shader and font, without the arm.
const OPENING_SCENE := "res://scenes/grid_stage/opening.tscn"
@export_range(0.4, 2.0, 0.05) var paint_seconds: float = 0.85
@export_range(-30.0, 30.0, 1.0) var text_offset_y: float = 8.0
var _wash: TextureRect
var _button: Button
var _ink: ShaderMaterial
var _hovered: bool = false
var _elapsed: float = 0.0
var _opacity: float = 0.0
var _starting: bool = false
var _next_scene = preload("res://scripts/grid_stage/scene_preparation.gd").new()

func _ready() -> void:
	add_child(_next_scene)
	_next_scene.request(OPENING_SCENE)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var source: Texture2D = preload("res://art/minhwa/title_brush/stroke.png")
	var crop := AtlasTexture.new()
	crop.atlas = source
	crop.region = Rect2(0, source.get_height() * .26, source.get_width(), source.get_height() * .46)
	_wash = TextureRect.new()
	_wash.name = "InkWash"
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wash.texture = ImageTexture.create_from_image(crop.get_image())
	_wash.size = size
	_ink = ShaderMaterial.new()
	_ink.shader = preload("res://shaders/grid_title_brush.gdshader")
	_ink.set_shader_parameter("sweep", 0.0)
	_wash.material = _ink
	add_child(_wash)
	_button = Button.new()
	_button.name = "GameStart"
	_button.text = "게임 시작"
	_button.size = size
	_button.position.y = text_offset_y
	_button.disabled = true
	_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.focus_mode = Control.FOCUS_NONE
	_button.add_theme_font_override("font", preload("res://art/fonts/HS-Winter-Snowflake.ttf"))
	_button.add_theme_font_size_override("font_size", 44)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		_button.add_theme_color_override(key, Color("f0e6cf"))
	_button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .8))
	_button.add_theme_constant_override("shadow_offset_y", 2)
	_button.modulate.a = 0.0
	add_child(_button)
	_button.pressed.connect(_on_start_pressed)
	get_node("../Lotus").hover_changed.connect(_on_hover_changed)
	modulate.a = 0.0
	hide()

func _on_start_pressed() -> void:
	if _starting: return
	BgmPlayer.play_ui_click()
	_starting = true
	_button.disabled = true
	_open_cutscene.call_deferred()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_E or event.keycode == KEY_E):
		BgmPlayer.play_ui_click()

func _open_cutscene() -> void:
	var packed: PackedScene = await _next_scene.fetch()
	if packed == null:
		_starting = false
		push_error("Could not load starting cutscene")
		return
	var error := get_tree().change_scene_to_packed(packed)
	if error != OK:
		_starting = false
		push_error("Could not open starting cutscene: %s" % error_string(error))

func _on_hover_changed(hovering: bool) -> void:
	_hovered = hovering
	if hovering: show()
	else:
		_button.disabled = true
		_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not visible: return
	_opacity = move_toward(_opacity, 1.0 if _hovered else 0.0, delta / .16)
	modulate.a = _opacity
	if _hovered: _elapsed += delta
	if _opacity <= 0.0:
		_elapsed = 0.0
		_ink.set_shader_parameter("sweep", 0.0)
		_button.modulate.a = 0.0
		hide()
		return
	var progress := _elapsed / maxf(paint_seconds, .4)
	var sweep := smoothstep(.15, 1.0, progress)
	_ink.set_shader_parameter("sweep", sweep * 1.03)
	var reveal := smoothstep(.95, 1.2, progress)
	_button.modulate.a = reveal
	_button.disabled = _starting or not _hovered or reveal < .99
	_button.mouse_filter = Control.MOUSE_FILTER_IGNORE if _button.disabled else Control.MOUSE_FILTER_STOP
