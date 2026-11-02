extends Node3D
# Two image halves hinge around the original image's vertical centreline.
const IMAGE=preload("res://art/minhwa/butterfly/guide.png")
const CLEARANCE:=1.65
var world:GridStageWorld
var wings:Array[Node3D]=[]
var body:Node3D
var route:=PackedVector3Array()
var cursor:=0
var flying:=false
var arrived:=false
var clock:=0.0
var anchor:=Vector3.ZERO
var start_anchor:=Vector3.ZERO
var goal_anchor:=Vector3.ZERO
var trail:CPUParticles3D
var flight_heading:=Vector3.FORWARD
var state:="entering"
var state_time:=0.0
var motion_origin:=Vector3.ZERO
var offscreen:=Vector3.ZERO
var departure_ready:=false
const EXIT_SPEECH = preload("res://scripts/grid_stage/speech_bubble.gd")
var exit_speech: EXIT_SPEECH
var exit_guidance := false
var contact_tutorial_finished:=false
func configure(owner_world:GridStageWorld) -> void:
	world=owner_world
	if world.stage_number==12:
		var speech_layer := CanvasLayer.new();speech_layer.layer=8;add_child(speech_layer)
		exit_speech=EXIT_SPEECH.new();speech_layer.add_child(exit_speech)
		exit_speech.size=Vector2(420,128);exit_speech.body.size=Vector2(356,83)
	body=Node3D.new();add_child(body);body.rotation.x=-PI*.5
	for side in [-1,1]:
		var hinge:=Node3D.new();body.add_child(hinge);wings.append(hinge)
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var left:float=-.46 if side<0 else 0.0
		var uv_left:float=0.0 if side<0 else .5
		var points:=[Vector2(left,-.307),Vector2(left+.46,-.307),Vector2(left+.46,.307),Vector2(left,.307)]
		var uvs:=[Vector2(uv_left,1),Vector2(uv_left+.5,1),Vector2(uv_left+.5,0),Vector2(uv_left,0)]
		for index in [0,1,2,0,2,3]:
			surface.set_uv(uvs[index]);surface.add_vertex(Vector3(points[index].x,points[index].y,0))
		var mesh:=MeshInstance3D.new();mesh.mesh=surface.commit()
		var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/grid_story_sprite.gdshader")
		ink.set_shader_parameter("illustration",IMAGE);ink.render_priority=116
		mesh.material_override=ink;mesh.set_meta("story_actor",true)
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;hinge.add_child(mesh)
	_build_route()
	anchor=start_anchor;position=anchor
	cursor=0
	_create_trail()
	motion_origin=_outside_screen(false,start_anchor)
	anchor=motion_origin;position=anchor
func _outside_screen(leaving:bool,reference:Vector3) -> Vector3:
	var frame:=get_viewport().get_visible_rect().size
	var screen:=Vector2(frame.x+180,-160) if leaving else Vector2(-180,frame.y*.3)
	var depth:float=(world.camera.global_position-reference).dot(world.camera.global_basis.z)
	return world.camera.project_position(screen,maxf(depth,1))
func finish_contact_tutorial() -> void:
	# Stage1's visible message owns this transition, not an independent flight timer.
	if world.stage_number!=4 or state!="tutorial":return
	contact_tutorial_finished=true
	flying=true;state="guiding";state_time=0

func begin_departure() -> void:
	if world.stage_number==4 and not contact_tutorial_finished:return
	if state in ["departing","gone"]:return
	state="departing";state_time=0;motion_origin=position
	offscreen=_outside_screen(true,position+Vector3.UP*1.8)
	flying=true;arrived=false
func begin_roaming() -> void:
	state="roaming";state_time=0;motion_origin=anchor
	flying=true;arrived=false
func guide_to_exit() -> void:
	exit_guidance=true
	var goal: Vector2 = world.stage_data.goal_rect.get_center()
	goal_anchor=Vector3(goal.x,world.stage_data.goal_height+CLEARANCE,goal.y)
	route.clear();route.append(goal_anchor);cursor=0
	state="guiding";state_time=0;flying=true;arrived=false

func _update_exit_speech() -> void:
	if exit_speech==null:return
	exit_speech.blocked=world.paused or world.transition.active
	if exit_speech.visible:
		exit_speech.place(world.camera.unproject_position(global_position+world.camera.global_basis.y*.35))
