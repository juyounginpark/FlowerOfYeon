extends Node
# Stage3's sea puzzle is owned by GridStageWorld; this adapter retains its NPC.
var world:GridStageWorld
@export_group("Stage3 Character 9")
@export var stage3_character9_corner_offset:=Vector3(.2,0,.2)
@export_range(.2,5,.05) var stage3_character9_height:=1.65

func _ready() -> void:
	world=get_parent() as GridStageWorld
	world.stage_loaded.connect(_on_stage_loaded)
	if is_instance_valid(world.stage_root):_on_stage_loaded(world.stage_number)

func _on_stage_loaded(number:int) -> void:
	if number==6:_add_character9()

func _add_character9() -> void:
	var character := Sprite3D.new()
	character.name = "Stage3Character9"
	character.texture = preload("res://art/stage3/9.png")
	character.pixel_size = stage3_character9_height / 1510.0
	# Sole center in the original 1024x1536 canvas; keep the full source artwork.
	character.offset = Vector2(-78,752)
	character.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	character.shaded = false
	character.no_depth_test = true
	character.render_priority = 114
	character.set_meta("screen_band",11)
	character.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	character.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var platform: Array = world.stage_data.low[0]
	character.position = Vector3(platform[0].x,platform[1].y,platform[0].z)*StageCells.UNIT + stage3_character9_corner_offset
	world.stage_root.add_child(character)
	var speech := preload("res://scripts/stage3/character9_dialogue.gd").new()
	speech.name = "Stage3Character9Dialogue"
	world.stage_root.add_child(speech)
	speech.configure(world)
	speech.position = character.position
	world.dialogue = speech
