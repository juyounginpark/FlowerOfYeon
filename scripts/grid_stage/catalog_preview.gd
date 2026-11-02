extends Control
const PAINTING = preload("res://scripts/grid_stage/lotus_painting.gd")
const MAPS = preload("res://scripts/grid_stage/lotus_stages.gd")
const DEW_TEXTURES := [preload("res://art/ui/lotus_pond/dew_round.png"), preload("res://art/ui/lotus_pond/dew_long.png")]
static var cached_maps: Array[Dictionary] = []
var flower: Control
var source: SubViewport
var blossom: TextureRect
var surface_shadow: TextureRect
var koi: Control
var dew_regions: Array[Rect2] = []
var pond: ColorRect
var cleared: Array[int] = []
var petal_count := 1
var flower_rect := Rect2()
var bloom_time := 1.0
var map_shapes: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pond = ColorRect.new()
	pond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pond.show_behind_parent = true
	pond.material = ShaderMaterial.new()
	pond.material.shader = preload("res://shaders/lotus_pond.gdshader")
	add_child(pond)
	source = SubViewport.new()
	source.size = Vector2i(PAINTING.CANVAS)
	source.transparent_bg = true
	source.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(source)
	flower = PAINTING.new()
	flower.size = PAINTING.CANVAS
	source.add_child(flower)
	koi = preload("res://scripts/grid_stage/pond_koi.gd").new()
	koi.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	koi.show_behind_parent = true
	add_child(koi)
	surface_shadow = _image()
	surface_shadow.material = ShaderMaterial.new()
	surface_shadow.material.shader = preload("res://shaders/lotus_surface_shadow.gdshader")
	for texture in DEW_TEXTURES:
		dew_regions.append(_dew_region(texture))
	blossom = _image()
	resized.connect(_layout)
	_layout()
	_prepare_maps()

func _image() -> TextureRect:
	var view := TextureRect.new()
	view.texture = source.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Draw the map polygons in this parent's _draw over the painted images.
	view.show_behind_parent = true
	add_child(view)
	return view

func lotus_radius() -> float:
	return minf(size.y * 0.195, size.x * 0.1794)

func map_center(number: int) -> Vector2:
	# Preserve the clockwise radial structure, viewed straight down over water.
	var base := size * Vector2(0.5, 0.53)
	return base if number == 9 else base + Vector2.from_angle(-PI * 0.5 + (number - 1) * TAU / 8.0) * lotus_radius()

func _layout() -> void:
	if not is_instance_valid(blossom):
		return
	var radius := lotus_radius()
	var extent := radius / 0.285
	var center := map_center(9)
	flower_rect = Rect2(center - Vector2.ONE * extent * 0.5, Vector2.ONE * extent)
	blossom.position = flower_rect.position
	blossom.size = flower_rect.size
	surface_shadow.position = flower_rect.position + Vector2(3, 6) * extent / 440.0
	surface_shadow.size = flower_rect.size
	pond.material.set_shader_parameter("origin", center / size.max(Vector2.ONE))
	pond.material.set_shader_parameter("resolution", size)
	queue_redraw()

func set_progress(stages: Array[int], animate := true) -> void:
	cleared = stages.duplicate()
	var count := LotusProgress.available_count(cleared)
	flower.previous_count = petal_count if animate else count
	petal_count = count
	flower.petal_count = count
	bloom_time = 0.0 if animate and count > flower.previous_count else 1.0
	flower.bloom = bloom_time
	flower.queue_redraw()
	queue_redraw()

func hover_stage(number: int) -> void:
	if number > 0 and flower.hovered != number: BgmPlayer.play_landing()
	flower.hovered = number
	flower.queue_redraw()
	queue_redraw()

func stage_at(point: Vector2) -> int:
	if not flower_rect.has_point(point):
		return 0
	return flower.stage_at((point - flower_rect.position) * PAINTING.CANVAS / flower_rect.size)

func _draw() -> void:
	if not is_instance_valid(flower):
		return
	for number in range(1, petal_count + 1):
		_draw_map(number)

