extends SceneTree
var world: GridStageWorld
var failed := false
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error(message)

func release_input() -> void:
	for action in ["forward", "back", "left", "right", "jump"]:
		Input.action_release(action)

func drive(direction: Vector3) -> void:
	release_input()
	var forward := -world.camera.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := world.camera.global_basis.x
	right.y = 0
	right = right.normalized()
	var f := direction.dot(forward)
	var r := direction.dot(right)
	Input.action_press("forward" if f >= 0 else "back", absf(f))
	Input.action_press("right" if r >= 0 else "left", absf(r))

func ticks(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func place(point: Vector3) -> void:
	release_input()
	world.player.position = point
	world.player.velocity = Vector3.ZERO
	await ticks(5)

func run() -> void:
	world = load("res://scenes/grid_stage/main.tscn").instantiate()
	world.stage_number = 5
	root.add_child(world)
	world.transition.cancel()
	await ticks(3)
	var blocker: StaticBody3D = world.stage_root.get_node("Stage2WoodcutterBlocker")
	var collision: CollisionShape3D = blocker.get_node("FixedPassageCollision")
	var fixed_size: Vector3 = collision.shape.size
	var fixed_transform := blocker.global_transform
	var actor: AnimatedSprite3D = world.stage_root.get_node("Stage2Woodcutter")
	var artwork_transform := actor.transform
	var artwork_pixel_size := actor.pixel_size
	var photo_transforms: Array[Transform3D] = []
	for photo in world.stage_root.get_node("Stage2Photos").get_children():
		photo_transforms.append(photo.global_transform)
	check(blocker.collision_layer == 1 and world.player.collision_mask & 1, "existing world collision layer")
	# Sweep the REAL player capsule across every frame, both platform edges,
	# and the neighboring air gaps, on foot and near maximum jump height.
	world.player.set_physics_process(false)
	for frame in range(16):
		actor.frame = frame
		for z: float in [0.7, 1.01, 1.23, 1.8, 2.37, 2.59, 2.9]:
			for y: float in [0.04, 1.05]:
				var hit := KinematicCollision3D.new()
				var blocked := world.player.test_move(Transform3D(Basis.IDENTITY, Vector3(-2, y, z)), Vector3(4, 0, 0), hit)
				check(blocked and hit.get_collider() == blocker, "capsule blocked frame=%d z=%.2f y=%.2f" % [frame, z, y])
		check(collision.shape.size == fixed_size and blocker.global_transform == fixed_transform, "frame-independent collision")
	world.player.set_physics_process(true)
	# Existing input -> acceleration -> move_and_slide, with no test movement replacement.
	for z: float in [1.02, 1.8, 2.58]:
		await place(Vector3(-2, 0.04, z))
		drive(Vector3.RIGHT)
		await ticks(100)
		check(world.player.position.x < -1.0 and world.player.position.x > -1.2, "stops at woodcutter, lane %.2f" % z)
		check(world.player.is_on_floor() and not world.player.input_locked, "blocked without freezing input")
		var stopped_x: float = world.player.position.x
		drive(Vector3.LEFT)
		await ticks(35)
		check(world.player.position.x < stopped_x - 0.7, "can retreat, lane %.2f" % z)
	# Jump/diagonal edge attempts must not cross the occupied third section.
	for direction: Vector3 in [Vector3.RIGHT, Vector3(1, 0, -1).normalized(), Vector3(1, 0, 1).normalized()]:
		await place(Vector3(-1.4, 0.04, 1.8))
		drive(direction)
		Input.action_press("jump")
		await ticks(1)
		Input.action_release("jump")
		for tick in range(90):
			await ticks(1)
			check(world.player.position.x < -0.85, "no jump/diagonal bypass")
	release_input()
	check(actor.transform == artwork_transform and actor.pixel_size == artwork_pixel_size and actor.is_playing(), "visual placement, size and animation retained")
	var index := 0
	for photo in world.stage_root.get_node("Stage2Photos").get_children():
		check(photo.global_transform == photo_transforms[index], "photos unchanged")
		index += 1
	world.restart()
	await ticks(3)
	check(world.stage_root.has_node("Stage2WoodcutterBlocker"), "restart restores blocker")
	world.load_stage(6)
	await ticks(3)
	check(not world.stage_root.has_node("Stage2WoodcutterBlocker"), "no blocker in next stage")
	world.queue_free()
	await process_frame
	if not failed:
		print("PASS: %d Stage2 obstacle checks (capsule sweeps, edges, jump, real movement, retreat, restart, isolation)" % checks)
	quit(1 if failed else 0)
