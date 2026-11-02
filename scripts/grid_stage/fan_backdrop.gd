extends Node3D
# Transparent supplied fan decorations sit over the existing earth scenery.
var camera:Camera3D
var sheet:Sprite3D
func configure(view:Camera3D,_number:int) -> void:
	camera=view
	sheet=Sprite3D.new();sheet.texture=preload("res://art/minhwa/fan_story/fan_collage.png")
	sheet.shaded=false;sheet.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.set_meta("screen_band",0);add_child(sheet)
	_layout()
func _layout() -> void:
	var frame:=get_viewport().get_visible_rect().size
	sheet.global_basis=camera.global_basis
	sheet.global_position=camera.global_position-camera.global_basis.z*40
	sheet.pixel_size=maxf(camera.size/sheet.texture.get_height(),camera.size*frame.x/frame.y/sheet.texture.get_width())*1.05
func _process(_delta:float) -> void:
	if is_instance_valid(camera):_layout()
