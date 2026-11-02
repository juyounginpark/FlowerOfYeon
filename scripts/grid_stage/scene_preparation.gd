extends Node
## Keep the next scene's resources alive without blocking on an unfinished load.
var path: String
var packed: PackedScene
var failed := false

func request(scene_path: String) -> void:
	path = scene_path
	failed = ResourceLoader.load_threaded_request(path, "PackedScene") != OK
	set_process(not failed)

func _process(_delta: float) -> void:
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		packed = ResourceLoader.load_threaded_get(path) as PackedScene
		failed = packed == null
		set_process(false)
	elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		failed = true
		set_process(false)

func fetch() -> PackedScene:
	while packed == null and not failed:
		await get_tree().process_frame
	return packed
