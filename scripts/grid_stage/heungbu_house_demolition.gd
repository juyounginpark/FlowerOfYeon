extends Node3D
## Four staggered arrivals, frame-synchronized hits, physical loose props,
## and one explicitly choreographed bridge flight. Owned by the stage root.
const Art=preload("res://scripts/grid_stage/heungbu_minhwa.gd")
const Bridge=preload("res://scripts/grid_stage/heungbu_bridge.gd")
const FLIGHT_SECONDS:=1.8
const SMASH_SECONDS:=4.8
const BRIDGE_SECONDS:=2.4
const BRIDGE_A:=Vector3(2,1.8,-2.2)
const BRIDGE_B:=Vector3(2,3.6,-4.2)
var story:Node3D
var origin:=Vector3.ZERO
var elapsed:=0.0
var actors:Array[AnimatedSprite3D]=[]
var debris:Array[RigidBody3D]=[]
var dust:Array[Dictionary]=[]
var hits:=0
var launched:=false
var finished:=false
var bridge_time:=0.0
var bridge_visual:MeshInstance3D
var bridge_destination:=Transform3D.IDENTITY
var bridge_origin:=Vector3.ZERO
var house_rest_position:=Vector3.ZERO
var shake_remaining:=0.0
var shake_direction:=1.0
const SHAKE_SECONDS:=.24

func setup(owner_:Node3D,point:Vector3) -> void:
	story=owner_;origin=point+Vector3.UP*.45
	house_rest_position=story.house.global_position
	for index:int in 4:
		var actor:=AnimatedSprite3D.new();actor.name="HouseDokkaebi%d"%index
		actor.sprite_frames=Art.demolition_frames(index);actor.pixel_size=2.2/256.0
		Art.style_goblin(actor)
		actor.shaded=false;add_child(actor);actor.global_basis=story.camera.global_basis
		actor.global_position=origin;actor.hide();actors.append(actor)
		actor.frame_changed.connect(_on_strike.bind(index))

func _physics_process(delta:float) -> void:
	if not is_instance_valid(story):return
	var paused:bool=story.locked or story.reset_pending or story.world.paused or story.world.transition.active
	for actor:AnimatedSprite3D in actors:actor.speed_scale=0 if paused else 1
	for body:RigidBody3D in debris:body.freeze=paused
	if paused:return
	elapsed+=delta
	_update_house_shake(delta)
	_update_dust(delta)
	for index:int in actors.size():
		var actor:AnimatedSprite3D=actors[index]
		var age:float=elapsed-index*.18
		if age<0:continue
		var target:Vector3=story.house_impact_point()+story.camera.global_basis.x*(index-1.5)*1.05+story.camera.global_basis.y*(.2 if index%2==0 else .9)
		actor.flip_h=index>=2
		if age<FLIGHT_SECONDS:
			if not actor.visible:actor.show();actor.play("fly")
			var t:float=age/FLIGHT_SECONDS
			actor.global_position=origin.lerp(target,smoothstep(0,1,t))+Vector3.UP*sin(PI*t)*(1.2+index*.3)
			actor.scale=Vector3.ONE*lerpf(.35,1,t)
		elif not launched:
			actor.global_position=target;actor.scale=Vector3.ONE
			if actor.animation!="smash":actor.play("smash")
		else:
			actor.play("fly")
			actor.global_position+=story.camera.global_basis.y*delta*2+story.camera.global_basis.x*(index-1.5)*delta
			actor.modulate.a=maxf(0,actor.modulate.a-delta*.5)
	if not launched and elapsed>=FLIGHT_SECONDS+.54+SMASH_SECONDS:
		story.collapse_house();_launch_bridge()
	if launched and not finished:_advance_bridge(delta)

func _on_strike(index:int) -> void:
	var actor:AnimatedSprite3D=actors[index]
	if actor.animation!="smash" or actor.frame!=2 or launched:return
	if story.locked or story.reset_pending or story.world.paused or story.world.transition.active:return
	hits+=1
	shake_remaining=SHAKE_SECONDS;shake_direction=-1.0 if index>=2 else 1.0
	# Keep every damage stage visible for several club strikes. The last
	# collapse remains synchronized with the launch of the bridge prop.
	story.set_house_damage(mini(3,hits/9))
	var point:Vector3=actor.global_position+story.camera.global_basis.x*(-.65 if actor.flip_h else .65)-story.camera.global_basis.y*.3
	for puff:int in 3:_emit_dust(point,puff)
	# One object per several impacts; all five variants are used before collapse.
	if hits%3==0:_emit_junk((hits/3-1)%5,point)

