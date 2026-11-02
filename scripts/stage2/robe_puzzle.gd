extends "res://scripts/grid_stage/paper_cutting.gd"
## The rock/robe is real cut paper. Fragments persist until an explicit restart.
const ART = preload("res://scripts/stage2/art.gd")
const COMPOSITOR = preload("res://scripts/grid_stage/screen_slices.gd")
const FRONT_LAYERS := (1 << (COMPOSITOR.ART_BIT_START + COMPOSITOR.BAND_COUNT - 1)) | COMPOSITOR.PLAYER_MASK_LAYER
enum State { UNCUT, SETTLING, ROBE_READY, ESCAPING, OPEN, ASCENDING, APPROACHING, PUSHING, RESTARTING }
var state := State.UNCUT
var swim_sound: AudioStreamPlayer
var original: Sprite3D
var actor: AnimatedSprite3D
var blocker: StaticBody3D
var fairy: Sprite3D
var fairy_image: Image
var bare_rock: Sprite3D
var rock_change := 0.0
const ROCK_CHANGE_SECONDS := .65
const SWIM_SECONDS := 2.0
const SWIM_DELAY := .55
var robe_piece: Dictionary = {}
var parked_robe: Dictionary = {}
var original_piece: Dictionary = {}
var cut_source: Dictionary
var robe_source: Dictionary
var initial_cut_pose := Transform2D.IDENTITY
var initial_robe_pose := Transform2D.IDENTITY
var actor_origin := Vector3.ZERO
var fairy_origin := Transform3D.IDENTITY
var fairy_unit := 0.0
var fairy_offset := Vector2.ZERO
var settle_time := 0.0
var reveal_time := 0.0
var scene_time := 0.0
var escape_start := Vector3.ZERO
var escape_end := Vector3.ZERO
var swim_end := Vector3.ZERO
var escape_seconds := 3.0
var push_velocity := Vector3.ZERO
var push_hit := false
var impact: Sprite3D
var swim_frames: Array = []
var ascent_frames: Array = []
var fragment_fade := -1.0
var swim_route := PackedVector3Array()
var swim_cursor := 0
var swim_speed := 0.0
var look_frames: Array = []
var fairy_ramp: StaticBody3D
var look_time := 0.0
var head_anchor := Vector3(0,.9,0)

