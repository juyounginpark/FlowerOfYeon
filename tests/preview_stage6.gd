extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720)
	var world=load("res://scripts/grid_stage/world.gd").new()
	world.stage_number=9;root.add_child(world)
	await create_timer(7.0).timeout
	world.paused=true;world.player.paused=true
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/stage6"))
	var error:=root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/stage6/layout.png"))
	print("STAGE6_LAYOUT_CAPTURE ",error," player=",world.player.position," sister=",world.story.sister_base)
	quit()
