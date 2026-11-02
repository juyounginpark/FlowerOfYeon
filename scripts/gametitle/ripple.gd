@tool
extends Node2D
## AnimationPlayer owns expansion and visibility_weight, never the sprite properties.
@export_range(1.0, 2000.0, 1.0) var start_width: float = 120.0:
	set(value):
		start_width = value
		_apply()
@export_range(1.0, 3000.0, 1.0) var end_width: float = 1400.0:
	set(value):
		end_width = value
		_apply()
@export_range(0.0, 1.0, 0.01) var peak_opacity: float = 0.22:
	set(value):
		peak_opacity = value
		_apply()
@export var artwork_width: float = 2115.0
@export_range(0.0, 1.0, 0.01) var expansion: float = 0.0:
	set(value):
		expansion = value
		_apply()
@export_range(0.0, 1.0, 0.01) var visibility_weight: float = 0.0:
	set(value):
		visibility_weight = value
		_apply()

func _ready() -> void:
	_apply()

func _apply() -> void:
	var sprite := get_node_or_null("Ring") as Sprite2D
	if sprite == null: return
	# Slight deceleration, with no hard change of speed in the visible interval.
	var spread := 1.0 - pow(1.0 - clampf(expansion, 0.0, 1.0), 1.4)
	sprite.scale = Vector2.ONE * lerpf(start_width, end_width, spread) / maxf(artwork_width, 1.0)
	# Ease both the emergence and disappearance of each ring.
	sprite.modulate.a = peak_opacity * smoothstep(0.0, 1.0, visibility_weight)
