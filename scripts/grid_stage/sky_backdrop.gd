extends Node3D
# Painted clouds use the same screen-band compositor as the water collage.
var camera:Camera3D
var world:Node
var clouds:Array[Dictionary]=[]
var elapsed:float=0.0
var storm := false
var storm_mix := 0.0
var storm_bases: Array[Color] = []
var mountains:Array[Dictionary]=[]
const NIGHT_CLOUDS:=[Color("171727"),Color("49335f"),Color("294c80"),Color("29233e"),Color("3c5790")]
func configure(view:Camera3D,stage_number:int) -> void:
	camera=view;world=camera.get_parent()
	var rng:=RandomNumberGenerator.new()
	rng.seed=9731+stage_number*701
	# Keep the existing veils, plus a staggered 8 x 8 distant cloud bed.
	for i:int in range(94):
		var fill_cloud:bool=i>=30
		var cloud:=Sprite3D.new()
		cloud.name="DriftingCloud%d"%(i+1)
		var texture_index:int=(i+(3 if stage_number==8 else 0))%8+1
		cloud.texture=load("res://art/dummys/DummyCloud_%d.png"%texture_index)
		cloud.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
		cloud.shaded=false;cloud.double_sided=true
		cloud.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Random size groups keep a dense background plus six large foreground veils.
		var multiplier:float=rng.randf_range(1.55,2.0) if i%5==0 else rng.randf_range(.8,1.5)
		if fill_cloud:multiplier=rng.randf_range(.95,1.25)
		var size_t:float=inverse_lerp(.8,2.0,multiplier)
		var opacity:float=lerpf(.94,.16,size_t)
		var cloud_layer:String="front" if multiplier>=1.55 else "middle" if multiplier>=1.18 else "back"
		if fill_cloud:cloud_layer="back"
		# Both background depths composite before map bands; only veils overlay them.
		var layer:int=11 if cloud_layer=="front" else 0
		var depth:float=9.0 if layer==11 else 42.0 if cloud_layer=="middle" else 65.0
		cloud.set_meta("screen_band",layer)
		cloud.set_meta("cloud_layer",cloud_layer)
		# Translucent veils always composite over the column-cover cloud rows.
		cloud.render_priority=127 if layer==11 else -10
		cloud.no_depth_test=layer==11
		cloud.set_meta("sky_cloud",true)
		cloud.modulate=Color(1,1,1,opacity)
		if stage_number==8:
			cloud.modulate=NIGHT_CLOUDS[i%NIGHT_CLOUDS.size()]
			cloud.modulate.a=opacity
		add_child(cloud)
		var row:int=i/5
		var anchor:=Vector2(-.35+(i%5)*.36+(row%2)*.12,-.06+row*.22)
		if fill_cloud:
			var fill_index:int=i-30
			row=fill_index/8
			anchor=Vector2(-.4+(fill_index%8)*.225+(row%2)*.1125,-.08+row*.165)
			depth=72.0
		if cloud_layer=="front":anchor.x=rng.randf_range(.15,.85)
		if stage_number==8:anchor.x=1.0-anchor.x
		clouds.append({"visual":cloud,"anchor":anchor,"width":.48*multiplier,"size_multiplier":multiplier,"speed":(.008+row*.0018)*(1.35 if layer==11 else 1.0),"phase":rng.randf_range(0,TAU),"depth":depth+i*.025})
	_create_mountains(stage_number)
	_create_foreground_clouds(stage_number)
	_layout()
func _create_foreground_clouds(stage_number:int) -> void:
	# Overlapping rows remain dense while the clouds drift across the frame.
	for row:int in range(4):
		for col:int in range(7):
			var cloud:=Sprite3D.new()
			cloud.name="ColumnCoverCloud%d_%d"%[row,col]
			var source:Texture2D=load("res://art/dummys/DummyCloud_%d.png"%((row*3+col+stage_number)%8+1))
			var cropped:=AtlasTexture.new();cropped.atlas=source
			cropped.region=source.get_image().get_used_rect()
			cloud.texture=cropped
			cloud.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var ink:=ShaderMaterial.new()
			ink.shader=preload("res://shaders/grid_sky_foreground.gdshader")
			ink.set_shader_parameter("cloud_image",source)
			if stage_number==8:ink.set_shader_parameter("ink_tint",NIGHT_CLOUDS[(row*3+col)%NIGHT_CLOUDS.size()])
			ink.render_priority=30+row
			cloud.material_override=ink
			cloud.set_meta("screen_band",11)
			cloud.set_meta("cloud_layer","column_cover")
			add_child(cloud)
			clouds.append({"visual":cloud,"anchor":Vector2(-.4+col*.30+(row%2)*.15,.84+row*.105),"width":.54,"speed":.004+row*.001,"phase":float(col+row),"depth":5.0-row*.3})
