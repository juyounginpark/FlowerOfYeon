class_name WorldRoute
extends RefCounted

var points: Array[Vector3] = []
var stations: Array[float] = []
var turns: Array[float] = []
var length := 0.0
var baseline_length := 18.4166724085808
var original_world_length := 0.0
var original_point_count := 0
var upper_start_station := 0.0
var upper_end_parameter := 1.0
var stair_breakpoint_stations: Array[float] = []
var stair_sections: Array[Vector2] = []
const EXPANSION_RATIO := 10.0
const UPPER_START_ANGLE := PI
const UPPER_TURNS := 12.0


func _init() -> void:
	for i in 433:
		var t := float(i) / 432
		var angle := deg_to_rad(-10 + 1080 * t)
		var radius := lerpf(12.2, 8.0, t)
		# Base cloisters and upper masonry follow polygonal faces; the middle
		# gallery follows a true curved perimeter. Both are one continuous path.
		if t < 0.30 or t > 0.69:
			var sector := fposmod(angle + PI / 8, PI / 4) - PI / 8
			radius *= cos(PI / 8) / cos(sector)
		var rise := 37.0 * t + 3.0 * clampf((t - 0.45) / 0.035, 0, 1)
		var p := Vector3(sin(angle) * radius, 4 + rise, cos(angle) * radius)
		if not points.is_empty():
			length += p.distance_to(points[-1])
		points.append(p)
		stations.append(length)
		if i > 0 and i < 432 and i % 36 == 24:
			turns.append(length)

	# A short level approach reaches the actual summit terrace, not a rim below it.
	var summit_start: Vector3 = points[-1]
	var initial_angle := atan2(summit_start.x,summit_start.z)
	var initial_radius := Vector2(summit_start.x,summit_start.z).length()
	for step in range(1,9):
		var t := step/8.0
		var angle := initial_angle+deg_to_rad(10.0)*t
		var radius := lerpf(initial_radius,6.2,t)
		var point := Vector3(sin(angle)*radius,44.0,cos(angle)*radius)
		length += point.distance_to(points[-1])
		points.append(point)
		stations.append(length)
	# Keep view transitions on stable stone before a terrain puzzle.
	for index in turns.size():
		for gap in [Vector2(23,29),Vector2(93,99),Vector2(151,156.5),Vector2(159,164.5)]:
			if turns[index]>gap.x-0.5 and turns[index]<gap.y+0.5:
				turns[index]=gap.x-0.8
	_append_expanded_route()
	_author_stone_stairs()

func _append_point(value:Vector3) -> void:
	length+=points[-1].distance_to(value)
	points.append(value)
	stations.append(length)

func _append_expanded_route() -> void:
	original_world_length=length
	original_point_count=points.size()
	# The former44m altar becomes an intermediate terrace. A supported spiral
	# ramp expands outward between the eight giant open-basement columns.
	var initial:=points[-1]
	var initial_radius:=Vector2(initial.x,initial.z).length()
	var initial_angle:=atan2(initial.x,initial.z)
	for i in range(1,145):
		var u:=float(i)/144.0
		var angle:=lerpf(initial_angle,UPPER_START_ANGLE,u)
		var radius:=lerpf(initial_radius,upper_radius(0.0,UPPER_START_ANGLE),u)
		_append_point(Vector3(sin(angle)*radius,lerpf(44.0,65.0,smoothstep(0.10,1.0,u)),cos(angle)*radius))
	upper_start_station=length
	var target:=original_world_length*EXPANSION_RATIO
	for i in range(1,2881):
		var u:=float(i)/2880.0
		var angle:=UPPER_START_ANGLE+TAU*UPPER_TURNS*u
		var radius:=upper_radius(u,angle)
		var candidate:=Vector3(sin(angle)*radius,upper_height(u),cos(angle)*radius)
		var span:=candidate.distance_to(points[-1])
		if length+span>=target:
			var fraction:float=(target-length)/span
			upper_end_parameter=lerpf(float(i-1)/2880.0,u,fraction)
			_append_point(points[-1].lerp(candidate,fraction))
			break
		_append_point(candidate)

