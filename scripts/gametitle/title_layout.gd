@tool
extends Control
## Composition coordinates use the original 1586 x 992 background.
## AnimationPlayer owns only lift_phase; this script derives both vertical offsets.
const REFERENCE_SIZE := Vector2(1586, 992)
var _reflection_phase: float = 0.0
@export_range(0.0, 12.0, 0.1) var lotus_lift_px: float = 4.0:
	set(value):
		lotus_lift_px = value
		_apply_lift()
@export_range(0.0, 1.0, 0.05) var reflection_follow_ratio: float = 0.3:
	set(value):
		reflection_follow_ratio = value
		_apply_lift()
@export_range(0.02, 0.5, 0.01) var reflection_response_seconds: float = 0.16
@export_range(0.0, 1.0, 0.01) var reflection_opacity: float = 0.25:
	set(value):
		reflection_opacity = value
		_apply_lift()
@export_range(0.0, 1.0, 0.01) var lift_phase: float = 0.0:
	set(value):
		lift_phase = value
		_apply_lift()

func _ready() -> void:
	_reflection_phase = lift_phase
	resized.connect(_fit_composition)
	_fit_composition()
	_apply_lift()

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	# Frame-rate-independent damped following, without cumulative position changes.
	var weight := 1.0 - exp(-delta / maxf(reflection_response_seconds, 0.02))
	_reflection_phase = lerpf(_reflection_phase, lift_phase, weight)
	if absf(_reflection_phase - lift_phase) < 0.0001:
		_reflection_phase = lift_phase
	_apply_lift()

func _fit_composition() -> void:
	var composition := get_node_or_null("Composition") as Control
	if composition == null: return
	var factor := minf(size.x / REFERENCE_SIZE.x, size.y / REFERENCE_SIZE.y)
	composition.scale = Vector2.ONE * factor
	composition.position = (size - REFERENCE_SIZE * factor) * 0.5

func _apply_lift() -> void:
	var lotus := get_node_or_null("Composition/LotusMotion") as Node2D
	var reflection := get_node_or_null("Composition/ReflectionMotion") as Node2D
	var displacement := -lotus_lift_px * lift_phase
	if lotus != null: lotus.position.y = displacement
	if reflection != null:
		# Editor scrubbing remains deterministic; running playback adds gentle lag.
		if Engine.is_editor_hint(): _reflection_phase = lift_phase
		reflection.position.y = -lotus_lift_px * reflection_follow_ratio * _reflection_phase
		reflection.modulate.a = reflection_opacity
