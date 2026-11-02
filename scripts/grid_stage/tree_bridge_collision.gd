extends RefCounted
# One closed collision skin: no box end walls inside the walking surface.
static func join_spans(crossing:Node3D) -> void:
	var spans:Array[CollisionShape3D]=[]
	for body:Node in crossing.get_children():
		if not body is StaticBody3D:continue
		for child:Node in body.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:spans.append(child)
	if spans.is_empty():return
	var faces:=PackedVector3Array()
	var previous_left:=Vector3.ZERO;var previous_right:=Vector3.ZERO
	for index:int in range(spans.size()):
		var collider:CollisionShape3D=spans[index]
		var size:Vector3=(collider.shape as BoxShape3D).size
		var pose:Transform3D=collider.get_parent().transform*collider.transform
		var left:=pose*Vector3(-size.x*.5,size.y*.5,size.z*.5)
		var right:=pose*Vector3(size.x*.5,size.y*.5,size.z*.5)
		var end_left:=pose*Vector3(-size.x*.5,size.y*.5,-size.z*.5)
		var end_right:=pose*Vector3(size.x*.5,size.y*.5,-size.z*.5)
		# Reuse the preceding edge exactly, avoiding floating-point cracks.
		if index>0:left=previous_left;right=previous_right
		var down:=Vector3.DOWN*size.y
		_quad(faces,left,right,end_right,end_left)
		_quad(faces,end_left+down,end_right+down,right+down,left+down)
		_quad(faces,left,end_left,end_left+down,left+down)
		_quad(faces,end_right,right,right+down,end_right+down)
		if index==0:_quad(faces,right,left,left+down,right+down)
		if index==spans.size()-1:_quad(faces,end_left,end_right,end_right+down,end_left+down)
		previous_left=end_left;previous_right=end_right
		# Keep box dimensions for the artwork and physical fragments after sabotage.
		collider.disabled=true
	var body:=StaticBody3D.new();body.name="ContinuousWalkSurface"
	body.collision_layer=0;body.collision_mask=2
	var shape:=ConcavePolygonShape3D.new();shape.set_faces(faces)
	# Both approaches and the underside remain solid without internal end caps.
	shape.backface_collision=true
	var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider)
	crossing.add_child(body)

static func _quad(faces:PackedVector3Array,a:Vector3,b:Vector3,c:Vector3,d:Vector3) -> void:
	faces.append_array(PackedVector3Array([a,b,c,a,c,d]))
