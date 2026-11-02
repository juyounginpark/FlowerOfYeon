@tool
extends Node2D
## Independent clock: the eight-second lotus animation never resets cloud drift.
@export var base_position := Vector2.ZERO:
	set(value):
		base_position = value
		_apply()
@export_range(0.0, 100.0, 0.5) var amplitude_px: float = 18.0:
	set(value):
		amplitude_px = value
		_apply()
@export_range(1.0, 120.0, 0.1) var period_seconds: float = 24.0
@export_range(0.0, 6.283185, 0.01) var initial_phase: float = 0.0:
	set(value):
		initial_phase = value
		_apply()
var elapsed: float = 0.0

func _ready() -> void:
	_apply()

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	elapsed += delta
	_apply()

func _apply() -> void:
	position = base_position + Vector2(sin(elapsed * TAU / maxf(period_seconds, 0.001) + initial_phase) * amplitude_px, 0)