func setup(owner_world: GridStageWorld, rock: Sprite3D,
		woodcutter: AnimatedSprite3D, passage: StaticBody3D) -> void:
	swim_sound = AudioStreamPlayer.new()
	var splash: AudioStreamMP3 = load("res://music/water-splash-3.mp3").duplicate()
	splash.loop = true
	swim_sound.stream = splash
	swim_sound.volume_db = BgmPlayer.BASE_VOLUME_DB
	add_child(swim_sound)
	original = rock
	actor = woodcutter
	blocker = passage
	fairy = rock.get_parent().get_node("BathingFairy")
	fairy_image = ART.frames("fairy_back_v2")[0].image
	actor.prepare_actions()
	ascent_frames = ART.frames("fairy_ascend")
	look_frames = ART.frames("fairy_look_v2")
	swim_frames = ART.frames("fairy_swim_v2")
	actor_origin = actor.global_position
	fairy_origin = fairy.global_transform
	fairy_unit = fairy.pixel_size
	fairy_offset = fairy.offset
	var point := rock.global_position + rock.global_basis * Vector3(rock.offset.x, rock.offset.y, 0) * rock.pixel_size
	var cut_proxy := _proxy("CutSource", rock.texture, rock.pixel_size, point, owner_world.camera)
	cut_proxy.set_meta("edge_foam", true)
	var robe_texture: Texture2D = ART.texture("robe_v2")
	var robe_width: float = rock.texture.get_width() * rock.pixel_size * .42
	var item_proxy := _proxy("RobeSource", robe_texture, robe_width / robe_texture.get_width(), point, owner_world.camera)
	item_proxy.set_meta("paper_cuttable", false)
	# The latest Stage2 direction explicitly gives the detached robe top priority.
	item_proxy.set_meta("paper_foreground", true)
	var front_ink := StandardMaterial3D.new()
	front_ink.render_priority = 127
	item_proxy.material_override = front_ink
	super.configure(owner_world.camera, [cut_proxy, item_proxy])
	cut_source = sources[0]
	robe_source = sources[1]
	robe_source.depth = float(cut_source.depth) - .08
	initial_cut_pose = pieces[0].body.transform
	initial_robe_pose = pieces[1].body.transform
	# A small local water support in front of the original rock silhouette.
	cut_source.baseline += 28.0
	cut_source.floor.position.y = cut_source.baseline + 12.0
	robe_source.baseline = cut_source.baseline + 12.0
	robe_source.floor.position.y = robe_source.baseline + 12.0
	original.hide()
	bare_rock = Sprite3D.new()
	bare_rock.name = "Stage2BareRock"
	bare_rock.texture = ART.texture("bare_rock_v2")
	# The edited bare-rock image preserves the robe-rock canvas and stone base.
	var canvas_ratio: float = float(original.texture.get_width()) / bare_rock.texture.get_width()
	bare_rock.pixel_size = original.pixel_size * canvas_ratio
	bare_rock.offset = original.offset / canvas_ratio
	bare_rock.shaded = false
	bare_rock.no_depth_test = false
	bare_rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bare_rock.set_meta("shore_painted", ART.frames("bare_rock_v2")[0].painted)
	bare_rock.add_to_group("shore_illustration")
	ART.sliced_sprite(bare_rock, bare_rock.texture)
	original.get_parent().add_child(bare_rock)
	bare_rock.global_transform = original.global_transform
	bare_rock.hide()
	original_piece = pieces[0]
	parked_robe = pieces[1]
	pieces.erase(parked_robe)
	parked_robe.visual.hide()
	impact = Sprite3D.new()
	impact.name = "Stage2PushImpact"
	impact.texture = ART.texture("push_impact")
	impact.pixel_size = 1.1 / impact.texture.get_width()
	impact.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	impact.shaded = false
	impact.no_depth_test = false
	ART.sliced_sprite(impact, impact.texture, false)
	add_child(impact)
	impact.hide()

func _proxy(node_name: String, texture: Texture2D, unit: float, point: Vector3, view: Camera3D) -> Sprite3D:
	var proxy := Sprite3D.new()
	proxy.name = node_name
	proxy.texture = texture
	proxy.pixel_size = unit
	proxy.set_meta("triangle_cut_collision", true)
	proxy.set_meta("map_occluded", true)
	proxy.set_meta("background_depth", (point - view.global_position).dot(-view.global_basis.z))
	add_child(proxy)
	proxy.global_position = point
	proxy.global_basis = original.global_basis
	return proxy

func _pick(point: Vector2) -> Dictionary:
	if state != State.ROBE_READY: return {}
	var all_pieces := pieces
	pieces = [robe_piece]
	var hit := super._pick(point)
	pieces = all_pieces
	return hit

func _cut(start: Vector2, end: Vector2) -> void:
	if state not in [State.UNCUT, State.SETTLING, State.ROBE_READY]: return
	var previous: Array = pieces.duplicate()
	# After the first cut the fixed remainder is only the outgoing crossfade.
	# Keep recutting physical detached fragments, not that fading remainder.
	var fixed: Array[Dictionary] = []
	if state != State.UNCUT:
		for piece: Dictionary in pieces.duplicate():
			if piece.attached:
				fixed.append(piece)
				pieces.erase(piece)
	super._cut(start, end)
	pieces.append_array(fixed)
	var changed := false
	for piece: Dictionary in previous:
		if not pieces.has(piece): changed = true
	if not changed: return
	if state == State.UNCUT:
		state = State.SETTLING
		rock_change = 0.0
		bare_rock.modulate.a = 0.0
		bare_rock.show()
		cut_source.sprite.set_meta("edge_foam", false)
	settle_time = 0.0
	_cancel_background_strokes(world.stage_root)

