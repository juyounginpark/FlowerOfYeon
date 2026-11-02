extends RefCounted
# Shared collision/visual boxes for the archived stories and tree crossings.
static func box(owner:Node3D,position:Vector3,size:Vector3,color:Color,visible:=true) -> StaticBody3D:
	var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=2
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new()
	shape.size=size;collision.shape=shape;body.add_child(collision)
	if visible:
		var visual:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;visual.mesh=mesh
		var ink:=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ink.albedo_color=color
		visual.material_override=ink;body.add_child(visual)
	owner.add_child(body);body.position=position
	return body
