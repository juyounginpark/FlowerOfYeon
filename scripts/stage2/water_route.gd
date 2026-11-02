extends RefCounted
# Conservative XZ navigation: inflated building footprints are never traversed.
static func build(world: GridStageWorld, start: Vector3, finish: Vector3) -> PackedVector3Array:
	var obstacles: Array[Rect2] = []
	var bounds := Rect2(Vector2(start.x, start.z), Vector2.ZERO).expand(Vector2(finish.x, finish.z))
	for box: Array in world.stage_data.low + world.stage_data.raised:
		var a: Vector3 = world.stage_root.to_global(Vector3(box[0]) * .2)
		var b: Vector3 = world.stage_root.to_global(Vector3(box[1]) * .2)
		var rect := Rect2(Vector2(a.x, a.z), Vector2(b.x-a.x, b.z-a.z)).grow(.65)
		obstacles.append(rect)
		bounds = bounds.merge(rect)
	bounds = bounds.grow(2.0)
	var grid := AStarGrid2D.new()
	grid.cell_size = Vector2(.25, .25)
	grid.offset = bounds.position
	grid.region = Rect2i(Vector2i.ZERO, Vector2i(ceil(bounds.size.x/.25)+1, ceil(bounds.size.y/.25)+1))
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	var first := Vector2i.ZERO
	var last := Vector2i.ZERO
	var near_start := INF
	var near_finish := INF
	for x in range(grid.region.size.x):
		for y in range(grid.region.size.y):
			var id := Vector2i(x,y)
			var point := grid.get_point_position(id)
			var blocked := false
			for rect: Rect2 in obstacles:
				if rect.has_point(point): blocked = true; break
			grid.set_point_solid(id, blocked)
			if blocked: continue
			var ds := point.distance_squared_to(Vector2(start.x,start.z))
			var de := point.distance_squared_to(Vector2(finish.x,finish.z))
			if ds < near_start: near_start = ds; first = id
			if de < near_finish: near_finish = de; last = id
	var result := PackedVector3Array()
	for point: Vector2 in grid.get_point_path(first,last): result.append(Vector3(point.x,start.y,point.y))
	return result
