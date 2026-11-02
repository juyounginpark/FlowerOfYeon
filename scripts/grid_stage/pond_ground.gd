extends Node3D
# A few stationary slivers of land between the existing moving wave bands.
var camera:Camera3D
var layers:Node
var patches:Array[Dictionary]=[]
func configure(view:Camera3D,controller:Node,stage_number:int) -> void:
	camera=view;layers=controller
	var anchors:Array[Vector2]=[Vector2(.23,.33),Vector2(.78,.49),Vector2(.17,.66),Vector2(.74,.82)]
	for i:int in range(4):
		var source:Texture2D=load("res://art/dummys/DummyGround_%d.png"%((i+stage_number)%4+1))
		var atlas:=AtlasTexture.new();atlas.atlas=source;atlas.region=source.get_image().get_used_rect();atlas.filter_clip=true
		var patch:=Sprite3D.new();patch.name="PondGround%d"%i;patch.texture=atlas
		patch.shaded=false;patch.double_sided=true
		patch.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
		patch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var anchor:Vector2=anchors[i]
		anchor.x+=float(stage_number-2)*.035
		var band:int=clampi(floori(anchor.y*12),0,11)
		patch.set_meta("screen_band",band)
		patch.set_meta("pond_ground",true)
		add_child(patch)
		patches.append({"visual":patch,"anchor":anchor,"band":band,"width":.17+(i%2)*.035})
	_layout()
func _process(_delta:float) -> void:_layout()
func _layout() -> void:
	var frame:Vector2=get_viewport().get_visible_rect().size
	if frame.y<=0:return
	var height:float=camera.size
	var width:float=height*frame.x/frame.y
	for entry:Dictionary in patches:
		var patch:Sprite3D=entry.visual
		var anchor:Vector2=entry.anchor
		var depth:float=layers.depth_for_band("row_%d"%entry.band)-.18
		patch.global_basis=camera.global_basis
		patch.global_position=camera.global_position-camera.global_basis.z*depth+camera.global_basis.x*((anchor.x-.5)*width)+camera.global_basis.y*((.5-anchor.y)*height)
		patch.pixel_size=width*float(entry.width)/float(patch.texture.get_width())
