extends SceneTree
var world:Node3D
var puzzle:Node3D
var failures:=0
var visual:=false
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func frames(count:int) -> void:
	for tick:int in count:await physics_frame
func capture(title:String) -> void:
	if not visual:return
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/stage7-"+title+".png")
func unlock() -> void:
	world.transition.cancel();world.stage_intro.hide();world.player.input_locked=false
	puzzle=world.stage7_puzzle
func stroke_polygon(polygon:PackedVector2Array) -> void:
	var bounds:=Rect2(polygon[0],Vector2.ZERO)
	for point:Vector2 in polygon:bounds=bounds.expand(point)
	var scale_:float=root.get_visible_rect().size.y/1000.0
	var a:=Vector2(bounds.position.x-10,bounds.get_center().y)*scale_
	var b:=Vector2(bounds.end.x+10,bounds.get_center().y)*scale_
	var motion:=InputEventMouseMotion.new();motion.position=a;motion.global_position=a;root.push_input(motion,true)
	var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=a;press.global_position=a;root.push_input(press,true)
	motion=InputEventMouseMotion.new();motion.position=b;motion.global_position=b;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion,true)
	var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.position=b;release.global_position=b;root.push_input(release,true)
func bird(index:int) -> void:stroke_polygon(puzzle._mouth_polygon(index))
func item(role:String) -> Dictionary:
	for entry:Dictionary in puzzle.fruits:
		if entry.role==role:return entry
	return {}
func open(role:String) -> void:stroke_polygon(puzzle._fruit_polygon(item(role)))
func until(predicate:Callable,message:String,limit:=600) -> bool:
	for tick:int in limit:
		if predicate.call():check(true,message);return true
		await physics_frame
	check(false,message);quit(1);return false
func ready(role:String) -> bool:return not item(role).is_empty() and item(role).state=="ready"
func steer(direction:Vector3) -> void:
	for action:String in ["left","right","forward","back"]:Input.action_release(action)
	var right:Vector3=world.camera.global_basis.x;right.y=0;right=right.normalized()
	var ahead:Vector3=-world.camera.global_basis.z;ahead.y=0;ahead=ahead.normalized()
	var x:=direction.normalized().dot(right);var z:=direction.normalized().dot(ahead)
	if absf(x)>.001:Input.action_press("right" if x>0 else "left",absf(x))
	if absf(z)>.001:Input.action_press("forward" if z>0 else "back",absf(z))
func walk(from:Vector3,to:Vector3,title:String) -> void:
	world.player.position=from;world.player.velocity=Vector3.ZERO;await frames(20)
	for tick:int in 360:
		var direction:Vector3=to-world.player.position;direction.y=0
		if direction.length()<.10:break
		steer(direction);await physics_frame
	steer(Vector3.ZERO);await frames(15)
	check(Vector2(world.player.position.x-to.x,world.player.position.z-to.z).length()<.18 and absf(world.player.position.y-to.y)<.12 and world.player.is_on_floor(),title+" actual WASD traversal: "+str(world.player.position))
func restart() -> void:
	world.restart();await frames(5);unlock();await frames(25)
