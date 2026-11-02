extends Node3D
const ACTOR = preload("res://scripts/stage3/fish_actor.gd")
const ITEM = preload("res://scripts/stage3/fish_item.gd")
var world: GridStageWorld
var sun: Node
var sea: Array[Node3D] = []
var items: Array[Node] = []
var spawn_clock := 0.0
var started := false
var rng := RandomNumberGenerator.new()
var max_sea := 3
var max_land := 4
var interval := 2.5
var land_chance := .25
var fps := 10.0
var fish_width := 1.2
var strike_frame := 8
var landing_points: Array[Vector3] = []
var jump_cells := 24
var flying := false
var flight_player: WorldPilgrim
var flight_time := 0.0
var flight_origin := Vector3.ZERO
var flight_target := Vector3.ZERO
var flight_horizontal := Vector3.ZERO
var previous_lock := false
var last_distance := 0.0
var last_landing := Vector3.ZERO
var flight_count := 0

func setup(owner: GridStageWorld,puzzle: Node) -> void:
	world = owner
	sun = puzzle
	rng.randomize()
	process_physics_priority = 5

func make_actor(point: Vector3) -> Node3D:
	var actor := ACTOR.new()
	actor.width = fish_width
	actor.fps = fps
	add_child(actor)
	actor.global_position = point
	return actor