func _process(delta:float) -> void:
	if not is_instance_valid(camera):return
	if not bool(world.get("paused")):elapsed+=delta
	if storm and not bool(world.get("paused")):
		storm_mix=minf(1.0,storm_mix+delta/1.8)
		for index in range(clouds.size()):
			var cloud: Sprite3D = clouds[index].visual
			var blue: Color = NIGHT_CLOUDS[index%NIGHT_CLOUDS.size()]
			if cloud.material_override is ShaderMaterial:
				cloud.material_override.set_shader_parameter("ink_tint",Color.WHITE.lerp(blue,storm_mix))
			else:
				blue.a=storm_bases[index].a
				cloud.modulate=storm_bases[index].lerp(blue,storm_mix)
	_layout()

func begin_storm() -> void:
	if storm:return
	storm=true
	for entry: Dictionary in clouds:storm_bases.append(entry.visual.modulate)
func _layout() -> void:
	var frame:Vector2=get_viewport().get_visible_rect().size
	if frame.y<=0:return
	var height:float=camera.size
	var width:float=height*frame.x/frame.y
	for entry:Dictionary in mountains:
		var ridge:MeshInstance3D=entry.visual
		var anchor:Vector2=entry.anchor
		ridge.global_basis=camera.global_basis.scaled(Vector3.ONE*width*float(entry.width))
		ridge.global_position=camera.global_position-camera.global_basis.z*float(entry.depth)+camera.global_basis.x*((anchor.x-.5)*width)+camera.global_basis.y*((.5-anchor.y)*height)
	for entry:Dictionary in clouds:
		var cloud:Sprite3D=entry.visual
		var anchor:Vector2=entry.anchor
		var x:float=wrapf(anchor.x+elapsed*float(entry.speed),-.4,1.4)
		var y:float=anchor.y+sin(elapsed*.22+float(entry.phase))*.012
		cloud.global_basis=camera.global_basis
		cloud.global_position=camera.global_position-camera.global_basis.z*float(entry.depth)+camera.global_basis.x*((x-.5)*width)+camera.global_basis.y*((.5-y)*height)
		cloud.pixel_size=width*float(entry.width)/float(cloud.texture.get_width())

func _create_mountains(stage_number:int) -> void:
	var anchors:Array[Vector2]=[Vector2(.12,.52),Vector2(.88,.59),Vector2(.20,.87),Vector2(.83,.94)]
	for i:int in range(4):
		var texture:Texture2D=load("res://art/dummys/DummyMountain_%d.png"%(i+1 if stage_number==7 else i+5))
		var bounds:Rect2i=texture.get_image().get_used_rect()
		var dimensions:=Vector2(texture.get_size())
		var ink:=ShaderMaterial.new()
		ink.shader=preload("res://shaders/grid_mountain_mist.gdshader")
		ink.set_shader_parameter("mountain_image",texture)
		ink.set_shader_parameter("crop_uv",Vector4(bounds.position.x/dimensions.x,bounds.position.y/dimensions.y,bounds.size.x/dimensions.x,bounds.size.y/dimensions.y))
		ink.set_shader_parameter("opacity",.76 if i<2 else .70)
		if stage_number==8:ink.set_shader_parameter("ink_tint",Color("555f91"))
		ink.render_priority=-10
		var ridge:=MeshInstance3D.new()
		ridge.name="CloudRidge%d"%(i+1)
		var quad:=QuadMesh.new()
		quad.size=Vector2(1,float(bounds.size.y)/float(bounds.size.x))
		ridge.mesh=quad;ridge.material_override=ink
		ridge.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ridge.set_meta("slice_whole",true);ridge.set_meta("screen_band",0)
		ridge.set_meta("sky_mountain",true)
		add_child(ridge)
		var anchor:Vector2=anchors[i]
		if stage_number==8:anchor.x=1.0-anchor.x;anchor.y-=.035
		mountains.append({"visual":ridge,"anchor":anchor,"width":.22 if i%2==0 else .18,"depth":38.0+i*.3})
