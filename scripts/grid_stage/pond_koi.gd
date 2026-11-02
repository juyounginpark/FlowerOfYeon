extends Control

const SHEET = preload("res://art/ui/lotus_pond/koi_8_frames.png")
const FRAME_COUNT := 8
const COLUMNS := 4
const FPS := 7.0
const FIRST_VISIT_DELAY := 0.7
const VISIT_INTERVAL := Vector2(3.0, 5.0)
const GROUP_SIZE := Vector2i(1, 1)
const FISH_LENGTH := Vector2(260.0, 350.0)
const MAX_FISH := 3
const DIAGONAL_ROUTES := [
	[Vector2(-0.12, -0.25), Vector2(1.12, 1.25)],
	[Vector2(1.12, -0.25), Vector2(-0.12, 1.25)],
	[Vector2(-0.10, 1.25), Vector2(0.80, -0.25)],
	[Vector2(1.10, 1.25), Vector2(0.20, -0.25)],
]
var visitors: Array[Dictionary] = []
var frame_offsets: Array[Vector2] = []
var next_visit := FIRST_VISIT_DELAY
var rng := RandomNumberGenerator.new()
var visit_count := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rng.randomize()
	var image_ := SHEET.get_image()
	var cell := Vector2i(SHEET.get_size()) / Vector2i(COLUMNS, 2)
	# Register each frame at its nose, avoiding a jump between sprite-sheet rows.
	for frame in range(FRAME_COUNT):
		var region := Rect2i(Vector2i(frame % COLUMNS, frame / COLUMNS) * cell, cell)
		var anchor := Vector2(cell) * Vector2(0.93, 0.55)
		for x in range(region.end.x - 1, region.position.x + cell.x / 2, -1):
			var y_sum := 0.0
			var count := 0
			for y in range(region.position.y, region.end.y):
				if image_.get_pixel(x, y).a > 0.35:
					y_sum += y - region.position.y
					count += 1
			if count > 0:
				anchor = Vector2(x - region.position.x, y_sum / count)
				break
		frame_offsets.append(Vector2(0.93, 0.55) - anchor / Vector2(cell))

func frame_index(age: float, phase := 0.0) -> int:
	return posmod(int(floor((age + phase) * FPS)), FRAME_COUNT)

func spawn_visit() -> void:
	var capacity := MAX_FISH - visitors.size()
	if capacity <= 0:
		next_visit = 1.0
		return
	visit_count += 1
	var route: Array = DIAGONAL_ROUTES[(visit_count - 1) % DIAGONAL_ROUTES.size()]
	var count := mini(capacity, rng.randi_range(GROUP_SIZE.x, GROUP_SIZE.y))
	for i in range(count):
		var lateral := Vector2(rng.randf_range(-0.06, 0.06), 0)
		visitors.append({"age": 0.0,
			"duration": rng.randf_range(12.0, 16.0),
			"from": route[0] + lateral, "to": route[1] + lateral,
			"bend": rng.randf_range(-0.035, 0.035),
			"length": rng.randf_range(FISH_LENGTH.x, FISH_LENGTH.y),
			"phase": rng.randf_range(0.0, 1.0)})
	next_visit = rng.randf_range(VISIT_INTERVAL.x, VISIT_INTERVAL.y)
	queue_redraw()

func advance(delta: float) -> void:
	for visitor in visitors:
		visitor.age += delta
	for i in range(visitors.size() - 1, -1, -1):
		if visitors[i].age >= visitors[i].duration:
			visitors.remove_at(i)
	next_visit -= delta
	if next_visit <= 0:
		spawn_visit()
	queue_redraw()

func _process(delta: float) -> void:
	if is_visible_in_tree():
		advance(delta)

func swim_position(visitor: Dictionary, progress: float) -> Vector2:
	var start: Vector2 = visitor.from * size
	var end: Vector2 = visitor.to * size
	var bend := Vector2(0, visitor.bend * size.y)
	return start.bezier_interpolate(start.lerp(end, 0.33) + bend, start.lerp(end, 0.67) - bend, end, progress)

func _draw() -> void:
	var cell := Vector2(SHEET.get_size()) / Vector2(COLUMNS, 2)
	for visitor in visitors:
		if visitor.age < 0:
			continue
		var progress: float = clampf(visitor.age / visitor.duration, 0, 1)
		var center := swim_position(visitor, progress)
		var heading := swim_position(visitor, minf(1, progress + 0.001)) - center
		var frame := frame_index(visitor.age, visitor.phase)
		var region := Rect2(Vector2(frame % COLUMNS, frame / COLUMNS) * cell, cell)
		var length_: float = visitor.length * minf(size.x / 1280.0, size.y / 644.0)
		var dimensions := Vector2.ONE * length_
		var alpha := smoothstep(0.0, 0.09, progress) * smoothstep(0.0, 0.12, 1.0 - progress) * 0.26
		draw_set_transform(center, heading.angle())
		draw_texture_rect_region(SHEET, Rect2(-dimensions * 0.5 + frame_offsets[frame] * dimensions, dimensions), region, Color(0.48, 0.63, 0.60, alpha))
	draw_set_transform(Vector2.ZERO)