func _author_stone_stairs() -> void:
	# Two bounded upper sections: six real horizontal treads each. The remaining
	# 40percent of each metre forms a beveled rise, not an invisible smooth ramp.
	# Both endpoints retain their old positions/heights; the original441 points
	# precede these ranges and are copied untouched.
	var rebuilt: Array[Vector3] = []
	var breakpoint_indices: Array[int] = []
	var section_indices: Array[Vector2i] = []
	var cursor:=0
	for source_range in [Vector2(360,366),Vector2(1000,1006)]:
		while cursor<points.size() and stations[cursor]<source_range.x:
			rebuilt.append(points[cursor])
			cursor+=1
		var beginning:=point(source_range.x)
		var ending:=point(source_range.y)
		var first_index:=rebuilt.size()
		rebuilt.append(beginning)
		breakpoint_indices.append(first_index)
		for step in 6:
			var level:=lerpf(beginning.y,ending.y,float(step)/6.0)
			var tread_end:=point(lerpf(source_range.x,source_range.y,(float(step)+0.60)/6.0))
			tread_end.y=level
			rebuilt.append(tread_end)
			breakpoint_indices.append(rebuilt.size()-1)
			var rise_end:=point(lerpf(source_range.x,source_range.y,float(step+1)/6.0))
			rise_end.y=lerpf(beginning.y,ending.y,float(step+1)/6.0)
			rebuilt.append(rise_end)
			breakpoint_indices.append(rebuilt.size()-1)
		section_indices.append(Vector2i(first_index,rebuilt.size()-1))
		while cursor<points.size() and stations[cursor]<=source_range.y:cursor+=1
	while cursor<points.size():
		rebuilt.append(points[cursor])
		cursor+=1
	points=rebuilt
	stations.clear()
	length=0.0
	for i in points.size():
		if i>0:length+=points[i-1].distance_to(points[i])
		stations.append(length)
	for index in breakpoint_indices:stair_breakpoint_stations.append(stations[index])
	for indices in section_indices:stair_sections.append(Vector2(stations[indices.x],stations[indices.y]))

static func upper_height(u:float) -> float:
	# Positive slope throughout, with broad gentle landing-like sections.
	return 65.0+310.0*(u-0.012*sin(u*TAU*6.0))

static func upper_radius(u:float,angle:float) -> float:
	var radius:=lerpf(34.0,17.0,u)
	var octant:=fposmod(angle+PI/8.0,PI/4.0)-PI/8.0
	var polygon:=cos(PI/8.0)/cos(octant)
	# Alternating faceted and rounded architectural tiers, smoothly joined.
	var faceting:=smoothstep(0.15,0.85,0.5+0.5*cos(u*TAU*3.0))
	return radius*lerpf(1.0,polygon,faceting)

func width_axis(station:float) -> Vector3:
	var p:=point(station)
	var radial:=Vector3(p.x,0,p.z).normalized()
	if station<=original_world_length:return radial
	return expanded_width_axis(station)

func expanded_width_axis(station:float) -> Vector3:
	# Never rotate a wide cross-section while climbing: that twists its two
	# triangles into a steep invisible wall. A separate flat landing joins the
	# old radial end edge to this perpendicular outgoing frame.
	var at:=point(station)
	var direction:=point(minf(length,station+0.1))-point(maxf(original_world_length,station-0.1))
	direction.y=0
	if direction.length_squared()<0.000001:direction=tangent(station)
	var side:=direction.normalized().cross(Vector3.UP)
	if side.dot(Vector3(at.x,0,at.z))<0:side=-side
	return side

func interval(station: float) -> int:
	var low:=0
	var high:=stations.size()-2
	while low<high:
		var middle: int=(low+high)>>1
		if station<=stations[middle+1]:high=middle
		else:low=middle+1
	return low

