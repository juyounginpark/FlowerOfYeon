extends RefCounted
## User-marked outer screen regions. Gourds drop onto real map/floor colliders.
const LEFT_ZONE:=Rect2(.025,.10,.19,.79)
const RIGHT_ZONE:=Rect2(.70,.10,.28,.79)

static func build(story:Node3D) -> Array[Dictionary]:
	var view:Camera3D=story.camera
	var screen:Vector2=story.get_viewport().get_visible_rect().size
	if screen.x<64 or screen.y<64:return []
	var pixels_per_unit:float=screen.y/view.size
	var gourd_width:float=story.gourd_width*2.0
	var gourd_height:float=story.textures[3].get_height()*gourd_width/story.textures[3].get_width()
	var stem:Vector2=preload("res://scripts/grid_stage/heungbu_minhwa.gd").stem_anchor(story.textures[3])*gourd_width/story.textures[3].get_width()
	var bob_pixels:float=absf(view.unproject_position(Vector3.UP*.16).y-view.unproject_position(Vector3.ZERO).y)
	var margin:float=12+bob_pixels
	# One lane on the left; two separate X lanes in the wider right box.
	var slots:=[Vector2(.025,.215),Vector2(.70,.835),Vector2(.845,.98)]
	var lane_width:float=.135*screen.x
	var width:float=minf(minf(story.bird_width,2.4),(lane_width-2*margin)/(287.0*4.0/440.0*pixels_per_unit))
	if width<=0:return []
	var scale_:float=width*4.0/440.0
	var forward:Vector3=-view.global_basis.z
	if absf(forward.y)<.001:return []
	var result:Array[Dictionary]=[]
	for index:int in 3:
		var flipped:bool=index>0
		var zone_normalized:Rect2=RIGHT_ZONE if flipped else LEFT_ZONE
		var zone:=Rect2(zone_normalized.position*screen,zone_normalized.size*screen)
		var slot:Vector2=slots[index]
		var half_span:float=143.5*scale_*pixels_per_unit+margin
		var target_x:float=randf_range(slot.x*screen.x+half_span,slot.y*screen.x-half_span)
		var body_offset:float=(141.5 if flipped else -141.5)*scale_
		var beak_x:float=target_x-body_offset*pixels_per_unit
		var low_y:float=maxf(screen.y*.15,zone.position.y+162*scale_*pixels_per_unit+margin)
		var gourd_bottom:float=(stem.y+gourd_height*.5)*pixels_per_unit
		var high_y:float=minf(screen.y*.62,minf(zone.end.y-160*scale_*pixels_per_unit-margin,screen.y*.88-gourd_bottom))
		if high_y<low_y:return []
		var beak_pixel:=Vector2(beak_x,randf_range(low_y,high_y))
		var attachment:Vector3=view.global_basis.x*(-stem.x if flipped else stem.x)+view.global_basis.y*stem.y
		var support:Vector3=_support_offset(story,flipped)
		var up_pixels:float=maxf(.001,view.unproject_position(Vector3.ZERO).y-view.unproject_position(Vector3.UP).y)
		var available_drop:float=(screen.y*.94-beak_pixel.y-gourd_bottom)/up_pixels
		var drop:float=clampf(available_drop,.5,maxf(.5,story.gourd_drop_distance))
		var center_y:float=story.gourd_minimum_y-support.y+drop
		# Solve depth along the viewing ray so screen placement is independent
		# of the narrow terraces, while the whole gourd starts above Y=0.
		var near_center:Vector3=view.project_position(beak_pixel,1.0)-attachment
		var depth:float=1.0+(center_y-near_center.y)/forward.y
		if depth<=view.near:return []
		var beak:Vector3=view.project_position(beak_pixel,depth)
		var center:Vector3=beak-attachment
		var landing:=Vector3(center.x,story.gourd_minimum_y-support.y,center.z)
		var bird_rect:=Rect2(beak_pixel,Vector2.ZERO)
		for corner:Vector2 in [Vector2(-285,-160),Vector2(2,-160),Vector2(2,162),Vector2(-285,162)]:
			var offset:=Vector2(-corner.x if flipped else corner.x,corner.y)*scale_
			bird_rect=bird_rect.expand(view.unproject_position(beak+view.global_basis.x*offset.x+view.global_basis.y*offset.y))
		bird_rect=bird_rect.grow(margin)
		var rect:Rect2=bird_rect
		for corner:Vector2 in [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]:
			rect=rect.expand(view.unproject_position(center+view.global_basis.x*corner.x*gourd_width+view.global_basis.y*corner.y*gourd_height))
		result.append({"center":center,"beak":beak,"landing":landing,"flip":flipped,"width":width,"rect":rect,"bird_rect":bird_rect,"target_x":target_x,"body_offset":body_offset,"zone":zone,"relaxed":true})
	return result

static func _support_offset(story:Node3D,flipped:bool) -> Vector3:
	var outline:PackedVector2Array=story.silhouettes[3]
	var size_:Vector2=story.textures[3].get_size()
	var unit:float=story.gourd_width*2.0/size_.x
	var bounds:=Rect2(outline[0],Vector2.ZERO)
	for point:Vector2 in outline:bounds=bounds.expand(point)
	var half_depth:float=maxf(.04,bounds.size.x*unit*.18)
	var points:=PackedVector3Array();var lowest:=INF
	for point:Vector2 in outline:
		for depth:float in [-half_depth,half_depth]:
			var local:=Vector3((point.x-size_.x*.5)*unit,(size_.y*.5-point.y)*unit,depth)
			if flipped:local.x=-local.x
			var offset:Vector3=story.camera.global_basis*local
			points.append(offset);lowest=minf(lowest,offset.y)
	var support:=Vector3.ZERO;var count:=0
	for point:Vector3 in points:
		if point.y<=lowest+.01:support+=point;count+=1
	support/=maxi(count,1);support.y=lowest
	return support
