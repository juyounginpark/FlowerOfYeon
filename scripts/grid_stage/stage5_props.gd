extends Node3D
# Shared Stage5 prop layout; stage5_story.gd adds the interactions.
const ART:="res://stages/5-손톱/"
const RAT_SCALE:=1.6

func configure(world:GridStageWorld) -> void:
	var camera:Camera3D=world.camera
	# Most of the enlarged inn sits beyond the right edge; its roof and cat remain visible.
	var frame_size:=get_viewport().get_visible_rect().size
	var inn_base:Vector3=camera.project_position(frame_size*Vector2(1.04,.88),20.0)
	var inn:=_picture("Inn",load(ART+"주막-v2.png"),inn_base,9.0,camera)
	_ground_picture(inn,camera)
	_picture("Cat",load(ART+"고양이.png"),camera.project_position(frame_size*Vector2(.87,.365),20.0),1.25,camera)
	_picture("Beauty",load(ART+"미인.png"),Vector3(-3.8,3.6,-4.7),2.15,camera)
	_picture("Uncle",load(ART+"주막 옆 아저씨.png"),camera.project_position(frame_size*Vector2(.80,.88),20.0),1.4,camera)
	# The supplied 8-by-3 sheet already depicts the player with a rat tail.
	var sheet:Texture2D=load(ART+"손톱먹은쥐.png")
	var frame:=AtlasTexture.new();frame.atlas=sheet
	frame.region=Rect2(0,0,sheet.get_width()/8.0,sheet.get_height()/3.0)
	var impostor:=_picture("Impostor",frame,Vector3(.1,1.8,-1.4),1.5*RAT_SCALE,camera)
	_add_rat_border(impostor,camera)
	# The revealed mouse shares the impostor's place, hidden until its reveal.
	var mouse:Sprite3D=_picture("Mouse",load(ART+"쥐original.png"),Vector3(.1,1.8,-1.4),.6*RAT_SCALE,camera)
	_add_rat_border(mouse,camera)
	mouse.hide()

func _add_rat_border(sprite:Sprite3D,camera:Camera3D) -> void:
	sprite.set_meta("border_only",true)
	sprite.set_meta("paper_color",Color("c93632"))
	sprite.set_meta("border_width",3.2)
	preload("res://scripts/grid_stage/sticker_sprite.gd").install(sprite,camera)
	var effect= sprite.get_node("PaperSticker")
	for layer:MeshInstance3D in effect.layers:
		layer.set_meta("paper_foreground",true)
		layer.material_override.no_depth_test=true

func _ground_picture(sprite:Sprite3D,camera:Camera3D) -> void:
	# Reuse the local earth sheet's depth so its actual ink silhouette covers
	# the base. A late screen band would still draw above these ground sheets.
	var earth=camera.get_parent().stage_root.get_node("EarthBackdrop")
	var frame:=get_viewport().get_visible_rect().size
	var foot:Vector3=sprite.global_position-camera.global_basis.y*sprite.texture.get_height()*sprite.pixel_size*.5
	var anchor:Vector2=camera.unproject_position(foot)/frame
	var nearest:=INF;var ground_depth:=55.0
	for entry:Dictionary in earth.sheets:
		if not str(entry.visual.name).begins_with("EarthRidge"):continue
		var distance:float=((Vector2(entry.anchor)-anchor)*Vector2(frame.x/frame.y,1)).length_squared()
		if distance<nearest:nearest=distance;ground_depth=float(entry.depth)
	var depth:float=(camera.global_position-sprite.global_position).dot(camera.global_basis.z)
	sprite.global_position-=camera.global_basis.z*(ground_depth+.3-depth)
	sprite.set_meta("background_depth",ground_depth+.3)
	sprite.set_meta("paper_grounded",true);sprite.set_meta("paper_foreground",false);sprite.set_meta("screen_band",0)
	sprite.material_override.shader=preload("res://shaders/grid_paper_grounded.gdshader")
	sprite.material_override.render_priority=0

func _picture(label:String,texture:Texture2D,base:Vector3,height:float,camera:Camera3D) -> Sprite3D:
	# Remove transparent margins so height and the bottom anchor follow the art.
	var source:Image=texture.get_image()
	var cropped:Image=source.get_region(source.get_used_rect())
	var sprite:=Sprite3D.new()
	sprite.name=label;sprite.texture=ImageTexture.create_from_image(cropped)
	sprite.set_meta("source_crop",source.get_used_rect())
	sprite.pixel_size=height/float(cropped.get_height())
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.set_meta("paper_foreground",true)
	var ink:=ShaderMaterial.new()
	ink.shader=preload("res://shaders/grid_paper_foreground.gdshader")
	ink.render_priority=125 if label in ["Cat","Beauty","Uncle","Impostor","Mouse"] else 115
	ink.set_shader_parameter("illustration",sprite.texture);sprite.material_override=ink
	add_child(sprite)
	sprite.global_basis=camera.global_basis
	sprite.position=base+camera.global_basis.y*(height*.5)
	return sprite
