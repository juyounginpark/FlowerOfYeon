extends SceneTree
var world: GridStageWorld
var checks := 0
var failed := false
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error(label)
func ticks(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func e() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	await ticks(2)
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	Input.parse_input_event(event)
	await ticks(2)
func capture(name_: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/"+name_+".png")
func run() -> void:
	root.size = Vector2i(1280,720)
	var menu = load("res://scenes/grid_stage/menu.tscn").instantiate()
	root.add_child(menu)
	await ticks(3)
	menu.stage_buttons[0].pressed.emit()
	world = menu.world
	world.transition.cancel()
	world.stage_intro.hide()
	await ticks(20)
	check(world.player.is_on_floor(),"player lands on expanded starting pad")
	check(world.player.position.distance_to(Vector3(.1,0,2.2))<.1,"player starts at pad center")
	var art = world.stage_root.get_node("Stage1Artwork")
	check(art.has_node("LeftTree") and art.has_node("RightTree"),"two trees present")
	var tree_puzzle=world.stage_root.get_node("Stage1TreeBridge")
	for piece:Dictionary in tree_puzzle.paper.pieces:
		check(piece.border.visible and piece.border.get_parent()==piece.visual,"tree paper keeps its shared silhouette border")
	var people = art.get_node("DanoPeopleAnimation")
	check(people.actors[0].frames.size()==8 and people.actors[1].frames.size()==8,"upper women have eight drawn grooming poses")
	check(art.get_node("RestingWoman").get_meta("swimming") and art.get_node("BathingWomen").get_meta("swimming"),"lower women use layered water treatment")
	var speech = world.dialogue
	var woman_frame := speech.npc.sprite_frames.get_frame_texture("default",0) as AtlasTexture
	check(woman_frame!=null and woman_frame.atlas.resource_path == "res://art/stage1/dano/swing_woman_user_v2.png","user replacement woman artwork used")
	check(speech.npc.sprite_frames.get_frame_count("default")==8,"eight swing frames")
	var margins:Array=[]
	for i in range(8): margins.append((speech.npc.sprite_frames.get_frame_texture("default",i) as AtlasTexture).margin.position)
	check(margins.all(func(value):return margins.count(value)==1),"each swing frame has a distinct pose offset")
	check(speech.npc.render_priority > art.get_node("LeftTree").render_priority,"woman in front of tree")
	await capture("stage1-start-layout")
	await e()
	check(not speech.active,"far E ignored")
	check(world.interaction_icon.visible,"Stage1 E marker remains visible outside interaction range")
	world.player.position = speech.global_position + Vector3(.8,.04,0)
	world.player.velocity = Vector3.ZERO
	await ticks(12)
	await e()
	check(speech.active and speech.bubble.visible,"near E opens shared dialogue")
	check(not world.interaction_icon.visible,"Stage1 E marker hides during speech")
	check(tree_puzzle.tutorial.step==tree_puzzle.tutorial.Step.CUT,"first player E starts the cutting tutorial")
	check(speech.line.text == "나무를 잘라서 다리를 만들어","exact NPC line")
	check(not world.player.input_locked,"shared nonmodal input behavior preserved")
	var elapsed: float = speech.elapsed
	await e()
	check(speech.elapsed > elapsed,"E does not duplicate or restart active speech")
	await capture("stage1-woman-dialogue")
	speech._process(speech.display_seconds+speech.fade_seconds)
	check(not speech.active,"shared timed end")
	var before: Vector3 = world.player.position
	Input.action_press("right")
	await ticks(20)
	Input.action_release("right")
	check(world.player.position.distance_to(before)>.2 and world.player.is_on_floor(),"real movement on platform")
	world.restart()
	world.transition.cancel()
	await ticks(5)
	check(not is_instance_valid(speech) and not world.dialogue.active,"restart removes old dialogue")
	world.load_stage(5)
	world.transition.cancel()
	await ticks(5)
	check(not world.stage_root.has_node("Stage1Artwork"),"other stage has no Stage1 artwork")
	check(world.dialogue.name == "WoodcutterDialogue" and not world.rune_candidates.is_empty(),"other stage retains shared NPC and lift")
	menu.queue_free()
	await ticks(2)
	print("Stage1 start/dialogue: ",checks," checks, failed=",failed)
	quit(1 if failed else 0)
