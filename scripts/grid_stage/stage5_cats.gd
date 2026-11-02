extends Node
# Four independent pursuers share the same live fish target, never a teleport.
var world:GridStageWorld
var story:Node3D
var entries:Array[Dictionary]=[]
var target_piece:Dictionary={}
var active:=false
var arrived:=false
var phase:="waiting"

func configure(owner_world:GridStageWorld,owner_story:Node3D,actors:Array[Sprite3D]) -> void:
	world=owner_world;story=owner_story
	for actor:Sprite3D in actors:_register(actor,actor,null)

func _register(actor:Sprite3D,mover:Node3D,dialogue:Node3D) -> void:
	entries.append({"actor":actor,"mover":mover,"dialogue":dialogue,"home":mover.global_position,
		"jump_start":mover.global_position,"jump_time":-1.0,"arrived":false,"goal":mover.global_position})

func register_kitten(dialogue:Node3D) -> void:
	_register(dialogue.actor,dialogue,dialogue)

func _find_fish() -> Dictionary:
	if not target_piece.is_empty() and story.paper.pieces.has(target_piece) and target_piece.sticker:return target_piece
	var best:Dictionary={};var area:=0.0
	for piece:Dictionary in story.paper.pieces:
		if piece.source.sprite!=story.fish or piece.attached or not piece.sticker:continue
		var candidate:float=story.paper._area(piece.polygon)
		if candidate<maxf(3.0,story.paper._area(piece.source.polygon)*.06) or candidate<=area:continue
		if piece==story.paper.grabbed_piece:return piece
		area=candidate;best=piece
	return best

func _landing(piece:Dictionary) -> Vector3:
	var pixel:Vector2=world.camera.unproject_position(piece.visual.global_position)
	var origin:=world.camera.project_ray_origin(pixel)
	var direction:=world.camera.project_ray_normal(pixel)
	var ray:=PhysicsRayQueryParameters3D.create(origin,origin+direction*world.camera.far,5)
	ray.exclude=[world.player.get_rid()]
	var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
	var best:Vector3=story.chase_center;var distance:=INF
	for block:Array in world.stage_data.low+world.stage_data.raised:
		var lo:=Vector3(block[0])*.2;var hi:=Vector3(block[1])*.2
		var aim:Vector3=hit.position if not hit.is_empty() else piece.visual.global_position
		var point:=Vector3(clampf(aim.x,lo.x+.24,hi.x-.24),hi.y,clampf(aim.z,lo.z+.24,hi.z-.24))
		var screen_distance:float=world.camera.unproject_position(point).distance_squared_to(pixel)
		if screen_distance<distance:best=point;distance=screen_distance
	return best

func _process(delta:float) -> void:
	if world==null or world.paused or world.transition.active or world.player.input_locked:return
	if story.caught:
		phase="caught"
		for entry:Dictionary in entries:
			entry.actor.play_animation("idle")
			if entry.dialogue!=null:entry.dialogue.pursuing=false
		return
	var fish:=_find_fish()
	if fish.is_empty():
		active=false;arrived=false;story.cat_arrived=false;story.cat_time=-1.0
		for entry:Dictionary in entries:
			entry.actor.play_animation("idle")
			if entry.dialogue!=null:entry.dialogue.pursuing=false
		return
	var new_target:bool=not active
	active=true;target_piece=fish
	if new_target:
		phase="bait";BgmPlayer.play_cat()
	elif phase=="bait" and entries.all(func(entry):return entry.arrived):
		phase="chase";BgmPlayer.play_cat()
	var landing:Vector3=_landing(fish)
	arrived=false
	for index:int in range(entries.size()):
		var entry:Dictionary=entries[index]
		var mover:Node3D=entry.mover;var actor:Sprite3D=entry.actor
		var angle:float=TAU*index/entries.size()
		# Small offsets keep all four cats readable as they surround the bait.
		var goal:Vector3=landing+Vector3(cos(angle),0,sin(angle))*.38
		if phase=="chase":
			goal=story.rat_base+Vector3(cos(angle),0,sin(angle))*.24 if story.distracted else story._circle_point(story.chase_angle-story.chase_direction*(.30+index*.16))
		entry.goal=goal
		if new_target:
			entry.jump_start=mover.global_position;entry.jump_time=0.0;entry.arrived=false
			if entry.dialogue!=null:entry.dialogue.pursuing=true;entry.dialogue.cancel()
		var before:=mover.global_position
		if float(entry.jump_time)>=0:
			entry.jump_time+=delta
			var t:=clampf(float(entry.jump_time)/(1.05+index*.08),0,1)
			mover.global_position=Vector3(entry.jump_start).lerp(goal,t)+Vector3.UP*sin(t*PI)*1.5
			if t>=1:entry.jump_time=-1.0;entry.arrived=true
		elif absf(mover.global_position.y-goal.y)>.35:
			entry.jump_start=mover.global_position;entry.jump_time=0.0;entry.arrived=false
		else:
			mover.global_position=mover.global_position.move_toward(goal,delta*(3.2+index*.15))
		var moving:bool=mover.global_position.distance_squared_to(before)>.000001 or float(entry.jump_time)>=0
		actor.play_animation("chase" if moving or phase=="chase" else "idle")
		if moving:actor.flip_h=(mover.global_position-before).dot(world.camera.global_basis.x)>0
		if mover.global_position.distance_to(goal)<.3:entry.arrived=true;arrived=true
		if entry.dialogue!=null:entry.dialogue.pursuing=moving or phase=="chase"
	story.cat_time=0.0 if not arrived and phase=="bait" else -1.0
	story.cat_arrived=arrived or phase=="chase"

func distance_to(point:Vector3) -> float:
	var nearest:=INF
	for entry:Dictionary in entries:nearest=minf(nearest,entry.mover.global_position.distance_to(point))
	return nearest
