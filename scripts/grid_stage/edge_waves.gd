extends Node3D
# Small whole illustrations aligned to real visible lower masonry edges.
const MAX_PATCHES:int=36
const SHORE_PATCHES:int=24
var camera:Camera3D
var map_mask = null
var patches:Array[Dictionary]=[]
var images:Array=[]
var elapsed:=0.0
var stage_root:Node3D
var botanical_mask=null
var layered_waves:bool=false
var top_mask=null
var botanical_clock:float=0.0
var botanical_ids:Array=[]
var placement_pending:bool=true
var splash_events:int=0
func configure(view:Camera3D,stage:Node3D,mask,shared_sheet:ArrayMesh) -> void:
	camera=view;map_mask=mask;stage_root=stage
	# Chapter 2 uses render ordering instead of recurring paper silhouette work.
	layered_waves=int(view.get_parent().stage_number)==5
	if not layered_waves:
		botanical_mask=preload("res://scripts/grid_stage/map_silhouette.gd").new()
		botanical_mask.camera=view;botanical_mask.mask_width=256
		botanical_mask.refresh()
	top_mask=preload("res://scripts/grid_stage/map_silhouette.gd").new()
	top_mask.camera=view
	for surface:Dictionary in map_mask.surfaces:
		var top_faces:=PackedVector3Array()
		var faces:PackedVector3Array=surface.triangles
		for i:int in range(0,faces.size(),3):
			# Godot clockwise triangles: upward visible faces have negative cross Y.
			if (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).normalized().y<-.7:
				top_faces.append_array(PackedVector3Array([faces[i],faces[i+1],faces[i+2]]))
		top_mask.surfaces.append({"visual":surface.visual,"triangles":top_faces})
	top_mask.refresh()
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://art/dummys/diagonal_waves.json"))
	images=data.get("images",[])
	for index:int in range(MAX_PATCHES):
		var visual:=MeshInstance3D.new();visual.mesh=shared_sheet
		visual.name="BottomEdgeFoam%d"%index
		visual.set_meta("slice_whole",true);visual.set_meta("pond_wave",true)
		visual.set_meta("boundary_wave",true)
		visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.extra_cull_margin=.1;visual.visible=false
		var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/grid_shore_wave.gdshader")
		ink.set_shader_parameter("protect_paper",not layered_waves)
		if botanical_mask!=null:ink.set_shader_parameter("botanical_silhouette",botanical_mask.texture)
		ink.set_shader_parameter("map_silhouette",map_mask.texture)
		ink.set_shader_parameter("walking_silhouette",top_mask.texture)
		ink.set_shader_parameter("amplitude",.007)
		ink.set_shader_parameter("rate",.45+float(index%3)*.025)
		ink.set_shader_parameter("phase",float(index)*1.37)
		ink.set_shader_parameter("opacity",.92)
		visual.material_override=ink;add_child(visual)
		patches.append({"visual":visual,"ink":ink})
	_reposition()
