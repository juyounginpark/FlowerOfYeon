extends RefCounted
## Opening text shares main's stage-title font; hints retain the HUD palette.

const FONT_SIZE := 22
const FOREGROUND := Color("f3e7ce")

static func font() -> Font:
	return preload("res://scripts/grid_stage/traditional_font.gd").create()

static func configure_continue_hint(label: Label) -> void:
	label.text = "E 키를 눌러 계속"
	label.add_theme_font_override("font", font())
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", FOREGROUND)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("315c5b")
	paper.border_color = Color("c6ac73")
	paper.set_border_width_all(1)
	paper.set_corner_radius_all(6)
	paper.content_margin_left = 16
	paper.content_margin_right = 16
	paper.content_margin_top = 5
	paper.content_margin_bottom = 5
	label.add_theme_stylebox_override("normal", paper)
