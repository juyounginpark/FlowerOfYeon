extends "res://scripts/grid_stage/paper_cutting.gd"
## One landed fish, using the shared finite stroke, drag and sticker contracts.
var actor: Node3D
var manager: Node
var cut_piece: Dictionary
var item: Dictionary
var converted := false
var installed := false
var contact := Vector3.ZERO
var tail: Node3D
var tail_clock := 0.0
var launch_count := 0

func setup(owner: Node, fish: Node3D) -> void:
	# Intercept the jump action before the ordinary player physics callback.
	process_physics_priority = -5
	manager = owner
	actor = fish
	camera = manager.world.camera
	var proxy := Sprite3D.new()
	proxy.texture = actor.sprite_frames.get_frame_texture("1",0)
	proxy.pixel_size = actor.pixel_size
	proxy.set_meta("triangle_cut_collision",true)
	add_child(proxy)
	proxy.global_transform = Transform3D(camera.global_basis,actor.global_position+camera.global_basis.y*actor.offset.y*actor.pixel_size)
	var still := Sprite3D.new()
	still.texture = actor.STILL
	still.pixel_size = actor.width/1700.0
	still.set_meta("triangle_cut_collision",true)
	add_child(still)
	# Match the painted width and fixed sole anchor, not transparent canvas size.
	still.global_transform = Transform3D(camera.global_basis,actor.global_position+camera.global_basis.y*(750.0-443.5)*still.pixel_size)
	super.configure(camera,[proxy,still])
	cut_piece = pieces[0]
	item = pieces[1]
	for piece in pieces: piece.visual.hide()
	item.visual.name = "FishItem"
	item.visual.set_meta("screen_band",11)
	item.visual.material_override = manager.behind_player_material(item.source.texture)
	item.border.material_override = manager.behind_player_material(null,false,-1)
	item.shadow.hide()

func _pick(point: Vector2) -> Dictionary:
	if not converted or is_instance_valid(tail): return {}
	return super._pick(point)

func _cut(a: Vector2,b: Vector2) -> void:
	if converted: return
	pieces = [cut_piece]
	super._cut(a,b)
	if pieces.has(cut_piece):
		pieces = [cut_piece,item]
		return
	converted = true
	for piece in pieces:
		piece.body.queue_free()
		piece.visual.queue_free()
	pieces = [item]
	sources = [item.source]
	actor.queue_free()
	item.attached = false
	item.visual.show()
	_cancel_strokes(world.stage_root)

func _cancel_strokes(node: Node) -> void:
	if node is GridPaperCutting and node != self:
		node.drawing = false
		node.stroke.clear_points()
	for child in node.get_children(): _cancel_strokes(child)

func _preview_surface(piece: Dictionary) -> Dictionary:
	var surface := super._preview_surface(piece)
	if surface.is_empty(): return {}
	# Only upward walkable terrain, with room for the player's capsule.
	var ray := PhysicsRayQueryParameters3D.create(camera.project_ray_origin(get_viewport().get_mouse_position()),camera.project_ray_origin(get_viewport().get_mouse_position())+camera.project_ray_normal(get_viewport().get_mouse_position())*camera.far,5)
	ray.exclude = [world.player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y < cos(world.player.floor_max_angle): return {}
	if not manager.valid_landing(hit.position): return {}
	contact = hit.position
	# The sticker host remains the actual terrain. Fish art stays upright above it.
	var size_basis := camera.global_basis.scaled(Vector3.ONE*camera.size/1000.0)
	var bottom := -INF
	for vertex: Vector2 in item.polygon: bottom = maxf(bottom,vertex.y)
	surface.pose = Transform3D(size_basis,contact+Vector3.UP*.025+size_basis.y*bottom)
	return surface

func _begin_drag(piece: Dictionary) -> void:
	super._begin_drag(piece)
	installed = false

func _finish_drag(commit: bool) -> void:
	var held := is_instance_valid(grabbed)
	super._finish_drag(commit)
	if not held: return
	installed = bool(item.sticker)
	if installed:
		contact = item.host.global_transform * item.host_pose.origin
		var bottom := -INF
		for vertex: Vector2 in item.polygon: bottom = maxf(bottom,vertex.y)
		contact -= item.visual.global_basis.y*bottom
		contact -= Vector3.UP*.025
	else:
		var bounds := Rect2(item.polygon[0],Vector2.ZERO)
		for point: Vector2 in item.polygon: bounds = bounds.expand(point)
		var size := _screen(get_viewport().get_visible_rect().size)
		item.body.position.x = clampf(item.body.position.x,-bounds.position.x,size.x-bounds.end.x)
		item.body.position.y = clampf(item.body.position.y,-bounds.position.y,size.y-bounds.end.y)

func _unhandled_input(event: InputEvent) -> void:
	if locked or world.paused or world.transition.active or is_instance_valid(tail): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not converted: super._unhandled_input(event)
			else:
				var hit := _pick(_mouse())
				if not hit.is_empty():
					_begin_drag(hit)
					get_viewport().set_input_as_handled()
		else:
			var dragging := is_instance_valid(grabbed)
			var previous := converted
			super._unhandled_input(event)
			if dragging or previous != converted: get_viewport().set_input_as_handled()
	elif is_instance_valid(grabbed):
		if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT): super._unhandled_input(event)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	super._process(delta)
	if converted:
		if not is_instance_valid(grabbed): item.body.freeze = true
		item.visual.set_meta("slice_whole",true)
		item.visual.set_meta("wall_layer_attached",false)
	if not installed or world.paused or world.transition.active: return
	if is_instance_valid(item.host):
		var bottom := -INF
		for vertex: Vector2 in item.polygon: bottom = maxf(bottom,vertex.y)
		contact = item.visual.global_position-item.visual.global_basis.y*bottom-Vector3.UP*.025
	if is_instance_valid(tail):
		tail_clock += delta
		tail.advance(delta)
		if tail_clock >= 16.0/manager.fps:
			tail.queue_free()
			tail = null
			item.visual.show()

func _physics_process(_delta: float) -> void:
	if not installed or is_instance_valid(grabbed) or is_instance_valid(tail): return
	if world.paused or world.transition.active or world.player.input_locked or manager.busy(): return
	if not Input.is_action_just_pressed("jump"): return
	var distance: Vector3 = world.player.global_position-contact
	if Vector2(distance.x,distance.z).length()>=.46 or absf(distance.y)>=.2: return
	if not world.player.is_on_floor() or not manager.launch(contact): return
	launch_count += 1
	tail = manager.make_actor(contact)
	tail.switch(2)
	tail.material_override = manager.behind_player_material(tail.SHEETS[2],true,112)
	# Start at the striking pose: the button press launches immediately, without windup.
	tail_clock = manager.strike_frame / manager.fps
	tail.clock = tail_clock
	tail.frame = manager.strike_frame
	item.visual.hide()
