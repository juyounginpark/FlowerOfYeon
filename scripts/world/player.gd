class_name WorldPilgrim
extends CharacterBody3D

var route: WorldRoute
# Shared local walking heading drives both visible facing and rune eligibility.
var heading := Vector3.FORWARD
var path_forward := Vector3.FORWARD
var visual_forward := Vector3.FORWARD
var tower_root: Node3D
var camera: Camera3D
var camera_relative_movement := false
var sprite: AnimatedSprite3D
var station := 0.0
var move_speed := 3.8
var jump_speed := 6.2
var gravity := 18.0
var input_locked := false
var paused := false
var play_time := 0.0
var land_time := 0.0
var facing := "south"
var was_grounded := false
var prevent_walk_off_edges := true
var knockback_velocity := Vector3.ZERO
var knockback_time := 0.0
var max_step_height := 0.0

func apply_knockback(impulse:Vector3,seconds:=.35) -> void:
	knockback_velocity=Vector3(impulse.x,0,impulse.z)
	knockback_time=seconds
	velocity.y=maxf(velocity.y,impulse.y)
var shadow: MeshInstance3D
signal fell
signal jumped

func _ready() -> void:
	process_physics_priority = 0 # World position-follow controller runs later at20.
	collision_layer=2
	collision_mask=5
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.22
	capsule.height = 1.25
	collision.shape = capsule
	collision.position.y = 0.625
	add_child(collision)
	# TowerRoot carries the whole local world once. Built-in moving-platform
	# velocity would add that inherited angular motion a second time.
	platform_floor_layers=0
	platform_wall_layers=0
	platform_on_leave=CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	# Rune safety pauses extension on contact and defers occupied retraction;
	# occupants never require a second automatic moving-platform transport.
	floor_snap_length = 0.23
	floor_max_angle = deg_to_rad(45)
	floor_constant_speed = true
	floor_stop_on_slope = true
	sprite = AnimatedSprite3D.new()
	sprite.name = "IllustratedTraveler"
	sprite.sprite_frames = TravelerFrames.create()
	sprite.pixel_size = 0.0032
	# Billboard rotates about the sole anchor, not the image center. This keeps
	# the rendered foot on the floor even with an elevated orthographic camera.
	sprite.offset = Vector2(0, 488 - 256)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.25
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.no_depth_test = false
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(sprite)
	sprite.play("idle_south")
	var disk := CylinderMesh.new()
	disk.top_radius = 0.28
	disk.bottom_radius = 0.28
	disk.height = 0.004
	disk.radial_segments = 32
	shadow = MeshInstance3D.new()
	shadow.name = "ContactShadow"
	shadow.mesh = disk
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.17, 0.22, 0.18, 0.22)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)

