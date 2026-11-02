extends Node3D
## Stage7-only pursuit. The runner uses real floor collisions and jumps the
## authored 0.4m seam; it never interpolates a running actor across empty air.
var story:Node3D
var phase:="emerge"
var elapsed:=0.0
var runner:CharacterBody3D
var animation:AnimatedSprite3D
var waypoint:=0
var path:=PackedVector3Array([Vector3(-2.4,1.8,-1.6),Vector3(-2.4,1.8,.38)])
var origin:=Vector3.ZERO
var last_jump:=-10.0
var hat:Sprite3D
var hat_time:=-1.0
var hat_start:=Vector3.ZERO
var build_origin:=Vector3.ZERO
var air_time:=0.0
var traversed:Array[Vector3]=[]
var look_angle:=0.0
@export var chase_gap:=2.4
const Art=preload("res://scripts/grid_stage/heungbu_art.gd")
const Bridge=preload("res://scripts/grid_stage/heungbu_bridge.gd")
const Minhwa=preload("res://scripts/grid_stage/heungbu_minhwa.gd")

func setup(owner_:Node3D,from:Vector3) -> void:
	story=owner_;origin=from+Vector3.UP*.7
	story._spawn_goblin();story.goblin.global_position=origin
	_face_nolbu(1.0)

func _physics_process(delta:float) -> void:
	if not is_instance_valid(story) or story.locked or story.reset_pending:return
	elapsed+=delta
	if is_instance_valid(animation):animation.speed_scale=1.0 if runner.is_on_floor() else 0.0
	match phase:
		"emerge":
			story.goblin.global_position=origin.lerp(story.nolbu.global_position+Vector3.RIGHT*chase_gap+Vector3.UP*.75,minf(elapsed/1.1,1))
			if elapsed>=1.1:_begin_run()
		"run":
			var target:Vector3=path[waypoint]
			var offset:=Vector3(target.x-runner.global_position.x,0,target.z-runner.global_position.z)
			if offset.length()<.09:
				if waypoint==path.size()-1:_fall();return
				waypoint+=1;target=path[waypoint];offset=Vector3(target.x-runner.global_position.x,0,target.z-runner.global_position.z)
			var direction:=offset.normalized()
			runner.velocity.x=direction.x*1.8;runner.velocity.z=direction.z*1.8
			if runner.is_on_floor():
				runner.velocity.y=0;air_time=0
				var probe:=runner.global_position+direction*.28
				var query:=PhysicsRayQueryParameters3D.create(probe+Vector3.UP*.15,probe-Vector3.UP*.3,1,[runner.get_rid()])
				if runner.get_world_3d().direct_space_state.intersect_ray(query).is_empty() and elapsed-last_jump>.7:
					runner.velocity.y=4.5;last_jump=elapsed
			else:runner.velocity.y-=18*delta;air_time+=delta
			runner.move_and_slide();traversed.append(runner.global_position)
			story.goblin.global_position=_trailing_position()+Vector3.UP*.75
		"fall":
			animation.rotation.z=-minf(elapsed/.4,1)*PI*.5
			if elapsed>=.4:_make_body_bridge()
		"build":
			var destination:Vector3=build_origin+story.camera.global_basis.y*4
			story.goblin.global_position=build_origin.lerp(destination,smoothstep(0,1,minf(elapsed/1.8,1)))
			story.goblin_animation.modulate.a=1-smoothstep(.7,1.8,elapsed)
			if elapsed>=1.8:
				story.goblin.queue_free();story.goblin=null;phase="complete"
				story.chase_complete=true;story.update_path_open()
	_face_nolbu(delta)
	if hat_time>=0:_fly_hat(delta)