func _update_house_shake(delta:float) -> void:
	if shake_remaining<=0:return
	shake_remaining=maxf(0,shake_remaining-delta)
	if shake_remaining<=0:
		story.house.global_position=house_rest_position
		return
	var age:float=SHAKE_SECONDS-shake_remaining
	# About 2.5 screen pixels: a small visual recoil, never moving colliders.
	var amplitude:float=story.camera.size/maxf(1,get_viewport().get_visible_rect().size.y)*2.5
	var x:float=sin(age*65)*exp(-age*15)*amplitude*shake_direction
	var y:float=sin(age*90)*exp(-age*20)*amplitude*.25
	story.house.global_position=house_rest_position+story.camera.global_basis.x*x+story.camera.global_basis.y*y

func _emit_dust(point:Vector3,index:int) -> void:
	var visual:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(1.8,.9);visual.mesh=quad
	var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/heungbu_demolition_dust.gdshader")
	ink.set_shader_parameter("cloud_image",load("res://art/dummys/DummyCloud_%d.png"%((hits+index)%8+1)))
	visual.material_override=ink
	add_child(visual);visual.global_basis=story.camera.global_basis
	visual.global_position=point+story.camera.global_basis.z*.05
	dust.append({"visual":visual,"ink":ink,"age":0.0,"velocity":story.camera.global_basis.x*randf_range(-1.2,1.2)+story.camera.global_basis.y*randf_range(.4,1.3)})

func _update_dust(delta:float) -> void:
	for puff:Dictionary in dust.duplicate():
		puff.age+=delta;puff.visual.global_position+=puff.velocity*delta
		puff.visual.scale=Vector3.ONE*(.4+puff.age*1.1)
		puff.ink.set_shader_parameter("opacity",.68*maxf(0,1-puff.age/1.7))
		if puff.age>=1.7:puff.visual.queue_free();dust.erase(puff)

func _emit_junk(index:int,point:Vector3) -> void:
	var body:=RigidBody3D.new();body.name="HouseJunk%d"%index
	body.collision_layer=0;body.collision_mask=5;body.continuous_cd=true
	body.physics_material_override=PhysicsMaterial.new();body.physics_material_override.bounce=.25
	add_child(body);body.global_position=point
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.25,.3,.2);shape.shape=box;body.add_child(shape)
	var visual:=MeshInstance3D.new();var quad:=QuadMesh.new();var texture:=Art.junk(index)
	quad.size=Vector2(.6*texture.get_width()/float(texture.get_height()),.6);visual.mesh=quad
	var ink:=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;ink.cull_mode=BaseMaterial3D.CULL_DISABLED;ink.albedo_texture=texture
	visual.material_override=ink;body.add_child(visual);visual.global_basis=story.camera.global_basis
	# Meshes keep the normal per-fragment map compositor and depth testing.
	body.linear_velocity=story.camera.global_basis.x*randf_range(-3,3)+Vector3.UP*randf_range(3,5)+story.camera.global_basis.z*randf_range(2,4)
	body.angular_velocity=Vector3(randf_range(-2,2),randf_range(-2,2),randf_range(-4,4));debris.append(body)

func _launch_bridge() -> void:
	launched=true
	story.goblin_bridge=Bridge.create(story,"HouseWritingTabletBridge",BRIDGE_A,BRIDGE_B,1.25,Art.junk(4),true)
	story.goblin_bridge.collision_layer=0
	bridge_visual=story.goblin_bridge.get_node("BridgeSurface")
	bridge_destination=bridge_visual.global_transform
	bridge_origin=story.house_impact_point()
	bridge_visual.global_transform=Transform3D(story.camera.global_basis.scaled(Vector3.ONE*.12),bridge_origin)
	bridge_visual.rotation.z=-.5

func _advance_bridge(delta:float) -> void:
	bridge_time+=delta
	var t:float=clampf(bridge_time/BRIDGE_SECONDS,0,1)
	var eased:float=smoothstep(0,1,t)
	# A magical intact prop grows from the distant house into the real map.
	var turn:Quaternion=Quaternion(story.camera.global_basis).slerp(Quaternion(bridge_destination.basis),eased)
	bridge_visual.global_transform=Transform3D(Basis(turn).scaled(Vector3.ONE*lerpf(.12,1,eased)),bridge_origin.lerp(bridge_destination.origin,eased)+Vector3.UP*sin(PI*t)*2)
	if t>=1:
		bridge_visual.global_transform=bridge_destination
		story.goblin_bridge.collision_layer=1;finished=true
		story.update_path_open()
