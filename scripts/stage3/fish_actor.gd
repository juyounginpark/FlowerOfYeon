extends AnimatedSprite3D
## Fixed cell pivots: never normalize each animation frame independently.
const STILL = preload("res://art/stage3/4.png")
const SHEETS = [preload("res://art/stage3/5.png"),preload("res://art/stage3/6.png"),preload("res://art/stage3/7.png")]
var width := 1.2
var fps := 10.0
var mode := 0
var clock := 0.0
var landed := false
var origin := Vector3.ZERO
var destination := Vector3.ZERO
var lands := false
var controller: Node

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	no_depth_test = true
	render_priority = 112
	set_meta("screen_band",11)
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for i in range(3):
		var animation := str(i)
		frames.add_animation(animation)
		frames.set_animation_speed(animation,fps)
		frames.set_animation_loop(animation,i == 1)
		var size: Vector2 = SHEETS[i].get_size()
		for j in range(16):
			var atlas := AtlasTexture.new()
			atlas.atlas = SHEETS[i]
			var first := Vector2(floor((j%4)*size.x/4),floor((j/4)*size.y/4))
			var end := Vector2(floor((j%4+1)*size.x/4),floor((j/4+1)*size.y/4))
			atlas.region = Rect2(first,end-first)
			atlas.filter_clip = true
			frames.add_frame(animation,atlas)
	sprite_frames = frames
	switch(0)

func switch(next: int) -> void:
	mode = next
	if next == 1 or next == 2: BgmPlayer.play_fish_splash()
	clock = 0
	animation = str(next)
	frame = 0
	pixel_size = width / 300.0
	offset = Vector2(0, (270.0 if next == 0 else 289.0 if next == 1 else 250.0)-156.5)

func advance(delta: float) -> void:
	var previous_cycle := floori(clock * fps / 16.0)
	clock += delta
	if mode == 1 and floori(clock * fps / 16.0) > previous_cycle:
		BgmPlayer.play_fish_splash()
	frame = mini(int(clock*fps)%16 if mode == 1 else int(clock*fps),15)
