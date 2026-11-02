extends RefCounted
# Supplied eight-pose sheets, normalized to a shared sole without changing gameplay physics.
const SIZE := Vector2(384,640)
const OFFSET := Vector2(0,288)
static func install(frames:SpriteFrames) -> void:
	for color:String in ["red","blue"]:
		var animation:="fan_"+color
		if not frames.has_animation(animation):
			var sheet:Texture2D=load("res://art/minhwa/fan_story/"+color+"_fanning.png")
			frames.add_animation(animation);frames.set_animation_loop(animation,true);frames.set_animation_speed(animation,8)
			for index in range(8):
				var texture:=AtlasTexture.new();texture.atlas=sheet;texture.region=Rect2(Vector2(index*SIZE.x,0),SIZE)
				frames.add_frame(animation,texture)
		var holding:="hold_"+color
		if not frames.has_animation(holding):
			frames.add_animation(holding);frames.set_animation_loop(holding,true)
			frames.add_frame(holding,frames.get_frame_texture(animation,0))
