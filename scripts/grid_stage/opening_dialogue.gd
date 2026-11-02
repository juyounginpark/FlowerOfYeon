extends RefCounted
## Six actual, editable Label nodes over the empty narration boxes.

const BOXES := [
	{"panel": 0, "rect": Rect2(55, 62, 365, 112), "max_font": 30,
		"text": "옛날 옛적, 게으른 이무기가 살았습니다."},
	{"panel": 0, "rect": Rect2(148, 782, 277, 82), "max_font": 25,
		"text": "이무기는 매일 수행을 빼먹고 놀러다니기 바빴습니다."},
	{"panel": 1, "rect": Rect2(510, 59, 310, 120), "max_font": 25,
		"text": "어느 날 이무기가 옥황상제를 찾아가 왜 자신은 용이 될 수 없냐 물었습니다."},
	{"panel": 1, "rect": Rect2(783, 354, 243, 100), "max_font": 23,
		"text": "옥황상제는 그것은 네 스스로 깨달아야 한다고 말했습니다."},
	{"panel": 2, "rect": Rect2(510, 594, 243, 84), "max_font": 25,
		"text": "그러자 이무기는 성을 내며 떼를 썼습니다."},
	{"panel": 3, "rect": Rect2(1252, 770, 373, 113), "max_font": 22,
		"text": "옥황상제는 긴 한숨을 내쉬며 말했습니다. \"속세에 내려가 깨달음을 얻고 오거라.\" 이무기는 인간이 되어 지상에 떨어졌습니다."},
]

static func install(panels: Array[Node]) -> Array[Label]:
	var font := preload("res://scripts/grid_stage/main_ui_style.gd").font()
	var labels: Array[Label] = []
	for index in range(BOXES.size()):
		var box: Dictionary = BOXES[index]
		var label := Label.new()
		label.name = "Narration%d" % (index + 1)
		label.set_meta("narration", box.text)
		label.position = box.rect.position
		label.size = box.rect.size
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.add_theme_font_override("font", font)
		label.add_theme_color_override("font_color", Color("29251f"))
		label.add_theme_constant_override("line_spacing", 2)
		panels[box.panel].add_child(label)
		for font_size in range(box.max_font, 13, -1):
			label.add_theme_font_size_override("font_size", font_size)
			label.text = _wrap_words(box.text, font, font_size, box.rect.size.x)
			label.size = box.rect.size
			var lines := label.get_line_count()
			var height := lines * label.get_line_height() + maxi(0, lines - 1) * 2
			if height <= box.rect.size.y:
				break
		label.modulate.a = 0.0
		panels[box.panel].narration_labels.append(label)
		labels.append(label)
	return labels

static func _wrap_words(text: String, font: Font, font_size: int, width: float) -> String:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var candidate := word if line.is_empty() else line + " " + word
		if not line.is_empty() and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			lines.append(line)
			line = word
		else:
			line = candidate
	if not line.is_empty():
		lines.append(line)
	return "\n".join(lines)