func _prepare_maps() -> void:
	if not cached_maps.is_empty():
		map_shapes = cached_maps
		return
	# Fitting all nine maps against petal masks is expensive on first lobby entry.
	# Let the pond draw and keep each fitting batch within a small CPU budget.
	await get_tree().process_frame
	var batch_start := Time.get_ticks_usec()
	for number in range(1, 10):
		var data: Dictionary = MAPS.get_stage(number)
		var boxes: Array = data.low + data.raised
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for box: Array in boxes:
			low = low.min(Vector2(box[0].x, box[0].z))
			high = high.max(Vector2(box[1].x, box[1].z))
		var midpoint := (low + high) * 0.5
		var scale_ := PAINTING.RADIUS * (0.82 if number == 9 else 1.20) / maxf((high - low).x, (high - low).y)
		var goal: Array = data.goal_cells
		var goal_center := Vector2(goal[0].x + goal[1].x, goal[0].z + goal[1].z) * 0.1
		var entry: Vector3 = data.start
		if not data.lifts.is_empty():
			entry = data.lifts[0]
		elif not data.get("tree_routes", []).is_empty():
			entry = data.tree_routes[0][0]
		var progression := goal_center - Vector2(entry.x, entry.z)
		var rotation_ := 0.0 if number == 9 else -PI * 0.5 + (number - 1) * TAU / 8.0 - progression.angle()
		var polygons: Array[PackedVector2Array] = []
		var raised: Array[bool] = []
		for box: Array in boxes:
			var a := Vector2(box[0].x, box[0].z)
			var b := Vector2(box[1].x, box[1].z)
			var points := PackedVector2Array()
			for point: Vector2 in [a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]:
				points.append(((point - midpoint) * scale_).rotated(rotation_))
			polygons.append(points)
			raised.append(box[1].y > 0)
		var lifts := PackedVector2Array()
		for origin: Vector3 in data.lifts:
			lifts.append(((Vector2(origin.x, origin.z) * 5.0 - midpoint) * scale_).rotated(rotation_))
		var samples := _polygon_samples(polygons, 4)
		for lift_point in lifts:
			for angle in range(8):
				samples.append(lift_point + Vector2.from_angle(angle * TAU / 8.0) * 8.0)
		var best_scale := 0.0
		var best_offset := Vector2.ZERO
		for y in [0.0, -0.08, 0.08]:
			for x in [0.0, -0.06, 0.06]:
				var offset := (Vector2(x, y) * PAINTING.PETAL_SIZE).rotated(PAINTING.stage_rotation(number))
				var lower := 0.0
				var upper := 1.0
				for iteration in range(9):
					var candidate := (lower + upper) * 0.5
					if _fits_map(number, samples, candidate, offset):
						lower = candidate
					else:
						upper = candidate
				if lower > best_scale:
					best_scale = lower
					best_offset = offset
				if Time.get_ticks_usec() - batch_start >= 4000:
					await get_tree().process_frame
					batch_start = Time.get_ticks_usec()
		# A dense pass protects concave edges between the coarse fitting samples.
		var dense := _polygon_samples(polygons, 12)
		while best_scale > 0.05 and not _fits_map(number, dense, best_scale, best_offset):
			best_scale *= 0.97
			if Time.get_ticks_usec() - batch_start >= 4000:
				await get_tree().process_frame
				batch_start = Time.get_ticks_usec()
		var anchor: Vector2 = PAINTING.stage_center(number) + best_offset
		for i in range(polygons.size()):
			for j in range(polygons[i].size()):
				polygons[i][j] = anchor + polygons[i][j] * best_scale
		for i in range(lifts.size()):
			lifts[i] = anchor + lifts[i] * best_scale
		map_shapes.append({"polygons": polygons, "raised": raised, "lifts": lifts})
	cached_maps = map_shapes
	queue_redraw()

func _polygon_samples(polygons: Array[PackedVector2Array], steps: int) -> PackedVector2Array:
	var samples := PackedVector2Array()
	for polygon in polygons:
		for y in range(steps + 1):
			for x in range(steps + 1):
				var top := polygon[0].lerp(polygon[1], float(x) / steps)
				var bottom := polygon[3].lerp(polygon[2], float(x) / steps)
				samples.append(top.lerp(bottom, float(y) / steps))
	return samples

