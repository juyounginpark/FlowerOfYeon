extends "res://tests/verify_fairy_story.gd"
# Future runtime regression only. Do not execute under the current AGENTS.md;
# --check-only parses this file without instantiating or simulating the game.

func seed_for(success:bool) -> int:
	var probe:=RandomNumberGenerator.new()
	for seed_value in range(1000):
		probe.seed=seed_value
		if (probe.randf()<.5)==success:return seed_value
	return -1

func finish_rescue(story:Node3D) -> void:
	for seconds:float in [1.3,1.5,.8,.5]:story._advance_rescue(seconds)

func run() -> void:
	world=load("res://scenes/grid_stage/main.tscn").instantiate();world.stage_number=6;root.add_child(world)
	world.transition.cancel();await frames(20)
	var story:Node3D=world.story;story.set_physics_process(false)
	check(world.rune_candidates.is_empty() and world.lift==null,"both movement blocks are removed")
	check(not world.stage_root.has_node("Stage3SunPuzzle") and not world.stage_root.has_node("Stage3Fish"),"old sun placement and tail-launch systems are not instantiated")
	check(not story.path_open and story.clouds.size()==10,"original cloud resource remains until the path opens")
	check(not world.player.prevent_walk_off_edges,"Stage3 permits stepping into the sea")
	check(world.interact_stone(),"NPC dialogue remains reachable before unlocking the path")
	world.dialogue.cancel()
	world.player.global_position=Vector3(2,-.3,3)
	story._begin_rescue()
	check(story.eligible_entries==0 and story.bridge_state=="waiting","walking off an edge cannot roll bridge chance")
	check(story.lotus.visible and world.player.input_locked,"lotus catches the entrant before returning")
	check(world.player.global_position.is_equal_approx(Vector3(2,-.3,3)),"water entry does not teleport to spawn")
	var clock:float=story.rescue_clock
	world.paused=true;story._physics_process(1)
	check(story.rescue_clock==clock,"pause freezes lotus rescue")
	world.paused=false;finish_rescue(story)
	check(story.rescue_state=="idle" and not world.player.input_locked,"lotus returns control after landing")
	story.rng.seed=seed_for(false);story._on_jump()
	world.player.global_position=Vector3(-2,-.3,3);story._begin_rescue()
	check(story.eligible_entries==1 and story.bridge_state=="waiting","failed 50 percent draw still rescues the player")
	story.respawn();check(story.eligible_entries==1,"repeated fall signal cannot reroll")
	finish_rescue(story)
	story.rng.seed=seed_for(true);story._on_jump()
	world.player.global_position=Vector3(2,-.3,3);story._begin_rescue()
	check(story.eligible_entries==2 and story.bridge_state=="assembling","successful jump entry starts bridge assembly")
	check(story.creatures.size()==16 and story.bridges.size()==2,"fish and turtles fill both spans")
	for bridge:StaticBody3D in story.bridges:
		check(bridge.collision_layer==0,"bridge remains unwalkable during animal leaps")
		for child in bridge.get_children():check(not child is GeometryInstance3D,"collider has no visible bridge mesh")
	story._advance_bridge(3);await physics_frame
	check(story.path_open and story.bridge_state=="open","arrival enables the transparent bridges")
	for bridge:StaticBody3D in story.bridges:check(bridge.collision_layer==1,"completed bridge collides with player")
	story._advance_clouds(1.8)
	check(story.clouds.is_empty(),"clouds scatter and disappear after opening")
	finish_rescue(story);story.respawn()
	check(story.path_open and story.bridges.size()==2,"subsequent rescue preserves open paths")
	world.restart();world.transition.cancel();await frames(3)
	check(not world.story.path_open and world.story.eligible_entries==0 and world.story.clouds.size()==10,"explicit restart resets the puzzle")
	world.queue_free();await frames()
	if not failed:print("PASS: Stage3 sea rework checks")
	quit(1 if failed else 0)