func _physics_process(delta: float) -> void:
	if paused or input_locked:
		return
	station = route.closest(position)
	play_time = maxf(0, play_time - delta)
	land_time = maxf(0, land_time - delta)
	# D/A follows the route; W/S crosses its width (arrow aliases remain).
	# This basis supplies directions only: there is no centre attraction,
	# positional snap, lateral clamp or endpoint movement lock.
	var forward_axis := Input.get_axis("back", "forward")
	var lateral_axis := Input.get_axis("left", "right")
	path_forward=route.horizontal_heading(station)
	var tangent := path_forward
	var lateral := tangent.cross(Vector3.UP).normalized()
	if camera_relative_movement:
		var view_forward:Vector3=-camera.global_basis.z
		view_forward.y=0
		var view_right:Vector3=camera.global_basis.x
		view_right.y=0
		# Camera axes are WORLD vectors. Convert once into the parent-local frame;
		# the existing movement assignment below converts the final vector back once.
		tangent=tower_root.global_basis.inverse()*view_forward.normalized()
		lateral=tower_root.global_basis.inverse()*view_right.normalized()
	var local_input := (tangent*forward_axis+lateral*lateral_axis).limit_length(1.0)
	var movement := tower_root.global_basis*local_input*move_speed
	velocity.x=move_toward(velocity.x,movement.x,delta*24)
	velocity.z=move_toward(velocity.z,movement.z,delta*24)
	var knocked:=knockback_time>0
	if knocked:
		velocity.x=knockback_velocity.x;velocity.z=knockback_velocity.z
		knockback_time=maxf(0,knockback_time-delta)
		knockback_velocity=knockback_velocity.move_toward(Vector3.ZERO,delta*5)
	var driven := Vector2(velocity.x,velocity.z).length_squared()>0.000001
	var grounded_before := is_on_floor()
	var before_local := position
	if grounded_before:
		if Input.is_action_just_pressed("jump"):
			velocity.y=jump_speed;jumped.emit()
		elif prevent_walk_off_edges and not knocked:_guard_walk_edges(delta)
	else:
		velocity.y-=gravity*delta
	_constrain_motion(delta)
	_step_over_seam(delta,grounded_before,knocked)
	move_and_slide()
	# Local travel excludes inherited tower carry. This controls appearance only;
	# the world independently observes position after this callback. Braking counts, but
	# excludes airborne motion, stationary idle and passive platform transport.
	var actual_step:=position-before_local
	actual_step.y=0
	var walking:=grounded_before and is_on_floor() and driven and actual_step.length_squared()>0.00000001
	if walking:
		heading=actual_step.normalized()
	station = route.closest(position)
	if is_on_floor() and not was_grounded:
		land_time = 0.22
	was_grounded = is_on_floor()
	_update_walk_facing()
	var action := "idle"
	if play_time > 0:
		action = "play"
	elif not is_on_floor():
		action = "jump"
	elif land_time > 0:
		action = "land"
	elif walking:
		action = "walk"
	_play_directional_animation(action)
	_update_shadow()
	if position.y < route.point(station).y - 1.25:
		fell.emit()

func _constrain_motion(_delta:float) -> void:
	pass

func _step_over_seam(delta:float,grounded:bool,knocked:bool) -> void:
	if max_step_height<=0 or not grounded or knocked or Input.is_action_just_pressed("jump"):return
	var travel:=Vector3(velocity.x,0,velocity.z)*delta
	if travel.length_squared()<.00000001:return
	var obstruction:=KinematicCollision3D.new()
	if not test_move(global_transform,travel,obstruction):return
	# Ordinary slopes stay with move_and_slide; only a blocking lip needs help.
	if obstruction.get_normal().dot(Vector3.UP)>=cos(floor_max_angle):return
	var clearance:=Vector3.UP*(max_step_height+safe_margin*2.0)
	if test_move(global_transform,clearance):return
	var raised:=global_transform
	raised.origin+=clearance
	if test_move(raised,travel):return
	raised.origin+=travel
	var landing:=KinematicCollision3D.new()
	if not test_move(raised,-clearance-Vector3.UP*floor_snap_length,landing):return
	if landing.get_normal().dot(Vector3.UP)<cos(floor_max_angle):return
	var rise:=clearance.y+landing.get_travel().y
	if rise<=safe_margin or rise>max_step_height:return
	# Full capsule sweeps verify headroom, the forward path and real support.
	# Raise only; the normal movement call still handles horizontal collisions.
	global_position.y+=rise
	velocity.y=0.0

