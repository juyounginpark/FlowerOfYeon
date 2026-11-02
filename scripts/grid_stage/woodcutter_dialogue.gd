extends Node3D
const SHEET=preload("res://art/minhwa/woodcutter_dialogue/idle.png")
const SPEECH_UI=preload("res://scripts/grid_stage/npc_speech_bubble.gd")
@export var lines:PackedStringArray=["곶감이 먹고 싶네.", "나무를 배어야하는데"]
@export_range(.1,30,.1) var display_seconds:=3.0
@export_range(.1,5,.1) var fade_seconds:=.8
@export var interaction_range:=1.65
var world:GridStageWorld
var npc:AnimatedSprite3D
var speaker:Sprite3D
var speaker_at_feet:=false
var frame_bounds:Array[Rect2i]=[]
var active:=false
var elapsed:=0.0
var idle_time:=0.0
var bubble:Control
var line:Label
var rng:=RandomNumberGenerator.new()

func configure(owner_world:GridStageWorld,speaker_sprite:Sprite3D=null) -> void:
	world=owner_world;speaker=speaker_sprite;position=Vector3(-2,0,1.35)
	if speaker_at_feet and is_instance_valid(speaker):global_position=speaker.global_position
	rng.randomize()
	if speaker==null:_create_actor()
	var overlay:=CanvasLayer.new();overlay.layer=8;add_child(overlay)
	bubble=preload("res://scripts/grid_stage/speech_bubble.gd").new()
	bubble.automatic=false;overlay.add_child(bubble)
	line=bubble.body
	bubble.hide()
func _create_actor() -> void:
	npc=AnimatedSprite3D.new();npc.name="MinhwaWoodcutter"
	npc.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	npc.shaded=false;npc.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	npc.set_meta("story_actor",true)
	var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/grid_traveler_slice.gdshader")
	ink.set_shader_parameter("frame_texture",SHEET);ink.render_priority=125
	npc.material_override=ink
	var frames:=SpriteFrames.new();frames.remove_animation("default");frames.add_animation("idle")
	frames.set_animation_loop("idle",true);frames.set_animation_speed("idle",4)
	var cell:=Vector2i(SHEET.get_size())/2
	var source:=SHEET.get_image()
	if source.is_compressed():source.decompress()
	for index in range(4):
		var rect:=Rect2i(Vector2i(index%2,index/2)*cell,cell)
		var atlas:=AtlasTexture.new();atlas.atlas=SHEET;atlas.region=Rect2(rect)
		frames.add_frame("idle",atlas)
		frame_bounds.append(source.get_region(rect).get_used_rect())
	npc.sprite_frames=frames
	add_child(npc)
	npc.frame_changed.connect(_align_frame)
	_align_frame()
	# Advance manually so pause and camera transitions have deterministic timing.
	npc.animation="idle"
	var body:=StaticBody3D.new();body.name="WoodcutterBody"
	body.collision_layer=1;body.collision_mask=2;add_child(body)
	var collision:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new()
	capsule.radius=.24;capsule.height=1.5
	collision.shape=capsule;collision.position.y=.75;body.add_child(collision)

func _align_frame() -> void:
	var bounds:Rect2i=frame_bounds[npc.frame]
	var cell:Vector2=SHEET.get_size()*.5
	npc.pixel_size=1.72/maxf(1,bounds.size.y)
	npc.offset=Vector2(cell.x*.5-(bounds.position.x+bounds.size.x*.5),bounds.end.y-cell.y*.5)

func can_interact() -> bool:
	if world.paused or world.completed or world.transition.active or world.player.input_locked:return false
	var distance:=world.player.global_position-global_position
	return Vector2(distance.x,distance.z).length()<=interaction_range and absf(distance.y)<.25 and world.player.is_on_floor()

func begin() -> bool:
	if not can_interact():return false
	# Consume E near a speaking NPC without restarting speech or triggering a lift.
	if active:return true
	if lines.is_empty():return false
	line.text=lines[rng.randi_range(0,lines.size()-1)]
	bubble.fit_to_text()
	active=true;elapsed=0;bubble.modulate.a=0;bubble.show()
	return true

func cancel() -> void:
	active=false;elapsed=0;bubble.hide()

func _process(delta:float) -> void:
	if world==null:return
	if is_instance_valid(speaker):
		global_position=speaker.global_position if speaker_at_feet else speaker.global_position-world.camera.global_basis.y*speaker.pixel_size*speaker.texture.get_height()*.5
	if not world.paused:
		idle_time+=delta
		var phase:=fmod(idle_time,2.4)
		if is_instance_valid(npc):
			npc.frame=0 if phase<1 else 1 if phase<1.6 else 2 if phase<1.74 else 3
		if active:
			elapsed+=delta
			bubble.modulate.a=minf(elapsed/.18,1.0)*(1.0-clampf((elapsed-display_seconds)/fade_seconds,0,1))
			if elapsed>=display_seconds+fade_seconds:cancel()
	var anchor:=global_position+Vector3.UP*1.92
	if is_instance_valid(speaker):anchor=speaker.global_position+world.camera.global_basis.y*speaker.pixel_size*speaker.texture.get_height()*(1.0 if speaker_at_feet else .5)
	var head:=world.camera.unproject_position(anchor)
	bubble.position=head-Vector2(bubble.size.x*.5,bubble.size.y)+Vector2(0,-minf(elapsed/.25,1)*5)
	bubble.visible=active and not world.camera.is_position_behind(global_position) and not world.transition.active
