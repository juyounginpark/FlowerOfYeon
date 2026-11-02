extends RefCounted
# CPU-only projection of the actual opaque map triangles. This data texture
# protects map silhouettes across compositor bands without another render pass.
const MASK_WIDTH:int=512
var mask_width:int=MASK_WIDTH
var camera:Camera3D
var surfaces:Array[Dictionary]=[]
var texture:ImageTexture
var mask_image:Image
var previous_state:Array=[]
var dimensions:=Vector2i.ZERO
func configure(view:Camera3D,stage:Node3D) -> void:
	camera=view
	for body:Node in stage.get_children():
		if not body is PhysicsBody3D or body is CharacterBody3D:continue
		if (body.collision_layer&5)==0:continue
		for node:Node in body.get_children():
			if node is MeshInstance3D and node.mesh!=null:
				surfaces.append({"visual":node,"triangles":node.mesh.get_faces()})
	refresh()
func refresh() -> bool:
	var frame:Vector2=camera.get_viewport().get_visible_rect().size
	if frame.x<=0 or frame.y<=0:return false
	var wanted:=Vector2i(mask_width,maxi(1,int(round(mask_width*frame.y/frame.x))))
	# Transform values are copied, so idle frames perform no raster/texture work.
	var state:Array=[camera.global_transform,camera.projection,camera.size,camera.fov,camera.h_offset,camera.v_offset,camera.keep_aspect,camera.near,camera.far,frame,wanted]
	for surface in surfaces:
		if is_instance_valid(surface.visual):state.append(surface.visual.global_transform)
	if state==previous_state:return false
	previous_state=state;dimensions=wanted
	var pixels:=PackedByteArray();pixels.resize(dimensions.x*dimensions.y);pixels.fill(0)
	for surface in surfaces:
		if not is_instance_valid(surface.visual):continue
		var pose:Transform3D=surface.visual.global_transform
		var triangles:PackedVector3Array=surface.triangles
		for i:int in range(0,triangles.size(),3):
			var a:Vector3=pose*triangles[i];var b:Vector3=pose*triangles[i+1];var c:Vector3=pose*triangles[i+2]
			# The active fixed whole-map view has no near-plane intersections.
			if camera.is_position_behind(a) or camera.is_position_behind(b) or camera.is_position_behind(c):continue
			var pa:Vector2=camera.unproject_position(a)/frame*Vector2(dimensions)
			var pb:Vector2=camera.unproject_position(b)/frame*Vector2(dimensions)
			var pc:Vector2=camera.unproject_position(c)/frame*Vector2(dimensions)
			_fill_triangle(pixels,pa,pb,pc)
	var image:=Image.create_from_data(dimensions.x,dimensions.y,false,Image.FORMAT_R8,pixels)
	mask_image=image
	if texture==null:texture=ImageTexture.create_from_image(image)
	elif texture.get_width()!=dimensions.x or texture.get_height()!=dimensions.y:texture.set_image(image)
	else:texture.update(image)
	return true
func _fill_triangle(pixels:PackedByteArray,a:Vector2,b:Vector2,c:Vector2) -> void:
	var points:=PackedVector2Array([a,b,c])
	var top:int=maxi(0,int(floor(minf(a.y,minf(b.y,c.y)))))
	var bottom:int=mini(dimensions.y-1,int(ceil(maxf(a.y,maxf(b.y,c.y)))))
	for y:int in range(top,bottom+1):
		var scan:float=float(y)+.5
		var left:float=INF;var right:float=-INF
		for edge:int in range(3):
			var p:Vector2=points[edge];var q:Vector2=points[(edge+1)%3]
			if (p.y<=scan and q.y>scan) or (q.y<=scan and p.y>scan):
				var x:float=p.x+(scan-p.y)*(q.x-p.x)/(q.y-p.y)
				left=minf(left,x);right=maxf(right,x)
		if not is_finite(left):continue
		var first:int=maxi(0,int(ceil(left-.5)))
		var last:int=mini(dimensions.x-1,int(floor(right-.5)))
		for x:int in range(first,last+1):pixels[y*dimensions.x+x]=255

func coverage_at(screen_point:Vector2) -> float:
	if mask_image==null:return 0.0
	var frame:Vector2=camera.get_viewport().get_visible_rect().size
	if frame.x<=0 or frame.y<=0:return 0.0
	var point:Vector2=screen_point/frame*Vector2(dimensions)
	if point.x<0 or point.y<0 or point.x>=dimensions.x or point.y>=dimensions.y:return 0.0
	return mask_image.get_pixel(int(point.x),int(point.y)).r
