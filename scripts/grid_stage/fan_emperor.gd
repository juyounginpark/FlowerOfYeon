extends Node3D
const ASCENT_SPEED := 3.2
# Separate inserted scene/World3D. The original stage is kept intact below its viewport.
var camera:Camera3D
var portrait:Sprite3D
var brows:Node3D
var brow_cards:Array[Sprite3D]=[]
var eye_positions:Array[Vector3]=[]
var platform:Node3D
var traveler:AnimatedSprite3D
var speech:Label
var first_dialogue:Panel
var dialogue_count:=0
var dismiss_frame:=-10
var caption:Label
var sky:Node3D
var paused:=false
var touched:=false
var height:=0.0
var face_position:=Vector3.ZERO
var camera_origin:=Vector3.ZERO
var frame_size:=Vector2(1280,720)

func configure(source_camera:Camera3D,source_lift:AnimatableBody3D,source_player:WorldPilgrim) -> void:
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("eee1c7")
	add_child(environment)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=source_camera.size
	camera.cull_mask=1;camera.current=true;add_child(camera)
	camera.global_basis=source_camera.global_basis;camera_origin=camera.global_basis.z*25+camera.global_basis.y*1.3
	camera.position=camera_origin
	# Reuse Stage8's complete cloud and mountain arrangement, including its seed/palette.
	sky=preload("res://scripts/grid_stage/sky_backdrop.gd").new();sky.name="Stage8Backdrop"
	add_child(sky);sky.configure(camera,8)
	# Stage8's foreground veils become background here so the face and reaction stay clear.
	for entry:Dictionary in sky.clouds:
		entry.depth=float(entry.depth)+60.0
		var cloud:Sprite3D=entry.visual
		cloud.no_depth_test=false;cloud.render_priority=-10
		if cloud.material_override is ShaderMaterial:cloud.material_override.render_priority=-10
	for entry:Dictionary in sky.mountains:entry.depth=float(entry.depth)+60.0
	sky._layout()
	portrait=_picture(preload("res://art/minhwa/fan_story/emperor.png"),27.0)
	portrait.position=camera.global_basis.x*1.8+camera.global_basis.y*10.5-camera.global_basis.z*.35
	# Eye coordinates measured on the original zip portrait, after the preserved (23,8) crop.
	for point:Vector2 in [Vector2(164,100),Vector2(199,98)]:
		eye_positions.append(portrait.position+camera.global_basis.x*(point.x-190)*portrait.pixel_size+camera.global_basis.y*(355-point.y)*portrait.pixel_size)
	face_position=(eye_positions[0]+eye_positions[1])*.5
	_create_brows()
	platform=source_lift.duplicate();platform.name="AscendingFanPlatform";add_child(platform)
	platform.position=camera.global_basis.x*1.1
	platform.collision_layer=0;platform.collision_mask=0
	traveler=source_player.sprite.duplicate();traveler.name="EmperorTraveler";platform.add_child(traveler)
	traveler.position=Vector3.ZERO;traveler.visible=true;traveler.material_override=null
	traveler.layers=1
	preload("res://scripts/grid_stage/fan_animation.gd").install(traveler.sprite_frames)
	traveler.offset=preload("res://scripts/grid_stage/fan_animation.gd").OFFSET
	traveler.speed_scale=1.0;traveler.play("fan_red")
	var ui:=CanvasLayer.new();add_child(ui)
	var font:Font=preload("res://art/fonts/HS-Winter-Snowflake.ttf")
	speech=Label.new();speech.add_theme_font_override("font",font);speech.add_theme_font_size_override("font_size",32)
	speech.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	speech.text="옥황상제\n네 놈의 코가 하늘을 찌르는구나!"
	speech.add_theme_color_override("font_color",Color("392e23"))
	var paper:=StyleBoxFlat.new();paper.bg_color=Color("fff5df");paper.set_corner_radius_all(14)
	paper.content_margin_left=20;paper.content_margin_right=20;paper.content_margin_top=14;paper.content_margin_bottom=14
	speech.add_theme_stylebox_override("normal",paper);ui.add_child(speech);speech.hide()
	caption=Label.new();caption.hide();caption.add_theme_font_override("font",font);caption.add_theme_font_size_override("font_size",18)
	caption.add_theme_color_override("font_color",Color("514a3b"));caption.text="옥황상제의 하늘  ·  Esc 일시정지  ·  Home 재시작";ui.add_child(caption)
	first_dialogue=preload("res://scripts/grid_stage/fan_dialogue.gd").new();ui.add_child(first_dialogue)
	first_dialogue.dismissed.connect(_on_first_dialogue_closed)
	_layout()

