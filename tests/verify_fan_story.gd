extends "res://tests/verify_fairy_story.gd"
var story:Node3D
func settle(count:=30) -> void:
	for tick in range(count):await physics_frame
func drag_fan(id:String) -> void:
	var cutter:GridPaperCutting=story.items[id].cutter
	var center:=world.camera.unproject_position(cutter.pieces[0].visual.global_position)
	var point:=center;var found:=false
	for offset:Vector2 in [Vector2.ZERO,Vector2(-40,0),Vector2(40,0),Vector2(0,40),Vector2(-60,30)]:
		if not cutter._pick(cutter._screen(center+offset)).is_empty():point=center+offset;found=true;break
	check(found,"visible fan can be picked: "+id)
	mouse_button(point,true)
	check(story.dragging==id,"pointer press begins drag, not equip")
	mouse_motion(Vector2(780,470));await frames(3)
	check(is_instance_valid(story.drag_view) and story.drag_layer.layer==100,"drag uses topmost overlay")
	check(story.items[id].proxy.layers==1<<21,"dragged fan is isolated from map depth passes")
	await capture("fan_v2_drag_front_"+id)
	mouse_motion(story._player_rect().get_center())
	check(story.drag_scale<.15,"fan shrinks to icon size near player")
	mouse_button(story._player_rect().get_center(),false)
	check(story.held_fan==id,"drop on player equips "+id)
	await frames(3)
func click_fan() -> void:
	mouse_button(Vector2(1000,620),true);mouse_button(Vector2(1000,620),false)
