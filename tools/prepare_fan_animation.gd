extends SceneTree
# Extract the eight supplied poses without changing either source sheet.
const ROOT := "res://art/minhwa/fan_story/"
const FRAME := Vector2i(384,640)
const SOLE := Vector2(192,608)
func _initialize() -> void:
	for color in ["red","blue"]:
		var source:=Image.load_from_file(ROOT+color+"_fanning_source.png")
		var bitmap:=BitMap.new();bitmap.create_from_image_alpha(source,.15)
		var outlines:=bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,source.get_size()),2.0)
		var poses:Array[Dictionary]=[]
		for polygon in outlines:
			var area:=0.0;var low:=Vector2(INF,INF);var high:=-low
			for i in polygon.size():
				area+=polygon[i].cross(polygon[(i+1)%polygon.size()]);low=low.min(polygon[i]);high=high.max(polygon[i])
			if absf(area)*.5>15000:poses.append({"region":Rect2i(Vector2i(low),Vector2i(high-low)),"outline":polygon})
		poses.sort_custom(func(a:Dictionary,b:Dictionary):return a.region.position.x<b.region.position.x)
		assert(poses.size()==8,"Expected eight supplied poses for "+color)
		var scale_factor:float=475.0/poses[0].region.size.y
		var atlas:=Image.create(FRAME.x*8,FRAME.y,false,Image.FORMAT_RGBA8)
		for frame in range(8):
			var region:Rect2i=poses[frame].region;var pose:=_isolate(source,region,poses[frame].outline)
			var foot_center:=_feet_center(pose)
			pose.resize(roundi(region.size.x*scale_factor),roundi(region.size.y*scale_factor),Image.INTERPOLATE_LANCZOS)
			var destination:=Vector2i(roundi(SOLE.x-foot_center*scale_factor),roundi(SOLE.y-region.size.y*scale_factor))
			assert(destination.y>=0 and destination.x>=0 and destination.x+pose.get_width()<=FRAME.x,"Pose must fit its sole-aligned frame")
			atlas.blit_rect(pose,Rect2i(Vector2i.ZERO,pose.get_size()),Vector2i(frame*FRAME.x,0)+destination)
		assert(atlas.save_png(ROOT+color+"_fanning.png")==OK)
		print("Prepared eight sole-aligned ",color," fanning poses")
	quit()
func _isolate(source:Image,region:Rect2i,outline:PackedVector2Array) -> Image:
	# Adjacent poses overlap in X. Keep only this connected figure, not neighboring scraps.
	var pose:=source.get_region(region)
	for y in range(region.size.y):
		var scan:=region.position.y+y+.5
		var crossings:=PackedFloat32Array()
		for edge in range(outline.size()):
			var a:=outline[edge];var b:=outline[(edge+1)%outline.size()]
			if (a.y>scan)!=(b.y>scan):crossings.append(a.x+(scan-a.y)*(b.x-a.x)/(b.y-a.y))
		crossings.sort()
		var interval:=0
		for x in range(region.size.x):
			var point:=region.position.x+x+.5
			while interval+1<crossings.size() and point>crossings[interval+1]:interval+=2
			if interval+1>=crossings.size() or point<crossings[interval]:pose.set_pixel(x,y,Color.TRANSPARENT)
	return pose

func _feet_center(image:Image) -> float:
	var groups:Array[Dictionary]=[];var left:=-1;var mass:=0
	for x in range(image.get_width()+1):
		var count:=0
		if x<image.get_width():
			for y in range(maxi(0,image.get_height()-22),image.get_height()):
				if image.get_pixel(x,y).a>.3:count+=1
		if count>=2:
			if left<0:left=x
			mass+=count
		elif left>=0:
			if mass>=25:groups.append({"left":left,"right":x,"mass":mass})
			left=-1;mass=0
	groups.sort_custom(func(a:Dictionary,b:Dictionary):return a.mass>b.mass)
	assert(not groups.is_empty(),"Could not locate a supplied pose's soles")
	var lo:float=groups[0].left;var hi:float=groups[0].right
	if groups.size()>1:lo=minf(lo,groups[1].left);hi=maxf(hi,groups[1].right)
	return (lo+hi)*.5
