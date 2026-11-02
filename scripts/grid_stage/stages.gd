class_name GridStageDefinitions
extends RefCounted
static func get_stage(number:int) -> Dictionary:
	if number>=4:return preload("res://scripts/grid_stage/lotus_stages.gd").get_stage(clampi(number-3,1,9))
	var base:Dictionary={
		"start":Vector3(-4.2,.04,2.2),"camera_size":11.2,"focus":Vector3(-.4,.4,1),
		"low":[[Vector3i(-27,-4,4),Vector3i(-15,0,19)],[Vector3i(-15,-4,-4),Vector3i(-4,0,10)]],
		"raised":[[Vector3i(4,-4,-4),Vector3i(24,9,7)]],
		"lifts":[Vector3.ZERO],"goal_cells":[Vector3i(18,8,-2),Vector3i(23,9,3)],
		"goal_rect":Rect2(3.6,-.4,1.0,1.0),"goal_height":1.8,
		"waypoints":[Vector3(-3.2,0,1.4),Vector3(-1.7,0,.2),Vector3.ZERO,Vector3(4,1.8,0)]}
	if number==2:
		base.camera_size=12.8;base.focus=Vector3(-.1,.6,-.3)
		base.raised=[[Vector3i(4,-4,-4),Vector3i(20,9,7)],[Vector3i(12,-4,-20),Vector3i(20,9,-4)]]
		base.goal_cells=[Vector3i(13,8,-19),Vector3i(18,9,-14)]
		base.goal_rect=Rect2(2.6,-3.8,1,1)
		base.waypoints=[Vector3(-3.2,0,1.4),Vector3(-1.7,0,.2),Vector3.ZERO,Vector3(3.2,1.8,0),Vector3(3.2,1.8,-3.3)]
	elif number==3:
		base.start=Vector3(-5.2,.04,2.2);base.camera_size=14.3;base.focus=Vector3(-.7,1.1,-1)
		base.low=[[Vector3i(-31,-4,4),Vector3i(-19,0,19)],[Vector3i(-19,-4,-4),Vector3i(-12,0,10)]]
		base.raised=[[Vector3i(-4,-4,-4),Vector3i(12,9,8)],[Vector3i(4,-4,-27),Vector3i(18,18,-12)]]
		base.lifts=[Vector3(-1.6,0,0),Vector3(1.6,1.8,-1.6)]
		base.goal_cells=[Vector3i(8,17,-25),Vector3i(13,18,-20)]
		base.goal_rect=Rect2(1.6,-5,1,1);base.goal_height=3.6
		base.waypoints=[Vector3(-4,0,1),Vector3(-2.7,0,.2),Vector3(-1.6,0,0),Vector3(1.6,1.8,0),Vector3(1.6,1.8,-1.6),Vector3(2.1,3.6,-4.5)]
	return base
