extends Node3D
# Stage3: 45% per deliberate sea jump, guaranteed by the fourth attempt.
# Walking falls respawn normally; both creature bridges persist through falls.
const ART:="res://art/minhwa/stage3_sea/"
const SEA_Y:=-.22
const BRIDGE_CHANCE:=.45
const ANIMALS_PER_SPAN:=8
const LEAP_SECONDS:=1.25
const CLOUD_SECONDS:=1.8
const CLOUD_TINTS:=[Color("171727"),Color("294c80"),Color("202735"),Color("3c5790")]
const CLOUD_LAYOUT:=[Vector3(.49,.14,.36),Vector3(.23,.28,.25),Vector3(.57,.25,.30),Vector3(.40,.35,.31),Vector3(.69,.34,.31),Vector3(.22,.44,.27),Vector3(.56,.39,.25),Vector3(.47,.46,.34),Vector3(.79,.45,.30),Vector3(.62,.56,.36)]
var world:GridStageWorld
var camera:Camera3D
var path_open:=false
var bridge_state:="waiting"
var bridge_clock:=0.0
var cloud_clock:=0.0
var cloud_drift_clock:=0.0
var clouds:Array[Dictionary]=[]
var creatures:Array[Dictionary]=[]
var bridges:Array[StaticBody3D]=[]
var rng:=RandomNumberGenerator.new()
var jump_pending:=false
var eligible_entries:=0
var rescue_count:=0
var on_creature_bridge:=false
var last_safe:=Vector3.ZERO
var rescue_state:="idle"
var rescue_clock:=0.0
var rescue_origin:=Vector3.ZERO
var rescue_target:=Vector3.ZERO
var cruise_height:=0.0
var previous_lock:=false
var lotus:AnimatableBody3D
var lotus_picture:Sprite3D
var lotus_shape:CollisionShape3D
var textures:Dictionary={}

func configure(owner_world:GridStageWorld) -> void:
	world=owner_world;camera=world.camera;last_safe=world.start_position
	process_physics_priority=10
	rng.randomize()
	for id:String in ["lotus","fish","turtle"]:textures[id]=load(ART+id+".png")
	world.player.jumped.connect(_on_jump)
	_setup_lotus()
	_setup_clouds()

func _picture(id:String,texture:Texture2D,width:float,parent:Node=null) -> Sprite3D:
	if parent==null:parent=self
	var sprite:=Sprite3D.new();sprite.name=id;sprite.texture=texture
	sprite.pixel_size=width/texture.get_width()
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.set_meta("story_actor",true)
	var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/grid_story_sprite.gdshader")
	ink.set_shader_parameter("illustration",texture);sprite.material_override=ink
	parent.add_child(sprite);sprite.global_basis=camera.global_basis
	return sprite

func _setup_lotus() -> void:
	lotus=AnimatableBody3D.new();lotus.name="RescueLotus";lotus.collision_layer=4;lotus.collision_mask=2
	lotus.sync_to_physics=false;add_child(lotus)
	lotus_shape=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(1.35,.12,1.1)
	lotus_shape.shape=shape;lotus_shape.position.y=-.06;lotus_shape.disabled=true;lotus.add_child(lotus_shape)
	lotus_picture=_picture("LotusBloom",textures.lotus,2.2,lotus)
	lotus_picture.position=-camera.global_basis.y*.03;lotus.hide()

func _setup_clouds() -> void:
	var frame:=get_viewport().get_visible_rect().size
	var depth:float=camera.global_position.distance_to(world.stage_data.focus)
	var width:=camera.size*frame.aspect()
	# Three staggered clouds per authored patch keep the same vertical region.
	# Whole sprites in the final band avoid translucent strip overlap seams.
	for i in range(CLOUD_LAYOUT.size()*3):
		var entry:Vector3=CLOUD_LAYOUT[i%CLOUD_LAYOUT.size()]
		var texture:Texture2D=load("res://art/dummys/DummyCloud_%d.png"%(i%8+1))
		var source:=texture.get_image()
		if source.is_compressed():source.decompress()
		var painted:=source.get_used_rect()
		var cloud:=_picture("Stage3Cloud%d"%i,texture,width*entry.z*texture.get_width()/maxf(1,painted.size.x))
		cloud.remove_meta("story_actor")
		cloud.set_meta("screen_band",11)
		cloud.no_depth_test=true
		cloud.render_priority=127
		var ink:=ShaderMaterial.new()
		ink.shader=preload("res://shaders/stage3_storm_cloud.gdshader")
		ink.render_priority=127
		ink.set_shader_parameter("illustration",texture)
		cloud.material_override=ink
		var opacity:=lerpf(.46,.28,inverse_lerp(.25,.36,entry.z))
		cloud.material_override.set_shader_parameter("ink_tint",CLOUD_TINTS[i%CLOUD_TINTS.size()])
		cloud.material_override.set_shader_parameter("opacity",opacity)
		var correction:=Vector2(texture.get_size())*.5-Vector2(painted.get_center())
		cloud.offset=Vector2(correction.x,-correction.y)
		var copy_index:int=i/CLOUD_LAYOUT.size()
		var anchor:=Vector2(wrapf(entry.x+copy_index*.6,-.4,1.4),entry.y)
		cloud.global_position=camera.project_position(anchor*frame,depth)
		clouds.append({"sprite":cloud,"anchor":anchor,"width":entry.z,"speed":.025+float(i%5)*.004,"opacity":opacity})