func _create_trail() -> void:
	trail=CPUParticles3D.new();trail.name="GoldenDustTrail"
	trail.amount=64;trail.lifetime=1.35;trail.local_coords=false
	trail.emitting=false;trail.position=Vector3(0,0,.16)
	trail.direction=Vector3(0,.3,1);trail.spread=50
	trail.initial_velocity_min=.08;trail.initial_velocity_max=.25
	trail.gravity=Vector3(0,-.12,0);trail.damping_min=.3;trail.damping_max=.7
	trail.scale_amount_min=.4;trail.scale_amount_max=1.2
	var fade:=Gradient.new();fade.set_color(0,Color(1,1,1,.9));fade.set_color(1,Color(1,1,1,0))
	trail.color_ramp=fade
	var quad:=QuadMesh.new();quad.size=Vector2(.18,.18);trail.mesh=quad
	var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/grid_butterfly_spark.gdshader")
	ink.render_priority=114;trail.material_override=ink
	trail.set_meta("story_actor",true);trail.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)
func _build_route() -> void:
	# Sample actual terrace footprints and lift footprints, not a straight line through the map.
	var cells:Dictionary={}
	for box:Array in world.stage_data.low+world.stage_data.raised:
		for x in range(box[0].x,box[1].x):
			for z in range(box[0].z,box[1].z):
				var key:=Vector2i(x,z)
				cells[key]=maxf(float(cells.get(key,-1000)),box[1].y*.2)
	for origin:Vector3 in world.stage_data.lifts:
		var center:=Vector2i(roundi(origin.x*5),roundi(origin.z*5))
		for x in range(-4,4):
			for z in range(-4,4):
				var key:=center+Vector2i(x,z)
				if not cells.has(key):cells[key]=origin.y
	# Include the intended tree crossings in guidance, without adding platforms.
	for span:Array in world.stage_data.get("tree_routes",[])+world.stage_data.get("bridge_routes",[]):
		for step:int in range(41):
			var point:Vector3=span[0].lerp(span[1],float(step)/40.0)
			var key:=Vector2i(floori(point.x*5),floori(point.z*5))
			if not cells.has(key):cells[key]=point.y
	# Stage8's removed pillar is replaced by the authored bird-bridge route.
	# Sample the planned spans so guidance still connects before they are built.
	for span:Array in world.stage_data.get("bird_bridges",[])+world.stage_data.get("sea_bridges",[]):
		var a:Vector3=span[0];var b:Vector3=span[1]
		var steps:=ceili(a.distance_to(b)/.1)
		for step in range(steps+1):
			var point:Vector3=a.lerp(b,float(step)/steps)
			var key:=Vector2i(floori(point.x*5),floori(point.z*5))
			cells[key]=maxf(float(cells.get(key,-1000)),point.y)

	# Planned nose fragments replace Stage4's lift footprints in the guide route.
	for endpoints:Array in world.stage_data.get("nose_bridges",[]):
		var a:Vector3=endpoints[0];var b:Vector3=endpoints[1]
		for step in range(41):
			var point:=a.lerp(b,float(step)/40.0)
			cells[Vector2i(floori(point.x*5),floori(point.z*5))]=point.y
	var graph:=AStar3D.new();var ids:Dictionary={}
	for key:Vector2i in cells:
		var id:=ids.size();ids[key]=id
		graph.add_point(id,Vector3((key.x+.5)*.2,cells[key],(key.y+.5)*.2))
	for key:Vector2i in ids:
		for dx in range(-3,4):
			for dz in range(-3,4):
				var other:=key+Vector2i(dx,dz)
				if not ids.has(other) or int(ids[other])<=int(ids[key]):continue
				if Vector2(dx,dz).length()>3.05 or absf(cells[key]-cells[other])>1.81:continue
				graph.connect_points(ids[key],ids[other])
	var goal:Vector2=world.stage_data.goal_rect.get_center()
	var destination:Vector3=world.stage_data.get("guide_goal",Vector3(goal.x,world.stage_data.goal_height,goal.y))
	goal_anchor=destination+Vector3.UP*CLEARANCE
	var path:=graph.get_point_path(graph.get_closest_point(world.start_position),graph.get_closest_point(goal_anchor-Vector3.UP*CLEARANCE))
	if path.is_empty() and world.stage_data.get("guide_can_cross_gap",false):
		# Stage1 intentionally has no connecting lift; only the flying guide crosses.
		path=PackedVector3Array([world.start_position,goal_anchor-Vector3.UP*CLEARANCE])
	assert(not path.is_empty(),"Butterfly route must connect the start to the goal")
	var travelled:=0.0;var begin:=0
	for i in range(1,path.size()):
		travelled+=path[i-1].distance_to(path[i]);begin=i
		if travelled>=1.5:break
	# Waiting height belongs to this floor, not the higher terrace anticipated in flight.
	start_anchor=path[begin]+Vector3.UP*CLEARANCE
	for i in range(begin,path.size()):
		var point:Vector3=path[i]
		# Anticipate raised edges so the wings clear terrace walls while climbing.
		for j in range(maxi(begin,i-3),mini(path.size(),i+4)):point.y=maxf(point.y,path[j].y)
		route.append(point+Vector3.UP*CLEARANCE)
	route.append(goal_anchor)