func _create_brows() -> void:
	brows=Node3D.new();brows.name="AngryEyebrows";add_child(brows)
	brows.set_meta("source_texture","res://art/minhwa/fan_story/emperor_brows.png")
	var image:=preload("res://art/minhwa/fan_story/emperor_brows.png").get_image()
	var half:=image.get_width()/2
	for index in range(2):
		var isolated:=image.get_region(Rect2i(index*half,0,half,image.get_height()))
		var used:=isolated.get_used_rect()
		var card:=_picture(ImageTexture.create_from_image(isolated),1.05)
		card.reparent(brows,true);card.name="LeftBrow" if index==0 else "RightBrow"
		card.global_basis=camera.global_basis*Basis.from_scale(Vector3(1,1.35,1))
		# Centre each eyebrow on its own eye, with its lowest ink just above the eyelid.
		card.position=eye_positions[index]-camera.global_basis.x*(used.get_center().x-half*.5)*card.pixel_size+camera.global_basis.y*((used.end.y-image.get_height()*.5)*card.pixel_size*1.35+.06)+camera.global_basis.z*.06
		card.material_override.render_priority=120;brow_cards.append(card)
	brows.hide()

func _picture(texture:Texture2D,size:float) -> Sprite3D:
	var sprite:=Sprite3D.new();sprite.texture=texture;sprite.pixel_size=size/texture.get_height()
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/grid_story_sprite.gdshader")
	ink.set_shader_parameter("illustration",texture);ink.render_priority=115;sprite.material_override=ink
	add_child(sprite);sprite.global_basis=camera.global_basis
	return sprite

func rider_head() -> Vector3:
	return platform.position+camera.global_basis.y*1.35

func advance(delta:float) -> void:
	if not touched:
		height+=delta*ASCENT_SPEED
		platform.position=camera.global_basis.x*1.1+camera.global_basis.y*height
		if rider_head().distance_to(face_position)<1.0:
			touched=true;traveler.pause()
	camera.position=camera_origin+camera.global_basis.y*height
	_layout()

func show_dialogue(first:=true) -> void:
	dialogue_count+=1;brows.show()
	if first:
		speech.hide()
		var art:=AtlasTexture.new();art.atlas=portrait.texture
		art.region=Rect2(0,0,portrait.texture.get_width(),portrait.texture.get_height()*.56)
		first_dialogue.present("옥황상제","네 놈의 코가 하늘을 찌르는구나!",art)
	else:
		first_dialogue.hide();speech.show()
	_layout()

func _on_first_dialogue_closed() -> void:
	dismiss_frame=Engine.get_process_frames()
	caption.text="옥황상제의 하늘  ·  E 다시 대화  ·  Esc 일시정지  ·  Home 재시작"

func resize_view(frame:Vector2) -> void:
	frame_size=frame
	traveler.speed_scale=0.0 if paused else 1.0
	first_dialogue.blocked=paused
	_layout()

func _layout() -> void:
	caption.position=Vector2(30,28)
	# The speech remains next to the face rather than covering it.
	speech.add_theme_font_size_override("font_size",clampi(roundi(frame_size.x/1280.0*32),26,36))
	speech.custom_minimum_size.x=minf(540,frame_size.x*.42);speech.reset_size()
	speech.position=Vector2(30,frame_size.y*.23)