func _on_jump() -> void:
	if rescue_state=="idle":jump_pending=true

func _physics_process(delta:float) -> void:
	if world.paused or world.transition.active:return
	_advance_bridge(delta)
	_update_bridge_audio()
	_advance_clouds(delta)
	if rescue_state!="idle":
		_advance_rescue(delta);return
	var player:=world.player
	if player.input_locked:return
	if player.is_on_floor():
		# Store only supported feet; walking off never qualifies as a jump.
		last_safe=player.global_position;jump_pending=false
	elif player.global_position.y<=SEA_Y and player.velocity.y<0:
		_begin_rescue()

func _update_bridge_audio() -> void:
	var on_bridge:=false
	if world.player.is_on_floor():
		for i in range(world.player.get_slide_collision_count()):
			var collision:=world.player.get_slide_collision(i)
			if bridges.has(collision.get_collider()) and collision.get_normal().dot(Vector3.UP)>.5:
				on_bridge=true;break
	if on_bridge and not on_creature_bridge:
		BgmPlayer.stop_water_up()
		BgmPlayer.play_fish_splash()
	on_creature_bridge=on_bridge

func respawn() -> void:
	# The shared fall threshold follows route height, so upper terraces can
	# signal a fall while still above water. Wait for actual descending entry.
	# Repeated signals cannot reroll the chance or restart an active rescue.
	if rescue_state=="idle" and world.player.global_position.y<=SEA_Y and world.player.velocity.y<0:
		_begin_rescue()

func _begin_rescue() -> void:
	if rescue_state!="idle":return
	BgmPlayer.play_water_splash()
	var eligible:=jump_pending;jump_pending=false
	if not eligible:
		if is_instance_valid(world.dialogue):world.dialogue.cancel()
		world.player.position=world.start_position
		world.player.velocity=Vector3.ZERO
		last_safe=world.player.global_position
		return
	rescue_count+=1
	if bridge_state=="waiting":
		eligible_entries+=1
		if eligible_entries>=4 or rng.randf()<BRIDGE_CHANCE:_start_bridge()
	if is_instance_valid(world.dialogue):world.dialogue.cancel()
	var player:=world.player
	previous_lock=player.input_locked;player.input_locked=true;player.velocity=Vector3.ZERO
	rescue_origin=player.global_position
	rescue_target=last_safe+Vector3.UP*.035
	cruise_height=maxf(rescue_target.y+1.1,SEA_Y+.8)
	lotus.global_position=rescue_origin;lotus.show()
	lotus_picture.material_override.set_shader_parameter("opacity",0.0)
	lotus_shape.set_deferred("disabled",false)
	rescue_clock=0;rescue_state="rise"
	BgmPlayer.play_water_up()
	player._play_directional_animation("idle")

func _advance_rescue(delta:float) -> void:
	rescue_clock+=delta
	var foot:=lotus.global_position
	match rescue_state:
		"rise":
			var t:=clampf(rescue_clock/1.3,0,1)
			foot=rescue_origin.lerp(Vector3(rescue_origin.x,cruise_height,rescue_origin.z),smoothstep(0,1,t))
			lotus_picture.material_override.set_shader_parameter("opacity",smoothstep(0,.3,t))
			if t>=1:rescue_state="return";rescue_clock=0
		"return":
			var t:=clampf(rescue_clock/1.5,0,1)
			foot=Vector3(rescue_origin.x,cruise_height,rescue_origin.z).lerp(Vector3(rescue_target.x,cruise_height,rescue_target.z),smoothstep(0,1,t))
			if t>=1:rescue_state="land";rescue_clock=0
		"land":
			var t:=clampf(rescue_clock/.8,0,1)
			foot=Vector3(rescue_target.x,cruise_height,rescue_target.z).lerp(rescue_target,smoothstep(0,1,t))
			if t>=1:
				world.player.global_position=foot;world.player.velocity=Vector3.ZERO
				world.player.land_time=.22
				lotus_shape.set_deferred("disabled",true)
				rescue_state="fade";rescue_clock=0
		"fade":
			lotus_picture.material_override.set_shader_parameter("opacity",1-clampf(rescue_clock/.5,0,1))
			if rescue_clock>=.5:
				lotus.hide();rescue_state="idle";world.player.input_locked=previous_lock
			return
	lotus.global_position=foot
	if rescue_state!="fade":world.player.global_position=foot

