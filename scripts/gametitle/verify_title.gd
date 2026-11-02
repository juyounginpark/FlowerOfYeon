extends SceneTree
## Optional standalone verification; never referenced by gameplay scenes.
var failures: int = 0
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
	else: print("PASS ", message)

func _initialize() -> void:
	call_deferred("verify")

func capture(file: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/" + file + ".png")

func verify() -> void:
	var scene := load("res://scenes/gametitle/GameTitleAnimated.tscn") as PackedScene
	check(scene != null, "independent scene loads")
	if scene == null:
		quit(1)
		return
	var title := scene.instantiate() as Control
	root.add_child(title)
	var composition := title.get_node("Composition") as Control
	var player := title.get_node("AnimationPlayer") as AnimationPlayer
	var rings: Array[Sprite2D] = []
	for i in range(1, 4): rings.append(title.get_node("Composition/Ripple%d/Ring" % i))
	check(rings.all(func(r: Sprite2D) -> bool: return r.modulate.a == 0), "rings invisible before first rendered frame")
	await process_frame
	check(player.is_playing() and player.current_animation == "LotusBreath", "eight-second animation autoplays")
	await capture("gametitle-start")
	var clouds: Array[Node2D] = [composition.get_node("CloudLeft"), composition.get_node("CloudRight"), composition.get_node("CloudSmall")]
	var previous: Array[Vector2] = [clouds[0].position, clouds[1].position, clouds[2].position]
	var saw_lift: bool = false
	var saw_rings: bool = false
	var hidden_during_rest: bool = true
	var smooth_clouds: bool = true
	var bounded_lift: bool = true
	var cycle_count: int = 0
	var last_time: float = 0
	var rest_cycles: int = 0
	var resting: bool = false
	var continuous_rings: bool = true
	var previous_width: float = rings[0].scale.x * 2115.0
	var previous_alpha: float = rings[0].modulate.a
	for frame in range(1560):
		await process_frame
		var t := player.current_animation_position
		var width: float = rings[0].scale.x * 2115.0
		if rings[0].modulate.a > 0.001 and previous_alpha > 0.001:
			continuous_rings = continuous_rings and absf(width - previous_width) < 20.0 and absf(rings[0].modulate.a - previous_alpha) < 0.04
		previous_width = width
		previous_alpha = rings[0].modulate.a
		if t < last_time: cycle_count += 1
		last_time = t
		var lift := composition.get_node("LotusMotion") as Node2D
		bounded_lift = bounded_lift and lift.position.y >= -4.001 and lift.position.y <= 0.001
		if t > 0.9 and t < 1.5 and lift.position.y < -0.1: saw_lift = true
		if t > 2.5 and t < 4 and rings[0].modulate.a > 0.01: saw_rings = true
		if t < 1.6 or t > 6.41:
			hidden_during_rest = hidden_during_rest and rings.all(func(r: Sprite2D) -> bool: return r.modulate.a < 0.0001)
		if t > 6.5 and not resting:
			rest_cycles += 1
			resting = true
		if t < 1: resting = false
		for i in range(3):
			smooth_clouds = smooth_clouds and clouds[i].position.distance_to(previous[i]) < 1.0
			previous[i] = clouds[i].position
		if frame == 210: await capture("gametitle-ripples")
		if frame == 450: await capture("gametitle-rest")
	check(cycle_count >= 3 and rest_cycles >= 3, "at least three complete loops and quiet intervals")
	check(saw_lift and saw_rings and hidden_during_rest, "lift precedes ripples; all rings invisible during initial and final rest")
	check(bounded_lift, "lotus displacement stays within four pixels with no accumulation")
	check(smooth_clouds, "clouds remain continuous across all lotus loop boundaries")
	check(continuous_rings, "visible ripple width and opacity change continuously rather than integer steps")
	var lotus_local := (composition.get_node("LotusMotion/Lotus") as Sprite2D).position
	for window_size in [Vector2i(1100, 700), Vector2i(700, 900), Vector2i(1500, 600)]:
		root.size = window_size
		for i in range(6): await process_frame
		var factor := minf(title.size.x / 1586.0, title.size.y / 992.0)
		check(composition.scale.is_equal_approx(Vector2.ONE * factor) and composition.position.is_equal_approx((title.size - Vector2(1586, 992) * factor) * .5), "uniform centered layout at %s" % window_size)
		check((composition.get_node("LotusMotion/Lotus") as Sprite2D).position == lotus_local, "resize preserves artwork reference coordinates")
		await capture("gametitle-size-%dx%d" % [window_size.x, window_size.y])
	print("GAMETITLE RESULT: ", failures, " failures")
	quit(0 if failures == 0 else 1)
