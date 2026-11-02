extends RefCounted
# Painted deck follows the existing collision boxes, including their sloped joins.
const TEXTURE_PATH:="res://art/story_props/minhwa_wood_bridge.png"
const FADE_SECONDS:=.8
var spans:Array[Dictionary]=[]
var elapsed:=0.0

func configure(crossing:Node3D) -> void:
	var texture:Texture2D=load(TEXTURE_PATH)
	var bodies:Array[StaticBody3D]=[]
	var total_length:=0.0
	for child:Node in crossing.get_children():
		if child is StaticBody3D:
			var collider:CollisionShape3D=child.get_child(0)
			# The joined walk collider has no separate art; the original spans supply it.
			if not collider.shape is BoxShape3D:continue
			bodies.append(child)
			total_length+=(collider.shape as BoxShape3D).size.z
	var travelled:=0.0
	for body:StaticBody3D in bodies:
		var collider:CollisionShape3D=body.get_child(0)
		var size:Vector3=(collider.shape as BoxShape3D).size
		var mesh:=MeshInstance3D.new();mesh.name="CompletedMinhwaDeck"
		mesh.mesh=_deck_mesh(size,travelled/total_length,(travelled+size.z)/total_length)
		travelled+=size.z
		var ink:=StandardMaterial3D.new()
		ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		ink.cull_mode=BaseMaterial3D.CULL_DISABLED
		ink.albedo_texture=texture;ink.albedo_color.a=0
		mesh.material_override=ink
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Completed decks are readable over walls; falling fragments restore map depth.
		mesh.set_meta("completed_bridge_overlay",true)
		body.add_child(mesh)
		spans.append({"mesh":mesh,"material":ink,"size":size,"body":body})

func _deck_mesh(size:Vector3,start:float,end:float) -> ArrayMesh:
	var x:=size.x*.5;var z:=size.z*.5;var y:=size.y*.5+.006
	# Exclude the transparent margin without changing the source painting.
	var region:=Rect2(246.0/1024.0,16.0/1536.0,534.0/1024.0,1503.0/1536.0)
	var u0:=region.position.x;var u1:=region.end.x
	var v0:=lerpf(region.position.y,region.end.y,start)
	var v1:=lerpf(region.position.y,region.end.y,end)
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-x,y,z),Vector3(x,y,z),Vector3(x,y,-z),Vector3(-x,y,-z)])
	arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(u0,v0),Vector2(u1,v0),Vector2(u1,v1),Vector2(u0,v1)])
	arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
	var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result

func advance(delta:float) -> float:
	elapsed=minf(elapsed+delta,FADE_SECONDS)
	var blend:=smoothstep(0.0,FADE_SECONDS,elapsed)
	for span:Dictionary in spans:span.material.albedo_color.a=blend
	return 1.0-blend

func release(owner_story:Node3D,sideways:Vector3) -> Array[Dictionary]:
	var falling_spans:Array[Dictionary]=[]
	for span:Dictionary in spans:
		# Collide with terrain under gravity, but never act as a player platform.
		var falling:=RigidBody3D.new();falling.collision_layer=0;falling.collision_mask=1
		owner_story.add_child(falling);falling.global_transform=span.body.global_transform
		span.mesh.reparent(falling,true)
		span.mesh.remove_meta("completed_bridge_overlay")
		var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new()
		shape.size=span.size;collider.shape=shape;falling.add_child(collider)
		falling.linear_velocity=sideways*3.5+Vector3.DOWN*.8
		falling.angular_velocity=Vector3(1.5,0,2.0)
		falling_spans.append({"body":falling,"material":span.material,"age":0.0,"opacity":span.material.albedo_color.a})
	spans.clear()
	return falling_spans