func advance(time:float,geometry_changed:bool) -> void:
	elapsed=time
	if not layered_waves:
		_update_paper_contacts()
		if elapsed-botanical_clock>=.1 or botanical_ids.is_empty():
			botanical_clock=elapsed
			_refresh_botanicals()
	if geometry_changed or placement_pending:
		top_mask.refresh()
		_reposition()
		placement_pending=false
	for patch in patches:
		if not patch.visual.visible:continue
		patch.ink.set_shader_parameter("elapsed",elapsed)
		if is_instance_valid(patch.get("host",null)):
			var host:Node3D=patch.host
			patch.base_position=host.global_transform*patch.local_base
			patch.contact_pivot=host.global_transform*patch.local_pivot
			patch.rest_basis=host.global_basis*patch.local_basis
			patch.outward_world=(host.global_basis*patch.local_surge).normalized()
		# Calm contact/recession in the screen-plane normal, never on the path.
		var surge:float=-sin(elapsed*.75+float(patch.get("phase",0.0)))*float(patch.get("surge_units",.018))
		var age:float=elapsed-float(patch.get("pulse_start",-100.0))
		var pulse:float=sin(PI*clampf(age/1.5,0,1)) if age>=0 and age<1.5 else 0.0
		var wall_height:float=float(patch.get("wall_height",0.0))
		var pulse_gain:float=.2 if patch.has("host") else .4
		if patch.has("host"):surge=0.0 # Painted bottom stays bonded to its wall.
		patch.visual.global_position=patch.contact_pivot+(patch.base_position-patch.contact_pivot)*(1.0+pulse_gain*pulse)+patch.outward_world*surge
		patch.visual.global_basis=patch.rest_basis.scaled_local(Vector3.ONE*(1.0+pulse_gain*pulse))
		if wall_height>0:
			var allowed:float=minf(.35,wall_height*.5)+maxf(0.0,wall_height*.5-.35)*pulse
			patch.ink.set_shader_parameter("edge_up",(camera.unproject_position(patch.world_center+Vector3.UP*allowed)-camera.unproject_position(patch.world_center))/get_viewport().get_visible_rect().size)
func observe_front(previous_x:float,current_x:float,top:float,bottom:float) -> void:
	var active:int=0
	for index:int in range(SHORE_PATCHES):
		if elapsed-float(patches[index].get("pulse_start",-100.0))<1.5:active+=1
	if active>=4:return
	for index:int in range(SHORE_PATCHES):
		var patch:Dictionary=patches[index]
		if not patch.visual.visible or not patch.has("contact_center"):continue
		var contact:Vector2=patch.contact_center
		if contact.y<top or contact.y>bottom:continue
		if previous_x>contact.x and current_x<=contact.x and elapsed-float(patch.get("pulse_start",-100.0))>2.2:
			patch["pulse_start"]=elapsed;splash_events+=1;active+=1
			if active>=4:return
func _update_paper_contacts() -> void:
	for index:int in range(SHORE_PATCHES,MAX_PATCHES):patches[index].visual.visible=false
	var used:int=SHORE_PATCHES
	var frame:Vector2=get_viewport().get_visible_rect().size
	var ratio:float=frame.y/1000.0
	# Story illustrations opt into the same existing shore patches as cut paper.
	for node: Node in get_tree().get_nodes_in_group("shore_illustration"):
		if not node is Sprite3D or not stage_root.is_ancestor_of(node) or not node.is_visible_in_tree(): continue
		if used + 2 > MAX_PATCHES: break
		var painted: Rect2 = node.get_meta("shore_painted")
		var size: Vector2 = node.texture.get_size()
		var lower_y: float = (size.y * .5 - painted.end.y + node.offset.y) * node.pixel_size
		var left_x: float = (painted.position.x - size.x * .5 + node.offset.x) * node.pixel_size
		var right_x: float = (painted.end.x - size.x * .5 + node.offset.x) * node.pixel_size
		var left: Vector3 = node.global_transform * Vector3(left_x, lower_y, 0)
		var right: Vector3 = node.global_transform * Vector3(right_x, lower_y, 0)
		for part: int in range(2):
			var pa := camera.unproject_position(left.lerp(right, float(part) / 2.0))
			var pb := camera.unproject_position(left.lerp(right, float(part + 1) / 2.0))
			_place(used, pa, pb, Vector2.DOWN, (left + right) * .5, frame, 1.0)
			patches[used].ink.set_shader_parameter("edge_up", Vector2.ZERO)
			used += 1
	for child:Node in stage_root.find_children("*","Node3D",true,false):
		if not child is GridPaperCutting:continue
		if child.locked:return
		for piece:Dictionary in child.pieces:
			var body:RigidBody2D=piece.body
			if piece.sticker or body==child.grabbed:continue
			var anchored_foam: bool = piece.attached and bool(piece.source.sprite.get_meta("edge_foam", false))
			if piece.attached and not anchored_foam: continue
			if not anchored_foam and body.get_colliding_bodies().is_empty():continue
			if body.linear_velocity.length()>20.0 or absf(body.angular_velocity)>.4:continue
			var baseline:float=float(piece.source.baseline)
			var polygon:PackedVector2Array=body.transform*piece.polygon
			if anchored_foam:
				baseline = -INF
				for point: Vector2 in polygon: baseline = maxf(baseline, point.y)
			var left:float=INF;var right:float=-INF
			for i:int in range(polygon.size()):
				var a:Vector2=polygon[i];var b:Vector2=polygon[(i+1)%polygon.size()]
				# Measure just the portion inside a six-unit bottom-contact strip.
				if a.y>=baseline-6.0 and a.y<=baseline+6.0:
					left=minf(left,a.x);right=maxf(right,a.x)
				if (a.y<baseline-6.0)!=(b.y<baseline-6.0):
					var crossing:float=lerpf(a.x,b.x,(baseline-6.0-a.y)/(b.y-a.y))
					left=minf(left,crossing);right=maxf(right,crossing)
			if not is_finite(left) or right-left<5.0:continue
			var count:int=2 if (right-left)*ratio>90.0 else 1
			for part:int in range(count):
				if used>=MAX_PATCHES:return
				var pa:=Vector2(lerpf(left,right,float(part)/count),baseline)*ratio
				var pb:=Vector2(lerpf(left,right,float(part+1)/count),baseline)*ratio
				_place(used,pa,pb,Vector2.DOWN,piece.visual.global_position,frame,1.0)
				# Paper contact must never gain permission to paint onto architecture.
				patches[used].ink.set_shader_parameter("edge_up",Vector2.ZERO)
				used+=1
	set_meta("paper_contact_patches",used-SHORE_PATCHES)
