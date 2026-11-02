extends "res://tests/verify_fairy_story.gd"
# Future authorized runtime regression only. Under AGENTS.md, compile with
# --headless --rendering-driver dummy --audio-driver Dummy --check-only.
# This simulation has NOT been executed for this revision.
var story:Node3D

func cut_branch() -> void:
	var branch:Node3D=story.perches[0].branch
	var a:Vector2=world.camera.unproject_position(branch.point_at(Vector2(.4,.2)))
	var b:Vector2=world.camera.unproject_position(branch.point_at(Vector2(.4,.96)))
	check(story.cut_at(a,b),"stroke cuts occupied branch")
	check(story.perches[0].state=="flight","branch cut starts flight")
	check(not story.cut_at(a,b),"same cut cannot duplicate a bird")
	check(not branch.fallen.is_empty(),"cut produces physical fragments")
	for body:RigidBody3D in branch.fallen:
		check(body.gravity_scale>0 and (body.collision_mask&1)!=0,"fragments use gravity and terrain collisions")
		var colliders:=0
		for child in body.get_children():
			if child is CollisionShape3D:colliders+=1
		check(colliders==1 and body.collision_mask==1,"one terrain-only collider per falling fragment")
		for child in body.get_children():
			if child is MeshInstance3D:check(child.mesh.get_surface_count()>0,"falling branch keeps drawable geometry")

