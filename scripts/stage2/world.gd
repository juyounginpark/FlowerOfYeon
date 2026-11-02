extends "res://scripts/grid_stage/world.gd"
## main.tscn entry point: inherit shared gameplay, add features only for runtime 5.
const WOODCUTTER = preload("res://scripts/stage2/woodcutter.gd")
const PHOTO_PAIR = preload("res://scripts/stage2/photo_pair.gd")
const WOODCUTTER_BLOCKER = preload("res://scripts/stage2/woodcutter_blocker.gd")
const DIALOGUE = preload("res://scripts/stage2/dialogue.gd")
const ROBE_PUZZLE = preload("res://scripts/stage2/robe_puzzle.gd")
var stage2_dialogue: Node3D
@export_range(0.1, 60.0, 0.1) var woodcutter_fps: float = 8.0
@export_group("Stage2 Photos")
## Visible artwork center: (0,0) top-left, (1,1) bottom-right at stage entry.
@export var fairy_position_ratio := Vector2(0.819896, 0.448195)
@export_range(0.01, 0.8, 0.001) var fairy_visible_width_ratio: float = 0.236243
@export var rock_position_ratio := Vector2(0.572234, 0.797753)
@export_range(0.01, 0.8, 0.001) var rock_visible_width_ratio: float = 0.243657

func _uses_default_woodcutter() -> bool:
	return false

func load_stage(number: int, preserve_transition := false) -> void:
	stage2_dialogue = null
	# Preserve the PDF-aligned Stage2 camera; retain upstream yaw for other maps.
	var shared_yaw := camera_yaw_degrees
	if number == 5:
		camera_yaw_degrees = 45.0
	await super.load_stage(number, preserve_transition)
	camera_yaw_degrees = shared_yaw
	if stage_number != 5:
		return
	await _entry_build_step()
	var actor := WOODCUTTER.new()
	actor.name = "Stage2Woodcutter"
	actor.animation_fps = woodcutter_fps
	# Match the actual painted player silhouette rather than a fraction of screen.
	var player_texture: Texture2D = player.sprite.sprite_frames.get_frame_texture(player.sprite.animation, player.sprite.frame)
	var player_image := player_texture.get_image()
	if player_image.is_compressed(): player_image.decompress()
	actor.character_height = player_image.get_used_rect().size.y * player.sprite.pixel_size
	# The long START platform is one cuboid, visually read as three blocks.
	# Third block = final third along +X, on the same Z row as the player.
	var start_box: Array = stage_data.low[0]
	var left: float = start_box[0].x * 0.2
	var right: float = start_box[1].x * 0.2
	actor.position = Vector3(lerpf(left, right, 5.0 / 6.0), start_box[1].y * 0.2, start_position.z)
	stage_root.add_child(actor)
	await _entry_build_step()
	var blocker := WOODCUTTER_BLOCKER.new()
	blocker.name = "Stage2WoodcutterBlocker"
	stage_root.add_child(blocker)
	blocker.configure(start_box, actor.position, player)
	var photos := PHOTO_PAIR.new()
	photos.name = "Stage2Photos"
	stage_root.add_child(photos)
	photos.configure(camera, stage_data.focus, fairy_position_ratio,
		fairy_visible_width_ratio, rock_position_ratio, rock_visible_width_ratio)
	await _entry_build_step()
	stage2_dialogue = DIALOGUE.new()
	stage2_dialogue.name = "Stage2Dialogue"
	stage_root.add_child(stage2_dialogue)
	stage2_dialogue.configure(self)
	stage2_dialogue.position = actor.position
	dialogue = stage2_dialogue
	var puzzle := ROBE_PUZZLE.new()
	puzzle.name = "Stage2RobePuzzle"
	stage_root.add_child(puzzle)
	puzzle.setup(self, photos.get_node("RobeOnRock"), actor, blocker)

	stage2_camera_pose = camera.global_transform
	stage2_camera_size = camera.size

var stage2_camera_pose := Transform3D.IDENTITY
var stage2_camera_size := 10.0
var stage2_resetting := false

func restart() -> void:
	if stage_number != 5:
		super.restart()
		return
	if stage2_resetting: return
	_restart_stage2()

func _restart_stage2() -> void:
	stage2_resetting = true
	if is_instance_valid(stage_help):stage_help.reset(stage_number)
	var root := stage_root
	transition.cancel()
	paused = true
	player.paused = true
	player.input_locked = true
	if is_instance_valid(dialogue): dialogue.cancel()
	camera.global_transform = stage2_camera_pose
	camera.size = stage2_camera_size
	# Reuse terrain, render passes, decoded art and collision resources.
	# Restore one botanical source per frame instead of rebuilding every viewport.
	var cutters: Array[Node] = []
	for child: Node in root.find_children("*", "Node3D", true, false):
		if child is GridPaperCutting: cutters.append(child)
	for cutter: Node in cutters:
		if cutter.has_method("reset_puzzle"):
			cutter.reset_puzzle()
		else:
			if is_instance_valid(cutter.grabbed): cutter._finish_drag(false)
			cutter.drawing = false
			cutter.stroke.clear_points()
			for source: Dictionary in cutter.sources:
				cutter.restore_source(source.sprite)
				await get_tree().process_frame
				if not is_instance_valid(root) or stage_root != root:
					stage2_resetting = false
					return
	for candidate: Dictionary in rune_candidates:
		candidate.body.position = candidate.origin
		candidate.phase = LiftPhase.IDLE
		candidate.time = 0.0
	phase = LiftPhase.IDLE
	phase_time = 0.0
	elapsed = 0.0
	completion_time = -1.0
	completed = false
	transition_consumed = false
	player.position = start_position
	player.velocity = Vector3.ZERO
	player.play_time = 0.0
	player.land_time = 0.0
	player.facing = "southeast"
	player.sprite.show()
	player._play_directional_animation("idle")
	for mark: Dictionary in player.footprints.marks:
		if is_instance_valid(mark.mesh): mark.mesh.queue_free()
	player.footprints.marks.clear()
	var butterfly := stage_root.get_node_or_null("ButterflyGuide")
	if butterfly != null:
		butterfly.cursor = 0
		butterfly.clock = 0.0
		butterfly.state = "entering"
		butterfly.state_time = 0.0
		butterfly.flying = false
		butterfly.arrived = false
		butterfly.departure_ready = false
		butterfly.motion_origin = butterfly._outside_screen(false, butterfly.start_anchor)
		butterfly.anchor = butterfly.motion_origin
		butterfly.position = butterfly.anchor
		butterfly.trail.emitting = false
		butterfly.show()
	for child: Node in stage_root.get_children():
		if child is GridCollageLayers:
			child.elapsed = 0.0
			child.refresh_clock = 0.0
			child.edge_water.elapsed = 0.0
			child.edge_water.botanical_clock = 0.0
			child.edge_water.placement_pending = true
			for patch: Dictionary in child.edge_water.patches:
				patch["pulse_start"] = -100.0
	paused = false
	player.paused = false
	stage_intro.begin(stage_number, true)
	transition.start_entry()
	stage2_resetting = false

func _process(delta: float) -> void:
	if stage2_resetting: return
	super._process(delta)
