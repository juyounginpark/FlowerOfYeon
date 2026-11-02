extends SceneTree
# Authorized CPU/headless runtime regression checks for the current Stage6.
var world:GridStageWorld
var menu:Control
var failures:=0

func _initialize() -> void:
	call_deferred("run")

func check(value:bool,message:String) -> void:
	print("PASS " if value else "FAIL ",message)
	if not value:failures+=1

func frames(count:int) -> void:
	for i in range(count):await physics_frame

func wait_phase(story:Node,wanted:int,limit:=900) -> bool:
	for i in range(limit):
		if story.phase==wanted:return true
		await physics_frame
	return false

func drag(a:Vector2,b:Vector2) -> void:
	var motion:=InputEventMouseMotion.new();motion.position=a;Input.parse_input_event(motion)
	var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.position=a;press.pressed=true
	Input.parse_input_event(press);await frames(2)
	for step:int in range(1,7):
		motion=InputEventMouseMotion.new();motion.position=a.lerp(b,step/6.0);motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion);await frames(1)
	var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.position=b
	Input.parse_input_event(release);await frames(3)

func source_piece(sprite:Sprite3D,loose:=false) -> Dictionary:
	var found:Dictionary={};var largest:=0.0
	for piece:Dictionary in world.story.paper.pieces:
		if piece.source.sprite!=sprite or (loose and piece.attached):continue
		var area:float=world.story.paper._area(piece.polygon)
		if area>largest:found=piece;largest=area
	return found

func ink_point(piece:Dictionary) -> Vector2:
	var source:Dictionary=piece.source
	for y:int in range(0,source.image.get_height(),8):
		for x:int in range(0,source.image.get_width(),8):
			if source.image.get_pixel(x,y).a<.8:continue
			if x<12 or y<12 or x>=source.image.get_width()-12 or y>=source.image.get_height()-12:continue
			if source.image.get_pixel(x-10,y).a<.8 or source.image.get_pixel(x+10,y).a<.8 or source.image.get_pixel(x,y-10).a<.8 or source.image.get_pixel(x,y+10).a<.8:continue
			var local:Vector2=(Vector2(x,y)-Vector2(source.image.get_size())*.5)*float(source.scale)
			if Geometry2D.is_point_in_polygon(local,piece.polygon):
				var screen:=world.camera.unproject_position(piece.visual.global_transform*Vector3(local.x,-local.y,0))
				var picked:Dictionary=world.story.paper._pick(world.story.paper._screen(screen))
				if picked.get("body")==piece.body:return screen
	return Vector2(-1,-1)

func tiger_ink(story:Node) -> Vector2:
	var tiger:Sprite3D=story.tiger
	var source:Image=tiger.texture.get_image()
	for y:int in range(source.get_height()/3,source.get_height(),3):
		for x:int in range(source.get_width()/3,source.get_width(),3):
			if source.get_pixel(x,y).a<.8:continue
			if x<12 or y<12 or x>=source.get_width()-12 or y>=source.get_height()-12:continue
			if source.get_pixel(x-10,y).a<.8 or source.get_pixel(x+10,y).a<.8 or source.get_pixel(x,y-10).a<.8 or source.get_pixel(x,y+10).a<.8:continue
			var pixel:=Vector2(source.get_width()-x-1 if tiger.flip_h else x,y)
			var offset:Vector2=(pixel-Vector2(source.get_size())*.5+Vector2(tiger.offset.x,-tiger.offset.y))*tiger.pixel_size
			return world.camera.unproject_position(tiger.global_position+world.camera.global_basis.x*offset.x-world.camera.global_basis.y*offset.y)
	return Vector2(-1,-1)

func cut_tree(story:Node,sprite:Sprite3D) -> void:
	var piece:=source_piece(sprite)
	if piece.is_empty():return
	var bounds:=Rect2(piece.polygon[0],Vector2.ZERO)
	for point:Vector2 in piece.polygon:bounds=bounds.expand(point)
	var y:=lerpf(bounds.position.y,bounds.end.y,.65)
	var ratio:=root.size.y/1000.0
	if sprite==story.rice:
		var x:=lerpf(bounds.position.x,bounds.end.x,.25)
		await drag((piece.body.transform*Vector2(x,bounds.position.y-15))*ratio,(piece.body.transform*Vector2(x,bounds.end.y+15))*ratio)
		return
	await drag((piece.body.transform*Vector2(bounds.position.x-15,y))*ratio,(piece.body.transform*Vector2(bounds.end.x+15,y))*ratio)

