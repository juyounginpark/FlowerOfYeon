extends Node3D
## Stage-local failure effect; every scattered object has gravity and map collision.
const Art=preload("res://scripts/grid_stage/heungbu_minhwa.gd")
const BURST_COLUMNS:=12
const BURST_ROWS:=6
const BURST_COUNT:=BURST_COLUMNS*BURST_ROWS
const FLY_COUNT:=7
const RESTART_AFTER:=5.5
var story:Node3D
var origin:=Vector3.ZERO
var elapsed:=0.0
var emitted:=0
var debris:Array[RigidBody3D]=[]
var flies:Array[AnimatedSprite3D]=[]
var restarting:=false
var burst_targets:Array[Vector2]=[]

func setup(owner_:Node3D,point:Vector3) -> void:
	story=owner_;origin=point
	# Cover the whole viewport in shuffled cells rather than a small local ring.
	for row:int in BURST_ROWS:
		for column:int in BURST_COLUMNS:
			burst_targets.append(Vector2((column+randf_range(.1,.9))/BURST_COLUMNS,(row+randf_range(.1,.9))/BURST_ROWS))
	burst_targets.shuffle()
	for index:int in FLY_COUNT:
		var fly:=AnimatedSprite3D.new();fly.name="Fly%d"%index
		fly.sprite_frames=Art.frames("fly");fly.pixel_size=.28/300.0
		fly.shaded=false;fly.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		add_child(fly);fly.global_position=origin;fly.play();fly.frame=index%3
		flies.append(fly)

func _physics_process(delta:float) -> void:
	if not is_instance_valid(story) or restarting:return
	var paused:bool=story.world.paused or story.world.transition.active
	for body:RigidBody3D in debris:body.freeze=paused
	for fly:AnimatedSprite3D in flies:fly.speed_scale=0 if paused else 1
	if paused:return
	elapsed+=delta
	while emitted<BURST_COUNT and elapsed>=emitted*.025:
		_emit_piece(emitted);emitted+=1
	for index:int in flies.size():
		var phase:float=TAU*index/FLY_COUNT
		var orbit:=Vector3(cos(elapsed*3.1+phase)*(1+index*.18),.7+sin(elapsed*5.7+phase)*.45,sin(elapsed*3.9+phase)*1.1)
		var buzz:=Vector3(sin(elapsed*39+phase),cos(elapsed*43+phase),sin(elapsed*33+phase))*.075
		flies[index].global_position=origin+orbit+buzz
		flies[index].flip_h=cos(elapsed*3.1+phase)<0
	if elapsed>=RESTART_AFTER:
		restarting=true
		story.world.call_deferred("restart")

func _emit_piece(index:int) -> void:
	var body:=RigidBody3D.new();body.name="ScatteredDung%d"%index
	body.collision_layer=0;body.collision_mask=5;body.linear_damp=0;body.continuous_cd=true
	body.linear_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
	body.physics_material_override=PhysicsMaterial.new();body.physics_material_override.bounce=.3
	add_child(body);body.global_position=origin+Vector3.UP*.15
	var width:float=randf_range(1.0,1.8)
	var collision:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=width*.22
	collision.shape=sphere;body.add_child(collision)
	var sprite:=Sprite3D.new();sprite.texture=Art.texture("dung%d"%(index%3))
	sprite.pixel_size=width/sprite.texture.get_width();sprite.shaded=false
	# Requested foreground splatter; only drawing order changes, not physics.
	sprite.set_meta("paper_foreground",true)
	sprite.no_depth_test=true;sprite.render_priority=127;sprite.sorting_offset=1000
	sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED;body.add_child(sprite)
	var view:Camera3D=story.camera
	var depth:float=maxf(view.near+.5,(origin-view.global_position).dot(-view.global_basis.z)+randf_range(-1,1))
	var target:Vector3=view.project_position(burst_targets[index]*get_viewport().get_visible_rect().size,depth)
	var flight:float=randf_range(.65,1.05)
	var gravity:Vector3=Vector3(ProjectSettings.get_setting("physics/3d/default_gravity_vector",Vector3.DOWN))*float(ProjectSettings.get_setting("physics/3d/default_gravity",9.8))
	# Set the initial ballistic velocity only; real gravity and terrain contacts
	# control the subsequent flight, bounce and fall of every scattered piece.
	body.linear_velocity=(target-body.global_position-gravity*.5*flight*flight)/flight
	body.angular_velocity=Vector3(randf_range(-4,4),randf_range(-3,3),randf_range(-4,4))
	debris.append(body)
