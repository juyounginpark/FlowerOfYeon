extends Control
## Title-local modal; no project input actions or global UI state are changed.
@export_multiline var credits_text: String = "":
	set(value):
		credits_text = value
		if is_instance_valid(_body): _body.text = value
const FONT = preload("res://art/fonts/HS-Winter-Snowflake.ttf")
var _link: BaseButton
var _shield: Control
var _panel: ColorRect
var _heading: Label
var _body: RichTextLabel
var _sound_settings: VBoxContainer
var _volume_slider: HSlider
var _volume_label: Label
var _mute_button: Button
var _link_fade: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_link = get_node("CreditsLink") as BaseButton
	_link.pressed.connect(_open)
	_link.mouse_entered.connect(_set_link_opacity.bind(1.0))
	_link.mouse_exited.connect(_set_link_opacity.bind(0.65))
	_link.modulate.a = 0.65
	var settings_button := Button.new()
	settings_button.name = "SoundSettings"
	settings_button.text = "설정"
	settings_button.add_theme_font_override("font", FONT)
	settings_button.add_theme_font_size_override("font_size", 26)
	settings_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	settings_button.position = Vector2(size.x - 144, 24)
	settings_button.size = Vector2(120, 52)
	settings_button.pressed.connect(_open_settings)
	add_child(settings_button)
	_shield = Control.new()
	_shield.name = "ModalInputShield"
	_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shield.gui_input.connect(_outside_input)
	add_child(_shield)
	_panel = ColorRect.new()
	_panel.name = "BlackCreditsWindow"
	_panel.color = Color.BLACK
	# Consume clicks inside the window so they cannot close it or reach the title.
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_shield.add_child(_panel)
	_heading = Label.new()
	_heading.text = "크레딧"
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.add_theme_font_override("font", FONT)
	_heading.add_theme_font_size_override("font_size", 34)
	_heading.add_theme_color_override("font_color", Color.WHITE)
	_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_heading)
	_body = RichTextLabel.new()
	_body.name = "CopyrightText"
	_body.text = credits_text
	_body.bbcode_enabled = false
	_body.scroll_active = true
	_body.add_theme_font_override("normal_font", FONT)
	_body.add_theme_font_size_override("normal_font_size", 24)
	_body.add_theme_color_override("default_color", Color.WHITE)
	_body.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_child(_body)
	_sound_settings = VBoxContainer.new()
	_sound_settings.add_theme_constant_override("separation", 24)
	_panel.add_child(_sound_settings)
	_volume_label = Label.new()
	_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_volume_label.add_theme_font_override("font", FONT)
	_volume_label.add_theme_font_size_override("font_size", 28)
	_sound_settings.add_child(_volume_label)
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0
	_volume_slider.max_value = 10
	_volume_slider.step = 1
	_volume_slider.custom_minimum_size = Vector2(0, 48)
	_volume_slider.value_changed.connect(_set_volume)
	_sound_settings.add_child(_volume_slider)
	_mute_button = Button.new()
	_mute_button.add_theme_font_override("font", FONT)
	_mute_button.add_theme_font_size_override("font_size", 26)
	_mute_button.pressed.connect(get_node("/root/GameAudio").toggle_mute)
	_sound_settings.add_child(_mute_button)
	var close_button := Button.new()
	close_button.text = "닫기"
	close_button.add_theme_font_override("font", FONT)
	close_button.add_theme_font_size_override("font_size", 26)
	close_button.pressed.connect(_close)
	_sound_settings.add_child(close_button)
	get_node("/root/GameAudio").volume_changed.connect(_refresh_volume)
	_refresh_volume(int(get_node("/root/GameAudio").level))
	_sound_settings.hide()
	_shield.hide()
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	_panel.size = Vector2(minf(760, maxf(100, size.x - 48)), minf(500, maxf(100, size.y - 48)))
	_panel.position = (size - _panel.size) * .5
	_heading.position = Vector2(24, 20)
	_heading.size = Vector2(_panel.size.x - 48, 48)
	_body.position = Vector2(32, 86)
	_body.size = Vector2(maxf(1, _panel.size.x - 64), maxf(1, _panel.size.y - 118))
	_sound_settings.position = Vector2(48, 110)
	_sound_settings.size = Vector2(maxf(1, _panel.size.x - 96), 0)

func _open() -> void:
	_heading.text = "크레딧"
	_body.show()
	_sound_settings.hide()
	get_node("/root/BgmPlayer").play_ui_click()
	_set_link_opacity(0.65)
	get_parent().set_meta("credits_open", true)
	_shield.show()
	_link.release_focus()

func _open_settings() -> void:
	_open()
	_heading.text = "사운드 설정"
	_body.hide()
	_sound_settings.show()
	_volume_slider.grab_focus()

func _set_volume(value: float) -> void:
	get_node("/root/GameAudio").set_level(int(value))

func _refresh_volume(level: int) -> void:
	_volume_slider.set_value_no_signal(level)
	_volume_label.text = "전체 음량  %d%%" % (level * 10)
	_mute_button.text = "소리 켜기" if level == 0 else "음소거"

func _set_link_opacity(opacity: float) -> void:
	if _link_fade != null and _link_fade.is_valid(): _link_fade.kill()
	_link_fade = create_tween()
	_link_fade.tween_property(_link, "modulate:a", opacity, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _close() -> void:
	get_node("/root/BgmPlayer").play_ui_click()
	_shield.hide()
	get_parent().set_meta("credits_open", false)

func _outside_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		accept_event()
		_close()

func _input(event: InputEvent) -> void:
	if is_instance_valid(_shield) and _shield.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()
