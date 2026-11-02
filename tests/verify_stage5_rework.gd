extends "res://tests/verify_fairy_story.gd"

func run() -> void:
	root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURES))
	world=load("res://scripts/grid_stage/world.gd").new();world.stage_number=8;root.add_child(world)
	world.transition.cancel();world.stage_intro.hide();world.player.input_locked=false
	await frames(5)
	var story=world.story
	check(story.trees.size()==4,"four individually painted trees")
	check(is_equal_approx(world.player.sprite.pixel_size,.0032),"player matches other stages")
	check(is_equal_approx(story.impostor.texture.get_height()*story.impostor.pixel_size,1.5),"impostor matches original scholar height")
	check(story.rat_marker.visible,"mouse icon above impostor")
	check(story.roof_cats.size()==3,"three roof cat variants")
	var actors:Array=story.roof_cats.duplicate();actors.append(world.dialogue.actor)
	for actor in actors:
		check(actor.frames.size()==4,"each cat owns four separate frame textures")
		check(actor.animations.chase.size()==4,"each cat owns four chase frames")
		for index:int in range(4):
			actor._set_frame(index)
			check(actor.texture.get_image().get_used_rect().has_area(),"animation cell is nonempty")
		var previous:int=actor.frame_index
		world.paused=true;actor._process(.5)
		check(actor.frame_index==previous,"cat animation respects pause")
		world.paused=false
		actor.play_animation("chase")
		var hashes:Array=[]
		for texture:Texture2D in actor.frames:
			var signature:int=hash(texture.get_image().get_data())
			check(not hashes.has(signature),"chase frames show distinct poses")
			hashes.append(signature)
		actor.play_animation("idle")
	for tree:Sprite3D in story.trees:
		var found:=false
		for piece:Dictionary in story.paper.pieces:
			if piece.source.sprite==tree:found=piece.border.visible and piece.body is RigidBody2D
		check(found,"tree has cuttable border and physical body")
		check(bool(tree.get_meta("paper_alpha_border",false)),"tree border follows alpha instead of filled hull")
	world.player.position=world.dialogue.position+Vector3(-.55,.04,0)
	for tick:int in range(25):await physics_frame
	check(world.nearest_interaction()==world.dialogue,"kitten is nearest E target")
	world._update_interaction_icon(0)
	check(world.interaction_icon.visible,"kitten E icon visible")
	check(world.interact_stone(),"kitten dialogue is available before puzzle clears")
	check(world.dialogue.bubble.body.text=="배고프다옹","exact kitten dialogue")
	world.dialogue._process(.2)
	var elapsed:float=world.dialogue.elapsed
	check(world.interact_stone() and world.dialogue.elapsed==elapsed,"repeat E does not restart speech")
	world.paused=true;world.dialogue._process(1)
	check(world.dialogue.elapsed==elapsed,"dialogue pauses")
	world.paused=false
	await capture("stage5_revision_overview")
	world.dialogue._process(4)
	check(not world.dialogue.active,"dialogue fades and finishes")
	var painting:Dictionary={}
	for piece:Dictionary in story.paper.pieces:
		if piece.source.sprite==story.beauty:painting=piece
	check(not painting.is_empty() and not painting.get("mounted_art",false),"beauty starts as original standing woman")
	var host:Node3D=world.stage_root.get_node("HighGoalAndTerrace")
	var wall_x:float=world.stage_data.raised[1][1].x*.2
	var hit:Dictionary={"collider":host,"position":Vector3(wall_x,1.5,-3.6),"normal":Vector3.RIGHT}
	var basis:=Basis(Vector3(0,0,-1),Vector3.UP,Vector3.RIGHT).scaled(Vector3.ONE*world.camera.size/1000)
	var pose:=Transform3D(basis,Vector3(wall_x+.008,1.5,-3.6))
	check(story._painting_surface_allowed(hit,pose,painting.polygon),"painting fits designated exit side wall")
	var ray:=PhysicsRayQueryParameters3D.create(Vector3(wall_x+.6,1.5,-3.6),Vector3(wall_x-.2,1.5,-3.6),5)
	var actual_hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not actual_hit.is_empty() and story._painting_surface_allowed(actual_hit,pose,painting.polygon),"real collision face accepts painting")
	var wrong:Dictionary=hit.duplicate();wrong.normal=Vector3.UP
	check(not story._painting_surface_allowed(wrong,pose,painting.polygon),"floor rejected")
	wrong=hit.duplicate();wrong.position=Vector3(3.6,1.5,-3.6)
	check(not story._painting_surface_allowed(wrong,pose,painting.polygon),"other terrace wall rejected")
	wrong=hit.duplicate();wrong.normal=Vector3.BACK
	check(not story._painting_surface_allowed(wrong,pose,painting.polygon),"front wall rejected")
	wrong=hit.duplicate();wrong.position.y=4.5
	check(not story._painting_surface_allowed(wrong,pose,painting.polygon),"hit outside designated wall rejected")
	painting.attached=false;painting.sticker=true;painting.host=host
	painting.host_pose=host.global_transform.affine_inverse()*pose
	painting.visual.global_transform=pose
	story.paper._process(0);story._on_piece_dropped(painting,Vector2.ZERO)
	check(story.distracted and painting.body.freeze,"mounted painting lures impostor and stays fixed")
	check(painting.mounted_art and painting.visual.mesh is QuadMesh,"attaching transforms woman into full mural")
	check(painting.paper_material.albedo_texture==story.beauty.get_meta("paper_mounted_texture"),"mural contains painted backdrop")
	check(painting.permanent and painting.consumed_by_mural,"mural consumes and locks beauty")
	check(not painting.visual.visible,"small sticker hidden behind full wall mural")
	var block:Array=world.stage_data.raised[1]
	var extent:Vector3=(Vector3(block[1])-Vector3(block[0]))*.2
	check(story.mural.mesh.size.is_equal_approx(Vector2(extent.z,extent.y)),"mural covers entire designated face")
	story.paper._begin_drag(painting)
	check(story.paper.grabbed_piece.is_empty(),"permanent mural cannot be dragged")
	var soak:float=story.mural.elapsed
	world.paused=true;story.mural._process(1)
	check(story.mural.elapsed==soak,"mural soak pauses")
	world.paused=false
	await create_timer(2.5).timeout
	check(is_equal_approx(story.mural.elapsed,2.4),"mural soaking completes")
	await capture("stage5_revision_wall_painting")
	check(story.cats.entries.size()==4,"NPC kitten and all roof cats are pursuers")
	story.cats.set_process(false)
	var fish_piece:Dictionary={}
	for piece:Dictionary in story.paper.pieces:
		if piece.source.sprite==story.fish:fish_piece=piece;break
	var fish_pose:Transform2D=fish_piece.body.transform
	var cut_y:float=-fish_piece.source.image.get_height()*fish_piece.source.scale*.25
	story.paper._cut(fish_pose*Vector2(-500,cut_y),fish_pose*Vector2(500,cut_y))
	story.paper._process(0)
	for piece:Dictionary in story.paper.pieces:
		if piece.source.sprite==story.fish and not piece.attached:fish_piece=piece;break
	check(not fish_piece.is_empty(),"cut fish activates all-cat chase")
	fish_piece.sticker=true;fish_piece.host=host;fish_piece.attached=false
	var fish_basis:=Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP).scaled(Vector3.ONE*world.camera.size/1000)
	fish_piece.host_pose=host.global_transform.affine_inverse()*Transform3D(fish_basis,Vector3(.4,1.82,-2.4))
	story.paper._process(0);story.cats._process(.2)
	var positions:Array[Vector3]=[]
	for entry:Dictionary in story.cats.entries:
		check(entry.actor.animation=="chase","every cat plays its own rush animation")
		check(entry.mover.global_position.distance_to(entry.home)>.01,"every cat leaves its starting spot")
		positions.append(entry.mover.global_position)
	world.paused=true;story.cats._process(2)
	for index:int in range(4):check(story.cats.entries[index].mover.global_position==positions[index],"all pursuit pauses")
	world.paused=false
	await capture("stage5_revision_all_cats_rushing")
	story.cats._process(2)
	for entry:Dictionary in story.cats.entries:
		check(entry.mover.global_position.distance_to(entry.goal)<.3,"every cat lands around the fish")
	fish_piece.host_pose.origin.x+=1.0;story.paper._process(0);story.cats._process(.1)
	for entry:Dictionary in story.cats.entries:check(entry.actor.animation=="chase","moving bait retargets every cat")
	var source_piece:Dictionary={}
	for piece:Dictionary in story.paper.pieces:
		if piece.source.sprite==story.trees[0]:source_piece=piece;break
	var cut_pose:Transform2D=source_piece.body.transform
	story.paper._cut(cut_pose*Vector2(-500,0),cut_pose*Vector2(500,0))
	var loose:Array[Dictionary]=[]
	for piece:Dictionary in story.paper.pieces:
		if piece.source.sprite==story.trees[0] and not piece.attached:loose.append(piece)
	check(not loose.is_empty(),"new tree artwork can be cut into loose pieces")
	for tick:int in range(5):await physics_frame
	var falling:=false
	for piece:Dictionary in loose:
		if not piece.body.freeze and piece.body.linear_velocity.y>0:falling=true
	check(falling,"cut tree fragments fall under real gravity")
	fish_piece.host_pose.origin=story.rat_view+Vector3(.25,.02,0)
	story.paper._process(0);story.cats._process(2)
	story.rat_base=story.rat_view;story.distracted=true;story._advance_cat(0)
	check(story.caught and story.path_open,"fish crowd catches distracted impostor and opens exit")
	world.restart();world.transition.cancel();world.stage_intro.hide()
	check(not world.dialogue.active and world.story.roof_cats.size()==3,"restart resets dialogue and actors")
	check(not world.story.cats.active and world.story.cats.entries.size()==4,"restart restores all four pursuers")
	check(is_equal_approx(world.player.sprite.pixel_size,.0032),"restart retains normal player scale")
	world.queue_free();await frames()
	if not failed:print("PASS: %d Stage5 rework checks"%checks)
	quit(1 if failed else 0)