func _cancel_background_strokes(node: Node) -> void:
	if node is GridPaperCutting and node != self:
		node.drawing = false
		node.stroke.clear_points()
	for child in node.get_children(): _cancel_background_strokes(child)

func _unhandled_input(event: InputEvent) -> void:
	if locked or state not in [State.UNCUT, State.SETTLING, State.ROBE_READY]: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var item := _pick(_mouse())
			if not item.is_empty():
				_begin_drag(item)
				get_viewport().set_input_as_handled()
			else: super._unhandled_input(event)
		else:
			var held := is_instance_valid(grabbed)
			var before := state
			super._unhandled_input(event)
			if held or before != state: get_viewport().set_input_as_handled()
	elif is_instance_valid(grabbed):
		super._unhandled_input(event)
		get_viewport().set_input_as_handled()

func _largest_fallen() -> Dictionary:
	var largest: Dictionary = {}
	var area := 0.0
	for piece: Dictionary in pieces:
		if piece.source != cut_source or piece.attached: continue
		var size := _area(piece.polygon)
		if size > area:
			largest = piece
			area = size
	return largest

func _spawn_robe(fragment: Dictionary) -> void:
	robe_piece = parked_robe
	parked_robe = {}
	var center := Vector2.ZERO
	var twice_area := 0.0
	var polygon: PackedVector2Array = fragment.polygon
	for index: int in range(polygon.size()):
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % polygon.size()]
		var weight := a.cross(b)
		center += (a + b) * weight
		twice_area += weight
	center = fragment.body.transform * (center / (3.0 * twice_area))
	var bottom := -INF
	for point: Vector2 in robe_piece.polygon: bottom = maxf(bottom, point.y)
	# Spawn close to the largest settled fragment, above its own physical floor.
	center.y = minf(center.y, float(robe_source.baseline) - bottom - 18.0)
	robe_piece.body.transform = Transform2D(0, center)
	robe_piece.attached = false
	robe_piece.sticker = false
	robe_piece.body.freeze = false
	robe_piece.body.collision_layer = int(robe_source.layer)
	robe_piece.body.collision_mask = int(robe_source.layer)
	robe_piece.body.linear_velocity = Vector2.ZERO
	robe_piece["stage2_item"] = "fairy_robe"
	robe_piece.visual.name = "Stage2RobeItem"
	pieces.append(robe_piece)
	reveal_time = 0.0
	fragment_fade = 0.0
	state = State.ROBE_READY

func _preview_surface(piece: Dictionary) -> Dictionary:
	var surface := super._preview_surface(piece)
	if state == State.ROBE_READY and piece.get("stage2_item", "") == "fairy_robe":
		var fairy_surface := _fairy_surface()
		if not fairy_surface.is_empty(): return fairy_surface
	if state != State.ROBE_READY or piece.get("stage2_item", "") != "fairy_robe" or not is_instance_valid(actor):
		return surface
	# Reuse the surface-sticker contract (pose + host). The tall painted actor
	# extends above its gameplay collider, so resolve its billboard plane and
	# alpha here rather than accepting invisible margins of the wide blocker.
	var origin := camera.project_ray_origin(get_viewport().get_mouse_position())
	var direction := camera.project_ray_normal(get_viewport().get_mouse_position())
	var basis_: Basis = camera.global_basis
	var center := actor.global_position + (basis_.x * actor.offset.x + basis_.y * actor.offset.y) * actor.pixel_size
	var denominator: float = direction.dot(basis_.z)
	if absf(denominator) < 0.00001:
		return surface
	var distance: float = (center - origin).dot(basis_.z) / denominator
	if distance <= 0:
		return surface
	var contact: Vector3 = origin + direction * distance
	var local: Vector3 = basis_.inverse() * (contact - center) / actor.pixel_size
	var entry: Dictionary = actor.current_art()
	var image: Image = entry.image
	var pixel: Vector2 = Vector2(local.x, -local.y) + Vector2(image.get_size()) * .5
	if not Rect2(Vector2.ZERO, image.get_size()).has_point(pixel): return surface
	if actor.flip_h: pixel.x = image.get_width() - 1 - pixel.x
	if image.get_pixelv(Vector2i(pixel)).a <= 0.5:
		return surface
	var size_basis: Basis = basis_.scaled(Vector3.ONE * camera.size / 1000.0)
	return {"host": actor, "pose": Transform3D(size_basis,
		contact + basis_.z * SURFACE_OFFSET - size_basis * Vector3(grab_local.x, -grab_local.y, 0))}

