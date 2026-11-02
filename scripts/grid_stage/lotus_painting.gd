extends Control

# Match the original selector: eight clockwise petals, Stage9 in the center.
# Every image was generated independently; rotations only place them in the UI.
const CANVAS := Vector2(1200, 1200)
const CENTER := CANVAS * 0.5
const RADIUS := 342.0
const PETAL_SIZE := Vector2(0.96, 1.36) * RADIUS
const HEART_SIZE := Vector2.ONE * RADIUS * 0.92
const TEXTURES := [
	preload("res://art/ui/lotus_petals/petal-stage-01.png"),
	preload("res://art/ui/lotus_petals/petal-stage-02.png"),
	preload("res://art/ui/lotus_petals/petal-stage-03.png"),
	preload("res://art/ui/lotus_petals/petal-stage-04.png"),
	preload("res://art/ui/lotus_petals/petal-stage-05.png"),
	preload("res://art/ui/lotus_petals/petal-stage-06.png"),
	preload("res://art/ui/lotus_petals/petal-stage-07.png"),
	preload("res://art/ui/lotus_petals/petal-stage-08.png"),
	preload("res://art/ui/lotus_petals/heart-stage-09.png"),
]
var petal_count := 1
var hovered := 0
var bloom := 1.0
var previous_count := 1
var regions: Array[Rect2] = []
var masks: Array[BitMap] = []
var images: Array[Image] = []
var silhouettes: Array[BitMap] = []
var heart_core_radius := 0.0

static func stage_center(number: int) -> Vector2:
	return CENTER if number == 9 else CENTER + Vector2.from_angle(-PI * 0.5 + (number - 1) * TAU / 8.0) * RADIUS

static func stage_rotation(number: int) -> float:
	return 0.0 if number == 9 else (number - 1) * TAU / 8.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hover_ink := ShaderMaterial.new()
	hover_ink.shader = preload("res://shaders/lotus_hover.gdshader")
	material = hover_ink
	for texture in TEXTURES:
		var image_: Image = texture.get_image()
		images.append(image_)
		regions.append(Rect2(image_.get_used_rect()))
		var mask := BitMap.new()
		mask.create_from_image_alpha(image_, 0.12)
		masks.append(mask)
		silhouettes.append(_fill_internal_holes(mask) if masks.size() == 9 else mask)
	# The central stage belongs on the seed head, inside the fine stamen halo.
	for radius in range(8, int(HEART_SIZE.x * 0.5), 2):
		var safe := true
		for ray in range(128):
			if not contains_point(9, CENTER + Vector2.from_angle(ray * TAU / 128.0) * radius, 4.0, true):
				safe = false
				break
		if not safe:
			break
		heart_core_radius = maxf(4, radius - 4)

func _fill_internal_holes(mask: BitMap) -> BitMap:
	# Seed pores are transparent details inside the heart, not its outer edge.
	# Flood only the exterior; the render still keeps the original pore alpha.
	const SIDE := 256
	var filled := BitMap.new()
	filled.create(Vector2i(SIDE, SIDE))
	var exterior := PackedByteArray()
	exterior.resize(SIDE * SIDE)
	var queue := PackedInt32Array()
	for y in range(SIDE):
		for x in range(SIDE):
			var pixel := Vector2i(Vector2(x, y) / SIDE * Vector2(mask.get_size()))
			filled.set_bit(x, y, mask.get_bitv(pixel))
			if x == 0 or y == 0 or x == SIDE - 1 or y == SIDE - 1:
				if not filled.get_bit(x, y):
					var index := y * SIDE + x
					exterior[index] = 1
					queue.append(index)
	var cursor := 0
	while cursor < queue.size():
		var index := queue[cursor]
		cursor += 1
		var point := Vector2i(index % SIDE, index / SIDE)
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = point + direction
			if next.x < 0 or next.y < 0 or next.x >= SIDE or next.y >= SIDE:
				continue
			var next_index := next.y * SIDE + next.x
			if exterior[next_index] == 0 and not filled.get_bitv(next):
				exterior[next_index] = 1
				queue.append(next_index)
	for y in range(SIDE):
		for x in range(SIDE):
			filled.set_bit(x, y, exterior[y * SIDE + x] == 0)
	return filled

func growth(number: int) -> float:
	return 1.0 if number <= previous_count else smoothstep(0.0, 1.0, bloom)

func texture_uv(number: int, point: Vector2, animated := false) -> Vector2:
	var dimensions := HEART_SIZE if number == 9 else PETAL_SIZE
	if animated:
		dimensions *= lerpf(0.78, 1.0, growth(number))
	var local := (point - stage_center(number)).rotated(-stage_rotation(number))
	var uv := local / dimensions + Vector2.ONE * 0.5
	return (regions[number - 1].position + uv * regions[number - 1].size) / Vector2(TEXTURES[number - 1].get_size())

func contains_point(number: int, point: Vector2, margin := 0.0, outer_only := false) -> bool:
	var mask := silhouettes[number - 1] if outer_only else masks[number - 1]
	for offset in [Vector2.ZERO, Vector2(margin, 0), Vector2(-margin, 0), Vector2(0, margin), Vector2(0, -margin)]:
		var uv := texture_uv(number, point + offset)
		var pixel := Vector2i(uv * Vector2(mask.get_size()))
		if pixel.x < 0 or pixel.y < 0 or pixel.x >= mask.get_size().x or pixel.y >= mask.get_size().y:
			return false
		if not mask.get_bitv(pixel):
			return false
	return true

func color_at(number: int, point: Vector2) -> Color:
	var image_ := images[number - 1]
	var pixel := Vector2i(texture_uv(number, point) * Vector2(image_.get_size()))
	return image_.get_pixelv(pixel.clamp(Vector2i.ZERO, image_.get_size() - Vector2i.ONE))

func stage_at(point: Vector2) -> int:
	for number in range(petal_count, 0, -1):
		# Seed-head pores are decoration, not holes in the boss entry target.
		if contains_point(number, point, 0.0, number == 9):
			return number
	return 0

func _draw() -> void:
	if regions.size() != 9:
		return
	for number in range(1, petal_count + 1):
		var grow := growth(number)
		if grow < 0.001:
			continue
		var dimensions := (HEART_SIZE if number == 9 else PETAL_SIZE) * lerpf(0.78, 1.0, grow)
		var tint := Color(1.05, 1.03, 1.02, grow) if hovered == number else Color(1, 1, 1, grow)
		if hovered > 0 and hovered != number:
			tint = Color(0, 1, 1, grow)
		draw_set_transform(stage_center(number), stage_rotation(number))
		draw_texture_rect_region(TEXTURES[number - 1], Rect2(-dimensions * 0.5, dimensions), regions[number - 1], tint)
	draw_set_transform(Vector2.ZERO)
