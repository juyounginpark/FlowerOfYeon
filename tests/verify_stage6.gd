extends SceneTree
var world:GridStageWorld
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(value:bool,message:String) -> void:
	print("PASS " if value else "FAIL ",message)
	if not value:failures+=1
func frames(count:=3) -> void:
	for frame in range(count):await process_frame
func drag(a:Vector2,b:Vector2) -> void:
	var motion:=InputEventMouseMotion.new();motion.position=a;Input.parse_input_event(motion)
	var button:=InputEventMouseButton.new();button.button_index=MOUSE_BUTTON_LEFT;button.position=a;button.pressed=true;Input.parse_input_event(button)
	await frames(2)
	for step:int in range(1,9):
		motion=InputEventMouseMotion.new();motion.position=a.lerp(b,step/8.0);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;Input.parse_input_event(motion)
		await frames(1)
	button=InputEventMouseButton.new();button.button_index=MOUSE_BUTTON_LEFT;button.position=b;button.pressed=false;Input.parse_input_event(button)
	await frames(4)
func cut_source(sprite:Sprite3D) -> void:
	for piece:Dictionary in world.story.paper.pieces.duplicate():
		if piece.source.sprite!=sprite or not piece.attached:continue
		var low:=Vector2(INF,INF);var high:=Vector2(-INF,-INF)
		for point:Vector2 in piece.polygon:low=low.min(point);high=high.max(point)
		var y:float=lerpf(low.y,high.y,.65)
		var ratio:float=root.size.y/1000.0
		await drag((piece.body.transform*Vector2(low.x-12,y))*ratio,(piece.body.transform*Vector2(high.x+12,y))*ratio)
		return
func loose(sprite:Sprite3D) -> Dictionary:
	var found:Dictionary={};var largest:=0.0
	for piece:Dictionary in world.story.paper.pieces:
		if piece.source.sprite!=sprite or piece.attached:continue
		var area:float=world.story.paper._area(piece.polygon)
		if area>largest:found=piece;largest=area
	return found
func ink_point(piece:Dictionary) -> Vector2:
	var source:Dictionary=piece.source;var image:Image=source.image
	for y:int in range(0,image.get_height(),3):
		for x:int in range(0,image.get_width(),3):
			if image.get_pixel(x,y).a<.7:continue
			var local:Vector2=(Vector2(x,y)-Vector2(image.get_size())*.5)*float(source.scale)
			if not Geometry2D.is_point_in_polygon(local,piece.polygon):continue
			return world.camera.unproject_position(piece.visual.global_transform*Vector3(local.x,-local.y,0))
	return Vector2(-1,-1)
func capture(name:String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/stage6/"+name+".png"))
func run() -> void:
	root.size=Vector2i(1280,720)
	world=load("res://scripts/grid_stage/world.gd").new();world.stage_number=9;root.add_child(world)
	await create_timer(7.0).timeout
	var story=world.story
	check(world.rune_candidates.size()==1,"only final lift remains")
	await cut_source(story.rice)
	var rice_piece:Dictionary=loose(story.rice)
	check(not rice_piece.is_empty(),"native mouse stroke cuts basket rice")
	if not rice_piece.is_empty():
		await drag(ink_point(rice_piece),world.camera.unproject_position(Vector3(-3,1,.6)))
	check(story.phase==story.Phase.LURED,"native rice drag onto left wall lures tiger")
	await cut_source(story.trees[0])
	var wood:Dictionary=loose(story.trees[0])
	check(not wood.is_empty(),"native mouse stroke cuts tree")
	if not wood.is_empty():await drag(ink_point(wood),world.camera.unproject_position((story.span[0]+story.span[1])*.5))
	check(is_instance_valid(story.bridge),"native wood drop builds physical bridge")
	await capture("bridge-built")
	if is_instance_valid(story.bridge):
		var elapsed:=0.0
		Input.action_press("forward");Input.action_press("right",tan(deg_to_rad(world.camera_yaw_degrees)))
		while elapsed<6.0 and world.player.position.z>.05:
			await physics_frame;elapsed+=1.0/Engine.physics_ticks_per_second
		Input.action_release("forward");Input.action_release("right")
		await create_timer(.7).timeout
		print("WALK player=",world.player.position," sister=",story.sister_base," phase=",story.phase)
		check(story._on_middle(world.player.position),"player walks across bridge without jumping")
		check(story.crossed,"sister crosses and tiger rush starts")
		await capture("after-crossing")
	print("STAGE6_RESULT failures=",failures)
	quit(failures)