func _walk_has_support(step:Vector3) -> bool:
	# Probe only real walkable collision surfaces, including ramps and moving lifts.
	# Small height tolerance permits slope travel without stepping into a deep drop.
	var destination:=global_position+step
	var rise:=maxf(maxf(.12,max_step_height+.02),step.length()*tan(floor_max_angle)+.03)
	var query:=PhysicsRayQueryParameters3D.create(destination+Vector3.UP*rise,destination-Vector3.UP*maxf(.45,floor_snap_length),collision_mask,[get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.normal.dot(Vector3.UP)>=cos(floor_max_angle)-.01

func _guard_walk_edges(delta:float) -> void:
	var requested:=Vector3(velocity.x,0,velocity.z)
	if requested.length_squared()<.000001:return
	# Keep the foot centre slightly inside the surface; do not require a full
	# capsule-width footprint, so the narrow severed-nose bridges remain usable.
	var probe:=requested*delta+requested.normalized()*.045
	if _walk_has_support(probe):return
	var allowed:=Vector3.ZERO
	var best:=0.0
	# Slide along an edge instead of sticking when the input points diagonally out.
	for degrees:int in [15,30,45,60,75,90]:
		for sign_:float in [-1.0,1.0]:
			var direction:=requested.normalized().rotated(Vector3.UP,deg_to_rad(degrees)*sign_)
			var speed:=maxf(0,requested.dot(direction))
			var candidate:=direction*speed
			var score:=candidate.dot(requested)
			if score>best and _walk_has_support(candidate*delta+direction*.045):
				allowed=candidate;best=score
	velocity.x=allowed.x;velocity.z=allowed.z

static func polar_advance(before:Vector3,after:Vector3) -> float:
	var a:=Vector2(before.x,before.z)
	var b:=Vector2(after.x,after.z)
	if a.length_squared()<0.000001 or b.length_squared()<0.000001:return 0.0
	# atan2(x,z) increases along the authored climb. Cross/dot gives the exact
	# shortest signed angular advance across +/-PI, including varying radius.
	return atan2(a.y*b.x-a.x*b.y,a.dot(b))

func _update_walk_facing() -> void:
	# Keep the last actual walking heading when blocked/jumping/idle, but
	# reproject it after any parent yaw so the sprite never faces a stale frame.
	path_forward=route.horizontal_heading(route.closest(position))
	visual_forward=(tower_root.global_basis*heading).normalized()
	# Camera up gives SCREEN vertical, unlike camera backward which overweights
	# depth at an elevated view. Vector2 is screen-right / screen-down.
	var projected := Vector2(visual_forward.dot(camera.global_basis.x), -visual_forward.dot(camera.global_basis.y))
	if camera_relative_movement:
		# Shoulder view uses view azimuth: looking above the horizon must not
		# turn an away-walking character into a front-facing sprite.
		var view_forward:Vector3=-camera.global_basis.z
		view_forward.y=0
		projected=Vector2(visual_forward.dot(camera.global_basis.x),-visual_forward.dot(view_forward.normalized()))
	facing = screen_direction(projected, facing)

static func screen_direction(projected: Vector2, previous: String, hysteresis_degrees: float = 5.0) -> String:
	if projected.length_squared() < 0.000001: return previous
	var angle := atan2(projected.x, projected.y)
	var previous_index := TravelerFrames.DIRECTIONS.find(previous)
	if previous_index >= 0:
		var difference := absf(wrapf(angle-float(previous_index)*PI/4.0, -PI, PI))
		if difference <= PI/8.0+deg_to_rad(hysteresis_degrees): return previous
	var index := posmod(int(floor((angle+PI/8.0)/(PI/4.0))), 8)
	return TravelerFrames.DIRECTIONS[index]

func _play_directional_animation(action: String) -> void:
	var animation := action+"_"+facing
	if sprite.animation == animation: return
	var previous_action := String(sprite.animation).get_slice("_", 0)
	var previous_frame := sprite.frame
	var previous_progress := sprite.frame_progress
	var previous_playing := sprite.is_playing()
	sprite.play(animation)
	# Changing view sector must not restart the stride (or a play/landing pose).
	# A genuinely different action starts its own timeline normally.
	if previous_action == action:
		sprite.set_frame_and_progress(mini(previous_frame, sprite.sprite_frames.get_frame_count(animation)-1), previous_progress)
		if not previous_playing: sprite.pause()

func _update_shadow() -> void:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.12, global_position + Vector3.DOWN * 3.0)
	query.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	shadow.visible = not result.is_empty()
	if shadow.visible:
		shadow.global_position = result.position + result.normal * 0.012
		shadow.global_basis = Basis(Quaternion(Vector3.UP, result.normal))
		var height := global_position.distance_to(result.position)
		shadow.scale = Vector3.ONE * lerpf(0.95, 1.25, clampf(height / 2.0, 0, 1))
		shadow.material_override.albedo_color = Color(0.17, 0.22, 0.18, 0.22 * clampf(1.0 - height / 3.0, 0.1, 1.0))
