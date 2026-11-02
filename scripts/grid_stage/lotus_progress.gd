class_name LotusProgress
extends RefCounted

# Runtime maps 1–3 are practice maps; maps 4–12 are the nine lotus stages.
static var storage_path := "user://lotus_progress.cfg"

static func cleared_stages() -> Array[int]:
	var result: Array[int] = []
	var config := ConfigFile.new()
	if config.load(storage_path) != OK:
		return result
	for number in range(1, 10):
		if config.get_value("cleared", str(number), false) == true:
			result.append(number)
	return result

static func available_count(cleared: Array[int]) -> int:
	var count := 1
	# Older saves may have gaps from story-specific completion paths.
	# Keep later cleared maps and their successor accessible without inventing clears.
	for number in cleared:
		if number >= 1 and number <= 9:
			count = maxi(count, mini(number + 1, 9))
	return count

static func record_clear(runtime_map: int) -> Error:
	if runtime_map < 4 or runtime_map > 12:
		return OK
	var config := ConfigFile.new()
	var error := config.load(storage_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		return error
	config.set_value("cleared", str(runtime_map - 3), true)
	return config.save(storage_path)
