extends Node3D
## World-space illustrations. Camera basis is sampled once, not followed per frame.
const ART = preload("res://scripts/stage2/art.gd")

func configure(view: Camera3D, focus: Vector3, fairy_center: Vector2,
		fairy_width: float, rock_center: Vector2, rock_width: float) -> void:
	var rear: Dictionary = ART.frames("fairy_back_v2")[0]
	var rock: Dictionary = ART.frames("robe_rock_v2")[0]
	_add_photo("BathingFairy", rear.texture, rear.painted, view, focus, fairy_center, fairy_width * 0.6 * 0.7)
	_add_photo("RobeOnRock", rock.texture, rock.painted, view, focus, rock_center, rock_width * 0.6)

func _add_photo(node_name: String, source: Texture2D, painted: Rect2,
		view: Camera3D, focus: Vector3, center_ratio: Vector2, width_ratio: float) -> void:
	var photo := Sprite3D.new()
	photo.name = node_name
	photo.texture = source
	var viewport_size := get_viewport().get_visible_rect().size
	var depth: float = view.global_position.distance_to(focus)
	var width: float = view.project_position(Vector2.ZERO, depth).distance_to(
		view.project_position(Vector2(viewport_size.x * width_ratio, 0), depth))
	photo.pixel_size = width / painted.size.x
	var correction: Vector2 = Vector2(source.get_size()) * 0.5 - painted.get_center()
	photo.offset = Vector2(correction.x, -correction.y)
	photo.centered = true
	photo.shaded = false
	photo.double_sided = true
	photo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	photo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ART.sliced_sprite(photo, source)
	photo.no_depth_test = false
	photo.set_meta("shore_painted", painted)
	if node_name == "BathingFairy": photo.add_to_group("shore_illustration")
	add_child(photo)
	# Resolve the reference composition once into a real world transform.
	# No CanvasLayer, screen-following update, or camera changes.
	photo.global_transform = Transform3D(view.global_basis,
		view.project_position(center_ratio * viewport_size, depth))
