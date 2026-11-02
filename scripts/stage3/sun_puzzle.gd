extends "res://scripts/grid_stage/paper_cutting.gd"
## Stage3 adapter. Shared cutter validates strokes and owns drag/sticker physics.
const COMPOSITE = preload("res://art/stage3/0.png")
const MOUNTAIN = preload("res://art/stage3/8.png")
const SUN = preload("res://art/stage3/3.png")
const CLOUD = preload("res://art/stage3/2.png")
enum State { UNCUT, SUN_READY, CLEARING, CLEAR }
var state := State.UNCUT
var original: Sprite3D
var mountain: Sprite3D
var original_piece: Dictionary
var sun_piece: Dictionary
var sky_host: Node3D
var sky_region: Rect2
var clouds: Array[Dictionary] = []
var cloud_seconds := 1.8
var cloud_travel := 0.65
var elapsed := 0.0
var screen_world_width := 1.0
var cleared_count := 0

func photo(node_name: String, texture: Texture2D, unit: float, point: Vector3, priority: int) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.pixel_size = unit
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.render_priority = priority
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.set_meta("screen_band", 11)
	sprite.set_meta("triangle_cut_collision", true)
	add_child(sprite)
	sprite.global_transform = Transform3D(camera.global_basis, point)
	return sprite

func setup(owner_world: GridStageWorld, center: Vector2, width: float,
	layout: Array[Vector3], region: Rect2, seconds: float, travel: float) -> void:
	camera = owner_world.camera
	world = owner_world
	sky_region = region
	cloud_seconds = seconds
	cloud_travel = travel
	var viewport := get_viewport().get_visible_rect().size
	var depth: float = camera.global_position.distance_to(world.stage_data.focus)
	screen_world_width = camera.project_position(Vector2.ZERO, depth).distance_to(camera.project_position(Vector2(viewport.x,0), depth))
	original = photo("MountainAndSun", COMPOSITE, screen_world_width * width / COMPOSITE.get_width(), camera.project_position(center * viewport,depth),115)
	# Both mountain files use the same 1774x887 canvas and ridge anchors.
	mountain = photo("FixedMountain", MOUNTAIN, original.pixel_size, original.global_position,115)
	mountain.hide()
	for i in layout.size():
		var entry := layout[i]
		var image := CLOUD.get_image()
		if image.is_compressed(): image.decompress()
		var painted := image.get_used_rect()
		var cloud := photo("Cloud%d" % i, CLOUD, screen_world_width * entry.z / painted.size.x,
			camera.project_position(Vector2(entry.x,entry.y) * viewport,depth),110)
		var correction := Vector2(CLOUD.get_size()) * .5 - Vector2(painted.get_center())
		cloud.offset = Vector2(correction.x,-correction.y)
		clouds.append({"node":cloud,"start":cloud.global_position,"direction":-1.0 if entry.x < .5 else 1.0})
	sky_host = Node3D.new()
	sky_host.name = "SkyAttachmentPlane"
	add_child(sky_host)
	var proxy := photo("CompositeCutSource", COMPOSITE, original.pixel_size, original.global_position,115)
	# Painted sun in 0.png: center (919,478), diameter 278px.
	# 3.png painted diameter ~994px; transparent canvas must not set its size.
	var sun_position := original.global_position + camera.global_basis * Vector3(919.0-887.0,443.5-478.0,0) * original.pixel_size
	var source := photo("SunSource", SUN, original.pixel_size * 278.0 / 994.0, sun_position,120)
	super.configure(camera,[proxy,source])
	original_piece = pieces[0]
	sun_piece = pieces[1]
	for piece in pieces: piece.visual.hide()
	sun_piece.visual.name = "DraggableSun"
	sun_piece.visual.set_meta("screen_band",11)
	sun_piece.visual.material_override.no_depth_test = true
	sun_piece.visual.material_override.render_priority = 127
	# The painting is flat; don't add an unrelated dark halo around the sun.
	sun_piece.shadow.hide()

func _pick(point: Vector2) -> Dictionary:
	if state != State.SUN_READY: return {}
	return super._pick(point)

