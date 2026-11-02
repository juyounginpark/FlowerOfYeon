extends "res://scripts/grid_stage/woodcutter_dialogue.gd"
## Reuse shared range checks, nearest-E targeting, speech UI, fade and cleanup.
const SCRIPT_LINE := "심청이가 임당수에 빠졌더랬지 ..."
const CLEAR_LINE := SCRIPT_LINE

func begin() -> bool:
	if not active:
		var puzzle = world.story
		var cleared: bool = is_instance_valid(puzzle) and puzzle.path_open
		lines = PackedStringArray([CLEAR_LINE if cleared else SCRIPT_LINE])
	return super.begin()

func _create_actor() -> void:
	# Stage3 already owns the static 9.png character; do not spawn another NPC.
	pass

func configure(owner_world: GridStageWorld, speaker_sprite: Sprite3D = null) -> void:
	lines = PackedStringArray([SCRIPT_LINE])
	display_seconds = 5.0
	super.configure(owner_world, speaker_sprite)
	line.add_theme_font_size_override("font_size",22)
	bubble.fit_to_text()