func _refresh_botanicals() -> void:
	var entries:Array[Dictionary]=[]
	var ids:Array=[]
	for child:Node in stage_root.find_children("*","Node3D",true,false):
		if not child is GridPaperCutting:continue
		for piece:Dictionary in child.pieces:
			var visual:MeshInstance3D=piece.visual
			if not is_instance_valid(visual) or not visual.is_visible_in_tree():continue
			if bool(piece.sticker) or bool(visual.get_meta("wall_layer_attached",false)):continue
			ids.append(visual.get_instance_id())
			entries.append({"visual":visual,"triangles":visual.mesh.get_faces()})
	if ids!=botanical_ids:
		botanical_ids=ids;botanical_mask.previous_state=[]
	botanical_mask.surfaces=entries
	botanical_mask.refresh()
func _reposition() -> void:
	for index:int in range(SHORE_PATCHES):patches[index].visual.visible=false
	if images.is_empty() or map_mask.mask_image==null:return
	var frame:Vector2=get_viewport().get_visible_rect().size
	if frame.y<=0:return
	var used:int=0
	var known:Dictionary={}
	for surface:Dictionary in map_mask.surfaces:
		if not is_instance_valid(surface.visual):continue
		# Raised interaction stones have no shoreline: keep their moving meshes
		# in the occlusion mask, but never author foam on their suspended edges.
		if surface.visual.get_parent() is AnimatableBody3D:continue
		var pose:Transform3D=surface.visual.global_transform
		var triangles:PackedVector3Array=surface.triangles
		for i:int in range(0,triangles.size(),3):
			var a:Vector3=pose*triangles[i];var b:Vector3=pose*triangles[i+1];var c:Vector3=pose*triangles[i+2]
			var normal:Vector3=(b-a).cross(c-a).normalized()
			if absf(normal.y)>.1:continue
			var points:Array[Vector3]=[a,b,c]
			var lowest:float=minf(a.y,minf(b.y,c.y))
			for side:int in range(3):
				var start:Vector3=points[side];var finish:Vector3=points[(side+1)%3]
				if absf(start.y-finish.y)>.001 or absf(start.y-lowest)>.001:continue
				if camera.is_position_behind(start) or camera.is_position_behind(finish):continue
				var pa:Vector2=camera.unproject_position(start);var pb:Vector2=camera.unproject_position(finish)
				if pa.x>pb.x:
					var swap:Vector2=pa;pa=pb;pb=swap
				var key:String=str(pa.round())+str(pb.round())
				if known.has(key):continue
				known[key]=true
				var line:Vector2=pb-pa
				if line.length()<12:continue
				var outward:Vector2=Vector2(-line.y,line.x).normalized()
				# Sample visibility over the complete true edge, retaining every
				# exposed run (including elevated platforms above another silhouette).
				var steps:int=maxi(2,int(ceil(line.length()/4.0)))
				var run:int=-1
				for step:int in range(steps+1):
					var sample:Vector2=pa.lerp(pb,(float(step)+.5)/float(steps))
					var visible:bool=step<steps and map_mask.coverage_at(sample-outward*4.0)>.5 and map_mask.coverage_at(sample+outward*4.0)<.2
					if visible and run<0:run=step
					if not visible and run>=0:
						var first:Vector2=pa.lerp(pb,float(run)/steps)
						var last:Vector2=pa.lerp(pb,float(step)/steps)
						if first.distance_to(last)>12 and used<SHORE_PATCHES:
							var count:int=2 if first.distance_to(last)>150.0*frame.y/720.0 else 1
							for part:int in range(count):
								if used>=SHORE_PATCHES:break
								var from_t:float=maxf(0.0,float(part)/count-.025)
								var to_t:float=minf(1.0,float(part+1)/count+.025)
								_place(used,first.lerp(last,from_t),first.lerp(last,to_t),outward,(start+finish)*.5,frame,2.25,maxf(a.y,maxf(b.y,c.y))-lowest)
								_attach_to_wall(patches[used],surface.visual,(start+finish)*.5,normal)
								used+=1
						run=-1
	set_meta("visible_shore_segments",used)
