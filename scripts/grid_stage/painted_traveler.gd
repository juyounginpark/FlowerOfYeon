class_name PaintedTravelerFrames
extends RefCounted
# Authored row-major views: front, front-right, right, rear-right,
# rear, rear-left, left, front-left; names are SCREEN facing, not world axes.
static var cached:SpriteFrames
static func create() -> SpriteFrames:
	if cached!=null:return cached
	cached=SpriteFrames.new();cached.remove_animation("default")
	var actions:Dictionary={"idle":2,"walk":8,"jump":1,"land":2,"play":4}
	for direction in TravelerFrames.DIRECTIONS:
		var texture:Texture2D=load("res://art/minhwa/traveler_v3/traveler/%s_frames.png"%direction)
		var index:=0
		for action in actions:
			var name_:String=action+"_"+direction
			cached.add_animation(name_);cached.set_animation_loop(name_,action in ["idle","walk"])
			cached.set_animation_speed(name_,7 if action=="walk" else (10 if action=="land" else 6))
			if action=="walk":
				# Generated contact/passing/contact/passing poses; preserve old atlas
				# offsets for all unrelated actions below.
				var walking:Texture2D=load("res://art/minhwa/walk_v2/%s_walk.png"%direction)
				for walk_frame in 4:
					var walk_region:=AtlasTexture.new();walk_region.atlas=walking
					walk_region.region=Rect2(walk_frame*384,0,384,512)
					cached.add_frame(name_,walk_region)
				index+=int(actions[action])
				continue
			for frame in int(actions[action]):
				var region:=AtlasTexture.new();region.atlas=texture
				region.region=Rect2((index%8)*384,(index/8)*512,384,512)
				cached.add_frame(name_,region);index+=1
	return cached
