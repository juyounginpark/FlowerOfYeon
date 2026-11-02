class_name GridClearTransition
extends Node2D
var world:Node3D
var active:=false
var phase:="idle"
var phase_time:=0.0
var elapsed:=0.0
var from_position:=Vector2.ZERO
var destination:=Vector2.ZERO
var carried:=false
var next_stage:=1
var palm:MinhwaHandPoses
var fingers:MinhwaHandPoses
var proxy:Sprite2D
var hand:Node2D
var book:Node2D
func _ready() -> void:
	var book_layer:=CanvasLayer.new();book_layer.layer=20;add_child(book_layer)
	book=preload("res://scripts/grid_stage/book_transition.gd").new();book_layer.add_child(book);book.hide()
	hand=Node2D.new();add_child(hand)
	palm=MinhwaHandPoses.new();palm.z_index=0;hand.add_child(palm)
	palm.configure("res://art/minhwa/bodhisattva_hands/poses.json")
	proxy=Sprite2D.new();proxy.z_index=1;proxy.position=Vector2(0,-46.4);proxy.scale=Vector2.ONE*.2
	proxy.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;hand.add_child(proxy)
	fingers=MinhwaHandPoses.new();fingers.z_index=2;fingers.front=true;hand.add_child(fingers)
	fingers.configure("res://art/minhwa/bodhisattva_hands/poses.json")
	hand.visible=false
func anchor() -> Vector2:
	return world.camera.unproject_position(world.player.global_position)
func refresh_proxy() -> void:
	var sprite:AnimatedSprite3D=world.player.sprite
	proxy.texture=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
	proxy.modulate=sprite.modulate
	proxy.material=null
	if world.stage_number==12 and world.completed:
		var glow:=ShaderMaterial.new()
		glow.shader=preload("res://shaders/final_clear_proxy.gdshader")
		if sprite.material_override is ShaderMaterial:
			glow.set_shader_parameter("clear_glow",sprite.material_override.get_shader_parameter("clear_glow"))
		proxy.material=glow
func start() -> void:
	if active:return
	active=true;phase="beat";phase_time=0;elapsed=0;carried=false
	next_stage=world.following_stage()
	world.transition_consumed=true
	world.player.input_locked=true;world.player.velocity=Vector3.ZERO
	world.player._play_directional_animation("idle")
	if next_stage>0:
		phase="book";hand.hide();proxy.hide()
		book.begin(world,next_stage)
		return
	hand.scale=Vector2.ONE*(world.player.sprite.pixel_size*get_viewport_rect().size.y/world.camera.size/.2)
	from_position=anchor();destination=from_position
	refresh_proxy();proxy.visible=false;hand.visible=false
	set_curl(0)
func start_selection_entry() -> void:
	active=true;phase="book";phase_time=0;elapsed=0;carried=false
	world.transition_consumed=false
	world.player.input_locked=true;world.player.velocity=Vector3.ZERO
	world.player.sprite.hide();world.player._play_directional_animation("idle")
	hand.hide();proxy.hide()
	book.begin(world,world.stage_number,true)
func start_entry() -> void:
	# Direct map selection/restart uses the same left-hand release as a carried transition.
	active=true;phase="descend";phase_time=0;elapsed=0;carried=true
	world.transition_consumed=false
	world.player.input_locked=true;world.player.velocity=Vector3.ZERO
	world.player.sprite.visible=false;world.player._play_directional_animation("idle")
	hand.scale=Vector2.ONE*(world.player.sprite.pixel_size*get_viewport_rect().size.y/world.camera.size/.2)
	destination=anchor();from_position=destination
	refresh_proxy();proxy.visible=true;hand.visible=true
	hand.position=Vector2(get_viewport_rect().size.x*.53,-280)
	set_curl(1)
func set_curl(value:float) -> void:
	palm.curl=value;fingers.curl=value;palm.apply_pose();fingers.apply_pose()
func advance(next:String) -> void:phase=next;phase_time=0
func cancel() -> void:
	if is_instance_valid(book) and book.state!="idle":book.cancel()
	if is_instance_valid(world.player):
		world.player.sprite.visible=true;world.player.input_locked=false
	hand.visible=false;proxy.visible=false;active=false;carried=false;phase="idle"
func _process(delta:float) -> void:
	if not active or world.paused:return
	if phase=="book":book.tick(delta);return
	phase_time+=delta;elapsed+=delta
	var sky:=Vector2(get_viewport_rect().size.x*.53,-280)
	match phase:
		"beat":
			if phase_time>=.35:hand.visible=true;advance("approach")
		"approach":
			hand.position=from_position.lerp(from_position+Vector2(150,-480),1-smoothstep(0,1,phase_time/1.15))
			if phase_time>=1.15:hand.position=from_position;advance("grasp")
		"grasp":
			set_curl(smoothstep(0,1,phase_time/.7))
			if phase_time>.20 and not carried:
				world.player.sprite.visible=false;proxy.visible=true;carried=true
			if phase_time>=.7:advance("ascend")
		"ascend":
			hand.position=from_position.lerp(sky,smoothstep(0,1,phase_time/1.2))
			if phase_time>=1.2:
				if world.stage_number==12 and next_stage==0:
					hand.hide();proxy.hide();active=false;phase="idle"
					world.show_ending()
					return
				if next_stage>0:
					world.load_stage(next_stage,true)
					world.player.input_locked=true;world.player.sprite.visible=false
					hand.scale=Vector2.ONE*(world.player.sprite.pixel_size*get_viewport_rect().size.y/world.camera.size/.2)
					refresh_proxy()
				destination=anchor();advance("descend")
		"descend":
			hand.position=sky.lerp(destination,smoothstep(0,1,phase_time/1.2))
			if phase_time>=1.2:hand.position=destination;advance("release")
		"release":
			set_curl(1-smoothstep(0,1,phase_time/.75))
			if phase_time>=.75:
				proxy.visible=false;world.player.sprite.visible=true
				world.player.input_locked=false;world.player.velocity=Vector3.ZERO
				world.stage_intro.release_from_hand()
				advance("retreat")
		"retreat":
			hand.position=destination.lerp(destination+Vector2(180,-500),smoothstep(0,1,phase_time/.85))
			if phase_time>=.85:cancel()
