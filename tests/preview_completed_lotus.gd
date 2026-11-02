extends SceneTree

# Interactive preview with a separate save. Closing the window keeps real
# player progress untouched; entering/replaying maps uses this preview save.
var preview_save := "/private/tmp/topofyean-lotus-preview-%d.cfg" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	LotusProgress.storage_path = preview_save
	var config := ConfigFile.new()
	for number in range(1, 10):
		config.set_value("cleared", str(number), true)
	if config.save(preview_save) != OK:
		push_error("Could not prepare the completed lotus preview")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.title = "연의 꽃 · 전체 클리어 미리보기"
	var selection: Control = load("res://scenes/grid_stage/menu.tscn").instantiate()
	root.add_child(selection)
	for frame in range(8):
		await process_frame
	if root.has_method("grab_focus"):
		root.call("grab_focus")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/lotus-live-preview.png")
	print("Completed lotus preview ready: all 9 stages unlocked; original save unchanged.")

func _finalize() -> void:
	DirAccess.remove_absolute(preview_save)