func _place(index:int,pa:Vector2,pb:Vector2,outward:Vector2,world_center:Vector3,frame:Vector2,multiplier:float=2.25,wall_height:float=0.0) -> void:
	var line:Vector2=pb-pa
	var image_index:int=(0 if index%2==0 else 3) if line.y<0 else (1 if index%2==0 else 2)
	var image:Dictionary=images[image_index]
	var angle:float=float(image.native_axis_radians)
	var aspect:float=float(image.aspect)
	var parallel_extent:float=float(image.paint_axis_extent)
	var perpendicular_extent:float=float(image.paint_normal_extent)
	var mirror:float=-1.0 if line.y>0.0 else 1.0
	# One uniform scale in the original painted coordinate system. Never
	# compress the cross-edge dimension to a separately chosen foam thickness.
	var paint_scale:float=line.length()/parallel_extent*multiplier
	var thickness:float=perpendicular_extent*paint_scale
	# Place the entire silhouette outside the edge; only its innermost painted
	# contour overlaps by position, never by a shader clipping boundary.
	var overlap:float=thickness*.90 # Anchor the painted lower 90% contact line to the shore.
	var center:Vector2=(pa+pb)*.5+outward*(thickness*.5-overlap-float(image.paint_normal_center)*paint_scale)-line.normalized()*mirror*float(image.paint_axis_center)*paint_scale
	var depth:float=maxf(camera.near+.2,(world_center-camera.global_position).dot(-camera.global_basis.z)-.04)
	var position:Vector3=camera.project_position(center,depth)
	var units:float=camera.size/frame.y
	var patch:Dictionary=patches[index]
	patch["paint_image"]=image
	patch["screen_a"]=pa;patch["screen_b"]=pb
	patch["surge_units"]=2.0*units
	patch["wall_height"]=wall_height
	patch["world_center"]=world_center
	patch["contact_center"]=(pa+pb)*.5
	patch.ink.set_shader_parameter("shore_contact",true)
	patch.ink.set_shader_parameter("edge_start",pa/frame)
	patch.ink.set_shader_parameter("edge_end",pb/frame)
	patch.ink.set_shader_parameter("edge_up",(camera.unproject_position(world_center+Vector3.UP*.35)-camera.unproject_position(world_center))/frame)
	patch.ink.set_shader_parameter("frame_size",frame)
	patch["contact_pivot"]=camera.project_position((pa+pb)*.5,depth)
	patch["base_position"]=position;patch["outward_world"]=(camera.global_basis.x*outward.x-camera.global_basis.y*outward.y).normalized();patch["phase"]=float(index)*1.37
	patch.visual.global_position=position
	patch.visual.global_basis=camera.global_basis*Basis(Vector3.BACK,-line.angle())*Basis.from_scale(Vector3(mirror*paint_scale*units,paint_scale*units,1))*Basis(Vector3.BACK,angle)*Basis.from_scale(Vector3(1,aspect,1))
	patch["rest_basis"]=patch.visual.global_basis
	patch.visual.visible=true
	patch.ink.set_shader_parameter("wave_image",load("res://art/dummys/"+str(image.image)))
	var crop:Array=image.crop_uv
	patch.ink.set_shader_parameter("crop_uv",Vector4(float(crop[0]),float(crop[1]),float(crop[2]),float(crop[3])))

