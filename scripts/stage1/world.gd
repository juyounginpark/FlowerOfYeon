extends "res://scripts/stage2/world.gd"
## Keep Stage2's stage-gated features, then add Stage1 artwork only for runtime 4.
@export_group("Stage1 Artwork")
@export var tree_height := 4.86
@export var tree_left := Vector3(-4.8,0,2.4)
@export var tree_right := Vector3(4.9,0,2.4)
@export var woman_position := Vector3(3.8,0,2.4)
@export var swing_height := 4.1

func _update_interaction_icon(delta:float) -> void:
	if stage_number!=4 or not is_instance_valid(dialogue) or not dialogue.has_method("speech_anchor"):
		super._update_interaction_icon(delta);return
	interaction_clock+=delta
	interaction_icon.hide()
	if not bool(stage_root.get_meta("stage1_interaction_ready",false)):return
	if transition.active or completed or dialogue.active:return
	var anchor:Vector3=dialogue.speech_anchor()
	if camera.is_position_behind(anchor):return
	var point:=camera.unproject_position(anchor)-Vector2(22,52)
	point.y+=sin(interaction_clock*2.8)*3
	var frame:=get_viewport().get_visible_rect().size
	interaction_icon.position=Vector2(clampf(point.x,8,maxf(8,frame.x-52)),clampf(point.y,8,maxf(8,frame.y-52)))
	interaction_icon.show()

func load_stage(number: int, preserve_transition := false) -> void:
	await super.load_stage(number,preserve_transition)
	if stage_number != 4: return
	await _entry_build_step()
	# Remove only the peripheral botanical artwork, including its cut-paper copies.
	for child in stage_root.get_children():
		if child is GridFlowerBackdrop: child.free()
	var artwork := Node3D.new()
	artwork.name = "Stage1Artwork"
	stage_root.add_child(artwork)
	# Each purple-area sprite contains one complete rock, without rectangular cuts.
	_add_scenery(artwork,"UpperLeftRock","rock_left_complete_v2",Vector2(.22,.205),.29,11)
	_add_scenery(artwork,"LowerLeftRock","rock_left_complete_v2",Vector2(.123,.635),.33,11)
	_add_scenery(artwork,"RightRock","rock_right_complete_v2",Vector2(.79,.35),.45,11)
	var people = preload("res://scripts/stage1/people.gd").new()
	people.name = "DanoPeopleAnimation"
	artwork.add_child(people)
	people.configure(self,artwork)
	await _entry_build_step()
	var children := _add_scenery(artwork,"PeekingChildren","peeking_children_user_v2",Vector2(.125,.225),.145,11)
	children.flip_h = true
	children.render_priority = 85 # Behind the rock (90), above the distant water.
	var anchors := [Vector2(.72,.33),Vector2(.315,.56)]
	for i in range(2):
		var tree := Sprite3D.new()
		tree.name = "LeftTree" if i == 0 else "RightTree"
		tree.texture = preload("res://art/stage1/dano/main_tree.png") if i == 0 else preload("res://art/stage1/3.png")
		tree.pixel_size = tree_height/tree.texture.get_height() if i == 0 else 4.3/1130.0
		var root := Vector2(tree.texture.get_width()*.90,tree.texture.get_height()*.99) if i == 0 else Vector2(670,1130)
		tree.offset = Vector2(tree.texture.get_width()*.5-root.x,root.y-tree.texture.get_height()*.5)
		tree.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tree.shaded = false
		tree.no_depth_test = true
		tree.render_priority = 110
		tree.set_meta("screen_band",11)
		tree.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tree.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		artwork.add_child(tree)
		tree.position = tree_left if i == 0 else tree_right
		var depth := (camera.global_position-tree.global_position).dot(camera.global_basis.z)
		tree.global_position = camera.project_position(get_viewport().get_visible_rect().size*anchors[i],depth)
	await _entry_build_step()
	dialogue = preload("res://scripts/stage1/woman_dialogue.gd").new()
	dialogue.name = "Stage1WomanDialogue"
	dialogue.swing_height = swing_height
	artwork.add_child(dialogue)
	dialogue.configure(self)
	dialogue.position = woman_position
	# Keep the initial interaction on the pad; after falling it follows the body.
	var frame := get_viewport().get_visible_rect().size
	var foot := camera.unproject_position(dialogue.global_position)
	var horizontal := camera.unproject_position(dialogue.global_position+Vector3.RIGHT).x-foot.x
	dialogue.npc.position.x = (frame.x*.692-foot.x)/horizontal
	foot = camera.unproject_position(dialogue.global_position+Vector3.RIGHT*dialogue.npc.position.x)
	var vertical := camera.unproject_position(dialogue.global_position+Vector3.UP).y-foot.y
	dialogue.npc.position.y = (frame.y*.43-foot.y)/vertical
	dialogue.attach_swing(artwork.get_node("LeftTree"))
	await _entry_build_step()
	var bridge = preload("res://scripts/stage1/tree_bridge.gd").new()
	bridge.name = "Stage1TreeBridge"
	stage_root.add_child(bridge)
	bridge.setup(self,artwork.get_node("LeftTree"),artwork.get_node("RightTree"),dialogue)
	await _entry_build_step()
	var onboarding:=preload("res://scripts/stage1/onboarding.gd").new()
	onboarding.name="Stage1Onboarding";stage_root.add_child(onboarding);onboarding.configure(self,bridge)
	var rock_waves = preload("res://scripts/stage1/rock_waves.gd").new()
	rock_waves.name = "RockContactWaves"
	artwork.add_child(rock_waves)
	rock_waves.configure(self,artwork)

func _add_scenery(parent: Node3D, node_name: String, asset: String, center: Vector2, height_fraction: float, band: int) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = node_name
	sprite.texture = load("res://art/stage1/dano/"+asset+".png")
	sprite.pixel_size = camera.size*height_fraction/sprite.texture.get_height()
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.render_priority = 90 if asset.begins_with("rock_") else 108
	sprite.set_meta("screen_band",band)
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sprite)
	sprite.global_basis = camera.global_basis
	sprite.global_position = camera.project_position(get_viewport().get_visible_rect().size*center,40.0)
	return sprite
