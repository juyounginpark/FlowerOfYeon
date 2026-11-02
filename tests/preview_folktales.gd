extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1280,720)
 for number in [7,8,11]:
  var world=load("res://scripts/grid_stage/world.gd").new();world.stage_number=number;root.add_child(world)
  for frame in range(12):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../stage_screenshots/story_%d_preview.png"%(number-3)))
  world.queue_free();await process_frame
 quit()
