class_name GridFootprints
extends Node3D
# Small shoe-shaped ink impressions, emitted only at walk-cycle contacts.
const LIFETIME:=5.0
const MAX_MARKS:=64
var actor:WorldPilgrim
var marks:Array[Dictionary]=[]
var last_frame:=-1
var was_walking:=false
var distance_since_contact:=0.0
var soles:Array[ArrayMesh]=[]
func configure(player:WorldPilgrim) -> void:
	actor=player
	for side:float in [-1.0,1.0]:soles.append(_sole_mesh(side))
func _sole_mesh(side:float) -> ArrayMesh:
	# Rounded broad toe, narrowed arch, squared heel; mirror left/right shoes.
	var outline:=PackedVector2Array([Vector2(-.035,.105),Vector2(.031,.105),Vector2(.042,.066),Vector2(.035,.012),Vector2(.052,-.052),Vector2(.040,-.108),Vector2(.009,-.132),Vector2(-.028,-.124),Vector2(-.048,-.082),Vector2(-.043,-.022),Vector2(-.030,.052)])
	var polygon:=PackedVector2Array();var vertices:=PackedVector3Array()
	for point:Vector2 in outline:
		point.x*=side;polygon.append(point);vertices.append(Vector3(point.x,0,point.y))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_INDEX]=Geometry2D.triangulate_polygon(polygon)
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
func advance(delta:float,travel:Vector3) -> void:
	if actor.paused or actor.input_locked:
		was_walking=false;last_frame=-1;distance_since_contact=0;return
	for index in range(marks.size()-1,-1,-1):
		var mark:Dictionary=marks[index]
		if not is_instance_valid(mark.mesh):marks.remove_at(index);continue
		mark.age=float(mark.age)+delta
		if float(mark.age)>=LIFETIME:
			mark.mesh.queue_free();marks.remove_at(index);continue
		# Hold briefly, then fade without changing palette or emitting particles.
		mark.ink.albedo_color=Color(.18,.23,.22,.29*(1.0-smoothstep(1.5,LIFETIME,float(mark.age))))
	travel.y=0
	var distance:=travel.length()
	# Respawn/teleport and no-input platform carry must not stamp a trail.
	var maximum_step:float=actor.move_speed*delta*2.5+.04
	var walking:bool=actor.is_on_floor() and String(actor.sprite.animation).begins_with("walk_") and distance>.001 and distance<maximum_step
	if not walking:
		was_walking=false;last_frame=-1;distance_since_contact=0;return
	distance_since_contact+=distance
	var frame:int=actor.sprite.frame%4
	var contact:bool=frame in [0,2] and (not was_walking or frame!=last_frame)
	if contact and distance_since_contact>.045:
		_stamp(0 if frame==0 else 1,travel.normalized())
		distance_since_contact=0
	last_frame=frame;was_walking=true
func _stamp(foot:int,forward:Vector3) -> void:
	var right:=forward.cross(Vector3.UP).normalized()
	var side:float=-1.0 if foot==0 else 1.0
	var start:=actor.global_position+right*side*.09+forward*.025+Vector3.UP*.24
	var query:=PhysicsRayQueryParameters3D.create(start,start+Vector3.DOWN*.65,5)
	query.exclude=[actor.get_rid()]
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider is Node3D:return
	if bool(hit.collider.get_meta("no_surface_marks",false)):return
	var normal:Vector3=hit.normal.normalized()
	if normal.dot(Vector3.UP)<.65:return
	var tangent:Vector3=(forward-normal*forward.dot(normal)).normalized()
	if tangent.length_squared()<.001:return
	right=tangent.cross(normal).normalized()
	var ink:=StandardMaterial3D.new()
	ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.cull_mode=BaseMaterial3D.CULL_DISABLED;ink.albedo_color=Color(.18,.23,.22,.29)
	var stamp:=MeshInstance3D.new();stamp.name="ShoeInkLeft" if foot==0 else "ShoeInkRight"
	stamp.mesh=soles[foot];stamp.material_override=ink
	stamp.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Parent to the struck collider: lifting blocks carry their ink impressions.
	hit.collider.add_child(stamp)
	stamp.global_transform=Transform3D(Basis(right,normal,-tangent),hit.position+normal*.004)
	marks.append({"mesh":stamp,"ink":ink,"age":0.0})
	while marks.size()>MAX_MARKS:
		var oldest:Dictionary=marks.pop_front()
		if is_instance_valid(oldest.mesh):oldest.mesh.queue_free()
