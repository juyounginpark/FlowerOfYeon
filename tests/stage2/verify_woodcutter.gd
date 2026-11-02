extends SceneTree
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func run() -> void:
	root.size = Vector2i(1280, 720)
	var world = load("res://scenes/grid_stage/main.tscn").instantiate()
	world.stage_number = 5
	root.add_child(world)
	var actor: AnimatedSprite3D = world.stage_root.get_node("Stage2Woodcutter")
	check(world.stage_number == 5, "Stage2 runtime id")
	check(actor.sprite_frames.get_frame_count(&"axe") == 16, "16 individual frames")
	check(actor.sprite_frames.get_animation_speed(&"axe") == 8.0, "8 FPS default")
	check(actor.is_playing() and actor.sprite_frames.get_animation_loop(&"axe"), "autoplay loop")
	for i: int in range(16):
		var texture: AtlasTexture = actor.sprite_frames.get_frame_texture(&"axe", i)
		check(texture.region == Rect2((i % 4) * 256, floori(i / 4.0) * 384, 256, 384), "row-major frame %d" % i)
	check(actor.position.distance_to(Vector3(-1.0 / 30.0, 0, 1.8)) < 0.001, "third section of long start platform")
	var anchor := actor.position
	var offset := actor.offset
	var seen: Dictionary = {}
	var looped := [false]
	actor.animation_looped.connect(func(): looped[0] = true)
	for tick in range(145):
		await create_timer(0.02).timeout
		seen[actor.frame] = true
		check(actor.position == anchor and actor.offset == offset, "stationary sole anchor")
	check(seen.size() == 16 and looped[0], "all frames played and looped")
	actor.animation_fps = 12.0
	check(actor.sprite_frames.get_animation_speed(&"axe") == 12.0, "adjustable FPS")
	world.restart()
	check(world.stage_root.get_node("Stage2Woodcutter").is_playing(), "restart recreates animation")
	if DisplayServer.get_name() != "headless":
		await create_timer(7.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/stage2_woodcutter_preview.png")
	world.load_stage(6)
	check(not world.stage_root.has_node("Stage2Woodcutter"), "absent from other stages")
	world.queue_free()
	await process_frame
	if not failed:
		print("PASS Stage2 woodcutter: atlas, autoplay, loop, anchor, speed, restart, isolation")
	quit(1 if failed else 0)
