extends RigidBody3D
signal landed
var world: GridStageWorld
var grounded := false
var resume_velocity := Vector3.ZERO

func _physics_process(_delta: float) -> void:
	var stopped := grounded or world.paused or world.transition.active
	if stopped == freeze: return
	if stopped:
		resume_velocity = linear_velocity
		freeze = true
	else:
		freeze = false
		linear_velocity = resume_velocity

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if grounded: return
	for i in range(state.get_contact_count()):
		if state.get_contact_local_normal(i).y > .65 and state.linear_velocity.y <= .2:
			grounded = true
			state.linear_velocity = Vector3.ZERO
			set_deferred("freeze",true)
			landed.emit()
			return
