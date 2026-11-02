extends Control
# Shared presentation from main's woodcutter dialogue; callers own speech timing.
const PAPER_UI = preload("res://scripts/grid_stage/stretch_speech_paper.gd")
var minimum_dimensions := Vector2(320,110)
var line:Label

func configure(font:Font,dimensions:=Vector2(320,110)) -> void:
	minimum_dimensions=dimensions
	size=dimensions;mouse_filter=Control.MOUSE_FILTER_IGNORE
	var paper:=PAPER_UI.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.modulate.a=.82;paper.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(paper)
	line=Label.new();line.add_theme_font_override("font",font)
	line.add_theme_font_size_override("font_size",19)
	line.add_theme_color_override("font_color",Color("393d31"))
	line.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	line.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	line.position=Vector2(32,10);line.size=dimensions-Vector2(64,45)
	line.autowrap_mode=TextServer.AUTOWRAP_OFF
	line.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(line)
	line.minimum_size_changed.connect(fit_to_text)
	fit_to_text()

func fit_to_text() -> void:
	PAPER_UI.fit(self,line,minimum_dimensions)
