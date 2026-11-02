extends RefCounted
const STORY_NAMES:=["단오","선녀와 나무꾼","심청전","빨간부채  파란부채","손톱먹은 쥐","해와 달이 된 오누이","흥부전","견우와 직녀","용이 되지 못한 이무기"]
static func story_title(number:int) -> String:
	return STORY_NAMES[number-1] if number>=1 and number<=STORY_NAMES.size() else ""
# Independent cuboid compositions on PreMap3's 0.2 m grid.
# A one-cell inset leaves 0.4 m between neighboring authored footprints.
static func box(x0:int,y0:int,z0:int,x1:int,y1:int,z1:int) -> Array:
	return [Vector3i(x0,y0,z0),Vector3i(x1,y1,z1)]

static func get_stage(number:int) -> Dictionary:
	number=clampi(number,1,9)
	var d:Dictionary={"low":[],"raised":[],"lifts":[],"lift_delta":Vector3(0,1.8,0),
		"start":Vector3.ZERO,"goal_cells":[],"goal_height":3.6,"camera_size":14.3,
		"focus":Vector3.ZERO,"fixed_camera":true,"waypoints":[]}
	d.theme="water" if number<=3 else "earth" if number<=6 else "sky"
	d.story_title=story_title(number)
	match number:
		1: # Stem: wide starting pad and opposite raised pad, without a lift.
			d.layout_name="Stem"
			# Original visible pad is 11 cells wide after the shared inset.
			# Add two pad-widths (22 cells) on each side, keeping its center.
			d.low=[box(-28,-4,4,29,0,18)]
			d.raised=[box(-6,-4,-19,7,9,-4)]
			d.lifts=[]
			d.guide_can_cross_gap=true
			d.start=Vector3(.1,.04,2.2)
			d.goal_cells=box(0,8,-13,5,9,-8)
		2: # Elbow: one wide horizontal entry and a narrow upright tip.
			d.layout_name="Elbow"
			d.low=[box(-22,-4,4,5,0,14)]
			d.raised=[box(-5,-4,-18,16,9,-4)]
			d.lifts=[]
			d.sea_bridges=[[Vector3(0,0,1.15),Vector3(0,1.8,-1.15)]]
			d.start=Vector3(-3.4,.04,1.8)
			d.goal_cells=box(9,8,-13,14,9,-8)
		3: # Three centered terraces: a small square, broad slab and tall cube.
			d.layout_name="Terraces"
			d.low=[box(-6,-4,12,6,0,24)]
			d.raised=[box(-14,-4,-4,14,9,4),box(-12,-4,-36,12,18,-12)]
			d.lifts=[] # Sea creatures connect both gaps after a successful jump into water.
			# Reach terrace height 5 cm before its front edge, then use a level landing.
			d.sea_bridges=[[Vector3(0,0,2.7),Vector3(0,1.8,.85)],[Vector3(0,1.8,-.5),Vector3(0,3.6,-2.35)]]
			d.start=Vector3(0,.04,3.4)
			d.goal_cells=box(-10,17,-22,-5,18,-17)
		4: # Three slabs in a single right-hand dogleg; no side branches.
			d.layout_name="Dogleg"
			d.low=[box(-22,-4,-4,-4,0,12)]
			d.raised=[box(4,-4,-4,20,9,6),box(10,-4,-26,30,18,-12)]
			d.lifts=[] # Stage4 is crossed on the severed nose bridges.
			d.nose_bridges=[[Vector3(-2,0,2),Vector3(1.05,2.12,.5)],[Vector3(3.2,1.8,.3),Vector3(3.2,3.92,-2.65)]]
			d.start=Vector3(-3.2,.04,1.2)
			d.goal_cells=box(23,17,-23,28,18,-18)
		5: # S-ribbon: alternate left/right turns across a long crossbar.
			d.layout_name="Ribbon"
			d.low=[box(-22,-4,4,-10,0,18),box(-12,-4,4,5,0,14)]
			d.raised=[box(-5,-4,-18,18,9,-4),box(-24,-4,-30,-12,18,-8)]
			d.lifts=[] # Stage5 crosses the gaps on felled trees.
			d.tree_routes=[[Vector3(0,0,2.4),Vector3(0,1.8,-1.0)],[Vector3(.4,1.8,-2.6),Vector3(-2.6,3.6,-2.6)]]
			d.start=Vector3(-3.2,.04,2.4)
			d.goal_cells=box(-22,17,-17,-17,18,-12)
		6: # Fork: two balanced arms around a clear central ascent.
			d.layout_name="Fork"
			d.low=[box(-6,-4,12,6,0,24)]
			d.raised=[box(-8,-4,-4,8,9,4),box(-22,-4,-10,-6,9,4),box(6,-4,-10,22,9,4),box(-20,-4,-24,7,18,-12)]
			d.lifts=[] # Stage6 exits by the heavenly rope after feeding the tiger.
			d.guide_goal=Vector3(4.0,1.8,-1.35) # Reachable ledge beside the rope.
			d.bridge_routes=[[Vector3(0,0,3.0),Vector3(0,1.8,.6)]]
			d.start=Vector3(0,.04,3.4)
			d.goal_cells=box(-18,17,-21,-13,18,-16)
		7: # Open court: a large rectangular void framed on three sides.
			d.layout_name="Courtyard"
			d.low=[box(-18,-4,12,-6,0,24)]
			d.raised=[box(-18,-4,-12,-6,9,4),box(-6,-4,-12,14,9,-4),box(14,-4,-12,24,9,8),box(-6,-4,-34,18,18,-20)]
			d.lifts=[Vector3(-2.4,0,1.6),Vector3(2,1.8,-3.2)]
			d.start=Vector3(-2.4,.04,3.4)
			d.goal_cells=box(-4,17,-27,1,18,-22)
		8: # Fan: staggered wide bars, with detached rectangular outer petals.
			d.layout_name="Fan"
			d.low=[box(-5,-4,12,5,0,24),box(-17,-4,12,-5,0,20),box(5,-4,12,17,0,20)]
			d.raised=[box(-18,-4,-4,18,9,4),box(-28,-4,-14,-18,9,0),box(18,-4,-14,28,9,0),box(-11,-4,-28,25,18,-12)]
			# The second pillar is crossed out in the supplied layout: no mesh or collider.
			d.lifts=[Vector3(0,0,1.6)]
			d.auto_lifts=true
			d.bird_bridges=[[Vector3(0,1.8,-.4),Vector3(0,3.6,-2.6)]]
			d.start=Vector3(0,.04,3.6)
			d.goal_cells=box(18,17,-19,23,18,-14)
		9: # A single level cuboid, with a decoy exit on its breakaway left volume.
			d.layout_name="Cuboid"
			d.raised=[box(-24,-4,-36,24,9,24)]
			d.start=Vector3(0,1.84,3.4)
			d.goal_cells=box(15,8,-27,20,9,-22)
			d.fake_exit=Vector3(-3.4,1.8,-1.0)
			d.guide_goal=d.fake_exit
			d.guide_immediate=true
	for field:String in ["low","raised"]:
		for part:Array in d[field]:
			part[0]+=Vector3i(1,0,1)
			part[1]-=Vector3i(1,0,1)
	var lo:=Vector3(INF,INF,INF)
	var hi:=Vector3(-INF,-INF,-INF)
	for part:Array in d.low+d.raised:
		lo=lo.min(Vector3(part[0])*.2);hi=hi.max(Vector3(part[1])*.2)
	d.focus=(lo+hi)*.5
	# Extend foundations only after framing the playable rooftops.
	# The camera stays at PreMap3 scale while columns disappear below the frame.
	if number>=4 and number!=8:
		var foundation_y:int=-110 if number>=7 else -80
		for field:String in ["low","raised"]:
			for part:Array in d[field]:part[0].y=foundation_y
	d.separate_bounds=d.low+d.raised
	var goal:Array=d.goal_cells
	d.goal_height=goal[1].y*.2
	d.goal_rect=Rect2(goal[0].x*.2,goal[0].z*.2,(goal[1].x-goal[0].x)*.2,(goal[1].z-goal[0].z)*.2)
	d.catalog_center=Vector2.ZERO if number==9 else Vector2.from_angle(-PI*.5+(number-1)*TAU/8.0)*24.0
	return d