func _finish_drag(commit: bool) -> void:
	var held := grabbed_piece
	super._finish_drag(commit)
	if not commit or state != State.ROBE_READY or held != robe_piece: return
	if not held.get("sticker", false): return
	if held.get("host") == fairy: _punish()
	elif held.get("host") == actor: _deliver()

func _consume_robe() -> void:
	# Delivery is an explicit quest consumption, never a substitute for cut physics.
	pieces.erase(robe_piece)
	parked_robe = robe_piece
	parked_robe.body.freeze = true
	parked_robe.visual.hide()
	robe_piece = {}
	if is_instance_valid(world.stage2_dialogue): world.stage2_dialogue.cancel()
	world.dialogue = null
	_cancel_background_strokes(world.stage_root)

func _deliver() -> void:
	if state != State.ROBE_READY or robe_piece.is_empty(): return
	_consume_robe()
	state = State.ESCAPING
	scene_time = 0.0
	escape_start = actor.global_position
	escape_end = world.stage_root.to_global(world.start_position)
	escape_end.y = escape_start.y
	escape_seconds = maxf(2.5, escape_start.distance_to(escape_end) / 1.8)
	head_anchor = world.stage_root.to_global(Vector3(0,.9,0))
	var entry: Dictionary = look_frames[0]
	var unit: float = fairy_unit * .7 * ART.texture("fairy_back_v2").get_width() / entry.texture.get_width()
	swim_end = head_anchor - camera.global_basis.y * (entry.texture.get_height() * .5 - entry.painted.position.y) * unit
	swim_route = preload("res://scripts/stage2/water_route.gd").build(world, fairy.global_position, swim_end)
	swim_cursor = 0
	var route_length := 0.0
	var previous := fairy.global_position
	for point: Vector3 in swim_route:
		route_length += previous.distance_to(point)
		previous = point
	swim_speed = route_length / SWIM_SECONDS
	blocker.collision_layer = 0
	blocker.collision_mask = 0

func _punish() -> void:
	if state != State.ROBE_READY or robe_piece.is_empty(): return
	_consume_robe()
	state = State.ASCENDING
	scene_time = 0.0
	world.player.input_locked = true
	world.player.velocity = Vector3.ZERO
	blocker.collision_layer = 0
	blocker.collision_mask = 0

