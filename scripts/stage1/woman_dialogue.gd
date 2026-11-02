extends "res://scripts/grid_stage/woodcutter_dialogue.gd"
signal first_player_interaction
var player_interacted:=false
## Supply Stage1's actor and text; shared E range, UI, timer and controls are unchanged.
const WOMAN = preload("res://art/stage1/dano/swing_woman_user_v2.png")
const FRAME_PADDING := Vector2(120,48)
const FRAME_OFFSETS := [Vector2(0,18),Vector2(71,13),Vector2(100,0),Vector2(71,-13),Vector2(0,-18),Vector2(-71,-13),Vector2(-100,0),Vector2(-71,13)]
const FOOT_ANCHOR := Vector2(760,1699)
const SWING_HEAD:=Vector2(350,355)
const FALL_HEADS:=[Vector2(166,90),Vector2(198,116),Vector2(130,130),Vector2(166,64),Vector2(153,80),Vector2(144,119),Vector2(136,100),Vector2(162,109)]
const FALL_SHEET = preload("res://art/stage1/dano/swing_woman_fall_8frames.png")
var swing_height := 3.05
var scripted_warning := false
var falling := false
var landed := false
var landing_y := 0.0
var fall_time := 0.0
var landing_time := 0.0
var fall_body
var fall_ink: ShaderMaterial
var fall_atlas: Dictionary
var swing_time := 0.0
var rope_tree: Sprite3D
var ropes: MeshInstance3D
var rope_mesh: ImmediateMesh
var rope_state: Array = []

func warn_wrong_tree() -> void:
	cancel()
	var previous := lines
	lines = PackedStringArray(["이쪽 말고 반대쪽 나무"])
	scripted_warning = true
	begin()
	scripted_warning = false
	lines = previous

func can_interact() -> bool:
	if falling:return false
	if scripted_warning:
		return not world.paused and not world.transition.active
	if not bool(world.stage_root.get_meta("stage1_interaction_ready",false)):return false
	return super.can_interact()

func begin() -> bool:
	var was_active:=active
	var accepted:=super.begin()
	if accepted and not was_active and not scripted_warning and not player_interacted:
		player_interacted=true;first_player_interaction.emit()
	return accepted

func drop_to_platform() -> void:
	if falling or landed: return
	cancel()
	falling = true
	fall_time = 0.0
	var origin := npc.global_position
	fall_body = preload("res://scripts/stage1/swing_fall_body.gd").new()
	fall_body.name = "FallingSwingWoman"
	fall_body.world = world
	fall_body.collision_layer = 2
	fall_body.collision_mask = 5
	fall_body.contact_monitor = true
	fall_body.max_contacts_reported = 4
	fall_body.axis_lock_angular_x = true
	fall_body.axis_lock_angular_y = true
	fall_body.axis_lock_angular_z = true
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .28
	capsule.height = 2.0
	collision.shape = capsule
	collision.position.y = 1.0
	fall_body.add_child(collision)
	world.stage_root.add_child(fall_body)
	fall_body.global_position = origin
	var toward_pad := global_position-origin
	toward_pad.y = 0
	fall_body.linear_velocity = toward_pad.normalized()*.8
	fall_body.landed.connect(_on_fall_landed)
	npc.reparent(fall_body,false)
	npc.position = Vector3.ZERO
	npc.animation = "fall"
	npc.pixel_size = swing_height*.82/float(fall_atlas.reference_height)
	npc.scale = Vector3.ONE
	npc.no_depth_test = false
	npc.set_meta("story_actor",true)
	# Foreground only while falling; cut wood retains terrain occlusion.
	npc.set_meta("paper_foreground",true)
	fall_ink = ShaderMaterial.new()
	fall_ink.shader = preload("res://scripts/stage1/swing_fall_ink.gdshader")
	fall_ink.render_priority = 115
	fall_ink.set_shader_parameter("illustration",FALL_SHEET)
	npc.material_override = fall_ink
	ropes.hide()
	_set_fall_pose(0)

func _on_fall_landed() -> void:
	falling = false
	landed = true
	landing_time = 0.0
	_set_fall_pose(5)
	global_position=fall_body.global_position
	lines=PackedStringArray(["나빠"])
	npc.remove_meta("paper_foreground")
	npc.material_override=fall_ink

func _set_fall_pose(index: int) -> void:
	npc.frame = index
	var frame: Texture2D = npc.sprite_frames.get_frame_texture("fall",index)
	npc.offset = Vector2(0,float(fall_atlas.frames[index].foot_y)-frame.get_height()*.5)

func _process(delta: float) -> void:
	if (falling or landed) and is_instance_valid(fall_body):
		global_position=fall_body.global_position
	super._process(delta)
	if falling or landed:
		if not world.paused and not world.transition.active:
			if falling: fall_time += delta
			else: landing_time += delta
		npc.animation = "fall"
		_set_fall_pose(mini(4,int(fall_time*8.0)) if falling else mini(7,5+int(landing_time*7.0)))
		_place_head_bubble()
		return
	if not world.paused and not world.transition.active and not falling and not landed:
		swing_time += delta
	npc.frame = 0 if falling or landed else int(floor(swing_time*4.0))%8
	# A small perspective change makes the eight poses move fore and aft.
	npc.scale = Vector3.ONE if falling or landed else Vector3.ONE*(1.0+0.025*sin(npc.frame*TAU/8.0))
	_update_ropes()
	_place_head_bubble()