func _process(delta:float) -> void:
	if world==null:return
	var frozen:bool=world.paused or (world.transition.active and (state!="entering" or world.transition.phase=="book"))
	trail.speed_scale=0.0 if frozen else 1.0
	if frozen:
		_update_exit_speech()
		return
	clock+=delta;state_time+=delta
	if state=="gone":return
	if state=="perched":
		trail.emitting=false;position=anchor
		wings[0].rotation.y=.18;wings[1].rotation.y=-.18
		body.rotation=Vector3(-PI*.5,0,0)
		_update_exit_speech()
		return
	var fold:=.22+(sin(clock*TAU*3.2)+1)*.5*1.12
	wings[0].rotation.y=fold;wings[1].rotation.y=-fold
	body.rotation.z=sin(clock*6.0)*(.18 if flying else .08)
	body.rotation.x=-PI*.5+sin(clock*4.2)*.09
	var previous:=anchor
	var flutter:=1.0
	match state:
		"entering":
			var t:=clampf(state_time/2.8,0,1)
			anchor=motion_origin.bezier_interpolate(motion_origin+world.camera.global_basis.x*4+Vector3.UP*1.5,start_anchor-world.camera.global_basis.x*1.2+Vector3.UP*.6,start_anchor,smoothstep(0,1,t))
			flutter=1-t*.8
			if t>=1:
				anchor=start_anchor;state_time=0
				flying=bool(world.stage_data.get("guide_immediate",false))
				state="guiding" if flying else "waiting"
		"waiting":
			var offset:=world.player.position-anchor;offset.y=0
			var contact_radius:=.65 if world.stage_number==4 else 1.05
			var contact_height:=.65 if world.stage_number==4 else 1.5
			if offset.length()<contact_radius and absf(world.player.position.y-(anchor.y-CLEARANCE))<contact_height:
				if world.stage_number==4:state="tutorial";state_time=0
				else:flying=true;state="guiding";state_time=0
		"tutorial":
			# Hover here until the on-screen instruction finishes its full display.
			flying=false
		"guiding":
			var distance:=delta*2.05
			while cursor<route.size() and distance>0:
				var remaining:=anchor.distance_to(route[cursor])
				if remaining<=distance:anchor=route[cursor];cursor+=1;distance-=remaining
				else:anchor=anchor.move_toward(route[cursor],distance);distance=0
			if cursor>=route.size():state="landing";state_time=0;motion_origin=position;flying=false
		"roaming":
			var screen := Vector2(.29+sin(clock*1.1)*.045,.18+sin(clock*1.7)*.035)
			var target := world.camera.project_position(screen*get_viewport().get_visible_rect().size,20.0)
			anchor=motion_origin.lerp(target,smoothstep(0,1,clampf(state_time/1.7,0,1)))
		"landing":
			var t:=smoothstep(0,1,clampf(state_time/1.1,0,1))
			anchor=motion_origin.lerp(goal_anchor-Vector3.UP*(CLEARANCE-.04),t)
			flutter=1-t
			wings[0].rotation.y=lerpf(fold,.18,t);wings[1].rotation.y=-wings[0].rotation.y
			body.rotation.z*=1-t;body.rotation.x=lerpf(body.rotation.x,-PI*.5,t)
			if t>=1:
				state="perched";arrived=true;state_time=0
				if exit_guidance and exit_speech!=null:
					exit_guidance=false
					exit_speech.present("나비","깨달음을 얻었느냐, 이무기여. 용이 될 준비를 마쳤나니.")
		"departing":
			var t:=clampf(state_time/2.5,0,1)
			anchor=motion_origin.bezier_interpolate(motion_origin+Vector3.UP*3,motion_origin+Vector3.UP*4+world.camera.global_basis.x*5,offscreen,t*t)
			flutter=minf(state_time*2,1)
			if t>=1:
				state="gone";departure_ready=true;flying=false;trail.emitting=false;hide()
				if exit_speech!=null:exit_speech.close()
				return
	var direction:=anchor-previous
	if Vector2(direction.x,direction.z).length()>.001:
		flight_heading=flight_heading.lerp(Vector3(direction.x,0,direction.z).normalized(),minf(delta*5,1)).normalized()
		rotation.y=lerp_angle(rotation.y,atan2(-direction.x,-direction.z),minf(delta*6,1))
	trail.emitting=state in ["entering","guiding","departing","roaming"]
	var hover:=Vector3(sin(clock*1.5)*.045,sin(clock*3)*.10,cos(clock*1.3)*.035)
	if state in ["entering","guiding","departing","roaming"]:
		var sideways:=flight_heading.cross(Vector3.UP).normalized()
		hover+=sideways*(sin(clock*5.4)*.17+sin(clock*9.1)*.035)
		hover.y+=sin(clock*8.3)*.075
	position=anchor+hover*flutter
	_update_exit_speech()