func _process(delta: float) -> void:
	super._process(delta)
	# Explicit Stage2 request: loose quest paper stays above map and water,
	# including drag previews and stickers. Physics remains the shared simulation.
	for piece: Dictionary in pieces:
		if piece.source == cut_source and piece.attached:
			var opacity := 1.0 - smoothstep(0.0, ROCK_CHANGE_SECONDS, rock_change)
			piece.paper_material.albedo_color.a = opacity
			piece.visual.visible = opacity > .001
			piece.border.visible = state == State.UNCUT
			piece.shadow.visible = state == State.UNCUT
		else:
			_keep_paper_in_front(piece)
	var swimming := state == State.ESCAPING and scene_time >= SWIM_DELAY and swim_cursor < swim_route.size()
	swim_sound.stream_paused = world.paused or world.transition.active
	if not swimming: swim_sound.stop()
	if world.paused or world.transition.active: return
	if state != State.UNCUT:
		rock_change = minf(rock_change + delta, ROCK_CHANGE_SECONDS)
		bare_rock.modulate.a = smoothstep(0.0, ROCK_CHANGE_SECONDS, rock_change)
	if fragment_fade >= 0.0:
		fragment_fade += delta
		for piece: Dictionary in pieces.duplicate():
			if piece.source != cut_source or piece.attached: continue
			var opacity := 1.0 - smoothstep(.45, 1.35, fragment_fade)
			piece.paper_material.albedo_color.a = opacity
			piece.front_border_material.albedo_color.a = opacity
			piece.front_shadow_material.albedo_color.a = opacity
			if fragment_fade >= 1.35:
				piece.body.queue_free()
				piece.visual.queue_free()
				pieces.erase(piece)
	if state == State.ASCENDING:
		scene_time += delta
		var t := clampf(scene_time / 2.1, 0.0, 1.0)
		var entry: Dictionary = ascent_frames[mini(2, int(t * 3.0))]
		fairy.texture = entry.texture
		fairy.offset = Vector2.ZERO
		fairy.pixel_size = fairy_unit * ART.texture("fairy_back_v2").get_width() / entry.texture.get_width()
		ART.sliced_sprite(fairy, fairy.texture)
		fairy.global_position = fairy_origin.origin + Vector3.UP * (t * t * 6.0)
		fairy.modulate.a = 1.0 - smoothstep(.8, 1.0, t)
		if t >= 1.0:
			fairy.hide()
			state = State.APPROACHING
			scene_time = 0.0
	if state == State.SETTLING:
		var largest := _largest_fallen()
		if not largest.is_empty():
			var body: RigidBody2D = largest.body
			if not body.get_colliding_bodies().is_empty() and body.linear_velocity.length() < 12.0:
				settle_time += delta
			else: settle_time = 0.0
			if settle_time >= .35: _spawn_robe(largest)
	if state == State.ROBE_READY:
		reveal_time = minf(reveal_time + delta, .45)
		robe_piece.paper_material.albedo_color.a = smoothstep(0.0, .45, reveal_time)
	if state == State.ESCAPING:
		scene_time += delta
		var t := clampf(scene_time / escape_seconds, 0.0, 1.0)
		actor.global_position = escape_start.lerp(escape_end, t)
		var left := camera.unproject_position(escape_end).x < camera.unproject_position(escape_start).x
		actor.action("woodcutter_run", int(scene_time * 8.0) % 4, left)
		actor.modulate.a = 1.0 - smoothstep(.85, 1.0, t)
		if scene_time >= SWIM_DELAY:
			if not swim_sound.playing: swim_sound.play()
			var entry: Dictionary = swim_frames[int((scene_time - SWIM_DELAY) * 6.0) % 4]
			fairy.texture = entry.texture
			ART.sliced_sprite(fairy, fairy.texture)
			fairy.pixel_size = fairy_unit * ART.texture("fairy_back_v2").get_width() / entry.texture.get_width()
			fairy.offset = Vector2.ZERO
			fairy.set_meta("shore_painted", entry.painted)
			fairy.flip_h = camera.unproject_position(swim_end).x > camera.unproject_position(fairy_origin.origin).x
			# Spend the full frame's travel across corners, so route length and
			# waypoint count never extend the two-second swimming duration.
			var swim_delta := minf(delta, scene_time - SWIM_DELAY)
			var travel := swim_speed * swim_delta
			while swim_cursor < swim_route.size():
				var distance := fairy.global_position.distance_to(swim_route[swim_cursor])
				if distance > travel:
					fairy.global_position = fairy.global_position.move_toward(swim_route[swim_cursor], travel)
					break
				fairy.global_position = swim_route[swim_cursor]
				travel = maxf(0.0, travel - distance)
				swim_cursor += 1
			fairy.modulate.a = 1.0
		if scene_time >= SWIM_DELAY and swim_cursor >= swim_route.size():
			actor.hide()
			fairy.modulate = Color.WHITE
			look_time = 0.0
			_build_fairy_ramp()
			swim_sound.stop()
			state = State.OPEN
	if state == State.OPEN:
		look_time += delta
		var entry: Dictionary = look_frames[int(look_time * 3.0) % 5]
		fairy.texture = entry.texture
		fairy.pixel_size = fairy_unit * .7 * ART.texture("fairy_back_v2").get_width() / entry.texture.get_width()
		fairy.flip_h = false
		var size: Vector2 = entry.texture.get_size()
		var painted: Rect2 = entry.painted
		fairy.offset = Vector2(size.x * .5 - painted.get_center().x, painted.position.y - size.y * .5)
		fairy.global_position = head_anchor
		fairy.set_meta("shore_painted", painted)
		ART.sliced_sprite(fairy, fairy.texture)
	if state == State.APPROACHING:
		scene_time += delta
		var target: Vector3 = world.player.global_position
		var towards: Vector3 = target - actor.global_position
		towards.y = 0.0
		var left := camera.unproject_position(target).x < camera.unproject_position(actor.global_position).x
		actor.action("woodcutter_push", 0, left)
		if towards.length() > .67:
			actor.global_position += towards.normalized() * minf(delta * 4.0, towards.length() - .66)
		else:
			state = State.PUSHING
			scene_time = 0.0
			push_hit = false
	if state == State.PUSHING:
		scene_time += delta
		var left := camera.unproject_position(world.player.global_position).x < camera.unproject_position(actor.global_position).x
		actor.action("woodcutter_push", mini(2, int(scene_time / .18)), left)
		if scene_time >= .18 and not push_hit:
			push_hit = true
			BgmPlayer.play_punch()
			var direction: Vector3 = world.player.global_position - actor.global_position
			direction.y = 0.0
			if direction.length_squared() < .01: direction = camera.global_basis.x
			push_velocity = direction.normalized() * 4.0 + Vector3.UP * 2.0
			impact.global_position = world.player.global_position + Vector3.UP * .8
			impact.flip_h = left
			impact.show()
		impact.modulate.a = 1.0 - smoothstep(.28, .65, scene_time)
		if scene_time >= 1.1:
			state = State.RESTARTING
			world.restart.call_deferred()

