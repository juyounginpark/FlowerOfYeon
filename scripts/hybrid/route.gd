class_name HybridRoute
extends RefCounted

# One permanently loaded route: round gallery followed by a faceted gallery.
# Station is cumulative physical distance, not face index or modulo-four state.
const RADIUS := 5.9
const BASE_HEIGHT := 2.2
const RISE_PER_METRE := 0.115
var points: Array[Vector3] = []
var stations: Array[float] = []
var boundary := 0.0
var length := 0.0

func _init() -> void:
	for degree in range(-10, 81, 5):
		_append(deg_to_rad(degree))
	boundary = length
	_append(deg_to_rad(125))
	_append(deg_to_rad(170))

func _append(angle: float) -> void:
	var p := Vector3(sin(angle) * RADIUS, 0, cos(angle) * RADIUS)
	if not points.is_empty():
		var before := points[-1]
		before.y = 0
		length += before.distance_to(p)
	p.y = BASE_HEIGHT + length * RISE_PER_METRE
	points.append(p)
	stations.append(length)

func interval(station: float) -> int:
	for i in range(stations.size() - 1):
		if station <= stations[i + 1]:
			return i
	return stations.size() - 2

func point(station: float) -> Vector3:
	station = clampf(station, 0, length)
	var i := interval(station)
	return points[i].lerp(points[i + 1], (station - stations[i]) / (stations[i + 1] - stations[i]))

func tangent(station: float) -> Vector3:
	var i := interval(clampf(station, 0, length))
	var direction := points[i + 1] - points[i]
	direction.y = 0
	return direction.normalized()

func closest(position: Vector3) -> float:
	var best := INF
	var result := 0.0
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		a.y = 0
		b.y = 0
		var p := position
		p.y = 0
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0, 1)
		var distance := p.distance_squared_to(a.lerp(b, t))
		if distance < best:
			best = distance
			result = lerpf(stations[i], stations[i + 1], t)
	return result