func _face_nolbu(delta:float) -> void:
	if not is_instance_valid(story.goblin) or not is_instance_valid(story.goblin_animation):return
	var target:Vector3
	if is_instance_valid(runner) and not runner.is_queued_for_deletion():target=runner.global_position+Vector3.UP*.75
	elif is_instance_valid(story.nolbu):target=story.nolbu.global_position+Vector3.UP*.75
	elif is_instance_valid(story.nolbu_bridge):target=story.nolbu_bridge.global_position
	else:return
	var offset:Vector3=target-story.goblin.global_position
	var horizontal:float=offset.dot(story.camera.global_basis.x)
	var vertical:float=offset.dot(story.camera.global_basis.y)
	if absf(horizontal)+absf(vertical)<.02:return
	var actor:AnimatedSprite3D=story.goblin_animation
	if absf(horizontal)>.03:actor.flip_h=horizontal<0
	var desired:float=atan2(vertical,maxf(absf(horizontal),.001))*(-1.0 if actor.flip_h else 1.0)
	look_angle=lerp_angle(look_angle,desired,1.0-exp(-12.0*delta))
	actor.global_basis=story.camera.global_basis*Basis(Vector3.BACK,look_angle)

func _trailing_position() -> Vector3:
	# Follow the same travelled path at a fixed distance, including its corner.
	# Chasing the runner's current direction cuts the corner and closes the gap.
	var remaining:=chase_gap
	var point:=runner.global_position
	for index:int in range(traversed.size()-2,-1,-1):
		var previous:=traversed[index]
		var length:=Vector2(point.x-previous.x,point.z-previous.z).length()
		if length>=remaining:return point.lerp(previous,remaining/length)
		remaining-=length;point=previous
	return point+Vector3.RIGHT*remaining

func _begin_run() -> void:
	phase="run";elapsed=0
	story.remove_blocker(story.nolbu_block)
	runner=CharacterBody3D.new();runner.name="NolbuRunner";runner.collision_layer=0;runner.collision_mask=1;runner.floor_snap_length=.23
	add_child(runner);runner.global_position=story.nolbu.global_position+Vector3.UP*.04
	var collision:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.15;capsule.height=1.2;collision.shape=capsule;collision.position.y=.6;runner.add_child(collision)
	animation=AnimatedSprite3D.new();animation.sprite_frames=Minhwa.frames("run")
	animation.pixel_size=story.nolbu_height/400.0;animation.offset=Vector2(0,280);animation.flip_h=false
	story._above_clouds(animation);runner.add_child(animation);animation.global_basis=story.camera.global_basis;animation.play()
	story.nolbu.hide()

func _fall() -> void:
	phase="fall";elapsed=0;runner.velocity=Vector3.ZERO;animation.stop()

func _make_body_bridge() -> void:
	if is_instance_valid(story.nolbu_bridge):return
	var texture:Texture2D=Minhwa.texture("prone")
	story.nolbu_bridge=Bridge.create(story,"NolbuBodyBridge",Vector3(-2.4,0,2.6),Vector3(-2.4,1.8,.6),1.15,texture)
	runner.queue_free();animation=null;story.nolbu.queue_free();story.nolbu=null
	# UV y=.78 is the head in the supplied overhead prone artwork, not its
	# transparent bounding-box edge. Hat launch follows this actual surface.
	hat_start=Vector3(-2.4,0,2.6).lerp(Vector3(-2.4,1.8,.6),.22)+Vector3.UP*.06
	hat=story._extra_art("검은갓.png",.65,hat_start,"FlyingBlackHat");hat.offset.y=0;hat_time=0
	build_origin=story.goblin.global_position;elapsed=0;phase="build"

func _fly_hat(delta:float) -> void:
	hat_time+=delta
	var t:=minf(hat_time/1.7,1)
	var destination:Vector3=story.heungbu.global_position+story.camera.global_basis.y*story.heungbu_height*.89
	hat.global_position=hat_start.lerp(destination,smoothstep(0,1,t))+Vector3.UP*sin(PI*t)*1.5
	if t>=1:
		story.set_heungbu("hatted");hat.queue_free();hat=null;hat_time=-1