func _physics_process(delta: float) -> void:
	if state != State.PUSHING or not push_hit or world.paused: return
	# The player is input-locked; use its real capsule for the knockback.
	push_velocity.y -= world.player.gravity * delta
	var collision: KinematicCollision3D = world.player.move_and_collide(push_velocity * delta)
	if collision != null: push_velocity = push_velocity.slide(collision.get_normal())

func reset_puzzle() -> void:
	swim_sound.stop()
	if is_instance_valid(fairy_ramp):
		fairy_ramp.collision_layer = 0
		fairy_ramp.queue_free()
	fairy_ramp = null
	if is_instance_valid(grabbed): _finish_drag(false)
	drawing = false
	stroke.clear_points()
	for piece: Dictionary in pieces:
		piece.body.queue_free()
		piece.visual.queue_free()
	if not parked_robe.is_empty():
		parked_robe.body.queue_free()
		parked_robe.visual.queue_free()
	pieces.clear()
	_add_piece(cut_source, cut_source.polygon, initial_cut_pose, true)
	original_piece = pieces[0]
	_add_piece(robe_source, robe_source.polygon, initial_robe_pose, true)
	parked_robe = pieces[1]
	pieces.erase(parked_robe)
	parked_robe.visual.hide()
	robe_piece = {}
	state = State.UNCUT
	fragment_fade = -1.0
	rock_change = 0.0
	bare_rock.hide()
	cut_source.sprite.set_meta("edge_foam", true)
	settle_time = 0.0
	scene_time = 0.0
	push_hit = false
	impact.hide()
	actor.global_position = actor_origin
	actor.reset_actor()
	fairy.texture = ART.texture("fairy_back_v2")
	ART.sliced_sprite(fairy, fairy.texture)
	fairy.global_transform = fairy_origin
	fairy.pixel_size = fairy_unit
	fairy.offset = fairy_offset
	fairy.flip_h = false
	fairy.modulate = Color.WHITE
	fairy.set_meta("shore_painted", ART.frames("fairy_back_v2")[0].painted)
	fairy.show()
	blocker.collision_layer = 1
	blocker.collision_mask = 2
	world.dialogue = world.stage2_dialogue

