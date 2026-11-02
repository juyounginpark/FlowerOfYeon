extends "res://scripts/grid_stage/woodcutter_dialogue.gd"
## Reuse the common nearest-target E interaction, hanji bubble and pause/fade.
var puzzle:Node3D

func can_interact() -> bool:
	return is_instance_valid(puzzle) and not puzzle.reset_pending and super.can_interact()
