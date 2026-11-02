extends RefCounted
## Shared by stage titles, opening narration and hints.

static func create() -> Font:
	return preload("res://art/fonts/HS-Winter-Snowflake.ttf")