func run() -> void:
	root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURES))
	world=load("res://scripts/grid_stage/world.gd").new();world.stage_number=7;root.add_child(world)
	world.transition.cancel();world.stage_intro.hide();world.player.input_locked=false;story=world.story
	await settle()
	check(story.items.blue.anchor.x<story.items.red.anchor.x,"blue fan is left of red fan")
	check(story.NPC_LINES==["부채를 부쳐보겠능감?"],"NPC uses requested dialogue")
	check(world.rune_candidates.is_empty() and world.lift==null,"Stage4 has no moving platforms")
	check(not story.equip("red"),"hanging fan cannot be equipped")
	world.player.position=story.NPC_FOOT+Vector3(.5,.04,.3);await settle()
	world._update_interaction_icon(0)
	check(world.interaction_icon.visible,"shared E indicator selects NPC")
	await key(KEY_E)
	check(story.npc_intro.visible and not world.player.input_locked,"shared nonblocking dialogue")
	await key(KEY_E);check(story.npc_interactions==1,"speech is not restarted by repeat E")
	await capture("fan_v2_hanging")
	for id:String in ["red","blue"]:
		var item:Dictionary=story.items[id]
		var fan:Dictionary=item.cutter.pieces[0]
		check(fan.border.visible,"fan has a color identification border")
		var before:int=item.cutter.pieces.size()
		item.cutter._cut(Vector2(-1000,fan.body.position.y),Vector2(3000,fan.body.position.y))
		check(item.cutter.pieces.size()==before,"fan itself cannot be cut")
		var cord:Dictionary=story.ropes[id]
		var point:Vector2=cord.top.lerp(cord.end,.65)
		check(story.cut_at(point-Vector2(30,0),point+Vector2(30,0)),"cord cut releases "+id)
		var fixed_parts:Array=cord.cutter.pieces.filter(func(piece):return piece.attached)
		check(fixed_parts.size()==1,"one ceiling-side cord remains anchored")
		var fixed_position:Vector2=fixed_parts[0].body.position
		var y:float=fan.body.position.y
		await settle(20)
		check(fan.body.position.y>y+2 and not fan.attached,"released fan falls under real gravity")
		check(fixed_parts[0].body.freeze and fixed_parts[0].body.position.distance_to(fixed_position)<.01,"upper cord stays fixed while lower pieces fall")
		check(not cord.intact and item.loose,"cut state persists")
	await settle(120)
	await capture("fan_v2_fallen")
	var red_visual:MeshInstance3D=story.items.red.cutter.pieces[0].visual
	var click_point:=world.camera.unproject_position(red_visual.global_position)
	mouse_button(click_point,true);mouse_button(click_point,false)
	check(story.held_fan.is_empty(),"plain fan click does not equip")
	await settle(90)
	await drag_fan("red")
	check(not story.items.red.cutter.pieces[0].visual.visible,"equipped world fan is hidden")
	check(world.player.equipped_fan_marker.visible and world.player.equipped_fan_marker.texture.resource_path.ends_with("red_folding_v2.png"),"red icon appears above head")
	await capture("fan_v2_equipped_marker")
	var red_position:Vector2=story.items.red.cutter.pieces[0].body.position
	await drag_fan("blue")
	check(story.items.red.transit and story.items.red.proxy.visible and not story.items.red.cutter.pieces[0].visual.visible,"old fan returns from icon without immediate full-size pop")
	check(world.player.equipped_fan_marker.texture.resource_path.ends_with("blue_folding_v2.png"),"head icon switches to blue")
	await settle(18);await capture("fan_v2_return_enlarging")
	await settle(70)
	check(not story.items.red.transit and story.items.red.cutter.pieces[0].visual.visible and not story.ropes.red.intact,"returned fan remains loose")
	check(story.items.red.cutter.pieces[0].body.position.distance_to(red_position)<5,"return flight ends in a physical drop at saved position")
	story.respawn();await settle()
	check(story.held_fan=="blue" and not story.ropes.red.intact,"respawn preserves inventory and cut state")
	click_fan();await settle(20)
	check(story.neck_clicks==1 and is_equal_approx(story.neck_length,story.body_height*.1),"blue click extends neck by one tenth of body height")
	check(story.growth_clicks==0 and not world.player.input_locked,"blue neck does not grow nose or lock movement")
	await capture("fan_v2_neck_one")
	for count in range(25):click_fan();await settle(8)
	await settle(60)
	check(story.neck_clicks==20 and is_equal_approx(story.neck_length,story.body_height*2),"neck caps at twenty increments")
	check(world.player.neck_length==story.neck_length,"head and icon follow neck extension")
	await capture("fan_v2_neck_max")
	await drag_fan("red");await settle(90)
	var home:Vector3=world.camera.position
	click_fan();await settle(40)
	check(story.growth_clicks==1 and story.nose_length<.2,"first click grows only a small amount")
	var length:float=story.nose_length
	var player_home:Vector3=world.player.position
	Input.action_press("right");await settle(10);Input.action_release("right")
	check(is_equal_approx(length,story.nose_length),"nose stops growing until another click")
	check(world.player.position.distance_to(player_home)>.05 and not world.player.input_locked,"first seven clicks allow movement")
	for count in range(2,8):click_fan();await settle(18)
	check(not world.player.input_locked,"seventh click still allows movement")
	click_fan();await settle(18)
	player_home=world.player.position
	Input.action_press("right");await settle(20);Input.action_release("right")
	check(world.player.input_locked and world.player.position.distance_to(player_home)<.01,"eighth click locks movement")
	for count in range(9,11):click_fan();await settle(18)
	check(story.growth_clicks==10 and story.nose_length>3 and story.nose_length<4,"ten clicks remain below the sky threshold")
	var diagonal:Vector2=world.camera.unproject_position(story.nose_tip.position)-world.camera.unproject_position(story.nose_base)
	check(diagonal.x>0 and diagonal.y<0 and absf(diagonal.x+diagonal.y)<.1,"nose grows at 45 degrees")
	check((story.nose.global_transform*Vector3(.5,0,0)).distance_to(story.nose_tip.position)<.001,"cropped nose reaches its tip")
	await capture("fan_v2_nose_growing")
	world.paused=true;world.player.paused=true
	var count_before:int=story.growth_clicks;click_fan();await settle(20)
	check(story.growth_clicks==count_before,"pause rejects growth clicks")
	world.paused=false;world.player.paused=false
	for count in range(11,13):click_fan();await settle(18)
	check(story.sky_scene!=null and story.sky_scene.get_world_3d()!=world.get_world_3d(),"ascent enters separate cinematic sky")
	check(world.stage_number==7,"sky is an interlude, not a new map")
	await capture("fan_v2_sky_lower")
	for count in range(13,20):click_fan();await settle(18)
	check(story.state=="growing" and story.growth_clicks==19,"nineteen clicks do not finish ascent")
	var before_last:float=story.nose_length
	click_fan();await settle(30)
	check(story.growth_clicks==20 and story.nose_length-before_last>2,"twentieth click produces a larger final growth")
	check(story.state=="anger" and story.emperor.visible and story.brows.visible,"heaven is pierced and emperor reacts")
	check(is_equal_approx(story.emperor.pixel_size*story.emperor.texture.get_height(),27.0),"emperor keeps the original monumental scale")
	await capture("fan_v2_emperor")
	for tick in range(300):
		if story.state=="strike":break
		await physics_frame
	await settle(35);await capture("fan_v2_lightning")
	await settle(25)
	check(is_instance_valid(story.severed_nose),"coiling lightning creates a physical separated nose tip")
	await capture("fan_v2_nose_separated")
	for tick in range(900):
		if story.path_open and story.state=="map":break
		await physics_frame
	print("Bridge positions: ",story.bridges.map(func(entry):return entry.body.position))
	check(story.path_open and story.bridges.size()==2,"physical nose segments settle into two bridges")
	check(not world.player.input_locked and world.camera.position.distance_to(home)<.1,"camera and control return after impact")
	check(story.sky_scene==null and world.stage_number==7,"sky interlude is removed on return to original Stage4")
	await capture("fan_v2_bridges")
	# Walk the complete dogleg over the physical slopes without teleporting or lifts.
	world.player.position=Vector3(-2, .05,2);await settle()
	await walk_to(Vector2(1.05,.5))
	check(world.player.position.y>1.7,"first severed segment supports ascent to middle slab")
	await walk_to(Vector2(3.2,.3))
	await walk_to(Vector2(3.2,-2.6))
	check(world.player.position.y>3.4,"second severed segment supports ascent to upper slab")
	await walk_to(world.stage_data.goal_rect.get_center(),true)
	check(world.completed,"physical bridge route reaches goal")
	world.load_stage(7);world.transition.cancel();story=world.story
	check(story.ropes.red.intact and story.ropes.blue.intact and story.held_fan.is_empty(),"explicit restart alone resets fan state")
	world.queue_free();await frames()
	if not failed:print("PASS: %d Stage4 nose / fan / rope physics checks"%checks)
	quit(1 if failed else 0)
