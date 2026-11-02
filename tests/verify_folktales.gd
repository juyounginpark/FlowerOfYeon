extends "res://tests/verify_fairy_story.gd"
var story:Node3D
func _initialize() -> void:
	call_deferred("run")
	create_timer(240).timeout.connect(func():push_error("FAIL: folktale verification timed out");quit(1))
func scene(number:int) -> void:
	if world==null:
		world=load("res://scripts/grid_stage/world.gd").new();world.stage_number=number+3;root.add_child(world)
	else:world.load_stage(number+3)
	story=world.story
	await frames(5)
	check(story!=null and not story.path_open,"story %d starts locked"%number)
func cut(id:String) -> void:
	var rect:Rect2=story._rect(story.items[id].sprite)
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.shift_pressed=true
	event.position=rect.get_center()-Vector2(rect.size.x*.65,0);root.push_input(event,true)
	mouse_motion(rect.get_center())
	mouse_button(rect.get_center()+Vector2(rect.size.x*.65,0),false)
	check(story.items[id].delay>=0,"real polygon cut: "+id)
	await capture("story_%d_%s_fragments"%[story.number,id])
	await create_timer(.9).timeout
	check(story.items[id].loose,"cut item becomes draggable: "+id)
func deliver(id:String,target:String) -> void:
	var position:Vector2=story._rect(story.items[id].sprite).get_center()
	mouse_button(position,true)
	check(story.dragging==id,"grab: "+id)
	position=story._rect(story.targets[target]).get_center()
	mouse_motion(position);mouse_button(position,false)
	await frames()
func until_state(field:String,value:int) -> void:
	for tick in range(1200):
		if int(story.get(field))==value:return
		await physics_frame
	check(false,"timeout: %s=%d, player=%s"%[field,value,world.player.position])
func jump_to(target:Vector2) -> void:
	steer(Vector3(target.x-world.player.position.x,0,target.y-world.player.position.z))
	await key(KEY_SPACE)
	await walk_to(target)
	for tick in range(20):await physics_frame
func finish() -> void:
	var completed_number:=world.stage_number-3
	await walk_to(world.stage_data.goal_rect.get_center(),true)
	await frames(3)
	check(world.completed,"goal reached in story %d"%story.number)
	await capture("story_%d_complete"%story.number)
	var next:=world.stage_number+1
	for tick in range(900):
		if world.stage_number==next and not world.transition.active:break
		await physics_frame
	check(world.stage_number==next and not world.player.input_locked,"next stage is playable")
	print("PASS: story %d mechanics, physical traversal and transition"%completed_number)
func run() -> void:
	root.size=Vector2i(1280,720)
	await scene(4)
	await capture("story_4_start")
	check(not story.drop_item("red","red"),"uncut fan cannot activate lift")
	await cut("red");await cut("blue")
	check(not story.drop_item("blue","blue"),"blue fan cannot bypass emperor")
	await deliver("red","red")
	check(story.fan_step==1,"red fan armed")
	await walk_to(Vector2(-1.3,0))
	await jump_to(Vector2(0,0))
	await until_state("fan_step",3)
	check(world.player.position.y>8.8,"red fan carries player to emperor")
	check(story.items.brows.sprite.visible,"emperor changes eyebrows")
	for block in story.red_blocks:check(block.collision_layer==0,"red obstruction destroyed")
	await capture("story_4_emperor")
	await deliver("blue","blue")
	await walk_to(Vector2(.45,0))
	await jump_to(Vector2(1.8,0))
	await walk_to(Vector2(3.2,-.35))
	await jump_to(Vector2(3.2,-1.6))
	await until_state("fan_step",6)
	check(world.player.position.y>10.6,"blue fan descends and automatically raises rider")
	await jump_to(Vector2(3.2,-3))
	await finish()

	await scene(5)
	await capture("story_5_start")
	await cut("bridge")
	await deliver("bridge","bridge")
	check(story.bridge_failures==1 and story.bridges.is_empty(),"impostor sabotages first bridge attempt")
	await create_timer(.9).timeout
	await deliver("beauty","beauty")
	check(story.mouse_step==1,"beauty lures impostor")
	await deliver("bridge","bridge")
	check(story.mouse_step==2 and story.bridges.has(0),"bridge persists while impostor drinks")
	await cut("roof");await deliver("roof","cat")
	await until_state("mouse_step",4)
	check(story.path_open and not story.items.impostor.sprite.visible and not story.items.mouse.sprite.visible,"cat exposes and removes mouse")
	await capture("story_5_open")
	await walk_to(Vector2(-2.55,1.6))
	await jump_to(Vector2(-1.2,1.6))
	await walk_to(Vector2(0,1.4))
	await walk_to(Vector2(0,-1.6))
	check(world.player.position.y>1.7,"first mouse bridge supports player")
	await walk_to(Vector2(-.4,-2.4))
	await walk_to(Vector2(-3.1,-2.4))
	check(world.player.position.y>3.5,"second mouse bridge supports player")
	await finish()


	for number in [4,5]:
		await scene(number)
		await key(KEY_HOME)
		check(not world.story.path_open,"Home resets story %d"%number)
	for runtime in [4,6,9,10,11]:
		world.load_stage(runtime)
		check(world.story==null,"no invented mechanics in unprovided stage %d"%(runtime-3))
	stop_moving();world.queue_free();await frames()
	if not failed:print("PASS: %d checks; all supplied folktales, physical routes, transitions, reset and isolation"%checks)
	quit(1 if failed else 0)
