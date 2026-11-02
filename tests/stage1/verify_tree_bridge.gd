extends "res://tests/stage1/verify_start_dialogue.gd"
# Optional regression; current project rules permit check-only parsing, not running.
var puzzle:Node

func attached_piece(index:int) -> Dictionary:
	for piece:Dictionary in puzzle.paper.pieces:
		if piece.source.sprite==puzzle.trees[index] and piece.attached:return piece
	return {}

func loose_piece(index:int) -> Dictionary:
	var best:Dictionary={}
	for piece:Dictionary in puzzle.paper.pieces:
		if piece.source.sprite!=puzzle.trees[index] or piece.attached or piece.sticker:continue
		if best.is_empty() or puzzle.paper._area(piece.polygon)>puzzle.paper._area(best.polygon):best=piece
	return best

func cut_tree(index:int) -> void:
	var piece:=attached_piece(index)
	check(not piece.is_empty(),"tree has attached cuttable paper")
	if piece.is_empty():return
	var bounds:=Rect2(piece.polygon[0],Vector2.ZERO)
	for point:Vector2 in piece.polygon:bounds=bounds.expand(point)
	var y:=bounds.position.y+bounds.size.y*.65
	puzzle.paper._cut(piece.body.transform*Vector2(bounds.position.x-20,y),piece.body.transform*Vector2(bounds.end.x+20,y))
	await ticks(2)

func run() -> void:
	root.size=Vector2i(1280,720)
	world=load("res://scenes/grid_stage/main.tscn").instantiate()
	world.stage_number=4;root.add_child(world)
	world.transition.cancel();world.stage_intro.hide()
	await ticks(10)
	puzzle=world.stage_root.get_node("Stage1TreeBridge")
	check(not puzzle.bridge_previews[0].visible and puzzle.bridges.is_empty(),"route preview stays hidden until a fragment is grabbed")
	puzzle.tutorial.start()
	check(puzzle.tutorial.target==puzzle.trees[1],"tutorial targets the left ordinary tree rather than the swing tree")
	await cut_tree(1)
	check(puzzle.tutorial.is_drag_step() and not puzzle.tutorial.dashes.visible,"cut replaces the dashed tutorial with the drag tutorial")
	var wood:=loose_piece(1)
	check(not wood.is_empty(),"cut keeps an actual detached tree fragment")
	if not wood.is_empty():
		check(wood.body is RigidBody2D and not wood.body.freeze and wood.body.gravity_scale>0,"loose wood uses gravity")
		check(wood.body.get_child_count()==1,"convex tree fragment needs only one collision shape")
		var size_before:float=puzzle.paper._area(wood.polygon)
		var texture_before:Texture2D=wood.source.texture
		var target:Vector2=puzzle.paper._screen(world.camera.unproject_position((puzzle.start+puzzle.crest)*.5))
		puzzle._on_piece_dropped(wood,target)
		check(wood.sticker and wood.host==puzzle.bridges[0],"real wood mounts on the route")
		check(wood.source.texture==texture_before and is_equal_approx(puzzle.paper._area(wood.polygon),size_before),"mounted wood preserves its artwork and cut shape")
		var ready:bool=puzzle.tree_bridge.ready_to_walk(0)
		for body:Node in puzzle.bridges[0].get_children():
			if body is StaticBody3D:check((body.collision_layer==1)==ready,"collision follows actual 55 percent coverage")
		puzzle.tree_bridge.tick(3.9)
		check(puzzle.regrowing.has(puzzle.trees[1]),"ordinary tree grows from its root instead of appearing instantly")
		puzzle._tick_regrowth(1.5)
		check(puzzle.paper.pieces.has(wood) and wood.sticker,"regrowth preserves mounted wood")
	check(not attached_piece(1).is_empty(),"ordinary tree regrows")
	var woman=world.dialogue
	await cut_tree(0)
	check(puzzle.warned and not puzzle.cut_done[0],"swing tree first gives the warning")
	woman._process(woman.display_seconds+woman.fade_seconds+.1)
	await cut_tree(0)
	check(woman.falling and woman.npc.get_meta("paper_foreground",false),"falling woman uses foreground")
	check(not puzzle.tree_bridge.growth.has(puzzle.trees[0]),"swing tree never enters regrowth queue")
	var stump:=attached_piece(0)
	puzzle.tree_bridge.tick(5.0)
	check(attached_piece(0)==stump,"swing stump is not replaced after regrowth delay")
	await ticks(240)
	check(woman.landed and woman.fall_body.grounded,"woman lands with physical contact")
	if woman.landed:
		check(woman.global_position.distance_to(woman.fall_body.global_position)<.05,"interaction anchor follows landing")
		check(woman.lines==PackedStringArray(["나빠"]),"landed woman says the requested line")
		world.player.position=woman.global_position+Vector3(.6,.04,0)
		world.player.velocity=Vector3.ZERO
		await ticks(12);await e()
		check(woman.active and woman.line.text=="나빠","nearby E opens the landed dialogue")
	var count:int=puzzle.paper.pieces.size()
	world._respawn()
	check(puzzle.paper.pieces.size()==count and puzzle.cut_done[0],"respawn preserves cuts and bridge pieces")
	world.restart();world.transition.cancel();await ticks(5)
	puzzle=world.stage_root.get_node("Stage1TreeBridge")
	check(not puzzle.cut_done[0] and puzzle.bridges.is_empty(),"explicit restart resets the puzzle")
	world.queue_free();await ticks(2)
	print("Stage1 accumulating bridge: ",checks," checks, failed=",failed)
	quit(1 if failed else 0)
