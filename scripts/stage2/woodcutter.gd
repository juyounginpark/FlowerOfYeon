extends AnimatedSprite3D
## Simple Joseon artwork. Every animation frame owns an isolated texture.
const ART = preload("res://scripts/stage2/art.gd")
const ASSETS := {"axe": "woodcutter_idle_v2", "woodcutter_run": "woodcutter_run_v2", "woodcutter_push": "woodcutter_push_v2"}
@export_range(0.1, 60.0, 0.1) var animation_fps: float = 8.0:
	set(value):
		animation_fps = maxf(value, 0.1)
		if sprite_frames != null and sprite_frames.has_animation("axe"):
			sprite_frames.set_animation_speed("axe", minf(animation_fps, 4.0))
@export var character_height: float = 1.5
var action_name := ""
var action_heights: Dictionary = {}

func _ready() -> void:
	sprite_frames = SpriteFrames.new()
	sprite_frames.remove_animation("default")
	prepare_actions()
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	no_depth_test = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	frame_changed.connect(_align_frame)
	reset_actor()

func prepare_actions() -> void:
	for animation_name: String in ASSETS:
		if sprite_frames.has_animation(animation_name): continue
		var entries: Array = ART.frames(ASSETS[animation_name])
		var tallest := 1.0
		for entry: Dictionary in entries: tallest = maxf(tallest, entry.painted.size.y)
		action_heights[animation_name] = tallest
		sprite_frames.add_animation(animation_name)
		sprite_frames.set_animation_speed(animation_name, minf(animation_fps, 4.0) if animation_name == "axe" else 8.0)
		for entry: Dictionary in entries: sprite_frames.add_frame(animation_name, entry.texture)

func current_art() -> Dictionary:
	return ART.frames(ASSETS[String(animation)])[frame]

func _align_frame() -> void:
	if not ASSETS.has(String(animation)): return
	var entry := current_art()
	var bounds: Rect2 = entry.painted
	var size: Vector2 = entry.texture.get_size()
	pixel_size = character_height / float(action_heights[String(animation)])
	offset = Vector2(size.x * .5 - bounds.get_center().x, bounds.end.y - size.y * .5)
	ART.sliced_sprite(self, entry.texture, false)

func action(asset: String, index: int, face_left: bool) -> void:
	stop()
	action_name = asset
	animation = asset
	frame = clampi(index, 0, sprite_frames.get_frame_count(asset) - 1)
	flip_h = not face_left if asset == "woodcutter_run" else face_left
	_align_frame()

func reset_actor() -> void:
	action_name = ""
	flip_h = false
	modulate = Color.WHITE
	show()
	play("axe")
	_align_frame()

func _process(_delta: float) -> void:
	var stage_world := get_parent().get_parent() as GridStageWorld
	if stage_world != null:
		speed_scale = 0.0 if stage_world.paused else 1.0
