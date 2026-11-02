extends Node3D
# Static ink-painted earth terraces, with distant mountains along the horizon.
var camera:Camera3D
var sheets:Array[Dictionary]=[]
var elapsed:float=0.0
func configure(view:Camera3D,stage_number:int) -> void:
	camera=view
	var rng:=RandomNumberGenerator.new()
	rng.seed=4417+stage_number*101
	# Small pale cloud banks recede behind the mountains, well above the land.
	for i:int in range(9):
		var distance_row:int=i/3
		var anchor:=Vector2(.08+(i%3)*.36+rng.randf_range(-.035,.035),.06+distance_row*.085)
		_add_sheet("res://art/dummys/DummyCloud_%d.png"%((i+stage_number)%8+1),"DistantEarthCloud%d"%i,anchor,rng.randf_range(.11,.19),92.0-distance_row*2.0,.28+distance_row*.10)
		sheets[-1].distant_cloud=true;sheets[-1].phase=rng.randf_range(0,TAU)
	# A low, uneven ridge around the upper third.
	for i:int in range(5):
		var index:int=(i+stage_number*2)%8+1
		_add_sheet("res://art/dummys/DummyMountain_%d.png"%index,"EarthMountain%d"%i,Vector2(.03+i*.24,.31+rng.randf_range(-.035,.025)),rng.randf_range(.22,.29),78.0+i*.02,.82)
	# Fill the sky behind the unchanged mountain silhouettes.
	for row:int in range(5):
		for column:int in range(6):
			var index:int=(row*3+column+stage_number)%8+1
			_add_sheet("res://art/dummys/DummyCloud_%d.png"%index,"SkyFill%d_%d"%[row,column],Vector2(-.22+column*.30+(row%2)*.10,-.04+row*.09),rng.randf_range(.34,.43),96.0-row*.6,rng.randf_range(.58,.76))
			sheets[-1].distant_cloud=true
	for i:int in range(3):
		_add_sheet("res://art/dummys/DummyCloud_%d.png"%((i*3+stage_number)%8+1),"PaleCloudVeil%d"%i,Vector2(-.10+i*.62,.11+i*.045),rng.randf_range(.58,.76),82.0+i*.2,.22)
		sheets[-1].distant_cloud=true;sheets[-1].large_cloud=true
	# Each ridge is 1.2 times the .44-wide shore waves, with deep staggered overlap.
	const RIDGE_WIDTH:float=.44*1.2
	for row:int in range(9):
		for column:int in range(5):
			_add_sheet("res://art/dummys/DummyRidgeGround_%d.png"%((row*3+column+stage_number+4)%8+1),"RidgeFill%d_%d"%[row,column],Vector2(-.03+column*.28,.48+row*.07),RIDGE_WIDTH,73.0-row*.1,1.0)
	var supports:Array[Dictionary]=[]
	for row:int in range(10):
		for column:int in range(5):
			var index:int=(row*3+column+stage_number)%8+1
			var anchor:=Vector2(-.16+column*.28+(row%2)*.07+rng.randf_range(-.016,.016),.43+row*.07+rng.randf_range(-.008,.008))
			_add_sheet("res://art/dummys/DummyRidgeGround_%d.png"%index,"EarthRidge%d_%d"%[row,column],anchor,RIDGE_WIDTH,68.0-row*.55,1.0)
			supports.append(sheets[-1])
	for i:int in range(6):
		var support:Dictionary=supports[(i*5+stage_number)%50]
		var anchor:Vector2=support.anchor
		anchor.x+=rng.randf_range(-.12,.12);anchor.y-=.018
		_add_sheet("res://art/dummys/DummyRock_%d.png"%((i+stage_number)%4+1),"EmbeddedRock%d"%i,anchor,rng.randf_range(.045,.075),float(support.depth)+.10,.94)
		sheets[-1].rock=true;sheets[-1].sway=.014 if i%3==0 else 0.0;sheets[-1].phase=rng.randf_range(0,TAU)
	# Only a thin strip of shore water remains at the bottom of the frame.
	for column:int in range(5):
		var anchor:=Vector2(-.06+column*.29,1.05)
		_add_sheet("res://art/dummys/DummyWave_%d.png"%((column+stage_number)%8+1),"EarthShore%d"%column,anchor,.44,54.0,.94)
		sheets[-1].shore=true;sheets[-1].phase=rng.randf_range(0,TAU)
	# Occasional wisps sit near three-quarter height, behind the architecture.
	for i:int in range(3):
		_add_sheet("res://art/dummys/DummyCloud_%d.png"%((i*2+stage_number)%8+1),"EarthWisp%d"%i,Vector2([.12,.88,.48][i],.75+rng.randf_range(-.035,.035)),rng.randf_range(.18,.25),48.0+i*.2,.52)
		sheets[-1].wisp=true;sheets[-1].phase=rng.randf_range(0,TAU)
	# Dense interleaved foreground covers tower bases without visible gaps.
	for row:int in range(5):
		for column:int in range(5):
			var anchor:=Vector2(-.10+column*.29+(row%2)*.08,.84+row*.052)
			_add_sheet("res://art/dummys/DummyRidgeGround_%d.png"%((row*3+column+stage_number)%8+1),"ForegroundRidge%d_%d"%[row,column],anchor,RIDGE_WIDTH,10.0-row*.4,1.0)
	_layout()
	get_viewport().size_changed.connect(_layout)
	var wildlife=preload("res://scripts/grid_stage/earth_wildlife.gd").new()
	wildlife.name="EarthWildlife"
	add_child(wildlife);wildlife.configure(camera,stage_number)
