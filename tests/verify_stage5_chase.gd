extends "res://tests/verify_fairy_story.gd"

func run() -> void:
	root.size=Vector2i(1280,720)
	world=load("res://scripts/grid_stage/world.gd").new();world.stage_number=8;root.add_child(world)
	world.transition.cancel();world.stage_intro.hide();world.player.input_locked=false
	await frames(5)
	var story=world.story
	var fish:Dictionary={}
	for piece:Dictionary in story.paper.pieces:
		if piece.source.sprite==story.fish:fish=piece;break
	var pose:Transform2D=fish.body.transform
	var y:float=-fish.source.image.get_height()*fish.source.scale*.25
	story.paper._cut(pose*Vector2(-500,y),pose*Vector2(500,y))
	await frames(2)
	for piece:Dictionary in story.paper.pieces:
		if piece.source.sprite==story.fish and not piece.attached:fish=piece;break
	check(not fish.is_empty(),"actual fish cut produces bait")
	var host:Node3D=world.stage_root.get_node("HighGoalAndTerrace")
	fish.sticker=true;fish.host=host
	var orientation:=Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP).scaled(Vector3.ONE*world.camera.size/1000)
	fish.host_pose=host.global_transform.affine_inverse()*Transform3D(orientation,Vector3(2,1.82,-2.2))
	await create_timer(.2).timeout
	check(story.cats.phase=="bait","fish landing precedes impostor chase")
	var landing:Vector3=story.cats._landing(fish)
	for entry:Dictionary in story.cats.entries:
		check(entry.goal.distance_to(landing)<.5 and entry.actor.animation=="chase","every cat jumps toward mounted fish first")
	await create_timer(1.4).timeout
	check(story.cats.phase=="chase","all cats transition from bait arrival to impostor chase")
	var positions:Array[Vector3]=[]
	for entry:Dictionary in story.cats.entries:
		check(entry.arrived,"each cat completed its bait landing")
		positions.append(entry.mover.global_position)
	await create_timer(1.5).timeout
	for index:int in range(4):
		check(story.cats.entries[index].mover.global_position.distance_to(positions[index])>.2,"cat keeps pursuing moving impostor")
	fish.host_pose.origin.x-=1.8
	story.paper._process(0);story._on_piece_dropped(fish,Vector2.ZERO)
	await create_timer(.2).timeout
	check(story.cats.phase=="bait","new fish placement interrupts pursuit with another bait jump")
	landing=story.cats._landing(fish)
	for entry:Dictionary in story.cats.entries:check(entry.goal.distance_to(landing)<.5,"each cat targets new fish location")
	await create_timer(1.4).timeout
	check(story.cats.phase=="chase","impostor chase resumes after second fish landing")
	await capture("stage5_bait_then_chase")
	world.queue_free();await frames()
	if not failed:print("PASS: %d live Stage5 chase checks"%checks)
	quit(1 if failed else 0)
