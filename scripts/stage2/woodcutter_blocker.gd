extends StaticBody3D
## Fixed gameplay footprint, independent of atlas frames and visual scale.
## The third start-platform section is occupied by the woodcutter.

func configure(start_box: Array, anchor: Vector3, pilgrim: WorldPilgrim) -> void:
	collision_layer = 1 # Same solid-world layer as StageCells.
	collision_mask = 2 # Player; no trigger, damage, or input locking.
	var low := Vector3(start_box[0]) * StageCells.UNIT
	var high := Vector3(start_box[1]) * StageCells.UNIT
	var section_width: float = (high.x - low.x) / 3.0
	# The platform borders open water, not walls. Extend the barrier into that
	# water beyond one normal jump's horizontal reach, so neither edge forms a
	# shortcut onto the adjacent lift. No extra floor or visible geometry.
	var jump_reach: float = pilgrim.move_speed * (2.0 * pilgrim.jump_speed / pilgrim.gravity)
	var capsule: CapsuleShape3D = null
	for child: Node in pilgrim.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:
			capsule = child.shape
			break
	assert(capsule != null, "Stage2 blocker expects the existing player capsule")
	var edge_guard: float = snappedf(ceilf((jump_reach + capsule.radius + 0.05) / StageCells.UNIT) * StageCells.UNIT, StageCells.UNIT)
	var jump_height: float = pilgrim.jump_speed * pilgrim.jump_speed / (2.0 * pilgrim.gravity)
	var top: float = high.y + jump_height + capsule.height + 0.2
	var box := BoxShape3D.new()
	box.size = Vector3(section_width, top - low.y, high.z - low.z + 2.0 * edge_guard)
	var collision := CollisionShape3D.new()
	collision.name = "FixedPassageCollision"
	collision.shape = box
	add_child(collision)
	position = Vector3(anchor.x, (low.y + top) * 0.5, (low.z + high.z) * 0.5)