func _add_sheet(path:String,label:String,anchor:Vector2,width:float,depth:float,opacity:float) -> void:
	var source:Texture2D=load(path)
	var atlas:=AtlasTexture.new()
	atlas.atlas=source;atlas.region=source.get_image().get_used_rect();atlas.filter_clip=true
	var sprite:=Sprite3D.new()
	sprite.name=label;sprite.texture=atlas
	sprite.shaded=false;sprite.double_sided=true
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.modulate=Color(1,1,1,opacity)
	sprite.set_meta("screen_band",0)
	sprite.set_meta("earth_backdrop",true)
	if label.begins_with("EarthShore"):
		var ink:=ShaderMaterial.new()
		ink.shader=preload("res://shaders/grid_earth_inlet.gdshader")
		ink.set_shader_parameter("ink_texture",source)
		sprite.material_override=ink
	if label.contains("Ridge") or label.begins_with("EarthMountain"):
		var ridge_ink:=ShaderMaterial.new()
		ridge_ink.shader=preload("res://shaders/grid_ridge_depth.gdshader")
		ridge_ink.set_shader_parameter("ink_texture",source)
		ridge_ink.set_shader_parameter("haze_color",Color("d9cbb0"))
		ridge_ink.set_shader_parameter("haze_amount",clampf((depth-60.0)*.02,0.0,.38))
		ridge_ink.set_shader_parameter("opacity",opacity)
		ridge_ink.set_shader_parameter("soften_base",label.contains("Ridge"))
		var crop:Rect2=atlas.region
		var dimensions:Vector2=source.get_size()
		ridge_ink.set_shader_parameter("crop_uv",Vector4(crop.position.x/dimensions.x,crop.position.y/dimensions.y,crop.size.x/dimensions.x,crop.size.y/dimensions.y))
		var foreground:bool=label.begins_with("ForegroundRidge")
		ridge_ink.set_shader_parameter("foreground",foreground)
		if foreground:
			sprite.set_meta("screen_band",11)
			sprite.set_meta("foreground_ridge",true)
			ridge_ink.render_priority=25
		sprite.material_override=ridge_ink
	add_child(sprite)
	sheets.append({"visual":sprite,"anchor":anchor,"width":width,"depth":depth})
func _layout() -> void:
	var frame:Vector2=get_viewport().get_visible_rect().size
	if frame.y<=0:return
	var height:float=camera.size
	var width:float=height*frame.x/frame.y
	for entry:Dictionary in sheets:
		var sprite:Sprite3D=entry.visual
		var anchor:Vector2=entry.anchor
		if entry.get("shore",false):anchor.x+=sin(elapsed*.16+float(entry.phase))*.012
		if entry.get("distant_cloud",false):
			var margin:float=.50 if entry.get("large_cloud",false) else .24
			var speed:float=.0018 if entry.get("large_cloud",false) else .0035
			anchor.x=wrapf(anchor.x+elapsed*speed,-margin,1.0+margin)
		if entry.get("wisp",false):anchor.x+=sin(elapsed*.09+float(entry.phase))*.035
		sprite.global_basis=camera.global_basis*Basis(Vector3.BACK,float(entry.get("roll",0.0)))
		sprite.global_position=camera.global_position-camera.global_basis.z*float(entry.depth)+camera.global_basis.x*((anchor.x-.5)*width)+camera.global_basis.y*((.5-anchor.y)*height)
		sprite.pixel_size=width*float(entry.width)/float(sprite.texture.get_width())
		if entry.get("rock",false):
			var angle:float=sin(elapsed*.65+float(entry.phase))*float(entry.sway)
			sprite.global_basis=camera.global_basis*Basis(Vector3.BACK,float(entry.get("roll",0.0)))*Basis(Vector3.BACK,angle)
			# Pivot at the buried foot so a rocking stone never floats off its soil.
			sprite.global_position-=sprite.global_basis*Vector3(0,-sprite.texture.get_height()*sprite.pixel_size*.5,0)

func _process(delta:float) -> void:
	if not is_instance_valid(camera):return
	if not bool(camera.get_parent().get("paused")):
		elapsed+=delta
		_layout()