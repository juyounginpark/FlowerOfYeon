extends Sprite2D
signal hover_changed(hovering: bool)
## Alpha-aware hover follows the animated sprite and the resized composition.
@export_range(1.0, 5.0, 0.25) var outline_width_px: float = 3.0
@export_range(0.02, 0.3, 0.01) var fade_seconds: float = 0.08
var _outline_material: ShaderMaterial
var _opacity: float = 0.0
var _hovering: bool = false

func _ready() -> void:
	_outline_material = material.duplicate() as ShaderMaterial
	material = _outline_material
	_outline_material.set_shader_parameter("hover_amount", 0.0)

func _process(delta: float) -> void:
	var local_mouse := get_local_mouse_position()
	var inside_window := get_viewport().get_visible_rect().has_point(get_viewport().get_mouse_position())
	var modal_open: bool = get_node("../../..").get_meta("credits_open", false)
	var hovering := not modal_open and inside_window and get_window().has_focus() and get_rect().has_point(local_mouse) and is_pixel_opaque(local_mouse)
	if hovering != _hovering:
		_hovering = hovering
		hover_changed.emit(hovering)
	_opacity = move_toward(_opacity, 1.0 if hovering else 0.0, delta / maxf(fade_seconds, 0.02))
	_outline_material.set_shader_parameter("hover_amount", _opacity)
	# Width is in reference composition pixels, independent of source PNG size.
	_outline_material.set_shader_parameter("width_texels", outline_width_px / maxf(absf(scale.x), 0.001))