func ground_at(point: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(point.x,12,point.z),Vector3(point.x,-2,point.z),5)
	ray.exclude = [world.player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(ray)

func valid_landing(point: Vector3) -> bool:
	# Require all four capsule-support samples to be on the same walkable top.
	for offset in [Vector3.ZERO,Vector3(.25,0,0),Vector3(-.25,0,0),Vector3(0,0,.25),Vector3(0,0,-.25)]:
		var hit := ground_at(point+offset)
		if hit.is_empty() or absf(hit.position.y-point.y)>.08 or hit.normal.y<cos(world.player.floor_max_angle): return false
	return true

func sea_point() -> Variant:
	for attempt in range(40):
		var point := Vector3(rng.randf_range(-5,5),-.05,rng.randf_range(-6,5))
		if Vector2(point.x-world.player.position.x,point.z-world.player.position.z).length()<1.4: continue
		var clear := true
		for offset in [Vector3.ZERO,Vector3(.8,0,0),Vector3(-.8,0,0),Vector3(0,0,.8),Vector3(0,0,-.8)]:
			if not ground_at(point+offset).is_empty(): clear = false
		for actor in sea:
			if actor.global_position.distance_to(point)<1.5: clear = false
		var screen := world.camera.unproject_position(point)/get_viewport().get_visible_rect().size
		var pixel := screen*get_viewport().get_visible_rect().size
		var ray := PhysicsRayQueryParameters3D.create(world.camera.project_ray_origin(pixel),world.camera.project_ray_origin(pixel)+world.camera.project_ray_normal(pixel)*world.camera.far,5)
		ray.exclude = [world.player.get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): clear = false
		if pixel.distance_to(world.camera.unproject_position(world.player.global_position))<70: clear = false
		if clear and Rect2(.08,.15,.84,.65).has_point(screen): return point
	return null

func spawn(force_land := false) -> Node3D:
	if not started or sea.size()>=max_sea: return null
	var point = sea_point()
	if point == null: return null
	var actor := make_actor(point)
	actor.origin = point
	var candidates: Array[Vector3] = []
	var reserved := 0
	for pending in sea:
		if pending.lands: reserved += 1
	if items.size()+reserved<max_land and (force_land or rng.randf()<land_chance):
		for target in landing_points:
			if not valid_landing(target) or target.distance_to(world.player.position)<.65: continue
			var occupied := false
			for existing in items:
				var anchor: Vector3 = existing.contact if existing.converted else existing.actor.global_position
				if target.distance_to(anchor)<fish_width: occupied = true
			for pending in sea:
				if pending.lands and pending.destination.distance_to(target)<fish_width: occupied = true
			if not occupied: candidates.append(target)
	if not candidates.is_empty():
		actor.lands = true
		actor.destination = candidates[rng.randi_range(0,candidates.size()-1)]
	sea.append(actor)
	return actor

func _process(delta: float) -> void:
	if world.paused or world.transition.active: return
	if not started:
		if sun.state != sun.State.CLEAR: return
		started = true
		spawn_clock = interval
	spawn_clock += delta
	if spawn_clock >= interval:
		spawn_clock = 0
		spawn()
	for actor in sea.duplicate():
		actor.advance(delta)
		if actor.lands:
			var progress: float = clampf(actor.clock/(8.0/fps),0,1)
			actor.frame = mini(int(actor.clock*fps),7)
			actor.offset.y = lerpf(270.0,207.0,progress)-156.5
			actor.global_position = actor.origin.lerp(actor.destination,progress)+Vector3.UP*sin(progress*PI)*1.2
			if progress >= 1:
				sea.erase(actor)
				actor.landed = true
				actor.switch(1)
				var item := ITEM.new()
				add_child(item)
				item.setup(self,actor)
				items.append(item)
		elif actor.clock >= 16.0/fps:
			sea.erase(actor)
			actor.queue_free()
	for item in items:
		if not item.converted and is_instance_valid(item.actor): item.actor.advance(delta)

func busy() -> bool:
	return flying

func launch(contact: Vector3) -> bool:
	if flying or world.player.input_locked or not world.player.is_on_floor(): return false
	var player: WorldPilgrim = world.player
	var direction: Vector3 = (world.stage_root.global_basis*player.heading)
	direction.y = 0
	if direction.length_squared()<.001: return false
	direction = direction.normalized()
	# StageCells is the terrain's source of truth. Never interpret three as metres.
	last_distance = jump_cells*StageCells.UNIT
	flight_origin = player.global_position
	flight_target = flight_origin+direction*last_distance
	var hit := ground_at(flight_target)
	var target_y := flight_origin.y
	if not hit.is_empty(): target_y = hit.position.y
	var apex := maxf(flight_origin.y,target_y)+maxf(1.4,player.jump_speed*player.jump_speed/(2*player.gravity))
	var up_speed := sqrt(2*player.gravity*(apex-flight_origin.y))
	var duration := up_speed/player.gravity+sqrt(2*(apex-target_y)/player.gravity)
	flight_horizontal = direction*last_distance/duration
	flight_player = player
	previous_lock = player.input_locked
	player.input_locked = true
	player.velocity = flight_horizontal+Vector3.UP*up_speed
	flying = true
	flight_time = 0
	flight_count += 1
	return true

func _physics_process(delta: float) -> void:
	if not flying: return
	if not is_instance_valid(flight_player):
		flying = false
		return
	if world.paused or world.transition.active: return
	var player := flight_player
	flight_time += delta
	player.velocity.x = flight_horizontal.x
	player.velocity.z = flight_horizontal.z
	player.velocity.y -= player.gravity*delta
	# Same CharacterBody3D collision mask, capsule, slopes and floor rules as walking.
	player.move_and_slide()
	player._update_walk_facing()
	player._play_directional_animation("jump")
	if player.is_on_wall(): flight_horizontal = Vector3.ZERO
	if flight_time>.1 and player.is_on_floor():
		last_landing = player.global_position
		player.land_time = .22
		player._play_directional_animation("land")
		end_flight()
	elif player.position.y < -1.25 or flight_time>5:
		end_flight()
		world._respawn()

func end_flight() -> void:
	if is_instance_valid(flight_player):
		flight_player.input_locked = previous_lock
		flight_player.velocity.x = 0
		flight_player.velocity.z = 0
	flying = false

func _exit_tree() -> void:
	end_flight()

func behind_player_material(texture: Texture2D, billboard := false, priority := 122) -> ShaderMaterial:
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://scripts/stage3/fish_behind_player.gdshader")
	ink.render_priority = priority
	ink.set_shader_parameter("textured",texture != null)
	ink.set_shader_parameter("fish_texture",texture)
	ink.set_shader_parameter("billboard",billboard)
	for child in world.stage_root.get_children():
		var mask = child.get("player_mask")
		if mask is SubViewport:
			ink.set_shader_parameter("player_silhouette",mask.get_texture())
			ink.set_shader_parameter("protect_player",true)
			break
	return ink
