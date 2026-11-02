extends WorldPilgrim
# Authored pace: 4 frames at 7 fps, contacts at frames 0/2 = 3.5 steps/s.
# Target 0.48 m per foot contact; an art-based estimate, not runtime measured.
const WALK_METRES_PER_CONTACT:=0.48
const WALK_CONTACTS_PER_SECOND:=3.5
var idle_elapsed:=.4
var footprints:GridFootprints
var rebounding:=false
var rebound_launch:=false
var rebound_velocity:=Vector3.ZERO

func rebound_to(target:Vector3) -> void:
	# A ballistic hop onto the remaining roof; ordinary gravity and collision apply.
	var flight_time:=.8
	rebound_velocity=(target-global_position)/flight_time
	rebound_velocity.y=gravity*flight_time*.5
	rebounding=true;rebound_launch=true

var fan_color:=""
var held_fan_color:=""
var equipped_fan_marker:Sprite3D
var neck_length:=0.0
func set_neck_length(length_:float) -> void:
	neck_length=length_
	sprite.set_meta("neck_length",length_)
	if is_instance_valid(equipped_fan_marker):equipped_fan_marker.position=camera.global_basis.y*(2.05+length_)
func _ready() -> void:
	super._ready()
	move_speed=WALK_METRES_PER_CONTACT*WALK_CONTACTS_PER_SECOND
	# Cross one 0.2 m grid seam without allowing climbs up full terrace walls.
	max_step_height=.24
	platform_floor_layers=4
	platform_wall_layers=0
	camera_relative_movement=true
	sprite.sprite_frames=PaintedTravelerFrames.create()
	sprite.modulate=Color.WHITE
	facing="southeast";sprite.play("idle_southeast")
	var shadow_plane:=PlaneMesh.new();shadow_plane.size=Vector2(.85,.60)
	shadow.mesh=shadow_plane
	var shadow_ink:=ShaderMaterial.new()
	shadow_ink.shader=preload("res://shaders/grid_player_shadow.gdshader")
	shadow_ink.render_priority=80
	shadow.material_override=shadow_ink
	shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_update_shadow()
	footprints=preload("res://scripts/grid_stage/footprints.gd").new()
	tower_root.add_child(footprints);footprints.configure(self)
func _physics_process(delta:float) -> void:
	if not held_fan_color.is_empty() or not fan_color.is_empty():sprite.speed_scale=0.0 if paused else 1.0
	if Input.get_vector("left","right","back","forward").length_squared()>.001:idle_elapsed=0
	var previous_position:=global_position
	var grounded_before:=is_on_floor()
	var fall_speed:=velocity.y
	super._physics_process(delta)
	footprints.advance(delta,global_position-previous_position)
	if paused or input_locked:
		BgmPlayer.set_walking(false)
		_update_shadow();return
	var travel:=global_position-previous_position;travel.y=0
	var walking:bool=grounded_before and is_on_floor() and not rebounding and knockback_time<=0 and Input.get_vector("left","right","back","forward").length_squared()>.001 and travel.length()>.001 and travel.length()<move_speed*delta*2.5+.04
	BgmPlayer.set_walking(walking)
	if not grounded_before and is_on_floor() and fall_speed<-.6:BgmPlayer.play_landing()
	if rebounding and not rebound_launch and is_on_floor() and velocity.y<=0:rebounding=false
	if Vector2(velocity.x,velocity.z).length()>.04 or not is_on_floor() or play_time>0 or land_time>0:
		idle_elapsed=0
	else:
		idle_elapsed+=delta
		if idle_elapsed>.35:facing="southeast";_play_directional_animation("idle")
func _update_walk_facing() -> void:
	# This stage is orthographic, even though its INPUT is camera-relative.
	# Do not inherit the shoulder-camera azimuth shortcut: foreshortening
	# changes screen-sector boundaries. Heading is actual LOCAL ground travel;
	# transform once to WORLD, then project onto screen right/down.
	visual_forward=(tower_root.global_basis*heading).normalized()
	var screen_travel:=Vector2(visual_forward.dot(camera.global_basis.x),-visual_forward.dot(camera.global_basis.y))
	facing=screen_direction(screen_travel,facing)
	if idle_elapsed>.35 and is_on_floor() and play_time<=0:facing="southeast"
