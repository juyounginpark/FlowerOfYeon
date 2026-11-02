extends "res://scripts/grid_stage/woodcutter_dialogue.gd"
## Stage2 configuration; shared script owns E targeting, UI and timed fade.

func _create_actor() -> void:
	# The animated Stage2 actor and passage blocker already exist.
	pass

func configure(owner_world: GridStageWorld, speaker_sprite: Sprite3D = null) -> void:
	lines = PackedStringArray(["선녀의 옷을 가져다줘."])
	display_seconds = 5.0
	super.configure(owner_world, speaker_sprite)