func run() -> void:
	# Maintained regression fixture. AGENTS.md permits parsing only, not executing.
	root.size=Vector2i(1280,720)
	var selection=load("res://scenes/grid_stage/menu.tscn").instantiate()
	root.add_child(selection);await frames(3)
	selection.stage_buttons[6].pressed.emit();world=selection.world
	puzzle=world.stage7_puzzle
	check(puzzle.attempt_number==1,"first stage attempt starts at one")
	check(not puzzle._bad_outcome(1) and puzzle._bad_outcome(2),"first two openings are win then loss")
	for carrier:Dictionary in puzzle.birds:
		check(not carrier.sprite.visible and not carrier.gourd.visible,"carriers wait outside the hand entry")
	unlock();await frames(90)
	for waiting:Dictionary in puzzle.birds:
		check(not waiting.sprite.visible and not waiting.gourd.visible,"birds stay hidden for the first two active seconds")
	await frames(180)
	check(puzzle.birds.size()==3,"three variants retain stage ownership")
	for index:int in 3:
		var carrier:Dictionary=puzzle.birds[index]
		check(carrier.state=="idle" and carrier.sprite.visible and carrier.gourd.visible,"all three carriers appear together")
		var placement:Dictionary=puzzle.carrier_layout[index]
		var body_center:Vector3=carrier.target+world.camera.global_basis.x*float(placement.body_offset)
		var body_x:float=world.camera.unproject_position(body_center).x/root.size.x
		check(placement.zone.grow(1).encloses(placement.bird_rect),"entire bird lies inside the marked outer side region")
		check(absf(body_x-float(placement.target_x)/root.size.x)<.001,"bird uses its randomized horizontal target")
		check(carrier.sprite.get_meta("paper_foreground",false),"bird uses the frontmost art layer")
		check(carrier.facing_left==(world.camera.unproject_position(carrier.target).x>root.size.x*.5),"birds face the screen center")
		check(carrier.sprite.global_basis.x.dot(world.camera.global_basis.x)<0 if carrier.facing_left else carrier.sprite.global_basis.x.dot(world.camera.global_basis.x)>0,"bird turns around local Y")
		check(is_equal_approx(carrier.sprite.pixel_size,puzzle.carrier_layout[index].width*4.0/440.0),"bird pixel scale doubles")
		check(carrier.bird_ink.render_priority>carrier.fruit_ink.render_priority,"bird draws in front of its gourd")
		var center_:Vector3=carrier.target-carrier.attachment
		check(is_equal_approx(center_.x,carrier.landing.x) and is_equal_approx(center_.z,carrier.landing.z),"fruit is directly above its landing terrace")
		for other:int in range(index):
			check(not placement.bird_rect.intersects(puzzle.carrier_layout[other].bird_rect),"all wing frames and idle bobbing remain separated")
			var first_span:Rect2=placement.bird_rect
			var second_span:Rect2=puzzle.carrier_layout[other].bird_rect
			check(first_span.end.x<=second_span.position.x or second_span.end.x<=first_span.position.x,"bird horizontal spans do not overlap even at different heights")
			if not placement.get("relaxed",false):
				check(not placement.rect.intersects(puzzle.carrier_layout[other].rect),"strict carrier layout does not overlap")
		check(carrier.gourd.get_meta("paper_foreground",false),"gourd uses requested top layer")
		check(is_equal_approx(carrier.gourd.pixel_size,puzzle.gourd_width*2/carrier.gourd.texture.get_width()),"gourd illustration doubles")
	check(is_equal_approx(float(puzzle.birds[0].fruit_ink.get_shader_parameter("border_radius")),21.6),"stem outline is twice the former thickness")
	var left_count:=0
	for entry:Dictionary in puzzle.birds:
		if not entry.facing_left:left_count+=1
	check(left_count in [1,2],"three birds are split between both quarter boundaries")
	var carrier:Dictionary=puzzle.birds[0]
	var before:Vector3=carrier.sprite.global_position
	await frames(12)
	check(carrier.sprite.global_position.distance_to(before)>.001,"idle carrier bobs vertically")
	check(carrier.gourd.global_position.is_equal_approx(carrier.sprite.global_position-carrier.attachment),"stem remains attached during bobbing")
	var center:Vector3=carrier.sprite.global_position-world.camera.global_basis.y*.08
	var a:Vector2=puzzle._screen(world.camera.unproject_position(center-world.camera.global_basis.x*.5))
	var b:Vector2=puzzle._screen(world.camera.unproject_position(center+world.camera.global_basis.x*.5))
	puzzle._cut(a,b);await frames(2)
	check(carrier.has("item"),"stem stroke releases physical gourd")
	if not carrier.has("item"):quit(1);return
	var dropped:Dictionary=carrier.item
	check(dropped.sprite.has_meta("paper_source_outline"),"cut contour survives release")
	check(is_instance_valid(dropped.cut_visual),"falling illustration uses the actual clipped mesh")
	check(not dropped.cut_visual.get_meta("paper_foreground",false) and not dropped.cut_visual.material_override.no_depth_test,"severed fruit respects map depth")
	check((dropped.body.collision_layer & 16)!=0 and (dropped.body.collision_mask & 16)!=0,"gourds mutually collide on their shared 3D layer")
	check((dropped.body.collision_mask & 32)!=0,"gourd collides with the minimum-height safety floor")
	check(absf(dropped.body.linear_velocity.x)<.001 and absf(dropped.body.linear_velocity.z)<.001,"stem release has no sideways throw")
	if not await until(func():return dropped.state=="ready","physical gourd lands on map"):return
	check(not dropped.body.freeze,"landed gourd remains dynamic so stacked supports can be removed")
	check(puzzle.sources.size()>0,"landed contour transfers to shared paper cutter")
	check(not dropped.opened,"cutting the stem is not a reward opening")
	world.restart();await frames(4);unlock()
	check(puzzle.attempt_number==2,"explicit restart advances probability phase")
	# Resolve two wins through the existing reward handler after forcing first-attempt
	# non-loss ordinals; no probabilistic assertion depends on lucky random draws.
	puzzle.attempt_number=1;puzzle.opened_count=2
	var first:Dictionary={"opened":false,"state":"ready","destination":Vector3.ZERO}
	puzzle._open_fruit(first)
	check(is_instance_valid(puzzle.demolition) and not puzzle.house_collapsed,"first reward starts demolition before collapse")
	for variant:int in 4:
		var poses:SpriteFrames=preload("res://scripts/grid_stage/heungbu_minhwa.gd").demolition_frames(variant)
		check(poses.get_frame_count("fly")==4 and poses.get_frame_count("smash")==4,"each dokkaebi has four flight and four impact poses")
	var second:Dictionary={"opened":false,"state":"ready","destination":Vector3.ZERO}
	puzzle._open_fruit(second)
	check(puzzle.normal_opened==2,"two normal rewards trigger spoil cleanup")
	check(not puzzle.path_open,"completion waits for chase and house bridge arrival")
	for remaining:Dictionary in puzzle.fruits:
		check(remaining.rotten,"unopened remaining gourds spoil")
	check(puzzle.rotten_flies.size()==puzzle.fruits.size()*2,"each spoiled gourd has two flies")
	world.load_stage(9);await frames(3)
	check(world.stage7_puzzle==null,"leaving stage cleans up entry, bob and flies")
	print("STAGE7 RESULT: ",failures," failures");quit(1 if failures else 0)