func speech_anchor() -> Vector3:
	# Use the painted head, not the sprite's top (which includes long ropes/hands).
	var frame:AtlasTexture=npc.sprite_frames.get_frame_texture(npc.animation,npc.frame)
	var pixel:Vector2=FALL_HEADS[npc.frame] if falling or landed else SWING_HEAD
	pixel+=frame.margin.position
	var offset:Vector2=pixel-frame.get_size()*.5
	offset=Vector2(offset.x,-offset.y)+npc.offset
	return npc.global_position+world.camera.global_basis.x*offset.x*npc.pixel_size*npc.scale.x+world.camera.global_basis.y*(offset.y*npc.pixel_size*npc.scale.y+.08)

func _place_head_bubble() -> void:
	if active:bubble.place(world.camera.unproject_position(speech_anchor()))

func configure(owner_world: GridStageWorld, speaker_sprite: Sprite3D = null) -> void:
	lines = PackedStringArray(["나무를 잘라서 다리를 만들어"])
	super.configure(owner_world,speaker_sprite)

func _create_actor() -> void:
	npc = AnimatedSprite3D.new()
	npc.name = "SwingWoman"
	var frames := SpriteFrames.new()
	# Eight distinct atlas margins move the exact user pixels without eight copies.
	for shift: Vector2 in FRAME_OFFSETS:
		var frame := AtlasTexture.new()
		frame.atlas = WOMAN
		frame.region = Rect2(Vector2.ZERO,WOMAN.get_size())
		frame.margin = Rect2(FRAME_PADDING+shift,FRAME_PADDING*2)
		frame.filter_clip = true
		frames.add_frame("default",frame)
	frames.set_animation_speed("default",4.0)
	frames.set_animation_loop("default",true)
	frames.add_animation("fall")
	frames.set_animation_loop("fall",false)
	frames.set_animation_speed("fall",8.0)
	fall_atlas = JSON.parse_string(FileAccess.get_file_as_string("res://art/stage1/dano/swing-fall-atlas.json"))
	for pose: Dictionary in fall_atlas.frames:
		var frame := AtlasTexture.new()
		frame.atlas = FALL_SHEET
		frame.region = Rect2(pose.region[0],pose.region[1],pose.region[2],pose.region[3])
		frame.margin = Rect2(pose.margin[0],pose.margin[1],pose.margin[2],pose.margin[3])
		frame.filter_clip = true
		frames.add_frame("fall",frame)
	npc.sprite_frames = frames
	npc.pixel_size = swing_height/FOOT_ANCHOR.y
	# Ground interaction anchor follows the woman's feet, never the long ropes.
	var canvas_size := WOMAN.get_size()+FRAME_PADDING*2
	npc.offset = Vector2(canvas_size.x*.5-FOOT_ANCHOR.x-FRAME_PADDING.x,FOOT_ANCHOR.y+FRAME_PADDING.y-canvas_size.y*.5)
	var image := WOMAN.get_image()
	if image.is_compressed(): image.decompress()
	landing_y = (image.get_used_rect().end.y+FRAME_PADDING.y+FRAME_OFFSETS[0].y-canvas_size.y*.5-npc.offset.y)*npc.pixel_size
	# Suspend the swing above the roof, with its painted bottom used for landing.
	npc.position.y = landing_y + .35
	npc.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	npc.shaded = false
	npc.no_depth_test = true
	npc.render_priority = 115
	npc.set_meta("screen_band",11)
	npc.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	npc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(npc)
	rope_mesh = ImmediateMesh.new()
	ropes = MeshInstance3D.new()
	ropes.name = "SwingRopeExtensions"
	ropes.mesh = rope_mesh
	var rope_ink := StandardMaterial3D.new()
	rope_ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rope_ink.vertex_color_use_as_albedo = true
	rope_ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rope_ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	rope_ink.no_depth_test = true
	rope_ink.render_priority = 114
	ropes.material_override = rope_ink
	ropes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ropes.set_meta("slice_whole",true)
	ropes.set_meta("screen_band",11)
	add_child(ropes)

func attach_swing(tree: Sprite3D) -> void:
	rope_tree = tree
	_update_ropes()

func _update_ropes() -> void:
	if falling or landed or not is_instance_valid(rope_tree) or not rope_tree.is_visible_in_tree():
		ropes.hide()
		return
	var camera := world.camera
	var state: Array = [npc.frame,npc.global_transform,camera.global_basis,rope_tree.global_transform]
	if state == rope_state: return
	rope_state = state
	ropes.show()
	rope_mesh.clear_surfaces()
	rope_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var branches := [Vector2(1040,124),Vector2(1110,148)]
	var rope_tops := [Vector2(325,0),Vector2(576,0)]
	var texture: AtlasTexture = npc.sprite_frames.get_frame_texture("default",npc.frame)
	for i in range(2):
		var tree_pixel: Vector2 = branches[i]-rope_tree.texture.get_size()*.5
		tree_pixel.y = -tree_pixel.y
		tree_pixel += rope_tree.offset
		var a: Vector3 = rope_tree.global_position+camera.global_basis*Vector3(tree_pixel.x,tree_pixel.y,0)*rope_tree.pixel_size
		var pixel: Vector2 = rope_tops[i]+texture.margin.position-texture.get_size()*.5
		pixel.y = -pixel.y
		pixel += npc.offset
		var b: Vector3 = npc.global_position+camera.global_basis*Vector3(pixel.x,pixel.y,0)*npc.pixel_size*npc.scale.x
		# Dark edges and a light center match the supplied twisted rope artwork.
		_rope_strip(a,b,0.040,Color("725236"))
		_rope_strip(a,b,0.018,Color("c5a17a"))
	rope_mesh.surface_end()

func _rope_strip(a: Vector3, b: Vector3, width: float, tint: Color) -> void:
	var side := world.camera.global_basis.x*width*.5
	var points := [a-side,a+side,b+side,b-side]
	for index in [0,1,2,0,2,3]:
		rope_mesh.surface_set_color(tint)
		rope_mesh.surface_add_vertex(ropes.to_local(points[index]))
