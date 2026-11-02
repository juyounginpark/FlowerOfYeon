extends RefCounted
## Walkable top planes join actual Stage7 terrace heights; no player override.
static func create(parent:Node3D,title:String,a:Vector3,b:Vector3,width:float,texture:Texture2D=null,fit_width:bool=false) -> StaticBody3D:
	if texture==null:texture=preload("res://scripts/grid_stage/heungbu_minhwa.gd").texture("bridge")
	var direction:Vector3=(b-a).normalized();var right:=direction.cross(Vector3.UP).normalized()
	var normal:=right.cross(direction).normalized();var basis:=Basis(right,normal,-direction)
	var body:=StaticBody3D.new();body.name=title;body.collision_layer=1;body.collision_mask=0
	parent.add_child(body);body.global_transform=Transform3D(basis,(a+b)*.5)
	body.set_meta("start",a);body.set_meta("end",b)
	var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(width,.16,a.distance_to(b)+.12);collision.shape=box;collision.position.y=-.08;body.add_child(collision)
	var visual:=MeshInstance3D.new();visual.name="BridgeSurface"
	var ink:=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	if texture:
		var quad:=QuadMesh.new();quad.size=Vector2(a.distance_to(b)*texture.get_width()/float(texture.get_height()),a.distance_to(b))
		if fit_width:quad.size.x=width
		visual.mesh=quad;visual.rotation.x=-PI*.5;visual.position.y=.008
		ink.albedo_texture=texture;ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;ink.cull_mode=BaseMaterial3D.CULL_DISABLED
	else:
		var mesh:=BoxMesh.new();mesh.size=box.size;visual.mesh=mesh;visual.position.y=-.08;ink.albedo_color=Color("ab8153")
	visual.material_override=ink;body.add_child(visual)
	if texture==null:
		for index:int in 12:
			var seam:=MeshInstance3D.new();var strip:=BoxMesh.new();strip.size=Vector3(width,.015,.028);seam.mesh=strip
			var dark:=StandardMaterial3D.new();dark.albedo_color=Color("624a31");dark.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;seam.material_override=dark
			seam.position=Vector3(0,.005,lerpf(-a.distance_to(b)*.5,a.distance_to(b)*.5,index/11.0));body.add_child(seam)
	return body