func _update_shadow() -> void:
	if not is_instance_valid(shadow):return
	shadow.hide()
	if not sprite.is_visible_in_tree():return
	var query:=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.24,global_position+Vector3.DOWN*3.0,collision_mask,[get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():return
	var normal:Vector3=hit.normal.normalized()
	if normal.dot(Vector3.UP)<.5:return
	var height:=maxf(0.0,global_position.y-Vector3(hit.position).y)
	var spread:=lerpf(1.0,1.5,clampf(height/2.0,0,1))
	shadow.global_position=hit.position+normal*.018
	shadow.global_basis=Basis(Quaternion(Vector3.UP,normal)).scaled(Vector3.ONE*spread)
	shadow.material_override.set_shader_parameter("opacity",.28*(1.0-smoothstep(0.0,3.0,height)))
	shadow.show()

func _constrain_motion(_delta:float) -> void:
	if rebounding:
		velocity.x=rebound_velocity.x;velocity.z=rebound_velocity.z
		if rebound_launch:velocity.y=rebound_velocity.y;rebound_launch=false

func set_fan_gesture(color:String) -> void:
	if fan_color==color:return
	fan_color=color
	if color.is_empty():
		sprite.speed_scale=0.0 if paused else 1.0
		_play_directional_animation("idle")
	else:
		preload("res://scripts/grid_stage/fan_animation.gd").install(sprite.sprite_frames)
		sprite.offset=preload("res://scripts/grid_stage/fan_animation.gd").OFFSET
		sprite.speed_scale=0.0 if paused else 1.0;sprite.play("fan_"+color)

func set_held_fan(color:String) -> void:
	if held_fan_color==color:return
	held_fan_color=color;fan_color=""
	if not is_instance_valid(equipped_fan_marker):
		equipped_fan_marker=Sprite3D.new();equipped_fan_marker.name="EquippedFanMarker"
		equipped_fan_marker.set_meta("story_actor",true)
		equipped_fan_marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var marker_ink:=ShaderMaterial.new();marker_ink.shader=preload("res://shaders/grid_story_sprite.gdshader")
		marker_ink.render_priority=125;equipped_fan_marker.material_override=marker_ink
		add_child(equipped_fan_marker)
	equipped_fan_marker.visible=not color.is_empty()
	if not color.is_empty():
		equipped_fan_marker.texture=load("res://art/minhwa/fan_story/"+color+"_folding_v2.png")
		equipped_fan_marker.pixel_size=.52/equipped_fan_marker.texture.get_height()
		equipped_fan_marker.material_override.set_shader_parameter("illustration",equipped_fan_marker.texture)
		equipped_fan_marker.global_basis=camera.global_basis
		equipped_fan_marker.position=camera.global_basis.y*(2.05+neck_length)
		var previous_border:=equipped_fan_marker.get_node_or_null("PaperSticker")
		if previous_border!=null:
			equipped_fan_marker.remove_child(previous_border);previous_border.queue_free()
		equipped_fan_marker.set_meta("border_only",true)
		equipped_fan_marker.set_meta("border_width",1.4)
		equipped_fan_marker.set_meta("paper_color",Color("c93632") if color=="red" else Color("2868b5"))
		preload("res://scripts/grid_stage/sticker_sprite.gd").install(equipped_fan_marker,camera)
	if not color.is_empty():
		preload("res://scripts/grid_stage/fan_animation.gd").install(sprite.sprite_frames)
	_play_directional_animation("idle")

func _play_directional_animation(action:String) -> void:
	if not fan_color.is_empty():
		sprite.offset=preload("res://scripts/grid_stage/fan_animation.gd").OFFSET
		if sprite.animation!="fan_"+fan_color:sprite.play("fan_"+fan_color)
		return
	if not held_fan_color.is_empty() and action=="idle":
		sprite.offset=preload("res://scripts/grid_stage/fan_animation.gd").OFFSET
		if sprite.animation!="hold_"+held_fan_color:sprite.play("hold_"+held_fan_color)
		return
	sprite.offset=Vector2(0,232)
	super._play_directional_animation(action)