func _attach_to_wall(patch:Dictionary,host:Node3D,point:Vector3,normal:Vector3) -> void:
	var facing:Vector3=normal.normalized()
	if facing.dot(camera.global_position-point)<0:facing=-facing
	var ray:Vector3=-camera.global_basis.z
	var divisor:float=facing.dot(ray)
	if absf(divisor)<.08:
		patch.visual.visible=false
		return
	var plane_point:Vector3=point+facing*.025
	var ends:Array[Vector3]=[]
	for screen:Vector2 in [patch.screen_a,patch.screen_b]:
		var origin:Vector3=camera.project_ray_origin(screen)
		ends.append(origin-ray*(facing.dot(origin-plane_point)/divisor))
	var tangent:Vector3=(ends[1]-ends[0]).normalized()
	var pivot:Vector3=(ends[0]+ends[1])*.5
	var image:Dictionary=patch.paint_image
	var wall_height:float=float(patch.wall_height)
	# Uniform native-art scale. Painted alpha center sits on the wall bottom edge.
	var paint_scale:float=minf(ends[0].distance_to(ends[1])/float(image.paint_axis_extent),wall_height*.41/maxf(.01,float(image.paint_normal_extent)))
	var base:Vector3=pivot+Vector3.UP*float(image.paint_normal_center)*paint_scale-tangent*float(image.paint_axis_center)*paint_scale
	var wall_axes:=Basis(tangent,Vector3.UP,tangent.cross(Vector3.UP))
	var wall_basis:Basis=wall_axes*Basis(Vector3.BACK,float(image.native_axis_radians))*Basis.from_scale(Vector3(paint_scale,paint_scale*float(image.aspect),1))
	patch.host=host
	patch.local_base=host.to_local(base);patch.local_pivot=host.to_local(pivot)
	patch.local_basis=host.global_basis.inverse()*wall_basis
	patch.local_surge=host.global_basis.inverse()*Vector3.UP
	patch.base_position=base;patch.contact_pivot=pivot;patch.rest_basis=wall_basis;patch.outward_world=Vector3.UP
	patch.visual.global_transform=Transform3D(wall_basis,base)
	patch.visual.set_meta("wall_layer_attached",true)
	patch.visual.set_meta("slice_whole",false)
	patch.visual.layers=1
	patch.ink.set_shader_parameter("amplitude",.025)
	if patch.ink.shader!=preload("res://shaders/grid_wall_wave.gdshader"):
		patch.ink.shader=preload("res://shaders/grid_wall_wave.gdshader")
		patch.ink.set_shader_parameter("protect_paper",not layered_waves)