func _fits_map(number: int, samples: PackedVector2Array, scale_: float, offset: Vector2) -> bool:
	var center: Vector2 = PAINTING.stage_center(number) + offset
	for point in samples:
		if number == 9 and (center + point * scale_).distance_to(PAINTING.CENTER) > flower.heart_core_radius:
			return false
		if not flower.contains_point(number, center + point * scale_, 6.0, true):
			return false
	return true

func map_is_contained(number: int) -> bool:
	for point in _polygon_samples(map_shapes[number - 1].polygons, 16):
		if not flower.contains_point(number, point, 4.0, true):
			return false
	for point: Vector2 in map_shapes[number - 1].lifts:
		for ray in range(16):
			if not flower.contains_point(number, point + Vector2.from_angle(ray * TAU / 16.0) * 6.5, 2.0, true):
				return false
	return true

func _dew_region(texture: Texture2D) -> Rect2:
	var image_ := texture.get_image()
	var mask := BitMap.new()
	mask.create_from_image_alpha(image_, 0.28)
	var polygons := mask.opaque_to_polygons(Rect2i(Vector2i.ZERO, image_.get_size()), 2.0)
	var largest := Rect2(image_.get_used_rect())
	var largest_area := 0.0
	for polygon in polygons:
		var region := Rect2(polygon[0], Vector2.ZERO)
		for point in polygon:
			region = region.expand(point)
		if region.get_area() > largest_area:
			largest = region
			largest_area = region.get_area()
	return largest.grow(3).intersection(Rect2(Vector2.ZERO, texture.get_size()))

func _draw_map(number: int) -> void:
	if map_shapes.size() != 9:
		return
	var shape := map_shapes[number - 1]
	var grow: float = flower.growth(number)
	for polygon: PackedVector2Array in shape.polygons:
		var center := (polygon[0] + polygon[2]) * 0.5
		var axis_x := (polygon[1] - polygon[0]) * 0.79
		var axis_y := (polygon[3] - polygon[0]) * 0.79
		# Water tension rounds the old footprints into compact, smooth beads.
		if axis_x.length() > axis_y.length():
			var swap := axis_x
			axis_x = axis_y
			axis_y = -swap
		if axis_y.length() > axis_x.length() * 2.15:
			axis_y = axis_y.normalized() * axis_x.length() * 2.15
		var variant := 1 if axis_y.length() > axis_x.length() * 1.45 else 0
		_draw_dew(number, center, axis_x, axis_y, variant, grow)
	for point: Vector2 in shape.lifts:
		_draw_dew(number, point, Vector2(12, 0), Vector2(0, 12), 0, grow)

func _draw_dew(number: int, center: Vector2, axis_x: Vector2, axis_y: Vector2, variant: int, grow: float) -> void:
	var texture: Texture2D = DEW_TEXTURES[variant]
	var region := dew_regions[variant]
	var uv_rect := Rect2(region.position / texture.get_size(), region.size / texture.get_size())
	var uvs := PackedVector2Array([uv_rect.position, Vector2(uv_rect.end.x, uv_rect.position.y), uv_rect.end, Vector2(uv_rect.position.x, uv_rect.end.y)])
	var points := PackedVector2Array()
	var anchor: Vector2 = PAINTING.stage_center(number)
	var image_scale := lerpf(0.78, 1.0, grow)
	for point: Vector2 in [center - axis_x * 0.5 - axis_y * 0.5, center + axis_x * 0.5 - axis_y * 0.5, center + axis_x * 0.5 + axis_y * 0.5, center - axis_x * 0.5 + axis_y * 0.5]:
		var animated := anchor + (point - anchor) * image_scale
		points.append(flower_rect.position + animated * flower_rect.size / PAINTING.CANVAS)
	draw_polygon(points, PackedColorArray([Color(1, 1, 1, grow * 0.91)]), uvs, texture)

func _process(delta: float) -> void:
	source.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	if is_visible_in_tree() and bloom_time < 1.0:
		bloom_time = minf(1.0, bloom_time + delta / 1.4)
		flower.bloom = bloom_time
		flower.queue_redraw()
		queue_redraw()