func point(station: float) -> Vector3:
	station = clampf(station, 0, length)
	var i := interval(station)
	return points[i].lerp(points[i + 1], (station - stations[i]) / (stations[i + 1] - stations[i]))

func tangent(station: float) -> Vector3:
	var i := interval(clampf(station, 0, length))
	var result := points[i + 1] - points[i]
	result.y = 0
	return result.normalized()

func horizontal_heading(station:float, sample_distance:=0.65) -> Vector3:
	# Spatial look-behind/look-ahead blends adjacent segment directions without
	# mixing coordinate spaces or lerping opposite unit vectors through zero.
	var span:=maxf(0.05,sample_distance)
	var direction:=point(minf(length,station+span))-point(maxf(0.0,station-span))
	direction.y=0
	if direction.length_squared()>0.000001:return direction.normalized()
	# One-sided endpoints, vertical segments or a cancelling hairpin still
	# receive a deterministic nonzero horizontal frame.
	var index:=interval(clampf(station,0,length))
	for offset in range(points.size()-1):
		for candidate in [index+offset,index-offset]:
			if candidate<0 or candidate>=points.size()-1:continue
			direction=points[candidate+1]-points[candidate]
			direction.y=0
			if direction.length_squared()>0.000001:return direction.normalized()
	return Vector3.FORWARD

func closest(position: Vector3) -> float:
	var best := INF
	var result := 0.0
	for i in range(points.size() - 1):
		var delta := points[i + 1] - points[i]
		var t := clampf((position - points[i]).dot(delta) / delta.length_squared(), 0, 1)
		var distance := position.distance_squared_to(points[i] + delta * t)
		if distance < best:
			best = distance
			result = lerpf(stations[i], stations[i + 1], t)
	return result

func mesh(start: float, finish: float, width := 1.7, thickness := 0.36) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := maxi(2, int(ceil((finish - start) / 0.20)))
	var samples: Array[float] = []
	for i in range(steps+1):samples.append(lerpf(start,finish,float(i)/steps))
	# Merely sampling every0.20m can round off a tread/riser corner. Insert all
	# exact authored stair corners; renderer and trimesh collider share this mesh.
	for corner in stair_breakpoint_stations:
		if corner>start and corner<finish:samples.append(corner)
	samples.sort()
	var unique: Array[float] = []
	for value in samples:
		if unique.is_empty() or absf(value-unique[-1])>0.00000001:unique.append(value)
	var segments:=unique.size()-1
	for i in segments:
		var s0 := unique[i]
		var s1 := unique[i+1]
		var p0 := point(s0)
		var p1 := point(s1)
		var r0 := expanded_width_axis(s0) if start>=original_world_length else width_axis(s0)
		var r1 := expanded_width_axis(s1) if start>=original_world_length else width_axis(s1)
		var a := p0 - r0 * width / 2
		var b := p0 + r0 * width / 2
		var c := p1 + r1 * width / 2
		var d := p1 - r1 * width / 2
		var down := Vector3.DOWN * thickness
		var normal := (d - a).cross(b - a).normalized()
		if normal.y < 0: normal = -normal
		HybridStone._quad(surface, a, b, c, d, normal, [Vector2(s0,-width/2),Vector2(s0,width/2),Vector2(s1,width/2),Vector2(s1,-width/2)])
		HybridStone._quad(surface, b, b + down, c + down, c, (r0 + r1).normalized())
		HybridStone._quad(surface, d, d + down, a + down, a, -(r0 + r1).normalized())
		HybridStone._quad(surface, a + down, d + down, c + down, b + down, Vector3.DOWN)
		if i == 0: HybridStone._quad(surface, a, a + down, b + down, b, -tangent(start))
		if i == segments - 1: HybridStone._quad(surface, c, c + down, d + down, d, tangent(finish))
	return surface.commit()