func run() -> void:
	root.size=Vector2i(1280,720)
	menu=load("res://scenes/grid_stage/menu.tscn").instantiate()
	root.add_child(menu);await frames(3)
	menu.select_map(9);world=menu.world
	await frames(10)
	check(is_instance_valid(world.story),"Stage6 loads")
	if not is_instance_valid(world.story):quit(1);return
	var story=world.story
	check(is_instance_valid(story.paper),"paper cutter configured")
	check(is_instance_valid(story.rope),"heaven rope configured")
	check(story.frames.size()==5,"five independent tiger frames")
	check(story.eat_frames.size()==3,"three isolated eating frames")
	check(not world.stage_root.get_node("ButterflyGuide").route.is_empty(),"butterfly route reaches the rope ledge")
	await frames(220)
	check(world.transition.book.state=="read","menu entrance reaches book reading state")
	await drag(Vector2(640,600),Vector2(640,600))
	for i in range(600):
		if not world.transition.active and not world.player.input_locked:break
		await physics_frame
	check(not world.transition.active and not world.player.input_locked,"book click releases playable Stage6")
	world.stage_intro.panel.hide()
	await frames(240)
	check(story.rush_episode>=2,"tiger rush repeats")
	var timer:float=story.phase_time
	world.paused=true;world.player.paused=true;await frames(20)
	check(is_equal_approx(timer,story.phase_time),"pause freezes tiger state")
	world.paused=false
	# Freeze only AI while native input delivers rice to a visible emergence pose.
	for feeding in range(3):
		story.set_physics_process(false);world.player.paused=true
		story._start_rush();story.rush_time=.45;story._hunt(0.0);story._place_tiger()
		await frames(2)
		await cut_tree(story,story.rice)
		var rice_piece:=source_piece(story.rice,true)
		check(not rice_piece.is_empty(),"native cut releases a basket portion")
		if rice_piece.is_empty():break
		var remaining:int=story.paper.pieces.size()
		await drag(ink_point(rice_piece),tiger_ink(story))
		check(story.fed_total==feeding+1,"native rice drop increments exactly once")
		check(story.paper.pieces.size()==remaining-1,"only the fed portion is consumed")
		check(story.phase==story.Phase.EAT,"feeding starts airborne eating")
		story.set_physics_process(true)
		check(await wait_phase(story,story.Phase.FED_RETREAT,100),"eating finishes before retreat")
		if feeding<2:check(await wait_phase(story,story.Phase.HUNT,100),"fed tiger retreats before rushing again")
	check(await wait_phase(story,story.Phase.READY),"three feedings sleep and lower rope")
	check(is_equal_approx(story.tiger.pixel_size*story.tiger.texture.get_height(),.95*3),"sleeping tiger has triple scale")
	check(is_equal_approx(story.rope.scale.x*story.rope.texture.get_width(),.48),"rope width is tripled")
	# A real cut must release a physics fragment; native drop uses Stage5 coverage.
	story.set_physics_process(false)
	await cut_tree(story,story.trees[0])
	var wood:=source_piece(story.trees[0],true)
	check(not wood.is_empty(),"native stroke cuts tree into loose paper")
	if not wood.is_empty():
		check(wood.body is RigidBody2D and not wood.body.freeze,"tree fragment uses gravity")
		var mid:Vector3=story.routes[0][0].lerp(story.routes[0][1],.5)
		await drag(ink_point(wood),world.camera.unproject_position(mid))
		check(story.bridges.has(0),"native wood drop creates Stage5 crossing")
		check(story.tree_bridge.coverage.get(0,0.0)>0,"crossing counts actual painted wood")
	story.set_physics_process(true)
	# First try: let the deadline expire, verify fall/retry and retained progress.
	world.player.position=story.ROPE_FOOT+Vector3(-.6,0,0)
	check(await wait_phase(story,story.Phase.CHASE),"rope touch climbs and wakes tiger")
	check(world.player.input_locked,"rope ascent holds player on rope")
	check(story.climb_art.visible and not world.player.sprite.visible and not story.sister.visible,"climbing artwork replaces standing actors")
	check(story.sister_base.y<world.player.position.y,"sister climbs below the player")
	check(world.player.position.y>=story.ROPE_FOOT.y+story.ASCENT_HEIGHT*.8,"tiger starts climbing only near the top")
	check(story.cut_top.y-story.cut_bottom.y>=2.4-.001,"rope has the widened cutting interval")
	check(story.climb_art.material_override.render_priority>story.rope.material_override.render_priority,"siblings draw ahead of rope")
	check(await wait_phase(story,story.Phase.FAILED,240),"uncut rope times out after three seconds")
	world.player.paused=false
	check(await wait_phase(story,story.Phase.READY,360),"failed escape returns to ready state")
	check(story.fed_total==3,"retry retains all three feedings")
	check(world.player.position.distance_to(world.start_position)<.3,"retry restores player start")
	check(not story.climb_art.visible and world.player.sprite.visible and story.sister.visible,"retry restores standing artwork")
	check(story.bridges.has(0),"retry preserves assembled tree pieces")
	# Second try: cut through the highlighted interval using actual input events.
	world.player.paused=true;world.player.position=story.ROPE_FOOT+Vector3(-.6,0,0)
	check(await wait_phase(story,story.Phase.CHASE),"second rope attempt starts")
	var cut:Vector2=world.camera.unproject_position(story.cut_bottom.lerp(story.cut_top,.5))
	await drag(cut+Vector2(-35,0),cut+Vector2(35,0))
	check(story.phase==story.Phase.ESCAPE,"native cut accepts highlighted rope interval")
	check(is_instance_valid(story.falling_tiger),"cut creates physical tiger and rope body")
	if is_instance_valid(story.falling_tiger):
		var fall_y:float=story.falling_tiger.global_position.y
		var fixed:Vector3=story.upper_rope.global_position
		await frames(30)
		check(story.falling_tiger.global_position.y<fall_y-.15,"tiger falls under engine gravity")
		check(story.upper_rope.global_position.is_equal_approx(fixed),"upper rope stays anchored")
		world.paused=true;await frames(2)
		var frozen:Vector3=story.falling_tiger.global_position
		await frames(20)
		check(story.falling_tiger.global_position.is_equal_approx(frozen),"pause freezes severed tiger physics")
		world.paused=false
	check(await wait_phase(story,story.Phase.CLEARED,900),"successful rope escape clears")
	check(story._climbers_above_screen(),"both siblings fully leave the top of screen before clear")
	check(world.completed,"shared world receives stage clear")
	# Recreate the stage node: the feeding count must survive explicit Home retry.
	world.restart();await frames(5)
	check(world.story.fed_total==3,"Home restart preserves feeding progress")
	print("STAGE6_REWORK_RESULT failures=",failures)
	menu.queue_free();await process_frame;quit(failures)