func _fairy_surface() -> Dictionary:
	if not is_instance_valid(fairy) or not fairy.visible: return {}
	var origin := camera.project_ray_origin(get_viewport().get_mouse_position())
	var direction := camera.project_ray_normal(get_viewport().get_mouse_position())
	var basis_: Basis = fairy.global_basis
	var center := fairy.global_position + basis_ * Vector3(fairy.offset.x,fairy.offset.y,0) * fairy.pixel_size
	var denominator := direction.dot(basis_.z)
	if absf(denominator) < .00001: return {}
	var distance := (center-origin).dot(basis_.z)/denominator
	if distance <= 0: return {}
	var contact := origin + direction * distance
	var local := basis_.inverse() * (contact-center) / fairy.pixel_size
	var pixel := Vector2(local.x,-local.y) + fairy.texture.get_size()*.5
	if not Rect2(Vector2.ZERO,fairy.texture.get_size()).has_point(pixel): return {}
	if fairy_image.get_pixelv(Vector2i(pixel)).a <= .5: return {}
	var size_basis := camera.global_basis.scaled(Vector3.ONE * camera.size / 1000.0)
	return {"host":fairy, "pose":Transform3D(size_basis,contact + basis_.z*SURFACE_OFFSET - size_basis*Vector3(grab_local.x,-grab_local.y,0))}

func _add_piece(source: Dictionary, polygon: PackedVector2Array, pose: Transform2D, attached: bool) -> void:
	var previous_count := pieces.size()
	super._add_piece(source, polygon, pose, attached)
	if pieces.size() == previous_count: return
	var piece: Dictionary = pieces.back()
	# Retain materials because the screen compositor replaces render overrides.
	piece["front_border_material"] = piece.border.material_override
	piece["front_shadow_material"] = piece.shadow.material_override
	if not attached: _keep_paper_in_front(piece)

func _keep_paper_in_front(piece: Dictionary) -> void:
	var material: StandardMaterial3D = piece.paper_material
	material.no_depth_test = true
	material.render_priority = 127
	piece.visual.material_override = material
	for visual: MeshInstance3D in [piece.visual, piece.border, piece.shadow]:
		visual.layers = FRONT_LAYERS
		visual.set_meta("paper_foreground", true)
		visual.set_meta("slice_whole", true)
		visual.set_meta("wall_layer_attached", false)
		visual.set_meta("screen_band", 11)
		visual.set_meta("resolved_screen_band", 11)
	for key: String in ["border", "shadow"]:
		var ink: StandardMaterial3D = piece["front_" + key + "_material"]
		ink.no_depth_test = true
		ink.render_priority = 126 if key == "border" else 125
		piece[key].material_override = ink

func _build_fairy_ramp() -> void:
	if is_instance_valid(fairy_ramp): return
	fairy_ramp = StaticBody3D.new()
	fairy_ramp.name = "Stage2FairyHeadRamp"
	fairy_ramp.collision_layer = 1
	fairy_ramp.collision_mask = 2
	# 38-degree convex wedge, overlapping both shores and touching the crown.
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for x: float in [-.6,.6]:
		points.append(Vector3(x,0,1.15))
		points.append(Vector3(x,1.8,-1.15))
		points.append(Vector3(x,-.25,-1.15))
		points.append(Vector3(x,-.25,1.15))
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.shape = shape
	fairy_ramp.add_child(collision)
	world.stage_root.add_child(fairy_ramp)