func _start_bridge() -> void:
	if bridge_state!="waiting":return
	bridge_state="assembling";bridge_clock=0
	for span_index in range(world.stage_data.sea_bridges.size()):
		var span:Array=world.stage_data.sea_bridges[span_index]
		var a:Vector3=span[0];var b:Vector3=span[1]
		var direction:Vector3=(b-a).normalized()
		var right:=direction.cross(Vector3.UP).normalized();var up:=right.cross(direction).normalized()
		var body:=StaticBody3D.new();body.name="SeaBridge%d"%span_index;body.collision_layer=0;body.collision_mask=2
		var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1.15,.16,a.distance_to(b))
		collider.shape=box;body.add_child(collider);add_child(body)
		body.position=(a+b)*.5-up*.08;body.basis=Basis(right,up,-direction);bridges.append(body)
		# A level end overlaps the terrace instead of leaving a vertical lip.
		# Keep the landing on the same assembly gate as the sloping span.
		var forward:=Vector3(b.x-a.x,0,b.z-a.z).normalized()
		var landing:=StaticBody3D.new();landing.name="SeaBridgeLanding%d"%span_index
		landing.collision_layer=0;landing.collision_mask=2
		var landing_shape:=BoxShape3D.new();landing_shape.size=Vector3(1.15,.16,.50)
		var landing_collider:=CollisionShape3D.new();landing_collider.shape=landing_shape
		landing.add_child(landing_collider);add_child(landing)
		landing.position=b+forward*.24-Vector3.UP*.08
		landing.basis=Basis(right,Vector3.UP,-forward);bridges.append(landing)
		for i in range(ANIMALS_PER_SPAN):
			var turtle:bool=(i+span_index)%2==0
			var sprite:=_picture("BridgeAnimal%d_%d"%[span_index,i],textures.turtle if turtle else textures.fish,1.05)
			var deck:=a.lerp(b,float(i)/float(ANIMALS_PER_SPAN-1))
			# The shell/back meets the collision deck; the body hangs below it.
			var height:float=sprite.texture.get_height()*sprite.pixel_size
			var target:=deck-camera.global_basis.y*height*(.28 if turtle else .25)
			var origin:=Vector3((-4.0 if i%2==0 else 4.0),SEA_Y-.6,deck.z)
			sprite.flip_h=camera.unproject_position(target).x<camera.unproject_position(origin).x
			sprite.global_position=origin;sprite.hide()
			creatures.append({"sprite":sprite,"from":origin,"to":target,"delay":i*.13+span_index*.22,"arrived":false})

func _advance_bridge(delta:float) -> void:
	if bridge_state!="assembling":return
	bridge_clock+=delta
	var complete:=true
	for creature:Dictionary in creatures:
		if creature.arrived:continue
		var local:float=bridge_clock-float(creature.delay)
		if local<0:complete=false;continue
		var t:=clampf(local/LEAP_SECONDS,0,1)
		var sprite:Sprite3D=creature.sprite;sprite.show()
		sprite.global_position=Vector3(creature.from).lerp(creature.to,t)+Vector3.UP*sin(PI*t)*2.0
		sprite.material_override.set_shader_parameter("opacity",smoothstep(0,.18,t))
		if t>=1:creature.arrived=true
		else:complete=false
	if complete:
		for bridge:StaticBody3D in bridges:bridge.set_deferred("collision_layer",1)
		bridge_state="open";path_open=true;cloud_clock=0

func _advance_clouds(delta:float) -> void:
	if clouds.is_empty():return
	cloud_drift_clock+=delta
	if path_open:cloud_clock+=delta
	var t:=smoothstep(0,1,clampf(cloud_clock/CLOUD_SECONDS,0,1)) if path_open else 0.0
	var frame:=get_viewport().get_visible_rect().size
	var depth:float=camera.global_position.distance_to(world.stage_data.focus)
	for entry:Dictionary in clouds:
		var anchor:Vector2=entry.anchor
		anchor.x=wrapf(anchor.x-cloud_drift_clock*float(entry.speed),-.4,1.4)
		var cloud:Sprite3D=entry.sprite
		cloud.global_basis=camera.global_basis
		cloud.global_position=camera.project_position(anchor*frame,depth)
		entry.sprite.material_override.set_shader_parameter("opacity",float(entry.opacity)*(1-t))
	if path_open and cloud_clock>=CLOUD_SECONDS:
		for entry:Dictionary in clouds:entry.sprite.queue_free()
		clouds.clear()
