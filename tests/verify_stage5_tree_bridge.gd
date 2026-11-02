extends "res://tests/verify_fairy_story.gd"

func cut_tree(story:Node3D) -> Dictionary:
	var rooted:Dictionary={}
	for piece:Dictionary in story.paper.pieces:
		if piece.source.sprite==story.trees[0] and piece.attached:rooted=piece;break
	check(not rooted.is_empty(),"regrown tree can be cut again")
	var pose:Transform2D=rooted.body.transform
	story.paper._cut(pose*Vector2(-500,0),pose*Vector2(500,0))
	var largest:Dictionary={};var area:=0.0
	for piece:Dictionary in story.paper.pieces:
		if piece.source.sprite==story.trees[0] and not piece.attached and not piece.sticker:
			var size:float=story.paper._area(piece.polygon)
			if size>area:area=size;largest=piece
	check(not largest.is_empty(),"real cut produces persistent wood")
	return largest

func run() -> void:
	root.size=Vector2i(1280,720)
	world=load("res://scripts/grid_stage/world.gd").new();world.stage_number=8;root.add_child(world)
	world.transition.cancel();world.stage_intro.hide();world.player.input_locked=false
	await frames(5)
	var story=world.story;story.set_process(false)
	var construction=story.tree_bridge
	var wood:=cut_tree(story)
	var original_polygon:PackedVector2Array=wood.polygon.duplicate()
	var old_body:RigidBody2D=wood.body
	world.paused=true;story._process(4)
	check(construction.growth.has(story.trees[0]),"pause prevents tree regrowth")
	world.paused=false;construction.tick(3.1)
	check(story.paper.pieces.has(wood) and is_instance_valid(old_body),"regrowing preserves detached physical wood")
	var a:Vector3=story.routes[0][0];var b:Vector3=story.routes[0][1]
	var midpoint:Vector3=a.lerp(b,.5)
	var drop:Vector2=story.paper._screen(world.camera.unproject_position(midpoint))
	# A truly small polygon cut out of the same source is accepted for assembly.
	var small:PackedVector2Array=PackedVector2Array([Vector2(-5,-5),Vector2(5,-5),Vector2(5,5),Vector2(-5,5)])
	story.paper._add_piece(wood.source,small,Transform2D.IDENTITY,false)
	var scrap:Dictionary=story.paper.pieces.back()
	check(story._bridge_candidate(scrap,drop)==0,"small scraps can be attached")
	story._on_piece_dropped(scrap,drop)
	check(not construction.ready_to_walk(0),"small fragment alone does not enable crossing")
	for body:StaticBody3D in story.bridges[0].get_children():check(body.collision_layer==0,"incomplete bridge has no walkable collision")
	story._on_piece_dropped(wood,drop)
	check(wood.polygon==original_polygon,"mount preserves original cut outline")
	check(is_equal_approx(wood.visual.basis.x.length(),world.camera.size/1000.0),"original horizontal scale retained")
	check(is_equal_approx(wood.visual.basis.y.length(),world.camera.size/1000.0),"original vertical scale retained without stretch")
	var before:float=construction.coverage[0]
	story.paper._add_piece(wood.source,wood.polygon,Transform2D(wood.body.rotation,Vector2.ZERO),false)
	var overlap:Dictionary=story.paper.pieces.back()
	construction.mount(0,overlap,drop)
	check(is_equal_approx(construction.coverage[0],before),"overlapping ink does not inflate filled area")
	var mounted_count:int=construction.layers[0].size()
	cut_tree(story);construction.tick(3.1)
	check(construction.layers[0].size()==mounted_count and wood.sticker,"regrowth leaves assembled bridge pieces intact")
	# Fill different positions with equally scaled real cut geometry.
	var right:Vector3=(b-a).normalized().cross(Vector3.UP).normalized()
	for row:int in range(8):
		for col:int in range(3):
			story.paper._add_piece(wood.source,wood.polygon,Transform2D(wood.body.rotation,Vector2.ZERO),false)
			var fragment:Dictionary=story.paper.pieces.back()
			var anchor:Vector3=a.lerp(b,(row+.5)/8.0)+right*(col-1)*.5
			construction.mount(0,fragment,story.paper._screen(world.camera.unproject_position(anchor)))
			if construction.ready_to_walk(0):break
		if construction.ready_to_walk(0):break
	print("Visible bridge coverage: ",construction.coverage[0])
	check(construction.ready_to_walk(0),"distributed ink unlocks crossing at 55 percent")
	check(story.bridges[0].find_children("*","MeshInstance3D",true,false).is_empty(),"bridge still has no solid 3D mesh")
	await physics_frame
	world.player.position=a+Vector3.UP*.15
	for tick:int in range(12):await physics_frame
	await walk_to(Vector2(b.x,b.z))
	check(world.player.position.y>b.y-.2,"player walks completed collage bridge")
	await capture("stage5_collage_bridge")
	var fragments:Array=construction.layers[0].duplicate()
	world.player.position=a+Vector3(-1.3,.12,0)
	for tick:int in range(20):await physics_frame
	story.crossed[0]=false;story.bridge_age[0]=2.0;story.rat_base=b
	story._process(.01)
	check(story.kick.index==0,"approaching completed bridge automatically triggers sabotage")
	for tick:int in range(20):
		if story.kick.phase=="kick":break
		story.kick.tick(.1)
	story.kick.tick(.35)
	check(story.bridges.has(0) and story.kick.actor.visible,"kick windup visible before damage")
	story.kick.tick(.14)
	check(not story.bridges.has(0) and story.kick.effect.visible,"impact removes support and displays generated effect")
	check(story.kick.bubble.visible and story.kick.bubble.body.text=="못올라오겠지 찍","kick taunt uses exact requested dialogue")
	for fragment:Dictionary in fragments:
		check(story.paper.pieces.has(fragment) and not fragment.sticker and not fragment.body.freeze,"kick releases original piece into real physics")
	world.paused=true
	var kick_time:float=story.kick.elapsed;story._process(1)
	check(story.kick.elapsed==kick_time,"kick and taunt pause with gameplay")
	world.paused=false
	story.kick.tick(.18)
	await capture("stage5_kick_impact")
	story.kick.tick(.7)
	check(not story.kick.actor.visible and story.impostor.visible,"kick restores normal actor")
	world.restart();world.transition.cancel();world.stage_intro.hide()
	check(world.story.tree_bridge.layers.is_empty() and world.story.kick.index==-1,"restart clears construction and kick state")
	world.queue_free();await frames()
	if not failed:print("PASS: %d Stage5 collage/regrowth/kick checks"%checks)
	quit(1 if failed else 0)
