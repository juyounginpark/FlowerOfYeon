extends SceneTree
# Run with a display for captures, or --headless for the same input/physics checks.
var world:GridStageWorld
var checks:=0
var failed:=false
const CAPTURES:="res://../stage_screenshots/"

func _initialize() -> void:
	call_deferred("run")
	create_timer(90).timeout.connect(func():push_error("FAIL: verification timed out");quit(1))

func check(condition:bool,message:String) -> void:
	checks+=1
	if not condition:
		failed=true
		push_error("FAIL: "+message)
		quit(1)
		assert(condition,message)

func frames(count:=2) -> void:
	for frame in range(count):await process_frame

func capture(name_:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await frames(3)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(CAPTURES+name_+".png"))==OK,"save "+name_)

func mouse_button(position:Vector2,pressed:bool) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT;event.position=position;event.global_position=position;event.pressed=pressed
	root.push_input(event,true)

func mouse_motion(position:Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=position;event.global_position=position;event.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(event,true)

func key(code:Key) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true
	Input.parse_input_event(event)
	await frames()
	event=InputEventKey.new();event.physical_keycode=code;event.pressed=false
	Input.parse_input_event(event)
	await frames()

func stop_moving() -> void:
	for action in ["forward","back","left","right"]:Input.action_release(action)

func steer(direction:Vector3) -> void:
	stop_moving()
	direction=direction.normalized()
	var right:=world.camera.global_basis.x;right.y=0;right=right.normalized()
	var forward:Vector3=-world.camera.global_basis.z;forward.y=0;forward=forward.normalized()
	var lateral:=direction.dot(right);var ahead:=direction.dot(forward)
	Input.action_press("right" if lateral>=0 else "left",absf(lateral))
	Input.action_press("forward" if ahead>=0 else "back",absf(ahead))

func walk_to(target:Vector2,until_goal:=false) -> void:
	for tick in range(600):
		var direction:=Vector3(target.x-world.player.position.x,0,target.y-world.player.position.z)
		if direction.length()<.09 or (until_goal and world.completed):
			stop_moving()
			return
		steer(direction)
		await physics_frame
	stop_moving()
	check(false,"walk to %s; stopped at %s"%[target,world.player.position])

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURES))
	root.size=Vector2i(1280,720)
	world=load("res://scripts/grid_stage/world.gd").new();world.stage_number=5;root.add_child(world)
	await frames()
	var story=world.story;story.set_process(false)
	check(story!=null and not story.path_open,"Stage2 puzzle present and closed")
	await capture("stage_02_story_start")

	# Use the real CharacterBody and camera-relative movement against the passage.
	steer(Vector3.RIGHT)
	for tick in range(150):await physics_frame
	stop_moving()
	check(world.player.position.x< -1.6 and world.player.position.x> -1.9,"woodcutter physically blocks walking")
	world.player.position=Vector3(0,.04,0)
	for tick in range(8):await physics_frame
	check(not world.interact_stone(),"nearby rune stays locked before the story ends")
	world.player.position=world.start_position;world.player.velocity=Vector3.ZERO

	var rect:Rect2=story._rect(story.rock)
	var center:=rect.get_center()
	var left:=center-Vector2(rect.size.x*.55,0)
	var right:=center+Vector2(rect.size.x*.55,0)
	mouse_button(center,true);mouse_button(center+Vector2(2,0),false)
	check(story.phase==story.Phase.ROBE_ON_ROCK,"click is not a cut")
	mouse_button(Vector2(10,200),true);mouse_button(Vector2(100,200),false)
	check(story.phase==story.Phase.ROBE_ON_ROCK,"stroke missing the silhouette cannot cut")
	world.player.position=Vector3(-1.7,0,2.4);story._process(.5)
	check(story.wood_foot.z>2.2,"woodcutter follows player along the wall")
	await capture("stage_02_story_blocking")
	world.player.position=world.start_position

	# Pause after mouse-down: cancellation must not depend on another mouse event.
	mouse_button(left,true);mouse_motion(center)
	check(story.drawing,"viewport dispatch starts cutting")
	await key(KEY_ESCAPE);story._process(.1)
	check(world.paused and not story.drawing and story.stroke.points.is_empty(),"pause cancels the in-progress cut")
	await key(KEY_ESCAPE)
	mouse_button(right,false)
	check(story.phase==story.Phase.ROBE_ON_ROCK,"release after pause cannot finish a stale cut")
	mouse_button(left,true);mouse_motion(center);mouse_button(right,false)
	check(story.phase==story.Phase.SPLITTING and story.cutter.pieces.size()>=2,"lotus cutting produces real polygon fragments")
	await capture("stage_02_story_fragments")
	story._process(.9)
	check(story.phase==story.Phase.ROBE_LOOSE and story.robe.visible,"viewport cut separates the robe")
	await capture("stage_02_story_cut")

	var robe_center:Vector2=story._rect(story.robe).get_center()
	mouse_button(robe_center,true);mouse_motion(Vector2(640,300));mouse_button(Vector2(640,300),false)
	check(story.phase==story.Phase.ROBE_LOOSE and not story.dragging,"invalid drop returns the robe")
	check(story._rect(story.robe).get_center().distance_to(robe_center)<1,"invalid drop restores the robe position")
	mouse_button(robe_center,true);mouse_motion(Vector2(640,300))
	await key(KEY_ESCAPE);story._process(.1)
	check(world.paused and not story.dragging,"pause cancels dragging without mouse motion")
	await key(KEY_ESCAPE)
	mouse_button(story._rect(story.fairy).get_center(),false)
	check(story.phase==story.Phase.ROBE_LOOSE,"release after pause does not deliver the robe")
	mouse_button(story._rect(story.robe).get_center(),true)
	check(story.dragging,"visible robe can be grabbed again")
	var destination:Vector2=story._rect(story.fairy).get_center()
	mouse_motion(destination);mouse_button(destination,false)
	check(story.phase==story.Phase.DRESSING and not story.robe.visible,"drag dresses the fairy")
	await key(KEY_ESCAPE);story._process(10)
	check(story.phase==story.Phase.DRESSING,"pause freezes story animation")
	await key(KEY_ESCAPE)
	story._process(.7);check(story.phase==story.Phase.FLYING,"dressing leads to flight")
	story._process(1.3);await capture("stage_02_story_flight")
	story._process(1.4);check(story.phase==story.Phase.ASCENDING,"fairy reaches the woodcutter")
	check(story.couple.global_position.distance_to(story.wood_foot)<.01,"couple starts at the meeting point")
	story._process(.8);await capture("stage_02_story_ascent")
	check(not story.path_open,"passage remains closed during ascent")
	story._process(3.3)
	check(story.path_open and story.blocker.collision_layer==0,"ascent opens the passage")
	await capture("stage_02_story_open")
	print("PASS: input dispatch, invalid cuts/drops, pause cancellation, flight, ascent and unlock")

	# Complete the level with walking input and the actual moving-platform physics.
	await walk_to(Vector2(0,1.8))
	check(world.player.position.x>-.1,"opened passage permits walking")
	await walk_to(Vector2.ZERO)
	for tick in range(8):await physics_frame
	check(world.on_lift(),"player walks onto the rune lift")
	await key(KEY_E)
	check(world.rune_candidates[0].phase!=world.LiftPhase.IDLE,"E activates the unlocked rune")
	for tick in range(150):await physics_frame
	check(world.player.position.y>1.7 and world.on_lift(),"rising lift carries the player")
	await walk_to(Vector2(0,-.45))
	steer(Vector3.FORWARD)
	await key(KEY_SPACE)
	await walk_to(Vector2(0,-1.5))
	for tick in range(30):await physics_frame
	check(world.player.position.y>1.7 and world.player.is_on_floor(),"Space crosses the gap to the upper terrace")
	await walk_to(world.stage_data.goal_rect.get_center(),true)
	await frames(3)
	check(world.completed,"Stage2 can be completed by walking and jumping from the start")
	await capture("stage_02_story_complete")
	for tick in range(900):
		if world.stage_number==6 and not world.transition.active:break
		await physics_frame
	check(world.stage_number==6 and world.story==null and not world.player.input_locked,"clear transition reaches playable Stage3")
	print("PASS: passage traversal, E input, lift transport, Space jump, goal and next-stage transition")

	world.load_stage(5);await frames()
	story=world.story
	mouse_button(story._rect(story.rock).get_center()-Vector2(60,0),true)
	await key(KEY_HOME)
	check(world.stage_number==5 and not world.story.path_open and not world.story.drawing,"Home resets the puzzle and pending input")
	var target:Rect2=world.story._rect(world.story.rock)
	check(world.story.try_cut(target.get_center()-Vector2(0,target.size.y),target.get_center()+Vector2(0,target.size.y)),"vertical cut uses the same lotus polygon splitting")
	for stage in [1,4,6,7,10,12]:
		world.load_stage(stage);check(world.story==null or world.story.get_script().resource_path.ends_with("folktale_story.gd"),"fairy puzzle isolated from runtime stage %d"%stage)
	stop_moving();world.queue_free();await process_frame
	if not failed:print("PASS: %d checks, including reset and stage isolation"%checks)
	quit(1 if failed else 0)