func _cut(start: Vector2, end: Vector2) -> void:
	if state != State.UNCUT: return
	pieces = [original_piece]
	super._cut(start,end)
	if pieces.has(original_piece):
		pieces = [original_piece,sun_piece]
		return
	state = State.SUN_READY
	for fragment in pieces:
		fragment.body.queue_free()
		fragment.visual.queue_free()
	pieces = [sun_piece]
	sources = [sun_piece.source]
	original.hide()
	original.queue_free()
	mountain.show()
	sun_piece.attached = false
	# Keep the freshly separated sun where it appeared until picked up.
	sun_piece.body.freeze = true
	sun_piece.visual.show()
	_cancel_other_strokes(world.stage_root)

func _cancel_other_strokes(node: Node) -> void:
	if node is GridPaperCutting and node != self:
		node.drawing = false
		node.stroke.clear_points()
	for child in node.get_children(): _cancel_other_strokes(child)

func _unhandled_input(event: InputEvent) -> void:
	if locked or world.paused or world.transition.active: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if state == State.UNCUT:
				super._unhandled_input(event)
			elif state == State.SUN_READY:
				var hit := _pick(_mouse())
				if not hit.is_empty():
					_begin_drag(hit)
					sun_piece.visual.material_override.render_priority = 127
					get_viewport().set_input_as_handled()
		else:
			var dragging := is_instance_valid(grabbed)
			var previous := state
			super._unhandled_input(event)
			if dragging or previous != state: get_viewport().set_input_as_handled()
	elif is_instance_valid(grabbed):
		# Keep a sun painting flat; reuse shared mouse drag, not perpendicular props.
		if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT):
			super._unhandled_input(event)
		get_viewport().set_input_as_handled()

func _preview_surface(piece: Dictionary) -> Dictionary:
	if state != State.SUN_READY or piece != sun_piece: return {}
	var viewport := get_viewport().get_visible_rect().size
	var pixel := get_viewport().get_mouse_position()
	if not sky_region.has_point(pixel / viewport): return {}
	# Sky is a broad virtual world plane, independent of clouds or terrain rays.
	# Return the same host/pose contract consumed by the shared sticker code.
	var pose_basis := camera.global_basis.scaled(Vector3.ONE * camera.size / 1000.0)
	var point := camera.project_position(pixel,2.0)
	return {"host":sky_host,"pose":Transform3D(pose_basis,point-pose_basis*Vector3(grab_local.x,-grab_local.y,0))}

func _finish_drag(commit: bool) -> void:
	var had_sun := grabbed_piece == sun_piece and is_instance_valid(grabbed)
	super._finish_drag(commit)
	if not had_sun: return
	if commit and state == State.SUN_READY and sun_piece.sticker and sun_piece.host == sky_host:
		state = State.CLEARING
		cleared_count += 1
		# Keep the final whole-band overlay, including after shared sticker updates.
		sun_piece.visual.set_meta("wall_layer_attached",false)
	else:
		# Invalid release remains available, without falling behind the lower painting.
		var bounds := Rect2(sun_piece.polygon[0],Vector2.ZERO)
		for vertex: Vector2 in sun_piece.polygon: bounds = bounds.expand(vertex)
		var viewport := _screen(get_viewport().get_visible_rect().size)
		sun_piece.body.position.x = clampf(sun_piece.body.position.x,-bounds.position.x,viewport.x-bounds.end.x)
		sun_piece.body.position.y = clampf(sun_piece.body.position.y,-bounds.position.y,viewport.y-bounds.end.y)
		sun_piece.body.freeze = true

func _process(delta: float) -> void:
	super._process(delta)
	if state == State.SUN_READY and not is_instance_valid(grabbed):
		sun_piece.body.freeze = true
	if state != State.UNCUT:
		sun_piece.visual.set_meta("slice_whole",true)
		sun_piece.visual.set_meta("wall_layer_attached",false)
	if state != State.CLEARING or world.paused or world.transition.active: return
	elapsed = minf(elapsed+delta,cloud_seconds)
	var progress := smoothstep(0.0,1.0,elapsed/cloud_seconds)
	for entry in clouds:
		entry.node.global_position = entry.start + camera.global_basis.x * entry.direction * screen_world_width * cloud_travel * progress
		entry.node.modulate.a = 1.0-progress
	if elapsed >= cloud_seconds:
		for entry in clouds: entry.node.queue_free()
		clouds.clear()
		state = State.CLEAR
