extends RefCounted
## Real vertical drops collide with terrain, other gourds, and the minimum floor.
const GOURD_LAYER:=1<<4
const GOURD_FLOOR_LAYER:=1<<5

var story:Node3D
func _init(owner_:Node3D) -> void:story=owner_

func install_minimum_floor() -> void:
	# A real, stage-owned safety floor that only the gourds collide with.
	# Its upper surface is the explicit minimum Y; no position clamping.
	var floor_body:=StaticBody3D.new();floor_body.name="GourdMinimumHeightFloor"
	floor_body.collision_layer=GOURD_FLOOR_LAYER;floor_body.collision_mask=GOURD_LAYER
	var collision:=CollisionShape3D.new();var box:=BoxShape3D.new()
	box.size=Vector3(256,.5,256);collision.shape=box;floor_body.add_child(collision)
	story.add_child(floor_body);floor_body.global_position=Vector3(0,story.gourd_minimum_y-.25,0)

func separate(index:int) -> void:
	var bird:Dictionary=story.birds[index]
	if bird.state!="idle":return
	var role:="pending"
	story.normal_selected+=1
	var sprite:Sprite3D=bird.gourd
	var body:=RigidBody3D.new();body.name="FallingGourd"
	body.collision_layer=GOURD_LAYER;body.collision_mask=5|GOURD_LAYER|GOURD_FLOOR_LAYER
	body.lock_rotation=true;body.linear_damp=0;body.contact_monitor=true;body.max_contacts_reported=8;body.continuous_cd=true
	body.physics_material_override=PhysicsMaterial.new()
	body.physics_material_override.friction=.8;body.physics_material_override.bounce=.05
	story.add_child(body);body.global_position=sprite.global_position
	sprite.reparent(body,true)
	# Straight down from the beak: no throw, teleport or retrieval.
	# Once severed, the falling fruit obeys the same map depth as other debris.
	sprite.set_meta("paper_foreground",false);sprite.set_meta("paper_loose_foreground",false)
	sprite.remove_meta("screen_band");sprite.render_priority=0;sprite.sorting_offset=0
	sprite.material_override=null;sprite.no_depth_test=false
	# The layout puts the fruit above a physical landing surface; severing gives
	# no lateral impulse or animated transport. Gravity starts immediately.
	body.linear_velocity=Vector3.ZERO
	var radius:float=story.gourd_width*.48
	var shape:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=radius;shape.shape=sphere;body.add_child(shape)
	var item:Dictionary={"role":role,"body":body,"sprite":sprite,"state":"falling","opened":false,"bird":index,"destination":body.global_position,"landing":bird.landing}
	story.fruits.append(item);bird.item=item;bird.state="watch";bird.time=0.0
	bird.bird_ink.set_shader_parameter("enabled",false)
	bird.fruit_ink.set_shader_parameter("enabled",false)
	bird.fruit_ink.set_shader_parameter("sliced",false)

func tick(delta:float) -> void:
	# Caller gates pause, transitions and input_locked. Start the two-second
	# countdown only once the summoned player is visible and controllable.
	if story.birds.is_empty() or not story.world.player.is_visible_in_tree():return
	if story.carrier_entry_elapsed<story.carrier_entry_delay:
		story.carrier_entry_elapsed+=delta
		if story.carrier_entry_elapsed<story.carrier_entry_delay:return
		delta=story.carrier_entry_elapsed-story.carrier_entry_delay
	for bird:Dictionary in story.birds:
		bird.sprite.speed_scale=story.wing_fps/8.0
		bird.time+=delta
		if bird.state=="waiting":
			if bird.time<bird.delay:continue
			bird.state="entering";bird.time=0.0;bird.sprite.show();bird.gourd.show()
		elif bird.state=="entering":
			var t:float=clampf(bird.time/1.7,0,1)
			bird.sprite.global_position=bird.entry.lerp(bird.target,smoothstep(0,1,t))
			bird.gourd.global_position=bird.sprite.global_position-bird.attachment
			if t>=1:bird.state="idle";bird.time=0.0
		elif bird.state=="idle":
			bird.sprite.global_position=bird.target+Vector3.UP*sin(bird.time*2.8+bird.index*.7)*.16
			bird.gourd.global_position=bird.sprite.global_position-bird.attachment
		elif bird.state=="watch":
			var item:Dictionary=bird.item
			var body:RigidBody3D=item.body
			var settled:bool=body.get_contact_count()>0 and body.linear_velocity.length_squared()<.25
			item["settled_for"]=float(item.get("settled_for",0.0))+delta if settled else 0.0
			if float(item.settled_for)>=.15:
				item.state="ready";item.destination=body.global_position
				# Land first, then use the shared physical paper cutter.
				# Stay dynamic: another gourd can push this one, or its support
				# can be cut away. Shared cut-paper follows the source sprite.
				if item.get("rotten",false):item.state="rotten"
				else:story.prepare_landed_gourd(item)
				bird.state="exit";bird.time=0.0;bird.origin=bird.sprite.global_position
				story.provided+=1
		elif bird.state=="exit":
			var t:float=clampf(bird.time/story.flight_seconds,0,1)
			var back:Vector3=story.camera.global_basis.x*(1 if bird.facing_left else -1)
			bird.sprite.global_position=bird.origin+back*12*t-story.camera.global_basis.z*8*t
			bird.sprite.modulate.a=1-smoothstep(.55,1,t)
			if t>=1:bird.state="gone";bird.sprite.hide()

func sync_bodies() -> void:
	var paused:bool=story.world.paused or story.world.transition.active or story.world.player.input_locked or story.world.completed or story.reset_pending
	for item:Dictionary in story.fruits:
		if item.opened or not is_instance_valid(item.body):continue
		item.body.freeze=paused
		item.destination=item.body.global_position
		if item.state!="ready":continue
		var sprite:Sprite3D=item.sprite
		sprite.set_meta("background_depth",(sprite.global_position-story.camera.global_position).dot(-story.camera.global_basis.z))
		var bottom:Vector3=sprite.global_position-story.camera.global_basis.y*sprite.texture.get_height()*sprite.pixel_size*.5
		var floor_y:float=story._screen(story.camera.unproject_position(bottom)).y+15
		sprite.set_meta("paper_floor_y",floor_y)
		for source:Dictionary in story.sources:
			if source.sprite==sprite:
				source.baseline=floor_y;source.floor.position.y=floor_y+12