func run() -> void:
	world=load("res://scripts/grid_stage/world.gd").new();world.stage_number=11;root.add_child(world)
	world.transition.cancel();await frames(5)
	story=world.story;story.set_process(false)
	check(not story.path_open and story.bridges.is_empty(),"stage begins without bridge")
	check(world.rune_candidates.size()==1 and world.rune_candidates[0].auto_board,"single automatic lift remains")
	for removed:String in ["crow","magpie","crow_npc","magpie_npc","couple","chart_branches_0","chart_branches_1"]:
		check(not story.items.has(removed),"old actor removed: "+removed)
	check(story.perches.size()==4 and story.VARIANTS.size()==6,"four perches and six variants")
	for perch:Dictionary in story.perches:
		check(perch.branch.intact.visible and perch.branch.intact.mesh.get_surface_count()>0,"uncut bough is drawable even if detailed contour triangulation fails")
	for frames_:Array in story.bird_frames.values():check(frames_.size()==4,"each bird has four frames")
	check(story.items.gyeonwu.sprite.visible and story.items.jiknyeo.sprite.visible,"A and B have distinct characters")
	check(story.speech_bubbles.size()==2 and not story.items.reunited_couple.sprite.visible,"reunion speech is hidden before the bridge")
	check(story.REQUIRED_BIRDS==15,"bridge requires fifteen arrivals")
	check(not story.starlight.activated and not story.starlight.stars.visible,"stars wait for the embrace")
	for id:String in ["gyeonwu","jiknyeo"]:
		check(story.walk_frames[id].size()==4,"each walker has four independent cropped frames")
	check(story.GYEONWU_LINE=="직녀를 만나러 가고싶어...","verbatim requested dialogue")
	check(story.targets.is_empty() and not story.drop_item("crow","crow"),"old drag delivery removed")
	var first_variant:int=story.perches[0].variant
	cut_branch()
	var fragment:RigidBody3D=story.perches[0].branch.fallen[0]
	var original_y:=fragment.position.y
	for tick in range(8):await physics_frame
	check(fragment.position.y<original_y,"branch fragment falls physically")
	check(story.arrived_count==0,"departure does not count as arrival")
	var bird_texture:Texture2D=story.flock[0].bird.sprite.texture
	var original_pixel:float=story.flock[0].bird.sprite.pixel_size
	story._process(1.1)
	check(story.flock[0].bird.sprite.texture==bird_texture and story.flock[0].bird.sprite.pixel_size==original_pixel,"flight and animation keep sprite geometry fixed")
	world.paused=true
	var flight_clock:float=story.flock[0].clock;story._process(3)
	check(story.flock[0].clock==flight_clock,"pause freezes flight")
	world.paused=false;story._process(1.1)
	check(story.arrived_count==1 and story.bridges.is_empty(),"one arrival cannot build bridge")
	check(is_equal_approx(story.flock[0].bird.sprite.global_basis.x.length(),1.0/3.0),"bird reaches exactly one-third size by transform")
	story._process(1);story._process(1)
	check(story.perches[0].state=="perched" and story.perches[0].variant!=first_variant,"regrowth brings a different bird")
	check(story.perches[0].branch.intact.visible and story.perches[0].branch.intact.mesh.get_surface_count()>0,"regrown bough retains visible geometry")
	world._respawn()
	check(story.arrived_count==1 and is_instance_valid(fragment),"fall recovery preserves progress and debris")
	for arrival in range(2,16):
		cut_branch()
		check(story.arrived_count==arrival-1,"release is not arrival")
		for tick in range(23):story._process(.1)
		check(story.arrived_count==arrival,"arrival counted once")
		if arrival<15:check(story.bridges.is_empty() and story.reunion_state=="waiting","fewer than fifteen arrivals cannot start the bridge or reunion")
		else:
			check(story.bridges.size()==1 and story.path_open and story.reunion_state=="walking","fifteenth arrival enables walkway and starts reunion")
			check(not story.bridge_collision.disabled,"transparent collision is walkable on completion")
		story._process(1);story._process(1)
	await frames(2)
	check(story.path_open and not story.bridge_collision.disabled,"gathered birds remain walkable")
	check(not story.items.has("ojakgyo"),"no additional Ojakgyo image is created")
	for flight:Dictionary in story.flock:
		check(flight.bird.sprite.visible and is_equal_approx(float(flight.bird.sprite.material_override.get_shader_parameter("opacity")),1.0),"arrived bird remains visible without a bridge-image fade")
	for child in story.bridges[0].get_children():check(not child is GeometryInstance3D,"bridge body has collision only")
	story._build_bridge(0);check(story.bridges.size()==1,"walkway creation is idempotent")
	var walk_clock:float=story.reunion_clock
	check(not story.starlight.activated,"walkway completion alone does not start twinkling")
	world.paused=true;story._process(1)
	check(story.reunion_clock==walk_clock,"pause freezes reunion walking")
	world.paused=false;story._process(story.REUNION_SECONDS)
	check(story.reunion_state=="embracing" and story.items.reunited_couple.sprite.visible,"couple embraces after walking")
	check(story.starlight.activated and story.starlight.stars.visible,"embrace starts mapped star twinkling")
	var sparkle_clock:float=story.starlight.elapsed
	world.paused=true;story._process(1)
	check(story.starlight.elapsed==sparkle_clock,"pause freezes star twinkling")
	world.paused=false
	check(not story.items.gyeonwu.sprite.visible and not story.items.jiknyeo.sprite.visible,"walking actors are replaced by the embrace")
	var midpoint:Vector3=(Vector3(story.routes[0][0])+Vector3(story.routes[0][1]))*.5
	check(Vector3(story.items.gyeonwu.feet).is_equal_approx(midpoint) and Vector3(story.items.jiknyeo.feet).is_equal_approx(midpoint),"both people meet at the bridge center")
	await walk_to(Vector2(0,1.7))
	for tick in range(240):
		if world.lift.position.y>=1.79:break
		await physics_frame
	await walk_to(Vector2(0,0));await walk_to(Vector2(0,-1.5))
	world._update_interaction_icon(0)
	check(world.nearest_interaction()==story.items.reunited_couple.sprite and world.interaction_icon.visible,"shared E selects embracing couple")
	check(world.interact_stone(),"E speaks to reunited couple")
	check(story.speech_bubbles.reunited_couple.label.text=="사랑해요,\n사랑해요","hanji bubble displays requested two lines")
	story._process(.2);var speech_clock:float=story.speech_bubbles.reunited_couple.elapsed
	world.paused=true;story._process(1)
	check(story.speech_bubbles.reunited_couple.elapsed==speech_clock,"pause freezes speech")
	world.paused=false
	check(world.interact_stone() and story.speech_bubbles.reunited_couple.elapsed==speech_clock,"repeated E does not restart speech")
	await walk_to(Vector2(0,0));await walk_to(Vector2(0,-.4));await walk_to(Vector2(0,-3.1))
	check(world.player.position.y>3.5,"transparent bird walkway reaches upper terrace")
	world.restart();world.transition.cancel();await frames(5)
	check(world.story.arrived_count==0 and world.story.bridges.is_empty() and not world.story.path_open,"restart resets flock and bridge")
	world.queue_free();await frames()
	if not failed:print("PASS: %d Stage8 rework checks"%checks)
	quit(1 if failed else 0)
