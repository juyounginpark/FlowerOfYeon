extends RefCounted
## Frame extraction and opaque artwork anchors, local to Stage7.
static var frame_cache:Dictionary={}
static var bound_cache:Dictionary={}
static func bounds(texture:Texture2D) -> Rect2:
	var key:=texture.get_instance_id()
	if bound_cache.has(key):return bound_cache[key]
	var img:=texture.get_image()
	if img.is_compressed():img.decompress()
	var bitmap:=BitMap.new();bitmap.create_from_image_alpha(img,.5)
	var rect:=Rect2();var first:=true
	for polygon:PackedVector2Array in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,img.get_size()),3):
		if polygon.size()<4:continue
		for point:Vector2 in polygon:
			if first:rect=Rect2(point,Vector2.ZERO);first=false
			else:rect=rect.expand(point)
	bound_cache[key]=rect
	return rect

static func sheet(path:String,bird:bool) -> SpriteFrames:
	if frame_cache.has(path):return frame_cache[path]
	var tex:Texture2D=load(path);var source:=tex.get_image()
	if source.is_compressed():source.decompress()
	var result:=SpriteFrames.new();result.set_animation_speed("default",8)
	for index:int in 8:
		var col:int=index%4;var row:int=index/4
		var left:int=col*source.get_width()/4;var top:int=row*source.get_height()/2
		var tile:=source.get_region(Rect2i(left,top,(col+1)*source.get_width()/4-left,(row+1)*source.get_height()/2-top))
		var origin:=Vector2i.ZERO
		if bird:
			# Rightmost opaque point around the face is the beak, independent of
			# wing excursion. All frames share that beak anchor.
			for y:int in range(int(tile.get_height()*.43),int(tile.get_height()*.65)):
				for x:int in tile.get_width():
					if tile.get_pixel(x,y).a>.5 and x>origin.x:origin=Vector2i(x,y)
		else:
			var b:=bounds(ImageTexture.create_from_image(tile))
			origin=Vector2i(roundi(b.get_center().x),roundi(b.end.y))
		var canvas:=Image.create(512,512,false,Image.FORMAT_RGBA8)
		canvas.blit_rect(tile,Rect2i(Vector2i.ZERO,tile.get_size()),(Vector2i(400,240) if bird else Vector2i(256,480))-origin)
		result.add_frame("default",ImageTexture.create_from_image(canvas))
	frame_cache[path]=result
	return result

static func replace_at_feet(sprite:Sprite3D,texture:Texture2D,height:float) -> void:
	var box:=bounds(texture)
	sprite.texture=texture;sprite.pixel_size=height/box.size.y
	sprite.offset=Vector2(texture.get_width()*.5-box.get_center().x,box.end.y-texture.get_height()*.5)

static func replace_building(sprite:Sprite3D,texture:Texture2D) -> void:
	var old:=bounds(sprite.texture);var next:=bounds(texture)
	var old_anchor:=Vector3((old.get_center().x-sprite.texture.get_width()*.5+sprite.offset.x)*sprite.pixel_size,(sprite.texture.get_height()*.5-old.end.y+sprite.offset.y)*sprite.pixel_size,0)
	var foot:=sprite.global_transform*old_anchor
	var width:=old.size.x*sprite.pixel_size
	sprite.texture=texture;sprite.pixel_size=width/next.size.x
	sprite.offset=Vector2(texture.get_width()*.5-next.get_center().x,next.end.y-texture.get_height()*.5)
	sprite.global_position=foot
