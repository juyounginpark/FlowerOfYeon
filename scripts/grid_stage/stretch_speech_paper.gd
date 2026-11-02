extends Control
## Preserve the painted ends and central tail; extend only the paper between them.
const PAPER = preload("res://art/minhwa/woodcutter_dialogue/bubble.png")
var tail_ratio := 0.5

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)

func _draw() -> void:
	var source_size := PAPER.get_size()
	var scale_y := size.y / source_size.y
	var cuts: Array[float] = [0.0, 480.0, 900.0, 1240.0, 1600.0, source_size.x]
	var left := cuts[1] * scale_y
	var middle := (cuts[3] - cuts[2]) * scale_y
	var right := (cuts[5] - cuts[4]) * scale_y
	var center_left := (size.x - middle) * .5
	if not is_equal_approx(tail_ratio, .5):
		center_left = clampf(size.x * tail_ratio - middle * .5, left, size.x - right - middle)
	var edges := [0.0, left, center_left, center_left + middle, size.x - right, size.x]
	for i in range(5):
		draw_texture_rect_region(PAPER,
			Rect2(edges[i], 0, edges[i + 1] - edges[i], size.y),
			Rect2(cuts[i], 0, cuts[i + 1] - cuts[i], source_size.y))

static func fit(panel: Control, label: Label, minimum: Vector2) -> void:
	# Label's minimum size measures explicit newlines with wrapping disabled.
	var text_size := label.get_minimum_size().ceil()
	var height := maxf(minimum.y, text_size.y + 45.0)
	# Leave space for the three fixed illustrated pieces even with larger fonts.
	panel.size = Vector2(maxf(maxf(minimum.x, text_size.x + 64.0), height * 2.9), height)
	label.position = Vector2(32, 10)
	label.size = panel.size - Vector2(64, 45)
